package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminOperationsHandlers_StartBigQuerySyncAuthorization(t *testing.T) {
	service := &stubExportService{}
	handler := NewAdminOperationsHandlers(nil, service)

	req := httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewBufferString(`{"entities":["orders"]}`))
	rec := httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing identity, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewBufferString(`{"entities":["orders"]}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user"}))
	rec = httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 for missing admin/staff role, got %d", rec.Code)
	}
}

func TestAdminOperationsHandlers_StartBigQuerySyncServiceUnavailable(t *testing.T) {
	handler := NewAdminOperationsHandlers(nil, nil)
	req := httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewBufferString(`{"entities":["orders"]}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 when export service is nil, got %d", rec.Code)
	}
}

func TestAdminOperationsHandlers_StartBigQuerySyncInvalidJSON(t *testing.T) {
	service := &stubExportService{}
	handler := NewAdminOperationsHandlers(nil, service)

	req := httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewBufferString("{invalid"))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid json, got %d", rec.Code)
	}
}

func TestAdminOperationsHandlers_StartBigQuerySyncInvalidEntities(t *testing.T) {
	service := &stubExportService{}
	handler := NewAdminOperationsHandlers(nil, service)

	body := map[string]any{
		"entities": []string{"orders", "unknown"},
	}
	payload, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewReader(payload))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid entity, got %d", rec.Code)
	}
}

func TestAdminOperationsHandlers_StartBigQuerySyncInvalidTimeWindow(t *testing.T) {
	service := &stubExportService{}
	handler := NewAdminOperationsHandlers(nil, service)

	body := map[string]any{
		"entities": []string{"orders"},
		"timeWindow": map[string]string{
			"from": "2024-02-01T00:00:00Z",
			"to":   "2024-01-01T00:00:00Z",
		},
	}
	payload, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewReader(payload))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid time window, got %d", rec.Code)
	}
}

func TestAdminOperationsHandlers_StartBigQuerySyncServiceError(t *testing.T) {
	service := &stubExportService{
		err: services.ErrExportConflict,
	}
	handler := NewAdminOperationsHandlers(nil, service)

	body := map[string]any{
		"entities": []string{"orders"},
	}
	payload, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewReader(payload))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)
	if rec.Code != http.StatusConflict {
		t.Fatalf("expected 409 for export conflict, got %d", rec.Code)
	}
}

func TestAdminOperationsHandlers_StartBigQuerySyncSuccess(t *testing.T) {
	now := time.Date(2024, 7, 10, 15, 4, 5, 0, time.UTC)
	started := now.Add(5 * time.Minute)
	resultRef := "gs://bucket/path"

	service := &stubExportService{
		result: services.SystemTask{
			ID:             "task_123",
			Kind:           "export.bigquery",
			Status:         services.SystemTaskStatusPending,
			RequestedBy:    "admin",
			IdempotencyKey: "key-1",
			Parameters: map[string]any{
				"entities": []string{"orders", "users"},
			},
			ResultRef:    &resultRef,
			CreatedAt:    now,
			UpdatedAt:    now,
			StartedAt:    &started,
			CompletedAt:  nil,
			ErrorMessage: nil,
		},
	}
	handler := NewAdminOperationsHandlers(nil, service)

	body := map[string]any{
		"entities": []string{" Orders ", "Users", "orders"},
		"timeWindow": map[string]string{
			"from": "2024-01-01T00:00:00Z",
			"to":   "2024-01-31T23:59:59Z",
		},
		"idempotencyKey": " key-1 ",
	}
	payload, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/exports:bigquery-sync", bytes.NewReader(payload))
	req.Header.Set("Idempotency-Key", "header-key")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: " admin ", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.startBigQuerySync(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", rec.Code)
	}

	cmd := service.lastCommand()
	if cmd.ActorID != "admin" {
		t.Fatalf("expected actor admin, got %q", cmd.ActorID)
	}
	if len(cmd.Entities) != 2 || cmd.Entities[0] != "orders" || cmd.Entities[1] != "users" {
		t.Fatalf("unexpected entities %v", cmd.Entities)
	}
	if cmd.IdempotencyKey != "key-1" {
		t.Fatalf("expected idempotency key key-1, got %q", cmd.IdempotencyKey)
	}
	if cmd.Window == nil || cmd.Window.From == nil || cmd.Window.To == nil {
		t.Fatalf("expected window to be set, got %+v", cmd.Window)
	}
	if from := cmd.Window.From.Format(time.RFC3339); from != "2024-01-01T00:00:00Z" {
		t.Fatalf("unexpected window from %s", from)
	}
	if to := cmd.Window.To.Format(time.RFC3339); to != "2024-01-31T23:59:59Z" {
		t.Fatalf("unexpected window to %s", to)
	}

	var resp struct {
		Task struct {
			ID             string         `json:"id"`
			Kind           string         `json:"kind"`
			Status         string         `json:"status"`
			RequestedBy    string         `json:"requested_by"`
			IdempotencyKey string         `json:"idempotency_key"`
			Parameters     map[string]any `json:"parameters"`
			ResultRef      *string        `json:"result_ref"`
			CreatedAt      string         `json:"created_at"`
			UpdatedAt      string         `json:"updated_at"`
			StartedAt      string         `json:"started_at"`
			CompletedAt    string         `json:"completed_at"`
		} `json:"task"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Task.ID != "task_123" || resp.Task.Kind != "export.bigquery" {
		t.Fatalf("unexpected response task %+v", resp.Task)
	}
	if resp.Task.Status != string(services.SystemTaskStatusPending) {
		t.Fatalf("expected status pending, got %s", resp.Task.Status)
	}
	if resp.Task.IdempotencyKey != "key-1" {
		t.Fatalf("expected idempotency key key-1, got %s", resp.Task.IdempotencyKey)
	}
	if resp.Task.CreatedAt != formatTime(now) {
		t.Fatalf("expected createdAt %s, got %s", formatTime(now), resp.Task.CreatedAt)
	}
	if resp.Task.UpdatedAt != formatTime(now) {
		t.Fatalf("expected updatedAt %s, got %s", formatTime(now), resp.Task.UpdatedAt)
	}
	if resp.Task.StartedAt != formatTime(started) {
		t.Fatalf("expected startedAt %s, got %s", formatTime(started), resp.Task.StartedAt)
	}
	if resp.Task.CompletedAt != "" {
		t.Fatalf("expected empty completedAt, got %s", resp.Task.CompletedAt)
	}
	if resp.Task.ResultRef == nil || *resp.Task.ResultRef != resultRef {
		t.Fatalf("expected resultRef %s, got %+v", resultRef, resp.Task.ResultRef)
	}
	if resp.Task.Parameters == nil {
		t.Fatalf("expected parameters to be present")
	}
}

type stubExportService struct {
	mu       sync.Mutex
	commands []services.BigQueryExportCommand
	result   services.SystemTask
	err      error
}

func (s *stubExportService) StartBigQuerySync(ctx context.Context, cmd services.BigQueryExportCommand) (services.SystemTask, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.commands = append(s.commands, cmd)
	if s.err != nil {
		return services.SystemTask{}, s.err
	}
	return s.result, nil
}

func (s *stubExportService) lastCommand() services.BigQueryExportCommand {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.commands) == 0 {
		return services.BigQueryExportCommand{}
	}
	return s.commands[len(s.commands)-1]
}
