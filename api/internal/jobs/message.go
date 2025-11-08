package jobs

import (
	"encoding/json"
	"time"
)

// Message represents a normalized Pub/Sub message delivered to a processor.
// It intentionally hides the underlying Pub/Sub client to keep processors
// decoupled from transport semantics.
type Message struct {
	ID               string
	Data             []byte
	Attributes       map[string]string
	PublishTime      time.Time
	DeliveryAttempt  int
	OrderingKey      string
	SubscriptionName string
}

// DecodeJSON unmarshals the message payload into the supplied destination.
func (m Message) DecodeJSON(dst any) error {
	return json.Unmarshal(m.Data, dst)
}

// Attribute returns the attribute value for the provided key, trimming whitespace.
func (m Message) Attribute(key string) string {
	if len(m.Attributes) == 0 {
		return ""
	}
	value, ok := m.Attributes[key]
	if !ok {
		return ""
	}
	return value
}
