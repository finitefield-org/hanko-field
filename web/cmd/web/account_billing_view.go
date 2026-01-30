package main

import (
	"time"

	mw "finitefield.org/hanko-web/internal/middleware"
)

// AccountBillingPageView drives the `/account/billing` page layout.
type AccountBillingPageView struct {
	User     AccountUser
	NavItems []AccountNavItem
	Section  AccountBillingSection
	Cards    []AccountBillingCard
	Updated  time.Time
}

// AccountBillingSection configures the primary header copy.
type AccountBillingSection struct {
	Eyebrow  string
	Title    string
	Subtitle string
}

// AccountBillingCard renders a summary card in the billing page.
type AccountBillingCard struct {
	Title       string
	Description string
	ActionLabel string
	ActionHref  string
	Meta        string
}

func buildAccountBillingPageView(lang string, sess *mw.SessionData) AccountBillingPageView {
	profile := sessionProfileOrFallback(sess.Profile, lang)
	user := accountUserFromProfile(profile, lang)

	section := AccountBillingSection{
		Eyebrow:  i18nOrDefault(lang, "account.nav.billing", "Billing"),
		Title:    i18nOrDefault(lang, "account.billing.title", "Invoices & usage"),
		Subtitle: i18nOrDefault(lang, "account.billing.subtitle", "Review invoices, payment history, and workspace usage in one place."),
	}

	cards := []AccountBillingCard{
		{
			Title:       i18nOrDefault(lang, "account.billing.card.invoices.title", "Invoices"),
			Description: i18nOrDefault(lang, "account.billing.card.invoices.desc", "Download invoices, check payment status, and share receipts with finance."),
			ActionLabel: i18nOrDefault(lang, "account.billing.card.invoices.cta", "Contact billing"),
			ActionHref:  "/support",
			Meta:        i18nOrDefault(lang, "account.billing.card.invoices.meta", "Next invoice: 2026/02/01"),
		},
		{
			Title:       i18nOrDefault(lang, "account.billing.card.usage.title", "Usage"),
			Description: i18nOrDefault(lang, "account.billing.card.usage.desc", "Track monthly usage and confirm quota thresholds before renewals."),
			ActionLabel: i18nOrDefault(lang, "account.billing.card.usage.cta", "View usage report"),
			ActionHref:  "/support",
			Meta:        i18nOrDefault(lang, "account.billing.card.usage.meta", "Last updated: today"),
		},
	}

	return AccountBillingPageView{
		User:     user,
		NavItems: accountNavItems(lang, "billing"),
		Section:  section,
		Cards:    cards,
		Updated:  time.Now().UTC(),
	}
}
