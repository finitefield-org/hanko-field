package content

import (
	"context"
	"fmt"
	"html"
	"sort"
	"strings"
	"time"
)

// PageStatus enumerates lifecycle states for pages.
type PageStatus string

const (
	// PageStatusDraft indicates the page is a draft.
	PageStatusDraft PageStatus = "draft"
	// PageStatusScheduled indicates the page has a future publish window.
	PageStatusScheduled PageStatus = "scheduled"
	// PageStatusPublished indicates the page is live.
	PageStatusPublished PageStatus = "published"
	// PageStatusArchived marks the page as archived.
	PageStatusArchived PageStatus = "archived"
)

// Page represents a localized content page.
type Page struct {
	ID           string
	Slug         string
	Locale       string
	Title        string
	Type         string
	Summary      string
	Tags         []string
	Status       PageStatus
	StatusLabel  string
	StatusTone   string
	PublishedAt  *time.Time
	ScheduledAt  *time.Time
	UpdatedAt    time.Time
	UpdatedBy    string
	Version      string
	Editor       string
	Navigation   []string
	DefaultShare string
}

// PageSummaryCounts aggregates totals for summary chips.
type PageSummaryCounts struct {
	Total     int
	Published int
	Draft     int
	Scheduled int
	Archived  int
}

// PageQuery captures filters when listing pages.
type PageQuery struct {
	Search     string
	Type       string
	Status     PageStatus
	Locale     string
	SelectedID string
}

// PageTree represents the hierarchical view for page navigation.
type PageTree struct {
	Nodes        []PageNode
	Counts       PageSummaryCounts
	StatusCounts map[PageStatus]int
	TypeCounts   map[string]int
	LocaleCounts map[string]int
	Total        int
	ActiveID     string
}

// PageNode represents a single navigation entry.
type PageNode struct {
	ID              string
	Title           string
	Subtitle        string
	Slug            string
	Locale          string
	Type            string
	StatusLabel     string
	StatusTone      string
	UpdatedAt       time.Time
	UpdatedRelative string
	Selected        bool
	Leaf            bool
	Icon            string
	Children        []PageNode
}

// PageDraft represents the editable fields for a page.
type PageDraft struct {
	Locale      string
	Title       string
	Summary     string
	Outline     string
	Blocks      []PageDraftBlock
	SEO         PageSEO
	Tags        []string
	LastSavedAt time.Time
	LastSavedBy string
}

// PageDraftBlock captures a block entry within the block editor.
type PageDraftBlock struct {
	ID          string
	Type        string
	Label       string
	Icon        string
	Summary     string
	Description string
	Handle      string
	Locked      bool
}

// PageSEO encapsulates SEO metadata fields.
type PageSEO struct {
	MetaTitle       string
	MetaDescription string
	OGImageURL      string
	CanonicalURL    string
}

// PageProperties powers the properties side panel.
type PageProperties struct {
	Slug            string
	Type            string
	Tags            []string
	SEO             PageSEO
	LiveURL         string
	PreviewURL      string
	ShareURL        string
	LastPublishedAt *time.Time
	LastPublishedBy string
	Version         string
	VisibilityLabel string
	VisibilityTone  string
	Breadcrumbs     []string
}

// PageSchedule represents scheduling metadata.
type PageSchedule struct {
	ScheduledAt     *time.Time
	WindowLabel     string
	TimezoneLabel   string
	LastScheduledBy string
	LastScheduledAt *time.Time
	StatusLabel     string
	StatusTone      string
}

// PageHistoryEntry records a previous version entry.
type PageHistoryEntry struct {
	ID         string
	Title      string
	Summary    string
	Actor      string
	Version    string
	OccurredAt time.Time
	Tone       string
	Icon       string
}

// PageEditor bundles data necessary for the editor workspace.
type PageEditor struct {
	Page         Page
	Draft        PageDraft
	Properties   PageProperties
	Schedule     PageSchedule
	Locales      []PageLocale
	BlockPalette []PageBlockPaletteGroup
	History      []PageHistoryEntry
}

// PageBlockPaletteGroup groups available blocks for insertion.
type PageBlockPaletteGroup struct {
	Label  string
	Blocks []PageBlockPaletteItem
}

// PageBlockPaletteItem represents a block available for insertion.
type PageBlockPaletteItem struct {
	Type        string
	Label       string
	Description string
	Icon        string
}

// PageLocale represents a selectable locale for a page.
type PageLocale struct {
	Locale   string
	Label    string
	Active   bool
	Fallback bool
}

// PagePreview contains the rendered preview payload.
type PagePreview struct {
	Page        Page
	Locales     []PageLocale
	ShareURL    string
	ExternalURL string
	Content     PagePreviewContent
	Notes       []string
	SEO         PageSEO
}

// PagePreviewContent holds rendered HTML for previewing drafts.
type PagePreviewContent struct {
	HeroHTML string
	BodyHTML string
}

// PageDraftInput captures values submitted from the editor for draft persistence or preview.
type PageDraftInput struct {
	Locale          string
	Title           string
	Summary         string
	Outline         string
	Tags            []string
	MetaTitle       string
	MetaDescription string
	OGImageURL      string
	CanonicalURL    string
}

type pagePreviewEntry struct {
	HeroHTML    string
	BodyHTML    string
	Notes       []string
	ShareURL    string
	ExternalURL string
	SEO         PageSEO
}

type pageTreeNodeDef struct {
	ID       string
	Title    string
	Subtitle string
	ParentID string
	PageID   string
	Icon     string
	Order    int
}

type pageStaticDataset struct {
	pages      []Page
	drafts     map[string]PageDraft
	previews   map[string]pagePreviewEntry
	locales    map[string][]PageLocale
	properties map[string]PageProperties
	schedules  map[string]PageSchedule
	history    map[string][]PageHistoryEntry
	palette    []PageBlockPaletteGroup
	structure  []pageTreeNodeDef
}

// ListPages implements Service.
func (s *StaticService) ListPages(_ context.Context, _ string, query PageQuery) (PageTree, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.buildPageTreeLocked(query), nil
}

// PageEditor implements Service.
func (s *StaticService) PageEditor(_ context.Context, _ string, pageID string) (PageEditor, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	idx := s.pageIndexLocked(pageID)
	if idx < 0 {
		return PageEditor{}, ErrPageNotFound
	}

	page := clonePage(s.pages[idx])
	draft := clonePageDraft(s.pageDrafts[pageID])
	props := clonePageProperties(s.pageProperties[pageID])
	schedule := clonePageSchedule(s.pageSchedules[pageID])
	history := clonePageHistory(s.pageHistory[pageID])
	palette := clonePagePalette(s.pagePalette)

	locales := clonePageLocales(s.pageLocales[page.Slug])
	for i := range locales {
		locales[i].Active = strings.EqualFold(locales[i].Locale, page.Locale)
	}

	return PageEditor{
		Page:         page,
		Draft:        draft,
		Properties:   props,
		Schedule:     schedule,
		Locales:      locales,
		BlockPalette: palette,
		History:      history,
	}, nil
}

// PagePreview implements Service.
func (s *StaticService) PagePreview(_ context.Context, _ string, pageID string, locale string) (PagePreview, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	idx := s.pageIndexLocked(pageID)
	if idx < 0 {
		return PagePreview{}, ErrPageNotFound
	}
	page := clonePage(s.pages[idx])

	activeLocale := strings.TrimSpace(locale)
	if activeLocale == "" {
		activeLocale = page.Locale
	}
	pageForLocale := page
	for _, candidate := range s.pages {
		if candidate.Slug == page.Slug && strings.EqualFold(candidate.Locale, activeLocale) {
			pageForLocale = clonePage(candidate)
			break
		}
	}

	entry, ok := s.pagePreviews[previewKey(page.Slug, pageForLocale.Locale)]
	if !ok {
		entry = pagePreviewEntry{
			BodyHTML: renderDefaultPageBody(pageForLocale, s.pageDrafts[pageForLocale.ID]),
			SEO:      s.pageProperties[pageForLocale.ID].SEO,
		}
	}

	locales := clonePageLocales(s.pageLocales[page.Slug])
	for i := range locales {
		locales[i].Active = strings.EqualFold(locales[i].Locale, pageForLocale.Locale)
	}

	hero := sanitizeMarkup(entry.HeroHTML)
	body := sanitizeMarkup(entry.BodyHTML)

	return PagePreview{
		Page:        pageForLocale,
		Locales:     locales,
		ShareURL:    entry.ShareURL,
		ExternalURL: entry.ExternalURL,
		Content: PagePreviewContent{
			HeroHTML: hero,
			BodyHTML: body,
		},
		Notes: entry.Notes,
		SEO:   entry.SEO,
	}, nil
}

// PagePreviewDraft implements Service.
func (s *StaticService) PagePreviewDraft(_ context.Context, _ string, pageID string, input PageDraftInput) (PagePreview, error) {
	s.mu.RLock()
	idx := s.pageIndexLocked(pageID)
	if idx < 0 {
		s.mu.RUnlock()
		return PagePreview{}, ErrPageNotFound
	}

	page := clonePage(s.pages[idx])
	baseDraft := clonePageDraft(s.pageDrafts[pageID])
	baseLocales := clonePageLocales(s.pageLocales[page.Slug])
	basePreview := s.pagePreviews[previewKey(page.Slug, page.Locale)]
	s.mu.RUnlock()

	draft := mergePageDraftInput(baseDraft, input)

	locales := baseLocales
	activeLocale := draft.Locale
	if activeLocale == "" {
		activeLocale = page.Locale
	}
	for i := range locales {
		locales[i].Active = strings.EqualFold(locales[i].Locale, activeLocale)
	}

	page.Locale = activeLocale
	page.Title = draft.Title
	page.Summary = draft.Summary
	page.Tags = append([]string(nil), draft.Tags...)
	page.StatusLabel, page.StatusTone = pageStatusPresentation(page.Status)
	page.UpdatedAt = time.Now()
	page.UpdatedBy = "Draft Preview"

	body := sanitizeMarkup(renderDraftPreviewBody(draft))
	hero := sanitizeMarkup(renderDraftHero(draft))

	seo := draft.SEO
	if seo.MetaTitle == "" {
		seo.MetaTitle = page.Title
	}
	if seo.MetaDescription == "" {
		seo.MetaDescription = page.Summary
	}
	if seo.OGImageURL == "" {
		seo.OGImageURL = basePreview.SEO.OGImageURL
	}
	if seo.CanonicalURL == "" {
		seo.CanonicalURL = basePreview.SEO.CanonicalURL
	}

	return PagePreview{
		Page:    page,
		Locales: locales,
		ShareURL: func() string {
			if basePreview.ShareURL != "" {
				return basePreview.ShareURL + "&draft=1"
			}
			return fmt.Sprintf("https://preview.hanko.example/pages/%s?lang=%s&draft=1", page.Slug, page.Locale)
		}(),
		ExternalURL: basePreview.ExternalURL,
		Content:     PagePreviewContent{HeroHTML: hero, BodyHTML: body},
		SEO:         seo,
		Notes:       append([]string(nil), basePreview.Notes...),
	}, nil
}

// PageSaveDraft implements Service.
func (s *StaticService) PageSaveDraft(_ context.Context, _ string, pageID string, input PageDraftInput) (PageDraft, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	idx := s.pageIndexLocked(pageID)
	if idx < 0 {
		return PageDraft{}, ErrPageNotFound
	}

	draft := mergePageDraftInput(s.pageDrafts[pageID], input)
	now := time.Now()
	draft.LastSavedAt = now
	draft.LastSavedBy = "自分"
	if draft.Locale == "" {
		draft.Locale = s.pages[idx].Locale
	}
	s.pageDrafts[pageID] = draft

	page := s.pages[idx]
	if strings.TrimSpace(draft.Title) != "" {
		page.Title = draft.Title
	}
	if strings.TrimSpace(draft.Summary) != "" {
		page.Summary = draft.Summary
	}
	if len(draft.Tags) > 0 {
		page.Tags = append([]string(nil), draft.Tags...)
	}
	page.UpdatedAt = now
	page.UpdatedBy = "自分"
	page.StatusLabel, page.StatusTone = pageStatusPresentation(page.Status)
	s.pages[idx] = page

	props := s.pageProperties[pageID]
	if strings.TrimSpace(input.MetaTitle) != "" || strings.TrimSpace(input.MetaDescription) != "" || strings.TrimSpace(input.OGImageURL) != "" {
		props.SEO = draft.SEO
	}
	if len(draft.Tags) > 0 {
		props.Tags = append([]string(nil), draft.Tags...)
	}
	s.pageProperties[pageID] = props

	return clonePageDraft(draft), nil
}

// PageTogglePublish implements Service.
func (s *StaticService) PageTogglePublish(_ context.Context, _ string, pageID string, publish bool) (Page, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	idx := s.pageIndexLocked(pageID)
	if idx < 0 {
		return Page{}, ErrPageNotFound
	}

	page := s.pages[idx]
	now := time.Now()
	if publish {
		page.Status = PageStatusPublished
		page.PublishedAt = timePtr(now)
		page.ScheduledAt = nil
		page.UpdatedBy = "自分"
	} else {
		page.Status = PageStatusDraft
		page.PublishedAt = nil
		page.UpdatedBy = "自分"
	}
	page.StatusLabel, page.StatusTone = pageStatusPresentation(page.Status)
	page.UpdatedAt = now
	s.pages[idx] = page

	props := s.pageProperties[pageID]
	if publish {
		props.LastPublishedAt = timePtr(now)
		props.LastPublishedBy = "自分"
		props.VisibilityLabel = "公開中"
		props.VisibilityTone = "success"
	} else {
		props.VisibilityLabel = "下書き"
		props.VisibilityTone = ""
	}
	s.pageProperties[pageID] = props

	sched := s.pageSchedules[pageID]
	if !publish && page.Status != PageStatusScheduled {
		sched.ScheduledAt = nil
		sched.StatusLabel = "未設定"
		sched.StatusTone = ""
	}
	s.pageSchedules[pageID] = sched

	return clonePage(page), nil
}

// PageSchedule implements Service.
func (s *StaticService) PageSchedule(_ context.Context, _ string, pageID string, scheduledAt *time.Time) (Page, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	idx := s.pageIndexLocked(pageID)
	if idx < 0 {
		return Page{}, ErrPageNotFound
	}

	page := s.pages[idx]
	now := time.Now()
	sched := s.pageSchedules[pageID]

	if scheduledAt != nil && !scheduledAt.IsZero() {
		local := scheduledAt.In(time.Local)
		page.Status = PageStatusScheduled
		page.ScheduledAt = timePtr(local)
		page.UpdatedAt = now
		page.UpdatedBy = "自動公開"
		page.StatusLabel, page.StatusTone = pageStatusPresentation(page.Status)

		sched.ScheduledAt = timePtr(local)
		sched.WindowLabel = local.Format("2006-01-02 15:04")
		sched.TimezoneLabel = local.Format("MST")
		sched.LastScheduledBy = "自分"
		sched.LastScheduledAt = timePtr(now)
		sched.StatusLabel = "公開予定"
		sched.StatusTone = "warning"
	} else {
		page.ScheduledAt = nil
		if page.Status == PageStatusScheduled {
			page.Status = PageStatusDraft
		}
		page.StatusLabel, page.StatusTone = pageStatusPresentation(page.Status)
		page.UpdatedAt = now
		page.UpdatedBy = "自分"

		sched.ScheduledAt = nil
		sched.WindowLabel = ""
		sched.StatusLabel = "未設定"
		sched.StatusTone = ""
	}

	s.pages[idx] = page
	s.pageSchedules[pageID] = sched
	return clonePage(page), nil
}

func (s *StaticService) buildPageTreeLocked(query PageQuery) PageTree {
	counts, statusCounts, typeCounts, localeCounts := aggregatePages(s.pages)

	filtered := make(map[string]bool, len(s.pages))
	search := strings.ToLower(strings.TrimSpace(query.Search))
	for _, page := range s.pages {
		if pageMatchesQuery(page, query, search) {
			filtered[page.ID] = true
		}
	}
	if query.SelectedID != "" {
		filtered[query.SelectedID] = true
	}

	nodes := buildTreeNodes(s.pageStructure, s.pages, filtered)

	activeID := query.SelectedID
	if activeID == "" && len(nodes) > 0 {
		activeID = findFirstPageNode(nodes)
	}

	markSelected(nodes, activeID)

	return PageTree{
		Nodes:        nodes,
		Counts:       counts,
		StatusCounts: statusCounts,
		TypeCounts:   typeCounts,
		LocaleCounts: localeCounts,
		Total:        counts.Total,
		ActiveID:     activeID,
	}
}

func buildTreeNodes(defs []pageTreeNodeDef, pages []Page, allowed map[string]bool) []PageNode {
	index := make(map[string]*PageNode, len(defs))
	children := make(map[string][]*PageNode)

	pageIndex := make(map[string]Page, len(pages))
	for _, page := range pages {
		pageIndex[page.ID] = page
	}

	for _, def := range defs {
		node := PageNode{
			ID:       def.ID,
			Title:    def.Title,
			Subtitle: def.Subtitle,
			Icon:     def.Icon,
		}
		if def.PageID != "" {
			if _, ok := allowed[def.PageID]; !ok {
				continue
			}
			if page, exists := pageIndex[def.PageID]; exists {
				node.Leaf = true
				node.Slug = page.Slug
				node.Locale = page.Locale
				node.Type = page.Type
				node.StatusLabel = page.StatusLabel
				node.StatusTone = page.StatusTone
				node.UpdatedAt = page.UpdatedAt
				node.UpdatedRelative = relative(page.UpdatedAt)
				if node.Title == "" {
					node.Title = page.Title
				}
				if node.Subtitle == "" {
					node.Subtitle = strings.ToUpper(page.Locale)
				}
			}
		}

		index[def.ID] = &node
		children[def.ParentID] = append(children[def.ParentID], &node)
	}

	var assemble func(parentID string) []PageNode
	assemble = func(parentID string) []PageNode {
		nodes := children[parentID]
		sort.Slice(nodes, func(i, j int) bool {
			di := findDef(defs, nodes[i].ID)
			dj := findDef(defs, nodes[j].ID)
			if di.Order == dj.Order {
				return nodes[i].Title < nodes[j].Title
			}
			return di.Order < dj.Order
		})

		result := make([]PageNode, 0, len(nodes))
		for _, child := range nodes {
			cloned := *child
			cloned.Children = assemble(child.ID)
			if child.Leaf || len(cloned.Children) > 0 {
				result = append(result, cloned)
			}
		}
		return result
	}

	return assemble("")
}

func findDef(defs []pageTreeNodeDef, id string) pageTreeNodeDef {
	for _, def := range defs {
		if def.ID == id {
			return def
		}
	}
	return pageTreeNodeDef{}
}

func markSelected(nodes []PageNode, activeID string) bool {
	found := false
	for i := range nodes {
		selected := nodes[i].ID == activeID || nodes[i].Slug == activeID
		if len(nodes[i].Children) > 0 {
			if markSelected(nodes[i].Children, activeID) {
				selected = true
			}
		}
		nodes[i].Selected = selected
		if selected {
			found = true
		}
	}
	return found
}

func findFirstPageNode(nodes []PageNode) string {
	for _, node := range nodes {
		if node.Leaf && node.ID != "" {
			return node.ID
		}
		if len(node.Children) > 0 {
			if id := findFirstPageNode(node.Children); id != "" {
				return id
			}
		}
	}
	return ""
}

func aggregatePages(pages []Page) (PageSummaryCounts, map[PageStatus]int, map[string]int, map[string]int) {
	counts := PageSummaryCounts{}
	statusCounts := make(map[PageStatus]int)
	typeCounts := make(map[string]int)
	localeCounts := make(map[string]int)

	for _, page := range pages {
		counts.Total++
		statusCounts[page.Status]++
		typeCounts[page.Type]++
		localeCounts[page.Locale]++

		switch page.Status {
		case PageStatusDraft:
			counts.Draft++
		case PageStatusPublished:
			counts.Published++
		case PageStatusScheduled:
			counts.Scheduled++
		case PageStatusArchived:
			counts.Archived++
		}
	}
	return counts, statusCounts, typeCounts, localeCounts
}

func pageMatchesQuery(page Page, query PageQuery, normalizedSearch string) bool {
	if query.Status != "" && page.Status != query.Status {
		return false
	}
	if query.Type != "" && !strings.EqualFold(page.Type, query.Type) {
		return false
	}
	if query.Locale != "" && !strings.EqualFold(page.Locale, query.Locale) {
		return false
	}
	if normalizedSearch != "" {
		title := strings.ToLower(page.Title)
		slug := strings.ToLower(page.Slug)
		summary := strings.ToLower(page.Summary)
		if !strings.Contains(title, normalizedSearch) &&
			!strings.Contains(slug, normalizedSearch) &&
			!strings.Contains(summary, normalizedSearch) {
			return false
		}
	}
	return true
}

func mergePageDraftInput(draft PageDraft, input PageDraftInput) PageDraft {
	if input.Locale != "" {
		draft.Locale = input.Locale
	}
	if strings.TrimSpace(input.Title) != "" {
		draft.Title = strings.TrimSpace(input.Title)
	}
	if strings.TrimSpace(input.Summary) != "" {
		draft.Summary = strings.TrimSpace(input.Summary)
	}
	if strings.TrimSpace(input.Outline) != "" {
		draft.Outline = strings.TrimSpace(input.Outline)
	}
	if input.Tags != nil {
		draft.Tags = append([]string(nil), input.Tags...)
	}
	if strings.TrimSpace(input.MetaTitle) != "" || strings.TrimSpace(input.MetaDescription) != "" || strings.TrimSpace(input.OGImageURL) != "" || strings.TrimSpace(input.CanonicalURL) != "" {
		draft.SEO.MetaTitle = strings.TrimSpace(input.MetaTitle)
		draft.SEO.MetaDescription = strings.TrimSpace(input.MetaDescription)
		draft.SEO.OGImageURL = strings.TrimSpace(input.OGImageURL)
		draft.SEO.CanonicalURL = strings.TrimSpace(input.CanonicalURL)
	}
	return draft
}

func renderDraftHero(draft PageDraft) string {
	title := html.EscapeString(draft.Title)
	if title == "" {
		title = "プレビューページ"
	}
	var sb strings.Builder
	sb.WriteString(`<section class="hero bg-slate-900 text-white rounded-3xl px-8 py-12 shadow-lg"><div class="max-w-3xl space-y-4">`)
	sb.WriteString(fmt.Sprintf("<h1 class=\"text-3xl font-semibold\">%s</h1>", title))
	if draft.Summary != "" {
		sb.WriteString(fmt.Sprintf("<p class=\"text-lg text-slate-200\">%s</p>", html.EscapeString(draft.Summary)))
	}
	sb.WriteString(`<div class="flex flex-wrap gap-3 text-sm text-slate-200">`)
	for _, tag := range draft.Tags {
		sb.WriteString(fmt.Sprintf("<span class=\"rounded-full bg-slate-800 px-3 py-1\">#%s</span>", html.EscapeString(tag)))
	}
	sb.WriteString("</div></div></section>")
	return sb.String()
}

func renderDraftPreviewBody(draft PageDraft) string {
	var sb strings.Builder
	sb.WriteString(`<article class="prose prose-slate max-w-none space-y-8">`)
	if draft.Outline != "" {
		sb.WriteString(fmt.Sprintf("<p class=\"lead\">%s</p>", html.EscapeString(draft.Outline)))
	}
	if len(draft.Blocks) > 0 {
		for _, block := range draft.Blocks {
			sb.WriteString(`<section class="not-prose rounded-xl border border-slate-200 bg-white p-6 shadow-sm">`)
			sb.WriteString(fmt.Sprintf("<h2 class=\"text-xl font-semibold text-slate-900\">%s</h2>", html.EscapeString(block.Label)))
			if block.Summary != "" {
				sb.WriteString(fmt.Sprintf("<p class=\"mt-2 text-slate-600\">%s</p>", html.EscapeString(block.Summary)))
			}
			if block.Description != "" {
				sb.WriteString(fmt.Sprintf("<p class=\"mt-1 text-slate-500 text-sm\">%s</p>", html.EscapeString(block.Description)))
			}
			sb.WriteString("</section>")
		}
	} else {
		sb.WriteString(`<section class="rounded-xl border border-dashed border-slate-300 p-6 text-center text-slate-500">`)
		sb.WriteString("ブロックを追加するとここに内容がプレビューされます。")
		sb.WriteString("</section>")
	}
	sb.WriteString("</article>")
	return sb.String()
}

func renderDefaultPageBody(page Page, draft PageDraft) string {
	if strings.TrimSpace(page.ID) == "" {
		return ""
	}
	copyDraft := draft
	if copyDraft.Title == "" {
		copyDraft.Title = page.Title
	}
	if copyDraft.Summary == "" {
		copyDraft.Summary = page.Summary
	}
	if len(copyDraft.Blocks) == 0 {
		copyDraft.Blocks = []PageDraftBlock{
			{
				ID:      "block-overview",
				Type:    "section",
				Label:   "概要",
				Summary: "最新の製品アップデートと会社情報を紹介します。",
			},
		}
	}
	return renderDraftPreviewBody(copyDraft)
}

func clonePage(page Page) Page {
	cloned := page
	if len(page.Tags) > 0 {
		cloned.Tags = append([]string(nil), page.Tags...)
	}
	if len(page.Navigation) > 0 {
		cloned.Navigation = append([]string(nil), page.Navigation...)
	}
	return cloned
}

func clonePageDraft(draft PageDraft) PageDraft {
	cloned := draft
	if len(draft.Blocks) > 0 {
		cloned.Blocks = make([]PageDraftBlock, len(draft.Blocks))
		copy(cloned.Blocks, draft.Blocks)
	}
	if len(draft.Tags) > 0 {
		cloned.Tags = append([]string(nil), draft.Tags...)
	}
	return cloned
}

func clonePageProperties(props PageProperties) PageProperties {
	cloned := props
	if len(props.Tags) > 0 {
		cloned.Tags = append([]string(nil), props.Tags...)
	}
	if len(props.Breadcrumbs) > 0 {
		cloned.Breadcrumbs = append([]string(nil), props.Breadcrumbs...)
	}
	return cloned
}

func clonePageSchedule(schedule PageSchedule) PageSchedule {
	return schedule
}

func clonePageHistory(entries []PageHistoryEntry) []PageHistoryEntry {
	if len(entries) == 0 {
		return nil
	}
	cloned := make([]PageHistoryEntry, len(entries))
	copy(cloned, entries)
	return cloned
}

func clonePagePalette(groups []PageBlockPaletteGroup) []PageBlockPaletteGroup {
	if len(groups) == 0 {
		return nil
	}
	cloned := make([]PageBlockPaletteGroup, len(groups))
	for i, group := range groups {
		cloned[i].Label = group.Label
		if len(group.Blocks) > 0 {
			cloned[i].Blocks = make([]PageBlockPaletteItem, len(group.Blocks))
			copy(cloned[i].Blocks, group.Blocks)
		}
	}
	return cloned
}

func clonePageLocales(locales []PageLocale) []PageLocale {
	if len(locales) == 0 {
		return nil
	}
	cloned := make([]PageLocale, len(locales))
	copy(cloned, locales)
	return cloned
}

func (s *StaticService) pageIndexLocked(id string) int {
	for i, page := range s.pages {
		if page.ID == id {
			return i
		}
	}
	return -1
}

func pageStatusPresentation(status PageStatus) (string, string) {
	switch status {
	case PageStatusPublished:
		return "公開中", "success"
	case PageStatusScheduled:
		return "公開予定", "warning"
	case PageStatusArchived:
		return "アーカイブ", "muted"
	default:
		return "下書き", ""
	}
}

func buildStaticPages(now time.Time) pageStaticDataset {
	inHours := func(h int) *time.Time {
		ts := now.Add(time.Duration(h) * time.Hour)
		return &ts
	}

	makePage := func(base Page) Page {
		if strings.TrimSpace(base.ID) == "" {
			base.ID = fmt.Sprintf("page-%s-%s", strings.ReplaceAll(base.Slug, "/", "-"), strings.ToLower(strings.ReplaceAll(base.Locale, " ", "")))
		}
		if base.Status == "" {
			base.Status = PageStatusDraft
		}
		base.StatusLabel, base.StatusTone = pageStatusPresentation(base.Status)
		if base.UpdatedAt.IsZero() {
			base.UpdatedAt = now.Add(-3 * time.Hour)
		}
		if base.UpdatedBy == "" {
			base.UpdatedBy = "中村 麻衣"
		}
		return base
	}

	pages := []Page{
		makePage(Page{
			ID:          "page-about-ja",
			Slug:        "about",
			Locale:      "ja-JP",
			Title:       "会社概要",
			Type:        "landing",
			Status:      PageStatusPublished,
			PublishedAt: inHours(-72),
			UpdatedAt:   now.Add(-6 * time.Hour),
			UpdatedBy:   "松本 彩",
			Version:     "v2.3.0",
			Summary:     "ハンコフィールドのミッションとプロダクト戦略を紹介します。",
			Tags:        []string{"会社情報", "ブランド"},
			Navigation:  []string{"コンテンツ", "会社情報"},
		}),
		makePage(Page{
			ID:         "page-about-en",
			Slug:       "about",
			Locale:     "en-US",
			Title:      "About Hanko Field",
			Type:       "landing",
			Status:     PageStatusDraft,
			UpdatedAt:  now.Add(-2 * time.Hour),
			UpdatedBy:  "Hannah Ito",
			Version:    "v2.3.0-draft",
			Summary:    "Overview of Hanko Field in English, pending localization review.",
			Tags:       []string{"company", "brand"},
			Navigation: []string{"Content", "Company"},
		}),
		makePage(Page{
			ID:          "page-privacy-ja",
			Slug:        "legal/privacy-policy",
			Locale:      "ja-JP",
			Title:       "プライバシーポリシー",
			Type:        "legal",
			Status:      PageStatusPublished,
			PublishedAt: inHours(-240),
			UpdatedAt:   now.Add(-36 * time.Hour),
			UpdatedBy:   "法務チーム",
			Version:     "2024.12",
			Summary:     "個人情報保護と利用目的に関する最新の合意事項。",
			Tags:        []string{"法務", "規約"},
			Navigation:  []string{"コンテンツ", "法務"},
		}),
		makePage(Page{
			ID:          "page-privacy-en",
			Slug:        "legal/privacy-policy",
			Locale:      "en-US",
			Title:       "Privacy Policy",
			Type:        "legal",
			Status:      PageStatusScheduled,
			ScheduledAt: inHours(24),
			UpdatedAt:   now.Add(-10 * time.Hour),
			UpdatedBy:   "Legal Ops",
			Version:     "2024.12-en",
			Summary:     "English privacy policy scheduled for launch with new compliance notes.",
			Tags:        []string{"legal", "gdpr"},
			Navigation:  []string{"Content", "Legal"},
		}),
		makePage(Page{
			ID:         "page-pricing-ja",
			Slug:       "pricing",
			Locale:     "ja-JP",
			Title:      "料金プラン",
			Type:       "landing",
			Status:     PageStatusDraft,
			UpdatedAt:  now.Add(-12 * time.Hour),
			UpdatedBy:  "佐藤 未来",
			Version:    "v1.1.0-draft",
			Summary:    "最新の料金構成とキャンペーン情報。",
			Tags:       []string{"料金", "キャンペーン"},
			Navigation: []string{"コンテンツ", "会社情報"},
		}),
		makePage(Page{
			ID:          "page-status-ja",
			Slug:        "status",
			Locale:      "ja-JP",
			Title:       "システム稼働状況",
			Type:        "system",
			Status:      PageStatusPublished,
			PublishedAt: inHours(-12),
			UpdatedAt:   now.Add(-1 * time.Hour),
			UpdatedBy:   "SRE Team",
			Version:     "v0.9.4",
			Summary:     "リアルタイムのステータス更新とメンテナンス予定。",
			Tags:        []string{"ステータス", "SRE"},
			Navigation:  []string{"コンテンツ", "ステータス"},
		}),
	}

	drafts := map[string]PageDraft{
		"page-about-ja": {
			Locale:  "ja-JP",
			Title:   "会社概要",
			Summary: "ハンコフィールドのミッションと沿革を紹介します。",
			Outline: "工房ネットワークとテクノロジーによる新しいハンコ体験を提供。",
			Blocks: []PageDraftBlock{
				{ID: "hero", Type: "hero", Label: "ヒーロー", Icon: "🌅", Summary: "ミッションを伝えるヒーローセクション"},
				{ID: "history", Type: "timeline", Label: "沿革", Icon: "🕰", Summary: "創業から現在までのストーリー"},
				{ID: "team", Type: "feature-list", Label: "チーム紹介", Icon: "👥", Summary: "主要メンバーの紹介"},
			},
			SEO: PageSEO{
				MetaTitle:       "ハンコフィールド | 会社概要",
				MetaDescription: "ハンコフィールドのビジョンとプロダクトへの取り組みをご紹介します。",
				OGImageURL:      "https://cdn.hanko.example/og/about.jpg",
			},
			Tags:        []string{"会社情報", "ブランド"},
			LastSavedAt: now.Add(-6 * time.Hour),
			LastSavedBy: "松本 彩",
		},
		"page-about-en": {
			Locale:  "en-US",
			Title:   "About Hanko Field",
			Summary: "Discover Hanko Field's mission and craft experience.",
			Outline: "Our product vision and artisan network in English.",
			Blocks: []PageDraftBlock{
				{ID: "hero", Type: "hero", Label: "Hero", Icon: "🌅", Summary: "Introduce the mission statement"},
				{ID: "value", Type: "section", Label: "Value Proposition", Icon: "💡", Summary: "Why customers choose us"},
			},
			SEO: PageSEO{
				MetaTitle:       "Hanko Field | About Us",
				MetaDescription: "Learn more about Hanko Field's mission and team.",
				OGImageURL:      "https://cdn.hanko.example/og/about-en.jpg",
			},
			Tags:        []string{"company", "brand"},
			LastSavedAt: now.Add(-2 * time.Hour),
			LastSavedBy: "Hannah Ito",
		},
		"page-privacy-ja": {
			Locale:  "ja-JP",
			Title:   "プライバシーポリシー",
			Summary: "個人情報保護方針と利用目的について定めています。",
			Outline: "収集データ、利用目的、第三者提供、問い合わせ窓口などを記載。",
			Blocks: []PageDraftBlock{
				{ID: "principle", Type: "section", Label: "基本方針", Icon: "📜", Summary: "個人情報保護に関する基本的な考え方"},
				{ID: "usage", Type: "section", Label: "利用目的", Icon: "🎯", Summary: "収集した情報の利用目的"},
				{ID: "contact", Type: "cta", Label: "お問い合わせ", Icon: "✉️", Summary: "プライバシーに関する問い合わせ窓口"},
			},
			SEO: PageSEO{
				MetaTitle:       "プライバシーポリシー | ハンコフィールド",
				MetaDescription: "ハンコフィールドの個人情報保護方針について説明します。",
				OGImageURL:      "https://cdn.hanko.example/og/privacy.jpg",
				CanonicalURL:    "https://www.hanko.example/legal/privacy-policy",
			},
			Tags:        []string{"法務", "規約"},
			LastSavedAt: now.Add(-36 * time.Hour),
			LastSavedBy: "法務チーム",
		},
		"page-privacy-en": {
			Locale:  "en-US",
			Title:   "Privacy Policy",
			Summary: "Explains how we collect and use personal data in English.",
			Outline: "Covers data collection, retention, and contact channels.",
			Blocks: []PageDraftBlock{
				{ID: "principle", Type: "section", Label: "Principles", Icon: "📜", Summary: "Core privacy commitments"},
				{ID: "gdpr", Type: "section", Label: "GDPR Compliance", Icon: "🇪🇺", Summary: "Regional compliance notes"},
			},
			SEO: PageSEO{
				MetaTitle:       "Privacy Policy | Hanko Field",
				MetaDescription: "Learn how Hanko Field safeguards customer data.",
				OGImageURL:      "https://cdn.hanko.example/og/privacy-en.jpg",
			},
			Tags:        []string{"legal", "gdpr"},
			LastSavedAt: now.Add(-10 * time.Hour),
			LastSavedBy: "Legal Ops",
		},
		"page-pricing-ja": {
			Locale:  "ja-JP",
			Title:   "料金プラン",
			Summary: "用途別に最適な料金プランを案内します。",
			Outline: "ベーシック、プロフェッショナル、エンタープライズの3プラン構成。",
			Blocks: []PageDraftBlock{
				{ID: "plans", Type: "columns", Label: "プラン比較", Icon: "📊", Summary: "各プランの料金と特徴"},
				{ID: "faq", Type: "faq", Label: "FAQ", Icon: "❓", Summary: "よくある質問"},
				{ID: "cta", Type: "cta", Label: "お問い合わせCTA", Icon: "📞", Summary: "営業担当への連絡導線"},
			},
			SEO: PageSEO{
				MetaTitle:       "料金プラン | ハンコフィールド",
				MetaDescription: "用途に合わせた柔軟な料金プランをご紹介します。",
				OGImageURL:      "https://cdn.hanko.example/og/pricing.jpg",
			},
			Tags:        []string{"料金", "キャンペーン"},
			LastSavedAt: now.Add(-12 * time.Hour),
			LastSavedBy: "佐藤 未来",
		},
		"page-status-ja": {
			Locale:  "ja-JP",
			Title:   "システム稼働状況",
			Summary: "現在の稼働状況と過去のインシデント履歴。",
			Outline: "稼働率とメンテナンススケジュール、障害連絡を提供します。",
			Blocks: []PageDraftBlock{
				{ID: "status", Type: "timeline", Label: "最新のステータス", Icon: "📈", Summary: "コンポーネント別の稼働状況"},
				{ID: "maintenance", Type: "calendar", Label: "メンテナンス予定", Icon: "🛠", Summary: "今後のメンテナンス情報"},
			},
			SEO: PageSEO{
				MetaTitle:       "システム稼働状況 | ハンコフィールド",
				MetaDescription: "リアルタイムの稼働情報とメンテナンス予定を確認できます。",
				OGImageURL:      "https://cdn.hanko.example/og/status.jpg",
			},
			Tags:        []string{"ステータス", "SRE"},
			LastSavedAt: now.Add(-1 * time.Hour),
			LastSavedBy: "SRE Team",
		},
	}

	previews := map[string]pagePreviewEntry{
		previewKey("about", "ja-JP"): {
			HeroHTML: renderDraftHero(drafts["page-about-ja"]),
			BodyHTML: renderDraftPreviewBody(drafts["page-about-ja"]),
			Notes: []string{
				"ブランドガイドラインに沿った画像を最終確認してください。",
				"英語版の公開と同時にSNSでシェア予定です。",
			},
			ShareURL:    "https://preview.hanko.example/pages/about?lang=ja-JP&token=about-ja",
			ExternalURL: "https://www.hanko.example/about?lang=ja-JP",
			SEO:         drafts["page-about-ja"].SEO,
		},
		previewKey("about", "en-US"): {
			HeroHTML: renderDraftHero(drafts["page-about-en"]),
			BodyHTML: renderDraftPreviewBody(drafts["page-about-en"]),
			Notes: []string{
				"Localization QA scheduled for tomorrow.",
				"Ensure pricing links use US currency before publishing.",
			},
			ShareURL:    "https://preview.hanko.example/pages/about?lang=en-US&token=about-en",
			ExternalURL: "https://www.hanko.example/about?lang=en-US",
			SEO:         drafts["page-about-en"].SEO,
		},
		previewKey("legal/privacy-policy", "ja-JP"): {
			HeroHTML: renderDraftHero(drafts["page-privacy-ja"]),
			BodyHTML: renderDraftPreviewBody(drafts["page-privacy-ja"]),
			Notes: []string{
				"法務レビュー済み。公開後は通知メールを送付してください。",
			},
			ShareURL:    "https://preview.hanko.example/pages/legal/privacy-policy?lang=ja-JP&token=privacy-ja",
			ExternalURL: "https://www.hanko.example/legal/privacy-policy?lang=ja-JP",
			SEO:         drafts["page-privacy-ja"].SEO,
		},
		previewKey("legal/privacy-policy", "en-US"): {
			HeroHTML: renderDraftHero(drafts["page-privacy-en"]),
			BodyHTML: renderDraftPreviewBody(drafts["page-privacy-en"]),
			Notes: []string{
				"待機中: DPOのサインオフを取得してから公開してください。",
			},
			ShareURL:    "https://preview.hanko.example/pages/legal/privacy-policy?lang=en-US&token=privacy-en",
			ExternalURL: "https://www.hanko.example/legal/privacy-policy?lang=en-US",
			SEO:         drafts["page-privacy-en"].SEO,
		},
		previewKey("pricing", "ja-JP"): {
			HeroHTML: renderDraftHero(drafts["page-pricing-ja"]),
			BodyHTML: renderDraftPreviewBody(drafts["page-pricing-ja"]),
			Notes: []string{
				"キャンペーンバナーは別途S3で差し替え予定です。",
			},
			ShareURL:    "https://preview.hanko.example/pages/pricing?lang=ja-JP&token=pricing-ja",
			ExternalURL: "https://www.hanko.example/pricing?lang=ja-JP",
			SEO:         drafts["page-pricing-ja"].SEO,
		},
		previewKey("status", "ja-JP"): {
			HeroHTML: renderDraftHero(drafts["page-status-ja"]),
			BodyHTML: renderDraftPreviewBody(drafts["page-status-ja"]),
			Notes: []string{
				"自動更新はCloud Functions経由で5分間隔です。",
			},
			ShareURL:    "https://preview.hanko.example/pages/status?lang=ja-JP&token=status-ja",
			ExternalURL: "https://status.hanko.example/",
			SEO:         drafts["page-status-ja"].SEO,
		},
	}

	locales := map[string][]PageLocale{
		"about": {
			{Locale: "ja-JP", Label: "日本語"},
			{Locale: "en-US", Label: "English"},
		},
		"legal/privacy-policy": {
			{Locale: "ja-JP", Label: "日本語"},
			{Locale: "en-US", Label: "English"},
		},
		"pricing": {
			{Locale: "ja-JP", Label: "日本語"},
		},
		"status": {
			{Locale: "ja-JP", Label: "日本語"},
		},
	}

	properties := map[string]PageProperties{
		"page-about-ja": {
			Slug:            "about",
			Type:            "landing",
			Tags:            []string{"会社情報", "ブランド"},
			SEO:             drafts["page-about-ja"].SEO,
			LiveURL:         "https://www.hanko.example/about?lang=ja-JP",
			PreviewURL:      "https://preview.hanko.example/pages/about?lang=ja-JP",
			ShareURL:        "https://www.hanko.example/about?lang=ja-JP",
			LastPublishedAt: inHours(-72),
			LastPublishedBy: "松本 彩",
			Version:         "v2.3.0",
			VisibilityLabel: "公開中",
			VisibilityTone:  "success",
			Breadcrumbs:     []string{"コンテンツ", "会社情報"},
		},
		"page-about-en": {
			Slug:            "about",
			Type:            "landing",
			Tags:            []string{"company", "brand"},
			SEO:             drafts["page-about-en"].SEO,
			LiveURL:         "",
			PreviewURL:      "https://preview.hanko.example/pages/about?lang=en-US",
			ShareURL:        "https://www.hanko.example/about?lang=en-US",
			Version:         "v2.3.0-draft",
			VisibilityLabel: "下書き",
			VisibilityTone:  "",
			Breadcrumbs:     []string{"Content", "Company"},
		},
		"page-privacy-ja": {
			Slug:            "legal/privacy-policy",
			Type:            "legal",
			Tags:            []string{"法務", "規約"},
			SEO:             drafts["page-privacy-ja"].SEO,
			LiveURL:         "https://www.hanko.example/legal/privacy-policy?lang=ja-JP",
			PreviewURL:      "https://preview.hanko.example/pages/legal/privacy-policy?lang=ja-JP",
			ShareURL:        "https://www.hanko.example/legal/privacy-policy?lang=ja-JP",
			LastPublishedAt: inHours(-240),
			LastPublishedBy: "法務チーム",
			Version:         "2024.12",
			VisibilityLabel: "公開中",
			VisibilityTone:  "success",
			Breadcrumbs:     []string{"コンテンツ", "法務"},
		},
		"page-privacy-en": {
			Slug:            "legal/privacy-policy",
			Type:            "legal",
			Tags:            []string{"legal", "gdpr"},
			SEO:             drafts["page-privacy-en"].SEO,
			LiveURL:         "",
			PreviewURL:      "https://preview.hanko.example/pages/legal/privacy-policy?lang=en-US",
			ShareURL:        "https://www.hanko.example/legal/privacy-policy?lang=en-US",
			Version:         "2024.12-en",
			VisibilityLabel: "公開予定",
			VisibilityTone:  "warning",
			Breadcrumbs:     []string{"Content", "Legal"},
		},
		"page-pricing-ja": {
			Slug:            "pricing",
			Type:            "landing",
			Tags:            []string{"料金", "キャンペーン"},
			SEO:             drafts["page-pricing-ja"].SEO,
			LiveURL:         "",
			PreviewURL:      "https://preview.hanko.example/pages/pricing?lang=ja-JP",
			ShareURL:        "https://www.hanko.example/pricing?lang=ja-JP",
			Version:         "v1.1.0-draft",
			VisibilityLabel: "下書き",
			VisibilityTone:  "",
			Breadcrumbs:     []string{"コンテンツ", "会社情報"},
		},
		"page-status-ja": {
			Slug:            "status",
			Type:            "system",
			Tags:            []string{"ステータス", "SRE"},
			SEO:             drafts["page-status-ja"].SEO,
			LiveURL:         "https://status.hanko.example/",
			PreviewURL:      "https://preview.hanko.example/pages/status?lang=ja-JP",
			ShareURL:        "https://status.hanko.example/",
			LastPublishedAt: inHours(-12),
			LastPublishedBy: "SRE Team",
			Version:         "v0.9.4",
			VisibilityLabel: "公開中",
			VisibilityTone:  "success",
			Breadcrumbs:     []string{"コンテンツ", "ステータス"},
		},
	}

	schedules := map[string]PageSchedule{
		"page-about-ja": {
			StatusLabel: "未設定",
			StatusTone:  "",
		},
		"page-about-en": {
			StatusLabel: "未設定",
			StatusTone:  "",
		},
		"page-privacy-ja": {
			StatusLabel: "公開中",
			StatusTone:  "success",
		},
		"page-privacy-en": {
			ScheduledAt:     pages[3].ScheduledAt,
			WindowLabel:     pages[3].ScheduledAt.In(time.Local).Format("2006-01-02 15:04"),
			TimezoneLabel:   pages[3].ScheduledAt.In(time.Local).Format("MST"),
			LastScheduledBy: "Legal Ops",
			LastScheduledAt: inHours(-10),
			StatusLabel:     "公開予定",
			StatusTone:      "warning",
		},
		"page-pricing-ja": {
			StatusLabel: "未設定",
		},
		"page-status-ja": {
			StatusLabel: "公開中",
			StatusTone:  "success",
		},
	}

	history := map[string][]PageHistoryEntry{
		"page-about-ja": {
			{
				ID:         "hist-about-1",
				Title:      "v2.3.0 公開",
				Summary:    "ブランドメッセージと沿革を更新しました。",
				Actor:      "松本 彩",
				Version:    "v2.3.0",
				OccurredAt: now.Add(-72 * time.Hour),
				Tone:       "success",
				Icon:       "🚀",
			},
			{
				ID:         "hist-about-0",
				Title:      "翻訳チェック一覧追加",
				Summary:    "多言語化ロードマップに沿ってコンテンツを整理しました。",
				Actor:      "Localization Team",
				Version:    "v2.2.1",
				OccurredAt: now.Add(-240 * time.Hour),
				Tone:       "info",
				Icon:       "🌐",
			},
		},
		"page-privacy-en": {
			{
				ID:         "hist-privacy-en-1",
				Title:      "DPOレビュー完了",
				Summary:    "GDPR節をアップデートしました。",
				Actor:      "Legal Ops",
				Version:    "2024.12-en",
				OccurredAt: now.Add(-10 * time.Hour),
				Tone:       "warning",
				Icon:       "⚖️",
			},
		},
		"page-pricing-ja": {
			{
				ID:         "hist-pricing-1",
				Title:      "キャンペーン情報更新",
				Summary:    "春の割引情報を追加しました。",
				Actor:      "佐藤 未来",
				Version:    "v1.1.0-draft",
				OccurredAt: now.Add(-12 * time.Hour),
				Tone:       "info",
				Icon:       "💡",
			},
		},
	}

	palette := []PageBlockPaletteGroup{
		{
			Label: "レイアウト",
			Blocks: []PageBlockPaletteItem{
				{Type: "hero", Label: "ヒーロー", Description: "大型ビジュアルと主要メッセージを表示します。", Icon: "🌅"},
				{Type: "columns", Label: "3カラム", Description: "特徴を横並びで表現します。", Icon: "🧱"},
				{Type: "section", Label: "セクション", Description: "テキスト主体のセクションを追加します。", Icon: "📝"},
			},
		},
		{
			Label: "コンテンツ",
			Blocks: []PageBlockPaletteItem{
				{Type: "faq", Label: "FAQ", Description: "よくある質問と回答を折りたたみで表示します。", Icon: "❓"},
				{Type: "timeline", Label: "タイムライン", Description: "沿革やステータス更新を時系列で表示します。", Icon: "🕒"},
				{Type: "cta", Label: "CTA", Description: "行動を促す大きなボタンを表示します。", Icon: "🚀"},
			},
		},
	}

	structure := []pageTreeNodeDef{
		{ID: "node-company", Title: "会社情報", ParentID: "", Icon: "🏢", Order: 1},
		{ID: "node-company-about-ja", Title: "会社概要", Subtitle: "日本語", ParentID: "node-company", PageID: "page-about-ja", Order: 1},
		{ID: "node-company-about-en", Title: "About Hanko Field", Subtitle: "English", ParentID: "node-company", PageID: "page-about-en", Order: 2},
		{ID: "node-company-pricing", Title: "料金プラン", Subtitle: "日本語", ParentID: "node-company", PageID: "page-pricing-ja", Order: 3},
		{ID: "node-legal", Title: "法務", ParentID: "", Icon: "⚖️", Order: 2},
		{ID: "node-legal-privacy-ja", Title: "プライバシーポリシー", Subtitle: "日本語", ParentID: "node-legal", PageID: "page-privacy-ja", Order: 1},
		{ID: "node-legal-privacy-en", Title: "Privacy Policy", Subtitle: "English", ParentID: "node-legal", PageID: "page-privacy-en", Order: 2},
		{ID: "node-status", Title: "ステータス", ParentID: "", Icon: "📡", Order: 3},
		{ID: "node-status-ja", Title: "システム稼働状況", Subtitle: "日本語", ParentID: "node-status", PageID: "page-status-ja", Order: 1},
	}

	return pageStaticDataset{
		pages:      pages,
		drafts:     drafts,
		previews:   previews,
		locales:    locales,
		properties: properties,
		schedules:  schedules,
		history:    history,
		palette:    palette,
		structure:  structure,
	}
}
