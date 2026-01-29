package main

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

// DesignKanjiMapHandler renders the standalone kanji mapping tool page.
func DesignKanjiMapHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	name := strings.TrimSpace(r.URL.Query().Get("name"))

	candidates := kanjiMappingCandidates(lang, name)
	view := map[string]any{
		"Lang":        lang,
		"Name":        name,
		"Candidates":  candidates,
		"HasName":     name != "",
		"HasResults":  len(candidates) > 0,
		"LastUpdated": time.Now(),
		"Standalone":  true,
	}

	pageTitle := editorCopy(lang, "漢字マッピングツール", "Kanji mapping tool")
	desc := editorCopy(lang, "氏名の漢字表記と代替候補を確認し、編集画面へ反映できます。", "Review mapped kanji candidates and open them in the editor.")

	vm := handlersPkg.PageData{Title: pageTitle, Lang: lang}
	vm.Path = r.URL.Path
	vm.Nav = nav.Build(vm.Path)
	vm.Breadcrumbs = nav.Breadcrumbs(vm.Path)
	vm.Analytics = handlersPkg.LoadAnalyticsFromEnv()
	vm.FeatureFlags = handlersPkg.LoadFeatureFlags()
	vm.DesignKanjiMap = view

	brand := i18nOrDefault(lang, "brand.name", "Hanko Field")
	vm.SEO.Title = fmt.Sprintf("%s | %s", pageTitle, brand)
	vm.SEO.Description = desc
	vm.SEO.Canonical = absoluteURL(r)
	vm.SEO.OG.URL = vm.SEO.Canonical
	vm.SEO.OG.SiteName = brand
	vm.SEO.OG.Type = "website"
	vm.SEO.OG.Title = vm.SEO.Title
	vm.SEO.OG.Description = vm.SEO.Description
	vm.SEO.Twitter.Card = "summary_large_image"
	vm.SEO.Alternates = buildAlternates(r)

	renderPage(w, r, "design_kanji_mapper", vm)
}
