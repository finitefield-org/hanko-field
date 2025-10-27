package main

import (
	"encoding/json"
	"net/http"
	"net/url"
	"strings"
	"time"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
	"github.com/go-chi/chi/v5"
)

// AccountAddressesHandler renders the address management page.
func AccountAddressesHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)

	view := buildAccountAddressesPageView(lang, sess)

	title := i18nOrDefault(lang, "account.addresses.seo.title", "Account · Addresses")
	desc := i18nOrDefault(lang, "account.addresses.seo.desc", "Manage shipping, billing, and pickup addresses synced with checkout.")
	brand := i18nOrDefault(lang, "brand.name", "Hanko Field")

	vm := handlersPkg.PageData{
		Title:       title,
		Lang:        lang,
		Path:        r.URL.Path,
		Nav:         nav.Build(r.URL.Path),
		Breadcrumbs: nav.Breadcrumbs(r.URL.Path),
		Analytics:   handlersPkg.LoadAnalyticsFromEnv(),
		Account:     view,
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

	renderPage(w, r, "account_addresses", vm)
}

// AccountAddressTableHandler re-renders the saved addresses table fragment.
func AccountAddressTableHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	sess := mw.GetSession(r)
	view := buildAccountAddressesPageView(lang, sess)
	renderTemplate(w, r, "frag_account_addresses_table", view.Table)
}

// AccountAddressModalHandler returns the add/edit modal form.
func AccountAddressModalHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	lang := mw.Lang(r)
	sess := mw.GetSession(r)
	form := buildAccountAddressFormView(lang, sess, r.URL.Query())
	renderTemplate(w, r, "frag_account_address_modal", form)
}

// AccountAddressSaveHandler handles POST /me/addresses for add/edit.
func AccountAddressSaveHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid form", http.StatusBadRequest)
		return
	}
	lang := mw.Lang(r)
	sess := mw.GetSession(r)
	input := parseCheckoutAddressForm(r.PostForm)
	errors := validateCheckoutAddressForm(input, lang)
	if len(errors) > 0 {
		form := buildAccountAddressFormViewFromInput(lang, input)
		form.Errors = errors
		w.WriteHeader(http.StatusUnprocessableEntity)
		renderTemplate(w, r, "frag_account_address_modal", form)
		return
	}
	createdAt := time.Now().UTC()
	saved := mw.SessionAddress{
		ID:         input.ID,
		Label:      input.Label,
		Recipient:  input.Recipient,
		Company:    input.Company,
		Department: input.Department,
		Line1:      input.Line1,
		Line2:      input.Line2,
		City:       input.City,
		Region:     input.Region,
		Postal:     input.Postal,
		Country:    strings.ToUpper(input.Country),
		Phone:      input.Phone,
		Kind:       input.Kind,
		Notes:      input.Notes,
		CreatedAt:  createdAt,
	}
	if saved.ID == "" {
		saved.ID = newSessionAddressID()
	}
	upsertSessionAddress(sess, saved)
	applyAddressSelectionForKind(sess, saved.ID, input.Kind)

	payload := map[string]any{
		"account:addresses:refresh": map[string]string{
			"id":     saved.ID,
			"action": "saved",
		},
	}
	if raw, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	msg := i18nOrDefault(lang, "account.addresses.saved", "Address saved. Updating list…")
	_, _ = w.Write([]byte(`<div class="p-6 text-center text-sm text-emerald-700">` + msg + `</div>`))
}

// AccountAddressDeleteHandler removes a custom saved address.
func AccountAddressDeleteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	sess := mw.GetSession(r)
	id := chi.URLParam(r, "id")
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}
	if !deleteSessionAddress(sess, id) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	payload := map[string]any{
		"account:addresses:refresh": map[string]string{
			"id":     id,
			"action": "deleted",
		},
	}
	if raw, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}
	w.WriteHeader(http.StatusNoContent)
}

func buildAccountAddressFormView(lang string, sess *mw.SessionData, q url.Values) CheckoutAddressFormView {
	params := cloneValues(q)
	if params.Get("kind") == "" {
		params.Set("kind", "both")
	}
	if params.Get("country") == "" && sess != nil {
		params.Set("country", strings.ToUpper(sess.Profile.Country))
	}
	form := buildCheckoutAddressFormView(lang, params, sess, params.Get("id"))
	return decorateAccountAddressForm(form, lang)
}

func buildAccountAddressFormViewFromInput(lang string, input checkoutAddressFormInput) CheckoutAddressFormView {
	form := buildCheckoutAddressFormViewFromInput(lang, input)
	return decorateAccountAddressForm(form, lang)
}

func decorateAccountAddressForm(form CheckoutAddressFormView, lang string) CheckoutAddressFormView {
	form.Title = i18nOrDefault(lang, "account.addresses.modal.title", "Save address")
	if form.Mode == "new" {
		form.Title = i18nOrDefault(lang, "account.addresses.modal.new", "Add address")
	}
	form.Subtitle = i18nOrDefault(lang, "account.addresses.modal.subtitle", "Addresses sync to checkout, invoices, and library exports.")
	return form
}
