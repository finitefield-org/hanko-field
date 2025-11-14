package main

import (
	"net/url"
	"strings"
	"time"

	mw "finitefield.org/hanko-web/internal/middleware"
)

// AccountAddressesPageView drives the `/account/addresses` page layout.
type AccountAddressesPageView struct {
	User      AccountUser
	NavItems  []AccountNavItem
	Section   AccountAddressesSection
	AddAction AccountAddressAction
	Sync      AccountAddressSyncBanner
	Table     AccountAddressTableView
}

// AccountAddressesSection configures the primary header copy.
type AccountAddressesSection struct {
	Eyebrow  string
	Title    string
	Subtitle string
}

// AccountAddressAction controls the pinned CTA.
type AccountAddressAction struct {
	Label string
	URL   string
}

// AccountAddressSyncBanner renders an inline alert above the table.
type AccountAddressSyncBanner struct {
	Tone  string
	Icon  string
	Title string
	Body  string
}

// AccountAddressTableView feeds the table fragment rendered via htmx.
type AccountAddressTableView struct {
	Lang              string
	Addresses         []CheckoutAddress
	EmptyTitle        string
	EmptyBody         string
	EmptyActionLabel  string
	ModalURL          string
	LastSynced        time.Time
	SessionAddressIDs map[string]bool
}

func buildAccountAddressesPageView(lang string, sess *mw.SessionData) AccountAddressesPageView {
	profile := sessionProfileOrFallback(sess.Profile, lang)
	user := accountUserFromProfile(profile, lang)

	addresses := mergeCheckoutAddresses(lang, sess.Checkout.Addresses)
	shippingID := strings.TrimSpace(sess.Checkout.ShippingAddressID)
	billingID := strings.TrimSpace(sess.Checkout.BillingAddressID)
	now := time.Now()
	sessionIDs := map[string]bool{}
	for _, addr := range sess.Checkout.Addresses {
		if addr.ID != "" {
			sessionIDs[addr.ID] = true
		}
	}
	for i := range addresses {
		if shippingID != "" && addresses[i].ID == shippingID {
			addresses[i].DefaultShipping = true
		}
		if billingID != "" && addresses[i].ID == billingID {
			addresses[i].DefaultBilling = true
		}
		if addresses[i].UpdatedAt.IsZero() {
			addresses[i].UpdatedAt = now
		}
	}

	modalURL := buildAccountAddressModalURL(sess, nil)
	section := AccountAddressesSection{
		Eyebrow:  i18nOrDefault(lang, "account.addresses.eyebrow", "Addresses"),
		Title:    i18nOrDefault(lang, "account.addresses.title", "Shipping & billing addresses"),
		Subtitle: i18nOrDefault(lang, "account.addresses.subtitle", "Control every address used across checkout, billing, and library exports."),
	}

	addAction := AccountAddressAction{
		Label: i18nOrDefault(lang, "account.addresses.add", "Add address"),
		URL:   modalURL,
	}

	sync := AccountAddressSyncBanner{
		Tone:  "info",
		Icon:  "arrows-right-left",
		Title: i18nOrDefault(lang, "account.addresses.sync.title", "Synced with checkout"),
		Body:  i18nOrDefault(lang, "account.addresses.sync.body", "Any changes here update the checkout experience instantly for your workspace."),
	}

	table := AccountAddressTableView{
		Lang:              lang,
		Addresses:         addresses,
		EmptyTitle:        i18nOrDefault(lang, "account.addresses.empty.title", "No saved addresses yet"),
		EmptyBody:         i18nOrDefault(lang, "account.addresses.empty.body", "Add your studio, billing, or warehouse contacts to speed through checkout later."),
		EmptyActionLabel:  i18nOrDefault(lang, "account.addresses.empty.cta", "Create address"),
		ModalURL:          modalURL,
		LastSynced:        now,
		SessionAddressIDs: sessionIDs,
	}

	return AccountAddressesPageView{
		User:      user,
		NavItems:  accountNavItems(lang, "addresses"),
		Section:   section,
		AddAction: addAction,
		Sync:      sync,
		Table:     table,
	}
}

func buildAccountAddressModalURL(sess *mw.SessionData, q url.Values) string {
	params := cloneValues(q)
	if params.Get("kind") == "" {
		params.Set("kind", "both")
	}
	country := strings.ToUpper(params.Get("country"))
	if country == "" && sess != nil {
		country = strings.ToUpper(sess.Profile.Country)
	}
	if country == "" {
		country = "JP"
	}
	params.Set("country", country)
	return "/account/addresses/modal?" + params.Encode()
}

func cloneValues(src url.Values) url.Values {
	dst := url.Values{}
	if src == nil {
		return dst
	}
	for k, vals := range src {
		if len(vals) == 0 {
			continue
		}
		dstVals := make([]string, len(vals))
		copy(dstVals, vals)
		dst[k] = dstVals
	}
	return dst
}
