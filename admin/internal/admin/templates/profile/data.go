package profile

import (
	"sort"
	"strings"
	"time"

	"finitefield.org/hanko-admin/internal/admin/profile"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData drives the main profile page.
type PageData struct {
	UserEmail    string
	UserName     string
	DisplayName  string
	Roles        []string
	LastLogin    *time.Time
	Security     *profile.SecurityState
	FeatureFlags []FeatureFlagEntry
	ActiveTab    string
	CSRFToken    string
	Flash        string
}

// SessionUpdateData refreshes sessions table.
type SessionUpdateData struct {
	Security  *profile.SecurityState
	CSRFToken string
	Message   string
}

// AlertContent describes a static callout card.
type AlertContent struct {
	Title    string
	Body     string
	LinkHref string
	LinkText string
}

// FeatureFlagEntry captures the enabled/disabled state for a named feature flag.
type FeatureFlagEntry struct {
	Key     string
	Enabled bool
}

func breadcrumbItems() []partials.Breadcrumb {
	return []partials.Breadcrumb{
		{Label: "プロフィール"},
	}
}


// FeatureFlagsFromMap converts a feature flag map into a deterministic slice for rendering.
func FeatureFlagsFromMap(flags map[string]bool) []FeatureFlagEntry {
	if len(flags) == 0 {
		return nil
	}
	entries := make([]FeatureFlagEntry, 0, len(flags))
	for key, enabled := range flags {
		trimmed := strings.TrimSpace(key)
		if trimmed == "" {
			continue
		}
		entries = append(entries, FeatureFlagEntry{Key: trimmed, Enabled: enabled})
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Key < entries[j].Key
	})
	return entries
}

// MostRecentSessionAt returns the most recent session timestamp from the security state.
func MostRecentSessionAt(state *profile.SecurityState) *time.Time {
	if state == nil {
		return nil
	}
	var latest *time.Time
	for _, session := range state.Sessions {
		ts := session.LastSeenAt
		if ts.IsZero() {
			ts = session.CreatedAt
		}
		if ts.IsZero() {
			continue
		}
		candidate := ts
		if latest == nil || candidate.After(*latest) {
			latest = &candidate
		}
	}
	return latest
}

// AvatarInitial derives the initial used for avatar placeholders.
func AvatarInitial(name, email, fallback string) string {
	candidate := strings.TrimSpace(name)
	if candidate == "" {
		candidate = strings.TrimSpace(email)
	}
	if candidate == "" {
		candidate = strings.TrimSpace(fallback)
	}
	if candidate == "" {
		return "?"
	}
	runes := []rune(strings.ToUpper(candidate))
	return string(runes[0])
}

func formatTimestamp(t time.Time) string {
	if t.IsZero() {
		return "-"
	}
	return helpers.Relative(t)
}
