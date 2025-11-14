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
	"github.com/oklog/ulid/v2"

	domain "github.com/hanko-field/api/internal/domain"
	pfirestore "github.com/hanko-field/api/internal/platform/firestore"
	"github.com/hanko-field/api/internal/repositories"
)

const auditLogsCollection = "auditLogs"

// AuditLogRepository persists immutable audit log entries in Firestore.
type AuditLogRepository struct {
	logs *pfirestore.BaseRepository[auditLogDocument]
}

// NewAuditLogRepository constructs a Firestore-backed audit log repository.
func NewAuditLogRepository(provider *pfirestore.Provider) (*AuditLogRepository, error) {
	if provider == nil {
		return nil, errors.New("audit log repository: firestore provider is required")
	}
	return &AuditLogRepository{
		logs: pfirestore.NewBaseRepository[auditLogDocument](provider, auditLogsCollection, nil, nil),
	}, nil
}

// Append writes the supplied audit entry, generating an ID when absent.
func (r *AuditLogRepository) Append(ctx context.Context, entry domain.AuditLogEntry) error {
	if r == nil || r.logs == nil {
		return errors.New("audit log repository not initialised")
	}
	if entry.CreatedAt.IsZero() {
		return errors.New("audit log repository: createdAt is required")
	}
	id := strings.TrimSpace(entry.ID)
	if id == "" {
		id = ulid.Make().String()
	}
	doc := newAuditLogDocument(entry)
	if _, err := r.logs.Set(ctx, id, doc); err != nil {
		return err
	}
	return nil
}

// List retrieves audit log entries applying filters and pagination.
func (r *AuditLogRepository) List(ctx context.Context, filter repositories.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	if r == nil || r.logs == nil {
		return domain.CursorPage[domain.AuditLogEntry]{}, errors.New("audit log repository not initialised")
	}

	pageSize := filter.Pagination.PageSize
	if pageSize <= 0 {
		pageSize = 50
	} else if pageSize > 200 {
		pageSize = 200
	}
	fetchLimit := pageSize + 1

	var startCreated time.Time
	var startID string
	token := strings.TrimSpace(filter.Pagination.PageToken)
	if token != "" {
		createdAt, docID, err := decodeAuditLogPageToken(token)
		if err != nil {
			return domain.CursorPage[domain.AuditLogEntry]{}, err
		}
		startCreated = createdAt
		startID = docID
	}

	docs, err := r.logs.Query(ctx, func(q firestore.Query) firestore.Query {
		if trimmed := strings.TrimSpace(filter.TargetRef); trimmed != "" {
			q = q.Where("targetRef", "==", trimmed)
		}
		if trimmed := strings.TrimSpace(filter.Actor); trimmed != "" {
			q = q.Where("actor", "==", trimmed)
		}
		if trimmed := strings.TrimSpace(filter.ActorType); trimmed != "" {
			q = q.Where("actorType", "==", trimmed)
		}
		if trimmed := strings.TrimSpace(filter.Action); trimmed != "" {
			q = q.Where("action", "==", trimmed)
		}
		if filter.DateRange.From != nil && !filter.DateRange.From.IsZero() {
			q = q.Where("createdAt", ">=", filter.DateRange.From.UTC())
		}
		if filter.DateRange.To != nil && !filter.DateRange.To.IsZero() {
			q = q.Where("createdAt", "<=", filter.DateRange.To.UTC())
		}
		q = q.OrderBy("createdAt", firestore.Desc).OrderBy(firestore.DocumentID, firestore.Desc)
		if !startCreated.IsZero() && strings.TrimSpace(startID) != "" {
			q = q.StartAfter(startCreated, startID)
		}
		return q.Limit(fetchLimit)
	})
	if err != nil {
		return domain.CursorPage[domain.AuditLogEntry]{}, err
	}

	nextToken := ""
	if len(docs) == fetchLimit {
		last := docs[len(docs)-1]
		nextToken = encodeAuditLogPageToken(last.Data.CreatedAt, last.ID)
		docs = docs[:len(docs)-1]
	}

	items := make([]domain.AuditLogEntry, 0, len(docs))
	for _, doc := range docs {
		items = append(items, doc.Data.toDomain(doc.ID))
	}

	return domain.CursorPage[domain.AuditLogEntry]{
		Items:         items,
		NextPageToken: nextToken,
	}, nil
}

type auditLogDocument struct {
	Actor     string         `firestore:"actor"`
	ActorType string         `firestore:"actorType,omitempty"`
	Action    string         `firestore:"action"`
	TargetRef string         `firestore:"targetRef"`
	Metadata  map[string]any `firestore:"metadata,omitempty"`
	Diff      map[string]any `firestore:"diff,omitempty"`
	IPHash    string         `firestore:"ipHash,omitempty"`
	UserAgent string         `firestore:"userAgent,omitempty"`
	Severity  string         `firestore:"severity,omitempty"`
	RequestID string         `firestore:"requestId,omitempty"`
	CreatedAt time.Time      `firestore:"createdAt"`
}

func newAuditLogDocument(entry domain.AuditLogEntry) auditLogDocument {
	return auditLogDocument{
		Actor:     strings.TrimSpace(entry.Actor),
		ActorType: strings.TrimSpace(entry.ActorType),
		Action:    strings.TrimSpace(entry.Action),
		TargetRef: strings.TrimSpace(entry.TargetRef),
		Metadata:  copyAnyMap(entry.Metadata),
		Diff:      copyAnyMap(entry.Diff),
		IPHash:    strings.TrimSpace(entry.IPHash),
		UserAgent: strings.TrimSpace(entry.UserAgent),
		Severity:  strings.TrimSpace(entry.Severity),
		RequestID: strings.TrimSpace(entry.RequestID),
		CreatedAt: entry.CreatedAt.UTC(),
	}
}

func (d auditLogDocument) toDomain(id string) domain.AuditLogEntry {
	entry := domain.AuditLogEntry{
		ID:        strings.TrimSpace(id),
		Actor:     strings.TrimSpace(d.Actor),
		ActorType: strings.TrimSpace(d.ActorType),
		Action:    strings.TrimSpace(d.Action),
		TargetRef: strings.TrimSpace(d.TargetRef),
		Metadata:  copyAnyMap(d.Metadata),
		Diff:      copyAnyMap(d.Diff),
		IPHash:    strings.TrimSpace(d.IPHash),
		UserAgent: strings.TrimSpace(d.UserAgent),
		Severity:  strings.TrimSpace(d.Severity),
		RequestID: strings.TrimSpace(d.RequestID),
		CreatedAt: d.CreatedAt.UTC(),
	}
	return entry
}

func encodeAuditLogPageToken(createdAt time.Time, id string) string {
	createdAt = createdAt.UTC().Truncate(time.Microsecond)
	payload := fmt.Sprintf("%d|%s", createdAt.UnixMicro(), strings.TrimSpace(id))
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

func decodeAuditLogPageToken(token string) (time.Time, string, error) {
	if strings.TrimSpace(token) == "" {
		return time.Time{}, "", nil
	}
	decoded, err := base64.RawURLEncoding.DecodeString(strings.TrimSpace(token))
	if err != nil {
		return time.Time{}, "", fmt.Errorf("audit log repository: invalid page token")
	}
	parts := strings.SplitN(string(decoded), "|", 2)
	if len(parts) != 2 {
		return time.Time{}, "", fmt.Errorf("audit log repository: invalid page token")
	}
	unixMicros, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return time.Time{}, "", fmt.Errorf("audit log repository: invalid page token")
	}
	createdAt := time.UnixMicro(unixMicros).UTC()
	id := strings.TrimSpace(parts[1])
	if id == "" {
		return time.Time{}, "", fmt.Errorf("audit log repository: invalid page token")
	}
	return createdAt, id, nil
}

func copyAnyMap(src map[string]any) map[string]any {
	if len(src) == 0 {
		return nil
	}
	dst := make(map[string]any, len(src))
	for key, value := range src {
		dst[key] = value
	}
	return dst
}
