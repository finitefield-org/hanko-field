package webhook

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"go.uber.org/zap/zaptest/observer"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/requestctx"
)

func TestSecurityMiddlewareBlocksUnauthorizedIP(t *testing.T) {
	_, network, err := net.ParseCIDR("10.0.0.0/24")
	if err != nil {
		t.Fatalf("failed to parse cidr: %v", err)
	}

	core, logs := observer.New(zap.WarnLevel)
	logger := zap.New(core)

	now := time.Date(2025, 1, 1, 10, 0, 0, 0, time.UTC)
	clock := func() time.Time { return now }
	metrics := &recordingMetrics{}

	cfg := SecurityConfig{
		AllowedNetworks: []*net.IPNet{network},
		ReplayStore:     NewInMemoryReplayStore(WithReplayClock(clock)),
		ReplayTTL:       time.Minute,
		Logger:          logger,
		Metrics:         metrics,
		Clock:           clock,
	}

	called := false
	handler := NewSecurityMiddleware(cfg)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodPost, "/webhooks/test", nil)
	req.RemoteAddr = "203.0.113.10:443"
	ctx := requestctx.WithLogger(req.Context(), logger)
	req = req.WithContext(ctx)

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected status 403, got %d", rec.Code)
	}
	if called {
		t.Fatalf("expected handler not to be called")
	}
	if logs.Len() == 0 {
		t.Fatalf("expected log entry for blocked ip")
	}
	entry := logs.All()[0]
	if entry.Message != "webhook blocked: source ip not allowed" {
		t.Fatalf("unexpected log message %q", entry.Message)
	}
	if _, ok := entry.ContextMap()["remote_ip"]; !ok {
		t.Fatalf("expected remote_ip field in log")
	}
	if !metrics.contains("blocked_ip") {
		t.Fatalf("expected metrics to record blocked_ip outcome, got %v", metrics.outcomes())
	}
}

func TestSecurityMiddlewareDetectsReplay(t *testing.T) {
	now := time.Date(2025, 1, 2, 9, 30, 0, 0, time.UTC)
	clock := func() time.Time { return now }

	core, logs := observer.New(zapcore.DebugLevel)
	logger := zap.New(core)
	metrics := &recordingMetrics{}
	store := NewInMemoryReplayStore(WithReplayClock(clock))

	cfg := SecurityConfig{
		ReplayStore: store,
		ReplayTTL:   time.Minute,
		Logger:      logger,
		Metrics:     metrics,
		Clock:       clock,
	}

	handler := NewSecurityMiddleware(cfg)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusAccepted)
	}))

	baseCtx := requestctx.WithLogger(context.Background(), logger)
	metaCtx := auth.WithHMACMetadata(baseCtx, &auth.HMACMetadata{
		RawSignature: "signature-123",
		Timestamp:    now,
	})

	req := httptest.NewRequest(http.MethodPost, "/webhooks/payments/stripe", nil)
	req = req.WithContext(metaCtx)

	rec1 := httptest.NewRecorder()
	handler.ServeHTTP(rec1, req)

	if rec1.Code != http.StatusAccepted {
		t.Fatalf("expected status 202 for first request, got %d", rec1.Code)
	}

	rec2 := httptest.NewRecorder()
	handler.ServeHTTP(rec2, req.Clone(metaCtx))

	if rec2.Code != http.StatusConflict {
		t.Fatalf("expected status 409 for replay, got %d", rec2.Code)
	}

	if !metrics.contains("replay_detected") {
		t.Fatalf("expected replay_detected outcome in metrics, got %v", metrics.outcomes())
	}

	if logs.FilterMessage("webhook blocked: replay detected").Len() == 0 {
		t.Fatalf("expected replay detected log entry")
	}
}

type recordingMetrics struct {
	outcomesLog []string
}

func (m *recordingMetrics) Record(_ context.Context, outcome string, _ time.Duration) {
	m.outcomesLog = append(m.outcomesLog, outcome)
}

func (m *recordingMetrics) contains(outcome string) bool {
	for _, recorded := range m.outcomesLog {
		if recorded == outcome {
			return true
		}
	}
	return false
}

func (m *recordingMetrics) outcomes() []string {
	return append([]string(nil), m.outcomesLog...)
}
