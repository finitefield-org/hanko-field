package main

import (
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	mw "finitefield.org/hanko-web/internal/middleware"
)

const accountOrdersPageSize = 6

var accountOrdersNow = time.Date(2025, time.March, 24, 9, 0, 0, 0, time.UTC)

// AccountOrdersPageView drives the `/account/orders` layout.
type AccountOrdersPageView struct {
	Lang     string
	User     AccountUser
	NavItems []AccountNavItem

	Section AccountOrdersSection
	Filters AccountOrdersFilterView
	Table   AccountOrdersTableView
	Support AccountOrdersSupportCard
}

// AccountOrdersSection configures the section header copy.
type AccountOrdersSection struct {
	Eyebrow  string
	Title    string
	Subtitle string
}

// AccountOrdersFilterView powers the toolbar controls.
type AccountOrdersFilterView struct {
	Status string
	Range  string
	Query  string

	StatusOptions []AccountOrdersFilterOption
	RangeOptions  []AccountOrdersFilterOption
	ResultsLabel  string
}

// AccountOrdersFilterOption represents a selectable filter chip/option.
type AccountOrdersFilterOption struct {
	ID     string
	Label  string
	Count  int
	Active bool
}

// AccountOrdersTableView feeds the orders table fragment.
type AccountOrdersTableView struct {
	Lang string

	Rows []AccountOrderRow

	Total       int
	Page        int
	Per         int
	Showing     int
	HasMore     bool
	NextPage    int
	LastUpdated time.Time

	EmptyTitle       string
	EmptyBody        string
	EmptyActionLabel string
	EmptyActionHref  string
}

// AccountOrderRow represents one order in the table.
type AccountOrderRow struct {
	ID          string
	Number      string
	DetailURL   string
	PlacedAt    time.Time
	Total       int64
	Currency    string
	StatusKey   string
	StatusTone  string
	StatusLabel string
	Summary     string
}

// AccountOrdersSupportCard renders the inline help banner.
type AccountOrdersSupportCard struct {
	Tone     string
	Title    string
	Body     string
	CTALabel string
	CTAHref  string
}

func buildAccountOrdersPageView(lang string, sess *mw.SessionData, q url.Values) AccountOrdersPageView {
	profile := sessionProfileOrFallback(sess.Profile, lang)
	user := accountUserFromProfile(profile, lang)

	status := normalizeAccountOrderStatus(strings.TrimSpace(q.Get("status")))
	dateRange := normalizeAccountOrderRange(strings.TrimSpace(q.Get("range")))
	query := strings.TrimSpace(q.Get("q"))
	queryLower := strings.ToLower(query)
	page := parseAccountOrdersPage(q.Get("page"))

	allOrders := accountOrdersMockData()
	rangeFiltered := make([]accountOrder, 0, len(allOrders))
	statusCounts := map[string]int{
		"all":        0,
		"processing": 0,
		"production": 0,
		"fulfilled":  0,
		"shipped":    0,
		"cancelled":  0,
		"draft":      0,
	}
	for _, o := range allOrders {
		if !withinAccountOrderRange(o.PlacedAt, dateRange) {
			continue
		}
		if query != "" && !strings.Contains(o.searchIndex, queryLower) {
			continue
		}
		rangeFiltered = append(rangeFiltered, o)
		statusCounts["all"]++
		statusCounts[o.Status]++
	}

	filtered := make([]accountOrder, 0, len(rangeFiltered))
	for _, o := range rangeFiltered {
		if status != "" && status != "all" && o.Status != status {
			continue
		}
		filtered = append(filtered, o)
	}

	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].PlacedAt.After(filtered[j].PlacedAt)
	})

	total := len(filtered)
	per := accountOrdersPageSize
	if per <= 0 {
		per = 10
	}
	if page < 1 {
		page = 1
	}
	maxPage := 1
	if total > 0 {
		maxPage = (total + per - 1) / per
	}
	if page > maxPage {
		page = maxPage
	}
	limit := page * per
	if limit > total {
		limit = total
	}
	rows := make([]AccountOrderRow, 0, limit)
	for i := 0; i < limit; i++ {
		o := filtered[i]
		rows = append(rows, AccountOrderRow{
			ID:          o.ID,
			Number:      o.Number,
			DetailURL:   "/account/orders/" + url.PathEscape(o.ID),
			PlacedAt:    o.PlacedAt,
			Total:       o.Total,
			Currency:    o.Currency,
			StatusKey:   o.Status,
			StatusTone:  accountOrderStatusTone(o.Status),
			StatusLabel: accountOrderStatusLabel(lang, o.Status),
			Summary:     accountOrderSummary(lang, o),
		})
	}

	section := AccountOrdersSection{
		Eyebrow:  i18nOrDefault(lang, "account.orders.section.eyebrow", "Orders"),
		Title:    i18nOrDefault(lang, "account.orders.section.title", "Order history"),
		Subtitle: i18nOrDefault(lang, "account.orders.section.subtitle", "Track fulfillment, download invoices, and revisit order status updates."),
	}

	statusOptions := buildAccountOrderStatusFilters(lang, status, statusCounts)
	rangeOptions := buildAccountOrderRangeFilters(lang, dateRange)

	filters := AccountOrdersFilterView{
		Status:        status,
		Range:         dateRange,
		Query:         query,
		StatusOptions: statusOptions,
		RangeOptions:  rangeOptions,
		ResultsLabel:  fmt.Sprintf("%s %d/%d", i18nOrDefault(lang, "account.orders.filters.showing", "Showing"), len(rows), total),
	}

	table := AccountOrdersTableView{
		Lang:             lang,
		Rows:             rows,
		Total:            total,
		Page:             page,
		Per:              per,
		Showing:          limit,
		HasMore:          limit < total,
		NextPage:         page + 1,
		LastUpdated:      accountOrdersNow,
		EmptyTitle:       i18nOrDefault(lang, "account.orders.empty.title", "No orders yet"),
		EmptyBody:        i18nOrDefault(lang, "account.orders.empty.body", "As soon as you place an order, it will appear here with real-time updates."),
		EmptyActionLabel: i18nOrDefault(lang, "account.orders.empty.cta", "Start a new order"),
		EmptyActionHref:  "/design/new",
	}

	support := AccountOrdersSupportCard{
		Tone:     "info",
		Title:    i18nOrDefault(lang, "account.orders.support.title", "Need help with an order?"),
		Body:     i18nOrDefault(lang, "account.orders.support.body", "Visit the operations guide to learn about lead times, delivery expectations, and escalation paths."),
		CTALabel: i18nOrDefault(lang, "account.orders.support.cta", "Open order guide"),
		CTAHref:  "/guides/operations-orders",
	}

	return AccountOrdersPageView{
		Lang:     lang,
		User:     user,
		NavItems: accountNavItems(lang, "orders"),
		Section:  section,
		Filters:  filters,
		Table:    table,
		Support:  support,
	}
}

func buildAccountOrderStatusFilters(lang, active string, counts map[string]int) []AccountOrdersFilterOption {
	statuses := []struct {
		ID    string
		Label string
	}{
		{ID: "all", Label: i18nOrDefault(lang, "account.orders.status.all", "All statuses")},
		{ID: "processing", Label: accountOrderStatusLabel(lang, "processing")},
		{ID: "production", Label: accountOrderStatusLabel(lang, "production")},
		{ID: "fulfilled", Label: accountOrderStatusLabel(lang, "fulfilled")},
		{ID: "shipped", Label: accountOrderStatusLabel(lang, "shipped")},
		{ID: "cancelled", Label: accountOrderStatusLabel(lang, "cancelled")},
		{ID: "draft", Label: accountOrderStatusLabel(lang, "draft")},
	}
	opts := make([]AccountOrdersFilterOption, 0, len(statuses))
	for _, s := range statuses {
		count := counts[s.ID]
		if s.ID == "all" {
			count = counts["all"]
		}
		opts = append(opts, AccountOrdersFilterOption{
			ID:     s.ID,
			Label:  s.Label,
			Count:  count,
			Active: (active == "" && s.ID == "all") || active == s.ID,
		})
	}
	return opts
}

func buildAccountOrderRangeFilters(lang, active string) []AccountOrdersFilterOption {
	options := []AccountOrdersFilterOption{
		{ID: "all", Label: i18nOrDefault(lang, "account.orders.range.all", "All time")},
		{ID: "30d", Label: i18nOrDefault(lang, "account.orders.range.30d", "Last 30 days")},
		{ID: "90d", Label: i18nOrDefault(lang, "account.orders.range.90d", "Last 90 days")},
		{ID: "365d", Label: i18nOrDefault(lang, "account.orders.range.365d", "Last 12 months")},
	}
	for i := range options {
		options[i].Active = (active == "" && options[i].ID == "all") || active == options[i].ID
	}
	return options
}

func normalizeAccountOrderStatus(status string) string {
	switch status {
	case "processing", "production", "fulfilled", "shipped", "cancelled", "draft", "all":
		return status
	default:
		return ""
	}
}

func normalizeAccountOrderRange(r string) string {
	switch r {
	case "30d", "90d", "365d":
		return r
	default:
		return "all"
	}
}

func parseAccountOrdersPage(v string) int {
	if v == "" {
		return 1
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return 1
	}
	if n < 1 {
		return 1
	}
	return n
}

func withinAccountOrderRange(ts time.Time, r string) bool {
	if r == "" || r == "all" {
		return true
	}
	diff := accountOrdersNow.Sub(ts)
	switch r {
	case "30d":
		return diff <= 30*24*time.Hour
	case "90d":
		return diff <= 90*24*time.Hour
	case "365d":
		return diff <= 365*24*time.Hour
	}
	return true
}

func accountOrderStatusTone(status string) string {
	switch status {
	case "fulfilled", "shipped":
		return "success"
	case "cancelled":
		return "danger"
	case "processing":
		return "info"
	case "production":
		return "indigo"
	case "draft":
		return "muted"
	default:
		return "muted"
	}
}

func accountOrderStatusLabel(lang, status string) string {
	key := "account.orders.status." + status
	defaults := map[string]string{
		"processing": "Processing",
		"production": "In production",
		"fulfilled":  "Fulfilled",
		"shipped":    "Shipped",
		"cancelled":  "Cancelled",
		"draft":      "Draft",
		"all":        "All statuses",
	}
	if def, ok := defaults[status]; ok {
		return i18nOrDefault(lang, key, def)
	}
	return i18nOrDefault(lang, key, titleCaseASCII(status))
}

func accountOrderSummary(lang string, o accountOrder) string {
	return fmt.Sprintf("%s · %s", o.PrimaryItem, o.Destination)
}

type accountOrder struct {
	ID          string
	Number      string
	PlacedAt    time.Time
	Total       int64
	Currency    string
	Status      string
	PrimaryItem string
	Destination string
	searchIndex string
}

func accountOrdersMockData() []accountOrder {
	data := []accountOrder{
		{
			ID:          "ord_20250321A",
			Number:      "HF-2025-0321",
			PlacedAt:    accountOrdersNow.Add(-48 * time.Hour),
			Total:       2860000,
			Currency:    "JPY",
			Status:      "production",
			PrimaryItem: "Corporate seal bundle (engraved)",
			Destination: "Tokyo HQ · Logistics",
		},
		{
			ID:          "ord_20250318B",
			Number:      "HF-2025-0318",
			PlacedAt:    accountOrdersNow.Add(-5 * 24 * time.Hour),
			Total:       1345000,
			Currency:    "JPY",
			Status:      "processing",
			PrimaryItem: "Onboarding kits (12 sets)",
			Destination: "Osaka Studio · Operations",
		},
		{
			ID:          "ord_20250310C",
			Number:      "HF-2025-0310",
			PlacedAt:    accountOrdersNow.Add(-14 * 24 * time.Hour),
			Total:       980000,
			Currency:    "JPY",
			Status:      "production",
			PrimaryItem: "Desk seals · Premium wood",
			Destination: "Nagoya Branch · People Ops",
		},
		{
			ID:          "ord_20250222D",
			Number:      "HF-2025-0222",
			PlacedAt:    accountOrdersNow.Add(-30 * 24 * time.Hour),
			Total:       1625000,
			Currency:    "JPY",
			Status:      "fulfilled",
			PrimaryItem: "Bilingual approval seals",
			Destination: "Singapore Office · Admin",
		},
		{
			ID:          "ord_20250212E",
			Number:      "HF-2025-0212",
			PlacedAt:    accountOrdersNow.Add(-40 * 24 * time.Hour),
			Total:       742000,
			Currency:    "JPY",
			Status:      "shipped",
			PrimaryItem: "Inkan replacements (6)",
			Destination: "Kyoto Satellite",
		},
		{
			ID:          "ord_20250201F",
			Number:      "HF-2025-0201",
			PlacedAt:    accountOrdersNow.Add(-51 * 24 * time.Hour),
			Total:       320000,
			Currency:    "JPY",
			Status:      "fulfilled",
			PrimaryItem: "Visitor badge seals",
			Destination: "Tokyo HQ · Reception",
		},
		{
			ID:          "ord_20250118G",
			Number:      "HF-2025-0118",
			PlacedAt:    accountOrdersNow.Add(-65 * 24 * time.Hour),
			Total:       212000,
			Currency:    "JPY",
			Status:      "cancelled",
			PrimaryItem: "Seasonal commemorative stamp",
			Destination: "Internal Communications",
		},
		{
			ID:          "ord_20250105H",
			Number:      "HF-2025-0105",
			PlacedAt:    accountOrdersNow.Add(-78 * 24 * time.Hour),
			Total:       1120000,
			Currency:    "JPY",
			Status:      "fulfilled",
			PrimaryItem: "Department seals (18)",
			Destination: "Fukuoka Office · People Ops",
		},
		{
			ID:          "ord_20241220I",
			Number:      "HF-2024-1220",
			PlacedAt:    accountOrdersNow.Add(-94 * 24 * time.Hour),
			Total:       865000,
			Currency:    "JPY",
			Status:      "shipped",
			PrimaryItem: "Holiday gifting seals",
			Destination: "Remote · Project Aster",
		},
		{
			ID:          "ord_20241130J",
			Number:      "HF-2024-1130",
			PlacedAt:    accountOrdersNow.Add(-115 * 24 * time.Hour),
			Total:       154000,
			Currency:    "JPY",
			Status:      "draft",
			PrimaryItem: "Event booth signage stamp",
			Destination: "Osaka Expo Team",
		},
		{
			ID:          "ord_20241005K",
			Number:      "HF-2024-1005",
			PlacedAt:    accountOrdersNow.Add(-170 * 24 * time.Hour),
			Total:       1200000,
			Currency:    "JPY",
			Status:      "fulfilled",
			PrimaryItem: "Legal-entity seal refresh",
			Destination: "Corporate Legal · Tokyo",
		},
		{
			ID:          "ord_20240918L",
			Number:      "HF-2024-0918",
			PlacedAt:    accountOrdersNow.Add(-187 * 24 * time.Hour),
			Total:       640000,
			Currency:    "JPY",
			Status:      "fulfilled",
			PrimaryItem: "Renewal seal kit (8)",
			Destination: "Nagoya Branch · Sales",
		},
	}

	for i := range data {
		idxParts := []string{
			strings.ToLower(data[i].Number),
			strings.ToLower(data[i].PrimaryItem),
			strings.ToLower(data[i].Destination),
			strings.ToLower(data[i].Status),
		}
		data[i].searchIndex = strings.Join(idxParts, " ")
	}

	sort.Slice(data, func(i, j int) bool {
		return data[i].PlacedAt.After(data[j].PlacedAt)
	})
	return data
}
