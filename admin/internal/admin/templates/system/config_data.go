package system

import (
	"sort"
	"strings"
	"time"

	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// EnvironmentSettingsPageData represents the payload for the environment settings page.
type EnvironmentSettingsPageData struct {
	Title           string
	Description     string
	Breadcrumbs     []partials.Breadcrumb
	Environment     string
	EnvironmentName string
	Region          string
	Summary         string
	ReadOnly        bool
	Error           string
	GeneratedLabel  string
	Metadata        []KeyValue
	Documents       []LinkView
	Categories      []ConfigCategoryView
	Navigation      []ConfigNavigationItem
	AuditTrail      []ConfigAuditEntryView
}

// ConfigCategoryView renders grouped configuration values.
type ConfigCategoryView struct {
	ID          string
	Anchor      string
	Title       string
	Description string
	Items       []ConfigItemView
}

// ConfigItemView renders a single configuration toggle/value.
type ConfigItemView struct {
	ID           string
	Label        string
	Description  string
	Value        string
	ValueHint    string
	StatusLabel  string
	StatusTone   string
	Tags         []string
	Docs         []LinkView
	Sensitive    bool
	Locked       bool
	LockedReason string
}

// ConfigNavigationItem renders the left side category navigation.
type ConfigNavigationItem struct {
	ID    string
	Href  string
	Title string
}

// ConfigAuditEntryView renders the recent change log.
type ConfigAuditEntryView struct {
	ID        string
	Actor     string
	Action    string
	Summary   string
	Timestamp string
	Relative  string
	Changes   []ConfigAuditChangeView
}

// ConfigAuditChangeView renders before/after details.
type ConfigAuditChangeView struct {
	Field  string
	Before string
	After  string
}

// BuildEnvironmentSettingsPageData assembles the page payload from the domain model.
func BuildEnvironmentSettingsPageData(basePath string, cfg adminsystem.EnvironmentConfig) EnvironmentSettingsPageData {
	generated := cfg.GeneratedAt
	if generated.IsZero() {
		generated = time.Now()
	}

	metadata := make([]KeyValue, 0, len(cfg.Metadata))
	for key, value := range cfg.Metadata {
		metadata = append(metadata, KeyValue{
			Key:   strings.TrimSpace(key),
			Value: strings.TrimSpace(value),
		})
	}
	sort.Slice(metadata, func(i, j int) bool {
		return metadata[i].Key < metadata[j].Key
	})

	documents := make([]LinkView, 0, len(cfg.Documents))
	for _, link := range cfg.Documents {
		if strings.TrimSpace(link.Label) == "" || strings.TrimSpace(link.URL) == "" {
			continue
		}
		documents = append(documents, LinkView{
			Label: link.Label,
			URL:   link.URL,
			Icon:  link.Icon,
		})
	}

	categories := make([]ConfigCategoryView, 0, len(cfg.Categories))
	nav := make([]ConfigNavigationItem, 0, len(cfg.Categories))
	for _, cat := range cfg.Categories {
		id := slugify(cat.ID, cat.Title)
		items := make([]ConfigItemView, 0, len(cat.Items))
		for _, item := range cat.Items {
			items = append(items, ConfigItemView{
				ID:           strings.TrimSpace(item.ID),
				Label:        fallbackString(item.Label, item.ID),
				Description:  strings.TrimSpace(item.Description),
				Value:        strings.TrimSpace(item.Value),
				ValueHint:    strings.TrimSpace(item.ValueHint),
				StatusLabel:  strings.TrimSpace(item.StatusLabel),
				StatusTone:   strings.TrimSpace(item.StatusTone),
				Tags:         append([]string(nil), item.Tags...),
				Docs:         linkViewsFromLinks(item.Docs),
				Sensitive:    item.Sensitive,
				Locked:       item.Locked,
				LockedReason: strings.TrimSpace(item.LockedReason),
			})
		}
		categories = append(categories, ConfigCategoryView{
			ID:          id,
			Anchor:      "#" + id,
			Title:       fallbackString(cat.Title, capFirst(id)),
			Description: strings.TrimSpace(cat.Description),
			Items:       items,
		})
		nav = append(nav, ConfigNavigationItem{
			ID:    id,
			Href:  "#" + id,
			Title: fallbackString(cat.Title, capFirst(id)),
		})
	}

	auditTrail := make([]ConfigAuditEntryView, 0, len(cfg.AuditTrail))
	sort.Slice(cfg.AuditTrail, func(i, j int) bool {
		return cfg.AuditTrail[i].Timestamp.After(cfg.AuditTrail[j].Timestamp)
	})
	for _, entry := range cfg.AuditTrail {
		ts := entry.Timestamp
		timestamp := "-"
		relative := ""
		if !ts.IsZero() {
			timestamp = helpers.Date(ts, "2006-01-02 15:04")
			relative = helpers.Relative(ts)
		}
		changes := make([]ConfigAuditChangeView, 0, len(entry.Changes))
		for _, change := range entry.Changes {
			changes = append(changes, ConfigAuditChangeView{
				Field:  strings.TrimSpace(change.Field),
				Before: strings.TrimSpace(change.Before),
				After:  strings.TrimSpace(change.After),
			})
		}
		actor := fallbackString(entry.ActorName, entry.ActorEmail)
		if actor == "" {
			actor = "Unknown"
		}
		auditTrail = append(auditTrail, ConfigAuditEntryView{
			ID:        strings.TrimSpace(entry.ID),
			Actor:     actor,
			Action:    strings.TrimSpace(entry.Action),
			Summary:   strings.TrimSpace(entry.Summary),
			Timestamp: timestamp,
			Relative:  relative,
			Changes:   changes,
		})
	}

	return EnvironmentSettingsPageData{
		Title:           "環境設定",
		Description:     "フィーチャーフラグや主要連携の状態を確認します。変更は Runbook に従って申請してください。",
		Breadcrumbs:     systemBreadcrumbs(basePath, "/system/settings"),
		Environment:     strings.TrimSpace(cfg.Environment),
		EnvironmentName: fallbackString(cfg.EnvironmentLabel, cfg.Environment),
		Region:          strings.TrimSpace(cfg.Region),
		Summary:         strings.TrimSpace(cfg.Summary),
		ReadOnly:        cfg.ReadOnly,
		Error:           "",
		GeneratedLabel:  helpers.I18N("common.last_updated") + ": " + helpers.Relative(generated),
		Metadata:        metadata,
		Documents:       documents,
		Categories:      categories,
		Navigation:      nav,
		AuditTrail:      auditTrail,
	}
}

func linkViewsFromLinks(links []adminsystem.Link) []LinkView {
	result := make([]LinkView, 0, len(links))
	for _, link := range links {
		if strings.TrimSpace(link.Label) == "" || strings.TrimSpace(link.URL) == "" {
			continue
		}
		result = append(result, LinkView{
			Label: link.Label,
			URL:   link.URL,
			Icon:  link.Icon,
		})
	}
	return result
}

func fallbackString(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return strings.TrimSpace(fallback)
	}
	return strings.TrimSpace(value)
}

func capFirst(value string) string {
	if value == "" {
		return ""
	}
	runes := []rune(value)
	if len(runes) == 0 {
		return value
	}
	runes[0] = toUpper(runes[0])
	return string(runes)
}

func slugify(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) == "" {
			continue
		}
		return strings.ToLower(strings.ReplaceAll(strings.TrimSpace(value), " ", "-"))
	}
	return ""
}

func systemBreadcrumbs(basePath, current string) []partials.Breadcrumb {
	return []partials.Breadcrumb{
		{Label: "システム運用", Href: joinBasePath(basePath, "/system/tasks")},
		{Label: "環境設定", Href: joinBasePath(basePath, current)},
	}
}
