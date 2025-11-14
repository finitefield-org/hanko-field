package ai

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/services"
)

// Executor performs the actual AI job processing.
type Executor interface {
	Execute(ctx context.Context, message services.SuggestionJobMessage) error
}

// ExecutorFunc adapts a function to the Executor interface.
type ExecutorFunc func(context.Context, services.SuggestionJobMessage) error

// Execute invokes the wrapped function.
func (f ExecutorFunc) Execute(ctx context.Context, message services.SuggestionJobMessage) error {
	return f(ctx, message)
}

// Processor bridges Pub/Sub messages to the configured Executor.
type Processor struct {
	executor Executor
	logger   *zap.Logger
}

// NewProcessor constructs a processor with the supplied executor.
func NewProcessor(executor Executor, logger *zap.Logger) *Processor {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &Processor{
		executor: executor,
		logger:   logger,
	}
}

// Process decodes the message and delegates execution.
func (p *Processor) Process(ctx context.Context, msg jobs.Message) error {
	var payload services.SuggestionJobMessage
	if err := msg.DecodeJSON(&payload); err != nil {
		p.logger.Error("ai processor: failed to decode message",
			zap.Error(err),
			zap.String("message_id", msg.ID),
			zap.String("subscription", msg.SubscriptionName),
		)
		return jobs.Permanent(fmt.Errorf("decode suggestion job: %w", err))
	}

	payload.JobID = strings.TrimSpace(payload.JobID)
	payload.SuggestionID = strings.TrimSpace(payload.SuggestionID)

	if payload.JobID == "" || payload.SuggestionID == "" {
		err := errors.New("ai processor: jobId and suggestionId are required")
		p.logger.Error("ai processor: missing identifiers",
			zap.Error(err),
			zap.String("message", jobs.DebugString(msg)),
		)
		return jobs.Permanent(err)
	}

	if p.executor == nil {
		p.logger.Warn("ai processor: executor not configured, acknowledging message",
			zap.String("job_id", payload.JobID),
			zap.String("suggestion_id", payload.SuggestionID),
		)
		return nil
	}

	if err := p.executor.Execute(ctx, payload); err != nil {
		p.logger.Error("ai processor: executor failed",
			zap.Error(err),
			zap.String("job_id", payload.JobID),
			zap.String("suggestion_id", payload.SuggestionID),
		)
		return err
	}

	p.logger.Debug("ai processor: job dispatched",
		zap.String("job_id", payload.JobID),
		zap.String("suggestion_id", payload.SuggestionID),
	)
	return nil
}

var _ jobs.Processor = (*Processor)(nil)
