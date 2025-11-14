package handlers

import (
	"bytes"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	stripeWebhook "github.com/stripe/stripe-go/v78/webhook"

	"github.com/hanko-field/api/internal/services"
)

func TestPaymentWebhookHandlerSuccess(t *testing.T) {
	t.Helper()

	secret := "whsec_test"
	payload := []byte(`{"id":"evt_test","object":"event","type":"payment_intent.succeeded","data":{"object":{"id":"pi_test","object":"payment_intent"}}}`)
	signed := stripeWebhook.GenerateTestSignedPayload(&stripeWebhook.UnsignedPayload{
		Payload:   payload,
		Secret:    secret,
		Timestamp: time.Now(),
	})

	var recorded services.PaymentWebhookCommand
	service := &webhookStubPaymentService{
		recordFn: func(ctx context.Context, cmd services.PaymentWebhookCommand) error {
			recorded = cmd
			return nil
		},
	}

	handler := NewPaymentWebhookHandlers(service, func(context.Context) (string, error) {
		return secret, nil
	})

	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodPost, "/payments/stripe", bytes.NewReader(payload))
	req.Header.Set("Stripe-Signature", signed.Header)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", rr.Code, rr.Body.String())
	}
	if recorded.Provider != "stripe" {
		t.Fatalf("expected provider stripe, got %s", recorded.Provider)
	}
	if !bytes.Equal(recorded.Payload, payload) {
		t.Fatalf("expected payload to match signed payload")
	}
	if recorded.Headers["Stripe-Event-ID"] != "evt_test" {
		t.Fatalf("expected event id header evt_test, got %s", recorded.Headers["Stripe-Event-ID"])
	}
	if recorded.Headers["Stripe-Event-Type"] != "payment_intent.succeeded" {
		t.Fatalf("expected event type header payment_intent.succeeded, got %s", recorded.Headers["Stripe-Event-Type"])
	}
}

func TestPaymentWebhookHandlerInvalidSignature(t *testing.T) {
	t.Helper()

	service := &webhookStubPaymentService{}
	handler := NewPaymentWebhookHandlers(service, func(context.Context) (string, error) {
		return "secret", nil
	})

	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodPost, "/payments/stripe", bytes.NewReader([]byte(`{"id":"evt"}`)))
	req.Header.Set("Stripe-Signature", "invalid")
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400 for invalid signature, got %d", rr.Code)
	}
}

func TestPaymentWebhookHandlerServiceError(t *testing.T) {
	t.Helper()

	secret := "whsec_test"
	payload := []byte(`{"id":"evt_err","object":"event","type":"payment_intent.succeeded","data":{"object":{"id":"pi_err","object":"payment_intent"}}}`)
	signed := stripeWebhook.GenerateTestSignedPayload(&stripeWebhook.UnsignedPayload{
		Payload:   payload,
		Secret:    secret,
		Timestamp: time.Now(),
	})

	service := &webhookStubPaymentService{
		recordFn: func(context.Context, services.PaymentWebhookCommand) error {
			return services.ErrPaymentInvalidInput
		},
	}
	handler := NewPaymentWebhookHandlers(service, func(context.Context) (string, error) {
		return secret, nil
	})
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodPost, "/payments/stripe", bytes.NewReader(payload))
	req.Header.Set("Stripe-Signature", signed.Header)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400 when service returns invalid input, got %d", rr.Code)
	}
}

type webhookStubPaymentService struct {
	recordFn func(context.Context, services.PaymentWebhookCommand) error
}

func (s *webhookStubPaymentService) RecordWebhookEvent(ctx context.Context, cmd services.PaymentWebhookCommand) error {
	if s.recordFn == nil {
		return nil
	}
	return s.recordFn(ctx, cmd)
}

func (s *webhookStubPaymentService) ManualCapture(context.Context, services.PaymentManualCaptureCommand) (services.Payment, error) {
	return services.Payment{}, errors.New("not implemented")
}

func (s *webhookStubPaymentService) ManualRefund(context.Context, services.PaymentManualRefundCommand) (services.Payment, error) {
	return services.Payment{}, errors.New("not implemented")
}

func (s *webhookStubPaymentService) ListPayments(context.Context, string) ([]services.Payment, error) {
	return nil, errors.New("not implemented")
}
