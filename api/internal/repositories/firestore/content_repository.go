package firestore

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	domain "github.com/hanko-field/api/internal/domain"
	pfirestore "github.com/hanko-field/api/internal/platform/firestore"
	"github.com/hanko-field/api/internal/repositories"
)

const (
	contentGuidesCollection = "contentGuides"
	contentPagesCollection  = "contentPages"
)

// ContentRepository persists guides and pages for CMS features.
type ContentRepository struct {
	guides *pfirestore.BaseRepository[contentGuideDocument]
	pages  *pfirestore.BaseRepository[contentPageDocument]
}

// NewContentRepository constructs the Firestore-backed content repository.
func NewContentRepository(provider *pfirestore.Provider) (*ContentRepository, error) {
	if provider == nil {
		return nil, errors.New("content repository: firestore provider is required")
	}
	return &ContentRepository{
		guides: pfirestore.NewBaseRepository[contentGuideDocument](provider, contentGuidesCollection, nil, nil),
		pages:  pfirestore.NewBaseRepository[contentPageDocument](provider, contentPagesCollection, nil, nil),
	}, nil
}

func (r *ContentRepository) ListGuides(ctx context.Context, filter repositories.ContentGuideFilter) (domain.CursorPage[domain.ContentGuide], error) {
	if r == nil || r.guides == nil {
		return domain.CursorPage[domain.ContentGuide]{}, errors.New("content repository not initialised")
	}

	pageSize := filter.Pagination.PageSize
	if pageSize <= 0 {
		pageSize = 20
	} else if pageSize > 60 {
		pageSize = 60
	}
	fetchLimit := pageSize + 1

	startAfter, err := decodeGuidePageToken(strings.TrimSpace(filter.Pagination.PageToken))
	if err != nil {
		return domain.CursorPage[domain.ContentGuide]{}, err
	}

	trimPtr := func(value *string) string {
		if value == nil {
			return ""
		}
		return strings.TrimSpace(*value)
	}

	category := trimPtr(filter.Category)
	slug := trimPtr(filter.Slug)
	locale := trimPtr(filter.Locale)
	fallback := strings.TrimSpace(filter.FallbackLocale)
	statuses := clipFilterValues(filter.Status)

	locales := make([]string, 0, 2)
	if locale != "" {
		locales = append(locales, locale)
	}
	if fallback != "" && (locale == "" || fallback != locale) {
		locales = append(locales, fallback)
	}

	docs, err := r.guides.Query(ctx, func(q firestore.Query) firestore.Query {
		if category != "" {
			q = q.Where("category", "==", category)
		}
		if slug != "" {
			q = q.Where("slug", "==", slug)
		}
		if len(locales) == 1 {
			q = q.Where("locale", "==", locales[0])
		} else if len(locales) > 1 {
			q = q.Where("locale", "in", limitValues(locales, 10))
		}
		if len(statuses) == 1 {
			q = q.Where("status", "==", statuses[0])
		} else if len(statuses) > 1 {
			q = q.Where("status", "in", limitValues(statuses, 10))
		}
		if filter.OnlyPublished {
			q = q.Where("isPublished", "==", true)
		}
		q = q.OrderBy("updatedAt", firestore.Desc).OrderBy(firestore.DocumentID, firestore.Desc)
		if len(startAfter) == 2 {
			q = q.StartAfter(startAfter...)
		}
		q = q.Limit(fetchLimit)
		return q
	})
	if err != nil {
		return domain.CursorPage[domain.ContentGuide]{}, err
	}

	nextToken := ""
	if len(docs) == fetchLimit {
		last := docs[len(docs)-1]
		updated := last.Data.UpdatedAt
		if updated.IsZero() {
			updated = last.UpdateTime
		}
		nextToken = encodeGuidePageToken(updated, last.ID)
		docs = docs[:len(docs)-1]
	}

	items := make([]domain.ContentGuide, 0, len(docs))
	for _, doc := range docs {
		items = append(items, doc.Data.toDomain(doc.ID))
	}

	return domain.CursorPage[domain.ContentGuide]{
		Items:         items,
		NextPageToken: nextToken,
	}, nil
}

func (r *ContentRepository) UpsertGuide(ctx context.Context, guide domain.ContentGuide) (domain.ContentGuide, error) {
	if r == nil || r.guides == nil {
		return domain.ContentGuide{}, errors.New("content repository not initialised")
	}
	id := strings.TrimSpace(guide.ID)
	if id == "" {
		return domain.ContentGuide{}, errors.New("content repository: guide id is required")
	}
	doc := newContentGuideDocument(guide)
	if _, err := r.guides.Set(ctx, id, doc); err != nil {
		return domain.ContentGuide{}, err
	}
	return doc.toDomain(id), nil
}

func (r *ContentRepository) DeleteGuide(ctx context.Context, guideID string) error {
	if r == nil || r.guides == nil {
		return errors.New("content repository not initialised")
	}
	id := strings.TrimSpace(guideID)
	if id == "" {
		return errors.New("content repository: guide id is required")
	}
	ref, err := r.guides.DocumentRef(ctx, id)
	if err != nil {
		return err
	}
	if _, err := ref.Delete(ctx); err != nil {
		return pfirestore.WrapError("contentGuides.delete", err)
	}
	return nil
}

func (r *ContentRepository) GetGuideBySlug(ctx context.Context, slug string, locale string) (domain.ContentGuide, error) {
	if r == nil || r.guides == nil {
		return domain.ContentGuide{}, errors.New("content repository not initialised")
	}
	slug = strings.TrimSpace(slug)
	locale = strings.TrimSpace(locale)
	if slug == "" {
		return domain.ContentGuide{}, errors.New("content repository: slug is required")
	}
	if locale == "" {
		return domain.ContentGuide{}, errors.New("content repository: locale is required")
	}

	docs, err := r.guides.Query(ctx, func(q firestore.Query) firestore.Query {
		return q.Where("slug", "==", slug).
			Where("locale", "==", locale).
			Limit(1)
	})
	if err != nil {
		return domain.ContentGuide{}, err
	}
	if len(docs) == 0 {
		return domain.ContentGuide{}, pfirestore.WrapError("contentGuides.get_by_slug", status.Error(codes.NotFound, "guide not found"))
	}
	doc := docs[0]
	return doc.Data.toDomain(doc.ID), nil
}

func (r *ContentRepository) GetGuide(ctx context.Context, guideID string) (domain.ContentGuide, error) {
	if r == nil || r.guides == nil {
		return domain.ContentGuide{}, errors.New("content repository not initialised")
	}
	id := strings.TrimSpace(guideID)
	if id == "" {
		return domain.ContentGuide{}, errors.New("content repository: guide id is required")
	}
	doc, err := r.guides.Get(ctx, id)
	if err != nil {
		return domain.ContentGuide{}, err
	}
	return doc.Data.toDomain(doc.ID), nil
}

func (r *ContentRepository) GetPage(ctx context.Context, slug string, locale string) (domain.ContentPage, error) {
	if r == nil || r.pages == nil {
		return domain.ContentPage{}, errors.New("content repository not initialised")
	}
	slug = strings.TrimSpace(slug)
	locale = strings.TrimSpace(locale)
	if slug == "" {
		return domain.ContentPage{}, errors.New("content repository: slug is required")
	}
	if locale == "" {
		return domain.ContentPage{}, errors.New("content repository: locale is required")
	}

	docs, err := r.pages.Query(ctx, func(q firestore.Query) firestore.Query {
		return q.Where("slug", "==", slug).
			Where("locale", "==", locale).
			Limit(1)
	})
	if err != nil {
		return domain.ContentPage{}, err
	}
	if len(docs) == 0 {
		return domain.ContentPage{}, pfirestore.WrapError("contentPages.get", status.Error(codes.NotFound, "page not found"))
	}
	return docs[0].Data.toDomain(docs[0].ID), nil
}

func (r *ContentRepository) UpsertPage(ctx context.Context, page domain.ContentPage) (domain.ContentPage, error) {
	if r == nil || r.pages == nil {
		return domain.ContentPage{}, errors.New("content repository not initialised")
	}
	id := strings.TrimSpace(page.ID)
	if id == "" {
		return domain.ContentPage{}, errors.New("content repository: page id is required")
	}
	doc := newContentPageDocument(page)
	if _, err := r.pages.Set(ctx, id, doc); err != nil {
		return domain.ContentPage{}, err
	}
	return doc.toDomain(id), nil
}

func (r *ContentRepository) DeletePage(ctx context.Context, pageID string) error {
	if r == nil || r.pages == nil {
		return errors.New("content repository not initialised")
	}
	id := strings.TrimSpace(pageID)
	if id == "" {
		return errors.New("content repository: page id is required")
	}
	ref, err := r.pages.DocumentRef(ctx, id)
	if err != nil {
		return err
	}
	if _, err := ref.Delete(ctx); err != nil {
		return pfirestore.WrapError("contentPages.delete", err)
	}
	return nil
}

func clipFilterValues(values []string) []string {
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
	return result
}

func limitValues(values []string, max int) []string {
	if len(values) <= max {
		return values
	}
	out := make([]string, max)
	copy(out, values[:max])
	return out
}

func encodeGuidePageToken(updatedAt time.Time, docID string) string {
	payload := fmt.Sprintf("%d|%s", updatedAt.UTC().UnixNano(), docID)
	return base64.StdEncoding.EncodeToString([]byte(payload))
}

func decodeGuidePageToken(token string) ([]any, error) {
	if token == "" {
		return nil, nil
	}
	decoded, err := base64.StdEncoding.DecodeString(token)
	if err != nil {
		return nil, fmt.Errorf("content repository: invalid page token")
	}
	parts := strings.SplitN(string(decoded), "|", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("content repository: invalid page token")
	}
	ns, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("content repository: invalid page token")
	}
	docID := strings.TrimSpace(parts[1])
	if docID == "" {
		return nil, fmt.Errorf("content repository: invalid page token")
	}
	return []any{time.Unix(0, ns).UTC(), docID}, nil
}

type contentGuideDocument struct {
	Slug        string     `firestore:"slug"`
	Locale      string     `firestore:"locale"`
	Category    string     `firestore:"category"`
	Title       string     `firestore:"title"`
	Summary     string     `firestore:"summary"`
	BodyHTML    string     `firestore:"bodyHtml"`
	HeroImage   string     `firestore:"heroImage"`
	Tags        []string   `firestore:"tags"`
	Status      string     `firestore:"status"`
	IsPublished bool       `firestore:"isPublished"`
	PublishedAt *time.Time `firestore:"publishedAt,omitempty"`
	CreatedAt   time.Time  `firestore:"createdAt"`
	UpdatedAt   time.Time  `firestore:"updatedAt"`
}

func newContentGuideDocument(guide domain.ContentGuide) contentGuideDocument {
	doc := contentGuideDocument{
		Slug:        strings.TrimSpace(guide.Slug),
		Locale:      strings.TrimSpace(guide.Locale),
		Category:    strings.TrimSpace(guide.Category),
		Title:       guide.Title,
		Summary:     guide.Summary,
		BodyHTML:    guide.BodyHTML,
		HeroImage:   guide.HeroImage,
		Tags:        append([]string(nil), guide.Tags...),
		Status:      strings.TrimSpace(guide.Status),
		IsPublished: guide.IsPublished,
		CreatedAt:   guide.CreatedAt.UTC(),
		UpdatedAt:   guide.UpdatedAt.UTC(),
	}
	if !guide.PublishedAt.IsZero() {
		ts := guide.PublishedAt.UTC()
		doc.PublishedAt = &ts
	}
	return doc
}

func (d contentGuideDocument) toDomain(id string) domain.ContentGuide {
	guide := domain.ContentGuide{
		ID:          strings.TrimSpace(id),
		Slug:        strings.TrimSpace(d.Slug),
		Locale:      strings.TrimSpace(d.Locale),
		Category:    strings.TrimSpace(d.Category),
		Title:       d.Title,
		Summary:     d.Summary,
		BodyHTML:    d.BodyHTML,
		HeroImage:   d.HeroImage,
		Tags:        append([]string(nil), d.Tags...),
		Status:      strings.TrimSpace(d.Status),
		IsPublished: d.IsPublished,
		CreatedAt:   d.CreatedAt.UTC(),
		UpdatedAt:   d.UpdatedAt.UTC(),
	}
	if d.PublishedAt != nil {
		guide.PublishedAt = d.PublishedAt.UTC()
	}
	return guide
}

type contentPageDocument struct {
	Slug        string            `firestore:"slug"`
	Locale      string            `firestore:"locale"`
	Title       string            `firestore:"title"`
	BodyHTML    string            `firestore:"bodyHtml"`
	SEO         map[string]string `firestore:"seo"`
	Status      string            `firestore:"status"`
	IsPublished bool              `firestore:"isPublished"`
	UpdatedAt   time.Time         `firestore:"updatedAt"`
}

func newContentPageDocument(page domain.ContentPage) contentPageDocument {
	return contentPageDocument{
		Slug:        strings.TrimSpace(page.Slug),
		Locale:      strings.TrimSpace(page.Locale),
		Title:       page.Title,
		BodyHTML:    page.BodyHTML,
		SEO:         copyStringMap(page.SEO),
		Status:      strings.TrimSpace(page.Status),
		IsPublished: page.IsPublished,
		UpdatedAt:   page.UpdatedAt.UTC(),
	}
}

func (d contentPageDocument) toDomain(id string) domain.ContentPage {
	return domain.ContentPage{
		ID:          strings.TrimSpace(id),
		Slug:        strings.TrimSpace(d.Slug),
		Locale:      strings.TrimSpace(d.Locale),
		Title:       d.Title,
		BodyHTML:    d.BodyHTML,
		SEO:         copyStringMap(d.SEO),
		Status:      strings.TrimSpace(d.Status),
		IsPublished: d.IsPublished,
		UpdatedAt:   d.UpdatedAt.UTC(),
	}
}

func copyStringMap(input map[string]string) map[string]string {
	if len(input) == 0 {
		return nil
	}
	cloned := make(map[string]string, len(input))
	for k, v := range input {
		cloned[k] = v
	}
	return cloned
}
