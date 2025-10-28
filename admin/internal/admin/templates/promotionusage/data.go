package promotionusage

import (
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	adminpromotions "finitefield.org/hanko-admin/internal/admin/promotions"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData contains the payload for the promotion usage page.
type PageData struct {
	Title            string
	Description      string
	Breadcrumbs      []partials.Breadcrumb
	Promotion        PromotionHeader
	Query            QueryState
	Filters          Filters
	Metrics          []MetricCard
	Table            TableData
	TableEndpoint    string
	ExportEndpoint   string
	Alert            *Alert
	ExportStatus     *ExportJobPayload
	AutoRefreshLabel string
}

// PromotionHeader summarises the promotion being viewed.
type PromotionHeader struct {
	ID          string
	Name        string
	Code        string
	StatusLabel string
	StatusTone  string
	PeriodLabel string
}

// MetricCard renders the metric band at the top of the page.
type MetricCard struct {
	Label   string
	Value   string
	SubText string
	Icon    string
	Tone    string
}

// Filters contains option lists for the filter toolbar.
type Filters struct {
	TimeframeOptions []TimeframeOption
	ChannelOptions   []FilterOption
	SourceOptions    []FilterOption
	SegmentOptions   []FilterOption
	Thresholds       []ThresholdOption
}

// TimeframeOption represents a saved timeframe preset.
type TimeframeOption struct {
	Key      string
	Label    string
	Selected bool
}

// FilterOption represents a checkbox or select option.
type FilterOption struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// ThresholdOption renders the quick min-usage selectors.
type ThresholdOption struct {
	Value  int
	Label  string
	Active bool
}

// Alert describes a contextual warning for the page.
type Alert struct {
	Tone      string
	Message   string
	LinkLabel string
	LinkURL   string
}

// QueryState captures the raw filter state parsed from the query string.
type QueryState struct {
	MinUses       int
	Timeframe     string
	Channels      []string
	Sources       []string
	Segments      []string
	SortKey       string
	SortDirection string
	Page          int
	PageSize      int
	AutoRefresh   bool
	RawQuery      string
	StartInput    string
	EndInput      string
	Start         *time.Time
	End           *time.Time
}

// TableData contains the usage table payload.
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
}

// TableRow renders a single usage record.
type TableRow struct {
	UserName           string
	UserEmail          string
	SegmentLabel       string
	SegmentTone        string
	UsageCount         int
	UsageLabel         string
	ChannelsLabel      string
	SourcesLabel       string
	TotalDiscountLabel string
	AverageDiscount    string
	TotalOrderLabel    string
	AverageOrderLabel  string
	LastUsed           string
	LastUsedRelative   string
	LastOrder          OrderSummary
}

// OrderSummary summarises the latest order for a usage record.
type OrderSummary struct {
	ID          string
	Number      string
	AmountLabel string
	StatusLabel string
	StatusTone  string
	DetailURL   string
}

// ExportJobPayload describes the export job status block.
type ExportJobPayload struct {
	Visible   bool
	Job       ExportJobView
	StatusURL string
	Poll      bool
	Finished  bool
	Submitted string
	Completed string
}

// ExportJobView renders the export job content.
type ExportJobView struct {
	ID          string
	Status      string
	StatusTone  string
	Message     string
	Progress    int
	Download    string
	RecordCount int
}

// BuildQueryState parses the raw query values into a query state.
func BuildQueryState(values url.Values) QueryState {
	state := QueryState{
		RawQuery: values.Encode(),
	}

	if minUses, err := strconv.Atoi(strings.TrimSpace(values.Get("minUses"))); err == nil && minUses > 0 {
		state.MinUses = minUses
	}
	state.Timeframe = strings.TrimSpace(values.Get("timeframe"))
	state.SortKey = strings.TrimSpace(values.Get("sort"))
	state.SortDirection = strings.TrimSpace(values.Get("direction"))

	if page, err := strconv.Atoi(strings.TrimSpace(values.Get("page"))); err == nil && page > 0 {
		state.Page = page
	}
	if size, err := strconv.Atoi(strings.TrimSpace(values.Get("pageSize"))); err == nil && size > 0 {
		state.PageSize = size
	}

	for _, ch := range values["channel"] {
		ch = strings.TrimSpace(ch)
		if ch != "" {
			state.Channels = append(state.Channels, ch)
		}
	}
	for _, src := range values["source"] {
		src = strings.TrimSpace(src)
		if src != "" {
			state.Sources = append(state.Sources, src)
		}
	}
	for _, seg := range values["segment"] {
		seg = strings.TrimSpace(seg)
		if seg != "" {
			state.Segments = append(state.Segments, seg)
		}
	}

	if strings.TrimSpace(values.Get("autoRefresh")) != "" {
		state.AutoRefresh = true
	}

	if start := strings.TrimSpace(values.Get("start")); start != "" {
		if ts, err := time.Parse("2006-01-02", start); err == nil {
			state.Start = &ts
			state.StartInput = start
		}
	}
	if end := strings.TrimSpace(values.Get("end")); end != "" {
		if ts, err := time.Parse("2006-01-02", end); err == nil {
			state.End = &ts
			state.EndInput = end
		}
	}

	return state
}

// BuildPageData composes the full page payload.
func BuildPageData(basePath, promotionID string, state QueryState, result adminpromotions.UsageResult, table TableData, export *ExportJobPayload) PageData {
	promoHeader := buildPromotionHeader(result.Promotion)
	metrics := usageMetrics(result.Summary)
	alert := buildAlert(result.Alert, basePath, promotionID)
	filters := buildFilters(state, result.Filters)

	page := PageData{
		Title:            fmt.Sprintf("利用状況 - %s", promoHeader.Name),
		Description:      "プロモーションの利用状況を確認し、セグメントやチャネル別の傾向を把握します。",
		Breadcrumbs:      []partials.Breadcrumb{{Label: "プロモーション", Href: joinBase(basePath, "/promotions")}, {Label: promoHeader.Name}},
		Promotion:        promoHeader,
		Query:            state,
		Filters:          filters,
		Metrics:          metrics,
		Table:            table,
		TableEndpoint:    joinBase(basePath, fmt.Sprintf("/promotions/%s/usages/table", url.PathEscape(promotionID))),
		ExportEndpoint:   joinBase(basePath, fmt.Sprintf("/promotions/%s/usages/export", url.PathEscape(promotionID))),
		Alert:            alert,
		AutoRefreshLabel: "自動更新",
	}

	if export != nil {
		page.ExportStatus = export
	}

	return page
}

// TablePayload converts the usage result to table data.
func TablePayload(basePath, promotionID string, state QueryState, result adminpromotions.UsageResult, errMsg string) TableData {
	rows := make([]TableRow, 0, len(result.Records))
	for _, record := range result.Records {
		rows = append(rows, toTableRow(basePath, record))
	}

	data := TableData{
		Rows:         rows,
		BasePath:     joinBase(basePath, fmt.Sprintf("/promotions/%s/usages", url.PathEscape(promotionID))),
		FragmentPath: joinBase(basePath, fmt.Sprintf("/promotions/%s/usages/table", url.PathEscape(promotionID))),
		RawQuery:     state.RawQuery,
		HxTarget:     "#promotion-usage-table",
		HxSwap:       "outerHTML",
	}

	if errMsg != "" {
		data.Error = errMsg
	}
	if len(rows) == 0 && data.Error == "" {
		data.EmptyMessage = "利用履歴がまだありません。フィルタを調整するか、後ほど再度ご確認ください。"
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
		Label:         "Promotion usage pagination",
	}

	return data
}

// BuildExportJobPayload builds the export job status payload.
func BuildExportJobPayload(basePath, promotionID string, job adminpromotions.UsageExportJob) *ExportJobPayload {
	if strings.TrimSpace(job.ID) == "" {
		return nil
	}

	payload := &ExportJobPayload{
		Visible:   true,
		StatusURL: joinBase(basePath, fmt.Sprintf("/promotions/%s/usages/export/jobs/%s", url.PathEscape(promotionID), url.PathEscape(job.ID))),
		Poll:      job.Progress < 100,
		Finished:  job.Progress >= 100,
		Submitted: helpers.Date(job.SubmittedAt, "2006-01-02 15:04"),
	}
	if job.CompletedAt != nil && !job.CompletedAt.IsZero() {
		payload.Completed = helpers.Date(*job.CompletedAt, "2006-01-02 15:04")
	}

	payload.Job = ExportJobView{
		ID:          job.ID,
		Status:      job.Status,
		StatusTone:  job.StatusTone,
		Message:     job.Message,
		Progress:    job.Progress,
		Download:    job.DownloadURL,
		RecordCount: job.RecordCount,
	}

	return payload
}

func toTableRow(basePath string, record adminpromotions.UsageRecord) TableRow {
	totalDiscount := "—"
	if record.TotalDiscountMinor != 0 {
		totalDiscount = helpers.Currency(record.TotalDiscountMinor, record.LastOrder.Currency)
	}
	avgDiscount := "—"
	if record.AverageDiscountMinor != 0 {
		avgDiscount = helpers.Currency(record.AverageDiscountMinor, record.LastOrder.Currency)
	}
	totalOrder := "—"
	if record.TotalOrderAmountMinor != 0 {
		totalOrder = helpers.Currency(record.TotalOrderAmountMinor, record.LastOrder.Currency)
	}
	avgOrder := "—"
	if record.AverageOrderAmountMinor != 0 {
		avgOrder = helpers.Currency(record.AverageOrderAmountMinor, record.LastOrder.Currency)
	}

	lastUsed := ""
	lastRelative := ""
	if !record.LastUsedAt.IsZero() {
		lastUsed = helpers.Date(record.LastUsedAt, "2006-01-02 15:04")
		lastRelative = helpers.Relative(record.LastUsedAt)
	}

	order := OrderSummary{}
	if strings.TrimSpace(record.LastOrder.ID) != "" {
		order = OrderSummary{
			ID:          record.LastOrder.ID,
			Number:      record.LastOrder.Number,
			AmountLabel: helpers.Currency(record.LastOrder.AmountMinor, record.LastOrder.Currency),
			StatusLabel: fallback(record.LastOrder.StatusLabel, "—"),
			StatusTone:  record.LastOrder.StatusTone,
		}
		if record.LastOrder.ID != "" {
			order.DetailURL = joinBase(basePath, fmt.Sprintf("/orders/%s", url.PathEscape(record.LastOrder.ID)))
		}
	}

	channels := strings.Join(recordChannelLabels(record.Channels), ", ")
	sources := strings.Join(recordSources(record.Sources), ", ")

	return TableRow{
		UserName:           fallback(record.User.Name, record.User.Email),
		UserEmail:          record.User.Email,
		SegmentLabel:       record.SegmentLabel,
		SegmentTone:        record.SegmentTone,
		UsageCount:         record.UsageCount,
		UsageLabel:         fmt.Sprintf("%d回", record.UsageCount),
		ChannelsLabel:      channels,
		SourcesLabel:       sources,
		TotalDiscountLabel: totalDiscount,
		AverageDiscount:    avgDiscount,
		TotalOrderLabel:    totalOrder,
		AverageOrderLabel:  avgOrder,
		LastUsed:           lastUsed,
		LastUsedRelative:   lastRelative,
		LastOrder:          order,
	}
}

func usageMetrics(summary adminpromotions.UsageSummary) []MetricCard {
	metrics := []MetricCard{
		{
			Label:   "総利用数",
			Value:   fmt.Sprintf("%d 件", summary.TotalRedemptions),
			SubText: "",
			Icon:    "🧾",
			Tone:    "info",
		},
		{
			Label:   "コンバージョン率",
			Value:   fmt.Sprintf("%.1f%%", summary.ConversionRate*100),
			SubText: "対象セグメント比",
			Icon:    "🎯",
			Tone:    "success",
		},
		{
			Label:   "平均割引額",
			Value:   helpers.Currency(summary.AverageDiscountMinor, "JPY"),
			SubText: "1回あたり",
			Icon:    "💸",
			Tone:    "warning",
		},
	}

	return metrics
}

func buildFilters(state QueryState, summary adminpromotions.UsageFilterSummary) Filters {
	channelOptions := make([]FilterOption, 0, len(summary.ChannelOptions))
	for _, opt := range summary.ChannelOptions {
		channelOptions = append(channelOptions, FilterOption{
			Value:    opt.Value,
			Label:    opt.Label,
			Count:    opt.Count,
			Selected: contains(state.Channels, opt.Value),
		})
	}

	sourceOptions := make([]FilterOption, 0, len(summary.SourceOptions))
	for _, opt := range summary.SourceOptions {
		sourceOptions = append(sourceOptions, FilterOption{
			Value:    opt.Value,
			Label:    opt.Label,
			Count:    opt.Count,
			Selected: contains(state.Sources, opt.Value),
		})
	}

	segmentOptions := make([]FilterOption, 0, len(summary.SegmentOptions))
	for _, opt := range summary.SegmentOptions {
		segmentOptions = append(segmentOptions, FilterOption{
			Value:    opt.Value,
			Label:    opt.Label,
			Count:    opt.Count,
			Selected: contains(state.Segments, opt.Value),
		})
	}

	timeframes := make([]TimeframeOption, 0, len(summary.TimeframePresets))
	for _, preset := range summary.TimeframePresets {
		timeframes = append(timeframes, TimeframeOption{
			Key:      preset.Key,
			Label:    preset.Label,
			Selected: strings.EqualFold(state.Timeframe, preset.Key),
		})
	}
	if len(timeframes) > 0 && state.Timeframe == "" {
		timeframes[0].Selected = true
	}

	thresholds := make([]ThresholdOption, 0, len(summary.UsageThresholds))
	for _, opt := range summary.UsageThresholds {
		thresholds = append(thresholds, ThresholdOption{
			Value:  opt.Value,
			Label:  opt.Label,
			Active: state.MinUses == opt.Value,
		})
	}

	return Filters{
		TimeframeOptions: timeframes,
		ChannelOptions:   channelOptions,
		SourceOptions:    sourceOptions,
		SegmentOptions:   segmentOptions,
		Thresholds:       thresholds,
	}
}

func buildPromotionHeader(promo adminpromotions.Promotion) PromotionHeader {
	header := PromotionHeader{
		ID:          promo.ID,
		Name:        fallback(promo.Name, promo.Code),
		Code:        promo.Code,
		StatusLabel: fallback(promo.StatusLabel, statusLabel(promo.Status)),
		StatusTone:  promo.StatusTone,
	}

	if promo.StartAt != nil {
		start := helpers.Date(*promo.StartAt, "2006-01-02")
		if promo.EndAt != nil {
			header.PeriodLabel = fmt.Sprintf("%s 〜 %s", start, helpers.Date(*promo.EndAt, "2006-01-02"))
		} else {
			header.PeriodLabel = fmt.Sprintf("%s 〜", start)
		}
	}

	return header
}

func buildAlert(alert *adminpromotions.UsageAlert, basePath, promotionID string) *Alert {
	if alert == nil {
		return nil
	}
	link := alert.LinkURL
	if strings.HasPrefix(link, "/") {
		link = joinBase(basePath, link)
	}
	return &Alert{
		Tone:      fallback(alert.Tone, "warning"),
		Message:   alert.Message,
		LinkLabel: fallback(alert.LinkLabel, "詳細を確認"),
		LinkURL:   link,
	}
}

func recordChannelLabels(channels []adminpromotions.Channel) []string {
	if len(channels) == 0 {
		return nil
	}
	labels := make([]string, 0, len(channels))
	for _, ch := range channels {
		switch ch {
		case adminpromotions.ChannelOnlineStore:
			labels = append(labels, "オンライン")
		case adminpromotions.ChannelRetail:
			labels = append(labels, "店舗")
		case adminpromotions.ChannelApp:
			labels = append(labels, "アプリ")
		default:
			labels = append(labels, string(ch))
		}
	}
	sort.Strings(labels)
	return labels
}

func recordSources(sources []string) []string {
	if len(sources) == 0 {
		return nil
	}
	labels := make([]string, 0, len(sources))
	for _, src := range sources {
		switch strings.ToLower(strings.TrimSpace(src)) {
		case "checkout_web":
			labels = append(labels, "オンラインストア")
		case "express_checkout":
			labels = append(labels, "クイックチェックアウト")
		case "app_push":
			labels = append(labels, "アプリPush")
		case "app_campaign":
			labels = append(labels, "アプリキャンペーン")
		case "app_flash":
			labels = append(labels, "フラッシュセール")
		case "push_message":
			labels = append(labels, "Pushメッセージ")
		case "support_manual":
			labels = append(labels, "サポート代行")
		case "retail_pos":
			labels = append(labels, "店舗POS")
		case "campaign_preview":
			labels = append(labels, "キャンペーン検証")
		default:
			if trimmed := strings.TrimSpace(src); trimmed != "" {
				labels = append(labels, trimmed)
			}
		}
	}
	sort.Strings(labels)
	return labels
}

func joinBase(base, path string) string {
	base = strings.TrimRight(base, "/")
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	return base + path
}

func fallback(value, alt string) string {
	if strings.TrimSpace(value) != "" {
		return value
	}
	return alt
}

func contains(list []string, value string) bool {
	for _, item := range list {
		if strings.EqualFold(strings.TrimSpace(item), strings.TrimSpace(value)) {
			return true
		}
	}
	return false
}

func statusLabel(status adminpromotions.Status) string {
	switch status {
	case adminpromotions.StatusActive:
		return "アクティブ"
	case adminpromotions.StatusPaused:
		return "一時停止"
	case adminpromotions.StatusScheduled:
		return "公開予定"
	case adminpromotions.StatusExpired:
		return "終了"
	case adminpromotions.StatusDraft:
		return "下書き"
	default:
		return string(status)
	}
}
