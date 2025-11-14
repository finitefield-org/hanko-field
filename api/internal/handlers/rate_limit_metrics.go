package handlers

import (
	"context"
	"strings"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"
)

const (
	rateLimitScopeUser      = "user"
	rateLimitScopeIP        = "ip"
	rateLimitScopeAnonymous = "anonymous"
)

// RateLimitMetrics records throttled requests for observability.
type RateLimitMetrics interface {
	Record(ctx context.Context, endpoint, scope string)
}

type noopRateLimitMetrics struct{}

func (noopRateLimitMetrics) Record(context.Context, string, string) {}

type otelRateLimitMetrics struct {
	counter metric.Int64Counter
	enabled bool
}

func (m *otelRateLimitMetrics) Record(ctx context.Context, endpoint, scope string) {
	if m == nil || !m.enabled {
		return
	}
	attrs := make([]attribute.KeyValue, 0, 2)
	if endpoint = strings.TrimSpace(endpoint); endpoint != "" {
		attrs = append(attrs, attribute.String("endpoint", endpoint))
	}
	if scope = strings.TrimSpace(scope); scope != "" {
		attrs = append(attrs, attribute.String("scope", scope))
	}
	m.counter.Add(ctx, 1, metric.WithAttributes(attrs...))
}

// NewRateLimitMetrics registers an OpenTelemetry counter for throttled requests.
func NewRateLimitMetrics(logger *zap.Logger) RateLimitMetrics {
	meter := otel.GetMeterProvider().Meter("github.com/hanko-field/api/internal/handlers/rate_limit")
	counter, err := meter.Int64Counter(
		"security.rate_limit.throttled",
		metric.WithDescription("Count of requests dropped by application-level rate limiting"),
	)
	if err != nil {
		if logger != nil {
			logger.Warn("rate limit metrics disabled", zap.Error(err))
		}
		return noopRateLimitMetrics{}
	}
	return &otelRateLimitMetrics{counter: counter, enabled: true}
}
