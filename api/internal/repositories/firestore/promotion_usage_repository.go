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
	"google.golang.org/api/iterator"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	domain "github.com/hanko-field/api/internal/domain"
	pfirestore "github.com/hanko-field/api/internal/platform/firestore"
	"github.com/hanko-field/api/internal/repositories"
)

const promotionUsageCollection = "usages"

// PromotionUsageRepository persists per-user promotion usage aggregates under promotion documents.
type PromotionUsageRepository struct {
	provider *pfirestore.Provider
}

// NewPromotionUsageRepository constructs a Firestore-backed promotion usage repository.
func NewPromotionUsageRepository(provider *pfirestore.Provider) (*PromotionUsageRepository, error) {
	if provider == nil {
		return nil, errors.New("promotion usage repository: firestore provider is required")
	}
	return &PromotionUsageRepository{provider: provider}, nil
}

// IncrementUsage atomically increments promotion usage counters for the supplied user.
func (r *PromotionUsageRepository) IncrementUsage(ctx context.Context, promoID string, userID string, now time.Time) (domain.PromotionUsage, error) {
	if r == nil || r.provider == nil {
		return domain.PromotionUsage{}, errors.New("promotion usage repository not initialised")
	}
	promoID = strings.TrimSpace(promoID)
	userID = strings.TrimSpace(userID)
	if promoID == "" {
		return domain.PromotionUsage{}, errors.New("promotion usage repository: promotion id is required")
	}
	if userID == "" {
		return domain.PromotionUsage{}, errors.New("promotion usage repository: user id is required")
	}
	if now.IsZero() {
		now = time.Now().UTC()
	}

	client, err := r.provider.Client(ctx)
	if err != nil {
		return domain.PromotionUsage{}, err
	}

	promoRef := client.Collection(promotionsCollection).Doc(promoID)
	usageRef := promoRef.Collection(promotionUsageCollection).Doc(userID)

	var result domain.PromotionUsage

	writeErr := r.provider.RunTransaction(ctx, func(txCtx context.Context, tx *firestore.Transaction) error {
		promoSnap, err := tx.Get(promoRef)
		if err != nil {
			return pfirestore.WrapError("promotion_usage.increment.get_promotion", err)
		}
		var promoDoc promotionDocument
		if err := promoSnap.DataTo(&promoDoc); err != nil {
			return fmt.Errorf("promotion usage repository: decode promotion: %w", err)
		}
		if promoDoc.UsageLimit > 0 && promoDoc.UsageCount >= promoDoc.UsageLimit {
			return repositories.ErrPromotionUsageLimitExceeded
		}

		usageSnap, err := tx.Get(usageRef)
		usageDoc := promotionUsageDocument{}
		existing := false
		if err != nil {
			if status.Code(err) != codes.NotFound {
				return pfirestore.WrapError("promotion_usage.increment.get_usage", err)
			}
		} else {
			existing = true
			if err := usageSnap.DataTo(&usageDoc); err != nil {
				return fmt.Errorf("promotion usage repository: decode usage: %w", err)
			}
			if usageDoc.Blocked {
				return repositories.ErrPromotionUsageBlocked
			}
		}

		if promoDoc.LimitPerUser > 0 {
			if existing && usageDoc.Times >= promoDoc.LimitPerUser {
				return repositories.ErrPromotionUsagePerUserLimitExceeded
			}
		}

		nowUTC := now.UTC()
		firstUsed := usageDoc.FirstUsedAt
		if firstUsed == nil || firstUsed.IsZero() {
			value := nowUTC
			firstUsed = &value
		}

		updatedDoc := promotionUsageDocument{
			UID:         fmt.Sprintf("users/%s", userID),
			Times:       usageDoc.Times + 1,
			LastUsedAt:  nowUTC,
			FirstUsedAt: firstUsed,
			OrderRefs:   cloneUsageStrings(usageDoc.OrderRefs),
			Blocked:     usageDoc.Blocked,
			Notes:       usageDoc.Notes,
		}

		if err := tx.Set(usageRef, updatedDoc); err != nil {
			return pfirestore.WrapError("promotion_usage.increment.set_usage", err)
		}

		promoDoc.UsageCount++
		promoDoc.UpdatedAt = nowUTC
		if err := tx.Set(promoRef, map[string]any{
			"usageCount": promoDoc.UsageCount,
			"updatedAt":  promoDoc.UpdatedAt,
		}, firestore.MergeAll); err != nil {
			return pfirestore.WrapError("promotion_usage.increment.update_promotion", err)
		}

		result = decodePromotionUsage(userID, updatedDoc)
		return nil
	})

	if writeErr != nil {
		return domain.PromotionUsage{}, writeErr
	}

	return result, nil
}

// RemoveUsage is currently not implemented.
func (r *PromotionUsageRepository) RemoveUsage(context.Context, string, string) error {
	return errors.New("promotion usage repository: remove not implemented")
}

// GetUsage fetches the usage aggregate for a specific user.
func (r *PromotionUsageRepository) GetUsage(ctx context.Context, promoID string, userID string) (domain.PromotionUsage, error) {
	if r == nil || r.provider == nil {
		return domain.PromotionUsage{}, errors.New("promotion usage repository not initialised")
	}
	promoID = strings.TrimSpace(promoID)
	userID = strings.TrimSpace(userID)
	if promoID == "" {
		return domain.PromotionUsage{}, errors.New("promotion usage repository: promotion id is required")
	}
	if userID == "" {
		return domain.PromotionUsage{}, errors.New("promotion usage repository: user id is required")
	}

	coll, err := r.collection(ctx, promoID)
	if err != nil {
		return domain.PromotionUsage{}, err
	}

	snap, err := coll.Doc(userID).Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return domain.PromotionUsage{UserID: userID}, nil
		}
		return domain.PromotionUsage{}, pfirestore.WrapError("promotion_usage.get", err)
	}
	var doc promotionUsageDocument
	if err := snap.DataTo(&doc); err != nil {
		return domain.PromotionUsage{}, fmt.Errorf("promotion usage repository: decode usage: %w", err)
	}
	return decodePromotionUsage(snap.Ref.ID, doc), nil
}

// ListUsage returns promotion usage aggregates keyed by user.
func (r *PromotionUsageRepository) ListUsage(ctx context.Context, query repositories.PromotionUsageListQuery) (domain.CursorPage[domain.PromotionUsage], error) {
	if r == nil || r.provider == nil {
		return domain.CursorPage[domain.PromotionUsage]{}, errors.New("promotion usage repository not initialised")
	}
	promoID := strings.TrimSpace(query.PromotionID)
	if promoID == "" {
		return domain.CursorPage[domain.PromotionUsage]{}, errors.New("promotion usage repository: promotion id is required")
	}

	var limit = query.Pagination.PageSize
	if limit < 0 {
		limit = 0
	}
	fetchLimit := limit
	if limit > 0 {
		fetchLimit = limit + 1
	}

	sortField := normalizeUsageSort(query.SortBy)
	orderDirection := firestore.Desc
	if !query.SortDesc {
		orderDirection = firestore.Asc
	}

	applyQueryFilter := sortField == "times" && query.MinTimes > 0

	coll, err := r.collection(ctx, promoID)
	if err != nil {
		return domain.CursorPage[domain.PromotionUsage]{}, err
	}

	fsQuery := coll.OrderBy(sortField, orderDirection).OrderBy(firestore.DocumentID, orderDirection)
	if applyQueryFilter {
		fsQuery = fsQuery.Where("times", ">=", query.MinTimes)
	}

	if token := strings.TrimSpace(query.Pagination.PageToken); token != "" {
		value, docID, err := decodePromotionUsageToken(token)
		if err != nil {
			return domain.CursorPage[domain.PromotionUsage]{}, fmt.Errorf("%w: %s", repositories.ErrPromotionUsageInvalidPageToken, err.Error())
		}
		startAfter, err := usageStartAfter(sortField, value, docID)
		if err != nil {
			return domain.CursorPage[domain.PromotionUsage]{}, fmt.Errorf("%w: %s", repositories.ErrPromotionUsageInvalidPageToken, err.Error())
		}
		if len(startAfter) > 0 {
			fsQuery = fsQuery.StartAfter(startAfter...)
		}
	}

	iter := fsQuery.Documents(ctx)
	defer iter.Stop()

	rows := make([]usageRow, 0, fetchLimit)
	for {
		if fetchLimit > 0 && len(rows) >= fetchLimit {
			break
		}
		snap, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return domain.CursorPage[domain.PromotionUsage]{}, pfirestore.WrapError("promotion_usage.list", err)
		}
		var doc promotionUsageDocument
		if err := snap.DataTo(&doc); err != nil {
			return domain.CursorPage[domain.PromotionUsage]{}, fmt.Errorf("promotion usage repository: decode %s: %w", snap.Ref.ID, err)
		}
		if !applyQueryFilter && query.MinTimes > 0 && doc.Times < query.MinTimes {
			continue
		}
		rows = append(rows, usageRow{
			id:   snap.Ref.ID,
			data: doc,
		})
	}

	nextToken := ""
	if limit > 0 && len(rows) == fetchLimit {
		last := rows[len(rows)-1]
		nextToken = encodePromotionUsageToken(sortFieldValue(sortField, last.data), last.id)
		rows = rows[:len(rows)-1]
	}

	items := make([]domain.PromotionUsage, 0, len(rows))
	for _, row := range rows {
		items = append(items, decodePromotionUsage(row.id, row.data))
	}

	return domain.CursorPage[domain.PromotionUsage]{
		Items:         items,
		NextPageToken: nextToken,
	}, nil
}

func (r *PromotionUsageRepository) collection(ctx context.Context, promoID string) (*firestore.CollectionRef, error) {
	client, err := r.provider.Client(ctx)
	if err != nil {
		return nil, pfirestore.WrapError("promotion_usage.collection", err)
	}
	return client.Collection(promotionsCollection).Doc(promoID).Collection(promotionUsageCollection), nil
}

type promotionUsageDocument struct {
	UID         string     `firestore:"uid"`
	Times       int        `firestore:"times"`
	LastUsedAt  time.Time  `firestore:"lastUsedAt"`
	FirstUsedAt *time.Time `firestore:"firstUsedAt"`
	OrderRefs   []string   `firestore:"orderRefs"`
	Blocked     bool       `firestore:"blocked"`
	Notes       string     `firestore:"notes"`
}

type usageRow struct {
	id   string
	data promotionUsageDocument
}

func normalizeUsageSort(sort repositories.PromotionUsageSort) string {
	switch sort {
	case repositories.PromotionUsageSortTimes:
		return "times"
	default:
		return "lastUsedAt"
	}
}

func usageStartAfter(sortField string, value string, docID string) ([]any, error) {
	switch sortField {
	case "times":
		count, err := strconv.Atoi(value)
		if err != nil {
			return nil, err
		}
		return []any{count, docID}, nil
	case "lastUsedAt":
		if value == "" {
			return []any{time.Time{}, docID}, nil
		}
		ts, err := time.Parse(time.RFC3339Nano, value)
		if err != nil {
			return nil, err
		}
		return []any{ts, docID}, nil
	default:
		return nil, fmt.Errorf("unsupported sort field %q", sortField)
	}
}

func sortFieldValue(sortField string, doc promotionUsageDocument) string {
	switch sortField {
	case "times":
		return strconv.Itoa(doc.Times)
	case "lastUsedAt":
		if doc.LastUsedAt.IsZero() {
			return ""
		}
		return doc.LastUsedAt.UTC().Format(time.RFC3339Nano)
	default:
		return ""
	}
}

func decodePromotionUsageToken(token string) (string, string, error) {
	bytes, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return "", "", err
	}
	parts := strings.SplitN(string(bytes), "|", 2)
	if len(parts) != 2 {
		return "", "", errors.New("invalid token parts")
	}
	return parts[0], parts[1], nil
}

func encodePromotionUsageToken(sortValue string, docID string) string {
	payload := fmt.Sprintf("%s|%s", sortValue, docID)
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

func decodePromotionUsage(docID string, doc promotionUsageDocument) domain.PromotionUsage {
	userID := strings.TrimSpace(docID)
	if ref := strings.TrimSpace(doc.UID); ref != "" {
		userID = extractUserID(ref)
	}
	usage := domain.PromotionUsage{
		UserID:    userID,
		Times:     doc.Times,
		OrderRefs: cloneUsageStrings(doc.OrderRefs),
		Blocked:   doc.Blocked,
		Notes:     strings.TrimSpace(doc.Notes),
	}
	if !doc.LastUsedAt.IsZero() {
		usage.LastUsed = doc.LastUsedAt.UTC()
	}
	if doc.FirstUsedAt != nil && !doc.FirstUsedAt.IsZero() {
		first := doc.FirstUsedAt.UTC()
		usage.FirstUsed = &first
	}
	return usage
}

func extractUserID(path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return ""
	}
	parts := strings.Split(path, "/")
	return strings.TrimSpace(parts[len(parts)-1])
}

func cloneUsageStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
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
		out = append(out, trimmed)
	}
	return out
}
