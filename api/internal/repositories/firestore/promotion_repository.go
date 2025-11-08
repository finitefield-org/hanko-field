package firestore

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	domain "github.com/hanko-field/api/internal/domain"
	pfirestore "github.com/hanko-field/api/internal/platform/firestore"
	"github.com/hanko-field/api/internal/repositories"
)

const promotionsCollection = "promotions"

// PromotionRepository persists promotion definitions for admin and public surfaces.
type PromotionRepository struct {
	base *pfirestore.BaseRepository[promotionDocument]
}

// NewPromotionRepository constructs a Firestore-backed promotion repository.
func NewPromotionRepository(provider *pfirestore.Provider) (*PromotionRepository, error) {
	if provider == nil {
		return nil, errors.New("promotion repository: firestore provider is required")
	}
	base := pfirestore.NewBaseRepository[promotionDocument](provider, promotionsCollection, nil, nil)
	return &PromotionRepository{base: base}, nil
}

// Insert creates a new promotion document. The ID must be unique.
func (r *PromotionRepository) Insert(ctx context.Context, promotion domain.Promotion) error {
	if r == nil || r.base == nil {
		return errors.New("promotion repository not initialised")
	}
	promoID := strings.TrimSpace(promotion.ID)
	if promoID == "" {
		return errors.New("promotion repository: promotion id is required")
	}
	docRef, err := r.base.DocumentRef(ctx, promoID)
	if err != nil {
		return err
	}
	doc := encodePromotionDocument(promotion)
	if _, err := docRef.Create(ctx, doc); err != nil {
		return pfirestore.WrapError("promotions.insert", err)
	}
	return nil
}

// Update replaces the stored promotion with the provided snapshot.
func (r *PromotionRepository) Update(ctx context.Context, promotion domain.Promotion) error {
	if r == nil || r.base == nil {
		return errors.New("promotion repository not initialised")
	}
	promoID := strings.TrimSpace(promotion.ID)
	if promoID == "" {
		return errors.New("promotion repository: promotion id is required")
	}
	docRef, err := r.base.DocumentRef(ctx, promoID)
	if err != nil {
		return err
	}
	doc := encodePromotionDocument(promotion)
	if _, err := docRef.Set(ctx, doc); err != nil {
		return pfirestore.WrapError("promotions.update", err)
	}
	return nil
}

// Delete removes the promotion document from the collection.
func (r *PromotionRepository) Delete(ctx context.Context, promotionID string) error {
	if r == nil || r.base == nil {
		return errors.New("promotion repository not initialised")
	}
	promotionID = strings.TrimSpace(promotionID)
	if promotionID == "" {
		return errors.New("promotion repository: promotion id is required")
	}
	docRef, err := r.base.DocumentRef(ctx, promotionID)
	if err != nil {
		return err
	}
	if _, err := docRef.Delete(ctx); err != nil {
		return pfirestore.WrapError("promotions.delete", err)
	}
	return nil
}

// Get fetches a promotion by its identifier.
func (r *PromotionRepository) Get(ctx context.Context, promotionID string) (domain.Promotion, error) {
	if r == nil || r.base == nil {
		return domain.Promotion{}, errors.New("promotion repository not initialised")
	}
	promotionID = strings.TrimSpace(promotionID)
	if promotionID == "" {
		return domain.Promotion{}, errors.New("promotion repository: promotion id is required")
	}
	doc, err := r.base.Get(ctx, promotionID)
	if err != nil {
		return domain.Promotion{}, err
	}
	return decodePromotionDocument(promotionID, doc.Data), nil
}

// FindByCode looks up a promotion using its unique code.
func (r *PromotionRepository) FindByCode(ctx context.Context, code string) (domain.Promotion, error) {
	if r == nil || r.base == nil {
		return domain.Promotion{}, errors.New("promotion repository not initialised")
	}
	code = strings.ToUpper(strings.TrimSpace(code))
	if code == "" {
		return domain.Promotion{}, errors.New("promotion repository: code is required")
	}
	docs, err := r.base.Query(ctx, func(q firestore.Query) firestore.Query {
		return q.Where("code", "==", code).Limit(1)
	})
	if err != nil {
		return domain.Promotion{}, err
	}
	if len(docs) == 0 {
		return domain.Promotion{}, pfirestore.WrapError("promotions.find_by_code", status.Error(codes.NotFound, "promotion not found"))
	}
	doc := docs[0]
	return decodePromotionDocument(doc.ID, doc.Data), nil
}

// List returns promotions matching the supplied filter using cursor pagination.
func (r *PromotionRepository) List(ctx context.Context, filter repositories.PromotionListFilter) (domain.CursorPage[domain.Promotion], error) {
	if r == nil || r.base == nil {
		return domain.CursorPage[domain.Promotion]{}, errors.New("promotion repository not initialised")
	}

	pageSize := filter.Pagination.PageSize
	if pageSize < 0 {
		pageSize = 0
	}
	fetchLimit := pageSize
	if pageSize > 0 {
		fetchLimit = pageSize + 1
	}

	var startAfter []any
	if token := strings.TrimSpace(filter.Pagination.PageToken); token != "" {
		ts, id, err := decodePromotionPageToken(token)
		if err != nil {
			return domain.CursorPage[domain.Promotion]{}, fmt.Errorf("promotion repository: invalid page token: %w", err)
		}
		startAfter = []any{ts, id}
	}

	statusFilters := normaliseFilterValues(filter.Status)
	kindFilters := normaliseFilterValues(filter.Kinds)

	var activeOn *time.Time
	if filter.ActiveOn != nil {
		value := filter.ActiveOn.UTC()
		if !value.IsZero() {
			activeOn = &value
		}
	}

	docs, err := r.base.Query(ctx, func(q firestore.Query) firestore.Query {
		if len(statusFilters) == 1 {
			q = q.Where("status", "==", statusFilters[0])
		} else if len(statusFilters) > 1 {
			q = q.Where("status", "in", limitStrings(statusFilters, 10))
		}

		if len(kindFilters) == 1 {
			q = q.Where("kind", "==", kindFilters[0])
		} else if len(kindFilters) > 1 {
			q = q.Where("kind", "in", limitStrings(kindFilters, 10))
		}

		if activeOn != nil {
			q = q.Where("startsAt", "<=", *activeOn).Where("endsAt", ">=", *activeOn)
		}

		q = q.OrderBy("startsAt", firestore.Desc).OrderBy(firestore.DocumentID, firestore.Desc)
		if len(startAfter) == 2 {
			q = q.StartAfter(startAfter...)
		}
		if fetchLimit > 0 {
			q = q.Limit(fetchLimit)
		}
		return q
	})
	if err != nil {
		return domain.CursorPage[domain.Promotion]{}, err
	}

	valueDocs := docs
	nextToken := ""
	if pageSize > 0 && len(valueDocs) == fetchLimit {
		last := valueDocs[len(valueDocs)-1]
		nextToken = encodePromotionPageToken(last.Data.StartsAt, last.ID)
		valueDocs = valueDocs[:len(valueDocs)-1]
	}

	items := make([]domain.Promotion, 0, len(valueDocs))
	for _, doc := range valueDocs {
		items = append(items, decodePromotionDocument(doc.ID, doc.Data))
	}

	return domain.CursorPage[domain.Promotion]{
		Items:         items,
		NextPageToken: nextToken,
	}, nil
}

type promotionDocument struct {
	Code              string                      `firestore:"code"`
	Name              string                      `firestore:"name"`
	Description       string                      `firestore:"description"`
	DescriptionPublic string                      `firestore:"descriptionPublic"`
	Status            string                      `firestore:"status"`
	Kind              string                      `firestore:"kind"`
	Value             float64                     `firestore:"value"`
	Currency          string                      `firestore:"currency"`
	IsActive          bool                        `firestore:"isActive"`
	StartsAt          time.Time                   `firestore:"startsAt"`
	EndsAt            time.Time                   `firestore:"endsAt"`
	UsageLimit        int                         `firestore:"usageLimit"`
	UsageCount        int                         `firestore:"usageCount"`
	LimitPerUser      int                         `firestore:"limitPerUser"`
	Notes             string                      `firestore:"notes"`
	EligibleAudiences []string                    `firestore:"eligibleAudiences"`
	InternalOnly      bool                        `firestore:"internalOnly"`
	RequiresAuth      bool                        `firestore:"requiresAuth"`
	Metadata          map[string]any              `firestore:"metadata"`
	Stacking          promotionStackingDocument   `firestore:"stacking"`
	Conditions        promotionConditionsDocument `firestore:"conditions"`
	CreatedAt         time.Time                   `firestore:"createdAt"`
	UpdatedAt         time.Time                   `firestore:"updatedAt"`
}

type promotionStackingDocument struct {
	Combinable    bool `firestore:"combinable"`
	WithSalePrice bool `firestore:"withSalePrice"`
	MaxStack      *int `firestore:"maxStack"`
}

type promotionConditionsDocument struct {
	MinSubtotal     *int64                      `firestore:"minSubtotal"`
	CountryIn       []string                    `firestore:"countryIn"`
	CurrencyIn      []string                    `firestore:"currencyIn"`
	ShapeIn         []string                    `firestore:"shapeIn"`
	SizeMMBetween   *promotionSizeRangeDocument `firestore:"sizeMmBetween"`
	ProductRefsIn   []string                    `firestore:"productRefsIn"`
	MaterialRefsIn  []string                    `firestore:"materialRefsIn"`
	NewCustomerOnly *bool                       `firestore:"newCustomerOnly"`
}

type promotionSizeRangeDocument struct {
	Min *float64 `firestore:"min"`
	Max *float64 `firestore:"max"`
}

func encodePromotionDocument(p domain.Promotion) promotionDocument {
	var sizeRange *promotionSizeRangeDocument
	if p.Conditions.SizeMMBetween != nil {
		size := promotionSizeRangeDocument{
			Min: p.Conditions.SizeMMBetween.Min,
			Max: p.Conditions.SizeMMBetween.Max,
		}
		sizeRange = &size
	}

	metadata := make(map[string]any, len(p.Metadata))
	for k, v := range p.Metadata {
		metadata[k] = v
	}

	return promotionDocument{
		Code:              p.Code,
		Name:              p.Name,
		Description:       p.Description,
		DescriptionPublic: p.DescriptionPublic,
		Status:            p.Status,
		Kind:              p.Kind,
		Value:             p.Value,
		Currency:          p.Currency,
		IsActive:          p.IsActive,
		StartsAt:          p.StartsAt.UTC(),
		EndsAt:            p.EndsAt.UTC(),
		UsageLimit:        p.UsageLimit,
		UsageCount:        p.UsageCount,
		LimitPerUser:      p.LimitPerUser,
		Notes:             p.Notes,
		EligibleAudiences: clonePromotionStrings(p.EligibleAudiences),
		InternalOnly:      p.InternalOnly,
		RequiresAuth:      p.RequiresAuth,
		Metadata:          metadata,
		Stacking: promotionStackingDocument{
			Combinable:    p.Stacking.Combinable,
			WithSalePrice: p.Stacking.WithSalePrice,
			MaxStack:      p.Stacking.MaxStack,
		},
		Conditions: promotionConditionsDocument{
			MinSubtotal:     p.Conditions.MinSubtotal,
			CountryIn:       clonePromotionStrings(p.Conditions.CountryIn),
			CurrencyIn:      clonePromotionStrings(p.Conditions.CurrencyIn),
			ShapeIn:         clonePromotionStrings(p.Conditions.ShapeIn),
			SizeMMBetween:   sizeRange,
			ProductRefsIn:   clonePromotionStrings(p.Conditions.ProductRefsIn),
			MaterialRefsIn:  clonePromotionStrings(p.Conditions.MaterialRefsIn),
			NewCustomerOnly: p.Conditions.NewCustomerOnly,
		},
		CreatedAt: p.CreatedAt.UTC(),
		UpdatedAt: p.UpdatedAt.UTC(),
	}
}

func decodePromotionDocument(id string, doc promotionDocument) domain.Promotion {
	return domain.Promotion{
		ID:                strings.TrimSpace(id),
		Code:              doc.Code,
		Name:              doc.Name,
		Description:       doc.Description,
		DescriptionPublic: doc.DescriptionPublic,
		Status:            doc.Status,
		Kind:              doc.Kind,
		Value:             doc.Value,
		Currency:          doc.Currency,
		IsActive:          doc.IsActive,
		StartsAt:          doc.StartsAt,
		EndsAt:            doc.EndsAt,
		UsageLimit:        doc.UsageLimit,
		UsageCount:        doc.UsageCount,
		LimitPerUser:      doc.LimitPerUser,
		Notes:             doc.Notes,
		EligibleAudiences: clonePromotionStrings(doc.EligibleAudiences),
		InternalOnly:      doc.InternalOnly,
		RequiresAuth:      doc.RequiresAuth,
		Metadata:          clonePromotionMap(doc.Metadata),
		Stacking: domain.PromotionStacking{
			Combinable:    doc.Stacking.Combinable,
			WithSalePrice: doc.Stacking.WithSalePrice,
			MaxStack:      doc.Stacking.MaxStack,
		},
		Conditions: domain.PromotionConditions{
			MinSubtotal:     doc.Conditions.MinSubtotal,
			CountryIn:       clonePromotionStrings(doc.Conditions.CountryIn),
			CurrencyIn:      clonePromotionStrings(doc.Conditions.CurrencyIn),
			ShapeIn:         clonePromotionStrings(doc.Conditions.ShapeIn),
			SizeMMBetween:   decodePromotionSizeRange(doc.Conditions.SizeMMBetween),
			ProductRefsIn:   clonePromotionStrings(doc.Conditions.ProductRefsIn),
			MaterialRefsIn:  clonePromotionStrings(doc.Conditions.MaterialRefsIn),
			NewCustomerOnly: doc.Conditions.NewCustomerOnly,
		},
		CreatedAt: doc.CreatedAt,
		UpdatedAt: doc.UpdatedAt,
	}
}

func decodePromotionSizeRange(doc *promotionSizeRangeDocument) *domain.PromotionSizeRange {
	if doc == nil {
		return nil
	}
	return &domain.PromotionSizeRange{
		Min: doc.Min,
		Max: doc.Max,
	}
}

func clonePromotionStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, len(values))
	copy(out, values)
	return out
}

func clonePromotionMap(values map[string]any) map[string]any {
	if len(values) == 0 {
		return nil
	}
	out := make(map[string]any, len(values))
	for k, v := range values {
		out[k] = v
	}
	return out
}

func limitStrings(values []string, max int) []string {
	if max <= 0 || len(values) <= max {
		return values
	}
	return values[:max]
}

func normaliseFilterValues(values []string) []string {
	result := make([]string, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(strings.ToLower(value))
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
	}
	return result
}

func encodePromotionPageToken(startsAt time.Time, docID string) string {
	payload := fmt.Sprintf("%s|%s", startsAt.UTC().Format(time.RFC3339Nano), docID)
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

func decodePromotionPageToken(token string) (time.Time, string, error) {
	bytes, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return time.Time{}, "", err
	}
	parts := strings.SplitN(string(bytes), "|", 2)
	if len(parts) != 2 {
		return time.Time{}, "", errors.New("invalid token parts")
	}
	ts, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, "", err
	}
	return ts, parts[1], nil
}
