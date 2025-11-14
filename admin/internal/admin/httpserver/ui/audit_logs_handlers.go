package ui

import (
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/a-h/templ"

	adminaudit "finitefield.org/hanko-admin/internal/admin/auditlogs"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	auditlogstpl "finitefield.org/hanko-admin/internal/admin/templates/auditlogs"
)

const (
	defaultAuditLogPageSize = 20
	auditLogDateLayout      = "2006-01-02"
)

type auditLogsRequest struct {
	query adminaudit.ListQuery
	state auditlogstpl.QueryState
}

// AuditLogsPage renders the audit log index page.
func (h *Handlers) AuditLogsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildAuditLogsRequest(r.URL.Query())
	result, err := h.auditlogs.List(ctx, user.Token, req.query)
	if err != nil {
		log.Printf("audit logs: list failed: %v", err)
		http.Error(w, "監査ログの取得に失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	data := auditlogstpl.BuildPageData(basePath, req.state, result)
	templ.Handler(auditlogstpl.Index(data)).ServeHTTP(w, r)
}

// AuditLogsTable renders the table fragment for htmx requests.
func (h *Handlers) AuditLogsTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildAuditLogsRequest(r.URL.Query())
	result, err := h.auditlogs.List(ctx, user.Token, req.query)
	if err != nil {
		log.Printf("audit logs: list (fragment) failed: %v", err)
		http.Error(w, "監査ログの取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	table := auditlogstpl.TablePayload(basePath, req.state, result, "")
	templ.Handler(auditlogstpl.Table(table)).ServeHTTP(w, r)
}

// AuditLogsExport streams a CSV export for the current filter set.
func (h *Handlers) AuditLogsExport(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildAuditLogsRequest(r.URL.Query())
	export, err := h.auditlogs.Export(ctx, user.Token, req.query)
	if err != nil {
		log.Printf("audit logs: export failed: %v", err)
		http.Error(w, "監査ログのエクスポートに失敗しました。", http.StatusBadGateway)
		return
	}

	filename := export.Filename
	if strings.TrimSpace(filename) == "" {
		filename = "audit-logs.csv"
	}

	contentType := strings.TrimSpace(export.ContentType)
	if contentType == "" {
		contentType = "text/csv; charset=utf-8"
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Disposition", `attachment; filename="`+filename+`"`)
	w.WriteHeader(http.StatusOK)
	if len(export.Data) > 0 {
		_, _ = w.Write(export.Data)
	}
}

func buildAuditLogsRequest(raw url.Values) auditLogsRequest {
	state := auditlogstpl.BuildQueryState(raw)

	page := state.Page
	if page <= 0 {
		page = 1
	}
	pageSize := state.PageSize
	if pageSize <= 0 {
		pageSize = defaultAuditLogPageSize
	}

	state.Page = page
	state.PageSize = pageSize

	query := adminaudit.ListQuery{
		Targets:  duplicate(state.Targets),
		Actors:   duplicate(state.Actors),
		Actions:  duplicate(state.Actions),
		Search:   state.Search,
		Page:     page,
		PageSize: pageSize,
		Sort:     strings.TrimSpace(raw.Get("sort")),
	}

	if parsed := parseAuditLogDate(state.From); parsed != nil {
		query.From = parsed
	}
	if parsed := parseAuditLogDate(state.To); parsed != nil {
		query.To = parsed
	}

	return auditLogsRequest{
		query: query,
		state: state,
	}
}

func duplicate(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, len(values))
	copy(out, values)
	return out
}

func parseAuditLogDate(value string) *time.Time {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	ts, err := time.ParseInLocation(auditLogDateLayout, value, time.Local)
	if err != nil {
		return nil
	}
	return &ts
}
