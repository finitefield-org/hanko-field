package catalog

import (
	"context"
	"strings"
	"time"
)

// Service exposes catalog listing capabilities for the admin UI.
type Service interface {
	// ListAssets returns catalog assets filtered by the provided query arguments.
	ListAssets(ctx context.Context, token string, query ListQuery) (ListResult, error)
}

// Kind enumerates high-level catalog groupings.
type Kind string

const (
	// KindTemplates represents design templates that users can customise.
	KindTemplates Kind = "templates"
	// KindFonts represents typography assets.
	KindFonts Kind = "fonts"
	// KindMaterials represents print substrates and material options.
	KindMaterials Kind = "materials"
	// KindProducts represents purchasable SKUs and bundles.
	KindProducts Kind = "products"
)

// NormalizeKind coerces arbitrary input to a known kind, defaulting to templates.
func NormalizeKind(value string) Kind {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case string(KindFonts):
		return KindFonts
	case string(KindMaterials):
		return KindMaterials
	case string(KindProducts):
		return KindProducts
	default:
		return KindTemplates
	}
}

// Label returns a human friendly label for the kind.
func (k Kind) Label() string {
	switch k {
	case KindFonts:
		return "フォント"
	case KindMaterials:
		return "用紙・素材"
	case KindProducts:
		return "商品"
	default:
		return "テンプレート"
	}
}

// Status represents the publish state of a catalog asset.
type Status string

const (
	// StatusDraft indicates the asset is in draft.
	StatusDraft Status = "draft"
	// StatusInReview indicates the asset awaits approval.
	StatusInReview Status = "in_review"
	// StatusPublished indicates the asset is live.
	StatusPublished Status = "published"
	// StatusArchived indicates the asset is archived.
	StatusArchived Status = "archived"
)

// ViewMode controls how assets are rendered in the UI.
type ViewMode string

const (
	// ViewModeTable renders the list as a data table.
	ViewModeTable ViewMode = "table"
	// ViewModeCards renders the list as cards.
	ViewModeCards ViewMode = "cards"
)

// SortDirection controls ordering for sortable fields.
type SortDirection string

const (
	// SortDirectionAsc sorts ascending.
	SortDirectionAsc SortDirection = "asc"
	// SortDirectionDesc sorts descending.
	SortDirectionDesc SortDirection = "desc"
)

// NormalizeViewMode defaults to the table view when the input is empty or unknown.
func NormalizeViewMode(value string) ViewMode {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case string(ViewModeCards):
		return ViewModeCards
	default:
		return ViewModeTable
	}
}

// ListQuery captures filter arguments for listing catalog assets.
type ListQuery struct {
	Kind          Kind
	Statuses      []Status
	Category      string
	Owner         string
	Tags          []string
	UpdatedRange  string
	Search        string
	View          ViewMode
	SelectedID    string
	Page          int
	PageSize      int
	SortKey       string
	SortDirection SortDirection
}

// ListResult wraps the filtered asset listing and supporting metadata.
type ListResult struct {
	Kind           Kind
	Items          []Item
	Summary        Summary
	Filters        FilterSummary
	Bulk           BulkSummary
	View           ViewMode
	SelectedID     string
	SelectedDetail *ItemDetail
	EmptyMessage   string
	Pagination     Pagination
}

// Pagination describes paging metadata for catalog listings.
type Pagination struct {
	Page       int
	PageSize   int
	TotalItems int
	NextPage   *int
	PrevPage   *int
}

// Item describes a summarized catalog asset as shown in tables or cards.
type Item struct {
	ID            string
	Name          string
	Identifier    string
	Kind          Kind
	Category      string
	CategoryLabel string
	Status        Status
	StatusLabel   string
	StatusTone    string
	Description   string
	Owner         OwnerInfo
	UpdatedAt     time.Time
	Version       string
	UsageCount    int
	UsageLabel    string
	Tags          []string
	PreviewURL    string
	PreviewAlt    string
	Channels      []string
	Format        string
	Metrics       []ItemMetric
	Badge         string
	BadgeTone     string
	PrimaryColor  string
}

// OwnerInfo identifies the staff member responsible for an asset.
type OwnerInfo struct {
	Name      string
	Email     string
	AvatarURL string
}

// ItemMetric highlights performance indicators for an asset.
type ItemMetric struct {
	Label string
	Value string
	Icon  string
}

// ItemDetail extends Item with preview, dependency, and audit metadata.
type ItemDetail struct {
	Item         Item
	PreviewURL   string
	PreviewAlt   string
	Description  string
	Owner        OwnerInfo
	Usage        []UsageMetric
	Metadata     []MetadataEntry
	Dependencies []Dependency
	AuditTrail   []AuditEntry
	Tags         []string
	UpdatedAt    time.Time
}

// UsageMetric summarises usage across channels or personas.
type UsageMetric struct {
	Label string
	Value string
	Icon  string
}

// MetadataEntry represents arbitrary key/value metadata.
type MetadataEntry struct {
	Key   string
	Value string
	Icon  string
}

// Dependency reflects upstream/downstream relationships for an asset.
type Dependency struct {
	Label   string
	Kind    string
	Status  string
	Tone    string
	LinkURL string
}

// AuditEntry captures change history for the asset.
type AuditEntry struct {
	Timestamp time.Time
	Actor     string
	Action    string
	Channel   string
}

// Summary aggregates top-line metrics for the filtered result set.
type Summary struct {
	Total        int
	Published    int
	Drafts       int
	Archived     int
	InReview     int
	LastUpdated  time.Time
	PrimaryLabel string
}

// BulkSummary describes the current bulk selection state and available actions.
type BulkSummary struct {
	Eligible int
	Actions  []BulkAction
}

// BulkAction represents a selectable bulk operation.
type BulkAction struct {
	Value       string
	Label       string
	Tone        string
	Description string
	Disabled    bool
}

// FilterSummary enumerates filter controls for the listing UI.
type FilterSummary struct {
	Statuses      []FilterOption
	Categories    []FilterOption
	Owners        []FilterOption
	Tags          []FilterOption
	UpdatedRanges []UpdatedRange
}

// FilterOption is a generic option with count metadata.
type FilterOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// UpdatedRange suggests quick filters for last updated timestamps.
type UpdatedRange struct {
	Value  string
	Label  string
	Hint   string
	Active bool
}
