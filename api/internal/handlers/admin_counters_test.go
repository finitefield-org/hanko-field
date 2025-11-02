package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminCounterHandlers_NextCounterValueAuthorization(t *testing.T) {
	handler := NewAdminCounterHandlers(nil, &stubAdminCounterService{}, nil)

	req := httptest.NewRequest(http.MethodPost, "/counters/orders:next", nil)
	req = attachCounterRouteParam(req, "orders")
	rec := httptest.NewRecorder()
	handler.nextCounterValue(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing identity, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodPost, "/counters/orders:next", nil)
	req = attachCounterRouteParam(req, "orders")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user"}))
	rec = httptest.NewRecorder()
	handler.nextCounterValue(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 for insufficient role, got %d", rec.Code)
	}
}

func TestAdminCounterHandlers_NextCounterValueServiceUnavailable(t *testing.T) {
	handler := NewAdminCounterHandlers(nil, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/counters/orders:next", nil)
	req = attachCounterRouteParam(req, "orders")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.nextCounterValue(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}
}

func TestAdminCounterHandlers_NextCounterValueInvalidJSON(t *testing.T) {
	handler := NewAdminCounterHandlers(nil, &stubAdminCounterService{}, nil)

	req := httptest.NewRequest(http.MethodPost, "/counters/orders:next", bytes.NewBufferString("{invalid"))
	req = attachCounterRouteParam(req, "orders")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.nextCounterValue(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid json, got %d", rec.Code)
	}
}

func TestAdminCounterHandlers_NextCounterValueScopeRestriction(t *testing.T) {
	service := &stubAdminCounterService{
		result: services.CounterValue{Value: 1, Formatted: "1"},
	}
	handler := NewAdminCounterHandlers(nil, service, nil, WithAdminCounterAllowedScopes("orders", "invoices"))

	req := httptest.NewRequest(http.MethodPost, "/counters/exports:next", nil)
	req = attachCounterRouteParam(req, "exports")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()
	handler.nextCounterValue(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403 for disallowed scope, got %d", rec.Code)
	}
}

func TestAdminCounterHandlers_NextCounterValuePathSegment(t *testing.T) {
	var captured struct {
		scope   string
		segment string
	}
	service := &stubAdminCounterService{
		nextFn: func(ctx context.Context, scope, name string, opts services.CounterGenerationOptions) (services.CounterValue, error) {
			captured.scope = scope
			captured.segment = name
			return services.CounterValue{Value: 2, Formatted: "2"}, nil
		},
	}
	handler := NewAdminCounterHandlers(nil, service, nil, WithAdminCounterAllowedScopes("orders"))

	req := httptest.NewRequest(http.MethodPost, "/counters/orders:year=2025:next", nil)
	req = attachCounterRouteParam(req, "orders:year=2025")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff",
		Roles: []string{auth.RoleStaff},
	}))
	rec := httptest.NewRecorder()

	handler.nextCounterValue(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if captured.scope != "orders" {
		t.Fatalf("expected scope orders, got %q", captured.scope)
	}
	if captured.segment != "year=2025" {
		t.Fatalf("expected segment year=2025, got %q", captured.segment)
	}
}

func TestAdminCounterHandlers_NextCounterValueSuccess(t *testing.T) {
	var captured struct {
		scope string
		name  string
		opts  services.CounterGenerationOptions
	}
	service := &stubAdminCounterService{
		nextFn: func(ctx context.Context, scope, name string, opts services.CounterGenerationOptions) (services.CounterValue, error) {
			captured.scope = scope
			captured.name = name
			captured.opts = opts
			return services.CounterValue{Value: 101, Formatted: "ORD-2025-000101"}, nil
		},
	}

	audit := &captureCounterAuditService{}
	now := time.Date(2025, 5, 1, 9, 30, 0, 0, time.UTC)
	handler := NewAdminCounterHandlers(nil, service, audit,
		WithAdminCounterAllowedScopes("orders"),
		WithAdminCounterClock(func() time.Time { return now }),
	)

	body := map[string]any{
		"scope":     map[string]string{"year": "2025"},
		"step":      float64(1),
		"prefix":    " ORD-2025-",
		"padLength": float64(6),
	}
	payload, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/counters/orders:next", bytes.NewReader(payload))
	req = attachCounterRouteParam(req, "orders")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   " admin ",
		Roles: []string{auth.RoleAdmin},
	}))
	rec := httptest.NewRecorder()

	handler.nextCounterValue(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	if captured.scope != "orders" {
		t.Fatalf("expected scope orders, got %q", captured.scope)
	}
	if captured.name != "year=2025" {
		t.Fatalf("expected segment year=2025, got %q", captured.name)
	}
	if captured.opts.Step != 1 {
		t.Fatalf("expected step 1, got %d", captured.opts.Step)
	}
	if captured.opts.Prefix != "ORD-2025-" {
		t.Fatalf("expected trimmed prefix, got %q", captured.opts.Prefix)
	}
	if captured.opts.PadLength != 6 {
		t.Fatalf("expected pad length 6, got %d", captured.opts.PadLength)
	}

	var resp adminNextCounterResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.Number != "ORD-2025-000101" {
		t.Fatalf("expected formatted number, got %q", resp.Number)
	}

	auditRecords := audit.snapshot()
	if len(auditRecords) != 1 {
		t.Fatalf("expected one audit record, got %d", len(auditRecords))
	}
	record := auditRecords[0]
	if record.Actor != "admin" || record.ActorType != "admin" {
		t.Fatalf("unexpected actor info %+v", record)
	}
	if record.Action != "counter.next" {
		t.Fatalf("expected counter.next action, got %q", record.Action)
	}
	if record.TargetRef != "/counters/orders:year=2025" {
		t.Fatalf("unexpected target ref %q", record.TargetRef)
	}
	if record.OccurredAt != now {
		t.Fatalf("expected occurredAt to use injected clock")
	}
	if record.Metadata["formatted"] != "ORD-2025-000101" {
		t.Fatalf("expected metadata to include formatted, got %+v", record.Metadata)
	}
	if record.Metadata["step"] != int64(1) {
		t.Fatalf("expected metadata step 1, got %+v", record.Metadata["step"])
	}
}

func TestAdminCounterHandlers_NextCounterValueConcurrency(t *testing.T) {
	const iterations = 10
	service := &stubAdminCounterService{}
	audit := &captureCounterAuditService{}
	handler := NewAdminCounterHandlers(nil, service, audit, WithAdminCounterAllowedScopes("orders"))

	var wg sync.WaitGroup
	results := make(chan string, iterations)
	for i := 0; i < iterations; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			req := httptest.NewRequest(http.MethodPost, "/counters/orders:next", bytes.NewBufferString(`{}`))
			req = attachCounterRouteParam(req, "orders")
			req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
				UID:   "staff",
				Roles: []string{auth.RoleStaff},
			}))
			rec := httptest.NewRecorder()
			handler.nextCounterValue(rec, req)
			if rec.Code != http.StatusOK {
				t.Errorf("expected 200, got %d", rec.Code)
				return
			}
			var resp adminNextCounterResponse
			if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
				t.Errorf("failed to parse response: %v", err)
				return
			}
			results <- resp.Number
		}()
	}
	wg.Wait()
	close(results)

	outputs := make([]string, 0, iterations)
	for value := range results {
		outputs = append(outputs, value)
	}
	if len(outputs) != iterations {
		t.Fatalf("expected %d results, got %d", iterations, len(outputs))
	}
	if !isUnique(outputs) {
		t.Fatalf("expected unique counter values, got %v", outputs)
	}
	if len(audit.snapshot()) != iterations {
		t.Fatalf("expected %d audit records, got %d", iterations, len(audit.snapshot()))
	}
}

func attachCounterRouteParam(req *http.Request, name string) *http.Request {
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("name", name)
	return req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
}

type stubAdminCounterService struct {
	mu     sync.Mutex
	nextFn func(context.Context, string, string, services.CounterGenerationOptions) (services.CounterValue, error)
	result services.CounterValue
	count  int
}

func (s *stubAdminCounterService) Next(ctx context.Context, scope, name string, opts services.CounterGenerationOptions) (services.CounterValue, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.nextFn != nil {
		return s.nextFn(ctx, scope, name, opts)
	}
	s.count++
	if s.result.Formatted == "" {
		return services.CounterValue{Value: int64(s.count), Formatted: fmt.Sprintf("%d", s.count)}, nil
	}
	return s.result, nil
}

func (s *stubAdminCounterService) NextOrderNumber(context.Context) (string, error) {
	return "", errors.New("not implemented")
}

func (s *stubAdminCounterService) NextInvoiceNumber(context.Context) (string, error) {
	return "", errors.New("not implemented")
}

type captureCounterAuditService struct {
	mu      sync.Mutex
	records []services.AuditLogRecord
}

func (c *captureCounterAuditService) Record(_ context.Context, record services.AuditLogRecord) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.records = append(c.records, record)
}

func (c *captureCounterAuditService) List(context.Context, services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	return domain.CursorPage[domain.AuditLogEntry]{}, nil
}

func (c *captureCounterAuditService) snapshot() []services.AuditLogRecord {
	c.mu.Lock()
	defer c.mu.Unlock()
	cp := make([]services.AuditLogRecord, len(c.records))
	copy(cp, c.records)
	return cp
}

func isUnique(values []string) bool {
	if len(values) <= 1 {
		return true
	}
	sorted := make([]string, len(values))
	copy(sorted, values)
	sort.Strings(sorted)
	for i := 1; i < len(sorted); i++ {
		if sorted[i] == sorted[i-1] {
			return false
		}
	}
	return true
}
