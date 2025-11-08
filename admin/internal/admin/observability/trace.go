package observability

import (
	"context"
	"net/http"
	"strings"
)

const (
	headerRequestID = "X-Request-ID"
	headerTraceID   = "X-Hanko-Trace-ID"
)

// TraceContext captures identifiers used to correlate logs across services.
type TraceContext struct {
	RequestID string
	TraceID   string
}

type traceContextKey struct{}

var ctxTraceKey traceContextKey

// WithTrace stores the trace identifiers in context for downstream consumers.
func WithTrace(ctx context.Context, trace TraceContext) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	trace.RequestID = strings.TrimSpace(trace.RequestID)
	trace.TraceID = strings.TrimSpace(trace.TraceID)
	return context.WithValue(ctx, ctxTraceKey, trace)
}

// TraceFromContext extracts the trace identifiers from context.
func TraceFromContext(ctx context.Context) TraceContext {
	if ctx == nil {
		return TraceContext{}
	}
	if trace, ok := ctx.Value(ctxTraceKey).(TraceContext); ok {
		return trace
	}
	return TraceContext{}
}

// PropagateTraceHeaders ensures outgoing HTTP requests include correlation headers.
func PropagateTraceHeaders(ctx context.Context, req *http.Request) {
	if req == nil {
		return
	}
	trace := TraceFromContext(ctx)
	if trace.RequestID != "" && req.Header.Get(headerRequestID) == "" {
		req.Header.Set(headerRequestID, trace.RequestID)
	}
	if trace.TraceID != "" && req.Header.Get(headerTraceID) == "" {
		req.Header.Set(headerTraceID, trace.TraceID)
	}
}
