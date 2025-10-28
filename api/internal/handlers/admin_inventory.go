package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const (
	defaultLowStockPageSize      = 50
	maxLowStockPageSize          = 200
	defaultVelocityLookback      = 14
	defaultLowStockOrderPageSize = 200
	maxVelocityPages             = 20
)

// AdminInventoryHandlers exposes admin/staff stock endpoints.
type AdminInventoryHandlers struct {
	authn     *auth.Authenticator
	inventory services.InventoryService
	catalog   services.CatalogService
	orders    services.OrderService

	now                  func() time.Time
	velocityLookbackDays int
	orderPageSize        int
	maxOrderPages        int
}

// NewAdminInventoryHandlers constructs admin inventory handlers.
func NewAdminInventoryHandlers(authn *auth.Authenticator, inventory services.InventoryService, catalog services.CatalogService, orders services.OrderService) *AdminInventoryHandlers {
	handler := &AdminInventoryHandlers{
		authn:     authn,
		inventory: inventory,
		catalog:   catalog,
		orders:    orders,
		now: func() time.Time {
			return time.Now().UTC()
		},
		velocityLookbackDays: defaultVelocityLookback,
		orderPageSize:        defaultLowStockOrderPageSize,
		maxOrderPages:        maxVelocityPages,
	}
	return handler
}

// Routes registers admin inventory endpoints under /stock.
func (h *AdminInventoryHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Route("/stock", func(rt chi.Router) {
		rt.Get("/low", h.listLowStock)
	})
}

func (h *AdminInventoryHandlers) listLowStock(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.inventory == nil {
		httpx.WriteError(ctx, w, httpx.NewError("inventory_service_unavailable", "inventory service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	query := r.URL.Query()
	pageSize := defaultLowStockPageSize
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("page_size"), query.Get("pageSize"))); raw != "" {
		size, err := strconv.Atoi(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", "page_size must be an integer", http.StatusBadRequest))
			return
		}
		switch {
		case size <= 0:
			pageSize = defaultLowStockPageSize
		case size > maxLowStockPageSize:
			pageSize = maxLowStockPageSize
		default:
			pageSize = size
		}
	}

	threshold := 0
	if raw := strings.TrimSpace(query.Get("threshold")); raw != "" {
		value, err := strconv.Atoi(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_threshold", "threshold must be an integer", http.StatusBadRequest))
			return
		}
		threshold = value
	}

	filter := services.InventoryLowStockFilter{
		Threshold: threshold,
		Pagination: services.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(firstNonEmpty(query.Get("page_token"), query.Get("pageToken"))),
		},
	}

	page, err := h.inventory.ListLowStock(ctx, filter)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("inventory_query_failed", err.Error(), http.StatusInternalServerError))
		return
	}

	now := h.now()
	skuSet := make(map[string]struct{}, len(page.Items))
	for _, snapshot := range page.Items {
		sku := strings.TrimSpace(snapshot.SKU)
		if sku != "" {
			skuSet[sku] = struct{}{}
		}
	}

	velocityBySKU, err := h.computeSalesVelocity(ctx, now, skuSet)
	if err != nil {
		var httpStatus int
		code := "order_service_error"
		if errors.Is(err, services.ErrOrderInvalidInput) {
			httpStatus = http.StatusBadRequest
			code = "invalid_order_filter"
		} else if errors.Is(err, services.ErrOrderNotFound) {
			httpStatus = http.StatusNotFound
			code = "order_not_found"
		} else {
			httpStatus = http.StatusInternalServerError
		}
		httpx.WriteError(ctx, w, httpx.NewError(code, err.Error(), httpStatus))
		return
	}

	items := make([]adminLowStockItem, 0, len(page.Items))
	for _, snapshot := range page.Items {
		info, err := h.resolveSupplierInfo(ctx, snapshot.ProductRef)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("catalog_lookup_failed", err.Error(), http.StatusInternalServerError))
			return
		}
		velocity := velocityBySKU[strings.TrimSpace(snapshot.SKU)]
		projected := h.projectDepletion(now, snapshot.Available, velocity)

		item := adminLowStockItem{
			SKU:                    strings.TrimSpace(snapshot.SKU),
			ProductRef:             strings.TrimSpace(snapshot.ProductRef),
			OnHand:                 snapshot.OnHand,
			Reserved:               snapshot.Reserved,
			Available:              snapshot.Available,
			SafetyStock:            snapshot.SafetyStock,
			SafetyDelta:            snapshot.SafetyDelta,
			SupplierRef:            info.SupplierRef,
			SupplierName:           info.SupplierName,
			RecentSalesVelocity:    velocity,
			ProjectedDepletionDate: projected,
			UpdatedAt:              snapshot.UpdatedAt,
		}
		items = append(items, item)
	}

	response := adminLowStockResponse{
		Items:         items,
		NextPageToken: strings.TrimSpace(page.NextPageToken),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(response)
}

func (h *AdminInventoryHandlers) computeSalesVelocity(ctx context.Context, now time.Time, skus map[string]struct{}) (map[string]float64, error) {
	result := make(map[string]float64, len(skus))
	if h.orders == nil || len(skus) == 0 || h.velocityLookbackDays <= 0 {
		return result, nil
	}

	lookbackStart := now.Add(-time.Duration(h.velocityLookbackDays) * 24 * time.Hour)
	filter := services.OrderListFilter{
		Status: []string{
			string(domain.OrderStatusPaid),
			string(domain.OrderStatusInProduction),
			string(domain.OrderStatusReadyToShip),
			string(domain.OrderStatusShipped),
			string(domain.OrderStatusDelivered),
			string(domain.OrderStatusCompleted),
		},
		DateRange: domain.RangeQuery[time.Time]{From: &lookbackStart},
		Pagination: services.Pagination{
			PageSize: h.orderPageSize,
		},
		SortBy:    services.OrderSortCreatedAt,
		SortOrder: services.SortDesc,
	}

	pagesRead := 0
	pageToken := ""
	for {
		filter.Pagination.PageToken = pageToken
		page, err := h.orders.ListOrders(ctx, filter)
		if err != nil {
			return nil, err
		}
		for _, order := range page.Items {
			if order.CreatedAt.Before(lookbackStart) {
				continue
			}
			for _, item := range order.Items {
				sku := strings.TrimSpace(item.SKU)
				if _, ok := skus[sku]; !ok || sku == "" {
					continue
				}
				result[sku] += float64(item.Quantity)
			}
		}
		pageToken = strings.TrimSpace(page.NextPageToken)
		pagesRead++
		if pageToken == "" || pagesRead >= h.maxOrderPages {
			break
		}
	}

	days := float64(h.velocityLookbackDays)
	if days <= 0 {
		return result, nil
	}
	for sku, total := range result {
		result[sku] = math.Round((total/days)*100) / 100
	}
	return result, nil
}

func (h *AdminInventoryHandlers) projectDepletion(now time.Time, available int, velocity float64) *time.Time {
	if velocity <= 0 {
		return nil
	}
	remaining := float64(available)
	if remaining <= 0 {
		projected := now
		return &projected
	}
	duration := time.Duration(remaining / velocity * 24 * float64(time.Hour))
	projected := now.Add(duration)
	return &projected
}

type supplierSnapshot struct {
	SupplierRef  string
	SupplierName string
}

func (h *AdminInventoryHandlers) resolveSupplierInfo(ctx context.Context, productRef string) (supplierSnapshot, error) {
	productRef = strings.TrimSpace(productRef)
	if productRef == "" || h.catalog == nil {
		return supplierSnapshot{}, nil
	}
	if strings.HasPrefix(productRef, "/materials/") {
		materialID := strings.TrimPrefix(productRef, "/materials/")
		material, err := h.catalog.GetMaterial(ctx, materialID)
		if err != nil {
			return supplierSnapshot{}, err
		}
		return supplierSnapshot{
			SupplierRef:  strings.TrimSpace(material.Procurement.SupplierRef),
			SupplierName: strings.TrimSpace(material.Procurement.SupplierName),
		}, nil
	}
	if strings.HasPrefix(productRef, "/products/") {
		productID := strings.TrimPrefix(productRef, "/products/")
		product, err := h.catalog.GetProduct(ctx, productID)
		if err != nil {
			return supplierSnapshot{}, err
		}
		defaultMaterialID := strings.TrimSpace(product.DefaultMaterialID)
		if defaultMaterialID == "" {
			return supplierSnapshot{}, nil
		}
		material, err := h.catalog.GetMaterial(ctx, defaultMaterialID)
		if err != nil {
			return supplierSnapshot{}, err
		}
		return supplierSnapshot{
			SupplierRef:  strings.TrimSpace(material.Procurement.SupplierRef),
			SupplierName: strings.TrimSpace(material.Procurement.SupplierName),
		}, nil
	}
	return supplierSnapshot{}, nil
}

type adminLowStockResponse struct {
	Items         []adminLowStockItem `json:"items"`
	NextPageToken string              `json:"next_page_token,omitempty"`
}

type adminLowStockItem struct {
	SKU                    string     `json:"sku"`
	ProductRef             string     `json:"product_ref"`
	OnHand                 int        `json:"on_hand"`
	Reserved               int        `json:"reserved"`
	Available              int        `json:"available"`
	SafetyStock            int        `json:"safety_stock"`
	SafetyDelta            int        `json:"safety_delta"`
	SupplierRef            string     `json:"supplier_ref,omitempty"`
	SupplierName           string     `json:"supplier_name,omitempty"`
	RecentSalesVelocity    float64    `json:"recent_sales_velocity"`
	ProjectedDepletionDate *time.Time `json:"projected_depletion_date,omitempty"`
	UpdatedAt              time.Time  `json:"updated_at"`
}
