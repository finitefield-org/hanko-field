package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminProductionQueueHandlers_ListQueues_Authorization(t *testing.T) {
	handler := NewAdminProductionQueueHandlers(nil, &stubAdminProductionQueueService{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/production-queues", nil)
	rec := httptest.NewRecorder()
	handler.listQueues(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodGet, "/production-queues", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user"}))
	rec = httptest.NewRecorder()
	handler.listQueues(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

func TestAdminProductionQueueHandlers_ListQueues_Success(t *testing.T) {
	service := &stubAdminProductionQueueService{
		listResult: domain.CursorPage[services.ProductionQueue]{
			Items: []services.ProductionQueue{
				{
					ID:          "pqu_01",
					Name:        "Engraving",
					Capacity:    12,
					WorkCenters: []string{"Station A"},
					Priority:    "rush",
					Status:      "active",
					CreatedAt:   time.Date(2024, 4, 8, 12, 0, 0, 0, time.UTC),
					UpdatedAt:   time.Date(2024, 4, 8, 13, 0, 0, 0, time.UTC),
				},
			},
			NextPageToken: "next123",
		},
	}
	handler := NewAdminProductionQueueHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodGet, "/production-queues", nil)
	query := req.URL.Query()
	query.Set("status", "Active")
	query.Set("priority", "Rush")
	query.Set("page_size", "20")
	query.Set("page_token", " token ")
	req.URL.RawQuery = query.Encode()
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listQueues(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if len(service.listFilter.Status) != 1 || strings.TrimSpace(service.listFilter.Status[0]) != "Active" {
		t.Fatalf("expected status trimmed, got %v", service.listFilter.Status)
	}
	if len(service.listFilter.Priorities) != 1 || strings.TrimSpace(service.listFilter.Priorities[0]) != "Rush" {
		t.Fatalf("expected priority trimmed, got %v", service.listFilter.Priorities)
	}
	if service.listFilter.Pagination.PageSize != 20 {
		t.Fatalf("expected page size 20, got %d", service.listFilter.Pagination.PageSize)
	}
	if service.listFilter.Pagination.PageToken != "token" {
		t.Fatalf("expected trimmed token, got %q", service.listFilter.Pagination.PageToken)
	}

	var payload adminProductionQueueListResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(payload.Items) != 1 || payload.Items[0].ID != "pqu_01" {
		t.Fatalf("unexpected response items %+v", payload.Items)
	}
	if payload.NextPageToken != "next123" {
		t.Fatalf("expected next page token propagated, got %q", payload.NextPageToken)
	}
}

func TestAdminProductionQueueHandlers_CreateQueue_PassesPayload(t *testing.T) {
	service := &stubAdminProductionQueueService{
		createResult: services.ProductionQueue{
			ID:          "pqu_new",
			Name:        "New Queue",
			Capacity:    5,
			WorkCenters: []string{"Station Z"},
			Priority:    "normal",
			Status:      "active",
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
	}
	handler := NewAdminProductionQueueHandlers(nil, service, nil)

	body := `{"name":"  New Queue ","capacity":5,"work_centers":[" Station Z "],"priority":"normal","status":"active","notes":" note ","metadata":{"region":"tokyo"}}`
	req := httptest.NewRequest(http.MethodPost, "/production-queues", bytes.NewBufferString(body))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: " admin ", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.createQueue(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d", rec.Code)
	}
	if service.createCmd.ActorID != "admin" {
		t.Fatalf("expected actor trimmed, got %q", service.createCmd.ActorID)
	}
	if strings.TrimSpace(service.createCmd.Queue.Name) != "New Queue" {
		t.Fatalf("expected queue name captured, got %q", service.createCmd.Queue.Name)
	}
	if len(service.createCmd.Queue.WorkCenters) != 1 || strings.TrimSpace(service.createCmd.Queue.WorkCenters[0]) != "Station Z" {
		t.Fatalf("expected work centers captured, got %v", service.createCmd.Queue.WorkCenters)
	}
	var payload adminProductionQueueResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if payload.ID != "pqu_new" {
		t.Fatalf("expected id in response, got %q", payload.ID)
	}
	if payload.Notes != "" {
		t.Fatalf("expected notes omitted when blank, got %q", payload.Notes)
	}
}

func TestAdminProductionQueueHandlers_CreateQueue_ServiceError(t *testing.T) {
	service := &stubAdminProductionQueueService{
		createErr: services.ErrProductionQueueInvalid,
	}
	handler := NewAdminProductionQueueHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodPost, "/production-queues", bytes.NewBufferString(`{"name":"Queue"}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.createQueue(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestAdminProductionQueueHandlers_UpdateQueue_PassesIdentifiers(t *testing.T) {
	service := &stubAdminProductionQueueService{
		updateResult: services.ProductionQueue{
			ID:        "pqu_123",
			Name:      "Updated",
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
	}
	handler := NewAdminProductionQueueHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodPut, "/production-queues/pqu_123", bytes.NewBufferString(`{"name":"Updated","capacity":3}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_123")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	rec := httptest.NewRecorder()

	handler.updateQueue(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if service.updateCmd.QueueID != "pqu_123" {
		t.Fatalf("expected queue id forwarded, got %q", service.updateCmd.QueueID)
	}
	if service.updateCmd.ActorID != "admin" {
		t.Fatalf("expected actor trimmed, got %q", service.updateCmd.ActorID)
	}
}

func TestAdminProductionQueueHandlers_GetQueueWIP_Authorization(t *testing.T) {
	handler := NewAdminProductionQueueHandlers(nil, &stubAdminProductionQueueService{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/production-queues/pqu_123/wip", nil)
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_123")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))

	rec := httptest.NewRecorder()
	handler.getQueueWIP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}

	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user"}))
	rec = httptest.NewRecorder()
	handler.getQueueWIP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

func TestAdminProductionQueueHandlers_GetQueueWIP_Success(t *testing.T) {
	generated := time.Date(2024, 4, 8, 12, 15, 0, 0, time.UTC)
	service := &stubAdminProductionQueueService{
		wipResult: services.ProductionQueueWIPSummary{
			QueueID: "pqu_prod",
			StatusCounts: map[string]int{
				"waiting":     4,
				"in_progress": 3,
			},
			Total:          7,
			AverageAge:     30 * time.Minute,
			OldestAge:      2 * time.Hour,
			SLABreachCount: 1,
			GeneratedAt:    generated,
		},
	}
	handler := NewAdminProductionQueueHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodGet, "/production-queues/pqu_prod/wip", nil)
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", " pqu_prod ")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.getQueueWIP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if service.wipQueueID != "pqu_prod" {
		t.Fatalf("expected trimmed queue id passed, got %q", service.wipQueueID)
	}

	var payload struct {
		QueueID        string         `json:"queue_id"`
		Total          int            `json:"total"`
		Counts         map[string]int `json:"counts"`
		AverageAge     float64        `json:"average_age_seconds"`
		OldestAge      float64        `json:"oldest_age_seconds"`
		SLABreachCount int            `json:"sla_breach_count"`
		GeneratedAt    string         `json:"generated_at"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if payload.QueueID != "pqu_prod" {
		t.Fatalf("expected queue id pqu_prod, got %q", payload.QueueID)
	}
	if payload.Total != 7 {
		t.Fatalf("expected total 7, got %d", payload.Total)
	}
	if payload.Counts["waiting"] != 4 || payload.Counts["in_progress"] != 3 {
		t.Fatalf("unexpected counts %+v", payload.Counts)
	}
	if payload.AverageAge != float64(30*60) {
		t.Fatalf("expected average age seconds 1800, got %.0f", payload.AverageAge)
	}
	if payload.OldestAge != float64(2*3600) {
		t.Fatalf("expected oldest age seconds 7200, got %.0f", payload.OldestAge)
	}
	if payload.SLABreachCount != 1 {
		t.Fatalf("expected SLA breach count 1, got %d", payload.SLABreachCount)
	}
	if payload.GeneratedAt != generated.Format(time.RFC3339Nano) {
		t.Fatalf("expected generated at %s, got %s", generated.Format(time.RFC3339Nano), payload.GeneratedAt)
	}
}

func TestAdminProductionQueueHandlers_GetQueueWIP_RecordsMetrics(t *testing.T) {
	service := &stubAdminProductionQueueService{
		wipResult: services.ProductionQueueWIPSummary{
			QueueID: "pqu_depth",
			StatusCounts: map[string]int{
				"waiting": 2,
			},
			Total: 2,
		},
	}
	recorder := &captureQueueDepthRecorder{}
	handler := NewAdminProductionQueueHandlers(nil, service, nil, WithProductionQueueMetrics(recorder))

	req := httptest.NewRequest(http.MethodGet, "/production-queues/pqu_depth/wip", nil)
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_depth")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.getQueueWIP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if len(recorder.records) != 1 {
		t.Fatalf("expected 1 metrics record, got %d", len(recorder.records))
	}
	record := recorder.records[0]
	if record.queueID != "pqu_depth" {
		t.Fatalf("expected queue id pqu_depth, got %s", record.queueID)
	}
	if record.total != 2 {
		t.Fatalf("expected total 2, got %d", record.total)
	}
	if record.counts["waiting"] != 2 {
		t.Fatalf("expected waiting count 2, got %v", record.counts)
	}
}

func TestAdminProductionQueueHandlers_GetQueueWIP_SkipsMetricsWhenServiceHandles(t *testing.T) {
	internalRecorder := &captureQueueDepthRecorder{}
	service := &stubAdminProductionQueueService{
		wipResult: services.ProductionQueueWIPSummary{
			QueueID: "pqu_depth",
			Total:   1,
		},
		metrics: internalRecorder,
	}
	recorder := &captureQueueDepthRecorder{}
	handler := NewAdminProductionQueueHandlers(nil, service, nil, WithProductionQueueMetrics(recorder))

	req := httptest.NewRequest(http.MethodGet, "/production-queues/pqu_depth/wip", nil)
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_depth")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.getQueueWIP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if len(recorder.records) != 0 {
		t.Fatalf("expected no external metrics, got %d", len(recorder.records))
	}
}

func TestAdminProductionQueueHandlers_GetQueueWIP_NotFound(t *testing.T) {
	service := &stubAdminProductionQueueService{
		wipErr: services.ErrProductionQueueNotFound,
	}
	handler := NewAdminProductionQueueHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodGet, "/production-queues/pqu_missing/wip", nil)
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_missing")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.getQueueWIP(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}

func TestAdminProductionQueueHandlers_DeleteQueue_ErrorMapping(t *testing.T) {
	service := &stubAdminProductionQueueService{
		deleteErr: services.ErrProductionQueueHasAssignments,
	}
	handler := NewAdminProductionQueueHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodDelete, "/production-queues/pqu_busy", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_busy")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	rec := httptest.NewRecorder()

	handler.deleteQueue(rec, req)
	if rec.Code != http.StatusConflict {
		t.Fatalf("expected 409, got %d", rec.Code)
	}
	if service.deleteCmd.QueueID != "pqu_busy" {
		t.Fatalf("expected queue id forwarded")
	}
}

func TestAdminProductionQueueHandlers_AssignOrder_Success(t *testing.T) {
	var captured services.AssignOrderToQueueCommand
	now := time.Date(2024, 5, 1, 9, 0, 0, 0, time.UTC)
	queue := "pqu_main"

	orderSvc := &stubOrderService{
		assignFn: func(_ context.Context, cmd services.AssignOrderToQueueCommand) (services.Order, error) {
			captured = cmd
			return services.Order{
				ID:          "ord_assign",
				OrderNumber: "HF-2024-000050",
				Status:      domain.OrderStatusInProduction,
				Production: services.OrderProduction{
					QueueRef:      &queue,
					LastEventType: "queued",
					LastEventAt:   &now,
				},
				CreatedAt: now,
				UpdatedAt: now,
			}, nil
		},
	}
	handler := NewAdminProductionQueueHandlers(nil, nil, orderSvc)

	body := `{"order_id":" ord_assign ","expected_status":"paid","expected_queue_id":" old_queue ","if_unmodified_since":"2024-04-30T23:00:00Z"}`
	req := httptest.NewRequest(http.MethodPost, "/production-queues/pqu_main:assign-order", bytes.NewBufferString(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("queueID", " pqu_main ")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: " staff-77 ", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.assignOrder(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	if captured.QueueID != "pqu_main" {
		t.Fatalf("expected queue id trimmed, got %q", captured.QueueID)
	}
	if captured.ActorID != "staff-77" {
		t.Fatalf("expected actor trimmed, got %q", captured.ActorID)
	}
	if captured.OrderID != "ord_assign" {
		t.Fatalf("expected order id trimmed, got %q", captured.OrderID)
	}
	if captured.ExpectedStatus == nil || *captured.ExpectedStatus != services.OrderStatus(domain.OrderStatusPaid) {
		t.Fatalf("expected expected status paid, got %#v", captured.ExpectedStatus)
	}
	if captured.ExpectedQueueID == nil || *captured.ExpectedQueueID != "old_queue" {
		t.Fatalf("expected expected queue old_queue, got %#v", captured.ExpectedQueueID)
	}
	if captured.IfUnmodifiedSince == nil || captured.IfUnmodifiedSince.Format(time.RFC3339) != "2024-04-30T23:00:00Z" {
		t.Fatalf("expected if_unmodified_since parsed, got %#v", captured.IfUnmodifiedSince)
	}

	var payload struct {
		Order adminOrderSummary `json:"order"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if payload.Order.ID != "ord_assign" {
		t.Fatalf("expected order id in response, got %s", payload.Order.ID)
	}
	if payload.Order.ProductionQueue != "pqu_main" {
		t.Fatalf("expected production queue pqu_main, got %s", payload.Order.ProductionQueue)
	}
	if payload.Order.Status != "in_production" {
		t.Fatalf("expected status in_production, got %s", payload.Order.Status)
	}
}

func TestAdminProductionQueueHandlers_AssignOrder_InvalidRequest(t *testing.T) {
	orderSvc := &stubOrderService{}
	handler := NewAdminProductionQueueHandlers(nil, nil, orderSvc)

	req := httptest.NewRequest(http.MethodPost, "/production-queues/pqu_main:assign-order", bytes.NewBufferString(`{"order_id":""}`))
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_main")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.assignOrder(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestAdminProductionQueueHandlers_AssignOrder_ServiceError(t *testing.T) {
	orderSvc := &stubOrderService{
		assignFn: func(context.Context, services.AssignOrderToQueueCommand) (services.Order, error) {
			return services.Order{}, services.ErrOrderQueueCapacityReached
		},
	}
	handler := NewAdminProductionQueueHandlers(nil, nil, orderSvc)

	req := httptest.NewRequest(http.MethodPost, "/production-queues/pqu_main:assign-order", bytes.NewBufferString(`{"order_id":"ord"}`))
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_main")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.assignOrder(rec, req)
	if rec.Code != http.StatusConflict {
		t.Fatalf("expected 409, got %d", rec.Code)
	}
}

func TestAdminProductionQueueHandlers_AssignOrder_Unauthorized(t *testing.T) {
	handler := NewAdminProductionQueueHandlers(nil, nil, &stubOrderService{})

	req := httptest.NewRequest(http.MethodPost, "/production-queues/pqu_main:assign-order", bytes.NewBufferString(`{"order_id":"ord"}`))
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_main")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	rec := httptest.NewRecorder()

	handler.assignOrder(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestAdminProductionQueueHandlers_AssignOrder_ServiceUnavailable(t *testing.T) {
	handler := NewAdminProductionQueueHandlers(nil, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/production-queues/pqu_main:assign-order", bytes.NewBufferString(`{"order_id":"ord"}`))
	ctx := chi.NewRouteContext()
	ctx.URLParams.Add("queueID", "pqu_main")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, ctx))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.assignOrder(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}
}

type stubAdminProductionQueueService struct {
	listFilter   services.ProductionQueueListFilter
	listResult   domain.CursorPage[services.ProductionQueue]
	listErr      error
	getResult    services.ProductionQueue
	getErr       error
	createCmd    services.UpsertProductionQueueCommand
	createResult services.ProductionQueue
	createErr    error
	updateCmd    services.UpsertProductionQueueCommand
	updateResult services.ProductionQueue
	updateErr    error
	deleteCmd    services.DeleteProductionQueueCommand
	deleteErr    error
	wipQueueID   string
	wipResult    services.ProductionQueueWIPSummary
	wipErr       error
	metrics      services.QueueDepthRecorder
}

func (s *stubAdminProductionQueueService) ListQueues(ctx context.Context, filter services.ProductionQueueListFilter) (domain.CursorPage[services.ProductionQueue], error) {
	_ = ctx
	s.listFilter = filter
	if s.listErr != nil {
		return domain.CursorPage[services.ProductionQueue]{}, s.listErr
	}
	return s.listResult, nil
}

func (s *stubAdminProductionQueueService) GetQueue(ctx context.Context, queueID string) (services.ProductionQueue, error) {
	_ = ctx
	if s.getErr != nil {
		return services.ProductionQueue{}, s.getErr
	}
	return s.getResult, nil
}

func (s *stubAdminProductionQueueService) CreateQueue(ctx context.Context, cmd services.UpsertProductionQueueCommand) (services.ProductionQueue, error) {
	_ = ctx
	s.createCmd = cmd
	if s.createErr != nil {
		return services.ProductionQueue{}, s.createErr
	}
	return s.createResult, nil
}

func (s *stubAdminProductionQueueService) UpdateQueue(ctx context.Context, cmd services.UpsertProductionQueueCommand) (services.ProductionQueue, error) {
	_ = ctx
	s.updateCmd = cmd
	if s.updateErr != nil {
		return services.ProductionQueue{}, s.updateErr
	}
	return s.updateResult, nil
}

func (s *stubAdminProductionQueueService) DeleteQueue(ctx context.Context, cmd services.DeleteProductionQueueCommand) error {
	_ = ctx
	s.deleteCmd = cmd
	return s.deleteErr
}

func (s *stubAdminProductionQueueService) QueueWIPSummary(ctx context.Context, queueID string) (services.ProductionQueueWIPSummary, error) {
	_ = ctx
	s.wipQueueID = queueID
	if s.wipErr != nil {
		return services.ProductionQueueWIPSummary{}, s.wipErr
	}
	return s.wipResult, nil
}

func (s *stubAdminProductionQueueService) QueueMetricsRecorder() services.QueueDepthRecorder {
	return s.metrics
}

type queueDepthRecord struct {
	queueID string
	total   int
	counts  map[string]int
}

type captureQueueDepthRecorder struct {
	records []queueDepthRecord
}

func (c *captureQueueDepthRecorder) RecordQueueDepth(_ context.Context, queueID string, total int, statusCounts map[string]int) {
	cloned := make(map[string]int, len(statusCounts))
	for key, value := range statusCounts {
		cloned[key] = value
	}
	c.records = append(c.records, queueDepthRecord{
		queueID: queueID,
		total:   total,
		counts:  cloned,
	})
}
