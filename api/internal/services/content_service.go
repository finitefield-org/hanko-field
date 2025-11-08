package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/oklog/ulid/v2"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/textutil"
	"github.com/hanko-field/api/internal/platform/validation"
	"github.com/hanko-field/api/internal/repositories"
)

const (
	defaultContentLocale     = "ja"
	defaultGuidePageSize     = 20
	maxGuidePageSize         = 60
	maxContentSlugLength     = 120
	maxContentTitleLength    = 160
	maxContentSummaryLength  = 600
	maxContentCategoryLength = 80
)

// ContentCacheInvalidator purges CDN/cache entries for content pages.
type ContentCacheInvalidator interface {
	InvalidatePages(ctx context.Context, pages []ContentCacheKey) error
}

// ContentCacheKey identifies cache entries for invalidation.
type ContentCacheKey struct {
	Slug   string
	Locale string
}

// ContentServiceDeps groups constructor parameters for the content service.
type ContentServiceDeps struct {
	Repository            repositories.ContentRepository
	Clock                 func() time.Time
	DefaultLocale         string
	Audit                 AuditLogService
	Cache                 ContentCacheInvalidator
	IDGenerator           func() string
	PreviewTokenGenerator func() (string, error)
}

type contentService struct {
	repo          repositories.ContentRepository
	clock         func() time.Time
	defaultLocale string
	audit         AuditLogService
	cache         ContentCacheInvalidator
	idGen         func() string
	tokenGen      func() (string, error)
}

// ErrContentRepositoryMissing signals that the content repository dependency is absent.
var ErrContentRepositoryMissing = errors.New("content service: content repository is not configured")

// ErrContentPageInvalid indicates invalid page payload supplied.
var ErrContentPageInvalid = errors.New("content service: invalid page input")

// ErrContentPageConflict indicates slug + locale already exists.
var ErrContentPageConflict = errors.New("content service: page conflict")

// ErrContentPageNotFound indicates the referenced page does not exist.
var ErrContentPageNotFound = errors.New("content service: page not found")

// NewContentService constructs the content service with the supplied dependencies.
func NewContentService(deps ContentServiceDeps) (ContentService, error) {
	if deps.Repository == nil {
		return nil, ErrContentRepositoryMissing
	}
	clock := deps.Clock
	if clock == nil {
		clock = time.Now
	}
	defaultLocale := strings.TrimSpace(deps.DefaultLocale)
	if defaultLocale == "" {
		defaultLocale = defaultContentLocale
	}
	idGen := deps.IDGenerator
	if idGen == nil {
		idGen = func() string { return ulid.Make().String() }
	}
	tokenGen := deps.PreviewTokenGenerator
	if tokenGen == nil {
		tokenGen = generatePreviewToken
	}
	return &contentService{
		repo:          deps.Repository,
		clock:         func() time.Time { return clock().UTC() },
		defaultLocale: normalizeLocaleValue(defaultLocale),
		audit:         deps.Audit,
		cache:         deps.Cache,
		idGen:         idGen,
		tokenGen:      tokenGen,
	}, nil
}

func (s *contentService) ListGuides(ctx context.Context, filter ContentGuideFilter) (domain.CursorPage[ContentGuide], error) {
	if s.repo == nil {
		return domain.CursorPage[ContentGuide]{}, ErrContentRepositoryMissing
	}

	requestedLocale := normalizeLocalePointer(filter.Locale)
	if requestedLocale == "" {
		requestedLocale = s.defaultLocale
	}

	fallback := normalizeLocaleValue(filter.FallbackLocale)
	if fallback == "" {
		fallback = s.defaultLocale
	}

	pageSize := filter.Pagination.PageSize
	switch {
	case pageSize <= 0:
		pageSize = defaultGuidePageSize
	case pageSize > maxGuidePageSize:
		pageSize = maxGuidePageSize
	}

	repoFilter := repositories.ContentGuideFilter{
		Category:       normalizeFilterPointer(filter.Category),
		Slug:           normalizeFilterPointer(filter.Slug),
		Locale:         pointerIfNotEmpty(requestedLocale),
		FallbackLocale: fallback,
		Status:         normalizeStatusSlice(filter.Status),
		OnlyPublished:  filter.PublishedOnly,
		Pagination: domain.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(filter.Pagination.PageToken),
		},
	}

	page, err := s.repo.ListGuides(ctx, repoFilter)
	if err != nil {
		return domain.CursorPage[ContentGuide]{}, err
	}

	result := domain.CursorPage[ContentGuide]{
		Items:         make([]ContentGuide, 0, len(page.Items)),
		NextPageToken: page.NextPageToken,
	}

	for _, guide := range page.Items {
		normalized := normalizeContentGuide(guide, requestedLocale, fallback, s.defaultLocale)
		result.Items = append(result.Items, ContentGuide(normalized))
	}

	return result, nil
}

func (s *contentService) GetGuideBySlug(ctx context.Context, slug string, locale string) (ContentGuide, error) {
	if s.repo == nil {
		return ContentGuide{}, ErrContentRepositoryMissing
	}

	slug = strings.TrimSpace(slug)
	if slug == "" {
		return ContentGuide{}, errors.New("content service: slug is required")
	}

	requested := normalizeLocaleValue(locale)
	if requested == "" {
		requested = s.defaultLocale
	}

	guide, err := s.repo.GetGuideBySlug(ctx, slug, requested)
	if err != nil && requested != s.defaultLocale && isRepositoryNotFound(err) {
		guide, err = s.repo.GetGuideBySlug(ctx, slug, s.defaultLocale)
	}
	if err != nil {
		return ContentGuide{}, err
	}

	return ContentGuide(normalizeContentGuide(guide, requested, s.defaultLocale, s.defaultLocale)), nil
}

func (s *contentService) GetGuide(ctx context.Context, guideID string) (ContentGuide, error) {
	if s.repo == nil {
		return ContentGuide{}, ErrContentRepositoryMissing
	}
	guideID = strings.TrimSpace(guideID)
	if guideID == "" {
		return ContentGuide{}, errors.New("content service: guide id is required")
	}
	guide, err := s.repo.GetGuide(ctx, guideID)
	if err != nil {
		return ContentGuide{}, err
	}
	return ContentGuide(normalizeContentGuide(guide, "", "", s.defaultLocale)), nil
}

func (s *contentService) UpsertGuide(ctx context.Context, cmd UpsertContentGuideCommand) (ContentGuide, error) {
	if s.repo == nil {
		return ContentGuide{}, ErrContentRepositoryMissing
	}

	guide := cmd.Guide
	guide.ID = strings.TrimSpace(guide.ID)
	slug, err := validation.NormalizeSlug(guide.Slug, maxContentSlugLength)
	if err != nil {
		return ContentGuide{}, fmt.Errorf("%w: %v", ErrContentPageInvalid, err)
	}
	guide.Slug = slug
	guide.Locale = normalizeLocaleValue(guide.Locale)
	guide.Category = validation.SanitizePlainText(guide.Category, maxContentCategoryLength)
	guide.Title = validation.SanitizePlainText(guide.Title, maxContentTitleLength)
	if guide.Title == "" {
		return ContentGuide{}, fmt.Errorf("%w: title is required", ErrContentPageInvalid)
	}
	guide.Summary = validation.SanitizePlainText(guide.Summary, maxContentSummaryLength)
	guide.BodyHTML = validation.SanitizeGuideHTML(guide.BodyHTML)
	guide.HeroImage = strings.TrimSpace(guide.HeroImage)
	guide.Tags = normalizeStringSlice(guide.Tags)
	guide.Status = strings.TrimSpace(guide.Status)
	if guide.Locale == "" {
		guide.Locale = s.defaultLocale
	}

	now := s.clock()
	if guide.CreatedAt.IsZero() {
		guide.CreatedAt = now
	} else {
		guide.CreatedAt = guide.CreatedAt.UTC()
	}
	guide.UpdatedAt = now
	if !guide.PublishedAt.IsZero() {
		guide.PublishedAt = guide.PublishedAt.UTC()
	}

	saved, err := s.repo.UpsertGuide(ctx, domain.ContentGuide(guide))
	if err != nil {
		return ContentGuide{}, err
	}
	return ContentGuide(normalizeContentGuide(saved, guide.Locale, "", s.defaultLocale)), nil
}

func (s *contentService) DeleteGuide(ctx context.Context, guideID string) error {
	if s.repo == nil {
		return ErrContentRepositoryMissing
	}
	guideID = strings.TrimSpace(guideID)
	if guideID == "" {
		return errors.New("content service: guide id is required")
	}
	return s.repo.DeleteGuide(ctx, guideID)
}

func (s *contentService) GetPage(ctx context.Context, slug string, locale string) (ContentPage, error) {
	if s.repo == nil {
		return ContentPage{}, ErrContentRepositoryMissing
	}
	slug = strings.TrimSpace(slug)
	if slug == "" {
		return ContentPage{}, errors.New("content service: slug is required")
	}
	locale = normalizeLocaleValue(locale)
	if locale == "" {
		locale = s.defaultLocale
	}
	page, err := s.repo.GetPage(ctx, slug, locale)
	resolvedLocale := locale
	if err != nil && locale != s.defaultLocale && isRepositoryNotFound(err) {
		page, err = s.repo.GetPage(ctx, slug, s.defaultLocale)
		resolvedLocale = s.defaultLocale
	}
	if err != nil {
		return ContentPage{}, err
	}
	return ContentPage(normalizeContentPage(page, resolvedLocale, s.defaultLocale)), nil
}

func (s *contentService) UpsertPage(ctx context.Context, cmd UpsertContentPageCommand) (ContentPage, error) {
	if s.repo == nil {
		return ContentPage{}, ErrContentRepositoryMissing
	}
	actorID := strings.TrimSpace(cmd.ActorID)
	if actorID == "" {
		return ContentPage{}, fmt.Errorf("%w: actor id is required", ErrContentPageInvalid)
	}

	page := cmd.Page
	page.ID = strings.TrimSpace(page.ID)
	slug, err := validation.NormalizeSlug(page.Slug, maxContentSlugLength)
	if err != nil {
		return ContentPage{}, fmt.Errorf("%w: %v", ErrContentPageInvalid, err)
	}
	page.Slug = slug
	page.Locale = normalizeLocaleValue(page.Locale)
	if page.Locale == "" {
		page.Locale = s.defaultLocale
	}
	page.Title = validation.SanitizePlainText(page.Title, maxContentTitleLength)
	if page.Title == "" {
		return ContentPage{}, fmt.Errorf("%w: title is required", ErrContentPageInvalid)
	}
	page.BodyHTML = validation.SanitizePageHTML(page.BodyHTML)
	status, err := normalizePageStatus(strings.TrimSpace(page.Status))
	if err != nil {
		return ContentPage{}, err
	}
	page.Status = status
	page.IsPublished = strings.EqualFold(status, "published")
	page.SEO = textutil.NormalizeStringMap(page.SEO)
	page.UpdatedAt = s.clock().UTC()

	var existing domain.ContentPage
	if page.ID != "" {
		existing, err = s.repo.GetPageByID(ctx, page.ID)
		if err != nil {
			if isRepositoryNotFound(err) {
				return ContentPage{}, ErrContentPageNotFound
			}
			return ContentPage{}, err
		}
	} else {
		page.ID = s.idGen()
	}

	if err := s.ensureUniquePage(ctx, page.Slug, page.Locale, page.ID); err != nil {
		return ContentPage{}, err
	}

	page.PreviewToken = strings.TrimSpace(existing.PreviewToken)
	if !page.IsPublished {
		needsToken := cmd.RegeneratePreviewToken || existing.PreviewToken == "" || existing.IsPublished || existing.ID == ""
		if needsToken {
			token, tokenErr := s.tokenGen()
			if tokenErr != nil {
				return ContentPage{}, fmt.Errorf("content service: generate preview token: %w", tokenErr)
			}
			page.PreviewToken = token
		}
	} else if existing.ID == "" {
		page.PreviewToken = ""
	}

	domainPage := normalizeContentPage(domain.ContentPage(page), page.Locale, s.defaultLocale)
	saved, err := s.repo.UpsertPage(ctx, domainPage)
	if err != nil {
		return ContentPage{}, err
	}

	normalized := ContentPage(normalizeContentPage(saved, page.Locale, s.defaultLocale))

	action := "content.page.create"
	if strings.TrimSpace(existing.ID) != "" {
		action = "content.page.update"
	}
	s.recordPageAudit(ctx, action, existing, domain.ContentPage(normalized), actorID)

	if existing.IsPublished != normalized.IsPublished {
		s.invalidatePages(ctx, []ContentCacheKey{{
			Slug:   normalized.Slug,
			Locale: normalized.Locale,
		}})
	}

	return normalized, nil
}

func (s *contentService) DeletePage(ctx context.Context, cmd DeleteContentPageCommand) error {
	if s.repo == nil {
		return ErrContentRepositoryMissing
	}
	pageID := strings.TrimSpace(cmd.PageID)
	if pageID == "" {
		return fmt.Errorf("%w: page id is required", ErrContentPageInvalid)
	}
	existing, err := s.repo.GetPageByID(ctx, pageID)
	if err != nil {
		if isRepositoryNotFound(err) {
			return ErrContentPageNotFound
		}
		return err
	}
	if err := s.repo.DeletePage(ctx, pageID); err != nil {
		return err
	}
	s.recordPageAudit(ctx, "content.page.delete", existing, domain.ContentPage{}, strings.TrimSpace(cmd.ActorID))
	if existing.IsPublished {
		s.invalidatePages(ctx, []ContentCacheKey{{
			Slug:   strings.TrimSpace(existing.Slug),
			Locale: normalizeLocaleValue(existing.Locale),
		}})
	}
	return nil
}

func normalizeContentGuide(guide domain.ContentGuide, requestedLocale, fallbackLocale, defaultLocale string) domain.ContentGuide {
	guide.Slug = strings.TrimSpace(guide.Slug)
	guide.Locale = normalizeLocaleValue(guide.Locale)
	requestedLocale = normalizeLocaleValue(requestedLocale)
	fallbackLocale = normalizeLocaleValue(fallbackLocale)
	defaultLocale = normalizeLocaleValue(defaultLocale)

	if guide.Locale == "" {
		switch {
		case requestedLocale != "":
			guide.Locale = requestedLocale
		case fallbackLocale != "":
			guide.Locale = fallbackLocale
		default:
			guide.Locale = defaultLocale
		}
	}

	guide.Category = strings.TrimSpace(guide.Category)
	guide.Title = strings.TrimSpace(guide.Title)
	guide.Summary = strings.TrimSpace(guide.Summary)
	guide.BodyHTML = strings.TrimSpace(guide.BodyHTML)
	guide.HeroImage = strings.TrimSpace(guide.HeroImage)
	guide.Tags = normalizeStringSlice(guide.Tags)
	guide.Status = strings.TrimSpace(guide.Status)
	if !guide.IsPublished && guide.Status != "" {
		guide.IsPublished = strings.EqualFold(guide.Status, "published")
	}

	if !guide.PublishedAt.IsZero() {
		guide.PublishedAt = guide.PublishedAt.UTC()
	}
	if !guide.CreatedAt.IsZero() {
		guide.CreatedAt = guide.CreatedAt.UTC()
	}
	if !guide.UpdatedAt.IsZero() {
		guide.UpdatedAt = guide.UpdatedAt.UTC()
	}
	return guide
}

func normalizeContentPage(page domain.ContentPage, requestedLocale, defaultLocale string) domain.ContentPage {
	page.Slug = strings.TrimSpace(page.Slug)
	page.PreviewToken = strings.TrimSpace(page.PreviewToken)

	requestedLocale = normalizeLocaleValue(requestedLocale)
	defaultLocale = normalizeLocaleValue(defaultLocale)
	pageLocale := normalizeLocaleValue(page.Locale)

	switch {
	case pageLocale != "":
		page.Locale = pageLocale
	case requestedLocale != "":
		page.Locale = requestedLocale
	default:
		page.Locale = defaultLocale
	}

	page.Title = strings.TrimSpace(page.Title)
	page.BodyHTML = strings.TrimSpace(page.BodyHTML)
	page.Status = strings.TrimSpace(page.Status)
	page.SEO = textutil.NormalizeStringMap(page.SEO)

	if !page.IsPublished && page.Status != "" {
		page.IsPublished = strings.EqualFold(page.Status, "published")
	}

	if !page.UpdatedAt.IsZero() {
		page.UpdatedAt = page.UpdatedAt.UTC()
	}

	return page
}

func (s *contentService) ensureUniquePage(ctx context.Context, slug, locale, pageID string) error {
	existing, err := s.repo.GetPage(ctx, slug, locale)
	if err != nil {
		if isRepositoryNotFound(err) {
			return nil
		}
		return err
	}
	if strings.EqualFold(strings.TrimSpace(existing.ID), strings.TrimSpace(pageID)) {
		return nil
	}
	return ErrContentPageConflict
}

func (s *contentService) recordPageAudit(ctx context.Context, action string, before, after domain.ContentPage, actorID string) {
	if s.audit == nil {
		return
	}
	actorID = strings.TrimSpace(actorID)
	targetID := pickFirstNonEmptyString(after.ID, before.ID)
	metadata := map[string]any{
		"pageId":      targetID,
		"slug":        pickFirstNonEmptyString(after.Slug, before.Slug),
		"locale":      pickFirstNonEmptyString(after.Locale, before.Locale, s.defaultLocale),
		"status":      pickFirstNonEmptyString(after.Status, before.Status),
		"isPublished": after.IsPublished || (!after.IsPublished && before.IsPublished),
	}
	if metadata["pageId"] == "" {
		delete(metadata, "pageId")
	}

	s.audit.Record(ctx, AuditLogRecord{
		Actor:      actorID,
		ActorType:  "staff",
		Action:     action,
		TargetRef:  pageTargetRef(targetID),
		Severity:   "info",
		OccurredAt: s.clock(),
		Metadata:   metadata,
		Diff:       buildPageDiff(before, after),
	})
}

func (s *contentService) invalidatePages(ctx context.Context, pages []ContentCacheKey) {
	if s.cache == nil || len(pages) == 0 {
		return
	}
	_ = s.cache.InvalidatePages(ctx, pages)
}

func buildPageDiff(before, after domain.ContentPage) map[string]AuditLogDiff {
	diff := make(map[string]AuditLogDiff)
	add := func(field, beforeVal, afterVal string) {
		if beforeVal == afterVal {
			return
		}
		diff[field] = AuditLogDiff{Before: beforeVal, After: afterVal}
	}

	add("slug", strings.TrimSpace(before.Slug), strings.TrimSpace(after.Slug))
	add("locale", normalizeLocaleValue(before.Locale), normalizeLocaleValue(after.Locale))
	add("title", strings.TrimSpace(before.Title), strings.TrimSpace(after.Title))
	add("status", strings.TrimSpace(before.Status), strings.TrimSpace(after.Status))

	if strings.TrimSpace(before.BodyHTML) != strings.TrimSpace(after.BodyHTML) {
		diff["body_html"] = AuditLogDiff{Before: strings.TrimSpace(before.BodyHTML), After: strings.TrimSpace(after.BodyHTML)}
	}
	if !mapsEqualStringMap(before.SEO, after.SEO) {
		diff["seo"] = AuditLogDiff{Before: textutil.NormalizeStringMap(before.SEO), After: textutil.NormalizeStringMap(after.SEO)}
	}
	if before.IsPublished != after.IsPublished {
		diff["is_published"] = AuditLogDiff{Before: before.IsPublished, After: after.IsPublished}
	}

	if len(diff) == 0 {
		return nil
	}
	return diff
}

func mapsEqualStringMap(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for key, val := range a {
		if strings.TrimSpace(val) != strings.TrimSpace(b[key]) {
			return false
		}
	}
	for key, val := range b {
		if strings.TrimSpace(val) != strings.TrimSpace(a[key]) {
			return false
		}
	}
	return true
}

func pickFirstNonEmptyString(values ...string) string {
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func pageTargetRef(pageID string) string {
	trimmed := strings.TrimSpace(pageID)
	if trimmed == "" {
		return ""
	}
	return fmt.Sprintf("/content/pages/%s", trimmed)
}

func normalizePageStatus(status string) (string, error) {
	trimmed := strings.ToLower(strings.TrimSpace(status))
	if trimmed == "" {
		return "draft", nil
	}
	switch trimmed {
	case "draft", "published", "archived":
		return trimmed, nil
	default:
		return "", fmt.Errorf("%w: unsupported status %q", ErrContentPageInvalid, status)
	}
}

func generatePreviewToken() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

func normalizeLocalePointer(value *string) string {
	if value == nil {
		return ""
	}
	return normalizeLocaleValue(*value)
}

func pointerIfNotEmpty(value string) *string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func normalizeStatusSlice(statuses []string) []string {
	if len(statuses) == 0 {
		return nil
	}
	result := make([]string, 0, len(statuses))
	seen := make(map[string]struct{}, len(statuses))
	for _, status := range statuses {
		trimmed := strings.TrimSpace(status)
		if trimmed == "" {
			continue
		}
		lower := strings.ToLower(trimmed)
		if _, ok := seen[lower]; ok {
			continue
		}
		seen[lower] = struct{}{}
		result = append(result, lower)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func normalizeStringSlice(values []string) []string {
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
		key := strings.ToLower(trimmed)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, trimmed)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func normalizeLocaleValue(raw string) string {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return ""
	}
	normalized := strings.ReplaceAll(trimmed, "_", "-")
	return strings.ToLower(normalized)
}

func isRepositoryNotFound(err error) bool {
	if err == nil {
		return false
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		return repoErr.IsNotFound()
	}
	return false
}
