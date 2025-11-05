package payments

import (
	"context"
	"errors"
	"time"
)

// ErrNotConfigured indicates the payments service dependency was not supplied.
var ErrNotConfigured = errors.New("payments service not configured")

// ErrTransactionNotFound indicates the requested transaction could not be retrieved.
var ErrTransactionNotFound = errors.New("transaction not found")

// Service exposes PSP transaction operations required by the admin UI.
type Service interface {
	// ListTransactions returns a filtered collection of PSP transactions.
	ListTransactions(ctx context.Context, token string, query TransactionsQuery) (TransactionsResult, error)
	// TransactionDetail returns an enriched representation for the drawer.
	TransactionDetail(ctx context.Context, token, transactionID string) (TransactionDetail, error)
}

// Provider enumerates supported payment service providers.
type Provider string

const (
	// ProviderStripe indicates the Stripe PSP.
	ProviderStripe Provider = "stripe"
	// ProviderSquare indicates Square.
	ProviderSquare Provider = "square"
	// ProviderAirpay indicates GMO-Aozora AirPay.
	ProviderAirpay Provider = "airpay"
	// ProviderZeus indicates ZEUS Payment.
	ProviderZeus Provider = "zeus"
)

// Status captures the current lifecycle state of a transaction.
type Status string

const (
	// StatusAuthorized indicates the transaction has been authorised but not captured.
	StatusAuthorized Status = "authorized"
	// StatusCaptured indicates the transaction has been captured successfully.
	StatusCaptured Status = "captured"
	// StatusSettled indicates the transaction has been settled into a payout.
	StatusSettled Status = "settled"
	// StatusFailed indicates the transaction failed.
	StatusFailed Status = "failed"
	// StatusRefunded indicates the transaction has been refunded.
	StatusRefunded Status = "refunded"
	// StatusDisputed indicates the transaction is under dispute or chargeback.
	StatusDisputed Status = "disputed"
)

// TransactionsQuery represents listing filters.
type TransactionsQuery struct {
	Providers      []Provider
	Statuses       []Status
	CapturedFrom   *time.Time
	CapturedTo     *time.Time
	AmountMinMinor *int64
	AmountMaxMinor *int64
	OnlyFlagged    bool
	Page           int
	PageSize       int
	SortKey        string
	SortDirection  string
}

// TransactionsResult contains the list response.
type TransactionsResult struct {
	Transactions []Transaction
	Pagination   Pagination
	Summary      Summary
	Filters      FilterSummary
}

// Pagination contains page metadata.
type Pagination struct {
	Page       int
	PageSize   int
	TotalItems int
	NextPage   *int
	PrevPage   *int
}

// Summary powers the headline metrics.
type Summary struct {
	GrossVolumeMinor      int64
	GrossVolumeCurrency   string
	FailureRatePercent    float64
	FailureRateDelta      float64
	AverageTicketMinor    int64
	AverageTicketCurrency string
	FlaggedCount          int
	DisputeOpenCount      int
}

// FilterSummary enriches filter controls with counts.
type FilterSummary struct {
	ProviderCounts map[Provider]int
	StatusCounts   map[Status]int
	FlaggedCount   int
	AmountMinMinor int64
	AmountMaxMinor int64
	EarliestDate   *time.Time
	LatestDate     *time.Time
}

// Transaction represents a PSP transaction row.
type Transaction struct {
	ID                string
	PSPReference      string
	Provider          Provider
	ProviderLabel     string
	ProviderIcon      string
	Status            Status
	StatusLabel       string
	StatusTone        string
	OrderID           string
	OrderNumber       string
	CustomerName      string
	AmountMinor       int64
	Currency          string
	FeeMinor          int64
	NetMinor          int64
	CapturedAt        time.Time
	SettledAt         *time.Time
	RiskFlag          bool
	RiskLabel         string
	RiskTone          string
	PayoutBatchID     string
	PayoutScheduledAt *time.Time
	Installments      string
	PaymentMethod     string
	AuthID            string
	Channel           string
	OrderURL          string
	PSPDashboardURL   string
}

// TransactionDetail provides drawer data.
type TransactionDetail struct {
	Transaction Transaction
	Timeline    []TimelineEvent
	Breakdown   []BreakdownEntry
	Adjustments []Adjustment
	Disputes    []Dispute
	Notes       []Note
	RawPayload  []PayloadField
}

// TimelineEvent represents a chronological entry for the transaction lifecycle.
type TimelineEvent struct {
	Timestamp   time.Time
	Label       string
	Description string
	Tone        string
	Icon        string
}

// BreakdownEntry outlines the allocation of the transaction amount.
type BreakdownEntry struct {
	Label       string
	AmountMinor int64
	Currency    string
	Tone        string
}

// Adjustment represents manual adjustments (refunds, captured amounts).
type Adjustment struct {
	ID          string
	Type        string
	Label       string
	AmountMinor int64
	Currency    string
	Actor       string
	Reason      string
	Timestamp   time.Time
	StatusLabel string
	StatusTone  string
}

// Dispute captures dispute state for the transaction.
type Dispute struct {
	ID            string
	StatusLabel   string
	StatusTone    string
	AmountMinor   int64
	Currency      string
	ResponseDueAt *time.Time
	LastUpdatedAt time.Time
	MoreInfoURL   string
}

// Note captures reconciliation notes.
type Note struct {
	Author    string
	Message   string
	Timestamp time.Time
}

// PayloadField is a key/value entry for raw PSP payload display.
type PayloadField struct {
	Key   string
	Value string
}
