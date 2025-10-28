package promotions

import (
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/a-h/templ"

	adminpromotions "finitefield.org/hanko-admin/internal/admin/promotions"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData contains the SSR payload for the promotions index page.
type PageData struct {
	Title              string
	Description        string
	Breadcrumbs        []partials.Breadcrumb
	TableEndpoint      string
	ResetURL           string
	BulkEndpoint       string
	DrawerEndpoint     string
	NewModalURL        string
	EditModalURL       string
	Query              QueryState
	Filters            Filters
	Metrics            []MetricChip
	Table              TableData
	Toolbar            components.BulkToolbarProps
	Drawer             DrawerData
	HasSelection       bool
	DefaultSelectedIDs []string
}

// MetricChip renders the summary chips in the page header.
type MetricChip struct {
	Label   string
	Value   string
	SubText string
	Tone    string
	Icon    string
}

// QueryState captures the applied filter values.
type QueryState struct {
	Search        string
	Statuses      []string
	Types         []string
	Channels      []string
	Owners        []string
	ScheduleStart string
	ScheduleEnd   string
	Page          int
	PageSize      int
	RawQuery      string
	SelectedID    string
}

// Filters groups the filter control view models.
type Filters struct {
	StatusChips     []StatusFilterOption
	TypeOptions     []Option
	ChannelOptions  []Option
	OwnerOptions    []Option
	SchedulePresets []SchedulePresetView
}

// StatusFilterOption represents a chip-style filter for promotion status.
type StatusFilterOption struct {
	Value  string
	Label  string
	Count  int
	Tone   string
	Active bool
}

// Option represents a generic <option> entry with a count badge.
type Option struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// SchedulePresetView renders saved schedule shortcuts.
type SchedulePresetView struct {
	Key   string
	Label string
	Start string
	End   string
}

// TableData contains the table fragment payload.
type TableData struct {
	Rows         []TableRow
	Error        string
	EmptyMessage string
	Pagination   components.PaginationProps
	BasePath     string
	FragmentPath string
	RawQuery     string
	HxTarget     string
	HxSwap       string
	SelectedID   string
}

// TableRow represents a promotion row.
type TableRow struct {
	ID                  string
	Code                string
	Name                string
	StatusLabel         string
	StatusTone          string
	TypeLabel           string
	TypeTone            string
	ChannelLabel        string
	ScheduleLabel       string
	StartLabel          string
	EndLabel            string
	UsageLabel          string
	RedemptionLabel     string
	RevenueLabel        string
	LastUpdatedLabel    string
	LastUpdatedRelative string
	CreatedBy           string
	SegmentName         string
	SegmentPreview      []string
	Metrics             []RowMetric
	Attributes          templ.Attributes
}

// RowMetric renders secondary numerical chips inside the row.
type RowMetric struct {
	Label string
	Value string
	Tone  string
	Icon  string
}

// DrawerData powers the right-hand drawer preview.
type DrawerData struct {
	Empty              bool
	ID                 string
	Title              string
	StatusLabel        string
	StatusTone         string
	TypeLabel          string
	Schedule           string
	ChannelLabel       string
	CreatedBy          string
	LastEdited         string
	LastEditedRelative string
	SegmentName        string
	SegmentDescription string
	SegmentPreview     []string
	Targeting          []DrawerItem
	Benefits           []DrawerItem
	AuditLog           []AuditItem
	Usage              []DrawerItem
	Metrics            []RowMetric
	EditURL            string
}

// DrawerItem is a labeled value row in the drawer.
type DrawerItem struct {
	Label string
	Value string
	Icon  string
}

// AuditItem represents an audit timeline entry.
type AuditItem struct {
	Timestamp string
	Relative  string
	Actor     string
	Action    string
	Summary   string
}

// BuildPageData assembles the SSR payload for the promotions index.
func BuildPageData(basePath string, state QueryState, result adminpromotions.ListResult, table TableData, toolbar components.BulkToolbarProps, drawer DrawerData) PageData {
	return PageData{
		Title:              "プロモーション管理",
		Description:        "チャネル横断で実施中のプロモーションを把握し、ステータスやスケジュールを調整します。",
		Breadcrumbs:        []partials.Breadcrumb{{Label: "プロモーション"}},
		TableEndpoint:      joinBase(basePath, "/promotions/table"),
		ResetURL:           joinBase(basePath, "/promotions"),
		BulkEndpoint:       joinBase(basePath, "/promotions/bulk/status"),
		DrawerEndpoint:     joinBase(basePath, "/promotions/drawer"),
		NewModalURL:        joinBase(basePath, "/promotions/modal/new"),
		EditModalURL:       joinBase(basePath, "/promotions/modal/edit"),
		Query:              state,
		Filters:            buildFilters(state, result.Filters),
		Metrics:            metricChips(result.Summary),
		Table:              table,
		Toolbar:            toolbar,
		Drawer:             drawer,
		HasSelection:       toolbar.SelectedCount > 0,
		DefaultSelectedIDs: defaultSelectedIDs(table),
	}
}

// TablePayload converts the list result into a table view model.
func TablePayload(basePath string, state QueryState, result adminpromotions.ListResult, errMsg string) TableData {
	rows := make([]TableRow, 0, len(result.Promotions))
	for _, promo := range result.Promotions {
		rows = append(rows, toTableRow(promo))
	}

	data := TableData{
		Rows:         rows,
		BasePath:     joinBase(basePath, "/promotions"),
		FragmentPath: joinBase(basePath, "/promotions/table"),
		RawQuery:     state.RawQuery,
		HxTarget:     "#promotions-table",
		HxSwap:       "outerHTML",
		SelectedID:   state.SelectedID,
	}

	if errMsg != "" {
		data.Error = errMsg
	}
	if len(rows) == 0 && data.Error == "" {
		data.EmptyMessage = "該当するプロモーションはありません。フィルタを調整してください。"
	}

	total := result.Pagination.TotalItems
	data.Pagination = components.PaginationProps{
		Info: components.PageInfo{
			PageSize:   result.Pagination.PageSize,
			Current:    result.Pagination.Page,
			Count:      len(rows),
			TotalItems: &total,
			Next:       result.Pagination.NextPage,
			Prev:       result.Pagination.PrevPage,
		},
		BasePath:      data.BasePath,
		RawQuery:      state.RawQuery,
		FragmentPath:  data.FragmentPath,
		FragmentQuery: state.RawQuery,
		Param:         "page",
		SizeParam:     "pageSize",
		HxTarget:      data.HxTarget,
		HxSwap:        data.HxSwap,
		HxPushURL:     true,
		Label:         "Promotions pagination",
	}

	return data
}

// DrawerPayload builds the drawer state from the detail response.
func DrawerPayload(detail adminpromotions.PromotionDetail) DrawerData {
	if detail.Promotion.ID == "" {
		return DrawerData{Empty: true}
	}

	promo := detail.Promotion
	statusLabel := promo.StatusLabel
	if statusLabel == "" {
		statusLabel = statusFilterLabel(promo.Status)
	}

	targeting := make([]DrawerItem, 0, len(detail.Targeting))
	for _, rule := range detail.Targeting {
		targeting = append(targeting, DrawerItem{
			Label: rule.Label,
			Value: rule.Value,
			Icon:  rule.Icon,
		})
	}

	benefits := make([]DrawerItem, 0, len(detail.Benefits))
	for _, reward := range detail.Benefits {
		benefits = append(benefits, DrawerItem{
			Label: reward.Label,
			Value: reward.Description,
			Icon:  reward.Icon,
		})
	}

	usage := make([]DrawerItem, 0, len(detail.UsageSlices))
	for _, slice := range detail.UsageSlices {
		usage = append(usage, DrawerItem{
			Label: slice.Label,
			Value: slice.Value,
		})
	}

	audit := make([]AuditItem, 0, len(detail.AuditLog))
	for _, entry := range detail.AuditLog {
		audit = append(audit, AuditItem{
			Timestamp: helpers.Date(entry.Timestamp, "2006-01-02 15:04"),
			Relative:  helpers.Relative(entry.Timestamp),
			Actor:     entry.Actor,
			Action:    entry.Action,
			Summary:   entry.Summary,
		})
	}

	metrics := []RowMetric{
		{
			Label: "想定売上",
			Value: helpers.Currency(detail.Promotion.Metrics.AttributedRevenueMinor, "JPY"),
			Tone:  "info",
			Icon:  "💹",
		},
		{
			Label: "CVR",
			Value: fmt.Sprintf("%.1f%%", detail.Promotion.Metrics.ConversionRate*100),
			Tone:  "success",
			Icon:  "🎯",
		},
	}

	schedule := scheduleLabel(promo.StartAt, promo.EndAt)
	channels := channelLabel(promo.Channels)

	return DrawerData{
		ID:                 promo.ID,
		Title:              promo.Name,
		StatusLabel:        statusLabel,
		StatusTone:         toneForStatus(promo.Status, promo.StatusTone),
		TypeLabel:          typeLabel(promo.Type, promo.TypeLabel),
		Schedule:           schedule,
		ChannelLabel:       channels,
		CreatedBy:          promo.CreatedBy,
		LastEdited:         helpers.Date(detail.LastEdited, "2006-01-02 15:04"),
		LastEditedRelative: helpers.Relative(detail.LastEdited),
		SegmentName:        promo.Segment.Name,
		SegmentDescription: promo.Segment.Description,
		SegmentPreview:     append([]string(nil), promo.Segment.Preview...),
		Targeting:          targeting,
		Benefits:           benefits,
		AuditLog:           audit,
		Usage:              usage,
		Metrics:            metrics,
	}
}

// EmptyDrawer returns an empty state drawer when no detail is available.
func EmptyDrawer() DrawerData {
	return DrawerData{Empty: true}
}

func buildFilters(state QueryState, summary adminpromotions.FilterSummary) Filters {
	return Filters{
		StatusChips:     statusFilterChips(state.Statuses, summary.StatusCounts),
		TypeOptions:     optionList(state.Types, summary.TypeCounts, typeLabelFromType),
		ChannelOptions:  optionList(state.Channels, summary.ChannelCounts, channelLabelFromChannel),
		OwnerOptions:    ownerOptions(state.Owners, summary.OwnerCounts),
		SchedulePresets: schedulePresets(summary.ScheduleRanges),
	}
}

func statusFilterChips(selected []string, counts map[adminpromotions.Status]int) []StatusFilterOption {
	active := make(map[string]struct{}, len(selected))
	for _, value := range selected {
		active[strings.TrimSpace(value)] = struct{}{}
	}

	options := []adminpromotions.Status{
		adminpromotions.StatusActive,
		adminpromotions.StatusScheduled,
		adminpromotions.StatusPaused,
		adminpromotions.StatusDraft,
		adminpromotions.StatusExpired,
	}

	result := make([]StatusFilterOption, 0, len(options)+1)
	total := 0
	for _, count := range counts {
		total += count
	}
	result = append(result, StatusFilterOption{
		Value:  "",
		Label:  fmt.Sprintf("すべて (%d)", total),
		Count:  total,
		Tone:   "info",
		Active: len(active) == 0,
	})

	for _, st := range options {
		val := string(st)
		_, isActive := active[val]
		result = append(result, StatusFilterOption{
			Value:  val,
			Label:  fmt.Sprintf("%s (%d)", statusFilterLabel(st), counts[st]),
			Count:  counts[st],
			Tone:   toneForStatus(st, ""),
			Active: isActive,
		})
	}
	return result
}

func optionList[T comparable](
	selected []string,
	counts map[T]int,
	labelFn func(T) string,
) []Option {
	active := make(map[string]struct{}, len(selected))
	for _, val := range selected {
		active[strings.TrimSpace(val)] = struct{}{}
	}

	keys := make([]T, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		return labelFn(keys[i]) < labelFn(keys[j])
	})

	result := make([]Option, 0, len(keys))
	for _, key := range keys {
		val := fmt.Sprintf("%v", key)
		label := labelFn(key)
		if label == "" {
			label = val
		}
		_, isActive := active[val]
		result = append(result, Option{
			Value:    val,
			Label:    fmt.Sprintf("%s (%d)", label, counts[key]),
			Count:    counts[key],
			Selected: isActive,
		})
	}
	return result
}

func ownerOptions(selected []string, counts map[string]int) []Option {
	active := make(map[string]struct{}, len(selected))
	for _, value := range selected {
		active[strings.TrimSpace(value)] = struct{}{}
	}

	keys := make([]string, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	result := make([]Option, 0, len(keys))
	for _, owner := range keys {
		_, isActive := active[owner]
		result = append(result, Option{
			Value:    owner,
			Label:    fmt.Sprintf("%s (%d)", owner, counts[owner]),
			Count:    counts[owner],
			Selected: isActive,
		})
	}
	return result
}

func schedulePresets(presets []adminpromotions.SchedulePreset) []SchedulePresetView {
	result := make([]SchedulePresetView, 0, len(presets))
	for _, preset := range presets {
		var start string
		if preset.Start != nil {
			start = preset.Start.Format("2006-01-02")
		}
		var end string
		if preset.End != nil {
			end = preset.End.Format("2006-01-02")
		}
		result = append(result, SchedulePresetView{
			Key:   preset.Key,
			Label: preset.Label,
			Start: start,
			End:   end,
		})
	}
	return result
}

func metricChips(summary adminpromotions.Summary) []MetricChip {
	return []MetricChip{
		{
			Label: "稼働中",
			Value: fmt.Sprintf("%d 件", summary.ActiveCount),
			Tone:  "success",
			Icon:  "🟢",
		},
		{
			Label: "想定月次リフト",
			Value: fmt.Sprintf("+%.1f%%", summary.MonthlyUpliftRate*100),
			Tone:  "info",
			Icon:  "📈",
		},
		{
			Label: "平均利用数",
			Value: fmt.Sprintf("%.0f 件", summary.AverageRedemption),
			Tone:  "info",
			Icon:  "🧾",
		},
	}
}

func toTableRow(promo adminpromotions.Promotion) TableRow {
	revenue := helpers.Currency(promo.Metrics.AttributedRevenueMinor, "JPY")
	schedule := scheduleLabel(promo.StartAt, promo.EndAt)
	usage := fmt.Sprintf("%d 件", promo.UsageCount)
	redemption := fmt.Sprintf("%d 件", promo.RedemptionCount)
	statusLabel := promo.StatusLabel
	if strings.TrimSpace(statusLabel) == "" {
		statusLabel = statusFilterLabel(promo.Status)
	}
	typeName := typeLabel(promo.Type, promo.TypeLabel)

	metrics := []RowMetric{
		{Label: "CVR", Value: fmt.Sprintf("%.1f%%", promo.Metrics.ConversionRate*100), Tone: "success", Icon: "🎯"},
		{Label: "リピート", Value: fmt.Sprintf("%.0f%%", promo.Metrics.RetentionLift*100), Tone: "info", Icon: "♻️"},
	}

	return TableRow{
		ID:                  promo.ID,
		Code:                promo.Code,
		Name:                promo.Name,
		StatusLabel:         statusLabel,
		StatusTone:          toneForStatus(promo.Status, promo.StatusTone),
		TypeLabel:           typeName,
		TypeTone:            toneForType(promo.Type),
		ChannelLabel:        channelLabel(promo.Channels),
		ScheduleLabel:       schedule,
		StartLabel:          dateLabel(promo.StartAt),
		EndLabel:            dateLabel(promo.EndAt),
		UsageLabel:          usage,
		RedemptionLabel:     redemption,
		RevenueLabel:        revenue,
		LastUpdatedLabel:    helpers.Date(promo.LastModifiedAt, "2006-01-02 15:04"),
		LastUpdatedRelative: helpers.Relative(promo.LastModifiedAt),
		CreatedBy:           promo.CreatedBy,
		SegmentName:         promo.Segment.Name,
		SegmentPreview:      append([]string(nil), promo.Segment.Preview...),
		Metrics:             metrics,
		Attributes: templ.Attributes{
			"data-promotion-row": "true",
			"data-promotion-id":  promo.ID,
		},
	}
}

func dateLabel(ts *time.Time) string {
	if ts == nil || ts.IsZero() {
		return "未設定"
	}
	return ts.Format("2006-01-02")
}

func scheduleLabel(start, end *time.Time) string {
	switch {
	case start != nil && end != nil:
		return fmt.Sprintf("%s 〜 %s", start.Format("2006-01-02"), end.Format("2006-01-02"))
	case start != nil:
		return fmt.Sprintf("%s 〜", start.Format("2006-01-02"))
	case end != nil:
		return fmt.Sprintf("〜 %s", end.Format("2006-01-02"))
	default:
		return "スケジュール未設定"
	}
}

func channelLabel(channels []adminpromotions.Channel) string {
	if len(channels) == 0 {
		return "未設定"
	}
	labels := make([]string, 0, len(channels))
	for _, ch := range channels {
		labels = append(labels, channelLabelFromChannel(ch))
	}
	return strings.Join(labels, " / ")
}

func channelLabelFromChannel(ch adminpromotions.Channel) string {
	switch ch {
	case adminpromotions.ChannelOnlineStore:
		return "オンラインストア"
	case adminpromotions.ChannelRetail:
		return "店舗"
	case adminpromotions.ChannelApp:
		return "アプリ"
	default:
		return string(ch)
	}
}

func toneForStatus(status adminpromotions.Status, fallback string) string {
	if strings.TrimSpace(fallback) != "" {
		return fallback
	}
	switch status {
	case adminpromotions.StatusActive:
		return "success"
	case adminpromotions.StatusScheduled:
		return "info"
	case adminpromotions.StatusPaused:
		return "warning"
	case adminpromotions.StatusDraft:
		return "muted"
	case adminpromotions.StatusExpired:
		return "muted"
	default:
		return "info"
	}
}

func toneForType(kind adminpromotions.Type) string {
	switch kind {
	case adminpromotions.TypePercentage:
		return "success"
	case adminpromotions.TypeFixedAmount:
		return "info"
	case adminpromotions.TypeBundle:
		return "warning"
	case adminpromotions.TypeShipping:
		return "info"
	default:
		return "info"
	}
}

func typeLabel(kind adminpromotions.Type, fallback string) string {
	if strings.TrimSpace(fallback) != "" {
		return fallback
	}
	return typeLabelFromType(kind)
}

func typeLabelFromType(kind adminpromotions.Type) string {
	switch kind {
	case adminpromotions.TypePercentage:
		return "割引(%)"
	case adminpromotions.TypeFixedAmount:
		return "割引(定額)"
	case adminpromotions.TypeBundle:
		return "セット/バンドル"
	case adminpromotions.TypeShipping:
		return "配送特典"
	default:
		return string(kind)
	}
}

func statusFilterLabel(status adminpromotions.Status) string {
	switch status {
	case adminpromotions.StatusActive:
		return "稼働中"
	case adminpromotions.StatusScheduled:
		return "公開予定"
	case adminpromotions.StatusPaused:
		return "一時停止"
	case adminpromotions.StatusDraft:
		return "下書き"
	case adminpromotions.StatusExpired:
		return "終了済み"
	default:
		return string(status)
	}
}

func defaultSelectedIDs(table TableData) []string {
	if len(table.Rows) == 0 {
		return nil
	}
	if table.SelectedID != "" {
		return []string{table.SelectedID}
	}
	return []string{table.Rows[0].ID}
}

func joinBase(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" || base == "/" {
		base = ""
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	res := base + suffix
	for strings.Contains(res, "//") {
		res = strings.ReplaceAll(res, "//", "/")
	}
	if res == "" {
		return "/"
	}
	if !strings.HasPrefix(res, "/") {
		res = "/" + res
	}
	return res
}

// BuildQueryState normalises raw request values into QueryState.
func BuildQueryState(raw url.Values) QueryState {
	statuses := raw["status"]
	types := raw["type"]
	channels := raw["channel"]
	owners := raw["createdBy"]
	page := parseIntDefault(raw.Get("page"), 1)
	pageSize := parseIntDefault(raw.Get("pageSize"), 20)
	start := strings.TrimSpace(raw.Get("scheduleStart"))
	end := strings.TrimSpace(raw.Get("scheduleEnd"))

	selected := strings.TrimSpace(raw.Get("selected"))

	return QueryState{
		Search:        strings.TrimSpace(raw.Get("q")),
		Statuses:      cloneStrings(statuses),
		Types:         cloneStrings(types),
		Channels:      cloneStrings(channels),
		Owners:        cloneStrings(owners),
		ScheduleStart: start,
		ScheduleEnd:   end,
		Page:          page,
		PageSize:      pageSize,
		RawQuery:      raw.Encode(),
		SelectedID:    selected,
	}
}

func cloneStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, len(values))
	copy(out, values)
	return out
}

func parseIntDefault(raw string, def int) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return def
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return def
	}
	return value
}

// ModalData represents the promotion create/edit modal payload.
type ModalData struct {
	Title        string
	Description  string
	Mode         string
	ActionURL    string
	Method       string
	SubmitLabel  string
	SubmitTone   string
	HiddenFields []ModalHiddenField
	Sections     []ModalSection
	Error        string
	Conditions   map[string]string
}

// ModalHiddenField captures hidden inputs rendered in the modal form.
type ModalHiddenField struct {
	Name  string
	Value string
}

// ModalSection groups related fields and supports conditional display.
type ModalSection struct {
	ID              string
	Title           string
	Description     string
	Fields          []ModalField
	ConditionKey    string
	ConditionValue  string
	HideWhenMissing bool
}

// ModalField describes a single form control inside the modal.
type ModalField struct {
	Name           string
	Label          string
	Type           string
	Value          string
	Placeholder    string
	Hint           string
	Required       bool
	FullWidth      bool
	Options        []ModalOption
	Rows           int
	Attributes     templ.Attributes
	Error          string
	Prefix         string
	Suffix         string
	Step           string
	Min            string
	Max            string
	ConditionKey   string
	ConditionValue string
	Multiple       bool
}

// ModalOption represents a selectable option for dropdowns, radios, or checkboxes.
type ModalOption struct {
	Value       string
	Label       string
	Selected    bool
	Description string
}
