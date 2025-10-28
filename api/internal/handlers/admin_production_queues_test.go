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
	handler := NewAdminProductionQueueHandlers(nil, &stubAdminProductionQueueService{})

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
	handler := NewAdminProductionQueueHandlers(nil, service)

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
	handler := NewAdminProductionQueueHandlers(nil, service)

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
	handler := NewAdminProductionQueueHandlers(nil, service)

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
	handler := NewAdminProductionQueueHandlers(nil, service)

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

func TestAdminProductionQueueHandlers_DeleteQueue_ErrorMapping(t *testing.T) {
	service := &stubAdminProductionQueueService{
		deleteErr: services.ErrProductionQueueHasAssignments,
	}
	handler := NewAdminProductionQueueHandlers(nil, service)

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
