package httpapi

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"hanko-field/api/internal/store"
)

const stripeSignatureTolerance = 5 * time.Minute

var nowForStripeSignature = time.Now

type stripeEventEnvelope struct {
	ID   string `json:"id"`
	Type string `json:"type"`
	Data struct {
		Object json.RawMessage `json:"object"`
	} `json:"data"`
}

func parseStripeEvent(payload []byte) (store.StripeWebhookEvent, error) {
	var env stripeEventEnvelope
	if err := json.Unmarshal(payload, &env); err != nil {
		return store.StripeWebhookEvent{}, fmt.Errorf("failed to parse stripe event: %w", err)
	}

	env.ID = strings.TrimSpace(env.ID)
	env.Type = strings.TrimSpace(env.Type)
	if env.ID == "" || env.Type == "" {
		return store.StripeWebhookEvent{}, errors.New("stripe event must include id and type")
	}

	event := store.StripeWebhookEvent{
		ProviderEventID: env.ID,
		EventType:       env.Type,
	}

	if len(env.Data.Object) == 0 {
		return event, nil
	}

	var object map[string]any
	if err := json.Unmarshal(env.Data.Object, &object); err != nil {
		return event, nil
	}

	if objectID := strings.TrimSpace(asString(object["id"])); strings.HasPrefix(objectID, "pi_") {
		event.PaymentIntentID = objectID
	}
	if pi := strings.TrimSpace(asString(object["payment_intent"])); pi != "" {
		event.PaymentIntentID = pi
	}

	orderID := extractOrderID(object)
	event.OrderID = strings.TrimSpace(orderID)
	return event, nil
}

func verifyStripeSignature(payload []byte, signatureHeader, secret string) error {
	if strings.TrimSpace(secret) == "" {
		return nil
	}

	sig := strings.TrimSpace(signatureHeader)
	if sig == "" {
		return errors.New("missing Stripe-Signature header")
	}

	timestamp, signatures, err := parseStripeSignatureHeader(sig)
	if err != nil {
		return err
	}

	now := nowForStripeSignature().UTC()
	eventTime := time.Unix(timestamp, 0).UTC()
	if now.Sub(eventTime) > stripeSignatureTolerance || eventTime.Sub(now) > stripeSignatureTolerance {
		return errors.New("stripe signature timestamp is outside tolerance")
	}

	signedPayload := fmt.Sprintf("%d.%s", timestamp, payload)
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(signedPayload))
	expected := mac.Sum(nil)

	for _, candidate := range signatures {
		decoded, err := hex.DecodeString(candidate)
		if err != nil {
			continue
		}
		if hmac.Equal(decoded, expected) {
			return nil
		}
	}

	return errors.New("invalid stripe signature")
}

func parseStripeSignatureHeader(value string) (int64, []string, error) {
	parts := strings.Split(value, ",")
	var timestamp int64
	signatures := make([]string, 0, 1)
	seenTimestamp := false

	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		kv := strings.SplitN(part, "=", 2)
		if len(kv) != 2 {
			continue
		}
		k := strings.TrimSpace(kv[0])
		v := strings.TrimSpace(kv[1])
		switch k {
		case "t":
			ts, err := strconv.ParseInt(v, 10, 64)
			if err != nil {
				return 0, nil, errors.New("invalid stripe signature timestamp")
			}
			timestamp = ts
			seenTimestamp = true
		case "v1":
			if v != "" {
				signatures = append(signatures, v)
			}
		}
	}

	if !seenTimestamp {
		return 0, nil, errors.New("stripe signature does not include timestamp")
	}
	if len(signatures) == 0 {
		return 0, nil, errors.New("stripe signature does not include v1")
	}
	return timestamp, signatures, nil
}

func extractOrderID(object map[string]any) string {
	if direct := asString(object["order_id"]); direct != "" {
		return direct
	}

	metadata, ok := object["metadata"].(map[string]any)
	if !ok {
		return ""
	}
	if orderID := asString(metadata["order_id"]); orderID != "" {
		return orderID
	}
	if orderID := asString(metadata["orderId"]); orderID != "" {
		return orderID
	}
	if orderID := asString(metadata["orderID"]); orderID != "" {
		return orderID
	}
	return ""
}

func asString(v any) string {
	s, ok := v.(string)
	if !ok {
		return ""
	}
	return s
}
