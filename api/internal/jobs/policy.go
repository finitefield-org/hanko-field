package jobs

import (
	"strings"
	"time"
)

// WorkerKind enumerates the supported background worker categories.
type WorkerKind string

const (
	// WorkerKindAI covers AI suggestion background processing.
	WorkerKindAI WorkerKind = "ai"
	// WorkerKindInvoice covers invoice generation workers.
	WorkerKindInvoice WorkerKind = "invoice"
	// WorkerKindExport covers export synchronisation workers.
	WorkerKindExport WorkerKind = "export"
)

// SubscriptionPolicy describes retry/backoff and dead-letter configuration to
// apply to a Pub/Sub subscription.
type SubscriptionPolicy struct {
	Retry      *RetryPolicy
	DeadLetter *DeadLetterPolicy
}

// RetryPolicy defines the exponential backoff parameters enforced at the
// subscription layer.
type RetryPolicy struct {
	MinimumBackoff time.Duration
	MaximumBackoff time.Duration
}

// DeadLetterPolicy configures forwarding of failed messages after exceeding the
// permitted delivery attempts.
type DeadLetterPolicy struct {
	// TopicID is the short topic identifier without the `projects/{id}/topics/`
	// prefix. It is combined with the project ID when constructing resource
	// paths.
	TopicID string
	// Topic is an optional fully-qualified topic resource path. When supplied it
	// takes precedence over TopicID and is used verbatim.
	Topic string
	// MaxDeliveryAttempts defines the number of deliveries Pub/Sub will attempt
	// before forcing the message onto the configured dead-letter topic.
	MaxDeliveryAttempts int
}

// DefaultSubscriptionPolicy returns the standard retry and dead-letter policy
// for the supplied worker kind. Policies are intentionally conservative to
// favour delayed retries over rapid redelivery storms.
func DefaultSubscriptionPolicy(kind WorkerKind) *SubscriptionPolicy {
	switch kind {
	case WorkerKindAI:
		return &SubscriptionPolicy{
			Retry: &RetryPolicy{
				MinimumBackoff: 10 * time.Second,
				MaximumBackoff: 2 * time.Minute,
			},
			DeadLetter: &DeadLetterPolicy{
				TopicID:             "ai-jobs-dlq",
				MaxDeliveryAttempts: 10,
			},
		}
	case WorkerKindInvoice:
		return &SubscriptionPolicy{
			Retry: &RetryPolicy{
				MinimumBackoff: 10 * time.Second,
				MaximumBackoff: 5 * time.Minute,
			},
			DeadLetter: &DeadLetterPolicy{
				TopicID:             "invoice-jobs-dlq",
				MaxDeliveryAttempts: 8,
			},
		}
	case WorkerKindExport:
		return &SubscriptionPolicy{
			Retry: &RetryPolicy{
				MinimumBackoff: 15 * time.Second,
				MaximumBackoff: 10 * time.Minute,
			},
			DeadLetter: &DeadLetterPolicy{
				TopicID:             "export-jobs-dlq",
				MaxDeliveryAttempts: 8,
			},
		}
	default:
		return &SubscriptionPolicy{}
	}
}

// Clone returns a deep copy of the subscription policy allowing callers to
// mutate overrides without affecting shared defaults.
func (p *SubscriptionPolicy) Clone() *SubscriptionPolicy {
	if p == nil {
		return nil
	}
	out := &SubscriptionPolicy{}
	if p.Retry != nil {
		out.Retry = &RetryPolicy{
			MinimumBackoff: p.Retry.MinimumBackoff,
			MaximumBackoff: p.Retry.MaximumBackoff,
		}
	}
	if p.DeadLetter != nil {
		out.DeadLetter = &DeadLetterPolicy{
			TopicID:             p.DeadLetter.TopicID,
			Topic:               p.DeadLetter.Topic,
			MaxDeliveryAttempts: p.DeadLetter.MaxDeliveryAttempts,
		}
	}
	return out
}

// ApplyOverrides mutates the policy by applying the supplied overrides. Zero
// values are ignored so callers can opt-in to specific fields.
func (p *SubscriptionPolicy) ApplyOverrides(ov SubscriptionPolicyOverrides) {
	if p == nil {
		return
	}
	if ov.MinimumBackoff != nil {
		if p.Retry == nil {
			p.Retry = &RetryPolicy{}
		}
		p.Retry.MinimumBackoff = *ov.MinimumBackoff
	}
	if ov.MaximumBackoff != nil {
		if p.Retry == nil {
			p.Retry = &RetryPolicy{}
		}
		p.Retry.MaximumBackoff = *ov.MaximumBackoff
	}
	if ov.MaxDeliveryAttempts != nil {
		if p.DeadLetter == nil {
			p.DeadLetter = &DeadLetterPolicy{}
		}
		p.DeadLetter.MaxDeliveryAttempts = *ov.MaxDeliveryAttempts
	}
	if topic := strings.TrimSpace(ov.DeadLetterTopic); topic != "" {
		if p.DeadLetter == nil {
			p.DeadLetter = &DeadLetterPolicy{}
		}
		if strings.HasPrefix(topic, "projects/") {
			p.DeadLetter.Topic = topic
			p.DeadLetter.TopicID = ""
		} else {
			p.DeadLetter.Topic = ""
			p.DeadLetter.TopicID = topic
		}
	}
}

// SubscriptionPolicyOverrides provides optional overrides for runtime
// configuration via flags or environment variables.
type SubscriptionPolicyOverrides struct {
	MinimumBackoff      *time.Duration
	MaximumBackoff      *time.Duration
	MaxDeliveryAttempts *int
	DeadLetterTopic     string
}
