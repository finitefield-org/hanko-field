package deadletter

import (
	"context"
	"time"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
)

// Event summarises a message that has been routed to a dead-letter topic.
type Event struct {
	MessageID        string
	SubscriptionName string
	Attributes       map[string]string
	Payload          []byte
	DeliveryAttempt  int
	PublishTime      time.Time
	ReceivedAt       time.Time
}

// Sink handles notification when a message arrives in the dead-letter queue.
type Sink interface {
	ReportDeadLetter(ctx context.Context, event Event) error
}

// Processor consumes dead-letter Pub/Sub messages and forwards them to the
// configured sink.
type Processor struct {
	sink    Sink
	logger  *zap.Logger
	metrics jobs.MetricsRecorder
	name    string
}

// NewProcessor constructs a dead-letter processor with the supplied sink. A nil
// sink results in logging-only behaviour.
func NewProcessor(sink Sink, logger *zap.Logger, metrics jobs.MetricsRecorder) *Processor {
	if logger == nil {
		logger = zap.NewNop()
	}
	if metrics == nil {
		metrics = jobs.NewMetricsRecorder(logger)
	}
	return &Processor{
		sink:    sink,
		logger:  logger,
		metrics: metrics,
		name:    "deadletter",
	}
}

// Process records the dead-letter event and forwards it to the configured sink.
func (p *Processor) Process(ctx context.Context, msg jobs.Message) error {
	event := Event{
		MessageID:        msg.ID,
		SubscriptionName: msg.SubscriptionName,
		Attributes:       cloneAttributes(msg.Attributes),
		Payload:          cloneBytes(msg.Data),
		DeliveryAttempt:  msg.DeliveryAttempt,
		PublishTime:      msg.PublishTime,
		ReceivedAt:       time.Now().UTC(),
	}

	if p.sink != nil {
		if err := p.sink.ReportDeadLetter(ctx, event); err != nil {
			p.metrics.Record(ctx, p.name, "dead_letter_retry", msg.DeliveryAttempt, 0)
			p.logger.Error("deadletter processor: sink failed",
				zap.Error(err),
				zap.String("message_id", msg.ID),
				zap.Int("delivery_attempt", msg.DeliveryAttempt),
			)
			return err
		}
	}

	p.metrics.Record(ctx, p.name, "dead_letter", msg.DeliveryAttempt, 0)
	p.logger.Error("deadletter processor: message captured",
		zap.String("message_id", msg.ID),
		zap.Int("delivery_attempt", msg.DeliveryAttempt),
		zap.String("subscription", msg.SubscriptionName),
	)

	return nil
}

func cloneAttributes(attrs map[string]string) map[string]string {
	if len(attrs) == 0 {
		return map[string]string{}
	}
	out := make(map[string]string, len(attrs))
	for k, v := range attrs {
		out[k] = v
	}
	return out
}

func cloneBytes(data []byte) []byte {
	if len(data) == 0 {
		return []byte{}
	}
	out := make([]byte, len(data))
	copy(out, data)
	return out
}

var _ jobs.Processor = (*Processor)(nil)
