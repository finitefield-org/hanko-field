package invoice

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/services"
)

// Processor translates Pub/Sub messages into invoice issuance commands.
type Processor struct {
	Service services.InvoiceService
	Logger  *zap.Logger
}

// NewProcessor constructs a Processor using the provided service.
func NewProcessor(service services.InvoiceService, logger *zap.Logger) *Processor {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &Processor{
		Service: service,
		Logger:  logger,
	}
}

// Process decodes the incoming message and invokes the invoice service.
func (p *Processor) Process(ctx context.Context, msg jobs.Message) error {
	if p.Service == nil {
		p.Logger.Error("invoice processor: service not configured",
			zap.String("message", jobs.DebugString(msg)),
		)
		return jobs.Permanent(errors.New("invoice processor: service not configured"))
	}

	var cmd services.IssueInvoicesCommand
	if err := msg.DecodeJSON(&cmd); err != nil {
		p.Logger.Error("invoice processor: failed to decode payload",
			zap.Error(err),
			zap.String("message_id", msg.ID),
		)
		return jobs.Permanent(fmt.Errorf("decode invoice message: %w", err))
	}

	cmd.ActorID = strings.TrimSpace(cmd.ActorID)
	if cmd.ActorID == "" {
		err := errors.New("invoice processor: actorId is required")
		p.Logger.Error("invoice processor: missing actorId",
			zap.String("message", jobs.DebugString(msg)),
		)
		return jobs.Permanent(err)
	}

	_, err := p.Service.IssueInvoices(ctx, cmd)
	if err != nil {
		if isInvoicePermanent(err) {
			p.Logger.Warn("invoice processor: permanent error",
				zap.Error(err),
				zap.String("actor_id", cmd.ActorID),
			)
			return jobs.Permanent(err)
		}
		p.Logger.Error("invoice processor: transient error",
			zap.Error(err),
			zap.String("actor_id", cmd.ActorID),
		)
		return err
	}

	p.Logger.Info("invoice processor: batch issued",
		zap.String("actor_id", cmd.ActorID),
		zap.Int("orders", len(cmd.OrderIDs)),
	)
	return nil
}

func isInvoicePermanent(err error) bool {
	return errors.Is(err, services.ErrInvoiceInvalidInput) ||
		errors.Is(err, services.ErrInvoiceConflict) ||
		errors.Is(err, services.ErrInvoiceOrderNotFound)
}

var _ jobs.Processor = (*Processor)(nil)
