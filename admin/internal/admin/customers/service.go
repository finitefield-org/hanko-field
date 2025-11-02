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

	// Detail loads full profile data for a single customer.
	Detail(ctx context.Context, token, customerID string) (Detail, error)

	// DeactivateModal retrieves contextual information required to render the deactivate + mask modal.
	DeactivateModal(ctx context.Context, token, customerID string) (DeactivateModal, error)

	// DeactivateAndMask performs the irreversible deactivate + mask operation and returns the updated profile context.
	DeactivateAndMask(ctx context.Context, token, customerID string, req DeactivateAndMaskRequest) (DeactivateAndMaskResult, error)
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

// ErrCustomerNotFound indicates the requested customer doesn't exist.
var ErrCustomerNotFound = errors.New("customer not found")

// ErrInvalidConfirmation indicates the provided confirmation phrase is incorrect.
var ErrInvalidConfirmation = errors.New("invalid confirmation phrase")

// ErrAlreadyDeactivated is returned when trying to deactivate an already deactivated customer.
var ErrAlreadyDeactivated = errors.New("customer already deactivated")

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

// Detail encapsulates the data needed to render a customer profile view.
type Detail struct {
	Profile        Profile
	Metrics        []Metric
	RecentOrders   []OrderSummary
	Addresses      []Address
	PaymentMethods []PaymentMethod
	SupportNotes   []SupportNote
	Activity       []ActivityItem
	InfoRail       InfoRail
	LastUpdated    time.Time
}

// Profile summarises the primary customer information.
type Profile struct {
	ID                 string
	DisplayName        string
	Email              string
	Phone              string
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
	JoinedAt           time.Time
	RiskLevel          string
	Flags              []Flag
	Tags               []string
	QuickActions       []QuickAction
}

// QuickAction renders shortcut buttons in the profile header.
type QuickAction struct {
	Label   string
	Href    string
	Variant string
	Icon    string
	Method  string
}

// Metric renders summary KPI cards.
type Metric struct {
	Key       string
	Label     string
	Value     string
	SubLabel  string
	Tone      string
	Trend     Trend
	Indicator string
}

// Trend describes directional change for a metric.
type Trend struct {
	Label string
	Tone  string
	Icon  string
}

// OrderSummary renders rows in the orders tab.
type OrderSummary struct {
	ID                string
	Number            string
	PlacedAt          time.Time
	Status            string
	StatusTone        string
	FulfillmentStatus string
	FulfillmentTone   string
	PaymentStatus     string
	PaymentTone       string
	TotalMinor        int64
	Currency          string
	ItemSummary       string
	DeliveryTarget    string
	LastUpdated       time.Time
}

// Address represents a saved customer address.
type Address struct {
	ID         string
	Label      string
	Name       string
	Company    string
	Phone      string
	Lines      []string
	City       string
	Prefecture string
	PostalCode string
	Country    string
	Type       string
	Primary    bool
	UpdatedAt  time.Time
	Notes      []string
}

// PaymentMethod represents a stored payment credential.
type PaymentMethod struct {
	ID         string
	Type       string
	Brand      string
	Last4      string
	ExpMonth   int
	ExpYear    int
	HolderName string
	Status     string
	StatusTone string
	Primary    bool
	AddedAt    time.Time
}

// SupportNote captures support interactions or notes.
type SupportNote struct {
	ID         string
	Title      string
	Body       string
	CreatedAt  time.Time
	Author     string
	AuthorRole string
	Tone       string
	Visibility string
	Tags       []string
}

// ActivityItem renders timeline events in the activity tab.
type ActivityItem struct {
	ID          string
	Timestamp   time.Time
	Actor       string
	ActorRole   string
	Title       string
	Description string
	Tone        string
	Icon        string
}

// InfoRail summarises contextual panels shown in the right-hand column.
type InfoRail struct {
	RiskLevel       string
	RiskTone        string
	RiskDescription string
	Segments        []string
	Flags           []Flag
	Escalations     []RailItem
	FraudChecks     []RailItem
	IdentityDocs    []RailItem
	Contacts        []RailItem
}

// RailItem renders an item inside the info rail sections.
type RailItem struct {
	ID          string
	Label       string
	Description string
	Tone        string
	Timestamp   time.Time
	LinkLabel   string
	LinkURL     string
}

// DeactivateModal provides the data needed to render the deactivate + mask confirmation modal.
type DeactivateModal struct {
	CustomerID         string
	DisplayName        string
	Email              string
	Status             Status
	TotalOrders        int
	LifetimeValueMinor int64
	Currency           string
	LastOrderNumber    string
	LastOrderAt        time.Time
	ConfirmationPhrase string
	Impacts            []DeactivateImpact
}

// DeactivateImpact summarises a single consequence of the deactivate + mask action.
type DeactivateImpact struct {
	Title       string
	Description string
	Icon        string
	Tone        string
}

// DeactivateAndMaskRequest captures input required to process a deactivate + mask operation.
type DeactivateAndMaskRequest struct {
	Reason        string
	Confirmation  string
	ActorID       string
	ActorEmail    string
	RequestedAt   time.Time
	CorrelationID string
}

// DeactivateAndMaskResult returns the updated customer detail context together with audit metadata.
type DeactivateAndMaskResult struct {
	Detail Detail
	Audit  AuditRecord
}

// AuditRecord references the audit log entry emitted after a destructive operation.
type AuditRecord struct {
	ID         string
	Action     string
	Message    string
	Timestamp  time.Time
	ActorID    string
	ActorEmail string
	Metadata   map[string]string
}
