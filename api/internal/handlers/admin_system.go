package handlers

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const (
	defaultSystemListPageSize = 50
	maxSystemListPageSize     = 200
)

// AdminSystemHandlers exposes system monitoring endpoints for operations staff.
type AdminSystemHandlers struct {
	authn           *auth.Authenticator
	system          services.SystemService
	defaultPageSize int
	maximumPageSize int
}

// AdminSystemOption customises the behaviour of system handlers.
type AdminSystemOption func(*AdminSystemHandlers)

// WithAdminSystemPageSizes overrides the default and maximum page sizes for list endpoints.
func WithAdminSystemPageSizes(defaultSize, maxSize int) AdminSystemOption {
	return func(h *AdminSystemHandlers) {
		if h == nil {
			return
		}
		if defaultSize > 0 {
			h.defaultPageSize = defaultSize
		}
		if maxSize > 0 {
			h.maximumPageSize = maxSize
		}
	}
}

// NewAdminSystemHandlers constructs handlers for system error and task listings.
func NewAdminSystemHandlers(authn *auth.Authenticator, system services.SystemService, opts ...AdminSystemOption) *AdminSystemHandlers {
	handler := &AdminSystemHandlers{
		authn:           authn,
		system:          system,
		defaultPageSize: defaultSystemListPageSize,
		maximumPageSize: maxSystemListPageSize,
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	return handler
}

// Routes registers system routes under the provided router.
func (h *AdminSystemHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Group(func(rt chi.Router) {
		if h.authn != nil {
			rt.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
		}
		rt.Get("/system/errors", h.listSystemErrors)
		rt.Get("/system/tasks", h.listSystemTasks)
	})
}

func (h *AdminSystemHandlers) listSystemErrors(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h.system == nil {
		httpx.WriteError(ctx, w, httpx.NewError("system_service_unavailable", "system service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := h.requireAdminOrStaff(ctx, w)
	if !ok {
		return
	}

	query := r.URL.Query()

	pageSize, err := h.parsePageSize(query)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", err.Error(), http.StatusBadRequest))
		return
	}

	var (
		rangeFrom *time.Time
		rangeTo   *time.Time
	)
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("since"), query.Get("from"), query.Get("start"))); raw != "" {
		ts, err := parseTimeParam(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_since", "since must be RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		value := ts
		rangeFrom = &value
	}
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("until"), query.Get("to"), query.Get("end"))); raw != "" {
		ts, err := parseTimeParam(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_until", "until must be RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		value := ts
		rangeTo = &value
	}
	if rangeFrom != nil && rangeTo != nil && rangeFrom.After(*rangeTo) {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_range", "since must be before until", http.StatusBadRequest))
		return
	}

	filter := services.SystemErrorFilter{
		Sources:    collectCSVParams(query, "source", "sources"),
		JobTypes:   collectCSVParams(query, "jobType", "job_type", "job"),
		Statuses:   collectCSVParams(query, "status", "statuses"),
		Severities: collectCSVParams(query, "severity", "severities", "level"),
		Search:     strings.TrimSpace(firstNonEmpty(query.Get("search"), query.Get("q"))),
		DateRange: domain.RangeQuery[time.Time]{
			From: rangeFrom,
			To:   rangeTo,
		},
		Pagination: services.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(firstNonEmpty(query.Get("pageToken"), query.Get("page_token"))),
		},
	}

	page, err := h.system.ListSystemErrors(ctx, filter)
	if err != nil {
		h.writeSystemError(ctx, w, err, "system_errors_unavailable", "failed to list system errors")
		return
	}

	if token := strings.TrimSpace(page.NextPageToken); token != "" {
		w.Header().Set("X-Next-Page-Token", token)
	}

	items := make([]adminSystemErrorResponse, 0, len(page.Items))
	for _, entry := range page.Items {
		items = append(items, newAdminSystemErrorResponse(entry, identity))
	}

	response := adminSystemErrorListResponse{
		Items:         items,
		NextPageToken: strings.TrimSpace(page.NextPageToken),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminSystemHandlers) listSystemTasks(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h.system == nil {
		httpx.WriteError(ctx, w, httpx.NewError("system_service_unavailable", "system service unavailable", http.StatusServiceUnavailable))
		return
	}

	if _, ok := h.requireAdminOrStaff(ctx, w); !ok {
		return
	}

	query := r.URL.Query()

	pageSize, err := h.parsePageSize(query)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", err.Error(), http.StatusBadRequest))
		return
	}

	statuses, err := parseTaskStatuses(collectCSVParams(query, "status", "statuses"))
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_status", err.Error(), http.StatusBadRequest))
		return
	}

	var (
		rangeFrom *time.Time
		rangeTo   *time.Time
	)
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("since"), query.Get("from"), query.Get("start"))); raw != "" {
		ts, err := parseTimeParam(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_since", "since must be RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		value := ts
		rangeFrom = &value
	}
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("until"), query.Get("to"), query.Get("end"))); raw != "" {
		ts, err := parseTimeParam(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_until", "until must be RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		value := ts
		rangeTo = &value
	}
	if rangeFrom != nil && rangeTo != nil && rangeFrom.After(*rangeTo) {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_range", "since must be before until", http.StatusBadRequest))
		return
	}

	filter := services.SystemTaskFilter{
		Statuses:    statuses,
		Kinds:       collectCSVParams(query, "kind", "kinds", "jobType", "job_type"),
		RequestedBy: strings.TrimSpace(firstNonEmpty(query.Get("requestedBy"), query.Get("requested_by"), query.Get("actor"))),
		DateRange: domain.RangeQuery[time.Time]{
			From: rangeFrom,
			To:   rangeTo,
		},
		Pagination: services.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(firstNonEmpty(query.Get("pageToken"), query.Get("page_token"))),
		},
	}

	page, err := h.system.ListSystemTasks(ctx, filter)
	if err != nil {
		h.writeSystemError(ctx, w, err, "system_tasks_unavailable", "failed to list system tasks")
		return
	}

	if token := strings.TrimSpace(page.NextPageToken); token != "" {
		w.Header().Set("X-Next-Page-Token", token)
	}

	items := make([]adminSystemTaskResponse, 0, len(page.Items))
	for _, task := range page.Items {
		items = append(items, newAdminSystemTaskResponse(task))
	}

	response := adminSystemTaskListResponse{
		Items:         items,
		NextPageToken: strings.TrimSpace(page.NextPageToken),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminSystemHandlers) requireAdminOrStaff(ctx context.Context, w http.ResponseWriter) (*auth.Identity, bool) {
	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return nil, false
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return nil, false
	}
	return identity, true
}

func (h *AdminSystemHandlers) parsePageSize(values url.Values) (int, error) {
	defaultSize := h.defaultPageSize
	if defaultSize <= 0 {
		defaultSize = defaultSystemListPageSize
	}
	maxSize := h.maximumPageSize
	if maxSize <= 0 {
		maxSize = maxSystemListPageSize
	}

	raw := strings.TrimSpace(firstNonEmpty(values.Get("pageSize"), values.Get("page_size"), values.Get("limit")))
	if raw == "" {
		return defaultSize, nil
	}

	size, err := strconv.Atoi(raw)
	if err != nil {
		return 0, errors.New("pageSize must be an integer")
	}
	if size < 0 {
		return 0, errors.New("pageSize must be non-negative")
	}
	if size == 0 {
		return defaultSize, nil
	}
	if maxSize > 0 && size > maxSize {
		return maxSize, nil
	}
	return size, nil
}

func (h *AdminSystemHandlers) writeSystemError(ctx context.Context, w http.ResponseWriter, err error, code, message string) {
	switch {
	case err == nil:
		return
	case errors.Is(err, context.DeadlineExceeded):
		httpx.WriteError(ctx, w, httpx.NewError(code, "request timed out", http.StatusGatewayTimeout))
	case errors.Is(err, context.Canceled):
		httpx.WriteError(ctx, w, httpx.NewError(code, "request cancelled", http.StatusRequestTimeout))
	case strings.Contains(strings.ToLower(err.Error()), "not configured"):
		httpx.WriteError(ctx, w, httpx.NewError("system_not_configured", "system monitoring not configured", http.StatusServiceUnavailable))
	default:
		httpx.WriteError(ctx, w, httpx.NewError(code, message, http.StatusInternalServerError))
	}
}

type adminSystemErrorListResponse struct {
	Items         []adminSystemErrorResponse `json:"items"`
	NextPageToken string                     `json:"next_page_token,omitempty"`
}

type adminSystemErrorResponse struct {
	ID                string         `json:"id"`
	Source            string         `json:"source,omitempty"`
	Queue             string         `json:"queue,omitempty"`
	Kind              string         `json:"kind,omitempty"`
	JobType           string         `json:"job_type,omitempty"`
	Status            string         `json:"status,omitempty"`
	Severity          string         `json:"severity,omitempty"`
	Code              string         `json:"code,omitempty"`
	Message           string         `json:"message"`
	Occurrences       int            `json:"occurrences"`
	Retryable         bool           `json:"retryable"`
	RetryEndpoint     string         `json:"retry_endpoint,omitempty"`
	RetryMethod       string         `json:"retry_method,omitempty"`
	TaskRef           string         `json:"task_ref,omitempty"`
	Metadata          map[string]any `json:"metadata,omitempty"`
	Sensitive         map[string]any `json:"sensitive,omitempty"`
	SensitiveRedacted bool           `json:"sensitive_redacted,omitempty"`
	FirstOccurredAt   string         `json:"first_occurred_at,omitempty"`
	LastOccurredAt    string         `json:"last_occurred_at,omitempty"`
	CreatedAt         string         `json:"created_at,omitempty"`
	UpdatedAt         string         `json:"updated_at,omitempty"`
}

type adminSystemTaskListResponse struct {
	Items         []adminSystemTaskResponse `json:"items"`
	NextPageToken string                    `json:"next_page_token,omitempty"`
}

func newAdminSystemErrorResponse(err services.SystemError, identity *auth.Identity) adminSystemErrorResponse {
	resp := adminSystemErrorResponse{
		ID:              strings.TrimSpace(err.ID),
		Source:          strings.TrimSpace(err.Source),
		Queue:           strings.TrimSpace(err.Queue),
		Kind:            strings.TrimSpace(err.Kind),
		JobType:         strings.TrimSpace(err.JobType),
		Status:          strings.TrimSpace(err.Status),
		Severity:        strings.TrimSpace(err.Severity),
		Code:            strings.TrimSpace(err.Code),
		Occurrences:     err.Occurrences,
		Retryable:       err.Retryable,
		RetryMethod:     strings.TrimSpace(err.RetryMethod),
		FirstOccurredAt: formatTime(err.FirstOccurredAt),
		LastOccurredAt:  formatTime(err.LastOccurredAt),
		CreatedAt:       formatTime(err.CreatedAt),
		UpdatedAt:       formatTime(err.UpdatedAt),
	}
	if err.RetryEndpoint != nil {
		resp.RetryEndpoint = strings.TrimSpace(*err.RetryEndpoint)
	}
	if err.TaskRef != nil {
		resp.TaskRef = strings.TrimSpace(*err.TaskRef)
	}
	if len(err.Metadata) > 0 {
		resp.Metadata = cloneAnyMap(err.Metadata)
	}

	safeMessage := strings.TrimSpace(err.SafeMessage)
	fullMessage := strings.TrimSpace(err.Message)
	isAdmin := identity != nil && identity.HasRole(auth.RoleAdmin)
	if isAdmin {
		if fullMessage != "" {
			resp.Message = fullMessage
		} else {
			resp.Message = safeMessage
		}
		if len(err.Sensitive) > 0 {
			resp.Sensitive = cloneAnyMap(err.Sensitive)
		}
	} else {
		if safeMessage != "" {
			resp.Message = safeMessage
		} else {
			resp.Message = fullMessage
		}
		if len(err.Sensitive) > 0 {
			resp.SensitiveRedacted = true
		}
	}
	if resp.Message == "" {
		resp.Message = "unknown error"
	}
	return resp
}

func collectCSVParams(values url.Values, keys ...string) []string {
	if len(keys) == 0 {
		return nil
	}
	seen := make(map[string]struct{})
	result := make([]string, 0)
	for _, key := range keys {
		raw := strings.TrimSpace(values.Get(key))
		if raw == "" {
			continue
		}
		for _, part := range strings.Split(raw, ",") {
			token := strings.TrimSpace(part)
			if token == "" {
				continue
			}
			lower := strings.ToLower(token)
			if _, ok := seen[lower]; ok {
				continue
			}
			seen[lower] = struct{}{}
			result = append(result, token)
		}
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func parseTaskStatuses(values []string) ([]services.SystemTaskStatus, error) {
	if len(values) == 0 {
		return nil, nil
	}
	seen := make(map[services.SystemTaskStatus]struct{}, len(values))
	result := make([]services.SystemTaskStatus, 0, len(values))
	for _, value := range values {
		token := strings.TrimSpace(value)
		if token == "" {
			continue
		}
		status := services.SystemTaskStatus(strings.ToLower(token))
		switch status {
		case services.SystemTaskStatusPending,
			services.SystemTaskStatusRunning,
			services.SystemTaskStatusCompleted,
			services.SystemTaskStatusFailed:
			if _, ok := seen[status]; ok {
				continue
			}
			seen[status] = struct{}{}
			result = append(result, status)
		default:
			return nil, fmt.Errorf("unsupported status %q", token)
		}
	}
	if len(result) == 0 {
		return nil, nil
	}
	return result, nil
}
