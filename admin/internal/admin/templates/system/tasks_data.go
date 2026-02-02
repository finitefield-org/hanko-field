package system

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// TasksPageData represents the full payload for the tasks monitor page.
type TasksPageData struct {
	Title          string
	Description    string
	Breadcrumbs    []partials.Breadcrumb
	Scheduler      SchedulerBadge
	Alerts         []TaskAlertView
	Query          TasksQueryState
	Filters        TasksFilters
	TableEndpoint  string
	Table          TasksTableData
	Drawer         TasksDrawerData
	History        TaskHistoryChart
	GeneratedLabel string
}

// SchedulerBadge renders the scheduler heartbeat indicator.
type SchedulerBadge struct {
	Label     string
	Tone      string
	Message   string
	Latency   string
	CheckedAt string
}

// TaskAlertView renders prominent alerts on the page.
type TaskAlertView struct {
	ID      string
	Tone    string
	Title   string
	Message string
	Action  TaskAlertActionView
}

// TaskAlertActionView represents alert escalation controls.
type TaskAlertActionView struct {
	Label  string
	URL    string
	Method string
	Icon   string
}

// TasksQueryState mirrors filter inputs.
type TasksQueryState struct {
	Type       string
	State      string
	Host       string
	Window     string
	Search     string
	SelectedID string
	Limit      string
	RawQuery   string
}

// TasksFilters groups available filter options.
type TasksFilters struct {
	TypeOptions   []ToggleOption
	StateOptions  []ToggleOption
	HostOptions   []SelectOption
	WindowOptions []SelectOption
}

// TasksTableData represents the jobs table fragment payload.
type TasksTableData struct {
	Items        []TasksTableRow
	Error        string
	EmptyMessage string
	Total        int
	FragmentPath string
	RawQuery     string
	SelectedID   string
	GeneratedAt  string
}

// TasksTableRow renders a job in the table.
type TasksTableRow struct {
	ID              string
	Name            string
	Description     string
	TypeLabel       string
	TypeTone        string
	Host            string
	Schedule        string
	StatusLabel     string
	StatusTone      string
	LastRunRelative string
	LastRunTooltip  string
	DurationLabel   string
	NextRunRelative string
	NextRunTooltip  string
	SuccessRate     string
	Tags            []string
	Actions         []TaskRowAction
	Attributes      map[string]string
}

// TaskRowAction represents row-level actions.
type TaskRowAction struct {
	Label    string
	URL      string
	Method   string
	Icon     string
	Disabled bool
	Tooltip  string
	Confirm  string
}

// TasksDrawerData powers the drawer detail view.
type TasksDrawerData struct {
	Empty       bool
	Error       string
	Job         TasksDrawerJob
	Parameters  []KeyValue
	Environment []KeyValue
	Runs        []TaskRunView
	History     TaskHistoryChart
	Insights    []TaskInsightView
	Actions     []TaskDrawerAction
}

// TasksDrawerJob summarises job metadata in the drawer.
type TasksDrawerJob struct {
	ID                 string
	Name               string
	Description        string
	TypeLabel          string
	TypeTone           string
	StateLabel         string
	StateTone          string
	Schedule           string
	Host               string
	Queue              string
	SuccessRate        string
	AverageDuration    string
	LastRunRelative    string
	LastRunStatusLabel string
	LastRunStatusTone  string
	NextRunRelative    string
	NextRunExact       string
	RunbookURL         string
	LogsURL            string
	Tags               []string
}

// TaskRunView renders individual run entries.
type TaskRunView struct {
	ID          string
	StatusLabel string
	StatusTone  string
	StartedAt   string
	Relative    string
	Duration    string
	Trigger     string
	Worker      string
	Region      string
	LogsURL     string
	Attempt     string
	Error       string
}

// TaskHistoryChart powers the run history chart.
type TaskHistoryChart struct {
	Empty  bool
	Points []TaskHistoryPointView
}

// TaskHistoryPointView represents a single plotted point.
type TaskHistoryPointView struct {
	Label           string
	Tooltip         string
	DurationSeconds float64
	StatusTone      string
}

// TaskInsightView renders insight callouts.
type TaskInsightView struct {
	Title       string
	Description string
	Tone        string
	Icon        string
}

// TaskDrawerAction renders manual control buttons in the drawer.
type TaskDrawerAction struct {
	Label     string
	URL       string
	Method    string
	Icon      string
	Confirm   string
	Dangerous bool
	Disabled  bool
	Tooltip   string
}

// BuildTasksPageData assembles the SSR payload for the tasks monitor.
func BuildTasksPageData(ctx context.Context, basePath string, state TasksQueryState, result adminsystem.JobResult, table TasksTableData, drawer TasksDrawerData, history TaskHistoryChart) TasksPageData {
	formatter := helpers.NewFormatter(ctx)
	return TasksPageData{
		Title:          "タスク / ジョブ監視",
		Description:    "スケジューラの実行状況、失敗、および手動オペレーションを可視化します。",
		Breadcrumbs:    tasksBreadcrumbs(basePath),
		Scheduler:      schedulerBadge(result.Scheduler),
		Alerts:         taskAlerts(result.Alerts),
		Query:          state,
		Filters:        taskFilters(basePath, state, result.Filters, result.Jobs),
		TableEndpoint:  joinBase(basePath, "/system/tasks/table"),
		Table:          table,
		Drawer:         drawer,
		History:        history,
		GeneratedLabel: fmt.Sprintf("%s: %s", formatter.T("common.last_updated"), formatter.Relative(result.GeneratedAt)),
	}
}

// TasksTablePayload prepares the HTMX table payload.
func TasksTablePayload(basePath string, state TasksQueryState, result adminsystem.JobResult, selectedID string, errMsg string) TasksTableData {
	rows := make([]TasksTableRow, 0, len(result.Jobs))
	for _, job := range result.Jobs {
		rows = append(rows, toTaskRow(basePath, job, selectedID))
	}
	generated := ""
	if !result.GeneratedAt.IsZero() {
		generated = helpers.Date(result.GeneratedAt, "2006-01-02 15:04")
	}
	empty := "現在表示できるタスクはありません。フィルタ条件を調整してください。"
	return TasksTableData{
		Items:        rows,
		Error:        errMsg,
		EmptyMessage: empty,
		Total:        len(result.Jobs),
		FragmentPath: joinBase(basePath, "/system/tasks/table"),
		RawQuery:     state.RawQuery,
		SelectedID:   selectedID,
		GeneratedAt:  generated,
	}
}

// TasksDrawerPayload builds the drawer payload for the selected job.
func TasksDrawerPayload(basePath string, job adminsystem.Job, detail adminsystem.JobDetail, errMsg string) TasksDrawerData {
	if errMsg != "" {
		return TasksDrawerData{Error: errMsg, Empty: false}
	}
	if job.ID == "" && detail.Job.ID == "" {
		return TasksDrawerData{Empty: true}
	}
	// prefer enriched job detail
	summary := mergeJobSummary(job, detail.Job)
	drawerJob := TasksDrawerJob{
		ID:                 summary.ID,
		Name:               summary.Name,
		Description:        summary.Description,
		TypeLabel:          jobTypeLabel(summary.Type),
		TypeTone:           jobTypeTone(summary.Type),
		StateLabel:         jobStateLabel(summary.State),
		StateTone:          jobStateTone(summary.State),
		Schedule:           summary.Schedule,
		Host:               summary.Host,
		Queue:              summary.Queue,
		SuccessRate:        formatSuccessRate(summary.SuccessRate),
		AverageDuration:    formatDuration(summary.AverageDuration),
		LastRunRelative:    relativeOrDash(summary.LastRun.StartedAt),
		LastRunStatusLabel: jobRunStatusLabel(summary.LastRun.Status),
		LastRunStatusTone:  jobRunStatusTone(summary.LastRun.Status),
		NextRunRelative:    nextRunRelative(summary.NextRun),
		NextRunExact:       nextRunExact(summary.NextRun),
		RunbookURL:         summary.PrimaryRunbookURL,
		LogsURL:            summary.LogsURL,
		Tags:               append([]string(nil), summary.Tags...),
	}
	parameters := keyValuesFromMap(detail.Parameters)
	environment := keyValuesFromMap(detail.Environment)
	runs := make([]TaskRunView, 0, len(detail.RecentRuns))
	sortedRuns := append([]adminsystem.JobRun(nil), detail.RecentRuns...)
	sort.Slice(sortedRuns, func(i, j int) bool {
		return sortedRuns[i].StartedAt.After(sortedRuns[j].StartedAt)
	})
	for _, run := range sortedRuns {
		runs = append(runs, toTaskRunView(run))
	}
	insights := make([]TaskInsightView, 0, len(detail.Insights))
	for _, insight := range detail.Insights {
		insights = append(insights, TaskInsightView{
			Title:       insight.Title,
			Description: insight.Description,
			Tone:        normalizeTone(insight.Tone),
			Icon:        insight.Icon,
		})
	}
	actions := make([]TaskDrawerAction, 0, len(detail.ManualActions))
	for _, action := range detail.ManualActions {
		actions = append(actions, TaskDrawerAction{
			Label:     action.Label,
			URL:       joinBase(basePath, action.URL),
			Method:    strings.ToUpper(action.Method),
			Icon:      action.Icon,
			Confirm:   action.Confirm,
			Dangerous: action.Dangerous,
			Disabled:  action.Disabled,
			Tooltip:   action.Tooltip,
		})
	}
	return TasksDrawerData{
		Empty:       false,
		Error:       "",
		Job:         drawerJob,
		Parameters:  parameters,
		Environment: environment,
		Runs:        runs,
		History:     historyChart(detail.History),
		Insights:    insights,
		Actions:     actions,
	}
}

// historyChart converts history points to chart data.
func historyChart(points []adminsystem.JobHistoryPoint) TaskHistoryChart {
	if len(points) == 0 {
		return TaskHistoryChart{Empty: true}
	}
	sorted := append([]adminsystem.JobHistoryPoint(nil), points...)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Timestamp.Before(sorted[j].Timestamp)
	})
	view := make([]TaskHistoryPointView, 0, len(sorted))
	for _, point := range sorted {
		label := point.Timestamp.Format("01/02 15:04")
		tooltip := fmt.Sprintf("%s • %s", label, jobRunStatusLabel(point.Status))
		view = append(view, TaskHistoryPointView{
			Label:           label,
			Tooltip:         tooltip,
			DurationSeconds: point.Duration.Seconds(),
			StatusTone:      jobRunStatusTone(point.Status),
		})
	}
	return TaskHistoryChart{Points: view}
}

func tasksBreadcrumbs(basePath string) []partials.Breadcrumb {
	return []partials.Breadcrumb{
		{Label: "ダッシュボード", Href: joinBase(basePath, "/")},
		{Label: "システム", Href: joinBase(basePath, "/system/tasks")},
		{Label: "タスク / ジョブ監視", Href: joinBase(basePath, "/system/tasks")},
	}
}

func schedulerBadge(health adminsystem.SchedulerHealth) SchedulerBadge {
	if health.Status == "" {
		return SchedulerBadge{}
	}
	return SchedulerBadge{
		Label:     health.Label,
		Tone:      jobStateTone(health.Status),
		Message:   health.Message,
		Latency:   formatLatency(health.Latency),
		CheckedAt: helpers.Relative(health.CheckedAt),
	}
}

func taskAlerts(alerts []adminsystem.JobAlert) []TaskAlertView {
	views := make([]TaskAlertView, 0, len(alerts))
	for _, alert := range alerts {
		views = append(views, TaskAlertView{
			ID:      alert.ID,
			Tone:    normalizeTone(alert.Tone),
			Title:   alert.Title,
			Message: alert.Message,
			Action: TaskAlertActionView{
				Label:  alert.Action.Label,
				URL:    alert.Action.URL,
				Method: alert.Action.Method,
				Icon:   alert.Action.Icon,
			},
		})
	}
	return views
}

func taskFilters(basePath string, state TasksQueryState, summary adminsystem.JobFilterSummary, jobs []adminsystem.Job) TasksFilters {
	return TasksFilters{
		TypeOptions:   taskTypeOptions(state.Type, summary.TypeCounts),
		StateOptions:  taskStateOptions(state.State, summary.StateCounts),
		HostOptions:   taskHostOptions(state.Host, summary.HostCounts, jobs),
		WindowOptions: taskWindowOptions(state.Window, summary.Windows, len(jobs)),
	}
}

func taskTypeOptions(selected string, counts map[adminsystem.JobType]int) []ToggleOption {
	options := []struct {
		Value adminsystem.JobType
		Label string
		Icon  string
	}{
		{adminsystem.JobTypeScheduled, "定期", "⏲"},
		{adminsystem.JobTypeBatch, "バッチ", "📦"},
		{adminsystem.JobTypeAdhoc, "手動", "🧑‍💻"},
		{adminsystem.JobTypeEvent, "イベント", "⚡"},
	}
	views := make([]ToggleOption, 0, len(options)+1)
	views = append(views, ToggleOption{
		Value:  "",
		Label:  "すべて",
		Count:  0,
		Tone:   "neutral",
		Active: strings.TrimSpace(selected) == "",
	})
	for _, opt := range options {
		value := string(opt.Value)
		views = append(views, ToggleOption{
			Value:  value,
			Label:  opt.Label,
			Icon:   opt.Icon,
			Tone:   jobTypeTone(opt.Value),
			Count:  counts[opt.Value],
			Active: strings.TrimSpace(selected) == value,
		})
	}
	return views
}

func taskStateOptions(selected string, counts map[adminsystem.JobState]int) []ToggleOption {
	states := []adminsystem.JobState{
		adminsystem.JobStateHealthy,
		adminsystem.JobStateRunning,
		adminsystem.JobStateDegraded,
		adminsystem.JobStateFailed,
		adminsystem.JobStatePaused,
	}
	views := make([]ToggleOption, 0, len(states)+1)
	views = append(views, ToggleOption{
		Value:  "",
		Label:  "すべて",
		Tone:   "neutral",
		Count:  0,
		Active: strings.TrimSpace(selected) == "",
	})
	for _, state := range states {
		value := string(state)
		views = append(views, ToggleOption{
			Value:  value,
			Label:  jobStateLabel(state),
			Tone:   jobStateTone(state),
			Count:  counts[state],
			Active: strings.TrimSpace(selected) == value,
		})
	}
	return views
}

func taskHostOptions(selected string, counts map[string]int, jobs []adminsystem.Job) []SelectOption {
	options := make([]SelectOption, 0, len(counts)+1)
	op := SelectOption{
		Value:  "",
		Label:  "すべてのホスト",
		Count:  len(jobs),
		Active: strings.TrimSpace(selected) == "",
	}
	options = append(options, op)
	keys := make([]string, 0, len(counts))
	for host := range counts {
		keys = append(keys, host)
	}
	sort.Strings(keys)
	for _, host := range keys {
		options = append(options, SelectOption{
			Value:  host,
			Label:  host,
			Count:  counts[host],
			Active: strings.TrimSpace(selected) == host,
		})
	}
	return options
}

func taskWindowOptions(selected string, windows []adminsystem.JobWindowOption, total int) []SelectOption {
	options := make([]SelectOption, 0, len(windows)+1)
	options = append(options, SelectOption{
		Value:  "",
		Label:  "すべて",
		Count:  total,
		Active: strings.TrimSpace(selected) == "",
	})
	for _, window := range windows {
		options = append(options, SelectOption{
			Value:  window.Value,
			Label:  window.Label,
			Count:  window.Count,
			Active: strings.TrimSpace(selected) == window.Value,
		})
	}
	return options
}

func toTaskRow(basePath string, job adminsystem.Job, selectedID string) TasksTableRow {
	attrs := map[string]string{
		"data-system-task-row": "true",
		"data-system-task-id":  job.ID,
		"hx-get":               joinBase(basePath, fmt.Sprintf("/system/tasks/jobs/%s/drawer", job.ID)),
		"hx-target":            "#system-task-drawer",
		"hx-swap":              "innerHTML",
	}
	return TasksTableRow{
		ID:              job.ID,
		Name:            job.Name,
		Description:     job.Description,
		TypeLabel:       jobTypeLabel(job.Type),
		TypeTone:        jobTypeTone(job.Type),
		Host:            job.Host,
		Schedule:        job.Schedule,
		StatusLabel:     jobStateLabel(job.State),
		StatusTone:      jobStateTone(job.State),
		LastRunRelative: relativeOrDash(job.LastRun.StartedAt),
		LastRunTooltip:  helpers.Date(job.LastRun.StartedAt, "2006-01-02 15:04"),
		DurationLabel:   formatDuration(job.LastRun.Duration),
		NextRunRelative: nextRunRelative(job.NextRun),
		NextRunTooltip:  nextRunExact(job.NextRun),
		SuccessRate:     formatSuccessRate(job.SuccessRate),
		Tags:            append([]string(nil), job.Tags...),
		Actions:         taskRowActions(basePath, job),
		Attributes:      attrs,
	}
}

func taskRowActions(basePath string, job adminsystem.Job) []TaskRowAction {
	actions := make([]TaskRowAction, 0, 2)
	if job.ManualTrigger {
		actions = append(actions, TaskRowAction{
			Label:   "手動実行",
			URL:     joinBase(basePath, fmt.Sprintf("/system/tasks/jobs/%s:trigger", job.ID)),
			Method:  "POST",
			Icon:    "⏱",
			Confirm: fmt.Sprintf("%s を今すぐ実行しますか？", job.Name),
		})
	}
	if job.RetryAvailable && !job.ManualTrigger {
		actions = append(actions, TaskRowAction{
			Label:   "再実行",
			URL:     joinBase(basePath, fmt.Sprintf("/system/tasks/jobs/%s:trigger", job.ID)),
			Method:  "POST",
			Icon:    "⟳",
			Confirm: fmt.Sprintf("%s を再実行しますか？", job.Name),
		})
	}
	return actions
}

func toTaskRunView(run adminsystem.JobRun) TaskRunView {
	attempt := ""
	if run.Attempt > 0 {
		attempt = fmt.Sprintf("Attempt %d", run.Attempt)
	}
	return TaskRunView{
		ID:          run.ID,
		StatusLabel: jobRunStatusLabel(run.Status),
		StatusTone:  jobRunStatusTone(run.Status),
		StartedAt:   helpers.Date(run.StartedAt, "2006-01-02 15:04"),
		Relative:    helpers.Relative(run.StartedAt),
		Duration:    formatDuration(run.Duration),
		Trigger:     jobTriggerLabel(run.Trigger, run.TriggeredBy),
		Worker:      run.Worker,
		Region:      run.Region,
		LogsURL:     run.LogsURL,
		Attempt:     attempt,
		Error:       run.Error,
	}
}

func mergeJobSummary(summary adminsystem.Job, detailed adminsystem.Job) adminsystem.Job {
	if detailed.ID == "" {
		return summary
	}
	merged := detailed
	if merged.Name == "" {
		merged.Name = summary.Name
	}
	if merged.Description == "" {
		merged.Description = summary.Description
	}
	if merged.Type == "" {
		merged.Type = summary.Type
	}
	if merged.State == "" {
		merged.State = summary.State
	}
	if merged.Host == "" {
		merged.Host = summary.Host
	}
	if merged.Schedule == "" {
		merged.Schedule = summary.Schedule
	}
	if merged.Queue == "" {
		merged.Queue = summary.Queue
	}
	if merged.PrimaryRunbookURL == "" {
		merged.PrimaryRunbookURL = summary.PrimaryRunbookURL
	}
	if merged.LogsURL == "" {
		merged.LogsURL = summary.LogsURL
	}
	if merged.LastRun.ID == "" {
		merged.LastRun = summary.LastRun
	}
	if merged.NextRun.IsZero() {
		merged.NextRun = summary.NextRun
	}
	if merged.AverageDuration == 0 {
		merged.AverageDuration = summary.AverageDuration
	}
	if merged.SuccessRate == 0 {
		merged.SuccessRate = summary.SuccessRate
	}
	if len(merged.Tags) == 0 {
		merged.Tags = summary.Tags
	}
	return merged
}

func jobTypeLabel(t adminsystem.JobType) string {
	switch t {
	case adminsystem.JobTypeBatch:
		return "バッチ"
	case adminsystem.JobTypeAdhoc:
		return "手動"
	case adminsystem.JobTypeEvent:
		return "イベント"
	case adminsystem.JobTypeScheduled:
		fallthrough
	default:
		return "定期"
	}
}

func jobTypeTone(t adminsystem.JobType) string {
	switch t {
	case adminsystem.JobTypeBatch:
		return "info"
	case adminsystem.JobTypeAdhoc:
		return "secondary"
	case adminsystem.JobTypeEvent:
		return "success"
	default:
		return "primary"
	}
}

func jobStateLabel(state adminsystem.JobState) string {
	switch state {
	case adminsystem.JobStateHealthy:
		return "正常"
	case adminsystem.JobStateRunning:
		return "実行中"
	case adminsystem.JobStateDegraded:
		return "注意"
	case adminsystem.JobStateFailed:
		return "失敗"
	case adminsystem.JobStatePaused:
		return "停止"
	default:
		return "不明"
	}
}

func jobStateTone(state adminsystem.JobState) string {
	switch state {
	case adminsystem.JobStateHealthy:
		return "success"
	case adminsystem.JobStateRunning:
		return "info"
	case adminsystem.JobStateDegraded:
		return "warning"
	case adminsystem.JobStateFailed:
		return "danger"
	case adminsystem.JobStatePaused:
		return "secondary"
	default:
		return "neutral"
	}
}

func jobRunStatusLabel(status adminsystem.JobRunStatus) string {
	switch status {
	case adminsystem.JobRunSuccess:
		return "成功"
	case adminsystem.JobRunFailed:
		return "失敗"
	case adminsystem.JobRunRunning:
		return "実行中"
	case adminsystem.JobRunCancelled:
		return "キャンセル"
	case adminsystem.JobRunQueued:
		return "待機"
	default:
		return "不明"
	}
}

func jobRunStatusTone(status adminsystem.JobRunStatus) string {
	switch status {
	case adminsystem.JobRunSuccess:
		return "success"
	case adminsystem.JobRunFailed:
		return "danger"
	case adminsystem.JobRunRunning:
		return "info"
	case adminsystem.JobRunCancelled:
		return "secondary"
	case adminsystem.JobRunQueued:
		return "warning"
	default:
		return "neutral"
	}
}

func jobTriggerLabel(trigger adminsystem.JobTrigger, actor string) string {
	switch trigger {
	case adminsystem.JobTriggerManual:
		if strings.TrimSpace(actor) != "" {
			return fmt.Sprintf("手動 (%s)", actor)
		}
		return "手動"
	case adminsystem.JobTriggerRetry:
		return "リトライ"
	case adminsystem.JobTriggerDependency:
		return "依存タスク"
	default:
		return "スケジューラ"
	}
}

func formatDuration(d time.Duration) string {
	if d <= 0 {
		return "-"
	}
	if d < time.Minute {
		return fmt.Sprintf("%d秒", int(d.Seconds()))
	}
	if d < time.Hour {
		return fmt.Sprintf("%d分%d秒", int(d.Minutes()), int(d.Seconds())%60)
	}
	hours := int(d.Hours())
	minutes := int(d.Minutes()) % 60
	return fmt.Sprintf("%d時間%02d分", hours, minutes)
}

func formatSuccessRate(rate float64) string {
	if rate <= 0 {
		return "-"
	}
	if rate > 1 {
		rate = rate / 100.0
	}
	return fmt.Sprintf("%.0f%%", rate*100)
}

func relativeOrDash(ts time.Time) string {
	if ts.IsZero() {
		return "-"
	}
	return helpers.Relative(ts)
}

func nextRunRelative(next time.Time) string {
	if next.IsZero() {
		return "未定"
	}
	if next.Before(time.Now()) {
		return "期限超過"
	}
	return helpers.Relative(next)
}

func nextRunExact(next time.Time) string {
	if next.IsZero() {
		return "未定"
	}
	return helpers.Date(next, "2006-01-02 15:04")
}

func formatLatency(latency time.Duration) string {
	if latency <= 0 {
		return ""
	}
	if latency < time.Minute {
		return fmt.Sprintf("遅延 %d秒", int(latency.Seconds()))
	}
	return fmt.Sprintf("遅延 %d分", int(latency.Minutes()))
}

func normalizeTone(tone string) string {
	t := strings.ToLower(strings.TrimSpace(tone))
	switch t {
	case "success", "ok", "positive":
		return "success"
	case "warning", "warn":
		return "warning"
	case "danger", "error", "critical":
		return "danger"
	case "info", "informational":
		return "info"
	case "secondary", "muted":
		return "secondary"
	default:
		return "neutral"
	}
}

func taskHistoryPoints(chart TaskHistoryChart) string {
	if len(chart.Points) == 0 {
		return ""
	}
	if len(chart.Points) == 1 {
		return "0,50 100,50"
	}
	min := chart.Points[0].DurationSeconds
	max := chart.Points[0].DurationSeconds
	for _, point := range chart.Points[1:] {
		if point.DurationSeconds < min {
			min = point.DurationSeconds
		}
		if point.DurationSeconds > max {
			max = point.DurationSeconds
		}
	}
	rangeVal := max - min
	if rangeVal == 0 {
		rangeVal = 1
	}
	points := make([]string, 0, len(chart.Points))
	lastIndex := len(chart.Points) - 1
	for idx, point := range chart.Points {
		x := 0.0
		if lastIndex > 0 {
			x = float64(idx) / float64(lastIndex) * 100
		}
		y := 100 - ((point.DurationSeconds - min) / rangeVal * 100)
		points = append(points, fmt.Sprintf("%.1f,%.1f", x, y))
	}
	return strings.Join(points, " ")
}

// FindJob locates a job in the listing result by identifier.
func FindJob(result adminsystem.JobResult, jobID string) (adminsystem.Job, bool) {
	for _, job := range result.Jobs {
		if job.ID == jobID {
			return job, true
		}
	}
	return adminsystem.Job{}, false
}
