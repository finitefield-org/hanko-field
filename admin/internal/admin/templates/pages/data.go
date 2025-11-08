package pages

import (
	"fmt"
	"net/url"
	"sort"
	"strings"
	"time"

	admincontent "finitefield.org/hanko-admin/internal/admin/content"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageManagementData is the root view model for the page management screen.
type PageManagementData struct {
	Title       string
	Description string
	Breadcrumbs []partials.Breadcrumb
	Tree        TreeViewData
	Workspace   WorkspaceData
	CSRFToken   string
}

// TreeViewData renders the navigation tree and filter header.
type TreeViewData struct {
	Nodes         []TreeNodeData
	Summary       []SummaryChip
	SearchValue   string
	StatusValue   string
	TypeValue     string
	LocaleValue   string
	ResetURL      string
	Query         QueryState
	StatusOptions []FilterOption
	TypeOptions   []FilterOption
	LocaleOptions []FilterOption
}

// SummaryChip represents a header summary pill.
type SummaryChip struct {
	Label string
	Tone  string
}

// TreeNodeData represents a node within the navigation tree.
type TreeNodeData struct {
	ID          string
	Title       string
	Subtitle    string
	StatusLabel string
	StatusTone  string
	URL         string
	Selected    bool
	Children    []TreeNodeData
	Icon        string
}

// FilterOption represents a select/filter option with counts.
type FilterOption struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// QueryState mirrors the current query string.
type QueryState struct {
	RawQuery string
	PageID   string
	Search   string
	Status   string
	Type     string
	Locale   string
}

// WorkspaceData encapsulates the editor workspace panes.
type WorkspaceData struct {
	PageID     string
	Editor     EditorViewData
	Preview    PreviewViewData
	Properties PropertiesViewData
	Schedule   ScheduleViewData
	History    HistoryViewData
	ActionBar  ActionBarData
}

// EditorViewData renders the block editor panel.
type EditorViewData struct {
	PageTitle       string
	PageSummary     string
	PageOutline     string
	StatusLabel     string
	StatusTone      string
	LocaleLabel     string
	LocaleValue     string
	Version         string
	UpdatedRelative string
	UpdatedExact    string
	LastSaved       string
	LastSavedBy     string
	TagsValue       string
	Blocks          []EditorBlockData
	Palette         []BlockPaletteGroupData
	Locales         []LocaleOption
	DraftAction     string
	PreviewAction   string
	BasePreviewURL  string
	PageID          string
}

// EditorBlockData summarises an editable block.
type EditorBlockData struct {
	ID          string
	Label       string
	Summary     string
	Description string
	Icon        string
	Locked      bool
}

// BlockPaletteGroupData groups palette items.
type BlockPaletteGroupData struct {
	Label  string
	Blocks []BlockPaletteItemData
}

// BlockPaletteItemData describes a block available for insertion.
type BlockPaletteItemData struct {
	Type        string
	Label       string
	Description string
	Icon        string
}

// LocaleOption renders a locale selector option.
type LocaleOption struct {
	Label  string
	Locale string
	URL    string
	Active bool
}

// PropertiesViewData renders the properties side panel.
type PropertiesViewData struct {
	Slug            string
	Type            string
	Version         string
	VisibilityLabel string
	VisibilityTone  string
	LiveURL         string
	PreviewURL      string
	ShareURL        string
	Tags            []string
	SEO             PageSEOData
	Breadcrumbs     []string
}

// PageSEOData contains metadata fields.
type PageSEOData struct {
	MetaTitle       string
	MetaDescription string
	OGImageURL      string
	CanonicalURL    string
}

// ScheduleViewData powers the scheduling form.
type ScheduleViewData struct {
	ScheduledValue   string
	ScheduledLabel   string
	Timezone         string
	StatusLabel      string
	StatusTone       string
	LastScheduled    string
	ScheduleAction   string
	UnscheduleAction string
}

// PreviewViewData renders the live preview pane.
type PreviewViewData struct {
	HeroHTML    string
	BodyHTML    string
	Notes       []string
	Locales     []LocaleOption
	ShareURL    string
	ExternalURL string
	SEO         PageSEOData
}

// HistoryViewData configures the history modal.
type HistoryViewData struct {
	ModalID string
	Items   []HistoryItemData
}

// HistoryItemData renders a single history entry.
type HistoryItemData struct {
	Title    string
	Summary  string
	Actor    string
	Version  string
	Occurred string
	Relative string
	Tone     string
	Icon     string
}

// ActionBarData renders the footer action bar.
type ActionBarData struct {
	SaveAction      string
	PreviewAction   string
	PublishAction   string
	UnpublishAction string
	PreviewURL      string
	IsPublished     bool
	StatusLabel     string
	PageID          string
}

// PreviewPageData renders the full preview page.
type PreviewPageData struct {
	Title       string
	Breadcrumbs []partials.Breadcrumb
	Header      PreviewHeaderData
	Content     PreviewViewData
}

// PreviewHeaderData renders preview header information.
type PreviewHeaderData struct {
	Title           string
	StatusLabel     string
	StatusTone      string
	LocaleOptions   []LocaleOption
	UpdatedRelative string
	UpdatedExact    string
	ShareURL        string
	ExternalURL     string
}

// PreviewFragmentData powers the live preview fragment.
type PreviewFragmentData struct {
	Preview PreviewViewData
}

// BuildPageManagementData assembles the data required for the page management UI.
func BuildPageManagementData(basePath string, state QueryState, tree admincontent.PageTree, editor admincontent.PageEditor, preview admincontent.PagePreview, csrfToken string) PageManagementData {
	selectedID := tree.ActiveID
	if selectedID == "" {
		selectedID = state.PageID
	}

	nodes := buildTreeNodes(basePath, state, tree.Nodes)

	summary := []SummaryChip{
		{Label: fmt.Sprintf("総数 %d", tree.Counts.Total), Tone: ""},
		{Label: fmt.Sprintf("公開 %d", tree.Counts.Published), Tone: "success"},
		{Label: fmt.Sprintf("公開予定 %d", tree.Counts.Scheduled), Tone: "warning"},
		{Label: fmt.Sprintf("下書き %d", tree.Counts.Draft), Tone: ""},
	}

	editorView := buildEditorView(basePath, state, editor, preview)
	propertiesView := buildPropertiesView(editor)
	scheduleView := buildScheduleView(basePath, editor)
	historyView := buildHistoryView(editor)
	previewView := buildPreviewView(basePath, state, preview)
	actionBar := buildActionBar(basePath, editor, preview)

	treeView := TreeViewData{
		Nodes:         nodes,
		Summary:       summary,
		SearchValue:   state.Search,
		StatusValue:   state.Status,
		TypeValue:     state.Type,
		LocaleValue:   state.Locale,
		ResetURL:      fmt.Sprintf("%s/content/pages", basePath),
		Query:         state,
		StatusOptions: buildStatusOptions(tree, state.Status),
		TypeOptions:   buildTypeOptions(tree.TypeCounts, state.Type),
		LocaleOptions: buildLocaleFilterOptions(tree.LocaleCounts, state.Locale),
	}

	return PageManagementData{
		Title:       "固定ページ管理",
		Description: "固定ページの構造、ブロック、公開スケジュールを管理します。",
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "コンテンツ", Href: fmt.Sprintf("%s/content/guides", basePath)},
			{Label: "固定ページ", Href: ""},
		},
		Tree: treeView,
		Workspace: WorkspaceData{
			PageID:     editor.Page.ID,
			Editor:     editorView,
			Preview:    previewView,
			Properties: propertiesView,
			Schedule:   scheduleView,
			History:    historyView,
			ActionBar:  actionBar,
		},
		CSRFToken: csrfToken,
	}
}

// BuildPreviewPageData assembles the full preview page payload.
func BuildPreviewPageData(basePath string, preview admincontent.PagePreview) PreviewPageData {
	updatedRelative := helpers.Relative(preview.Page.UpdatedAt)
	header := PreviewHeaderData{
		Title:           preview.Page.Title,
		StatusLabel:     preview.Page.StatusLabel,
		StatusTone:      preview.Page.StatusTone,
		LocaleOptions:   buildLocaleOptions(basePath, QueryState{}, preview.Page.Slug, preview.Locales),
		UpdatedRelative: updatedRelative,
		UpdatedExact:    helpers.Date(preview.Page.UpdatedAt, "2006-01-02 15:04"),
		ShareURL:        preview.ShareURL,
		ExternalURL:     preview.ExternalURL,
	}

	return PreviewPageData{
		Title: fmt.Sprintf("%s | プレビュー", preview.Page.Title),
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "コンテンツ", Href: fmt.Sprintf("%s/content/pages", basePath)},
			{Label: preview.Page.Title, Href: ""},
		},
		Header: header,
		Content: PreviewViewData{
			HeroHTML:    preview.Content.HeroHTML,
			BodyHTML:    preview.Content.BodyHTML,
			Notes:       preview.Notes,
			Locales:     buildLocaleOptions(basePath, QueryState{}, preview.Page.Slug, preview.Locales),
			ShareURL:    preview.ShareURL,
			ExternalURL: preview.ExternalURL,
			SEO: PageSEOData{
				MetaTitle:       preview.SEO.MetaTitle,
				MetaDescription: preview.SEO.MetaDescription,
				OGImageURL:      preview.SEO.OGImageURL,
				CanonicalURL:    preview.SEO.CanonicalURL,
			},
		},
	}
}

// BuildPreviewFragmentData assembles the live preview fragment payload.
func BuildPreviewFragmentData(basePath string, state QueryState, preview admincontent.PagePreview) PreviewFragmentData {
	return PreviewFragmentData{
		Preview: buildPreviewView(basePath, state, preview),
	}
}

func buildTreeNodes(basePath string, state QueryState, nodes []admincontent.PageNode) []TreeNodeData {
	results := make([]TreeNodeData, 0, len(nodes))
	for _, node := range nodes {
		url := buildNodeURL(basePath, state, node.ID)
		children := buildTreeNodes(basePath, state, node.Children)
		results = append(results, TreeNodeData{
			ID:          node.ID,
			Title:       node.Title,
			Subtitle:    node.Subtitle,
			StatusLabel: node.StatusLabel,
			StatusTone:  node.StatusTone,
			URL:         url,
			Selected:    node.Selected,
			Children:    children,
			Icon:        node.Icon,
		})
	}
	return results
}

func buildNodeURL(basePath string, state QueryState, pageID string) string {
	values := url.Values{}
	if state.Search != "" {
		values.Set("q", state.Search)
	}
	if state.Status != "" {
		values.Set("status", state.Status)
	}
	if state.Type != "" {
		values.Set("type", state.Type)
	}
	if state.Locale != "" {
		values.Set("locale", state.Locale)
	}
	values.Set("page", pageID)
	raw := values.Encode()
	if raw != "" {
		return fmt.Sprintf("%s/content/pages?%s", basePath, raw)
	}
	return fmt.Sprintf("%s/content/pages?page=%s", basePath, pageID)
}

func buildEditorView(basePath string, state QueryState, editor admincontent.PageEditor, preview admincontent.PagePreview) EditorViewData {
	localeLabel := strings.ToUpper(editor.Page.Locale)
	updatedRelative := helpers.Relative(editor.Page.UpdatedAt)
	updatedExact := helpers.Date(editor.Page.UpdatedAt, "2006-01-02 15:04")

	blocks := make([]EditorBlockData, 0, len(editor.Draft.Blocks))
	for _, block := range editor.Draft.Blocks {
		blocks = append(blocks, EditorBlockData{
			ID:          block.ID,
			Label:       block.Label,
			Summary:     block.Summary,
			Description: block.Description,
			Icon:        block.Icon,
			Locked:      block.Locked,
		})
	}

	palette := make([]BlockPaletteGroupData, 0, len(editor.BlockPalette))
	for _, group := range editor.BlockPalette {
		items := make([]BlockPaletteItemData, 0, len(group.Blocks))
		for _, block := range group.Blocks {
			items = append(items, BlockPaletteItemData{
				Type:        block.Type,
				Label:       block.Label,
				Description: block.Description,
				Icon:        block.Icon,
			})
		}
		palette = append(palette, BlockPaletteGroupData{
			Label:  group.Label,
			Blocks: items,
		})
	}

	lastSaved := ""
	if !editor.Draft.LastSavedAt.IsZero() {
		lastSaved = helpers.Relative(editor.Draft.LastSavedAt)
	}

	locales := buildLocaleOptions(basePath, state, editor.Page.Slug, editor.Locales)

	return EditorViewData{
		PageTitle:       editor.Page.Title,
		PageSummary:     editor.Page.Summary,
		PageOutline:     editor.Draft.Outline,
		StatusLabel:     editor.Page.StatusLabel,
		StatusTone:      editor.Page.StatusTone,
		LocaleLabel:     localeLabel,
		LocaleValue:     editor.Page.Locale,
		Version:         editor.Page.Version,
		UpdatedRelative: updatedRelative,
		UpdatedExact:    updatedExact,
		LastSaved:       lastSaved,
		LastSavedBy:     editor.Draft.LastSavedBy,
		TagsValue:       strings.Join(editor.Draft.Tags, ", "),
		Blocks:          blocks,
		Palette:         palette,
		Locales:         locales,
		DraftAction:     fmt.Sprintf("%s/content/pages/%s:save", basePath, editor.Page.ID),
		PreviewAction:   fmt.Sprintf("%s/content/pages/%s/edit/preview", basePath, editor.Page.ID),
		BasePreviewURL:  fmt.Sprintf("%s/content/pages/%s/preview", basePath, editor.Page.ID),
		PageID:          editor.Page.ID,
	}
}

func buildPropertiesView(editor admincontent.PageEditor) PropertiesViewData {
	props := editor.Properties
	return PropertiesViewData{
		Slug:            props.Slug,
		Type:            props.Type,
		Version:         props.Version,
		VisibilityLabel: props.VisibilityLabel,
		VisibilityTone:  props.VisibilityTone,
		LiveURL:         props.LiveURL,
		PreviewURL:      props.PreviewURL,
		ShareURL:        props.ShareURL,
		Tags:            append([]string(nil), props.Tags...),
		SEO: PageSEOData{
			MetaTitle:       props.SEO.MetaTitle,
			MetaDescription: props.SEO.MetaDescription,
			OGImageURL:      props.SEO.OGImageURL,
			CanonicalURL:    props.SEO.CanonicalURL,
		},
		Breadcrumbs: append([]string(nil), props.Breadcrumbs...),
	}
}

func buildScheduleView(basePath string, editor admincontent.PageEditor) ScheduleViewData {
	schedule := editor.Schedule
	value := ""
	if schedule.ScheduledAt != nil && !schedule.ScheduledAt.IsZero() {
		value = schedule.ScheduledAt.In(time.Local).Format("2006-01-02T15:04")
	}

	lastScheduled := ""
	if schedule.LastScheduledAt != nil && !schedule.LastScheduledAt.IsZero() {
		lastScheduled = fmt.Sprintf("%s（%s）", helpers.Relative(*schedule.LastScheduledAt), schedule.LastScheduledBy)
	}

	return ScheduleViewData{
		ScheduledValue:   value,
		ScheduledLabel:   schedule.WindowLabel,
		Timezone:         schedule.TimezoneLabel,
		StatusLabel:      schedule.StatusLabel,
		StatusTone:       schedule.StatusTone,
		LastScheduled:    lastScheduled,
		ScheduleAction:   fmt.Sprintf("%s/content/pages/%s:schedule", basePath, editor.Page.ID),
		UnscheduleAction: fmt.Sprintf("%s/content/pages/%s:unschedule", basePath, editor.Page.ID),
	}
}

func buildHistoryView(editor admincontent.PageEditor) HistoryViewData {
	items := make([]HistoryItemData, 0, len(editor.History))
	for _, entry := range editor.History {
		items = append(items, HistoryItemData{
			Title:    entry.Title,
			Summary:  entry.Summary,
			Actor:    entry.Actor,
			Version:  entry.Version,
			Occurred: helpers.Date(entry.OccurredAt, "2006-01-02 15:04"),
			Relative: helpers.Relative(entry.OccurredAt),
			Tone:     entry.Tone,
			Icon:     entry.Icon,
		})
	}
	return HistoryViewData{
		ModalID: "page-history-modal",
		Items:   items,
	}
}

// BuildHistoryModalData converts page history entries to modal data.
func BuildHistoryModalData(entries []admincontent.PageHistoryEntry) HistoryViewData {
	items := make([]HistoryItemData, 0, len(entries))
	for _, entry := range entries {
		items = append(items, HistoryItemData{
			Title:    entry.Title,
			Summary:  entry.Summary,
			Actor:    entry.Actor,
			Version:  entry.Version,
			Occurred: helpers.Date(entry.OccurredAt, "2006-01-02 15:04"),
			Relative: helpers.Relative(entry.OccurredAt),
			Tone:     entry.Tone,
			Icon:     entry.Icon,
		})
	}
	return HistoryViewData{ModalID: "page-history-modal", Items: items}
}

func buildPreviewView(basePath string, state QueryState, preview admincontent.PagePreview) PreviewViewData {
	locales := buildLocaleOptions(basePath, state, preview.Page.Slug, preview.Locales)
	return PreviewViewData{
		HeroHTML:    preview.Content.HeroHTML,
		BodyHTML:    preview.Content.BodyHTML,
		Notes:       append([]string(nil), preview.Notes...),
		Locales:     locales,
		ShareURL:    preview.ShareURL,
		ExternalURL: preview.ExternalURL,
		SEO: PageSEOData{
			MetaTitle:       preview.SEO.MetaTitle,
			MetaDescription: preview.SEO.MetaDescription,
			OGImageURL:      preview.SEO.OGImageURL,
			CanonicalURL:    preview.SEO.CanonicalURL,
		},
	}
}

func buildActionBar(basePath string, editor admincontent.PageEditor, preview admincontent.PagePreview) ActionBarData {
	return ActionBarData{
		SaveAction:      fmt.Sprintf("%s/content/pages/%s:save", basePath, editor.Page.ID),
		PreviewAction:   fmt.Sprintf("%s/content/pages/%s/edit/preview", basePath, editor.Page.ID),
		PublishAction:   fmt.Sprintf("%s/content/pages/%s:publish", basePath, editor.Page.ID),
		UnpublishAction: fmt.Sprintf("%s/content/pages/%s:unpublish", basePath, editor.Page.ID),
		PreviewURL:      fmt.Sprintf("%s/content/pages/%s/preview", basePath, editor.Page.ID),
		IsPublished:     editor.Page.Status == admincontent.PageStatusPublished,
		StatusLabel:     editor.Page.StatusLabel,
		PageID:          editor.Page.ID,
	}
}

func buildLocaleOptions(basePath string, state QueryState, slug string, locales []admincontent.PageLocale) []LocaleOption {
	options := make([]LocaleOption, 0, len(locales))
	for _, locale := range locales {
		values := url.Values{}
		if state.Search != "" {
			values.Set("q", state.Search)
		}
		if state.Status != "" {
			values.Set("status", state.Status)
		}
		if state.Type != "" {
			values.Set("type", state.Type)
		}
		values.Set("locale", locale.Locale)
		if state.PageID != "" {
			values.Set("page", state.PageID)
		}
		url := fmt.Sprintf("%s/content/pages?%s", basePath, values.Encode())
		options = append(options, LocaleOption{
			Label:  locale.Label,
			Locale: locale.Locale,
			URL:    url,
			Active: locale.Active,
		})
	}
	return options
}

func buildStatusOptions(tree admincontent.PageTree, current string) []FilterOption {
	options := []FilterOption{
		{Value: "", Label: fmt.Sprintf("すべて (%d)", tree.Counts.Total), Count: tree.Counts.Total, Selected: current == ""},
	}
	order := []admincontent.PageStatus{
		admincontent.PageStatusPublished,
		admincontent.PageStatusScheduled,
		admincontent.PageStatusDraft,
		admincontent.PageStatusArchived,
	}
	for _, status := range order {
		value := string(status)
		count := tree.StatusCounts[status]
		options = append(options, FilterOption{
			Value:    value,
			Label:    fmt.Sprintf("%s (%d)", pageStatusLabel(status), count),
			Count:    count,
			Selected: current == value,
		})
	}
	return options
}

func buildTypeOptions(counts map[string]int, current string) []FilterOption {
	total := sumCounts(counts)
	options := []FilterOption{
		{Value: "", Label: fmt.Sprintf("すべて (%d)", total), Count: total, Selected: current == ""},
	}
	keys := make([]string, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		label := key
		switch key {
		case "legal":
			label = "法務"
		case "landing":
			label = "ランディング"
		case "system":
			label = "システム"
		default:
			label = strings.Title(strings.ReplaceAll(key, "-", " "))
		}
		options = append(options, FilterOption{
			Value:    key,
			Label:    fmt.Sprintf("%s (%d)", label, counts[key]),
			Count:    counts[key],
			Selected: current == key,
		})
	}
	return options
}

func buildLocaleFilterOptions(counts map[string]int, current string) []FilterOption {
	total := sumCounts(counts)
	options := []FilterOption{
		{Value: "", Label: fmt.Sprintf("すべて (%d)", total), Count: total, Selected: current == ""},
	}
	keys := make([]string, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		options = append(options, FilterOption{
			Value:    key,
			Label:    fmt.Sprintf("%s (%d)", strings.ToUpper(key), counts[key]),
			Count:    counts[key],
			Selected: strings.EqualFold(current, key),
		})
	}
	return options
}

func sumCounts(counts map[string]int) int {
	total := 0
	for _, v := range counts {
		total += v
	}
	return total
}

func pageStatusLabel(status admincontent.PageStatus) string {
	switch status {
	case admincontent.PageStatusPublished:
		return "公開"
	case admincontent.PageStatusScheduled:
		return "公開予定"
	case admincontent.PageStatusArchived:
		return "アーカイブ"
	default:
		return "下書き"
	}
}
