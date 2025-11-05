package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminInventoryHandlers_ListLowStock_RequiresAuthentication(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, &stubInventoryService{}, nil, nil)

	req := httptest.NewRequest(http.MethodGet, "/stock/low", nil)
	rec := httptest.NewRecorder()

	handler.listLowStock(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ListLowStock_RequiresStaffRole(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, &stubInventoryService{}, nil, nil)

	req := httptest.NewRequest(http.MethodGet, "/stock/low", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user-1", Roles: []string{"customer"}}))
	rec := httptest.NewRecorder()

	handler.listLowStock(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ListLowStock_ServiceUnavailable(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, nil, nil, nil)

	req := httptest.NewRequest(http.MethodGet, "/stock/low", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "ops", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.listLowStock(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ListLowStock_CatalogUnavailable(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, &stubInventoryService{}, nil, &stubOrderService{})

	req := httptest.NewRequest(http.MethodGet, "/stock/low", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "ops", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listLowStock(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 when catalog missing, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ReleaseExpired_RequiresAuthentication(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, &stubInventoryService{}, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/stock/reservations:release-expired", nil)
	rec := httptest.NewRecorder()

	handler.releaseExpiredReservations(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ReleaseExpired_RequiresStaffRole(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, &stubInventoryService{}, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/stock/reservations:release-expired", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user-1", Roles: []string{"customer"}}))
	rec := httptest.NewRecorder()

	handler.releaseExpiredReservations(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ReleaseExpired_ServiceUnavailable(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, nil, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/stock/reservations:release-expired", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "ops", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.releaseExpiredReservations(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ReleaseExpired_RejectsNegativeLimit(t *testing.T) {
	handler := NewAdminInventoryHandlers(nil, &stubInventoryService{}, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/stock/reservations:release-expired", strings.NewReader(`{"limit": -5}`))
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "ops", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.releaseExpiredReservations(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestAdminInventoryHandlers_ReleaseExpired_Succeeds(t *testing.T) {
	var captured services.ReleaseExpiredReservationsCommand
	inventory := &stubInventoryService{
		releaseExpiredFn: func(ctx context.Context, cmd services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error) {
			captured = cmd
			return services.InventoryReleaseExpiredResult{
				CheckedCount:         3,
				ReleasedCount:        2,
				AlreadyReleasedCount: 1,
				NotFoundCount:        0,
				ReservationIDs:       []string{"res-1", "res-3"},
				AlreadyReleasedIDs:   []string{"res-2"},
				SKUs:                 []string{"SKU-1", "SKU-3"},
			}, nil
		},
	}
	handler := NewAdminInventoryHandlers(nil, inventory, nil, nil)

	body := strings.NewReader(`{"limit": 25, "reason": " manual cleanup "}`)
	req := httptest.NewRequest(http.MethodPost, "/stock/reservations:release-expired", body)
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "ops-1", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.releaseExpiredReservations(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if captured.Limit != 25 {
		t.Fatalf("expected limit 25 captured, got %d", captured.Limit)
	}
	if captured.ActorID != "ops-1" {
		t.Fatalf("expected actor ops-1, got %s", captured.ActorID)
	}
	if captured.Reason != "manual cleanup" {
		t.Fatalf("expected trimmed reason manual cleanup, got %q", captured.Reason)
	}

	var payload adminReleaseExpiredResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.CheckedCount != 3 || payload.ReleasedCount != 2 {
		t.Fatalf("unexpected counts %+v", payload)
	}
	if len(payload.ReservationIDs) != 2 || payload.ReservationIDs[0] != "res-1" {
		t.Fatalf("unexpected reservation ids %+v", payload.ReservationIDs)
	}
	if len(payload.AlreadyReleasedIDs) != 1 || payload.AlreadyReleasedIDs[0] != "res-2" {
		t.Fatalf("unexpected already released ids %+v", payload.AlreadyReleasedIDs)
	}
	if len(payload.Skus) != 2 {
		t.Fatalf("expected two skus, got %+v", payload.Skus)
	}
	if payload.SkippedCount != 0 || len(payload.SkippedIDs) != 0 {
		t.Fatalf("expected no skipped reservations, got %+v", payload.SkippedIDs)
	}
}

func TestAdminInventoryHandlers_ListLowStock_AggregatesSupplierAndVelocity(t *testing.T) {
	now := time.Date(2024, 6, 1, 10, 0, 0, 0, time.UTC)
	var capturedFilter services.InventoryLowStockFilter
	inventory := &stubInventoryService{
		listFn: func(ctx context.Context, filter services.InventoryLowStockFilter) (domain.CursorPage[services.InventorySnapshot], error) {
			capturedFilter = filter
			return domain.CursorPage[services.InventorySnapshot]{
				Items: []services.InventorySnapshot{{
					SKU:         "SKU-42",
					ProductRef:  "/materials/mat-wood",
					OnHand:      12,
					Reserved:    3,
					Available:   9,
					SafetyStock: 15,
					SafetyDelta: -6,
					UpdatedAt:   now.Add(-2 * time.Hour),
				}},
				NextPageToken: " next ",
			}, nil
		},
	}

	catalog := &inventoryCatalogStub{
		getMaterialFn: func(ctx context.Context, materialID string) (services.Material, error) {
			if materialID != "mat-wood" {
				t.Fatalf("expected material id mat-wood got %s", materialID)
			}
			return services.Material{
				MaterialSummary: services.MaterialSummary{
					ID:           materialID,
					LeadTimeDays: 12,
					Procurement: services.MaterialProcurement{
						SupplierRef:  "sup-17",
						SupplierName: "Nagoya Timber",
					},
				},
			}, nil
		},
	}

	order := &stubOrderService{
		listFn: func(ctx context.Context, filter services.OrderListFilter) (domain.CursorPage[services.Order], error) {
			if filter.Pagination.PageSize != 100 {
				t.Fatalf("expected page size 100, got %d", filter.Pagination.PageSize)
			}
			if filter.DateRange.From == nil {
				t.Fatalf("expected lookback start")
			}
			expectedFrom := now.Add(-14 * 24 * time.Hour)
			if filter.DateRange.From.Sub(expectedFrom) > time.Second || filter.DateRange.From.Sub(expectedFrom) < -time.Second {
				t.Fatalf("expected lookback start near %v got %v", expectedFrom, filter.DateRange.From)
			}
			statuses := map[string]bool{}
			for _, s := range filter.Status {
				statuses[s] = true
			}
			if !statuses[string(domain.OrderStatusPaid)] || !statuses[string(domain.OrderStatusCompleted)] {
				t.Fatalf("expected relevant statuses, got %v", filter.Status)
			}
			return domain.CursorPage[services.Order]{
				Items: []services.Order{
					{
						ID:        "ord-1",
						CreatedAt: now.Add(-time.Hour),
						Status:    domain.OrderStatusPaid,
						Items: []services.OrderLineItem{
							{SKU: "SKU-42", Quantity: 7},
						},
					},
					{
						ID:        "ord-2",
						CreatedAt: now.Add(-48 * time.Hour),
						Status:    domain.OrderStatusCompleted,
						Items: []services.OrderLineItem{
							{SKU: "SKU-42", Quantity: 7},
							{SKU: "SKU-99", Quantity: 2},
						},
					},
				},
			}, nil
		},
	}

	handler := NewAdminInventoryHandlers(nil, inventory, catalog, order, WithAdminInventoryConfig(AdminInventoryConfig{
		VelocityLookbackDays: 14,
		OrderPageSize:        100,
		MaxOrderPages:        3,
	}))
	handler.now = func() time.Time { return now }

	req := httptest.NewRequest(http.MethodGet, "/stock/low?threshold=5&page_size=120&page_token=%20tok%20", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "ops", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.listLowStock(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200 got %d", rec.Code)
	}

	if capturedFilter.Threshold != 5 {
		t.Fatalf("expected threshold 5 got %d", capturedFilter.Threshold)
	}
	if capturedFilter.Pagination.PageSize != 120 {
		t.Fatalf("expected page size 120 got %d", capturedFilter.Pagination.PageSize)
	}
	if capturedFilter.Pagination.PageToken != "tok" {
		t.Fatalf("expected trimmed page token tok got %q", capturedFilter.Pagination.PageToken)
	}

	var payload adminLowStockResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.NextPageToken != "next" {
		t.Fatalf("expected trimmed next page token next got %q", payload.NextPageToken)
	}
	if len(payload.Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(payload.Items))
	}
	item := payload.Items[0]
	if item.SKU != "SKU-42" {
		t.Fatalf("expected sku preserved got %s", item.SKU)
	}
	if strings.TrimSpace(item.SupplierRef) != "sup-17" {
		t.Fatalf("expected supplier ref sup-17 got %s", item.SupplierRef)
	}
	if strings.TrimSpace(item.SupplierName) != "Nagoya Timber" {
		t.Fatalf("expected supplier name Nagoya Timber got %s", item.SupplierName)
	}
	expectedVelocity := 1.0 // 14 units / 14 days
	if item.RecentSalesVelocity != expectedVelocity {
		t.Fatalf("expected velocity %.1f got %.2f", expectedVelocity, item.RecentSalesVelocity)
	}
	if item.ProjectedDepletionDate == nil {
		t.Fatalf("expected projected depletion date")
	}
	expectedDepletion := now.Add(9 * 24 * time.Hour)
	if item.ProjectedDepletionDate.Sub(expectedDepletion) > time.Minute || item.ProjectedDepletionDate.Sub(expectedDepletion) < -time.Minute {
		t.Fatalf("expected depletion around %v got %v", expectedDepletion, item.ProjectedDepletionDate)
	}
}

func TestAdminInventoryHandlers_WithConfigZeroValuesFallback(t *testing.T) {
	now := time.Date(2024, 6, 10, 9, 0, 0, 0, time.UTC)
	var captured services.OrderListFilter
	orderSvc := &stubOrderService{
		listFn: func(ctx context.Context, filter services.OrderListFilter) (domain.CursorPage[services.Order], error) {
			captured = filter
			return domain.CursorPage[services.Order]{}, nil
		},
	}

	handler := NewAdminInventoryHandlers(nil, &stubInventoryService{}, &inventoryCatalogStub{}, orderSvc)
	handler.velocityLookbackDays = 0
	handler.orderPageSize = 0
	handler.maxOrderPages = 0

	_, err := handler.computeSalesVelocity(context.Background(), now, map[string]struct{}{"SKU-1": {}})
	if err != nil {
		t.Fatalf("compute velocity: %v", err)
	}
	if captured.Pagination.PageSize != defaultLowStockOrderPageSize {
		t.Fatalf("expected default page size %d, got %d", defaultLowStockOrderPageSize, captured.Pagination.PageSize)
	}
	if captured.DateRange.From == nil {
		t.Fatalf("expected lookback start to be set")
	}
	expectedFrom := now.Add(-time.Duration(defaultVelocityLookback) * 24 * time.Hour)
	if delta := captured.DateRange.From.Sub(expectedFrom); delta > time.Second || delta < -time.Second {
		t.Fatalf("expected default lookback start near %v got %v", expectedFrom, captured.DateRange.From)
	}
}

type stubInventoryService struct {
	listFn           func(context.Context, services.InventoryLowStockFilter) (domain.CursorPage[services.InventorySnapshot], error)
	releaseExpiredFn func(context.Context, services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error)
	getFn            func(context.Context, string) (services.InventoryReservation, error)
}

func (s *stubInventoryService) ReserveStocks(ctx context.Context, cmd services.InventoryReserveCommand) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubInventoryService) CommitReservation(ctx context.Context, cmd services.InventoryCommitCommand) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubInventoryService) GetReservation(ctx context.Context, reservationID string) (services.InventoryReservation, error) {
	if s.getFn != nil {
		return s.getFn(ctx, reservationID)
	}
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubInventoryService) ReleaseReservation(ctx context.Context, cmd services.InventoryReleaseCommand) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubInventoryService) ReleaseExpiredReservations(ctx context.Context, cmd services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error) {
	if s.releaseExpiredFn != nil {
		return s.releaseExpiredFn(ctx, cmd)
	}
	return services.InventoryReleaseExpiredResult{}, errors.New("not implemented")
}

func (s *stubInventoryService) ListLowStock(ctx context.Context, filter services.InventoryLowStockFilter) (domain.CursorPage[services.InventorySnapshot], error) {
	if s.listFn != nil {
		return s.listFn(ctx, filter)
	}
	return domain.CursorPage[services.InventorySnapshot]{}, nil
}

func (s *stubInventoryService) ConfigureSafetyStock(ctx context.Context, cmd services.ConfigureSafetyStockCommand) (services.InventoryStock, error) {
	return services.InventoryStock{}, errors.New("not implemented")
}

func (s *stubInventoryService) RecordSafetyNotification(context.Context, services.RecordSafetyNotificationCommand) (services.InventoryStock, error) {
	return services.InventoryStock{}, errors.New("not implemented")
}

type inventoryCatalogStub struct {
	getMaterialFn func(context.Context, string) (services.Material, error)
	getProductFn  func(context.Context, string) (services.Product, error)
}

func (s *inventoryCatalogStub) ListTemplates(ctx context.Context, filter services.TemplateFilter) (domain.CursorPage[services.TemplateSummary], error) {
	return domain.CursorPage[services.TemplateSummary]{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) GetTemplate(ctx context.Context, templateID string) (services.Template, error) {
	return services.Template{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) UpsertTemplate(ctx context.Context, cmd services.UpsertTemplateCommand) (services.Template, error) {
	return services.Template{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) DeleteTemplate(ctx context.Context, cmd services.DeleteTemplateCommand) error {
	return errors.New("not implemented")
}

func (s *inventoryCatalogStub) ListFonts(ctx context.Context, filter services.FontFilter) (domain.CursorPage[services.FontSummary], error) {
	return domain.CursorPage[services.FontSummary]{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) GetFont(ctx context.Context, fontID string) (services.Font, error) {
	return services.Font{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) UpsertFont(ctx context.Context, cmd services.UpsertFontCommand) (services.FontSummary, error) {
	return services.FontSummary{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) DeleteFont(ctx context.Context, fontID string) error {
	return errors.New("not implemented")
}

func (s *inventoryCatalogStub) ListMaterials(ctx context.Context, filter services.MaterialFilter) (domain.CursorPage[services.MaterialSummary], error) {
	return domain.CursorPage[services.MaterialSummary]{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) GetMaterial(ctx context.Context, materialID string) (services.Material, error) {
	if s.getMaterialFn != nil {
		return s.getMaterialFn(ctx, materialID)
	}
	return services.Material{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) UpsertMaterial(ctx context.Context, cmd services.UpsertMaterialCommand) (services.MaterialSummary, error) {
	return services.MaterialSummary{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) DeleteMaterial(ctx context.Context, cmd services.DeleteMaterialCommand) error {
	return errors.New("not implemented")
}

func (s *inventoryCatalogStub) ListProducts(ctx context.Context, filter services.ProductFilter) (domain.CursorPage[services.ProductSummary], error) {
	return domain.CursorPage[services.ProductSummary]{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) GetProduct(ctx context.Context, productID string) (services.Product, error) {
	if s.getProductFn != nil {
		return s.getProductFn(ctx, productID)
	}
	return services.Product{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) UpsertProduct(ctx context.Context, cmd services.UpsertProductCommand) (services.Product, error) {
	return services.Product{}, errors.New("not implemented")
}

func (s *inventoryCatalogStub) DeleteProduct(ctx context.Context, cmd services.DeleteProductCommand) error {
	return errors.New("not implemented")
}
