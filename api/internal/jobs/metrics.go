package jobs

import (
	"context"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"
)

const metricNamespace = "github.com/hanko-field/api/internal/jobs"

// MetricsRecorder emits telemetry for processed messages.
type MetricsRecorder interface {
	Record(ctx context.Context, worker string, outcome string, duration time.Duration)
}

type otelMetrics struct {
	latency metric.Float64Histogram
	events  metric.Int64Counter
	enabled struct {
		latency bool
		events  bool
	}
}

// NewMetricsRecorder constructs an OpenTelemetry-backed metrics recorder. When
// instrumentation cannot be registered, calls become no-ops but execution
// continues.
func NewMetricsRecorder(logger *zap.Logger) MetricsRecorder {
	if logger == nil {
		logger = zap.NewNop()
	}

	meter := otel.GetMeterProvider().Meter(metricNamespace)

	latency, latencyErr := meter.Float64Histogram(
		"jobs.worker.latency",
		metric.WithUnit("ms"),
		metric.WithDescription("Latency in milliseconds for processing a background job message"),
	)
	if latencyErr != nil {
		logger.Warn("jobs metrics: failed to register latency histogram", zap.Error(latencyErr))
	}

	events, eventsErr := meter.Int64Counter(
		"jobs.worker.events",
		metric.WithDescription("Count of job worker outcomes per message"),
	)
	if eventsErr != nil {
		logger.Warn("jobs metrics: failed to register events counter", zap.Error(eventsErr))
	}

	recorder := &otelMetrics{
		latency: latency,
		events:  events,
	}
	recorder.enabled.latency = latencyErr == nil
	recorder.enabled.events = eventsErr == nil
	return recorder
}

// Record emits the measurement for the supplied outcome.
func (m *otelMetrics) Record(ctx context.Context, worker string, outcome string, duration time.Duration) {
	if m == nil {
		return
	}
	attr := attribute.NewSet(
		attribute.String("worker", sanitizeName(worker)),
		attribute.String("outcome", sanitizeOutcome(outcome)),
	)
	if m.enabled.latency {
		ms := float64(duration) / float64(time.Millisecond)
		m.latency.Record(ctx, ms, metric.WithAttributeSet(attr))
	}
	if m.enabled.events {
		m.events.Add(ctx, 1, metric.WithAttributeSet(attr))
	}
}

func sanitizeName(name string) string {
	name = strings.TrimSpace(strings.ToLower(name))
	if name == "" {
		return "unknown"
	}
	if len(name) > 48 {
		return name[:48]
	}
	return name
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
