package main

import (
	"time"

	mw "finitefield.org/hanko-web/internal/middleware"
)

// AccountNotificationsPageView drives the `/account/notifications` page layout.
type AccountNotificationsPageView struct {
	User        AccountUser
	NavItems    []AccountNavItem
	Section     AccountNotificationsSection
	Preferences []AccountPreference
	Archive     AccountNotificationsArchive
	Updated     time.Time
}

// AccountNotificationsSection configures the primary header copy.
type AccountNotificationsSection struct {
	Eyebrow  string
	Title    string
	Subtitle string
}

// AccountNotificationsArchive highlights the notifications archive entry point.
type AccountNotificationsArchive struct {
	Title       string
	Description string
	ActionLabel string
	ActionHref  string
}

func buildAccountNotificationsPageView(lang string, sess *mw.SessionData) AccountNotificationsPageView {
	profile := sessionProfileOrFallback(sess.Profile, lang)
	user := accountUserFromProfile(profile, lang)

	section := AccountNotificationsSection{
		Eyebrow:  i18nOrDefault(lang, "account.nav.notifications", "Notifications"),
		Title:    i18nOrDefault(lang, "account.notifications.title", "Communication settings"),
		Subtitle: i18nOrDefault(lang, "account.notifications.subtitle", "Choose which updates reach you, and jump to the notification archive when you need context."),
	}

	archive := AccountNotificationsArchive{
		Title:       i18nOrDefault(lang, "account.notifications.archive.title", "Notification archive"),
		Description: i18nOrDefault(lang, "account.notifications.archive.desc", "Review recent alerts about orders, designs, and account activity."),
		ActionLabel: i18nOrDefault(lang, "account.notifications.archive.cta", "View archive"),
		ActionHref:  "/notifications",
	}

	return AccountNotificationsPageView{
		User:        user,
		NavItems:    accountNavItems(lang, "notifications"),
		Section:     section,
		Preferences: accountPreferenceToggles(lang),
		Archive:     archive,
		Updated:     time.Now().UTC(),
	}
}
