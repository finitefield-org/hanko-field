package handlers

// LinkAction represents a user-facing action rendered as a button or link.
type LinkAction struct {
	Label       string
	Description string
	Href        string
	Kind        string // primary, secondary, link
	Icon        string
	External    bool
	Target      string
	Rel         string
}

// ErrorDiagnostic surfaces contextual debug information in an accordion/list UI.
type ErrorDiagnostic struct {
	Label string
	Value string
}

// ErrorPageData provides the view model for 4xx/5xx dedicated pages.
type ErrorPageData struct {
	PageData
	StatusCode   int
	ErrorCode    string
	Heading      string
	Message      string
	RetryAction  LinkAction
	SupportLinks []LinkAction
	Diagnostics  []ErrorDiagnostic
}

// OfflineCachedItem captures metadata for locally cached content.
type OfflineCachedItem struct {
	Title       string
	Description string
	Href        string
	Updated     string
	UpdatedISO  string
}

// OfflinePageData powers the offline-first landing page.
type OfflinePageData struct {
	PageData
	Heading       string
	Message       string
	RetryAction   LinkAction
	LastSynced    string
	LastSyncedISO string
	SupportLink   LinkAction
	CachedItems   []OfflineCachedItem
}

// MaintenanceCountdown exposes schedule details for planned downtime.
type MaintenanceCountdown struct {
	Heading        string
	Description    string
	ResumesAt      string
	ResumesAtISO   string
	CountdownLabel string
}

// MaintenanceNotifyForm models the subscription form for maintenance updates.
type MaintenanceNotifyForm struct {
	Action      string
	Method      string
	Placeholder string
	SubmitLabel string
	Disclaimer  string
	Success     bool
	Error       string
	Value       string
}

// MaintenancePageData represents the maintenance splash page.
type MaintenancePageData struct {
	PageData
	HeroHeading string
	HeroMessage string
	Countdown   MaintenanceCountdown
	StatusCTA   LinkAction
	Resources   []LinkAction
	NotifyForm  MaintenanceNotifyForm
}

// TelemetryConfig configures the telemetry beacon component.
type TelemetryConfig struct {
	Endpoint  string
	RequestID string
	Release   string
}
