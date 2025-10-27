package services

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/oklog/ulid/v2"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

const (
	defaultPromotionPageSize        = 25
	maxPromotionPageSize            = 100
	defaultPromotionUsagePageSize   = 50
	maxPromotionUsagePageSize       = 200
	defaultUsageLookupInterval      = 75 * time.Millisecond
	maxPromotionAudienceEntries     = 20
	maxPromotionConditionEntries    = 50
	promotionCodeMinLength          = 3
	promotionCodeMaxLength          = 64
	promotionAuditActorType         = "staff"
	promotionAuditTargetPrefix      = "/promotions/"
	promotionStatusActive           = "active"
	promotionStatusDraft            = "draft"
	promotionStatusArchived         = "archived"
	promotionKindPercent            = "percent"
	promotionKindFixed              = "fixed"
	promotionImmutableErrorTemplate = "immutable fields cannot change after start; use override to force changes"
)

var (
	promotionCodePattern    = regexp.MustCompile(`^[A-Z0-9][A-Z0-9_-]{2,63}$`)
	productReferencePattern = regexp.MustCompile(`^/products/[^/]+$`)
	materialReferencePtrn   = regexp.MustCompile(`^/materials/[^/]+$`)
	countryCodePattern      = regexp.MustCompile(`^[A-Za-z]{2}$`)
	currencyCodePattern     = regexp.MustCompile(`^[A-Z]{3}$`)
	allowedPromotionShapes  = map[string]struct{}{
		"round":  {},
		"square": {},
	}
)

// PromotionServiceDeps bundles dependencies required to construct a PromotionService implementation.
type PromotionServiceDeps struct {
	Promotions         repositories.PromotionRepository
	Usage              repositories.PromotionUsageRepository
	Users              UserService
	Audit              AuditLogService
	Clock              func() time.Time
	IDGenerator        func() string
	UserLookupInterval time.Duration
}

type promotionService struct {
	repo               repositories.PromotionRepository
	usageRepo          repositories.PromotionUsageRepository
	users              UserService
	audit              AuditLogService
	clock              func() time.Time
	idGen              func() string
	userLookupInterval time.Duration
}

// NewPromotionService wires a PromotionService backed by the provided repositories.
func NewPromotionService(deps PromotionServiceDeps) (PromotionService, error) {
	if deps.Promotions == nil {
		return nil, ErrPromotionRepositoryMissing
	}
	clock := deps.Clock
	if clock == nil {
		clock = time.Now
	}
	idGen := deps.IDGenerator
	if idGen == nil {
		idGen = func() string { return ulid.Make().String() }
	}
	interval := deps.UserLookupInterval
	if interval < 0 {
		interval = 0
	}
	return &promotionService{
		repo:               deps.Promotions,
		usageRepo:          deps.Usage,
		users:              deps.Users,
		audit:              deps.Audit,
		clock:              func() time.Time { return clock().UTC() },
		idGen:              idGen,
		userLookupInterval: interval,
	}, nil
}

func (s *promotionService) GetPublicPromotion(ctx context.Context, code string) (PromotionPublic, error) {
	if s == nil || s.repo == nil {
		return PromotionPublic{}, ErrPromotionRepositoryMissing
	}

	normalized := strings.ToUpper(strings.TrimSpace(code))
	if normalized == "" {
		return PromotionPublic{}, ErrPromotionInvalidCode
	}

	promotion, err := s.repo.FindByCode(ctx, normalized)
	if err != nil {
		return PromotionPublic{}, translatePromotionRepoError(err)
	}

	promotion = normalizePromotion(promotion)
	if promotion.InternalOnly || promotion.RequiresAuth {
		return PromotionPublic{}, ErrPromotionUnavailable
	}

	now := s.clock()
	available := isPromotionAvailable(promotion, now)

	result := PromotionPublic{
		Code:              promotion.Code,
		IsAvailable:       available,
		DescriptionPublic: strings.TrimSpace(promotion.DescriptionPublic),
		EligibleAudiences: cloneStringSlice(promotion.EligibleAudiences),
	}
	if !promotion.StartsAt.IsZero() {
		result.StartsAt = promotion.StartsAt.UTC()
	}
	if !promotion.EndsAt.IsZero() {
		result.EndsAt = promotion.EndsAt.UTC()
	}
	return result, nil
}

func (s *promotionService) ValidatePromotion(context.Context, ValidatePromotionCommand) (PromotionValidationResult, error) {
	return PromotionValidationResult{}, ErrPromotionOperationUnsupported
}

func (s *promotionService) ListPromotions(ctx context.Context, filter PromotionListFilter) (domain.CursorPage[Promotion], error) {
	if s == nil || s.repo == nil {
		return domain.CursorPage[Promotion]{}, ErrPromotionRepositoryMissing
	}

	pageSize := filter.Pagination.PageSize
	switch {
	case pageSize <= 0:
		pageSize = defaultPromotionPageSize
	case pageSize > maxPromotionPageSize:
		pageSize = maxPromotionPageSize
	}

	repoFilter := repositories.PromotionListFilter{
		Status:     normalizeFilterValues(filter.Status, 10),
		Kinds:      normalizeFilterValues(filter.Kinds, 5),
		Pagination: domain.Pagination{PageSize: pageSize, PageToken: strings.TrimSpace(filter.Pagination.PageToken)},
	}
	if filter.ActiveOn != nil && !filter.ActiveOn.IsZero() {
		normalized := filter.ActiveOn.UTC()
		repoFilter.ActiveOn = &normalized
	}

	page, err := s.repo.List(ctx, repoFilter)
	if err != nil {
		return domain.CursorPage[Promotion]{}, translatePromotionRepoError(err)
	}

	for i := range page.Items {
		page.Items[i] = normalizePromotion(page.Items[i])
	}
	return page, nil
}

func (s *promotionService) CreatePromotion(ctx context.Context, cmd UpsertPromotionCommand) (Promotion, error) {
	if s == nil || s.repo == nil {
		return Promotion{}, ErrPromotionRepositoryMissing
	}

	actorID := strings.TrimSpace(cmd.ActorID)
	if actorID == "" {
		return Promotion{}, fmt.Errorf("%w: actor id is required", ErrPromotionInvalidInput)
	}

	now := s.clock()
	promotion := normalizePromotion(cmd.Promotion)
	if promotion.ID == "" {
		promotion.ID = s.idGen()
	}
	if promotion.CreatedAt.IsZero() {
		promotion.CreatedAt = now
	} else {
		promotion.CreatedAt = promotion.CreatedAt.UTC()
	}
	promotion.UpdatedAt = now
	promotion.UsageCount = 0

	if err := validatePromotionInput(promotion); err != nil {
		return Promotion{}, err
	}

	if err := s.repo.Insert(ctx, domain.Promotion(promotion)); err != nil {
		return Promotion{}, translatePromotionRepoError(err)
	}

	s.recordPromotionAudit(ctx, "marketing.promotion.create", actorID, promotion.CreatedAt, Promotion{}, promotion)
	return promotion, nil
}

func (s *promotionService) UpdatePromotion(ctx context.Context, cmd UpsertPromotionCommand) (Promotion, error) {
	if s == nil || s.repo == nil {
		return Promotion{}, ErrPromotionRepositoryMissing
	}

	actorID := strings.TrimSpace(cmd.ActorID)
	if actorID == "" {
		return Promotion{}, fmt.Errorf("%w: actor id is required", ErrPromotionInvalidInput)
	}

	promoID := strings.TrimSpace(cmd.Promotion.ID)
	if promoID == "" {
		return Promotion{}, fmt.Errorf("%w: promotion id is required", ErrPromotionInvalidInput)
	}

	existing, err := s.repo.Get(ctx, promoID)
	if err != nil {
		return Promotion{}, translatePromotionRepoError(err)
	}

	now := s.clock()
	updated := normalizePromotion(cmd.Promotion)
	updated.ID = promoID
	updated.CreatedAt = existing.CreatedAt
	if updated.UsageCount == 0 {
		updated.UsageCount = existing.UsageCount
	}
	if !cmd.UsageLimitSet {
		updated.UsageLimit = existing.UsageLimit
	}
	if updated.LimitPerUser == 0 {
		updated.LimitPerUser = existing.LimitPerUser
	}
	updated.UpdatedAt = now

	if err := ensurePromotionMutability(existing, updated, now, cmd.AllowImmutableUpdates); err != nil {
		return Promotion{}, err
	}
	if err := validatePromotionInput(updated); err != nil {
		return Promotion{}, err
	}

	if err := s.repo.Update(ctx, domain.Promotion(updated)); err != nil {
		return Promotion{}, translatePromotionRepoError(err)
	}

	s.recordPromotionAudit(ctx, "marketing.promotion.update", actorID, updated.UpdatedAt, existing, updated)
	return updated, nil
}

func (s *promotionService) DeletePromotion(ctx context.Context, promoID string, actorID string) error {
	if s == nil || s.repo == nil {
		return ErrPromotionRepositoryMissing
	}
	promoID = strings.TrimSpace(promoID)
	if promoID == "" {
		return fmt.Errorf("%w: promotion id is required", ErrPromotionInvalidInput)
	}
	actorID = strings.TrimSpace(actorID)
	if actorID == "" {
		return fmt.Errorf("%w: actor id is required", ErrPromotionInvalidInput)
	}

	existing, err := s.repo.Get(ctx, promoID)
	if err != nil {
		return translatePromotionRepoError(err)
	}

	if err := s.repo.Delete(ctx, promoID); err != nil {
		return translatePromotionRepoError(err)
	}

	s.recordPromotionAudit(ctx, "marketing.promotion.delete", actorID, s.clock(), existing, Promotion{})
	return nil
}

func (s *promotionService) ListPromotionUsage(ctx context.Context, filter PromotionUsageFilter) (PromotionUsagePage, error) {
	if s == nil || s.usageRepo == nil {
		return PromotionUsagePage{}, ErrPromotionOperationUnsupported
	}
	promoID := strings.TrimSpace(filter.PromotionID)
	if promoID == "" {
		return PromotionUsagePage{}, fmt.Errorf("%w: promotion id is required", ErrPromotionInvalidInput)
	}

	pageSize := filter.Pagination.PageSize
	switch {
	case pageSize <= 0:
		pageSize = defaultPromotionUsagePageSize
	case pageSize > maxPromotionUsagePageSize:
		pageSize = maxPromotionUsagePageSize
	}

	sortField := filter.SortBy
	if sortField == "" {
		sortField = PromotionUsageSortLastUsed
	}
	switch sortField {
	case PromotionUsageSortLastUsed, PromotionUsageSortTimes:
	default:
		return PromotionUsagePage{}, fmt.Errorf("%w: unsupported sort field %q", ErrPromotionInvalidInput, sortField)
	}

	sortOrder := filter.SortOrder
	if sortOrder != domain.SortAsc {
		sortOrder = domain.SortDesc
	}

	minTimes := filter.MinTimes
	if minTimes < 0 {
		minTimes = 0
	}

	repoFilter := repositories.PromotionUsageListQuery{
		PromotionID: promoID,
		MinTimes:    minTimes,
		Pagination: domain.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(filter.Pagination.PageToken),
		},
		SortBy:   repositories.PromotionUsageSort(sortField),
		SortDesc: sortOrder != domain.SortAsc,
	}

	page, err := s.usageRepo.ListUsage(ctx, repoFilter)
	if err != nil {
		return PromotionUsagePage{}, translatePromotionRepoError(err)
	}

	items := make([]PromotionUsageRecord, 0, len(page.Items))
	var (
		ticker   *time.Ticker
		throttle <-chan time.Time
	)
	if s.users != nil {
		if interval := s.promotionsUserLookupInterval(); interval > 0 {
			ticker = time.NewTicker(interval)
			throttle = ticker.C
			defer ticker.Stop()
		}
	}

	for idx, usage := range page.Items {
		normalized := normalizePromotionUsage(usage)
		record := PromotionUsageRecord{
			Usage: normalized,
			User: PromotionUsageUser{
				ID: normalized.UserID,
			},
		}
		if s.users != nil {
			if idx > 0 && throttle != nil {
				select {
				case <-ctx.Done():
					return PromotionUsagePage{}, ctx.Err()
				case <-throttle:
				}
			}
			profile, err := s.users.GetByUID(ctx, normalized.UserID)
			if err != nil {
				if !isPromotionRepoNotFound(err) {
					return PromotionUsagePage{}, err
				}
			} else {
				record.User.Email = strings.TrimSpace(profile.Email)
				record.User.DisplayName = strings.TrimSpace(profile.DisplayName)
				if record.User.ID == "" {
					record.User.ID = strings.TrimSpace(profile.ID)
				}
			}
		}
		items = append(items, record)
	}

	return PromotionUsagePage{
		Items:         items,
		NextPageToken: page.NextPageToken,
	}, nil
}

func (s *promotionService) recordPromotionAudit(ctx context.Context, action string, actorID string, occurred time.Time, before, after Promotion) {
	if s.audit == nil {
		return
	}
	targetID := strings.TrimSpace(after.ID)
	if targetID == "" {
		targetID = strings.TrimSpace(before.ID)
	}
	targetRef := ""
	if targetID != "" {
		targetRef = promotionAuditTargetPrefix + targetID
	}
	metadata := map[string]any{}
	if code := strings.TrimSpace(after.Code); code != "" {
		metadata["code"] = code
	} else if code := strings.TrimSpace(before.Code); code != "" {
		metadata["code"] = code
	}

	diff := buildPromotionDiff(before, after)
	record := AuditLogRecord{
		Actor:      actorID,
		ActorType:  promotionAuditActorType,
		Action:     action,
		TargetRef:  targetRef,
		Metadata:   metadata,
		Diff:       diff,
		OccurredAt: occurred,
	}
	s.audit.Record(ctx, record)
}

func (s *promotionService) promotionsUserLookupInterval() time.Duration {
	if s == nil {
		return 0
	}
	interval := s.userLookupInterval
	if interval <= 0 {
		return defaultUsageLookupInterval
	}
	return interval
}

func normalizePromotionUsage(usage domain.PromotionUsage) PromotionUsage {
	normalized := PromotionUsage{
		UserID:    strings.TrimSpace(usage.UserID),
		Times:     usage.Times,
		OrderRefs: cloneStringSlice(usage.OrderRefs),
		Blocked:   usage.Blocked,
		Notes:     strings.TrimSpace(usage.Notes),
	}
	if normalized.Times < 0 {
		normalized.Times = 0
	}
	if !usage.LastUsed.IsZero() {
		normalized.LastUsed = usage.LastUsed.UTC()
	}
	if usage.FirstUsed != nil && !usage.FirstUsed.IsZero() {
		first := usage.FirstUsed.UTC()
		normalized.FirstUsed = &first
	}
	return normalized
}

func cloneStringSlice(in []string) []string {
	if len(in) == 0 {
		return nil
	}
	out := make([]string, len(in))
	for i, item := range in {
		out[i] = strings.TrimSpace(item)
	}
	return out
}

func isPromotionRepoNotFound(err error) bool {
	if err == nil {
		return false
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		return repoErr.IsNotFound()
	}
	return false
}

func normalizePromotion(p Promotion) Promotion {
	p.ID = strings.TrimSpace(p.ID)
	p.Code = strings.ToUpper(strings.TrimSpace(p.Code))
	p.Name = strings.TrimSpace(p.Name)
	p.Description = strings.TrimSpace(p.Description)
	p.DescriptionPublic = strings.TrimSpace(p.DescriptionPublic)
	p.Notes = strings.TrimSpace(p.Notes)
	p.Kind = normalizePromotionKind(p.Kind)
	p.Currency = strings.ToUpper(strings.TrimSpace(p.Currency))
	p.Status, p.IsActive = normalizePromotionStatusValue(p.Status, p.IsActive)
	p.Metadata = normalizeMap(p.Metadata)
	p.EligibleAudiences = normalizePromotionSlice(p.EligibleAudiences, maxPromotionAudienceEntries)
	p.Stacking = normalizePromotionStacking(p.Stacking)
	p.Conditions = normalizePromotionConditions(p.Conditions)
	p.InternalOnly = p.InternalOnly
	p.RequiresAuth = p.RequiresAuth
	p.StartsAt = p.StartsAt.UTC()
	p.EndsAt = p.EndsAt.UTC()
	p.CreatedAt = p.CreatedAt.UTC()
	if !p.UpdatedAt.IsZero() {
		p.UpdatedAt = p.UpdatedAt.UTC()
	}
	return p
}

func normalizePromotionKind(kind string) string {
	switch strings.ToLower(strings.TrimSpace(kind)) {
	case promotionKindFixed:
		return promotionKindFixed
	default:
		return promotionKindPercent
	}
}

func normalizePromotionStatusValue(status string, isActive bool) (string, bool) {
	normalized := strings.ToLower(strings.TrimSpace(status))
	switch normalized {
	case promotionStatusActive:
		return promotionStatusActive, true
	case promotionStatusArchived:
		return promotionStatusArchived, false
	case promotionStatusDraft:
		return promotionStatusDraft, false
	case "":
		if isActive {
			return promotionStatusActive, true
		}
		return promotionStatusDraft, false
	default:
		if isActive {
			return promotionStatusActive, true
		}
		return normalized, false
	}
}

func normalizePromotionStacking(stacking domain.PromotionStacking) domain.PromotionStacking {
	if stacking.MaxStack != nil {
		value := *stacking.MaxStack
		if value <= 0 {
			stacking.MaxStack = nil
		} else {
			clamped := value
			stacking.MaxStack = &clamped
		}
	}
	return stacking
}

func normalizePromotionConditions(c domain.PromotionConditions) domain.PromotionConditions {
	c.CountryIn = normalizePromotionUpperSlice(c.CountryIn, maxPromotionConditionEntries)
	c.CurrencyIn = normalizePromotionUpperSlice(c.CurrencyIn, maxPromotionConditionEntries)
	c.ShapeIn = normalizePromotionSlice(c.ShapeIn, maxPromotionConditionEntries)
	c.ProductRefsIn = normalizePromotionSlice(c.ProductRefsIn, maxPromotionConditionEntries)
	c.MaterialRefsIn = normalizePromotionSlice(c.MaterialRefsIn, maxPromotionConditionEntries)
	if c.SizeMMBetween != nil {
		size := *c.SizeMMBetween
		c.SizeMMBetween = &size
	}
	if c.NewCustomerOnly != nil {
		value := *c.NewCustomerOnly
		c.NewCustomerOnly = &value
	}
	return c
}

func normalizeFilterValues(values []string, limit int) []string {
	trimmed := normalizePromotionSlice(values, limit)
	result := make([]string, 0, len(trimmed))
	seen := make(map[string]struct{}, len(trimmed))
	for _, value := range trimmed {
		normalized := strings.ToLower(value)
		if normalized == "" {
			continue
		}
		if _, ok := seen[normalized]; ok {
			continue
		}
		seen[normalized] = struct{}{}
		result = append(result, normalized)
	}
	return result
}

func normalizePromotionSlice(values []string, limit int) []string {
	if len(values) == 0 {
		return nil
	}
	result := make([]string, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
		if limit > 0 && len(result) >= limit {
			break
		}
	}
	sort.Strings(result)
	return result
}

func normalizePromotionUpperSlice(values []string, limit int) []string {
	normalized := make([]string, 0, len(values))
	for _, value := range values {
		trimmed := strings.ToUpper(strings.TrimSpace(value))
		if trimmed == "" {
			continue
		}
		normalized = append(normalized, trimmed)
	}
	return normalizePromotionSlice(normalized, limit)
}

func normalizeMap(in map[string]any) map[string]any {
	if len(in) == 0 {
		return nil
	}
	result := make(map[string]any, len(in))
	for k, v := range in {
		key := strings.TrimSpace(k)
		if key == "" {
			continue
		}
		result[key] = v
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func validatePromotionInput(p Promotion) error {
	var problems []string

	if p.Code == "" {
		problems = append(problems, "code is required")
	} else if len(p.Code) < promotionCodeMinLength || len(p.Code) > promotionCodeMaxLength || !promotionCodePattern.MatchString(p.Code) {
		problems = append(problems, "code must be 3-64 characters [A-Z0-9_-]")
	}

	switch p.Kind {
	case promotionKindPercent, promotionKindFixed:
	default:
		problems = append(problems, "kind must be percent or fixed")
	}

	if p.Value <= 0 {
		problems = append(problems, "value must be greater than zero")
	} else if p.Kind == promotionKindPercent && p.Value > 100 {
		problems = append(problems, "percent discounts cannot exceed 100")
	}

	if p.Kind == promotionKindFixed {
		if p.Currency == "" || !currencyCodePattern.MatchString(p.Currency) {
			problems = append(problems, "currency must be ISO-4217 for fixed discounts")
		}
	} else if p.Currency != "" {
		problems = append(problems, "do not supply currency for percent discounts")
	}

	if p.StartsAt.IsZero() {
		problems = append(problems, "startsAt is required")
	}
	if p.EndsAt.IsZero() {
		problems = append(problems, "endsAt is required")
	} else if !p.StartsAt.IsZero() && !p.EndsAt.After(p.StartsAt) {
		problems = append(problems, "endsAt must be after startsAt")
	}

	if p.LimitPerUser < 1 {
		problems = append(problems, "limitPerUser must be at least 1")
	}
	if p.UsageLimit < 0 {
		problems = append(problems, "usageLimit cannot be negative")
	}
	if p.UsageLimit > 0 && p.UsageCount > p.UsageLimit {
		problems = append(problems, "usageCount exceeds usageLimit")
	}

	if p.Conditions.MinSubtotal != nil && *p.Conditions.MinSubtotal < 0 {
		problems = append(problems, "conditions.minSubtotal cannot be negative")
	}
	if p.Conditions.SizeMMBetween != nil {
		min := p.Conditions.SizeMMBetween.Min
		max := p.Conditions.SizeMMBetween.Max
		if min != nil && *min < 0 {
			problems = append(problems, "conditions.sizeMmBetween.min cannot be negative")
		}
		if max != nil && *max < 0 {
			problems = append(problems, "conditions.sizeMmBetween.max cannot be negative")
		}
		if min != nil && max != nil && *max < *min {
			problems = append(problems, "conditions.sizeMmBetween.max must be >= min")
		}
	}
	for _, country := range p.Conditions.CountryIn {
		if !countryCodePattern.MatchString(country) {
			problems = append(problems, fmt.Sprintf("invalid country code %s", country))
		}
	}
	for _, currency := range p.Conditions.CurrencyIn {
		if !currencyCodePattern.MatchString(currency) {
			problems = append(problems, fmt.Sprintf("invalid currency code %s", currency))
		}
	}
	for _, shape := range p.Conditions.ShapeIn {
		if _, ok := allowedPromotionShapes[strings.ToLower(shape)]; !ok {
			problems = append(problems, fmt.Sprintf("invalid shape %s", shape))
		}
	}
	for _, ref := range p.Conditions.ProductRefsIn {
		if !productReferencePattern.MatchString(ref) {
			problems = append(problems, fmt.Sprintf("invalid product reference %s", ref))
		}
	}
	for _, ref := range p.Conditions.MaterialRefsIn {
		if !materialReferencePtrn.MatchString(ref) {
			problems = append(problems, fmt.Sprintf("invalid material reference %s", ref))
		}
	}

	if len(problems) > 0 {
		return fmt.Errorf("%w: %s", ErrPromotionInvalidInput, strings.Join(problems, "; "))
	}
	return nil
}

func ensurePromotionMutability(existing, updated Promotion, now time.Time, override bool) error {
	started := !existing.StartsAt.IsZero() && (now.Equal(existing.StartsAt) || now.After(existing.StartsAt))
	if !started || override {
		return nil
	}

	immutableChanged := false
	if !strings.EqualFold(existing.Code, updated.Code) {
		immutableChanged = true
	}
	if existing.Kind != updated.Kind || existing.Value != updated.Value || existing.Currency != updated.Currency {
		immutableChanged = true
	}
	if existing.LimitPerUser != updated.LimitPerUser {
		immutableChanged = true
	}
	if !existing.StartsAt.Equal(updated.StartsAt) {
		immutableChanged = true
	}

	if immutableChanged {
		return fmt.Errorf("%w: %s", ErrPromotionImmutableChange, promotionImmutableErrorTemplate)
	}
	return nil
}

func isPromotionAvailable(p Promotion, now time.Time) bool {
	active := p.IsActive || strings.EqualFold(p.Status, promotionStatusActive)
	if !active {
		return false
	}
	if !p.StartsAt.IsZero() && now.Before(p.StartsAt) {
		return false
	}
	if !p.EndsAt.IsZero() && now.After(p.EndsAt) {
		return false
	}
	return true
}

func buildPromotionDiff(before, after Promotion) map[string]AuditLogDiff {
	diff := make(map[string]AuditLogDiff)
	addDiff := func(field string, oldVal, newVal any) {
		if fmt.Sprint(oldVal) == fmt.Sprint(newVal) {
			return
		}
		diff[field] = AuditLogDiff{Before: oldVal, After: newVal}
	}

	addDiff("code", before.Code, after.Code)
	addDiff("status", before.Status, after.Status)
	addDiff("kind", before.Kind, after.Kind)
	addDiff("value", before.Value, after.Value)
	addDiff("currency", before.Currency, after.Currency)
	addDiff("startsAt", before.StartsAt, after.StartsAt)
	addDiff("endsAt", before.EndsAt, after.EndsAt)
	addDiff("usageLimit", before.UsageLimit, after.UsageLimit)
	addDiff("usageCount", before.UsageCount, after.UsageCount)
	addDiff("limitPerUser", before.LimitPerUser, after.LimitPerUser)
	addDiff("notes", before.Notes, after.Notes)
	addDiff("internalOnly", before.InternalOnly, after.InternalOnly)
	addDiff("requiresAuth", before.RequiresAuth, after.RequiresAuth)
	if !slices.Equal(before.EligibleAudiences, after.EligibleAudiences) {
		diff["eligibleAudiences"] = AuditLogDiff{Before: before.EligibleAudiences, After: after.EligibleAudiences}
	}

	if len(diff) == 0 {
		return nil
	}
	return diff
}

func translatePromotionRepoError(err error) error {
	if err == nil {
		return nil
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		switch {
		case repoErr.IsNotFound():
			return ErrPromotionNotFound
		case repoErr.IsConflict():
			return ErrPromotionConflict
		case repoErr.IsUnavailable():
			return ErrPromotionRepositoryMissing
		}
	}
	return err
}
