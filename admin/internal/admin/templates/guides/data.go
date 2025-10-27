package guides

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/a-h/templ"

	admincontent "finitefield.org/hanko-admin/internal/admin/content"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData encapsulates the full server-side rendered payload.
type PageData struct {
	Title         string
	Description   string
	Breadcrumbs   []partials.Breadcrumb
	Summary       SummaryData
	Filters       FilterData
	Query         QueryState
	Table         TableData
	Drawer        DrawerData
	Bulk          BulkData
	TableEndpoint string
	CSRFToken     string
	ResetURL      string
}

// SummaryData renders the header area with totals and locale chips.
type SummaryData struct {
	TotalLabel     string
	PublishedLabel string
	ScheduledLabel string
	DraftLabel     string
	ArchivedLabel  string
	LocaleChips    []LocaleChip
}

// LocaleChip represents a locale toggle.
type LocaleChip struct {
	Value  string
	Label  string
	Count  int
	Active bool
	URL    string
}

// FilterData groups filter controls.
type FilterData struct {
	StatusSegments  []SegmentOption
	PersonaOptions  []SelectOption
	CategoryOptions []SelectOption
	ScheduleValue   string
}

// SegmentOption is used for segmented controls.
type SegmentOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// SelectOption holds dropdown options.
type SelectOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// QueryState mirrors incoming query params.
type QueryState struct {
	Search       string
	Status       string
	Persona      string
	Category     string
	Locale       string
	ScheduleDate string
	Selected     []string
	RawQuery     string
}

// TableData drives the guides table fragment.
type TableData struct {
	Rows         []TableRow
	Total        int
	Error        string
	EmptyMessage string
	SelectedID   string
	Locale       string
	RawQuery     string
	Bulk         BulkData
	FragmentPath string
}

// TableRow is a view model for a single row.
type TableRow struct {
	ID                 string
	Title              string
	Summary            string
	Locale             string
	LocaleLabel        string
	PersonaLabel       string
	CategoryLabel      string
	Author             string
	StatusLabel        string
	StatusTone         string
	UpdatedRelative    string
	UpdatedTooltip     string
	ScheduledLabel     string
	ScheduledRelative  string
	ScheduleInputValue string
	ScheduleHint       string
	IsPublished        bool
	PublishURL         string
	UnpublishURL       string
	ScheduleURL        string
	UnscheduleURL      string
	PreviewURL         string
	EditURL            string
	ViewURL            string
	Selected           bool
	Attributes         templ.Attributes
	Actions            []RowAction
}

// RowAction renders inline actions.
type RowAction struct {
	Label string
	URL   string
	Icon  string
}

// DrawerData powers the guide preview drawer.
type DrawerData struct {
	Empty           bool
	ID              string
	Title           string
	Summary         string
	StatusLabel     string
	StatusTone      string
	LocaleLabel     string
	PersonaLabel    string
	Author          string
	HeroImageURL    string
	PublishedLabel  string
	ScheduledLabel  string
	UpdatedLabel    string
	UpdatedRelative string
	LastChangeNote  string
	Highlights      []DrawerHighlight
	Timeline        []DrawerTimeline
	Tags            []string
}

// DrawerHighlight surfaces key metrics.
type DrawerHighlight struct {
	Label string
	Value string
	Icon  string
	Tone  string
}

// DrawerTimeline shows upcoming or past events.
type DrawerTimeline struct {
	Title       string
	Description string
	OccursLabel string
	Relative    string
	Tone        string
	Icon        string
}

// BulkData configures the bulk action bar.
type BulkData struct {
	SelectedIDs   []string
	SelectedCount int
	TotalCount    int
	Visible       bool
	Toolbar       components.BulkToolbarProps
	Progress      BulkProgress
}

// BulkProgress renders the stepper.
type BulkProgress struct {
	Steps      []BulkProgressStep
	ActiveStep int
}

// BulkProgressStep represents a step item.
type BulkProgressStep struct {
	Label     string
	Completed bool
	Current   bool
}

// FragmentData represents the payload for table fragment responses.
type FragmentData struct {
	Table     TableData
	Summary   SummaryData
	Bulk      BulkData
	Drawer    DrawerData
	CSRFToken string
}

// FragmentPayload assembles fragment data.
func FragmentPayload(table TableData, summary SummaryData, bulk BulkData, drawer DrawerData, csrfToken string) FragmentData {
	return FragmentData{
		Table:     table,
		Summary:   summary,
		Bulk:      bulk,
		Drawer:    drawer,
		CSRFToken: csrfToken,
	}
}

// PreviewPageData captures the data required to render the preview experience.
type PreviewPageData struct {
	PageTitle   string
	Breadcrumbs []partials.Breadcrumb
	Header      PreviewHeaderData
	Viewer      PreviewContentData
	Sidebar     PreviewSidebarData
	Feedback    PreviewFeedbackData
}

// PreviewHeaderData powers the sticky preview header.
type PreviewHeaderData struct {
	Title           string
	Subtitle        string
	StatusLabel     string
	StatusTone      string
	LocaleOptions   []PreviewLocaleOption
	UpdatedRelative string
	UpdatedAt       string
	ShareURL        string
	ExternalURL     string
}

// PreviewLocaleOption renders the locale segmented control.
type PreviewLocaleOption struct {
	Value  string
	Label  string
	URL    string
	Active bool
}

// PreviewContentData mirrors the device frame.
type PreviewContentData struct {
	HeroImageURL string
	Body         templ.Component
	DeviceModes  []PreviewDeviceMode
	Language     string
}

// PreviewDeviceMode represents an available viewport.
type PreviewDeviceMode struct {
	ID     string
	Label  string
	Active bool
}

// PreviewSidebarData surfaces metadata and notes.
type PreviewSidebarData struct {
	Summary         string
	PersonaLabel    string
	CategoryLabel   string
	LocaleLabel     string
	Author          string
	ReadingTime     string
	WordCount       int
	PublishedLabel  string
	ScheduleLabel   string
	UpdatedLabel    string
	UpdatedRelative string
	UpdatedAt       string
	UpdatedDisplay  string
	Tags            []string
	Notes           []string
	Upcoming        []PreviewTimelineItem
}

// PreviewTimelineItem renders upcoming change entries.
type PreviewTimelineItem struct {
	Title       string
	Description string
	OccursLabel string
	Relative    string
	Tone        string
	Icon        string
}

// PreviewFeedbackData configures the action bar.
type PreviewFeedbackData struct {
	ApproveURL         string
	RequestChangesURL  string
	CommentPlaceholder string
}

// EditorPageData drives the two-pane editor experience.
type EditorPageData struct {
	Title           string
	Description     string
	Breadcrumbs     []partials.Breadcrumb
	StatusLabel     string
	StatusTone      string
	LastSavedLabel  string
	LastSavedExact  string
	LastSavedBy     string
	BackURL         string
	PreviewEndpoint string
	PreviewPageURL  string
	PreviewTarget   string
	FormID          string
	Form            EditorFormData
	Preview         EditorPreviewData
	LocaleOptions   []PreviewLocaleOption
}

// EditorFormData represents the editable fields within the form pane.
type EditorFormData struct {
	GuideID      string
	Locale       string
	Title        string
	Summary      string
	HeroImageURL string
	BodyHTML     string
	Persona      string
	Category     string
	TagsValue    string
	CSRFToken    string
}

// EditorPreviewData powers the live preview pane.
type EditorPreviewData struct {
	FragmentID string
	Preview    PreviewPageData
}

// BuildPageData assembles page payload.
func BuildPageData(basePath string, state QueryState, feed admincontent.GuideFeed, selected []string, csrfToken string) PageData {
	table := TablePayload(basePath, state, feed, selected)
	drawer := DrawerPayload(feed, table.SelectedID)
	summary := SummaryPayload(basePath, state, feed)
	filters := FiltersPayload(basePath, state, feed)
	bulk := BulkPayload(basePath, state, table)

	return PageData{
		Title:         "ガイド管理",
		Description:   "公開ステータスやロケール別にガイド記事を管理します。",
		Breadcrumbs:   []partials.Breadcrumb{{Label: "コンテンツ"}, {Label: "ガイド"}},
		Summary:       summary,
		Filters:       filters,
		Query:         state,
		Table:         table,
		Drawer:        drawer,
		Bulk:          bulk,
		TableEndpoint: joinBase(basePath, "/content/guides/table"),
		CSRFToken:     csrfToken,
		ResetURL:      joinBase(basePath, "/content/guides"),
	}
}

// BuildPreviewPageData assembles the guide preview payload.
func BuildPreviewPageData(basePath string, preview admincontent.GuidePreview) PreviewPageData {
	guide := preview.Guide

	breadcrumbs := []partials.Breadcrumb{
		{Label: "コンテンツ"},
		{Label: "ガイド", Href: joinBase(basePath, "/content/guides")},
		{Label: guide.Title},
	}

	header := PreviewHeaderData{
		Title:           guide.Title,
		Subtitle:        guide.Summary,
		StatusLabel:     guide.StatusLabel,
		StatusTone:      guide.StatusTone,
		LocaleOptions:   buildPreviewLocaleOptions(basePath, guide.ID, preview.Locales),
		UpdatedRelative: helpers.Relative(guide.UpdatedAt),
		UpdatedAt:       helpers.Date(guide.UpdatedAt, "2006-01-02 15:04"),
		ShareURL:        preview.ShareURL,
		ExternalURL:     preview.ExternalURL,
	}

	bodyHTML := strings.TrimSpace(preview.Content.BodyHTML)
	if bodyHTML == "" {
		bodyHTML = "<p>プレビューを生成できませんでした。</p>"
	}

	viewer := PreviewContentData{
		HeroImageURL: coalesce(preview.Content.HeroImageURL, guide.HeroImageURL),
		Body:         htmlComponent(bodyHTML),
		DeviceModes:  defaultPreviewDeviceModes(),
		Language:     localeLabel(guide.Locale),
	}

	notes := cloneStrings(preview.Notes)
	if len(notes) == 0 && strings.TrimSpace(guide.LastChangeNote) != "" {
		notes = []string{guide.LastChangeNote}
	}

	sidebar := PreviewSidebarData{
		Summary:         guide.Summary,
		PersonaLabel:    personaLabel(guide.Persona),
		CategoryLabel:   categoryLabel(guide.Category),
		LocaleLabel:     localeLabel(guide.Locale),
		Author:          guide.Author,
		ReadingTime:     firstNonEmpty(guide.ReadingTime, estimateReadingFallback(guide.WordCount)),
		WordCount:       guide.WordCount,
		PublishedLabel:  timestampOrPlaceholder(guide.PublishedAt),
		ScheduleLabel:   timestampOrPlaceholder(guide.ScheduledAt),
		UpdatedLabel:    "最終更新",
		UpdatedRelative: helpers.Relative(guide.UpdatedAt),
		UpdatedAt:       helpers.Date(guide.UpdatedAt, "2006-01-02 15:04"),
		Tags:            cloneStrings(guide.Tags),
		Notes:           notes,
		Upcoming:        buildPreviewTimeline(guide.Upcoming),
	}

	if sidebar.UpdatedAt != "" {
		sidebar.UpdatedDisplay = sidebar.UpdatedAt
		if sidebar.UpdatedRelative != "" {
			sidebar.UpdatedDisplay = fmt.Sprintf("%s（%s）", sidebar.UpdatedAt, sidebar.UpdatedRelative)
		}
	}

	feedback := PreviewFeedbackData{
		ApproveURL:         preview.Feedback.ApproveURL,
		RequestChangesURL:  preview.Feedback.RequestChangesURL,
		CommentPlaceholder: firstNonEmpty(preview.Feedback.CommentPlaceholder, "フィードバックを入力…"),
	}

	return PreviewPageData{
		PageTitle:   fmt.Sprintf("%s プレビュー", guide.Title),
		Breadcrumbs: breadcrumbs,
		Header:      header,
		Viewer:      viewer,
		Sidebar:     sidebar,
		Feedback:    feedback,
	}
}

// BuildEditorPageData assembles the payload for the guide editor experience.
func BuildEditorPageData(basePath string, editor admincontent.GuideEditor, preview admincontent.GuidePreview, csrfToken string) EditorPageData {
	title := fmt.Sprintf("ガイド編集 - %s", editor.Guide.Title)
	description := "ライブプレビューを確認しながらガイドの本文や概要を編集します。"

	lastSavedLabel := "未保存"
	lastSavedExact := ""
	if !editor.Draft.LastSavedAt.IsZero() {
		lastSavedLabel = helpers.Relative(editor.Draft.LastSavedAt)
		lastSavedExact = helpers.Date(editor.Draft.LastSavedAt, "2006-01-02 15:04")
	}

	formID := "guide-editor-form"
	previewTarget := "#guide-editor-preview"

	return EditorPageData{
		Title:       title,
		Description: description,
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "コンテンツ"},
			{Label: "ガイド", Href: joinBase(basePath, "/content/guides")},
			{Label: editor.Guide.Title},
		},
		StatusLabel:     editor.Guide.StatusLabel,
		StatusTone:      editor.Guide.StatusTone,
		LastSavedLabel:  lastSavedLabel,
		LastSavedExact:  lastSavedExact,
		LastSavedBy:     coalesce(editor.Draft.LastSavedBy, editor.Guide.UpdatedBy),
		BackURL:         joinBase(basePath, "/content/guides"),
		PreviewEndpoint: joinBase(basePath, fmt.Sprintf("/content/guides/%s/edit/preview", editor.Guide.ID)),
		PreviewPageURL:  joinBase(basePath, fmt.Sprintf("/content/guides/%s/preview", editor.Guide.ID)),
		PreviewTarget:   previewTarget,
		FormID:          formID,
		Form: EditorFormData{
			GuideID:      editor.Guide.ID,
			Locale:       editor.Draft.Locale,
			Title:        editor.Draft.Title,
			Summary:      editor.Draft.Summary,
			HeroImageURL: editor.Draft.HeroImageURL,
			BodyHTML:     editor.Draft.BodyHTML,
			Persona:      editor.Draft.Persona,
			Category:     editor.Draft.Category,
			TagsValue:    joinTags(editor.Draft.Tags),
			CSRFToken:    csrfToken,
		},
		Preview:       BuildEditorPreviewData(basePath, preview),
		LocaleOptions: buildPreviewLocaleOptions(basePath, editor.Guide.ID, preview.Locales),
	}
}

// BuildEditorPreviewData assembles the preview fragment payload.
func BuildEditorPreviewData(basePath string, preview admincontent.GuidePreview) EditorPreviewData {
	return EditorPreviewData{
		FragmentID: "guide-editor-preview",
		Preview:    BuildPreviewPageData(basePath, preview),
	}
}

// SummaryPayload builds summary data.
func SummaryPayload(basePath string, state QueryState, feed admincontent.GuideFeed) SummaryData {
	total := feed.Counts.Total
	return SummaryData{
		TotalLabel:     fmt.Sprintf("全 %d 件", total),
		PublishedLabel: fmt.Sprintf("公開中 %d", feed.Counts.Published),
		ScheduledLabel: fmt.Sprintf("公開予定 %d", feed.Counts.Scheduled),
		DraftLabel:     fmt.Sprintf("下書き %d", feed.Counts.Draft),
		ArchivedLabel:  fmt.Sprintf("アーカイブ %d", feed.Counts.Archived),
		LocaleChips:    buildLocaleChips(basePath, state, feed.LocaleCounts),
	}
}

func buildLocaleChips(basePath string, state QueryState, counts map[string]int) []LocaleChip {
	locales := make([]string, 0, len(counts))
	for key := range counts {
		locales = append(locales, key)
	}
	sort.Strings(locales)

	chips := make([]LocaleChip, 0, len(locales)+1)
	total := 0
	for _, count := range counts {
		total += count
	}

	chips = append(chips, LocaleChip{
		Value:  "",
		Label:  fmt.Sprintf("すべて (%d)", total),
		Count:  total,
		Active: strings.TrimSpace(state.Locale) == "",
		URL:    buildQueryURL(basePath, state.RawQuery, "locale", ""),
	})

	for _, locale := range locales {
		chips = append(chips, LocaleChip{
			Value:  locale,
			Label:  localeLabel(locale),
			Count:  counts[locale],
			Active: strings.TrimSpace(state.Locale) == strings.TrimSpace(locale),
			URL:    buildQueryURL(basePath, state.RawQuery, "locale", locale),
		})
	}
	return chips
}

// FiltersPayload builds filter metadata.
func FiltersPayload(basePath string, state QueryState, feed admincontent.GuideFeed) FilterData {
	return FilterData{
		StatusSegments:  statusSegmentOptions(state.Status, feed.StatusCounts),
		PersonaOptions:  personaOptions(state.Persona, feed.PersonaCounts),
		CategoryOptions: categoryOptions(state.Category, feed.CategoryCounts),
		ScheduleValue:   state.ScheduleDate,
	}
}

func statusSegmentOptions(selected string, counts map[admincontent.GuideStatus]int) []SegmentOption {
	options := []SegmentOption{
		{Value: "", Label: fmt.Sprintf("すべて (%d)", totalStatus(counts))},
		{Value: string(admincontent.GuideStatusDraft), Label: fmt.Sprintf("下書き (%d)", counts[admincontent.GuideStatusDraft])},
		{Value: string(admincontent.GuideStatusScheduled), Label: fmt.Sprintf("公開予定 (%d)", counts[admincontent.GuideStatusScheduled])},
		{Value: string(admincontent.GuideStatusPublished), Label: fmt.Sprintf("公開中 (%d)", counts[admincontent.GuideStatusPublished])},
		{Value: string(admincontent.GuideStatusArchived), Label: fmt.Sprintf("アーカイブ (%d)", counts[admincontent.GuideStatusArchived])},
	}
	for idx := range options {
		options[idx].Active = strings.TrimSpace(options[idx].Value) == strings.TrimSpace(selected)
		options[idx].Count = deriveCountForOption(options[idx].Value, counts)
	}
	return options
}

func deriveCountForOption(value string, counts map[admincontent.GuideStatus]int) int {
	value = strings.TrimSpace(value)
	if value == "" {
		return totalStatus(counts)
	}
	return counts[admincontent.GuideStatus(value)]
}

func personaOptions(selected string, counts map[string]int) []SelectOption {
	personas := make([]string, 0, len(counts))
	for key := range counts {
		personas = append(personas, key)
	}
	sort.Strings(personas)

	options := []SelectOption{{Value: "", Label: "すべて", Count: totalIntMap(counts)}}
	for _, persona := range personas {
		options = append(options, SelectOption{
			Value:  persona,
			Label:  fmt.Sprintf("%s (%d)", personaLabel(persona), counts[persona]),
			Count:  counts[persona],
			Active: strings.TrimSpace(selected) == strings.TrimSpace(persona),
		})
	}
	for idx := range options {
		if strings.TrimSpace(options[idx].Value) == strings.TrimSpace(selected) {
			options[idx].Active = true
		}
	}
	return options
}

func categoryOptions(selected string, counts map[string]int) []SelectOption {
	categories := make([]string, 0, len(counts))
	for key := range counts {
		categories = append(categories, key)
	}
	sort.Strings(categories)

	options := []SelectOption{{Value: "", Label: "すべて", Count: totalIntMap(counts)}}
	for _, category := range categories {
		options = append(options, SelectOption{
			Value:  category,
			Label:  fmt.Sprintf("%s (%d)", categoryLabel(category), counts[category]),
			Count:  counts[category],
			Active: strings.TrimSpace(selected) == strings.TrimSpace(category),
		})
	}
	for idx := range options {
		if strings.TrimSpace(options[idx].Value) == strings.TrimSpace(selected) {
			options[idx].Active = true
		}
	}
	return options
}

// TablePayload builds table data.
func TablePayload(basePath string, state QueryState, feed admincontent.GuideFeed, selectedIDs []string) TableData {
	rows := make([]TableRow, 0, len(feed.Items))
	for _, guide := range feed.Items {
		rows = append(rows, toTableRow(basePath, guide))
	}

	selectedID := firstSelected(rows, selectedIDs)
	if selectedID == "" && len(rows) > 0 {
		selectedID = rows[0].ID
		rows[0].Selected = true
	}

	total := len(rows)
	data := TableData{
		Rows:         rows,
		Total:        total,
		SelectedID:   selectedID,
		Locale:       state.Locale,
		RawQuery:     state.RawQuery,
		FragmentPath: joinBase(basePath, "/content/guides/table"),
	}
	if total == 0 {
		data.EmptyMessage = "条件に一致するガイドはありません。"
	}
	data.Bulk = BulkPayload(basePath, state, data)
	return data
}

func firstSelected(rows []TableRow, selected []string) string {
	for idx := range rows {
		rows[idx].Selected = false
		clearRowSelection(&rows[idx])
	}
	if len(selected) > 0 {
		for _, candidate := range selected {
			for idx := range rows {
				if rows[idx].ID == candidate {
					rows[idx].Selected = true
					markRowSelected(&rows[idx])
					return candidate
				}
			}
		}
	}
	for idx := range rows {
		if rows[idx].Selected {
			markRowSelected(&rows[idx])
			return rows[idx].ID
		}
	}
	return ""
}

func toTableRow(basePath string, guide admincontent.Guide) TableRow {
	payload := encodeDrawerPayload(guide)
	attrs := templ.Attributes{
		"data-guide-row":     "true",
		"data-guide-id":      guide.ID,
		"data-guide-payload": payload,
	}

	row := TableRow{
		ID:              guide.ID,
		Title:           guide.Title,
		Summary:         guide.Summary,
		Locale:          guide.Locale,
		LocaleLabel:     localeLabel(guide.Locale),
		PersonaLabel:    personaLabel(guide.Persona),
		CategoryLabel:   categoryLabel(guide.Category),
		Author:          guide.Author,
		StatusLabel:     guide.StatusLabel,
		StatusTone:      guide.StatusTone,
		UpdatedRelative: helpers.Relative(guide.UpdatedAt),
		UpdatedTooltip:  helpers.Date(guide.UpdatedAt, "2006-01-02 15:04"),
		IsPublished:     guide.Status == admincontent.GuideStatusPublished,
		PublishURL:      joinBase(basePath, fmt.Sprintf("/content/guides/%s:publish", guide.ID)),
		UnpublishURL:    joinBase(basePath, fmt.Sprintf("/content/guides/%s:unpublish", guide.ID)),
		ScheduleURL:     joinBase(basePath, fmt.Sprintf("/content/guides/%s:schedule", guide.ID)),
		UnscheduleURL:   joinBase(basePath, fmt.Sprintf("/content/guides/%s:unschedule", guide.ID)),
		PreviewURL:      buildPreviewLocaleURL(basePath, guide.ID, guide.Locale),
		EditURL:         joinBase(basePath, fmt.Sprintf("/content/guides/%s/edit", guide.ID)),
		ViewURL:         joinBase("/", fmt.Sprintf("/guides/%s", guide.Slug)),
		Attributes:      attrs,
	}

	if guide.ScheduledAt != nil {
		row.ScheduledLabel = helpers.Date(*guide.ScheduledAt, "2006-01-02 15:04")
		row.ScheduledRelative = helpers.Relative(*guide.ScheduledAt)
		row.ScheduleInputValue = guide.ScheduledAt.In(time.Local).Format("2006-01-02T15:04")
		row.ScheduleHint = "公開予定日時を更新します。"
	} else {
		row.ScheduledLabel = "-"
		row.ScheduleInputValue = ""
		row.ScheduleHint = "公開日時を予約できます。"
	}
	row.Actions = []RowAction{
		{Label: "プレビュー", URL: row.PreviewURL, Icon: "🖥"},
		{Label: "編集", URL: row.EditURL, Icon: "✏️"},
		{Label: "公開ページ", URL: row.ViewURL, Icon: "🔗"},
	}
	return row
}

func clearRowSelection(row *TableRow) {
	if row == nil {
		return
	}
	if row.Attributes != nil {
		delete(row.Attributes, "data-selected")
	}
}

func markRowSelected(row *TableRow) {
	if row == nil {
		return
	}
	if row.Attributes == nil {
		row.Attributes = templ.Attributes{}
	}
	row.Attributes["data-selected"] = "true"
}

// DrawerPayload selects guide for drawer.
func DrawerPayload(feed admincontent.GuideFeed, selectedID string) DrawerData {
	if len(feed.Items) == 0 {
		return DrawerData{Empty: true}
	}
	selectedID = strings.TrimSpace(selectedID)
	var selected *admincontent.Guide
	if selectedID != "" {
		for idx := range feed.Items {
			if feed.Items[idx].ID == selectedID {
				selected = &feed.Items[idx]
				break
			}
		}
	}
	if selected == nil {
		selected = &feed.Items[0]
	}
	return toDrawerData(*selected)
}

func toDrawerData(guide admincontent.Guide) DrawerData {
	data := DrawerData{
		Empty:           false,
		ID:              guide.ID,
		Title:           guide.Title,
		Summary:         guide.Summary,
		StatusLabel:     guide.StatusLabel,
		StatusTone:      guide.StatusTone,
		LocaleLabel:     localeLabel(guide.Locale),
		PersonaLabel:    personaLabel(guide.Persona),
		Author:          guide.Author,
		HeroImageURL:    guide.HeroImageURL,
		UpdatedLabel:    helpers.Date(guide.UpdatedAt, "2006-01-02 15:04"),
		UpdatedRelative: helpers.Relative(guide.UpdatedAt),
		LastChangeNote:  guide.LastChangeNote,
		Tags:            append([]string(nil), guide.Tags...),
	}
	if guide.PublishedAt != nil {
		data.PublishedLabel = helpers.Date(*guide.PublishedAt, "2006-01-02 15:04")
	}
	if guide.ScheduledAt != nil {
		data.ScheduledLabel = helpers.Date(*guide.ScheduledAt, "2006-01-02 15:04")
	}
	data.Highlights = toDrawerHighlights(guide.Highlights)
	data.Timeline = toDrawerTimeline(guide.Upcoming)
	return data
}

func toDrawerHighlights(src []admincontent.GuideHighlight) []DrawerHighlight {
	if len(src) == 0 {
		return nil
	}
	result := make([]DrawerHighlight, 0, len(src))
	for _, highlight := range src {
		result = append(result, DrawerHighlight{
			Label: highlight.Label,
			Value: highlight.Value,
			Icon:  highlight.Icon,
			Tone:  highlight.Tone,
		})
	}
	return result
}

func toDrawerTimeline(events []admincontent.GuideChange) []DrawerTimeline {
	if len(events) == 0 {
		return nil
	}
	sort.Slice(events, func(i, j int) bool {
		return events[i].OccursAt.Before(events[j].OccursAt)
	})
	result := make([]DrawerTimeline, 0, len(events))
	for _, event := range events {
		result = append(result, DrawerTimeline{
			Title:       event.Title,
			Description: event.Description,
			OccursLabel: helpers.Date(event.OccursAt, "2006-01-02 15:04"),
			Relative:    helpers.Relative(event.OccursAt),
			Tone:        event.Tone,
			Icon:        event.Icon,
		})
	}
	return result
}

// BulkPayload builds bulk toolbar data.
func BulkPayload(basePath string, state QueryState, table TableData) BulkData {
	selectedCount := len(state.Selected)
	selectedIDs := append([]string(nil), state.Selected...)
	slices.Sort(selectedIDs)
	total := table.Total

	props := components.BulkToolbarProps{
		SelectedCount: selectedCount,
		TotalCount:    total,
		Message:       "",
		ClearAction: &components.BulkToolbarAction{
			Label: "選択をクリア",
			Component: templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
				_, err := fmt.Fprintf(w, `<button type="button" class="%s" data-guides-clear-selection>クリア</button>`, helpers.ButtonClass("ghost", "sm", false, false))
				return err
			}),
		},
	}
	props.Attrs = templ.Attributes{
		"data-guides-bulk-toolbar": "true",
		"data-total-count":         fmt.Sprintf("%d", total),
	}
	if selectedCount > 0 {
		props.Actions = []components.BulkToolbarAction{
			bulkActionButton("一括公開", "選択ガイドを公開します", joinBase(basePath, "/content/guides/bulk:publish"), "primary"),
			bulkActionButton("公開予定解除", "公開予定の設定をクリアします", joinBase(basePath, "/content/guides/bulk:unschedule"), "secondary"),
			bulkActionButton("アーカイブ", "選択ガイドをアーカイブします", joinBase(basePath, "/content/guides/bulk:archive"), "secondary"),
		}
	}

	progress := BulkProgress{
		Steps: []BulkProgressStep{
			{Label: "選択確認", Current: true},
			{Label: "処理中"},
			{Label: "完了"},
		},
		ActiveStep: 0,
	}

	return BulkData{
		SelectedIDs:   selectedIDs,
		SelectedCount: selectedCount,
		TotalCount:    total,
		Visible:       selectedCount > 0,
		Toolbar:       props,
		Progress:      progress,
	}
}

func bulkActionButton(label, description, actionURL, variant string) components.BulkToolbarAction {
	if variant == "" {
		variant = "secondary"
	}
	return components.BulkToolbarAction{
		Label:       label,
		Description: description,
		Component: templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
			buttonClass := helpers.ButtonClass(variant, "sm", false, false)
			_, err := fmt.Fprintf(w, `<button type="button" class="%s" data-guides-bulk-action data-action-url="%s">%s</button>`, buttonClass, actionURL, label)
			return err
		}),
	}
}

func encodeDrawerPayload(guide admincontent.Guide) string {
	payload := map[string]any{
		"id":          guide.ID,
		"title":       guide.Title,
		"summary":     guide.Summary,
		"statusLabel": guide.StatusLabel,
		"statusTone":  guide.StatusTone,
		"locale":      localeLabel(guide.Locale),
		"persona":     personaLabel(guide.Persona),
		"author":      guide.Author,
		"heroImage":   guide.HeroImageURL,
		"published":   nil,
		"scheduled":   nil,
		"updated": map[string]string{
			"label":    helpers.Date(guide.UpdatedAt, "2006-01-02 15:04"),
			"relative": helpers.Relative(guide.UpdatedAt),
		},
		"highlights": guide.Highlights,
		"timeline":   guide.Upcoming,
		"tags":       guide.Tags,
		"note":       guide.LastChangeNote,
	}
	if guide.PublishedAt != nil {
		payload["published"] = map[string]string{
			"label":    helpers.Date(*guide.PublishedAt, "2006-01-02 15:04"),
			"relative": helpers.Relative(*guide.PublishedAt),
		}
	}
	if guide.ScheduledAt != nil {
		payload["scheduled"] = map[string]string{
			"label":    helpers.Date(*guide.ScheduledAt, "2006-01-02 15:04"),
			"relative": helpers.Relative(*guide.ScheduledAt),
		}
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return "{}"
	}
	return string(data)
}

func buildPreviewLocaleOptions(basePath string, guideID string, locales []admincontent.GuideLocale) []PreviewLocaleOption {
	if len(locales) == 0 {
		return nil
	}
	options := make([]PreviewLocaleOption, 0, len(locales))
	for _, locale := range locales {
		options = append(options, PreviewLocaleOption{
			Value:  locale.Locale,
			Label:  locale.Label,
			URL:    buildPreviewLocaleURL(basePath, guideID, locale.Locale),
			Active: locale.Active,
		})
	}
	return options
}

func buildPreviewLocaleURL(basePath string, guideID string, locale string) string {
	path := fmt.Sprintf("/content/guides/%s/preview", guideID)
	trimmed := strings.TrimSpace(locale)
	if trimmed != "" {
		path = fmt.Sprintf("%s?lang=%s", path, url.QueryEscape(trimmed))
	}
	return joinBase(basePath, path)
}

func defaultPreviewDeviceModes() []PreviewDeviceMode {
	return []PreviewDeviceMode{
		{ID: "desktop", Label: "Desktop", Active: true},
		{ID: "tablet", Label: "Tablet", Active: false},
		{ID: "mobile", Label: "Mobile", Active: false},
	}
}

func buildPreviewTimeline(changes []admincontent.GuideChange) []PreviewTimelineItem {
	if len(changes) == 0 {
		return nil
	}
	result := make([]PreviewTimelineItem, 0, len(changes))
	for _, change := range changes {
		result = append(result, PreviewTimelineItem{
			Title:       change.Title,
			Description: change.Description,
			OccursLabel: helpers.Date(change.OccursAt, "2006-01-02 15:04"),
			Relative:    helpers.Relative(change.OccursAt),
			Tone:        change.Tone,
			Icon:        change.Icon,
		})
	}
	return result
}

func estimateReadingFallback(wordCount int) string {
	if wordCount <= 0 {
		return ""
	}
	minutes := wordCount / 280
	if minutes < 1 {
		minutes = 1
	}
	return fmt.Sprintf("%d分想定", minutes)
}

func timestampOrPlaceholder(ts *time.Time) string {
	if ts == nil || ts.IsZero() {
		return "—"
	}
	return helpers.Date(ts.In(time.Local), "2006-01-02 15:04")
}

func joinTags(tags []string) string {
	if len(tags) == 0 {
		return ""
	}
	clean := make([]string, 0, len(tags))
	for _, tag := range tags {
		if trimmed := strings.TrimSpace(tag); trimmed != "" {
			clean = append(clean, trimmed)
		}
	}
	return strings.Join(clean, ", ")
}

func cloneStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	dup := make([]string, len(values))
	copy(dup, values)
	return dup
}

func firstNonEmpty(values ...string) string {
	return coalesce(values...)
}

func coalesce(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func htmlComponent(value string) templ.Component {
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		_, err := io.WriteString(w, value)
		return err
	})
}

func totalStatus(counts map[admincontent.GuideStatus]int) int {
	total := 0
	for _, count := range counts {
		total += count
	}
	return total
}

func totalIntMap(counts map[string]int) int {
	total := 0
	for _, count := range counts {
		total += count
	}
	return total
}

func localeLabel(locale string) string {
	switch strings.ToLower(strings.TrimSpace(locale)) {
	case "ja-jp":
		return "日本語"
	case "en-us":
		return "English (US)"
	case "en-gb":
		return "English (UK)"
	case "zh-cn":
		return "简体中文"
	default:
		return locale
	}
}

func personaLabel(persona string) string {
	switch strings.TrimSpace(persona) {
	case "newcomer":
		return "新規ユーザー"
	case "artisan":
		return "工房スタッフ"
	case "operator":
		return "オペレーター"
	case "marketer":
		return "マーケター"
	default:
		return persona
	}
}

func categoryLabel(category string) string {
	switch strings.TrimSpace(category) {
	case "basics":
		return "基本"
	case "operations":
		return "オペレーション"
	case "marketing":
		return "マーケティング"
	default:
		return category
	}
}

func buildQueryURL(basePath, rawQuery, key, value string) string {
	updated := helpers.SetRawQuery(rawQuery, key, value)
	if value == "" {
		updated = helpers.DelRawQuery(updated, key)
	}
	path := joinBase(basePath, "/content/guides")
	if updated == "" {
		return path
	}
	return fmt.Sprintf("%s?%s", path, updated)
}

func joinBase(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" || base == "/" {
		base = ""
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	path := base + suffix
	for strings.Contains(path, "//") {
		path = strings.ReplaceAll(path, "//", "/")
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	return path
}
