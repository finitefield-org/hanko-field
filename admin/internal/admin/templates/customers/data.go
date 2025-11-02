package customers

import (
	"fmt"
	"math"
	"net/url"
	"sort"
	"strconv"
	"strings"

	admincustomers "finitefield.org/hanko-admin/internal/admin/customers"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData represents the payload for the customers index page.
type PageData struct {
	Title         string
	Description   string
	Breadcrumbs   []partials.Breadcrumb
	TableEndpoint string
	ResetURL      string
	Query         QueryState
	Filters       Filters
	Table         TableData
	Metrics       []MetricCard
	Segments      []SegmentChip
	LastUpdated   string
	LastRelative  string
}

// QueryState captures the current filter and pagination inputs.
type QueryState struct {
	Search    string
	Status    string
	Tier      string
	Page      int
	PageSize  int
	Sort      string
	SortKey   string
	SortDir   string
	RawQuery  string
	HasFilter bool
}

// Filters encapsulates the filter control options.
type Filters struct {
	Status []StatusFilterOption
	Tiers  []TierFilterOption
}

// StatusFilterOption renders a chip-style filter choice.
type StatusFilterOption struct {
	Value  string
	Label  string
	Count  int
	Tone   string
	Active bool
}

// TierFilterOption renders a select-style option.
type TierFilterOption struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// MetricCard renders a summary metric chip.
type MetricCard struct {
	Label   string
	Value   string
	SubText string
	Tone    string
	Icon    string
}

// SegmentChip renders the segment distribution chips.
type SegmentChip struct {
	Key     string
	Label   string
	Count   int
	Active  bool
	Tooltip string
}

// TableData represents the table fragment payload.
type TableData struct {
	BasePath     string
	FragmentPath string
	Rows         []TableRow
	Error        string
	EmptyMessage string
	Pagination   components.PaginationProps
	Sort         SortState
	HxTarget     string
	HxSwap       string
	RawQuery     string
}

// SortState describes current sort state for header controls.
type SortState struct {
	Active       string
	BasePath     string
	FragmentPath string
	RawQuery     string
	Param        string
	PageParam    string
	HxTarget     string
	HxSwap       string
	HxPushURL    bool
}

// TableRow represents a single customer row.
type TableRow struct {
	ID                string
	DisplayName       string
	Email             string
	Company           string
	Location          string
	AvatarURL         string
	DetailURL         string
	TotalOrdersLabel  string
	LifetimeValue     string
	LastOrderLabel    string
	LastOrderRelative string
	LastOrderNumber   string
	StatusLabel       string
	StatusTone        string
	TierLabel         string
	TierTone          string
	RiskLabel         string
	RiskTone          string
	Flags             []BadgeView
	Tags              []string
}

// BadgeView renders a badge in the flags column.
type BadgeView struct {
	Label string
	Tone  string
	Icon  string
	Title string
}

// BuildPageData assembles the full page payload.
func BuildPageData(basePath string, state QueryState, result admincustomers.ListResult, table TableData) PageData {
	lastUpdated, lastRelative := "-", ""
	if !result.GeneratedAt.IsZero() {
		lastUpdated = helpers.Date(result.GeneratedAt, "2006-01-02 15:04")
		lastRelative = helpers.Relative(result.GeneratedAt)
	}

	return PageData{
		Title:         "顧客一覧",
		Description:   "顧客の検索、セグメント確認、リスクフラグの把握を行います。",
		Breadcrumbs:   []partials.Breadcrumb{{Label: "顧客"}},
		TableEndpoint: joinBase(basePath, "/customers/table"),
		ResetURL:      joinBase(basePath, "/customers"),
		Query:         state,
		Filters:       buildFilters(state, result.Filters),
		Table:         table,
		Metrics:       buildMetrics(result.Summary),
		Segments:      buildSegments(state, result.Summary),
		LastUpdated:   lastUpdated,
		LastRelative:  lastRelative,
	}
}

// TablePayload prepares the table fragment data.
func TablePayload(basePath string, state QueryState, result admincustomers.ListResult, errMsg string) TableData {
	base := joinBase(basePath, "/customers")
	fragment := joinBase(basePath, "/customers/table")
	rows := toTableRows(basePath, result.Customers)

	empty := ""
	if errMsg == "" && len(rows) == 0 {
		empty = "条件に一致する顧客はありません。フィルタを調整してください。"
	}

	total := result.Pagination.TotalItems
	pagination := components.PaginationProps{
		Info: components.PageInfo{
			PageSize:   result.Pagination.PageSize,
			Current:    result.Pagination.Page,
			Count:      len(rows),
			TotalItems: &total,
			Next:       result.Pagination.NextPage,
			Prev:       result.Pagination.PrevPage,
		},
		BasePath:      base,
		RawQuery:      state.RawQuery,
		FragmentPath:  fragment,
		FragmentQuery: state.RawQuery,
		Param:         "page",
		SizeParam:     "pageSize",
		HxTarget:      "#customers-table",
		HxSwap:        "outerHTML",
		HxPushURL:     true,
		Label:         "Customers pagination",
	}

	data := TableData{
		BasePath:     base,
		FragmentPath: fragment,
		Rows:         rows,
		Error:        errMsg,
		EmptyMessage: empty,
		Pagination:   pagination,
		Sort: SortState{
			Active:       state.Sort,
			BasePath:     base,
			FragmentPath: fragment,
			RawQuery:     state.RawQuery,
			Param:        "sort",
			PageParam:    "page",
			HxTarget:     "#customers-table",
			HxSwap:       "outerHTML",
			HxPushURL:    true,
		},
		HxTarget: "#customers-table",
		HxSwap:   "outerHTML",
		RawQuery: state.RawQuery,
	}

	if errMsg != "" {
		data.Error = errMsg
	}

	return data
}

func buildMetrics(summary admincustomers.Summary) []MetricCard {
	if summary.TotalCustomers == 0 {
		return []MetricCard{
			{Label: "登録顧客", Value: "0"},
			{Label: "アクティブ", Value: "0"},
			{Label: "累計LTV", Value: "¥0.00"},
		}
	}

	metrics := []MetricCard{
		{
			Label:   "登録顧客",
			Value:   strconv.Itoa(summary.TotalCustomers),
			SubText: fmt.Sprintf("うち停止 %d", summary.DeactivatedCustomers),
			Tone:    "",
			Icon:    "👥",
		},
		{
			Label:   "アクティブ率",
			Value:   fmt.Sprintf("%d%%", int(math.Round(activeRate(summary)*100))),
			SubText: fmt.Sprintf("アクティブ %d", summary.ActiveCustomers),
			Tone:    "success",
			Icon:    "✅",
		},
		{
			Label:   "累計LTV",
			Value:   helpers.Currency(summary.TotalLifetimeMinor, summary.PrimaryCurrency),
			SubText: fmt.Sprintf("平均注文額 %s", helpers.Currency(int64(math.Round(summary.AverageOrderValue)), summary.PrimaryCurrency)),
			Tone:    "info",
			Icon:    "💴",
		},
	}
	if summary.HighValueCustomers > 0 {
		metrics = append(metrics, MetricCard{
			Label:   "ハイバリュー顧客",
			Value:   strconv.Itoa(summary.HighValueCustomers),
			SubText: "LTV 100万円以上",
			Tone:    "warning",
			Icon:    "💎",
		})
	}
	return metrics
}

func activeRate(summary admincustomers.Summary) float64 {
	if summary.TotalCustomers == 0 {
		return 0
	}
	return float64(summary.ActiveCustomers) / float64(summary.TotalCustomers)
}

func buildSegments(state QueryState, summary admincustomers.Summary) []SegmentChip {
	if len(summary.Segments) == 0 {
		return nil
	}
	chips := make([]SegmentChip, 0, len(summary.Segments))
	for _, segment := range summary.Segments {
		chips = append(chips, SegmentChip{
			Key:     segment.Key,
			Label:   segment.Label,
			Count:   segment.Count,
			Active:  state.Tier != "" && strings.EqualFold(state.Tier, segment.Key),
			Tooltip: fmt.Sprintf("%s セグメント", segment.Label),
		})
	}
	sort.SliceStable(chips, func(i, j int) bool {
		return chips[i].Count > chips[j].Count
	})
	return chips
}

func buildFilters(state QueryState, filters admincustomers.FilterSummary) Filters {
	statusOptions := []StatusFilterOption{
		{Value: "", Label: "全て", Tone: "", Count: totalStatusCount(filters.StatusOptions)},
	}
	for _, option := range filters.StatusOptions {
		tone := statusTone(option.Value)
		statusOptions = append(statusOptions, StatusFilterOption{
			Value:  string(option.Value),
			Label:  option.Label,
			Count:  option.Count,
			Tone:   tone,
			Active: state.Status == string(option.Value),
		})
	}
	for i := range statusOptions {
		if statusOptions[i].Value == "" {
			statusOptions[i].Active = state.Status == ""
		}
	}

	tierOptions := make([]TierFilterOption, 0, len(filters.TierOptions)+1)
	tierOptions = append(tierOptions, TierFilterOption{
		Value:    "",
		Label:    "全てのティア",
		Selected: state.Tier == "",
	})
	for _, option := range filters.TierOptions {
		tierOptions = append(tierOptions, TierFilterOption{
			Value:    option.Value,
			Label:    option.Label,
			Count:    option.Count,
			Selected: strings.EqualFold(state.Tier, option.Value),
		})
	}

	return Filters{
		Status: statusOptions,
		Tiers:  tierOptions,
	}
}

func totalStatusCount(options []admincustomers.StatusOption) int {
	total := 0
	for _, option := range options {
		total += option.Count
	}
	return total
}

func statusTone(status admincustomers.Status) string {
	switch status {
	case admincustomers.StatusActive:
		return "success"
	case admincustomers.StatusDeactivated:
		return "danger"
	case admincustomers.StatusInvited:
		return "warning"
	default:
		return ""
	}
}

func toTableRows(basePath string, customers []admincustomers.Customer) []TableRow {
	rows := make([]TableRow, 0, len(customers))
	for _, customer := range customers {
		row := TableRow{
			ID:               customer.ID,
			DisplayName:      customer.DisplayName,
			Email:            customer.Email,
			Company:          customer.Company,
			Location:         customer.Location,
			AvatarURL:        customer.AvatarURL,
			DetailURL:        joinBase(basePath, "/customers/"+url.PathEscape(strings.TrimSpace(customer.ID))),
			TotalOrdersLabel: fmt.Sprintf("%d件", customer.TotalOrders),
			LifetimeValue:    helpers.Currency(customer.LifetimeValueMinor, customer.Currency),
			StatusLabel:      statusLabel(customer.Status),
			StatusTone:       statusTone(customer.Status),
			TierLabel:        tierLabel(customer.Tier),
			TierTone:         tierTone(customer.Tier),
			RiskLabel:        riskLabel(customer.RiskLevel),
			RiskTone:         riskTone(customer.RiskLevel),
			Flags:            toFlagBadges(customer.Flags),
			Tags:             append([]string(nil), customer.Tags...),
		}

		if !customer.LastOrderAt.IsZero() {
			row.LastOrderLabel = helpers.Date(customer.LastOrderAt, "2006-01-02 15:04")
			row.LastOrderRelative = helpers.Relative(customer.LastOrderAt)
			row.LastOrderNumber = customer.LastOrderNumber
		} else {
			row.LastOrderLabel = "未注文"
			row.LastOrderRelative = ""
		}

		rows = append(rows, row)
	}
	return rows
}

func statusLabel(status admincustomers.Status) string {
	switch status {
	case admincustomers.StatusActive:
		return "アクティブ"
	case admincustomers.StatusDeactivated:
		return "無効化"
	case admincustomers.StatusInvited:
		return "未アクティブ"
	default:
		return string(status)
	}
}

func tierLabel(tier string) string {
	switch strings.ToLower(strings.TrimSpace(tier)) {
	case "vip":
		return "VIP"
	case "gold":
		return "ゴールド"
	case "silver":
		return "シルバー"
	case "bronze":
		return "ブロンズ"
	default:
		return "その他"
	}
}

func tierTone(tier string) string {
	switch strings.ToLower(strings.TrimSpace(tier)) {
	case "vip":
		return "warning"
	case "gold":
		return "info"
	case "silver":
		return ""
	case "bronze":
		return ""
	default:
		return ""
	}
}

func riskLabel(level string) string {
	switch strings.ToLower(level) {
	case "high":
		return "ハイリスク"
	case "medium":
		return "注意"
	case "low":
		return "安定"
	default:
		return ""
	}
}

func riskTone(level string) string {
	switch strings.ToLower(level) {
	case "high":
		return "danger"
	case "medium":
		return "warning"
	case "low":
		return "success"
	default:
		return ""
	}
}

func toFlagBadges(flags []admincustomers.Flag) []BadgeView {
	if len(flags) == 0 {
		return nil
	}
	badges := make([]BadgeView, 0, len(flags))
	for _, flag := range flags {
		badges = append(badges, BadgeView{
			Label: flag.Label,
			Tone:  flag.Tone,
			Icon:  flag.Icon,
			Title: flag.Description,
		})
	}
	return badges
}

func joinBase(base, suffix string) string {
	if strings.TrimSpace(suffix) == "" {
		return base
	}
	if strings.HasSuffix(base, "/") {
		base = strings.TrimRight(base, "/")
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	if base == "" {
		base = "/"
	}
	if base == "/" {
		return suffix
	}
	return base + suffix
}
