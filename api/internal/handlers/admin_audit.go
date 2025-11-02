package handlers

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"net/http"
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
	defaultAuditLogPageSize = 50
	maxAuditLogPageSize     = 200
)

// AdminAuditHandlers exposes endpoints for querying audit logs.
type AdminAuditHandlers struct {
	authn *auth.Authenticator
	audit services.AuditLogService
}

// NewAdminAuditHandlers constructs admin audit handlers.
func NewAdminAuditHandlers(authn *auth.Authenticator, audit services.AuditLogService) *AdminAuditHandlers {
	return &AdminAuditHandlers{
		authn: authn,
		audit: audit,
	}
}

// Routes registers admin audit endpoints.
func (h *AdminAuditHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Get("/audit-logs", h.listAuditLogs)
}

func (h *AdminAuditHandlers) listAuditLogs(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.audit == nil {
		httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "audit log service unavailable", http.StatusServiceUnavailable))
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

	query := r.URL.Query()
	targetRef := strings.TrimSpace(firstNonEmpty(query.Get("targetRef"), query.Get("target_ref")))
	if targetRef == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "targetRef parameter is required", http.StatusBadRequest))
		return
	}

	pageSize := defaultAuditLogPageSize
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("pageSize"), query.Get("page_size"))); raw != "" {
		size, err := strconv.Atoi(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", "pageSize must be an integer", http.StatusBadRequest))
			return
		}
		switch {
		case size <= 0:
			pageSize = defaultAuditLogPageSize
		case size > maxAuditLogPageSize:
			pageSize = maxAuditLogPageSize
		default:
			pageSize = size
		}
	}

	var (
		fromTime *time.Time
		toTime   *time.Time
	)
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("from"), query.Get("created_after"), query.Get("start"))); raw != "" {
		parsed, err := time.Parse(time.RFC3339, raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_from", "from must be an RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		from := parsed.UTC()
		fromTime = &from
	}
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("to"), query.Get("created_before"), query.Get("end"))); raw != "" {
		parsed, err := time.Parse(time.RFC3339, raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_to", "to must be an RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		to := parsed.UTC()
		toTime = &to
	}
	if fromTime != nil && toTime != nil && fromTime.After(*toTime) {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_range", "from must be before to", http.StatusBadRequest))
		return
	}

	filter := services.AuditLogFilter{
		TargetRef: targetRef,
		Pagination: services.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(firstNonEmpty(query.Get("pageToken"), query.Get("page_token"))),
		},
	}
	if actor := strings.TrimSpace(firstNonEmpty(query.Get("actor"), query.Get("actor_ref"))); actor != "" {
		filter.Actor = actor
	}
	if actorType := strings.TrimSpace(firstNonEmpty(query.Get("actorType"), query.Get("actor_type"))); actorType != "" {
		filter.ActorType = actorType
	}
	if action := strings.TrimSpace(query.Get("action")); action != "" {
		filter.Action = action
	}
	if fromTime != nil || toTime != nil {
		filter.DateRange = domain.RangeQuery[time.Time]{From: fromTime, To: toTime}
	}

	page, err := h.audit.List(ctx, filter)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("audit_logs_unavailable", "failed to list audit logs", http.StatusInternalServerError))
		return
	}

	entries := h.buildAuditResponses(page.Items, identity)
	if strings.EqualFold(strings.TrimSpace(query.Get("format")), "csv") {
		if page.NextPageToken != "" {
			w.Header().Set("X-Next-Page-Token", page.NextPageToken)
		}
		if err := writeAuditLogCSV(w, targetRef, entries); err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("export_failed", "failed to render csv export", http.StatusInternalServerError))
		}
		return
	}

	response := auditLogListResponse{
		Items:         entries,
		NextPageToken: page.NextPageToken,
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminAuditHandlers) buildAuditResponses(items []domain.AuditLogEntry, identity *auth.Identity) []auditLogEntryResponse {
	if len(items) == 0 {
		return []auditLogEntryResponse{}
	}
	result := make([]auditLogEntryResponse, 0, len(items))
	isAdmin := identity != nil && identity.HasRole(auth.RoleAdmin)
	for _, entry := range items {
		resp := auditLogEntryResponse{
			ID:        strings.TrimSpace(entry.ID),
			Actor:     strings.TrimSpace(entry.Actor),
			ActorType: strings.TrimSpace(entry.ActorType),
			Action:    strings.TrimSpace(entry.Action),
			TargetRef: strings.TrimSpace(entry.TargetRef),
			Severity:  strings.TrimSpace(entry.Severity),
			UserAgent: strings.TrimSpace(entry.UserAgent),
			CreatedAt: formatTime(entry.CreatedAt),
		}
		if isAdmin {
			resp.RequestID = strings.TrimSpace(entry.RequestID)
			resp.IPHash = strings.TrimSpace(entry.IPHash)
			if len(entry.Metadata) > 0 {
				resp.Metadata = cloneAnyMap(entry.Metadata)
			}
			if len(entry.Diff) > 0 {
				resp.Diff = cloneAnyMap(entry.Diff)
			}
		} else {
			if len(entry.Metadata) > 0 {
				resp.MetadataRedacted = true
			}
			if len(entry.Diff) > 0 {
				resp.DiffRedacted = true
			}
		}
		result = append(result, resp)
	}
	return result
}

type auditLogListResponse struct {
	Items         []auditLogEntryResponse `json:"items"`
	NextPageToken string                  `json:"nextPageToken,omitempty"`
}

type auditLogEntryResponse struct {
	ID               string         `json:"id"`
	Actor            string         `json:"actor"`
	ActorType        string         `json:"actorType,omitempty"`
	Action           string         `json:"action"`
	TargetRef        string         `json:"targetRef"`
	Severity         string         `json:"severity,omitempty"`
	RequestID        string         `json:"requestId,omitempty"`
	IPHash           string         `json:"ipHash,omitempty"`
	UserAgent        string         `json:"userAgent,omitempty"`
	CreatedAt        string         `json:"createdAt"`
	Metadata         map[string]any `json:"metadata,omitempty"`
	Diff             map[string]any `json:"diff,omitempty"`
	MetadataRedacted bool           `json:"metadataRedacted,omitempty"`
	DiffRedacted     bool           `json:"diffRedacted,omitempty"`
}

func writeAuditLogCSV(w http.ResponseWriter, targetRef string, entries []auditLogEntryResponse) error {
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	filename := sanitizeAuditFilename(targetRef)
	if filename != "" {
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	}

	writer := csv.NewWriter(w)
	header := []string{"id", "createdAt", "actor", "actorType", "action", "targetRef", "severity", "requestId", "ipHash", "userAgent", "metadata", "diff", "metadataRedacted", "diffRedacted"}
	if err := writer.Write(header); err != nil {
		return err
	}

	for _, entry := range entries {
		metadata := ""
		if entry.Metadata != nil {
			if data, err := json.Marshal(entry.Metadata); err == nil {
				metadata = string(data)
			}
		} else if entry.MetadataRedacted {
			metadata = "[redacted]"
		}

		diff := ""
		if entry.Diff != nil {
			if data, err := json.Marshal(entry.Diff); err == nil {
				diff = string(data)
			}
		} else if entry.DiffRedacted {
			diff = "[redacted]"
		}

		row := []string{
			entry.ID,
			entry.CreatedAt,
			entry.Actor,
			entry.ActorType,
			entry.Action,
			entry.TargetRef,
			entry.Severity,
			entry.RequestID,
			entry.IPHash,
			entry.UserAgent,
			metadata,
			diff,
			strconv.FormatBool(entry.MetadataRedacted),
			strconv.FormatBool(entry.DiffRedacted),
		}
		if err := writer.Write(row); err != nil {
			return err
		}
	}

	writer.Flush()
	return writer.Error()
}

func sanitizeAuditFilename(targetRef string) string {
	trimmed := strings.TrimSpace(targetRef)
	if trimmed == "" {
		return ""
	}
	normalized := strings.ReplaceAll(trimmed, "/", "-")
	normalized = strings.Trim(normalized, "-")
	if normalized == "" {
		return ""
	}
	return fmt.Sprintf("audit-logs-%s.csv", normalized)
}

func cloneAnyMap(src map[string]any) map[string]any {
	if len(src) == 0 {
		return nil
	}
	dst := make(map[string]any, len(src))
	for key, value := range src {
		dst[key] = value
	}
	return dst
}
