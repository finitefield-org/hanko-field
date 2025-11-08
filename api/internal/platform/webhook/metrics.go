package webhook

import (
	"context"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"
)

const metricNamespace = "github.com/hanko-field/api/internal/platform/webhook"

// MetricsRecorder captures webhook security outcomes for observability.
type MetricsRecorder interface {
	Record(ctx context.Context, outcome string, duration time.Duration)
}

type metricsRecorder struct {
	requests        metric.Int64Counter
	requestsEnabled bool
	latency         metric.Float64Histogram
	latencyEnabled  bool
}

// NewMetricsRecorder builds an OpenTelemetry-backed metrics recorder.
func NewMetricsRecorder(logger *zap.Logger) MetricsRecorder {
	if logger == nil {
		logger = zap.NewNop()
	}

	meter := otel.GetMeterProvider().Meter(metricNamespace)
	latency, latencyErr := meter.Float64Histogram(
		"webhooks.security.latency",
		metric.WithUnit("ms"),
		metric.WithDescription("Latency in milliseconds for webhook security middleware execution"),
	)
	if latencyErr != nil {
		logger.Warn("webhook metrics: unable to register latency histogram", zap.Error(latencyErr))
	}

	requests, requestsErr := meter.Int64Counter(
		"webhooks.security.requests",
		metric.WithDescription("Count of webhook security middleware outcomes"),
	)
	if requestsErr != nil {
		logger.Warn("webhook metrics: unable to register request counter", zap.Error(requestsErr))
	}

	return &metricsRecorder{
		requests:        requests,
		requestsEnabled: requestsErr == nil,
		latency:         latency,
		latencyEnabled:  latencyErr == nil,
	}
}

// Record emits metrics for the processed webhook request.
func (m *metricsRecorder) Record(ctx context.Context, outcome string, duration time.Duration) {
	if m == nil {
		return
	}
	attr := metric.WithAttributes(attribute.String("outcome", sanitizeOutcome(outcome)))
	if m.latencyEnabled {
		ms := float64(duration) / float64(time.Millisecond)
		m.latency.Record(ctx, ms, attr)
	}
	if m.requestsEnabled {
		m.requests.Add(ctx, 1, attr)
	}
}

func sanitizeOutcome(outcome string) string {
	outcome = strings.TrimSpace(strings.ToLower(outcome))
	if outcome == "" {
		return "unknown"
	}
	if len(outcome) > 48 {
		return outcome[:48]
	}
	return outcome
}
