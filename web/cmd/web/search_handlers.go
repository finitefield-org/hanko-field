package main

import (
	"context"
	"fmt"
	"html/template"
	"net/http"
	"strings"
	"time"

	"finitefield.org/hanko-web/internal/cms"
	"finitefield.org/hanko-web/internal/format"
	mw "finitefield.org/hanko-web/internal/middleware"
)

const (
	searchSourceProducts  = "products"
	searchSourceTemplates = "templates"
	searchSourceGuides    = "guides"
	searchSourceAccounts  = "accounts"
)

// SearchResultItem represents a single row in the global search overlay.
type SearchResultItem struct {
	Label       template.HTML
	Detail      template.HTML
	Description template.HTML
	PlainLabel  string
	PlainDetail string
	Meta        []string
	Badge       string
	BadgeTone   string
	Href        string
	Icon        string
	Accent      string
	ActionLabel string
	ActionIcon  string
}

// SearchResultsView powers the fragment template for a search result group.
type SearchResultsView struct {
	Lang        string
	Query       string
	Source      string
	SourceLabel string
	Results     []SearchResultItem
	Count       int
	Empty       bool
	EmptyLabel  string
	EmptyHelp   string
}

// SearchResultsFrag renders a fragment list of search results for a given source.
func SearchResultsFrag(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	source := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("source")))
	if source == "" {
		source = searchSourceProducts
	}
	query := strings.TrimSpace(r.URL.Query().Get("q"))

	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	view := buildSearchResultsView(ctx, lang, source, query)
	renderTemplate(w, r, "frag_search_results", view)
}

func buildSearchResultsView(ctx context.Context, lang, source, query string) SearchResultsView {
	q := strings.TrimSpace(query)
	view := SearchResultsView{
		Lang:   lang,
		Query:  q,
		Source: source,
	}

	switch source {
	case searchSourceTemplates:
		view.SourceLabel = i18nOrDefault(lang, "search.tabs.templates", "Templates")
		view.EmptyLabel = emptyLabelFor(lang, "search.empty.templates", q, "No templates match “%s”.")
		view.EmptyHelp = i18nOrDefault(lang, "search.empty.help.templates", "Try a writing style, size, or registrability keyword.")
		view.Results = searchTemplates(lang, q, 8)
	case searchSourceGuides:
		view.SourceLabel = i18nOrDefault(lang, "search.tabs.guides", "Guides")
		view.EmptyLabel = emptyLabelFor(lang, "search.empty.guides", q, "No guides found for “%s”.")
		view.EmptyHelp = i18nOrDefault(lang, "search.empty.help.guides", "Search by workshop, policy, or workflow topic.")
		view.Results = searchGuides(ctx, lang, q, 8)
	case searchSourceAccounts:
		view.SourceLabel = i18nOrDefault(lang, "search.tabs.accounts", "Accounts")
		view.EmptyLabel = emptyLabelFor(lang, "search.empty.accounts", q, "No account tools match “%s”.")
		view.EmptyHelp = i18nOrDefault(lang, "search.empty.help.accounts", "Navigate directly to profile, orders, or security settings.")
		view.Results = searchAccounts(lang, q, 8)
	default:
		view.Source = searchSourceProducts
		view.SourceLabel = i18nOrDefault(lang, "search.tabs.products", "Products")
		view.EmptyLabel = emptyLabelFor(lang, "search.empty.products", q, "No products match “%s”.")
		view.EmptyHelp = i18nOrDefault(lang, "search.empty.help.products", "Try material, size, or template keywords.")
		view.Results = searchProducts(lang, q, 8)
	}

	view.Count = len(view.Results)
	view.Empty = view.Count == 0
	return view
}

func emptyLabelFor(lang, key, query, fallback string) string {
	q := strings.TrimSpace(query)
	if q == "" {
		blankKey := key + ".blank"
		blankFallback := strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(fallback, "“%s”", ""), "%s", ""))
		if blankFallback == "" {
			blankFallback = fallback
		}
		blank := strings.TrimSpace(i18nOrDefault(lang, blankKey, blankFallback))
		if blank != "" {
			return blank
		}
		return blankFallback
	}
	label := i18nOrDefault(lang, key, fallback)
	if strings.Contains(label, "%s") {
		return fmt.Sprintf(label, q)
	}
	return strings.TrimSpace(label + " “" + q + "”")
}

func searchProducts(lang, query string, limit int) []SearchResultItem {
	items := productData(lang)
	queryLower := strings.ToLower(query)
	matchAll := queryLower == ""
	results := make([]SearchResultItem, 0, min(limit, len(items)))

	for _, p := range items {
		hay := strings.ToLower(strings.Join([]string{
			p.Name,
			materialLabel(lang, p.Material),
			shapeLabel(lang, p.Shape),
			sizeLabel(lang, p.Size),
		}, " "))
		if !matchAll && !strings.Contains(hay, queryLower) {
			continue
		}

		price := format.FmtCurrency(p.PriceJPY, "JPY", lang)
		detail := fmt.Sprintf("%s • %s • %s",
			shapeLabel(lang, p.Shape),
			sizeLabel(lang, p.Size),
			materialLabel(lang, p.Material),
		)
		description := i18nOrDefault(lang, "search.product.description", "Precision-carved seal with balanced kerning and courier tracking.")

		badge := ""
		badgeTone := ""
		if p.Sale {
			badge = i18nOrDefault(lang, "search.badge.sale", "Sale")
			badgeTone = "bg-rose-100 text-rose-700"
		} else if !p.InStock {
			badge = i18nOrDefault(lang, "search.badge.backorder", "Backorder")
			badgeTone = "bg-amber-100 text-amber-800"
		}

		meta := []string{
			price,
			fmt.Sprintf("%s · %s", shapeLabel(lang, p.Shape), sizeLabel(lang, p.Size)),
			materialLabel(lang, p.Material),
		}
		if m := measurementFor(p.Shape, p.Size); m != "" {
			meta = append(meta, m)
		}

		results = append(results, SearchResultItem{
			Label:       highlightMatch(p.Name, query),
			Detail:      highlightMatch(detail, query),
			Description: highlightMatch(description, query),
			PlainLabel:  p.Name,
			PlainDetail: detail,
			Meta:        meta,
			Badge:       badge,
			BadgeTone:   badgeTone,
			Href:        fmt.Sprintf("/products/%s", p.ID),
			Icon:        "shopping-bag",
			Accent:      accentForMaterial(p.Material),
			ActionLabel: i18nOrDefault(lang, "search.action.view_product", "View product"),
			ActionIcon:  "chevron-right",
		})

		if limit > 0 && len(results) >= limit {
			break
		}
	}

	return results
}

func searchTemplates(lang, query string, limit int) []SearchResultItem {
	data := templateData(lang)
	queryLower := strings.ToLower(query)
	matchAll := queryLower == ""
	results := make([]SearchResultItem, 0, min(limit, len(data)))

	for _, tpl := range data {
		hay := strings.ToLower(strings.Join([]string{
			tpl.Name,
			tpl.Summary,
			tpl.Script,
			tpl.ScriptLabel,
			tpl.Category,
			tpl.CategoryLabel,
			tpl.Style,
			tpl.StyleLabel,
			strings.Join(tpl.Tags, " "),
		}, " "))
		if !matchAll && !strings.Contains(hay, queryLower) {
			continue
		}

		detailParts := []string{}
		if tpl.ScriptLabel != "" {
			detailParts = append(detailParts, tpl.ScriptLabel)
		}
		if tpl.CategoryLabel != "" {
			detailParts = append(detailParts, tpl.CategoryLabel)
		}
		if tpl.PrimarySize != "" {
			detailParts = append(detailParts, tpl.PrimarySize)
		}
		detail := strings.Join(detailParts, " • ")

		meta := []string{}
		if tpl.ScriptLabel != "" {
			meta = append(meta, tpl.ScriptLabel)
		}
		if tpl.CategoryLabel != "" {
			meta = append(meta, tpl.CategoryLabel)
		}
		if tpl.PrimarySize != "" {
			meta = append(meta, tpl.PrimarySize)
		}
		if tpl.Usage > 0 {
			meta = append(meta, fmt.Sprintf(i18nOrDefault(lang, "search.meta.usage", "%d uses"), tpl.Usage))
		}
		if !tpl.Updated.IsZero() {
			meta = append(meta, fmt.Sprintf(i18nOrDefault(lang, "search.meta.updated", "Updated %s"), format.FmtDate(tpl.Updated, lang)))
		}

		badgeTone := ""
		if tpl.Badge != "" {
			badgeTone = "bg-indigo-100 text-indigo-700"
		}

		results = append(results, SearchResultItem{
			Label:       highlightMatch(tpl.Name, query),
			Detail:      highlightMatch(detail, query),
			Description: highlightMatch(tpl.Summary, query),
			PlainLabel:  tpl.Name,
			PlainDetail: detail,
			Meta:        meta,
			Badge:       tpl.Badge,
			BadgeTone:   badgeTone,
			Href:        "/templates/" + tpl.ID,
			Icon:        "layers",
			Accent:      "bg-indigo-100 text-indigo-700",
			ActionLabel: i18nOrDefault(lang, "search.action.view_template", "View template"),
			ActionIcon:  "chevron-right",
		})

		if limit > 0 && len(results) >= limit {
			break
		}
	}

	return results
}

func searchGuides(ctx context.Context, lang, query string, limit int) []SearchResultItem {
	opts := cms.ListGuidesOptions{
		Lang:  lang,
		Limit: limit,
	}
	if strings.TrimSpace(query) != "" {
		opts.Search = query
	}

	guides, err := cmsClient.ListGuides(ctx, opts)
	if err != nil {
		mw.ContextLogger(ctx).Warn("search guides fetch failed", "error", err, "query", query, "lang", lang)
	}

	results := make([]SearchResultItem, 0, len(guides))
	for _, g := range guides {
		detailParts := []string{}
		if label := guideCategoryLabel(lang, g.Category); label != "" {
			detailParts = append(detailParts, label)
		}
		if rt := guideReadingTimeLabel(lang, g.ReadingTimeMinutes); rt != "" {
			detailParts = append(detailParts, rt)
		}
		detail := strings.Join(detailParts, " • ")

		meta := []string{}
		if !g.PublishAt.IsZero() {
			meta = append(meta, format.FmtDate(g.PublishAt, lang))
		} else if !g.UpdatedAt.IsZero() {
			meta = append(meta, format.FmtDate(g.UpdatedAt, lang))
		}
		if len(g.Tags) > 0 {
			meta = append(meta, strings.Join(g.Tags[:min(len(g.Tags), 2)], ", "))
		}

		results = append(results, SearchResultItem{
			Label:       highlightMatch(g.Title, query),
			Detail:      highlightMatch(detail, query),
			Description: highlightMatch(g.Summary, query),
			PlainLabel:  g.Title,
			PlainDetail: detail,
			Meta:        meta,
			Href:        "/guides/" + g.Slug,
			Icon:        "document-text",
			Accent:      "bg-emerald-100 text-emerald-700",
			ActionLabel: i18nOrDefault(lang, "search.action.open_guide", "Open guide"),
			ActionIcon:  "chevron-right",
		})
	}

	return results
}

func searchAccounts(lang, query string, limit int) []SearchResultItem {
	navItems := accountNavItems(lang, "")
	queryLower := strings.ToLower(query)
	matchAll := queryLower == ""
	results := make([]SearchResultItem, 0, min(limit, len(navItems)))

	for _, item := range navItems {
		hay := strings.ToLower(strings.Join([]string{
			item.Label,
			item.Description,
			item.Badge,
		}, " "))
		if !matchAll && !strings.Contains(hay, queryLower) {
			continue
		}

		accent := "bg-sky-100 text-sky-700"
		badgeTone := ""
		if item.Badge != "" {
			badgeTone = "bg-sky-100 text-sky-700"
		}

		results = append(results, SearchResultItem{
			Label:       highlightMatch(item.Label, query),
			Detail:      highlightMatch(item.Description, query),
			Description: highlightMatch(i18nOrDefault(lang, "search.account.description", "Manage approvals, addresses, and account automation."), query),
			PlainLabel:  item.Label,
			PlainDetail: item.Description,
			Meta:        nil,
			Badge:       item.Badge,
			BadgeTone:   badgeTone,
			Href:        item.Href,
			Icon:        item.Icon,
			Accent:      accent,
			ActionLabel: i18nOrDefault(lang, "search.action.open_section", "Open section"),
			ActionIcon:  "chevron-right",
		})

		if limit > 0 && len(results) >= limit {
			break
		}
	}

	return results
}

func highlightMatch(text, query string) template.HTML {
	text = strings.TrimSpace(text)
	if text == "" {
		return ""
	}
	if query == "" {
		return template.HTML(template.HTMLEscapeString(text))
	}

	lower := strings.ToLower(text)
	qLower := strings.ToLower(query)
	if !strings.Contains(lower, qLower) {
		return template.HTML(template.HTMLEscapeString(text))
	}

	var b strings.Builder
	offset := 0
	for {
		idx := strings.Index(lower[offset:], qLower)
		if idx < 0 {
			b.WriteString(template.HTMLEscapeString(text[offset:]))
			break
		}
		start := offset + idx
		end := start + len(query)
		b.WriteString(template.HTMLEscapeString(text[offset:start]))
		b.WriteString(`<mark class="rounded bg-amber-200/70 px-0.5 py-px text-amber-900">`)
		b.WriteString(template.HTMLEscapeString(text[start:end]))
		b.WriteString(`</mark>`)
		offset = end
		if offset >= len(text) {
			break
		}
	}

	return template.HTML(b.String())
}

func accentForMaterial(material string) string {
	switch strings.ToLower(material) {
	case "wood":
		return "bg-amber-100 text-amber-800"
	case "rubber":
		return "bg-emerald-100 text-emerald-700"
	case "metal":
		return "bg-slate-200 text-slate-800"
	default:
		return "bg-slate-200 text-slate-700"
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
