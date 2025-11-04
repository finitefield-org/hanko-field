package handlers

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/services"
)

func TestShippingWebhookHandlers_DHL_Success(t *testing.T) {
	now := time.Date(2024, 11, 3, 10, 0, 0, 0, time.UTC)
	service := &shippingStubShipmentService{}

	handler := NewShippingWebhookHandlers(service,
		WithCarrierHMACSecret("dhl", "dhl-secret"),
		WithShippingWebhookClock(func() time.Time { return now }),
	)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"orderId":"ord_abc","shipmentId":"shp_123","trackingNumber":"DHL123456789","timestamp":"2024-11-03T09:00:00Z","status":"Delivered","location":"Tokyo"}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/dhl", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-DHL-Signature", signHMAC("dhl-secret", []byte(body)))

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", res.Code)
	}
	if !service.called {
		t.Fatalf("expected shipment service invoked")
	}

	cmd := service.lastCmd
	if cmd.Carrier != "DHL" {
		t.Fatalf("expected carrier DHL, got %s", cmd.Carrier)
	}
	if cmd.TrackingCode != "DHL123456789" {
		t.Fatalf("expected tracking code preserved, got %s", cmd.TrackingCode)
	}
	if cmd.Event.Status != "delivered" {
		t.Fatalf("expected status delivered, got %s", cmd.Event.Status)
	}
	expectedOccurred := time.Date(2024, 11, 3, 9, 0, 0, 0, time.UTC)
	if !cmd.Event.OccurredAt.Equal(expectedOccurred) {
		t.Fatalf("expected occurredAt %s, got %s", expectedOccurred, cmd.Event.OccurredAt)
	}
	if cmd.Event.Details["location"] != "Tokyo" {
		t.Fatalf("expected location detail")
	}
	if cmd.Event.Details["carrier"] != "DHL" {
		t.Fatalf("expected carrier detail")
	}
	if cmd.Event.Details["carrierStatus"] != "Delivered" {
		t.Fatalf("expected carrierStatus preserved")
	}
}

func TestShippingWebhookHandlers_JPPost_IPRestriction(t *testing.T) {
	service := &shippingStubShipmentService{}
	handler := NewShippingWebhookHandlers(service,
		WithCarrierAllowedCIDRs("jp-post", "203.0.113.0/24"),
	)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"mail":{"tracking_no":"JP123456789","event":{"code":"delivered","datetime":"2024-11-03T18:00:00+09:00"}}}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/jp-post", strings.NewReader(body))
	req.RemoteAddr = "198.51.100.10:443"
	req.Header.Set("Content-Type", "application/json")

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", res.Code)
	}
	if service.called {
		t.Fatalf("expected shipment service not called")
	}
}

func TestShippingWebhookHandlers_JPPost_Success(t *testing.T) {
	service := &shippingStubShipmentService{}
	handler := NewShippingWebhookHandlers(service,
		WithCarrierAllowedCIDRs("jp-post", "203.0.113.0/24"),
	)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"mail":{"order_id":"ord_jp","shipment_id":"shp_jp","tracking_no":"jp00112233","event":{"code":"delivered","description":"Delivered to customer","datetime":"2024-11-03T18:00:00+09:00"}}}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/jp-post", strings.NewReader(body))
	req.RemoteAddr = "203.0.113.45:443"
	req.Header.Set("Content-Type", "application/json")

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", res.Code)
	}
	if !service.called {
		t.Fatalf("expected shipment service called")
	}
	cmd := service.lastCmd
	if cmd.Carrier != "JPPOST" {
		t.Fatalf("expected carrier JPPOST, got %s", cmd.Carrier)
	}
	if cmd.Event.Status != "delivered" {
		t.Fatalf("expected status delivered, got %s", cmd.Event.Status)
	}
	expected := time.Date(2024, 11, 3, 9, 0, 0, 0, time.UTC)
	if !cmd.Event.OccurredAt.Equal(expected) {
		t.Fatalf("expected occurredAt %s, got %s", expected, cmd.Event.OccurredAt)
	}
}

func TestShippingWebhookHandlers_Yamato_InvalidToken(t *testing.T) {
	service := &shippingStubShipmentService{}
	handler := NewShippingWebhookHandlers(service,
		WithCarrierAuthToken("yamato", "token-123"),
	)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"tracking_code":"YM000111","status":"in_transit"}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/yamato", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", res.Code)
	}
	if service.called {
		t.Fatalf("expected shipment service not called")
	}
}

func TestShippingWebhookHandlers_Yamato_Success(t *testing.T) {
	now := time.Date(2024, 11, 4, 3, 0, 0, 0, time.UTC)
	service := &shippingStubShipmentService{}
	handler := NewShippingWebhookHandlers(service,
		WithCarrierAuthToken("yamato", "token-123"),
		WithShippingWebhookClock(func() time.Time { return now }),
	)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"order_id":"ord_yam","shipment_id":"shp_yam","tracking_code":"ym900","status":"OUT_FOR_DELIVERY","occurred_at":"","note":"Left with neighbor","expected_delivery":"2024-11-04T12:00:00+09:00"}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/yamato", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer token-123")

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", res.Code)
	}
	cmd := service.lastCmd
	if cmd.Event.Status != "out_for_delivery" {
		t.Fatalf("expected status out_for_delivery, got %s", cmd.Event.Status)
	}
	if cmd.Event.Details["note"] != "Left with neighbor" {
		t.Fatalf("expected note detail")
	}
	val, ok := cmd.Event.Details["expectedDelivery"].(time.Time)
	if !ok {
		t.Fatalf("expected expectedDelivery time")
	}
	expectedETA := time.Date(2024, 11, 4, 3, 0, 0, 0, time.UTC)
	if !val.Equal(expectedETA) {
		t.Fatalf("expected eta %s, got %s", expectedETA, val)
	}
}

func TestShippingWebhookHandlers_UPS_InvalidSignature(t *testing.T) {
	service := &shippingStubShipmentService{}
	handler := NewShippingWebhookHandlers(service, WithCarrierHMACSecret("ups", "ups-secret"))
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"trackingNumber":"1Z999","event":{"code":"D","time":"2024-11-03T10:00:00Z"}}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/ups", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-UPS-Signature", "deadbeef")

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 invalid signature, got %d", res.Code)
	}
	if service.called {
		t.Fatalf("expected shipment service not called")
	}
}

func TestShippingWebhookHandlers_FedEx_Success(t *testing.T) {
	service := &shippingStubShipmentService{}
	handler := NewShippingWebhookHandlers(service,
		WithCarrierAuthToken("fedex", "fx-token"),
	)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"order_id":"ord_fx","shipment_id":"shp_fx","tracking_number":"fx123","event_status":"DL","status_text":"Delivered","event_time":"2024-11-03T11:00:00Z"}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/fedex", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-FedEx-Webhook-Token", "fx-token")

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", res.Code)
	}
	cmd := service.lastCmd
	if cmd.Carrier != "FEDEX" {
		t.Fatalf("expected carrier FEDEX, got %s", cmd.Carrier)
	}
	if cmd.Event.Status != "delivered" {
		t.Fatalf("expected status delivered, got %s", cmd.Event.Status)
	}
}

func TestShippingWebhookHandlers_ServiceReturnsNotFound(t *testing.T) {
	service := &shippingStubShipmentService{recordErr: services.ErrShipmentNotFound}
	handler := NewShippingWebhookHandlers(service,
		WithCarrierHMACSecret("dhl", "secret"),
	)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"trackingNumber":"DHL404","timestamp":"2024-11-03T09:00:00Z","status":"Delivered"}`
	req := httptest.NewRequest(http.MethodPost, "/shipping/dhl", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-DHL-Signature", signHMAC("secret", []byte(body)))

	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", res.Code)
	}
}

func TestShippingWebhookHandlers_UnsupportedCarrier(t *testing.T) {
	service := &shippingStubShipmentService{}
	handler := NewShippingWebhookHandlers(service)
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodPost, "/shipping/unknown", nil)
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", res.Code)
	}
}

func TestShippingWebhookHandlers_ServiceUnavailable(t *testing.T) {
	handler := NewShippingWebhookHandlers(nil)
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodPost, "/shipping/dhl", nil)
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", res.Code)
	}
}

func signHMAC(secret string, body []byte) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

type shippingStubShipmentService struct {
	called    bool
	lastCmd   services.ShipmentEventCommand
	recordErr error
}

func (s *shippingStubShipmentService) RecordCarrierEvent(_ context.Context, cmd services.ShipmentEventCommand) error {
	s.called = true
	s.lastCmd = cmd
	return s.recordErr
}

func (s *shippingStubShipmentService) CreateShipment(context.Context, services.CreateShipmentCommand) (services.Shipment, error) {
	return services.Shipment{}, errors.New("not implemented")
}

func (s *shippingStubShipmentService) UpdateShipmentStatus(context.Context, services.UpdateShipmentCommand) (services.Shipment, error) {
	return services.Shipment{}, errors.New("not implemented")
}

func (s *shippingStubShipmentService) ListShipments(context.Context, string) ([]services.Shipment, error) {
	return nil, errors.New("not implemented")
}
