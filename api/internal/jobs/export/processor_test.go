package export

import (
	"context"
	"testing"
	"time"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/services"
)

func TestProcessorHandlerMissing(t *testing.T) {
	processor := NewProcessor(nil, zap.NewNop())
	err := processor.Process(context.Background(), jobs.Message{
		ID:   "msg1",
		Data: []byte(`{"taskId":"task_1","actorId":"staff","entities":["orders"]}`),
	})
	if err == nil {
		t.Fatal("expected error for missing handler")
	}
	if !jobs.IsPermanent(err) {
		t.Fatalf("expected permanent error, got %v", err)
	}
}

func TestProcessorInvokesHandler(t *testing.T) {
	handler := &stubHandler{}
	processor := NewProcessor(handler, zap.NewNop())
	now := time.Now().UTC()
	data := []byte(`{"taskId":"task_1","actorId":"staff","entities":["orders","users"],"queuedAt":"` + now.Format(time.RFC3339Nano) + `"}`)
	if err := processor.Process(context.Background(), jobs.Message{
		ID:   "msg2",
		Data: data,
	}); err != nil {
		t.Fatalf("Process: %v", err)
	}
	if handler.last.TaskID != "task_1" {
		t.Fatalf("expected task id task_1, got %q", handler.last.TaskID)
	}
	if len(handler.last.Entities) != 2 {
		t.Fatalf("expected 2 entities, got %d", len(handler.last.Entities))
	}
}

type stubHandler struct {
	last services.BigQueryExportMessage
}

func (s *stubHandler) Handle(ctx context.Context, msg services.BigQueryExportMessage) error {
	s.last = msg
	return nil
}
