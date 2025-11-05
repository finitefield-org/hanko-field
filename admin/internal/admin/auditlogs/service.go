package auditlogs

import (
	"context"
	"time"
)

// Service exposes audit log data to the admin UI.
type Service interface {
	// List returns paginated audit entries matching the provided filters.
	List(ctx context.Context, token string, query ListQuery) (ListResult, error)
	// Export generates a CSV export for the specified filter window.
	Export(ctx context.Context, token string, query ListQuery) (ExportResult, error)
}

// ListQuery captures filtering and pagination arguments.
type ListQuery struct {
	Targets  []string
	Actors   []string
	Actions  []string
	Search   string
	From     *time.Time
	To       *time.Time
	Page     int
	PageSize int
	Sort     string
}

// ListResult represents the paginated response returned to the UI.
type ListResult struct {
	Summary    Summary
	Filters    FilterSummary
	Entries    []Entry
	Pagination Pagination
	Alerts     []Alert
	Exportable bool
	Generated  time.Time
}

// Summary aggregates headline statistics.
type Summary struct {
	TotalEntries   int
	FilteredCount  int
	UniqueActors   int
	UniqueTargets  int
	WindowLabel    string
	RetentionDays  int
	RetentionLabel string
}

// FilterSummary enumerates select options for the toolbar.
type FilterSummary struct {
	Targets []Option
	Actors  []Option
	Actions []ActionOption
}

// Option represents a selectable filter value.
type Option struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// ActionOption renders an action chip filter.
type ActionOption struct {
	Value  string
	Label  string
	Tone   string
	Count  int
	Active bool
}

// Pagination conveys paging metadata.
type Pagination struct {
	Page       int
	PageSize   int
	TotalItems int
	NextPage   *int
	PrevPage   *int
}

// Entry describes a single audit record.
type Entry struct {
	ID          string
	Action      string
	ActionLabel string
	ActionTone  string
	Actor       Actor
	Target      Target
	Summary     string
	OccurredAt  time.Time
	IPAddress   string
	UserAgent   string
	Diff        Diff
	Metadata    map[string]string
}

// Actor identifies the user who performed the action.
type Actor struct {
	ID        string
	Name      string
	Email     string
	AvatarURL string
}

// Target represents the entity impacted by the change.
type Target struct {
	Reference string
	Label     string
	Type      string
	URL       string
}

// Diff exposes the before/after payloads for the change.
type Diff struct {
	Before string
	After  string
}

// Alert instructs the UI to surface contextual inline messaging.
type Alert struct {
	Tone    string
	Message string
	Icon    string
}

// ExportResult contains the rendered CSV payload.
type ExportResult struct {
	Filename    string
	ContentType string
	Data        []byte
	Generated   time.Time
}
