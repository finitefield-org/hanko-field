package customers

import (
	"context"
	"fmt"
	"strings"
	"time"

	templ "github.com/a-h/templ"

	admincustomers "finitefield.org/hanko-admin/internal/admin/customers"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// DetailPageData represents the payload used to render the customer detail page.
type DetailPageData struct {
	Title        string
	Description  string
	Breadcrumbs  []partials.Breadcrumb
	CustomerID   string
	ActiveTab    string
	RefreshURL   string
	Tabs         []DetailTab
	Header       DetailHeader
	Metrics      []DetailMetricCard
	Overview     OverviewTabData
	Orders       OrdersTabData
	Addresses    AddressesTabData
	Payments     PaymentsTabData
	Notes        NotesTabData
	Activity     ActivityTabData
	InfoRail     InfoRailData
	LastUpdated  string
	LastRelative string
}

// DetailTab describes each tab in the underline tab set.
type DetailTab struct {
	ID     string
	Label  string
	Href   string
	Active bool
	Badge  string
}

// DetailHeader summarises key profile information.
type DetailHeader struct {
	DisplayName      string
	Email            string
	Phone            string
	Company          string
	Location         string
	CustomerID       string
	StatusLabel      string
	StatusTone       string
	TierLabel        string
	TierTone         string
	RiskLabel        string
	RiskTone         string
	RiskDescription  string
	JoinedLabel      string
	LastOrderLabel   string
	AvatarURL        string
	AvatarInitial    string
	QuickActions     []QuickActionButton
	Flags            []BadgeView
	Tags             []string
	TotalOrdersLabel string
	LTVLabel         string
}

// QuickActionButton renders header quick action buttons.
type QuickActionButton struct {
	Label   string
	Href    string
	Variant string
	Icon    string
	Method  string
	Modal   bool
	Attrs   templ.Attributes
}

// DetailMetricCard renders a KPI card in the metrics row.
type DetailMetricCard struct {
	Label      string
	Value      string
	SubLabel   string
	Tone       string
	TrendLabel string
	TrendTone  string
	TrendIcon  string
}

// OverviewTabData powers the overview tab content.
type OverviewTabData struct {
	Summary      []OverviewField
	Flags        []BadgeView
	Tags         []string
	RecentOrders []OverviewOrderCard
}

// OverviewField renders key-value fields.
type OverviewField struct {
	Label string
	Value string
	Href  string
}

// OverviewOrderCard summarises a recent order.
type OverviewOrderCard struct {
	ID          string
	Number      string
	Status      string
	StatusTone  string
	Total       string
	PlacedDate  string
	Detail      string
	Href        string
	Payment     string
	Fulfillment string
}

// OrdersTabData powers the orders tab.
type OrdersTabData struct {
	Rows         []OrderRow
	EmptyMessage string
}

// OrderRow renders a table row for an order.
type OrderRow struct {
	ID              string
	Number          string
	Date            string
	Relative        string
	Status          string
	StatusTone      string
	Fulfillment     string
	FulfillmentTone string
	Payment         string
	PaymentTone     string
	Total           string
	Href            string
}

// AddressesTabData powers the addresses tab.
type AddressesTabData struct {
	Cards        []AddressCard
	EmptyMessage string
}

// AddressCard renders address information cards.
type AddressCard struct {
	Title     string
	TypeLabel string
	TypeTone  string
	Name      string
	Company   string
	Phone     string
	Lines     []string
	Updated   string
	Notes     []string
	Primary   bool
}

// PaymentsTabData powers the payment methods tab.
type PaymentsTabData struct {
	Rows         []PaymentRow
	EmptyMessage string
}

// PaymentRow renders a payment method row.
type PaymentRow struct {
	ID         string
	Type       string
	Brand      string
	Last4      string
	Expires    string
	Status     string
	StatusTone string
	Added      string
	Primary    bool
	Holder     string
}

// NotesTabData powers the support notes tab.
type NotesTabData struct {
	Notes        []SupportNoteCard
	EmptyMessage string
}

// SupportNoteCard renders a support note entry.
type SupportNoteCard struct {
	Title      string
	Body       string
	Tone       string
	Author     string
	Created    string
	Relative   string
	Tags       []string
	Visibility string
}

// ActivityTabData powers the activity tab.
type ActivityTabData struct {
	Items        []ActivityItemView
	EmptyMessage string
}

// ActivityItemView renders timeline events.
type ActivityItemView struct {
	Title       string
	Actor       string
	ActorRole   string
	Description string
	Tone        string
	Icon        string
	Time        string
	Relative    string
}

// InfoRailData powers the right-hand contextual column.
type InfoRailData struct {
	RiskLabel       string
	RiskTone        string
	RiskDescription string
	Segments        []string
	Flags           []BadgeView
	Sections        []InfoRailSection
}

// InfoRailSection renders grouped items in the info rail.
type InfoRailSection struct {
	Title string
	Items []InfoRailItem
}

// InfoRailItem renders individual entries in the info rail.
type InfoRailItem struct {
	Label       string
	Description string
	Meta        string
	Tone        string
	LinkLabel   string
	LinkURL     string
}

// BuildDetailPageData assembles the detail page payload.
func BuildDetailPageData(ctx context.Context, basePath string, detail admincustomers.Detail, activeTab string) DetailPageData {
	formatter := helpers.NewFormatter(ctx)
	tab := strings.TrimSpace(strings.ToLower(activeTab))
	if tab == "" {
		tab = "overview"
	}

	profile := detail.Profile
	displayName := strings.TrimSpace(profile.DisplayName)
	if displayName == "" {
		displayName = profile.Email
	}
	if displayName == "" {
		displayName = profile.ID
	}

	title := fmt.Sprintf("%s | 顧客詳細", displayName)
	description := "注文履歴、支払い方法、サポートノートを確認できます。"

	breadcrumbs := []partials.Breadcrumb{
		{Label: formatter.T("admin.customers.breadcrumb"), Href: joinBase(basePath, "/customers")},
		{Label: displayName},
	}

	tabBase := joinBase(basePath, fmt.Sprintf("/customers/%s", profile.ID))
	refreshURL := tabBase
	if tab != "" && tab != "overview" {
		refreshURL = tabBase + "?tab=" + tab
	}
	tabs := []DetailTab{
		{ID: "overview", Label: "概要", Href: tabBase, Active: tab == "overview"},
		{ID: "orders", Label: "注文", Href: tabBase + "?tab=orders", Active: tab == "orders", Badge: fmt.Sprintf("%d", profile.TotalOrders)},
		{ID: "addresses", Label: "住所", Href: tabBase + "?tab=addresses", Active: tab == "addresses", Badge: fmt.Sprintf("%d", len(detail.Addresses))},
		{ID: "payments", Label: "支払い方法", Href: tabBase + "?tab=payments", Active: tab == "payments", Badge: fmt.Sprintf("%d", len(detail.PaymentMethods))},
		{ID: "notes", Label: "サポートメモ", Href: tabBase + "?tab=notes", Active: tab == "notes", Badge: fmt.Sprintf("%d", len(detail.SupportNotes))},
		{ID: "activity", Label: "アクティビティ", Href: tabBase + "?tab=activity", Active: tab == "activity", Badge: fmt.Sprintf("%d", len(detail.Activity))},
	}

	header := DetailHeader{
		DisplayName:      displayName,
		Email:            profile.Email,
		Phone:            profile.Phone,
		Company:          profile.Company,
		Location:         profile.Location,
		CustomerID:       profile.ID,
		StatusLabel:      statusLabel(formatter, profile.Status),
		StatusTone:       statusTone(profile.Status),
		TierLabel:        tierLabel(formatter, profile.Tier),
		TierTone:         tierTone(profile.Tier),
		RiskLabel:        riskLabel(formatter, profile.RiskLevel),
		RiskTone:         riskTone(profile.RiskLevel),
		RiskDescription:  detail.InfoRail.RiskDescription,
		JoinedLabel:      formatDate(profile.JoinedAt, "2006-01-02"),
		LastOrderLabel:   formatDate(profile.LastOrderAt, "2006-01-02 15:04"),
		AvatarURL:        profile.AvatarURL,
		AvatarInitial:    avatarInitial(displayName, profile.Email, profile.ID),
		QuickActions:     quickActions(profile.QuickActions),
		Flags:            toFlagBadges(profile.Flags),
		Tags:             append([]string(nil), profile.Tags...),
		TotalOrdersLabel: fmt.Sprintf("%d件", profile.TotalOrders),
		LTVLabel:         helpers.Currency(profile.LifetimeValueMinor, profile.Currency),
	}

	metrics := make([]DetailMetricCard, 0, len(detail.Metrics))
	for _, metric := range detail.Metrics {
		metrics = append(metrics, DetailMetricCard{
			Label:      metric.Label,
			Value:      metric.Value,
			SubLabel:   metric.SubLabel,
			Tone:       metric.Tone,
			TrendLabel: metric.Trend.Label,
			TrendTone:  metric.Trend.Tone,
			TrendIcon:  metric.Trend.Icon,
		})
	}

	overview := buildOverview(detail, basePath)
	orders := buildOrders(detail, basePath)
	addresses := buildAddresses(detail)
	payments := buildPayments(detail)
	notes := buildNotes(detail)
	activity := buildActivity(detail)
	infoRail := buildInfoRail(formatter, detail)

	lastUpdated := "-"
	lastRelative := ""
	if !detail.LastUpdated.IsZero() {
		lastUpdated = helpers.Date(detail.LastUpdated, "2006-01-02 15:04")
		lastRelative = helpers.Relative(detail.LastUpdated)
	}

	return DetailPageData{
		Title:        title,
		Description:  description,
		Breadcrumbs:  breadcrumbs,
		CustomerID:   profile.ID,
		ActiveTab:    tab,
		RefreshURL:   refreshURL,
		Tabs:         tabs,
		Header:       header,
		Metrics:      metrics,
		Overview:     overview,
		Orders:       orders,
		Addresses:    addresses,
		Payments:     payments,
		Notes:        notes,
		Activity:     activity,
		InfoRail:     infoRail,
		LastUpdated:  lastUpdated,
		LastRelative: lastRelative,
	}
}

func buildOverview(detail admincustomers.Detail, basePath string) OverviewTabData {
	profile := detail.Profile
	summary := []OverviewField{
		{Label: "顧客 ID", Value: profile.ID},
	}
	if strings.TrimSpace(profile.Company) != "" {
		summary = append(summary, OverviewField{Label: "会社名", Value: profile.Company})
	}
	if strings.TrimSpace(profile.Location) != "" {
		summary = append(summary, OverviewField{Label: "所在地", Value: profile.Location})
	}
	if strings.TrimSpace(profile.Phone) != "" {
		summary = append(summary, OverviewField{Label: "電話番号", Value: profile.Phone})
	}
	if !profile.JoinedAt.IsZero() {
		summary = append(summary, OverviewField{Label: "初回登録", Value: formatDate(profile.JoinedAt, "2006-01-02")})
	}
	if !profile.LastOrderAt.IsZero() {
		value := formatDate(profile.LastOrderAt, "2006-01-02 15:04")
		if profile.LastOrderNumber != "" {
			value = fmt.Sprintf("%s (注文 %s)", value, profile.LastOrderNumber)
			summary = append(summary, OverviewField{
				Label: "最終注文",
				Value: value,
				Href:  joinBase(basePath, fmt.Sprintf("/orders/%s", profile.LastOrderID)),
			})
		} else {
			summary = append(summary, OverviewField{Label: "最終注文", Value: value})
		}
	}

	recent := make([]OverviewOrderCard, 0, len(detail.RecentOrders))
	for _, order := range detail.RecentOrders {
		recent = append(recent, OverviewOrderCard{
			ID:          order.ID,
			Number:      order.Number,
			Status:      order.Status,
			StatusTone:  order.StatusTone,
			Total:       helpers.Currency(order.TotalMinor, order.Currency),
			PlacedDate:  formatDate(order.PlacedAt, "2006-01-02 15:04"),
			Detail:      strings.TrimSpace(order.ItemSummary),
			Href:        joinBase(basePath, fmt.Sprintf("/orders/%s", order.ID)),
			Payment:     order.PaymentStatus,
			Fulfillment: order.FulfillmentStatus,
		})
	}

	return OverviewTabData{
		Summary:      summary,
		Flags:        toFlagBadges(profile.Flags),
		Tags:         append([]string(nil), profile.Tags...),
		RecentOrders: recent,
	}
}

func buildOrders(detail admincustomers.Detail, basePath string) OrdersTabData {
	if len(detail.RecentOrders) == 0 {
		return OrdersTabData{
			Rows:         nil,
			EmptyMessage: "表示可能な注文履歴がありません。",
		}
	}

	rows := make([]OrderRow, 0, len(detail.RecentOrders))
	for _, order := range detail.RecentOrders {
		rows = append(rows, OrderRow{
			ID:              order.ID,
			Number:          order.Number,
			Date:            formatDate(order.PlacedAt, "2006-01-02 15:04"),
			Relative:        helpers.Relative(order.PlacedAt),
			Status:          order.Status,
			StatusTone:      order.StatusTone,
			Fulfillment:     order.FulfillmentStatus,
			FulfillmentTone: order.FulfillmentTone,
			Payment:         order.PaymentStatus,
			PaymentTone:     order.PaymentTone,
			Total:           helpers.Currency(order.TotalMinor, order.Currency),
			Href:            joinBase(basePath, fmt.Sprintf("/orders/%s", order.ID)),
		})
	}

	return OrdersTabData{
		Rows: rows,
	}
}

func buildAddresses(detail admincustomers.Detail) AddressesTabData {
	if len(detail.Addresses) == 0 {
		return AddressesTabData{
			EmptyMessage: "登録された住所がありません。",
		}
	}

	cards := make([]AddressCard, 0, len(detail.Addresses))
	for _, address := range detail.Addresses {
		cards = append(cards, AddressCard{
			Title:     strings.TrimSpace(address.Label),
			TypeLabel: addressTypeLabel(address),
			TypeTone:  addressTypeTone(address),
			Name:      address.Name,
			Company:   address.Company,
			Phone:     address.Phone,
			Lines:     append([]string(nil), address.Lines...),
			Updated:   formatTimestamp(address.UpdatedAt),
			Notes:     append([]string(nil), address.Notes...),
			Primary:   address.Primary,
		})
	}

	return AddressesTabData{
		Cards: cards,
	}
}

func buildPayments(detail admincustomers.Detail) PaymentsTabData {
	if len(detail.PaymentMethods) == 0 {
		return PaymentsTabData{
			EmptyMessage: "登録された支払い方法がありません。",
		}
	}

	rows := make([]PaymentRow, 0, len(detail.PaymentMethods))
	for _, method := range detail.PaymentMethods {
		expires := ""
		if method.ExpMonth > 0 && method.ExpYear > 0 {
			expires = fmt.Sprintf("%02d/%d", method.ExpMonth, method.ExpYear)
		}
		rows = append(rows, PaymentRow{
			ID:         method.ID,
			Type:       paymentTypeLabel(method.Type),
			Brand:      strings.TrimSpace(method.Brand),
			Last4:      method.Last4,
			Expires:    expires,
			Status:     method.Status,
			StatusTone: method.StatusTone,
			Added:      formatTimestamp(method.AddedAt),
			Primary:    method.Primary,
			Holder:     method.HolderName,
		})
	}

	return PaymentsTabData{Rows: rows}
}

func buildNotes(detail admincustomers.Detail) NotesTabData {
	if len(detail.SupportNotes) == 0 {
		return NotesTabData{
			EmptyMessage: "サポートメモはまだ登録されていません。",
		}
	}

	notes := make([]SupportNoteCard, 0, len(detail.SupportNotes))
	for _, note := range detail.SupportNotes {
		notes = append(notes, SupportNoteCard{
			Title:      note.Title,
			Body:       note.Body,
			Tone:       note.Tone,
			Author:     authorDisplay(note.Author, note.AuthorRole),
			Created:    formatTimestamp(note.CreatedAt),
			Relative:   helpers.Relative(note.CreatedAt),
			Tags:       append([]string(nil), note.Tags...),
			Visibility: visibilityLabel(note.Visibility),
		})
	}

	return NotesTabData{Notes: notes}
}

func buildActivity(detail admincustomers.Detail) ActivityTabData {
	if len(detail.Activity) == 0 {
		return ActivityTabData{
			EmptyMessage: "最近のアクティビティはありません。",
		}
	}

	items := make([]ActivityItemView, 0, len(detail.Activity))
	for _, item := range detail.Activity {
		items = append(items, ActivityItemView{
			Title:       item.Title,
			Actor:       item.Actor,
			ActorRole:   item.ActorRole,
			Description: item.Description,
			Tone:        item.Tone,
			Icon:        item.Icon,
			Time:        formatTimestamp(item.Timestamp),
			Relative:    helpers.Relative(item.Timestamp),
		})
	}

	return ActivityTabData{Items: items}
}

func buildInfoRail(formatter helpers.Formatter, detail admincustomers.Detail) InfoRailData {
	rail := detail.InfoRail
	sections := []InfoRailSection{}

	if len(rail.Escalations) > 0 {
		sections = append(sections, InfoRailSection{
			Title: "エスカレーション",
			Items: railItems(rail.Escalations),
		})
	}
	if len(rail.FraudChecks) > 0 {
		sections = append(sections, InfoRailSection{
			Title: "本人確認 / リスク",
			Items: railItems(rail.FraudChecks),
		})
	}
	if len(rail.IdentityDocs) > 0 {
		sections = append(sections, InfoRailSection{
			Title: "提出書類",
			Items: railItems(rail.IdentityDocs),
		})
	}
	if len(rail.Contacts) > 0 {
		sections = append(sections, InfoRailSection{
			Title: "担当者・連絡先",
			Items: railItems(rail.Contacts),
		})
	}

	return InfoRailData{
		RiskLabel:       riskLabel(formatter, nonEmpty(rail.RiskLevel, detail.Profile.RiskLevel)),
		RiskTone:        nonEmpty(rail.RiskTone, riskTone(detail.Profile.RiskLevel)),
		RiskDescription: nonEmpty(rail.RiskDescription, "特記事項はありません。"),
		Segments:        append([]string(nil), rail.Segments...),
		Flags:           toFlagBadges(append([]admincustomers.Flag(nil), rail.Flags...)),
		Sections:        sections,
	}
}

func quickActions(actions []admincustomers.QuickAction) []QuickActionButton {
	if len(actions) == 0 {
		return nil
	}
	result := make([]QuickActionButton, 0, len(actions))
	for _, action := range actions {
		variant := strings.TrimSpace(action.Variant)
		if variant == "" {
			variant = "secondary"
		}
		href := strings.TrimSpace(action.Href)
		method := strings.TrimSpace(action.Method)
		attrs := templ.Attributes{
			"data-icon": strings.TrimSpace(action.Icon),
		}
		if method != "" {
			attrs["data-method"] = method
		}
		isModal := strings.EqualFold(method, "modal") && href != ""
		if isModal {
			attrs["hx-get"] = href
			attrs["hx-target"] = "#modal"
			attrs["hx-swap"] = "innerHTML"
		}
		result = append(result, QuickActionButton{
			Label:   action.Label,
			Href:    href,
			Variant: variant,
			Icon:    action.Icon,
			Method:  method,
			Modal:   isModal,
			Attrs:   attrs,
		})
	}
	return result
}

func railItems(items []admincustomers.RailItem) []InfoRailItem {
	result := make([]InfoRailItem, 0, len(items))
	for _, item := range items {
		meta := ""
		if !item.Timestamp.IsZero() {
			meta = formatTimestamp(item.Timestamp)
		}
		result = append(result, InfoRailItem{
			Label:       item.Label,
			Description: item.Description,
			Meta:        meta,
			Tone:        item.Tone,
			LinkLabel:   item.LinkLabel,
			LinkURL:     item.LinkURL,
		})
	}
	return result
}

func addressTypeLabel(address admincustomers.Address) string {
	switch strings.ToLower(strings.TrimSpace(address.Type)) {
	case "billing":
		return "請求先"
	case "shipping":
		return "出荷先"
	default:
		return "住所"
	}
}

func addressTypeTone(address admincustomers.Address) string {
	switch strings.ToLower(strings.TrimSpace(address.Type)) {
	case "billing":
		return "info"
	case "shipping":
		return "success"
	default:
		return "muted"
	}
}

func paymentTypeLabel(t string) string {
	switch strings.ToLower(strings.TrimSpace(t)) {
	case "card", "credit_card":
		return "クレジットカード"
	case "bank_transfer":
		return "銀行振込"
	case "konbini":
		return "コンビニ払い"
	default:
		return strings.TrimSpace(t)
	}
}

func authorDisplay(name, role string) string {
	if strings.TrimSpace(role) == "" {
		return name
	}
	return fmt.Sprintf("%s (%s)", name, role)
}

func visibilityLabel(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "public":
		return "共有メモ"
	case "private", "internal":
		return "内部メモ"
	default:
		return "メモ"
	}
}

func formatDate(ts time.Time, layout string) string {
	if ts.IsZero() {
		return "-"
	}
	return helpers.Date(ts, layout)
}

func formatTimestamp(ts time.Time) string {
	if ts.IsZero() {
		return "-"
	}
	return helpers.Date(ts, "2006-01-02 15:04")
}

func nonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func avatarInitial(name, email, fallback string) string {
	candidate := strings.TrimSpace(name)
	if candidate == "" {
		candidate = strings.TrimSpace(email)
	}
	if candidate == "" {
		candidate = strings.TrimSpace(fallback)
	}
	if candidate == "" {
		return "?"
	}
	runes := []rune(strings.ToUpper(candidate))
	return string(runes[0])
}

func trendToneClass(tone string) string {
	switch strings.ToLower(strings.TrimSpace(tone)) {
	case "success":
		return "mt-2 text-xs font-medium text-emerald-600"
	case "danger":
		return "mt-2 text-xs font-medium text-rose-600"
	case "warning":
		return "mt-2 text-xs font-medium text-amber-600"
	default:
		return "mt-2 text-xs font-medium text-slate-500"
	}
}

func noteCardClass(tone string) string {
	switch strings.ToLower(strings.TrimSpace(tone)) {
	case "danger":
		return "rounded-2xl border border-rose-200 bg-rose-50 px-5 py-5 shadow-sm"
	case "warning":
		return "rounded-2xl border border-amber-200 bg-amber-50 px-5 py-5 shadow-sm"
	case "success":
		return "rounded-2xl border border-emerald-200 bg-emerald-50 px-5 py-5 shadow-sm"
	default:
		return "rounded-2xl border border-slate-200 bg-slate-50 px-5 py-5 shadow-sm"
	}
}

func fallback(value, defaultValue string) string {
	if strings.TrimSpace(value) == "" {
		return defaultValue
	}
	return value
}
