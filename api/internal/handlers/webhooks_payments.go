package handlers

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	stripeWebhook "github.com/stripe/stripe-go/v78/webhook"

	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const maxStripeWebhookBodySize int64 = 64 * 1024

// StripeSecretFetcher resolves the signing secret used to validate webhook payloads.
type StripeSecretFetcher func(ctx context.Context) (string, error)

// PaymentWebhookHandlers exposes PSP webhook endpoints under /webhooks/payments.
type PaymentWebhookHandlers struct {
	payments  services.PaymentService
	secret    StripeSecretFetcher
	tolerance time.Duration
	clock     func() time.Time
}

// PaymentWebhookOption customises the webhook handler behaviour.
type PaymentWebhookOption func(*PaymentWebhookHandlers)

const defaultStripeTolerance = 5 * time.Minute

// WithStripeTolerance overrides the signature tolerance window used for Stripe webhooks.
func WithStripeTolerance(tolerance time.Duration) PaymentWebhookOption {
	return func(h *PaymentWebhookHandlers) {
		if tolerance > 0 {
			h.tolerance = tolerance
		}
	}
}

// WithStripeClock overrides the clock used for request handling (primarily for tests).
func WithStripeClock(clock func() time.Time) PaymentWebhookOption {
	return func(h *PaymentWebhookHandlers) {
		if clock != nil {
			h.clock = clock
		}
	}
}

// NewPaymentWebhookHandlers constructs handlers validating Stripe signatures before delegating to the payment service.
func NewPaymentWebhookHandlers(payments services.PaymentService, secret StripeSecretFetcher, opts ...PaymentWebhookOption) *PaymentWebhookHandlers {
	handler := &PaymentWebhookHandlers{
		payments:  payments,
		secret:    secret,
		tolerance: defaultStripeTolerance,
		clock:     time.Now,
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	return handler
}

// Routes wires webhook endpoints under the provided router.
func (h *PaymentWebhookHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/payments/stripe", h.handleStripePayments)
}

func (h *PaymentWebhookHandlers) handleStripePayments(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.payments == nil {
		httpx.WriteError(ctx, w, httpx.NewError("payment_service_unavailable", "payment service unavailable", http.StatusServiceUnavailable))
		return
	}
	if h.secret == nil {
		httpx.WriteError(ctx, w, httpx.NewError("webhook_secret_unavailable", "stripe webhook secret is not configured", http.StatusServiceUnavailable))
		return
	}

	body, err := readLimitedBody(r, maxStripeWebhookBodySize)
	if err != nil {
		switch {
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	signature := strings.TrimSpace(r.Header.Get("Stripe-Signature"))
	if signature == "" {
		httpx.WriteError(ctx, w, httpx.NewError("missing_signature", "Stripe-Signature header is required", http.StatusBadRequest))
		return
	}

	secret, err := h.secret(ctx)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("secret_resolve_failed", "unable to resolve stripe webhook secret", http.StatusServiceUnavailable))
		return
	}
	secret = strings.TrimSpace(secret)
	if secret == "" {
		httpx.WriteError(ctx, w, httpx.NewError("webhook_secret_unavailable", "stripe webhook secret is not configured", http.StatusServiceUnavailable))
		return
	}

	event, err := stripeWebhook.ConstructEventWithOptions(body, signature, secret, stripeWebhook.ConstructEventOptions{
		Tolerance:                h.tolerance,
		IgnoreAPIVersionMismatch: true,
	})
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_signature", err.Error(), http.StatusBadRequest))
		return
	}

	headers := map[string]string{
		"Stripe-Signature": signature,
	}
	if event.ID != "" {
		headers["Stripe-Event-ID"] = event.ID
	}
	if event.Type != "" {
		headers["Stripe-Event-Type"] = string(event.Type)
	}

	if err := h.payments.RecordWebhookEvent(ctx, services.PaymentWebhookCommand{
		Provider: "stripe",
		Payload:  body,
		Headers:  headers,
	}); err != nil {
		writeStripeWebhookError(ctx, w, err)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func writeStripeWebhookError(ctx context.Context, w http.ResponseWriter, err error) {
	if err == nil {
		w.WriteHeader(http.StatusOK)
		return
	}
	switch {
	case errors.Is(err, services.ErrPaymentInvalidInput):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrPaymentNotFound):
		w.WriteHeader(http.StatusAccepted)
	case errors.Is(err, services.ErrPaymentInvalidState), errors.Is(err, services.ErrPaymentConflict):
		httpx.WriteError(ctx, w, httpx.NewError("payment_conflict", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPaymentUnavailable):
		httpx.WriteError(ctx, w, httpx.NewError("payment_service_unavailable", "payment service unavailable", http.StatusServiceUnavailable))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("payment_error", "failed to process webhook", http.StatusInternalServerError))
	}
}
