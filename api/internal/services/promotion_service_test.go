package services

import (
	"context"
	"errors"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

func TestPromotionService_GetPublicPromotion_Success(t *testing.T) {
	now := time.Date(2024, time.June, 1, 9, 0, 0, 0, time.UTC)
	repo := &stubPromotionRepository{
		promotion: domain.Promotion{
			Code:              "SPRING10",
			Status:            "active",
			DescriptionPublic: "Spring offer",
			StartsAt:          now.Add(-time.Hour),
			EndsAt:            now.Add(2 * time.Hour),
			EligibleAudiences: []string{"new", "vip"},
		},
	}

	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: repo,
		Clock: func() time.Time {
			return now
		},
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	result, err := svc.GetPublicPromotion(context.Background(), " spring10 ")
	if err != nil {
		t.Fatalf("GetPublicPromotion returned error: %v", err)
	}
	if !result.IsAvailable {
		t.Fatalf("expected promotion to be available")
	}
	if result.Code != "SPRING10" {
		t.Fatalf("expected code SPRING10 got %s", result.Code)
	}
	if result.DescriptionPublic != "Spring offer" {
		t.Fatalf("unexpected description %q", result.DescriptionPublic)
	}
	if len(result.EligibleAudiences) != 2 {
		t.Fatalf("unexpected audiences %v", result.EligibleAudiences)
	}
	if repo.lastCode != "SPRING10" {
		t.Fatalf("repository looked up wrong code %s", repo.lastCode)
	}
}

func TestPromotionService_GetPublicPromotion_NotFound(t *testing.T) {
	repo := &stubPromotionRepository{
		findByCodeFn: func(context.Context, string) (domain.Promotion, error) {
			return domain.Promotion{}, &stubPromotionRepoError{notFound: true}
		},
	}
	svc, err := NewPromotionService(PromotionServiceDeps{Promotions: repo})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	_, err = svc.GetPublicPromotion(context.Background(), "MISSING")
	if !errors.Is(err, ErrPromotionNotFound) {
		t.Fatalf("expected ErrPromotionNotFound got %v", err)
	}
}

func TestPromotionService_GetPublicPromotion_UnavailableFlags(t *testing.T) {
	repo := &stubPromotionRepository{
		promotion: domain.Promotion{
			Code:         "PRIVATE",
			Status:       "active",
			InternalOnly: true,
		},
	}
	svc, err := NewPromotionService(PromotionServiceDeps{Promotions: repo})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	if _, err := svc.GetPublicPromotion(context.Background(), "PRIVATE"); !errors.Is(err, ErrPromotionUnavailable) {
		t.Fatalf("expected ErrPromotionUnavailable got %v", err)
	}

	repo.promotion.InternalOnly = false
	repo.promotion.RequiresAuth = true
	if _, err := svc.GetPublicPromotion(context.Background(), "PRIVATE"); !errors.Is(err, ErrPromotionUnavailable) {
		t.Fatalf("expected ErrPromotionUnavailable for requiresAuth flag got %v", err)
	}
}

func TestPromotionService_GetPublicPromotion_NotYetActive(t *testing.T) {
	now := time.Date(2024, time.July, 1, 10, 0, 0, 0, time.UTC)
	repo := &stubPromotionRepository{
		promotion: domain.Promotion{
			Code:     "LATER",
			Status:   "active",
			StartsAt: now.Add(time.Hour),
			EndsAt:   now.Add(24 * time.Hour),
		},
	}
	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: repo,
		Clock: func() time.Time {
			return now
		},
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	result, err := svc.GetPublicPromotion(context.Background(), "LATER")
	if err != nil {
		t.Fatalf("GetPublicPromotion returned error: %v", err)
	}
	if result.IsAvailable {
		t.Fatalf("expected promotion to be unavailable before start")
	}
}

func TestPromotionService_CreatePromotion_NormalizesPayload(t *testing.T) {
	now := time.Date(2024, time.April, 10, 12, 0, 0, 0, time.UTC)
	var inserted domain.Promotion
	repo := &stubPromotionRepository{
		insertFn: func(_ context.Context, promo domain.Promotion) error {
			inserted = promo
			return nil
		},
	}
	audit := &promotionAuditLogStub{}
	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: repo,
		Audit:      audit,
		Clock: func() time.Time {
			return now
		},
		IDGenerator: func() string { return "PROMO123" },
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	promo, err := svc.CreatePromotion(context.Background(), UpsertPromotionCommand{
		ActorID: "staff",
		Promotion: Promotion{
			Code:         "spring-15",
			Kind:         "percent",
			Value:        15,
			StartsAt:     now.Add(time.Minute),
			EndsAt:       now.Add(2 * time.Hour),
			LimitPerUser: 1,
		},
	})
	if err != nil {
		t.Fatalf("CreatePromotion returned error: %v", err)
	}
	if promo.ID != "PROMO123" {
		t.Fatalf("expected generated id, got %s", promo.ID)
	}
	if inserted.Code != "SPRING-15" {
		t.Fatalf("expected normalized code, got %s", inserted.Code)
	}
	if audit.last.Action != "marketing.promotion.create" {
		t.Fatalf("expected audit record for create")
	}
}

func TestPromotionService_CreatePromotion_InvalidInput(t *testing.T) {
	repo := &stubPromotionRepository{}
	svc, err := NewPromotionService(PromotionServiceDeps{Promotions: repo})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	_, err = svc.CreatePromotion(context.Background(), UpsertPromotionCommand{
		ActorID: "staff",
		Promotion: Promotion{
			Kind:         "percent",
			Value:        10,
			LimitPerUser: 1,
		},
	})
	if !errors.Is(err, ErrPromotionInvalidInput) {
		t.Fatalf("expected ErrPromotionInvalidInput, got %v", err)
	}
}

func TestPromotionService_UpdatePromotion_ImmutableWithoutOverride(t *testing.T) {
	now := time.Date(2024, time.May, 2, 8, 0, 0, 0, time.UTC)
	repo := &stubPromotionRepository{
		getFn: func(context.Context, string) (domain.Promotion, error) {
			return domain.Promotion{
				ID:           "promo1",
				Code:         "LOCKED",
				Kind:         "percent",
				Value:        10,
				Currency:     "",
				LimitPerUser: 1,
				StartsAt:     now.Add(-time.Hour),
				EndsAt:       now.Add(time.Hour),
			}, nil
		},
		updateFn: func(context.Context, domain.Promotion) error {
			t.Fatalf("update should not be called when immutable fields change without override")
			return nil
		},
	}
	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: repo,
		Clock: func() time.Time {
			return now
		},
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	_, err = svc.UpdatePromotion(context.Background(), UpsertPromotionCommand{
		ActorID: "staff",
		Promotion: Promotion{
			ID:           "promo1",
			Code:         "LOCKED",
			Kind:         "percent",
			Value:        20,
			LimitPerUser: 1,
			StartsAt:     now.Add(-time.Hour),
			EndsAt:       now.Add(time.Hour),
		},
	})
	if !errors.Is(err, ErrPromotionImmutableChange) {
		t.Fatalf("expected ErrPromotionImmutableChange, got %v", err)
	}
}

func TestPromotionService_UpdatePromotion_AllowsOverride(t *testing.T) {
	now := time.Date(2024, time.May, 2, 8, 0, 0, 0, time.UTC)
	var updated domain.Promotion
	repo := &stubPromotionRepository{
		getFn: func(context.Context, string) (domain.Promotion, error) {
			return domain.Promotion{
				ID:           "promo1",
				Code:         "LOCKED",
				Kind:         "percent",
				Value:        10,
				LimitPerUser: 1,
				StartsAt:     now.Add(-time.Hour),
				EndsAt:       now.Add(time.Hour),
			}, nil
		},
		updateFn: func(_ context.Context, promo domain.Promotion) error {
			updated = promo
			return nil
		},
	}
	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: repo,
		Clock: func() time.Time {
			return now
		},
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	promo, err := svc.UpdatePromotion(context.Background(), UpsertPromotionCommand{
		ActorID:               "staff",
		AllowImmutableUpdates: true,
		Promotion: Promotion{
			ID:           "promo1",
			Code:         "LOCKED",
			Kind:         "percent",
			Value:        20,
			LimitPerUser: 1,
			StartsAt:     now.Add(-time.Hour),
			EndsAt:       now.Add(time.Hour),
		},
	})
	if err != nil {
		t.Fatalf("UpdatePromotion returned error: %v", err)
	}
	if updated.Value != 20 || promo.Value != 20 {
		t.Fatalf("expected value to update with override")
	}
}

func TestPromotionService_ListPromotions_NormalizesFilters(t *testing.T) {
	var captured repositories.PromotionListFilter
	repo := &stubPromotionRepository{
		listFn: func(_ context.Context, filter repositories.PromotionListFilter) (domain.CursorPage[domain.Promotion], error) {
			captured = filter
			return domain.CursorPage[domain.Promotion]{Items: []domain.Promotion{{ID: "promo"}}}, nil
		},
	}
	svc, err := NewPromotionService(PromotionServiceDeps{Promotions: repo})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	activeOn := time.Now()
	_, err = svc.ListPromotions(context.Background(), PromotionListFilter{
		Status:   []string{"ACTIVE", "draft"},
		Kinds:    []string{"PERCENT"},
		ActiveOn: &activeOn,
		Pagination: Pagination{
			PageSize:  999,
			PageToken: " token ",
		},
	})
	if err != nil {
		t.Fatalf("ListPromotions returned error: %v", err)
	}
	if captured.Pagination.PageSize != maxPromotionPageSize {
		t.Fatalf("expected page size to clamp, got %d", captured.Pagination.PageSize)
	}
	if len(captured.Status) != 2 || captured.Status[0] != "active" {
		t.Fatalf("expected normalized statuses, got %v", captured.Status)
	}
	if len(captured.Kinds) != 1 || captured.Kinds[0] != "percent" {
		t.Fatalf("expected normalized kinds, got %v", captured.Kinds)
	}
	if captured.ActiveOn == nil || captured.ActiveOn.Location() != time.UTC {
		t.Fatalf("expected activeOn to be set and normalized to UTC")
	}
}

func TestPromotionService_DeletePromotion_RequiresActor(t *testing.T) {
	repo := &stubPromotionRepository{}
	svc, err := NewPromotionService(PromotionServiceDeps{Promotions: repo})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}
	if err := svc.DeletePromotion(context.Background(), "promo", ""); !errors.Is(err, ErrPromotionInvalidInput) {
		t.Fatalf("expected ErrPromotionInvalidInput, got %v", err)
	}
}

func TestPromotionService_DeletePromotion_Success(t *testing.T) {
	var deleted string
	repo := &stubPromotionRepository{
		getFn: func(context.Context, string) (domain.Promotion, error) {
			return domain.Promotion{ID: "promo", Code: "SALE"}, nil
		},
		deleteFn: func(_ context.Context, id string) error {
			deleted = id
			return nil
		},
	}
	audit := &promotionAuditLogStub{}
	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: repo,
		Audit:      audit,
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	if err := svc.DeletePromotion(context.Background(), "promo", "admin"); err != nil {
		t.Fatalf("DeletePromotion returned error: %v", err)
	}
	if deleted != "promo" {
		t.Fatalf("expected promotion to be deleted")
	}
	if audit.last.Action != "marketing.promotion.delete" {
		t.Fatalf("expected audit log entry for deletion")
	}
}

type stubPromotionRepository struct {
	promotion    domain.Promotion
	lastCode     string
	insertFn     func(context.Context, domain.Promotion) error
	updateFn     func(context.Context, domain.Promotion) error
	deleteFn     func(context.Context, string) error
	getFn        func(context.Context, string) (domain.Promotion, error)
	findByCodeFn func(context.Context, string) (domain.Promotion, error)
	listFn       func(context.Context, repositories.PromotionListFilter) (domain.CursorPage[domain.Promotion], error)
}

func (s *stubPromotionRepository) Insert(ctx context.Context, promotion domain.Promotion) error {
	if s.insertFn != nil {
		return s.insertFn(ctx, promotion)
	}
	return nil
}

func (s *stubPromotionRepository) Update(ctx context.Context, promotion domain.Promotion) error {
	if s.updateFn != nil {
		return s.updateFn(ctx, promotion)
	}
	return nil
}

func (s *stubPromotionRepository) Delete(ctx context.Context, id string) error {
	if s.deleteFn != nil {
		return s.deleteFn(ctx, id)
	}
	return nil
}

func (s *stubPromotionRepository) Get(ctx context.Context, id string) (domain.Promotion, error) {
	if s.getFn != nil {
		return s.getFn(ctx, id)
	}
	return domain.Promotion{}, nil
}

func (s *stubPromotionRepository) FindByCode(ctx context.Context, code string) (domain.Promotion, error) {
	s.lastCode = code
	if s.findByCodeFn != nil {
		return s.findByCodeFn(ctx, code)
	}
	return s.promotion, nil
}

func (s *stubPromotionRepository) List(ctx context.Context, filter repositories.PromotionListFilter) (domain.CursorPage[domain.Promotion], error) {
	if s.listFn != nil {
		return s.listFn(ctx, filter)
	}
	return domain.CursorPage[domain.Promotion]{}, nil
}

type stubPromotionRepoError struct {
	notFound    bool
	conflict    bool
	unavailable bool
}

func (e *stubPromotionRepoError) Error() string {
	return "promotion repo error"
}

func (e *stubPromotionRepoError) IsNotFound() bool    { return e.notFound }
func (e *stubPromotionRepoError) IsConflict() bool    { return e.conflict }
func (e *stubPromotionRepoError) IsUnavailable() bool { return e.unavailable }

type promotionAuditLogStub struct {
	last AuditLogRecord
}

func (s *promotionAuditLogStub) Record(_ context.Context, record AuditLogRecord) {
	s.last = record
}

func (s *promotionAuditLogStub) List(context.Context, AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	return domain.CursorPage[domain.AuditLogEntry]{}, nil
}
