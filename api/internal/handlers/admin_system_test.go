package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminSystemHandlers_ListSystemErrorsAuthorization(t *testing.T) {
	handler := NewAdminSystemHandlers(nil, &stubAdminSystemService{})

	req := httptest.NewRequest(http.MethodGet, "/system/errors", nil)
	rec := httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing identity, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodGet, "/system/errors", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user"}))
	rec = httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 for missing admin/staff role, got %d", rec.Code)
	}
}

func TestAdminSystemHandlers_ListSystemErrorsServiceUnavailable(t *testing.T) {
	handler := NewAdminSystemHandlers(nil, nil)
	req := httptest.NewRequest(http.MethodGet, "/system/errors", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 when system service missing, got %d", rec.Code)
	}
}

func TestAdminSystemHandlers_ListSystemErrorsInvalidPageSize(t *testing.T) {
	handler := NewAdminSystemHandlers(nil, &stubAdminSystemService{})
	req := httptest.NewRequest(http.MethodGet, "/system/errors?pageSize=abc", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid page size, got %d", rec.Code)
	}
}

func TestAdminSystemHandlers_ListSystemErrorsRangeValidation(t *testing.T) {
	handler := NewAdminSystemHandlers(nil, &stubAdminSystemService{})
	req := httptest.NewRequest(http.MethodGet, "/system/errors?since=2024-01-02T00:00:00Z&until=2024-01-01T00:00:00Z", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid range, got %d", rec.Code)
	}
}

func TestAdminSystemHandlers_ListSystemErrorsRedaction(t *testing.T) {
	now := time.Date(2024, 8, 1, 9, 0, 0, 0, time.UTC)
	taskRef := "task_1"
	retryEndpoint := "/internal/retry"

	service := &stubAdminSystemService{
		errorsResult: domain.CursorPage[domain.SystemError]{
			Items: []domain.SystemError{
				{
					ID:            "err_1",
					Source:        "queue",
					Queue:         "failed-jobs",
					Kind:          "worker",
					JobType:       "export.bigquery",
					Status:        "failed",
					Severity:      "critical",
					Code:          "EXPORT_FAILURE",
					Message:       "full details with PII",
					SafeMessage:   "sanitised failure",
					Occurrences:   3,
					Retryable:     true,
					RetryEndpoint: &retryEndpoint,
					RetryMethod:   "POST",
					TaskRef:       &taskRef,
					Metadata: map[string]any{
						"jobId": "job_1",
					},
					Sensitive: map[string]any{
						"email": "user@example.com",
					},
					FirstOccurredAt: now.Add(-2 * time.Hour),
					LastOccurredAt:  now,
					CreatedAt:       now.Add(-2 * time.Hour),
					UpdatedAt:       now,
				},
			},
			NextPageToken: "next-token",
		},
	}

	handler := NewAdminSystemHandlers(nil, service)
	values := url.Values{}
	values.Set("status", "FAILED")
	values.Set("severity", "Critical")
	values.Set("source", "Queue.Failures")
	values.Set("jobType", "Export.BigQuery")
	values.Set("search", "  fail  ")
	values.Set("since", "2024-08-01T08:00:00Z")
	values.Set("until", "2024-08-01T09:00:00Z")
	values.Set("pageSize", "10")
	req := httptest.NewRequest(http.MethodGet, "/system/errors?"+values.Encode(), nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	if header := rec.Header().Get("X-Next-Page-Token"); header != "next-token" {
		t.Fatalf("expected X-Next-Page-Token header, got %q", header)
	}

	var body struct {
		Items []adminSystemErrorResponse `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(body.Items) != 1 {
		t.Fatalf("expected one item, got %d", len(body.Items))
	}
	item := body.Items[0]
	if item.Message != "sanitised failure" {
		t.Fatalf("expected safe message, got %q", item.Message)
	}
	if !item.SensitiveRedacted {
		t.Fatalf("expected sensitive data to be redacted")
	}
	if item.Sensitive != nil {
		t.Fatalf("expected no sensitive data for staff, got %+v", item.Sensitive)
	}
	if item.RetryEndpoint != "/internal/retry" || item.RetryMethod != "POST" {
		t.Fatalf("unexpected retry info %+v", item)
	}
	if service.errorsFilter.Pagination.PageSize != 10 {
		t.Fatalf("expected page size 10, got %d", service.errorsFilter.Pagination.PageSize)
	}
	if got := service.errorsFilter.Statuses; len(got) != 1 || !strings.EqualFold(got[0], "failed") {
		t.Fatalf("expected status filter normalised, got %v", got)
	}
	if got := service.errorsFilter.Severities; len(got) != 1 || !strings.EqualFold(got[0], "critical") {
		t.Fatalf("expected severity filter normalised, got %v", got)
	}
	if got := service.errorsFilter.Sources; len(got) != 1 || !strings.EqualFold(got[0], "queue.failures") {
		t.Fatalf("expected source filter normalised, got %v", got)
	}
	if got := service.errorsFilter.JobTypes; len(got) != 1 || !strings.EqualFold(got[0], "export.bigquery") {
		t.Fatalf("expected job type filter normalised, got %v", got)
	}
}

func TestAdminSystemHandlers_ListSystemErrorsAdminView(t *testing.T) {
	retryEndpoint := "/internal/retry"
	service := &stubAdminSystemService{
		errorsResult: domain.CursorPage[domain.SystemError]{
			Items: []domain.SystemError{
				{
					ID:            "err_2",
					Message:       "full message",
					SafeMessage:   "safe",
					Sensitive:     map[string]any{"email": "user@example.com"},
					RetryEndpoint: &retryEndpoint,
				},
			},
		},
	}

	handler := NewAdminSystemHandlers(nil, service)
	req := httptest.NewRequest(http.MethodGet, "/system/errors", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Items []adminSystemErrorResponse `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(body.Items) != 1 {
		t.Fatalf("expected one item, got %d", len(body.Items))
	}
	item := body.Items[0]
	if item.Message != "full message" {
		t.Fatalf("expected full message, got %q", item.Message)
	}
	if item.SensitiveRedacted {
		t.Fatalf("did not expect redaction flag for admin")
	}
	if item.Sensitive == nil || item.Sensitive["email"] != "user@example.com" {
		t.Fatalf("expected sensitive data for admin, got %+v", item.Sensitive)
	}
}

func TestAdminSystemHandlers_ListSystemErrorsServiceError(t *testing.T) {
	service := &stubAdminSystemService{
		errorsErr: errors.New("system service: error store not configured"),
	}
	handler := NewAdminSystemHandlers(nil, service)
	req := httptest.NewRequest(http.MethodGet, "/system/errors", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listSystemErrors(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 for not configured, got %d", rec.Code)
	}
}

func TestAdminSystemHandlers_ListSystemTasksInvalidStatus(t *testing.T) {
	handler := NewAdminSystemHandlers(nil, &stubAdminSystemService{})
	req := httptest.NewRequest(http.MethodGet, "/system/tasks?status=unknown", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listSystemTasks(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid status, got %d", rec.Code)
	}
}

func TestAdminSystemHandlers_ListSystemTasksSuccess(t *testing.T) {
	now := time.Date(2024, 9, 1, 12, 0, 0, 0, time.UTC)
	task := domain.SystemTask{
		ID:          "task_1",
		Kind:        "export.bigquery",
		Status:      domain.SystemTaskStatusPending,
		RequestedBy: "admin",
		CreatedAt:   now.Add(-time.Minute),
		UpdatedAt:   now,
	}

	service := &stubAdminSystemService{
		tasksResult: domain.CursorPage[domain.SystemTask]{
			Items:         []domain.SystemTask{task},
			NextPageToken: "next",
		},
	}

	handler := NewAdminSystemHandlers(nil, service)
	req := httptest.NewRequest(http.MethodGet, "/system/tasks?status=pending&kind=export.bigquery&pageSize=5", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.listSystemTasks(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	if header := rec.Header().Get("X-Next-Page-Token"); header != "next" {
		t.Fatalf("expected next page token, got %q", header)
	}

	var body struct {
		Items []adminSystemTaskResponse `json:"items"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(body.Items) != 1 || body.Items[0].ID != "task_1" {
		t.Fatalf("unexpected response: %+v", body.Items)
	}
	if got := service.tasksFilter.Statuses; len(got) != 1 || got[0] != services.SystemTaskStatusPending {
		t.Fatalf("expected status filter to include pending, got %v", got)
	}
	if got := service.tasksFilter.Kinds; len(got) != 1 || got[0] != "export.bigquery" {
		t.Fatalf("expected kinds filter, got %v", got)
	}
	if service.tasksFilter.Pagination.PageSize != 5 {
		t.Fatalf("expected page size 5, got %d", service.tasksFilter.Pagination.PageSize)
	}
}

type stubAdminSystemService struct {
	errorsFilter services.SystemErrorFilter
	errorsResult domain.CursorPage[domain.SystemError]
	errorsErr    error

	tasksFilter services.SystemTaskFilter
	tasksResult domain.CursorPage[domain.SystemTask]
	tasksErr    error
}

func (s *stubAdminSystemService) HealthReport(context.Context) (services.SystemHealthReport, error) {
	return services.SystemHealthReport{}, nil
}

func (s *stubAdminSystemService) ListAuditLogs(context.Context, services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	return domain.CursorPage[domain.AuditLogEntry]{}, nil
}

func (s *stubAdminSystemService) ListSystemErrors(ctx context.Context, filter services.SystemErrorFilter) (domain.CursorPage[domain.SystemError], error) {
	s.errorsFilter = filter
	return s.errorsResult, s.errorsErr
}

func (s *stubAdminSystemService) ListSystemTasks(ctx context.Context, filter services.SystemTaskFilter) (domain.CursorPage[domain.SystemTask], error) {
	s.tasksFilter = filter
	return s.tasksResult, s.tasksErr
}

func (s *stubAdminSystemService) NextCounterValue(context.Context, services.CounterCommand) (int64, error) {
	return 0, nil
}

var _ services.SystemService = (*stubAdminSystemService)(nil)
