package observability

import (
	"context"
	"fmt"
	"strings"
	"time"

	metricexporter "github.com/GoogleCloudPlatform/opentelemetry-operations-go/exporter/metric"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

const (
	defaultMetricsInterval = time.Minute
	defaultServiceName     = "hanko-field-api"
)

// MetricsOptions configure the OpenTelemetry meter provider.
type MetricsOptions struct {
	ProjectID          string
	ServiceName        string
	ServiceVersion     string
	Environment        string
	CollectionInterval time.Duration
}

// InitMetrics wires the Cloud Monitoring exporter and sets the global meter provider.
func InitMetrics(ctx context.Context, opts MetricsOptions) (func(context.Context) error, error) {
	projectID := strings.TrimSpace(opts.ProjectID)
	if projectID == "" {
		return func(context.Context) error { return nil }, nil
	}
	if ctx == nil {
		ctx = context.Background()
	}

	interval := opts.CollectionInterval
	if interval <= 0 {
		interval = defaultMetricsInterval
	}

	env := strings.TrimSpace(opts.Environment)
	if env == "" {
		env = "local"
	}
	serviceName := strings.TrimSpace(opts.ServiceName)
	if serviceName == "" {
		serviceName = defaultServiceName
	}
	serviceVersion := strings.TrimSpace(opts.ServiceVersion)
	if serviceVersion == "" {
		serviceVersion = "dev"
	}

	res, err := resource.New(ctx,
		resource.WithTelemetrySDK(),
		resource.WithHost(),
		resource.WithProcess(),
		resource.WithOS(),
		resource.WithAttributes(
			semconv.ServiceNameKey.String(serviceName),
			semconv.ServiceVersionKey.String(serviceVersion),
			semconv.DeploymentEnvironmentKey.String(env),
			attribute.String("gcp.project_id", projectID),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("metrics resource: %w", err)
	}

	exporter, err := metricexporter.New(metricexporter.WithProjectID(projectID))
	if err != nil {
		return nil, fmt.Errorf("metrics exporter: %w", err)
	}

	reader := sdkmetric.NewPeriodicReader(exporter, sdkmetric.WithInterval(interval))
	provider := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(reader),
		sdkmetric.WithResource(res),
	)
	otel.SetMeterProvider(provider)

	return provider.Shutdown, nil
}
