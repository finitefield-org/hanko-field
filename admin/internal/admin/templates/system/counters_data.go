package system

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"sort"
	"strings"
	"time"

	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// CountersPageData represents the SSR payload for the counters page.
type CountersPageData struct {
	Title             string
	Description       string
	Breadcrumbs       []partials.Breadcrumb
	Alerts            []Alert
	Query             CountersQueryState
	NamespaceSelector NamespaceSelector
	TableEndpoint     string
	Table             CountersTableData
	Drawer            CountersDrawerData
	GeneratedLabel    string
}

// CountersQueryState mirrors the query parameters applied to the page.
type CountersQueryState struct {
	Namespace string
	Search    string
	Selected  string
	Scope     string
	RawQuery  string
}

// NamespaceSelector drives the namespace combobox in the header.
type NamespaceSelector struct {
	Endpoint string
	Options  []NamespaceOption
}

// NamespaceOption represents an individual namespace option.
type NamespaceOption struct {
	ID       string
	Label    string
	Sublabel string
	Active   bool
}

// CountersTableData configures the table fragment payload.
type CountersTableData struct {
	Items        []CountersTableRow
	Error        string
	EmptyMessage string
	Total        int
	FragmentPath string
	RawQuery     string
	Selected     string
	GeneratedAt  string
}

// CountersTableRow renders a counter row in the table.
type CountersTableRow struct {
	Name               string
	Label              string
	Namespace          string
	NamespaceLabel     string
	ScopeLabel         string
	Increment          string
	CurrentValue       string
	LastUpdated        string
	LastUpdatedTooltip string
	Tags               []string
	DrawerURL          string
	Selected           bool
	RowClass           string
}

// CountersDrawerData powers the drawer detail view.
type CountersDrawerData struct {
	Empty   bool
	Error   string
	Counter CountersDrawerCounter
	History []CounterHistoryItem
	Jobs    []CounterJobView
	Notes   []string
	Form    CountersNextForm
	Result  CountersNextResult
}

// CountersDrawerCounter summarises counter metadata for the drawer.
type CountersDrawerCounter struct {
	Name           string
	Label          string
	Namespace      string
	NamespaceLabel string
	Description    string
	CurrentValue   string
	Increment      string
	LastUpdated    string
	Owner          string
	Tags           []string
	ScopeKeys      string
	Alert          *Alert
}

// CounterHistoryItem renders recent counter operations.
type CounterHistoryItem struct {
	ID         string
	Timestamp  string
	Relative   string
	Actor      string
	ActorEmail string
	ScopeLabel string
	Delta      string
	Value      string
	Message    string
	Source     string
	AuditID    string
}

// CounterJobView links related jobs to the counter.
type CounterJobView struct {
	ID          string
	Name        string
	Description string
	URL         string
	StatusLabel string
	StatusTone  string
	LastRun     string
}

// CountersNextForm configures the inline next-counter form.
type CountersNextForm struct {
	Action           string
	ScopePlaceholder string
	ScopeValue       string
	Amount           string
	Disabled         bool
	Name             string
	Namespace        string
}

// CountersNextResult renders the latest next-counter outcome.
type CountersNextResult struct {
	Visible   bool
	Message   string
	Value     string
	Tone      string
	Timestamp string
}

// BuildCountersPageData assembles the counters page payload.
func BuildCountersPageData(ctx context.Context, basePath string, state CountersQueryState, result adminsystem.CounterResult, table CountersTableData, drawer CountersDrawerData) CountersPageData {
	formatter := helpers.NewFormatter(ctx)
	generated := result.GeneratedAt
	if generated.IsZero() {
		generated = time.Now()
	}
	return CountersPageData{
		Title:             "カウンタ管理",
		Description:       "採番カウンタの現在値を確認し、必要に応じて手動で次番号を試験取得します。",
		Breadcrumbs:       countersBreadcrumbs(formatter, basePath),
		Alerts:            counterAlerts(result.Alerts),
		Query:             state,
		NamespaceSelector: buildNamespaceSelector(basePath, state.Namespace, result.Namespaces),
		TableEndpoint:     joinBasePath(basePath, "/system/counters/table"),
		Table:             table,
		Drawer:            drawer,
		GeneratedLabel:    fmt.Sprintf("%s: %s", formatter.T("common.last_updated"), formatter.Relative(generated)),
	}
}

// CountersTablePayload prepares the table fragment payload.
func CountersTablePayload(ctx context.Context, basePath string, state CountersQueryState, result adminsystem.CounterResult, selected string, errMsg string) CountersTableData {
	formatter := helpers.NewFormatter(ctx)
	rows := make([]CountersTableRow, 0, len(result.Counters))
	for _, counter := range result.Counters {
		rows = append(rows, toCountersTableRow(formatter, basePath, counter, selected))
	}
	generated := ""
	if !result.GeneratedAt.IsZero() {
		generated = formatter.Date(result.GeneratedAt, "2006-01-02 15:04")
	}
	empty := "表示できるカウンタがありません。フィルタを調整するかスコープを確認してください。"
	return CountersTableData{
		Items:        rows,
		Error:        errMsg,
		EmptyMessage: empty,
		Total:        len(result.Counters),
		FragmentPath: joinBasePath(basePath, "/system/counters/table"),
		RawQuery:     state.RawQuery,
		Selected:     selected,
		GeneratedAt:  generated,
	}
}

// CountersDrawerPayload builds the drawer payload for the selected counter.
func CountersDrawerPayload(basePath string, state CountersQueryState, detail adminsystem.CounterDetail, outcome *adminsystem.CounterNextOutcome, errMsg string) CountersDrawerData {
	if errMsg != "" {
		return CountersDrawerData{Error: errMsg}
	}
	if detail.Counter.Name == "" {
		return CountersDrawerData{Empty: true}
	}

	history := make([]CounterHistoryItem, 0, len(detail.History))
	for _, event := range detail.History {
		history = append(history, toCounterHistoryItem(event))
	}
	jobs := make([]CounterJobView, 0, len(detail.RelatedJobs))
	for _, job := range detail.RelatedJobs {
		jobs = append(jobs, toCounterJobView(basePath, job))
	}
	alert := (*Alert)(nil)
	if detail.Counter.Alert != nil {
		alert = &Alert{
			Tone:      detail.Counter.Alert.Tone,
			Title:     detail.Counter.Alert.Title,
			Body:      detail.Counter.Alert.Message,
			LinkLabel: detail.Counter.Alert.Action.Label,
			LinkURL:   detail.Counter.Alert.Action.URL,
			Icon:      detail.Counter.Alert.Action.Icon,
		}
	}
	counter := CountersDrawerCounter{
		Name:           detail.Counter.Name,
		Label:          fallback(detail.Counter.Label, detail.Counter.Name),
		Namespace:      detail.Counter.Namespace,
		NamespaceLabel: namespaceLabel(detail.Counter.Namespace),
		Description:    detail.Counter.Description,
		CurrentValue:   fmt.Sprintf("%d", detail.Counter.CurrentValue),
		Increment:      fmt.Sprintf("%d", fallbackInt(detail.Counter.Increment, 1)),
		LastUpdated:    formatTimestamp(detail.Counter.LastUpdated),
		Owner:          detail.Counter.Owner,
		Tags:           append([]string(nil), detail.Counter.Tags...),
		ScopeKeys:      strings.Join(detail.Counter.ScopeKeys, ", "),
		Alert:          alert,
	}
	form := CountersNextForm{
		Action:           joinBasePath(basePath, fmt.Sprintf("/system/counters/%s:next", url.PathEscape(detail.Counter.Name))),
		ScopePlaceholder: scopePlaceholder(detail.Counter.ScopeExample),
		ScopeValue:       fallback(state.Scope, scopePlaceholder(detail.Counter.ScopeExample)),
		Amount:           fmt.Sprintf("%d", fallbackInt(detail.Counter.Increment, 1)),
		Disabled:         false,
		Name:             detail.Counter.Name,
		Namespace:        detail.Counter.Namespace,
	}
	result := CountersNextResult{}
	if outcome != nil {
		result = CountersNextResult{
			Visible:   true,
			Message:   outcome.Message,
			Value:     fmt.Sprintf("%d", outcome.Value),
			Tone:      "success",
			Timestamp: helpers.Date(outcome.OccurredAt, "15:04:05"),
		}
	}
	return CountersDrawerData{
		Empty:   false,
		Error:   "",
		Counter: counter,
		History: history,
		Jobs:    jobs,
		Notes:   append([]string(nil), detail.Notes...),
		Form:    form,
		Result:  result,
	}
}

func countersBreadcrumbs(_ helpers.Formatter, basePath string) []partials.Breadcrumb {
	return []partials.Breadcrumb{
		{Label: "システム運用", Href: joinBasePath(basePath, "/system/tasks")},
		{Label: "カウンタ", Href: joinBasePath(basePath, "/system/counters")},
	}
}

func counterAlerts(alerts []adminsystem.CounterAlert) []Alert {
	views := make([]Alert, 0, len(alerts))
	for _, alert := range alerts {
		views = append(views, Alert{
			Tone:      alert.Tone,
			Title:     alert.Title,
			Body:      alert.Message,
			LinkLabel: alert.Action.Label,
			LinkURL:   alert.Action.URL,
			Icon:      alert.Action.Icon,
		})
	}
	return views
}

func buildNamespaceSelector(basePath, selected string, options []adminsystem.CounterNamespace) NamespaceSelector {
	selector := NamespaceSelector{Endpoint: joinBasePath(basePath, "/system/counters")}
	selected = strings.TrimSpace(selected)
	allActive := selected == ""
	selector.Options = append(selector.Options, NamespaceOption{ID: "", Label: "すべて", Active: allActive})

	seen := make(map[string]struct{})
	hasActive := allActive
	for _, opt := range options {
		id := strings.TrimSpace(opt.ID)
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		active := opt.Active
		if selected != "" {
			active = strings.EqualFold(selected, id)
		}
		if active {
			hasActive = true
		}
		selector.Options = append(selector.Options, NamespaceOption{
			ID:       id,
			Label:    fallback(opt.Label, namespaceLabel(id)),
			Sublabel: opt.Sublabel,
			Active:   active,
		})
	}
	if !hasActive {
		selector.Options[0].Active = true
	}
	return selector
}

func toCountersTableRow(formatter helpers.Formatter, basePath string, counter adminsystem.Counter, selected string) CountersTableRow {
	selected = strings.TrimSpace(selected)
	name := strings.TrimSpace(counter.Name)
	isSelected := selected != "" && strings.EqualFold(selected, name)
	rowClass := "cursor-pointer transition-colors hover:bg-slate-50"
	if isSelected {
		rowClass += " bg-brand-50"
	}
	return CountersTableRow{
		Name:               name,
		Label:              fallback(counter.Label, name),
		Namespace:          counter.Namespace,
		NamespaceLabel:     namespaceLabel(counter.Namespace),
		ScopeLabel:         formatScopeLabel(counter.ScopeExample, counter.ScopeKeys),
		Increment:          fmt.Sprintf("%d", fallbackInt(counter.Increment, 1)),
		CurrentValue:       fmt.Sprintf("%d", counter.CurrentValue),
		LastUpdated:        formatter.Relative(counter.LastUpdated),
		LastUpdatedTooltip: formatter.Date(counter.LastUpdated, "2006-01-02 15:04"),
		Tags:               append([]string(nil), counter.Tags...),
		DrawerURL:          joinBasePath(basePath, fmt.Sprintf("/system/counters/%s/drawer", url.PathEscape(name))),
		Selected:           isSelected,
		RowClass:           rowClass,
	}
}

func toCounterHistoryItem(event adminsystem.CounterEvent) CounterHistoryItem {
	scopeLabel := formatScopeLabel(event.Scope, nil)
	return CounterHistoryItem{
		ID:         event.ID,
		Timestamp:  formatTimestamp(event.OccurredAt),
		Relative:   helpers.Relative(event.OccurredAt),
		Actor:      fallback(event.Actor, "system"),
		ActorEmail: event.ActorEmail,
		ScopeLabel: scopeLabel,
		Delta:      formatCounterDelta(event.Delta),
		Value:      fmt.Sprintf("%d", event.Value),
		Message:    event.Message,
		Source:     event.Source,
		AuditID:    event.AuditID,
	}
}

func toCounterJobView(basePath string, job adminsystem.CounterJob) CounterJobView {
	return CounterJobView{
		ID:          job.ID,
		Name:        job.Name,
		Description: job.Description,
		URL:         joinBasePath(basePath, job.URL),
		StatusLabel: fallback(job.StatusLabel, "-"),
		StatusTone:  fallback(job.StatusTone, "info"),
		LastRun:     helpers.Relative(job.LastRun),
	}
}

func formatScopeLabel(scope map[string]string, keys []string) string {
	if len(scope) == 0 {
		if len(keys) == 0 {
			return "-"
		}
		return strings.Join(keys, ", ")
	}
	pairs := make([]string, 0, len(scope))
	for key, value := range scope {
		pairs = append(pairs, fmt.Sprintf("%s=%s", key, value))
	}
	sort.Strings(pairs)
	return strings.Join(pairs, ", ")
}

func scopePlaceholder(scope map[string]string) string {
	if len(scope) == 0 {
		return "{}"
	}
	encoded, err := json.MarshalIndent(scope, "", "  ")
	if err != nil {
		return "{}"
	}
	return string(encoded)
}

func formatTimestamp(ts time.Time) string {
	if ts.IsZero() {
		return "-"
	}
	return helpers.Date(ts, "2006-01-02 15:04")
}

func formatCounterDelta(delta int64) string {
	if delta == 0 {
		return "±0"
	}
	sign := "+"
	if delta < 0 {
		sign = "-"
		delta = -delta
	}
	return fmt.Sprintf("%s%d", sign, delta)
}

func fallback(value, fallbackValue string) string {
	if strings.TrimSpace(value) == "" {
		return fallbackValue
	}
	return value
}

func fallbackInt(value, fallbackValue int64) int64 {
	if value == 0 {
		return fallbackValue
	}
	return value
}

func namespaceLabel(ns string) string {
	if strings.TrimSpace(ns) == "" {
		return "default"
	}
	parts := []rune(strings.ToLower(ns))
	if len(parts) == 0 {
		return ns
	}
	parts[0] = toUpper(parts[0])
	return string(parts)
}

func toUpper(r rune) rune {
	if r >= 'a' && r <= 'z' {
		return r - 32
	}
	return r
}

func joinBasePath(basePath, suffix string) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	base = strings.TrimRight(base, "/")
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	return base + suffix
}
