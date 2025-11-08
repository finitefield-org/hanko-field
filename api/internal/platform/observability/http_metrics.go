package observability

import (
	"context"
	"net/http"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"
)

const httpMetricNamespace = "github.com/hanko-field/api/internal/platform/observability/http"

// HTTPMetricsRecorder captures HTTP measurements for observability.
type HTTPMetricsRecorder interface {
	Record(ctx context.Context, method, route string, status int, latency time.Duration)
}

// HTTPMetricsMiddleware measures HTTP latency and status outcomes for incoming requests.
func HTTPMetricsMiddleware(recorder HTTPMetricsRecorder) func(http.Handler) http.Handler {
	if recorder == nil {
		recorder = noopHTTPMetrics{}
	}
	return func(next http.Handler) http.Handler {
		if next == nil {
			next = http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := newResponseRecorder(w)
			next.ServeHTTP(rec, r)

			method := r.Method
			route := routePattern(r)
			status := rec.Status()
			recorder.Record(r.Context(), method, route, status, time.Since(start))
		})
	}
}

// NewHTTPMetrics constructs OpenTelemetry-backed HTTP metrics.
func NewHTTPMetrics(logger *zap.Logger) HTTPMetricsRecorder {
	if logger == nil {
		logger = zap.NewNop()
	}

	meter := otel.GetMeterProvider().Meter(httpMetricNamespace)

	latency, latencyErr := meter.Float64Histogram(
		"http.server.latency",
		metric.WithUnit("ms"),
		metric.WithDescription("End-to-end HTTP server latency in milliseconds"),
	)
	if latencyErr != nil {
		logger.Warn("http metrics: failed to create latency histogram", zap.Error(latencyErr))
	}

	requests, requestsErr := meter.Int64Counter(
		"http.server.requests",
		metric.WithDescription("HTTP server request count partitioned by method, route, and status code"),
	)
	if requestsErr != nil {
		logger.Warn("http metrics: failed to create requests counter", zap.Error(requestsErr))
	}

	errorsMetric, errorsErr := meter.Int64Counter(
		"http.server.errors",
		metric.WithDescription("HTTP server error count partitioned by method, route, and error class"),
	)
	if errorsErr != nil {
		logger.Warn("http metrics: failed to create errors counter", zap.Error(errorsErr))
	}

	if latencyErr != nil && requestsErr != nil && errorsErr != nil {
		return noopHTTPMetrics{}
	}

	recorder := &httpMetrics{
		latency:  latency,
		requests: requests,
		errors:   errorsMetric,
	}
	recorder.enabled.latency = latencyErr == nil
	recorder.enabled.requests = requestsErr == nil
	recorder.enabled.errors = errorsErr == nil
	return recorder
}

type httpMetrics struct {
	latency  metric.Float64Histogram
	requests metric.Int64Counter
	errors   metric.Int64Counter
	enabled  struct {
		latency  bool
		requests bool
		errors   bool
	}
}

func (m *httpMetrics) Record(ctx context.Context, method, route string, status int, latency time.Duration) {
	if m == nil {
		return
	}

	method = SanitizeMethod(method)
	route = SanitizeRoute(route)
	statusClass := httpStatusClass(status)

	attrSet := attribute.NewSet(
		attribute.String("http.method", method),
		attribute.String("http.route", route),
		attribute.Int64("http.status_code", int64(status)),
		attribute.String("http.status_class", statusClass),
	)

	if m.enabled.latency {
		ms := float64(latency) / float64(time.Millisecond)
		if ms < 0 {
			ms = 0
		}
		m.latency.Record(ctx, ms, metric.WithAttributeSet(attrSet))
	}
	if m.enabled.requests {
		m.requests.Add(ctx, 1, metric.WithAttributeSet(attrSet))
	}
	if m.enabled.errors && status >= http.StatusBadRequest {
		errorAttrs := attribute.NewSet(
			attribute.String("http.method", method),
			attribute.String("http.route", route),
			attribute.Int64("http.status_code", int64(status)),
			attribute.String("error.type", errorTypeForStatus(status)),
			attribute.String("http.status_class", statusClass),
		)
		m.errors.Add(ctx, 1, metric.WithAttributeSet(errorAttrs))
	}
}

type noopHTTPMetrics struct{}

func (noopHTTPMetrics) Record(context.Context, string, string, int, time.Duration) {}

func httpStatusClass(status int) string {
	switch {
	case status >= 100 && status < 200:
		return "1xx"
	case status >= 200 && status < 300:
		return "2xx"
	case status >= 300 && status < 400:
		return "3xx"
	case status >= 400 && status < 500:
		return "4xx"
	case status >= 500 && status < 600:
		return "5xx"
	default:
		return "unknown"
	}
}

func errorTypeForStatus(status int) string {
	switch {
	case status >= http.StatusInternalServerError:
		return "server_error"
	case status >= http.StatusBadRequest:
		return "client_error"
	default:
		return "none"
	}
}
