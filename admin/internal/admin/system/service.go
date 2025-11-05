package system

import (
	"context"
	"errors"
	"time"
)

// ErrNotConfigured indicates the system service dependency has not been provided.
var ErrNotConfigured = errors.New("system service not configured")

// ErrFailureNotFound indicates the requested failure could not be located.
var ErrFailureNotFound = errors.New("failure not found")

// Service exposes operations for the system errors dashboard.
type Service interface {
	// ListFailures returns a filtered collection of recent failures along with dashboard metrics.
	ListFailures(ctx context.Context, token string, query FailureQuery) (FailureResult, error)
	// FailureDetail returns the enriched detail view for a specific failure identifier.
	FailureDetail(ctx context.Context, token, failureID string) (FailureDetail, error)
	// RetryFailure attempts to enqueue a retry for the failure when supported.
	RetryFailure(ctx context.Context, token, failureID string, opts RetryOptions) (RetryOutcome, error)
	// AcknowledgeFailure marks the failure as acknowledged, suppressing repeated alerts.
	AcknowledgeFailure(ctx context.Context, token, failureID string, opts AcknowledgeOptions) (AcknowledgeOutcome, error)
}

// Source enumerates failure origins.
type Source string

const (
	// SourceJob represents scheduled or background tasks.
	SourceJob Source = "job"
	// SourceWebhook represents inbound webhook deliveries.
	SourceWebhook Source = "webhook"
	// SourceAPI represents public API requests.
	SourceAPI Source = "api"
	// SourceWorker represents async worker processes.
	SourceWorker Source = "worker"
)

// Severity classifies failure criticality.
type Severity string

const (
	// SeverityCritical indicates immediate remediation is required.
	SeverityCritical Severity = "critical"
	// SeverityHigh indicates elevated urgency.
	SeverityHigh Severity = "high"
	// SeverityMedium indicates follow-up is required but non-blocking.
	SeverityMedium Severity = "medium"
	// SeverityLow indicates informational failures.
	SeverityLow Severity = "low"
)

// Status represents lifecycle state of a failure record.
type Status string

const (
	// StatusOpen indicates the failure is unacknowledged and awaiting action.
	StatusOpen Status = "open"
	// StatusAcknowledged indicates the failure has been triaged but not yet resolved.
	StatusAcknowledged Status = "acknowledged"
	// StatusResolved indicates the underlying issue has been remediated.
	StatusResolved Status = "resolved"
	// StatusSuppressed indicates the failure has been silenced temporarily.
	StatusSuppressed Status = "suppressed"
)

// FailureQuery captures filters applied by the dashboard.
type FailureQuery struct {
	Sources    []Source
	Severities []Severity
	Services   []string
	Statuses   []Status
	Search     string
	Start      *time.Time
	End        *time.Time
	Cursor     string
	Limit      int
}

// FailureResult contains the listing response and supporting metadata.
type FailureResult struct {
	Failures    []Failure
	Total       int
	NextCursor  string
	Metrics     MetricsSummary
	Filters     FilterSummary
	GeneratedAt time.Time
}

// MetricsSummary powers the headline KPI cards.
type MetricsSummary struct {
	TotalFailures      int
	RetrySuccessRate   float64
	RetrySuccessDelta  float64
	QueueBacklog       int
	ActiveIncidents    int
	RetrySuccessSample int
}

// FilterSummary enriches filter controls with counts.
type FilterSummary struct {
	SourceCounts   map[Source]int
	SeverityCounts map[Severity]int
	ServiceCounts  map[string]int
	StatusCounts   map[Status]int
}

// Failure is the core record displayed in the table.
type Failure struct {
	ID             string
	Source         Source
	Service        string
	Name           string
	Severity       Severity
	Status         Status
	Message        string
	Code           string
	FirstSeen      time.Time
	LastSeen       time.Time
	RetryCount     int
	MaxRetries     int
	Recoverable    bool
	RetryAvailable bool
	AckAvailable   bool
	Links          []Link
	Target         TargetRef
	RunbookURL     string
	LastPayload    string
	Attributes     map[string]string
}

// TargetRef links to the impacted resource.
type TargetRef struct {
	Kind  string
	Label string
	ID    string
	URL   string
}

// Link represents a contextual shortcut.
type Link struct {
	Label string
	URL   string
	Icon  string
}

// FailureDetail provides the drawer payload.
type FailureDetail struct {
	Failure        Failure
	StackTrace     []string
	Payload        map[string]any
	Headers        map[string]string
	LastAttempt    time.Time
	NextRetryAt    *time.Time
	RecentAttempts []Attempt
	RunbookSteps   []RunbookStep
}

// Attempt summarises a retry attempt.
type Attempt struct {
	Number     int
	OccurredAt time.Time
	Status     string
	Response   string
	Duration   time.Duration
}

// RunbookStep describes an operational mitigation instruction.
type RunbookStep struct {
	Title       string
	Description string
	Links       []Link
}

// RetryOptions configures retry requests.
type RetryOptions struct {
	Reason string
	Actor  string
}

// RetryOutcome returns contextual messaging following a retry request.
type RetryOutcome struct {
	Queued     bool
	Message    string
	NextRunAt  *time.Time
	RetryCount int
	Status     Status
}

// AcknowledgeOptions configures acknowledgement updates.
type AcknowledgeOptions struct {
	Actor  string
	Reason string
}

// AcknowledgeOutcome summarises state after acknowledgement.
type AcknowledgeOutcome struct {
	Acknowledged bool
	Message      string
	Status       Status
}
