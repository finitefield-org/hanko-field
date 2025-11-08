package system

import "time"

// EnvironmentConfig summarises the active environment configuration, feature toggles, and integration states.
type EnvironmentConfig struct {
	Environment      string
	EnvironmentLabel string
	Region           string
	ReadOnly         bool
	Summary          string
	GeneratedAt      time.Time
	Metadata         map[string]string
	Categories       []EnvironmentConfigCategory
	Documents        []Link
	AuditTrail       []ConfigAuditEntry
}

// EnvironmentConfigCategory groups related configuration items for presentation.
type EnvironmentConfigCategory struct {
	ID          string
	Title       string
	Description string
	Items       []EnvironmentConfigItem
}

// EnvironmentConfigItem captures an individual configuration toggle or value.
type EnvironmentConfigItem struct {
	ID           string
	Label        string
	Description  string
	Value        string
	ValueHint    string
	StatusLabel  string
	StatusTone   string
	Tags         []string
	Docs         []Link
	Sensitive    bool
	Locked       bool
	LockedReason string
}

// ConfigAuditEntry records the most recent configuration tweaks for awareness.
type ConfigAuditEntry struct {
	ID         string
	ActorName  string
	ActorEmail string
	Action     string
	Summary    string
	Timestamp  time.Time
	Changes    []ConfigAuditChange
}

// ConfigAuditChange enumerates before/after pairs for an audit trail row.
type ConfigAuditChange struct {
	Field  string
	Before string
	After  string
}
