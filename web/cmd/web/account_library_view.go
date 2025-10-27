package main

import (
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"finitefield.org/hanko-web/internal/format"
	mw "finitefield.org/hanko-web/internal/middleware"
)

const accountLibraryPageSize = 9

var accountLibraryNow = time.Date(2025, time.March, 24, 11, 15, 0, 0, time.UTC)

const (
	httpMethodPost   = "POST"
	httpMethodDelete = "DELETE"
)

type AccountLibraryPageView struct {
	Lang     string
	User     AccountUser
	NavItems []AccountNavItem

	Section AccountLibrarySection
	Filters AccountLibraryFilterView
	Grid    AccountLibraryGridView
	Drawer  AccountLibraryDrawerView
}

type AccountLibrarySection struct {
	Eyebrow        string
	Title          string
	Subtitle       string
	PrimaryLabel   string
	PrimaryHref    string
	SecondaryLabel string
	SecondaryHref  string
}

type AccountLibraryFilterView struct {
	Status string
	Tag    string
	Sort   string
	Query  string

	StatusOptions []AccountLibraryStatusOption
	TagOptions    []AccountLibraryTagOption
	SortOptions   []AccountLibrarySortOption

	SearchPlaceholder string
}

type AccountLibraryStatusOption struct {
	ID     string
	Label  string
	Count  int
	Active bool
	Tone   string
}

type AccountLibraryTagOption struct {
	ID     string
	Label  string
	Count  int
	Active bool
}

type AccountLibrarySortOption struct {
	ID     string
	Label  string
	Active bool
}

type AccountLibraryGridView struct {
	Lang string

	Items []AccountLibraryDesignCard

	ResultLabel string
	Total       int
	Page        int
	Per         int
	Showing     int
	HasMore     bool
	NextPage    int
	LastUpdated time.Time

	Bulk AccountLibraryBulkActionBar
}

type AccountLibraryDesignCard struct {
	ID           string
	Name         string
	Description  string
	Thumbnail    string
	ThumbnailAlt string

	StatusLabel string
	StatusTone  string

	RegistrabilityLabel string
	RegistrabilityTone  string

	AIScoreLabel string
	Meta         []string

	Tags []AccountLibraryTagChip

	UpdatedAt       time.Time
	UpdatedRelative string

	CreatedAt time.Time

	TemplateName string
	TemplateHref string

	OwnerName string
	OwnerRole string

	Selected bool

	DuplicateAction AccountLibraryAction
	ExportAction    AccountLibraryAction
	ShareAction     AccountLibraryAction
	DetailHref      string
}

type AccountLibraryTagChip struct {
	ID    string
	Label string
	Tone  string
}

type AccountLibraryAction struct {
	Label     string
	Icon      string
	Href      string
	Method    string
	HXTarget  string
	HXSwap    string
	HXTrigger string
	Confirm   string
}

type AccountLibraryBulkActionBar struct {
	Active        bool
	SelectedCount int
	SelectedIDs   []string

	Label string

	Actions []AccountLibraryBulkAction
}

type AccountLibraryBulkAction struct {
	Label   string
	Icon    string
	Href    string
	Method  string
	Variant string
	Confirm string
}

type AccountLibraryDrawerView struct {
	Lang   string
	Open   bool
	Design AccountLibraryDrawerDesign
}

type AccountLibraryDrawerDesign struct {
	ID                 string
	Name               string
	Subtitle           string
	StatusLabel        string
	StatusTone         string
	Registrability     string
	RegistrabilityTone string
	AIScore            string
	PreviewImage       string
	PreviewAlt         string
	PreviewBadge       string
	PreviewMeta        []string
	Tags               []AccountLibraryTagChip
	Owner              string
	OwnerRole          string
	UpdatedRelative    string
	UpdatedExact       string
	CreatedExact       string
	CreatedRelative    string
	TemplateName       string
	TemplateHref       string
	Metrics            []AccountLibraryDrawerMetric
	Properties         []AccountLibraryDrawerProperty
	QuickLinks         []AccountLibraryDrawerLink
	Activity           []AccountLibraryDrawerActivity
}

type AccountLibraryDrawerMetric struct {
	Label string
	Value string
	Tone  string
	Icon  string
}

type AccountLibraryDrawerProperty struct {
	Label string
	Value string
	Hint  string
}

type AccountLibraryDrawerLink struct {
	Label       string
	Description string
	Href        string
	Icon        string
	Modal       bool
}

type AccountLibraryDrawerActivity struct {
	Title       string
	Description string
	Relative    string
	Timestamp   string
	Icon        string
	Tone        string
}

type accountLibraryDesign struct {
	ID             string
	Name           string
	TemplateID     string
	TemplateName   string
	TemplateHref   string
	Status         string
	Registrable    bool
	Registrability string
	AIScore        int
	Shape          string
	SizeLabel      string
	Material       string
	Tags           []string
	UpdatedAt      time.Time
	CreatedAt      time.Time
	OwnerName      string
	OwnerRole      string
	PreviewImage   string
	PreviewAlt     string
	ExportCount    int
	LastExport     time.Time
	ShareCount     int
	LastShare      time.Time
	DuplicateCount int
	LastDuplicate  time.Time
	OrdersCount    int
	ApprovalsCount int
	Notes          string
	Activity       []accountLibraryActivity
}

type accountLibraryActivity struct {
	Title       string
	Description string
	Timestamp   time.Time
	Icon        string
	Tone        string
}

type accountLibraryStatusMeta struct {
	LabelJA string
	LabelEN string
	Tone    string
}

type accountLibraryTagMeta struct {
	LabelJA string
	LabelEN string
	Tone    string
}

var accountLibraryStatusOrder = []string{"all", "approved", "pending", "needs-review", "draft", "archived"}

var accountLibraryStatusCatalog = map[string]accountLibraryStatusMeta{
	"approved":     {LabelJA: "登録済み", LabelEN: "Approved", Tone: "success"},
	"pending":      {LabelJA: "申請中", LabelEN: "Pending review", Tone: "warning"},
	"needs-review": {LabelJA: "要再確認", LabelEN: "Needs review", Tone: "danger"},
	"draft":        {LabelJA: "下書き", LabelEN: "Draft", Tone: "muted"},
	"archived":     {LabelJA: "アーカイブ", LabelEN: "Archived", Tone: "slate"},
}

var accountLibraryTagCatalog = map[string]accountLibraryTagMeta{
	"corporate":    {LabelJA: "法人印", LabelEN: "Corporate", Tone: "indigo"},
	"ai":           {LabelJA: "AI提案", LabelEN: "AI assisted", Tone: "violet"},
	"finance":      {LabelJA: "金融", LabelEN: "Finance", Tone: "emerald"},
	"regulatory":   {LabelJA: "登記対応", LabelEN: "Regulatory", Tone: "sky"},
	"draft":        {LabelJA: "下書き", LabelEN: "Draft", Tone: "slate"},
	"legacy":       {LabelJA: "レガシー移行", LabelEN: "Legacy migration", Tone: "amber"},
	"event":        {LabelJA: "イベント", LabelEN: "Event", Tone: "rose"},
	"team":         {LabelJA: "チーム共有", LabelEN: "Team share", Tone: "cyan"},
	"ai-iteration": {LabelJA: "AI改稿", LabelEN: "AI iteration", Tone: "purple"},
}

var accountLibrarySortCatalog = []struct {
	ID      string
	LabelJA string
	LabelEN string
}{
	{ID: "updated", LabelJA: "更新日 (新しい順)", LabelEN: "Updated (newest)"},
	{ID: "created", LabelJA: "作成日 (新しい順)", LabelEN: "Created (newest)"},
	{ID: "ai", LabelJA: "AIスコア (高い順)", LabelEN: "AI score (high)"},
	{ID: "name", LabelJA: "名前 (A-Z)", LabelEN: "Name (A-Z)"},
}

func buildAccountLibraryPageView(lang string, sess *mw.SessionData, q url.Values) AccountLibraryPageView {
	profile := sessionProfileOrFallback(sess.Profile, lang)
	user := accountUserFromProfile(profile, lang)

	status := normalizeAccountLibraryStatus(q.Get("status"))
	tag := normalizeAccountLibraryTag(q.Get("tag"))
	sortKey := normalizeAccountLibrarySort(q.Get("sort"))
	query := strings.TrimSpace(q.Get("q"))
	page := parseAccountLibraryPage(q.Get("page"))
	selectedIDs := parseAccountLibrarySelected(q["sel"])

	designs := accountLibraryMockDesigns(lang)

	statusCounts := map[string]int{"all": len(designs)}
	tagCounts := map[string]int{"all": len(designs)}

	for _, d := range designs {
		statusCounts[d.Status]++
		for _, t := range d.Tags {
			tagCounts[t]++
		}
	}

	filtered := make([]accountLibraryDesign, 0, len(designs))
	searchLower := strings.ToLower(query)
	for _, d := range designs {
		if status != "" && status != "all" && d.Status != status {
			continue
		}
		if tag != "" && tag != "all" {
			if !containsString(d.Tags, tag) {
				continue
			}
		}
		if searchLower != "" {
			if !strings.Contains(librarySearchIndex(d), searchLower) {
				continue
			}
		}
		filtered = append(filtered, d)
	}

	switch sortKey {
	case "created":
		sort.Slice(filtered, func(i, j int) bool {
			return filtered[i].CreatedAt.After(filtered[j].CreatedAt)
		})
	case "ai":
		sort.Slice(filtered, func(i, j int) bool {
			if filtered[i].AIScore == filtered[j].AIScore {
				return filtered[i].UpdatedAt.After(filtered[j].UpdatedAt)
			}
			return filtered[i].AIScore > filtered[j].AIScore
		})
	case "name":
		sort.Slice(filtered, func(i, j int) bool {
			return strings.ToLower(filtered[i].Name) < strings.ToLower(filtered[j].Name)
		})
	default:
		sort.Slice(filtered, func(i, j int) bool {
			return filtered[i].UpdatedAt.After(filtered[j].UpdatedAt)
		})
	}

	total := len(filtered)
	per := accountLibraryPageSize
	if per <= 0 {
		per = 9
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
	end := page * per
	if end > total {
		end = total
	}

	paged := filtered
	if total > 0 {
		paged = filtered[:end]
	} else {
		paged = []accountLibraryDesign{}
	}

	selectedSet := make(map[string]struct{}, len(selectedIDs))
	for _, id := range selectedIDs {
		selectedSet[id] = struct{}{}
	}

	cards := make([]AccountLibraryDesignCard, 0, len(paged))
	for _, d := range paged {
		card := buildAccountLibraryDesignCard(lang, d, selectedSet)
		cards = append(cards, card)
	}

	hasMore := end < total
	nextPage := page + 1
	if !hasMore {
		nextPage = page
	}

	resultLabel := buildAccountLibraryResultLabel(lang, total, query, status, tag)

	statusOptions := buildAccountLibraryStatusOptions(lang, status, statusCounts)
	tagOptions := buildAccountLibraryTagOptions(lang, tag, tagCounts)
	sortOptions := buildAccountLibrarySortOptions(lang, sortKey)

	bulk := buildAccountLibraryBulkBar(lang, selectedIDs)

	grid := AccountLibraryGridView{
		Lang:        lang,
		Items:       cards,
		ResultLabel: resultLabel,
		Total:       total,
		Page:        page,
		Per:         per,
		Showing:     len(cards),
		HasMore:     hasMore,
		NextPage:    nextPage,
		LastUpdated: accountLibraryNow,
		Bulk:        bulk,
	}

	section := AccountLibrarySection{
		Eyebrow:        i18nOrDefault(lang, "account.library.section.eyebrow", "Design library"),
		Title:          i18nOrDefault(lang, "account.library.section.title", "Saved seals & approvals"),
		Subtitle:       i18nOrDefault(lang, "account.library.section.subtitle", "Track stamp status, export production assets, and share proofs with your team."),
		PrimaryLabel:   i18nOrDefault(lang, "account.library.section.primary", "Create new design"),
		PrimaryHref:    "/design/new",
		SecondaryLabel: i18nOrDefault(lang, "account.library.section.secondary", "Browse templates"),
		SecondaryHref:  "/templates",
	}

	filters := AccountLibraryFilterView{
		Status:            status,
		Tag:               tag,
		Sort:              sortKey,
		Query:             query,
		StatusOptions:     statusOptions,
		TagOptions:        tagOptions,
		SortOptions:       sortOptions,
		SearchPlaceholder: i18nOrDefault(lang, "account.library.filters.search", "Search designs, tags, or templates"),
	}

	drawer := buildAccountLibraryDrawer(lang, q.Get("design"), designs)

	view := AccountLibraryPageView{
		Lang:     lang,
		User:     user,
		NavItems: accountNavItems(lang, "library"),
		Section:  section,
		Filters:  filters,
		Grid:     grid,
		Drawer:   drawer,
	}

	return view
}

func buildAccountLibraryDesignCard(lang string, d accountLibraryDesign, selected map[string]struct{}) AccountLibraryDesignCard {
	statusLabel, statusTone := accountLibraryStatusLabelTone(lang, d.Status)
	regLabel, regTone := accountLibraryRegistrability(lang, d)

	tags := make([]AccountLibraryTagChip, 0, len(d.Tags))
	for _, t := range d.Tags {
		if meta, ok := accountLibraryTagCatalog[t]; ok {
			label := meta.LabelEN
			if lang == "ja" {
				label = meta.LabelJA
			}
			tags = append(tags, AccountLibraryTagChip{
				ID:    t,
				Label: label,
				Tone:  meta.Tone,
			})
		}
	}

	meta := []string{
		d.TemplateName,
		d.SizeLabel,
		materialLabel(lang, d.Material),
	}

	if d.Shape != "" {
		meta = append(meta, shapeLabel(lang, d.Shape))
	}

	var selectedFlag bool
	if _, ok := selected[d.ID]; ok {
		selectedFlag = true
	}

	card := AccountLibraryDesignCard{
		ID:                  d.ID,
		Name:                d.Name,
		Description:         d.Notes,
		Thumbnail:           d.PreviewImage,
		ThumbnailAlt:        d.PreviewAlt,
		StatusLabel:         statusLabel,
		StatusTone:          statusTone,
		RegistrabilityLabel: regLabel,
		RegistrabilityTone:  regTone,
		AIScoreLabel:        libraryAIScoreLabel(lang, d.AIScore),
		Meta:                meta,
		Tags:                tags,
		UpdatedAt:           d.UpdatedAt,
		UpdatedRelative:     formatDesignVersionRelative(lang, accountLibraryNow.Sub(d.UpdatedAt)),
		CreatedAt:           d.CreatedAt,
		TemplateName:        d.TemplateName,
		TemplateHref:        d.TemplateHref,
		OwnerName:           d.OwnerName,
		OwnerRole:           d.OwnerRole,
		Selected:            selectedFlag,
		DuplicateAction: AccountLibraryAction{
			Label:  libraryDuplicateLabel(lang),
			Icon:   "document-duplicate",
			Href:   fmt.Sprintf("/designs/%s:duplicate", d.ID),
			Method: httpMethodPost,
		},
		ExportAction: AccountLibraryAction{
			Label:  libraryExportLabel(lang),
			Icon:   "arrow-down-tray",
			Href:   fmt.Sprintf("/designs/%s:export", d.ID),
			Method: httpMethodPost,
		},
		ShareAction: AccountLibraryAction{
			Label:    libraryShareLabel(lang),
			Icon:     "share",
			Href:     fmt.Sprintf("/design/share/modal?design=%s", url.QueryEscape(d.ID)),
			HXTarget: "#modal",
			HXSwap:   "innerHTML",
		},
		DetailHref: fmt.Sprintf("/account/library/drawer?design=%s", url.QueryEscape(d.ID)),
	}
	return card
}

func buildAccountLibraryStatusOptions(lang, active string, counts map[string]int) []AccountLibraryStatusOption {
	out := make([]AccountLibraryStatusOption, 0, len(accountLibraryStatusOrder))
	for _, id := range accountLibraryStatusOrder {
		if id == "all" {
			label := i18nOrDefault(lang, "account.library.status.all", "All")
			out = append(out, AccountLibraryStatusOption{
				ID:     "all",
				Label:  fmt.Sprintf("%s · %d", label, counts["all"]),
				Count:  counts["all"],
				Active: active == "" || active == "all",
				Tone:   "default",
			})
			continue
		}
		meta, ok := accountLibraryStatusCatalog[id]
		if !ok {
			continue
		}
		label := meta.LabelEN
		if lang == "ja" {
			label = meta.LabelJA
		}
		out = append(out, AccountLibraryStatusOption{
			ID:     id,
			Label:  fmt.Sprintf("%s · %d", label, counts[id]),
			Count:  counts[id],
			Active: active == id,
			Tone:   meta.Tone,
		})
	}
	return out
}

func buildAccountLibraryTagOptions(lang, active string, counts map[string]int) []AccountLibraryTagOption {
	ids := make([]string, 0, len(counts))
	for id := range counts {
		if id == "all" {
			continue
		}
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool {
		if counts[ids[i]] == counts[ids[j]] {
			return ids[i] < ids[j]
		}
		return counts[ids[i]] > counts[ids[j]]
	})

	out := []AccountLibraryTagOption{
		{
			ID:     "all",
			Label:  i18nOrDefault(lang, "account.library.tags.all", "All tags"),
			Count:  counts["all"],
			Active: active == "" || active == "all",
		},
	}
	for _, id := range ids {
		meta, ok := accountLibraryTagCatalog[id]
		if !ok {
			continue
		}
		label := meta.LabelEN
		if lang == "ja" {
			label = meta.LabelJA
		}
		out = append(out, AccountLibraryTagOption{
			ID:     id,
			Label:  fmt.Sprintf("%s (%d)", label, counts[id]),
			Count:  counts[id],
			Active: active == id,
		})
	}
	return out
}

func buildAccountLibrarySortOptions(lang, active string) []AccountLibrarySortOption {
	out := make([]AccountLibrarySortOption, 0, len(accountLibrarySortCatalog))
	for _, opt := range accountLibrarySortCatalog {
		label := opt.LabelEN
		if lang == "ja" {
			label = opt.LabelJA
		}
		out = append(out, AccountLibrarySortOption{
			ID:     opt.ID,
			Label:  label,
			Active: active == "" && opt.ID == "updated" || active == opt.ID,
		})
	}
	return out
}

func buildAccountLibraryResultLabel(lang string, total int, query, status, tag string) string {
	if lang == "ja" {
		switch {
		case query != "":
			return fmt.Sprintf("「%s」の検索結果：%d件", query, total)
		case status != "" && status != "all":
			label, _ := accountLibraryStatusLabelTone(lang, status)
			return fmt.Sprintf("%s：%d件", label, total)
		case tag != "" && tag != "all":
			label := accountLibraryTagLabel(lang, tag)
			return fmt.Sprintf("%s：%d件", label, total)
		default:
			return fmt.Sprintf("%d件のデザイン", total)
		}
	}
	switch {
	case query != "":
		return fmt.Sprintf("Results for “%s” · %d designs", query, total)
	case status != "" && status != "all":
		label, _ := accountLibraryStatusLabelTone(lang, status)
		return fmt.Sprintf("%s · %d designs", label, total)
	case tag != "" && tag != "all":
		label := accountLibraryTagLabel(lang, tag)
		return fmt.Sprintf("%s · %d designs", label, total)
	default:
		return fmt.Sprintf("%d designs", total)
	}
}

func buildAccountLibraryBulkBar(lang string, selected []string) AccountLibraryBulkActionBar {
	count := len(selected)
	label := ""
	if count > 0 {
		if lang == "ja" {
			label = fmt.Sprintf("%d件選択中", count)
		} else {
			label = fmt.Sprintf("%d selected", count)
		}
	}

	actions := []AccountLibraryBulkAction{
		{
			Label:   libraryExportLabel(lang),
			Icon:    "arrow-down-tray",
			Href:    "/designs/bulk:export",
			Method:  httpMethodPost,
			Variant: "primary",
		},
		{
			Label:   libraryShareLabel(lang),
			Icon:    "share",
			Href:    "/designs/bulk:share",
			Method:  httpMethodPost,
			Variant: "secondary",
		},
		{
			Label:   libraryDeleteLabel(lang),
			Icon:    "trash",
			Href:    "/designs/bulk:delete",
			Method:  httpMethodPost,
			Variant: "danger",
			Confirm: libraryDeleteConfirm(lang),
		},
	}

	return AccountLibraryBulkActionBar{
		Active:        count > 0,
		SelectedCount: count,
		SelectedIDs:   selected,
		Label:         label,
		Actions:       actions,
	}
}

func buildAccountLibraryDrawer(lang, designParam string, designs []accountLibraryDesign) AccountLibraryDrawerView {
	normalized, _ := normalizeDesignID(designParam)
	if normalized == "" {
		return AccountLibraryDrawerView{
			Lang: lang,
			Open: false,
			Design: AccountLibraryDrawerDesign{
				PreviewMeta: []string{},
				Metrics:     []AccountLibraryDrawerMetric{},
				Properties:  []AccountLibraryDrawerProperty{},
				QuickLinks:  []AccountLibraryDrawerLink{},
				Activity:    []AccountLibraryDrawerActivity{},
			},
		}
	}

	var target *accountLibraryDesign
	for i := range designs {
		if designs[i].ID == normalized {
			target = &designs[i]
			break
		}
	}
	if target == nil {
		return AccountLibraryDrawerView{
			Lang: lang,
			Open: false,
			Design: AccountLibraryDrawerDesign{
				PreviewMeta: []string{},
				Metrics:     []AccountLibraryDrawerMetric{},
				Properties:  []AccountLibraryDrawerProperty{},
				QuickLinks:  []AccountLibraryDrawerLink{},
				Activity:    []AccountLibraryDrawerActivity{},
			},
		}
	}

	statusLabel, statusTone := accountLibraryStatusLabelTone(lang, target.Status)
	regLabel, regTone := accountLibraryRegistrability(lang, *target)

	previewMeta := []string{
		target.TemplateName,
		target.SizeLabel,
		materialLabel(lang, target.Material),
	}
	if target.Shape != "" {
		previewMeta = append(previewMeta, shapeLabel(lang, target.Shape))
	}

	tags := make([]AccountLibraryTagChip, 0, len(target.Tags))
	for _, t := range target.Tags {
		if meta, ok := accountLibraryTagCatalog[t]; ok {
			label := meta.LabelEN
			if lang == "ja" {
				label = meta.LabelJA
			}
			tags = append(tags, AccountLibraryTagChip{
				ID:    t,
				Label: label,
				Tone:  meta.Tone,
			})
		}
	}

	metrics := []AccountLibraryDrawerMetric{
		{
			Label: libraryMetricExports(lang),
			Value: fmt.Sprintf("%d", target.ExportCount),
			Tone:  "indigo",
			Icon:  "arrow-down-tray",
		},
		{
			Label: libraryMetricShares(lang),
			Value: fmt.Sprintf("%d", target.ShareCount),
			Tone:  "violet",
			Icon:  "share",
		},
		{
			Label: libraryMetricOrders(lang),
			Value: fmt.Sprintf("%d", target.OrdersCount),
			Tone:  "emerald",
			Icon:  "shopping-bag",
		},
		{
			Label: libraryMetricApprovals(lang),
			Value: fmt.Sprintf("%d", target.ApprovalsCount),
			Tone:  "sky",
			Icon:  "check-badge",
		},
	}

	props := []AccountLibraryDrawerProperty{
		{
			Label: libraryPropertyTemplate(lang),
			Value: target.TemplateName,
			Hint:  target.TemplateHref,
		},
		{
			Label: libraryPropertyUpdated(lang),
			Value: fmt.Sprintf("%s · %s", format.FmtDate(target.UpdatedAt, lang), target.UpdatedAt.Format("2006-01-02 15:04")),
			Hint:  libraryHintUpdated(lang),
		},
		{
			Label: libraryPropertyCreated(lang),
			Value: format.FmtDate(target.CreatedAt, lang),
			Hint:  target.CreatedAt.Format("2006-01-02 15:04"),
		},
		{
			Label: libraryPropertyRegistrability(lang),
			Value: regLabel,
			Hint:  target.Registrability,
		},
	}

	quickLinks := []AccountLibraryDrawerLink{
		{
			Label:       libraryActionOpenEditor(lang),
			Description: libraryActionOpenEditorDesc(lang),
			Href:        fmt.Sprintf("/design/editor?design=%s", url.QueryEscape(target.ID)),
			Icon:        "pencil-square",
			Modal:       false,
		},
		{
			Label:       libraryActionVersions(lang),
			Description: libraryActionVersionsDesc(lang),
			Href:        fmt.Sprintf("/design/versions?design=%s", url.QueryEscape(target.ID)),
			Icon:        "clock",
			Modal:       false,
		},
		{
			Label:       libraryActionShare(lang),
			Description: libraryActionShareDesc(lang),
			Href:        fmt.Sprintf("/design/share/modal?design=%s", url.QueryEscape(target.ID)),
			Icon:        "share",
			Modal:       true,
		},
	}

	activity := make([]AccountLibraryDrawerActivity, 0, len(target.Activity))
	for _, a := range target.Activity {
		activity = append(activity, AccountLibraryDrawerActivity{
			Title:       a.Title,
			Description: a.Description,
			Relative:    formatDesignVersionRelative(lang, accountLibraryNow.Sub(a.Timestamp)),
			Timestamp:   a.Timestamp.Format("2006-01-02 15:04"),
			Icon:        a.Icon,
			Tone:        a.Tone,
		})
	}

	drawer := AccountLibraryDrawerView{
		Lang: lang,
		Open: true,
		Design: AccountLibraryDrawerDesign{
			ID:                 target.ID,
			Name:               target.Name,
			Subtitle:           fmt.Sprintf("%s • %s", target.OwnerName, formatDesignVersionRelative(lang, accountLibraryNow.Sub(target.UpdatedAt))),
			StatusLabel:        statusLabel,
			StatusTone:         statusTone,
			Registrability:     regLabel,
			RegistrabilityTone: regTone,
			AIScore:            libraryAIScoreLabel(lang, target.AIScore),
			PreviewImage:       target.PreviewImage,
			PreviewAlt:         target.PreviewAlt,
			PreviewMeta:        previewMeta,
			Tags:               tags,
			Owner:              target.OwnerName,
			OwnerRole:          target.OwnerRole,
			UpdatedRelative:    formatDesignVersionRelative(lang, accountLibraryNow.Sub(target.UpdatedAt)),
			UpdatedExact:       target.UpdatedAt.Format("2006-01-02 15:04"),
			CreatedExact:       target.CreatedAt.Format("2006-01-02 15:04"),
			CreatedRelative:    formatDesignVersionRelative(lang, accountLibraryNow.Sub(target.CreatedAt)),
			TemplateName:       target.TemplateName,
			TemplateHref:       target.TemplateHref,
			Metrics:            metrics,
			Properties:         props,
			QuickLinks:         quickLinks,
			Activity:           activity,
		},
	}

	return drawer
}

func accountLibraryStatusLabelTone(lang, status string) (string, string) {
	meta, ok := accountLibraryStatusCatalog[status]
	if !ok {
		if lang == "ja" {
			return "不明", "muted"
		}
		return titleCaseASCII(status), "muted"
	}
	if lang == "ja" {
		return meta.LabelJA, meta.Tone
	}
	return meta.LabelEN, meta.Tone
}

func accountLibraryRegistrability(lang string, d accountLibraryDesign) (string, string) {
	if d.Registrable {
		if lang == "ja" {
			return "登録可", "success"
		}
		return "Registrable", "success"
	}
	label := d.Registrability
	if label == "" {
		if lang == "ja" {
			return "要確認", "warning"
		}
		return "Needs review", "warning"
	}
	return label, "warning"
}

func accountLibraryTagLabel(lang, tag string) string {
	if meta, ok := accountLibraryTagCatalog[tag]; ok {
		if lang == "ja" {
			return meta.LabelJA
		}
		return meta.LabelEN
	}
	return tag
}

func libraryAIScoreLabel(lang string, score int) string {
	if lang == "ja" {
		return fmt.Sprintf("AIスコア %d", score)
	}
	return fmt.Sprintf("AI score %d", score)
}

func libraryDuplicateLabel(lang string) string {
	if lang == "ja" {
		return "複製"
	}
	return "Duplicate"
}

func libraryExportLabel(lang string) string {
	if lang == "ja" {
		return "エクスポート"
	}
	return "Export"
}

func libraryShareLabel(lang string) string {
	if lang == "ja" {
		return "共有"
	}
	return "Share"
}

func libraryDeleteLabel(lang string) string {
	if lang == "ja" {
		return "削除"
	}
	return "Delete"
}

func libraryDeleteConfirm(lang string) string {
	if lang == "ja" {
		return "選択したデザインを削除しますか？"
	}
	return "Delete selected designs?"
}

func libraryMetricExports(lang string) string {
	if lang == "ja" {
		return "エクスポート"
	}
	return "Exports"
}

func libraryMetricShares(lang string) string {
	if lang == "ja" {
		return "共有"
	}
	return "Shares"
}

func libraryMetricOrders(lang string) string {
	if lang == "ja" {
		return "再注文"
	}
	return "Reorders"
}

func libraryMetricApprovals(lang string) string {
	if lang == "ja" {
		return "承認済み"
	}
	return "Approvals"
}

func libraryPropertyTemplate(lang string) string {
	if lang == "ja" {
		return "テンプレート"
	}
	return "Template"
}

func libraryPropertyUpdated(lang string) string {
	if lang == "ja" {
		return "最終更新"
	}
	return "Last updated"
}

func libraryPropertyCreated(lang string) string {
	if lang == "ja" {
		return "作成日"
	}
	return "Created"
}

func libraryPropertyRegistrability(lang string) string {
	if lang == "ja" {
		return "登録可否"
	}
	return "Registrability"
}

func libraryHintUpdated(lang string) string {
	if lang == "ja" {
		return "JST"
	}
	return "JST"
}

func libraryActionOpenEditor(lang string) string {
	if lang == "ja" {
		return "エディタで開く"
	}
	return "Open in editor"
}

func libraryActionOpenEditorDesc(lang string) string {
	if lang == "ja" {
		return "次の改稿や修正をすぐに開始できます。"
	}
	return "Jump back into the editor for quick revisions."
}

func libraryActionVersions(lang string) string {
	if lang == "ja" {
		return "バージョン履歴"
	}
	return "Version history"
}

func libraryActionVersionsDesc(lang string) string {
	if lang == "ja" {
		return "AI改稿や承認済みの履歴を一覧できます。"
	}
	return "Review AI iterations and approved history."
}

func libraryActionShare(lang string) string {
	if lang == "ja" {
		return "共有リンク"
	}
	return "Share link"
}

func libraryActionShareDesc(lang string) string {
	if lang == "ja" {
		return "ウォーターマーク付きで安全に共有します。"
	}
	return "Generate signed links with watermark defaults."
}

func normalizeAccountLibraryStatus(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))
	if s == "" {
		return "all"
	}
	if s == "all" {
		return s
	}
	if _, ok := accountLibraryStatusCatalog[s]; ok {
		return s
	}
	return "all"
}

func normalizeAccountLibraryTag(t string) string {
	t = strings.TrimSpace(strings.ToLower(t))
	if t == "" {
		return "all"
	}
	if t == "all" {
		return t
	}
	if _, ok := accountLibraryTagCatalog[t]; ok {
		return t
	}
	return "all"
}

func normalizeAccountLibrarySort(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))
	if s == "" {
		return "updated"
	}
	for _, opt := range accountLibrarySortCatalog {
		if opt.ID == s {
			return s
		}
	}
	return "updated"
}

func parseAccountLibraryPage(raw string) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 1
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 1 {
		return 1
	}
	return n
}

func parseAccountLibrarySelected(vals []string) []string {
	if len(vals) == 0 {
		return nil
	}
	seen := map[string]struct{}{}
	out := make([]string, 0, len(vals))
	for _, v := range vals {
		if normalized, ok := normalizeDesignID(v); ok {
			if _, exists := seen[normalized]; exists {
				continue
			}
			seen[normalized] = struct{}{}
			out = append(out, normalized)
		}
	}
	return out
}

func containsString(list []string, target string) bool {
	for _, v := range list {
		if v == target {
			return true
		}
	}
	return false
}

func librarySearchIndex(d accountLibraryDesign) string {
	var buf strings.Builder
	buf.WriteString(strings.ToLower(d.Name))
	buf.WriteByte(' ')
	buf.WriteString(strings.ToLower(d.TemplateName))
	buf.WriteByte(' ')
	buf.WriteString(strings.ToLower(d.OwnerName))
	buf.WriteByte(' ')
	buf.WriteString(strings.ToLower(d.Shape))
	buf.WriteByte(' ')
	buf.WriteString(strings.ToLower(d.SizeLabel))
	buf.WriteByte(' ')
	buf.WriteString(strings.ToLower(d.Material))
	for _, tag := range d.Tags {
		meta, ok := accountLibraryTagCatalog[tag]
		if ok {
			buf.WriteByte(' ')
			buf.WriteString(strings.ToLower(meta.LabelEN))
			buf.WriteByte(' ')
			buf.WriteString(strings.ToLower(meta.LabelJA))
		} else {
			buf.WriteByte(' ')
			buf.WriteString(strings.ToLower(tag))
		}
	}
	return buf.String()
}

func accountLibraryMockDesigns(lang string) []accountLibraryDesign {
	return []accountLibraryDesign{
		{
			ID:             "df-219a",
			Name:           i18nOrDefault(lang, "account.library.design.corporate.name", "Corporate seal · board approval"),
			TemplateID:     "tpl-ring-corporate",
			TemplateName:   i18nOrDefault(lang, "account.library.design.corporate.template", "Corporate ring template"),
			TemplateHref:   "/templates/tpl-ring-corporate",
			Status:         "approved",
			Registrable:    true,
			Registrability: i18nOrDefault(lang, "account.library.design.corporate.reg", "Certified for legal filings"),
			AIScore:        92,
			Shape:          "round",
			SizeLabel:      "18 mm",
			Material:       "wood",
			Tags:           []string{"corporate", "ai", "regulatory"},
			UpdatedAt:      accountLibraryNow.Add(-3 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-14 * 24 * time.Hour),
			OwnerName:      "Haruka Sato",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.corporate", "Legal operations"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-219a/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.corporate.alt", "Corporate ring seal"),
			ExportCount:    18,
			LastExport:     accountLibraryNow.Add(-2 * time.Hour),
			ShareCount:     9,
			LastShare:      accountLibraryNow.Add(-26 * time.Hour),
			DuplicateCount: 3,
			LastDuplicate:  accountLibraryNow.Add(-7 * 24 * time.Hour),
			OrdersCount:    12,
			ApprovalsCount: 6,
			Notes:          i18nOrDefault(lang, "account.library.design.corporate.notes", "Approved for corporate registry filings and capped with legal watermark."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.export.pdf.title", "Exported proof sheet (PDF)"),
					Description: i18nOrDefault(lang, "account.library.activity.export.pdf.desc", "Submitted to legal affairs bureau."),
					Timestamp:   accountLibraryNow.Add(-2 * time.Hour),
					Icon:        "arrow-down-tray",
					Tone:        "indigo",
				},
				{
					Title:       i18nOrDefault(lang, "account.library.activity.share.title", "Shared watermark link"),
					Description: i18nOrDefault(lang, "account.library.activity.share.desc", "Sent to external corporate secretary."),
					Timestamp:   accountLibraryNow.Add(-26 * time.Hour),
					Icon:        "share",
					Tone:        "violet",
				},
				{
					Title:       i18nOrDefault(lang, "account.library.activity.order.title", "Reorder completed"),
					Description: i18nOrDefault(lang, "account.library.activity.order.desc", "Hinoki 18mm production run dispatched."),
					Timestamp:   accountLibraryNow.Add(-3 * 24 * time.Hour),
					Icon:        "truck",
					Tone:        "emerald",
				},
			},
		},
		{
			ID:             "df-982c",
			Name:           i18nOrDefault(lang, "account.library.design.finance.name", "Finance audit seal"),
			TemplateID:     "tpl-rect-ledger",
			TemplateName:   i18nOrDefault(lang, "account.library.design.finance.template", "Ledger rectangular template"),
			TemplateHref:   "/templates/tpl-rect-ledger",
			Status:         "pending",
			Registrable:    false,
			Registrability: i18nOrDefault(lang, "account.library.design.finance.reg", "Awaiting address confirmation"),
			AIScore:        88,
			Shape:          "rect",
			SizeLabel:      "55 × 18 mm",
			Material:       "metal",
			Tags:           []string{"finance", "regulatory", "team"},
			UpdatedAt:      accountLibraryNow.Add(-9 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-6 * 24 * time.Hour),
			OwnerName:      "Takuya Mori",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.finance", "Finance controller"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-982c/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.finance.alt", "Finance ledger seal"),
			ExportCount:    7,
			LastExport:     accountLibraryNow.Add(-9 * time.Hour),
			ShareCount:     3,
			LastShare:      accountLibraryNow.Add(-11 * time.Hour),
			DuplicateCount: 2,
			LastDuplicate:  accountLibraryNow.Add(-4 * 24 * time.Hour),
			OrdersCount:    4,
			ApprovalsCount: 2,
			Notes:          i18nOrDefault(lang, "account.library.design.finance.notes", "Finance audit series pending director signature."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.submitted.title", "Submitted for director approval"),
					Description: i18nOrDefault(lang, "account.library.activity.submitted.desc", "Awaiting director stamp verification."),
					Timestamp:   accountLibraryNow.Add(-9 * time.Hour),
					Icon:        "paper-airplane",
					Tone:        "amber",
				},
				{
					Title:       i18nOrDefault(lang, "account.library.activity.comment.title", "Comment added by finance"),
					Description: i18nOrDefault(lang, "account.library.activity.comment.desc", "Requested address line adjustment."),
					Timestamp:   accountLibraryNow.Add(-12 * time.Hour),
					Icon:        "chat-bubble-oval-left-ellipsis",
					Tone:        "slate",
				},
			},
		},
		{
			ID:             "df-441k",
			Name:           i18nOrDefault(lang, "account.library.design.event.name", "Pop-up event seal"),
			TemplateID:     "tpl-square-brand",
			TemplateName:   i18nOrDefault(lang, "account.library.design.event.template", "Campaign square template"),
			TemplateHref:   "/templates/tpl-square-brand",
			Status:         "needs-review",
			Registrable:    false,
			Registrability: i18nOrDefault(lang, "account.library.design.event.reg", "Resubmission required for contrast"),
			AIScore:        76,
			Shape:          "square",
			SizeLabel:      "30 mm",
			Material:       "rubber",
			Tags:           []string{"event", "ai-iteration"},
			UpdatedAt:      accountLibraryNow.Add(-16 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-9 * 24 * time.Hour),
			OwnerName:      "Mika Kato",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.event", "Brand studio"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-441k/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.event.alt", "Event square seal"),
			ExportCount:    4,
			LastExport:     accountLibraryNow.Add(-3 * 24 * time.Hour),
			ShareCount:     5,
			LastShare:      accountLibraryNow.Add(-16 * time.Hour),
			DuplicateCount: 5,
			LastDuplicate:  accountLibraryNow.Add(-2 * time.Hour),
			OrdersCount:    1,
			ApprovalsCount: 0,
			Notes:          i18nOrDefault(lang, "account.library.design.event.notes", "Needs darker ink for pop-up signage."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.feedback.title", "Feedback requested"),
					Description: i18nOrDefault(lang, "account.library.activity.feedback.desc", "Marketing asked for higher contrast variant."),
					Timestamp:   accountLibraryNow.Add(-16 * time.Hour),
					Icon:        "exclamation-triangle",
					Tone:        "rose",
				},
				{
					Title:       i18nOrDefault(lang, "account.library.activity.ai.title", "AI iteration generated"),
					Description: i18nOrDefault(lang, "account.library.activity.ai.desc", "New variation created via AI assist."),
					Timestamp:   accountLibraryNow.Add(-18 * time.Hour),
					Icon:        "sparkles",
					Tone:        "violet",
				},
			},
		},
		{
			ID:             "df-771m",
			Name:           i18nOrDefault(lang, "account.library.design.legacy.name", "Legacy branch transfer"),
			TemplateID:     "tpl-ring-classic",
			TemplateName:   i18nOrDefault(lang, "account.library.design.legacy.template", "Classic ring template"),
			TemplateHref:   "/templates/tpl-ring-classic",
			Status:         "draft",
			Registrable:    false,
			Registrability: i18nOrDefault(lang, "account.library.design.legacy.reg", "Legacy import – verification pending"),
			AIScore:        63,
			Shape:          "round",
			SizeLabel:      "21 mm",
			Material:       "wood",
			Tags:           []string{"legacy", "team"},
			UpdatedAt:      accountLibraryNow.Add(-34 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-34 * time.Hour),
			OwnerName:      "Sho Tanabe",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.legacy", "Operations"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-771m/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.legacy.alt", "Legacy branch seal"),
			ExportCount:    0,
			ShareCount:     1,
			DuplicateCount: 0,
			OrdersCount:    0,
			ApprovalsCount: 0,
			Notes:          i18nOrDefault(lang, "account.library.design.legacy.notes", "Imported from legacy system. Requires glyph normalization."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.import.title", "Imported legacy design"),
					Description: i18nOrDefault(lang, "account.library.activity.import.desc", "Uploaded by operations system import."),
					Timestamp:   accountLibraryNow.Add(-34 * time.Hour),
					Icon:        "arrow-up-tray",
					Tone:        "slate",
				},
			},
		},
		{
			ID:             "df-884p",
			Name:           i18nOrDefault(lang, "account.library.design.approval.name", "Supplier approval seal"),
			TemplateID:     "tpl-rect-ledger",
			TemplateName:   i18nOrDefault(lang, "account.library.design.approval.template", "Ledger rectangular template"),
			TemplateHref:   "/templates/tpl-rect-ledger",
			Status:         "approved",
			Registrable:    true,
			Registrability: i18nOrDefault(lang, "account.library.design.approval.reg", "Approved for supplier onboarding"),
			AIScore:        82,
			Shape:          "rect",
			SizeLabel:      "60 × 20 mm",
			Material:       "rubber",
			Tags:           []string{"team", "regulatory"},
			UpdatedAt:      accountLibraryNow.Add(-48 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-18 * 24 * time.Hour),
			OwnerName:      "Misaki Endo",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.approval", "Procurement"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-884p/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.approval.alt", "Supplier approval seal"),
			ExportCount:    12,
			LastExport:     accountLibraryNow.Add(-48 * time.Hour),
			ShareCount:     6,
			LastShare:      accountLibraryNow.Add(-50 * time.Hour),
			DuplicateCount: 1,
			LastDuplicate:  accountLibraryNow.Add(-10 * 24 * time.Hour),
			OrdersCount:    5,
			ApprovalsCount: 5,
			Notes:          i18nOrDefault(lang, "account.library.design.approval.notes", "Used across supplier agreements."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.export.svg.title", "Exported production SVG"),
					Description: i18nOrDefault(lang, "account.library.activity.export.svg.desc", "Delivered to engraving partner."),
					Timestamp:   accountLibraryNow.Add(-48 * time.Hour),
					Icon:        "cube-transparent",
					Tone:        "emerald",
				},
				{
					Title:       i18nOrDefault(lang, "account.library.activity.share.bulk.title", "Share pack generated"),
					Description: i18nOrDefault(lang, "account.library.activity.share.bulk.desc", "Proof pack sent to supplier onboarding."),
					Timestamp:   accountLibraryNow.Add(-50 * time.Hour),
					Icon:        "share",
					Tone:        "violet",
				},
			},
		},
		{
			ID:             "df-553s",
			Name:           i18nOrDefault(lang, "account.library.design.aiSeries.name", "AI exploration series"),
			TemplateID:     "tpl-ring-corporate",
			TemplateName:   i18nOrDefault(lang, "account.library.design.aiSeries.template", "Corporate ring template"),
			TemplateHref:   "/templates/tpl-ring-corporate",
			Status:         "draft",
			Registrable:    false,
			Registrability: i18nOrDefault(lang, "account.library.design.aiSeries.reg", "Awaiting manual review"),
			AIScore:        94,
			Shape:          "round",
			SizeLabel:      "18 mm",
			Material:       "wood",
			Tags:           []string{"ai", "ai-iteration"},
			UpdatedAt:      accountLibraryNow.Add(-5 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-2 * 24 * time.Hour),
			OwnerName:      "Naoki Abe",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.aiSeries", "Design research"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-553s/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.aiSeries.alt", "AI exploration seal"),
			ExportCount:    2,
			LastExport:     accountLibraryNow.Add(-5 * time.Hour),
			ShareCount:     8,
			LastShare:      accountLibraryNow.Add(-6 * time.Hour),
			DuplicateCount: 6,
			LastDuplicate:  accountLibraryNow.Add(-8 * time.Hour),
			OrdersCount:    0,
			ApprovalsCount: 1,
			Notes:          i18nOrDefault(lang, "account.library.design.aiSeries.notes", "Batch of AI assisted iterations for review."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.ai.batch.title", "Generated 3 AI variants"),
					Description: i18nOrDefault(lang, "account.library.activity.ai.batch.desc", "Auto applied contrast improvements."),
					Timestamp:   accountLibraryNow.Add(-7 * time.Hour),
					Icon:        "sparkles",
					Tone:        "violet",
				},
			},
		},
		{
			ID:             "df-633t",
			Name:           i18nOrDefault(lang, "account.library.design.contract.name", "Contract approval seal"),
			TemplateID:     "tpl-ring-corporate",
			TemplateName:   i18nOrDefault(lang, "account.library.design.contract.template", "Corporate ring template"),
			TemplateHref:   "/templates/tpl-ring-corporate",
			Status:         "approved",
			Registrable:    true,
			Registrability: i18nOrDefault(lang, "account.library.design.contract.reg", "Approved for nationwide contract filings"),
			AIScore:        89,
			Shape:          "round",
			SizeLabel:      "15 mm",
			Material:       "wood",
			Tags:           []string{"corporate", "team"},
			UpdatedAt:      accountLibraryNow.Add(-6 * 24 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-24 * 24 * time.Hour),
			OwnerName:      "Haruka Sato",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.contract", "Legal operations"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-633t/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.contract.alt", "Contract approval seal"),
			ExportCount:    23,
			LastExport:     accountLibraryNow.Add(-6 * 24 * time.Hour),
			ShareCount:     11,
			LastShare:      accountLibraryNow.Add(-7 * 24 * time.Hour),
			DuplicateCount: 4,
			LastDuplicate:  accountLibraryNow.Add(-12 * 24 * time.Hour),
			OrdersCount:    14,
			ApprovalsCount: 8,
			Notes:          i18nOrDefault(lang, "account.library.design.contract.notes", "Primary contract seal with registrable glyphs."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.approved.title", "Board approval logged"),
					Description: i18nOrDefault(lang, "account.library.activity.approved.desc", "Board meeting minutes recorded."),
					Timestamp:   accountLibraryNow.Add(-8 * 24 * time.Hour),
					Icon:        "check-badge",
					Tone:        "emerald",
				},
			},
		},
		{
			ID:             "df-904r",
			Name:           i18nOrDefault(lang, "account.library.design.archive.name", "Archived seasonal seal"),
			TemplateID:     "tpl-square-brand",
			TemplateName:   i18nOrDefault(lang, "account.library.design.archive.template", "Campaign square template"),
			TemplateHref:   "/templates/tpl-square-brand",
			Status:         "archived",
			Registrable:    false,
			Registrability: i18nOrDefault(lang, "account.library.design.archive.reg", "Retired seasonal asset"),
			AIScore:        71,
			Shape:          "square",
			SizeLabel:      "24 mm",
			Material:       "rubber",
			Tags:           []string{"event"},
			UpdatedAt:      accountLibraryNow.Add(-64 * time.Hour),
			CreatedAt:      accountLibraryNow.Add(-90 * 24 * time.Hour),
			OwnerName:      "Mika Kato",
			OwnerRole:      i18nOrDefault(lang, "account.library.design.owner.archive", "Brand studio"),
			PreviewImage:   "https://cdn.hanko-field.app/designs/df-904r/preview.png",
			PreviewAlt:     i18nOrDefault(lang, "account.library.design.archive.alt", "Archived seasonal seal"),
			ExportCount:    9,
			LastExport:     accountLibraryNow.Add(-70 * time.Hour),
			ShareCount:     2,
			LastShare:      accountLibraryNow.Add(-80 * time.Hour),
			DuplicateCount: 0,
			OrdersCount:    0,
			ApprovalsCount: 1,
			Notes:          i18nOrDefault(lang, "account.library.design.archive.notes", "Archived after campaign; kept for reference."),
			Activity: []accountLibraryActivity{
				{
					Title:       i18nOrDefault(lang, "account.library.activity.archived.title", "Archived to cold storage"),
					Description: i18nOrDefault(lang, "account.library.activity.archived.desc", "Retired after autumn campaign."),
					Timestamp:   accountLibraryNow.Add(-64 * time.Hour),
					Icon:        "archive-box",
					Tone:        "slate",
				},
			},
		},
	}
}
