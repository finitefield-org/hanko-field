package handlers

import (
	"context"
	"encoding/json"
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
	if received.UsageLimitSet {
		t.Fatalf("expected usage limit to remain unset when field omitted")
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

func TestAdminPromotionHandlers_ListPromotionUsage_MapsFilters(t *testing.T) {
	var captured services.PromotionUsageFilter
	service := &stubPromotionAdminService{
		usageFn: func(ctx context.Context, filter services.PromotionUsageFilter) (services.PromotionUsagePage, error) {
			captured = filter
			return services.PromotionUsagePage{}, nil
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)

	req := httptest.NewRequest(http.MethodGet, "/promotions/promo-1/usages?pageSize=10&pageToken=%20token%20&minUsage=3&sort=times&order=asc", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("promotionID", " promo-1 ")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()

	handler.listPromotionUsage(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if captured.PromotionID != "promo-1" {
		t.Fatalf("expected promotion id trimmed, got %q", captured.PromotionID)
	}
	if captured.Pagination.PageSize != 10 {
		t.Fatalf("expected page size propagated, got %d", captured.Pagination.PageSize)
	}
	if captured.Pagination.PageToken != "token" {
		t.Fatalf("expected page token trimmed, got %q", captured.Pagination.PageToken)
	}
	if captured.MinTimes != 3 {
		t.Fatalf("expected min usage parsed, got %d", captured.MinTimes)
	}
	if captured.SortBy != services.PromotionUsageSortTimes {
		t.Fatalf("expected sort mapped to times, got %q", captured.SortBy)
	}
	if captured.SortOrder != services.SortAsc {
		t.Fatalf("expected sort order asc, got %v", captured.SortOrder)
	}
}

func TestAdminPromotionHandlers_ListPromotionUsage_AsCSV(t *testing.T) {
	usageTime := time.Date(2024, time.June, 1, 10, 0, 0, 0, time.UTC)
	firstUsed := usageTime.Add(-24 * time.Hour)
	service := &stubPromotionAdminService{
		usageFn: func(ctx context.Context, filter services.PromotionUsageFilter) (services.PromotionUsagePage, error) {
			return services.PromotionUsagePage{
				Items: []services.PromotionUsageRecord{{
					Usage: services.PromotionUsage{
						UserID:    "user-1",
						Times:     2,
						LastUsed:  usageTime,
						FirstUsed: &firstUsed,
						OrderRefs: []string{"/orders/abc"},
						Notes:     "checked",
					},
					User: services.PromotionUsageUser{
						ID:          "user-1",
						Email:       "user-1@example.com",
						DisplayName: "Tester",
					},
				}},
				NextPageToken: "next-token",
			}, nil
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)

	req := httptest.NewRequest(http.MethodGet, "/promotions/promo-99/usages?format=csv", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("promotionID", "promo-99")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()

	handler.listPromotionUsage(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); !strings.Contains(got, "text/csv") {
		t.Fatalf("expected csv content type, got %q", got)
	}
	if rec.Header().Get("X-Next-Page-Token") != "next-token" {
		t.Fatalf("expected next page token header")
	}
	body := strings.TrimSpace(rec.Body.String())
	lines := strings.Split(body, "\n")
	if len(lines) != 2 {
		t.Fatalf("expected header and one row, got %d lines: %v", len(lines), lines)
	}
	expectedHeader := "uid,email,displayName,times,lastUsedAt,firstUsedAt,blocked,orderRefs,notes"
	if lines[0] != expectedHeader {
		t.Fatalf("unexpected csv header %q", lines[0])
	}
	if !strings.Contains(lines[1], "user-1@example.com") {
		t.Fatalf("expected csv row to include user email, got %q", lines[1])
	}
}

func TestAdminPromotionHandlers_ListPromotionUsage_Unauthenticated(t *testing.T) {
	handler := NewAdminPromotionHandlers(nil, &stubPromotionAdminService{})
	req := httptest.NewRequest(http.MethodGet, "/promotions/promo-1/usages", nil)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("promotionID", "promo-1")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()

	handler.listPromotionUsage(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 unauthenticated, got %d", rec.Code)
	}
}

func TestAdminPromotionHandlers_ValidatePromotion_ReturnsChecks(t *testing.T) {
	var captured services.Promotion
	service := &stubPromotionAdminService{
		validateDefinitionFn: func(ctx context.Context, promotion services.Promotion) (services.PromotionDefinitionValidationResult, error) {
			captured = promotion
			return services.PromotionDefinitionValidationResult{
				Valid: false,
				Checks: []services.PromotionValidationCheck{
					{Constraint: services.PromotionConstraintStructure, Passed: true},
					{Constraint: services.PromotionConstraintSchedule, Passed: false, Issues: []string{"startsAt is required"}},
				},
				Normalized: services.Promotion{
					Code:         "SPRING",
					Kind:         "percent",
					Value:        10,
					LimitPerUser: 1,
				},
			}, nil
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)

	body := `{"code":"spring","kind":"percent","value":10,"limitPerUser":1}`
	req := httptest.NewRequest(http.MethodPost, "/promotions:validate", strings.NewReader(body))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rec := httptest.NewRecorder()

	handler.validatePromotion(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if captured.Code != "spring" {
		t.Fatalf("expected raw promotion code to remain unnormalized, got %s", captured.Code)
	}

	var response struct {
		Valid  bool `json:"valid"`
		Checks []struct {
			Constraint string   `json:"constraint"`
			Passed     bool     `json:"passed"`
			Issues     []string `json:"issues"`
		} `json:"checks"`
		Normalized struct {
			Code string `json:"code"`
		} `json:"normalized"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if response.Valid {
		t.Fatalf("expected validation to be false")
	}
	if len(response.Checks) == 0 {
		t.Fatalf("expected checks to be returned")
	}
	foundSchedule := false
	for _, check := range response.Checks {
		if check.Constraint == "schedule" {
			foundSchedule = true
			if check.Passed {
				t.Fatalf("expected schedule check to fail")
			}
			if len(check.Issues) != 1 || check.Issues[0] != "startsAt is required" {
				t.Fatalf("unexpected issues for schedule: %#v", check.Issues)
			}
		}
	}
	if !foundSchedule {
		t.Fatalf("expected schedule check in response: %#v", response.Checks)
	}
	if response.Normalized.Code != "SPRING" {
		t.Fatalf("expected normalized promotion code to be uppercased, got %s", response.Normalized.Code)
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
	if received.UsageLimitSet {
		t.Fatalf("expected usage limit unset when field omitted")
	}
}

func TestAdminPromotionHandlers_UpdatePromotion_UsageLimitProvided(t *testing.T) {
	var received services.UpsertPromotionCommand
	service := &stubPromotionAdminService{
		updateFn: func(ctx context.Context, cmd services.UpsertPromotionCommand) (services.Promotion, error) {
			received = cmd
			return cmd.Promotion, nil
		},
	}
	handler := NewAdminPromotionHandlers(nil, service)

	body := `{"code":"CLEAR","kind":"percent","value":5,"startsAt":"2024-01-01T00:00:00Z","endsAt":"2024-02-01T00:00:00Z","limitPerUser":1,"usageLimit":0}`
	req := httptest.NewRequest(http.MethodPut, "/promotions/promo2", strings.NewReader(body))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin"}))
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("promotionID", "promo2")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rec := httptest.NewRecorder()

	handler.updatePromotion(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if !received.UsageLimitSet {
		t.Fatalf("expected usage limit flag to be set when field provided")
	}
	if received.Promotion.UsageLimit != 0 {
		t.Fatalf("expected usage limit to propagate value, got %d", received.Promotion.UsageLimit)
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
	listFn               func(context.Context, services.PromotionListFilter) (services.PromotionPage, error)
	createFn             func(context.Context, services.UpsertPromotionCommand) (services.Promotion, error)
	updateFn             func(context.Context, services.UpsertPromotionCommand) (services.Promotion, error)
	deleteFn             func(context.Context, string, string) error
	usageFn              func(context.Context, services.PromotionUsageFilter) (services.PromotionUsagePage, error)
	validateDefinitionFn func(context.Context, services.Promotion) (services.PromotionDefinitionValidationResult, error)
}

func (s *stubPromotionAdminService) GetPublicPromotion(context.Context, string) (services.PromotionPublic, error) {
	return services.PromotionPublic{}, services.ErrPromotionOperationUnsupported
}

func (s *stubPromotionAdminService) ValidatePromotion(context.Context, services.ValidatePromotionCommand) (services.PromotionValidationResult, error) {
	return services.PromotionValidationResult{}, services.ErrPromotionOperationUnsupported
}

func (s *stubPromotionAdminService) ValidatePromotionDefinition(ctx context.Context, promotion services.Promotion) (services.PromotionDefinitionValidationResult, error) {
	if s.validateDefinitionFn != nil {
		return s.validateDefinitionFn(ctx, promotion)
	}
	return services.PromotionDefinitionValidationResult{}, nil
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

func (s *stubPromotionAdminService) ListPromotionUsage(ctx context.Context, filter services.PromotionUsageFilter) (services.PromotionUsagePage, error) {
	if s.usageFn != nil {
		return s.usageFn(ctx, filter)
	}
	return services.PromotionUsagePage{}, services.ErrPromotionOperationUnsupported
}
