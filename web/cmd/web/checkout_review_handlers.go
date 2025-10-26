package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

// CheckoutReviewHandler renders the final order review step.
func CheckoutReviewHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)
	view := buildCheckoutReviewView(lang, r.URL.Query(), sess)

	title := i18nOrDefault(lang, "checkout.review.title", "Checkout · Review & confirm")
	desc := i18nOrDefault(lang, "checkout.review.desc", "Confirm engraving details, fulfillment, and payment before placing the order.")

	vm := handlersPkg.PageData{
		Title:       title,
		Lang:        lang,
		Path:        r.URL.Path,
		Nav:         nav.Build(r.URL.Path),
		Breadcrumbs: nav.Breadcrumbs(r.URL.Path),
		Analytics:   handlersPkg.LoadAnalyticsFromEnv(),
		Checkout:    view,
	}

	brand := i18nOrDefault(lang, "brand.name", "Hanko Field")
	vm.SEO.Title = title + " | " + brand
	vm.SEO.Description = desc
	vm.SEO.Canonical = absoluteURL(r)
	vm.SEO.OG.URL = vm.SEO.Canonical
	vm.SEO.OG.SiteName = brand
	vm.SEO.OG.Title = vm.SEO.Title
	vm.SEO.OG.Description = vm.SEO.Description
	vm.SEO.OG.Type = "website"
	vm.SEO.Twitter.Card = "summary_large_image"
	vm.SEO.Alternates = buildAlternates(r)
	vm.SEO.Robots = "noindex, nofollow"

	renderPage(w, r, "checkout_review", vm)
}

// CheckoutReviewSubmitHandler acknowledges the final confirmation CTA.
func CheckoutReviewSubmitHandler(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid form", http.StatusBadRequest)
		return
	}
	lang := mw.Lang(r)
	accept := strings.TrimSpace(r.FormValue("accept_terms")) != ""
	if !accept {
		renderCheckoutReviewStatus(w, r, lang, "error", i18nOrDefault(lang, "checkout.review.submit.error", "Accept the terms to continue"), "", http.StatusUnprocessableEntity)
		return
	}

	orderID := mockOrderID()
	trigger := map[string]any{
		"checkout:review:placed": map[string]string{
			"orderId": orderID,
		},
	}
	if raw, err := json.Marshal(trigger); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}

	title := i18nOrDefault(lang, "checkout.review.submit.success", "Order queued for engraving")
	body := i18nOrDefault(lang, "checkout.review.submit.success.body", "We’ll email confirmation and share the tracking page shortly.")

	if r.Header.Get("HX-Request") != "true" {
		http.Redirect(w, r, "/checkout/review?status=placed", http.StatusSeeOther)
		return
	}

	renderCheckoutReviewStatus(w, r, lang, "success", title, body, http.StatusOK)
}

func renderCheckoutReviewStatus(w http.ResponseWriter, r *http.Request, lang, tone, title, body string, code int) {
	icon := "information-circle"
	if tone == "success" {
		icon = "check-circle"
	} else if tone == "error" {
		icon = "exclamation-triangle"
	}
	data := map[string]any{
		"Tone":  tone,
		"Title": title,
		"Body":  body,
		"Icon":  icon,
	}
	w.WriteHeader(code)
	renderTemplate(w, r, "c_inline_alert", data)
}

func mockOrderID() string {
	ts := time.Now().UTC()
	return fmt.Sprintf("HF-%d", ts.UnixNano()%1000000)
}
