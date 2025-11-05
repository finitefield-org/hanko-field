package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"sort"
	"strings"
	"time"

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
	defaultStockSafetyPageSize    = 100
	maxStockSafetyPageSize        = 500
	defaultStockSafetyMaxPages    = 5
	defaultStockSafetyCooldown    = 24 * time.Hour
)

// InternalMaintenanceHandlers exposes maintenance utilities for internal consumers.
type InternalMaintenanceHandlers struct {
	inventory services.InventoryService
	metrics   MaintenanceCleanupMetrics
	maxBody   int64
	notifier  services.StockSafetyNotifier
	clock     func() time.Time

	notificationCooldown time.Duration
	notifyPageSize       int
	notifyMaxPages       int

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

// WithMaintenanceNotifier overrides the notifier used for stock safety alerts.
func WithMaintenanceNotifier(notifier services.StockSafetyNotifier) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if notifier != nil {
			h.notifier = notifier
		}
	}
}

// WithMaintenanceClock overrides the clock used for timestamp generation.
func WithMaintenanceClock(clock func() time.Time) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if clock != nil {
			h.clock = clock
		}
	}
}

// WithMaintenanceNotificationCooldown sets the minimum duration between notifications per SKU.
func WithMaintenanceNotificationCooldown(cooldown time.Duration) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if cooldown >= 0 {
			h.notificationCooldown = cooldown
		}
	}
}

// WithMaintenanceNotificationPageSize sets the page size used when scanning low stock items.
func WithMaintenanceNotificationPageSize(size int) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if size > 0 {
			h.notifyPageSize = size
		}
	}
}

// WithMaintenanceNotificationPageLimit caps the number of pages scanned per invocation.
func WithMaintenanceNotificationPageLimit(limit int) InternalMaintenanceOption {
	return func(h *InternalMaintenanceHandlers) {
		if limit > 0 {
			h.notifyMaxPages = limit
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
		inventory:            inventory,
		metrics:              noopMaintenanceCleanupMetrics{},
		maxBody:              maxMaintenanceCleanupBodySize,
		notifier:             services.NewNoopStockSafetyNotifier(),
		clock:                time.Now,
		notificationCooldown: defaultStockSafetyCooldown,
		notifyPageSize:       defaultStockSafetyPageSize,
		notifyMaxPages:       defaultStockSafetyMaxPages,
		defaultActorID:       defaultCleanupActorID,
		defaultReason:        defaultCleanupReason,
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
	if handler.notifier == nil {
		handler.notifier = services.NewNoopStockSafetyNotifier()
	}
	if handler.clock == nil {
		handler.clock = time.Now
	}
	if handler.notificationCooldown < 0 {
		handler.notificationCooldown = defaultStockSafetyCooldown
	}
	if handler.notifyPageSize <= 0 {
		handler.notifyPageSize = defaultStockSafetyPageSize
	}
	if handler.notifyMaxPages <= 0 {
		handler.notifyMaxPages = defaultStockSafetyMaxPages
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
	r.Post("/maintenance/stock-safety-notify", h.stockSafetyNotify)
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

type stockSafetyNotifyRequest struct {
	Threshold       *int `json:"threshold,omitempty"`
	CooldownMinutes *int `json:"cooldown_minutes,omitempty"`
	Force           bool `json:"force,omitempty"`
	PageSize        *int `json:"page_size,omitempty"`
	MaxPages        *int `json:"max_pages,omitempty"`
}

type stockSafetyNotifyResponse struct {
	GeneratedAt             time.Time `json:"generated_at"`
	Threshold               int       `json:"threshold"`
	CooldownMinutes         int       `json:"cooldown_minutes"`
	NotifiedCount           int       `json:"notified_count"`
	AlreadyNotifiedCount    int       `json:"already_notified_count"`
	SkippedCount            int       `json:"skipped_count"`
	TotalCandidates         int       `json:"total_candidates"`
	NotifiedSkus            []string  `json:"notified_skus"`
	AlreadyNotifiedSkus     []string  `json:"already_notified_skus"`
	SkippedSkus             []string  `json:"skipped_skus"`
	NotificationsDispatched bool      `json:"notifications_dispatched"`
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

func (h *InternalMaintenanceHandlers) stockSafetyNotify(w http.ResponseWriter, r *http.Request) {
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

	var req stockSafetyNotifyRequest
	if len(body) > 0 {
		if err := json.Unmarshal(body, &req); err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_json", "request body must be valid JSON", http.StatusBadRequest))
			return
		}
	}

	pageSize := h.notifyPageSize
	if pageSize <= 0 {
		pageSize = defaultStockSafetyPageSize
	}
	if req.PageSize != nil {
		if *req.PageSize <= 0 {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "page_size must be positive", http.StatusBadRequest))
			return
		}
		pageSize = *req.PageSize
		if pageSize > maxStockSafetyPageSize {
			pageSize = maxStockSafetyPageSize
		}
	}

	maxPages := h.notifyMaxPages
	if maxPages <= 0 {
		maxPages = defaultStockSafetyMaxPages
	}
	if req.MaxPages != nil {
		if *req.MaxPages <= 0 {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "max_pages must be positive", http.StatusBadRequest))
			return
		}
		maxPages = *req.MaxPages
	}

	cooldown := h.notificationCooldown
	if cooldown < 0 {
		cooldown = defaultStockSafetyCooldown
	}
	if req.CooldownMinutes != nil {
		if *req.CooldownMinutes < 0 {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "cooldown_minutes must be non-negative", http.StatusBadRequest))
			return
		}
		cooldown = time.Duration(*req.CooldownMinutes) * time.Minute
	}
	cooldownMinutes := 0
	if cooldown > 0 {
		cooldownMinutes = int(cooldown / time.Minute)
	}

	threshold := 0
	if req.Threshold != nil {
		threshold = *req.Threshold
	}

	now := h.now()

	seen := make(map[string]struct{})
	toNotify := make([]services.InventorySnapshot, 0, pageSize)
	notifiedSkus := make([]string, 0, pageSize)
	alreadyNotified := make([]string, 0, pageSize)
	skippedSkus := make([]string, 0, pageSize)
	totalCandidates := 0

	pageToken := ""
	pagesFetched := 0

	for {
		filter := services.InventoryLowStockFilter{
			Threshold: threshold,
			Pagination: services.Pagination{
				PageSize:  pageSize,
				PageToken: pageToken,
			},
		}

		page, err := h.inventory.ListLowStock(ctx, filter)
		if err != nil {
			status := http.StatusInternalServerError
			code := "inventory_query_failed"
			if errors.Is(err, services.ErrInventoryInvalidInput) {
				status = http.StatusBadRequest
				code = "invalid_request"
			}
			httpx.WriteError(ctx, w, httpx.NewError(code, err.Error(), status))
			return
		}

		for _, snapshot := range page.Items {
			sku := strings.TrimSpace(snapshot.SKU)
			if sku == "" {
				continue
			}
			if _, exists := seen[sku]; exists {
				continue
			}
			seen[sku] = struct{}{}
			totalCandidates++

			if !req.Force && cooldown > 0 && snapshot.LastSafetyNotificationAt != nil {
				last := snapshot.LastSafetyNotificationAt.UTC()
				if !last.IsZero() && now.Sub(last) < cooldown {
					alreadyNotified = append(alreadyNotified, sku)
					continue
				}
			}

			if threshold <= 0 && snapshot.SafetyDelta >= 0 {
				skippedSkus = append(skippedSkus, sku)
				continue
			}

			toNotify = append(toNotify, snapshot)
		}

		pagesFetched++
		pageToken = strings.TrimSpace(page.NextPageToken)
		if pageToken == "" || pagesFetched >= maxPages {
			break
		}
	}

	notificationsDispatched := false
	if len(toNotify) > 0 && h.notifier != nil {
		notification := services.StockSafetyNotification{
			Alerts:      toNotify,
			GeneratedAt: now,
		}
		if err := h.notifier.NotifyStockSafety(ctx, notification); err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("notification_failed", err.Error(), http.StatusBadGateway))
			return
		}
		notificationsDispatched = true
		recorded := make(map[string]struct{}, len(toNotify))
		for _, snapshot := range toNotify {
			sku := strings.TrimSpace(snapshot.SKU)
			if sku == "" {
				continue
			}
			notifiedSkus = append(notifiedSkus, sku)
			if _, exists := recorded[sku]; exists {
				continue
			}
			if _, err := h.inventory.RecordSafetyNotification(ctx, services.RecordSafetyNotificationCommand{
				SKU:        sku,
				NotifiedAt: now,
			}); err != nil {
				httpx.WriteError(ctx, w, httpx.NewError("record_notification_failed", err.Error(), http.StatusInternalServerError))
				return
			}
			recorded[sku] = struct{}{}
		}
	}

	sort.Strings(notifiedSkus)
	sort.Strings(alreadyNotified)
	sort.Strings(skippedSkus)

	response := stockSafetyNotifyResponse{
		GeneratedAt:             now,
		Threshold:               threshold,
		CooldownMinutes:         cooldownMinutes,
		NotifiedCount:           len(notifiedSkus),
		AlreadyNotifiedCount:    len(alreadyNotified),
		SkippedCount:            len(skippedSkus),
		TotalCandidates:         totalCandidates,
		NotifiedSkus:            ensureStringSlice(notifiedSkus),
		AlreadyNotifiedSkus:     ensureStringSlice(alreadyNotified),
		SkippedSkus:             ensureStringSlice(skippedSkus),
		NotificationsDispatched: notificationsDispatched,
	}

	logger := observability.FromContext(ctx).Named("internal.maintenance")
	fields := []zap.Field{
		zap.Int("threshold", threshold),
		zap.Int("notified", response.NotifiedCount),
		zap.Int("alreadyNotified", response.AlreadyNotifiedCount),
		zap.Int("skipped", response.SkippedCount),
		zap.Int("candidates", totalCandidates),
		zap.Int("cooldownMinutes", response.CooldownMinutes),
	}
	if len(notifiedSkus) > 0 {
		fields = append(fields, zap.Strings("notifiedSkus", notifiedSkus))
	}
	logger.Info("stock safety notify run", fields...)

	writeJSONResponse(w, http.StatusOK, response)
}

func (h *InternalMaintenanceHandlers) now() time.Time {
	if h == nil || h.clock == nil {
		return time.Now().UTC()
	}
	return h.clock().UTC()
}
