package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"

	"hanko-field/api/internal/store"
)

const maxRequestBodyBytes = 1 << 20

type Options struct {
	StorageAssetsBucket string
	StripeWebhookSecret string
	Logger              *log.Logger
}

type Server struct {
	store               store.Store
	storageAssetsBucket string
	stripeWebhookSecret string
	logger              *log.Logger
}

func New(store store.Store, opts Options) *Server {
	logger := opts.Logger
	if logger == nil {
		logger = log.Default()
	}

	return &Server{
		store:               store,
		storageAssetsBucket: strings.TrimSpace(opts.StorageAssetsBucket),
		stripeWebhookSecret: strings.TrimSpace(opts.StripeWebhookSecret),
		logger:              logger,
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/v1/config/public", s.handlePublicConfig)
	mux.HandleFunc("/v1/catalog", s.handleCatalog)
	mux.HandleFunc("/v1/orders", s.handleCreateOrder)
	mux.HandleFunc("/v1/payments/stripe/webhook", s.handleStripeWebhook)
	return mux
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
		return
	}
	s.writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *Server) handlePublicConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
		return
	}

	cfg, err := s.store.GetPublicConfig(r.Context())
	if err != nil {
		s.logger.Printf("failed to load public config: %v", err)
		s.writeError(w, http.StatusInternalServerError, "internal", "internal server error")
		return
	}

	s.writeJSON(w, http.StatusOK, map[string]any{
		"supported_locales": cfg.SupportedLocales,
		"default_locale":    cfg.DefaultLocale,
	})
}

func (s *Server) handleCatalog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
		return
	}

	ctx := r.Context()
	cfg, err := s.store.GetPublicConfig(ctx)
	if err != nil {
		s.logger.Printf("failed to load public config: %v", err)
		s.writeError(w, http.StatusInternalServerError, "internal", "internal server error")
		return
	}

	requestedLocale := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("locale")))
	if requestedLocale == "" {
		requestedLocale = cfg.DefaultLocale
	}
	if !contains(cfg.SupportedLocales, requestedLocale) {
		s.writeError(w, http.StatusBadRequest, "invalid_locale", "unsupported locale")
		return
	}

	fonts, materials, countries, err := s.loadCatalog(ctx)
	if err != nil {
		s.logger.Printf("failed to load catalog: %v", err)
		s.writeError(w, http.StatusInternalServerError, "internal", "internal server error")
		return
	}

	fontResp := make([]map[string]any, 0, len(fonts))
	for _, item := range fonts {
		fontResp = append(fontResp, map[string]any{
			"key":         item.Key,
			"label":       resolveLocalized(item.LabelI18N, requestedLocale, cfg.DefaultLocale),
			"font_family": item.FontFamily,
			"version":     item.Version,
		})
	}

	materialResp := make([]map[string]any, 0, len(materials))
	for _, item := range materials {
		photos := make([]map[string]any, 0, len(item.Photos))
		for _, photo := range item.Photos {
			photos = append(photos, map[string]any{
				"asset_id":     photo.AssetID,
				"asset_url":    makeAssetURL(s.storageAssetsBucket, photo.StoragePath),
				"storage_path": photo.StoragePath,
				"alt":          resolveLocalized(photo.AltI18N, requestedLocale, cfg.DefaultLocale),
				"sort_order":   photo.SortOrder,
				"is_primary":   photo.IsPrimary,
				"width":        photo.Width,
				"height":       photo.Height,
			})
		}

		materialResp = append(materialResp, map[string]any{
			"key":         item.Key,
			"label":       resolveLocalized(item.LabelI18N, requestedLocale, cfg.DefaultLocale),
			"description": resolveLocalized(item.DescriptionI18N, requestedLocale, cfg.DefaultLocale),
			"price_jpy":   item.PriceJPY,
			"version":     item.Version,
			"photos":      photos,
		})
	}

	countryResp := make([]map[string]any, 0, len(countries))
	for _, item := range countries {
		countryResp = append(countryResp, map[string]any{
			"code":             item.Code,
			"label":            resolveLocalized(item.LabelI18N, requestedLocale, cfg.DefaultLocale),
			"shipping_fee_jpy": item.ShippingFeeJPY,
			"version":          item.Version,
		})
	}

	s.writeJSON(w, http.StatusOK, map[string]any{
		"locale":            requestedLocale,
		"supported_locales": cfg.SupportedLocales,
		"default_locale":    cfg.DefaultLocale,
		"fonts":             fontResp,
		"materials":         materialResp,
		"countries":         countryResp,
	})
}

func (s *Server) loadCatalog(ctx context.Context) ([]store.Font, []store.Material, []store.Country, error) {
	fonts, err := s.store.ListActiveFonts(ctx)
	if err != nil {
		return nil, nil, nil, err
	}
	materials, err := s.store.ListActiveMaterials(ctx)
	if err != nil {
		return nil, nil, nil, err
	}
	countries, err := s.store.ListActiveCountries(ctx)
	if err != nil {
		return nil, nil, nil, err
	}
	return fonts, materials, countries, nil
}

func (s *Server) handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
		return
	}

	var req createOrderRequest
	if err := decodeJSONBody(r, &req); err != nil {
		s.writeError(w, http.StatusBadRequest, "invalid_json", err.Error())
		return
	}

	input, err := validateCreateOrderRequest(req)
	if err != nil {
		s.writeError(w, http.StatusBadRequest, "validation_error", err.Error())
		return
	}

	result, err := s.store.CreateOrder(r.Context(), input)
	if err != nil {
		s.writeCreateOrderError(w, err)
		return
	}

	statusCode := http.StatusCreated
	if result.IdempotentReplay {
		statusCode = http.StatusOK
	}

	s.writeJSON(w, statusCode, map[string]any{
		"order_id":           result.OrderID,
		"order_no":           result.OrderNo,
		"status":             result.Status,
		"payment_status":     result.PaymentStatus,
		"fulfillment_status": result.FulfillmentStatus,
		"pricing": map[string]any{
			"total_jpy": result.TotalJPY,
			"currency":  result.Currency,
		},
		"idempotent_replay": result.IdempotentReplay,
	})
}

func (s *Server) writeCreateOrderError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, store.ErrUnsupportedLocale):
		s.writeError(w, http.StatusBadRequest, "unsupported_locale", "unsupported locale")
	case errors.Is(err, store.ErrInvalidReference):
		s.writeError(w, http.StatusBadRequest, "invalid_reference", "invalid font/material/country")
	case errors.Is(err, store.ErrInactiveReference):
		s.writeError(w, http.StatusBadRequest, "inactive_reference", "inactive font/material/country")
	case errors.Is(err, store.ErrIdempotencyConflict):
		s.writeError(w, http.StatusConflict, "idempotency_conflict", "idempotency key is already used with different payload")
	default:
		s.logger.Printf("failed to create order: %v", err)
		s.writeError(w, http.StatusInternalServerError, "internal", "internal server error")
	}
}

func (s *Server) handleStripeWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "method not allowed")
		return
	}

	payload, err := io.ReadAll(io.LimitReader(r.Body, maxRequestBodyBytes))
	if err != nil {
		s.writeError(w, http.StatusBadRequest, "invalid_request", "failed to read request body")
		return
	}

	if err := verifyStripeSignature(payload, r.Header.Get("Stripe-Signature"), s.stripeWebhookSecret); err != nil {
		s.writeError(w, http.StatusUnauthorized, "invalid_signature", err.Error())
		return
	}

	event, err := parseStripeEvent(payload)
	if err != nil {
		s.writeError(w, http.StatusBadRequest, "invalid_payload", err.Error())
		return
	}

	result, err := s.store.ProcessStripeWebhook(r.Context(), event)
	if err != nil {
		s.logger.Printf("failed to process stripe webhook: %v", err)
		s.writeError(w, http.StatusInternalServerError, "internal", "internal server error")
		return
	}

	s.writeJSON(w, http.StatusOK, map[string]any{
		"ok":                true,
		"processed":         result.Processed,
		"already_processed": result.AlreadyProcessed,
	})
}

func (s *Server) writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		s.logger.Printf("failed to encode JSON response: %v", err)
	}
}

func (s *Server) writeError(w http.ResponseWriter, status int, code, message string) {
	s.writeJSON(w, status, map[string]any{
		"error": map[string]any{
			"code":    code,
			"message": message,
		},
	})
}

func decodeJSONBody(r *http.Request, dst any) error {
	defer r.Body.Close()
	dec := json.NewDecoder(io.LimitReader(r.Body, maxRequestBodyBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}
	if err := dec.Decode(&struct{}{}); err != io.EOF {
		return errors.New("request body must contain a single JSON object")
	}
	return nil
}

func makeAssetURL(bucket, storagePath string) string {
	trimmedPath := strings.TrimLeft(strings.TrimSpace(storagePath), "/")
	trimmedBucket := strings.Trim(strings.TrimSpace(bucket), "/")
	if trimmedPath == "" {
		return ""
	}
	if trimmedBucket == "" {
		return "/" + trimmedPath
	}
	return fmt.Sprintf("https://storage.googleapis.com/%s/%s", trimmedBucket, trimmedPath)
}

func contains(values []string, target string) bool {
	for _, item := range values {
		if item == target {
			return true
		}
	}
	return false
}
