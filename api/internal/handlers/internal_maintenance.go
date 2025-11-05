package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/platform/observability"
	"github.com/hanko-field/api/internal/services"
)

const (
	maxMaintenanceCleanupBodySize = 4 * 1024
	defaultCleanupActorID         = "system:maintenance"
	defaultCleanupReason          = "expired_maintenance_cleanup"
)

// InternalMaintenanceHandlers exposes maintenance utilities for internal consumers.
type InternalMaintenanceHandlers struct {
	inventory services.InventoryService
	metrics   MaintenanceCleanupMetrics
	maxBody   int64

	defaultActorID string
	defaultReason  string
}

// InternalMaintenanceOption configures InternalMaintenanceHandlers behaviour during construction.
type InternalMaintenanceOption func(*InternalMaintenanceHandlers)

// MaintenanceCleanupMetrics records maintenance cleanup outcomes for observability.
type MaintenanceCleanupMetrics interface {
	RecordRun(ctx context.Context, checked, released, alreadyReleased, skipped int)
	RecordFailure(ctx context.Context, code string)
}

type noopMaintenanceCleanupMetrics struct{}

func (noopMaintenanceCleanupMetrics) RecordRun(context.Context, int, int, int, int) {}
func (noopMaintenanceCleanupMetrics) RecordFailure(context.Context, string)         {}

type maintenanceCleanupMetrics struct {
	runs            metric.Int64Counter
	checked         metric.Int64Counter
	released        metric.Int64Counter
	failures        metric.Int64Counter
	runsEnabled     bool
	checkedEnabled  bool
	releasedEnabled bool
	failuresEnabled bool
}

// RecordRun captures the reservation cleanup results for the current invocation.
func (m *maintenanceCleanupMetrics) RecordRun(ctx context.Context, checked, released, alreadyReleased, skipped int) {
	if m == nil {
		return
	}
	if m.runsEnabled {
		m.runs.Add(ctx, 1)
	}
	if m.checkedEnabled && checked > 0 {
		m.checked.Add(ctx, int64(checked))
	}
	if m.releasedEnabled {
		total := released
		if alreadyReleased > 0 {
			total += alreadyReleased
		}
		if skipped > 0 {
			total += skipped
		}
		if total > 0 {
			m.released.Add(ctx, int64(total))
		}
	}
}

// RecordFailure notes failures encountered while attempting cleanup.
func (m *maintenanceCleanupMetrics) RecordFailure(ctx context.Context, code string) {
	if m == nil || !m.failuresEnabled {
		return
	}
	attrs := []attribute.KeyValue{}
	if trimmed := strings.TrimSpace(code); trimmed != "" {
		attrs = append(attrs, attribute.String("code", trimmed))
	}
	m.failures.Add(ctx, 1, metric.WithAttributes(attrs...))
}

// NewMaintenanceCleanupMetrics constructs OpenTelemetry-backed metrics for maintenance cleanup runs.
func NewMaintenanceCleanupMetrics(logger *zap.Logger) MaintenanceCleanupMetrics {
	meter := otel.GetMeterProvider().Meter("github.com/hanko-field/api/internal/handlers/internal_maintenance")

	runsCounter, runsErr := meter.Int64Counter(
		"maintenance.cleanup.runs",
		metric.WithDescription("Count of maintenance cleanup invocations"),
	)
	checkedCounter, checkedErr := meter.Int64Counter(
		"maintenance.cleanup.checked",
		metric.WithDescription("Count of reservations evaluated during cleanup"),
	)
	releasedCounter, releasedErr := meter.Int64Counter(
		"maintenance.cleanup.processed",
		metric.WithDescription("Count of reservations processed (released, already released, skipped)"),
	)
	failuresCounter, failuresErr := meter.Int64Counter(
		"maintenance.cleanup.failures",
		metric.WithDescription("Count of maintenance cleanup failures"),
	)

	if logger == nil {
		logger = zap.NewNop()
	}

	recorder := &maintenanceCleanupMetrics{}
	if runsErr != nil {
		logger.Warn("maintenance metrics: unable to register runs counter", zap.Error(runsErr))
	} else {
		recorder.runs = runsCounter
		recorder.runsEnabled = true
	}

	if checkedErr != nil {
		logger.Warn("maintenance metrics: unable to register checked counter", zap.Error(checkedErr))
	} else {
		recorder.checked = checkedCounter
		recorder.checkedEnabled = true
	}

	if releasedErr != nil {
		logger.Warn("maintenance metrics: unable to register processed counter", zap.Error(releasedErr))
	} else {
		recorder.released = releasedCounter
		recorder.releasedEnabled = true
	}

	if failuresErr != nil {
		logger.Warn("maintenance metrics: unable to register failure counter", zap.Error(failuresErr))
	} else {
		recorder.failures = failuresCounter
		recorder.failuresEnabled = true
	}

	if !recorder.runsEnabled && !recorder.checkedEnabled && !recorder.releasedEnabled && !recorder.failuresEnabled {
		return noopMaintenanceCleanupMetrics{}
	}
	return recorder
}

// WithMaintenanceMetrics configures the metrics recorder used by maintenance handlers.
func WithMaintenanceMetrics(metrics MaintenanceCleanupMetrics) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if metrics != nil {
			h.metrics = metrics
		}
	}
}

// WithMaintenanceDefaults customises default actor and reason values applied when omitted from requests.
func WithMaintenanceDefaults(actorID, reason string) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if trimmed := strings.TrimSpace(actorID); trimmed != "" {
			h.defaultActorID = trimmed
		}
		if trimmed := strings.TrimSpace(reason); trimmed != "" {
			h.defaultReason = trimmed
		}
	}
}

// WithMaintenanceBodyLimit overrides the maximum accepted request body size.
func WithMaintenanceBodyLimit(limit int64) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if limit > 0 {
			h.maxBody = limit
		}
	}
}

// NewInternalMaintenanceHandlers wires dependencies for maintenance endpoints.
func NewInternalMaintenanceHandlers(inventory services.InventoryService, opts ...InternalMaintenanceOption) *InternalMaintenanceHandlers {
	handler := &InternalMaintenanceHandlers{
		inventory:      inventory,
		metrics:        noopMaintenanceCleanupMetrics{},
		maxBody:        maxMaintenanceCleanupBodySize,
		defaultActorID: defaultCleanupActorID,
		defaultReason:  defaultCleanupReason,
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	if handler.metrics == nil {
		handler.metrics = noopMaintenanceCleanupMetrics{}
	}
	if handler.maxBody <= 0 {
		handler.maxBody = maxMaintenanceCleanupBodySize
	}
	if strings.TrimSpace(handler.defaultActorID) == "" {
		handler.defaultActorID = defaultCleanupActorID
	}
	if strings.TrimSpace(handler.defaultReason) == "" {
		handler.defaultReason = defaultCleanupReason
	}
	return handler
}

// Routes registers internal maintenance endpoints.
func (h *InternalMaintenanceHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/maintenance/cleanup-reservations", h.cleanupReservations)
}

type internalMaintenanceCleanupRequest struct {
	Limit   *int   `json:"limit,omitempty"`
	Reason  string `json:"reason,omitempty"`
	ActorID string `json:"actorId,omitempty"`
}

type internalMaintenanceCleanupResponse struct {
	CheckedCount         int      `json:"checkedCount"`
	ReleasedCount        int      `json:"releasedCount"`
	AlreadyReleasedCount int      `json:"alreadyReleasedCount"`
	NotFoundCount        int      `json:"notFoundCount"`
	ReservationIDs       []string `json:"reservationIds"`
	AlreadyReleasedIDs   []string `json:"alreadyReleasedIds"`
	Skus                 []string `json:"skus"`
	SkippedCount         int      `json:"skippedCount"`
	SkippedIDs           []string `json:"skippedIds"`
}

func (h *InternalMaintenanceHandlers) cleanupReservations(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h == nil || h.inventory == nil {
		httpx.WriteError(ctx, w, httpx.NewError("inventory_unavailable", "inventory service unavailable", http.StatusServiceUnavailable))
		return
	}

	body, err := readLimitedBody(r, h.maxBody)
	switch {
	case err == nil:
	case errors.Is(err, errEmptyBody):
		body = nil
	case errors.Is(err, errBodyTooLarge):
		httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body too large", http.StatusRequestEntityTooLarge))
		return
	default:
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "unable to read request body", http.StatusBadRequest))
		return
	}

	var payload internalMaintenanceCleanupRequest
	if len(body) > 0 {
		if err := json.Unmarshal(body, &payload); err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_json", "request body must be valid JSON", http.StatusBadRequest))
			return
		}
	}

	if payload.Limit != nil && *payload.Limit < 0 {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "limit must be non-negative", http.StatusBadRequest))
		return
	}

	actorID := strings.TrimSpace(payload.ActorID)
	if actorID == "" {
		actorID = h.defaultActorID
	}
	if actorID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "actorId is required", http.StatusBadRequest))
		return
	}

	reason := strings.TrimSpace(payload.Reason)
	if reason == "" {
		reason = h.defaultReason
	}

	cmd := services.ReleaseExpiredReservationsCommand{
		ActorID: actorID,
		Reason:  reason,
	}
	if payload.Limit != nil {
		cmd.Limit = *payload.Limit
	}

	result, err := h.inventory.ReleaseExpiredReservations(ctx, cmd)
	if err != nil {
		code := "inventory_release_failed"
		status := http.StatusInternalServerError
		switch {
		case errors.Is(err, services.ErrInventoryInvalidInput):
			code = "invalid_request"
			status = http.StatusBadRequest
		case errors.Is(err, services.ErrInventoryReservationNotFound):
			code = "reservation_not_found"
			status = http.StatusNotFound
		}
		h.metrics.RecordFailure(ctx, code)
		httpx.WriteError(ctx, w, httpx.NewError(code, err.Error(), status))
		return
	}

	h.metrics.RecordRun(ctx, result.CheckedCount, result.ReleasedCount, result.AlreadyReleasedCount, result.SkippedCount)

	response := internalMaintenanceCleanupResponse{
		CheckedCount:         result.CheckedCount,
		ReleasedCount:        result.ReleasedCount,
		AlreadyReleasedCount: result.AlreadyReleasedCount,
		NotFoundCount:        result.NotFoundCount,
		ReservationIDs:       ensureStringSlice(result.ReservationIDs),
		AlreadyReleasedIDs:   ensureStringSlice(result.AlreadyReleasedIDs),
		Skus:                 ensureStringSlice(result.SKUs),
		SkippedCount:         result.SkippedCount,
		SkippedIDs:           ensureStringSlice(result.SkippedIDs),
	}

	logger := observability.FromContext(ctx).Named("internal.maintenance")
	fields := []zap.Field{
		zap.Int("checked", response.CheckedCount),
		zap.Int("released", response.ReleasedCount),
		zap.Int("alreadyReleased", response.AlreadyReleasedCount),
		zap.Int("notFound", response.NotFoundCount),
		zap.Int("skipped", response.SkippedCount),
		zap.String("actorId", actorID),
	}
	if len(response.Skus) > 0 {
		fields = append(fields, zap.Strings("skus", response.Skus))
	}
	logger.Info("cleanup reservations run", fields...)

	writeJSONResponse(w, http.StatusOK, response)
}
