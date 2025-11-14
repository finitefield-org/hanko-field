package main

import (
	"encoding/json"
	"net/http"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

// AccountHandler renders the account overview/profile page.
func AccountHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)

	view := buildAccountView(lang, sess)

	title := i18nOrDefault(lang, "account.seo.title", "Account · Profile")
	desc := i18nOrDefault(lang, "account.seo.desc", "Manage your profile, locale, notifications, and device sessions.")
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

	renderPage(w, r, "account", vm)
}

// AccountProfileFormHandler renders or updates the profile form fragment via htmx.
func AccountProfileFormHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)

	switch r.Method {
	case http.MethodGet:
		profile := sessionProfileOrFallback(sess.Profile, lang)
		view := buildAccountProfileFormView(lang, profile, nil, nil)
		renderTemplate(w, r, "frag_account_profile_form", view)
	case http.MethodPost:
		if err := r.ParseForm(); err != nil {
			http.Error(w, "invalid form", http.StatusBadRequest)
			return
		}
		input := parseAccountProfileForm(r.PostForm)
		errors := validateAccountProfileForm(input, lang)
		profile := sessionProfileOrFallback(sess.Profile, lang)
		if len(errors) > 0 {
			view := buildAccountProfileFormView(lang, profile, &input, errors)
			w.WriteHeader(http.StatusUnprocessableEntity)
			renderTemplate(w, r, "frag_account_profile_form", view)
			return
		}

		applyAccountProfileInput(sess, input)
		profile = sessionProfileOrFallback(sess.Profile, lang)
		view := buildAccountProfileFormView(lang, profile, nil, nil)

		payload := map[string]any{
			"account:profile:saved": map[string]string{
				"message":     i18nOrDefault(lang, "account.profile.saved", "Profile updated"),
				"displayName": profile.DisplayName,
				"language":    profile.Language,
				"country":     profile.Country,
			},
		}
		if raw, err := json.Marshal(payload); err == nil {
			w.Header().Set("HX-Trigger", string(raw))
		}

		renderTemplate(w, r, "frag_account_profile_form", view)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}
