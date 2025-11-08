package system

import "time"

// CounterQuery captures filters applied when listing counters.
type CounterQuery struct {
	Namespace string
	Search    string
	Scope     string
	Cursor    string
	Limit     int
}

// CounterResult contains the listing response.
type CounterResult struct {
	Counters    []Counter
	Total       int
	NextCursor  string
	GeneratedAt time.Time
	Alerts      []CounterAlert
	Namespaces  []CounterNamespace
}

// CounterNamespace describes an available namespace filter option.
type CounterNamespace struct {
	ID       string
	Label    string
	Sublabel string
	Active   bool
}

// Counter represents a named sequence generator.
type Counter struct {
	Name         string
	Label        string
	Namespace    string
	Description  string
	ScopeKeys    []string
	ScopeExample map[string]string
	Increment    int64
	CurrentValue int64
	LastUpdated  time.Time
	Owner        string
	Tags         []string
	Alert        *CounterAlert
}

// CounterAlert renders warnings for counters nearing limits.
type CounterAlert struct {
	ID      string
	Tone    string
	Title   string
	Message string
	Action  Link
}

// CounterDetail enriches the drawer view for a specific counter.
type CounterDetail struct {
	Counter     Counter
	History     []CounterEvent
	RelatedJobs []CounterJob
	Notes       []string
}

// CounterEvent records a recent counter operation.
type CounterEvent struct {
	ID         string
	OccurredAt time.Time
	Actor      string
	ActorEmail string
	Scope      map[string]string
	Delta      int64
	Value      int64
	Message    string
	Source     string
	AuditID    string
}

// CounterJob links jobs associated with the counter.
type CounterJob struct {
	ID          string
	Name        string
	Description string
	URL         string
	StatusLabel string
	StatusTone  string
	LastRun     time.Time
}

// CounterNextOptions customises the next counter call.
type CounterNextOptions struct {
	Actor  string
	Scope  map[string]string
	Amount int64
	Reason string
}

// CounterNextOutcome summarises the result of incrementing a counter.
type CounterNextOutcome struct {
	Name       string
	Scope      map[string]string
	Value      int64
	Message    string
	AuditID    string
	OccurredAt time.Time
}
