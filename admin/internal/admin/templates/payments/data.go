package payments

import (
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	adminpayments "finitefield.org/hanko-admin/internal/admin/payments"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData contains the SSR payload for the payments transactions page.
type PageData struct {
	Title          string
	Description    string
	Breadcrumbs    []partials.Breadcrumb
	SummaryCards   []SummaryCard
	Query          QueryState
	Filters        Filters
	Table          TableData
	Drawer         DrawerData
	Toolbar        components.BulkToolbarProps
	TableEndpoint  string
	DrawerEndpoint string
	ExportURL      string
	ResetURL       string
	SavedViews     []SavedView
}

// SummaryCard renders the headline metrics chips.
type SummaryCard struct {
	Label     string
	Value     string
	SubLabel  string
	Delta     string
	DeltaTone string
	Icon      string
}

// QueryState represents the applied list filters.
type QueryState struct {
	Providers   []string
	Statuses    []string
	From        string
	To          string
	AmountMin   string
	AmountMax   string
	OnlyFlagged bool
	Page        int
	PageSize    int
	RawQuery    string
	SelectedID  string
	Sort        string
}

// Filters aggregates the filter view models.
type Filters struct {
	ProviderOptions []Option
	StatusOptions   []StatusChip
	AmountHint      string
	AmountMinBound  string
	AmountMaxBound  string
	FlaggedCount    int
}

// Option models a multi-select option.
type Option struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// StatusChip renders a chip-style filter for status.
type StatusChip struct {
	Value  string
	Label  string
	Count  int
	Tone   string
	Active bool
}

// SavedView represents a saved filter preset.
type SavedView struct {
	Value    string
	Label    string
	Selected bool
}

// TableData contains the table fragment payload.
type TableData struct {
	Rows          []TableRow
	BasePath      string
	FragmentPath  string
	RawQuery      string
	HxTarget      string
	HxSwap        string
	Error         string
	EmptyMessage  string
	Pagination    components.PaginationProps
	SelectedID    string
	SelectionName string
}

// TableRow represents a transaction row.
type TableRow struct {
	ID               string
	Selectable       bool
	Selected         bool
	DisplayID        string
	OrderNumber      string
	OrderURL         string
	CustomerName     string
	ProviderIcon     string
	ProviderLabel    string
	AmountLabel      string
	NetLabel         string
	StatusLabel      string
	StatusTone       string
	CapturedAtLabel  string
	CapturedRelative string
	RiskLabel        string
	RiskTone         string
	PSPReference     string
	PayoutBatch      string
	PayoutSchedule   string
	Channel          string
	PaymentMethod    string
	PSPDashboardURL  string
	DrawerURL        string
	Actions          []RowAction
	InputName        string
}

// RowAction renders quick action buttons.
type RowAction struct {
	Label  string
	URL    string
	NewTab bool
	Icon   string
}

// DrawerData contains the reconciliation drawer payload.
type DrawerData struct {
	Empty           bool
	TransactionID   string
	StatusLabel     string
	StatusTone      string
	ProviderLabel   string
	AmountLabel     string
	NetLabel        string
	FeeLabel        string
	OrderNumber     string
	OrderURL        string
	CustomerName    string
	Channel         string
	PaymentMethod   string
	PSPReference    string
	PSPDashboardURL string
	Timeline        []DrawerTimeline
	Breakdown       []DrawerBreakdown
	Adjustments     []DrawerAdjustment
	Disputes        []DrawerDispute
	Notes           []DrawerNote
	Payload         []DrawerPayloadField
}

// DrawerTimeline represents an event entry.
type DrawerTimeline struct {
	Timestamp   string
	Relative    string
	Label       string
	Description string
	Tone        string
	Icon        string
}

// DrawerBreakdown renders amount breakdown rows.
type DrawerBreakdown struct {
	Label string
	Value string
	Tone  string
}

// DrawerAdjustment represents adjustments applied to the transaction.
type DrawerAdjustment struct {
	Label      string
	Amount     string
	Status     string
	StatusTone string
	Actor      string
	Reason     string
	Timestamp  string
}

// DrawerDispute shows dispute information.
type DrawerDispute struct {
	Label       string
	Status      string
	StatusTone  string
	Amount      string
	ResponseDue string
	MoreInfoURL string
}

// DrawerNote renders reconciliation notes.
type DrawerNote struct {
	Author    string
	Message   string
	Timestamp string
}

// DrawerPayloadField renders raw payload entries.
type DrawerPayloadField struct {
	Key   string
	Value string
}

// BuildPageData assembles the SSR payload for the payments transactions page.
func BuildPageData(basePath string, state QueryState, result adminpayments.TransactionsResult, table TableData, drawer DrawerData, toolbar components.BulkToolbarProps) PageData {
	return PageData{
		Title:          "決済トランザクション",
		Description:    "PSP横断で決済状況を確認し、異常や返金対応を即座に行います。",
		Breadcrumbs:    []partials.Breadcrumb{{Label: "ファイナンス"}, {Label: "決済トランザクション"}},
		SummaryCards:   summaryCards(result.Summary),
		Query:          state,
		Filters:        buildFilters(state, result.Filters),
		Table:          table,
		Drawer:         drawer,
		Toolbar:        toolbar,
		TableEndpoint:  joinBase(basePath, "/payments/transactions/table"),
		DrawerEndpoint: joinBase(basePath, "/payments/transactions/drawer"),
		ExportURL:      joinBase(basePath, "/payments/transactions/export"),
		ResetURL:       joinBase(basePath, "/payments/transactions"),
		SavedViews: []SavedView{
			{Value: "", Label: "デフォルト", Selected: state.Sort == ""},
			{Value: "flagged", Label: "要調査のみ", Selected: state.Sort == "flagged"},
			{Value: "disputes", Label: "異議申し立て", Selected: state.Sort == "disputes"},
		},
	}
}

// TablePayload builds the table data.
func TablePayload(basePath string, state QueryState, result adminpayments.TransactionsResult, errMsg string) TableData {
	rows := make([]TableRow, 0, len(result.Transactions))
	for _, tx := range result.Transactions {
		rows = append(rows, toTableRow(basePath, state.RawQuery, state.SelectedID, tx))
	}

	data := TableData{
		Rows:          rows,
		BasePath:      joinBase(basePath, "/payments/transactions"),
		FragmentPath:  joinBase(basePath, "/payments/transactions/table"),
		RawQuery:      state.RawQuery,
		HxTarget:      "#payments-transactions-table",
		HxSwap:        "outerHTML",
		SelectedID:    state.SelectedID,
		SelectionName: "transactionID",
	}

	if errMsg != "" {
		data.Error = errMsg
	} else if len(rows) == 0 {
		data.EmptyMessage = "該当するトランザクションがありません。フィルタを見直してください。"
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
		Label:         "Payments transactions pagination",
	}

	return data
}

// DrawerPayload converts the transaction detail into drawer view data.
func DrawerPayload(detail adminpayments.TransactionDetail) DrawerData {
	if detail.Transaction.ID == "" {
		return DrawerData{Empty: true}
	}

	tx := detail.Transaction
	amount := helpers.Currency(tx.AmountMinor, tx.Currency)
	net := helpers.Currency(tx.NetMinor, tx.Currency)
	fee := helpers.Currency(tx.FeeMinor, tx.Currency)

	timeline := make([]DrawerTimeline, 0, len(detail.Timeline))
	for _, event := range detail.Timeline {
		timeline = append(timeline, DrawerTimeline{
			Timestamp:   helpers.Date(event.Timestamp, "2006-01-02 15:04"),
			Relative:    helpers.Relative(event.Timestamp),
			Label:       event.Label,
			Description: event.Description,
			Tone:        event.Tone,
			Icon:        event.Icon,
		})
	}

	breakdown := make([]DrawerBreakdown, 0, len(detail.Breakdown))
	for _, item := range detail.Breakdown {
		breakdown = append(breakdown, DrawerBreakdown{
			Label: item.Label,
			Value: helpers.Currency(item.AmountMinor, item.Currency),
			Tone:  item.Tone,
		})
	}

	adjustments := make([]DrawerAdjustment, 0, len(detail.Adjustments))
	for _, adj := range detail.Adjustments {
		adjustments = append(adjustments, DrawerAdjustment{
			Label:      adj.Label,
			Amount:     helpers.Currency(adj.AmountMinor, adj.Currency),
			Status:     adj.StatusLabel,
			StatusTone: adj.StatusTone,
			Actor:      adj.Actor,
			Reason:     adj.Reason,
			Timestamp:  helpers.Date(adj.Timestamp, "2006-01-02 15:04"),
		})
	}

	disputes := make([]DrawerDispute, 0, len(detail.Disputes))
	for _, dsp := range detail.Disputes {
		response := ""
		if dsp.ResponseDueAt != nil {
			response = helpers.Date(*dsp.ResponseDueAt, "2006-01-02 15:04")
		}
		disputes = append(disputes, DrawerDispute{
			Label:       dsp.ID,
			Status:      dsp.StatusLabel,
			StatusTone:  dsp.StatusTone,
			Amount:      helpers.Currency(dsp.AmountMinor, dsp.Currency),
			ResponseDue: response,
			MoreInfoURL: dsp.MoreInfoURL,
		})
	}

	notes := make([]DrawerNote, 0, len(detail.Notes))
	for _, note := range detail.Notes {
		notes = append(notes, DrawerNote{
			Author:    note.Author,
			Message:   note.Message,
			Timestamp: helpers.Date(note.Timestamp, "2006-01-02 15:04"),
		})
	}

	payload := make([]DrawerPayloadField, 0, len(detail.RawPayload))
	for _, field := range detail.RawPayload {
		payload = append(payload, DrawerPayloadField{
			Key:   field.Key,
			Value: field.Value,
		})
	}

	statusLabel := tx.StatusLabel
	if statusLabel == "" {
		statusLabel = statusLabelFor(tx.Status)
	}
	statusTone := tx.StatusTone
	if statusTone == "" {
		statusTone = statusToneFor(tx.Status)
	}

	return DrawerData{
		TransactionID:   tx.ID,
		StatusLabel:     statusLabel,
		StatusTone:      statusTone,
		ProviderLabel:   tx.ProviderLabel,
		AmountLabel:     amount,
		NetLabel:        net,
		FeeLabel:        fee,
		OrderNumber:     tx.OrderNumber,
		OrderURL:        tx.OrderURL,
		CustomerName:    tx.CustomerName,
		Channel:         channelLabel(tx.Channel),
		PaymentMethod:   tx.PaymentMethod,
		PSPReference:    tx.PSPReference,
		PSPDashboardURL: tx.PSPDashboardURL,
		Timeline:        timeline,
		Breakdown:       breakdown,
		Adjustments:     adjustments,
		Disputes:        disputes,
		Notes:           notes,
		Payload:         payload,
	}
}

// BuildQueryState normalises raw query parameters into QueryState.
func BuildQueryState(raw url.Values) QueryState {
	providers := cloneStrings(raw["provider"])
	statuses := cloneStrings(raw["status"])
	page := parseIntDefault(raw.Get("page"), 0)
	pageSize := parseIntDefault(raw.Get("pageSize"), 20)

	return QueryState{
		Providers:   providers,
		Statuses:    statuses,
		From:        strings.TrimSpace(raw.Get("from")),
		To:          strings.TrimSpace(raw.Get("to")),
		AmountMin:   strings.TrimSpace(raw.Get("amountMin")),
		AmountMax:   strings.TrimSpace(raw.Get("amountMax")),
		OnlyFlagged: raw.Get("flagged") == "1",
		Page:        page,
		PageSize:    pageSize,
		RawQuery:    raw.Encode(),
		SelectedID:  strings.TrimSpace(raw.Get("selected")),
		Sort:        strings.TrimSpace(raw.Get("view")),
	}
}

// ParseListQuery converts QueryState into service query.
func ParseListQuery(state QueryState) adminpayments.TransactionsQuery {
	return adminpayments.TransactionsQuery{
		Providers:      toProviderEnums(state.Providers),
		Statuses:       toStatusEnums(state.Statuses),
		CapturedFrom:   parseDate(state.From),
		CapturedTo:     parseDate(state.To),
		AmountMinMinor: parseAmount(state.AmountMin),
		AmountMaxMinor: parseAmount(state.AmountMax),
		OnlyFlagged:    state.OnlyFlagged,
		Page:           state.Page,
		PageSize:       state.PageSize,
		SortKey:        "",
		SortDirection:  "desc",
	}
}

func buildFilters(state QueryState, summary adminpayments.FilterSummary) Filters {
	options := make([]Option, 0, len(summary.ProviderCounts))
	for provider, count := range summary.ProviderCounts {
		options = append(options, Option{
			Value:    string(provider),
			Label:    providerLabel(provider),
			Count:    count,
			Selected: stringInSlice(string(provider), state.Providers),
		})
	}
	sort.Slice(options, func(i, j int) bool {
		return options[i].Label < options[j].Label
	})

	statusChips := make([]StatusChip, 0, len(statusOrder()))
	for _, status := range statusOrder() {
		count := summary.StatusCounts[status]
		statusChips = append(statusChips, StatusChip{
			Value:  string(status),
			Label:  statusLabelFor(status),
			Count:  count,
			Tone:   statusToneFor(status),
			Active: stringInSlice(string(status), state.Statuses),
		})
	}

	minBound := ""
	maxBound := ""
	if summary.AmountMinMinor != 0 {
		minBound = helpers.Currency(summary.AmountMinMinor, "JPY")
	}
	if summary.AmountMaxMinor != 0 {
		maxBound = helpers.Currency(summary.AmountMaxMinor, "JPY")
	}

	return Filters{
		ProviderOptions: options,
		StatusOptions:   statusChips,
		AmountHint:      "¥で指定 (例: 10000)",
		AmountMinBound:  minBound,
		AmountMaxBound:  maxBound,
		FlaggedCount:    summary.FlaggedCount,
	}
}

func summaryCards(summary adminpayments.Summary) []SummaryCard {
	cards := []SummaryCard{
		{
			Label:     "総取扱高 (今週)",
			Value:     helpers.Currency(summary.GrossVolumeMinor, summary.GrossVolumeCurrency),
			SubLabel:  fmt.Sprintf("フラグ付き %d 件", summary.FlaggedCount),
			Delta:     fmt.Sprintf("%+.1f%% vs 先週", summary.FailureRateDelta),
			DeltaTone: "neutral",
			Icon:      "💰",
		},
		{
			Label:     "失敗率",
			Value:     fmt.Sprintf("%.1f%%", summary.FailureRatePercent),
			SubLabel:  "決済成功率を維持",
			Delta:     fmt.Sprintf("%d 件異常検知", summary.DisputeOpenCount),
			DeltaTone: "warning",
			Icon:      "⚠️",
		},
		{
			Label:     "平均客単価",
			Value:     helpers.Currency(summary.AverageTicketMinor, summary.AverageTicketCurrency),
			SubLabel:  "ギフトの季節性を注視",
			Delta:     "",
			DeltaTone: "neutral",
			Icon:      "🧾",
		},
	}
	return cards
}

func toTableRow(basePath, rawQuery, selectedID string, tx adminpayments.Transaction) TableRow {
	statusLabel := tx.StatusLabel
	if statusLabel == "" {
		statusLabel = statusLabelFor(tx.Status)
	}
	statusTone := tx.StatusTone
	if statusTone == "" {
		statusTone = statusToneFor(tx.Status)
	}

	actions := []RowAction{
		{
			Label: "注文を見る",
			URL:   tx.OrderURL,
			Icon:  "📦",
		},
	}
	if strings.TrimSpace(tx.PSPDashboardURL) != "" {
		actions = append(actions, RowAction{
			Label:  "PSPで開く",
			URL:    tx.PSPDashboardURL,
			NewTab: true,
			Icon:   "↗",
		})
	}

	return TableRow{
		ID:               tx.ID,
		Selectable:       true,
		Selected:         selectedID == tx.ID,
		DisplayID:        tx.PSPReference,
		OrderNumber:      tx.OrderNumber,
		OrderURL:         tx.OrderURL,
		CustomerName:     tx.CustomerName,
		ProviderIcon:     tx.ProviderIcon,
		ProviderLabel:    tx.ProviderLabel,
		AmountLabel:      helpers.Currency(tx.AmountMinor, tx.Currency),
		NetLabel:         helpers.Currency(tx.NetMinor, tx.Currency),
		StatusLabel:      statusLabel,
		StatusTone:       statusTone,
		CapturedAtLabel:  helpers.Date(tx.CapturedAt, "2006-01-02 15:04"),
		CapturedRelative: helpers.Relative(tx.CapturedAt),
		RiskLabel:        tx.RiskLabel,
		RiskTone:         tx.RiskTone,
		PSPReference:     tx.PSPReference,
		PayoutBatch:      tx.PayoutBatchID,
		PayoutSchedule:   payoutSchedule(tx),
		Channel:          channelLabel(tx.Channel),
		PaymentMethod:    tx.PaymentMethod,
		PSPDashboardURL:  tx.PSPDashboardURL,
		DrawerURL:        helpers.BuildURL(joinBase(basePath, "/payments/transactions/drawer"), helpers.SetRawQuery(rawQuery, "selected", tx.ID)),
		Actions:          actions,
		InputName:        "transactionID",
	}
}

func payoutSchedule(tx adminpayments.Transaction) string {
	if tx.PayoutScheduledAt != nil {
		return helpers.Date(*tx.PayoutScheduledAt, "2006-01-02")
	}
	return "-"
}

func toProviderEnums(values []string) []adminpayments.Provider {
	if len(values) == 0 {
		return nil
	}
	out := make([]adminpayments.Provider, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		out = append(out, adminpayments.Provider(value))
	}
	return out
}

func toStatusEnums(values []string) []adminpayments.Status {
	if len(values) == 0 {
		return nil
	}
	out := make([]adminpayments.Status, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		out = append(out, adminpayments.Status(value))
	}
	return out
}

func parseDate(raw string) *time.Time {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	layouts := []string{"2006-01-02", time.RFC3339}
	for _, layout := range layouts {
		if ts, err := time.Parse(layout, raw); err == nil {
			return &ts
		}
	}
	return nil
}

func parseAmount(raw string) *int64 {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	value, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return nil
	}
	// Treat value as yen major units, convert to minor (x100).
	minor := value * 100
	return &minor
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

func providerLabel(provider adminpayments.Provider) string {
	switch provider {
	case adminpayments.ProviderStripe:
		return "Stripe"
	case adminpayments.ProviderSquare:
		return "Square"
	case adminpayments.ProviderAirpay:
		return "AirPay"
	case adminpayments.ProviderZeus:
		return "ZEUS"
	default:
		if provider == "" {
			return "その他"
		}
		return string(provider)
	}
}

func statusOrder() []adminpayments.Status {
	return []adminpayments.Status{
		adminpayments.StatusSettled,
		adminpayments.StatusCaptured,
		adminpayments.StatusAuthorized,
		adminpayments.StatusRefunded,
		adminpayments.StatusDisputed,
		adminpayments.StatusFailed,
	}
}

func statusLabelFor(status adminpayments.Status) string {
	switch status {
	case adminpayments.StatusSettled:
		return "入金済み"
	case adminpayments.StatusCaptured:
		return "確定済み"
	case adminpayments.StatusAuthorized:
		return "仮売上"
	case adminpayments.StatusRefunded:
		return "返金済み"
	case adminpayments.StatusDisputed:
		return "異議申し立て"
	case adminpayments.StatusFailed:
		return "失敗"
	default:
		return string(status)
	}
}

func statusToneFor(status adminpayments.Status) string {
	switch status {
	case adminpayments.StatusSettled:
		return "success"
	case adminpayments.StatusCaptured, adminpayments.StatusAuthorized:
		return "info"
	case adminpayments.StatusRefunded:
		return "warning"
	case adminpayments.StatusDisputed, adminpayments.StatusFailed:
		return "danger"
	default:
		return "neutral"
	}
}

func channelLabel(channel string) string {
	switch strings.TrimSpace(channel) {
	case "web":
		return "オンラインストア"
	case "store":
		return "店舗"
	case "customer-support":
		return "サポート"
	case "app":
		return "アプリ"
	default:
		if channel == "" {
			return "-"
		}
		return channel
	}
}

func stringInSlice(value string, values []string) bool {
	for _, v := range values {
		if v == value {
			return true
		}
	}
	return false
}
