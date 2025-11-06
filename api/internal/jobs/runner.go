package jobs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"cloud.google.com/go/pubsub"
	"go.uber.org/zap"
)

const (
	defaultWorkerName = "worker"

	outcomeSuccess          = "success"
	outcomeRetry            = "retry"
	outcomePermanentFailure = "permanent_failure"
	outcomePanic            = "panic"
)

// Runner consumes messages from a Pub/Sub subscription and hands them to the
// configured processor. Runners are safe for single use; create one runner per
// subscription you need to service.
type Runner struct {
	name           string
	subscription   *pubsub.Subscription
	processor      Processor
	logger         *zap.Logger
	metrics        MetricsRecorder
	receiveOptions *pubsub.ReceiveSettings
}

// Option customises runner behaviour.
type Option func(*Runner)

// WithName sets the logical worker name used for logging and metrics.
func WithName(name string) Option {
	return func(r *Runner) {
		if trimmed := sanitizeName(name); trimmed != "" {
			r.name = trimmed
		}
	}
}

// WithLogger overrides the logger used for structured output.
func WithLogger(logger *zap.Logger) Option {
	return func(r *Runner) {
		r.logger = logger
	}
}

// WithMetrics supplies a custom metrics recorder. When omitted a default
// OpenTelemetry implementation is used.
func WithMetrics(recorder MetricsRecorder) Option {
	return func(r *Runner) {
		r.metrics = recorder
	}
}

// WithReceiveSettings replaces the default ReceiveSettings applied to the subscription.
func WithReceiveSettings(settings pubsub.ReceiveSettings) Option {
	return func(r *Runner) {
		r.receiveOptions = &settings
	}
}

// NewRunner wires a processor to the provided subscription.
func NewRunner(sub *pubsub.Subscription, processor Processor, opts ...Option) (*Runner, error) {
	if sub == nil {
		return nil, errors.New("jobs runner: subscription is required")
	}
	if processor == nil {
		return nil, errors.New("jobs runner: processor is required")
	}

	runner := &Runner{
		name:         defaultWorkerName,
		subscription: sub,
		processor:    processor,
	}

	for _, opt := range opts {
		if opt != nil {
			opt(runner)
		}
	}

	if runner.logger == nil {
		runner.logger = zap.NewNop()
	}
	if runner.metrics == nil {
		runner.metrics = NewMetricsRecorder(runner.logger)
	}
	if runner.receiveOptions != nil {
		sub.ReceiveSettings = *runner.receiveOptions
	}

	return runner, nil
}

// Run blocks while receiving messages until the context is cancelled or the
// underlying subscription returns an unrecoverable error. Context cancellation
// is treated as a normal shutdown and does not return an error.
func (r *Runner) Run(ctx context.Context) error {
	if r == nil {
		return errors.New("jobs runner: nil receiver")
	}

	logger := r.logger
	logFields := []zap.Field{
		zap.String("subscription", r.subscriptionString()),
		zap.String("worker", r.name),
	}
	logger.Info("jobs runner starting", logFields...)

	err := r.subscription.Receive(ctx, func(ctx context.Context, msg *pubsub.Message) {
		r.handleMessage(ctx, msg)
	})
	if err != nil && !errors.Is(err, context.Canceled) && !errors.Is(err, context.DeadlineExceeded) {
		logger.Error("jobs runner stopped with error", append(logFields, zap.Error(err))...)
		return err
	}

	logger.Info("jobs runner stopped", logFields...)
	return nil
}

func (r *Runner) handleMessage(ctx context.Context, msg *pubsub.Message) {
	outcome := outcomeRetry
	started := time.Now()
	message := normalizeMessage(r.subscriptionString(), msg)
	defer func() {
		r.metrics.Record(ctx, r.name, outcome, message.DeliveryAttempt, time.Since(started))
	}()

	defer func() {
		if rec := recover(); rec != nil {
			outcome = outcomePanic
			r.logger.Error("jobs processor panic recovered",
				zap.String("worker", r.name),
				zap.Any("panic", rec),
				zap.String("message_id", message.ID),
				zap.Int("delivery_attempt", message.DeliveryAttempt),
			)
			msg.Nack()
		}
	}()

	if ctx.Err() != nil {
		outcome = outcomeRetry
		msg.Nack()
		return
	}

	err := r.processor.Process(ctx, message)
	switch {
	case err == nil:
		outcome = outcomeSuccess
		msg.Ack()
		r.logger.Debug("jobs message processed",
			zap.String("worker", r.name),
			zap.String("message_id", message.ID),
			zap.Int("delivery_attempt", message.DeliveryAttempt),
		)
	case errors.Is(err, context.Canceled), errors.Is(err, context.DeadlineExceeded):
		outcome = outcomeRetry
		msg.Nack()
		r.logger.Warn("jobs processor cancelled",
			zap.String("worker", r.name),
			zap.String("message_id", message.ID),
			zap.Error(err),
			zap.Int("delivery_attempt", message.DeliveryAttempt),
		)
	case IsPermanent(err):
		outcome = outcomePermanentFailure
		msg.Ack()
		r.logger.Error("jobs processor permanent failure",
			zap.String("worker", r.name),
			zap.String("message_id", message.ID),
			zap.Error(err),
			zap.Int("delivery_attempt", message.DeliveryAttempt),
		)
	default:
		outcome = outcomeRetry
		msg.Nack()
		r.logger.Warn("jobs processor transient failure",
			zap.String("worker", r.name),
			zap.String("message_id", message.ID),
			zap.Error(err),
			zap.Int("delivery_attempt", message.DeliveryAttempt),
		)
	}
}

func (r *Runner) subscriptionString() string {
	if r == nil || r.subscription == nil {
		return ""
	}
	return r.subscription.String()
}

func normalizeMessage(subscription string, msg *pubsub.Message) Message {
	attrs := make(map[string]string, len(msg.Attributes))
	for k, v := range msg.Attributes {
		attrs[k] = v
	}
	attempt := 0
	if msg.DeliveryAttempt != nil {
		attempt = *msg.DeliveryAttempt
	}
	data := make([]byte, len(msg.Data))
	copy(data, msg.Data)
	return Message{
		ID:               msg.ID,
		Data:             data,
		Attributes:       attrs,
		PublishTime:      msg.PublishTime,
		DeliveryAttempt:  attempt,
		OrderingKey:      msg.OrderingKey,
		SubscriptionName: subscription,
	}
}

// RunOne processes a single message with the provided processor. This helper is
// primarily intended for tests.
func RunOne(ctx context.Context, processor Processor, msg Message) error {
	if processor == nil {
		return errors.New("jobs runner: processor is required")
	}
	if ctx == nil {
		return errors.New("jobs runner: context is required")
	}
	return processor.Process(ctx, msg)
}

// DebugString returns a formatted representation useful in logs and errors.
func DebugString(msg Message) string {
	return fmt.Sprintf("msg[id=%s attempt=%d subscription=%s]", msg.ID, msg.DeliveryAttempt, msg.SubscriptionName)
}
