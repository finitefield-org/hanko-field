package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
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
	maxInternalReserveRequestBody = 16 * 1024
	checkoutReserveReason         = "internal_checkout"
)

// InternalCheckoutHandlers exposes internal checkout-specific operations.
type InternalCheckoutHandlers struct {
	inventory services.InventoryService
	metrics   checkoutReservationMetricsRecorder
}

// InternalCheckoutOption customises internal checkout handlers during construction.
type InternalCheckoutOption func(*InternalCheckoutHandlers)

// CheckoutReservationMetrics records reservation outcomes for observability.
type CheckoutReservationMetrics interface {
	RecordCreated(ctx context.Context, ttl time.Duration, lineCount int)
	RecordFailure(ctx context.Context, reason string)
}

type checkoutReservationMetricsRecorder interface {
	CheckoutReservationMetrics
}

type noopCheckoutReservationMetrics struct{}

func (noopCheckoutReservationMetrics) RecordCreated(context.Context, time.Duration, int) {}
func (noopCheckoutReservationMetrics) RecordFailure(context.Context, string)             {}

type checkoutReservationMetrics struct {
	created         metric.Int64Counter
	failures        metric.Int64Counter
	createdEnabled  bool
	failuresEnabled bool
}

func (m *checkoutReservationMetrics) RecordCreated(ctx context.Context, ttl time.Duration, lineCount int) {
	if m == nil || !m.createdEnabled {
		return
	}
	attrs := []attribute.KeyValue{
		attribute.Int("line_count", lineCount),
	}
	ttlSeconds := ttl / time.Second
	if ttlSeconds > 0 {
		attrs = append(attrs, attribute.Int64("ttl_seconds", int64(ttlSeconds)))
	}
	m.created.Add(ctx, 1, metric.WithAttributes(attrs...))
}

func (m *checkoutReservationMetrics) RecordFailure(ctx context.Context, reason string) {
	if m == nil || !m.failuresEnabled {
		return
	}
	attrs := []attribute.KeyValue{}
	reason = strings.TrimSpace(reason)
	if reason != "" {
		attrs = append(attrs, attribute.String("reason", reason))
	}
	m.failures.Add(ctx, 1, metric.WithAttributes(attrs...))
}

// NewCheckoutReservationMetrics constructs OpenTelemetry-backed metrics for checkout reservations.
func NewCheckoutReservationMetrics(logger *zap.Logger) CheckoutReservationMetrics {
	meter := otel.GetMeterProvider().Meter("github.com/hanko-field/api/internal/handlers/internal_checkout")

	created, createdErr := meter.Int64Counter(
		"checkout.reservations.created",
		metric.WithDescription("Count of checkout stock reservations created via internal endpoint"),
	)
	failures, failuresErr := meter.Int64Counter(
		"checkout.reservations.failed",
		metric.WithDescription("Count of checkout stock reservation failures via internal endpoint"),
	)

	if logger == nil {
		logger = zap.NewNop()
	}

	recorder := &checkoutReservationMetrics{}
	if createdErr != nil {
		logger.Warn("checkout metrics: unable to register created counter", zap.Error(createdErr))
	} else {
		recorder.created = created
		recorder.createdEnabled = true
	}

	if failuresErr != nil {
		logger.Warn("checkout metrics: unable to register failure counter", zap.Error(failuresErr))
	} else {
		recorder.failures = failures
		recorder.failuresEnabled = true
	}

	if !recorder.createdEnabled && !recorder.failuresEnabled {
		return noopCheckoutReservationMetrics{}
	}
	return recorder
}

// WithInternalCheckoutMetrics sets the metrics recorder used by the handler.
func WithInternalCheckoutMetrics(metrics CheckoutReservationMetrics) InternalCheckoutOption {
	return func(h *InternalCheckoutHandlers) {
		if metrics != nil {
			h.metrics = metrics
		}
	}
}

// NewInternalCheckoutHandlers wires dependencies for internal checkout operations.
func NewInternalCheckoutHandlers(inventory services.InventoryService, opts ...InternalCheckoutOption) *InternalCheckoutHandlers {
	handler := &InternalCheckoutHandlers{
		inventory: inventory,
		metrics:   noopCheckoutReservationMetrics{},
	}
	for _, opt := range opts {
		opt(handler)
	}
	if handler.metrics == nil {
		handler.metrics = noopCheckoutReservationMetrics{}
	}
	return handler
}

// Routes registers internal checkout endpoints.
func (h *InternalCheckoutHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/checkout/reserve-stock", h.reserveStock)
}

type internalReserveStockRequest struct {
	OrderID        string                     `json:"orderId"`
	UserRef        string                     `json:"userRef"`
	UserID         string                     `json:"userId"`
	Lines          []internalReserveStockLine `json:"lines"`
	TTLSeconds     int64                      `json:"ttlSec"`
	IdempotencyKey string                     `json:"idempotencyKey"`
	Reason         string                     `json:"reason"`
}

type internalReserveStockLine struct {
	ProductRef  string `json:"productRef"`
	ProductID   string `json:"productId"`
	SKU         string `json:"sku"`
	Quantity    int    `json:"qty"`
	QuantityAlt int    `json:"quantity"`
}

type internalReserveStockResponse struct {
	ReservationID string                          `json:"reservationId"`
	Status        string                          `json:"status"`
	OrderRef      string                          `json:"orderRef"`
	UserRef       string                          `json:"userRef"`
	ExpiresAt     string                          `json:"expiresAt"`
	CreatedAt     string                          `json:"createdAt"`
	TTLSeconds    int64                           `json:"ttlSec"`
	Lines         []internalReserveStockLineReply `json:"lines"`
}

type internalReserveStockLineReply struct {
	ProductRef string `json:"productRef"`
	SKU        string `json:"sku"`
	Quantity   int    `json:"quantity"`
}

func (h *InternalCheckoutHandlers) reserveStock(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h == nil || h.inventory == nil {
		h.recordFailure(ctx, "service_unavailable")
		httpx.WriteError(ctx, w, httpx.NewError("inventory_unavailable", "inventory service unavailable", http.StatusServiceUnavailable))
		return
	}

	body, err := readLimitedBody(r, maxInternalReserveRequestBody)
	if err != nil {
		code := http.StatusBadRequest
		switch {
		case errors.Is(err, errBodyTooLarge):
			code = http.StatusRequestEntityTooLarge
		case errors.Is(err, errEmptyBody):
			code = http.StatusBadRequest
		}
		h.recordFailure(ctx, "invalid_request")
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), code))
		return
	}

	var req internalReserveStockRequest
	if err := json.Unmarshal(body, &req); err != nil {
		h.recordFailure(ctx, "invalid_json")
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "request body must be valid JSON", http.StatusBadRequest))
		return
	}

	command, ttl, err := buildReserveCommand(req)
	if err != nil {
		h.recordFailure(ctx, "invalid_request")
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	reservation, err := h.inventory.ReserveStocks(ctx, command)
	if err != nil {
		h.handleReserveError(ctx, w, err)
		return
	}

	h.metrics.RecordCreated(ctx, ttl, len(reservation.Lines))

	response := internalReserveStockResponse{
		ReservationID: strings.TrimSpace(reservation.ID),
		Status:        strings.TrimSpace(reservation.Status),
		OrderRef:      strings.TrimSpace(reservation.OrderRef),
		UserRef:       strings.TrimSpace(reservation.UserRef),
		ExpiresAt:     formatTime(reservation.ExpiresAt),
		CreatedAt:     formatTime(reservation.CreatedAt),
		TTLSeconds:    ttlSeconds(reservation),
		Lines:         convertReservationLines(reservation.Lines),
	}

	logger := observability.FromContext(ctx).Named("internal.checkout")
	logger.Info("checkout reserve stock created",
		zap.String("reservationId", response.ReservationID),
		zap.String("orderRef", response.OrderRef),
		zap.String("userRef", response.UserRef),
		zap.Int("lineCount", len(reservation.Lines)),
		zap.Int64("ttlSec", response.TTLSeconds),
	)

	writeJSONResponse(w, http.StatusOK, response)
}

func (h *InternalCheckoutHandlers) handleReserveError(ctx context.Context, w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, services.ErrInventoryInvalidInput):
		h.recordFailure(ctx, "invalid_request")
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrInventoryInsufficientStock):
		h.recordFailure(ctx, "insufficient_stock")
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_stock", "insufficient stock to reserve items", http.StatusConflict))
	case errors.Is(err, services.ErrInventoryInvalidState):
		h.recordFailure(ctx, "invalid_state")
		httpx.WriteError(ctx, w, httpx.NewError("invalid_state", err.Error(), http.StatusConflict))
	default:
		h.recordFailure(ctx, "reservation_error")
		httpx.WriteError(ctx, w, httpx.NewError("reservation_error", "failed to reserve stock", http.StatusInternalServerError))
	}
}

func (h *InternalCheckoutHandlers) recordFailure(ctx context.Context, reason string) {
	metrics := h.metrics
	if metrics == nil {
		return
	}
	metrics.RecordFailure(ctx, reason)
}

func buildReserveCommand(req internalReserveStockRequest) (services.InventoryReserveCommand, time.Duration, error) {
	orderID := strings.TrimSpace(req.OrderID)
	if orderID == "" {
		return services.InventoryReserveCommand{}, 0, errors.New("orderId is required")
	}

	userID := strings.TrimSpace(req.UserID)
	if userID == "" {
		userID = strings.TrimSpace(req.UserRef)
		userID = strings.TrimPrefix(userID, "/users/")
	}
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return services.InventoryReserveCommand{}, 0, errors.New("userRef is required")
	}

	if len(req.Lines) == 0 {
		return services.InventoryReserveCommand{}, 0, errors.New("lines must contain at least one entry")
	}

	ttlSeconds := req.TTLSeconds
	if ttlSeconds <= 0 {
		return services.InventoryReserveCommand{}, 0, errors.New("ttlSec must be positive")
	}
	ttl := time.Duration(ttlSeconds) * time.Second
	if ttl <= 0 {
		return services.InventoryReserveCommand{}, 0, fmt.Errorf("ttlSec %d is invalid", ttlSeconds)
	}

	lines := make([]services.InventoryLine, 0, len(req.Lines))
	for idx, line := range req.Lines {
		sku := strings.TrimSpace(line.SKU)
		if sku == "" {
			return services.InventoryReserveCommand{}, 0, fmt.Errorf("lines[%d].sku is required", idx)
		}
		productID := strings.TrimSpace(line.ProductID)
		if productID == "" {
			productID = strings.TrimSpace(line.ProductRef)
			productID = strings.TrimPrefix(productID, "/products/")
		}
		productID = strings.TrimSpace(productID)
		if productID == "" {
			return services.InventoryReserveCommand{}, 0, fmt.Errorf("lines[%d].productRef is required", idx)
		}
		quantity := line.Quantity
		if quantity <= 0 {
			quantity = line.QuantityAlt
		}
		if quantity <= 0 {
			return services.InventoryReserveCommand{}, 0, fmt.Errorf("lines[%d].quantity must be positive", idx)
		}

		lines = append(lines, services.InventoryLine{
			ProductID: productID,
			SKU:       sku,
			Quantity:  quantity,
		})
	}

	reason := strings.TrimSpace(req.Reason)
	if reason == "" {
		reason = checkoutReserveReason
	}

	return services.InventoryReserveCommand{
		OrderID:        orderID,
		UserID:         userID,
		Lines:          lines,
		TTL:            ttl,
		Reason:         reason,
		IdempotencyKey: strings.TrimSpace(req.IdempotencyKey),
	}, ttl, nil
}

func ttlSeconds(reservation services.InventoryReservation) int64 {
	ttl := reservation.ExpiresAt.Sub(reservation.CreatedAt)
	if ttl <= 0 {
		return 0
	}
	return int64(ttl / time.Second)
}

func convertReservationLines(lines []services.InventoryReservationLine) []internalReserveStockLineReply {
	out := make([]internalReserveStockLineReply, 0, len(lines))
	for _, line := range lines {
		out = append(out, internalReserveStockLineReply{
			ProductRef: strings.TrimSpace(line.ProductRef),
			SKU:        strings.TrimSpace(line.SKU),
			Quantity:   line.Quantity,
		})
	}
	return out
}
