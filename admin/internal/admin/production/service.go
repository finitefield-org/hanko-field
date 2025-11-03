package production

import (
	"context"
	"errors"
	"time"
)

// Service exposes production queue data and workflows for the admin UI.
type Service interface {
	// Board returns the current state of the selected production queue with filters applied.
	Board(ctx context.Context, token string, query BoardQuery) (BoardResult, error)
	// AppendEvent appends a production workflow event for the specified order/card.
	AppendEvent(ctx context.Context, token, orderID string, req AppendEventRequest) (AppendEventResult, error)
	// WorkOrder returns a detailed production brief for the specified order.
	WorkOrder(ctx context.Context, token, orderID string) (WorkOrder, error)
	// QCOverview returns the QC worklist and associated metrics.
	QCOverview(ctx context.Context, token string, query QCQuery) (QCResult, error)
	// RecordQCDecision captures pass/fail outcomes for the specified QC item.
	RecordQCDecision(ctx context.Context, token, orderID string, req QCDecisionRequest) (QCDecisionResult, error)
	// TriggerRework routes a failed QC item back to the requested stage with metadata.
	TriggerRework(ctx context.Context, token, orderID string, req QCReworkRequest) (QCReworkResult, error)
	// QueueSettings returns production queue definitions for the settings page with applied filters.
	QueueSettings(ctx context.Context, token string, query QueueSettingsQuery) (QueueSettingsResult, error)
	// QueueSettingsDetail returns the detailed configuration for a specific queue definition.
	QueueSettingsDetail(ctx context.Context, token, queueID string) (QueueDefinition, error)
	// QueueSettingsOptions returns selectable metadata used to populate queue definition forms.
	QueueSettingsOptions(ctx context.Context, token string) (QueueSettingsOptions, error)
	// CreateQueueDefinition registers a new production queue definition.
	CreateQueueDefinition(ctx context.Context, token string, input QueueDefinitionInput) (QueueDefinition, error)
	// UpdateQueueDefinition updates an existing production queue definition.
	UpdateQueueDefinition(ctx context.Context, token, queueID string, input QueueDefinitionInput) (QueueDefinition, error)
	// DeleteQueueDefinition removes a production queue definition.
	DeleteQueueDefinition(ctx context.Context, token, queueID string) error
}

var (
	// ErrQueueNotFound indicates the requested queue does not exist.
	ErrQueueNotFound = errors.New("production queue not found")
	// ErrCardNotFound indicates the requested order/card is unknown.
	ErrCardNotFound = errors.New("production order not found")
	// ErrStageInvalid indicates the requested stage is unsupported.
	ErrStageInvalid = errors.New("production stage is invalid")
	// ErrWorkOrderNotFound indicates no work order data exists for the id.
	ErrWorkOrderNotFound = errors.New("work order not found")
	// ErrQCItemNotFound indicates the requested QC record does not exist.
	ErrQCItemNotFound = errors.New("qc item not found")
	// ErrQCInvalidAction indicates the requested QC transition is not allowed.
	ErrQCInvalidAction = errors.New("qc action invalid for current state")
	// ErrQueueNameExists indicates a queue with the same name already exists.
	ErrQueueNameExists = errors.New("queue name already exists")
	// ErrQueueInvalidInput indicates the provided queue input is invalid.
	ErrQueueInvalidInput = errors.New("queue definition input invalid")
)

// Stage represents a workflow step on the production board.
type Stage string

const (
	StageQueued    Stage = "queued"
	StageEngraving Stage = "engraving"
	StagePolishing Stage = "polishing"
	StageQC        Stage = "qc"
	StagePacked    Stage = "packed"
)

// Priority represents the urgency of a card.
type Priority string

const (
	PriorityNormal Priority = "normal"
	PriorityRush   Priority = "rush"
	PriorityHold   Priority = "hold"
)

// BoardQuery captures filters applied to the kanban board.
type BoardQuery struct {
	QueueID     string
	Priority    string
	ProductLine string
	Workstation string
	Selected    string
}

// BoardResult describes the production board snapshot rendered for the UI.
type BoardResult struct {
	Queue           Queue
	Queues          []QueueOption
	Summary         Summary
	Filters         FilterSummary
	Lanes           []Lane
	Drawer          Drawer
	SelectedCardID  string
	GeneratedAt     time.Time
	RefreshInterval time.Duration
}

// Queue provides metadata about a specific production queue/workshop.
type Queue struct {
	ID            string
	Name          string
	Description   string
	Location      string
	Shift         string
	Capacity      int
	Load          int
	Utilisation   float64
	LeadTimeHours int
	Notes         []string
}

// QueueOption powers the queue selector combobox.
type QueueOption struct {
	ID       string
	Label    string
	Sublabel string
	Load     string
	Active   bool
}

// Summary aggregates WIP metrics for the current filters.
type Summary struct {
	TotalWIP     int
	DueSoon      int
	Blocked      int
	AvgLeadHours int
	Utilisation  int
	UpdatedAt    time.Time
}

// FilterSummary enumerates available filter options per facet.
type FilterSummary struct {
	ProductLines []FilterOption
	Priorities   []FilterOption
	Workstations []FilterOption
}

// FilterOption represents a selectable filter chip/option.
type FilterOption struct {
	Value  string
	Label  string
	Count  int
	Active bool
}

// Lane represents a single stage column on the board.
type Lane struct {
	Stage       Stage
	Label       string
	Description string
	Capacity    LaneCapacity
	SLA         SLAMeta
	Cards       []Card
}

// LaneCapacity reports usage/limit stats for the column.
type LaneCapacity struct {
	Used  int
	Limit int
}

// SLAMeta reflects SLA/aging info per stage.
type SLAMeta struct {
	Label string
	Tone  string
}

// Card models a single order card on the board.
type Card struct {
	ID            string
	OrderNumber   string
	Stage         Stage
	Priority      Priority
	PriorityLabel string
	PriorityTone  string
	Customer      string
	ProductLine   string
	Design        string
	PreviewURL    string
	PreviewAlt    string
	QueueID       string
	QueueName     string
	Workstation   string
	Assignees     []Assignee
	Flags         []CardFlag
	DueAt         time.Time
	DueLabel      string
	DueTone       string
	Notes         []string
	Blocked       bool
	BlockedReason string
	AgingHours    int
	LastEvent     ProductionEvent
	Timeline      []ProductionEvent
}

// CardFlag highlights blockers/warnings on a card.
type CardFlag struct {
	Label string
	Tone  string
	Icon  string
}

// Assignee lists operators currently owning the card.
type Assignee struct {
	Name      string
	AvatarURL string
	Initials  string
	Role      string
}

// Drawer contains data for the detail inspector panel.
type Drawer struct {
	Empty    bool
	Card     DrawerCard
	Timeline []ProductionEvent
	Details  []DrawerDetail
}

// DrawerCard summarises the selected card inside the drawer.
type DrawerCard struct {
	ID            string
	OrderNumber   string
	Customer      string
	PriorityLabel string
	PriorityTone  string
	Stage         Stage
	StageLabel    string
	ProductLine   string
	QueueName     string
	Workstation   string
	PreviewURL    string
	PreviewAlt    string
	DueLabel      string
	Notes         []string
	Flags         []CardFlag
	Assignees     []Assignee
	LastUpdated   time.Time
}

// DrawerDetail renders supplemental metadata rows.
type DrawerDetail struct {
	Label string
	Value string
}

// QCStatus represents the current state of a QC inspection.
type QCStatus string

const (
	// QCStatusPending indicates the item awaits QC processing.
	QCStatusPending QCStatus = "pending"
	// QCStatusFailed indicates QC recorded a failure awaiting rework routing.
	QCStatusFailed QCStatus = "failed"
	// QCStatusComplete indicates the QC item has been cleared or routed out.
	QCStatusComplete QCStatus = "complete"
)

// QCDecisionOutcome enumerates QC decision types.
type QCDecisionOutcome string

const (
	// QCDecisionPass marks the inspection as passed.
	QCDecisionPass QCDecisionOutcome = "pass"
	// QCDecisionFail marks the inspection as failed.
	QCDecisionFail QCDecisionOutcome = "fail"
)

// QCQuery captures filters applied to the QC worklist.
type QCQuery struct {
	QueueID     string
	ProductLine string
	IssueType   string
	Assignee    string
	Status      string
	Selected    string
}

// QCResult describes the QC page payload rendered for the UI.
type QCResult struct {
	Queue       Queue
	Queues      []QueueOption
	Alert       string
	Summary     []QCSummary
	Performance []QCSummary
	Filters     QCFilters
	Items       []QCItem
	Drawer      QCInspector
	SelectedID  string
	GeneratedAt time.Time
}

// QCSummary models KPI chips rendered on the QC page.
type QCSummary struct {
	Label   string
	Value   string
	Delta   string
	Tone    string
	Icon    string
	SubText string
}

// QCFilters enumerates available filter facets on the QC page.
type QCFilters struct {
	ProductLines []FilterOption
	IssueTypes   []FilterOption
	Assignees    []FilterOption
	Statuses     []FilterOption
	Query        QCQuery
}

// QCItem models a QC worklist row.
type QCItem struct {
	ID            string
	OrderNumber   string
	Customer      string
	ProductLine   string
	ItemType      string
	Stage         Stage
	StageLabel    string
	StageTone     string
	Assigned      string
	Workstation   string
	PriorityLabel string
	PriorityTone  string
	SLA           string
	SLATone       string
	AgingLabel    string
	AgingTone     string
	Flags         []CardFlag
	IssueHint     string
	QueueID       string
	PreviewURL    string
	Status        QCStatus
	StatusLabel   string
	StatusTone    string
}

// QCInspector powers the action drawer for the QC page.
type QCInspector struct {
	Empty        bool
	Item         QCItemDetail
	Checklist    []QCChecklistItem
	Issues       []QCIssueRecord
	Attachments  []QCAttachment
	Reasons      []QCReason
	ReworkRoutes []QCReworkRoute
	Notes        []string
}

// QCItemDetail summarises the selected QC item.
type QCItemDetail struct {
	ID            string
	OrderNumber   string
	Customer      string
	ProductLine   string
	PriorityLabel string
	PriorityTone  string
	StageLabel    string
	StageTone     string
	Assigned      string
	DueLabel      string
	DueTone       string
	PreviewURL    string
}

// QCChecklistItem renders QC checklist rows.
type QCChecklistItem struct {
	ID          string
	Label       string
	Description string
	Required    bool
	Status      string
}

// QCIssueRecord tracks prior QC failures.
type QCIssueRecord struct {
	ID        string
	Category  string
	Summary   string
	Actor     string
	Tone      string
	CreatedAt time.Time
}

// QCAttachment lists reference assets for the QC drawer.
type QCAttachment struct {
	ID    string
	URL   string
	Label string
	Kind  string
}

// QCReason enumerates fail reasons selectable by QC operators.
type QCReason struct {
	Code     string
	Label    string
	Category string
}

// QCReworkRoute describes routing destinations for failed items.
type QCReworkRoute struct {
	ID          string
	Label       string
	Description string
	Stage       Stage
}

// QCDecisionRequest captures QC pass/fail submissions.
type QCDecisionRequest struct {
	Outcome     QCDecisionOutcome
	Note        string
	ReasonCode  string
	Attachments []string
}

// QCDecisionResult reports the outcome of a QC decision action.
type QCDecisionResult struct {
	Item    QCItem
	Message string
}

// QCReworkRequest captures rework routing submissions.
type QCReworkRequest struct {
	RouteID   string
	IssueCode string
	Note      string
}

// QCReworkResult reports the outcome of a rework action.
type QCReworkResult struct {
	Item    QCItem
	Message string
}

// WorkOrder aggregates the contextual data rendered in the work order view.
type WorkOrder struct {
	Card            Card
	ResponsibleTeam string
	CustomerNote    string
	Materials       []WorkOrderMaterial
	Assets          []WorkOrderAsset
	Instructions    []WorkInstruction
	Checklist       []WorkChecklistItem
	Safety          []WorkOrderNotice
	Activity        []ProductionEvent
	PDFURL          string
	LastPrintedAt   time.Time
}

// WorkOrderMaterial describes a required material/spec for the job.
type WorkOrderMaterial struct {
	Name     string
	Detail   string
	Quantity string
	Source   string
	Status   string
}

// WorkOrderAsset represents a downloadable design artifact.
type WorkOrderAsset struct {
	ID          string
	Name        string
	Kind        string
	PreviewURL  string
	DownloadURL string
	Size        string
	UpdatedAt   time.Time
	Description string
}

// WorkInstruction enumerates step-by-step guidance for operators.
type WorkInstruction struct {
	ID          string
	Title       string
	Description string
	Stage       Stage
	StageLabel  string
	Duration    string
	Tools       []string
}

// WorkChecklistItem powers actionable step buttons in the UI.
type WorkChecklistItem struct {
	ID          string
	Label       string
	Description string
	Stage       Stage
	StageLabel  string
	Completed   bool
	CompletedAt time.Time
}

// WorkOrderNotice renders inline safety/quality callouts.
type WorkOrderNotice struct {
	Title string
	Body  string
	Tone  string
	Icon  string
}

// ProductionEvent stores timeline events for a card.
type ProductionEvent struct {
	ID          string
	Stage       Stage
	StageLabel  string
	Type        string
	Description string
	Actor       string
	ActorAvatar string
	Station     string
	Tone        string
	OccurredAt  time.Time
	Note        string
}

// AppendEventRequest captures inputs when changing a card stage via DnD.
type AppendEventRequest struct {
	Stage    Stage
	Note     string
	Station  string
	ActorID  string
	ActorRef string
}

// AppendEventResult returns the persisted event and updated card snapshot.
type AppendEventResult struct {
	Event ProductionEvent
	Card  Card
}

// StageLabel returns a japanese-friendly label for the stage.
func StageLabel(stage Stage) string {
	switch stage {
	case StageQueued:
		return "待機"
	case StageEngraving:
		return "刻印"
	case StagePolishing:
		return "研磨"
	case StageQC:
		return "検品"
	case StagePacked:
		return "梱包"
	default:
		return string(stage)
	}
}

// QueueSettingsQuery captures filters for the production queue settings view.
type QueueSettingsQuery struct {
	Workshop    string
	Status      string
	ProductLine string
	Search      string
	SelectedID  string
}

// QueueSettingsResult represents the response payload used by the settings page.
type QueueSettingsResult struct {
	Queues    []QueueDefinition
	Filters   QueueSettingsFilters
	Summary   QueueSettingsSummary
	Analytics QueueAnalytics
}

// QueueSettingsFilters enumerates selectable filter options with counts.
type QueueSettingsFilters struct {
	Workshops    []QueueFilterOption
	Statuses     []QueueFilterOption
	ProductLines []QueueFilterOption
}

// QueueFilterOption describes a selectable filter option.
type QueueFilterOption struct {
	Value string
	Label string
	Count int
}

// QueueSettingsSummary aggregates headline metrics for the settings page.
type QueueSettingsSummary struct {
	TotalQueues     int
	ActiveQueues    int
	TotalCapacity   int
	AverageSLAHours float64
}

// QueueAnalytics captures capacity and flow analytics across filtered queues.
type QueueAnalytics struct {
	AverageThroughputPerShift float64
	AverageWIPUtilisation     float64
}

// QueueDefinition models the persisted configuration of a production queue.
type QueueDefinition struct {
	ID             string
	Name           string
	Description    string
	Workshop       string
	ProductLine    string
	Priority       int
	PriorityLabel  string
	Capacity       int
	TargetSLAHours int
	Active         bool
	Notes          []string
	Metrics        QueueDefinitionMetrics
	WorkCenters    []QueueWorkCenterAssignment
	Roles          []QueueRoleAssignment
	Stages         []QueueStage
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// QueueDefinitionMetrics summarises operational metrics for a queue.
type QueueDefinitionMetrics struct {
	ThroughputPerShift float64
	WIPUtilisation     float64
	SLACompliance      float64
}

// QueueStage describes a workflow stage within a queue definition.
type QueueStage struct {
	Code           Stage
	Label          string
	Sequence       int
	Description    string
	WIPLimit       int
	TargetSLAHours int
}

// QueueWorkCenter captures metadata about an assignable work center.
type QueueWorkCenter struct {
	ID         string
	Name       string
	Location   string
	Capability string
	Active     bool
}

// QueueWorkCenterAssignment associates a work center with a queue.
type QueueWorkCenterAssignment struct {
	WorkCenter QueueWorkCenter
	Primary    bool
}

// QueueRoleOption exposes selectable roles for staffing a queue.
type QueueRoleOption struct {
	Key                string
	Label              string
	SuggestedHeadcount int
}

// QueueRoleAssignment records the staffing levels for a role within the queue.
type QueueRoleAssignment struct {
	Key       string
	Label     string
	Headcount int
}

// QueueSettingsOptions provides selectable metadata for queue definition forms.
type QueueSettingsOptions struct {
	WorkCenters    []QueueWorkCenter
	RoleOptions    []QueueRoleOption
	StageTemplates []QueueStage
}

// QueueDefinitionInput captures the fields required to create or update a queue.
type QueueDefinitionInput struct {
	Name                string
	Description         string
	Workshop            string
	ProductLine         string
	Priority            int
	Capacity            int
	TargetSLAHours      int
	Active              bool
	Notes               []string
	WorkCenterIDs       []string
	PrimaryWorkCenterID string
	Roles               []QueueRoleAssignmentInput
	Stages              []QueueStageInput
}

// QueueRoleAssignmentInput captures staffing adjustments supplied by the UI.
type QueueRoleAssignmentInput struct {
	Key       string
	Headcount int
}

// QueueStageInput captures stage adjustments supplied by the UI.
type QueueStageInput struct {
	Code           Stage
	Label          string
	Description    string
	WIPLimit       int
	TargetSLAHours int
}
