package auditlogs

import (
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	adminaudit "finitefield.org/hanko-admin/internal/admin/auditlogs"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData represents the payload for the audit log index page.
type PageData struct {
	Title         string
	Description   string
	Breadcrumbs   []partials.Breadcrumb
	Summary       SummaryView
	Alerts        []AlertView
	Query         QueryState
	Filters       Filters
	Table         TableData
	TableEndpoint string
	ExportURL     string
	ResetURL      string
}

// SummaryView renders the headline counters.
type SummaryView struct {
	WindowLabel   string
	CountLabel    string
	ActorsLabel   string
	TargetsLabel  string
	RetentionNote string
	GeneratedAt   string
	GeneratedAgo  string
}

// AlertView surfaces inline alerts above the table.
type AlertView struct {
	Tone    string
	Message string
	Icon    string
}

// QueryState captures the current filter selections.
type QueryState struct {
	Targets  []string
	Actors   []string
	Actions  []string
	From     string
	To       string
	Search   string
	Page     int
	PageSize int
	RawQuery string
}

// Filters groups filter option view models.
type Filters struct {
	TargetOptions []SelectOption
	ActorOptions  []SelectOption
	ActionOptions []ActionChip
}

// SelectOption renders selectable values for resource/actor selectors.
type SelectOption struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// ActionChip renders an action chip filter.
type ActionChip struct {
	Value  string
	Label  string
	Tone   string
	Count  int
	Active bool
}

// TableData powers the table fragment.
type TableData struct {
	Rows          []TableRow
	Error         string
	EmptyMessage  string
	BasePath      string
	FragmentPath  string
	RawQuery      string
	Pagination    components.PaginationProps
	ExportEnabled bool
}

// TableRow represents a table row with expandable diff payload.
type TableRow struct {
	ID                string
	ToggleID          string
	Timestamp         string
	TimestampRelative string
	ActionLabel       string
	ActionTone        string
	TargetLabel       string
	TargetURL         string
	TargetReference   string
	Summary           string
	ActorName         string
	ActorEmail        string
	ActorAvatar       string
	ActorTooltip      string
	IPAddress         string
	UserAgent         string
	DiffBefore        string
	DiffAfter         string
	Metadata          []MetadataItem
}

// MetadataItem renders supplemental key/value pairs.
type MetadataItem struct {
	Label string
	Value string
}

// BuildPageData assembles the SSR payload for the audit log page.
func BuildPageData(basePath string, state QueryState, result adminaudit.ListResult) PageData {
	table := TablePayload(basePath, state, result, "")

	return PageData{
		Title:         "監査ログ",
		Description:   "管理者の操作履歴やシステムアクションを検索し、差分を確認します。",
		Breadcrumbs:   breadcrumbItems(),
		Summary:       buildSummaryView(result.Summary, result.Generated),
		Alerts:        buildAlertViews(result.Alerts),
		Query:         state,
		Filters:       buildFilterView(state, result.Filters),
		Table:         table,
		TableEndpoint: joinBase(basePath, "/audit-logs/table"),
		ExportURL:     exportURL(basePath, state),
		ResetURL:      joinBase(basePath, "/audit-logs"),
	}
}

// TablePayload prepares the table fragment payload.
func TablePayload(basePath string, state QueryState, result adminaudit.ListResult, errMsg string) TableData {
	base := joinBase(basePath, "/audit-logs")
	fragment := joinBase(basePath, "/audit-logs/table")
	rows := toTableRows(result.Entries)

	empty := ""
	if errMsg == "" && len(rows) == 0 {
		empty = "条件に一致する監査ログはありません。フィルタを調整してください。"
	}

	total := result.Pagination.TotalItems
	pagination := components.PaginationProps{
		Info: components.PageInfo{
			PageSize:   result.Pagination.PageSize,
			Current:    result.Pagination.Page,
			Count:      len(rows),
			TotalItems: &total,
			Next:       result.Pagination.NextPage,
			Prev:       result.Pagination.PrevPage,
		},
		BasePath:      base,
		RawQuery:      state.RawQuery,
		FragmentPath:  fragment,
		FragmentQuery: state.RawQuery,
		Param:         "page",
		SizeParam:     "pageSize",
		HxTarget:      "#audit-log-table",
		HxSwap:        "outerHTML",
		HxPushURL:     true,
		Label:         "Audit log pagination",
	}

	return TableData{
		BasePath:      base,
		FragmentPath:  fragment,
		RawQuery:      state.RawQuery,
		Rows:          rows,
		Error:         errMsg,
		EmptyMessage:  empty,
		Pagination:    pagination,
		ExportEnabled: result.Exportable,
	}
}

func buildSummaryView(summary adminaudit.Summary, generated time.Time) SummaryView {
	countLabel := fmt.Sprintf("表示 %d / 合計 %d", summary.FilteredCount, summary.TotalEntries)
	actorsLabel := fmt.Sprintf("実行者 %d 人", summary.UniqueActors)
	targetsLabel := fmt.Sprintf("対象 %d 件", summary.UniqueTargets)

	var generatedAt, generatedAgo string
	if !generated.IsZero() {
		generatedAt = helpers.Date(generated, "2006-01-02 15:04")
		generatedAgo = helpers.Relative(generated)
	}

	return SummaryView{
		WindowLabel:   summary.WindowLabel,
		CountLabel:    countLabel,
		ActorsLabel:   actorsLabel,
		TargetsLabel:  targetsLabel,
		RetentionNote: summary.RetentionLabel,
		GeneratedAt:   generatedAt,
		GeneratedAgo:  generatedAgo,
	}
}

func buildAlertViews(alerts []adminaudit.Alert) []AlertView {
	if len(alerts) == 0 {
		return nil
	}
	out := make([]AlertView, 0, len(alerts))
	for _, alert := range alerts {
		out = append(out, AlertView{
			Tone:    alert.Tone,
			Message: alert.Message,
			Icon:    alert.Icon,
		})
	}
	return out
}

func buildFilterView(state QueryState, filters adminaudit.FilterSummary) Filters {
	targetOptions := make([]SelectOption, 0, len(filters.Targets))
	for _, option := range filters.Targets {
		targetOptions = append(targetOptions, SelectOption{
			Value:    option.Value,
			Label:    option.Label,
			Count:    option.Count,
			Selected: containsValue(state.Targets, option.Value),
		})
	}
	sort.SliceStable(targetOptions, func(i, j int) bool {
		return targetOptions[i].Label < targetOptions[j].Label
	})

	actorOptions := make([]SelectOption, 0, len(filters.Actors))
	for _, option := range filters.Actors {
		actorOptions = append(actorOptions, SelectOption{
			Value:    option.Value,
			Label:    option.Label,
			Count:    option.Count,
			Selected: containsValue(state.Actors, option.Value),
		})
	}
	sort.SliceStable(actorOptions, func(i, j int) bool {
		return actorOptions[i].Label < actorOptions[j].Label
	})

	actionOptions := make([]ActionChip, 0, len(filters.Actions))
	for _, action := range filters.Actions {
		actionOptions = append(actionOptions, ActionChip{
			Value:  action.Value,
			Label:  action.Label,
			Tone:   action.Tone,
			Count:  action.Count,
			Active: containsValue(state.Actions, action.Value),
		})
	}
	sort.SliceStable(actionOptions, func(i, j int) bool {
		return actionOptions[i].Label < actionOptions[j].Label
	})

	return Filters{
		TargetOptions: targetOptions,
		ActorOptions:  actorOptions,
		ActionOptions: actionOptions,
	}
}

func toTableRows(entries []adminaudit.Entry) []TableRow {
	rows := make([]TableRow, 0, len(entries))
	for _, entry := range entries {
		toggleID := fmt.Sprintf("audit-diff-%s", safeFragmentID(entry.ID))
		metadata := make([]MetadataItem, 0, len(entry.Metadata))
		for label, value := range entry.Metadata {
			if strings.TrimSpace(value) == "" {
				continue
			}
			metadata = append(metadata, MetadataItem{
				Label: label,
				Value: value,
			})
		}
		sort.SliceStable(metadata, func(i, j int) bool {
			return metadata[i].Label < metadata[j].Label
		})

		rows = append(rows, TableRow{
			ID:                entry.ID,
			ToggleID:          toggleID,
			Timestamp:         helpers.Date(entry.OccurredAt, "2006-01-02 15:04"),
			TimestampRelative: helpers.Relative(entry.OccurredAt),
			ActionLabel:       entry.ActionLabel,
			ActionTone:        entry.ActionTone,
			TargetLabel:       entry.Target.Label,
			TargetURL:         entry.Target.URL,
			TargetReference:   entry.Target.Reference,
			Summary:           entry.Summary,
			ActorName:         entry.Actor.Name,
			ActorEmail:        entry.Actor.Email,
			ActorAvatar:       entry.Actor.AvatarURL,
			ActorTooltip:      buildActorTooltip(entry.Actor),
			IPAddress:         entry.IPAddress,
			UserAgent:         entry.UserAgent,
			DiffBefore:        entry.Diff.Before,
			DiffAfter:         entry.Diff.After,
			Metadata:          metadata,
		})
	}
	return rows
}

func exportURL(basePath string, state QueryState) string {
	base := joinBase(basePath, "/audit-logs/export")
	if strings.TrimSpace(state.RawQuery) == "" {
		return base
	}
	return base + "?" + state.RawQuery
}

func breadcrumbItems() []partials.Breadcrumb {
	return []partials.Breadcrumb{
		{Label: "システム"},
		{Label: "監査ログ"},
	}
}

func safeFragmentID(value string) string {
	if strings.TrimSpace(value) == "" {
		return "row"
	}
	lower := strings.ToLower(value)
	builder := strings.Builder{}
	builder.Grow(len(lower))
	for _, r := range lower {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			builder.WriteRune(r)
			continue
		}
		if r == '-' {
			builder.WriteRune('-')
			continue
		}
		builder.WriteRune('-')
	}
	out := strings.Trim(builder.String(), "-")
	if out == "" {
		return "row"
	}
	return out
}

func buildActorTooltip(actor adminaudit.Actor) string {
	values := []string{}
	if strings.TrimSpace(actor.Name) != "" {
		values = append(values, actor.Name)
	}
	if strings.TrimSpace(actor.Email) != "" {
		values = append(values, actor.Email)
	}
	return strings.Join(values, " · ")
}

func containsValue(values []string, target string) bool {
	target = strings.ToLower(strings.TrimSpace(target))
	if target == "" {
		return false
	}
	for _, value := range values {
		if strings.ToLower(strings.TrimSpace(value)) == target {
			return true
		}
	}
	return false
}

func joinBase(basePath, suffix string) string {
	base := strings.TrimSpace(basePath)
	if base == "" || base == "/" {
		base = ""
	} else {
		if !strings.HasPrefix(base, "/") {
			base = "/" + base
		}
		base = strings.TrimRight(base, "/")
	}
	if strings.TrimSpace(suffix) == "" {
		if base == "" {
			return "/"
		}
		return base
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	return base + suffix
}

// BuildQueryState constructs view state from raw query parameters.
func BuildQueryState(raw url.Values) QueryState {
	targets := dedupe(nonEmpty(raw["target"]))
	actors := dedupe(nonEmpty(raw["actor"]))
	actions := dedupe(nonEmpty(raw["action"]))

	return QueryState{
		Targets:  targets,
		Actors:   actors,
		Actions:  actions,
		From:     strings.TrimSpace(raw.Get("from")),
		To:       strings.TrimSpace(raw.Get("to")),
		Search:   strings.TrimSpace(raw.Get("q")),
		Page:     parseInt(raw.Get("page")),
		PageSize: parseInt(raw.Get("pageSize")),
		RawQuery: raw.Encode(),
	}
}

func nonEmpty(values []string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		out = append(out, value)
	}
	return out
}

func dedupe(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	out := make([]string, 0, len(values))
	for _, value := range values {
		key := strings.ToLower(strings.TrimSpace(value))
		if key == "" {
			continue
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, value)
	}
	return out
}

func parseInt(value string) int {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0
	}
	return parsed
}
