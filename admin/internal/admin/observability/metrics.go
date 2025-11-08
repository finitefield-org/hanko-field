package observability

import (
	"context"
	"log"
	"strings"
	"time"

	gcpmetric "github.com/GoogleCloudPlatform/opentelemetry-operations-go/exporter/metric"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

const (
	defaultServiceName    = "hanko-admin"
	defaultMeterName      = "finitefield.org/hanko-admin/admin"
	defaultExportInterval = 60 * time.Second
)

// RequestKind differentiates full page renders from htmx fragment calls.
type RequestKind string

// MutationResult captures the high-level outcome for mutation handlers.
type MutationResult string

const (
	// RequestKindPage represents classic full-page navigations.
	RequestKindPage RequestKind = "page"
	// RequestKindFragment represents htmx fragment fetches.
	RequestKindFragment RequestKind = "fragment"
	// RequestKindUnknown is used when the request type cannot be inferred.
	RequestKindUnknown RequestKind = "unknown"

	// MutationResultSuccess indicates the mutation succeeded.
	MutationResultSuccess MutationResult = "success"
	// MutationResultValidationError indicates validation failed client-side/server-side.
	MutationResultValidationError MutationResult = "validation_error"
	// MutationResultInvalidRequest indicates the request could not be parsed or was malformed.
	MutationResultInvalidRequest MutationResult = "invalid_request"
	// MutationResultBackendError indicates downstream dependencies failed.
	MutationResultBackendError MutationResult = "backend_error"
	// MutationResultUnauthorized indicates the user was not authenticated/authorised.
	MutationResultUnauthorized MutationResult = "unauthorized"
	// MutationResultNotFound indicates the target entity was not found/visible.
	MutationResultNotFound MutationResult = "not_found"
)

// Config controls metric exporter initialisation.
type Config struct {
	Enabled        bool
	ProjectID      string
	ServiceName    string
	ServiceVersion string
	Environment    string
	ExportInterval time.Duration
}

// Metrics exposes helpers for recording admin observability signals.
type Metrics struct {
	enabled bool

	shutdown func(context.Context) error

	httpDuration           metric.Float64Histogram
	pageRenderDuration     metric.Float64Histogram
	fragmentRenderDuration metric.Float64Histogram
	httpErrors             metric.Int64Counter
	orderStatusChanges     metric.Int64Counter
	promotionsCreated      metric.Int64Counter

	defaultAttrs []attribute.KeyValue

	httpDurationOK      bool
	pageDurationOK      bool
	fragmentDurationOK  bool
	httpErrorsOK        bool
	orderStatusChangeOK bool
	promotionsCreatedOK bool
}

// HTTPRequestAttributes captures metadata required for request metrics.
type HTTPRequestAttributes struct {
	Method         string
	Route          string
	Status         int
	Kind           RequestKind
	FragmentTarget string
}

// NewMetrics configures the OpenTelemetry meter provider and Cloud Monitoring exporter.
func NewMetrics(ctx context.Context, cfg Config) (*Metrics, error) {
	cfg = cfg.applyDefaults()

	if !cfg.Enabled {
		return &Metrics{}, nil
	}

	exporter, err := gcpmetric.New(gcpmetric.WithProjectID(cfg.ProjectID))
	if err != nil {
		return nil, err
	}

	res, err := resource.New(ctx,
		resource.WithFromEnv(),
		resource.WithProcess(),
		resource.WithOS(),
		resource.WithContainer(),
		resource.WithAttributes(cfg.resourceAttributes()...),
	)
	if err != nil {
		return nil, err
	}

	reader := sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(cfg.ExportInterval))
	provider := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(reader),
		sdkmetric.WithResource(res),
	)
	otel.SetMeterProvider(provider)

	meter := provider.Meter(defaultMeterName)

	metrics := &Metrics{
		enabled:      true,
		shutdown:     provider.Shutdown,
		defaultAttrs: cfg.defaultAttributes(),
	}

	if hist, err := meter.Float64Histogram(
		"admin.http.request.duration",
		metric.WithUnit("ms"),
		metric.WithDescription("Total server-side latency for admin HTTP requests"),
	); err == nil {
		metrics.httpDuration = hist
		metrics.httpDurationOK = true
	} else {
		log.Printf("metrics: failed to register http request duration histogram: %v", err)
	}

	if hist, err := meter.Float64Histogram(
		"admin.http.page_render.duration",
		metric.WithUnit("ms"),
		metric.WithDescription("Latency for rendered admin page responses"),
	); err == nil {
		metrics.pageRenderDuration = hist
		metrics.pageDurationOK = true
	} else {
		log.Printf("metrics: failed to register page render histogram: %v", err)
	}

	if hist, err := meter.Float64Histogram(
		"admin.http.fragment.duration",
		metric.WithUnit("ms"),
		metric.WithDescription("Latency for htmx fragment responses"),
	); err == nil {
		metrics.fragmentRenderDuration = hist
		metrics.fragmentDurationOK = true
	} else {
		log.Printf("metrics: failed to register fragment histogram: %v", err)
	}

	if counter, err := meter.Int64Counter(
		"admin.http.errors",
		metric.WithDescription("Count of HTTP requests returning error responses"),
	); err == nil {
		metrics.httpErrors = counter
		metrics.httpErrorsOK = true
	} else {
		log.Printf("metrics: failed to register http error counter: %v", err)
	}

	if counter, err := meter.Int64Counter(
		"admin.orders.status_change.count",
		metric.WithDescription("Count of order status change submissions"),
	); err == nil {
		metrics.orderStatusChanges = counter
		metrics.orderStatusChangeOK = true
	} else {
		log.Printf("metrics: failed to register order status change counter: %v", err)
	}

	if counter, err := meter.Int64Counter(
		"admin.promotions.created.count",
		metric.WithDescription("Count of promotion create submissions"),
	); err == nil {
		metrics.promotionsCreated = counter
		metrics.promotionsCreatedOK = true
	} else {
		log.Printf("metrics: failed to register promotion create counter: %v", err)
	}

	return metrics, nil
}

// Enabled reports whether metrics recording is active.
func (m *Metrics) Enabled() bool {
	return m != nil && m.enabled
}

// Shutdown flushes pending metric exports.
func (m *Metrics) Shutdown(ctx context.Context) error {
	if m == nil || m.shutdown == nil {
		return nil
	}
	return m.shutdown(ctx)
}

// RecordHTTPRequest publishes latency/error metrics for HTTP handlers.
func (m *Metrics) RecordHTTPRequest(ctx context.Context, attrs HTTPRequestAttributes, duration time.Duration) {
	if !m.Enabled() {
		return
	}
	recordAttrs := m.httpAttributes(attrs)
	latencyMs := float64(duration) / float64(time.Millisecond)
	if m.httpDurationOK {
		m.httpDuration.Record(ctx, latencyMs, metric.WithAttributes(recordAttrs...))
	}
	switch attrs.Kind {
	case RequestKindFragment:
		if m.fragmentDurationOK {
			m.fragmentRenderDuration.Record(ctx, latencyMs, metric.WithAttributes(recordAttrs...))
		}
	case RequestKindPage:
		if m.pageDurationOK {
			m.pageRenderDuration.Record(ctx, latencyMs, metric.WithAttributes(recordAttrs...))
		}
	default:
		// fallthrough to avoid branching when kind unknown
	}
	if attrs.Status >= 500 && m.httpErrorsOK {
		m.httpErrors.Add(ctx, 1, metric.WithAttributes(recordAttrs...))
	}
}

// RecordOrderStatusChange increments the key event counter.
func (m *Metrics) RecordOrderStatusChange(ctx context.Context, nextStatus string, result MutationResult) {
	if !m.Enabled() || !m.orderStatusChangeOK {
		return
	}
	status := sanitizeLabel(nextStatus)
	resultVal := sanitizeMutationResult(result)
	attrs := m.copyDefaultAttrs()
	if status != "" {
		attrs = append(attrs, attribute.String("order.status", status))
	}
	attrs = append(attrs, attribute.String("result", resultVal))
	m.orderStatusChanges.Add(ctx, 1, metric.WithAttributes(attrs...))
}

// RecordPromotionCreated increments the promotion creation counter.
func (m *Metrics) RecordPromotionCreated(ctx context.Context, result MutationResult) {
	if !m.Enabled() || !m.promotionsCreatedOK {
		return
	}
	attrs := m.copyDefaultAttrs()
	attrs = append(attrs, attribute.String("result", sanitizeMutationResult(result)))
	m.promotionsCreated.Add(ctx, 1, metric.WithAttributes(attrs...))
}

func (m *Metrics) httpAttributes(attrs HTTPRequestAttributes) []attribute.KeyValue {
	method := strings.ToUpper(strings.TrimSpace(attrs.Method))
	route := sanitizeRoute(attrs.Route)
	target := sanitizeLabel(attrs.FragmentTarget)
	kind := attrs.Kind
	if kind == "" {
		kind = RequestKindUnknown
	}

	recordAttrs := m.copyDefaultAttrs()
	if method != "" {
		recordAttrs = append(recordAttrs, attribute.String("http.method", method))
	}
	if route != "" {
		recordAttrs = append(recordAttrs, attribute.String("endpoint", route))
	}
	if attrs.Status > 0 {
		recordAttrs = append(recordAttrs, attribute.Int("http.status_code", attrs.Status))
	}
	recordAttrs = append(recordAttrs, attribute.String("request.kind", string(kind)))
	if target != "" {
		recordAttrs = append(recordAttrs, attribute.String("htmx.target", target))
	}
	return recordAttrs
}

func (m *Metrics) copyDefaultAttrs() []attribute.KeyValue {
	if len(m.defaultAttrs) == 0 {
		return nil
	}
	out := make([]attribute.KeyValue, len(m.defaultAttrs))
	copy(out, m.defaultAttrs)
	return out
}

func (cfg Config) applyDefaults() Config {
	cfg.ProjectID = strings.TrimSpace(cfg.ProjectID)
	cfg.ServiceName = strings.TrimSpace(cfg.ServiceName)
	if cfg.ServiceName == "" {
		cfg.ServiceName = defaultServiceName
	}
	cfg.ServiceVersion = strings.TrimSpace(cfg.ServiceVersion)
	cfg.Environment = strings.TrimSpace(cfg.Environment)
	if cfg.ExportInterval <= 0 {
		cfg.ExportInterval = defaultExportInterval
	}
	if !cfg.Enabled {
		return cfg
	}
	if cfg.ProjectID == "" {
		log.Printf("metrics: disabling exporter because project ID is not set")
		cfg.Enabled = false
	}
	return cfg
}

func (cfg Config) resourceAttributes() []attribute.KeyValue {
	attrs := []attribute.KeyValue{
		semconv.ServiceName(cfg.ServiceName),
	}
	if cfg.ServiceVersion != "" {
		attrs = append(attrs, semconv.ServiceVersion(cfg.ServiceVersion))
	}
	if cfg.Environment != "" {
		attrs = append(attrs, attribute.String("deployment.environment", cfg.Environment))
	}
	return attrs
}

func (cfg Config) defaultAttributes() []attribute.KeyValue {
	if cfg.Environment == "" {
		return nil
	}
	return []attribute.KeyValue{
		attribute.String("environment", cfg.Environment),
	}
}

func sanitizeRoute(route string) string {
	route = strings.TrimSpace(route)
	if route == "" {
		return "/"
	}
	if !strings.HasPrefix(route, "/") {
		route = "/" + route
	}
	return route
}

func sanitizeLabel(value string) string {
	return strings.TrimSpace(value)
}

func sanitizeMutationResult(result MutationResult) string {
	val := strings.TrimSpace(string(result))
	if val == "" {
		return string(MutationResultBackendError)
	}
	return val
}
