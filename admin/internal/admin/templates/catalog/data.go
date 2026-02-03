package catalog

import (
	"fmt"
	"strings"
	"time"

	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData drives the full catalog overview page.
type PageData struct {
	Title          string
	Description    string
	Breadcrumbs    []partials.Breadcrumb
	Tabs           []components.UnderlineTab
	Kind           admincatalog.Kind
	KindLabel      string
	Query          QueryState
	Summary        SummaryData
	Filters        FilterData
	ViewToggle     ViewToggle
	Table          TableData
	Cards          CardsData
	Drawer         DrawerData
	Bulk           BulkBarData
	TableEndpoint  string
	CardsEndpoint  string
	DrawerEndpoint string
	CreateURL      string
	EmptyMessage   string
	PagePath       string
	PageURL        string
}

// EditPageData powers the catalog edit page.
type EditPageData struct {
	Title          string
	Kind           admincatalog.Kind
	KindLabel      string
	ItemID         string
	ItemName       string
	ItemIdentifier string
	StatusLabel    string
	StatusTone     string
	UpdatedLabel   string
	BackURL        string
	Form           ModalFormData
	Drawer         DrawerData
	Breadcrumbs    []partials.Breadcrumb
}

// QueryState mirrors query parameters from the HTTP request.
type QueryState struct {
	Status   []string
	Category string
	Owner    string
	Tags     []string
	Updated  string
	Search   string
	View     string
	Selected string
	RawQuery string
	Page     int
	PageSize int
	Sort     string
	SortKey  string
	SortDir  string
}

// SummaryData renders KPI chips for the current selection.
type SummaryData struct {
	TotalLabel     string
	PublishedLabel string
	ScheduledLabel string
	DraftLabel     string
	ReviewLabel    string
	LastUpdated    string
}

// FilterData hosts filter controls.
type FilterData struct {
	Statuses   []StatusFilter
	Categories []SelectOption
	Owners     []SelectOption
	Tags       []SelectOption
	Updated    []SelectOption
}

// StatusFilter models the status chip group.
type StatusFilter struct {
	Value  string
	Label  string
	Tone   string
	Count  int
	Active bool
}

// SelectOption represents a dropdown option.
type SelectOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// ViewToggle controls between table vs cards.
type ViewToggle struct {
	Active  string
	Options []ViewOption
}

// ViewOption is a single toggle.
type ViewOption struct {
	Value     string
	Label     string
	Icon      string
	Endpoint  string
	PushURL   string
	Indicator string
	Active    bool
}

// TableData powers the table fragment.
type TableData struct {
	BasePath     string
	FragmentPath string
	RawQuery     string
	FilterQuery  string
	Rows         []TableRow
	EmptyMessage string
	KindLabel    string
	SelectedID   string
	ViewParam    string
	Drawer       DrawerData
	PagePath     string
	View         ViewToggle
	Pagination   TablePagination
	Sort         SortState
}

// TableRow is a row in the catalog data table.
type TableRow struct {
	ID               string
	Name             string
	Identifier       string
	Description      string
	StatusLabel      string
	StatusTone       string
	Owner            string
	OwnerInitials    string
	UpdatedLabel     string
	UpdatedRelative  string
	UsageLabel       string
	Tags             []string
	Metrics          []RowMetric
	PreviewURL       string
	PreviewAlt       string
	Badge            string
	BadgeTone        string
	Selected         bool
	Version          string
	ScheduleLabel    string
	ScheduleRelative string
	CategoryLabel    string
	CategoryValue    string
	EditURL          string
	DeleteURL        string
}

// RowMetric highlights per-row stats.
type RowMetric struct {
	Label string
	Value string
	Icon  string
}

// CardsData powers the card grid fragment.
type CardsData struct {
	BasePath     string
	FragmentPath string
	RawQuery     string
	FilterQuery  string
	Cards        []CardView
	EmptyMessage string
	SelectedID   string
	Drawer       DrawerData
	PagePath     string
	View         ViewToggle
}

// TablePagination exposes pagination metadata for catalog listings.
type TablePagination struct {
	Page     int
	PageSize int
	Total    int
	TotalPtr *int
	Next     *int
	Prev     *int
}

// SortState configures sortable headers for the catalog table.
type SortState struct {
	Active        string
	BasePath      string
	FragmentPath  string
	RawQuery      string
	FragmentQuery string
	Param         string
	ResetPage     bool
	PageParam     string
	HxTarget      string
	HxSwap        string
	HxPushURL     bool
}

// CardView is a single card entry.
type CardView struct {
	ID               string
	Title            string
	Subtitle         string
	StatusLabel      string
	StatusTone       string
	UsageLabel       string
	Tags             []string
	Metrics          []RowMetric
	PreviewURL       string
	PreviewAlt       string
	Selected         bool
	Badge            string
	BadgeTone        string
	Version          string
	ScheduleLabel    string
	ScheduleRelative string
}

// DrawerData powers the metadata rail/drawer.
type DrawerData struct {
	ID                 string
	Kind               admincatalog.Kind
	Empty              bool
	Title              string
	StatusLabel        string
	StatusTone         string
	KindLabel          string
	Description        string
	Owner              DrawerOwner
	PreviewURL         string
	PreviewAlt         string
	Usage              []RowMetric
	Metadata           []MetadataView
	Dependencies       []DependencyView
	Audit              []AuditEntryView
	Tags               []string
	UpdatedLabel       string
	Version            string
	LastPublishedLabel string
	LastPublishedBy    string
	ScheduleLabel      string
	ScheduleRelative   string
	HasSchedule        bool
}

// DrawerOwner summarises owner info.
type DrawerOwner struct {
	Name  string
	Email string
}

// MetadataView is a key/value row.
type MetadataView struct {
	Key   string
	Value string
	Icon  string
}

// DependencyView renders dependency pills.
type DependencyView struct {
	Label  string
	Kind   string
	Status string
	Tone   string
}

// AuditEntryView renders audit trail events.
type AuditEntryView struct {
	Timestamp string
	Actor     string
	Action    string
	Channel   string
}

// BulkBarData powers the bulk action toolbar.
type BulkBarData struct {
	Visible bool
	Summary string
	Actions []BulkActionView
}

// BulkActionView is a bulk action button.
type BulkActionView struct {
	Label       string
	Tone        string
	Description string
	Disabled    bool
}

// ModalFormData represents the catalog CRUD modal payload.
type ModalFormData struct {
	Title        string
	Description  string
	Kind         admincatalog.Kind
	KindLabel    string
	Mode         string
	ActionURL    string
	Method       string
	SubmitLabel  string
	SubmitTone   string
	HiddenFields []ModalHiddenField
	Sections     []ModalSectionData
	Error        string
}

// ModalSectionData groups related form fields.
type ModalSectionData struct {
	Title       string
	Description string
	Fields      []ModalFieldData
}

// ModalFieldData represents a single input within the modal form.
type ModalFieldData struct {
	Name         string
	Label        string
	Type         string
	Value        string
	Placeholder  string
	Hint         string
	Required     bool
	FullWidth    bool
	Options      []ModalOptionData
	Rows         int
	InputMode    string
	Prefix       string
	Suffix       string
	Autocomplete string
	Error        string
	Asset        *ModalAssetField
}

// ModalAssetField configures the asset upload widget rendered inside a modal.
type ModalAssetField struct {
	Purpose        string
	Kind           string
	Accept         string
	MaxSizeBytes   int64
	AssetIDName    string
	AssetID        string
	AssetURL       string
	FileName       string
	FileNameName   string
	URLFieldName   string
	URLFieldValue  string
	DisplayPreview bool
	UploadLabel    string
	ReplaceLabel   string
	RemoveLabel    string
	EmptyLabel     string
}

// ModalOptionData is a selectable option for dropdown fields.
type ModalOptionData struct {
	Value    string
	Label    string
	Selected bool
}

// ModalHiddenField is a hidden input rendered within the modal form.
type ModalHiddenField struct {
	Name  string
	Value string
}

// DeleteModalData powers the delete confirmation modal.
type DeleteModalData struct {
	Title          string
	Description    string
	KindLabel      string
	ItemName       string
	ItemIdentifier string
	ActionURL      string
	Method         string
	SubmitLabel    string
	SubmitTone     string
	HiddenFields   []ModalHiddenField
	Metadata       []MetadataView
	Dependencies   []DependencyView
	Warning        string
	Error          string
}

// BuildPageData composes the server-rendered payload.

func BuildPageData(basePath string, kind admincatalog.Kind, state QueryState, result admincatalog.ListResult) PageData {
	pagePath := joinBase(basePath, fmt.Sprintf("/catalog/%s", kind))
	viewToggle := buildViewToggle(basePath, pagePath, kind, state)
	drawer := DrawerPayload(result.SelectedDetail)
	table := TablePayload(basePath, pagePath, kind, state, result, drawer, viewToggle)
	cards := CardsPayload(basePath, pagePath, kind, state, result, drawer, viewToggle)
	activeView := viewToggle.Active
	pageURL := helpers.BuildURL(pagePath, ensureQueryView(state.RawQuery, activeView))
	return PageData{
		Title:          "カタログ管理",
		Description:    "テンプレート・フォント・素材・商品を一元管理し、公開状態や依存関係を可視化します。",
		Breadcrumbs:    breadcrumbItems(basePath, kind),
		Tabs:           buildTabs(basePath, kind, state),
		Kind:           kind,
		KindLabel:      kind.Label(),
		Query:          state,
		Summary:        buildSummaryData(result.Summary),
		Filters:        buildFilterData(result.Filters, state),
		ViewToggle:     viewToggle,
		Table:          table,
		Cards:          cards,
		Drawer:         drawer,
		Bulk:           buildBulkBar(result.Bulk),
		TableEndpoint:  table.FragmentPath,
		CardsEndpoint:  cards.FragmentPath,
		DrawerEndpoint: joinBase(basePath, fmt.Sprintf("/catalog/%s/drawer", kind)),
		CreateURL:      joinBase(basePath, fmt.Sprintf("/catalog/%s/modal/new", kind)),
		EmptyMessage:   result.EmptyMessage,
		PagePath:       pagePath,
		PageURL:        pageURL,
	}
}

// BuildEditPageData composes the catalog edit page payload.
func BuildEditPageData(basePath string, kind admincatalog.Kind, detail admincatalog.ItemDetail, form ModalFormData) EditPageData {
	pagePath := joinBase(basePath, fmt.Sprintf("/catalog/%s", kind))
	breadcrumbs := []partials.Breadcrumb{
		{
			Label: "カタログ",
			Href:  joinBase(basePath, "/catalog/templates"),
		},
		{
			Label: kind.Label(),
			Href:  pagePath,
		},
		{
			Label: "編集",
			Href:  "",
		},
	}
	return EditPageData{
		Title:          fmt.Sprintf("%sを編集", kind.Label()),
		Kind:           kind,
		KindLabel:      kind.Label(),
		ItemID:         detail.Item.ID,
		ItemName:       detail.Item.Name,
		ItemIdentifier: detail.Item.Identifier,
		StatusLabel:    detail.Item.StatusLabel,
		StatusTone:     detail.Item.StatusTone,
		UpdatedLabel:   helpers.Date(detail.UpdatedAt, "2006-01-02 15:04"),
		BackURL:        pagePath,
		Form:           form,
		Drawer:         DrawerPayload(&detail),
		Breadcrumbs:    breadcrumbs,
	}
}

// TablePayload prepares the table fragment data.
func TablePayload(basePath, pagePath string, kind admincatalog.Kind, state QueryState, result admincatalog.ListResult, drawer DrawerData, view ViewToggle) TableData {
	rows := make([]TableRow, 0, len(result.Items))
	for _, item := range result.Items {
		rows = append(rows, toTableRow(basePath, kind, item, result.SelectedID))
	}
	rawQuery := ensureQueryView(state.RawQuery, "table")
	filterQuery := stripQueryParams(rawQuery, "page")
	pagination := toTablePagination(result.Pagination)
	sortValue := strings.TrimSpace(state.Sort)
	if sortValue == "" {
		sortValue = "-updated_at"
	}
	fragmentPath := joinBase(basePath, fmt.Sprintf("/catalog/%s/table", kind))
	return TableData{
		BasePath:     basePath,
		FragmentPath: fragmentPath,
		RawQuery:     rawQuery,
		FilterQuery:  filterQuery,
		Rows:         rows,
		EmptyMessage: result.EmptyMessage,
		KindLabel:    kind.Label(),
		SelectedID:   result.SelectedID,
		ViewParam:    "table",
		Drawer:       drawer,
		PagePath:     pagePath,
		View:         view,
		Pagination:   pagination,
		Sort: SortState{
			Active:        sortValue,
			BasePath:      pagePath,
			FragmentPath:  fragmentPath,
			RawQuery:      filterQuery,
			FragmentQuery: rawQuery,
			Param:         "sort",
			ResetPage:     true,
			PageParam:     "page",
			HxTarget:      "#catalog-view",
			HxSwap:        "outerHTML",
			HxPushURL:     true,
		},
	}
}

// CardsPayload prepares the card fragment data.
func CardsPayload(basePath, pagePath string, kind admincatalog.Kind, state QueryState, result admincatalog.ListResult, drawer DrawerData, view ViewToggle) CardsData {
	cards := make([]CardView, 0, len(result.Items))
	for _, item := range result.Items {
		cards = append(cards, toCardView(item, result.SelectedID))
	}
	rawQuery := ensureQueryView(state.RawQuery, "cards")
	return CardsData{
		BasePath:     basePath,
		FragmentPath: joinBase(basePath, fmt.Sprintf("/catalog/%s/cards", kind)),
		RawQuery:     rawQuery,
		FilterQuery:  stripQueryParams(rawQuery, "page"),
		Cards:        cards,
		EmptyMessage: result.EmptyMessage,
		SelectedID:   result.SelectedID,
		Drawer:       drawer,
		PagePath:     pagePath,
		View:         view,
	}
}

// DrawerPayload prepares the drawer pane data.
func DrawerPayload(detail *admincatalog.ItemDetail) DrawerData {
	if detail == nil {
		return DrawerData{Empty: true}
	}

	owner := DrawerOwner{
		Name:  detail.Owner.Name,
		Email: detail.Owner.Email,
	}

	usage := make([]RowMetric, 0, len(detail.Usage))
	for _, metric := range detail.Usage {
		usage = append(usage, RowMetric{Label: metric.Label, Value: metric.Value, Icon: metric.Icon})
	}

	metadata := make([]MetadataView, 0, len(detail.Metadata))
	for _, entry := range detail.Metadata {
		metadata = append(metadata, MetadataView{Key: entry.Key, Value: entry.Value, Icon: entry.Icon})
	}

	dependencies := make([]DependencyView, 0, len(detail.Dependencies))
	for _, dep := range detail.Dependencies {
		dependencies = append(dependencies, DependencyView{
			Label:  dep.Label,
			Kind:   dep.Kind,
			Status: dep.Status,
			Tone:   dep.Tone,
		})
	}

	audit := make([]AuditEntryView, 0, len(detail.AuditTrail))
	for _, entry := range detail.AuditTrail {
		audit = append(audit, AuditEntryView{
			Timestamp: entry.Timestamp.Local().Format("2006-01-02 15:04"),
			Actor:     entry.Actor,
			Action:    entry.Action,
			Channel:   entry.Channel,
		})
	}

	version := strings.TrimSpace(detail.Item.Version)
	lastPublishedLabel := formatTimePtr(detail.LastPublishedAt)
	lastPublishedBy := firstNonEmpty(detail.LastPublishedBy, detail.Item.LastPublishedBy, detail.Owner.Name)
	scheduleLabel, scheduleRelative := scheduleDescriptors(detail.ScheduledPublishAt)

	return DrawerData{
		ID:                 detail.Item.ID,
		Kind:               detail.Item.Kind,
		Empty:              false,
		Title:              detail.Item.Name,
		StatusLabel:        detail.Item.StatusLabel,
		StatusTone:         detail.Item.StatusTone,
		KindLabel:          detail.Item.Kind.Label(),
		Description:        detail.Description,
		Owner:              owner,
		PreviewURL:         detail.PreviewURL,
		PreviewAlt:         detail.PreviewAlt,
		Usage:              usage,
		Metadata:           metadata,
		Dependencies:       dependencies,
		Audit:              audit,
		Tags:               detail.Tags,
		UpdatedLabel:       helpers.Date(detail.UpdatedAt, "2006-01-02 15:04"),
		Version:            version,
		LastPublishedLabel: lastPublishedLabel,
		LastPublishedBy:    lastPublishedBy,
		ScheduleLabel:      scheduleLabel,
		ScheduleRelative:   scheduleRelative,
		HasSchedule:        scheduleLabel != "",
	}
}

func toTableRow(basePath string, kind admincatalog.Kind, item admincatalog.Item, selected string) TableRow {
	metrics := make([]RowMetric, 0, len(item.Metrics))
	for _, metric := range item.Metrics {
		metrics = append(metrics, RowMetric{
			Label: metric.Label,
			Value: metric.Value,
			Icon:  metric.Icon,
		})
	}
	editURL := joinBase(basePath, fmt.Sprintf("/catalog/%s/%s/edit", kind, item.ID))
	deleteURL := joinBase(basePath, fmt.Sprintf("/catalog/%s/%s/modal/delete", kind, item.ID))
	scheduleLabel, scheduleRelative := scheduleDescriptors(item.ScheduledPublishAt)

	return TableRow{
		ID:               item.ID,
		Name:             item.Name,
		Identifier:       item.Identifier,
		Description:      item.Description,
		StatusLabel:      item.StatusLabel,
		StatusTone:       item.StatusTone,
		Owner:            item.Owner.Name,
		OwnerInitials:    initials(item.Owner.Name),
		UpdatedLabel:     helpers.Date(item.UpdatedAt, "2006-01-02 15:04"),
		UpdatedRelative:  helpers.Relative(item.UpdatedAt),
		UsageLabel:       item.UsageLabel,
		Tags:             item.Tags,
		Metrics:          metrics,
		PreviewURL:       item.PreviewURL,
		PreviewAlt:       item.PreviewAlt,
		Badge:            item.Badge,
		BadgeTone:        item.BadgeTone,
		Selected:         item.ID == selected && selected != "",
		Version:          item.Version,
		ScheduleLabel:    scheduleLabel,
		ScheduleRelative: scheduleRelative,
		CategoryLabel:    item.CategoryLabel,
		CategoryValue:    item.Category,
		EditURL:          editURL,
		DeleteURL:        deleteURL,
	}
}

func toCardView(item admincatalog.Item, selected string) CardView {
	scheduleLabel, scheduleRelative := scheduleDescriptors(item.ScheduledPublishAt)
	return CardView{
		ID:          item.ID,
		Title:       item.Name,
		Subtitle:    item.Identifier,
		StatusLabel: item.StatusLabel,
		StatusTone:  item.StatusTone,
		UsageLabel:  item.UsageLabel,
		Tags:        item.Tags,
		Metrics: func() []RowMetric {
			rows := make([]RowMetric, 0, len(item.Metrics))
			for _, metric := range item.Metrics {
				rows = append(rows, RowMetric{Label: metric.Label, Value: metric.Value, Icon: metric.Icon})
			}
			return rows
		}(),
		PreviewURL:       item.PreviewURL,
		PreviewAlt:       item.PreviewAlt,
		Selected:         item.ID == selected && selected != "",
		Badge:            item.Badge,
		BadgeTone:        item.BadgeTone,
		Version:          item.Version,
		ScheduleLabel:    scheduleLabel,
		ScheduleRelative: scheduleRelative,
	}
}

func toTablePagination(p admincatalog.Pagination) TablePagination {
	var totalPtr *int
	if p.TotalItems >= 0 {
		value := p.TotalItems
		totalPtr = &value
	}
	return TablePagination{
		Page:     p.Page,
		PageSize: p.PageSize,
		Total:    p.TotalItems,
		TotalPtr: totalPtr,
		Next:     p.NextPage,
		Prev:     p.PrevPage,
	}
}

func buildTabs(basePath string, kind admincatalog.Kind, state QueryState) []components.UnderlineTab {
	kinds := []admincatalog.Kind{admincatalog.KindTemplates, admincatalog.KindFonts, admincatalog.KindMaterials, admincatalog.KindProducts}
	result := make([]components.UnderlineTab, 0, len(kinds))
	for _, k := range kinds {
		pagePath := joinBase(basePath, fmt.Sprintf("/catalog/%s", k))
		currentView := strings.TrimSpace(state.View)
		if currentView == "" {
			currentView = "table"
		}
		href := helpers.BuildURL(pagePath, ensureQueryView(state.RawQuery, currentView))
		fragment := joinBase(basePath, fmt.Sprintf("/catalog/%s/%s", k, currentView))
		tab := components.UnderlineTab{
			ID:     string(k),
			Label:  k.Label(),
			Href:   href,
			Active: k == kind,
		}
		tab.Attributes = map[string]string{
			"hx-get":      fmt.Sprintf("%s?%s", fragment, ensureQueryView(state.RawQuery, currentView)),
			"hx-target":   "#catalog-view",
			"hx-swap":     "outerHTML",
			"hx-push-url": href,
		}
		result = append(result, tab)
	}
	return result
}

func buildSummaryData(summary admincatalog.Summary) SummaryData {
	lastUpdated := ""
	if !summary.LastUpdated.IsZero() {
		lastUpdated = helpers.Relative(summary.LastUpdated)
	}
	return SummaryData{
		TotalLabel:     fmt.Sprintf("%d 件", summary.Total),
		PublishedLabel: fmt.Sprintf("公開中 %d", summary.Published),
		ScheduledLabel: fmt.Sprintf("公開予約 %d", summary.Scheduled),
		DraftLabel:     fmt.Sprintf("下書き %d", summary.Drafts),
		ReviewLabel:    fmt.Sprintf("レビュー中 %d", summary.InReview),
		LastUpdated:    lastUpdated,
	}
}

func buildFilterData(filters admincatalog.FilterSummary, state QueryState) FilterData {
	statusFilters := make([]StatusFilter, 0, len(filters.Statuses))
	for _, option := range filters.Statuses {
		statusFilters = append(statusFilters, StatusFilter{
			Value:  option.Value,
			Label:  option.Label,
			Tone:   toneForStatus(option.Value),
			Count:  option.Count,
			Active: option.Active,
		})
	}

	categoryOptions := make([]SelectOption, 0, len(filters.Categories))
	for _, option := range filters.Categories {
		categoryOptions = append(categoryOptions, SelectOption{
			Value:  option.Value,
			Label:  option.Label,
			Count:  option.Count,
			Active: option.Active,
		})
	}

	ownerOptions := make([]SelectOption, 0, len(filters.Owners))
	for _, option := range filters.Owners {
		ownerOptions = append(ownerOptions, SelectOption{
			Value:  option.Value,
			Label:  option.Label,
			Count:  option.Count,
			Active: option.Active,
		})
	}

	tagOptions := make([]SelectOption, 0, len(filters.Tags))
	for _, option := range filters.Tags {
		tagOptions = append(tagOptions, SelectOption{
			Value:  option.Value,
			Label:  option.Label,
			Count:  option.Count,
			Active: option.Active,
		})
	}

	updatedOptions := make([]SelectOption, 0, len(filters.UpdatedRanges))
	for _, option := range filters.UpdatedRanges {
		updatedOptions = append(updatedOptions, SelectOption{
			Value:  option.Value,
			Label:  option.Label,
			Count:  0,
			Active: option.Active,
		})
	}

	return FilterData{
		Statuses:   statusFilters,
		Categories: categoryOptions,
		Owners:     ownerOptions,
		Tags:       tagOptions,
		Updated:    updatedOptions,
	}
}

func buildViewToggle(basePath, pagePath string, kind admincatalog.Kind, state QueryState) ViewToggle {
	tableEndpoint := joinBase(basePath, fmt.Sprintf("/catalog/%s/table", kind))
	cardEndpoint := joinBase(basePath, fmt.Sprintf("/catalog/%s/cards", kind))
	tableURL := tableEndpoint
	cardURL := cardEndpoint
	if state.RawQuery != "" {
		tableURL = fmt.Sprintf("%s?%s", tableURL, ensureQueryView(state.RawQuery, "table"))
		cardURL = fmt.Sprintf("%s?%s", cardURL, ensureQueryView(state.RawQuery, "cards"))
	}
	view := state.View
	if strings.TrimSpace(view) == "" {
		view = "table"
	}
	tablePush := helpers.BuildURL(pagePath, ensureQueryView(state.RawQuery, "table"))
	cardPush := helpers.BuildURL(pagePath, ensureQueryView(state.RawQuery, "cards"))
	return ViewToggle{
		Active: view,
		Options: []ViewOption{
			{Value: "table", Label: "テーブル", Icon: "📋", Endpoint: tableURL, PushURL: tablePush, Active: view == "table"},
			{Value: "cards", Label: "カード", Icon: "🗂", Endpoint: cardURL, PushURL: cardPush, Active: view == "cards"},
		},
	}
}

func buildBulkBar(bulk admincatalog.BulkSummary) BulkBarData {
	if bulk.Eligible == 0 {
		return BulkBarData{}
	}
	actions := make([]BulkActionView, 0, len(bulk.Actions))
	for _, action := range bulk.Actions {
		actions = append(actions, BulkActionView{
			Label:       action.Label,
			Tone:        action.Tone,
			Description: action.Description,
			Disabled:    action.Disabled,
		})
	}
	return BulkBarData{
		Visible: true,
		Summary: fmt.Sprintf("表示中 %d 件 / 一括操作対象", bulk.Eligible),
		Actions: actions,
	}
}

func initials(name string) string {
	parts := strings.Fields(name)
	if len(parts) == 0 {
		return ""
	}
	if len(parts) == 1 {
		runes := []rune(parts[0])
		if len(runes) == 0 {
			return ""
		}
		if len(runes) == 1 {
			return strings.ToUpper(string(runes))
		}
		return strings.ToUpper(string(runes[0:2]))
	}
	return strings.ToUpper(string([]rune(parts[0])[0])) + strings.ToUpper(string([]rune(parts[len(parts)-1])[0]))
}

func formatTimePtr(ts *time.Time) string {
	if ts == nil {
		return ""
	}
	value := *ts
	if value.IsZero() {
		return ""
	}
	local := toTokyo(value)
	return helpers.Date(local, "2006-01-02 15:04 MST")
}

func scheduleDescriptors(ts *time.Time) (string, string) {
	if ts == nil {
		return "", ""
	}
	value := *ts
	if value.IsZero() {
		return "", ""
	}
	local := toTokyo(value)
	return helpers.Date(local, "2006-01-02 15:04 MST"), helpers.Relative(local)
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func toneForStatus(value string) string {
	switch value {
	case string(admincatalog.StatusDraft):
		return "warning"
	case string(admincatalog.StatusScheduled):
		return "info"
	case string(admincatalog.StatusInReview):
		return "info"
	case string(admincatalog.StatusArchived):
		return "muted"
	default:
		return "success"
	}
}

func toTokyo(t time.Time) time.Time {
	loc, err := time.LoadLocation("Asia/Tokyo")
	if err != nil {
		loc = time.FixedZone("JST", 9*60*60)
	}
	return t.In(loc)
}

func ensureQueryView(rawQuery, view string) string {
	query := helpers.SetRawQuery(rawQuery, "view", view)
	return query
}

func stripQueryParams(rawQuery string, keys ...string) string {
	clean := rawQuery
	for _, key := range keys {
		clean = helpers.DelRawQuery(clean, key)
	}
	return clean
}

func breadcrumbItems(basePath string, kind admincatalog.Kind) []partials.Breadcrumb {
	return []partials.Breadcrumb{
		{
			Label: "カタログ",
			Href:  joinBase(basePath, "/catalog/templates"),
		},
		{
			Label: kind.Label(),
			Href:  "",
		},
	}
}

func joinBase(base, suffix string) string {
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
