package requestctx

import (
	"context"
	"strings"

	"go.uber.org/zap"
)

type contextKey string

const (
	loggerContextKey      contextKey = "github.com/hanko-field/api/internal/platform/requestctx/logger"
	traceContextKey       contextKey = "github.com/hanko-field/api/internal/platform/requestctx/trace"
	correlationContextKey contextKey = "github.com/hanko-field/api/internal/platform/requestctx/correlation"
)

var noopLogger = zap.NewNop()

// TraceInfo captures trace metadata propagated through request context.
type TraceInfo struct {
	TraceID   string
	SpanID    string
	Sampled   bool
	ProjectID string
}

// WithLogger stores the logger in context for downstream consumers.
func WithLogger(ctx context.Context, logger *zap.Logger) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	if logger == nil {
		logger = noopLogger
	}
	return context.WithValue(ctx, loggerContextKey, logger)
}

// Logger retrieves the zap logger from context or returns a no-op logger.
func Logger(ctx context.Context) *zap.Logger {
	if ctx == nil {
		return noopLogger
	}
	if logger, ok := ctx.Value(loggerContextKey).(*zap.Logger); ok && logger != nil {
		return logger
	}
	return noopLogger
}

// NoopLogger exposes the shared noop logger instance used across the package.
func NoopLogger() *zap.Logger { return noopLogger }

// WithTrace stores the trace metadata on the context for downstream usage.
func WithTrace(ctx context.Context, info TraceInfo) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	return context.WithValue(ctx, traceContextKey, info)
}

// Trace retrieves the trace metadata from context when available.
func Trace(ctx context.Context) (TraceInfo, bool) {
	if ctx == nil {
		return TraceInfo{}, false
	}
	info, ok := ctx.Value(traceContextKey).(TraceInfo)
	if !ok {
		return TraceInfo{}, false
	}
	return info, true
}

// TraceID extracts the trace identifier from context when present.
func TraceID(ctx context.Context) string {
	info, ok := Trace(ctx)
	if !ok {
		return ""
	}
	return info.TraceID
}

// WithCorrelationID stores the correlation identifier on the context.
func WithCorrelationID(ctx context.Context, id string) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	id = strings.TrimSpace(id)
	if id == "" {
		return ctx
	}
	return context.WithValue(ctx, correlationContextKey, id)
}

// CorrelationID retrieves the correlation identifier from context when available.
func CorrelationID(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	if id, ok := ctx.Value(correlationContextKey).(string); ok {
		return strings.TrimSpace(id)
	}
	return ""
}
