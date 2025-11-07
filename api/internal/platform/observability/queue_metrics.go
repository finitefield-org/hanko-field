package observability

import (
	"context"
	"strings"
	"sync"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/services"
)

const (
	queueMetricNamespace   = "github.com/hanko-field/api/internal/services/production_queue"
	queueDepthMetricName   = "operations.production_queue.depth"
	queueDepthStatusAttr   = "queue.status"
	queueDepthQueueIDAttr  = "queue.id"
	queueDepthStalenessTTL = 5 * time.Minute
)

// NewQueueDepthMetrics exposes production queue depth snapshots as observable gauges.
func NewQueueDepthMetrics(logger *zap.Logger) services.QueueDepthRecorder {
	if logger == nil {
		logger = zap.NewNop()
	}
	meter := otel.GetMeterProvider().Meter(queueMetricNamespace)
	gauge, err := meter.Int64ObservableGauge(
		queueDepthMetricName,
		metric.WithDescription("Production queue depth per status"),
		metric.WithUnit("{work_items}"),
	)
	if err != nil {
		logger.Warn("queue metrics: failed to register depth gauge", zap.Error(err))
		return services.QueueDepthRecorderFunc(func(context.Context, string, int, map[string]int) {})
	}

	recorder := &queueDepthMetrics{
		logger:    logger,
		gauge:     gauge,
		snapshots: make(map[string]queueDepthSnapshot),
	}
	if _, err := meter.RegisterCallback(recorder.observe, gauge); err != nil {
		logger.Warn("queue metrics: failed to register gauge callback", zap.Error(err))
		return services.QueueDepthRecorderFunc(func(context.Context, string, int, map[string]int) {})
	}
	return recorder
}

type queueDepthMetrics struct {
	logger    *zap.Logger
	gauge     metric.Int64ObservableGauge
	mu        sync.Mutex
	snapshots map[string]queueDepthSnapshot
}

type queueDepthSnapshot struct {
	total    int64
	statuses map[string]int64
	updated  time.Time
}

func (m *queueDepthMetrics) RecordQueueDepth(_ context.Context, queueID string, total int, statusCounts map[string]int) {
	if m == nil {
		return
	}
	queueID = sanitizeQueueIdentifier(queueID)
	if queueID == "" {
		return
	}
	if total < 0 {
		total = 0
	}

	statuses := make(map[string]int64, len(statusCounts))
	for status, count := range statusCounts {
		key := sanitizeQueueStatus(status)
		if key == "" {
			continue
		}
		if count < 0 {
			count = 0
		}
		statuses[key] = int64(count)
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	m.snapshots[queueID] = queueDepthSnapshot{
		total:    int64(total),
		statuses: statuses,
		updated:  time.Now(),
	}
}

func (m *queueDepthMetrics) observe(_ context.Context, observer metric.Observer) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	cutoff := time.Now().Add(-queueDepthStalenessTTL)
	for queueID, snapshot := range m.snapshots {
		if snapshot.updated.Before(cutoff) {
			delete(m.snapshots, queueID)
			continue
		}

		baseAttrs := []attribute.KeyValue{
			attribute.String(queueDepthQueueIDAttr, queueID),
		}
		observer.ObserveInt64(m.gauge, snapshot.total,
			metric.WithAttributes(append(baseAttrs, attribute.String(queueDepthStatusAttr, "total"))...),
		)
		for status, count := range snapshot.statuses {
			observer.ObserveInt64(m.gauge, count,
				metric.WithAttributes(append(baseAttrs, attribute.String(queueDepthStatusAttr, status))...),
			)
		}
	}
	return nil
}

func sanitizeQueueIdentifier(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	return sanitizeString(value, 80)
}

func sanitizeQueueStatus(value string) string {
	value = strings.TrimSpace(strings.ToLower(strings.ReplaceAll(value, " ", "_")))
	if value == "" {
		return ""
	}
	return sanitizeString(value, 48)
}
