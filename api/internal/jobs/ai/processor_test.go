package ai

import (
	"context"
	"encoding/json"
	"testing"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/services"
)

func TestProcessorDecodeFailure(t *testing.T) {
	processor := NewProcessor(nil, zap.NewNop())
	err := processor.Process(context.Background(), jobs.Message{
		ID:   "msg1",
		Data: []byte("{invalid-json"),
	})
	if err == nil {
		t.Fatal("expected error for invalid payload, got nil")
	}
	if !jobs.IsPermanent(err) {
		t.Fatalf("expected permanent error for decode failure, got %v", err)
	}
}

func TestProcessorExecutes(t *testing.T) {
	var invoked bool
	executor := ExecutorFunc(func(ctx context.Context, msg services.SuggestionJobMessage) error {
		invoked = true
		if msg.JobID != "aj_1" || msg.SuggestionID != "as_1" {
			t.Fatalf("unexpected payload %+v", msg)
		}
		return nil
	})
	processor := NewProcessor(executor, zap.NewNop())
	payload, _ := json.Marshal(services.SuggestionJobMessage{
		JobID:        "aj_1",
		SuggestionID: "as_1",
	})
	if err := processor.Process(context.Background(), jobs.Message{
		ID:   "msg2",
		Data: payload,
	}); err != nil {
		t.Fatalf("Process: %v", err)
	}
	if !invoked {
		t.Fatal("expected executor to be invoked")
	}
}
