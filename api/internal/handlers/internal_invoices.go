package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/platform/observability"
	"github.com/hanko-field/api/internal/services"
)

const maxInternalInvoiceBodySize = 2 * 1024

// InternalInvoiceHandlers exposes invoice issuance operations for internal consumers.
type InternalInvoiceHandlers struct {
	invoices services.InvoiceService
}

// NewInternalInvoiceHandlers constructs handlers for internal invoice endpoints.
func NewInternalInvoiceHandlers(invoices services.InvoiceService) *InternalInvoiceHandlers {
	return &InternalInvoiceHandlers{invoices: invoices}
}

// Routes registers internal invoice routes.
func (h *InternalInvoiceHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/invoices/issue-one", h.issueInvoice)
}

type internalIssueInvoiceRequest struct {
	OrderID  string `json:"orderId"`
	OrderRef string `json:"orderRef"`
	ActorID  string `json:"actorId"`
	Notes    string `json:"notes"`
}

type internalIssueInvoiceResponse struct {
	OrderID       string `json:"orderId"`
	OrderRef      string `json:"orderRef,omitempty"`
	InvoiceNumber string `json:"invoiceNumber"`
	PDFAssetRef   string `json:"pdfAssetRef,omitempty"`
}

func (h *InternalInvoiceHandlers) issueInvoice(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h == nil || h.invoices == nil {
		httpx.WriteError(ctx, w, httpx.NewError("invoice_service_unavailable", "invoice service unavailable", http.StatusServiceUnavailable))
		return
	}

	body, err := readLimitedBody(r, maxInternalInvoiceBodySize)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body too large", http.StatusRequestEntityTooLarge))
		return
	}

	var payload internalIssueInvoiceRequest
	if len(body) > 0 {
		if err := json.Unmarshal(body, &payload); err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_json", "request body must be valid JSON", http.StatusBadRequest))
			return
		}
	}

	orderID := strings.TrimSpace(payload.OrderID)
	orderRef := strings.TrimSpace(payload.OrderRef)
	if orderID == "" && orderRef == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_invoice_request", "orderId or orderRef is required", http.StatusBadRequest))
		return
	}

	actorID := strings.TrimSpace(payload.ActorID)
	if actorID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_invoice_request", "actorId is required", http.StatusBadRequest))
		return
	}

	cmd := services.IssueInvoiceCommand{
		OrderID:  orderID,
		OrderRef: orderRef,
		ActorID:  actorID,
		Notes:    payload.Notes,
	}

	issued, err := h.invoices.IssueInvoice(ctx, cmd)
	if err != nil {
		writeAdminInvoiceError(ctx, w, err)
		return
	}

	resp := internalIssueInvoiceResponse{
		OrderID:       issued.OrderID,
		OrderRef:      normalizeInvoiceOrderRef(issued.OrderID, orderRef),
		InvoiceNumber: issued.InvoiceNumber,
		PDFAssetRef:   issued.PDFAssetRef,
	}

	logger := observability.FromContext(ctx).Named("internal.invoices")
	logger.Info("invoice issued",
		zap.String("orderId", resp.OrderID),
		zap.String("invoiceNumber", resp.InvoiceNumber),
	)

	writeJSONResponse(w, http.StatusOK, resp)
}

func normalizeInvoiceOrderRef(orderID, orderRef string) string {
	ref := strings.TrimSpace(orderRef)
	if ref != "" {
		if strings.HasPrefix(ref, "/orders/") {
			return ref
		}
		segments := strings.Split(ref, "/")
		for i := len(segments) - 1; i >= 0; i-- {
			if part := strings.TrimSpace(segments[i]); part != "" {
				return "/orders/" + part
			}
		}
	}
	id := strings.TrimSpace(orderID)
	if id == "" {
		return ""
	}
	return "/orders/" + id
}
