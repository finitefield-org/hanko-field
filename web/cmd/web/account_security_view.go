package main

import (
	"fmt"
	"net/http"
	"time"

	"finitefield.org/hanko-web/internal/format"
	mw "finitefield.org/hanko-web/internal/middleware"
)

// AccountSecurityPageView provides the data required to render `/account/security`.
type AccountSecurityPageView struct {
	Lang       string
	User       AccountUser
	NavItems   []AccountNavItem
	Header     AccountSecurityHeader
	Banner     *AlertBannerView
	Providers  AccountSecurityProviderSection
	TwoFactor  AccountSecurityTwoFactor
	Password   AccountSecurityPasswordCard
	Sessions   AccountSecuritySessionsView
	LastUpdate time.Time
}

// AccountSecurityHeader renders the section hero copy.
type AccountSecurityHeader struct {
	Eyebrow  string
	Title    string
	Subtitle string
}

// AccountSecurityProviderSection describes the linked account providers block.
type AccountSecurityProviderSection struct {
	Title     string
	Subtitle  string
	HelpText  string
	Providers []AccountSecurityProvider
}

// AccountSecurityProvider represents a single identity provider card.
type AccountSecurityProvider struct {
	ID               string
	Name             string
	Icon             string
	Description      string
	StatusLabel      string
	StatusBadgeClass string
	StatusTextClass  string
	StatusDotClass   string
	LastLinked       string
	LastLinkedISO    string
	Connected        bool
	PrimaryAction    AccountSecurityAction
	SecondaryAction  *AccountSecurityAction
	DangerAction     *AccountSecurityAction
	Modals           []AccountSecurityModal
	Metadata         []AccountSecurityMetaItem
}

// AccountSecurityMetaItem surfaces additional provider metadata.
type AccountSecurityMetaItem struct {
	Label string
	Value string
}

// AccountSecurityAction represents a button or link action on the card.
type AccountSecurityAction struct {
	Label          string
	Icon           string
	Variant        string
	Href           string
	Method         string
	HXTarget       string
	HXSwap         string
	ModalID        string
	Classes        string
	SuccessMessage string
}

// AccountSecurityModal defines a lightweight modal configuration rendered inline.
type AccountSecurityModal struct {
	ID              string
	Title           string
	Description     string
	Body            []AccountSecurityModalBody
	ConfirmLabel    string
	ConfirmVariant  string
	ConfirmHref     string
	ConfirmMethod   string
	ConfirmHXTarget string
	ConfirmHXSwap   string
	Danger          bool
	FooterNote      string
	SuccessMessage  string
	ConfirmClasses  string
}

// AccountSecurityModalBody lists copy and icon rows within a modal body.
type AccountSecurityModalBody struct {
	Icon        string
	Title       string
	Description string
}

// AccountSecurityTwoFactor models the 2FA setup card.
type AccountSecurityTwoFactor struct {
	Enabled               bool
	StatusLabel           string
	StatusBadgeClass      string
	StatusTextClass       string
	StatusDotClass        string
	Description           string
	Methods               []AccountSecurityTwoFactorMethod
	PrimaryAction         AccountSecurityAction
	SecondaryAction       *AccountSecurityAction
	Modal                 AccountSecurityModal
	BackupCodes           []string
	BackupCodesRotated    string
	BackupCodesRotatedISO string
	RecoveryEmail         string
	RecoveryPhone         string
}

// AccountSecurityTwoFactorMethod lists available second factors.
type AccountSecurityTwoFactorMethod struct {
	Icon        string
	Label       string
	StatusLabel string
	StatusClass string
	Description string
}

// AccountSecurityPasswordCard captures password management state.
type AccountSecurityPasswordCard struct {
	HasPassword     bool
	LastChanged     string
	LastChangedISO  string
	StrengthLabel   string
	StrengthClass   string
	Description     string
	Action          AccountSecurityAction
	SecondaryAction *AccountSecurityAction
}

// AccountSecuritySessionsView renders the active session table.
type AccountSecuritySessionsView struct {
	Title    string
	Subtitle string
	Sessions []AccountSecuritySession
	Empty    string
}

// AccountSecuritySession is a single device session row.
type AccountSecuritySession struct {
	ID            string
	Device        string
	Platform      string
	Location      string
	IP            string
	LastActive    string
	LastActiveISO string
	Current       bool
	Risk          string
	RiskBadge     string
	RiskText      string
	SignInMethod  string
	RevokeAction  AccountSecurityAction
}

func buildAccountSecurityPageView(lang string, sess *mw.SessionData) AccountSecurityPageView {
	profile := sessionProfileOrFallback(sess.Profile, lang)
	user := accountUserFromProfile(profile, lang)
	now := time.Now().UTC()

	header := AccountSecurityHeader{
		Eyebrow:  i18nOrDefault(lang, "account.security.header.eyebrow", "Linked access"),
		Title:    i18nOrDefault(lang, "account.security.header.title", "Keep your workspace locked down"),
		Subtitle: i18nOrDefault(lang, "account.security.header.subtitle", "Review connected identity providers, enforce multi-factor, and monitor active sessions."),
	}

	banner := buildAccountSecurityBanner(lang)

	providers := buildAccountSecurityProviders(lang, now)
	twoFactor := buildAccountSecurityTwoFactor(lang, now)
	password := buildAccountSecurityPassword(lang, now)
	sessions := buildAccountSecuritySessions(lang, now)

	return AccountSecurityPageView{
		Lang:     lang,
		User:     user,
		NavItems: accountNavItems(lang, "security"),
		Header:   header,
		Banner:   banner,
		Providers: AccountSecurityProviderSection{
			Title:     i18nOrDefault(lang, "account.security.providers.title", "Linked identity providers"),
			Subtitle:  i18nOrDefault(lang, "account.security.providers.subtitle", "Authorize SSO connections and revoke unused sign-in methods."),
			HelpText:  i18nOrDefault(lang, "account.security.providers.help", "Connections sync across the web app, mobile, and admin consoles."),
			Providers: providers,
		},
		TwoFactor:  twoFactor,
		Password:   password,
		Sessions:   sessions,
		LastUpdate: now,
	}
}

func buildAccountSecurityBanner(lang string) *AlertBannerView {
	bg, border, text, icon := accountSecurityTonePalette("warning")
	return &AlertBannerView{
		Variant:    "warning",
		Title:      i18nOrDefault(lang, "account.security.banner.title", "Unusual sign-in detected"),
		Message:    i18nOrDefault(lang, "account.security.banner.message", "We signed you out of an unfamiliar device. Review sessions and revoke anything that looks off."),
		LinkText:   i18nOrDefault(lang, "account.security.banner.link", "Review activity"),
		LinkURL:    "/account/security#sessions",
		Icon:       icon,
		Background: bg,
		Border:     border,
		Text:       text,
	}
}

func buildAccountSecurityProviders(lang string, now time.Time) []AccountSecurityProvider {
	providers := []AccountSecurityProvider{}

	badgeConnected, textConnected, dotConnected := accountSecurityStatusClasses("success")
	badgePending, textPending, dotPending := accountSecurityStatusClasses("pending")
	badgeDanger, textDanger, dotDanger := accountSecurityStatusClasses("danger")

	providers = append(providers, AccountSecurityProvider{
		ID:               "password",
		Name:             i18nOrDefault(lang, "account.security.provider.password", "Email & password"),
		Icon:             "lock-closed",
		Description:      i18nOrDefault(lang, "account.security.provider.password.desc", "Direct sign-in fallback. Required for recovery and offline access."),
		StatusLabel:      i18nOrDefault(lang, "account.security.provider.password.status", "Required"),
		StatusBadgeClass: badgeConnected,
		StatusTextClass:  textConnected,
		StatusDotClass:   dotConnected,
		LastLinked:       relativeTime(now.Add(-72*time.Hour), lang),
		LastLinkedISO:    now.Add(-72 * time.Hour).Format(time.RFC3339),
		Connected:        true,
		PrimaryAction: AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.provider.password.action", "Change password"),
			Icon:    "key",
			Variant: "primary",
			Href:    "/account/security/password/change",
			Method:  http.MethodGet,
			Classes: accountSecurityActionClasses("primary"),
		},
		Metadata: []AccountSecurityMetaItem{
			{
				Label: i18nOrDefault(lang, "account.security.provider.password.last_changed", "Last updated"),
				Value: format.FmtDate(now.Add(-72*time.Hour), lang),
			},
			{
				Label: i18nOrDefault(lang, "account.security.provider.password.recovery", "Recovery email"),
				Value: "haruka.sato@finitefield.org",
			},
		},
	})

	providers = append(providers, AccountSecurityProvider{
		ID:               "google",
		Name:             "Google Workspace",
		Icon:             "globe-alt",
		Description:      i18nOrDefault(lang, "account.security.provider.google.desc", "Authenticate with your corporate Google account."),
		StatusLabel:      i18nOrDefault(lang, "account.security.provider.google.connected", "Connected"),
		StatusBadgeClass: badgeConnected,
		StatusTextClass:  textConnected,
		StatusDotClass:   dotConnected,
		LastLinked:       relativeTime(now.Add(-18*time.Hour), lang),
		LastLinkedISO:    now.Add(-18 * time.Hour).Format(time.RFC3339),
		Connected:        true,
		PrimaryAction: AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.provider.google.unlink", "Unlink"),
			Icon:    "link-slash",
			Variant: "ghost",
			ModalID: "modal-provider-google-unlink",
			Classes: accountSecurityActionClasses("ghost"),
		},
		SecondaryAction: &AccountSecurityAction{
			Label:          i18nOrDefault(lang, "account.security.provider.google.rotate", "Rotate refresh token"),
			Icon:           "arrow-path",
			Variant:        "outline",
			Href:           "/account/security/providers/google/rotate",
			Method:         http.MethodPost,
			HXTarget:       fmt.Sprintf("#provider-%s", "google"),
			HXSwap:         "outerHTML",
			Classes:        accountSecurityActionClasses("outline"),
			SuccessMessage: i18nOrDefault(lang, "account.security.provider.google.rotate.success", "Refresh token rotation queued"),
		},
		Metadata: []AccountSecurityMetaItem{
			{
				Label: i18nOrDefault(lang, "account.security.provider.linked_by", "Linked by"),
				Value: "Haruka Sato",
			},
			{
				Label: i18nOrDefault(lang, "account.security.provider.last_login", "Last login"),
				Value: relativeTime(now.Add(-18*time.Hour), lang),
			},
		},
		Modals: []AccountSecurityModal{
			{
				ID:          "modal-provider-google-unlink",
				Title:       i18nOrDefault(lang, "account.security.modal.google.unlink.title", "Disconnect Google Workspace"),
				Description: i18nOrDefault(lang, "account.security.modal.google.unlink.desc", "Users will need to re-consent before signing in with Google again."),
				Body: []AccountSecurityModalBody{
					{
						Icon:        "information-circle",
						Title:       i18nOrDefault(lang, "account.security.modal.google.unlink.step1", "Revocation happens immediately"),
						Description: i18nOrDefault(lang, "account.security.modal.google.unlink.step1.desc", "All active Google sessions lose access within 60 seconds."),
					},
					{
						Icon:        "shield-check",
						Title:       i18nOrDefault(lang, "account.security.modal.google.unlink.step2", "Passkeys or password remain available"),
						Description: i18nOrDefault(lang, "account.security.modal.google.unlink.step2.desc", "Ensure another login method is enabled before disconnecting."),
					},
				},
				ConfirmLabel:    i18nOrDefault(lang, "account.security.modal.google.unlink.confirm", "Revoke Google access"),
				ConfirmVariant:  "danger",
				ConfirmHref:     "/account/security/providers/google/unlink",
				ConfirmMethod:   http.MethodPost,
				ConfirmHXTarget: fmt.Sprintf("#provider-%s", "google"),
				ConfirmHXSwap:   "outerHTML",
				Danger:          true,
				FooterNote:      i18nOrDefault(lang, "account.security.modal.google.unlink.footnote", "The user stays signed in on devices using non-Google methods."),
				SuccessMessage:  i18nOrDefault(lang, "account.security.modal.google.unlink.success", "Google access revoked"),
				ConfirmClasses:  accountSecurityActionClasses("danger"),
			},
		},
	})

	providers = append(providers, AccountSecurityProvider{
		ID:               "microsoft",
		Name:             "Microsoft Entra ID",
		Icon:             "users",
		Description:      i18nOrDefault(lang, "account.security.provider.microsoft.desc", "Connect Azure AD or Entra ID tenants for SSO policies."),
		StatusLabel:      i18nOrDefault(lang, "account.security.provider.microsoft.pending", "Awaiting setup"),
		StatusBadgeClass: badgePending,
		StatusTextClass:  textPending,
		StatusDotClass:   dotPending,
		LastLinked:       i18nOrDefault(lang, "account.security.provider.never_connected", "Not connected yet"),
		Connected:        false,
		PrimaryAction: AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.provider.microsoft.connect", "Connect tenant"),
			Icon:    "plus-small",
			Variant: "primary",
			ModalID: "modal-provider-microsoft-connect",
			Classes: accountSecurityActionClasses("primary"),
		},
		Metadata: []AccountSecurityMetaItem{
			{
				Label: i18nOrDefault(lang, "account.security.provider.microsoft.tooltip", "Recommended for enforcing conditional access policies."),
				Value: "",
			},
		},
		Modals: []AccountSecurityModal{
			{
				ID:          "modal-provider-microsoft-connect",
				Title:       i18nOrDefault(lang, "account.security.modal.microsoft.connect.title", "Connect Microsoft Entra"),
				Description: i18nOrDefault(lang, "account.security.modal.microsoft.connect.desc", "Grant Hanko Field delegated permissions to access profile claims."),
				Body: []AccountSecurityModalBody{
					{
						Icon:        "link",
						Title:       i18nOrDefault(lang, "account.security.modal.microsoft.connect.step1", "Sign in with a global admin"),
						Description: i18nOrDefault(lang, "account.security.modal.microsoft.connect.step1.desc", "We request the `User.Read` and `offline_access` scopes to mint refresh tokens."),
					},
					{
						Icon:        "document-text",
						Title:       i18nOrDefault(lang, "account.security.modal.microsoft.connect.step2", "Review the consent summary"),
						Description: i18nOrDefault(lang, "account.security.modal.microsoft.connect.step2.desc", "A secure window opens to Microsoft to finish app consent."),
					},
				},
				ConfirmLabel:    i18nOrDefault(lang, "account.security.modal.microsoft.connect.confirm", "Launch Microsoft consent"),
				ConfirmVariant:  "primary",
				ConfirmHref:     "/account/security/providers/microsoft/connect",
				ConfirmMethod:   http.MethodPost,
				ConfirmHXTarget: "#modal-root",
				ConfirmHXSwap:   "none",
				SuccessMessage:  i18nOrDefault(lang, "account.security.modal.microsoft.connect.success", "Opening Microsoft consent"),
				ConfirmClasses:  accountSecurityActionClasses("primary"),
			},
		},
	})

	providers = append(providers, AccountSecurityProvider{
		ID:               "line",
		Name:             "LINE Works",
		Icon:             "chat-bubble-left-right",
		Description:      i18nOrDefault(lang, "account.security.provider.line.desc", "Allow crew members to authenticate with LINE Works accounts."),
		StatusLabel:      i18nOrDefault(lang, "account.security.provider.line.degraded", "Certificate expired"),
		StatusBadgeClass: badgeDanger,
		StatusTextClass:  textDanger,
		StatusDotClass:   dotDanger,
		LastLinked:       relativeTime(now.Add(-15*24*time.Hour), lang),
		LastLinkedISO:    now.Add(-15 * 24 * time.Hour).Format(time.RFC3339),
		Connected:        true,
		PrimaryAction: AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.provider.line.renew", "Upload new certificate"),
			Icon:    "arrow-up-tray",
			Variant: "outline",
			Href:    "/account/security/providers/line/certificate",
			Method:  http.MethodGet,
			Classes: accountSecurityActionClasses("outline"),
		},
		DangerAction: &AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.provider.line.disable", "Disable sign-in"),
			Icon:    "no-symbol",
			Variant: "ghost",
			ModalID: "modal-provider-line-disable",
			Classes: accountSecurityActionClasses("ghost"),
		},
		Metadata: []AccountSecurityMetaItem{
			{
				Label: i18nOrDefault(lang, "account.security.provider.line.expires", "Certificate expires"),
				Value: format.FmtDate(now.Add(-24*time.Hour), lang),
			},
		},
		Modals: []AccountSecurityModal{
			{
				ID:          "modal-provider-line-disable",
				Title:       i18nOrDefault(lang, "account.security.modal.line.disable.title", "Disable LINE Works sign-in"),
				Description: i18nOrDefault(lang, "account.security.modal.line.disable.desc", "Active sessions signed in with LINE Works will be revoked."),
				Body: []AccountSecurityModalBody{
					{
						Icon:        "exclamation-triangle",
						Title:       i18nOrDefault(lang, "account.security.modal.line.disable.step1", "Users lose access immediately"),
						Description: i18nOrDefault(lang, "account.security.modal.line.disable.step1.desc", "They can still sign in with other linked providers."),
					},
					{
						Icon:        "clock",
						Title:       i18nOrDefault(lang, "account.security.modal.line.disable.step2", "We keep audit logs"),
						Description: i18nOrDefault(lang, "account.security.modal.line.disable.step2.desc", "All tokens are recorded for compliance reviews."),
					},
				},
				ConfirmLabel:    i18nOrDefault(lang, "account.security.modal.line.disable.confirm", "Disable LINE Works"),
				ConfirmVariant:  "danger",
				ConfirmHref:     "/account/security/providers/line/disable",
				ConfirmMethod:   http.MethodPost,
				ConfirmHXTarget: fmt.Sprintf("#provider-%s", "line"),
				ConfirmHXSwap:   "outerHTML",
				Danger:          true,
				SuccessMessage:  i18nOrDefault(lang, "account.security.modal.line.disable.success", "LINE Works disabled"),
				ConfirmClasses:  accountSecurityActionClasses("danger"),
			},
		},
	})

	return providers
}

func buildAccountSecurityTwoFactor(lang string, now time.Time) AccountSecurityTwoFactor {
	badge, text, dot := accountSecurityStatusClasses("success")
	methodBadge, _, _ := accountSecurityStatusClasses("success")
	pendingBadge, _, _ := accountSecurityStatusClasses("pending")

	methods := []AccountSecurityTwoFactorMethod{
		{
			Icon:        "device-phone-mobile",
			Label:       i18nOrDefault(lang, "account.security.mfa.passkeys", "Passkey (Face ID)"),
			StatusLabel: i18nOrDefault(lang, "account.security.mfa.passkeys.enabled", "Available"),
			StatusClass: methodBadge,
			Description: i18nOrDefault(lang, "account.security.mfa.passkeys.desc", "Use platform biometrics for seamless sign-ins on iOS and macOS."),
		},
		{
			Icon:        "qr-code",
			Label:       i18nOrDefault(lang, "account.security.mfa.totp", "Authenticator app"),
			StatusLabel: i18nOrDefault(lang, "account.security.mfa.totp.enabled", "Enabled"),
			StatusClass: methodBadge,
			Description: i18nOrDefault(lang, "account.security.mfa.totp.desc", "Scanned with Authy on Haruka’s iPhone. Backup codes rotated monthly."),
		},
		{
			Icon:        "shield-check",
			Label:       i18nOrDefault(lang, "account.security.mfa.webauthn", "Security key"),
			StatusLabel: i18nOrDefault(lang, "account.security.mfa.webauthn.pending", "Add a key"),
			StatusClass: pendingBadge,
			Description: i18nOrDefault(lang, "account.security.mfa.webauthn.desc", "Enroll a FIDO2 security key for high-risk approvals."),
		},
	}

	return AccountSecurityTwoFactor{
		Enabled:          true,
		StatusLabel:      i18nOrDefault(lang, "account.security.mfa.status", "Mandatory for admins"),
		StatusBadgeClass: badge,
		StatusTextClass:  text,
		StatusDotClass:   dot,
		Description:      i18nOrDefault(lang, "account.security.mfa.description", "Hanko Field requires multi-factor for workspace admins. Rotate recovery codes after onboarding new devices."),
		Methods:          methods,
		PrimaryAction: AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.mfa.manage", "Manage authenticators"),
			Icon:    "cog-6-tooth",
			Variant: "primary",
			ModalID: "modal-mfa-manage",
			Classes: accountSecurityActionClasses("primary"),
		},
		SecondaryAction: &AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.mfa.view_logs", "View last challenges"),
			Icon:    "clock",
			Variant: "outline",
			Href:    "/account/security/mfa/audit",
			Method:  http.MethodGet,
			Classes: accountSecurityActionClasses("outline"),
		},
		Modal: AccountSecurityModal{
			ID:          "modal-mfa-manage",
			Title:       i18nOrDefault(lang, "account.security.modal.mfa.title", "Manage multi-factor authentication"),
			Description: i18nOrDefault(lang, "account.security.modal.mfa.desc", "Scan the QR code below with your authenticator or enroll a passkey."),
			Body: []AccountSecurityModalBody{
				{
					Icon:        "qr-code",
					Title:       i18nOrDefault(lang, "account.security.modal.mfa.step1", "Scan QR code"),
					Description: i18nOrDefault(lang, "account.security.modal.mfa.step1.desc", "Open your authenticator app and add a new account using the code on screen."),
				},
				{
					Icon:        "device-phone-mobile",
					Title:       i18nOrDefault(lang, "account.security.modal.mfa.step2", "Confirm six digit code"),
					Description: i18nOrDefault(lang, "account.security.modal.mfa.step2.desc", "Enter the first generated code to verify the device."),
				},
			},
			ConfirmLabel:    i18nOrDefault(lang, "account.security.modal.mfa.confirm", "Mark device as enrolled"),
			ConfirmVariant:  "primary",
			ConfirmHref:     "/account/security/mfa/enroll",
			ConfirmMethod:   http.MethodPost,
			ConfirmHXTarget: "#modal-root",
			ConfirmHXSwap:   "none",
			FooterNote:      i18nOrDefault(lang, "account.security.modal.mfa.footnote", "Need help? Share the QR safely via secure messaging or regenerate a fresh secret."),
			SuccessMessage:  i18nOrDefault(lang, "account.security.modal.mfa.success", "Authenticator recorded"),
			ConfirmClasses:  accountSecurityActionClasses("primary"),
		},
		BackupCodes:           []string{"4JMP-93KD", "XQ2L-7H9N", "LTF8-PA0D", "CK92-MSNB", "JH6D-Q0LA"},
		BackupCodesRotated:    format.FmtDate(now.Add(-20*24*time.Hour), lang),
		BackupCodesRotatedISO: now.Add(-20 * 24 * time.Hour).Format(time.RFC3339),
		RecoveryEmail:         "security@finitefield.org",
		RecoveryPhone:         "+81-80-1234-9876",
	}
}

func buildAccountSecurityPassword(lang string, now time.Time) AccountSecurityPasswordCard {
	strengthBadge, _, _ := accountSecurityStatusClasses("success")

	return AccountSecurityPasswordCard{
		HasPassword:    true,
		LastChanged:    relativeTime(now.Add(-45*24*time.Hour), lang),
		LastChangedISO: now.Add(-45 * 24 * time.Hour).Format(time.RFC3339),
		StrengthLabel:  i18nOrDefault(lang, "account.security.password.strong", "Strong"),
		StrengthClass:  strengthBadge,
		Description:    i18nOrDefault(lang, "account.security.password.description", "Use a randomly generated password in your password manager. Required for SCIM or API usage."),
		Action: AccountSecurityAction{
			Label:   i18nOrDefault(lang, "account.security.password.change", "Change password"),
			Icon:    "key",
			Variant: "primary",
			Href:    "/account/security/password/change",
			Method:  http.MethodGet,
			Classes: accountSecurityActionClasses("primary"),
		},
		SecondaryAction: &AccountSecurityAction{
			Label:          i18nOrDefault(lang, "account.security.password.reset_link", "Email reset link"),
			Icon:           "envelope-open",
			Variant:        "outline",
			Href:           "/account/security/password/reset-link",
			Method:         http.MethodPost,
			Classes:        accountSecurityActionClasses("outline"),
			SuccessMessage: i18nOrDefault(lang, "account.security.password.reset_link.success", "Password reset email sent"),
		},
	}
}

func buildAccountSecuritySessions(lang string, now time.Time) AccountSecuritySessionsView {
	riskLowBadge, riskLowText, _ := accountSecurityStatusClasses("success")
	riskMedBadge, riskMedText, _ := accountSecurityStatusClasses("warning")
	riskHighBadge, riskHighText, _ := accountSecurityStatusClasses("danger")

	sessions := []AccountSecuritySession{
		{
			ID:            "sess-mac-01",
			Device:        "MacBook Pro 14”",
			Platform:      "Safari · macOS 15.2",
			Location:      i18nOrDefault(lang, "account.session.location.tokyo", "Tokyo, Japan"),
			IP:            "203.0.113.24",
			LastActive:    relativeTime(now.Add(-27*time.Minute), lang),
			LastActiveISO: now.Add(-27 * time.Minute).Format(time.RFC3339),
			Current:       true,
			Risk:          i18nOrDefault(lang, "account.security.sessions.risk.low", "Low"),
			RiskBadge:     riskLowBadge,
			RiskText:      riskLowText,
			SignInMethod:  "Passkey · Touch ID",
			RevokeAction: AccountSecurityAction{
				Label:   i18nOrDefault(lang, "account.security.sessions.current", "Active session"),
				Variant: "static",
				Classes: accountSecurityActionClasses("static"),
			},
		},
		{
			ID:            "sess-ios-02",
			Device:        "iPhone 15 Pro",
			Platform:      "Hanko Field App · iOS 18",
			Location:      i18nOrDefault(lang, "account.session.location.osaka", "Osaka, Japan"),
			IP:            "198.51.100.11",
			LastActive:    relativeTime(now.Add(-26*time.Hour), lang),
			LastActiveISO: now.Add(-26 * time.Hour).Format(time.RFC3339),
			Current:       false,
			Risk:          i18nOrDefault(lang, "account.security.sessions.risk.low", "Low"),
			RiskBadge:     riskLowBadge,
			RiskText:      riskLowText,
			SignInMethod:  "Authenticator · TOTP",
			RevokeAction: AccountSecurityAction{
				Label:          i18nOrDefault(lang, "account.security.sessions.sign_out", "Sign out"),
				Icon:           "power",
				Variant:        "ghost",
				Href:           "/account/security/sessions/sess-ios-02/revoke",
				Method:         http.MethodPost,
				HXTarget:       "#account-security-sessions",
				HXSwap:         "outerHTML",
				Classes:        accountSecurityActionClasses("ghost"),
				SuccessMessage: i18nOrDefault(lang, "account.security.sessions.sign_out.success", "Session sign-out requested"),
			},
		},
		{
			ID:            "sess-web-03",
			Device:        "Windows · Edge",
			Platform:      "Edge 131 · Windows 11",
			Location:      i18nOrDefault(lang, "account.session.location.singapore", "Singapore"),
			IP:            "192.0.2.88",
			LastActive:    relativeTime(now.Add(-5*24*time.Hour), lang),
			LastActiveISO: now.Add(-5 * 24 * time.Hour).Format(time.RFC3339),
			Current:       false,
			Risk:          i18nOrDefault(lang, "account.security.sessions.risk.medium", "Medium"),
			RiskBadge:     riskMedBadge,
			RiskText:      riskMedText,
			SignInMethod:  "Password + SMS",
			RevokeAction: AccountSecurityAction{
				Label:          i18nOrDefault(lang, "account.security.sessions.revoke", "Revoke token"),
				Icon:           "shield-exclamation",
				Variant:        "danger",
				Href:           "/account/security/sessions/sess-web-03/revoke",
				Method:         http.MethodPost,
				HXTarget:       "#account-security-sessions",
				HXSwap:         "outerHTML",
				Classes:        accountSecurityActionClasses("danger"),
				SuccessMessage: i18nOrDefault(lang, "account.security.sessions.revoke.success", "Access token revoked"),
			},
		},
		{
			ID:            "sess-unknown-04",
			Device:        i18nOrDefault(lang, "account.security.sessions.unknown_device", "Unknown Android device"),
			Platform:      "Chrome 130 · Android 15",
			Location:      i18nOrDefault(lang, "account.security.sessions.location.seoul", "Seoul, South Korea"),
			IP:            "203.0.113.91",
			LastActive:    relativeTime(now.Add(-9*time.Hour), lang),
			LastActiveISO: now.Add(-9 * time.Hour).Format(time.RFC3339),
			Current:       false,
			Risk:          i18nOrDefault(lang, "account.security.sessions.risk.high", "High"),
			RiskBadge:     riskHighBadge,
			RiskText:      riskHighText,
			SignInMethod:  "Authenticator (denied)",
			RevokeAction: AccountSecurityAction{
				Label:          i18nOrDefault(lang, "account.security.sessions.block", "Block & reset"),
				Icon:           "no-symbol",
				Variant:        "danger",
				Href:           "/account/security/sessions/sess-unknown-04/revoke",
				Method:         http.MethodPost,
				HXTarget:       "#account-security-sessions",
				HXSwap:         "outerHTML",
				Classes:        accountSecurityActionClasses("danger"),
				SuccessMessage: i18nOrDefault(lang, "account.security.sessions.block.success", "Session blocked and password reset"),
			},
		},
	}

	return AccountSecuritySessionsView{
		Title:    i18nOrDefault(lang, "account.security.sessions.title", "Active sessions"),
		Subtitle: i18nOrDefault(lang, "account.security.sessions.subtitle", "Sign out suspicious devices immediately to revoke access tokens."),
		Sessions: sessions,
		Empty:    i18nOrDefault(lang, "account.security.sessions.empty", "No active sessions."),
	}
}

func accountSecurityTonePalette(tone string) (bg, border, text, icon string) {
	switch tone {
	case "success":
		return "bg-emerald-50", "border-emerald-200", "text-emerald-900", "check-badge"
	case "danger":
		return "bg-rose-50", "border-rose-200", "text-rose-900", "no-symbol"
	case "warning":
		return "bg-amber-50", "border-amber-200", "text-amber-900", "exclamation-triangle"
	case "info":
		return "bg-sky-50", "border-sky-200", "text-sky-900", "information-circle"
	default:
		return "bg-gray-50", "border-gray-200", "text-gray-900", "information-circle"
	}
}

func accountSecurityStatusClasses(tone string) (badge, text, dot string) {
	switch tone {
	case "success":
		return "bg-emerald-100 text-emerald-800", "text-emerald-700", "bg-emerald-500"
	case "pending":
		return "bg-sky-100 text-sky-800", "text-sky-700", "bg-sky-500"
	case "warning":
		return "bg-amber-100 text-amber-800", "text-amber-700", "bg-amber-500"
	case "danger":
		return "bg-rose-100 text-rose-800", "text-rose-700", "bg-rose-500"
	default:
		return "bg-gray-100 text-gray-700", "text-gray-600", "bg-gray-400"
	}
}

func accountSecurityActionClasses(variant string) string {
	switch variant {
	case "primary":
		return "inline-flex items-center gap-2 rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
	case "outline":
		return "inline-flex items-center gap-2 rounded-xl border border-gray-300 bg-white px-4 py-2.5 text-sm font-semibold text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700"
	case "danger":
		return "inline-flex items-center gap-2 rounded-xl bg-rose-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-rose-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-rose-600"
	case "ghost":
		return "inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold text-gray-600 transition hover:bg-gray-100"
	case "static":
		return "inline-flex items-center gap-2 rounded-xl border border-gray-200 bg-gray-100 px-4 py-2 text-sm font-semibold text-gray-600"
	default:
		return "inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold text-gray-700 hover:bg-gray-100"
	}
}
