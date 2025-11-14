package middleware

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"

	"finitefield.org/hanko-admin/internal/admin/observability"
)

// RequestLogger emits structured JSON logs for each HTTP request and injects the logger into context.
func RequestLogger(logger *zap.Logger) func(http.Handler) http.Handler {
	if logger == nil {
		logger = zap.NewNop()
	}
	return func(next http.Handler) http.Handler {
		if next == nil {
			next = http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			request := r
			requestID := deriveRequestID(request)
			traceID := deriveTraceID(request, requestID)

			traceCtx := observability.TraceContext{
				RequestID: requestID,
				TraceID:   traceID,
			}
			ctx := observability.WithTrace(request.Context(), traceCtx)

			reqLogger := observability.WithRequestFields(logger,
				zap.String("request_id", requestID),
				zap.String("trace_id", traceID),
			)
			ctx = observability.WithLogger(ctx, reqLogger)

			start := time.Now()
			wrapped := chimw.NewWrapResponseWriter(w, request.ProtoMajor)
			if traceID != "" {
				wrapped.Header().Set("X-Hanko-Trace-ID", traceID)
			}
			if requestID != "" && wrapped.Header().Get("X-Request-ID") == "" {
				wrapped.Header().Set("X-Request-ID", requestID)
			}
			req := request.WithContext(ctx)
			next.ServeHTTP(wrapped, req)

			status := wrapped.Status()
			if status == 0 {
				status = http.StatusOK
			}
			duration := time.Since(start)
			route := sanitizedRoute(req.Context())

			fields := []zap.Field{
				zap.Int("status", status),
				zap.Duration("latency", duration),
				zap.String("method", req.Method),
				zap.String("route", route),
				zap.String("path", req.URL.Path),
			}

			if user, ok := UserFromContext(req.Context()); ok && user != nil && strings.TrimSpace(user.UID) != "" {
				fields = append(fields, zap.String("user_id", strings.TrimSpace(user.UID)))
			}

			if target := HTMXInfoFromContext(req.Context()); target.IsHTMX {
				fields = append(fields, zap.String("htmx_target", target.Target))
			}

			logRequest(reqLogger, levelFor(status, req.Context()), fields...)
		})
	}
}

func deriveRequestID(r *http.Request) string {
	if r == nil {
		return randomHex(16)
	}
	if header := strings.TrimSpace(r.Header.Get("X-Request-ID")); header != "" {
		return header
	}
	if id := strings.TrimSpace(chimw.GetReqID(r.Context())); id != "" {
		return id
	}
	return randomHex(16)
}

func deriveTraceID(r *http.Request, fallback string) string {
	if r != nil {
		if header := strings.TrimSpace(r.Header.Get("X-Hanko-Trace-ID")); header != "" {
			return header
		}
	}
	if fallback != "" {
		return fallback
	}
	return randomHex(16)
}

func sanitizedRoute(ctx context.Context) string {
	if ctx == nil {
		return "/"
	}
	if routeCtx := chi.RouteContext(ctx); routeCtx != nil {
		if pattern := strings.TrimSpace(routeCtx.RoutePattern()); pattern != "" {
			return pattern
		}
	}
	return "/"
}

func levelFor(status int, ctx context.Context) zapcore.Level {
	switch {
	case status >= 500:
		return zapcore.ErrorLevel
	case status >= 400:
		return zapcore.WarnLevel
	}
	if info := HTMXInfoFromContext(ctx); info.IsHTMX {
		return zapcore.DebugLevel
	}
	return zapcore.InfoLevel
}

func logRequest(logger *zap.Logger, level zapcore.Level, fields ...zap.Field) {
	switch level {
	case zapcore.DebugLevel:
		logger.Debug("request.complete", fields...)
	case zapcore.WarnLevel:
		logger.Warn("request.complete", fields...)
	case zapcore.ErrorLevel:
		logger.Error("request.failed", fields...)
	default:
		logger.Info("request.complete", fields...)
	}
}

func randomHex(size int) string {
	if size <= 0 {
		size = 16
	}
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return ""
	}
	return hex.EncodeToString(buf)
}
