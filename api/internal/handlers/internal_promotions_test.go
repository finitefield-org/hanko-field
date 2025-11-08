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

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
	"github.com/hanko-field/api/internal/services"
)

func TestInternalPromotionHandlers_ApplyPromotion_Success(t *testing.T) {
	now := time.Date(2024, time.September, 1, 10, 0, 0, 0, time.UTC)
	repo := &testPromotionRepository{promotion: domain.Promotion{
		ID:           "promo-success",
		Code:         "SAVE20",
		Status:       "active",
		IsActive:     true,
		Kind:         "percent",
		Value:        20,
		LimitPerUser: 5,
		UsageLimit:   100,
		StartsAt:     now.Add(-time.Hour),
		EndsAt:       now.Add(24 * time.Hour),
	}}
	usageRepo := newTestPromotionUsageRepo(repo, 5, 100)

	service, err := services.NewPromotionService(services.PromotionServiceDeps{
		Promotions: repo,
		Usage:      usageRepo,
		Clock:      func() time.Time { return now },
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	handler := NewInternalPromotionHandlers(service)
	router := chi.NewRouter()
	handler.Routes(router)

	rec := httptest.NewRecorder()
	requestBody := `{"code":"save20","userId":"user-1","cartTotals":{"currency":"jpy","subtotal":20000,"total":20000}}`
	req := httptest.NewRequest(http.MethodPost, "/promotions/apply", strings.NewReader(requestBody))
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	var resp internalPromotionApplyResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if !resp.Applied {
		t.Fatalf("expected applied true")
	}
	if resp.Code != "SAVE20" {
		t.Fatalf("expected code SAVE20, got %s", resp.Code)
	}
	if resp.DiscountAmount != 4000 {
		t.Fatalf("expected discount 4000, got %d", resp.DiscountAmount)
	}
	if resp.UserUsage.Times != 1 {
		t.Fatalf("expected user usage times 1, got %d", resp.UserUsage.Times)
	}
	if resp.RemainingUser == nil || *resp.RemainingUser != 4 {
		t.Fatalf("expected remaining user 4, got %v", resp.RemainingUser)
	}
	if resp.RemainingGlobal == nil || *resp.RemainingGlobal != 99 {
		t.Fatalf("expected remaining global 99, got %v", resp.RemainingGlobal)
	}
}

func TestInternalPromotionHandlers_ApplyPromotion_InvalidRequest(t *testing.T) {
	handler := NewInternalPromotionHandlers(nil)
	router := chi.NewRouter()
	handler.Routes(router)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/promotions/apply", strings.NewReader(`{"code":"","userId":""}`))
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 when service unavailable, got %d", rec.Code)
	}

	repo := &testPromotionRepository{promotion: domain.Promotion{}}
	service, _ := services.NewPromotionService(services.PromotionServiceDeps{
		Promotions: repo,
	})
	handler = NewInternalPromotionHandlers(service)
	router = chi.NewRouter()
	handler.Routes(router)
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/promotions/apply", strings.NewReader(`{"code":"","userId":"user"}`))
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for missing code, got %d", rec.Code)
	}
}

func TestInternalPromotionHandlers_ApplyPromotion_UserLimitError(t *testing.T) {
	now := time.Date(2024, time.September, 1, 11, 0, 0, 0, time.UTC)
	repo := &testPromotionRepository{promotion: domain.Promotion{
		ID:           "promo-limit",
		Code:         "ONCE",
		Status:       "active",
		IsActive:     true,
		Kind:         "fixed",
		Value:        1000,
		Currency:     "JPY",
		LimitPerUser: 1,
		UsageLimit:   10,
		StartsAt:     now.Add(-time.Hour),
		EndsAt:       now.Add(24 * time.Hour),
	}}
	usageRepo := newTestPromotionUsageRepo(repo, 1, 10)

	service, err := services.NewPromotionService(services.PromotionServiceDeps{
		Promotions: repo,
		Usage:      usageRepo,
		Clock:      func() time.Time { return now },
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	handler := NewInternalPromotionHandlers(service)
	router := chi.NewRouter()
	handler.Routes(router)

	payload := `{"code":"once","userId":"user-1","cartTotals":{"currency":"JPY","subtotal":5000,"total":5000}}`
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/promotions/apply", strings.NewReader(payload))
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected first request to succeed, got %d", rec.Code)
	}

	rec2 := httptest.NewRecorder()
	req2 := httptest.NewRequest(http.MethodPost, "/promotions/apply", strings.NewReader(payload))
	router.ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusConflict {
		t.Fatalf("expected 409 when limit reached, got %d", rec2.Code)
	}
}

type testPromotionRepository struct {
	promotion domain.Promotion
}

func (r *testPromotionRepository) Insert(context.Context, domain.Promotion) error {
	return nil
}

func (r *testPromotionRepository) Update(context.Context, domain.Promotion) error {
	return nil
}

func (r *testPromotionRepository) Delete(context.Context, string) error {
	return nil
}

func (r *testPromotionRepository) Get(context.Context, string) (domain.Promotion, error) {
	return r.promotion, nil
}

func (r *testPromotionRepository) FindByCode(context.Context, string) (domain.Promotion, error) {
	return r.promotion, nil
}

func (r *testPromotionRepository) List(context.Context, repositories.PromotionListFilter) (domain.CursorPage[domain.Promotion], error) {
	return domain.CursorPage[domain.Promotion]{}, nil
}

type testPromotionUsageRepo struct {
	repo         *testPromotionRepository
	usage        map[string]domain.PromotionUsage
	perUserLimit int
	globalLimit  int
}

func newTestPromotionUsageRepo(repo *testPromotionRepository, perUser, global int) *testPromotionUsageRepo {
	return &testPromotionUsageRepo{
		repo:         repo,
		usage:        make(map[string]domain.PromotionUsage),
		perUserLimit: perUser,
		globalLimit:  global,
	}
}

func (r *testPromotionUsageRepo) IncrementUsage(_ context.Context, _ string, userID string, now time.Time) (domain.PromotionUsage, error) {
	usage := r.usage[userID]
	if r.globalLimit > 0 && r.repo.promotion.UsageCount >= r.globalLimit {
		return domain.PromotionUsage{}, repositories.ErrPromotionUsageLimitExceeded
	}
	if usage.Blocked {
		return domain.PromotionUsage{}, repositories.ErrPromotionUsageBlocked
	}
	if r.perUserLimit > 0 && usage.Times >= r.perUserLimit {
		return domain.PromotionUsage{}, repositories.ErrPromotionUsagePerUserLimitExceeded
	}
	usage.UserID = userID
	usage.Times++
	usage.LastUsed = now.UTC()
	if usage.FirstUsed == nil {
		first := usage.LastUsed
		usage.FirstUsed = &first
	}
	r.usage[userID] = usage

	promo := r.repo.promotion
	promo.UsageCount++
	promo.UpdatedAt = now.UTC()
	r.repo.promotion = promo

	return usage, nil
}

func (r *testPromotionUsageRepo) GetUsage(_ context.Context, _ string, userID string) (domain.PromotionUsage, error) {
	if usage, ok := r.usage[userID]; ok {
		return usage, nil
	}
	return domain.PromotionUsage{UserID: userID}, nil
}

func (r *testPromotionUsageRepo) RemoveUsage(context.Context, string, string) error {
	return nil
}

func (r *testPromotionUsageRepo) ListUsage(context.Context, repositories.PromotionUsageListQuery) (domain.CursorPage[domain.PromotionUsage], error) {
	return domain.CursorPage[domain.PromotionUsage]{}, nil
}
