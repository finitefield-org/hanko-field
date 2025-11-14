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

// ErrJobNotFound indicates the requested job could not be located.
var ErrJobNotFound = errors.New("job not found")

// ErrJobTriggerNotAllowed indicates a manual trigger cannot be performed for the job.
var ErrJobTriggerNotAllowed = errors.New("job manual trigger not supported")

// ErrCounterNotFound indicates the requested counter could not be located.
var ErrCounterNotFound = errors.New("counter not found")

// ErrFeedbackInvalid indicates the feedback payload failed validation.
var ErrFeedbackInvalid = errors.New("feedback submission invalid")

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
	// ListJobs returns scheduler jobs and their recent execution summaries.
	ListJobs(ctx context.Context, token string, query JobQuery) (JobResult, error)
	// JobDetail returns the full detail for a specific job identifier.
	JobDetail(ctx context.Context, token, jobID string) (JobDetail, error)
	// TriggerJob enqueues a manual execution for the specified job when supported.
	TriggerJob(ctx context.Context, token, jobID string, opts TriggerOptions) (TriggerOutcome, error)
	// ListCounters returns the configured counters and supporting metadata.
	ListCounters(ctx context.Context, token string, query CounterQuery) (CounterResult, error)
	// CounterDetail returns the timeline and related jobs for a counter.
	CounterDetail(ctx context.Context, token, name string, scope map[string]string) (CounterDetail, error)
	// NextCounter advances the counter and returns the resulting value.
	NextCounter(ctx context.Context, token, name string, opts CounterNextOptions) (CounterNextOutcome, error)
	// EnvironmentConfig returns a high-level summary of environment configuration and feature toggles.
	EnvironmentConfig(ctx context.Context, token string) (EnvironmentConfig, error)
	// SubmitFeedback captures a bug/feedback report from the admin UI and routes it to the underlying tracker.
	SubmitFeedback(ctx context.Context, token string, submission FeedbackSubmission) (FeedbackReceipt, error)
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

// FeedbackSubmission contains details provided by an administrator when reporting a bug.
type FeedbackSubmission struct {
	Subject       string
	Description   string
	Expectation   string
	CurrentURL    string
	Browser       string
	ConsoleLog    string
	Contact       string
	ReporterName  string
	ReporterEmail string
}

// FeedbackReceipt provides tracker metadata for a newly created feedback entry.
type FeedbackReceipt struct {
	ID           string
	ReferenceURL string
	SubmittedAt  time.Time
	Message      string
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

// JobType enumerates scheduler task categories.
type JobType string

const (
	// JobTypeScheduled represents cron or interval based jobs.
	JobTypeScheduled JobType = "scheduled"
	// JobTypeBatch represents heavy batch processing tasks.
	JobTypeBatch JobType = "batch"
	// JobTypeAdhoc represents manually triggered or ad-hoc tasks.
	JobTypeAdhoc JobType = "adhoc"
	// JobTypeEvent represents event driven or reactive tasks.
	JobTypeEvent JobType = "event"
)

// JobState captures the high-level health of a job.
type JobState string

const (
	// JobStateHealthy indicates the job is operating nominally.
	JobStateHealthy JobState = "healthy"
	// JobStateRunning indicates the job is currently executing.
	JobStateRunning JobState = "running"
	// JobStateDegraded indicates warnings or elevated retry counts.
	JobStateDegraded JobState = "degraded"
	// JobStateFailed indicates the most recent attempts failed or the job is halted.
	JobStateFailed JobState = "failed"
	// JobStatePaused indicates the job is disabled or paused.
	JobStatePaused JobState = "paused"
)

// JobRunStatus reflects the outcome of a job execution.
type JobRunStatus string

const (
	// JobRunSuccess indicates the run completed successfully.
	JobRunSuccess JobRunStatus = "success"
	// JobRunFailed indicates the run failed fatally.
	JobRunFailed JobRunStatus = "failed"
	// JobRunRunning indicates the run is in progress.
	JobRunRunning JobRunStatus = "running"
	// JobRunCancelled indicates the run was cancelled.
	JobRunCancelled JobRunStatus = "cancelled"
	// JobRunQueued indicates the run is waiting to start.
	JobRunQueued JobRunStatus = "queued"
)

// JobTrigger identifies the source of an execution request.
type JobTrigger string

const (
	// JobTriggerScheduler indicates the platform scheduler initiated the run.
	JobTriggerScheduler JobTrigger = "scheduler"
	// JobTriggerManual indicates a user manually triggered the run.
	JobTriggerManual JobTrigger = "manual"
	// JobTriggerRetry indicates the run is a retry of a prior failure.
	JobTriggerRetry JobTrigger = "retry"
	// JobTriggerDependency indicates the run was triggered by a dependency completion.
	JobTriggerDependency JobTrigger = "dependency"
)

// JobQuery captures filters applied in the tasks monitor.
type JobQuery struct {
	Types  []JobType
	States []JobState
	Hosts  []string
	Window string
	Search string
	Cursor string
	Limit  int
}

// JobResult provides the jobs listing response and metadata.
type JobResult struct {
	Jobs        []Job
	Total       int
	NextCursor  string
	Scheduler   SchedulerHealth
	Alerts      []JobAlert
	Filters     JobFilterSummary
	GeneratedAt time.Time
}

// SchedulerHealth summarises the scheduler heartbeat.
type SchedulerHealth struct {
	Status    JobState
	Label     string
	Message   string
	CheckedAt time.Time
	Latency   time.Duration
}

// JobFilterSummary enriches UI filter controls with counts.
type JobFilterSummary struct {
	TypeCounts  map[JobType]int
	StateCounts map[JobState]int
	HostCounts  map[string]int
	Windows     []JobWindowOption
}

// JobWindowOption represents an upcoming run window option.
type JobWindowOption struct {
	Value string
	Label string
	Count int
}

// JobAlert surfaces critical job level callouts.
type JobAlert struct {
	ID      string
	Tone    string
	Title   string
	Message string
	Action  JobAlertAction
}

// JobAlertAction represents a quick escalation control.
type JobAlertAction struct {
	Label  string
	URL    string
	Method string
	Icon   string
}

// Job represents a scheduler managed task.
type Job struct {
	ID                  string
	Name                string
	Description         string
	Type                JobType
	State               JobState
	Host                string
	Schedule            string
	Queue               string
	Tags                []string
	LastRun             JobRun
	NextRun             time.Time
	AverageDuration     time.Duration
	SuccessRate         float64
	ManualTrigger       bool
	RetryAvailable      bool
	LogsURL             string
	PrimaryRunbookURL   string
	CreatedAt           time.Time
	UpdatedAt           time.Time
	SLASeconds          int
	PendingExecutions   int
	RecoveredAt         *time.Time
	LastFailureMessage  string
	LastFailureOccurred *time.Time
}

// JobRun captures a single job execution.
type JobRun struct {
	ID          string
	Status      JobRunStatus
	StartedAt   time.Time
	CompletedAt *time.Time
	Duration    time.Duration
	TriggeredBy string
	Trigger     JobTrigger
	Attempt     int
	LogsURL     string
	Worker      string
	Region      string
	Error       string
}

// JobDetail provides the drawer payload for a job.
type JobDetail struct {
	Job           Job
	Parameters    map[string]string
	Environment   map[string]string
	RecentRuns    []JobRun
	History       []JobHistoryPoint
	Timeline      []JobTimelineEntry
	Insights      []JobInsight
	ManualActions []JobAction
}

// JobHistoryPoint powers the runtime history chart.
type JobHistoryPoint struct {
	RunID     string
	Status    JobRunStatus
	Duration  time.Duration
	Timestamp time.Time
}

// JobTimelineEntry renders notable events for the job.
type JobTimelineEntry struct {
	Title       string
	Description string
	OccurredAt  time.Time
	Actor       string
	Tone        string
	Icon        string
}

// JobInsight highlights key observations for the job.
type JobInsight struct {
	Title       string
	Description string
	Tone        string
	Icon        string
}

// JobAction represents a manual control exposed in the drawer.
type JobAction struct {
	Label     string
	URL       string
	Method    string
	Icon      string
	Confirm   string
	Dangerous bool
	Disabled  bool
	Tooltip   string
}

// TriggerOptions configures manual job execution.
type TriggerOptions struct {
	Actor  string
	Reason string
	DryRun bool
	Force  bool
}

// TriggerOutcome is returned upon manual job trigger submission.
type TriggerOutcome struct {
	Message      string
	RunID        string
	ScheduledFor time.Time
	Status       JobRunStatus
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
