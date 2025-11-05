package ui

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	systemtpl "finitefield.org/hanko-admin/internal/admin/templates/system"
)

// SystemErrorsPage renders the system errors dashboard.
func (h *Handlers) SystemErrorsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildSystemErrorsRequest(r)

	result, err := h.system.ListFailures(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("system errors: list failed: %v", err)
		errMsg = "失敗ログの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminsystem.FailureResult{}
	}

	selectedID := resolveSelectedID(req.selectedID, result)
	req.state.SelectedID = selectedID
	req.state.RawQuery = encodeSystemErrorsQuery(req.state)

	table := systemtpl.TablePayload(custommw.BasePathFromContext(ctx), req.state, result, selectedID, errMsg)

	var detail adminsystem.FailureDetail
	detailErr := ""
	summary := systemtpl.FindFailure(result, selectedID)
	if selectedID != "" {
		var derr error
		detail, derr = h.system.FailureDetail(ctx, user.Token, selectedID)
		if derr != nil {
			if errors.Is(derr, adminsystem.ErrFailureNotFound) {
				detailErr = "対象の失敗ログは見つかりませんでした。"
			} else {
				detailErr = "詳細情報の取得に失敗しました。"
			}
			log.Printf("system errors: detail failed: %v", derr)
			detail = adminsystem.FailureDetail{}
		}
	}

	drawer := systemtpl.DrawerPayload(custommw.BasePathFromContext(ctx), summary, detail, detailErr)
	page := systemtpl.BuildPageData(custommw.BasePathFromContext(ctx), req.state, result, table, drawer)

	templ.Handler(systemtpl.Index(page)).ServeHTTP(w, r)
}

// SystemErrorsTable renders the table fragment for htmx refreshes.
func (h *Handlers) SystemErrorsTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildSystemErrorsRequest(r)
	result, err := h.system.ListFailures(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("system errors: list failed: %v", err)
		errMsg = "失敗ログの取得に失敗しました。"
		result = adminsystem.FailureResult{}
	}

	selectedID := resolveSelectedID(req.selectedID, result)
	req.state.SelectedID = selectedID
	req.state.RawQuery = encodeSystemErrorsQuery(req.state)

	table := systemtpl.TablePayload(custommw.BasePathFromContext(ctx), req.state, result, selectedID, errMsg)

	if canonical := canonicalSystemErrorsURL(custommw.BasePathFromContext(ctx), req.state); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(systemtpl.Table(table)).ServeHTTP(w, r)
}

// SystemErrorsDrawer renders the detail drawer fragment.
func (h *Handlers) SystemErrorsDrawer(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildSystemErrorsRequest(r)
	selectedID := strings.TrimSpace(chi.URLParam(r, "failureID"))
	if selectedID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	req.state.SelectedID = selectedID
	req.state.RawQuery = encodeSystemErrorsQuery(req.state)

	result, err := h.system.ListFailures(ctx, user.Token, req.query)
	if err != nil {
		log.Printf("system errors: list failed for drawer: %v", err)
		result = adminsystem.FailureResult{}
	}

	summary := systemtpl.FindFailure(result, selectedID)

	detail, derr := h.system.FailureDetail(ctx, user.Token, selectedID)
	detailErr := ""
	if derr != nil {
		if errors.Is(derr, adminsystem.ErrFailureNotFound) {
			detailErr = "対象の失敗ログは見つかりませんでした。"
		} else {
			detailErr = "詳細情報の取得に失敗しました。"
		}
		log.Printf("system errors: drawer detail failed: %v", derr)
		detail = adminsystem.FailureDetail{}
	}

	drawer := systemtpl.DrawerPayload(custommw.BasePathFromContext(ctx), summary, detail, detailErr)
	templ.Handler(systemtpl.Drawer(drawer)).ServeHTTP(w, r)
}

// SystemErrorsRetry enqueues a retry for the specified failure.
func (h *Handlers) SystemErrorsRetry(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	failureID := strings.TrimSpace(chi.URLParam(r, "failureID"))
	if failureID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	outcome, err := h.system.RetryFailure(ctx, user.Token, failureID, adminsystem.RetryOptions{
		Actor: user.Email,
	})
	if err != nil {
		log.Printf("system errors: retry failed: %v", err)
		http.Error(w, "再実行に失敗しました。", http.StatusInternalServerError)
		return
	}

	sendHXTrigger(w, outcome.Message, "success")
	w.WriteHeader(http.StatusOK)
}

// SystemErrorsAcknowledge marks a failure as acknowledged.
func (h *Handlers) SystemErrorsAcknowledge(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	failureID := strings.TrimSpace(chi.URLParam(r, "failureID"))
	if failureID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	outcome, err := h.system.AcknowledgeFailure(ctx, user.Token, failureID, adminsystem.AcknowledgeOptions{
		Actor: user.Email,
	})
	if err != nil {
		log.Printf("system errors: acknowledge failed: %v", err)
		http.Error(w, "確認済みへの更新に失敗しました。", http.StatusInternalServerError)
		return
	}

	sendHXTrigger(w, outcome.Message, "info")
	w.WriteHeader(http.StatusOK)
}

type systemErrorsRequest struct {
	query      adminsystem.FailureQuery
	state      systemtpl.QueryState
	selectedID string
}

func buildSystemErrorsRequest(r *http.Request) systemErrorsRequest {
	values := r.URL.Query()
	rawSource := strings.TrimSpace(values.Get("source"))
	rawSeverity := strings.TrimSpace(values.Get("severity"))
	rawStatus := strings.TrimSpace(values.Get("status"))
	rawService := strings.TrimSpace(values.Get("service"))
	rawSearch := strings.TrimSpace(values.Get("q"))
	rawStart := strings.TrimSpace(values.Get("start"))
	rawEnd := strings.TrimSpace(values.Get("end"))
	rawSelected := strings.TrimSpace(values.Get("selected"))
	rawLimit := strings.TrimSpace(values.Get("limit"))

	state := systemtpl.QueryState{
		Source:     normalizeFailureSource(rawSource),
		Severity:   normalizeFailureSeverity(rawSeverity),
		Status:     normalizeFailureStatus(rawStatus),
		Service:    rawService,
		Search:     rawSearch,
		StartDate:  normalizeDateInput(rawStart),
		EndDate:    normalizeDateInput(rawEnd),
		SelectedID: rawSelected,
		Limit:      rawLimit,
		RawQuery:   r.URL.RawQuery,
	}

	query := adminsystem.FailureQuery{
		Search: rawSearch,
	}
	if state.Source != "" {
		query.Sources = []adminsystem.Source{adminsystem.Source(state.Source)}
	}
	if state.Severity != "" {
		query.Severities = []adminsystem.Severity{adminsystem.Severity(state.Severity)}
	}
	if state.Status != "" {
		query.Statuses = []adminsystem.Status{adminsystem.Status(state.Status)}
	}
	if strings.TrimSpace(state.Service) != "" {
		query.Services = []string{state.Service}
	}

	if parsed := parseDate(rawStart); !parsed.IsZero() {
		query.Start = &parsed
	}
	if parsed := parseDate(rawEnd); !parsed.IsZero() {
		// extend end date to include entire day
		end := parsed.Add(24*time.Hour - time.Nanosecond)
		query.End = &end
	}

	if rawLimit != "" {
		if limit, err := parsePositiveInt(rawLimit); err == nil {
			query.Limit = limit
		}
	}

	return systemErrorsRequest{
		query:      query,
		state:      state,
		selectedID: rawSelected,
	}
}

func resolveSelectedID(candidate string, result adminsystem.FailureResult) string {
	candidate = strings.TrimSpace(candidate)
	if candidate == "" && len(result.Failures) > 0 {
		return result.Failures[0].ID
	}
	if candidate == "" {
		return ""
	}
	for _, failure := range result.Failures {
		if failure.ID == candidate {
			return candidate
		}
	}
	return ""
}

func encodeSystemErrorsQuery(state systemtpl.QueryState) string {
	values := url.Values{}
	if state.Source != "" {
		values.Set("source", state.Source)
	}
	if state.Severity != "" {
		values.Set("severity", state.Severity)
	}
	if strings.TrimSpace(state.Service) != "" {
		values.Set("service", strings.TrimSpace(state.Service))
	}
	if state.Status != "" {
		values.Set("status", state.Status)
	}
	if strings.TrimSpace(state.Search) != "" {
		values.Set("q", strings.TrimSpace(state.Search))
	}
	if state.StartDate != "" {
		values.Set("start", state.StartDate)
	}
	if state.EndDate != "" {
		values.Set("end", state.EndDate)
	}
	if strings.TrimSpace(state.SelectedID) != "" {
		values.Set("selected", strings.TrimSpace(state.SelectedID))
	}
	if strings.TrimSpace(state.Limit) != "" {
		values.Set("limit", strings.TrimSpace(state.Limit))
	}
	return values.Encode()
}

func canonicalSystemErrorsURL(basePath string, state systemtpl.QueryState) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/admin"
	}
	base = strings.TrimRight(base, "/")
	if base == "" {
		base = "/admin"
	}

	query := encodeSystemErrorsQuery(state)
	path := joinSystemRoute(base, "/system/errors")
	if query == "" {
		return path
	}
	return path + "?" + query
}

func joinSystemRoute(base, suffix string) string {
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	if base != "/" {
		base = strings.TrimRight(base, "/")
	}
	suffix = strings.TrimSpace(suffix)
	if suffix == "" {
		return base
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	if base == "/" {
		return suffix
	}
	return base + suffix
}

func normalizeFailureSource(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminsystem.SourceJob):
		return string(adminsystem.SourceJob)
	case string(adminsystem.SourceWebhook):
		return string(adminsystem.SourceWebhook)
	case string(adminsystem.SourceAPI):
		return string(adminsystem.SourceAPI)
	case string(adminsystem.SourceWorker):
		return string(adminsystem.SourceWorker)
	default:
		return ""
	}
}

func normalizeFailureSeverity(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminsystem.SeverityCritical):
		return string(adminsystem.SeverityCritical)
	case string(adminsystem.SeverityHigh):
		return string(adminsystem.SeverityHigh)
	case string(adminsystem.SeverityMedium):
		return string(adminsystem.SeverityMedium)
	case string(adminsystem.SeverityLow):
		return string(adminsystem.SeverityLow)
	default:
		return ""
	}
}

func normalizeFailureStatus(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminsystem.StatusOpen):
		return string(adminsystem.StatusOpen)
	case string(adminsystem.StatusAcknowledged):
		return string(adminsystem.StatusAcknowledged)
	case string(adminsystem.StatusResolved):
		return string(adminsystem.StatusResolved)
	case string(adminsystem.StatusSuppressed):
		return string(adminsystem.StatusSuppressed)
	default:
		return ""
	}
}

func sendHXTrigger(w http.ResponseWriter, message, tone string) {
	if strings.TrimSpace(message) == "" {
		message = "操作が完了しました。"
	}
	if strings.TrimSpace(tone) == "" {
		tone = "info"
	}
	payload := map[string]any{
		"toast": map[string]string{
			"message": message,
			"tone":    tone,
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		log.Printf("system errors: marshal HX-Trigger failed: %v", err)
		return
	}
	w.Header().Set("HX-Trigger", string(body))
}
