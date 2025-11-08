package ui

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	systemtpl "finitefield.org/hanko-admin/internal/admin/templates/system"
)

// SystemEnvironmentSettingsPage renders the environment configuration summary.
func (h *Handlers) SystemEnvironmentSettingsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	config, err := h.system.EnvironmentConfig(ctx, user.Token)
	page := systemtpl.BuildEnvironmentSettingsPageData(ctx, custommw.BasePathFromContext(ctx), config)
	if err != nil {
		log.Printf("system settings: fetch environment config failed: %v", err)
		page.Error = "環境設定の取得に失敗しました。時間を置いて再度お試しください。"
	}

	templ.Handler(systemtpl.EnvironmentSettingsPage(page)).ServeHTTP(w, r)
}

// SystemTasksPage renders the scheduler tasks monitor.
func (h *Handlers) SystemTasksPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildSystemTasksRequest(r)
	result, err := h.system.ListJobs(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("system tasks: list failed: %v", err)
		errMsg = "タスク情報の取得に失敗しました。"
		result = adminsystem.JobResult{}
	}

	selectedID := resolveTaskSelectedID(req.selectedID, result)
	req.state.SelectedID = selectedID
	req.state.RawQuery = encodeSystemTasksQuery(req.state)

	basePath := custommw.BasePathFromContext(ctx)
	table := systemtpl.TasksTablePayload(basePath, req.state, result, selectedID, errMsg)

	var summary adminsystem.Job
	if selectedID != "" {
		summary, _ = systemtpl.FindJob(result, selectedID)
	}

	var detail adminsystem.JobDetail
	detailErr := ""
	if selectedID != "" {
		var derr error
		detail, derr = h.system.JobDetail(ctx, user.Token, selectedID)
		if derr != nil {
			if errors.Is(derr, adminsystem.ErrJobNotFound) {
				detailErr = "対象のタスクが見つかりませんでした。"
			} else {
				detailErr = "タスク詳細の取得に失敗しました。"
			}
			log.Printf("system tasks: detail failed: %v", derr)
			detail = adminsystem.JobDetail{}
		}
	}

	drawer := systemtpl.TasksDrawerPayload(basePath, summary, detail, detailErr)
	history := drawer.History
	page := systemtpl.BuildTasksPageData(ctx, basePath, req.state, result, table, drawer, history)

	templ.Handler(systemtpl.TasksPage(page)).ServeHTTP(w, r)
}

// SystemTasksTable renders the jobs table fragment for HTMX.
func (h *Handlers) SystemTasksTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildSystemTasksRequest(r)
	result, err := h.system.ListJobs(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("system tasks: list failed: %v", err)
		errMsg = "タスク情報の取得に失敗しました。"
		result = adminsystem.JobResult{}
	}

	selectedID := resolveTaskSelectedID(req.selectedID, result)
	req.state.SelectedID = selectedID
	req.state.RawQuery = encodeSystemTasksQuery(req.state)

	basePath := custommw.BasePathFromContext(ctx)
	table := systemtpl.TasksTablePayload(basePath, req.state, result, selectedID, errMsg)

	if canonical := canonicalSystemTasksURL(basePath, req.state); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(systemtpl.TasksTable(table)).ServeHTTP(w, r)
}

// SystemTasksDrawer renders the detail drawer fragment.
func (h *Handlers) SystemTasksDrawer(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	jobID := strings.TrimSpace(chi.URLParam(r, "jobID"))
	if jobID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	req := buildSystemTasksRequest(r)
	req.state.SelectedID = jobID
	req.state.RawQuery = encodeSystemTasksQuery(req.state)

	result, err := h.system.ListJobs(ctx, user.Token, req.query)
	if err != nil {
		log.Printf("system tasks: list failed for drawer: %v", err)
		result = adminsystem.JobResult{}
	}

	summary, _ := systemtpl.FindJob(result, jobID)

	detail, derr := h.system.JobDetail(ctx, user.Token, jobID)
	detailErr := ""
	if derr != nil {
		if errors.Is(derr, adminsystem.ErrJobNotFound) {
			detailErr = "対象のタスクが見つかりませんでした。"
		} else {
			detailErr = "タスク詳細の取得に失敗しました。"
		}
		log.Printf("system tasks: drawer detail failed: %v", derr)
		detail = adminsystem.JobDetail{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	drawer := systemtpl.TasksDrawerPayload(basePath, summary, detail, detailErr)
	templ.Handler(systemtpl.TasksDrawer(drawer)).ServeHTTP(w, r)
}

// SystemTasksTrigger enqueues a manual execution for the specified job.
func (h *Handlers) SystemTasksTrigger(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	jobID := strings.TrimSpace(chi.URLParam(r, "jobID"))
	if jobID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	reason := strings.TrimSpace(r.FormValue("reason"))
	outcome, err := h.system.TriggerJob(ctx, user.Token, jobID, adminsystem.TriggerOptions{
		Actor:  user.Email,
		Reason: reason,
	})
	if err != nil {
		if errors.Is(err, adminsystem.ErrJobNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		if errors.Is(err, adminsystem.ErrJobTriggerNotAllowed) {
			http.Error(w, "このタスクでは手動実行が許可されていません。", http.StatusBadRequest)
			return
		}
		log.Printf("system tasks: trigger failed: %v", err)
		http.Error(w, "手動実行の要求に失敗しました。", http.StatusInternalServerError)
		return
	}

	sendHXTrigger(w, outcome.Message, "success")
	w.WriteHeader(http.StatusOK)
}

// SystemTasksStream emits SSE refresh events for the tasks table.
func (h *Handlers) SystemTasksStream(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	writeEvent := func() {
		if _, err := fmt.Fprintf(w, "event: refresh\n"); err != nil {
			return
		}
		if _, err := fmt.Fprintf(w, "data: %s\n\n", time.Now().Format(time.RFC3339)); err != nil {
			return
		}
		flusher.Flush()
	}

	writeEvent()
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			writeEvent()
		}
	}
}

// SystemCountersPage renders the counters management page.
func (h *Handlers) SystemCountersPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildSystemCountersRequest(r)
	result, err := h.system.ListCounters(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("system counters: list failed: %v", err)
		errMsg = "カウンタ情報の取得に失敗しました。"
		result = adminsystem.CounterResult{}
	}

	selected := resolveCounterSelected(req.selected, result)
	req.state.Selected = selected
	req.state.RawQuery = encodeSystemCountersQuery(req.state)

	basePath := custommw.BasePathFromContext(ctx)
	table := systemtpl.CountersTablePayload(ctx, basePath, req.state, result, selected, errMsg)

	var detail adminsystem.CounterDetail
	detailErr := ""
	if selected != "" {
		scope, scopeErr := parseScopeInput(req.state.Scope)
		if scopeErr != nil {
			detailErr = "スコープは JSON オブジェクトで指定してください。"
		} else {
			var derr error
			detail, derr = h.system.CounterDetail(ctx, user.Token, selected, scope)
			if derr != nil {
				if errors.Is(derr, adminsystem.ErrCounterNotFound) {
					detailErr = "対象のカウンタが見つかりませんでした。"
				} else {
					detailErr = "カウンタ詳細の取得に失敗しました。"
				}
				log.Printf("system counters: detail failed: %v", derr)
				detail = adminsystem.CounterDetail{}
			}
		}
	}

	drawer := systemtpl.CountersDrawerPayload(basePath, req.state, detail, nil, detailErr)
	page := systemtpl.BuildCountersPageData(ctx, basePath, req.state, result, table, drawer)

	templ.Handler(systemtpl.CountersPage(page)).ServeHTTP(w, r)
}

// SystemCountersTable renders the counters table fragment.
func (h *Handlers) SystemCountersTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildSystemCountersRequest(r)
	result, err := h.system.ListCounters(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("system counters: list failed: %v", err)
		errMsg = "カウンタ情報の取得に失敗しました。"
		result = adminsystem.CounterResult{}
	}

	selected := resolveCounterSelected(req.selected, result)
	req.state.Selected = selected
	req.state.RawQuery = encodeSystemCountersQuery(req.state)

	basePath := custommw.BasePathFromContext(ctx)
	table := systemtpl.CountersTablePayload(ctx, basePath, req.state, result, selected, errMsg)

	if canonical := canonicalSystemCountersURL(basePath, req.state); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(systemtpl.CountersTable(table)).ServeHTTP(w, r)
}

// SystemCountersDrawer renders the counter drawer fragment.
func (h *Handlers) SystemCountersDrawer(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	name := strings.TrimSpace(chi.URLParam(r, "name"))
	if name == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	req := buildSystemCountersRequest(r)
	req.state.Selected = name
	req.state.RawQuery = encodeSystemCountersQuery(req.state)

	scope, scopeErr := parseScopeInput(req.state.Scope)
	if scopeErr != nil {
		drawer := systemtpl.CountersDrawerPayload(custommw.BasePathFromContext(ctx), req.state, adminsystem.CounterDetail{}, nil, "スコープは JSON オブジェクトで指定してください。")
		templ.Handler(systemtpl.CountersDrawer(drawer, req.state)).ServeHTTP(w, r)
		return
	}

	detail, err := h.system.CounterDetail(ctx, user.Token, name, scope)
	detailErr := ""
	if err != nil {
		if errors.Is(err, adminsystem.ErrCounterNotFound) {
			detailErr = "対象のカウンタが見つかりませんでした。"
			w.WriteHeader(http.StatusNotFound)
		} else {
			detailErr = "カウンタ詳細の取得に失敗しました。"
			log.Printf("system counters: drawer detail failed: %v", err)
			w.WriteHeader(http.StatusInternalServerError)
		}
		detail = adminsystem.CounterDetail{}
	}

	drawer := systemtpl.CountersDrawerPayload(custommw.BasePathFromContext(ctx), req.state, detail, nil, detailErr)
	templ.Handler(systemtpl.CountersDrawer(drawer, req.state)).ServeHTTP(w, r)
}

// SystemCountersNext advances the selected counter and re-renders the drawer.
func (h *Handlers) SystemCountersNext(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	name := strings.TrimSpace(chi.URLParam(r, "name"))
	if name == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	req := buildSystemCountersRequest(r)
	req.state.Selected = name
	req.state.RawQuery = encodeSystemCountersQuery(req.state)

	scope, scopeErr := parseScopeInput(req.state.Scope)
	if scopeErr != nil {
		drawer := systemtpl.CountersDrawerPayload(custommw.BasePathFromContext(ctx), req.state, adminsystem.CounterDetail{}, nil, "スコープは JSON オブジェクトで指定してください。")
		templ.Handler(systemtpl.CountersDrawer(drawer, req.state)).ServeHTTP(w, r)
		return
	}

	amount := int64(0)
	if raw := strings.TrimSpace(r.Form.Get("amount")); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil {
			http.Error(w, "回数は整数で指定してください。", http.StatusBadRequest)
			return
		}
		amount = parsed
	}

	outcome, err := h.system.NextCounter(ctx, user.Token, name, adminsystem.CounterNextOptions{
		Actor:  user.Email,
		Scope:  scope,
		Amount: amount,
	})
	if err != nil {
		if errors.Is(err, adminsystem.ErrCounterNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("system counters: next failed: %v", err)
		http.Error(w, "次番号の取得に失敗しました。", http.StatusInternalServerError)
		return
	}

	detail, derr := h.system.CounterDetail(ctx, user.Token, name, scope)
	detailErr := ""
	if derr != nil {
		if errors.Is(derr, adminsystem.ErrCounterNotFound) {
			detailErr = "対象のカウンタが見つかりませんでした。"
		} else {
			detailErr = "カウンタ詳細の取得に失敗しました。"
			log.Printf("system counters: detail refresh failed: %v", derr)
		}
		detail = adminsystem.CounterDetail{}
	}

	drawer := systemtpl.CountersDrawerPayload(custommw.BasePathFromContext(ctx), req.state, detail, &outcome, detailErr)
	sendHXTrigger(w, outcome.Message, "success")
	templ.Handler(systemtpl.CountersDrawer(drawer, req.state)).ServeHTTP(w, r)
}

type systemTasksRequest struct {
	query      adminsystem.JobQuery
	state      systemtpl.TasksQueryState
	selectedID string
}

func buildSystemTasksRequest(r *http.Request) systemTasksRequest {
	q := r.URL.Query()
	state := systemtpl.TasksQueryState{
		Type:       strings.TrimSpace(q.Get("type")),
		State:      strings.TrimSpace(q.Get("state")),
		Host:       strings.TrimSpace(q.Get("host")),
		Window:     strings.TrimSpace(q.Get("window")),
		Search:     strings.TrimSpace(q.Get("q")),
		SelectedID: strings.TrimSpace(q.Get("selected")),
		Limit:      strings.TrimSpace(q.Get("limit")),
	}

	state.Type = normalizeJobTypeParam(state.Type)
	state.State = normalizeJobStateParam(state.State)
	state.Window = normalizeJobWindow(state.Window)

	query := adminsystem.JobQuery{
		Window: state.Window,
		Search: state.Search,
	}

	if state.Type != "" {
		query.Types = []adminsystem.JobType{adminsystem.JobType(state.Type)}
	}
	if state.State != "" {
		query.States = []adminsystem.JobState{adminsystem.JobState(state.State)}
	}
	if state.Host != "" {
		query.Hosts = []string{state.Host}
	}
	if state.Window != "" {
		query.Window = state.Window
	}

	if state.Limit != "" {
		if limit, err := strconv.Atoi(state.Limit); err == nil && limit > 0 {
			query.Limit = limit
		}
	}

	return systemTasksRequest{
		query:      query,
		state:      state,
		selectedID: state.SelectedID,
	}
}

func normalizeJobTypeParam(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminsystem.JobTypeScheduled):
		return string(adminsystem.JobTypeScheduled)
	case string(adminsystem.JobTypeBatch):
		return string(adminsystem.JobTypeBatch)
	case string(adminsystem.JobTypeAdhoc):
		return string(adminsystem.JobTypeAdhoc)
	case string(adminsystem.JobTypeEvent):
		return string(adminsystem.JobTypeEvent)
	default:
		return ""
	}
}

func normalizeJobStateParam(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminsystem.JobStateHealthy):
		return string(adminsystem.JobStateHealthy)
	case string(adminsystem.JobStateRunning):
		return string(adminsystem.JobStateRunning)
	case string(adminsystem.JobStateDegraded):
		return string(adminsystem.JobStateDegraded)
	case string(adminsystem.JobStateFailed):
		return string(adminsystem.JobStateFailed)
	case string(adminsystem.JobStatePaused):
		return string(adminsystem.JobStatePaused)
	default:
		return ""
	}
}

func normalizeJobWindow(value string) string {
	switch strings.TrimSpace(value) {
	case "overdue", "30m", "1h", "6h", "24h":
		return strings.TrimSpace(value)
	default:
		return ""
	}
}

func resolveTaskSelectedID(candidate string, result adminsystem.JobResult) string {
	id := strings.TrimSpace(candidate)
	if id != "" {
		for _, job := range result.Jobs {
			if job.ID == id {
				return id
			}
		}
	}
	if len(result.Jobs) > 0 {
		return result.Jobs[0].ID
	}
	return ""
}

func encodeSystemTasksQuery(state systemtpl.TasksQueryState) string {
	values := url.Values{}
	if state.Type != "" {
		values.Set("type", state.Type)
	}
	if state.State != "" {
		values.Set("state", state.State)
	}
	if state.Host != "" {
		values.Set("host", state.Host)
	}
	if state.Window != "" {
		values.Set("window", state.Window)
	}
	if state.Search != "" {
		values.Set("q", state.Search)
	}
	if state.Limit != "" {
		values.Set("limit", state.Limit)
	}
	if state.SelectedID != "" {
		values.Set("selected", state.SelectedID)
	}
	return values.Encode()
}

func canonicalSystemTasksURL(basePath string, state systemtpl.TasksQueryState) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/admin"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	base = strings.TrimRight(base, "/")
	if base == "" || base == "/" {
		base = ""
	}
	path := base + "/system/tasks"
	if raw := encodeSystemTasksQuery(state); raw != "" {
		return path + "?" + raw
	}
	return path
}

type systemCountersRequest struct {
	query    adminsystem.CounterQuery
	state    systemtpl.CountersQueryState
	selected string
}

func buildSystemCountersRequest(r *http.Request) systemCountersRequest {
	_ = r.ParseForm()
	state := systemtpl.CountersQueryState{
		Namespace: strings.TrimSpace(r.Form.Get("namespace")),
		Search:    strings.TrimSpace(r.Form.Get("q")),
		Selected:  strings.TrimSpace(r.Form.Get("selected")),
		Scope:     strings.TrimSpace(r.Form.Get("scope")),
	}
	query := adminsystem.CounterQuery{
		Namespace: state.Namespace,
		Search:    state.Search,
	}
	if raw := strings.TrimSpace(r.Form.Get("limit")); raw != "" {
		if limit, err := strconv.Atoi(raw); err == nil && limit > 0 {
			query.Limit = limit
		}
	}
	return systemCountersRequest{
		query:    query,
		state:    state,
		selected: state.Selected,
	}
}

func resolveCounterSelected(candidate string, result adminsystem.CounterResult) string {
	id := strings.TrimSpace(candidate)
	if id != "" {
		for _, counter := range result.Counters {
			if strings.EqualFold(counter.Name, id) {
				return counter.Name
			}
		}
	}
	if len(result.Counters) > 0 {
		return result.Counters[0].Name
	}
	return ""
}

func encodeSystemCountersQuery(state systemtpl.CountersQueryState) string {
	values := url.Values{}
	if state.Namespace != "" {
		values.Set("namespace", state.Namespace)
	}
	if state.Search != "" {
		values.Set("q", state.Search)
	}
	if state.Scope != "" {
		values.Set("scope", state.Scope)
	}
	if state.Selected != "" {
		values.Set("selected", state.Selected)
	}
	return values.Encode()
}

func canonicalSystemCountersURL(basePath string, state systemtpl.CountersQueryState) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/admin"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	base = strings.TrimRight(base, "/")
	path := base + "/system/counters"
	if raw := encodeSystemCountersQuery(state); raw != "" {
		return path + "?" + raw
	}
	return path
}

func parseScopeInput(raw string) (map[string]string, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" || trimmed == "{}" {
		return nil, nil
	}
	var generic map[string]any
	if err := json.Unmarshal([]byte(trimmed), &generic); err != nil {
		return nil, err
	}
	scope := make(map[string]string, len(generic))
	for key, value := range generic {
		k := strings.TrimSpace(key)
		if k == "" {
			continue
		}
		var str string
		switch v := value.(type) {
		case string:
			str = strings.TrimSpace(v)
		case fmt.Stringer:
			str = strings.TrimSpace(v.String())
		default:
			str = strings.TrimSpace(fmt.Sprintf("%v", v))
		}
		if str == "" {
			continue
		}
		scope[k] = str
	}
	if len(scope) == 0 {
		return nil, nil
	}
	return scope, nil
}

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
		"refresh": true,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		log.Printf("system errors: marshal HX-Trigger failed: %v", err)
		return
	}
	w.Header().Set("HX-Trigger", string(body))
}
