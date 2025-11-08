package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/hanko-field/api/internal/services"
)

func TestInternalInvoiceHandlers_IssueInvoiceSuccess(t *testing.T) {
	var captured services.IssueInvoiceCommand

	service := &stubInternalInvoiceService{
		issueFn: func(ctx context.Context, cmd services.IssueInvoiceCommand) (services.IssuedInvoice, error) {
			captured = cmd
			return services.IssuedInvoice{
				OrderID:       "order_123",
				InvoiceNumber: "INV-2025-000001",
				PDFAssetRef:   "/assets/orders/order_123/invoices/INV-2025-000001.pdf",
			}, nil
		},
	}

	handler := NewInternalInvoiceHandlers(service)

	body := `{"orderRef":" /orders/order_123 ","actorId":" system ","notes":" send "}`
	req := httptest.NewRequest(http.MethodPost, "/invoices/issue-one", strings.NewReader(body))
	rec := httptest.NewRecorder()

	handler.issueInvoice(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	if captured.OrderID != "" {
		t.Fatalf("expected order id empty when only ref provided, got %q", captured.OrderID)
	}
	if captured.OrderRef != "/orders/order_123" {
		t.Fatalf("expected order ref trimmed, got %q", captured.OrderRef)
	}
	if captured.ActorID != "system" {
		t.Fatalf("expected actor id trimmed, got %q", captured.ActorID)
	}
	if strings.TrimSpace(captured.Notes) != "send" {
		t.Fatalf("expected notes preserved, got %q", captured.Notes)
	}

	var resp internalIssueInvoiceResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.OrderID != "order_123" {
		t.Fatalf("expected order id order_123, got %q", resp.OrderID)
	}
	if resp.OrderRef != "/orders/order_123" {
		t.Fatalf("expected order ref /orders/order_123, got %q", resp.OrderRef)
	}
	if resp.InvoiceNumber != "INV-2025-000001" {
		t.Fatalf("expected invoice number, got %q", resp.InvoiceNumber)
	}
	if resp.PDFAssetRef == "" {
		t.Fatalf("expected pdf asset ref, got empty")
	}
}

func TestInternalInvoiceHandlers_IssueInvoiceInvalidJSON(t *testing.T) {
	handler := NewInternalInvoiceHandlers(&stubInternalInvoiceService{})

	req := httptest.NewRequest(http.MethodPost, "/invoices/issue-one", strings.NewReader("{"))
	rec := httptest.NewRecorder()

	handler.issueInvoice(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}

	var payload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode error: %v", err)
	}
	if payload["error"] != "invalid_json" {
		t.Fatalf("expected error code invalid_json, got %v", payload["error"])
	}
}

func TestInternalInvoiceHandlers_IssueInvoiceValidation(t *testing.T) {
	handler := NewInternalInvoiceHandlers(&stubInternalInvoiceService{})

	req := httptest.NewRequest(http.MethodPost, "/invoices/issue-one", strings.NewReader(`{"actorId":"system"}`))
	rec := httptest.NewRecorder()
	handler.issueInvoice(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400 when order ref missing, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodPost, "/invoices/issue-one", strings.NewReader(`{"orderRef":"/orders/abc"}`))
	rec = httptest.NewRecorder()
	handler.issueInvoice(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400 when actor missing, got %d", rec.Code)
	}
}

func TestInternalInvoiceHandlers_IssueInvoiceServiceError(t *testing.T) {
	service := &stubInternalInvoiceService{
		issueFn: func(context.Context, services.IssueInvoiceCommand) (services.IssuedInvoice, error) {
			return services.IssuedInvoice{}, services.ErrInvoiceOrderNotFound
		},
	}
	handler := NewInternalInvoiceHandlers(service)

	req := httptest.NewRequest(http.MethodPost, "/invoices/issue-one", strings.NewReader(`{"orderId":"missing","actorId":"system"}`))
	rec := httptest.NewRecorder()
	handler.issueInvoice(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", rec.Code)
	}

	var payload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode error: %v", err)
	}
	if payload["error"] != "order_not_found" {
		t.Fatalf("expected error code order_not_found, got %v", payload["error"])
	}
}

func TestInternalInvoiceHandlers_IssueInvoiceServiceUnavailable(t *testing.T) {
	handler := NewInternalInvoiceHandlers(nil)

	req := httptest.NewRequest(http.MethodPost, "/invoices/issue-one", strings.NewReader(`{"orderId":"o1","actorId":"system"}`))
	rec := httptest.NewRecorder()
	handler.issueInvoice(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected status 503, got %d", rec.Code)
	}
}

type stubInternalInvoiceService struct {
	issueFn func(context.Context, services.IssueInvoiceCommand) (services.IssuedInvoice, error)
	batchFn func(context.Context, services.IssueInvoicesCommand) (services.IssueInvoicesResult, error)
}

func (s *stubInternalInvoiceService) IssueInvoice(ctx context.Context, cmd services.IssueInvoiceCommand) (services.IssuedInvoice, error) {
	if s.issueFn != nil {
		return s.issueFn(ctx, cmd)
	}
	return services.IssuedInvoice{}, nil
}

func (s *stubInternalInvoiceService) IssueInvoices(ctx context.Context, cmd services.IssueInvoicesCommand) (services.IssueInvoicesResult, error) {
	if s.batchFn != nil {
		return s.batchFn(ctx, cmd)
	}
	return services.IssueInvoicesResult{}, nil
}
