package jobs

import (
	"testing"
	"time"
)

func TestDefaultSubscriptionPolicy(t *testing.T) {
	tests := []struct {
		name         string
		kind         WorkerKind
		minBackoff   time.Duration
		maxBackoff   time.Duration
		deadLetterID string
		maxAttempts  int
	}{
		{
			name:         "ai",
			kind:         WorkerKindAI,
			minBackoff:   10 * time.Second,
			maxBackoff:   2 * time.Minute,
			deadLetterID: "ai-jobs-dlq",
			maxAttempts:  10,
		},
		{
			name:         "invoice",
			kind:         WorkerKindInvoice,
			minBackoff:   10 * time.Second,
			maxBackoff:   5 * time.Minute,
			deadLetterID: "invoice-jobs-dlq",
			maxAttempts:  8,
		},
		{
			name:         "export",
			kind:         WorkerKindExport,
			minBackoff:   15 * time.Second,
			maxBackoff:   10 * time.Minute,
			deadLetterID: "export-jobs-dlq",
			maxAttempts:  8,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			policy := DefaultSubscriptionPolicy(tc.kind)
			if policy == nil {
				t.Fatalf("expected policy for kind %s", tc.kind)
			}
			if policy.Retry == nil {
				t.Fatalf("expected retry policy to be set")
			}
			if policy.Retry.MinimumBackoff != tc.minBackoff {
				t.Fatalf("expected min backoff %v, got %v", tc.minBackoff, policy.Retry.MinimumBackoff)
			}
			if policy.Retry.MaximumBackoff != tc.maxBackoff {
				t.Fatalf("expected max backoff %v, got %v", tc.maxBackoff, policy.Retry.MaximumBackoff)
			}
			if policy.DeadLetter == nil {
				t.Fatalf("expected dead letter policy to be set")
			}
			if policy.DeadLetter.TopicID != tc.deadLetterID {
				t.Fatalf("expected dead letter topic %q, got %q", tc.deadLetterID, policy.DeadLetter.TopicID)
			}
			if policy.DeadLetter.MaxDeliveryAttempts != tc.maxAttempts {
				t.Fatalf("expected max attempts %d, got %d", tc.maxAttempts, policy.DeadLetter.MaxDeliveryAttempts)
			}
		})
	}
}

func TestSubscriptionPolicyCloneAndOverrides(t *testing.T) {
	original := &SubscriptionPolicy{
		Retry: &RetryPolicy{
			MinimumBackoff: 15 * time.Second,
			MaximumBackoff: 1 * time.Minute,
		},
		DeadLetter: &DeadLetterPolicy{
			TopicID:             "jobs-dlq",
			MaxDeliveryAttempts: 5,
		},
	}

	cloned := original.Clone()
	if cloned == original {
		t.Fatalf("clone should return a distinct pointer")
	}
	cloned.ApplyOverrides(SubscriptionPolicyOverrides{
		DeadLetterTopic: "projects/test/topics/custom",
	})

	if original.DeadLetter.Topic != "" || original.DeadLetter.TopicID != "jobs-dlq" {
		t.Fatalf("overrides should not mutate original policy")
	}

	if cloned.DeadLetter.Topic != "projects/test/topics/custom" {
		t.Fatalf("expected override topic, got %q", cloned.DeadLetter.Topic)
	}
	if cloned.DeadLetter.TopicID != "" {
		t.Fatalf("expected TopicID to be cleared when Topic override is provided")
	}
}
