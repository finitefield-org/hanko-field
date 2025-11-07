package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const (
	maxProductionQueueRequestBody = 32 * 1024
	maxQueueAssignBodySize        = 4 * 1024
)

// AdminProductionQueueHandlers exposes CRUD operations for production queue configurations.
type AdminProductionQueueHandlers struct {
	authn         *auth.Authenticator
	queues        services.ProductionQueueService
	orders        services.OrderService
	queueMetrics  services.QueueDepthRecorder
	recordMetrics bool
}

// AdminProductionQueueOption customises handler construction.
type AdminProductionQueueOption func(*AdminProductionQueueHandlers)

// NewAdminProductionQueueHandlers constructs the handler set for production queue administration.
func NewAdminProductionQueueHandlers(authn *auth.Authenticator, queues services.ProductionQueueService, orders services.OrderService, opts ...AdminProductionQueueOption) *AdminProductionQueueHandlers {
	handler := &AdminProductionQueueHandlers{
		authn:  authn,
		queues: queues,
		orders: orders,
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	if handler.queueMetrics != nil {
		handler.recordMetrics = true
		if provider, ok := queues.(queueMetricsProvider); ok {
			if provider.QueueMetricsRecorder() != nil {
				handler.recordMetrics = false
			}
		}
	}
	return handler
}

// Routes registers production queue endpoints under /production-queues.
func (h *AdminProductionQueueHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Route("/production-queues", func(rt chi.Router) {
		rt.Get("/", h.listQueues)
		rt.Post("/", h.createQueue)
		rt.Put("/{queueID}", h.updateQueue)
		rt.Get("/{queueID}/wip", h.getQueueWIP)
		rt.Delete("/{queueID}", h.deleteQueue)
		if h.orders != nil {
			rt.Post("/{queueID}:assign-order", h.assignOrder)
		}
	})
}

func (h *AdminProductionQueueHandlers) listQueues(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.queues == nil {
		httpx.WriteError(ctx, w, httpx.NewError("queue_service_unavailable", "production queue service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	query := r.URL.Query()
	filter := services.ProductionQueueListFilter{
		Status:     collectQueryValues(query["status"]),
		Priorities: collectQueryValues(query["priority"]),
		Pagination: services.Pagination{
			PageToken: strings.TrimSpace(firstNonEmpty(query.Get("page_token"), query.Get("pageToken"))),
		},
	}
	if raw := strings.TrimSpace(firstNonEmpty(query.Get("page_size"), query.Get("pageSize"))); raw != "" {
		if size, err := strconv.Atoi(raw); err == nil && size >= 0 {
			filter.Pagination.PageSize = size
		} else {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", "page size must be a non-negative integer", http.StatusBadRequest))
			return
		}
	}

	page, err := h.queues.ListQueues(ctx, filter)
	if err != nil {
		writeAdminProductionQueueError(ctx, w, err, "list")
		return
	}

	items := make([]adminProductionQueueResponse, 0, len(page.Items))
	for _, queue := range page.Items {
		items = append(items, newAdminProductionQueueResponse(queue))
	}
	response := adminProductionQueueListResponse{
		Items:         items,
		NextPageToken: page.NextPageToken,
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminProductionQueueHandlers) createQueue(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.queues == nil {
		httpx.WriteError(ctx, w, httpx.NewError("queue_service_unavailable", "production queue service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	queue, err := decodeAdminProductionQueueRequest(r)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	result, err := h.queues.CreateQueue(ctx, services.UpsertProductionQueueCommand{
		ActorID: strings.TrimSpace(identity.UID),
		Queue:   queue,
	})
	if err != nil {
		writeAdminProductionQueueError(ctx, w, err, "create")
		return
	}

	writeJSONResponse(w, http.StatusCreated, newAdminProductionQueueResponse(result))
}

func (h *AdminProductionQueueHandlers) updateQueue(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.queues == nil {
		httpx.WriteError(ctx, w, httpx.NewError("queue_service_unavailable", "production queue service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "queue id is required", http.StatusBadRequest))
		return
	}

	queue, err := decodeAdminProductionQueueRequest(r)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	result, err := h.queues.UpdateQueue(ctx, services.UpsertProductionQueueCommand{
		QueueID: queueID,
		ActorID: strings.TrimSpace(identity.UID),
		Queue:   queue,
	})
	if err != nil {
		writeAdminProductionQueueError(ctx, w, err, "update")
		return
	}

	writeJSONResponse(w, http.StatusOK, newAdminProductionQueueResponse(result))
}

func (h *AdminProductionQueueHandlers) deleteQueue(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.queues == nil {
		httpx.WriteError(ctx, w, httpx.NewError("queue_service_unavailable", "production queue service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "queue id is required", http.StatusBadRequest))
		return
	}

	err := h.queues.DeleteQueue(ctx, services.DeleteProductionQueueCommand{
		QueueID: queueID,
		ActorID: strings.TrimSpace(identity.UID),
	})
	if err != nil {
		writeAdminProductionQueueError(ctx, w, err, "delete")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AdminProductionQueueHandlers) getQueueWIP(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.queues == nil {
		httpx.WriteError(ctx, w, httpx.NewError("queue_service_unavailable", "production queue service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "queue id is required", http.StatusBadRequest))
		return
	}

	summary, err := h.queues.QueueWIPSummary(ctx, queueID)
	if err != nil {
		writeAdminProductionQueueError(ctx, w, err, "get_wip")
		return
	}
	h.recordQueueDepth(ctx, summary)

	writeJSONResponse(w, http.StatusOK, newAdminProductionQueueWIPResponse(summary))
}

func (h *AdminProductionQueueHandlers) assignOrder(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.orders == nil {
		httpx.WriteError(ctx, w, httpx.NewError("order_service_unavailable", "order service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "queue id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxQueueAssignBodySize)
	if err != nil {
		switch {
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		case errors.Is(err, errEmptyBody):
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "request body is required", http.StatusBadRequest))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	var payload adminQueueAssignRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON body", http.StatusBadRequest))
		return
	}

	orderID := strings.TrimSpace(payload.OrderID)
	if orderID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "order_id is required", http.StatusBadRequest))
		return
	}

	cmd := services.AssignOrderToQueueCommand{
		OrderID: orderID,
		QueueID: queueID,
		ActorID: strings.TrimSpace(identity.UID),
	}

	if raw := strings.TrimSpace(payload.IfUnmodifiedSince); raw != "" {
		ts, err := parseTimeParam(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_if_unmodified_since", "if_unmodified_since must be RFC3339", http.StatusBadRequest))
			return
		}
		cmd.IfUnmodifiedSince = &ts
	}

	if statusRaw := strings.TrimSpace(payload.ExpectedStatus); statusRaw != "" {
		status, ok := parseOrderStatus(statusRaw)
		if !ok {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_expected_status", "expected_status must be a valid order status", http.StatusBadRequest))
			return
		}
		cmd.ExpectedStatus = &status
	}

	if expectedQueue := strings.TrimSpace(payload.ExpectedQueueID); expectedQueue != "" {
		eq := expectedQueue
		cmd.ExpectedQueueID = &eq
	}

	order, err := h.orders.AssignOrderToQueue(ctx, cmd)
	if err != nil {
		writeOrderError(ctx, w, err)
		return
	}

	response := adminQueueAssignResponse{
		Order: buildAdminOrderSummary(order),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

type adminProductionQueueRequest struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	Capacity    *int           `json:"capacity"`
	WorkCenters []string       `json:"work_centers"`
	Priority    string         `json:"priority"`
	Status      string         `json:"status"`
	Notes       string         `json:"notes"`
	Metadata    map[string]any `json:"metadata"`
}

func decodeAdminProductionQueueRequest(r *http.Request) (services.ProductionQueue, error) {
	defer func(closer io.ReadCloser) {
		_ = closer.Close()
	}(r.Body)

	reader := io.LimitReader(r.Body, maxProductionQueueRequestBody)
	decoder := json.NewDecoder(reader)
	decoder.DisallowUnknownFields()

	var payload adminProductionQueueRequest
	if err := decoder.Decode(&payload); err != nil {
		return services.ProductionQueue{}, err
	}
	if decoder.More() {
		return services.ProductionQueue{}, errors.New("multiple JSON objects provided")
	}

	queue := services.ProductionQueue{
		ID:          strings.TrimSpace(payload.ID),
		Name:        payload.Name,
		WorkCenters: payload.WorkCenters,
		Priority:    payload.Priority,
		Status:      payload.Status,
		Notes:       payload.Notes,
		Metadata:    payload.Metadata,
	}
	if payload.Capacity != nil {
		queue.Capacity = *payload.Capacity
	}
	return queue, nil
}

type adminProductionQueueResponse struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	Capacity    int            `json:"capacity"`
	WorkCenters []string       `json:"work_centers,omitempty"`
	Priority    string         `json:"priority"`
	Status      string         `json:"status"`
	Notes       string         `json:"notes,omitempty"`
	Metadata    map[string]any `json:"metadata,omitempty"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

type adminProductionQueueListResponse struct {
	Items         []adminProductionQueueResponse `json:"items"`
	NextPageToken string                         `json:"next_page_token,omitempty"`
}

type adminProductionQueueWIPResponse struct {
	QueueID           string         `json:"queue_id"`
	Total             int            `json:"total"`
	Counts            map[string]int `json:"counts,omitempty"`
	AverageAgeSeconds float64        `json:"average_age_seconds"`
	OldestAgeSeconds  float64        `json:"oldest_age_seconds"`
	SLABreachCount    int            `json:"sla_breach_count"`
	GeneratedAt       time.Time      `json:"generated_at,omitempty"`
}

func newAdminProductionQueueResponse(queue services.ProductionQueue) adminProductionQueueResponse {
	resp := adminProductionQueueResponse{
		ID:          strings.TrimSpace(queue.ID),
		Name:        queue.Name,
		Capacity:    queue.Capacity,
		WorkCenters: queue.WorkCenters,
		Priority:    queue.Priority,
		Status:      queue.Status,
		Notes:       queue.Notes,
		CreatedAt:   queue.CreatedAt,
		UpdatedAt:   queue.UpdatedAt,
	}
	if len(queue.Metadata) > 0 {
		resp.Metadata = queue.Metadata
	}
	if len(resp.WorkCenters) == 0 {
		resp.WorkCenters = nil
	}
	if strings.TrimSpace(resp.Notes) == "" {
		resp.Notes = ""
	}
	return resp
}

func newAdminProductionQueueWIPResponse(summary services.ProductionQueueWIPSummary) adminProductionQueueWIPResponse {
	queueID := strings.TrimSpace(summary.QueueID)
	resp := adminProductionQueueWIPResponse{
		QueueID:           queueID,
		Total:             summary.Total,
		AverageAgeSeconds: summary.AverageAge.Seconds(),
		OldestAgeSeconds:  summary.OldestAge.Seconds(),
		SLABreachCount:    summary.SLABreachCount,
	}
	if len(summary.StatusCounts) > 0 {
		counts := make(map[string]int, len(summary.StatusCounts))
		for key, value := range summary.StatusCounts {
			counts[key] = value
		}
		resp.Counts = counts
	}
	if summary.AverageAge <= 0 {
		resp.AverageAgeSeconds = 0
	}
	if summary.OldestAge <= 0 {
		resp.OldestAgeSeconds = 0
	}
	if summary.SLABreachCount < 0 {
		resp.SLABreachCount = 0
	}
	if !summary.GeneratedAt.IsZero() {
		resp.GeneratedAt = summary.GeneratedAt
	}
	return resp
}

func (h *AdminProductionQueueHandlers) recordQueueDepth(ctx context.Context, summary services.ProductionQueueWIPSummary) {
	if !h.recordMetrics || h.queueMetrics == nil {
		return
	}
	queueID := strings.TrimSpace(summary.QueueID)
	if queueID == "" {
		return
	}
	h.queueMetrics.RecordQueueDepth(ctx, queueID, summary.Total, summary.StatusCounts)
}

// queueMetricsProvider allows detection of services that already emit queue metrics.
type queueMetricsProvider interface {
	QueueMetricsRecorder() services.QueueDepthRecorder
}

// WithProductionQueueMetrics configures an external recorder for queue depth metrics when the service does not emit them.
func WithProductionQueueMetrics(metrics services.QueueDepthRecorder) AdminProductionQueueOption {
	return func(h *AdminProductionQueueHandlers) {
		h.queueMetrics = metrics
	}
}

type adminQueueAssignRequest struct {
	OrderID           string `json:"order_id"`
	ExpectedStatus    string `json:"expected_status"`
	ExpectedQueueID   string `json:"expected_queue_id"`
	IfUnmodifiedSince string `json:"if_unmodified_since"`
}

type adminQueueAssignResponse struct {
	Order adminOrderSummary `json:"order"`
}

func writeAdminProductionQueueError(ctx context.Context, w http.ResponseWriter, err error, action string) {
	if err == nil {
		return
	}
	switch {
	case errors.Is(err, services.ErrProductionQueueInvalid):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_queue", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrProductionQueueNotFound):
		httpx.WriteError(ctx, w, httpx.NewError("queue_not_found", "queue not found", http.StatusNotFound))
	case errors.Is(err, services.ErrProductionQueueConflict):
		httpx.WriteError(ctx, w, httpx.NewError("queue_conflict", "queue conflict", http.StatusConflict))
	case errors.Is(err, services.ErrProductionQueueHasAssignments):
		httpx.WriteError(ctx, w, httpx.NewError("queue_has_assignments", "queue has active assignments", http.StatusConflict))
	case errors.Is(err, services.ErrProductionQueueRepositoryUnavailable):
		httpx.WriteError(ctx, w, httpx.NewError("queue_repository_unavailable", "production queue repository unavailable", http.StatusServiceUnavailable))
	case errors.Is(err, services.ErrProductionQueueRepositoryMissing):
		httpx.WriteError(ctx, w, httpx.NewError("queue_service_unavailable", "production queue service unavailable", http.StatusServiceUnavailable))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("queue_operation_failed", err.Error(), http.StatusInternalServerError))
	}
	_ = action
}
