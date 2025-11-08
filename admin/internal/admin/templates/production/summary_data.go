package production

import (
	"context"
	"fmt"
	"math"
	"net/url"
	"strings"
	"time"

	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// WIPSummaryPageData represents the SSR payload for the production WIP summary page.
type WIPSummaryPageData struct {
	Title          string
	Description    string
	Breadcrumbs    []partials.Breadcrumb
	Query          SummaryQueryState
	Error          string
	SummaryChips   []SummaryChip
	QueueCards     []QueueCard
	Trend          SummaryTrendData
	Alerts         []SummaryAlert
	Filters        SummaryFilters
	Table          SummaryTableData
	GeneratedLabel string
	RefreshLabel   string
}

// SummaryQueryState captures active filters for the summary page.
type SummaryQueryState struct {
	Facility  string
	Shift     string
	QueueType string
	DateRange string
	RawQuery  string
}

// SummaryFilters describes selectable filter options.
type SummaryFilters struct {
	Endpoint   string
	ResetURL   string
	Facilities []SummaryFilterOption
	Shifts     []SummaryFilterOption
	QueueTypes []SummaryFilterOption
	DateRanges []SummaryFilterOption
	HasActive  bool
}

// SummaryFilterOption represents a single selectable filter option.
type SummaryFilterOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// SummaryAlert renders a workload/SLA alert.
type SummaryAlert struct {
	Tone        string
	Title       string
	Message     string
	ActionLabel string
	ActionURL   string
}

// QueueCard summarises a queue in the metrics band.
type QueueCard struct {
	Title    string
	Subtitle string
	Meta     string
	Metrics  []QueueCardMetric
	Tone     string
	LinkURL  string
}

// QueueCardMetric renders a metric within a queue card.
type QueueCardMetric struct {
	Label string
	Value string
	Tone  string
}

// SummaryTrendData models the stage distribution chart.
type SummaryTrendData struct {
	Caption string
	Bars    []SummaryTrendBar
}

// SummaryTrendBar represents a single bar in the chart.
type SummaryTrendBar struct {
	Label    string
	Count    int
	Capacity int
	Percent  int
	SLALabel string
	SLATone  string
}

// SummaryTableData describes the detail table content.
type SummaryTableData struct {
	Rows         []SummaryTableRow
	Totals       SummaryTableTotals
	EmptyMessage string
}

// SummaryTableRow renders a single queue row.
type SummaryTableRow struct {
	QueueName    string
	Meta         string
	QueueType    string
	WIP          string
	Capacity     string
	Utilisation  string
	SLABreaches  string
	AverageAge   string
	StageSummary string
	ActionURL    string
	Tone         string
}

// SummaryTableTotals provides aggregated totals for the table footer.
type SummaryTableTotals struct {
	WIP         string
	Capacity    string
	Utilisation string
	SLABreaches string
}

// BuildWIPSummaryPage assembles the full WIP summary payload.
func BuildWIPSummaryPage(ctx context.Context, basePath string, state SummaryQueryState, result adminproduction.QueueWIPSummaryResult, errMsg string) WIPSummaryPageData {
	// Harmonise query state with service response.
	state.Facility = normalizeFirstNonEmpty(state.Facility, result.State.Facility)
	state.Shift = normalizeFirstNonEmpty(state.Shift, result.State.Shift)
	state.QueueType = normalizeFirstNonEmpty(state.QueueType, result.State.QueueType)
	state.DateRange = normalizeFirstNonEmpty(state.DateRange, result.State.DateRange)
	state.RawQuery = canonicalSummaryQuery(state)

	chips := buildSummaryChipsFromTotals(result.Totals)
	cards := buildQueueCards(basePath, result.Cards)
	trend := buildSummaryTrend(result.Trend)
	alerts := buildSummaryAlerts(basePath, result.Alerts)
	filters := buildSummaryFilters(basePath, state, result.Filters)
	table := buildSummaryTable(basePath, result.Table)

	formatter := helpers.NewFormatter(ctx)
	generated := ""
	if !result.GeneratedAt.IsZero() {
		generated = fmt.Sprintf("%s %s", formatter.T("common.last_updated"), result.GeneratedAt.In(time.Local).Format("15:04"))
	}

	refresh := ""
	if result.RefreshInterval > 0 {
		refresh = fmt.Sprintf("自動更新 %d秒", int(result.RefreshInterval.Seconds()))
	}

	crumbs := append([]partials.Breadcrumb{}, breadcrumbs(basePath)...)
	crumbs = append(crumbs, partials.Breadcrumb{
		Label: "WIPサマリー",
		Href:  joinBase(basePath, "/production/queues/summary"),
	})

	return WIPSummaryPageData{
		Title:          "制作WIPサマリー",
		Description:    "制作キュー全体の負荷やSLA逸脱リスクを俯瞰し、優先対応すべきラインを特定します。",
		Breadcrumbs:    crumbs,
		Query:          state,
		Error:          errMsg,
		SummaryChips:   chips,
		QueueCards:     cards,
		Trend:          trend,
		Alerts:         alerts,
		Filters:        filters,
		Table:          table,
		GeneratedLabel: generated,
		RefreshLabel:   refresh,
	}
}

func buildSummaryChipsFromTotals(totals adminproduction.QueueWIPSummaryTotals) []SummaryChip {
	chips := []SummaryChip{
		{
			Label:   "総WIP",
			Value:   fmt.Sprintf("%d件", totals.TotalWIP),
			Tone:    "info",
			SubText: "対象キュー合計",
			Icon:    "🛠",
		},
		{
			Label:   "稼働率",
			Value:   fmt.Sprintf("%d%%", totals.Utilisation),
			Tone:    "info",
			SubText: fmt.Sprintf("容量 %d枠", totals.TotalCapacity),
			Icon:    "📈",
		},
	}

	slaTone := "success"
	if totals.SLABreaches > 0 {
		slaTone = "danger"
	}
	chips = append(chips, SummaryChip{
		Label:   "SLA逸脱",
		Value:   fmt.Sprintf("%d件", totals.SLABreaches),
		Tone:    slaTone,
		SubText: "要対応数",
		Icon:    "⏰",
	})

	chips = append(chips, SummaryChip{
		Label:   "締切迫る",
		Value:   fmt.Sprintf("%d件", totals.DueSoon),
		Tone:    "warning",
		SubText: "8時間以内",
		Icon:    "⚠",
	})

	return chips
}

func buildQueueCards(basePath string, cards []adminproduction.QueueWIPSummaryCard) []QueueCard {
	if len(cards) == 0 {
		return nil
	}
	out := make([]QueueCard, 0, len(cards))
	for _, card := range cards {
		tone := "info"
		if card.SLABreaches > 0 || card.Utilisation >= 95 {
			tone = "danger"
		} else if card.Utilisation >= 85 || card.DueSoon > 0 {
			tone = "warning"
		}

		metrics := []QueueCardMetric{
			{Label: "WIP", Value: fmt.Sprintf("%d件", card.WIPCount)},
			{Label: "容量", Value: fmt.Sprintf("%d枠", card.Capacity)},
			{Label: "使用率", Value: fmt.Sprintf("%d%%", card.Utilisation)},
		}
		if card.SLABreaches > 0 {
			metrics = append(metrics, QueueCardMetric{
				Label: "SLA逸脱",
				Value: fmt.Sprintf("%d件", card.SLABreaches),
				Tone:  "danger",
			})
		} else {
			metrics = append(metrics, QueueCardMetric{
				Label: "SLA逸脱",
				Value: "0件",
				Tone:  "success",
			})
		}
		if card.DueSoon > 0 {
			metrics = append(metrics, QueueCardMetric{
				Label: "締切迫る",
				Value: fmt.Sprintf("%d件", card.DueSoon),
				Tone:  "warning",
			})
		}

		values := url.Values{}
		values.Set("queue", card.QueueID)

		out = append(out, QueueCard{
			Title:    card.QueueName,
			Subtitle: fallback(strings.TrimSpace(card.QueueType), "種別未設定"),
			Meta:     combineMeta(card.Facility, card.Shift),
			Metrics:  metrics,
			Tone:     tone,
			LinkURL:  helpers.BuildURL(joinBase(basePath, "/production/queues"), values.Encode()),
		})
	}
	return out
}

func buildSummaryTrend(trend adminproduction.QueueWIPSummaryTrend) SummaryTrendData {
	if len(trend.Bars) == 0 {
		return SummaryTrendData{}
	}
	bars := make([]SummaryTrendBar, 0, len(trend.Bars))
	for _, bar := range trend.Bars {
		percent := 0
		if bar.Capacity > 0 {
			percent = int(math.Round(float64(bar.Count) / float64(bar.Capacity) * 100))
			if percent > 100 {
				percent = 100
			}
			if percent < 0 {
				percent = 0
			}
		}
		bars = append(bars, SummaryTrendBar{
			Label:    bar.Label,
			Count:    bar.Count,
			Capacity: bar.Capacity,
			Percent:  percent,
			SLALabel: bar.SLALabel,
			SLATone:  bar.SLATone,
		})
	}
	return SummaryTrendData{
		Caption: trend.Caption,
		Bars:    bars,
	}
}

func buildSummaryAlerts(basePath string, alerts []adminproduction.QueueWIPSummaryAlert) []SummaryAlert {
	if len(alerts) == 0 {
		return nil
	}
	out := make([]SummaryAlert, 0, len(alerts))
	for _, alert := range alerts {
		actionURL := ""
		if strings.TrimSpace(alert.ActionPath) != "" {
			actionURL = helpers.BuildURL(joinBase(basePath, alert.ActionPath), "")
		}
		out = append(out, SummaryAlert{
			Tone:        fallback(alert.Tone, "info"),
			Title:       fallback(alert.Title, "稼働警告"),
			Message:     strings.TrimSpace(alert.Message),
			ActionLabel: strings.TrimSpace(alert.ActionLabel),
			ActionURL:   actionURL,
		})
	}
	return out
}

func buildSummaryFilters(basePath string, state SummaryQueryState, filters adminproduction.QueueWIPSummaryFilters) SummaryFilters {
	endpoint := joinBase(basePath, "/production/queues/summary")
	result := SummaryFilters{
		Endpoint: endpoint,
		ResetURL: helpers.BuildURL(endpoint, ""),
	}

	var hasFacility, hasShift, hasType, hasDate bool
	result.Facilities, hasFacility = mapFilterOptions(filters.Facilities)
	result.Shifts, hasShift = mapFilterOptions(filters.Shifts)
	result.QueueTypes, hasType = mapFilterOptions(filters.QueueTypes)

	dateOptions := make([]SummaryFilterOption, 0, len(filters.DateRanges))
	for _, opt := range filters.DateRanges {
		label := fallback(opt.Label, humanizeWindow(opt.Value))
		active := opt.Active
		if active && strings.TrimSpace(opt.Value) != "" {
			hasDate = true
		}
		dateOptions = append(dateOptions, SummaryFilterOption{
			Value:  opt.Value,
			Label:  label,
			Count:  opt.Count,
			Active: active,
		})
	}
	result.DateRanges = dateOptions
	result.HasActive = hasFacility || hasShift || hasType || hasDate

	return result
}

func mapFilterOptions(options []adminproduction.FilterOption) ([]SummaryFilterOption, bool) {
	if len(options) == 0 {
		return nil, false
	}
	out := make([]SummaryFilterOption, 0, len(options))
	hasActive := false
	for _, opt := range options {
		active := opt.Active
		if active && strings.TrimSpace(opt.Value) != "" {
			hasActive = true
		}
		out = append(out, SummaryFilterOption{
			Value:  opt.Value,
			Label:  fallback(opt.Label, "未設定"),
			Count:  opt.Count,
			Active: active,
		})
	}
	return out, hasActive
}

func buildSummaryTable(basePath string, table adminproduction.QueueWIPSummaryTable) SummaryTableData {
	rows := make([]SummaryTableRow, 0, len(table.Rows))
	stageOrder := table.StageColumns

	for _, row := range table.Rows {
		stageSummary := buildStageSummary(stageOrder, row.StageBreakdown)
		tone := ""
		if row.SLABreaches > 0 {
			tone = "warning"
		}
		if row.Utilisation >= 95 {
			tone = "danger"
		}

		actionURL := ""
		if strings.TrimSpace(row.LinkPath) != "" {
			actionURL = helpers.BuildURL(joinBase(basePath, row.LinkPath), "")
		}

		rows = append(rows, SummaryTableRow{
			QueueName:    row.QueueName,
			Meta:         combineMeta(row.Facility, row.Shift),
			QueueType:    fallback(row.QueueType, "種別未設定"),
			WIP:          fmt.Sprintf("%d件", row.WIPCount),
			Capacity:     fmt.Sprintf("%d枠", row.Capacity),
			Utilisation:  fmt.Sprintf("%d%%", row.Utilisation),
			SLABreaches:  fmt.Sprintf("%d件", row.SLABreaches),
			AverageAge:   fmt.Sprintf("%dh", row.AverageAgeHours),
			StageSummary: stageSummary,
			ActionURL:    actionURL,
			Tone:         tone,
		})
	}

	totals := SummaryTableTotals{
		WIP:         fmt.Sprintf("%d件", table.Totals.TotalWIP),
		Capacity:    fmt.Sprintf("%d枠", table.Totals.TotalCapacity),
		Utilisation: fmt.Sprintf("%d%%", table.Totals.Utilisation),
		SLABreaches: fmt.Sprintf("%d件", table.Totals.SLABreaches),
	}

	return SummaryTableData{
		Rows:         rows,
		Totals:       totals,
		EmptyMessage: fallback(table.EmptyMessage, "該当するキューがありません。"),
	}
}

func buildStageSummary(columns []adminproduction.QueueWIPStageColumn, breakdown []adminproduction.QueueWIPStageBreakdown) string {
	if len(columns) == 0 || len(breakdown) == 0 {
		return "ステージ情報なし"
	}

	lookup := make(map[adminproduction.Stage]adminproduction.QueueWIPStageBreakdown, len(breakdown))
	for _, b := range breakdown {
		lookup[b.Stage] = b
	}

	parts := make([]string, 0, len(columns))
	for _, col := range columns {
		if segment, ok := lookup[col.Stage]; ok {
			parts = append(parts, fmt.Sprintf("%s %d件", col.Label, segment.Count))
		} else {
			parts = append(parts, fmt.Sprintf("%s 0件", col.Label))
		}
	}
	return strings.Join(parts, " / ")
}

func canonicalSummaryQuery(state SummaryQueryState) string {
	values := url.Values{}
	if strings.TrimSpace(state.Facility) != "" {
		values.Set("facility", state.Facility)
	}
	if strings.TrimSpace(state.Shift) != "" {
		values.Set("shift", state.Shift)
	}
	if strings.TrimSpace(state.QueueType) != "" {
		values.Set("queue_type", state.QueueType)
	}
	if strings.TrimSpace(state.DateRange) != "" {
		values.Set("window", state.DateRange)
	}
	return values.Encode()
}

func combineMeta(values ...string) string {
	parts := make([]string, 0, len(values))
	for _, value := range values {
		val := strings.TrimSpace(value)
		if val == "" || strings.EqualFold(val, "未設定") {
			continue
		}
		parts = append(parts, val)
	}
	if len(parts) == 0 {
		return ""
	}
	return strings.Join(parts, " ・ ")
}

func normalizeFirstNonEmpty(current, candidate string) string {
	current = strings.TrimSpace(current)
	candidate = strings.TrimSpace(candidate)
	if current != "" {
		return current
	}
	return candidate
}

func humanizeWindow(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "today":
		return "今日"
	case "24h":
		return "過去24時間"
	case "7d":
		return "過去7日間"
	case "30d":
		return "過去30日間"
	default:
		return "全期間"
	}
}
