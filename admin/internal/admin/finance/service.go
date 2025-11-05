package finance

import (
	"context"
	"errors"
	"time"
)

var (
	// ErrJurisdictionNotFound indicates the requested jurisdiction does not exist.
	ErrJurisdictionNotFound = errors.New("tax jurisdiction not found")
	// ErrTaxRuleNotFound indicates the requested tax rule does not exist.
	ErrTaxRuleNotFound = errors.New("tax rule not found")
	// ErrTaxRuleOverlap indicates the requested effective range overlaps an existing rule.
	ErrTaxRuleOverlap = errors.New("tax rule effective range overlaps existing rule")
	// ErrTaxRuleInvalid indicates the provided input cannot be accepted.
	ErrTaxRuleInvalid = errors.New("tax rule input invalid")
)

// Service models the finance tax configuration capabilities required by the admin UI.
type Service interface {
	// Jurisdictions returns grouped navigation metadata and jurisdiction summaries applying the provided filters.
	Jurisdictions(ctx context.Context, token string, query JurisdictionsQuery) (JurisdictionsResult, error)
	// JurisdictionDetail returns the full set of rules, registrations, and history for the specified jurisdiction.
	JurisdictionDetail(ctx context.Context, token, jurisdictionID string) (JurisdictionDetail, error)
	// UpsertTaxRule creates or updates a tax rule for the jurisdiction and returns the refreshed detail payload.
	UpsertTaxRule(ctx context.Context, token, jurisdictionID string, input TaxRuleInput) (JurisdictionDetail, error)
	// DeleteTaxRule removes the specified tax rule and returns the refreshed detail payload.
	DeleteTaxRule(ctx context.Context, token, jurisdictionID, ruleID string) (JurisdictionDetail, error)
	// ReconciliationDashboard returns the reconciliation exports overview, report metadata, and background job statuses.
	ReconciliationDashboard(ctx context.Context, token string) (ReconciliationDashboard, error)
	// TriggerReconciliation enqueues a reconciliation job run and returns the refreshed dashboard payload.
	TriggerReconciliation(ctx context.Context, token string) (ReconciliationDashboard, error)
}

// JurisdictionsQuery captures filters applied to the jurisdictions listing.
type JurisdictionsQuery struct {
	Region      string
	Country     string
	Search      string
	OnlyActive  bool
	SelectedID  string
	IncludeSoon bool
}

// JurisdictionsResult aggregates the data required to render the jurisdictions list and navigation.
type JurisdictionsResult struct {
	Regions       []RegionGroup
	Jurisdictions []JurisdictionSummary
	Summary       JurisdictionSummaryStats
	Alerts        []Alert
	PolicyLinks   []PolicyLink
}

// RegionGroup contains the region navigation entries.
type RegionGroup struct {
	ID        string
	Label     string
	Count     int
	Countries []CountryNav
}

// CountryNav represents a single jurisdiction entry in the navigation list.
type CountryNav struct {
	ID              string
	Label           string
	Region          string
	Code            string
	Active          bool
	PendingChanges  bool
	JurisdictionID  string
	RegistrationTag string
	Selected        bool
}

// JurisdictionSummaryStats summarises the active configuration footprint.
type JurisdictionSummaryStats struct {
	ActiveJurisdictions   int
	PendingJurisdictions  int
	ExpiredJurisdictions  int
	RegistrationsRequired int
	LastSyncedAt          time.Time
}

// JurisdictionSummary provides the table row data for a jurisdiction.
type JurisdictionSummary struct {
	ID                string
	Country           string
	Region            string
	Code              string
	DefaultRate       float64
	ReducedRate       *float64
	ThresholdMinor    int64
	ThresholdCurrency string
	EffectiveFrom     time.Time
	EffectiveTo       *time.Time
	HasPendingRule    bool
	Status            string
	StatusTone        string
	LastUpdatedAt     time.Time
	LastUpdatedBy     string
	RegistrationID    string
	RegistrationName  string
	Notes             []string
}

// Alert models inline validation warnings or notices.
type Alert struct {
	Tone   string
	Title  string
	Body   string
	Action *AlertAction
}

// AlertAction links to contextual remediation from an alert.
type AlertAction struct {
	Label string
	Href  string
}

// PolicyLink exposes quick links to authoritative tax resources.
type PolicyLink struct {
	Label string
	Href  string
}

// ReconciliationDashboard aggregates reconciliation status, report metadata, and supporting artefacts for the UI.
type ReconciliationDashboard struct {
	Summary ReconciliationSummary
	Reports []ReconciliationReport
	Jobs    []ReconciliationJob
	History []AuditEvent
	Alerts  []Alert
}

// ReconciliationSummary captures headline reconciliation metrics.
type ReconciliationSummary struct {
	LastRunAt             time.Time
	LastRunBy             string
	LastRunStatus         string
	LastRunStatusTone     string
	LastRunDuration       time.Duration
	PendingExceptions     int
	PendingAmountMinor    int64
	PendingAmountCurrency string
	NextScheduledAt       *time.Time
	TriggerDisabled       bool
	TriggerDisabledReason string
}

// ReconciliationReport exposes downloadable reconciliation artefacts.
type ReconciliationReport struct {
	ID              string
	Label           string
	Description     string
	Format          string
	Status          string
	StatusTone      string
	LastGeneratedAt time.Time
	LastGeneratedBy string
	DownloadURL     string
	FileSizeBytes   int64
	ExpiresAt       *time.Time
	BackgroundJobID string
}

// ReconciliationJob summarises scheduled background jobs generating reconciliation artefacts.
type ReconciliationJob struct {
	ID              string
	Label           string
	Schedule        string
	Status          string
	StatusTone      string
	LastRunAt       time.Time
	LastRunDuration time.Duration
	NextRunAt       *time.Time
	LastError       string
}

// JurisdictionDetail aggregates the rule set, registrations, and audit history for display.
type JurisdictionDetail struct {
	Metadata      JurisdictionMetadata
	Rules         []TaxRule
	Registrations []TaxRegistration
	Alerts        []Alert
	History       []AuditEvent
}

// JurisdictionMetadata summarises the jurisdiction header content.
type JurisdictionMetadata struct {
	ID             string
	Country        string
	Region         string
	Code           string
	Currency       string
	DefaultRate    float64
	ReducedRate    *float64
	UpdatedAt      time.Time
	UpdatedBy      string
	RegistrationID string
	Notes          []string
}

// TaxRule describes the stored configuration for a tax rule.
type TaxRule struct {
	ID                   string
	Label                string
	Scope                string
	ScopeLabel           string
	Type                 string
	RatePercent          float64
	ThresholdMinor       int64
	ThresholdCurrency    string
	EffectiveFrom        time.Time
	EffectiveTo          *time.Time
	RegistrationNumber   string
	RegistrationLabel    string
	RequiresRegistration bool
	Default              bool
	Status               string
	StatusTone           string
	Notes                []string
	UpdatedAt            time.Time
	UpdatedBy            string
}

// TaxRegistration lists registered tax IDs associated with the jurisdiction.
type TaxRegistration struct {
	ID         string
	Label      string
	Number     string
	IssuedAt   time.Time
	ExpiresAt  *time.Time
	Status     string
	StatusTone string
}

// AuditEvent traces configuration changes for the jurisdiction.
type AuditEvent struct {
	ID        string
	Timestamp time.Time
	Actor     string
	Action    string
	Details   string
	Tone      string
}

// TaxRuleInput captures user-provided values for rule creation or updates.
type TaxRuleInput struct {
	RuleID               string
	Label                string
	Scope                string
	Type                 string
	RatePercent          float64
	ThresholdMinor       int64
	ThresholdCurrency    string
	EffectiveFrom        time.Time
	EffectiveTo          *time.Time
	RegistrationNumber   string
	RequiresRegistration bool
	Default              bool
	Notes                []string
}

// TaxRuleValidationError represents validation issues for rule submissions.
type TaxRuleValidationError struct {
	FieldErrors map[string]string
	Message     string
}

// Error implements the error interface.
func (e *TaxRuleValidationError) Error() string {
	if e == nil {
		return ""
	}
	msg := e.Message
	if msg == "" {
		msg = "tax rule validation failed"
	}
	return msg
}
