package main

import (
	"fmt"
	"net/http"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
	"github.com/go-chi/chi/v5"
)

// AccountOrderDetailHandler renders the order detail page.
func AccountOrderDetailHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)
	orderID := chi.URLParam(r, "orderID")
	tab := r.URL.Query().Get("tab")

	view, ok := buildAccountOrderDetailPageView(lang, sess, orderID, tab)
	if !ok {
		http.NotFound(w, r)
		return
	}

	title := fmt.Sprintf("%s · %s", view.Header.Number, i18nOrDefault(lang, "account.order.seo.title", "Order detail"))
	desc := i18nOrDefault(lang, "account.order.seo.desc", "Monitor fulfillment progress, payments, and documents for this order.")
	brand := i18nOrDefault(lang, "brand.name", "Hanko Field")

	vm := handlersPkg.PageData{
		Title:        title,
		Lang:         lang,
		Path:         r.URL.Path,
		Nav:          nav.Build(r.URL.Path),
		Breadcrumbs:  nav.Breadcrumbs(r.URL.Path),
		Analytics:    handlersPkg.LoadAnalyticsFromEnv(),
		AccountOrder: view,
	}

	if len(vm.Breadcrumbs) > 0 {
		last := len(vm.Breadcrumbs) - 1
		vm.Breadcrumbs[last].Label = view.Header.Number
		vm.Breadcrumbs[last].LabelKey = ""
	}

	vm.SEO.Title = fmt.Sprintf("%s | %s", view.Header.Number, brand)
	vm.SEO.Description = desc
	vm.SEO.Canonical = absoluteURL(r)
	vm.SEO.OG.URL = vm.SEO.Canonical
	vm.SEO.OG.SiteName = brand
	vm.SEO.OG.Type = "website"
	vm.SEO.OG.Title = vm.SEO.Title
	vm.SEO.OG.Description = vm.SEO.Description
	vm.SEO.Alternates = buildAlternates(r)
	vm.SEO.Robots = "noindex, nofollow"

	renderPage(w, r, "account_order_detail", vm)
}

// AccountOrderDetailTabHandler renders a specific tab fragment.
func AccountOrderDetailTabHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	orderID := chi.URLParam(r, "orderID")
	tab := chi.URLParam(r, "tab")

	payload, ok := buildAccountOrderDetailTabPayload(lang, orderID, tab)
	if !ok {
		http.NotFound(w, r)
		return
	}

	templateName := ""
	switch tab {
	case "", "summary":
		templateName = "frag_account_order_summary"
	case "payments":
		templateName = "frag_account_order_payments"
	case "production":
		templateName = "frag_account_order_production"
	case "tracking":
		templateName = "frag_account_order_tracking"
	case "invoice":
		templateName = "frag_account_order_invoice"
	default:
		http.NotFound(w, r)
		return
	}

	targetURL := fmt.Sprintf("/account/orders/%s", orderID)
	if tab != "" && tab != "summary" {
		targetURL = targetURL + "?tab=" + tab
	}
	w.Header().Set("HX-Push-Url", targetURL)

	triggerPayload := fmt.Sprintf(`{"account-order:tab-changed":{"tab":"%s"}}`, tab)
	w.Header().Set("HX-Trigger", triggerPayload)

	renderTemplate(w, r, templateName, payload)
}
