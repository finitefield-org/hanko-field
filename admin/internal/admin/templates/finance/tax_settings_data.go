package finance

import (
	"fmt"
	"net/url"
	"sort"
	"strings"
	"time"

	adminfinance "finitefield.org/hanko-admin/internal/admin/finance"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

const (
	GridContainerID     = "tax-settings-grid"
	ContentContainerID  = "tax-settings-content"
	TableContainerID    = "tax-settings-table"
	DetailContainerID   = "tax-settings-detail"
	HistoryContainerID  = "tax-settings-history"
	DefaultDateLayout   = "2006/01/02"
	snackbarToneSuccess = "success"
	snackbarToneDanger  = "danger"
)

// PageData encapsulates the SSR payload for the tax settings page.
type PageData struct {
	Title       string
	Description string
	Breadcrumbs []partials.Breadcrumb
	Header      HeaderData
	Content     ContentData
	Snackbar    *SnackbarView
}

// HeaderData renders the page header metrics and reference links.
type HeaderData struct {
	Metrics     []HeaderMetric
	PolicyLinks []HeaderLink
	Alerts      []AlertView
	LastSynced  string
}

// HeaderMetric represents a single headline metric.
type HeaderMetric struct {
	Label    string
	Value    string
	SubLabel string
	Tone     string
}

// HeaderLink presents a quick link to reference documentation.
type HeaderLink struct {
	Label string
	Href  string
}

// SnackbarView renders the transient notification.
type SnackbarView struct {
	Message string
	Tone    string
}

// ContentData captures the interactive area rendered inside the htmx target.
type ContentData struct {
	Navigation NavigationData
	Table      JurisdictionTableData
	Detail     JurisdictionDetailData
	History    AuditSectionData
	Query      QueryState
}

// NavigationData powers the left navigation list and search box.
type NavigationData struct {
	ActionURL         string
	SearchValue       string
	SearchPlaceholder string
	IncludeSoon       bool
	Regions           []RegionNavGroup
}

// RegionNavGroup groups countries under a region heading.
type RegionNavGroup struct {
	Label string
	Count int
	Items []CountryNavItem
}

// CountryNavItem represents a single jurisdiction in the navigation list.
type CountryNavItem struct {
	ID           string
	Label        string
	Code         string
	Active       bool
	Pending      bool
	Registration string
	Selected     bool
	Href         string
	HXGet        string
	HXTarget     string
	HXSwap       string
}

// JurisdictionTableData describes the jurisdiction summary table.
type JurisdictionTableData struct {
	Rows         []JurisdictionRow
	Endpoint     string
	SelectedID   string
	EmptyMessage string
	Error        string
	Query        QueryState
	HXTarget     string
	HXSwap       string
}

// JurisdictionRow renders a single jurisdiction in the table.
type JurisdictionRow struct {
	ID             string
	Country        string
	Region         string
	Code           string
	StatusLabel    string
	StatusTone     string
	DefaultRate    string
	ReducedRate    string
	ThresholdLabel string
	EffectiveLabel string
	UpdatedLabel   string
	Registration   string
	Selected       bool
	SelectURL      string
	HXGet          string
}

// JurisdictionDetailData renders the jurisdiction detail panel.
type JurisdictionDetailData struct {
	Empty           bool
	Title           string
	Region          string
	Code            string
	Currency        string
	DefaultRate     string
	ReducedRate     string
	UpdatedAt       string
	UpdatedRelative string
	Notes           []string
	Alerts          []AlertView
	Rules           RuleSectionData
}

// RuleSectionData renders the rules table and actions.
type RuleSectionData struct {
	NewRuleURL string
	Table      RuleTableData
}

// RuleTableData lists rule rows.
type RuleTableData struct {
	Rows         []RuleRow
	EmptyMessage string
}

// RuleRow represents a single rule row inside the detail panel.
type RuleRow struct {
	ID           string
	Label        string
	Scope        string
	Rate         string
	Threshold    string
	Effective    string
	Status       string
	StatusTone   string
	Registration string
	Updated      string
	EditURL      string
	DeleteURL    string
}

// AuditSectionData renders the history timeline.
type AuditSectionData struct {
	Events []AuditEventView
}

// AuditEventView renders a single audit event.
type AuditEventView struct {
	ID        string
	Timestamp string
	Relative  string
	Actor     string
	Action    string
	Details   string
	Tone      string
}

// AlertView renders inline alerts.
type AlertView struct {
	Tone   string
	Title  string
	Body   string
	Action *AlertActionView
}

// AlertActionView renders the CTA inside an alert.
type AlertActionView struct {
	Label string
	Href  string
}

// RuleFormData powers the new/edit rule modal.
type RuleFormData struct {
	Title        string
	Description  string
	ActionURL    string
	Method       string
	SubmitLabel  string
	CSRFToken    string
	Jurisdiction string
	ReturnQuery  string
	Fields       RuleFormState
	FieldErrors  map[string]string
	GeneralError string
}

// RuleFormState mirrors the form inputs for a tax rule.
type RuleFormState struct {
	RuleID               string
	Label                string
	Scope                string
	Type                 string
	Rate                 string
	Threshold            string
	Currency             string
	EffectiveFrom        string
	EffectiveTo          string
	RegistrationNumber   string
	RequiresRegistration bool
	Default              bool
	Notes                string
}

// RuleDeleteModalData powers the delete confirmation modal.
type RuleDeleteModalData struct {
	Title       string
	Description string
	ActionURL   string
	Method      string
	SubmitLabel string
	CancelLabel string
	CSRFToken   string
	RuleLabel   string
	Effective   string
	Rate        string
	Error       string
	ReturnQuery string
}

// QueryState mirrors the active query parameters.
type QueryState struct {
	Region      string
	Country     string
	Search      string
	SelectedID  string
	IncludeSoon bool
	RawQuery    string
}

// Encode serialises the query into a URL encoded string.
func (q QueryState) Encode() string {
	values := url.Values{}
	if strings.TrimSpace(q.Region) != "" {
		values.Set("region", q.Region)
	}
	if strings.TrimSpace(q.Country) != "" {
		values.Set("country", q.Country)
	}
	if strings.TrimSpace(q.Search) != "" {
		values.Set("search", q.Search)
	}
	if strings.TrimSpace(q.SelectedID) != "" {
		values.Set("selected", q.SelectedID)
	}
	if q.IncludeSoon {
		values.Set("includeSoon", "true")
	}
	return values.Encode()
}

// WithSelected returns a copy of the query with the selected ID updated.
func (q QueryState) WithSelected(id string) QueryState {
	next := q
	next.SelectedID = strings.TrimSpace(id)
	next.RawQuery = next.Encode()
	return next
}

// WithSearch returns a copy of the query with the search term updated.
func (q QueryState) WithSearch(term string) QueryState {
	next := q
	next.Search = strings.TrimSpace(term)
	next.RawQuery = next.Encode()
	return next
}

// BuildPageData builds the full SSR payload.
func BuildPageData(basePath string, result adminfinance.JurisdictionsResult, detail *adminfinance.JurisdictionDetail, query QueryState, snackbar *SnackbarView) PageData {
	content := BuildContentData(basePath, result, detail, query)

	header := buildHeaderData(result)

	return PageData{
		Title:       "税設定",
		Description: "地域別の税率と登録番号を管理します。",
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "ファイナンス", Href: join(basePath, "/payments/transactions")},
			{Label: "税設定", Href: join(basePath, "/finance/taxes")},
		},
		Header:   header,
		Content:  content,
		Snackbar: snackbar,
	}
}

// BuildContentData constructs the htmx fragment payload containing nav, table, and detail.
func BuildContentData(basePath string, result adminfinance.JurisdictionsResult, detail *adminfinance.JurisdictionDetail, query QueryState) ContentData {
	nav := buildNavigationData(basePath, result, query)
	table := buildTableData(basePath, result, query)
	detailView := buildDetailData(basePath, detail)
	history := buildHistoryData(detail)

	return ContentData{
		Navigation: nav,
		Table:      table,
		Detail:     detailView,
		History:    history,
		Query:      query,
	}
}

func buildHeaderData(result adminfinance.JurisdictionsResult) HeaderData {
	metrics := []HeaderMetric{
		{
			Label: "運用中の地域",
			Value: fmt.Sprintf("%d", result.Summary.ActiveJurisdictions),
			Tone:  "success",
		},
		{
			Label: "更新予定",
			Value: fmt.Sprintf("%d", result.Summary.PendingJurisdictions),
			Tone:  "warning",
		},
		{
			Label: "登録番号要対応",
			Value: fmt.Sprintf("%d", result.Summary.RegistrationsRequired),
			Tone:  "info",
		},
	}

	policyLinks := make([]HeaderLink, 0, len(result.PolicyLinks))
	for _, link := range result.PolicyLinks {
		policyLinks = append(policyLinks, HeaderLink{
			Label: link.Label,
			Href:  link.Href,
		})
	}

	alerts := convertAlerts(result.Alerts)

	lastSynced := ""
	if !result.Summary.LastSyncedAt.IsZero() {
		lastSynced = helpers.Date(result.Summary.LastSyncedAt, "2006/01/02 15:04")
	}

	return HeaderData{
		Metrics:     metrics,
		PolicyLinks: policyLinks,
		Alerts:      alerts,
		LastSynced:  lastSynced,
	}
}

func buildNavigationData(basePath string, result adminfinance.JurisdictionsResult, query QueryState) NavigationData {
	groups := make([]RegionNavGroup, 0, len(result.Regions))
	for _, region := range result.Regions {
		items := make([]CountryNavItem, 0, len(region.Countries))
		for _, country := range region.Countries {
			targetQuery := query.WithSelected(country.ID)
			href := join(basePath, "/finance/taxes")
			hxGet := join(basePath, "/finance/taxes/grid")
			if encoded := targetQuery.Encode(); encoded != "" {
				href = href + "?" + encoded
				hxGet = hxGet + "?" + encoded
			}
			items = append(items, CountryNavItem{
				ID:           country.ID,
				Label:        country.Label,
				Code:         country.Code,
				Active:       country.Active,
				Pending:      country.PendingChanges,
				Registration: country.RegistrationTag,
				Selected:     country.Selected,
				Href:         href,
				HXGet:        hxGet,
				HXTarget:     "#" + GridContainerID,
				HXSwap:       "outerHTML",
			})
		}
		groups = append(groups, RegionNavGroup{
			Label: region.Label,
			Count: region.Count,
			Items: items,
		})
	}

	return NavigationData{
		ActionURL:         join(basePath, "/finance/taxes/grid"),
		SearchValue:       query.Search,
		SearchPlaceholder: "国名・コード・メモで検索",
		IncludeSoon:       query.IncludeSoon,
		Regions:           groups,
	}
}

func buildTableData(basePath string, result adminfinance.JurisdictionsResult, query QueryState) JurisdictionTableData {
	rows := make([]JurisdictionRow, 0, len(result.Jurisdictions))
	for _, item := range result.Jurisdictions {
		rowQuery := query.WithSelected(item.ID)
		target := join(basePath, "/finance/taxes/grid")
		hxGet := target
		if encoded := rowQuery.Encode(); encoded != "" {
			hxGet = hxGet + "?" + encoded
		}
		rows = append(rows, JurisdictionRow{
			ID:             item.ID,
			Country:        item.Country,
			Region:         item.Region,
			Code:           item.Code,
			StatusLabel:    item.Status,
			StatusTone:     item.StatusTone,
			DefaultRate:    formatPercent(item.DefaultRate),
			ReducedRate:    formatOptionalPercent(item.ReducedRate),
			ThresholdLabel: formatThreshold(item.ThresholdMinor, item.ThresholdCurrency),
			EffectiveLabel: formatPeriod(item.EffectiveFrom, item.EffectiveTo),
			UpdatedLabel:   formatUpdated(item.LastUpdatedAt, item.LastUpdatedBy),
			Registration:   item.RegistrationName,
			Selected:       strings.EqualFold(query.SelectedID, item.ID),
			SelectURL:      buildSelectURL(basePath, rowQuery),
			HXGet:          hxGet,
		})
	}

	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Region == rows[j].Region {
			return compare(rows[i].Country, rows[j].Country) < 0
		}
		return compare(rows[i].Region, rows[j].Region) < 0
	})

	return JurisdictionTableData{
		Rows:         rows,
		Endpoint:     join(basePath, "/finance/taxes/grid"),
		SelectedID:   query.SelectedID,
		EmptyMessage: "表示できる税率がありません。検索条件を見直してください。",
		HXTarget:     "#" + GridContainerID,
		HXSwap:       "outerHTML",
		Query:        query,
	}
}

func buildDetailData(basePath string, detail *adminfinance.JurisdictionDetail) JurisdictionDetailData {
	if detail == nil {
		return JurisdictionDetailData{
			Empty: true,
			Title: "地域を選択すると詳細が表示されます。",
		}
	}

	defaultRate := formatPercent(detail.Metadata.DefaultRate)
	reducedRate := ""
	if detail.Metadata.ReducedRate != nil {
		reducedRate = formatPercent(*detail.Metadata.ReducedRate)
	}

	notes := append([]string(nil), detail.Metadata.Notes...)

	alerts := convertAlerts(detail.Alerts)

	ruleTable := buildRuleTable(basePath, detail)

	return JurisdictionDetailData{
		Empty:           false,
		Title:           detail.Metadata.Country,
		Region:          detail.Metadata.Region,
		Code:            detail.Metadata.Code,
		Currency:        detail.Metadata.Currency,
		DefaultRate:     defaultRate,
		ReducedRate:     reducedRate,
		UpdatedAt:       formatTime(detail.Metadata.UpdatedAt),
		UpdatedRelative: helpers.Relative(detail.Metadata.UpdatedAt),
		Notes:           notes,
		Alerts:          alerts,
		Rules: RuleSectionData{
			NewRuleURL: join(basePath, fmt.Sprintf("/finance/taxes/jurisdictions/%s/modal/new", detail.Metadata.ID)),
			Table:      ruleTable,
		},
	}
}

func buildRuleTable(basePath string, detail *adminfinance.JurisdictionDetail) RuleTableData {
	rows := make([]RuleRow, 0, len(detail.Rules))
	for _, rule := range detail.Rules {
		rows = append(rows, RuleRow{
			ID:           rule.ID,
			Label:        safeLabel(rule.Label, rule.ScopeLabel),
			Scope:        rule.ScopeLabel,
			Rate:         formatPercent(rule.RatePercent),
			Threshold:    formatThreshold(rule.ThresholdMinor, rule.ThresholdCurrency),
			Effective:    formatPeriod(rule.EffectiveFrom, rule.EffectiveTo),
			Status:       rule.Status,
			StatusTone:   rule.StatusTone,
			Registration: rule.RegistrationNumber,
			Updated:      formatUpdated(rule.UpdatedAt, rule.UpdatedBy),
			EditURL:      join(basePath, fmt.Sprintf("/finance/taxes/jurisdictions/%s/modal/edit?rule=%s", detail.Metadata.ID, url.QueryEscape(rule.ID))),
			DeleteURL:    join(basePath, fmt.Sprintf("/finance/taxes/jurisdictions/%s/modal/delete?rule=%s", detail.Metadata.ID, url.QueryEscape(rule.ID))),
		})
	}

	return RuleTableData{
		Rows:         rows,
		EmptyMessage: "まだ税率が登録されていません。",
	}
}

func buildHistoryData(detail *adminfinance.JurisdictionDetail) AuditSectionData {
	if detail == nil {
		return AuditSectionData{}
	}
	events := make([]AuditEventView, 0, len(detail.History))
	for _, event := range detail.History {
		events = append(events, AuditEventView{
			ID:        event.ID,
			Timestamp: formatTime(event.Timestamp),
			Relative:  helpers.Relative(event.Timestamp),
			Actor:     event.Actor,
			Action:    event.Action,
			Details:   event.Details,
			Tone:      event.Tone,
		})
	}
	return AuditSectionData{Events: events}
}

func convertAlerts(alerts []adminfinance.Alert) []AlertView {
	if len(alerts) == 0 {
		return nil
	}
	out := make([]AlertView, 0, len(alerts))
	for _, alert := range alerts {
		item := AlertView{
			Tone:  alert.Tone,
			Title: alert.Title,
			Body:  alert.Body,
		}
		if alert.Action != nil {
			item.Action = &AlertActionView{
				Label: alert.Action.Label,
				Href:  alert.Action.Href,
			}
		}
		out = append(out, item)
	}
	return out
}

// DefaultRuleFormState returns the initial state for the rule form.
func DefaultRuleFormState(detail adminfinance.JurisdictionDetail, rule *adminfinance.TaxRule) RuleFormState {
	state := RuleFormState{
		Currency:             detail.Metadata.Currency,
		Default:              false,
		Scope:                "standard",
		Type:                 "consumption",
		RequiresRegistration: detail.Metadata.RegistrationID != "",
	}
	if rule != nil {
		state.RuleID = rule.ID
		state.Label = rule.Label
		state.Scope = rule.Scope
		state.Type = rule.Type
		state.Rate = fmt.Sprintf("%.2f", rule.RatePercent)
		state.Threshold = fmt.Sprintf("%d", rule.ThresholdMinor)
		state.Currency = rule.ThresholdCurrency
		state.EffectiveFrom = rule.EffectiveFrom.Format("2006-01-02")
		if rule.EffectiveTo != nil {
			state.EffectiveTo = rule.EffectiveTo.Format("2006-01-02")
		}
		state.RegistrationNumber = rule.RegistrationNumber
		state.RequiresRegistration = rule.RequiresRegistration
		state.Default = rule.Default
		state.Notes = strings.Join(rule.Notes, "\n")
	}
	return state
}

// BuildRuleFormData constructs the new/edit rule modal payload.
func BuildRuleFormData(basePath string, detail adminfinance.JurisdictionDetail, rule *adminfinance.TaxRule, csrf string, state RuleFormState, returnQuery string, fieldErrors map[string]string, generalErr string) RuleFormData {
	action := join(basePath, fmt.Sprintf("/finance/taxes/jurisdictions/%s/rules", detail.Metadata.ID))
	method := "post"
	title := "税率を追加"
	submit := "保存する"
	if rule != nil {
		action = join(basePath, fmt.Sprintf("/finance/taxes/jurisdictions/%s/rules/%s", detail.Metadata.ID, url.PathEscape(rule.ID)))
		method = "put"
		title = "税率を編集"
		submit = "更新する"
	}

	fields := state
	if fields.EffectiveFrom == "" {
		fields.EffectiveFrom = time.Now().Format("2006-01-02")
	}
	if fields.Currency == "" {
		fields.Currency = detail.Metadata.Currency
	}

	return RuleFormData{
		Title:        title,
		Description:  fmt.Sprintf("%s (%s) の税率を設定します。", detail.Metadata.Country, detail.Metadata.Code),
		ActionURL:    action,
		Method:       method,
		SubmitLabel:  submit,
		CSRFToken:    csrf,
		Jurisdiction: detail.Metadata.Country,
		ReturnQuery:  returnQuery,
		Fields:       fields,
		FieldErrors:  fieldErrors,
		GeneralError: generalErr,
	}
}

// BuildRuleDeleteModalData constructs the delete confirmation modal payload.
func BuildRuleDeleteModalData(basePath string, detail adminfinance.JurisdictionDetail, rule adminfinance.TaxRule, csrf string, returnQuery string, generalErr string) RuleDeleteModalData {
	return RuleDeleteModalData{
		Title:       "税率を削除",
		Description: fmt.Sprintf("%s (%s) の税率を削除します。元に戻せません。", detail.Metadata.Country, detail.Metadata.Code),
		ActionURL:   join(basePath, fmt.Sprintf("/finance/taxes/jurisdictions/%s/rules/%s", detail.Metadata.ID, url.PathEscape(rule.ID))),
		Method:      "delete",
		SubmitLabel: "削除する",
		CancelLabel: "キャンセル",
		CSRFToken:   csrf,
		RuleLabel:   safeLabel(rule.Label, rule.ScopeLabel),
		Effective:   formatPeriod(rule.EffectiveFrom, rule.EffectiveTo),
		Rate:        formatPercent(rule.RatePercent),
		Error:       generalErr,
		ReturnQuery: returnQuery,
	}
}

func formatPercent(value float64) string {
	return fmt.Sprintf("%.2f%%", value)
}

func formatOptionalPercent(value *float64) string {
	if value == nil {
		return "-"
	}
	return formatPercent(*value)
}

func formatThreshold(amount int64, currency string) string {
	if amount == 0 {
		return "なし"
	}
	return helpers.Currency(amount, currency)
}

func formatPeriod(from time.Time, to *time.Time) string {
	start := formatTime(from)
	if to == nil || to.IsZero() {
		return fmt.Sprintf("%s 〜", start)
	}
	return fmt.Sprintf("%s 〜 %s", start, formatTime(*to))
}

func formatTime(ts time.Time) string {
	if ts.IsZero() {
		return "-"
	}
	return ts.In(time.Local).Format(DefaultDateLayout)
}

func formatUpdated(ts time.Time, actor string) string {
	if ts.IsZero() {
		return "-"
	}
	label := ts.In(time.Local).Format("2006/01/02 15:04")
	if strings.TrimSpace(actor) != "" {
		return fmt.Sprintf("%s · %s", label, actor)
	}
	return label
}

func safeLabel(label, fallback string) string {
	if strings.TrimSpace(label) != "" {
		return label
	}
	if strings.TrimSpace(fallback) != "" {
		return fallback
	}
	return "名称未設定"
}

func join(basePath, suffix string) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/"
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	if base == "/" {
		return suffix
	}
	return strings.TrimRight(base, "/") + suffix
}

func buildSelectURL(basePath string, query QueryState) string {
	url := join(basePath, "/finance/taxes")
	if encoded := query.Encode(); encoded != "" {
		return url + "?" + encoded
	}
	return url
}

func compare(a, b string) int {
	return strings.Compare(strings.ToLower(a), strings.ToLower(b))
}
