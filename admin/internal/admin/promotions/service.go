package promotions

import (
	"context"
	"errors"
	"strings"
	"time"
)

// ErrNotConfigured indicates the promotions service dependency has not been provided.
var ErrNotConfigured = errors.New("promotions service not configured")

// ErrPromotionNotFound indicates the requested promotion does not exist or is not visible.
var ErrPromotionNotFound = errors.New("promotion not found")

// Service exposes promotion listing and enrichment capabilities for the admin UI.
type Service interface {
	// List returns a paginated collection of promotions matching the provided query.
	List(ctx context.Context, token string, query ListQuery) (ListResult, error)

	// Detail returns an enriched promotion payload for side drawers or follow-up actions.
	Detail(ctx context.Context, token, promotionID string) (PromotionDetail, error)

	// BulkStatus applies the requested bulk action to a collection of promotions.
	BulkStatus(ctx context.Context, token string, req BulkStatusRequest) (BulkStatusResult, error)

	// Create registers a new promotion using the provided configuration.
	Create(ctx context.Context, token string, input PromotionInput) (Promotion, error)

	// Update modifies an existing promotion.
	Update(ctx context.Context, token, promotionID string, input PromotionInput) (Promotion, error)
}

// Status represents the lifecycle state of a promotion.
type Status string

const (
	// StatusDraft indicates the promotion is being prepared.
	StatusDraft Status = "draft"
	// StatusScheduled indicates the promotion is scheduled for a future start date.
	StatusScheduled Status = "scheduled"
	// StatusActive indicates the promotion is currently active.
	StatusActive Status = "active"
	// StatusPaused indicates the promotion is temporarily paused.
	StatusPaused Status = "paused"
	// StatusExpired indicates the promotion has finished.
	StatusExpired Status = "expired"
)

// Type represents the discount or benefit style of a promotion.
type Type string

const (
	// TypePercentage applies a percentage discount.
	TypePercentage Type = "percentage"
	// TypeFixedAmount applies a fixed amount discount.
	TypeFixedAmount Type = "fixed_amount"
	// TypeBundle grants a bundle or BOGO style benefit.
	TypeBundle Type = "bundle"
	// TypeShipping applies free or discounted shipping.
	TypeShipping Type = "shipping"
)

// Channel identifies where a promotion can be redeemed.
type Channel string

const (
	// ChannelOnlineStore indicates the web storefront.
	ChannelOnlineStore Channel = "online_store"
	// ChannelRetail indicates the retail or physical stores.
	ChannelRetail Channel = "retail"
	// ChannelApp indicates the mobile app channel.
	ChannelApp Channel = "app"
)

// BulkAction enumerates supported mass actions.
type BulkAction string

const (
	// BulkActionActivate activates selected promotions.
	BulkActionActivate BulkAction = "activate"
	// BulkActionPause pauses selected promotions.
	BulkActionPause BulkAction = "pause"
	// BulkActionClone duplicates selected promotions for iteration.
	BulkActionClone BulkAction = "clone"
	// BulkActionDelete archives or deletes selected promotions.
	BulkActionDelete BulkAction = "delete"
)

// ListQuery captures available filters when listing promotions.
type ListQuery struct {
	Search        string
	Statuses      []Status
	Types         []Type
	Channels      []Channel
	CreatedBy     []string
	ScheduleStart *time.Time
	ScheduleEnd   *time.Time
	Page          int
	PageSize      int
	SortKey       string
	SortDirection string
}

// ListResult represents the list response from the promotions service.
type ListResult struct {
	Promotions []Promotion
	Pagination Pagination
	Summary    Summary
	Filters    FilterSummary
}

// Pagination includes page metadata.
type Pagination struct {
	Page       int
	PageSize   int
	TotalItems int
	NextPage   *int
	PrevPage   *int
}

// Summary includes quick metrics for the overview.
type Summary struct {
	ActiveCount       int
	PausedCount       int
	ScheduledCount    int
	ExpiredCount      int
	MonthlyUpliftRate float64
	AverageRedemption float64
}

// FilterSummary enriches filter controls with counts and labels.
type FilterSummary struct {
	StatusCounts   map[Status]int
	TypeCounts     map[Type]int
	ChannelCounts  map[Channel]int
	OwnerCounts    map[string]int
	ScheduleRanges []SchedulePreset
}

// SchedulePreset represents a saved date range shortcut.
type SchedulePreset struct {
	Key   string
	Label string
	Start *time.Time
	End   *time.Time
}

// Promotion is the core list row model.
type Promotion struct {
	ID                    string
	Code                  string
	Name                  string
	Description           string
	Status                Status
	StatusLabel           string
	StatusTone            string
	Type                  Type
	TypeLabel             string
	Channels              []Channel
	StartAt               *time.Time
	EndAt                 *time.Time
	UsageCount            int
	RedemptionCount       int
	LastModifiedAt        time.Time
	CreatedBy             string
	Segment               Segment
	Metrics               PromotionMetrics
	Version               string
	DiscountPercent       float64
	DiscountAmountMinor   int64
	DiscountCurrency      string
	BundleBuyQty          int
	BundleGetQty          int
	BundleDiscountPercent float64
	ShippingOption        string
	ShippingAmountMinor   int64
	ShippingCurrency      string
	EligibilityRules      []string
	MinOrderAmountMinor   int64
	UsageLimitTotal       int
	UsageLimitPerCustomer int
	BudgetMinor           int64
}

// PromotionMetrics exposes supplemental stats for the table tooltip or drawer.
type PromotionMetrics struct {
	AttributedRevenueMinor int64
	ConversionRate         float64
	RetentionLift          float64
}

// Segment summarises targeting information.
type Segment struct {
	Key         string
	Name        string
	Description string
	Preview     []string
	Audience    int
}

// PromotionDetail provides an expanded view for the drawer.
type PromotionDetail struct {
	Promotion   Promotion
	Targeting   []TargetingRule
	Benefits    []Benefit
	AuditLog    []AuditLogEntry
	LastEditor  string
	LastEdited  time.Time
	UsageSlices []UsageSlice
}

// PromotionInput captures the configuration submitted from the admin UI when creating or updating a promotion.
type PromotionInput struct {
	Name                  string
	Code                  string
	Description           string
	Status                Status
	Type                  Type
	Channels              []Channel
	SegmentKey            string
	EligibilityRules      []string
	DiscountPercent       float64
	DiscountAmountMinor   int64
	DiscountCurrency      string
	BundleBuyQty          int
	BundleGetQty          int
	BundleDiscountPercent float64
	ShippingOption        string
	ShippingAmountMinor   int64
	ShippingCurrency      string
	MinOrderAmountMinor   int64
	UsageLimitTotal       int
	UsageLimitPerCustomer int
	BudgetMinor           int64
	StartAt               time.Time
	EndAt                 *time.Time
	Version               string
}

// PromotionValidationError indicates validation issues for promotion create/update operations.
type PromotionValidationError struct {
	Message     string
	FieldErrors map[string]string
}

// Error implements error.
func (e *PromotionValidationError) Error() string {
	if e == nil {
		return "invalid promotion input"
	}
	msg := strings.TrimSpace(e.Message)
	if msg == "" {
		return "invalid promotion input"
	}
	return msg
}

// TargetingRule describes a single audience rule.
type TargetingRule struct {
	Label string
	Value string
	Icon  string
}

// Benefit outlines the benefit configuration.
type Benefit struct {
	Label       string
	Description string
	Icon        string
}

// AuditLogEntry summarises recent administrative actions.
type AuditLogEntry struct {
	Timestamp time.Time
	Actor     string
	Action    string
	Summary   string
}

// UsageSlice captures aggregated usage metrics.
type UsageSlice struct {
	Label string
	Value string
}

// BulkStatusRequest is the payload for bulk actions.
type BulkStatusRequest struct {
	Action       BulkAction
	PromotionIDs []string
	Reason       string
}

// BulkStatusResult summarises the outcome of a bulk action.
type BulkStatusResult struct {
	Action        BulkAction
	AffectedIDs   []string
	SkippedIDs    []string
	FailureReason string
}
