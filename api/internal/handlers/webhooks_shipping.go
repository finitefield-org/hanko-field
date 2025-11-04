package handlers

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const maxShippingWebhookBodySize int64 = 64 * 1024

// ShippingWebhookHandlers coordinates inbound shipping carrier webhooks and delegates them to the shipment service.
type ShippingWebhookHandlers struct {
	shipments services.ShipmentService
	configs   map[string]*carrierConfig
	maxBody   int64
	now       func() time.Time
}

// ShippingWebhookOption customises the behaviour of the shipping webhook handler.
type ShippingWebhookOption func(*ShippingWebhookHandlers)

type carrierConfig struct {
	key          string
	carrier      string
	statusMap    map[string]string
	hmacHeader   string
	hmacSecret   string
	tokenHeader  string
	authToken    string
	allowedCIDRs []*net.IPNet
}

type carrierPayload struct {
	orderID    string
	shipmentID string
	tracking   string
	status     string
	occurredAt time.Time
	details    map[string]any
}

type carrierError struct {
	code    string
	message string
	status  int
}

func (e carrierError) Error() string {
	return e.message
}

// NewShippingWebhookHandlers constructs handlers for /webhooks/shipping/{carrier}.
func NewShippingWebhookHandlers(shipments services.ShipmentService, opts ...ShippingWebhookOption) *ShippingWebhookHandlers {
	handler := &ShippingWebhookHandlers{
		shipments: shipments,
		maxBody:   maxShippingWebhookBodySize,
		now: func() time.Time {
			return time.Now().UTC()
		},
		configs: map[string]*carrierConfig{
			"dhl": {
				key:        "dhl",
				carrier:    "DHL",
				hmacHeader: "X-DHL-Signature",
				statusMap: map[string]string{
					"pre_transit":         "label_created",
					"transit":             "in_transit",
					"in_transit":          "in_transit",
					"out_for_delivery":    "out_for_delivery",
					"delivered":           "delivered",
					"exception":           "exception",
					"return_to_sender":    "return_to_sender",
					"arrived_at_facility": "arrived_hub",
				},
			},
			"jp-post": {
				key:     "jp-post",
				carrier: "JPPOST",
				statusMap: map[string]string{
					"posting":          "picked_up",
					"in_transit":       "in_transit",
					"arrival":          "arrived_hub",
					"out_for_delivery": "out_for_delivery",
					"delivered":        "delivered",
					"undeliverable":    "exception",
					"return":           "return_to_sender",
				},
			},
			"yamato": {
				key:         "yamato",
				carrier:     "YAMATO",
				tokenHeader: "Authorization",
				statusMap: map[string]string{
					"pickup":           "picked_up",
					"in_transit":       "in_transit",
					"with_courier":     "out_for_delivery",
					"delivered":        "delivered",
					"exception":        "exception",
					"return_to_sender": "return_to_sender",
				},
			},
			"ups": {
				key:        "ups",
				carrier:    "UPS",
				hmacHeader: "X-UPS-Signature",
				statusMap: map[string]string{
					"d": "delivered",
					"i": "in_transit",
					"o": "out_for_delivery",
					"x": "exception",
					"r": "return_to_sender",
					"p": "picked_up",
					"n": "arrived_hub",
				},
			},
			"fedex": {
				key:         "fedex",
				carrier:     "FEDEX",
				tokenHeader: "X-FedEx-Webhook-Token",
				statusMap: map[string]string{
					"dl": "delivered",
					"od": "out_for_delivery",
					"it": "in_transit",
					"ex": "exception",
					"rs": "return_to_sender",
				},
			},
		},
	}

	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}

	return handler
}

// WithCarrierHMACSecret configures the shared secret used to validate HMAC signatures for the given carrier.
func WithCarrierHMACSecret(carrier string, secret string) ShippingWebhookOption {
	return func(h *ShippingWebhookHandlers) {
		if cfg := h.configFor(carrier); cfg != nil {
			cfg.hmacSecret = strings.TrimSpace(secret)
		}
	}
}

// WithCarrierAllowedCIDRs restricts accepted webhook sources to the provided CIDR blocks for the given carrier.
func WithCarrierAllowedCIDRs(carrier string, cidrs ...string) ShippingWebhookOption {
	return func(h *ShippingWebhookHandlers) {
		cfg := h.configFor(carrier)
		if cfg == nil {
			return
		}
		for _, cidr := range cidrs {
			cidr = strings.TrimSpace(cidr)
			if cidr == "" {
				continue
			}
			_, network, err := net.ParseCIDR(cidr)
			if err != nil {
				continue
			}
			cfg.allowedCIDRs = append(cfg.allowedCIDRs, network)
		}
	}
}

// WithCarrierAuthToken sets the expected authentication token for the given carrier.
// When the configured header is Authorization, the token is validated as a Bearer token.
func WithCarrierAuthToken(carrier string, token string) ShippingWebhookOption {
	return func(h *ShippingWebhookHandlers) {
		if cfg := h.configFor(carrier); cfg != nil {
			cfg.authToken = strings.TrimSpace(token)
		}
	}
}

// WithShippingWebhookClock overrides the clock used for timestamp fallbacks (primarily for tests).
func WithShippingWebhookClock(clock func() time.Time) ShippingWebhookOption {
	return func(h *ShippingWebhookHandlers) {
		if clock != nil {
			h.now = func() time.Time {
				return clock().UTC()
			}
		}
	}
}

// WithShippingWebhookMaxBody adjusts the maximum accepted request body size.
func WithShippingWebhookMaxBody(limit int64) ShippingWebhookOption {
	return func(h *ShippingWebhookHandlers) {
		if limit > 0 {
			h.maxBody = limit
		}
	}
}

// Routes wires the shipping webhook endpoint under the provided router.
func (h *ShippingWebhookHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/shipping/{carrier}", h.handleShippingWebhook)
}

func (h *ShippingWebhookHandlers) handleShippingWebhook(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.shipments == nil {
		httpx.WriteError(ctx, w, httpx.NewError("shipment_service_unavailable", "shipment service unavailable", http.StatusServiceUnavailable))
		return
	}

	carrierKey := normalizeCarrierKey(chi.URLParam(r, "carrier"))
	cfg, ok := h.configs[carrierKey]
	if !ok {
		httpx.WriteError(ctx, w, httpx.NewError("unsupported_carrier", fmt.Sprintf("carrier %q is not supported", carrierKey), http.StatusNotFound))
		return
	}

	body, err := readLimitedBody(r, h.maxBody)
	if err != nil {
		switch {
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	payload, err := h.parseCarrierPayload(cfg, r, body)
	if err != nil {
		var cerr carrierError
		if errors.As(err, &cerr) {
			httpx.WriteError(ctx, w, httpx.NewError(cerr.code, cerr.message, cerr.status))
			return
		}
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	eventDetails := payload.details
	if eventDetails == nil {
		eventDetails = make(map[string]any)
	}
	eventDetails["carrier"] = cfg.carrier

	if err := h.shipments.RecordCarrierEvent(ctx, services.ShipmentEventCommand{
		OrderID:      payload.orderID,
		ShipmentID:   payload.shipmentID,
		Carrier:      cfg.carrier,
		TrackingCode: payload.tracking,
		Event: services.ShipmentEvent{
			Status:     payload.status,
			OccurredAt: payload.occurredAt,
			Details:    eventDetails,
		},
	}); err != nil {
		h.writeShipmentError(ctx, w, err)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (h *ShippingWebhookHandlers) parseCarrierPayload(cfg *carrierConfig, r *http.Request, body []byte) (carrierPayload, error) {
	switch cfg.key {
	case "dhl":
		return h.parseDHL(cfg, r, body)
	case "jp-post":
		return h.parseJPPost(cfg, r, body)
	case "yamato":
		return h.parseYamato(cfg, r, body)
	case "ups":
		return h.parseUPS(cfg, r, body)
	case "fedex":
		return h.parseFedEx(cfg, r, body)
	default:
		return carrierPayload{}, carrierError{code: "unsupported_carrier", message: "carrier not supported", status: http.StatusNotFound}
	}
}

func (h *ShippingWebhookHandlers) parseDHL(cfg *carrierConfig, r *http.Request, body []byte) (carrierPayload, error) {
	if err := validateHMAC(cfg, r, body); err != nil {
		return carrierPayload{}, err
	}

	var payload struct {
		OrderID        string         `json:"orderId"`
		ShipmentID     string         `json:"shipmentId"`
		TrackingNumber string         `json:"trackingNumber"`
		Timestamp      string         `json:"timestamp"`
		Status         string         `json:"status"`
		Description    string         `json:"description"`
		Location       string         `json:"location"`
		Metadata       map[string]any `json:"details"`
		Raw            map[string]any `json:"raw"`
	}

	if err := json.Unmarshal(body, &payload); err != nil {
		return carrierPayload{}, carrierError{code: "invalid_payload", message: "invalid DHL payload", status: http.StatusBadRequest}
	}

	tracking := strings.ToUpper(strings.TrimSpace(payload.TrackingNumber))
	if tracking == "" {
		return carrierPayload{}, carrierError{code: "missing_tracking", message: "trackingNumber is required", status: http.StatusBadRequest}
	}

	status, err := translateStatus(cfg, payload.Status)
	if err != nil {
		return carrierPayload{}, err
	}

	occurredAt := parseCarrierTimestamp(payload.Timestamp, h.now)
	details := cloneCarrierMap(payload.Metadata)
	details["carrierStatus"] = strings.TrimSpace(payload.Status)
	if payload.Description != "" {
		details["description"] = payload.Description
	}
	if payload.Location != "" {
		details["location"] = payload.Location
	}
	for k, v := range payload.Raw {
		if _, exists := details[k]; !exists {
			details[k] = v
		}
	}

	return carrierPayload{
		orderID:    strings.TrimSpace(payload.OrderID),
		shipmentID: strings.TrimSpace(payload.ShipmentID),
		tracking:   tracking,
		status:     status,
		occurredAt: occurredAt,
		details:    details,
	}, nil
}

func (h *ShippingWebhookHandlers) parseJPPost(cfg *carrierConfig, r *http.Request, body []byte) (carrierPayload, error) {
	if err := validateCIDR(cfg, r); err != nil {
		return carrierPayload{}, err
	}

	var payload struct {
		Mail struct {
			OrderID    string `json:"order_id"`
			ShipmentID string `json:"shipment_id"`
			TrackingNo string `json:"tracking_no"`
			Event      struct {
				Code        string `json:"code"`
				Description string `json:"description"`
				DateTime    string `json:"datetime"`
			} `json:"event"`
		} `json:"mail"`
	}

	if err := json.Unmarshal(body, &payload); err != nil {
		return carrierPayload{}, carrierError{code: "invalid_payload", message: "invalid JP Post payload", status: http.StatusBadRequest}
	}

	tracking := strings.ToUpper(strings.TrimSpace(payload.Mail.TrackingNo))
	if tracking == "" {
		return carrierPayload{}, carrierError{code: "missing_tracking", message: "tracking_no is required", status: http.StatusBadRequest}
	}

	status, err := translateStatus(cfg, payload.Mail.Event.Code)
	if err != nil {
		return carrierPayload{}, err
	}

	occurredAt := parseCarrierTimestamp(payload.Mail.Event.DateTime, h.now)
	details := map[string]any{
		"carrierStatus": strings.TrimSpace(payload.Mail.Event.Code),
	}
	if desc := strings.TrimSpace(payload.Mail.Event.Description); desc != "" {
		details["description"] = desc
	}

	return carrierPayload{
		orderID:    strings.TrimSpace(payload.Mail.OrderID),
		shipmentID: strings.TrimSpace(payload.Mail.ShipmentID),
		tracking:   tracking,
		status:     status,
		occurredAt: occurredAt,
		details:    details,
	}, nil
}

func (h *ShippingWebhookHandlers) parseYamato(cfg *carrierConfig, r *http.Request, body []byte) (carrierPayload, error) {
	if err := validateToken(cfg, r); err != nil {
		return carrierPayload{}, err
	}

	var payload struct {
		OrderID          string `json:"order_id"`
		ShipmentID       string `json:"shipment_id"`
		TrackingCode     string `json:"tracking_code"`
		Status           string `json:"status"`
		OccurredAt       string `json:"occurred_at"`
		Note             string `json:"note"`
		ExpectedDelivery string `json:"expected_delivery"`
	}

	if err := json.Unmarshal(body, &payload); err != nil {
		return carrierPayload{}, carrierError{code: "invalid_payload", message: "invalid Yamato payload", status: http.StatusBadRequest}
	}

	tracking := strings.ToUpper(strings.TrimSpace(payload.TrackingCode))
	if tracking == "" {
		return carrierPayload{}, carrierError{code: "missing_tracking", message: "tracking_code is required", status: http.StatusBadRequest}
	}

	status, err := translateStatus(cfg, payload.Status)
	if err != nil {
		return carrierPayload{}, err
	}

	occurredAt := parseCarrierTimestamp(payload.OccurredAt, h.now)
	details := map[string]any{
		"carrierStatus": strings.TrimSpace(payload.Status),
	}
	if payload.Note != "" {
		details["note"] = payload.Note
	}
	if strings.TrimSpace(payload.ExpectedDelivery) != "" {
		if eta, err := time.Parse(time.RFC3339, strings.TrimSpace(payload.ExpectedDelivery)); err == nil {
			details["expectedDelivery"] = eta.UTC()
		}
	}

	return carrierPayload{
		orderID:    strings.TrimSpace(payload.OrderID),
		shipmentID: strings.TrimSpace(payload.ShipmentID),
		tracking:   tracking,
		status:     status,
		occurredAt: occurredAt,
		details:    details,
	}, nil
}

func (h *ShippingWebhookHandlers) parseUPS(cfg *carrierConfig, r *http.Request, body []byte) (carrierPayload, error) {
	if err := validateHMAC(cfg, r, body); err != nil {
		return carrierPayload{}, err
	}

	var payload struct {
		OrderID    string `json:"orderId"`
		ShipmentID string `json:"shipmentId"`
		Tracking   string `json:"trackingNumber"`
		Event      struct {
			Code        string `json:"code"`
			Description string `json:"description"`
			Time        string `json:"time"`
			Location    string `json:"location"`
		} `json:"event"`
	}

	if err := json.Unmarshal(body, &payload); err != nil {
		return carrierPayload{}, carrierError{code: "invalid_payload", message: "invalid UPS payload", status: http.StatusBadRequest}
	}

	tracking := strings.ToUpper(strings.TrimSpace(payload.Tracking))
	if tracking == "" {
		return carrierPayload{}, carrierError{code: "missing_tracking", message: "trackingNumber is required", status: http.StatusBadRequest}
	}

	status, err := translateStatus(cfg, payload.Event.Code)
	if err != nil {
		return carrierPayload{}, err
	}

	occurredAt := parseCarrierTimestamp(payload.Event.Time, h.now)
	details := map[string]any{
		"carrierStatus": strings.TrimSpace(payload.Event.Code),
	}
	if payload.Event.Description != "" {
		details["description"] = payload.Event.Description
	}
	if payload.Event.Location != "" {
		details["location"] = payload.Event.Location
	}

	return carrierPayload{
		orderID:    strings.TrimSpace(payload.OrderID),
		shipmentID: strings.TrimSpace(payload.ShipmentID),
		tracking:   tracking,
		status:     status,
		occurredAt: occurredAt,
		details:    details,
	}, nil
}

func (h *ShippingWebhookHandlers) parseFedEx(cfg *carrierConfig, r *http.Request, body []byte) (carrierPayload, error) {
	if err := validateToken(cfg, r); err != nil {
		return carrierPayload{}, err
	}

	var payload struct {
		OrderID         string `json:"order_id"`
		ShipmentID      string `json:"shipment_id"`
		TrackingNumber  string `json:"tracking_number"`
		EventStatus     string `json:"event_status"`
		StatusText      string `json:"status_text"`
		EventTime       string `json:"event_time"`
		ExceptionReason string `json:"exception_reason"`
	}

	if err := json.Unmarshal(body, &payload); err != nil {
		return carrierPayload{}, carrierError{code: "invalid_payload", message: "invalid FedEx payload", status: http.StatusBadRequest}
	}

	tracking := strings.ToUpper(strings.TrimSpace(payload.TrackingNumber))
	if tracking == "" {
		return carrierPayload{}, carrierError{code: "missing_tracking", message: "tracking_number is required", status: http.StatusBadRequest}
	}

	status, err := translateStatus(cfg, payload.EventStatus)
	if err != nil {
		return carrierPayload{}, err
	}

	occurredAt := parseCarrierTimestamp(payload.EventTime, h.now)
	details := map[string]any{
		"carrierStatus": strings.TrimSpace(payload.EventStatus),
	}
	if payload.StatusText != "" {
		details["description"] = payload.StatusText
	}
	if payload.ExceptionReason != "" {
		details["exceptionReason"] = payload.ExceptionReason
	}

	return carrierPayload{
		orderID:    strings.TrimSpace(payload.OrderID),
		shipmentID: strings.TrimSpace(payload.ShipmentID),
		tracking:   tracking,
		status:     status,
		occurredAt: occurredAt,
		details:    details,
	}, nil
}

func (h *ShippingWebhookHandlers) writeShipmentError(ctx context.Context, w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, services.ErrShipmentInvalidInput):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrShipmentNotFound), errors.Is(err, services.ErrOrderNotFound):
		w.WriteHeader(http.StatusAccepted)
	case errors.Is(err, services.ErrShipmentConflict), errors.Is(err, services.ErrOrderConflict):
		httpx.WriteError(ctx, w, httpx.NewError("shipment_conflict", err.Error(), http.StatusConflict))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("shipment_event_failed", "failed to record shipment event", http.StatusInternalServerError))
	}
}

func (h *ShippingWebhookHandlers) configFor(carrier string) *carrierConfig {
	key := normalizeCarrierKey(carrier)
	if cfg, ok := h.configs[key]; ok {
		return cfg
	}
	return nil
}

func normalizeCarrierKey(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, "_", "-")
	value = strings.ReplaceAll(value, " ", "-")
	switch value {
	case "jppost":
		return "jp-post"
	}
	return value
}

func translateStatus(cfg *carrierConfig, raw string) (string, error) {
	status := strings.ToLower(strings.TrimSpace(raw))
	if status == "" {
		return "", carrierError{code: "invalid_status", message: "status is required", status: http.StatusBadRequest}
	}
	if cfg != nil && len(cfg.statusMap) > 0 {
		if mapped, ok := cfg.statusMap[status]; ok && mapped != "" {
			return mapped, nil
		}
	}
	return status, nil
}

func parseCarrierTimestamp(value string, fallback func() time.Time) time.Time {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback().UTC()
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05 MST",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if ts, err := time.Parse(layout, value); err == nil {
			return ts.UTC()
		}
	}
	return fallback().UTC()
}

func validateHMAC(cfg *carrierConfig, r *http.Request, body []byte) error {
	if cfg.hmacHeader == "" {
		return nil
	}
	secret := strings.TrimSpace(cfg.hmacSecret)
	if secret == "" {
		return carrierError{code: "webhook_secret_unavailable", message: "hmac secret not configured", status: http.StatusServiceUnavailable}
	}
	signature := strings.TrimSpace(r.Header.Get(cfg.hmacHeader))
	if signature == "" {
		return carrierError{code: "missing_signature", message: fmt.Sprintf("%s header is required", cfg.hmacHeader), status: http.StatusBadRequest}
	}
	payload, err := hex.DecodeString(signature)
	if err != nil {
		return carrierError{code: "invalid_signature", message: "signature must be hex encoded", status: http.StatusBadRequest}
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	expected := mac.Sum(nil)
	if !hmac.Equal(expected, payload) {
		return carrierError{code: "invalid_signature", message: "signature verification failed", status: http.StatusUnauthorized}
	}
	return nil
}

func validateToken(cfg *carrierConfig, r *http.Request) error {
	token := strings.TrimSpace(cfg.authToken)
	if token == "" {
		return carrierError{code: "webhook_auth_unavailable", message: "auth token not configured", status: http.StatusServiceUnavailable}
	}
	header := cfg.tokenHeader
	if header == "" {
		header = "Authorization"
	}

	value := strings.TrimSpace(r.Header.Get(header))
	if value == "" {
		return carrierError{code: "missing_auth", message: fmt.Sprintf("%s header is required", header), status: http.StatusUnauthorized}
	}

	if strings.EqualFold(header, "authorization") {
		if !strings.HasPrefix(strings.ToLower(value), "bearer ") {
			return carrierError{code: "invalid_auth", message: "bearer token required", status: http.StatusUnauthorized}
		}
		got := strings.TrimSpace(value[len("Bearer "):])
		if subtle.ConstantTimeCompare([]byte(got), []byte(token)) != 1 {
			return carrierError{code: "invalid_auth", message: "invalid bearer token", status: http.StatusUnauthorized}
		}
		return nil
	}

	if subtle.ConstantTimeCompare([]byte(value), []byte(token)) != 1 {
		return carrierError{code: "invalid_auth", message: "invalid token", status: http.StatusUnauthorized}
	}
	return nil
}

func validateCIDR(cfg *carrierConfig, r *http.Request) error {
	if len(cfg.allowedCIDRs) == 0 {
		return nil
	}
	ip, err := extractClientIP(r)
	if err != nil {
		return carrierError{code: "forbidden", message: "source ip not allowed", status: http.StatusForbidden}
	}
	for _, network := range cfg.allowedCIDRs {
		if network.Contains(ip) {
			return nil
		}
	}
	return carrierError{code: "forbidden", message: "source ip not allowed", status: http.StatusForbidden}
}

func extractClientIP(r *http.Request) (net.IP, error) {
	if r == nil {
		return nil, errors.New("request nil")
	}
	if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
		parts := strings.Split(forwarded, ",")
		for _, part := range parts {
			if ip := net.ParseIP(strings.TrimSpace(part)); ip != nil {
				return ip, nil
			}
		}
	}
	addr := strings.TrimSpace(r.RemoteAddr)
	if addr == "" {
		return nil, errors.New("remote addr missing")
	}
	if host, _, err := net.SplitHostPort(addr); err == nil {
		addr = host
	}
	ip := net.ParseIP(addr)
	if ip == nil {
		return nil, errors.New("invalid remote addr")
	}
	return ip, nil
}

func cloneCarrierMap(src map[string]any) map[string]any {
	if len(src) == 0 {
		return make(map[string]any)
	}
	dst := make(map[string]any, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}
