package main

import (
	"net/http"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

// AccountLibraryHandler renders the account design library.
func AccountLibraryHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)

	view := buildAccountLibraryPageView(lang, sess, r.URL.Query())

	title := i18nOrDefault(lang, "account.library.seo.title", "Account · Library")
	desc := i18nOrDefault(lang, "account.library.seo.desc", "Manage saved seals, track approvals, and export production-ready assets.")
	brand := i18nOrDefault(lang, "brand.name", "Hanko Field")

	vm := handlersPkg.PageData{
		Title:        title,
		Lang:         lang,
		Path:         r.URL.Path,
		Nav:          nav.Build(r.URL.Path),
		Breadcrumbs:  nav.Breadcrumbs(r.URL.Path),
		Analytics:    handlersPkg.LoadAnalyticsFromEnv(),
		FeatureFlags: handlersPkg.LoadFeatureFlags(),
		Account:      view,
	}

	vm.SEO.Title = title + " | " + brand
	vm.SEO.Description = desc
	vm.SEO.Canonical = absoluteURL(r)
	vm.SEO.OG.URL = vm.SEO.Canonical
	vm.SEO.OG.SiteName = brand
	vm.SEO.OG.Type = "website"
	vm.SEO.OG.Title = vm.SEO.Title
	vm.SEO.OG.Description = vm.SEO.Description
	vm.SEO.Alternates = buildAlternates(r)
	vm.SEO.Robots = "noindex, nofollow"

	renderPage(w, r, "account_library", vm)
}

// AccountLibraryTableHandler renders the design card grid fragment.
func AccountLibraryTableHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)

	view := buildAccountLibraryPageView(lang, sess, r.URL.Query())
	renderTemplate(w, r, "frag_account_library_table", view.Grid)
}

// AccountLibraryDrawerHandler renders the detail drawer fragment for a design.
func AccountLibraryDrawerHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)

	view := buildAccountLibraryPageView(lang, sess, r.URL.Query())
	renderTemplate(w, r, "frag_account_library_drawer", view.Drawer)
}
