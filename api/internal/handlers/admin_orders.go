package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
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
	defaultAdminOrderPageSize = 50
	maxAdminOrderPageSize     = 200
	maxAdminShipmentBodySize  = 6 * 1024
)

// AdminOrderHandlers exposes order list endpoints for operations dashboards.
type AdminOrderHandlers struct {
	authn     *auth.Authenticator
	orders    services.OrderService
	shipments services.ShipmentService
	payments  services.PaymentService
	audit     services.AuditLogService
}

type adminCreateShipmentRequest struct {
	Carrier            string                     `json:"carrier"`
	ServiceLevel       string                     `json:"service_level"`
	TrackingPreference string                     `json:"tracking_preference"`
	ManualTrackingCode *string                    `json:"manual_tracking_code"`
	Package            *adminShipmentPackage      `json:"package"`
	Items              []adminShipmentItemRequest `json:"items"`
}

type adminUpdateShipmentRequest struct {
	Status                string  `json:"status"`
	ExpectedDelivery      *string `json:"expected_delivery"`
	ClearExpectedDelivery bool    `json:"clear_expected_delivery"`
	Notes                 *string `json:"notes"`
	TrackingCode          *string `json:"tracking_code"`
	IfUnmodifiedSince     *string `json:"if_unmodified_since"`
}

type adminShipmentPackage struct {
	Length float64 `json:"length"`
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
	Weight float64 `json:"weight"`
	Unit   string  `json:"unit"`
}

type adminShipmentItemRequest struct {
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
}

// NewAdminOrderHandlers constructs the admin order handler set.
func NewAdminOrderHandlers(authn *auth.Authenticator, orders services.OrderService, shipments services.ShipmentService, payments services.PaymentService, audit services.AuditLogService) *AdminOrderHandlers {
	return &AdminOrderHandlers{
		authn:     authn,
		orders:    orders,
		shipments: shipments,
		payments:  payments,
		audit:     audit,
	}
}

// Routes registers admin order endpoints under the provided router.
func (h *AdminOrderHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Get("/orders", h.listOrders)
	r.Put("/orders/{orderID}:status", h.updateOrderStatus)
	if h.shipments != nil {
		r.Post("/orders/{orderID}/shipments", h.createShipment)
		r.Put("/orders/{orderID}/shipments/{shipmentID}", h.updateShipment)
	}
	if h.payments != nil {
		r.Post("/orders/{orderID}/payments:manual-capture", h.manualCapturePayment)
		r.Post("/orders/{orderID}/payments:refund", h.manualRefundPayment)
	}
}

func (h *AdminOrderHandlers) listOrders(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.orders == nil {
		httpx.WriteError(ctx, w, httpx.NewError("order_service_unavailable", "order service unavailable", http.StatusServiceUnavailable))
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
	rawQuery := map[string][]string(query)
	pageSize := defaultAdminOrderPageSize
	if sizeRaw := strings.TrimSpace(firstNonEmpty(query.Get("page_size"), query.Get("pageSize"))); sizeRaw != "" {
		size, err := strconv.Atoi(sizeRaw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", "page_size must be an integer", http.StatusBadRequest))
			return
		}
		switch {
		case size <= 0:
			pageSize = defaultAdminOrderPageSize
		case size > maxAdminOrderPageSize:
			pageSize = maxAdminOrderPageSize
		default:
			pageSize = size
		}
	}

	filter := services.OrderListFilter{
		Status:           collectAdminOrderFilters(rawQuery, "status"),
		PaymentStatuses:  collectAdminOrderFilters(rawQuery, "payment_status", "paymentStatus"),
		ProductionQueues: collectAdminOrderFilters(rawQuery, "queue", "production_queue", "productionQueue"),
		Channels:         collectAdminOrderFilters(rawQuery, "channel", "sales_channel", "salesChannel"),
		CustomerEmail:    strings.TrimSpace(firstNonEmpty(query.Get("customer_email"), query.Get("customerEmail"))),
		PromotionCode:    strings.TrimSpace(firstNonEmpty(query.Get("promotion_code"), query.Get("promotionCode"))),
		Pagination: services.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(firstNonEmpty(query.Get("page_token"), query.Get("pageToken"))),
		},
	}

	var dateRange domain.RangeQuery[time.Time]
	hasRange := false
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("created_after"), query.Get("since"))); raw != "" {
		ts, err := parseTimeParam(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_created_after", "created_after must be a valid RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		dateRange.From = &ts
		hasRange = true
	}
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("created_before"), query.Get("until"))); raw != "" {
		ts, err := parseTimeParam(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_created_before", "created_before must be a valid RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		dateRange.To = &ts
		hasRange = true
	}
	if hasRange {
		filter.DateRange = dateRange
	}

	sortValue := strings.TrimSpace(query.Get("sort"))
	if sortValue == "" {
		filter.SortBy = services.OrderSortCreatedAt
	} else {
		if sortField, ok := parseAdminOrderSort(sortValue); ok {
			filter.SortBy = sortField
		} else {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_sort", "sort must be created_at, updated_at, or placed_at", http.StatusBadRequest))
			return
		}
	}

	orderValue := strings.TrimSpace(query.Get("order"))
	switch strings.ToLower(orderValue) {
	case "", "desc", "descending":
		filter.SortOrder = services.SortDesc
	case "asc", "ascending":
		filter.SortOrder = services.SortAsc
	default:
		httpx.WriteError(ctx, w, httpx.NewError("invalid_order", "order must be asc or desc", http.StatusBadRequest))
		return
	}

	page, err := h.orders.ListOrders(ctx, filter)
	if err != nil {
		writeOrderError(ctx, w, err)
		return
	}

	items := make([]adminOrderSummary, 0, len(page.Items))
	for _, order := range page.Items {
		items = append(items, buildAdminOrderSummary(order))
	}

	response := adminOrderListResponse{
		Items:         items,
		NextPageToken: strings.TrimSpace(page.NextPageToken),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func parseAdminOrderSort(raw string) (services.OrderSort, bool) {
	normalized := strings.ToLower(strings.TrimSpace(raw))
	normalized = strings.ReplaceAll(normalized, "_", "")
	normalized = strings.ReplaceAll(normalized, "-", "")

	switch normalized {
	case "", "created", "createdat":
		return services.OrderSortCreatedAt, true
	case "updated", "updatedat":
		return services.OrderSortUpdatedAt, true
	case "placed", "placedat":
		return services.OrderSortPlacedAt, true
	default:
		return "", false
	}
}

type adminOrderListResponse struct {
	Items         []adminOrderSummary `json:"items"`
	NextPageToken string              `json:"next_page_token,omitempty"`
}

type adminOrderSummary struct {
	ID               string   `json:"id"`
	OrderNumber      string   `json:"order_number"`
	Status           string   `json:"status"`
	PaymentStatus    string   `json:"payment_status,omitempty"`
	Currency         string   `json:"currency"`
	Total            int64    `json:"total"`
	CustomerEmail    string   `json:"customer_email,omitempty"`
	PromotionCode    string   `json:"promotion_code,omitempty"`
	Channel          string   `json:"channel,omitempty"`
	ProductionQueue  string   `json:"production_queue,omitempty"`
	ProductionStage  string   `json:"production_stage,omitempty"`
	LastEventType    string   `json:"last_event_type,omitempty"`
	LastEventAt      string   `json:"last_event_at,omitempty"`
	OutstandingTasks []string `json:"outstanding_tasks,omitempty"`
	OnHold           bool     `json:"on_hold,omitempty"`
	CreatedAt        string   `json:"created_at"`
	UpdatedAt        string   `json:"updated_at,omitempty"`
	PlacedAt         string   `json:"placed_at,omitempty"`
	PaidAt           string   `json:"paid_at,omitempty"`
}

const (
	maxAdminOrderStatusBodySize = 4 * 1024
	maxAdminPaymentBodySize     = 8 * 1024
)

var adminOrderWorkflowTransitions = map[services.OrderStatus]services.OrderStatus{
	services.OrderStatus(domain.OrderStatusPaid):         services.OrderStatus(domain.OrderStatusInProduction),
	services.OrderStatus(domain.OrderStatusInProduction): services.OrderStatus(domain.OrderStatusShipped),
	services.OrderStatus(domain.OrderStatusReadyToShip):  services.OrderStatus(domain.OrderStatusShipped),
	services.OrderStatus(domain.OrderStatusShipped):      services.OrderStatus(domain.OrderStatusDelivered),
	services.OrderStatus(domain.OrderStatusDelivered):    services.OrderStatus(domain.OrderStatusCompleted),
}

var adminAllowedTargetStatuses = map[services.OrderStatus]struct{}{
	services.OrderStatus(domain.OrderStatusInProduction): {},
	services.OrderStatus(domain.OrderStatusShipped):      {},
	services.OrderStatus(domain.OrderStatusDelivered):    {},
	services.OrderStatus(domain.OrderStatusCompleted):    {},
}

type adminOrderStatusRequest struct {
	TargetStatus   string         `json:"target_status"`
	ExpectedStatus string         `json:"expected_status"`
	Reason         string         `json:"reason"`
	Metadata       map[string]any `json:"metadata"`
}

type adminOrderStatusResponse struct {
	Order adminOrderSummary `json:"order"`
}

func (h *AdminOrderHandlers) updateOrderStatus(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.orders == nil {
		httpx.WriteError(ctx, w, httpx.NewError("order_service_unavailable", "order service unavailable", http.StatusServiceUnavailable))
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

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "order id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxAdminOrderStatusBodySize)
	if err != nil {
		switch {
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		case errors.Is(err, errEmptyBody):
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "request body is required", http.StatusBadRequest))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	var payload adminOrderStatusRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON body", http.StatusBadRequest))
		return
	}

	targetRaw := strings.TrimSpace(payload.TargetStatus)
	if targetRaw == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "target_status is required", http.StatusBadRequest))
		return
	}
	targetStatus, ok := parseOrderStatus(targetRaw)
	if !ok {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "target_status must be a valid order status", http.StatusBadRequest))
		return
	}
	if _, allowed := adminAllowedTargetStatuses[targetStatus]; !allowed {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "target_status must be in_production, shipped, delivered, or completed", http.StatusBadRequest))
		return
	}

	order, err := h.orders.GetOrder(ctx, orderID, services.OrderReadOptions{})
	if err != nil {
		writeOrderError(ctx, w, err)
		return
	}

	currentStatus, parsed := parseOrderStatus(string(order.Status))
	if !parsed {
		currentStatus = services.OrderStatus(domain.OrderStatus(strings.TrimSpace(strings.ToLower(string(order.Status)))))
	}

	if currentStatus == targetStatus {
		httpx.WriteError(ctx, w, httpx.NewError("order_invalid_state", "order already in requested status", http.StatusConflict))
		return
	}

	nextStatus, ok := adminOrderWorkflowTransitions[currentStatus]
	if !ok {
		httpx.WriteError(ctx, w, httpx.NewError("order_invalid_state", fmt.Sprintf("status %s cannot transition via workflow", currentStatus), http.StatusConflict))
		return
	}
	if targetStatus != nextStatus {
		httpx.WriteError(ctx, w, httpx.NewError("order_invalid_state", fmt.Sprintf("status %s cannot transition to %s", currentStatus, targetStatus), http.StatusConflict))
		return
	}

	expectedStatus := currentStatus
	if trimmed := strings.TrimSpace(payload.ExpectedStatus); trimmed != "" {
		expectedParsed, ok := parseOrderStatus(trimmed)
		if !ok {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "expected_status must be a valid order status", http.StatusBadRequest))
			return
		}
		if expectedParsed != currentStatus {
			httpx.WriteError(ctx, w, httpx.NewError("order_conflict", fmt.Sprintf("expected status %q but was %q", trimmed, order.Status), http.StatusConflict))
			return
		}
		expectedStatus = expectedParsed
	}

	reason := strings.TrimSpace(payload.Reason)

	cmd := services.OrderStatusTransitionCommand{
		OrderID:        orderID,
		TargetStatus:   targetStatus,
		ActorID:        strings.TrimSpace(identity.UID),
		Reason:         reason,
		ExpectedStatus: &expectedStatus,
		Metadata:       cloneMap(payload.Metadata),
	}

	updated, err := h.orders.TransitionStatus(ctx, cmd)
	if err != nil {
		writeOrderError(ctx, w, err)
		return
	}

	h.recordOrderStatusAudit(ctx, identity, orderID, currentStatus, updated.Status, reason, payload.Metadata)

	response := adminOrderStatusResponse{
		Order: buildAdminOrderSummary(updated),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminOrderHandlers) createShipment(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.shipments == nil {
		httpx.WriteError(ctx, w, httpx.NewError("shipment_service_unavailable", "shipment service unavailable", http.StatusServiceUnavailable))
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

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_order_id", "order id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxAdminShipmentBodySize)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	var payload adminCreateShipmentRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON payload", http.StatusBadRequest))
		return
	}

	items := make([]services.ShipmentItem, 0, len(payload.Items))
	for _, item := range payload.Items {
		items = append(items, services.ShipmentItem{
			LineItemSKU: strings.TrimSpace(item.SKU),
			Quantity:    item.Quantity,
		})
	}

	var pkg *services.ShipmentPackage
	if payload.Package != nil {
		pkg = &services.ShipmentPackage{
			Length: payload.Package.Length,
			Width:  payload.Package.Width,
			Height: payload.Package.Height,
			Weight: payload.Package.Weight,
			Unit:   strings.TrimSpace(payload.Package.Unit),
		}
	}

	cmd := services.CreateShipmentCommand{
		OrderID:            orderID,
		Carrier:            payload.Carrier,
		ServiceLevel:       payload.ServiceLevel,
		TrackingPreference: payload.TrackingPreference,
		Package:            pkg,
		Items:              items,
		CreatedBy:          identity.UID,
	}
	if payload.ManualTrackingCode != nil {
		manual := strings.TrimSpace(*payload.ManualTrackingCode)
		if manual != "" {
			cmd.ManualTrackingCode = &manual
		}
	}

	shipment, err := h.shipments.CreateShipment(ctx, cmd)
	if err != nil {
		writeShipmentError(ctx, w, err)
		return
	}

	response := struct {
		Shipment orderShipmentPayload `json:"shipment"`
	}{
		Shipment: buildOrderShipmentDetail(shipment),
	}
	writeJSONResponse(w, http.StatusCreated, response)
}

func (h *AdminOrderHandlers) updateShipment(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.shipments == nil {
		httpx.WriteError(ctx, w, httpx.NewError("shipment_service_unavailable", "shipment service unavailable", http.StatusServiceUnavailable))
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

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_order_id", "order id is required", http.StatusBadRequest))
		return
	}
	shipmentID := strings.TrimSpace(chi.URLParam(r, "shipmentID"))
	if shipmentID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_shipment_id", "shipment id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxAdminShipmentBodySize)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	var payload adminUpdateShipmentRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON payload", http.StatusBadRequest))
		return
	}

	status := strings.TrimSpace(payload.Status)
	if status == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_status", "status is required", http.StatusBadRequest))
		return
	}

	var expectedDelivery *time.Time
	if payload.ExpectedDelivery != nil {
		trimmed := strings.TrimSpace(*payload.ExpectedDelivery)
		if trimmed != "" {
			parsed, parseErr := parseRFC3339Flexible(trimmed)
			if parseErr != nil {
				httpx.WriteError(ctx, w, httpx.NewError("invalid_expected_delivery", "expected_delivery must be RFC3339", http.StatusBadRequest))
				return
			}
			t := parsed.UTC()
			expectedDelivery = &t
		}
	}
	if payload.ClearExpectedDelivery && expectedDelivery != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_expected_delivery", "cannot set and clear expected delivery simultaneously", http.StatusBadRequest))
		return
	}

	var ifUnmodifiedSince *time.Time
	if payload.IfUnmodifiedSince != nil {
		trimmed := strings.TrimSpace(*payload.IfUnmodifiedSince)
		if trimmed != "" {
			parsed, parseErr := parseRFC3339Flexible(trimmed)
			if parseErr != nil {
				httpx.WriteError(ctx, w, httpx.NewError("invalid_if_unmodified_since", "if_unmodified_since must be RFC3339", http.StatusBadRequest))
				return
			}
			t := parsed.UTC()
			ifUnmodifiedSince = &t
		}
	}

	var trackingPtr *string
	if payload.TrackingCode != nil {
		value := strings.TrimSpace(*payload.TrackingCode)
		trackingPtr = &value
	}

	var notesPtr *string
	if payload.Notes != nil {
		value := strings.TrimSpace(*payload.Notes)
		notesPtr = &value
	}

	var previousShipment *services.Shipment
	if h.orders != nil {
		order, getErr := h.orders.GetOrder(ctx, orderID, services.OrderReadOptions{IncludeShipments: true})
		if getErr == nil {
			for idx := range order.Shipments {
				if strings.EqualFold(strings.TrimSpace(order.Shipments[idx].ID), shipmentID) {
					s := order.Shipments[idx]
					previousShipment = &s
					break
				}
			}
		}
	}

	cmd := services.UpdateShipmentCommand{
		OrderID:               orderID,
		ShipmentID:            shipmentID,
		Status:                status,
		TrackingCode:          trackingPtr,
		ExpectedDelivery:      expectedDelivery,
		ClearExpectedDelivery: payload.ClearExpectedDelivery,
		Notes:                 notesPtr,
		IfUnmodifiedSince:     ifUnmodifiedSince,
		ActorID:               identity.UID,
	}

	shipment, err := h.shipments.UpdateShipmentStatus(ctx, cmd)
	if err != nil {
		writeShipmentError(ctx, w, err)
		return
	}

	h.recordShipmentAudit(ctx, identity, orderID, previousShipment, shipment)

	response := struct {
		Shipment orderShipmentPayload `json:"shipment"`
	}{
		Shipment: buildOrderShipmentDetail(shipment),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func parseRFC3339Flexible(value string) (time.Time, error) {
	if parsed, err := time.Parse(time.RFC3339Nano, value); err == nil {
		return parsed, nil
	}
	return time.Parse(time.RFC3339, value)
}

type adminPaymentActionRequest struct {
	PaymentID      string            `json:"payment_id"`
	Amount         *int64            `json:"amount"`
	Reason         string            `json:"reason"`
	IdempotencyKey string            `json:"idempotency_key"`
	Metadata       map[string]string `json:"metadata"`
}

type adminPaymentActionResponse struct {
	Payment        adminPaymentPayload         `json:"payment"`
	PaymentSummary *adminPaymentSummaryPayload `json:"payment_summary,omitempty"`
}

type adminPaymentPayload struct {
	ID             string `json:"id"`
	Provider       string `json:"provider"`
	Status         string `json:"status"`
	Amount         int64  `json:"amount"`
	Currency       string `json:"currency"`
	TransactionID  string `json:"transaction_id,omitempty"`
	Captured       bool   `json:"captured"`
	CapturedAt     string `json:"captured_at,omitempty"`
	RefundedAt     string `json:"refunded_at,omitempty"`
	RefundedAmount int64  `json:"refunded_amount"`
	CreatedAt      string `json:"created_at"`
	UpdatedAt      string `json:"updated_at,omitempty"`
}

type adminPaymentSummaryPayload struct {
	Status         string `json:"status"`
	CapturedAmount int64  `json:"captured_amount"`
	RefundedAmount int64  `json:"refunded_amount"`
	BalanceDue     int64  `json:"balance_due"`
	UpdatedAt      string `json:"updated_at,omitempty"`
}

func (h *AdminOrderHandlers) manualCapturePayment(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.payments == nil {
		httpx.WriteError(ctx, w, httpx.NewError("payment_service_unavailable", "payment service unavailable", http.StatusServiceUnavailable))
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

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "order id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxAdminPaymentBodySize)
	if err != nil {
		switch {
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		case errors.Is(err, errEmptyBody):
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "request body is required", http.StatusBadRequest))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	var payload adminPaymentActionRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON body", http.StatusBadRequest))
		return
	}

	paymentID := strings.TrimSpace(payload.PaymentID)
	if paymentID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "payment_id is required", http.StatusBadRequest))
		return
	}

	if payload.Amount != nil && *payload.Amount <= 0 {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "amount must be positive", http.StatusBadRequest))
		return
	}

	cmd := services.PaymentManualCaptureCommand{
		OrderID:        orderID,
		PaymentID:      paymentID,
		ActorID:        strings.TrimSpace(identity.UID),
		Amount:         payload.Amount,
		Reason:         strings.TrimSpace(payload.Reason),
		IdempotencyKey: strings.TrimSpace(payload.IdempotencyKey),
		Metadata:       sanitizeStringMap(payload.Metadata),
	}

	payment, err := h.payments.ManualCapture(ctx, cmd)
	if err != nil {
		writePaymentError(ctx, w, err)
		return
	}

	response := adminPaymentActionResponse{
		Payment: buildAdminPaymentPayload(payment),
	}
	if summary := h.lookupPaymentSummary(ctx, orderID); summary != nil {
		response.PaymentSummary = summary
	}

	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminOrderHandlers) manualRefundPayment(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.payments == nil {
		httpx.WriteError(ctx, w, httpx.NewError("payment_service_unavailable", "payment service unavailable", http.StatusServiceUnavailable))
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

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "order id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxAdminPaymentBodySize)
	if err != nil {
		switch {
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		case errors.Is(err, errEmptyBody):
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "request body is required", http.StatusBadRequest))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	var payload adminPaymentActionRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON body", http.StatusBadRequest))
		return
	}

	paymentID := strings.TrimSpace(payload.PaymentID)
	if paymentID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "payment_id is required", http.StatusBadRequest))
		return
	}
	if payload.Amount != nil && *payload.Amount <= 0 {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "amount must be positive", http.StatusBadRequest))
		return
	}

	cmd := services.PaymentManualRefundCommand{
		OrderID:        orderID,
		PaymentID:      paymentID,
		ActorID:        strings.TrimSpace(identity.UID),
		Amount:         payload.Amount,
		Reason:         strings.TrimSpace(payload.Reason),
		IdempotencyKey: strings.TrimSpace(payload.IdempotencyKey),
		Metadata:       sanitizeStringMap(payload.Metadata),
	}

	payment, err := h.payments.ManualRefund(ctx, cmd)
	if err != nil {
		writePaymentError(ctx, w, err)
		return
	}

	response := adminPaymentActionResponse{
		Payment: buildAdminPaymentPayload(payment),
	}
	if summary := h.lookupPaymentSummary(ctx, orderID); summary != nil {
		response.PaymentSummary = summary
	}

	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminOrderHandlers) lookupPaymentSummary(ctx context.Context, orderID string) *adminPaymentSummaryPayload {
	if h.orders == nil {
		return nil
	}
	order, err := h.orders.GetOrder(ctx, orderID, services.OrderReadOptions{})
	if err != nil {
		return nil
	}
	return buildAdminPaymentSummary(order)
}

func buildAdminPaymentPayload(payment services.Payment) adminPaymentPayload {
	payload := adminPaymentPayload{
		ID:             strings.TrimSpace(payment.ID),
		Provider:       strings.TrimSpace(payment.Provider),
		Status:         strings.TrimSpace(payment.Status),
		Amount:         payment.Amount,
		Currency:       strings.ToUpper(strings.TrimSpace(payment.Currency)),
		TransactionID:  strings.TrimSpace(payment.IntentID),
		Captured:       payment.Captured,
		RefundedAmount: extractRefundedAmount(payment),
		CreatedAt:      formatTime(payment.CreatedAt),
		UpdatedAt:      formatTime(payment.UpdatedAt),
	}
	if payment.CapturedAt != nil {
		payload.CapturedAt = formatTime(pointerTime(payment.CapturedAt))
	}
	if payment.RefundedAt != nil {
		payload.RefundedAt = formatTime(pointerTime(payment.RefundedAt))
	}
	return payload
}

func buildAdminPaymentSummary(order services.Order) *adminPaymentSummaryPayload {
	root := mapFromAny(order.Metadata["payment"])
	if root == nil {
		return nil
	}
	summary := &adminPaymentSummaryPayload{
		Status:         strings.TrimSpace(stringify(valueFromMap(root, "status"))),
		CapturedAmount: intFromAny(valueFromMap(root, "capturedAmount", "captured_amount")),
		RefundedAmount: intFromAny(valueFromMap(root, "refundedAmount", "refunded_amount")),
		BalanceDue:     intFromAny(valueFromMap(root, "balanceDue", "balance_due")),
	}
	if updated := valueFromMap(root, "updatedAt", "updated_at"); updated != nil {
		switch v := updated.(type) {
		case time.Time:
			summary.UpdatedAt = formatTime(v)
		case *time.Time:
			if v != nil {
				summary.UpdatedAt = formatTime(pointerTime(v))
			}
		default:
			if ts := stringify(v); ts != "" {
				summary.UpdatedAt = ts
			}
		}
	}
	return summary
}

func buildAdminOrderSummary(order services.Order) adminOrderSummary {
	queueRef := ""
	if order.Production.QueueRef != nil {
		queueRef = strings.TrimSpace(*order.Production.QueueRef)
	}

	summary := adminOrderSummary{
		ID:               strings.TrimSpace(order.ID),
		OrderNumber:      strings.TrimSpace(order.OrderNumber),
		Status:           strings.TrimSpace(string(order.Status)),
		PaymentStatus:    strings.TrimSpace(extractOrderPaymentStatus(order)),
		Currency:         strings.TrimSpace(order.Currency),
		Total:            order.Totals.Total,
		CustomerEmail:    extractOrderCustomerEmail(order),
		PromotionCode:    extractOrderPromotionCode(order),
		Channel:          extractOrderChannel(order),
		ProductionQueue:  queueRef,
		ProductionStage:  extractOrderProductionStage(order),
		LastEventType:    strings.TrimSpace(order.Production.LastEventType),
		LastEventAt:      formatTime(pointerTime(order.Production.LastEventAt)),
		OutstandingTasks: extractOrderOutstandingTasks(order),
		OnHold:           order.Production.OnHold,
		CreatedAt:        formatTime(order.CreatedAt),
		UpdatedAt:        formatTime(order.UpdatedAt),
		PlacedAt:         formatTime(pointerTime(order.PlacedAt)),
		PaidAt:           formatTime(pointerTime(order.PaidAt)),
	}

	if len(summary.OutstandingTasks) > 1 {
		sort.Strings(summary.OutstandingTasks)
	}

	return summary
}

func extractOrderCustomerEmail(order services.Order) string {
	if order.Contact != nil {
		if email := strings.TrimSpace(order.Contact.Email); email != "" {
			return email
		}
	}
	if email := stringFromMap(order.Metadata, "customerEmail", "customer_email", "email"); email != "" {
		return email
	}
	if email := stringFromMap(order.Notes, "customerEmail", "customer_email"); email != "" {
		return email
	}
	return ""
}

func extractOrderPromotionCode(order services.Order) string {
	if order.Promotion != nil {
		if code := strings.TrimSpace(order.Promotion.Code); code != "" {
			return code
		}
	}
	return stringFromMap(order.Metadata, "promotionCode", "promotion_code", "promo", "promoCode")
}

func extractOrderChannel(order services.Order) string {
	if channel := stringFromMap(order.Metadata, "channel", "orderChannel", "salesChannel"); channel != "" {
		return channel
	}
	if ops := mapFromAny(order.Metadata["operations"]); ops != nil {
		if channel := stringFromMap(ops, "channel", "queue"); channel != "" {
			return channel
		}
	}
	return ""
}

func extractOrderProductionStage(order services.Order) string {
	if stage := stringFromMap(order.Metadata, "productionStage", "production_stage", "stage"); stage != "" {
		return stage
	}
	if stage := strings.TrimSpace(order.Production.LastEventType); stage != "" {
		return stage
	}
	return strings.TrimSpace(string(order.Status))
}

func extractOrderOutstandingTasks(order services.Order) []string {
	if tasks := normalizeStringSlice(stringSliceFromAny(order.Metadata["outstandingTasks"])); len(tasks) > 0 {
		return tasks
	}
	if tasks := normalizeStringSlice(stringSliceFromAny(order.Metadata["outstanding_tasks"])); len(tasks) > 0 {
		return tasks
	}
	if ops := mapFromAny(order.Metadata["operations"]); ops != nil {
		if tasks := normalizeStringSlice(stringSliceFromAny(ops["outstandingTasks"])); len(tasks) > 0 {
			return tasks
		}
		if tasks := normalizeStringSlice(stringSliceFromAny(ops["outstanding_tasks"])); len(tasks) > 0 {
			return tasks
		}
	}
	if len(order.Notes) > 0 {
		if tasks := normalizeStringSlice(stringSliceFromAny(order.Notes["outstandingTasks"])); len(tasks) > 0 {
			return tasks
		}
		if tasks := normalizeStringSlice(stringSliceFromAny(order.Notes["outstanding_tasks"])); len(tasks) > 0 {
			return tasks
		}
	}
	return nil
}

func extractOrderPaymentStatus(order services.Order) string {
	if status := stringFromMap(order.Metadata, "paymentStatus", "payment_status", "paymentState"); status != "" {
		return status
	}
	if payment := mapFromAny(order.Metadata["payment"]); payment != nil {
		if status := stringFromMap(payment, "status", "state"); status != "" {
			return status
		}
	}
	if len(order.Payments) > 0 {
		latest := order.Payments[0]
		for _, payment := range order.Payments[1:] {
			if payment.CreatedAt.After(latest.CreatedAt) {
				latest = payment
			}
		}
		if status := strings.TrimSpace(latest.Status); status != "" {
			return status
		}
	}
	if order.PaidAt != nil && !order.PaidAt.IsZero() {
		return "paid"
	}
	switch order.Status {
	case domain.OrderStatusPendingPayment:
		return "pending"
	case domain.OrderStatusCanceled:
		return "canceled"
	default:
		return ""
	}
}

func collectAdminOrderFilters(values map[string][]string, keys ...string) []string {
	if len(keys) == 0 || len(values) == 0 {
		return nil
	}
	combined := make([]string, 0)
	for _, key := range keys {
		if entries, ok := values[key]; ok {
			combined = append(combined, entries...)
		}
	}
	return collectQueryValues(combined)
}

func stringFromMap(data map[string]any, keys ...string) string {
	if len(data) == 0 {
		return ""
	}
	for _, key := range keys {
		if value, ok := data[key]; ok {
			if str := stringify(value); str != "" {
				return str
			}
		}
	}
	return ""
}

func normalizeStringSlice(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(values))
	out := make([]string, 0, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if _, exists := seen[trimmed]; exists {
			continue
		}
		seen[trimmed] = struct{}{}
		out = append(out, trimmed)
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func valueFromMap(data map[string]any, keys ...string) any {
	if len(data) == 0 {
		return nil
	}
	for _, key := range keys {
		if value, ok := data[key]; ok {
			return value
		}
	}
	return nil
}

func sanitizeStringMap(input map[string]string) map[string]string {
	if len(input) == 0 {
		return nil
	}
	result := make(map[string]string, len(input))
	for k, v := range input {
		key := strings.TrimSpace(k)
		if key == "" {
			continue
		}
		result[key] = strings.TrimSpace(v)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func writePaymentError(ctx context.Context, w http.ResponseWriter, err error) {
	if err == nil {
		return
	}
	switch {
	case errors.Is(err, services.ErrPaymentInvalidInput):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrPaymentNotFound):
		httpx.WriteError(ctx, w, httpx.NewError("payment_not_found", "payment not found", http.StatusNotFound))
	case errors.Is(err, services.ErrPaymentInvalidState):
		httpx.WriteError(ctx, w, httpx.NewError("payment_invalid_state", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPaymentConflict):
		httpx.WriteError(ctx, w, httpx.NewError("payment_conflict", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPaymentUnavailable):
		httpx.WriteError(ctx, w, httpx.NewError("payment_service_unavailable", "payment service unavailable", http.StatusServiceUnavailable))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("payment_error", "failed to process payment request", http.StatusInternalServerError))
	}
}

func (h *AdminOrderHandlers) recordOrderStatusAudit(ctx context.Context, identity *auth.Identity, orderID string, before services.OrderStatus, after services.OrderStatus, reason string, metadata map[string]any) {
	if h.audit == nil {
		return
	}

	trimmedOrderID := strings.TrimSpace(orderID)
	actorID := ""
	if identity != nil {
		actorID = strings.TrimSpace(identity.UID)
	}

	record := services.AuditLogRecord{
		Actor:      actorID,
		ActorType:  adminOrderActorType(identity),
		Action:     "order.status.transition",
		TargetRef:  fmt.Sprintf("/orders/%s", trimmedOrderID),
		OccurredAt: time.Now().UTC(),
		Diff: map[string]services.AuditLogDiff{
			"status": {
				Before: string(before),
				After:  string(after),
			},
		},
		Metadata: map[string]any{
			"fromStatus": string(before),
			"toStatus":   string(after),
		},
	}

	if reason != "" {
		record.Metadata["reason"] = reason
	}

	if len(metadata) > 0 {
		for key, value := range cloneMap(metadata) {
			if record.Metadata == nil {
				record.Metadata = map[string]any{}
			}
			if _, exists := record.Metadata[key]; exists {
				continue
			}
			record.Metadata[key] = value
		}
	}

	h.audit.Record(ctx, record)
}

func (h *AdminOrderHandlers) recordShipmentAudit(ctx context.Context, identity *auth.Identity, orderID string, before *services.Shipment, after services.Shipment) {
	if h.audit == nil {
		return
	}

	trimmedOrderID := strings.TrimSpace(orderID)
	trimmedShipmentID := strings.TrimSpace(after.ID)
	actorID := ""
	if identity != nil {
		actorID = strings.TrimSpace(identity.UID)
	}

	previousStatus := ""
	previousTracking := ""
	previousETA := ""
	previousNote := ""
	if before != nil {
		previousStatus = strings.TrimSpace(before.Status)
		previousTracking = strings.TrimSpace(before.TrackingCode)
		previousETA = formatTime(pointerTime(before.ETA))
		previousNote = strings.TrimSpace(before.Notes)
	}

	currentStatus := strings.TrimSpace(after.Status)
	currentTracking := strings.TrimSpace(after.TrackingCode)
	currentETA := formatTime(pointerTime(after.ETA))
	currentNote := strings.TrimSpace(after.Notes)

	diff := make(map[string]services.AuditLogDiff)
	if previousStatus != currentStatus {
		diff["status"] = services.AuditLogDiff{Before: previousStatus, After: currentStatus}
	}
	if previousTracking != currentTracking {
		diff["tracking_code"] = services.AuditLogDiff{Before: previousTracking, After: currentTracking}
	}
	if previousETA != currentETA {
		diff["expected_delivery"] = services.AuditLogDiff{Before: previousETA, After: currentETA}
	}
	if previousNote != currentNote {
		diff["note"] = services.AuditLogDiff{Before: previousNote, After: currentNote}
	}

	if len(diff) == 0 {
		return
	}

	metadata := map[string]any{
		"shipmentId": trimmedShipmentID,
		"status":     currentStatus,
	}
	if currentTracking != "" {
		metadata["trackingNumber"] = currentTracking
	}
	if currentETA != "" {
		metadata["expectedDelivery"] = currentETA
	}
	if currentNote != "" {
		metadata["note"] = currentNote
	}

	record := services.AuditLogRecord{
		Actor:      actorID,
		ActorType:  adminOrderActorType(identity),
		Action:     "order.shipment.update",
		TargetRef:  fmt.Sprintf("/orders/%s/shipments/%s", trimmedOrderID, trimmedShipmentID),
		OccurredAt: time.Now().UTC(),
		Metadata:   metadata,
		Diff:       diff,
	}

	h.audit.Record(ctx, record)
}

func adminOrderActorType(identity *auth.Identity) string {
	if identity == nil {
		return "staff"
	}
	switch {
	case identity.HasRole(auth.RoleAdmin):
		return "admin"
	case identity.HasRole(auth.RoleStaff):
		return "staff"
	default:
		if len(identity.Roles) > 0 {
			return strings.TrimSpace(identity.Roles[0])
		}
		return "staff"
	}
}
