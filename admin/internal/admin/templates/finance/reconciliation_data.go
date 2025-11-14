package finance

import (
	"fmt"
	"sort"
	"strings"
	"time"

	adminfinance "finitefield.org/hanko-admin/internal/admin/finance"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

const (
	// ReconciliationRootID is the htmx target container for the reconciliation dashboard.
	ReconciliationRootID = "reconciliation-root"
	// reconciliationTriggerIndicatorID identifies the manual trigger loading indicator element.
	reconciliationTriggerIndicatorID = "reconciliation-trigger-indicator"
)

// ReconciliationPageData aggregates the reconciliation dashboard payload for templ rendering.
type ReconciliationPageData struct {
	Title       string
	Description string
	Breadcrumbs []partials.Breadcrumb
	Metrics     []HeaderMetric
	Alerts      []AlertView
	Summary     SummaryView
	Reports     ReportsSection
	Jobs        JobsSection
	History     AuditSectionData
	Trigger     TriggerAction
	Snackbar    *SnackbarView
}

// SummaryView exposes the headline reconciliation status block.
type SummaryView struct {
	StatusLabel     string
	StatusTone      string
	LastRunAt       string
	LastRunRelative string
	LastRunBy       string
	Duration        string
	PendingLabel    string
	PendingTone     string
	PendingAmount   string
	NextRunLabel    string
	NextRunRelative string
}

// TriggerAction configures the manual reconciliation execution control.
type TriggerAction struct {
	ActionURL      string
	CSRFToken      string
	Disabled       bool
	DisabledReason string
	IndicatorID    string
}

// ReportsSection renders reconciliation export links.
type ReportsSection struct {
	Rows         []ReportRow
	EmptyMessage string
}

// ReportRow represents a downloadable reconciliation export artefact.
type ReportRow struct {
	ID              string
	Label           string
	Description     string
	StatusLabel     string
	StatusTone      string
	LastGenerated   string
	Relative        string
	FileSize        string
	DownloadURL     string
	DownloadLabel   string
	DownloadEnabled bool
	BackgroundJob   string
}

// JobsSection summarises background jobs powering reconciliation.
type JobsSection struct {
	Rows         []JobRow
	EmptyMessage string
}

// JobRow renders a background job status row.
type JobRow struct {
	ID          string
	Label       string
	Schedule    string
	StatusLabel string
	StatusTone  string
	LastRun     string
	Relative    string
	Duration    string
	NextRun     string
	LastError   string
}

// BuildReconciliationPageData assembles the reconciliation dashboard payload.
func BuildReconciliationPageData(basePath string, dashboard adminfinance.ReconciliationDashboard, triggerURL, csrf string, snackbar *SnackbarView) ReconciliationPageData {
	metrics := buildReconciliationMetrics(dashboard.Summary)
	summary := buildSummaryView(dashboard.Summary)
	reports := buildReportSection(dashboard.Reports, dashboard.Jobs)
	jobs := buildJobSection(dashboard.Jobs)
	history := buildReconciliationHistory(dashboard.History)
	alerts := convertAlerts(dashboard.Alerts)

	actionURL := triggerURL
	if strings.TrimSpace(actionURL) == "" {
		actionURL = join(basePath, "/finance/reconciliation:trigger")
	}

	return ReconciliationPageData{
		Title:       "リコンシリエーション",
		Description: "会計チーム向けの照合レポートを管理し、PSPとの突合状況を把握します。",
		Breadcrumbs: []partials.Breadcrumb{{Label: "ファイナンス"}, {Label: "リコンシリエーション"}},
		Metrics:     metrics,
		Alerts:      alerts,
		Summary:     summary,
		Reports:     reports,
		Jobs:        jobs,
		History:     history,
		Trigger: TriggerAction{
			ActionURL:      actionURL,
			CSRFToken:      csrf,
			Disabled:       dashboard.Summary.TriggerDisabled,
			DisabledReason: dashboard.Summary.TriggerDisabledReason,
			IndicatorID:    reconciliationTriggerIndicatorID,
		},
		Snackbar: snackbar,
	}
}

func buildReconciliationMetrics(summary adminfinance.ReconciliationSummary) []HeaderMetric {
	metrics := make([]HeaderMetric, 0, 3)

	lastRunValue := formatTime(summary.LastRunAt)
	lastRunSub := formatRelativePast(summary.LastRunAt)
	tone := summary.LastRunStatusTone
	if tone == "" {
		tone = "info"
	}
	metrics = append(metrics, HeaderMetric{
		Label:    "最終実行",
		Value:    lastRunValue,
		SubLabel: lastRunSub,
		Tone:     tone,
	})

	pendingTone := "success"
	if summary.PendingExceptions > 0 {
		pendingTone = "warning"
	}
	pendingSub := ""
	if summary.PendingAmountMinor > 0 && summary.PendingAmountCurrency != "" {
		pendingSub = helpers.Currency(summary.PendingAmountMinor, summary.PendingAmountCurrency)
	}
	metrics = append(metrics, HeaderMetric{
		Label:    "未処理例外",
		Value:    fmt.Sprintf("%d件", summary.PendingExceptions),
		SubLabel: pendingSub,
		Tone:     pendingTone,
	})

	nextValue := formatOptionalTime(summary.NextScheduledAt)
	nextSub := ""
	nextTone := "info"
	if summary.NextScheduledAt == nil || summary.NextScheduledAt.IsZero() {
		nextValue = "未設定"
		nextTone = "warning"
	} else {
		nextSub = formatUntil(*summary.NextScheduledAt)
		if summary.NextScheduledAt.Before(time.Now()) {
			nextTone = "danger"
		}
	}
	metrics = append(metrics, HeaderMetric{
		Label:    "次回予定",
		Value:    nextValue,
		SubLabel: nextSub,
		Tone:     nextTone,
	})

	return metrics
}

func buildSummaryView(summary adminfinance.ReconciliationSummary) SummaryView {
	status := strings.TrimSpace(summary.LastRunStatus)
	if status == "" {
		status = "未実行"
	}

	tone := summary.LastRunStatusTone
	if tone == "" {
		tone = "info"
	}

	lastRun := formatTime(summary.LastRunAt)
	if summary.LastRunAt.IsZero() {
		lastRun = "未実行"
	}

	relative := formatRelativePast(summary.LastRunAt)
	if summary.LastRunAt.IsZero() {
		relative = "-"
	}

	pendingTone := "success"
	if summary.PendingExceptions > 0 {
		pendingTone = "warning"
	}

	pendingAmount := ""
	if summary.PendingAmountMinor > 0 && summary.PendingAmountCurrency != "" {
		pendingAmount = helpers.Currency(summary.PendingAmountMinor, summary.PendingAmountCurrency)
	}

	nextLabel := formatOptionalTime(summary.NextScheduledAt)
	nextRelative := "-"
	if summary.NextScheduledAt != nil && !summary.NextScheduledAt.IsZero() {
		nextRelative = formatUntil(*summary.NextScheduledAt)
	}

	return SummaryView{
		StatusLabel:     status,
		StatusTone:      tone,
		LastRunAt:       lastRun,
		LastRunRelative: relative,
		LastRunBy:       strings.TrimSpace(summary.LastRunBy),
		Duration:        formatDuration(summary.LastRunDuration),
		PendingLabel:    fmt.Sprintf("%d件", summary.PendingExceptions),
		PendingTone:     pendingTone,
		PendingAmount:   pendingAmount,
		NextRunLabel:    nextLabel,
		NextRunRelative: nextRelative,
	}
}

func buildReportSection(reports []adminfinance.ReconciliationReport, jobs []adminfinance.ReconciliationJob) ReportsSection {
	if len(reports) == 0 {
		return ReportsSection{EmptyMessage: "ダウンロード可能なレポートがまだありません。"}
	}

	jobLabels := make(map[string]string, len(jobs))
	for _, job := range jobs {
		jobLabels[job.ID] = job.Label
	}

	rows := make([]ReportRow, 0, len(reports))
	for _, report := range reports {
		rows = append(rows, ReportRow{
			ID:              report.ID,
			Label:           report.Label,
			Description:     report.Description,
			StatusLabel:     report.Status,
			StatusTone:      report.StatusTone,
			LastGenerated:   formatTime(report.LastGeneratedAt),
			Relative:        formatRelativePast(report.LastGeneratedAt),
			FileSize:        formatFileSize(report.FileSizeBytes),
			DownloadURL:     report.DownloadURL,
			DownloadLabel:   fmt.Sprintf("%sをダウンロード", strings.ToUpper(strings.TrimSpace(report.Format))),
			DownloadEnabled: strings.TrimSpace(report.DownloadURL) != "",
			BackgroundJob:   jobLabels[report.BackgroundJobID],
		})
	}

	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Label == rows[j].Label {
			return rows[i].ID < rows[j].ID
		}
		return rows[i].Label < rows[j].Label
	})

	return ReportsSection{Rows: rows}
}

func buildJobSection(jobs []adminfinance.ReconciliationJob) JobsSection {
	if len(jobs) == 0 {
		return JobsSection{EmptyMessage: "登録されたバックグラウンドジョブがありません。"}
	}

	rows := make([]JobRow, 0, len(jobs))
	for _, job := range jobs {
		rows = append(rows, JobRow{
			ID:          job.ID,
			Label:       job.Label,
			Schedule:    job.Schedule,
			StatusLabel: job.Status,
			StatusTone:  job.StatusTone,
			LastRun:     formatTime(job.LastRunAt),
			Relative:    formatRelativePast(job.LastRunAt),
			Duration:    formatDuration(job.LastRunDuration),
			NextRun:     formatOptionalTime(job.NextRunAt),
			LastError:   strings.TrimSpace(job.LastError),
		})
	}

	sort.Slice(rows, func(i, j int) bool {
		return rows[i].Label < rows[j].Label
	})

	return JobsSection{Rows: rows}
}

func buildReconciliationHistory(events []adminfinance.AuditEvent) AuditSectionData {
	if len(events) == 0 {
		return AuditSectionData{}
	}
	history := make([]AuditEventView, 0, len(events))
	for _, event := range events {
		history = append(history, AuditEventView{
			ID:        event.ID,
			Timestamp: formatTime(event.Timestamp),
			Relative:  formatRelativePast(event.Timestamp),
			Actor:     event.Actor,
			Action:    event.Action,
			Details:   event.Details,
			Tone:      event.Tone,
		})
	}
	return AuditSectionData{Events: history}
}

func formatOptionalTime(ts *time.Time) string {
	if ts == nil || ts.IsZero() {
		return "未設定"
	}
	return helpers.Date(*ts, "2006/01/02 15:04")
}

func formatDuration(d time.Duration) string {
	if d <= 0 {
		return "-"
	}
	minutes := int(d / time.Minute)
	seconds := int(d % time.Minute / time.Second)
	if minutes > 0 {
		if seconds > 0 {
			return fmt.Sprintf("%d分%d秒", minutes, seconds)
		}
		return fmt.Sprintf("%d分", minutes)
	}
	return fmt.Sprintf("%d秒", seconds)
}

func formatRelativePast(ts time.Time) string {
	if ts.IsZero() {
		return "-"
	}
	if ts.After(time.Now()) {
		return "予定"
	}
	return helpers.Relative(ts)
}

func formatUntil(ts time.Time) string {
	now := time.Now()
	diff := ts.Sub(now)
	if diff <= 0 {
		if -diff < time.Hour {
			return "予定時刻を過ぎています"
		}
		return fmt.Sprintf("遅延約%dh", int((-diff).Hours()))
	}
	if diff < time.Minute {
		return "まもなく実行"
	}
	if diff < time.Hour {
		return fmt.Sprintf("約%dm後", int(diff.Minutes()))
	}
	if diff < 24*time.Hour {
		return fmt.Sprintf("約%dh後", int(diff.Hours()))
	}
	days := int(diff.Hours() / 24)
	if days < 7 {
		return fmt.Sprintf("約%d日後", days)
	}
	return ts.In(time.Local).Format("2006/01/02 15:04")
}

func formatFileSize(bytes int64) string {
	if bytes <= 0 {
		return "-"
	}
	const (
		kb = 1024
		mb = kb * 1024
	)
	switch {
	case bytes >= mb:
		return fmt.Sprintf("%.1f MB", float64(bytes)/float64(mb))
	case bytes >= kb:
		return fmt.Sprintf("%.1f KB", float64(bytes)/float64(kb))
	default:
		return fmt.Sprintf("%d B", bytes)
	}
}
