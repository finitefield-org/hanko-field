package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const maxAdminExportBodySize = 4 * 1024

// AdminOperationsHandlers surfaces operational utilities such as data exports.
type AdminOperationsHandlers struct {
	authn           *auth.Authenticator
	exports         services.ExportService
	allowedEntities map[string]struct{}
}

// AdminOperationsOption customises the operations handler behaviour.
type AdminOperationsOption func(*AdminOperationsHandlers)

// NewAdminOperationsHandlers constructs handlers for admin operational endpoints.
func NewAdminOperationsHandlers(authn *auth.Authenticator, exports services.ExportService, opts ...AdminOperationsOption) *AdminOperationsHandlers {
	handler := &AdminOperationsHandlers{
		authn:   authn,
		exports: exports,
		allowedEntities: map[string]struct{}{
			"orders":     {},
			"users":      {},
			"promotions": {},
		},
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	return handler
}

// WithAdminExportEntities overrides the set of supported export entities.
func WithAdminExportEntities(entities ...string) AdminOperationsOption {
	return func(h *AdminOperationsHandlers) {
		if h == nil {
			return
		}
		h.allowedEntities = make(map[string]struct{}, len(entities))
		for _, entity := range entities {
			trimmed := strings.ToLower(strings.TrimSpace(entity))
			if trimmed != "" {
				h.allowedEntities[trimmed] = struct{}{}
			}
		}
	}
}

// Routes registers the admin operations routes.
func (h *AdminOperationsHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Post("/exports:bigquery-sync", h.startBigQuerySync)
}

type adminBigQueryExportRequest struct {
	Entities       []string                   `json:"entities"`
	TimeWindow     *adminBigQueryExportWindow `json:"timeWindow"`
	IdempotencyKey string                     `json:"idempotencyKey"`
}

type adminBigQueryExportWindow struct {
	From string `json:"from"`
	To   string `json:"to"`
}

type adminBigQueryExportResponse struct {
	Task adminSystemTaskResponse `json:"task"`
}

type adminSystemTaskResponse struct {
	ID             string         `json:"id"`
	Kind           string         `json:"kind"`
	Status         string         `json:"status"`
	RequestedBy    string         `json:"requested_by,omitempty"`
	IdempotencyKey string         `json:"idempotency_key,omitempty"`
	Parameters     map[string]any `json:"parameters,omitempty"`
	Metadata       map[string]any `json:"metadata,omitempty"`
	ResultRef      *string        `json:"result_ref,omitempty"`
	Error          string         `json:"error,omitempty"`
	CreatedAt      string         `json:"created_at"`
	UpdatedAt      string         `json:"updated_at"`
	StartedAt      string         `json:"started_at,omitempty"`
	CompletedAt    string         `json:"completed_at,omitempty"`
}

func (h *AdminOperationsHandlers) startBigQuerySync(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h.exports == nil {
		httpx.WriteError(ctx, w, httpx.NewError("export_service_unavailable", "export service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	body, err := readLimitedBody(r, maxAdminExportBodySize)
	switch {
	case err == nil:
	case errors.Is(err, errBodyTooLarge):
		httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body too large", http.StatusRequestEntityTooLarge))
		return
	case errors.Is(err, errEmptyBody):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_export_request", "request body is required", http.StatusBadRequest))
		return
	default:
		httpx.WriteError(ctx, w, httpx.NewError("invalid_export_request", "failed to read request body", http.StatusBadRequest))
		return
	}

	var payload adminBigQueryExportRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_json", "request body must be valid JSON", http.StatusBadRequest))
		return
	}

	entities, err := h.resolveEntities(payload)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_entities", err.Error(), http.StatusBadRequest))
		return
	}

	window, err := resolveExportWindow(payload)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_time_window", err.Error(), http.StatusBadRequest))
		return
	}

	idempotencyKey := strings.TrimSpace(payload.IdempotencyKey)
	if idempotencyKey == "" {
		idempotencyKey = strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	}

	cmd := services.BigQueryExportCommand{
		ActorID:        strings.TrimSpace(identity.UID),
		Entities:       entities,
		IdempotencyKey: idempotencyKey,
	}
	if window != nil {
		cmd.Window = window
	}

	task, err := h.exports.StartBigQuerySync(ctx, cmd)
	if err != nil {
		writeAdminExportError(ctx, w, err)
		return
	}

	response := adminBigQueryExportResponse{
		Task: newAdminSystemTaskResponse(task),
	}
	writeJSONResponse(w, http.StatusAccepted, response)
}

func (h *AdminOperationsHandlers) resolveEntities(payload adminBigQueryExportRequest) ([]string, error) {
	raw := payload.Entities
	if len(raw) == 0 {
		return nil, errors.New("entities must be provided")
	}

	seen := make(map[string]struct{}, len(raw))
	result := make([]string, 0, len(raw))

	for _, entity := range raw {
		key := strings.ToLower(strings.TrimSpace(entity))
		if key == "" {
			continue
		}
		if _, allowed := h.allowedEntities[key]; !allowed {
			return nil, errors.New("unsupported entity: " + entity)
		}
		if _, duplicated := seen[key]; duplicated {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, key)
	}

	if len(result) == 0 {
		return nil, errors.New("entities must be provided")
	}

	return result, nil
}

func resolveExportWindow(payload adminBigQueryExportRequest) (*services.ExportTimeWindow, error) {
	windowPayload := payload.TimeWindow
	if windowPayload == nil {
		return nil, nil
	}

	var window services.ExportTimeWindow
	if from := strings.TrimSpace(windowPayload.From); from != "" {
		parsed, err := parseTimeParam(from)
		if err != nil {
			return nil, errors.New("from must be RFC3339 timestamp")
		}
		value := parsed.UTC()
		window.From = &value
	}
	if to := strings.TrimSpace(windowPayload.To); to != "" {
		parsed, err := parseTimeParam(to)
		if err != nil {
			return nil, errors.New("to must be RFC3339 timestamp")
		}
		value := parsed.UTC()
		window.To = &value
	}

	if window.From != nil && window.To != nil && window.From.After(*window.To) {
		return nil, errors.New("from must be before to")
	}

	return &window, nil
}

func newAdminSystemTaskResponse(task services.SystemTask) adminSystemTaskResponse {
	resp := adminSystemTaskResponse{
		ID:             strings.TrimSpace(task.ID),
		Kind:           strings.TrimSpace(task.Kind),
		Status:         string(task.Status),
		CreatedAt:      formatTime(task.CreatedAt),
		UpdatedAt:      formatTime(task.UpdatedAt),
		Parameters:     cloneMap(task.Parameters),
		Metadata:       cloneMap(task.Metadata),
		ResultRef:      cloneStringPointer(task.ResultRef),
		IdempotencyKey: strings.TrimSpace(task.IdempotencyKey),
	}
	if task.RequestedBy != "" {
		resp.RequestedBy = strings.TrimSpace(task.RequestedBy)
	}
	if task.ErrorMessage != nil {
		resp.Error = strings.TrimSpace(*task.ErrorMessage)
	}
	if task.StartedAt != nil {
		resp.StartedAt = formatOptionalTime(task.StartedAt)
	}
	if task.CompletedAt != nil {
		resp.CompletedAt = formatOptionalTime(task.CompletedAt)
	}
	return resp
}

func writeAdminExportError(ctx context.Context, w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, services.ErrExportInvalidInput):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_export_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrExportConflict):
		httpx.WriteError(ctx, w, httpx.NewError("export_conflict", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrExportUnavailable):
		httpx.WriteError(ctx, w, httpx.NewError("export_service_unavailable", "export service unavailable", http.StatusServiceUnavailable))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("export_failed", err.Error(), http.StatusInternalServerError))
	}
}

func formatOptionalTime(value *time.Time) string {
	if value == nil {
		return ""
	}
	return formatTime(*value)
}
