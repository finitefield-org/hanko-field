package runtime

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"cloud.google.com/go/pubsub"
	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/platform/observability"
)

// Options configures the job runtime harness.
type Options struct {
	ProjectID                  string
	SubscriptionID             string
	WorkerName                 string
	Processor                  jobs.Processor
	Logger                     *zap.Logger
	ReceiveSettings            *pubsub.ReceiveSettings
	SkipSubscriptionValidation bool
	SubscriptionPolicy         *jobs.SubscriptionPolicy
}

// Run wires the runtime harness and blocks until completion or context cancellation.
func Run(ctx context.Context, opts Options) error {
	if ctx == nil {
		return errors.New("jobs runtime: context is required")
	}
	if strings.TrimSpace(opts.WorkerName) == "" {
		opts.WorkerName = "worker"
	}
	if err := opts.validate(); err != nil {
		return err
	}

	logger := opts.Logger
	if logger == nil {
		var err error
		logger, err = observability.NewLogger()
		if err != nil {
			return fmt.Errorf("jobs runtime: failed to create logger: %w", err)
		}
	} else {
		logger = logger.With(zap.String("worker", opts.WorkerName))
	}
	defer func() {
		_ = logger.Sync()
	}()

	client, err := pubsub.NewClient(ctx, opts.ProjectID)
	if err != nil {
		return fmt.Errorf("jobs runtime: failed to create pubsub client: %w", err)
	}
	defer func() {
		_ = client.Close()
	}()

	sub := client.Subscription(opts.SubscriptionID)
	if !opts.SkipSubscriptionValidation {
		exists, err := sub.Exists(ctx)
		if err != nil {
			return fmt.Errorf("jobs runtime: subscription lookup failed: %w", err)
		}
		if !exists {
			return fmt.Errorf("jobs runtime: subscription %q not found", opts.SubscriptionID)
		}
	}

	if opts.SubscriptionPolicy != nil {
		if err := applySubscriptionPolicy(ctx, opts.ProjectID, sub, opts.SubscriptionPolicy, logger); err != nil {
			return err
		}
	}

	runnerOpts := []jobs.Option{
		jobs.WithLogger(logger),
		jobs.WithName(opts.WorkerName),
	}
	if opts.ReceiveSettings != nil {
		runnerOpts = append(runnerOpts, jobs.WithReceiveSettings(*opts.ReceiveSettings))
	}

	runner, err := jobs.NewRunner(sub, opts.Processor, runnerOpts...)
	if err != nil {
		return fmt.Errorf("jobs runtime: %w", err)
	}

	return runner.Run(ctx)
}

func (o Options) validate() error {
	if strings.TrimSpace(o.ProjectID) == "" {
		return errors.New("jobs runtime: project id is required")
	}
	if strings.TrimSpace(o.SubscriptionID) == "" {
		return errors.New("jobs runtime: subscription id is required")
	}
	if o.Processor == nil {
		return errors.New("jobs runtime: processor is required")
	}
	return nil
}

func applySubscriptionPolicy(ctx context.Context, projectID string, sub *pubsub.Subscription, policy *jobs.SubscriptionPolicy, logger *zap.Logger) error {
	if ctx == nil {
		return errors.New("jobs runtime: context is required for subscription policy")
	}
	if sub == nil || policy == nil {
		return nil
	}

	update := pubsub.SubscriptionConfigToUpdate{}

	if policy.Retry != nil && (policy.Retry.MinimumBackoff > 0 || policy.Retry.MaximumBackoff > 0) {
		update.RetryPolicy = &pubsub.RetryPolicy{
			MinimumBackoff: policy.Retry.MinimumBackoff,
			MaximumBackoff: policy.Retry.MaximumBackoff,
		}
	}

	if policy.DeadLetter != nil && (policy.DeadLetter.TopicID != "" || policy.DeadLetter.Topic != "" || policy.DeadLetter.MaxDeliveryAttempts > 0) {
		topic := strings.TrimSpace(policy.DeadLetter.Topic)
		if topic == "" {
			topicID := strings.TrimSpace(policy.DeadLetter.TopicID)
			if topicID != "" {
				if strings.HasPrefix(topicID, "projects/") {
					topic = topicID
				} else {
					topic = fmt.Sprintf("projects/%s/topics/%s", projectID, topicID)
				}
			}
		}
		if topic != "" {
			update.DeadLetterPolicy = &pubsub.DeadLetterPolicy{
				DeadLetterTopic:     topic,
				MaxDeliveryAttempts: policy.DeadLetter.MaxDeliveryAttempts,
			}
		}
	}

	if update.RetryPolicy == nil && update.DeadLetterPolicy == nil {
		return nil
	}

	if logger == nil {
		logger = zap.NewNop()
	}

	if _, err := sub.Update(ctx, update); err != nil {
		return fmt.Errorf("jobs runtime: failed to apply subscription policy: %w", err)
	}

	logger.Info("jobs runtime applied subscription policy",
		zap.String("subscription", sub.String()),
		zap.Bool("retry_configured", update.RetryPolicy != nil),
		zap.Bool("dead_letter_configured", update.DeadLetterPolicy != nil),
	)
	return nil
}
