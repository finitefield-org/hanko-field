package deadletter

import (
	"context"
	"errors"
	"testing"
	"time"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
)

func TestProcessorReportsDeadLetter(t *testing.T) {
	sink := &stubSink{}
	metrics := &stubMetrics{}
	logger := zap.NewNop()
	processor := NewProcessor(sink, logger, metrics)

	now := time.Now().UTC()
	msg := jobs.Message{
		ID:               "msg_1",
		Data:             []byte(`{"job":"test"}`),
		Attributes:       map[string]string{"kind": "ai"},
		DeliveryAttempt:  4,
		PublishTime:      now,
		SubscriptionName: "projects/test/subscriptions/ai-dlq-sub",
	}

	if err := processor.Process(context.Background(), msg); err != nil {
		t.Fatalf("Process returned error: %v", err)
	}

	if len(sink.events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(sink.events))
	}

	event := sink.events[0]
	if event.MessageID != msg.ID {
		t.Fatalf("expected message id %q, got %q", msg.ID, event.MessageID)
	}
	if string(event.Payload) != string(msg.Data) {
		t.Fatalf("payload mismatch, expected %q got %q", msg.Data, event.Payload)
	}
	if event.DeliveryAttempt != msg.DeliveryAttempt {
		t.Fatalf("expected delivery attempt %d, got %d", msg.DeliveryAttempt, event.DeliveryAttempt)
	}
	if event.ReceivedAt.IsZero() {
		t.Fatalf("expected ReceivedAt to be set")
	}

	if len(metrics.records) != 1 {
		t.Fatalf("expected 1 metrics record, got %d", len(metrics.records))
	}
	if metrics.records[0].outcome != "dead_letter" {
		t.Fatalf("expected outcome dead_letter, got %s", metrics.records[0].outcome)
	}
	if metrics.records[0].attempt != msg.DeliveryAttempt {
		t.Fatalf("expected attempt %d, got %d", msg.DeliveryAttempt, metrics.records[0].attempt)
	}
}

func TestProcessorRetriesOnSinkError(t *testing.T) {
	sink := &stubSink{err: errors.New("fail to persist")}
	metrics := &stubMetrics{}
	logger := zap.NewNop()
	processor := NewProcessor(sink, logger, metrics)

	msg := jobs.Message{
		ID:              "msg_2",
		Data:            []byte("test"),
		DeliveryAttempt: 2,
	}

	err := processor.Process(context.Background(), msg)
	if err == nil {
		t.Fatalf("expected error due to sink failure")
	}

	if len(metrics.records) != 1 {
		t.Fatalf("expected 1 metrics record, got %d", len(metrics.records))
	}
	if metrics.records[0].outcome != "dead_letter_retry" {
		t.Fatalf("expected outcome dead_letter_retry, got %s", metrics.records[0].outcome)
	}
}

type stubSink struct {
	err    error
	events []Event
}

func (s *stubSink) ReportDeadLetter(ctx context.Context, event Event) error {
	if s.err != nil {
		return s.err
	}
	s.events = append(s.events, event)
	return nil
}

type stubMetrics struct {
	records []metricsRecord
}

type metricsRecord struct {
	worker  string
	outcome string
	attempt int
}

func (s *stubMetrics) Record(ctx context.Context, worker, outcome string, attempt int, duration time.Duration) {
	s.records = append(s.records, metricsRecord{
		worker:  worker,
		outcome: outcome,
		attempt: attempt,
	})
}
