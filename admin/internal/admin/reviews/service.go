package reviews

import (
	"context"
	"errors"
	"time"
)

// ErrNotConfigured indicates the reviews service dependency has not been provided.
var ErrNotConfigured = errors.New("reviews service not configured")

// Service exposes review moderation data to the admin UI.
type Service interface {
	// List returns reviews matching the provided moderation query.
	List(ctx context.Context, token string, query ListQuery) (ListResult, error)
}

// ModerationStatus represents the moderation state of a review.
type ModerationStatus string

const (
	// ModerationPending indicates the review is awaiting moderation.
	ModerationPending ModerationStatus = "pending"
	// ModerationApproved indicates the review has been approved for publication.
	ModerationApproved ModerationStatus = "approved"
	// ModerationRejected indicates the review has been rejected.
	ModerationRejected ModerationStatus = "rejected"
)

// SortDirection captures ascending / descending preference.
type SortDirection string

const (
	// SortDirectionAsc sorts ascending.
	SortDirectionAsc SortDirection = "asc"
	// SortDirectionDesc sorts descending.
	SortDirectionDesc SortDirection = "desc"
)

// SortKey enumerates supported ordering keys.
type SortKey string

const (
	// SortSubmittedAt orders by submission timestamp.
	SortSubmittedAt SortKey = "submitted_at"
	// SortRating orders by review rating.
	SortRating SortKey = "rating"
)

// ListQuery captures moderation queue filters.
type ListQuery struct {
	Moderation    []ModerationStatus
	Ratings       []int
	ProductIDs    []string
	FlagTypes     []string
	Channels      []string
	AgeBucket     string
	Search        string
	Page          int
	PageSize      int
	SortKey       SortKey
	SortDirection SortDirection
}

// ListResult represents a paginated moderation result set.
type ListResult struct {
	Reviews     []Review
	Pagination  Pagination
	Summary     Summary
	Filters     FilterSummary
	Queue       QueueMetrics
	GeneratedAt time.Time
}

// Pagination captures pagination metadata.
type Pagination struct {
	Page       int
	PageSize   int
	TotalItems int
	NextPage   *int
	PrevPage   *int
}

// Summary aggregates moderation snapshot metrics.
type Summary struct {
	PendingCount   int
	ApprovedCount  int
	RejectedCount  int
	FlaggedCount   int
	EscalatedCount int
	AverageRating  float64
}

// FilterSummary exposes available filters for the toolbar.
type FilterSummary struct {
	Ratings    []RatingOption
	Products   []ProductOption
	Flags      []FlagOption
	Channels   []ChannelOption
	AgeBuckets []AgeBucketOption
}

// RatingOption renders the rating chip group.
type RatingOption struct {
	Value  int
	Label  string
	Count  int
	Active bool
}

// ProductOption renders the product select options.
type ProductOption struct {
	ID     string
	Label  string
	SKU    string
	Count  int
	Active bool
}

// FlagOption renders flag filter chips.
type FlagOption struct {
	Value       string
	Label       string
	Description string
	Tone        string
	Count       int
	Active      bool
}

// ChannelOption renders the channel selector.
type ChannelOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// AgeBucketOption renders the age bucket selector.
type AgeBucketOption struct {
	Value  string
	Label  string
	Active bool
}

// QueueMetrics powers the productivity summary cards.
type QueueMetrics struct {
	ProcessedToday      int
	ProcessedThisWeek   int
	BacklogPending      int
	BacklogFlagged      int
	SLASecondsRemaining int
	NextSLABreach       time.Time
}

// Review represents a single review awaiting moderation.
type Review struct {
	ID          string
	Rating      int
	Title       string
	Body        string
	Locale      string
	Channel     string
	SubmittedAt time.Time
	UpdatedAt   time.Time
	Helpful     HelpfulStats
	Reported    bool
	ReportNotes string
	Flags       []Flag
	Attachments []Attachment
	Customer    Customer
	Product     Product
	Order       Order
	Moderation  Moderation
	Preview     Preview
}

// Flag describes a review flag or report entry.
type Flag struct {
	Type        string
	Label       string
	Description string
	Tone        string
	CreatedAt   time.Time
	Actor       string
}

// HelpfulStats tracks helpful votes.
type HelpfulStats struct {
	Yes int
	No  int
}

// Attachment represents an uploaded asset.
type Attachment struct {
	ID       string
	URL      string
	ThumbURL string
	Kind     string
	Label    string
}

// Customer contains customer profile details.
type Customer struct {
	ID         string
	Name       string
	Email      string
	AvatarURL  string
	Location   string
	Segment    string
	OrderCount int
	LastOrder  time.Time
}

// Product summarises the purchased product.
type Product struct {
	ID           string
	Name         string
	Variant      string
	SKU          string
	ImageURL     string
	DetailURL    string
	PriceMinor   int64
	Currency     string
	PreviewImage string
}

// Order captures order level metadata.
type Order struct {
	ID         string
	Number     string
	URL        string
	PlacedAt   time.Time
	TotalMinor int64
	Currency   string
}

// Moderation aggregates moderation status and history.
type Moderation struct {
	Status        ModerationStatus
	StatusLabel   string
	StatusTone    string
	Escalated     bool
	Notes         string
	LastModerator string
	LastActionAt  time.Time
	History       []ModerationEvent
}

// ModerationEvent stores a historical moderation action.
type ModerationEvent struct {
	ID        string
	Action    string
	Outcome   string
	Reason    string
	Actor     string
	Tone      string
	CreatedAt time.Time
}

// Preview represents storefront display context.
type Preview struct {
	DisplayName string
	ProductName string
	Headline    string
	Body        string
	Rating      int
	Photos      []Attachment
	SubmittedAt time.Time
}
