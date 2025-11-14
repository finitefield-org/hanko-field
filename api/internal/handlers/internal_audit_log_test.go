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

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

type stubInternalAuditService struct {
	recorded bool
	record   services.AuditLogRecord
	ctx      context.Context
}

func (s *stubInternalAuditService) Record(ctx context.Context, record services.AuditLogRecord) {
	s.recorded = true
	s.record = record
	s.ctx = ctx
}

func (s *stubInternalAuditService) List(context.Context, services.AuditLogFilter) (domain.CursorPage[services.AuditLogEntry], error) {
	return domain.CursorPage[services.AuditLogEntry]{}, nil
}

func TestInternalAuditLogAppendSuccess(t *testing.T) {
	service := &stubInternalAuditService{}
	handler := NewInternalAuditLogHandlers(
		service,
		WithInternalAuditLogIDGenerator(func() string { return "audit-123" }),
	)

	payload := map[string]any{
		"actor":                 " user:42 ",
		"actorType":             "automation",
		"action":                "order.update",
		"targetRef":             " orders/1001 ",
		"severity":              "WARN",
		"requestId":             " req-42 ",
		"occurredAt":            "2024-06-15T10:00:00Z",
		"metadata":              map[string]any{"reason": "status change"},
		"diff":                  map[string]any{"status": map[string]any{"before": "draft", "after": "confirmed"}},
		"sensitiveMetadataKeys": []any{" reason ", "reason"},
		"sensitiveDiffKeys":     []any{" status "},
		"ipAddress":             "198.51.100.10 ",
		"userAgent":             " ServiceClient/1.0 ",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/internal/audit-log", bytes.NewReader(body))
	req = req.WithContext(auth.WithServiceIdentity(req.Context(), &auth.ServiceIdentity{Subject: "svc:checkout"}))
	rec := httptest.NewRecorder()

	handler.appendAuditLog(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d: %s", rec.Code, rec.Body.String())
	}
	var resp internalAuditLogResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.ID != "audit-123" {
		t.Fatalf("expected id audit-123, got %q", resp.ID)
	}

	if !service.recorded {
		t.Fatalf("expected record invoked")
	}
	if service.record.ID != "audit-123" {
		t.Fatalf("expected record id, got %q", service.record.ID)
	}
	if service.record.Actor != "user:42" {
		t.Fatalf("expected actor trimmed, got %q", service.record.Actor)
	}
	if service.record.TargetRef != "orders/1001" {
		t.Fatalf("expected targetRef trimmed, got %q", service.record.TargetRef)
	}
	if service.record.Action != "order.update" {
		t.Fatalf("expected action, got %q", service.record.Action)
	}
	if service.record.Severity != "WARN" {
		t.Fatalf("expected severity preserved, got %q", service.record.Severity)
	}
	if service.record.RequestID != "req-42" {
		t.Fatalf("expected request id trimmed, got %q", service.record.RequestID)
	}
	expectedTime := time.Date(2024, 6, 15, 10, 0, 0, 0, time.UTC)
	if !service.record.OccurredAt.Equal(expectedTime) {
		t.Fatalf("expected occurredAt %s, got %s", expectedTime.Format(time.RFC3339), service.record.OccurredAt.Format(time.RFC3339))
	}
	if len(service.record.Metadata) != 1 || service.record.Metadata["reason"] != "status change" {
		t.Fatalf("unexpected metadata %#v", service.record.Metadata)
	}
	diff, ok := service.record.Diff["status"]
	if !ok {
		t.Fatalf("expected diff for status")
	}
	if diff.Before != "draft" || diff.After != "confirmed" {
		t.Fatalf("unexpected diff %#v", diff)
	}
	if len(service.record.SensitiveMetadataKeys) != 1 || service.record.SensitiveMetadataKeys[0] != "reason" {
		t.Fatalf("unexpected sensitive metadata keys %#v", service.record.SensitiveMetadataKeys)
	}
	if len(service.record.SensitiveDiffKeys) != 1 || service.record.SensitiveDiffKeys[0] != "status" {
		t.Fatalf("unexpected sensitive diff keys %#v", service.record.SensitiveDiffKeys)
	}
	if service.record.IPAddress != "198.51.100.10" {
		t.Fatalf("expected trimmed ip, got %q", service.record.IPAddress)
	}
	if service.record.UserAgent != "ServiceClient/1.0" {
		t.Fatalf("expected trimmed user agent, got %q", service.record.UserAgent)
	}
	if svc, ok := auth.ServiceIdentityFromContext(service.ctx); !ok || svc == nil || svc.Subject != "svc:checkout" {
		t.Fatalf("expected service identity propagated, got %#v", svc)
	}
}

func TestInternalAuditLogAppendRequiresAuth(t *testing.T) {
	service := &stubInternalAuditService{}
	handler := NewInternalAuditLogHandlers(service)

	req := httptest.NewRequest(http.MethodPost, "/internal/audit-log", strings.NewReader(`{"actor":"foo","action":"bar","targetRef":"baz"}`))
	rec := httptest.NewRecorder()

	handler.appendAuditLog(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
	if service.recorded {
		t.Fatalf("expected no record invocation")
	}
}

func TestInternalAuditLogAppendValidatesRequiredFields(t *testing.T) {
	service := &stubInternalAuditService{}
	handler := NewInternalAuditLogHandlers(service)

	req := httptest.NewRequest(http.MethodPost, "/internal/audit-log", strings.NewReader(`{"actor":"","action":"","targetRef":""}`))
	req = req.WithContext(auth.WithServiceIdentity(req.Context(), &auth.ServiceIdentity{Subject: "svc:test"}))
	rec := httptest.NewRecorder()

	handler.appendAuditLog(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
	if service.recorded {
		t.Fatalf("expected no record invocation")
	}
}

func TestInternalAuditLogAppendValidatesTimestamp(t *testing.T) {
	service := &stubInternalAuditService{}
	handler := NewInternalAuditLogHandlers(service)

	req := httptest.NewRequest(http.MethodPost, "/internal/audit-log", strings.NewReader(`{"actor":"a","action":"b","targetRef":"c","occurredAt":"not-time"}`))
	req = req.WithContext(auth.WithServiceIdentity(req.Context(), &auth.ServiceIdentity{Subject: "svc:test"}))
	rec := httptest.NewRecorder()

	handler.appendAuditLog(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid timestamp, got %d", rec.Code)
	}
	if service.recorded {
		t.Fatalf("expected not to record entry")
	}
}

func TestInternalAuditLogAppendServiceUnavailable(t *testing.T) {
	handler := NewInternalAuditLogHandlers(nil)

	req := httptest.NewRequest(http.MethodPost, "/internal/audit-log", strings.NewReader(`{"actor":"a","action":"b","targetRef":"c"}`))
	req = req.WithContext(auth.WithServiceIdentity(req.Context(), &auth.ServiceIdentity{Subject: "svc:test"}))
	rec := httptest.NewRecorder()

	handler.appendAuditLog(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 when service missing, got %d", rec.Code)
	}
}
