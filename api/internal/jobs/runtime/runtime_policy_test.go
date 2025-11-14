package runtime

import (
	"context"
	"os"
	"testing"
	"time"

	"cloud.google.com/go/pubsub"
	"cloud.google.com/go/pubsub/pstest"
	"go.uber.org/zap"
	"google.golang.org/api/option"

	"github.com/hanko-field/api/internal/jobs"
)

func TestApplySubscriptionPolicy(t *testing.T) {
	ctx := context.Background()
	server := pstest.NewServer()
	defer server.Close()

	old := os.Getenv("PUBSUB_EMULATOR_HOST")
	os.Setenv("PUBSUB_EMULATOR_HOST", server.Addr)
	defer func() {
		if old == "" {
			os.Unsetenv("PUBSUB_EMULATOR_HOST")
		} else {
			os.Setenv("PUBSUB_EMULATOR_HOST", old)
		}
	}()

	client, err := pubsub.NewClient(ctx, "test", option.WithoutAuthentication())
	if err != nil {
		t.Fatalf("pubsub.NewClient: %v", err)
	}
	defer client.Close()

	mainTopic, err := client.CreateTopic(ctx, "ai-jobs")
	if err != nil {
		t.Fatalf("CreateTopic main: %v", err)
	}
	_, err = client.CreateTopic(ctx, "ai-jobs-dlq")
	if err != nil {
		t.Fatalf("CreateTopic dlq: %v", err)
	}

	sub, err := client.CreateSubscription(ctx, "ai-worker-sub", pubsub.SubscriptionConfig{
		Topic: mainTopic,
	})
	if err != nil {
		t.Fatalf("CreateSubscription: %v", err)
	}

	policy := &jobs.SubscriptionPolicy{
		Retry: &jobs.RetryPolicy{
			MinimumBackoff: 10 * time.Second,
			MaximumBackoff: 2 * time.Minute,
		},
		DeadLetter: &jobs.DeadLetterPolicy{
			TopicID:             "ai-jobs-dlq",
			MaxDeliveryAttempts: 7,
		},
	}

	if err := applySubscriptionPolicy(ctx, "test", sub, policy, zap.NewNop()); err != nil {
		t.Fatalf("applySubscriptionPolicy: %v", err)
	}

	cfg, err := sub.Config(ctx)
	if err != nil {
		t.Fatalf("Config: %v", err)
	}

	if cfg.RetryPolicy == nil {
		t.Fatalf("expected retry policy applied")
	}
	if cfg.RetryPolicy.MinimumBackoff != policy.Retry.MinimumBackoff {
		t.Fatalf("expected min backoff %v, got %v", policy.Retry.MinimumBackoff, cfg.RetryPolicy.MinimumBackoff)
	}
	if cfg.RetryPolicy.MaximumBackoff != policy.Retry.MaximumBackoff {
		t.Fatalf("expected max backoff %v, got %v", policy.Retry.MaximumBackoff, cfg.RetryPolicy.MaximumBackoff)
	}

	if cfg.DeadLetterPolicy == nil {
		t.Fatalf("expected dead letter policy applied")
	}
	expectedTopic := "projects/test/topics/ai-jobs-dlq"
	if cfg.DeadLetterPolicy.DeadLetterTopic != expectedTopic {
		t.Fatalf("expected dead letter topic %q, got %q", expectedTopic, cfg.DeadLetterPolicy.DeadLetterTopic)
	}
	if cfg.DeadLetterPolicy.MaxDeliveryAttempts != policy.DeadLetter.MaxDeliveryAttempts {
		t.Fatalf("expected max attempts %d, got %d", policy.DeadLetter.MaxDeliveryAttempts, cfg.DeadLetterPolicy.MaxDeliveryAttempts)
	}
}
