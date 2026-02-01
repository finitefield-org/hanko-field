package system

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData represents the full SSR payload for the system errors dashboard.
type PageData struct {
	Title           string
	Description     string
	Breadcrumbs     []partials.Breadcrumb
	SummaryCards    []SummaryCard
	Query           QueryState
	Filters         Filters
	TableEndpoint   string
	Table           TableData
	Drawer          DrawerData
	RunbookAlert    Alert
	RunbookSections []RunbookSection
	GeneratedLabel  string
}

// SummaryCard renders KPI chips in the header.
type SummaryCard struct {
	Label     string
	Value     string
	SubLabel  string
	Delta     string
	DeltaTone string
	Icon      string
}

// QueryState mirrors query string inputs.
type QueryState struct {
	Source     string
	Severity   string
	Service    string
	Status     string
	Search     string
	StartDate  string
	EndDate    string
	RawQuery   string
	SelectedID string
	Limit      string
}

// Filters groups available filter options.
type Filters struct {
	SourceOptions   []ToggleOption
	SeverityOptions []ToggleOption
	StatusOptions   []ToggleOption
	ServiceOptions  []SelectOption
}

// ToggleOption represents a segmented control option.
type ToggleOption struct {
	Value  string
	Label  string
	Count  int
	Tone   string
	Active bool
	Icon   string
}

// SelectOption renders select dropdown options.
type SelectOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// TableData represents the failures table fragment payload.
type TableData struct {
	Items        []TableRow
	Error        string
	EmptyMessage string
	Total        int
	FragmentPath string
	RawQuery     string
	SelectedID   string
	GeneratedAt  string
}

// TableRow is the display friendly table row model.
type TableRow struct {
	ID               string
	Name             string
	Service          string
	ServiceLabel     string
	SourceLabel      string
	SourceTone       string
	SeverityLabel    string
	SeverityTone     string
	StatusLabel      string
	StatusTone       string
	Message          string
	RetryLabel       string
	RetryTooltip     string
	TargetLabel      string
	TargetURL        string
	LastSeenRelative string
	LastSeenTooltip  string
	RunbookURL       string
	Actions          []RowAction
	Attributes       map[string]string
}

// RowAction renders the retry/acknowledge controls in the table.
type RowAction struct {
	Label    string
	URL      string
	Icon     string
	Variant  string
	Method   string
	Disabled bool
	Tooltip  string
}

// DrawerData powers the detail inspector.
type DrawerData struct {
	Empty            bool
	Error            string
	ID               string
	Title            string
	Subtitle         string
	Service          string
	SourceLabel      string
	SourceTone       string
	SeverityLabel    string
	SeverityTone     string
	StatusLabel      string
	StatusTone       string
	Message          string
	Code             string
	RetrySummary     string
	LastAttempt      string
	LastAttemptExact string
	NextRetry        string
	Target           TargetView
	Attributes       []KeyValue
	Links            []LinkView
	StackTrace       []string
	Payload          string
	Headers          []KeyValue
	Attempts         []AttemptView
	RunbookURL       string
	RunbookSteps     []RunbookStepView
}

// TargetView represents the impacted resource.
type TargetView struct {
	Label string
	URL   string
	Kind  string
}

// KeyValue renders metadata rows.
type KeyValue struct {
	Key   string
	Value string
}

// LinkView renders contextual links.
type LinkView struct {
	Label string
	URL   string
	Icon  string
}

// AttemptView renders attempt history entries.
type AttemptView struct {
	Number    int
	Timestamp string
	Relative  string
	Status    string
	Response  string
	Duration  string
}

// RunbookStepView renders runbook instructions.
type RunbookStepView struct {
	Title       string
	Description string
	Links       []LinkView
}

// Alert configures the inline runbook callout.
type Alert struct {
	Tone      string
	Title     string
	Body      string
	LinkLabel string
	LinkURL   string
	Icon      string
}

// RunbookSection configures the accordion of mitigation steps.
type RunbookSection struct {
	ID      string
	Title   string
	Summary string
	Steps   []RunbookSectionStep
}

// RunbookSectionStep renders individual mitigation steps.
type RunbookSectionStep struct {
	Title       string
	Description string
	LinkLabel   string
	LinkURL     string
}

// BuildPageData assembles the page payload.
func BuildPageData(basePath string, state QueryState, result adminsystem.FailureResult, table TableData, drawer DrawerData) PageData {
	generated := result.GeneratedAt
	if generated.IsZero() {
		generated = time.Now()
	}
	return PageData{
		Title:           "システムエラーダッシュボード",
		Description:     "背景処理・Webhook の失敗を監視し、迅速にリトライやエスカレーションを行います。",
		Breadcrumbs:     buildBreadcrumbs(basePath),
		SummaryCards:    buildSummaryCards(result.Metrics),
		Query:           state,
		Filters:         buildFilters(state, result.Filters),
		TableEndpoint:   joinBase(basePath, "/system/errors/table"),
		Table:           table,
		Drawer:          drawer,
		RunbookAlert:    runbookAlert(),
		RunbookSections: runbookSections(basePath),
		GeneratedLabel:  fmt.Sprintf("最終更新 %s", helpers.Date(generated, "15:04:05")),
	}
}

// TablePayload constructs the table fragment payload.
func TablePayload(basePath string, state QueryState, result adminsystem.FailureResult, selectedID string, errMsg string) TableData {
	rows := make([]TableRow, 0, len(result.Failures))
	for _, failure := range result.Failures {
		rows = append(rows, toTableRow(basePath, failure, selectedID))
	}
	emptyMessage := "失敗ログは見つかりませんでした。フィルタを調整してください。"
	generated := result.GeneratedAt
	if generated.IsZero() {
		generated = time.Now()
	}
	return TableData{
		Items:        rows,
		Error:        errMsg,
		EmptyMessage: emptyMessage,
		Total:        result.Total,
		FragmentPath: joinBase(basePath, "/system/errors/table"),
		RawQuery:     state.RawQuery,
		SelectedID:   selectedID,
		GeneratedAt:  helpers.Date(generated, "2006-01-02 15:04"),
	}
}

// DrawerPayload prepares the detail drawer payload.
func DrawerPayload(basePath string, summary *adminsystem.Failure, detail adminsystem.FailureDetail, errMsg string) DrawerData {
	if errMsg != "" {
		return DrawerData{
			Error: errMsg,
		}
	}
	if summary == nil && detail.Failure.ID == "" {
		return DrawerData{Empty: true}
	}

	failure := mergeFailure(summary, detail.Failure)
	data := DrawerData{
		Empty:            false,
		ID:               failure.ID,
		Title:            failure.Name,
		Subtitle:         failure.Service,
		Service:          failure.Service,
		SourceLabel:      sourceLabel(failure.Source),
		SourceTone:       sourceTone(failure.Source),
		SeverityLabel:    severityLabel(failure.Severity),
		SeverityTone:     severityTone(failure.Severity),
		StatusLabel:      statusLabel(failure.Status),
		StatusTone:       statusTone(failure.Status),
		Message:          failure.Message,
		Code:             failure.Code,
		RetrySummary:     fmt.Sprintf("%d / %d", failure.RetryCount, failure.MaxRetries),
		LastAttempt:      helpers.Relative(failure.LastSeen),
		LastAttemptExact: helpers.Date(failure.LastSeen, "2006-01-02 15:04"),
		Target: TargetView{
			Label: failure.Target.Label,
			URL:   failure.Target.URL,
			Kind:  failure.Target.Kind,
		},
		Attributes: keyValuesFromMap(failure.Attributes),
		Links:      linkViews(basePath, failure.Links),
		RunbookURL: failure.RunbookURL,
	}

	if detail.NextRetryAt != nil {
		data.NextRetry = helpers.Date(*detail.NextRetryAt, "2006-01-02 15:04")
	}
	if len(detail.StackTrace) > 0 {
		data.StackTrace = detail.StackTrace
	}
	if len(detail.Payload) > 0 {
		data.Payload = formatPayload(detail.Payload)
	} else if failure.LastPayload != "" {
		data.Payload = failure.LastPayload
	}
	if len(detail.Headers) > 0 {
		data.Headers = keyValuesFromMap(detail.Headers)
	}
	if len(detail.RecentAttempts) > 0 {
		data.Attempts = attemptViews(detail.RecentAttempts)
	}
	if len(detail.RunbookSteps) > 0 {
		data.RunbookSteps = runbookStepViews(basePath, detail.RunbookSteps)
	}
	return data
}

// FindFailure returns the failure with the provided ID if present.
func FindFailure(result adminsystem.FailureResult, failureID string) *adminsystem.Failure {
	for _, failure := range result.Failures {
		if failure.ID == failureID {
			return &failure
		}
	}
	return nil
}

func buildBreadcrumbs(basePath string) []partials.Breadcrumb {
	return []partials.Breadcrumb{
		{Label: "ダッシュボード", Href: joinBase(basePath, "/")},
		{Label: "システム", Href: joinBase(basePath, "/system/tasks")},
		{Label: "エラーダッシュボード", Href: joinBase(basePath, "/system/errors")},
	}
}

func buildSummaryCards(metrics adminsystem.MetricsSummary) []SummaryCard {
	failureValue := fmt.Sprintf("%d件", metrics.TotalFailures)
	if metrics.TotalFailures == 0 {
		failureValue = "0件"
	}
	successValue := fmt.Sprintf("%.1f%%", metrics.RetrySuccessRate)
	delta := formatDelta(metrics.RetrySuccessDelta)
	queueValue := fmt.Sprintf("%d", metrics.QueueBacklog)
	incidentValue := fmt.Sprintf("%d件", metrics.ActiveIncidents)

	return []SummaryCard{
		{
			Label:    "直近24時間の失敗",
			Value:    failureValue,
			SubLabel: fmt.Sprintf("%d 件のサンプル", metrics.RetrySuccessSample),
			Icon:     "🚨",
		},
		{
			Label:     "リトライ成功率",
			Value:     successValue,
			Delta:     delta.Value,
			DeltaTone: delta.Tone,
			Icon:      "⟳",
		},
		{
			Label:    "リトライ待ちキュー",
			Value:    queueValue,
			SubLabel: "未処理ジョブ",
			Icon:     "📬",
		},
		{
			Label:    "アクティブインシデント",
			Value:    incidentValue,
			SubLabel: "未解決",
			Icon:     "🧯",
		},
	}
}

func buildFilters(state QueryState, summary adminsystem.FilterSummary) Filters {
	sourceOptions := []ToggleOption{
		{
			Value:  "",
			Label:  "すべて",
			Active: state.Source == "",
			Tone:   "neutral",
		},
	}
	for _, source := range sortedSources(summary.SourceCounts) {
		sourceOptions = append(sourceOptions, ToggleOption{
			Value:  string(source),
			Label:  sourceLabel(source),
			Count:  summary.SourceCounts[source],
			Tone:   sourceTone(source),
			Active: state.Source == string(source),
			Icon:   sourceIcon(source),
		})
	}

	severityOptions := []ToggleOption{
		{
			Value:  "",
			Label:  "すべて",
			Active: state.Severity == "",
			Tone:   "neutral",
		},
	}
	for _, severity := range sortedSeverities(summary.SeverityCounts) {
		severityOptions = append(severityOptions, ToggleOption{
			Value:  string(severity),
			Label:  severityLabel(severity),
			Count:  summary.SeverityCounts[severity],
			Tone:   severityTone(severity),
			Active: state.Severity == string(severity),
		})
	}

	statusOptions := []ToggleOption{
		{
			Value:  "",
			Label:  "すべて",
			Active: state.Status == "",
			Tone:   "neutral",
		},
	}
	for _, status := range sortedStatuses(summary.StatusCounts) {
		statusOptions = append(statusOptions, ToggleOption{
			Value:  string(status),
			Label:  statusLabel(status),
			Count:  summary.StatusCounts[status],
			Tone:   statusTone(status),
			Active: state.Status == string(status),
		})
	}

	serviceOptions := []SelectOption{
		{
			Value:  "",
			Label:  "すべてのサービス",
			Active: state.Service == "",
		},
	}
	for _, service := range sortedServices(summary.ServiceCounts) {
		label := service
		count := summary.ServiceCounts[service]
		if count > 0 {
			label = fmt.Sprintf("%s (%d)", service, count)
		}
		serviceOptions = append(serviceOptions, SelectOption{
			Value:  service,
			Label:  label,
			Count:  count,
			Active: state.Service == service,
		})
	}

	return Filters{
		SourceOptions:   sourceOptions,
		SeverityOptions: severityOptions,
		StatusOptions:   statusOptions,
		ServiceOptions:  serviceOptions,
	}
}

func runbookAlert() Alert {
	return Alert{
		Tone:      "info",
		Title:     "障害対応のベストプラクティス",
		Body:      "Runbook コレクションから障害種別ごとの対応手順を確認できます。手順更新時は SRE チャンネルにも通知されます。",
		LinkLabel: "Runbook を開く",
		LinkURL:   "https://runbooks.hanko.local",
		Icon:      "📚",
	}
}

func runbookSections(basePath string) []RunbookSection {
	return []RunbookSection{
		{
			ID:      "webhooks",
			Title:   "Webhook 障害",
			Summary: "Webhook のリトライ設定とベンダー側再送手順をまとめています。",
			Steps: []RunbookSectionStep{
				{
					Title:       "ステータスコードの確認",
					Description: "410/422 などの永続的エラーか、500 系の一時的エラーかで対応を分岐します。",
				},
				{
					Title:       "リトライポリシーの調整",
					Description: "過度に失敗している場合はキュー設定を見直し、指数バックオフを適用します。",
					LinkLabel:   "キュー設定を開く",
					LinkURL:     joinBase(basePath, "/system/tasks"),
				},
				{
					Title:       "ベンダーへの確認",
					Description: "連携先のステータスページと通知チャンネルを確認し、既知障害か判定します。",
				},
			},
		},
		{
			ID:      "jobs",
			Title:   "バッチ・ジョブ失敗",
			Summary: "Firestore 競合や外部 API 制限のようなジョブ特有の障害パターンに対応します。",
			Steps: []RunbookSectionStep{
				{
					Title:       "スケジュールの変更",
					Description: "ピークタイムを避けるために一時的にジョブの開始時間を後ろ倒しします。",
				},
				{
					Title:       "負荷の分割",
					Description: "バッチ単位を細分化し、リトライ時の処理量を抑えます。",
				},
				{
					Title:       "SRE へのエスカレーション",
					Description: "連続失敗が続く場合は SRE チームに連絡し、恒久対応を検討します。",
					LinkLabel:   "エスカレーション手順",
					LinkURL:     "https://runbooks.hanko.local/escalation",
				},
			},
		},
	}
}

func toTableRow(basePath string, failure adminsystem.Failure, selectedID string) TableRow {
	attrs := map[string]string{
		"data-system-error-row": "true",
		"data-system-error-id":  failure.ID,
		"hx-get":                joinBase(basePath, fmt.Sprintf("/system/errors/%s/drawer", failure.ID)),
		"hx-target":             "#system-error-drawer",
		"hx-swap":               "innerHTML",
	}
	return TableRow{
		ID:               failure.ID,
		Name:             failure.Name,
		Service:          failure.Service,
		ServiceLabel:     failure.Service,
		SourceLabel:      sourceLabel(failure.Source),
		SourceTone:       sourceTone(failure.Source),
		SeverityLabel:    severityLabel(failure.Severity),
		SeverityTone:     severityTone(failure.Severity),
		StatusLabel:      statusLabel(failure.Status),
		StatusTone:       statusTone(failure.Status),
		Message:          failure.Message,
		RetryLabel:       fmt.Sprintf("%d / %d", failure.RetryCount, failure.MaxRetries),
		RetryTooltip:     retryTooltip(failure),
		TargetLabel:      failure.Target.Label,
		TargetURL:        failure.Target.URL,
		LastSeenRelative: helpers.Relative(failure.LastSeen),
		LastSeenTooltip:  helpers.Date(failure.LastSeen, "2006-01-02 15:04"),
		RunbookURL:       failure.RunbookURL,
		Actions:          rowActions(basePath, failure),
		Attributes:       attrs,
	}
}

func rowActions(basePath string, failure adminsystem.Failure) []RowAction {
	actions := make([]RowAction, 0, 2)
	if failure.RetryAvailable {
		actions = append(actions, RowAction{
			Label:   "再実行",
			URL:     joinBase(basePath, fmt.Sprintf("/system/errors/%s:retry", failure.ID)),
			Icon:    "⟳",
			Variant: "primary",
			Method:  "post",
		})
	}
	if failure.AckAvailable {
		actions = append(actions, RowAction{
			Label:   "確認済みにする",
			URL:     joinBase(basePath, fmt.Sprintf("/system/errors/%s:acknowledge", failure.ID)),
			Icon:    "✅",
			Variant: "secondary",
			Method:  "post",
		})
	}
	return actions
}

func mergeFailure(summary *adminsystem.Failure, detailed adminsystem.Failure) adminsystem.Failure {
	if summary == nil {
		return detailed
	}
	if detailed.ID == "" {
		return *summary
	}
	result := detailed
	if result.Service == "" {
		result.Service = summary.Service
	}
	if result.Name == "" {
		result.Name = summary.Name
	}
	if result.Message == "" {
		result.Message = summary.Message
	}
	if result.Target.Label == "" {
		result.Target = summary.Target
	}
	if result.RunbookURL == "" {
		result.RunbookURL = summary.RunbookURL
	}
	if len(result.Attributes) == 0 {
		result.Attributes = summary.Attributes
	}
	if result.RetryCount == 0 {
		result.RetryCount = summary.RetryCount
	}
	if result.MaxRetries == 0 {
		result.MaxRetries = summary.MaxRetries
	}
	if result.Severity == "" {
		result.Severity = summary.Severity
	}
	if result.Status == "" {
		result.Status = summary.Status
	}
	if result.Source == "" {
		result.Source = summary.Source
	}
	if result.LastPayload == "" {
		result.LastPayload = summary.LastPayload
	}
	if len(result.Links) == 0 {
		result.Links = summary.Links
	}
	return result
}

func keyValuesFromMap(values map[string]string) []KeyValue {
	if len(values) == 0 {
		return nil
	}
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	pairs := make([]KeyValue, 0, len(keys))
	for _, key := range keys {
		pairs = append(pairs, KeyValue{Key: key, Value: values[key]})
	}
	return pairs
}

func linkViews(basePath string, links []adminsystem.Link) []LinkView {
	if len(links) == 0 {
		return nil
	}
	views := make([]LinkView, 0, len(links))
	for _, link := range links {
		url := link.URL
		if strings.HasPrefix(link.URL, "/") {
			url = joinBase(basePath, link.URL)
		}
		views = append(views, LinkView{
			Label: link.Label,
			URL:   url,
			Icon:  link.Icon,
		})
	}
	return views
}

func attemptViews(attempts []adminsystem.Attempt) []AttemptView {
	if len(attempts) == 0 {
		return nil
	}
	views := make([]AttemptView, 0, len(attempts))
	for _, attempt := range attempts {
		views = append(views, AttemptView{
			Number:    attempt.Number,
			Timestamp: helpers.Date(attempt.OccurredAt, "2006-01-02 15:04"),
			Relative:  helpers.Relative(attempt.OccurredAt),
			Status:    attempt.Status,
			Response:  attempt.Response,
			Duration:  attempt.Duration.Round(time.Second).String(),
		})
	}
	return views
}

func runbookStepViews(basePath string, steps []adminsystem.RunbookStep) []RunbookStepView {
	if len(steps) == 0 {
		return nil
	}
	views := make([]RunbookStepView, 0, len(steps))
	for _, step := range steps {
		view := RunbookStepView{
			Title:       step.Title,
			Description: step.Description,
		}
		if len(step.Links) > 0 {
			view.Links = linkViews(basePath, step.Links)
		}
		views = append(views, view)
	}
	return views
}

func retryTooltip(failure adminsystem.Failure) string {
	if failure.MaxRetries == 0 {
		return ""
	}
	return fmt.Sprintf("リトライ %d / %d", failure.RetryCount, failure.MaxRetries)
}

type deltaView struct {
	Value string
	Tone  string
}

func formatDelta(value float64) deltaView {
	if value == 0 {
		return deltaView{Value: "±0%", Tone: "neutral"}
	}
	sign := "+"
	tone := "success"
	if value < 0 {
		sign = ""
		tone = "danger"
	}
	return deltaView{
		Value: fmt.Sprintf("%s%.1f%%", sign, value),
		Tone:  tone,
	}
}

func formatPayload(payload map[string]any) string {
	bytes, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return "{}"
	}
	return string(bytes)
}

func sortedSources(counts map[adminsystem.Source]int) []adminsystem.Source {
	keys := make([]adminsystem.Source, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		return sourceLabel(keys[i]) < sourceLabel(keys[j])
	})
	return keys
}

func sortedSeverities(counts map[adminsystem.Severity]int) []adminsystem.Severity {
	keys := make([]adminsystem.Severity, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		return severityOrder(keys[i]) < severityOrder(keys[j])
	})
	return keys
}

func sortedStatuses(counts map[adminsystem.Status]int) []adminsystem.Status {
	keys := make([]adminsystem.Status, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		return statusOrder(keys[i]) < statusOrder(keys[j])
	})
	return keys
}

func sortedServices(counts map[string]int) []string {
	keys := make([]string, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func severityOrder(severity adminsystem.Severity) int {
	switch severity {
	case adminsystem.SeverityCritical:
		return 0
	case adminsystem.SeverityHigh:
		return 1
	case adminsystem.SeverityMedium:
		return 2
	case adminsystem.SeverityLow:
		return 3
	default:
		return 10
	}
}

func statusOrder(status adminsystem.Status) int {
	switch status {
	case adminsystem.StatusOpen:
		return 0
	case adminsystem.StatusAcknowledged:
		return 1
	case adminsystem.StatusSuppressed:
		return 2
	case adminsystem.StatusResolved:
		return 3
	default:
		return 10
	}
}

func sourceLabel(source adminsystem.Source) string {
	switch source {
	case adminsystem.SourceJob:
		return "ジョブ"
	case adminsystem.SourceWebhook:
		return "Webhook"
	case adminsystem.SourceAPI:
		return "API"
	case adminsystem.SourceWorker:
		return "ワーカー"
	default:
		return "その他"
	}
}

func sourceTone(source adminsystem.Source) string {
	switch source {
	case adminsystem.SourceJob:
		return "info"
	case adminsystem.SourceWebhook:
		return "warning"
	case adminsystem.SourceAPI:
		return "danger"
	case adminsystem.SourceWorker:
		return "info"
	default:
		return "neutral"
	}
}

func sourceIcon(source adminsystem.Source) string {
	switch source {
	case adminsystem.SourceJob:
		return "⏱"
	case adminsystem.SourceWebhook:
		return "🔁"
	case adminsystem.SourceAPI:
		return "🛰"
	case adminsystem.SourceWorker:
		return "⚙️"
	default:
		return "📄"
	}
}

func severityLabel(severity adminsystem.Severity) string {
	switch severity {
	case adminsystem.SeverityCritical:
		return "クリティカル"
	case adminsystem.SeverityHigh:
		return "高"
	case adminsystem.SeverityMedium:
		return "中"
	case adminsystem.SeverityLow:
		return "低"
	default:
		return "不明"
	}
}

func severityTone(severity adminsystem.Severity) string {
	switch severity {
	case adminsystem.SeverityCritical:
		return "danger"
	case adminsystem.SeverityHigh:
		return "warning"
	case adminsystem.SeverityMedium:
		return "info"
	case adminsystem.SeverityLow:
		return "neutral"
	default:
		return "neutral"
	}
}

func statusLabel(status adminsystem.Status) string {
	switch status {
	case adminsystem.StatusOpen:
		return "新規"
	case adminsystem.StatusAcknowledged:
		return "対応中"
	case adminsystem.StatusResolved:
		return "解決済み"
	case adminsystem.StatusSuppressed:
		return "サプレッサー中"
	default:
		return "不明"
	}
}

func statusTone(status adminsystem.Status) string {
	switch status {
	case adminsystem.StatusOpen:
		return "danger"
	case adminsystem.StatusAcknowledged:
		return "warning"
	case adminsystem.StatusSuppressed:
		return "info"
	case adminsystem.StatusResolved:
		return "success"
	default:
		return "neutral"
	}
}

func joinBase(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" {
		base = "/"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	base = strings.TrimRight(base, "/")
	if base == "" {
		base = "/"
	}

	suffix = strings.TrimSpace(suffix)
	if suffix == "" || suffix == "/" {
		return base
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	path := base + suffix
	for strings.Contains(path, "//") {
		path = strings.ReplaceAll(path, "//", "/")
	}
	return path
}
