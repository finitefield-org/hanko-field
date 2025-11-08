package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const maxAdminInvoiceBodySize = 4 * 1024

// AdminInvoiceHandlers exposes operations utilities for invoice issuance.
type AdminInvoiceHandlers struct {
	authn    *auth.Authenticator
	invoices services.InvoiceService
}

// NewAdminInvoiceHandlers constructs invoice handlers for admin routes.
func NewAdminInvoiceHandlers(authn *auth.Authenticator, invoices services.InvoiceService) *AdminInvoiceHandlers {
	return &AdminInvoiceHandlers{
		authn:    authn,
		invoices: invoices,
	}
}

// Routes registers invoice routes against the provided router.
func (h *AdminInvoiceHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Post("/invoices:issue", h.issueInvoices)
}

type adminIssueInvoicesRequest struct {
	OrderIDs     []string `json:"orderIds"`
	Statuses     []string `json:"statuses"`
	PlacedAfter  *string  `json:"placedAfter"`
	PlacedBefore *string  `json:"placedBefore"`
	Limit        *int     `json:"limit"`
	Notes        string   `json:"notes"`
}

type adminIssuedInvoice struct {
	OrderID       string `json:"orderId"`
	InvoiceNumber string `json:"invoiceNumber"`
	PDFAssetRef   string `json:"pdfAssetRef"`
}

type adminInvoiceBatchSummary struct {
	Total  int `json:"total"`
	Issued int `json:"issued"`
	Failed int `json:"failed"`
}

type adminInvoiceFailure struct {
	OrderID string `json:"orderId"`
	Error   string `json:"error"`
}

type adminIssueInvoicesResponse struct {
	JobID    string                   `json:"jobId"`
	Summary  adminInvoiceBatchSummary `json:"summary"`
	Invoices []adminIssuedInvoice     `json:"invoices"`
	Failures []adminInvoiceFailure    `json:"failures,omitempty"`
}

func (h *AdminInvoiceHandlers) issueInvoices(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h.invoices == nil {
		httpx.WriteError(ctx, w, httpx.NewError("invoice_service_unavailable", "invoice service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	body, err := readLimitedBody(r, maxAdminInvoiceBodySize)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body too large", http.StatusRequestEntityTooLarge))
		return
	}

	var payload adminIssueInvoicesRequest
	if len(body) > 0 {
		if err := json.Unmarshal(body, &payload); err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_json", "request body must be valid JSON", http.StatusBadRequest))
			return
		}
	}

	var filter services.InvoiceBatchFilter
	if payload.PlacedAfter != nil {
		if ts := strings.TrimSpace(*payload.PlacedAfter); ts != "" {
			parsed, err := parseTimeParam(ts)
			if err != nil {
				httpx.WriteError(ctx, w, httpx.NewError("invalid_placed_after", "placedAfter must be RFC3339 timestamp", http.StatusBadRequest))
				return
			}
			from := parsed
			filter.PlacedRange.From = &from
		}
	}
	if payload.PlacedBefore != nil {
		if ts := strings.TrimSpace(*payload.PlacedBefore); ts != "" {
			parsed, err := parseTimeParam(ts)
			if err != nil {
				httpx.WriteError(ctx, w, httpx.NewError("invalid_placed_before", "placedBefore must be RFC3339 timestamp", http.StatusBadRequest))
				return
			}
			to := parsed
			filter.PlacedRange.To = &to
		}
	}
	filter.Statuses = payload.Statuses

	actorID := strings.TrimSpace(identity.UID)
	cmd := services.IssueInvoicesCommand{
		OrderIDs: payload.OrderIDs,
		Filter:   filter,
		ActorID:  actorID,
		Notes:    payload.Notes,
	}
	if payload.Limit != nil {
		cmd.Limit = *payload.Limit
	}

	result, err := h.invoices.IssueInvoices(ctx, cmd)
	if err != nil {
		writeAdminInvoiceError(ctx, w, err)
		return
	}

	resp := adminIssueInvoicesResponse{
		JobID:   result.JobID,
		Summary: adminInvoiceBatchSummary{Total: result.Summary.TotalOrders, Issued: result.Summary.Issued, Failed: result.Summary.Failed},
	}
	if len(result.Issued) > 0 {
		resp.Invoices = make([]adminIssuedInvoice, len(result.Issued))
		for i, issued := range result.Issued {
			resp.Invoices[i] = adminIssuedInvoice{
				OrderID:       issued.OrderID,
				InvoiceNumber: issued.InvoiceNumber,
				PDFAssetRef:   issued.PDFAssetRef,
			}
		}
	}
	if len(result.Failed) > 0 {
		resp.Failures = make([]adminInvoiceFailure, len(result.Failed))
		for i, failure := range result.Failed {
			resp.Failures[i] = adminInvoiceFailure{
				OrderID: failure.OrderID,
				Error:   failure.Error,
			}
		}
	}

	writeJSONResponse(w, http.StatusAccepted, resp)
}

func writeAdminInvoiceError(ctx context.Context, w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, services.ErrInvoiceInvalidInput):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_invoice_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrInvoiceOrderNotFound):
		httpx.WriteError(ctx, w, httpx.NewError("order_not_found", err.Error(), http.StatusNotFound))
	case errors.Is(err, services.ErrInvoiceConflict):
		httpx.WriteError(ctx, w, httpx.NewError("invoice_conflict", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrInvoiceRepositoryUnavailable):
		httpx.WriteError(ctx, w, httpx.NewError("invoice_repository_unavailable", "invoice repository unavailable", http.StatusServiceUnavailable))
	case errors.Is(err, services.ErrInvoiceGenerationFailed):
		httpx.WriteError(ctx, w, httpx.NewError("invoice_generation_failed", err.Error(), http.StatusInternalServerError))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("invoice_issue_failed", err.Error(), http.StatusInternalServerError))
	}
}
