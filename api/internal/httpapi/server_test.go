package httpapi

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"testing"
	"time"
)

func TestResolveLocalized(t *testing.T) {
	i18n := map[string]string{
		"ja": "柘植",
		"en": "Boxwood",
	}

	if got := resolveLocalized(i18n, "en", "ja"); got != "Boxwood" {
		t.Fatalf("expected en translation, got %q", got)
	}
	if got := resolveLocalized(i18n, "fr", "en"); got != "Boxwood" {
		t.Fatalf("expected default locale fallback, got %q", got)
	}
	if got := resolveLocalized(i18n, "fr", "ko"); got != "柘植" {
		t.Fatalf("expected ja fallback, got %q", got)
	}
}

func TestValidateCreateOrderRequest(t *testing.T) {
	req := createOrderRequest{
		Channel:        "web",
		Locale:         "ja",
		IdempotencyKey: "demo_key_123",
		TermsAgreed:    true,
		Seal: createOrderSealRequest{
			Line1:   "田中",
			Line2:   "太郎",
			Shape:   "square",
			FontKey: "zen_maru_gothic",
		},
		MaterialKey: "boxwood",
		Shipping: createOrderShippingRequest{
			CountryCode:   "jp",
			RecipientName: "田中 太郎",
			Phone:         "09000001111",
			PostalCode:    "1000001",
			State:         "東京都",
			City:          "千代田区",
			AddressLine1:  "1-1-1",
		},
		Contact: createOrderContactRequest{
			Email:           "taro@example.com",
			PreferredLocale: "ja",
		},
	}

	input, err := validateCreateOrderRequest(req)
	if err != nil {
		t.Fatalf("expected valid request: %v", err)
	}

	if input.Shipping.CountryCode != "JP" {
		t.Fatalf("expected country code normalized to JP, got %q", input.Shipping.CountryCode)
	}
}

func TestValidateCreateOrderRequestRejectsSealWhitespace(t *testing.T) {
	req := createOrderRequest{
		Channel:        "web",
		Locale:         "ja",
		IdempotencyKey: "demo_key_123",
		TermsAgreed:    true,
		Seal: createOrderSealRequest{
			Line1:   "田 中",
			Shape:   "square",
			FontKey: "zen_maru_gothic",
		},
		MaterialKey: "boxwood",
		Shipping: createOrderShippingRequest{
			CountryCode:   "JP",
			RecipientName: "田中 太郎",
			Phone:         "09000001111",
			PostalCode:    "1000001",
			State:         "東京都",
			City:          "千代田区",
			AddressLine1:  "1-1-1",
		},
		Contact: createOrderContactRequest{
			Email:           "taro@example.com",
			PreferredLocale: "ja",
		},
	}

	_, err := validateCreateOrderRequest(req)
	if err == nil {
		t.Fatal("expected validation error")
	}
}

func TestVerifyStripeSignature(t *testing.T) {
	payload := []byte(`{"id":"evt_1","type":"payment_intent.succeeded","data":{"object":{"id":"pi_1","metadata":{"order_id":"order_1"}}}}`)
	secret := "whsec_test"
	now := time.Date(2026, 2, 9, 12, 0, 0, 0, time.UTC)
	timestamp := now.Unix()

	signedPayload := fmt.Sprintf("%d.%s", timestamp, payload)
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(signedPayload))
	signature := hex.EncodeToString(mac.Sum(nil))
	header := fmt.Sprintf("t=%d,v1=%s", timestamp, signature)

	originalNow := nowForStripeSignature
	nowForStripeSignature = func() time.Time { return now }
	t.Cleanup(func() { nowForStripeSignature = originalNow })

	if err := verifyStripeSignature(payload, header, secret); err != nil {
		t.Fatalf("expected signature to pass: %v", err)
	}

	if err := verifyStripeSignature(payload, header, "wrong"); err == nil {
		t.Fatal("expected signature verification failure")
	}
}

func TestParseStripeEvent(t *testing.T) {
	payload := []byte(`{"id":"evt_1","type":"payment_intent.succeeded","data":{"object":{"id":"pi_1","metadata":{"order_id":"order_1"}}}}`)
	event, err := parseStripeEvent(payload)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if event.ProviderEventID != "evt_1" {
		t.Fatalf("unexpected event id: %s", event.ProviderEventID)
	}
	if event.PaymentIntentID != "pi_1" {
		t.Fatalf("unexpected payment intent id: %s", event.PaymentIntentID)
	}
	if event.OrderID != "order_1" {
		t.Fatalf("unexpected order id: %s", event.OrderID)
	}
}
