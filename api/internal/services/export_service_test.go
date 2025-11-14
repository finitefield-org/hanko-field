package services

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestExportService_StartBigQuerySyncValidatesInput(t *testing.T) {
	publisher := &stubExportPublisher{}
	service, err := NewExportService(ExportServiceDeps{
		Publisher:   publisher,
		Clock:       func() time.Time { return time.Now().UTC() },
		IDGenerator: func() string { return "task-1" },
	})
	if err != nil {
		t.Fatalf("NewExportService: %v", err)
	}

	_, err = service.StartBigQuerySync(nil, BigQueryExportCommand{})
	if !errors.Is(err, ErrExportInvalidInput) {
		t.Fatalf("expected ErrExportInvalidInput for nil context, got %v", err)
	}

	_, err = service.StartBigQuerySync(context.Background(), BigQueryExportCommand{})
	if !errors.Is(err, ErrExportInvalidInput) {
		t.Fatalf("expected ErrExportInvalidInput for missing actor, got %v", err)
	}

	_, err = service.StartBigQuerySync(context.Background(), BigQueryExportCommand{
		ActorID: "admin",
	})
	if !errors.Is(err, ErrExportInvalidInput) {
		t.Fatalf("expected ErrExportInvalidInput for missing entities, got %v", err)
	}

	windowFrom := time.Date(2024, 1, 2, 0, 0, 0, 0, time.UTC)
	windowTo := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	_, err = service.StartBigQuerySync(context.Background(), BigQueryExportCommand{
		ActorID:  "admin",
		Entities: []string{"orders"},
		Window: &ExportTimeWindow{
			From: &windowFrom,
			To:   &windowTo,
		},
	})
	if !errors.Is(err, ErrExportInvalidInput) {
		t.Fatalf("expected ErrExportInvalidInput for invalid window, got %v", err)
	}
}

func TestExportService_StartBigQuerySyncPublishesJob(t *testing.T) {
	now := time.Date(2024, 7, 11, 9, 30, 0, 0, time.UTC)
	publisher := &stubExportPublisher{}
	service, err := NewExportService(ExportServiceDeps{
		Publisher: publisher,
		Clock: func() time.Time {
			return now
		},
		IDGenerator: func() string {
			return "task-123"
		},
	})
	if err != nil {
		t.Fatalf("NewExportService: %v", err)
	}

	from := now.Add(-24 * time.Hour)
	to := now

	task, err := service.StartBigQuerySync(context.Background(), BigQueryExportCommand{
		ActorID:        "admin",
		Entities:       []string{"orders", "users"},
		IdempotencyKey: "idem-1",
		Window: &ExportTimeWindow{
			From: &from,
			To:   &to,
		},
	})
	if err != nil {
		t.Fatalf("StartBigQuerySync: %v", err)
	}

	if task.ID != "task-123" {
		t.Fatalf("expected task id task-123, got %s", task.ID)
	}
	if task.Status != SystemTaskStatusPending {
		t.Fatalf("expected status pending, got %s", task.Status)
	}
	if task.Kind != exportTaskKindBigQuery {
		t.Fatalf("expected kind %s, got %s", exportTaskKindBigQuery, task.Kind)
	}
	if task.RequestedBy != "admin" {
		t.Fatalf("expected requestedBy admin, got %s", task.RequestedBy)
	}
	if task.IdempotencyKey != "idem-1" {
		t.Fatalf("expected idempotency key idem-1, got %s", task.IdempotencyKey)
	}
	if len(task.Parameters) == 0 {
		t.Fatalf("expected parameters to be populated")
	}

	if len(publisher.messages) != 1 {
		t.Fatalf("expected one message published, got %d", len(publisher.messages))
	}
	message := publisher.messages[0]
	if message.TaskID != "task-123" {
		t.Fatalf("expected message task id task-123, got %s", message.TaskID)
	}
	if len(message.Entities) != 2 || message.Entities[0] != "orders" || message.Entities[1] != "users" {
		t.Fatalf("unexpected message entities %v", message.Entities)
	}
	if message.IdempotencyKey != "idem-1" {
		t.Fatalf("expected message idempotency idem-1, got %s", message.IdempotencyKey)
	}

	second, err := service.StartBigQuerySync(context.Background(), BigQueryExportCommand{
		ActorID:        "admin",
		Entities:       []string{"orders"},
		IdempotencyKey: "idem-1",
	})
	if err != nil {
		t.Fatalf("StartBigQuerySync second call: %v", err)
	}
	if second.ID != task.ID {
		t.Fatalf("expected idempotent call to reuse task id %s, got %s", task.ID, second.ID)
	}
	if len(publisher.messages) != 1 {
		t.Fatalf("expected publisher not invoked again, got %d messages", len(publisher.messages))
	}
}

func TestExportService_StartBigQuerySyncPublisherError(t *testing.T) {
	publisher := &stubExportPublisher{
		err: errors.New("publish failed"),
	}
	service, err := NewExportService(ExportServiceDeps{
		Publisher:   publisher,
		IDGenerator: func() string { return "task-err" },
	})
	if err != nil {
		t.Fatalf("NewExportService: %v", err)
	}

	_, err = service.StartBigQuerySync(context.Background(), BigQueryExportCommand{
		ActorID:  "admin",
		Entities: []string{"orders"},
	})
	if err == nil || !stringsContains(err.Error(), "publish bigquery export") {
		t.Fatalf("expected publish error, got %v", err)
	}
}

type stubExportPublisher struct {
	mu       sync.Mutex
	messages []BigQueryExportMessage
	err      error
}

func (s *stubExportPublisher) PublishBigQueryExport(ctx context.Context, message BigQueryExportMessage) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.err != nil {
		return "", s.err
	}
	s.messages = append(s.messages, message)
	return "msg-1", nil
}

func stringsContains(haystack, needle string) bool {
	return strings.Index(haystack, needle) >= 0
}
