package main

import (
	"net/http"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

// AccountSecurityHandler renders the account security page.
func AccountSecurityHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)

	view := buildAccountSecurityPageView(lang, sess)

	title := i18nOrDefault(lang, "account.security.seo.title", "Account · Security")
	desc := i18nOrDefault(lang, "account.security.seo.desc", "Manage linked sign-in providers, enforce multi-factor authentication, and monitor active sessions.")
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

	renderPage(w, r, "account_security", vm)
}
