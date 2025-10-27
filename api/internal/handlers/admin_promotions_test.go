package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminPromotionHandlers_CreatePromotion_CallsService(t *testing.T) {
	var received services.UpsertPromotionCommand
	service := &stubPromotionAdminService{
		createFn: func(ctx context.Context, cmd services.UpsertPromotionCommand) (services.Promotion, error) {
			received = cmd
			return services.Promotion{
				ID:           "promo123",
				Code:         "SPRING",
				Kind:         "percent",
				Value:        10,
				StartsAt:     time.Now(),
				EndsAt:       time.Now().Add(time.Hour),
				LimitPerUser: 1,
			}, nil
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)

	body := `{"code":"SPRING","kind":"percent","value":10,"startsAt":"2024-01-01T00:00:00Z","endsAt":"2024-02-01T00:00:00Z","limitPerUser":1}`
	req := httptest.NewRequest(http.MethodPost, "/promotions", strings.NewReader(body))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rec := httptest.NewRecorder()

	handler.createPromotion(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d", rec.Code)
	}
	if strings.ToUpper(received.Promotion.Code) != "SPRING" {
		t.Fatalf("expected promotion code passed to service")
	}
	if received.ActorID != "admin" {
		t.Fatalf("expected actor id to be propagated")
	}
}

func TestAdminPromotionHandlers_CreatePromotion_InvalidPayload(t *testing.T) {
	handler := NewAdminPromotionHandlers(nil, &stubPromotionAdminService{})
	req := httptest.NewRequest(http.MethodPost, "/promotions", strings.NewReader("{}"))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rec := httptest.NewRecorder()

	handler.createPromotion(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid payload, got %d", rec.Code)
	}
}

func TestAdminPromotionHandlers_ListPromotions_FilterMapping(t *testing.T) {
	var filter services.PromotionListFilter
	service := &stubPromotionAdminService{
		listFn: func(ctx context.Context, f services.PromotionListFilter) (services.PromotionPage, error) {
			filter = f
			return services.PromotionPage{}, nil
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)

	req := httptest.NewRequest(http.MethodGet, "/promotions?status=active,draft&kind=fixed&pageSize=5&activeOn=2024-01-01T00:00:00Z", nil)
	rec := httptest.NewRecorder()

	handler.listPromotions(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if len(filter.Status) != 2 {
		t.Fatalf("expected status filters to propagate, got %v", filter.Status)
	}
	if len(filter.Kinds) != 1 || filter.Kinds[0] != "fixed" {
		t.Fatalf("expected kind filter, got %v", filter.Kinds)
	}
	if filter.Pagination.PageSize != 5 {
		t.Fatalf("expected page size 5, got %d", filter.Pagination.PageSize)
	}
	if filter.ActiveOn == nil {
		t.Fatalf("expected activeOn to be set")
	}
}

func TestAdminPromotionHandlers_UpdatePromotion_AllowOverride(t *testing.T) {
	var received services.UpsertPromotionCommand
	service := &stubPromotionAdminService{
		updateFn: func(ctx context.Context, cmd services.UpsertPromotionCommand) (services.Promotion, error) {
			received = cmd
			return cmd.Promotion, nil
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)

	body := `{"code":"SPRING","kind":"percent","value":10,"startsAt":"2024-01-01T00:00:00Z","endsAt":"2024-02-01T00:00:00Z","limitPerUser":1,"allowImmutableUpdates":true}`
	req := httptest.NewRequest(http.MethodPut, "/promotions/promo1", strings.NewReader(body))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("promotionID", "promo1")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()

	handler.updatePromotion(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if !received.AllowImmutableUpdates {
		t.Fatalf("expected allow override flag to propagate")
	}
}

func TestAdminPromotionHandlers_DeletePromotion_MapsErrors(t *testing.T) {
	service := &stubPromotionAdminService{
		deleteFn: func(ctx context.Context, id string, actor string) error {
			return services.ErrPromotionNotFound
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)
	req := httptest.NewRequest(http.MethodDelete, "/promotions/promo", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("promotionID", "promo")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()

	handler.deletePromotion(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 when service reports missing, got %d", rec.Code)
	}
}

type stubPromotionAdminService struct {
	listFn   func(context.Context, services.PromotionListFilter) (services.PromotionPage, error)
	createFn func(context.Context, services.UpsertPromotionCommand) (services.Promotion, error)
	updateFn func(context.Context, services.UpsertPromotionCommand) (services.Promotion, error)
	deleteFn func(context.Context, string, string) error
}

func (s *stubPromotionAdminService) GetPublicPromotion(context.Context, string) (services.PromotionPublic, error) {
	return services.PromotionPublic{}, services.ErrPromotionOperationUnsupported
}

func (s *stubPromotionAdminService) ValidatePromotion(context.Context, services.ValidatePromotionCommand) (services.PromotionValidationResult, error) {
	return services.PromotionValidationResult{}, services.ErrPromotionOperationUnsupported
}

func (s *stubPromotionAdminService) ListPromotions(ctx context.Context, filter services.PromotionListFilter) (services.PromotionPage, error) {
	if s.listFn != nil {
		return s.listFn(ctx, filter)
	}
	return services.PromotionPage{}, nil
}

func (s *stubPromotionAdminService) CreatePromotion(ctx context.Context, cmd services.UpsertPromotionCommand) (services.Promotion, error) {
	if s.createFn != nil {
		return s.createFn(ctx, cmd)
	}
	return cmd.Promotion, nil
}

func (s *stubPromotionAdminService) UpdatePromotion(ctx context.Context, cmd services.UpsertPromotionCommand) (services.Promotion, error) {
	if s.updateFn != nil {
		return s.updateFn(ctx, cmd)
	}
	return cmd.Promotion, nil
}

func (s *stubPromotionAdminService) DeletePromotion(ctx context.Context, promotionID string, actorID string) error {
	if s.deleteFn != nil {
		return s.deleteFn(ctx, promotionID, actorID)
	}
	return nil
}

func (s *stubPromotionAdminService) ListPromotionUsage(context.Context, services.PromotionUsageFilter) (services.PromotionUsagePage, error) {
	return services.PromotionUsagePage{}, services.ErrPromotionOperationUnsupported
}
