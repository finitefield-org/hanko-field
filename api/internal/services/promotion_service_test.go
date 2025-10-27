package services

import (
	"context"
	"errors"
	"fmt"
	"strings"
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

func TestPromotionService_ValidatePromotionDefinition_Success(t *testing.T) {
	repo := &stubPromotionRepository{}
	svc, err := NewPromotionService(PromotionServiceDeps{Promotions: repo})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	now := time.Date(2024, time.January, 1, 0, 0, 0, 0, time.UTC)
	result, err := svc.ValidatePromotionDefinition(context.Background(), Promotion{
		Code:         "spring",
		Kind:         "percent",
		Value:        10,
		StartsAt:     now,
		EndsAt:       now.Add(24 * time.Hour),
		LimitPerUser: 1,
		EligibleAudiences: []string{
			" vip ", "vip",
		},
	})
	if err != nil {
		t.Fatalf("ValidatePromotionDefinition returned error: %v", err)
	}
	if !result.Valid {
		t.Fatalf("expected validation to succeed, got %#v", result.Checks)
	}
	if len(result.Checks) == 0 {
		t.Fatalf("expected validation checks to be returned")
	}
	for _, check := range result.Checks {
		if !check.Passed {
			t.Fatalf("expected all checks to pass, got %#v", result.Checks)
		}
	}
	if result.Normalized.Code != "SPRING" {
		t.Fatalf("expected normalized code to be uppercased, got %s", result.Normalized.Code)
	}
	if len(result.Normalized.EligibleAudiences) != 1 || result.Normalized.EligibleAudiences[0] != "vip" {
		t.Fatalf("expected audiences to be normalized, got %#v", result.Normalized.EligibleAudiences)
	}
}

func TestPromotionService_ValidatePromotionDefinition_IssuesReported(t *testing.T) {
	repo := &stubPromotionRepository{}
	svc, err := NewPromotionService(PromotionServiceDeps{Promotions: repo})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	audiences := make([]string, maxPromotionAudienceEntries+1)
	for i := range audiences {
		audiences[i] = fmt.Sprintf("group-%d", i)
	}
	maxStack := 2
	result, err := svc.ValidatePromotionDefinition(context.Background(), Promotion{
		Code:              "bad code",
		Kind:              "fixed",
		Value:             0,
		Currency:          "",
		LimitPerUser:      0,
		UsageLimit:        -1,
		UsageCount:        5,
		StartsAt:          time.Time{},
		EndsAt:            time.Time{},
		EligibleAudiences: audiences,
		Stacking: PromotionStacking{
			Combinable: false,
			MaxStack:   &maxStack,
		},
		Conditions: PromotionConditions{
			MinSubtotal: int64Ptr(-1),
			CountryIn:   []string{"ZZ"},
		},
	})
	if err != nil {
		t.Fatalf("ValidatePromotionDefinition returned error: %v", err)
	}
	if result.Valid {
		t.Fatalf("expected validation to fail")
	}

	var scheduleCheck, structureCheck, limitsCheck, stackingCheck, audienceCheck *PromotionValidationCheck
	for idx := range result.Checks {
		check := &result.Checks[idx]
		switch check.Constraint {
		case PromotionConstraintSchedule:
			scheduleCheck = check
		case PromotionConstraintStructure:
			structureCheck = check
		case PromotionConstraintLimits:
			limitsCheck = check
		case PromotionConstraintStacking:
			stackingCheck = check
		case PromotionConstraintAudience:
			audienceCheck = check
		}
	}
	if scheduleCheck == nil || scheduleCheck.Passed {
		t.Fatalf("expected schedule check to fail: %#v", result.Checks)
	}
	if structureCheck == nil || structureCheck.Passed {
		t.Fatalf("expected structure check to fail: %#v", result.Checks)
	}
	if limitsCheck == nil || limitsCheck.Passed {
		t.Fatalf("expected limits check to fail: %#v", result.Checks)
	}
	if stackingCheck == nil || stackingCheck.Passed {
		t.Fatalf("expected stacking check to fail: %#v", result.Checks)
	}
	if audienceCheck == nil || audienceCheck.Passed {
		t.Fatalf("expected audience check to fail: %#v", result.Checks)
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

func TestPromotionService_UpdatePromotion_CanClearUsageLimit(t *testing.T) {
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
				UsageLimit:   25,
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

	result, err := svc.UpdatePromotion(context.Background(), UpsertPromotionCommand{
		ActorID:       "staff",
		UsageLimitSet: true,
		Promotion: Promotion{
			ID:           "promo1",
			Code:         "LOCKED",
			Kind:         "percent",
			Value:        10,
			LimitPerUser: 1,
			StartsAt:     now.Add(-time.Hour),
			EndsAt:       now.Add(time.Hour),
			UsageLimit:   0,
		},
	})
	if err != nil {
		t.Fatalf("UpdatePromotion returned error: %v", err)
	}
	if result.UsageLimit != 0 {
		t.Fatalf("expected usage limit to clear, got %d", result.UsageLimit)
	}
	if updated.UsageLimit != 0 {
		t.Fatalf("expected repository update to receive cleared usage limit")
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

func TestPromotionService_ListPromotionUsage_NormalizesFilter(t *testing.T) {
	var captured repositories.PromotionUsageListQuery
	usageRepo := &stubPromotionUsageRepository{
		listFn: func(ctx context.Context, query repositories.PromotionUsageListQuery) (domain.CursorPage[domain.PromotionUsage], error) {
			captured = query
			return domain.CursorPage[domain.PromotionUsage]{}, nil
		},
	}
	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: &stubPromotionRepository{},
		Usage:      usageRepo,
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	_, err = svc.ListPromotionUsage(context.Background(), PromotionUsageFilter{
		PromotionID: " promo-usage ",
		MinTimes:    -5,
		Pagination: Pagination{
			PageSize:  9999,
			PageToken: " token ",
		},
	})
	if err != nil {
		t.Fatalf("ListPromotionUsage returned error: %v", err)
	}
	if captured.PromotionID != "promo-usage" {
		t.Fatalf("expected promotion id to trim, got %q", captured.PromotionID)
	}
	if captured.MinTimes != 0 {
		t.Fatalf("expected min times to clamp to zero, got %d", captured.MinTimes)
	}
	if captured.Pagination.PageSize != maxPromotionUsagePageSize {
		t.Fatalf("expected page size to clamp to %d, got %d", maxPromotionUsagePageSize, captured.Pagination.PageSize)
	}
	if captured.Pagination.PageToken != "token" {
		t.Fatalf("expected page token trimmed, got %q", captured.Pagination.PageToken)
	}
	if captured.SortBy != repositories.PromotionUsageSortLastUsed {
		t.Fatalf("expected default sort by lastUsedAt, got %q", captured.SortBy)
	}
	if !captured.SortDesc {
		t.Fatalf("expected default sort order descending")
	}
}

func TestPromotionService_ListPromotionUsage_EnrichesUsers(t *testing.T) {
	lastUsed := time.Date(2024, time.May, 1, 12, 30, 0, 0, time.FixedZone("JST", 9*60*60))
	firstUsed := lastUsed.Add(-48 * time.Hour)
	usageRepo := &stubPromotionUsageRepository{
		listFn: func(ctx context.Context, query repositories.PromotionUsageListQuery) (domain.CursorPage[domain.PromotionUsage], error) {
			return domain.CursorPage[domain.PromotionUsage]{
				Items: []domain.PromotionUsage{{
					UserID:    " user-123 ",
					Times:     3,
					LastUsed:  lastUsed,
					FirstUsed: &firstUsed,
					OrderRefs: []string{" /orders/abc123 "},
					Blocked:   true,
					Notes:     " Flagged ",
				}},
			}, nil
		},
	}
	userSvc := &stubUserService{
		getFn: func(ctx context.Context, userID string) (UserProfile, error) {
			return UserProfile{
				ID:          userID,
				Email:       userID + "@example.com",
				DisplayName: "Promotion Tester",
			}, nil
		},
	}

	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions:         &stubPromotionRepository{},
		Usage:              usageRepo,
		Users:              userSvc,
		UserLookupInterval: time.Nanosecond,
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	page, err := svc.ListPromotionUsage(context.Background(), PromotionUsageFilter{PromotionID: "promo1"})
	if err != nil {
		t.Fatalf("ListPromotionUsage returned error: %v", err)
	}
	if len(page.Items) != 1 {
		t.Fatalf("expected one usage record, got %d", len(page.Items))
	}
	record := page.Items[0]
	if record.User.Email != "user-123@example.com" {
		t.Fatalf("expected email enrichment, got %q", record.User.Email)
	}
	if record.User.DisplayName != "Promotion Tester" {
		t.Fatalf("expected display name enrichment")
	}
	if record.Usage.UserID != "user-123" {
		t.Fatalf("expected user id trimmed, got %q", record.Usage.UserID)
	}
	if record.Usage.Times != 3 {
		t.Fatalf("expected usage times 3, got %d", record.Usage.Times)
	}
	if !record.Usage.LastUsed.Equal(lastUsed.UTC()) {
		t.Fatalf("expected last used normalized to UTC, got %s", record.Usage.LastUsed)
	}
	if record.Usage.FirstUsed == nil || !record.Usage.FirstUsed.Equal(firstUsed.UTC()) {
		t.Fatalf("expected first used pointer normalized to UTC")
	}
	if len(record.Usage.OrderRefs) != 1 || record.Usage.OrderRefs[0] != "/orders/abc123" {
		t.Fatalf("expected order refs trimmed, got %v", record.Usage.OrderRefs)
	}
	if !record.Usage.Blocked {
		t.Fatalf("expected blocked flag to propagate")
	}
	if strings.TrimSpace(record.Usage.Notes) != "Flagged" {
		t.Fatalf("expected notes trimmed, got %q", record.Usage.Notes)
	}
}

func TestPromotionService_ListPromotionUsage_InvalidToken(t *testing.T) {
	usageRepo := &stubPromotionUsageRepository{
		listFn: func(ctx context.Context, query repositories.PromotionUsageListQuery) (domain.CursorPage[domain.PromotionUsage], error) {
			return domain.CursorPage[domain.PromotionUsage]{}, fmt.Errorf("%w", repositories.ErrPromotionUsageInvalidPageToken)
		},
	}

	svc, err := NewPromotionService(PromotionServiceDeps{
		Promotions: &stubPromotionRepository{},
		Usage:      usageRepo,
	})
	if err != nil {
		t.Fatalf("NewPromotionService: %v", err)
	}

	_, err = svc.ListPromotionUsage(context.Background(), PromotionUsageFilter{PromotionID: "promo"})
	if err == nil {
		t.Fatalf("expected error for invalid token")
	}
	if !errors.Is(err, ErrPromotionInvalidInput) {
		t.Fatalf("expected ErrPromotionInvalidInput, got %v", err)
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

func int64Ptr(v int64) *int64 {
	return &v
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

type stubPromotionUsageRepository struct {
	listFn func(context.Context, repositories.PromotionUsageListQuery) (domain.CursorPage[domain.PromotionUsage], error)
}

func (s *stubPromotionUsageRepository) IncrementUsage(context.Context, string, string, time.Time) (domain.PromotionUsage, error) {
	return domain.PromotionUsage{}, nil
}

func (s *stubPromotionUsageRepository) RemoveUsage(context.Context, string, string) error {
	return nil
}

func (s *stubPromotionUsageRepository) ListUsage(ctx context.Context, query repositories.PromotionUsageListQuery) (domain.CursorPage[domain.PromotionUsage], error) {
	if s.listFn != nil {
		return s.listFn(ctx, query)
	}
	return domain.CursorPage[domain.PromotionUsage]{}, nil
}

type stubUserService struct {
	getFn func(context.Context, string) (UserProfile, error)
}

func (s *stubUserService) GetProfile(ctx context.Context, userID string) (UserProfile, error) {
	return s.GetByUID(ctx, userID)
}

func (s *stubUserService) GetByUID(ctx context.Context, userID string) (UserProfile, error) {
	if s.getFn != nil {
		return s.getFn(ctx, strings.TrimSpace(userID))
	}
	return UserProfile{}, nil
}

func (s *stubUserService) UpdateProfile(context.Context, UpdateProfileCommand) (UserProfile, error) {
	return UserProfile{}, nil
}

func (s *stubUserService) MaskProfile(context.Context, MaskProfileCommand) (UserProfile, error) {
	return UserProfile{}, nil
}

func (s *stubUserService) SetUserActive(context.Context, SetUserActiveCommand) (UserProfile, error) {
	return UserProfile{}, nil
}

func (s *stubUserService) ListAddresses(context.Context, string) ([]Address, error) {
	return nil, nil
}

func (s *stubUserService) UpsertAddress(context.Context, UpsertAddressCommand) (Address, error) {
	return Address{}, nil
}

func (s *stubUserService) DeleteAddress(context.Context, DeleteAddressCommand) error {
	return nil
}

func (s *stubUserService) ListPaymentMethods(context.Context, string) ([]PaymentMethod, error) {
	return nil, nil
}

func (s *stubUserService) AddPaymentMethod(context.Context, AddPaymentMethodCommand) (PaymentMethod, error) {
	return PaymentMethod{}, nil
}

func (s *stubUserService) RemovePaymentMethod(context.Context, RemovePaymentMethodCommand) error {
	return nil
}

func (s *stubUserService) ListFavorites(context.Context, string, Pagination) (domain.CursorPage[FavoriteDesign], error) {
	return domain.CursorPage[FavoriteDesign]{}, nil
}

func (s *stubUserService) ToggleFavorite(context.Context, ToggleFavoriteCommand) error {
	return nil
}
