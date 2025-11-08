package export

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/services"
)

// Handler processes an export job message.
type Handler interface {
	Handle(ctx context.Context, message services.BigQueryExportMessage) error
}

// HandlerFunc adapts a function to the Handler interface.
type HandlerFunc func(context.Context, services.BigQueryExportMessage) error

// Handle invokes the wrapped function.
func (f HandlerFunc) Handle(ctx context.Context, message services.BigQueryExportMessage) error {
	return f(ctx, message)
}

// Processor bridges Pub/Sub messages to the export handler.
type Processor struct {
	Handler Handler
	Logger  *zap.Logger
}

// NewProcessor constructs a Processor with the provided handler.
func NewProcessor(handler Handler, logger *zap.Logger) *Processor {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &Processor{
		Handler: handler,
		Logger:  logger,
	}
}

// Process decodes the export message and invokes the handler.
func (p *Processor) Process(ctx context.Context, msg jobs.Message) error {
	if p.Handler == nil {
		p.Logger.Error("export processor: handler not configured",
			zap.String("message", jobs.DebugString(msg)),
		)
		return jobs.Permanent(errors.New("export processor: handler not configured"))
	}

	var payload rawMessage
	if err := msg.DecodeJSON(&payload); err != nil {
		p.Logger.Error("export processor: failed to decode payload",
			zap.Error(err),
			zap.String("message_id", msg.ID),
		)
		return jobs.Permanent(fmt.Errorf("decode export message: %w", err))
	}

	message := payload.toExportMessage()
	if message.TaskID == "" || message.ActorID == "" || len(message.Entities) == 0 {
		err := errors.New("export processor: missing required fields")
		p.Logger.Error("export processor: invalid payload",
			zap.Error(err),
			zap.String("message", jobs.DebugString(msg)),
		)
		return jobs.Permanent(err)
	}

	if err := p.Handler.Handle(ctx, message); err != nil {
		p.Logger.Error("export processor: handler failed",
			zap.Error(err),
			zap.String("task_id", message.TaskID),
			zap.Strings("entities", message.Entities),
		)
		return err
	}

	p.Logger.Info("export processor: job handled",
		zap.String("task_id", message.TaskID),
		zap.Strings("entities", message.Entities),
	)
	return nil
}

type rawMessage struct {
	TaskID         string     `json:"taskId"`
	ActorID        string     `json:"actorId"`
	Entities       []string   `json:"entities"`
	WindowFrom     *time.Time `json:"windowFrom"`
	WindowTo       *time.Time `json:"windowTo"`
	IdempotencyKey string     `json:"idempotencyKey"`
	QueuedAt       time.Time  `json:"queuedAt"`
}

func (m rawMessage) toExportMessage() services.BigQueryExportMessage {
	entities := make([]string, 0, len(m.Entities))
	for _, entity := range m.Entities {
		if trimmed := strings.TrimSpace(entity); trimmed != "" {
			entities = append(entities, trimmed)
		}
	}
	return services.BigQueryExportMessage{
		TaskID:         strings.TrimSpace(m.TaskID),
		ActorID:        strings.TrimSpace(m.ActorID),
		Entities:       entities,
		WindowFrom:     m.WindowFrom,
		WindowTo:       m.WindowTo,
		IdempotencyKey: strings.TrimSpace(m.IdempotencyKey),
		QueuedAt:       m.QueuedAt,
	}
}

var _ jobs.Processor = (*Processor)(nil)
