package services

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
	"sync"
	"time"
)

const (
	exportTaskKindBigQuery = "export.bigquery"
)

// ExportJobPublisher publishes export jobs for asynchronous processing.
type ExportJobPublisher interface {
	PublishBigQueryExport(ctx context.Context, message BigQueryExportMessage) (string, error)
}

// BigQueryExportMessage represents the payload delivered to background workers.
type BigQueryExportMessage struct {
	TaskID         string     `json:"taskId"`
	ActorID        string     `json:"actorId"`
	Entities       []string   `json:"entities"`
	WindowFrom     *time.Time `json:"windowFrom,omitempty"`
	WindowTo       *time.Time `json:"windowTo,omitempty"`
	IdempotencyKey string     `json:"idempotencyKey,omitempty"`
	QueuedAt       time.Time  `json:"queuedAt"`
}

// ExportServiceDeps enumerates collaborators required to construct an ExportService.
type ExportServiceDeps struct {
	Publisher   ExportJobPublisher
	Clock       func() time.Time
	IDGenerator func() string
	Logger      func(ctx context.Context, event string, fields map[string]any)
}

type exportService struct {
	publisher ExportJobPublisher
	now       func() time.Time
	newID     func() string
	log       func(context.Context, string, map[string]any)

	mu          sync.Mutex
	idempotency map[string]SystemTask
	tasksByID   map[string]SystemTask
}

// NewExportService constructs an ExportService using the provided dependencies.
func NewExportService(deps ExportServiceDeps) (ExportService, error) {
	if deps.Publisher == nil {
		return nil, errors.New("export service: publisher is required")
	}

	clock := deps.Clock
	if clock == nil {
		clock = time.Now
	}
	idGen := deps.IDGenerator
	if idGen == nil {
		idGen = func() string {
			return fmt.Sprintf("task_%d", time.Now().UnixNano())
		}
	}
	logger := deps.Logger
	if logger == nil {
		logger = func(context.Context, string, map[string]any) {}
	}

	return &exportService{
		publisher: deps.Publisher,
		now: func() time.Time {
			return clock().UTC()
		},
		newID:       idGen,
		log:         logger,
		idempotency: make(map[string]SystemTask),
		tasksByID:   make(map[string]SystemTask),
	}, nil
}

func (s *exportService) StartBigQuerySync(ctx context.Context, cmd BigQueryExportCommand) (SystemTask, error) {
	if ctx == nil {
		return SystemTask{}, fmt.Errorf("%w: context is required", ErrExportInvalidInput)
	}

	actorID := strings.TrimSpace(cmd.ActorID)
	if actorID == "" {
		return SystemTask{}, fmt.Errorf("%w: actor id is required", ErrExportInvalidInput)
	}

	if len(cmd.Entities) == 0 {
		return SystemTask{}, fmt.Errorf("%w: at least one entity is required", ErrExportInvalidInput)
	}

	window := cmd.Window
	if window != nil && window.From != nil && window.To != nil && window.From.After(*window.To) {
		return SystemTask{}, fmt.Errorf("%w: window from must be before to", ErrExportInvalidInput)
	}

	now := s.now()
	idempotencyKey := strings.TrimSpace(cmd.IdempotencyKey)

	s.mu.Lock()
	if key := idempotencyKey; key != "" {
		if existing, ok := s.idempotency[key]; ok {
			result := cloneSystemTask(existing)
			s.mu.Unlock()
			return result, nil
		}
	}
	taskID := ensureTaskID(s.newID())
	task := SystemTask{
		ID:             taskID,
		Kind:           exportTaskKindBigQuery,
		Status:         SystemTaskStatusPending,
		RequestedBy:    actorID,
		IdempotencyKey: idempotencyKey,
		Parameters:     map[string]any{},
		Metadata:       map[string]any{},
		CreatedAt:      now,
		UpdatedAt:      now,
	}
	task.Parameters["entities"] = append([]string(nil), cmd.Entities...)
	if window != nil {
		if window.From != nil {
			task.Parameters["windowFrom"] = window.From.UTC().Format(time.RFC3339Nano)
		}
		if window.To != nil {
			task.Parameters["windowTo"] = window.To.UTC().Format(time.RFC3339Nano)
		}
	}
	s.mu.Unlock()

	message := BigQueryExportMessage{
		TaskID:         task.ID,
		ActorID:        task.RequestedBy,
		Entities:       append([]string(nil), cmd.Entities...),
		IdempotencyKey: idempotencyKey,
		QueuedAt:       now,
	}
	if window != nil {
		message.WindowFrom = cloneTimePointer(window.From)
		message.WindowTo = cloneTimePointer(window.To)
	}

	if _, err := s.publisher.PublishBigQueryExport(ctx, message); err != nil {
		return SystemTask{}, fmt.Errorf("publish bigquery export: %w", err)
	}

	s.mu.Lock()
	taskCopy := cloneSystemTask(task)
	if idempotencyKey != "" {
		s.idempotency[idempotencyKey] = taskCopy
	}
	s.tasksByID[taskCopy.ID] = taskCopy
	s.mu.Unlock()

	s.log(ctx, "export.bigquery.enqueued", map[string]any{
		"taskId":   taskCopy.ID,
		"actorId":  taskCopy.RequestedBy,
		"entities": strings.Join(cmd.Entities, ","),
	})

	return taskCopy, nil
}

func ensureTaskID(id string) string {
	id = strings.TrimSpace(id)
	if id != "" {
		return id
	}
	return fmt.Sprintf("task_%d", time.Now().UnixNano())
}

func cloneSystemTask(task SystemTask) SystemTask {
	copyTask := task
	if len(task.Parameters) > 0 {
		copyTask.Parameters = make(map[string]any, len(task.Parameters))
		for k, v := range task.Parameters {
			copyTask.Parameters[k] = v
		}
	}
	if len(task.Metadata) > 0 {
		copyTask.Metadata = make(map[string]any, len(task.Metadata))
		for k, v := range task.Metadata {
			copyTask.Metadata[k] = v
		}
	}
	if task.ResultRef != nil {
		value := *task.ResultRef
		copyTask.ResultRef = &value
	}
	if task.ErrorMessage != nil {
		value := *task.ErrorMessage
		copyTask.ErrorMessage = &value
	}
	if task.StartedAt != nil {
		copyTask.StartedAt = cloneTimePointer(task.StartedAt)
	}
	if task.CompletedAt != nil {
		copyTask.CompletedAt = cloneTimePointer(task.CompletedAt)
	}
	return copyTask
}

func cloneTimePointer(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	value := t.UTC()
	return &value
}

// NoopExportPublisher is an ExportJobPublisher that records the last message but does not deliver it externally.
type NoopExportPublisher struct {
	mu       sync.Mutex
	messages []BigQueryExportMessage
}

// NewNoopExportPublisher constructs an in-memory publisher useful for local development environments.
func NewNoopExportPublisher() *NoopExportPublisher {
	return &NoopExportPublisher{}
}

// PublishBigQueryExport records the message and returns a synthetic message ID.
func (p *NoopExportPublisher) PublishBigQueryExport(_ context.Context, message BigQueryExportMessage) (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.messages = append(p.messages, message)
	return fmt.Sprintf("noop-%d", len(p.messages)), nil
}

// Messages returns a snapshot of published messages.
func (p *NoopExportPublisher) Messages() []BigQueryExportMessage {
	p.mu.Lock()
	defer p.mu.Unlock()
	return slices.Clone(p.messages)
}
