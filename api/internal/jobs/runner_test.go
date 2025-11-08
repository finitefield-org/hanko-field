package jobs

import (
	"context"
	"os"
	"sync"
	"testing"
	"time"

	"cloud.google.com/go/pubsub"
	"cloud.google.com/go/pubsub/pstest"
	"go.uber.org/zap"
	"google.golang.org/api/option"
)

func TestRunnerProcessesMessageSuccess(t *testing.T) {
	srv, client := newPubSubClient(t)

	sub := createSubscription(t, client, "projects/test/topics/ai-jobs", "ai-worker-sub")

	processed := make(chan struct{}, 1)
	processor := ProcessorFunc(func(ctx context.Context, msg Message) error {
		processed <- struct{}{}
		return nil
	})

	runner, err := NewRunner(sub, processor, WithLogger(zap.NewNop()))
	if err != nil {
		t.Fatalf("NewRunner: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := runner.Run(ctx); err != nil {
			t.Errorf("runner.Run: %v", err)
		}
	}()

	publish(t, client, "projects/test/topics/ai-jobs", []byte(`{"jobId":"aj_1"}`))

	select {
	case <-processed:
	case <-time.After(5 * time.Second):
		t.Fatal("timeout waiting for processor invocation")
	}

	cancel()
	wg.Wait()

	msgs := srv.Messages()
	if len(msgs) != 1 {
		t.Fatalf("expected 1 message published, got %d", len(msgs))
	}
	if msgs[0].Acks != 1 {
		t.Fatalf("expected message to be acknowledged once, got %d", msgs[0].Acks)
	}
}

func TestRunnerRetriesOnError(t *testing.T) {
	srv, client := newPubSubClient(t)

	sub := createSubscription(t, client, "projects/test/topics/invoice-jobs", "invoice-worker-sub")

	attempts := make(chan struct{}, 1)
	processor := ProcessorFunc(func(ctx context.Context, msg Message) error {
		attempts <- struct{}{}
		return assertError("boom")
	})

	runner, err := NewRunner(sub, processor, WithLogger(zap.NewNop()))
	if err != nil {
		t.Fatalf("NewRunner: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		_ = runner.Run(ctx)
	}()

	publish(t, client, "projects/test/topics/invoice-jobs", []byte(`{"batch":"test"}`))

	select {
	case <-attempts:
	case <-time.After(5 * time.Second):
		t.Fatal("timeout waiting for processor invocation")
	}

	cancel()
	wg.Wait()

	msgs := srv.Messages()
	if len(msgs) != 1 {
		t.Fatalf("expected 1 message published, got %d", len(msgs))
	}
	if msgs[0].Acks != 0 {
		t.Fatalf("expected unacked message due to retry, got %d acks", msgs[0].Acks)
	}
	if msgs[0].Deliveries < 1 {
		t.Fatalf("expected at least one delivery attempt, got %d", msgs[0].Deliveries)
	}
}

func TestRunnerPermanentErrorAcknowledges(t *testing.T) {
	srv, client := newPubSubClient(t)

	sub := createSubscription(t, client, "projects/test/topics/export-jobs", "export-worker-sub")

	processed := make(chan struct{}, 1)
	processor := ProcessorFunc(func(ctx context.Context, msg Message) error {
		processed <- struct{}{}
		return Permanent(assertError("invalid payload"))
	})

	runner, err := NewRunner(sub, processor, WithLogger(zap.NewNop()))
	if err != nil {
		t.Fatalf("NewRunner: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		_ = runner.Run(ctx)
	}()

	publish(t, client, "projects/test/topics/export-jobs", []byte(`{"taskId":"task_1"}`))

	select {
	case <-processed:
	case <-time.After(5 * time.Second):
		t.Fatal("timeout waiting for processor invocation")
	}

	cancel()
	wg.Wait()

	msgs := srv.Messages()
	if len(msgs) != 1 {
		t.Fatalf("expected 1 message published, got %d", len(msgs))
	}
	if msgs[0].Acks != 1 {
		t.Fatalf("expected message to be acknowledged once, got %d", msgs[0].Acks)
	}
}

// --- helpers ---------------------------------------------------------------

func newPubSubClient(t *testing.T) (*pstest.Server, *pubsub.Client) {
	t.Helper()
	server := pstest.NewServer()
	t.Cleanup(func() { server.Close() })

	oldHost := os.Getenv("PUBSUB_EMULATOR_HOST")
	os.Setenv("PUBSUB_EMULATOR_HOST", server.Addr)
	t.Cleanup(func() {
		if oldHost == "" {
			os.Unsetenv("PUBSUB_EMULATOR_HOST")
		} else {
			os.Setenv("PUBSUB_EMULATOR_HOST", oldHost)
		}
	})

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	client, err := pubsub.NewClient(ctx, "test", option.WithoutAuthentication())
	if err != nil {
		t.Fatalf("pubsub.NewClient: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })
	return server, client
}

func createSubscription(t *testing.T, client *pubsub.Client, topicPath, subID string) *pubsub.Subscription {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	topic, err := client.CreateTopic(ctx, trimTopicName(topicPath))
	if err != nil {
		t.Fatalf("CreateTopic: %v", err)
	}
	sub, err := client.CreateSubscription(ctx, subID, pubsub.SubscriptionConfig{
		Topic: topic,
	})
	if err != nil {
		t.Fatalf("CreateSubscription: %v", err)
	}
	return sub
}

func publish(t *testing.T, client *pubsub.Client, topicPath string, data []byte) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	topic := client.Topic(trimTopicName(topicPath))
	res := topic.Publish(ctx, &pubsub.Message{Data: data})
	if _, err := res.Get(ctx); err != nil {
		t.Fatalf("Publish: %v", err)
	}
}

func trimTopicName(path string) string {
	last := -1
	for i := len(path) - 1; i >= 0; i-- {
		if path[i] == '/' {
			last = i
			break
		}
	}
	if last == -1 || last == len(path)-1 {
		return path
	}
	return path[last+1:]
}

type assertError string

func (e assertError) Error() string { return string(e) }
