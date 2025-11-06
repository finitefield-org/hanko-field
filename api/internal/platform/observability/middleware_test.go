package observability

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"go.uber.org/zap/zaptest/observer"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/requestctx"
)

func TestInjectLoggerMiddlewareStoresLogger(t *testing.T) {
	core, recorded := observer.New(zap.InfoLevel)
	logger := zap.New(core)

	handler := InjectLoggerMiddleware(logger)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got := requestctx.Logger(r.Context())
		if got != logger {
			t.Fatalf("expected logger to be stored in context")
		}
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if len(recorded.All()) != 0 {
		t.Fatalf("unexpected logs emitted: %+v", recorded.All())
	}
}

func TestInjectLoggerMiddlewareDefaultsToNoop(t *testing.T) {
	handler := InjectLoggerMiddleware(nil)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got := requestctx.Logger(r.Context())
		if got == nil {
			t.Fatalf("expected logger to default to no-op")
		}
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)
}

func TestRequestLoggerMiddlewareEnrichesContextAndLogsLifecycle(t *testing.T) {
	core, recorded := observer.New(zap.InfoLevel)
	baseLogger := zap.New(core)

	req := httptest.NewRequest(http.MethodPost, "/orders/123?debug=true", nil)
	ctx := req.Context()
	ctx = requestctx.WithLogger(ctx, baseLogger)
	ctx = requestctx.WithTrace(ctx, requestctx.TraceInfo{TraceID: "abc123", SpanID: "def456", ProjectID: "project-1"})
	ctx = context.WithValue(ctx, middleware.RequestIDKey, "req-789")
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: " user-01\t\n"})
	req = req.WithContext(ctx)
	req.RemoteAddr = "10.0.0.15:8080"

	handler := RequestLoggerMiddleware("project-1")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		logger := requestctx.Logger(r.Context())
		if logger == baseLogger {
			t.Fatalf("expected context logger to be enriched copy")
		}
		logger.Info("handler executing")
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte("ok"))
	}))

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	entries := recorded.All()
	if len(entries) != 3 {
		t.Fatalf("expected 3 log entries (start, handler, end), got %d", len(entries))
	}

	start := entries[0]
	if start.Message != "request started" {
		t.Fatalf("expected start log message, got %q", start.Message)
	}
	startFields := contextMap(start)
	if startFields["request_id"] != "req-789" {
		t.Fatalf("expected request_id field, got %+v", startFields)
	}
	if startFields["route"] != "/orders/123" {
		t.Fatalf("expected sanitized route, got %+v", startFields)
	}
	userID, _ := startFields["user_id"].(string)
	if strings.TrimSpace(userID) != "user-01" {
		t.Fatalf("expected sanitized user id containing user-01, got %+v", startFields)
	}
	if startFields["remote_ip"] != "10.0.0.15" {
		t.Fatalf("expected sanitized remote ip, got %+v", startFields)
	}
	if traceResource := startFields["logging.googleapis.com/trace"]; traceResource != "projects/project-1/traces/abc123" {
		t.Fatalf("unexpected trace resource: %v", traceResource)
	}

	handlerLog := entries[1]
	if handlerLog.Message != "handler executing" {
		t.Fatalf("expected handler log message, got %q", handlerLog.Message)
	}
	if handlerFields := contextMap(handlerLog); handlerFields["route"] != "/orders/123" {
		t.Fatalf("expected handler log to inherit context fields")
	}

	completed := entries[2]
	if completed.Message != "request completed" {
		t.Fatalf("expected completion log message, got %q", completed.Message)
	}
	completedFields := contextMap(completed)
	if status := completedFields["status"]; status != int64(http.StatusCreated) {
		t.Fatalf("expected status 201, got %v", status)
	}
	if bytes := completedFields["bytes"]; bytes != int64(2) {
		t.Fatalf("expected bytes=2 for body, got %v", bytes)
	}
	if _, ok := completedFields["latency"]; !ok {
		t.Fatalf("expected latency field to be recorded")
	}
}

func TestRequestLoggerMiddlewareErrorsPromoteLogLevel(t *testing.T) {
	core, recorded := observer.New(zap.InfoLevel)
	baseLogger := zap.New(core)

	req := httptest.NewRequest(http.MethodGet, "/panic", nil)
	ctx := requestctx.WithLogger(req.Context(), baseLogger)
	req = req.WithContext(ctx)

	handler := RequestLoggerMiddleware("project-1")(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	}))

	defer func() {
		if rec := recover(); rec == nil {
			t.Fatalf("expected panic to propagate")
		}
	}()

	handler.ServeHTTP(httptest.NewRecorder(), req)

	entries := recorded.All()
	if len(entries) != 2 {
		t.Fatalf("expected two log entries due to panic propagation, got %d", len(entries))
	}
	if entries[1].Level.String() != "error" {
		t.Fatalf("expected completion log to be error level when panic occurs, got %s", entries[1].Level)
	}
}

func TestRecoveryMiddlewareUsesContextLogger(t *testing.T) {
	core, recorded := observer.New(zap.ErrorLevel)
	contextLogger := zap.New(core)

	handler := RecoveryMiddleware(zap.NewNop())(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("kaboom")
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req = req.WithContext(requestctx.WithLogger(req.Context(), contextLogger))
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", rr.Code)
	}

	var payload map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &payload); err != nil {
		t.Fatalf("expected JSON response: %v", err)
	}
	if payload["error"] != "internal_server_error" {
		t.Fatalf("unexpected error payload: %+v", payload)
	}

	entries := recorded.All()
	if len(entries) != 1 {
		t.Fatalf("expected single panic log entry, got %d", len(entries))
	}
	if entries[0].Message != "panic recovered" {
		t.Fatalf("expected panic message, got %q", entries[0].Message)
	}
}

func TestRecoveryMiddlewareFallsBackToProvidedLogger(t *testing.T) {
	core, recorded := observer.New(zap.ErrorLevel)
	fallback := zap.New(core)

	handler := RecoveryMiddleware(fallback)(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("explode")
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", rr.Code)
	}

	if len(recorded.All()) != 1 {
		t.Fatalf("expected panic log using fallback logger")
	}
}

func contextMap(entry observer.LoggedEntry) map[string]any {
	fields := make(map[string]any, len(entry.Context))
	for _, field := range entry.Context {
		switch field.Type {
		case zapcore.StringType:
			fields[field.Key] = field.String
		case zapcore.Int64Type:
			fields[field.Key] = field.Integer
		case zapcore.Int32Type:
			fields[field.Key] = int64(field.Integer)
		case zapcore.DurationType:
			fields[field.Key] = time.Duration(field.Integer)
		case zapcore.BoolType:
			fields[field.Key] = field.Integer == 1
		default:
			fields[field.Key] = field.Interface
		}
	}
	return fields
}
