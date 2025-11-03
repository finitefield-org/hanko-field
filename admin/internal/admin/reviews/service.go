package reviews

import (
	"context"
	"errors"
	"time"
)

// ErrNotConfigured indicates the reviews service dependency has not been provided.
var ErrNotConfigured = errors.New("reviews service not configured")

// ErrReviewNotFound indicates the requested review does not exist.
var ErrReviewNotFound = errors.New("review not found")

// ErrInvalidDecision indicates the provided moderation decision is unsupported.
var ErrInvalidDecision = errors.New("invalid moderation decision")

// ErrEmptyReplyBody indicates the reply body was empty.
var ErrEmptyReplyBody = errors.New("reply body cannot be empty")

// Service exposes review moderation data to the admin UI.
type Service interface {
	// List returns reviews matching the provided moderation query.
	List(ctx context.Context, token string, query ListQuery) (ListResult, error)

	// ModerationModal loads contextual data for rendering the approval / rejection modal.
	ModerationModal(ctx context.Context, token, reviewID string, decision ModerationDecision) (ModerationModal, error)

	// Moderate submits a moderation decision for the specified review and returns the updated review.
	Moderate(ctx context.Context, token, reviewID string, req ModerationRequest) (ModerationResult, error)

	// ReplyModal loads contextual data for capturing a storefront reply for the specified review.
	ReplyModal(ctx context.Context, token, reviewID string) (ReplyModal, error)

	// StoreReply persists a storefront reply for the specified review and returns the updated review.
	StoreReply(ctx context.Context, token, reviewID string, req ReplyRequest) (ReplyResult, error)
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

// ModerationDecision represents an approval or rejection choice.
type ModerationDecision string

const (
	// ModerationDecisionApprove approves a review for publication.
	ModerationDecisionApprove ModerationDecision = "approve"
	// ModerationDecisionReject rejects a review.
	ModerationDecisionReject ModerationDecision = "reject"
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
	Replies     []Reply
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

// Reply represents a recorded storefront response from staff.
type Reply struct {
	ID             string
	Body           string
	IsPublic       bool
	NotifyCustomer bool
	AuthorName     string
	AuthorEmail    string
	CreatedAt      time.Time
	LastUpdatedAt  time.Time
}

// ModerationModal provides context for moderation decisions.
type ModerationModal struct {
	ReviewID           string
	Decision           ModerationDecision
	DecisionLabel      string
	ReviewTitle        string
	ReviewExcerpt      string
	Rating             int
	CustomerName       string
	CustomerEmail      string
	CurrentStatus      ModerationStatus
	CurrentStatusLabel string
	CurrentStatusTone  string
	ExistingNotes      string
	Escalated          bool
	Flags              []ModerationFlag
}

// ModerationFlag summarises a review flag for modal context.
type ModerationFlag struct {
	Label       string
	Description string
	Tone        string
}

// ModerationRequest encapsulates the moderation decision payload.
type ModerationRequest struct {
	Decision       ModerationDecision
	Notes          string
	NotifyCustomer bool
	ActorID        string
	ActorName      string
	ActorEmail     string
}

// ModerationResult returns the updated review after a moderation decision.
type ModerationResult struct {
	Review Review
}

// ReplyModal encapsulates the data required to render the reply modal.
type ReplyModal struct {
	ReviewID      string
	ReviewTitle   string
	CustomerName  string
	CustomerEmail string
	Rating        int
	ExistingReply *Reply
}

// ReplyRequest captures the payload for storing a reply.
type ReplyRequest struct {
	Body           string
	IsPublic       bool
	NotifyCustomer bool
	ActorID        string
	ActorName      string
	ActorEmail     string
}

// ReplyResult returns the updated review and the stored reply.
type ReplyResult struct {
	Review Review
	Reply  Reply
}
