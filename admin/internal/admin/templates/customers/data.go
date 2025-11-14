package customers

import (
	"context"
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
	AvatarAlt         string
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
func BuildPageData(ctx context.Context, basePath string, state QueryState, result admincustomers.ListResult, table TableData) PageData {
	formatter := helpers.NewFormatter(ctx)
	lastUpdated, lastRelative := "-", ""
	if !result.GeneratedAt.IsZero() {
		lastUpdated = formatter.Date(result.GeneratedAt, "2006-01-02 15:04")
		lastRelative = formatter.Relative(result.GeneratedAt)
	}

	return PageData{
		Title:         formatter.T("admin.customers.title"),
		Description:   formatter.T("admin.customers.description"),
		Breadcrumbs:   []partials.Breadcrumb{{Label: formatter.T("admin.customers.breadcrumb")}},
		TableEndpoint: joinBase(basePath, "/customers/table"),
		ResetURL:      joinBase(basePath, "/customers"),
		Query:         state,
		Filters:       buildFilters(formatter, state, result.Filters),
		Table:         table,
		Metrics:       buildMetrics(formatter, result.Summary),
		Segments:      buildSegments(formatter, state, result.Summary),
		LastUpdated:   lastUpdated,
		LastRelative:  lastRelative,
	}
}

// TablePayload prepares the table fragment data.
func TablePayload(ctx context.Context, basePath string, state QueryState, result admincustomers.ListResult, errMsg string) TableData {
	formatter := helpers.NewFormatter(ctx)
	base := joinBase(basePath, "/customers")
	fragment := joinBase(basePath, "/customers/table")
	rows := toTableRows(formatter, basePath, result.Customers)

	empty := ""
	if errMsg == "" && len(rows) == 0 {
		empty = formatter.T("admin.customers.table.empty")
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

func buildMetrics(formatter helpers.Formatter, summary admincustomers.Summary) []MetricCard {
	if summary.TotalCustomers == 0 {
		return []MetricCard{
			{Label: formatter.T("admin.customers.metrics.total.label"), Value: "0"},
			{Label: formatter.T("admin.customers.metrics.active_rate.label"), Value: "0%"},
			{Label: formatter.T("admin.customers.metrics.ltv.label"), Value: formatter.Currency(0, "JPY")},
		}
	}

	metrics := []MetricCard{
		{
			Label:   formatter.T("admin.customers.metrics.total.label"),
			Value:   strconv.Itoa(summary.TotalCustomers),
			SubText: formatter.T("admin.customers.metrics.total.subtext", summary.DeactivatedCustomers),
			Tone:    "",
			Icon:    "👥",
		},
		{
			Label:   formatter.T("admin.customers.metrics.active_rate.label"),
			Value:   fmt.Sprintf("%d%%", int(math.Round(activeRate(summary)*100))),
			SubText: formatter.T("admin.customers.metrics.active_rate.subtext", summary.ActiveCustomers),
			Tone:    "success",
			Icon:    "✅",
		},
		{
			Label:   formatter.T("admin.customers.metrics.ltv.label"),
			Value:   formatter.Currency(summary.TotalLifetimeMinor, summary.PrimaryCurrency),
			SubText: formatter.T("admin.customers.metrics.ltv.subtext", formatter.Currency(int64(math.Round(summary.AverageOrderValue)), summary.PrimaryCurrency)),
			Tone:    "info",
			Icon:    "💴",
		},
	}
	if summary.HighValueCustomers > 0 {
		metrics = append(metrics, MetricCard{
			Label:   formatter.T("admin.customers.metrics.high_value.label"),
			Value:   strconv.Itoa(summary.HighValueCustomers),
			SubText: formatter.T("admin.customers.metrics.high_value.subtext"),
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

func buildSegments(formatter helpers.Formatter, state QueryState, summary admincustomers.Summary) []SegmentChip {
	if len(summary.Segments) == 0 {
		return nil
	}
	chips := make([]SegmentChip, 0, len(summary.Segments))
	for _, segment := range summary.Segments {
		label := formatter.T("admin.customers.tier." + segment.Key)
		if segment.Key == "all" {
			label = formatter.T("admin.customers.segments.all")
		} else if label == "admin.customers.tier."+segment.Key {
			label = formatter.T("admin.customers.tier.other")
		}
		chips = append(chips, SegmentChip{
			Key:     segment.Key,
			Label:   label,
			Count:   segment.Count,
			Active:  state.Tier != "" && strings.EqualFold(state.Tier, segment.Key),
			Tooltip: formatter.T("admin.customers.segments.tooltip", label),
		})
	}
	sort.SliceStable(chips, func(i, j int) bool {
		return chips[i].Count > chips[j].Count
	})
	return chips
}

func buildFilters(formatter helpers.Formatter, state QueryState, filters admincustomers.FilterSummary) Filters {
	statusOptions := []StatusFilterOption{
		{Value: "", Label: formatter.T("admin.customers.status.all"), Tone: "", Count: totalStatusCount(filters.StatusOptions)},
	}
	for _, option := range filters.StatusOptions {
		tone := statusTone(option.Value)
		statusOptions = append(statusOptions, StatusFilterOption{
			Value:  string(option.Value),
			Label:  formatter.T("admin.customers.status." + string(option.Value)),
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
		Label:    formatter.T("admin.customers.tier.all"),
		Selected: state.Tier == "",
	})
	for _, option := range filters.TierOptions {
		label := formatter.T("admin.customers.tier." + option.Value)
		if label == "admin.customers.tier."+option.Value {
			label = formatter.T("admin.customers.tier.other")
		}
		tierOptions = append(tierOptions, TierFilterOption{
			Value:    option.Value,
			Label:    label,
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

func toTableRows(formatter helpers.Formatter, basePath string, customers []admincustomers.Customer) []TableRow {
	rows := make([]TableRow, 0, len(customers))
	for _, customer := range customers {
		name := strings.TrimSpace(customer.DisplayName)
		var avatarAlt string
		if name != "" {
			avatarAlt = formatter.T("admin.customers.avatar.alt_named", name)
		} else {
			avatarAlt = formatter.T("admin.customers.avatar.alt_generic")
		}

		row := TableRow{
			ID:               customer.ID,
			DisplayName:      customer.DisplayName,
			Email:            customer.Email,
			Company:          customer.Company,
			Location:         customer.Location,
			AvatarURL:        customer.AvatarURL,
			AvatarAlt:        avatarAlt,
			DetailURL:        joinBase(basePath, "/customers/"+url.PathEscape(strings.TrimSpace(customer.ID))),
			TotalOrdersLabel: formatter.T("admin.customers.table.orders_count", customer.TotalOrders),
			LifetimeValue:    formatter.Currency(customer.LifetimeValueMinor, customer.Currency),
			StatusLabel:      statusLabel(formatter, customer.Status),
			StatusTone:       statusTone(customer.Status),
			TierLabel:        tierLabel(formatter, customer.Tier),
			TierTone:         tierTone(customer.Tier),
			RiskLabel:        riskLabel(formatter, customer.RiskLevel),
			RiskTone:         riskTone(customer.RiskLevel),
			Flags:            toFlagBadges(customer.Flags),
			Tags:             append([]string(nil), customer.Tags...),
		}

		if !customer.LastOrderAt.IsZero() {
			row.LastOrderLabel = formatter.Date(customer.LastOrderAt, "2006-01-02 15:04")
			row.LastOrderRelative = formatter.Relative(customer.LastOrderAt)
			row.LastOrderNumber = customer.LastOrderNumber
		} else {
			row.LastOrderLabel = formatter.T("admin.customers.table.no_orders")
			row.LastOrderRelative = ""
		}

		rows = append(rows, row)
	}
	return rows
}

func statusLabel(formatter helpers.Formatter, status admincustomers.Status) string {
	switch status {
	case admincustomers.StatusActive:
		return formatter.T("admin.customers.status.active")
	case admincustomers.StatusDeactivated:
		return formatter.T("admin.customers.status.deactivated")
	case admincustomers.StatusInvited:
		return formatter.T("admin.customers.status.invited")
	default:
		return string(status)
	}
}

func tierLabel(formatter helpers.Formatter, tier string) string {
	switch strings.ToLower(strings.TrimSpace(tier)) {
	case "vip":
		return formatter.T("admin.customers.tier.vip")
	case "gold":
		return formatter.T("admin.customers.tier.gold")
	case "silver":
		return formatter.T("admin.customers.tier.silver")
	case "bronze":
		return formatter.T("admin.customers.tier.bronze")
	default:
		return formatter.T("admin.customers.tier.other")
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

func riskLabel(formatter helpers.Formatter, level string) string {
	switch strings.ToLower(level) {
	case "high":
		return formatter.T("admin.customers.risk.high")
	case "medium":
		return formatter.T("admin.customers.risk.medium")
	case "low":
		return formatter.T("admin.customers.risk.low")
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
