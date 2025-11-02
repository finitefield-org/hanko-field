package customers

import (
	"context"
	"errors"
	"time"
)

// ErrNotConfigured indicates the customers service dependency has not been provided.
var ErrNotConfigured = errors.New("customers service not configured")

// Service exposes customer listing capabilities for the admin UI.
type Service interface {
	// List returns a filtered and paginated set of customers.
	List(ctx context.Context, token string, query ListQuery) (ListResult, error)
}

// Status represents the lifecycle state of a customer account.
type Status string

const (
	// StatusActive indicates the customer can sign in and place orders.
	StatusActive Status = "active"
	// StatusDeactivated indicates the customer account has been deactivated.
	StatusDeactivated Status = "deactivated"
	// StatusInvited indicates the customer has been invited but not activated yet.
	StatusInvited Status = "invited"
)

// SortDirection describes the requested sort ordering.
type SortDirection string

const (
	// SortDirectionAsc sorts ascending.
	SortDirectionAsc SortDirection = "asc"
	// SortDirectionDesc sorts descending.
	SortDirectionDesc SortDirection = "desc"
)

// ListQuery captures filters and pagination arguments for listing customers.
type ListQuery struct {
	Search        string
	Status        Status
	Tier          string
	Page          int
	PageSize      int
	SortKey       string
	SortDirection SortDirection
}

// ListResult represents a paginated customers response.
type ListResult struct {
	Customers   []Customer
	Pagination  Pagination
	Summary     Summary
	Filters     FilterSummary
	GeneratedAt time.Time
}

// Pagination captures paging metadata.
type Pagination struct {
	Page       int
	PageSize   int
	TotalItems int
	NextPage   *int
	PrevPage   *int
}

// Summary aggregates quick metrics for the current result set.
type Summary struct {
	TotalCustomers       int
	ActiveCustomers      int
	DeactivatedCustomers int
	HighValueCustomers   int
	AverageOrderValue    float64
	TotalLifetimeMinor   int64
	PrimaryCurrency      string
	Segments             []SegmentMetric
}

// SegmentMetric captures counts per segment or tier.
type SegmentMetric struct {
	Key         string
	Label       string
	Count       int
	Description string
}

// FilterSummary exposes supporting data used to render filter controls.
type FilterSummary struct {
	StatusOptions []StatusOption
	TierOptions   []TierOption
}

// StatusOption represents a selectable status filter item.
type StatusOption struct {
	Value Status
	Label string
	Count int
}

// TierOption represents a selectable tier filter item.
type TierOption struct {
	Value string
	Label string
	Count int
}

// Customer represents a single customer row in the index table.
type Customer struct {
	ID                 string
	DisplayName        string
	Email              string
	AvatarURL          string
	Company            string
	Location           string
	Tier               string
	Status             Status
	TotalOrders        int
	LifetimeValueMinor int64
	Currency           string
	LastOrderAt        time.Time
	LastOrderNumber    string
	LastOrderID        string
	LastInteraction    string
	RiskLevel          string
	Flags              []Flag
	Tags               []string
	JoinedAt           time.Time
}

// Flag represents a notable attribute or warning for a customer.
type Flag struct {
	Label       string
	Tone        string
	Icon        string
	Description string
}
