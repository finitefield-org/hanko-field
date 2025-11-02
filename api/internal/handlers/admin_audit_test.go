package handlers

import (
	"context"
	"encoding/csv"
	"encoding/json"
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

type stubAuditLogService struct {
	listFn      func(ctx context.Context, filter services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error)
	lastFilter  services.AuditLogFilter
	listInvoked int
}

func (s *stubAuditLogService) Record(context.Context, services.AuditLogRecord) {}

func (s *stubAuditLogService) List(ctx context.Context, filter services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	s.lastFilter = filter
	s.listInvoked++
	if s.listFn != nil {
		return s.listFn(ctx, filter)
	}
	return domain.CursorPage[domain.AuditLogEntry]{}, nil
}

func TestAdminAuditHandlers_ListAuditLogs_ServiceUnavailable(t *testing.T) {
	handler := NewAdminAuditHandlers(nil, nil)

	req := httptest.NewRequest(http.MethodGet, "/audit-logs?targetRef=/orders/123", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-1",
		Roles: []string{auth.RoleStaff},
	}))
	rec := httptest.NewRecorder()

	handler.listAuditLogs(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected status 503, got %d", rec.Code)
	}
}

func TestAdminAuditHandlers_ListAuditLogs_TargetRefRequired(t *testing.T) {
	handler := NewAdminAuditHandlers(nil, &stubAuditLogService{})

	req := httptest.NewRequest(http.MethodGet, "/audit-logs", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-1",
		Roles: []string{auth.RoleStaff},
	}))
	rec := httptest.NewRecorder()

	handler.listAuditLogs(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("expected json response: %v", err)
	}
	if body["error"] != "invalid_request" {
		t.Fatalf("expected invalid_request error, got %v", body["error"])
	}
}

func TestAdminAuditHandlers_ListAuditLogs_RedactsForStaff(t *testing.T) {
	now := time.Date(2024, time.June, 1, 10, 0, 0, 0, time.UTC)
	service := &stubAuditLogService{
		listFn: func(ctx context.Context, filter services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
			return domain.CursorPage[domain.AuditLogEntry]{
				Items: []domain.AuditLogEntry{{
					ID:        "log-1",
					Actor:     "/users/user-1",
					ActorType: "staff",
					Action:    "order.update",
					TargetRef: "/orders/123",
					Severity:  "warn",
					RequestID: "req-123",
					IPHash:    "sha256:abc",
					UserAgent: "cli/1.0",
					CreatedAt: now,
					Metadata: map[string]any{
						"email": "hashed",
						"note":  "updated",
					},
					Diff: map[string]any{
						"status": map[string]any{
							"before": "draft",
							"after":  "ready",
						},
					},
				}},
				NextPageToken: "next-token",
			}, nil
		},
	}
	handler := NewAdminAuditHandlers(nil, service)

	req := httptest.NewRequest(http.MethodGet, "/audit-logs?targetRef=/orders/123", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-1",
		Roles: []string{auth.RoleStaff},
	}))
	rec := httptest.NewRecorder()

	handler.listAuditLogs(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var resp auditLogListResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(resp.Items) != 1 {
		t.Fatalf("expected single entry, got %d", len(resp.Items))
	}
	entry := resp.Items[0]
	if entry.Metadata != nil {
		t.Fatalf("expected metadata redacted, got %#v", entry.Metadata)
	}
	if !entry.MetadataRedacted {
		t.Fatalf("expected metadataRedacted flag set")
	}
	if entry.Diff != nil {
		t.Fatalf("expected diff redacted, got %#v", entry.Diff)
	}
	if !entry.DiffRedacted {
		t.Fatalf("expected diffRedacted flag set")
	}
	if entry.RequestID != "" {
		t.Fatalf("expected requestId redacted, got %q", entry.RequestID)
	}
	if entry.IPHash != "" {
		t.Fatalf("expected ipHash redacted, got %q", entry.IPHash)
	}
	if resp.NextPageToken != "next-token" {
		t.Fatalf("expected next page token propagated, got %q", resp.NextPageToken)
	}
	if entry.CreatedAt != formatTime(now) {
		t.Fatalf("expected createdAt formatted, got %q", entry.CreatedAt)
	}
}

func TestAdminAuditHandlers_ListAuditLogs_AdminSeesDetails(t *testing.T) {
	now := time.Date(2024, time.June, 2, 11, 0, 0, 0, time.UTC)
	service := &stubAuditLogService{
		listFn: func(ctx context.Context, filter services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
			return domain.CursorPage[domain.AuditLogEntry]{
				Items: []domain.AuditLogEntry{{
					ID:        "log-2",
					Actor:     "system",
					ActorType: "system",
					Action:    "order.status",
					TargetRef: "/orders/456",
					Severity:  "info",
					RequestID: "req-456",
					IPHash:    "sha256:def",
					UserAgent: "api/2.0",
					CreatedAt: now,
					Metadata: map[string]any{
						"field": "value",
					},
					Diff: map[string]any{
						"status": map[string]any{
							"before": "pending",
							"after":  "shipped",
						},
					},
				}},
			}, nil
		},
	}
	handler := NewAdminAuditHandlers(nil, service)

	req := httptest.NewRequest(http.MethodGet, "/audit-logs?targetRef=%20/orders/456%20&pageSize=120", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-1",
		Roles: []string{auth.RoleAdmin},
	}))
	rec := httptest.NewRecorder()

	handler.listAuditLogs(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var resp auditLogListResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(resp.Items) != 1 {
		t.Fatalf("expected single entry, got %d", len(resp.Items))
	}
	entry := resp.Items[0]
	if entry.Metadata == nil || entry.Metadata["field"] != "value" {
		t.Fatalf("expected metadata preserved, got %#v", entry.Metadata)
	}
	if entry.Diff == nil {
		t.Fatalf("expected diff present")
	}
	if entry.RequestID != "req-456" {
		t.Fatalf("expected request id preserved, got %q", entry.RequestID)
	}
	if entry.IPHash != "sha256:def" {
		t.Fatalf("expected ip hash preserved, got %q", entry.IPHash)
	}
	if entry.MetadataRedacted || entry.DiffRedacted {
		t.Fatalf("expected redaction flags false")
	}
	if service.lastFilter.TargetRef != "/orders/456" {
		t.Fatalf("expected target ref trimmed, got %q", service.lastFilter.TargetRef)
	}
	if service.lastFilter.Pagination.PageSize != 120 {
		t.Fatalf("expected page size propagated, got %d", service.lastFilter.Pagination.PageSize)
	}
}

func TestAdminAuditHandlers_ListAuditLogs_AppliesFilters(t *testing.T) {
	from := time.Date(2024, time.July, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2024, time.July, 2, 0, 0, 0, 0, time.UTC)
	service := &stubAuditLogService{}
	handler := NewAdminAuditHandlers(nil, service)

	values := url.Values{}
	values.Set("targetRef", " /orders/789 ")
	values.Set("pageToken", " token ")
	values.Set("from", from.Format(time.RFC3339))
	values.Set("to", to.Format(time.RFC3339))
	values.Set("actor", " /users/staff-2 ")
	values.Set("actorType", " staff ")
	values.Set("action", "order.cancel")
	req := httptest.NewRequest(http.MethodGet, "/audit-logs?"+values.Encode(), nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-2",
		Roles: []string{auth.RoleAdmin},
	}))
	rec := httptest.NewRecorder()

	handler.listAuditLogs(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	if service.listInvoked != 1 {
		t.Fatalf("expected list invoked once, got %d", service.listInvoked)
	}
	filter := service.lastFilter
	if filter.TargetRef != "/orders/789" {
		t.Fatalf("expected trimmed target ref, got %q", filter.TargetRef)
	}
	if filter.Pagination.PageToken != "token" {
		t.Fatalf("expected trimmed page token, got %q", filter.Pagination.PageToken)
	}
	if filter.Actor != "/users/staff-2" {
		t.Fatalf("expected actor trimmed, got %q", filter.Actor)
	}
	if filter.ActorType != "staff" {
		t.Fatalf("expected actor type trimmed, got %q", filter.ActorType)
	}
	if filter.Action != "order.cancel" {
		t.Fatalf("expected action propagated, got %q", filter.Action)
	}
	if filter.DateRange.From == nil || !filter.DateRange.From.Equal(from) {
		t.Fatalf("expected from time, got %#v", filter.DateRange.From)
	}
	if filter.DateRange.To == nil || !filter.DateRange.To.Equal(to) {
		t.Fatalf("expected to time, got %#v", filter.DateRange.To)
	}
}

func TestAdminAuditHandlers_ListAuditLogs_CSVExport(t *testing.T) {
	now := time.Date(2024, time.August, 10, 9, 30, 0, 0, time.UTC)
	service := &stubAuditLogService{
		listFn: func(ctx context.Context, filter services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
			return domain.CursorPage[domain.AuditLogEntry]{
				Items: []domain.AuditLogEntry{{
					ID:        "log-3",
					Actor:     "/users/user-3",
					ActorType: "staff",
					Action:    "order.note",
					TargetRef: "/orders/abc",
					Severity:  "warn",
					RequestID: "req-789",
					IPHash:    "sha256:ghi",
					UserAgent: "ops/1.2",
					CreatedAt: now,
					Metadata: map[string]any{
						"note": "handled",
					},
					Diff: map[string]any{
						"notes": map[string]any{
							"before": "",
							"after":  "added",
						},
					},
				}},
				NextPageToken: "csv-token",
			}, nil
		},
	}
	handler := NewAdminAuditHandlers(nil, service)

	req := httptest.NewRequest(http.MethodGet, "/audit-logs?targetRef=/orders/abc&format=csv", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-2",
		Roles: []string{auth.RoleStaff},
	}))
	rec := httptest.NewRecorder()

	handler.listAuditLogs(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); !strings.Contains(got, "text/csv") {
		t.Fatalf("expected csv content type, got %q", got)
	}
	if got := rec.Header().Get("Content-Disposition"); !strings.Contains(got, "audit-logs-orders-abc.csv") {
		t.Fatalf("expected sanitized filename, got %q", got)
	}
	if rec.Header().Get("X-Next-Page-Token") != "csv-token" {
		t.Fatalf("expected next page token header")
	}

	reader := csv.NewReader(strings.NewReader(rec.Body.String()))
	records, err := reader.ReadAll()
	if err != nil {
		t.Fatalf("failed to parse csv: %v", err)
	}
	if len(records) != 2 {
		t.Fatalf("expected header and one row, got %d", len(records))
	}
	header := records[0]
	if header[0] != "id" || header[10] != "metadata" || header[12] != "metadataRedacted" {
		t.Fatalf("unexpected header: %v", header)
	}
	row := records[1]
	if row[7] != "" || row[8] != "" {
		t.Fatalf("expected request id and ip hash redacted in csv, got %v %v", row[7], row[8])
	}
	if row[10] != "[redacted]" {
		t.Fatalf("expected metadata column redacted, got %q", row[10])
	}
	if row[11] != "[redacted]" {
		t.Fatalf("expected diff column redacted, got %q", row[11])
	}
	if row[12] != "true" || row[13] != "true" {
		t.Fatalf("expected redaction flags true, got %q %q", row[12], row[13])
	}
}
