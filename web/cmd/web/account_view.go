package main

import (
	"fmt"
	"net/url"
	"strings"
	"time"

	mw "finitefield.org/hanko-web/internal/middleware"
)

// AccountView aggregates the data required to render the account page.
type AccountView struct {
	Lang        string
	User        AccountUser
	NavItems    []AccountNavItem
	ProfileForm AccountProfileFormView
	Preferences []AccountPreference
	Sessions    []AccountSession
	Security    AccountSecurityCard
	LastUpdated time.Time
}

// AccountUser summarises the current profile owner.
type AccountUser struct {
	DisplayName  string
	Email        string
	Phone        string
	Language     string
	LanguageID   string
	Country      string
	PhoneCountry string
	AvatarURL    string
	Plan         string
	Role         string
}

// AccountNavItem powers the sidebar navigation block.
type AccountNavItem struct {
	Key         string
	Label       string
	Description string
	Icon        string
	Href        string
	Active      bool
	Badge       string
}

// AccountPreference describes a switch row in the communication settings list.
type AccountPreference struct {
	ID          string
	Label       string
	Description string
	Enabled     bool
	Required    bool
}

// AccountSession lists an active device session.
type AccountSession struct {
	ID         string
	Device     string
	Platform   string
	Location   string
	IP         string
	LastActive string
	Current    bool
	Risk       string
}

// AccountSecurityCard configures the inline alert banner.
type AccountSecurityCard struct {
	Tone       string
	Title      string
	Body       string
	ActionHref string
	ActionText string
}

// AccountProfileFormView feeds the profile form fragment.
type AccountProfileFormView struct {
	Lang         string
	FormID       string
	Subtitle     string
	AvatarURL    string
	Values       map[string]string
	Errors       map[string]string
	Languages    []AccountOption
	Countries    []AccountOption
	DialCodes    []AccountOption
	InitialState string
}

// AccountOption is a simple select option.
type AccountOption struct {
	Value string
	Label string
}

type accountProfileFormInput struct {
	DisplayName  string
	Email        string
	Phone        string
	PhoneCountry string
	Language     string
	Country      string
}

func buildAccountView(lang string, sess *mw.SessionData) AccountView {
	profile := sessionProfileOrFallback(sess.Profile, lang)
	view := AccountView{
		Lang:        lang,
		User:        accountUserFromProfile(profile, lang),
		NavItems:    accountNavItems(lang),
		ProfileForm: buildAccountProfileFormView(lang, profile, nil, nil),
		Preferences: accountPreferenceToggles(lang),
		Sessions:    accountSessions(lang),
		Security:    accountSecurityCard(lang),
		LastUpdated: time.Now().UTC(),
	}
	return view
}

func sessionProfileOrFallback(sp mw.SessionProfile, lang string) mw.SessionProfile {
	profile := sp
	if profile.DisplayName == "" {
		if lang == "ja" {
			profile.DisplayName = "佐藤 遥"
		} else {
			profile.DisplayName = "Haruka Sato"
		}
	}
	if profile.Email == "" {
		profile.Email = "haruka.sato@finitefield.org"
	}
	if profile.Phone == "" {
		profile.Phone = "08012345678"
	}
	if profile.PhoneCountry == "" {
		profile.PhoneCountry = "JP"
	}
	if profile.Language == "" {
		profile.Language = lang
	}
	if profile.Country == "" {
		profile.Country = "JP"
	}
	if profile.AvatarURL == "" {
		profile.AvatarURL = "https://api.dicebear.com/7.x/miniavs/svg?seed=Hanko"
	}
	return profile
}

func accountUserFromProfile(profile mw.SessionProfile, lang string) AccountUser {
	return AccountUser{
		DisplayName:  profile.DisplayName,
		Email:        profile.Email,
		Phone:        profile.Phone,
		Language:     accountLanguageLabel(profile.Language, lang),
		LanguageID:   profile.Language,
		Country:      accountCountryLabel(profile.Country, lang),
		PhoneCountry: profile.PhoneCountry,
		AvatarURL:    profile.AvatarURL,
		Plan:         "Hanko Field Teams",
		Role:         i18nOrDefault(lang, "account.role.admin", "Org admin"),
	}
}

func accountNavItems(lang string) []AccountNavItem {
	items := []AccountNavItem{
		{Key: "overview", Label: i18nOrDefault(lang, "account.nav.overview", "Overview"), Description: i18nOrDefault(lang, "account.nav.overview.desc", "Activity highlights and alerts"), Icon: "chart-pie", Href: "/account"},
		{Key: "profile", Label: i18nOrDefault(lang, "account.nav.profile", "Profile"), Description: i18nOrDefault(lang, "account.nav.profile.desc", "Identity and locale preferences"), Icon: "user-circle", Href: "/account"},
		{Key: "library", Label: i18nOrDefault(lang, "account.nav.library", "Library"), Description: i18nOrDefault(lang, "account.nav.library.desc", "Saved seals and approvals"), Icon: "document-duplicate", Href: "/account/library", Badge: i18nOrDefault(lang, "account.nav.beta", "Beta")},
		{Key: "security", Label: i18nOrDefault(lang, "account.nav.security", "Security"), Description: i18nOrDefault(lang, "account.nav.security.desc", "Sessions, devices, and 2FA"), Icon: "shield-check", Href: "/account/security"},
		{Key: "billing", Label: i18nOrDefault(lang, "account.nav.billing", "Billing"), Description: i18nOrDefault(lang, "account.nav.billing.desc", "Invoices and usage"), Icon: "credit-card", Href: "/account/billing"},
		{Key: "notifications", Label: i18nOrDefault(lang, "account.nav.notifications", "Notifications"), Description: i18nOrDefault(lang, "account.nav.notifications.desc", "Communication settings"), Icon: "bell-alert", Href: "/account/notifications"},
	}
	for i := range items {
		if items[i].Key == "profile" {
			items[i].Active = true
		}
	}
	return items
}

func accountPreferenceToggles(lang string) []AccountPreference {
	return []AccountPreference{
		{
			ID:          "product-updates",
			Label:       i18nOrDefault(lang, "account.prefs.product", "Product announcements"),
			Description: i18nOrDefault(lang, "account.prefs.product.desc", "Roadmap notes, changelogs, and launch recaps."),
			Enabled:     true,
		},
		{
			ID:          "weekly-digest",
			Label:       i18nOrDefault(lang, "account.prefs.digest", "Weekly summaries"),
			Description: i18nOrDefault(lang, "account.prefs.digest.desc", "Design completion stats and pending approvals."),
			Enabled:     true,
		},
		{
			ID:          "security-alerts",
			Label:       i18nOrDefault(lang, "account.prefs.security", "Security alerts"),
			Description: i18nOrDefault(lang, "account.prefs.security.desc", "Login warnings, device approvals, and policy changes."),
			Enabled:     true,
			Required:    true,
		},
		{
			ID:          "approver-nudges",
			Label:       i18nOrDefault(lang, "account.prefs.approvals", "Approver nudges"),
			Description: i18nOrDefault(lang, "account.prefs.approvals.desc", "Reminders for sign-offs awaiting your review."),
			Enabled:     false,
		},
	}
}

func accountSessions(lang string) []AccountSession {
	now := time.Now()
	return []AccountSession{
		{
			ID:         "sess-mac",
			Device:     "MacBook Pro 14”",
			Platform:   "Safari · macOS 15.2",
			Location:   i18nOrDefault(lang, "account.session.location.tokyo", "Tokyo, Japan"),
			IP:         "203.0.113.24",
			LastActive: relativeTime(now.Add(-27*time.Minute), lang),
			Current:    true,
			Risk:       "low",
		},
		{
			ID:         "sess-ios",
			Device:     "iPhone 15 Pro",
			Platform:   "iOS 18 · App",
			Location:   i18nOrDefault(lang, "account.session.location.osaka", "Osaka, Japan"),
			IP:         "198.51.100.11",
			LastActive: relativeTime(now.Add(-26*time.Hour), lang),
			Current:    false,
			Risk:       "low",
		},
		{
			ID:         "sess-web",
			Device:     "Windows · Edge",
			Platform:   "Edge 131 · Windows 11",
			Location:   i18nOrDefault(lang, "account.session.location.singapore", "Singapore"),
			IP:         "192.0.2.88",
			LastActive: relativeTime(now.Add(-5*24*time.Hour), lang),
			Current:    false,
			Risk:       "medium",
		},
	}
}

func accountSecurityCard(lang string) AccountSecurityCard {
	return AccountSecurityCard{
		Tone:       "info",
		Title:      i18nOrDefault(lang, "account.security.title", "Harden your workspace"),
		Body:       i18nOrDefault(lang, "account.security.body", "Enable passkeys or TOTP for every admin. We’ll guide you through device enrollment and policy checks."),
		ActionHref: "/account/security",
		ActionText: i18nOrDefault(lang, "account.security.cta", "Review security checklist"),
	}
}

func buildAccountProfileFormView(lang string, profile mw.SessionProfile, input *accountProfileFormInput, errors map[string]string) AccountProfileFormView {
	values := map[string]string{
		"display_name":  profile.DisplayName,
		"email":         profile.Email,
		"phone":         profile.Phone,
		"phone_country": profile.PhoneCountry,
		"lang":          profile.Language,
		"country":       profile.Country,
	}
	if input != nil {
		if input.DisplayName != "" {
			values["display_name"] = input.DisplayName
		}
		if input.Email != "" {
			values["email"] = input.Email
		}
		if input.Phone != "" {
			values["phone"] = input.Phone
		}
		if input.PhoneCountry != "" {
			values["phone_country"] = strings.ToUpper(input.PhoneCountry)
		}
		if input.Language != "" {
			values["lang"] = strings.ToLower(input.Language)
		}
		if input.Country != "" {
			values["country"] = strings.ToUpper(input.Country)
		}
	}
	return AccountProfileFormView{
		Lang:         lang,
		FormID:       "account-profile-form",
		Subtitle:     i18nOrDefault(lang, "account.profile.subtitle", "Share how your name should appear on approvals and workspace exports."),
		AvatarURL:    profile.AvatarURL,
		Values:       values,
		Errors:       errors,
		Languages:    accountLanguageOptions(lang),
		Countries:    accountCountryOptions(lang),
		DialCodes:    accountDialCodeOptions(lang),
		InitialState: serializeProfileFormState(values),
	}
}

func accountLanguageOptions(lang string) []AccountOption {
	return []AccountOption{
		{Value: "ja", Label: i18nOrDefault(lang, "account.lang.ja", "Japanese (JA)")},
		{Value: "en", Label: i18nOrDefault(lang, "account.lang.en", "English (EN)")},
	}
}

func accountCountryOptions(lang string) []AccountOption {
	opts := []AccountOption{
		{Value: "JP", Label: i18nOrDefault(lang, "account.country.jp", "Japan")},
		{Value: "SG", Label: i18nOrDefault(lang, "account.country.sg", "Singapore")},
		{Value: "US", Label: i18nOrDefault(lang, "account.country.us", "United States")},
		{Value: "GB", Label: i18nOrDefault(lang, "account.country.gb", "United Kingdom")},
	}
	return opts
}

func accountDialCodeOptions(lang string) []AccountOption {
	return []AccountOption{
		{Value: "JP", Label: i18nOrDefault(lang, "account.dial.jp", "+81 · JP")},
		{Value: "SG", Label: i18nOrDefault(lang, "account.dial.sg", "+65 · SG")},
		{Value: "US", Label: i18nOrDefault(lang, "account.dial.us", "+1 · US")},
		{Value: "GB", Label: i18nOrDefault(lang, "account.dial.gb", "+44 · UK")},
	}
}

func parseAccountProfileForm(form url.Values) accountProfileFormInput {
	return accountProfileFormInput{
		DisplayName:  strings.TrimSpace(form.Get("display_name")),
		Email:        strings.TrimSpace(form.Get("email")),
		Phone:        strings.TrimSpace(form.Get("phone")),
		PhoneCountry: strings.ToUpper(strings.TrimSpace(form.Get("phone_country"))),
		Language:     strings.ToLower(strings.TrimSpace(form.Get("lang"))),
		Country:      strings.ToUpper(strings.TrimSpace(form.Get("country"))),
	}
}

func validateAccountProfileForm(input accountProfileFormInput, lang string) map[string]string {
	errors := map[string]string{}
	if input.DisplayName == "" {
		errors["display_name"] = i18nOrDefault(lang, "account.profile.error.name", "Enter a display name.")
	}
	if input.Email == "" || !strings.Contains(input.Email, "@") {
		errors["email"] = i18nOrDefault(lang, "account.profile.error.email", "Provide a valid email.")
	}
	if input.Language == "" {
		errors["lang"] = i18nOrDefault(lang, "account.profile.error.language", "Choose a language.")
	}
	if input.Country == "" {
		errors["country"] = i18nOrDefault(lang, "account.profile.error.country", "Select a country.")
	}
	if input.PhoneCountry == "" {
		input.PhoneCountry = "JP"
	}
	phoneDigits := strings.ReplaceAll(strings.ReplaceAll(input.Phone, "-", ""), " ", "")
	if input.Phone != "" && len(phoneDigits) < 8 {
		errors["phone"] = i18nOrDefault(lang, "account.profile.error.phone", "Enter a longer phone number.")
	}
	return errors
}

func applyAccountProfileInput(sess *mw.SessionData, input accountProfileFormInput) {
	if sess == nil {
		return
	}
	profile := sess.Profile
	profile.DisplayName = input.DisplayName
	profile.Email = input.Email
	profile.Phone = input.Phone
	profile.PhoneCountry = strings.ToUpper(input.PhoneCountry)
	profile.Language = input.Language
	profile.Country = input.Country
	if profile.AvatarURL == "" {
		profile.AvatarURL = "https://api.dicebear.com/7.x/miniavs/svg?seed=Hanko"
	}
	sess.Profile = profile
	if input.Language != "" {
		sess.Locale = input.Language
	}
	sess.MarkDirty()
}

func serializeProfileFormState(values map[string]string) string {
	keys := []string{"display_name", "email", "phone", "phone_country", "lang", "country"}
	var builder strings.Builder
	for i, k := range keys {
		if i > 0 {
			builder.WriteByte('&')
		}
		builder.WriteString(k)
		builder.WriteByte('=')
		builder.WriteString(values[k])
	}
	return builder.String()
}

func accountLanguageLabel(code, lang string) string {
	switch strings.ToLower(code) {
	case "ja":
		return i18nOrDefault(lang, "account.lang.ja", "Japanese (JA)")
	case "en":
		return i18nOrDefault(lang, "account.lang.en", "English (EN)")
	default:
		return strings.ToUpper(code)
	}
}

func accountCountryLabel(code, lang string) string {
	switch strings.ToUpper(code) {
	case "JP":
		return i18nOrDefault(lang, "account.country.jp", "Japan")
	case "SG":
		return i18nOrDefault(lang, "account.country.sg", "Singapore")
	case "US":
		return i18nOrDefault(lang, "account.country.us", "United States")
	case "GB":
		return i18nOrDefault(lang, "account.country.gb", "United Kingdom")
	default:
		return strings.ToUpper(code)
	}
}

func relativeTime(ts time.Time, lang string) string {
	diff := time.Since(ts)
	if diff < time.Minute {
		if lang == "ja" {
			return "たった今"
		}
		return "just now"
	}
	if diff < time.Hour {
		min := int(diff.Minutes())
		if lang == "ja" {
			return fmt.Sprintf("%d分前", min)
		}
		return fmt.Sprintf("%d min ago", min)
	}
	if diff < 24*time.Hour {
		hrs := int(diff.Hours())
		if lang == "ja" {
			return fmt.Sprintf("%d時間前", hrs)
		}
		return fmt.Sprintf("%d hr ago", hrs)
	}
	days := int(diff.Hours() / 24)
	if lang == "ja" {
		return fmt.Sprintf("%d日前", days)
	}
	return fmt.Sprintf("%d d ago", days)
}
