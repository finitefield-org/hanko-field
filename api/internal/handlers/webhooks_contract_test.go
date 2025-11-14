package handlers

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	stripe "github.com/stripe/stripe-go/v78"
	stripeWebhook "github.com/stripe/stripe-go/v78/webhook"

	"github.com/hanko-field/api/internal/platform/idempotency"
	"github.com/hanko-field/api/internal/services"
)

func TestWebhookContract_StripePayments(t *testing.T) {
	t.Helper()

	payload := loadWebhookFixture(t, "webhooks/stripe_payment_intent_succeeded.json")
	var rawEvent struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(payload, &rawEvent); err != nil {
		t.Fatalf("failed to decode stripe fixture: %v", err)
	}
	idempotencyKey := rawEvent.ID

	secret := "whsec_contract"
	signed := stripeWebhook.GenerateTestSignedPayload(&stripeWebhook.UnsignedPayload{
		Payload:   payload,
		Secret:    secret,
		Timestamp: time.Now(),
	})

	var recorded services.PaymentWebhookCommand
	callCount := 0
	service := &webhookStubPaymentService{
		recordFn: func(ctx context.Context, cmd services.PaymentWebhookCommand) error {
			callCount++
			recorded = cmd
			return nil
		},
	}

	handler := NewPaymentWebhookHandlers(service, func(context.Context) (string, error) {
		return secret, nil
	}, WithStripeTolerance(24*time.Hour))

	router := chi.NewRouter()
	router.Use(idempotency.Middleware(idempotency.NewMemoryStore()))
	router.Route("/webhooks", handler.Routes)

	makeRequest := func() *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/webhooks/payments/stripe", bytes.NewReader(payload))
		req.Header.Set("Stripe-Signature", signed.Header)
		req.Header.Set("Idempotency-Key", idempotencyKey)
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)
		return rr
	}

	first := makeRequest()
	if first.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d (%s)", first.Code, first.Body.String())
	}
	if callCount != 1 {
		t.Fatalf("expected payment service called once, got %d", callCount)
	}
	if recorded.Provider != "stripe" {
		t.Fatalf("expected provider stripe, got %s", recorded.Provider)
	}
	if recorded.Headers["Stripe-Event-ID"] != rawEvent.ID {
		t.Fatalf("expected stripe event id propagated, got %s", recorded.Headers["Stripe-Event-ID"])
	}
	if recorded.Headers["Stripe-Signature"] == "" {
		t.Fatalf("expected signature header forwarded to service")
	}

	var event stripe.Event
	if err := json.Unmarshal(recorded.Payload, &event); err != nil {
		t.Fatalf("failed to parse recorded event: %v", err)
	}
	if event.ID != rawEvent.ID {
		t.Fatalf("expected event id %s, got %s", rawEvent.ID, event.ID)
	}
	if event.Type != stripe.EventTypePaymentIntentSucceeded {
		t.Fatalf("expected payment_intent.succeeded, got %s", event.Type)
	}
	if event.Data == nil || len(event.Data.Raw) == 0 {
		t.Fatalf("expected event data payload to be present")
	}
	var intent stripe.PaymentIntent
	if err := json.Unmarshal(event.Data.Raw, &intent); err != nil {
		t.Fatalf("failed to decode payment intent: %v", err)
	}
	if intent.Metadata["order_id"] != "ord_contract_001" {
		t.Fatalf("expected order metadata ord_contract_001, got %s", intent.Metadata["order_id"])
	}
	if intent.Metadata["payment_id"] != "pay_contract_001" {
		t.Fatalf("expected payment metadata pay_contract_001, got %s", intent.Metadata["payment_id"])
	}

	second := makeRequest()
	if second.Code != http.StatusOK {
		t.Fatalf("expected replay status 200, got %d", second.Code)
	}
	if second.Header().Get("X-Idempotent-Replay") != "true" {
		t.Fatalf("expected X-Idempotent-Replay header on cached response")
	}
	if callCount != 1 {
		t.Fatalf("expected handler not reinvoked on replay, got %d calls", callCount)
	}
}

func TestWebhookContract_ShippingDHL(t *testing.T) {
	t.Helper()

	payload := loadWebhookFixture(t, "webhooks/shipping_dhl_delivered.json")
	var fixture struct {
		TrackingNumber string `json:"trackingNumber"`
	}
	if err := json.Unmarshal(payload, &fixture); err != nil {
		t.Fatalf("failed to decode shipping fixture: %v", err)
	}

	service := newRecordingShipmentService()
	now := time.Date(2024, 11, 3, 10, 0, 0, 0, time.UTC)
	handler := NewShippingWebhookHandlers(service,
		WithCarrierHMACSecret("dhl", "dhl-secret"),
		WithShippingWebhookClock(func() time.Time { return now }),
	)

	router := chi.NewRouter()
	router.Use(idempotency.Middleware(idempotency.NewMemoryStore()))
	router.Route("/webhooks", handler.Routes)

	signature := computeHexHMAC(t, "dhl-secret", payload)
	makeRequest := func() *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/webhooks/shipping/dhl", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-DHL-Signature", signature)
		req.Header.Set("Idempotency-Key", fixture.TrackingNumber)
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)
		return rr
	}

	first := makeRequest()
	if first.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d (%s)", first.Code, first.Body.String())
	}
	if service.calls != 1 {
		t.Fatalf("expected shipment service called once, got %d", service.calls)
	}

	cmd := service.shippingStubShipmentService.lastCmd
	if cmd.Carrier != "DHL" {
		t.Fatalf("expected carrier DHL, got %s", cmd.Carrier)
	}
	if cmd.TrackingCode != fixture.TrackingNumber {
		t.Fatalf("expected tracking %s, got %s", fixture.TrackingNumber, cmd.TrackingCode)
	}
	if cmd.Event.Status != "delivered" {
		t.Fatalf("expected normalized status delivered, got %s", cmd.Event.Status)
	}
	expectedTime := time.Date(2024, 11, 3, 9, 15, 0, 0, time.UTC)
	if !cmd.Event.OccurredAt.Equal(expectedTime) {
		t.Fatalf("expected occurredAt %s, got %s", expectedTime, cmd.Event.OccurredAt)
	}
	if cmd.Event.Details["location"] != "Osaka JP" {
		t.Fatalf("expected location detail preserved, got %#v", cmd.Event.Details["location"])
	}
	if cmd.Event.Details["carrierStatus"] != "Delivered" {
		t.Fatalf("expected carrierStatus detail, got %#v", cmd.Event.Details["carrierStatus"])
	}

	second := makeRequest()
	if second.Code != http.StatusOK {
		t.Fatalf("expected replay status 200, got %d", second.Code)
	}
	if second.Header().Get("X-Idempotent-Replay") != "true" {
		t.Fatalf("expected replay header on cached response")
	}
	if service.calls != 1 {
		t.Fatalf("expected shipment handler not reinvoked, got %d calls", service.calls)
	}
}

func TestWebhookContract_AIWorker(t *testing.T) {
	t.Helper()

	payload := loadWebhookFixture(t, "webhooks/ai_worker_succeeded.json")
	var fixture struct {
		JobID string `json:"jobId"`
	}
	if err := json.Unmarshal(payload, &fixture); err != nil {
		t.Fatalf("failed to decode ai worker fixture: %v", err)
	}

	dispatcher := newRecordingJobDispatcher(func(_ context.Context, cmd services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error) {
		suggestion := cmd.Suggestion
		return services.CompleteAISuggestionResult{
			Suggestion: &suggestion,
		}, nil
	})
	handler := NewAIWorkerWebhookHandlers(dispatcher, services.NewNoopAISuggestionNotifier())

	router := chi.NewRouter()
	router.Use(idempotency.Middleware(idempotency.NewMemoryStore()))
	router.Route("/webhooks", handler.Routes)

	makeRequest := func() *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/webhooks/ai/worker", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Idempotency-Key", fixture.JobID)
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)
		return rr
	}

	first := makeRequest()
	if first.Code != http.StatusAccepted {
		t.Fatalf("expected status 202, got %d (%s)", first.Code, first.Body.String())
	}
	if dispatcher.calls != 1 {
		t.Fatalf("expected dispatcher invoked once, got %d", dispatcher.calls)
	}
	if dispatcher.lastCmd.JobID != fixture.JobID {
		t.Fatalf("expected job id %s, got %s", fixture.JobID, dispatcher.lastCmd.JobID)
	}
	if dispatcher.lastCmd.Suggestion.ID == "" {
		t.Fatalf("expected suggestion payload populated")
	}
	if dispatcher.lastCmd.Suggestion.Method != "headline-variations" {
		t.Fatalf("expected suggestion method headline-variations, got %s", dispatcher.lastCmd.Suggestion.Method)
	}
	if len(dispatcher.lastCmd.Outputs) == 0 || dispatcher.lastCmd.Outputs["variants"] == nil {
		t.Fatalf("expected outputs.vairants to be forwarded, got %#v", dispatcher.lastCmd.Outputs)
	}

	second := makeRequest()
	if second.Code != http.StatusAccepted {
		t.Fatalf("expected replay status 202, got %d", second.Code)
	}
	if second.Header().Get("X-Idempotent-Replay") != "true" {
		t.Fatalf("expected replay header on ai worker response")
	}
	if dispatcher.calls != 1 {
		t.Fatalf("expected dispatcher not reinvoked, got %d calls", dispatcher.calls)
	}
}

func loadWebhookFixture(t *testing.T, name string) []byte {
	t.Helper()

	path := filepath.Join("testdata", name)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read fixture %s: %v", path, err)
	}
	return data
}

func computeHexHMAC(t *testing.T, secret string, payload []byte) string {
	t.Helper()

	mac := hmac.New(sha256.New, []byte(secret))
	if _, err := mac.Write(payload); err != nil {
		t.Fatalf("failed to compute hmac: %v", err)
	}
	return hex.EncodeToString(mac.Sum(nil))
}

type recordingShipmentService struct {
	*shippingStubShipmentService
	calls int
}

func newRecordingShipmentService() *recordingShipmentService {
	return &recordingShipmentService{
		shippingStubShipmentService: &shippingStubShipmentService{},
	}
}

func (s *recordingShipmentService) RecordCarrierEvent(ctx context.Context, cmd services.ShipmentEventCommand) error {
	s.calls++
	return s.shippingStubShipmentService.RecordCarrierEvent(ctx, cmd)
}

type recordingJobDispatcher struct {
	*stubAIJobDispatcher
	calls   int
	lastCmd services.CompleteAISuggestionCommand
}

func newRecordingJobDispatcher(fn func(context.Context, services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error)) *recordingJobDispatcher {
	return &recordingJobDispatcher{
		stubAIJobDispatcher: &stubAIJobDispatcher{completeFn: fn},
	}
}

func (d *recordingJobDispatcher) CompleteAISuggestion(ctx context.Context, cmd services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error) {
	d.calls++
	d.lastCmd = cmd
	if d.stubAIJobDispatcher != nil && d.stubAIJobDispatcher.completeFn != nil {
		return d.stubAIJobDispatcher.completeFn(ctx, cmd)
	}
	return services.CompleteAISuggestionResult{}, nil
}

var (
	_ services.ShipmentService         = (*recordingShipmentService)(nil)
	_ services.BackgroundJobDispatcher = (*recordingJobDispatcher)(nil)
)
