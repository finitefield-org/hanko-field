package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/oklog/ulid/v2"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const maxInternalAuditLogBody = 16 * 1024

// InternalAuditLogHandlers exposes endpoints for recording audit events from internal services.
type InternalAuditLogHandlers struct {
	audit services.AuditLogService
	clock func() time.Time
	idGen func() string
}

// InternalAuditLogOption customises handler construction.
type InternalAuditLogOption func(*InternalAuditLogHandlers)

// NewInternalAuditLogHandlers constructs handlers for internal audit log writes.
func NewInternalAuditLogHandlers(audit services.AuditLogService, opts ...InternalAuditLogOption) *InternalAuditLogHandlers {
	handler := &InternalAuditLogHandlers{
		audit: audit,
		clock: time.Now,
		idGen: func() string { return ulid.Make().String() },
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	return handler
}

// WithInternalAuditLogClock overrides the clock used for timestamp parsing defaults.
func WithInternalAuditLogClock(clock func() time.Time) InternalAuditLogOption {
	return func(h *InternalAuditLogHandlers) {
		if clock != nil {
			h.clock = clock
		}
	}
}

// WithInternalAuditLogIDGenerator overrides the ID generator used for entries.
func WithInternalAuditLogIDGenerator(generator func() string) InternalAuditLogOption {
	return func(h *InternalAuditLogHandlers) {
		if generator != nil {
			h.idGen = generator
		}
	}
}

// Routes registers internal audit endpoints.
func (h *InternalAuditLogHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/audit-log", h.appendAuditLog)
}

type internalAuditLogRequest struct {
	Actor                 string                          `json:"actor"`
	ActorType             string                          `json:"actorType"`
	Action                string                          `json:"action"`
	TargetRef             string                          `json:"targetRef"`
	Severity              string                          `json:"severity"`
	RequestID             string                          `json:"requestId"`
	OccurredAt            string                          `json:"occurredAt"`
	Metadata              map[string]any                  `json:"metadata"`
	Diff                  map[string]internalAuditLogDiff `json:"diff"`
	SensitiveMetadataKeys []string                        `json:"sensitiveMetadataKeys"`
	SensitiveDiffKeys     []string                        `json:"sensitiveDiffKeys"`
	IPAddress             string                          `json:"ipAddress"`
	UserAgent             string                          `json:"userAgent"`
}

type internalAuditLogDiff struct {
	Before any `json:"before"`
	After  any `json:"after"`
}

type internalAuditLogResponse struct {
	ID string `json:"id"`
}

func (h *InternalAuditLogHandlers) appendAuditLog(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h == nil || h.audit == nil {
		httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "audit log service unavailable", http.StatusServiceUnavailable))
		return
	}

	if identity, ok := auth.ServiceIdentityFromContext(ctx); !ok || identity == nil || strings.TrimSpace(identity.Subject) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "service authentication required", http.StatusUnauthorized))
		return
	}

	body := http.MaxBytesReader(w, r.Body, maxInternalAuditLogBody)
	defer body.Close()

	decoder := json.NewDecoder(body)
	decoder.DisallowUnknownFields()

	var req internalAuditLogRequest
	if err := decoder.Decode(&req); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON payload", http.StatusBadRequest))
		return
	}

	if decoder.More() {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "unexpected data after payload", http.StatusBadRequest))
		return
	}

	actor := strings.TrimSpace(req.Actor)
	if actor == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "actor is required", http.StatusBadRequest))
		return
	}
	targetRef := strings.TrimSpace(req.TargetRef)
	if targetRef == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "targetRef is required", http.StatusBadRequest))
		return
	}
	action := strings.TrimSpace(req.Action)
	if action == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "action is required", http.StatusBadRequest))
		return
	}

	var occurredAt time.Time
	if trimmed := strings.TrimSpace(req.OccurredAt); trimmed != "" {
		parsed, err := time.Parse(time.RFC3339, trimmed)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "occurredAt must be RFC3339", http.StatusBadRequest))
			return
		}
		occurredAt = parsed
	}

	metadata := cloneAnyMap(req.Metadata)
	diff := make(map[string]services.AuditLogDiff, len(req.Diff))
	for key, delta := range req.Diff {
		trimmedKey := strings.TrimSpace(key)
		if trimmedKey == "" {
			continue
		}
		diff[trimmedKey] = services.AuditLogDiff{
			Before: delta.Before,
			After:  delta.After,
		}
	}

	record := services.AuditLogRecord{
		ID:                    h.generateID(),
		Actor:                 actor,
		ActorType:             strings.TrimSpace(req.ActorType),
		Action:                action,
		TargetRef:             targetRef,
		Severity:              strings.TrimSpace(req.Severity),
		RequestID:             strings.TrimSpace(req.RequestID),
		OccurredAt:            occurredAt,
		Metadata:              metadata,
		Diff:                  diff,
		SensitiveMetadataKeys: sanitizeKeySlice(req.SensitiveMetadataKeys),
		SensitiveDiffKeys:     sanitizeKeySlice(req.SensitiveDiffKeys),
		IPAddress:             strings.TrimSpace(req.IPAddress),
		UserAgent:             strings.TrimSpace(req.UserAgent),
	}

	h.audit.Record(ctx, record)

	writeJSONResponse(w, http.StatusCreated, internalAuditLogResponse{ID: record.ID})
}

func (h *InternalAuditLogHandlers) generateID() string {
	if h == nil || h.idGen == nil {
		return ulid.Make().String()
	}
	id := strings.TrimSpace(h.idGen())
	if id == "" {
		return ulid.Make().String()
	}
	return id
}

func sanitizeKeySlice(keys []string) []string {
	if len(keys) == 0 {
		return nil
	}
	result := make([]string, 0, len(keys))
	seen := make(map[string]struct{}, len(keys))
	for _, raw := range keys {
		trimmed := strings.TrimSpace(raw)
		if trimmed == "" {
			continue
		}
		lower := strings.ToLower(trimmed)
		if _, exists := seen[lower]; exists {
			continue
		}
		seen[lower] = struct{}{}
		result = append(result, trimmed)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}
