package domain

import "time"

// ProductionQueue represents a configurable production work queue used by operations staff.
type ProductionQueue struct {
	ID          string
	Name        string
	Capacity    int
	WorkCenters []string
	Priority    string
	Status      string
	Notes       string
	Metadata    map[string]any
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// ProductionQueueWIPSummary captures aggregated workload metrics for a production queue.
type ProductionQueueWIPSummary struct {
	QueueID        string
	StatusCounts   map[string]int
	Total          int
	AverageAge     time.Duration
	OldestAge      time.Duration
	SLABreachCount int
	GeneratedAt    time.Time
}

// ProductionQueue status values.
const (
	ProductionQueueStatusActive   = "active"
	ProductionQueueStatusPaused   = "paused"
	ProductionQueueStatusArchived = "archived"
)

// ProductionQueue priority values.
const (
	ProductionQueuePriorityNormal = "normal"
	ProductionQueuePriorityRush   = "rush"
)
