package main

import (
	"net/http"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

// CheckoutCompleteHandler renders the order completion page.
func CheckoutCompleteHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)
	view := buildCheckoutCompleteView(lang, r.URL.Query(), sess, siteBaseURL(r))

	title := i18nOrDefault(lang, "checkout.complete.seo.title", "Checkout · Complete")
	desc := i18nOrDefault(lang, "checkout.complete.seo.desc", "View your order number, tracking steps, and share updates with your team.")

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
	vm.SEO.OG.Type = "website"
	vm.SEO.OG.Title = vm.SEO.Title
	vm.SEO.OG.Description = vm.SEO.Description
	vm.SEO.Twitter.Card = "summary_large_image"
	vm.SEO.Robots = "noindex, nofollow"
	vm.SEO.Alternates = buildAlternates(r)

	resetCheckoutProgress(sess)

	renderPage(w, r, "checkout_complete", vm)
}

func resetCheckoutProgress(sess *mw.SessionData) {
	if sess == nil {
		return
	}
	if sess.CartID == "" &&
		sess.Checkout.ShippingAddressID == "" &&
		sess.Checkout.BillingAddressID == "" &&
		sess.Checkout.ShippingMethodID == "" &&
		sess.Checkout.PaymentMethodID == "" &&
		len(sess.Checkout.Addresses) == 0 {
		return
	}
	sess.CartID = ""
	sess.Checkout = mw.CheckoutState{}
	sess.MarkDirty()
}
