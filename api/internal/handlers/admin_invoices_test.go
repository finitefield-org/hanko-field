package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminInvoiceHandlers_IssueInvoicesAuthorization(t *testing.T) {
	handler := NewAdminInvoiceHandlers(nil, &stubAdminInvoiceService{})

	req := httptest.NewRequest(http.MethodPost, "/invoices:issue", nil)
	rec := httptest.NewRecorder()
	handler.issueInvoices(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodPost, "/invoices:issue", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "user"}))
	rec = httptest.NewRecorder()
	handler.issueInvoices(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

func TestAdminInvoiceHandlers_IssueInvoicesSuccess(t *testing.T) {
	var captured services.IssueInvoicesCommand
	service := &stubAdminInvoiceService{
		issueFn: func(ctx context.Context, cmd services.IssueInvoicesCommand) (services.IssueInvoicesResult, error) {
			captured = cmd
			return services.IssueInvoicesResult{
				JobID: "job_123",
				Summary: services.InvoiceBatchSummary{
					TotalOrders: 1,
					Issued:      1,
					Failed:      0,
				},
				Issued: []services.IssuedInvoice{
					{OrderID: "order_1", InvoiceNumber: "INV-1", PDFAssetRef: "/assets/orders/order_1/invoices/INV-1.pdf"},
				},
				Failed: nil,
			}, nil
		},
	}
	handler := NewAdminInvoiceHandlers(nil, service)

	body := map[string]any{
		"orderIds":     []string{" order_1 "},
		"statuses":     []string{" paid "},
		"placedAfter":  "2025-05-01T00:00:00Z",
		"placedBefore": "2025-05-31T00:00:00Z",
		"limit":        5,
		"notes":        " please issue ",
	}
	payload, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/invoices:issue", bytes.NewReader(payload))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: " admin ", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.issueInvoices(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", rec.Code)
	}

	if captured.ActorID != "admin" {
		t.Fatalf("expected actor trimmed, got %q", captured.ActorID)
	}
	if captured.Limit != 5 {
		t.Fatalf("expected limit captured, got %d", captured.Limit)
	}
	if len(captured.OrderIDs) != 1 || captured.OrderIDs[0] != " order_1 " {
		t.Fatalf("expected order ids passed through, got %v", captured.OrderIDs)
	}
	if len(captured.Filter.Statuses) != 1 || captured.Filter.Statuses[0] != " paid " {
		t.Fatalf("expected statuses passed through, got %v", captured.Filter.Statuses)
	}
	if captured.Filter.PlacedRange.From == nil || captured.Filter.PlacedRange.To == nil {
		t.Fatalf("expected placed range set, got %+v", captured.Filter.PlacedRange)
	}
	expectedFrom, _ := time.Parse(time.RFC3339, "2025-05-01T00:00:00Z")
	if !captured.Filter.PlacedRange.From.Equal(expectedFrom) {
		t.Fatalf("expected placed from parsed, got %v", captured.Filter.PlacedRange.From)
	}
	if captured.Notes != " please issue " {
		t.Fatalf("expected notes captured, got %q", captured.Notes)
	}

	var resp adminIssueInvoicesResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp.JobID != "job_123" {
		t.Fatalf("expected job id job_123, got %q", resp.JobID)
	}
	if resp.Summary.Total != 1 || resp.Summary.Issued != 1 || resp.Summary.Failed != 0 {
		t.Fatalf("unexpected summary %+v", resp.Summary)
	}
	if len(resp.Invoices) != 1 || resp.Invoices[0].OrderID != "order_1" {
		t.Fatalf("expected issued invoice in response, got %+v", resp.Invoices)
	}
	if len(resp.Failures) != 0 {
		t.Fatalf("expected no failures, got %+v", resp.Failures)
	}
}

func TestAdminInvoiceHandlers_IssueInvoicesInvalidJSON(t *testing.T) {
	handler := NewAdminInvoiceHandlers(nil, &stubAdminInvoiceService{})

	req := httptest.NewRequest(http.MethodPost, "/invoices:issue", bytes.NewBufferString("{invalid"))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.issueInvoices(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 invalid json, got %d", rec.Code)
	}
}

func TestAdminInvoiceHandlers_IssueInvoicesServiceError(t *testing.T) {
	service := &stubAdminInvoiceService{
		issueFn: func(context.Context, services.IssueInvoicesCommand) (services.IssueInvoicesResult, error) {
			return services.IssueInvoicesResult{}, services.ErrInvoiceInvalidInput
		},
	}
	handler := NewAdminInvoiceHandlers(nil, service)

	req := httptest.NewRequest(http.MethodPost, "/invoices:issue", bytes.NewBufferString(`{"orderIds":["order_1"]}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.issueInvoices(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestAdminInvoiceHandlers_IssueInvoicesReturnsFailures(t *testing.T) {
	service := &stubAdminInvoiceService{
		issueFn: func(context.Context, services.IssueInvoicesCommand) (services.IssueInvoicesResult, error) {
			return services.IssueInvoicesResult{
				JobID: "job_fail",
				Summary: services.InvoiceBatchSummary{
					TotalOrders: 2,
					Issued:      1,
					Failed:      1,
				},
				Issued: []services.IssuedInvoice{
					{OrderID: "order_1", InvoiceNumber: "INV-1"},
				},
				Failed: []services.InvoiceFailure{
					{OrderID: "order_2", Error: "storage unavailable"},
				},
			}, nil
		},
	}
	handler := NewAdminInvoiceHandlers(nil, service)

	req := httptest.NewRequest(http.MethodPost, "/invoices:issue", bytes.NewBufferString(`{}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.issueInvoices(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", rec.Code)
	}

	var resp adminIssueInvoicesResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if len(resp.Failures) != 1 || resp.Failures[0].OrderID != "order_2" {
		t.Fatalf("expected failure entry, got %+v", resp.Failures)
	}
	if resp.Summary.Failed != 1 {
		t.Fatalf("expected summary failed 1, got %d", resp.Summary.Failed)
	}
}

type stubAdminInvoiceService struct {
	issueFn    func(context.Context, services.IssueInvoicesCommand) (services.IssueInvoicesResult, error)
	issueOneFn func(context.Context, services.IssueInvoiceCommand) (services.IssuedInvoice, error)
}

func (s *stubAdminInvoiceService) IssueInvoice(ctx context.Context, cmd services.IssueInvoiceCommand) (services.IssuedInvoice, error) {
	if s.issueOneFn != nil {
		return s.issueOneFn(ctx, cmd)
	}
	return services.IssuedInvoice{}, nil
}

func (s *stubAdminInvoiceService) IssueInvoices(ctx context.Context, cmd services.IssueInvoicesCommand) (services.IssueInvoicesResult, error) {
	if s.issueFn != nil {
		return s.issueFn(ctx, cmd)
	}
	return services.IssueInvoicesResult{}, nil
}
