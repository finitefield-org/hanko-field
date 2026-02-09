package store

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const (
	defaultLocale = "ja"
)

var errIdempotentReplay = errors.New("idempotent replay")

type FirestoreStore struct {
	client *firestore.Client
	now    func() time.Time
	jst    *time.Location
}

type publicConfigDoc struct {
	SupportedLocales []string  `firestore:"supported_locales"`
	DefaultLocale    string    `firestore:"default_locale"`
	UpdatedAt        time.Time `firestore:"updated_at"`
}

type fontDoc struct {
	LabelI18N  map[string]string `firestore:"label_i18n"`
	FontFamily string            `firestore:"font_family"`
	IsActive   bool              `firestore:"is_active"`
	SortOrder  int               `firestore:"sort_order"`
	Version    int               `firestore:"version"`
}

type materialPhotoDoc struct {
	AssetID     string            `firestore:"asset_id"`
	StoragePath string            `firestore:"storage_path"`
	AltI18N     map[string]string `firestore:"alt_i18n"`
	SortOrder   int               `firestore:"sort_order"`
	IsPrimary   bool              `firestore:"is_primary"`
	Width       int               `firestore:"width"`
	Height      int               `firestore:"height"`
}

type materialDoc struct {
	LabelI18N       map[string]string  `firestore:"label_i18n"`
	DescriptionI18N map[string]string  `firestore:"description_i18n"`
	Photos          []materialPhotoDoc `firestore:"photos"`
	PriceJPY        int                `firestore:"price_jpy"`
	IsActive        bool               `firestore:"is_active"`
	SortOrder       int                `firestore:"sort_order"`
	Version         int                `firestore:"version"`
}

type countryDoc struct {
	LabelI18N      map[string]string `firestore:"label_i18n"`
	ShippingFeeJPY int               `firestore:"shipping_fee_jpy"`
	IsActive       bool              `firestore:"is_active"`
	SortOrder      int               `firestore:"sort_order"`
	Version        int               `firestore:"version"`
}

type idempotencyDoc struct {
	OrderID     string `firestore:"order_id"`
	RequestHash string `firestore:"request_hash"`
}

type orderCounterDoc struct {
	LastSeq int `firestore:"last_seq"`
}

type orderSummaryDoc struct {
	OrderNo string `firestore:"order_no"`
	Status  string `firestore:"status"`
	Pricing struct {
		TotalJPY int    `firestore:"total_jpy"`
		Currency string `firestore:"currency"`
	} `firestore:"pricing"`
	Payment struct {
		Status string `firestore:"status"`
	} `firestore:"payment"`
	Fulfillment struct {
		Status string `firestore:"status"`
	} `firestore:"fulfillment"`
}

type webhookEventDoc struct {
	Processed bool `firestore:"processed"`
}

func NewFirestoreStore(ctx context.Context, projectID string) (*FirestoreStore, error) {
	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return nil, err
	}

	loc, err := time.LoadLocation("Asia/Tokyo")
	if err != nil {
		loc = time.FixedZone("JST", 9*60*60)
	}

	return &FirestoreStore{
		client: client,
		now:    time.Now,
		jst:    loc,
	}, nil
}

func (s *FirestoreStore) Close() error {
	return s.client.Close()
}

func (s *FirestoreStore) GetPublicConfig(ctx context.Context) (PublicConfig, error) {
	doc, err := s.client.Collection("app_config").Doc("public").Get(ctx)
	if status.Code(err) == codes.NotFound {
		return defaultPublicConfig(), nil
	}
	if err != nil {
		return PublicConfig{}, err
	}

	var cfg publicConfigDoc
	if err := doc.DataTo(&cfg); err != nil {
		return PublicConfig{}, err
	}
	return normalizePublicConfig(PublicConfig{
		SupportedLocales: cfg.SupportedLocales,
		DefaultLocale:    cfg.DefaultLocale,
	}), nil
}

func (s *FirestoreStore) ListActiveFonts(ctx context.Context) ([]Font, error) {
	docs, err := s.client.Collection("fonts").
		Where("is_active", "==", true).
		OrderBy("sort_order", firestore.Asc).
		Documents(ctx).
		GetAll()
	if err != nil {
		return nil, err
	}

	fonts := make([]Font, 0, len(docs))
	for _, d := range docs {
		var item fontDoc
		if err := d.DataTo(&item); err != nil {
			return nil, err
		}
		fonts = append(fonts, Font{
			Key:        d.Ref.ID,
			LabelI18N:  cloneI18N(item.LabelI18N),
			FontFamily: item.FontFamily,
			Version:    item.Version,
			SortOrder:  item.SortOrder,
		})
	}

	return fonts, nil
}

func (s *FirestoreStore) ListActiveMaterials(ctx context.Context) ([]Material, error) {
	docs, err := s.client.Collection("materials").
		Where("is_active", "==", true).
		OrderBy("sort_order", firestore.Asc).
		Documents(ctx).
		GetAll()
	if err != nil {
		return nil, err
	}

	materials := make([]Material, 0, len(docs))
	for _, d := range docs {
		var item materialDoc
		if err := d.DataTo(&item); err != nil {
			return nil, err
		}

		photos := make([]MaterialPhoto, 0, len(item.Photos))
		for _, p := range item.Photos {
			photos = append(photos, MaterialPhoto{
				AssetID:     p.AssetID,
				StoragePath: p.StoragePath,
				AltI18N:     cloneI18N(p.AltI18N),
				SortOrder:   p.SortOrder,
				IsPrimary:   p.IsPrimary,
				Width:       p.Width,
				Height:      p.Height,
			})
		}
		sort.Slice(photos, func(i, j int) bool {
			if photos[i].SortOrder == photos[j].SortOrder {
				return photos[i].AssetID < photos[j].AssetID
			}
			return photos[i].SortOrder < photos[j].SortOrder
		})

		materials = append(materials, Material{
			Key:             d.Ref.ID,
			LabelI18N:       cloneI18N(item.LabelI18N),
			DescriptionI18N: cloneI18N(item.DescriptionI18N),
			Photos:          photos,
			PriceJPY:        item.PriceJPY,
			Version:         item.Version,
			SortOrder:       item.SortOrder,
		})
	}

	return materials, nil
}

func (s *FirestoreStore) ListActiveCountries(ctx context.Context) ([]Country, error) {
	docs, err := s.client.Collection("countries").
		Where("is_active", "==", true).
		OrderBy("sort_order", firestore.Asc).
		Documents(ctx).
		GetAll()
	if err != nil {
		return nil, err
	}

	countries := make([]Country, 0, len(docs))
	for _, d := range docs {
		var item countryDoc
		if err := d.DataTo(&item); err != nil {
			return nil, err
		}
		countries = append(countries, Country{
			Code:           d.Ref.ID,
			LabelI18N:      cloneI18N(item.LabelI18N),
			ShippingFeeJPY: item.ShippingFeeJPY,
			Version:        item.Version,
			SortOrder:      item.SortOrder,
		})
	}

	return countries, nil
}

func (s *FirestoreStore) CreateOrder(ctx context.Context, input CreateOrderInput) (CreateOrderResult, error) {
	now := s.now().UTC()
	normalized := normalizeCreateOrderInput(input)
	requestHash, err := hashOrderRequest(normalized)
	if err != nil {
		return CreateOrderResult{}, err
	}

	idempotencyID := fmt.Sprintf("%s:%s", normalized.Channel, normalized.IdempotencyKey)
	idempotencyRef := s.client.Collection("idempotency_keys").Doc(idempotencyID)
	orderRef := s.client.Collection("orders").NewDoc()
	orderEventRef := orderRef.Collection("events").NewDoc()
	counterID := now.In(s.jst).Format("200601")
	counterRef := s.client.Collection("order_no_counters").Doc(counterID)

	result := CreateOrderResult{}

	err = s.client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		cfg, err := s.getPublicConfigTx(ctx, tx)
		if err != nil {
			return err
		}
		if !contains(cfg.SupportedLocales, normalized.Locale) || !contains(cfg.SupportedLocales, normalized.Contact.PreferredLocale) {
			return ErrUnsupportedLocale
		}

		idempotencySnap, err := tx.Get(idempotencyRef)
		if err == nil {
			var idem idempotencyDoc
			if err := idempotencySnap.DataTo(&idem); err != nil {
				return err
			}
			if idem.RequestHash != requestHash {
				return ErrIdempotencyConflict
			}

			existingOrderRef := s.client.Collection("orders").Doc(idem.OrderID)
			existingOrderSnap, err := tx.Get(existingOrderRef)
			if err != nil {
				return err
			}
			var existing orderSummaryDoc
			if err := existingOrderSnap.DataTo(&existing); err != nil {
				return err
			}
			result = CreateOrderResult{
				OrderID:           idem.OrderID,
				OrderNo:           existing.OrderNo,
				Status:            existing.Status,
				PaymentStatus:     existing.Payment.Status,
				FulfillmentStatus: existing.Fulfillment.Status,
				TotalJPY:          existing.Pricing.TotalJPY,
				Currency:          existing.Pricing.Currency,
				IdempotentReplay:  true,
			}
			return errIdempotentReplay
		}
		if status.Code(err) != codes.NotFound {
			return err
		}

		font, err := s.getFontTx(ctx, tx, normalized.Seal.FontKey)
		if err != nil {
			return err
		}
		material, err := s.getMaterialTx(ctx, tx, normalized.MaterialKey)
		if err != nil {
			return err
		}
		country, err := s.getCountryTx(ctx, tx, normalized.Shipping.CountryCode)
		if err != nil {
			return err
		}

		subtotal := material.PriceJPY
		shipping := country.ShippingFeeJPY
		tax := 0
		discount := 0
		total := subtotal + shipping + tax - discount
		if total < 0 {
			total = 0
		}

		seq := 1
		counterSnap, err := tx.Get(counterRef)
		if err == nil {
			var counter orderCounterDoc
			if err := counterSnap.DataTo(&counter); err != nil {
				return err
			}
			if counter.LastSeq > 0 {
				seq = counter.LastSeq + 1
			}
		} else if status.Code(err) != codes.NotFound {
			return err
		}

		if err := tx.Set(counterRef, map[string]any{
			"last_seq":   seq,
			"updated_at": now,
		}, firestore.MergeAll); err != nil {
			return err
		}

		orderNo := fmt.Sprintf("HF-%s-%04d", now.In(s.jst).Format("20060102"), seq)
		orderData := map[string]any{
			"order_no":          orderNo,
			"channel":           normalized.Channel,
			"locale":            normalized.Locale,
			"status":            "pending_payment",
			"status_updated_at": now,
			"seal": map[string]any{
				"line1":           normalized.Seal.Line1,
				"line2":           normalized.Seal.Line2,
				"shape":           normalized.Seal.Shape,
				"font_key":        font.Key,
				"font_label_i18n": cloneI18N(font.LabelI18N),
				"font_version":    font.Version,
			},
			"material": map[string]any{
				"key":            material.Key,
				"label_i18n":     cloneI18N(material.LabelI18N),
				"unit_price_jpy": material.PriceJPY,
				"version":        material.Version,
			},
			"shipping": map[string]any{
				"country_code":       country.Code,
				"country_label_i18n": cloneI18N(country.LabelI18N),
				"country_version":    country.Version,
				"fee_jpy":            country.ShippingFeeJPY,
				"recipient_name":     normalized.Shipping.RecipientName,
				"phone":              normalized.Shipping.Phone,
				"postal_code":        normalized.Shipping.PostalCode,
				"state":              normalized.Shipping.State,
				"city":               normalized.Shipping.City,
				"address_line1":      normalized.Shipping.AddressLine1,
				"address_line2":      normalized.Shipping.AddressLine2,
			},
			"contact": map[string]any{
				"email":            normalized.Contact.Email,
				"preferred_locale": normalized.Contact.PreferredLocale,
			},
			"pricing": map[string]any{
				"subtotal_jpy": subtotal,
				"shipping_jpy": shipping,
				"tax_jpy":      tax,
				"discount_jpy": discount,
				"total_jpy":    total,
				"currency":     "JPY",
			},
			"payment": map[string]any{
				"provider": "stripe",
				"status":   "unpaid",
			},
			"fulfillment": map[string]any{
				"status": "pending",
			},
			"idempotency_key": normalized.IdempotencyKey,
			"terms_agreed":    normalized.TermsAgreed,
			"created_at":      now,
			"updated_at":      now,
		}

		if err := tx.Set(orderRef, orderData); err != nil {
			return err
		}

		if err := tx.Set(orderEventRef, map[string]any{
			"type":       "order_created",
			"actor_type": "system",
			"payload": map[string]any{
				"channel":   normalized.Channel,
				"total_jpy": total,
			},
			"created_at": now,
		}); err != nil {
			return err
		}

		if err := tx.Set(idempotencyRef, map[string]any{
			"channel":         normalized.Channel,
			"idempotency_key": normalized.IdempotencyKey,
			"request_hash":    requestHash,
			"order_id":        orderRef.ID,
			"created_at":      now,
			"expire_at":       now.Add(30 * 24 * time.Hour),
		}); err != nil {
			return err
		}

		result = CreateOrderResult{
			OrderID:           orderRef.ID,
			OrderNo:           orderNo,
			Status:            "pending_payment",
			PaymentStatus:     "unpaid",
			FulfillmentStatus: "pending",
			TotalJPY:          total,
			Currency:          "JPY",
			IdempotentReplay:  false,
		}
		return nil
	})
	if err != nil {
		if errors.Is(err, errIdempotentReplay) {
			return result, nil
		}
		return CreateOrderResult{}, err
	}

	return result, nil
}

func (s *FirestoreStore) ProcessStripeWebhook(ctx context.Context, event StripeWebhookEvent) (ProcessStripeWebhookResult, error) {
	e := normalizeWebhookEvent(event)
	if e.ProviderEventID == "" {
		return ProcessStripeWebhookResult{}, errors.New("provider event id is required")
	}

	now := s.now().UTC()
	webhookRef := s.client.Collection("payment_webhook_events").Doc(e.ProviderEventID)
	result := ProcessStripeWebhookResult{}

	err := s.client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		webhookSnap, err := tx.Get(webhookRef)
		if err == nil {
			var existing webhookEventDoc
			if err := webhookSnap.DataTo(&existing); err != nil {
				return err
			}
			if existing.Processed {
				result.AlreadyProcessed = true
				result.Processed = false
				return nil
			}
		} else if status.Code(err) != codes.NotFound {
			return err
		}

		if err := tx.Set(webhookRef, map[string]any{
			"provider":   "stripe",
			"event_type": e.EventType,
			"order_id":   e.OrderID,
			"processed":  false,
			"created_at": now,
			"expire_at":  now.Add(90 * 24 * time.Hour),
		}, firestore.MergeAll); err != nil {
			return err
		}

		if e.OrderID == "" {
			if err := tx.Set(webhookRef, map[string]any{"processed": true}, firestore.MergeAll); err != nil {
				return err
			}
			result.Processed = true
			return nil
		}

		orderRef := s.client.Collection("orders").Doc(e.OrderID)
		orderSnap, err := tx.Get(orderRef)
		if status.Code(err) == codes.NotFound {
			if err := tx.Set(webhookRef, map[string]any{"processed": true}, firestore.MergeAll); err != nil {
				return err
			}
			result.Processed = true
			return nil
		}
		if err != nil {
			return err
		}

		var order orderSummaryDoc
		if err := orderSnap.DataTo(&order); err != nil {
			return err
		}

		paymentStatus, nextStatus, auditEventType := stripeTransition(e.EventType)
		afterStatus := order.Status
		updates := []firestore.Update{
			{Path: "payment.last_event_id", Value: e.ProviderEventID},
			{Path: "updated_at", Value: now},
		}
		if e.PaymentIntentID != "" {
			updates = append(updates, firestore.Update{Path: "payment.intent_id", Value: e.PaymentIntentID})
		}
		if paymentStatus != "" {
			updates = append(updates, firestore.Update{Path: "payment.status", Value: paymentStatus})
		}
		if nextStatus != "" && nextStatus != order.Status && canTransition(order.Status, nextStatus) {
			updates = append(updates,
				firestore.Update{Path: "status", Value: nextStatus},
				firestore.Update{Path: "status_updated_at", Value: now},
			)
			afterStatus = nextStatus
		}

		if err := tx.Update(orderRef, updates); err != nil {
			return err
		}

		payload := map[string]any{
			"provider_event_id": e.ProviderEventID,
			"event_type":        e.EventType,
		}
		if e.PaymentIntentID != "" {
			payload["payment_intent_id"] = e.PaymentIntentID
		}

		eventData := map[string]any{
			"type":       auditEventType,
			"actor_type": "webhook",
			"actor_id":   "stripe",
			"payload":    payload,
			"created_at": now,
		}
		if afterStatus != order.Status {
			eventData["before_status"] = order.Status
			eventData["after_status"] = afterStatus
		}
		if err := tx.Set(orderRef.Collection("events").NewDoc(), eventData); err != nil {
			return err
		}

		if err := tx.Set(webhookRef, map[string]any{"processed": true}, firestore.MergeAll); err != nil {
			return err
		}
		result.Processed = true
		return nil
	})
	if err != nil {
		return ProcessStripeWebhookResult{}, err
	}
	return result, nil
}

func (s *FirestoreStore) getPublicConfigTx(ctx context.Context, tx *firestore.Transaction) (PublicConfig, error) {
	doc, err := tx.Get(s.client.Collection("app_config").Doc("public"))
	if status.Code(err) == codes.NotFound {
		return defaultPublicConfig(), nil
	}
	if err != nil {
		return PublicConfig{}, err
	}

	var cfg publicConfigDoc
	if err := doc.DataTo(&cfg); err != nil {
		return PublicConfig{}, err
	}

	return normalizePublicConfig(PublicConfig{
		SupportedLocales: cfg.SupportedLocales,
		DefaultLocale:    cfg.DefaultLocale,
	}), nil
}

func (s *FirestoreStore) getFontTx(ctx context.Context, tx *firestore.Transaction, key string) (Font, error) {
	doc, err := tx.Get(s.client.Collection("fonts").Doc(key))
	if status.Code(err) == codes.NotFound {
		return Font{}, ErrInvalidReference
	}
	if err != nil {
		return Font{}, err
	}

	var item fontDoc
	if err := doc.DataTo(&item); err != nil {
		return Font{}, err
	}
	if !item.IsActive {
		return Font{}, ErrInactiveReference
	}
	return Font{
		Key:        key,
		LabelI18N:  cloneI18N(item.LabelI18N),
		FontFamily: item.FontFamily,
		Version:    item.Version,
		SortOrder:  item.SortOrder,
	}, nil
}

func (s *FirestoreStore) getMaterialTx(ctx context.Context, tx *firestore.Transaction, key string) (Material, error) {
	doc, err := tx.Get(s.client.Collection("materials").Doc(key))
	if status.Code(err) == codes.NotFound {
		return Material{}, ErrInvalidReference
	}
	if err != nil {
		return Material{}, err
	}

	var item materialDoc
	if err := doc.DataTo(&item); err != nil {
		return Material{}, err
	}
	if !item.IsActive {
		return Material{}, ErrInactiveReference
	}

	photos := make([]MaterialPhoto, 0, len(item.Photos))
	for _, p := range item.Photos {
		photos = append(photos, MaterialPhoto{
			AssetID:     p.AssetID,
			StoragePath: p.StoragePath,
			AltI18N:     cloneI18N(p.AltI18N),
			SortOrder:   p.SortOrder,
			IsPrimary:   p.IsPrimary,
			Width:       p.Width,
			Height:      p.Height,
		})
	}
	return Material{
		Key:             key,
		LabelI18N:       cloneI18N(item.LabelI18N),
		DescriptionI18N: cloneI18N(item.DescriptionI18N),
		Photos:          photos,
		PriceJPY:        item.PriceJPY,
		Version:         item.Version,
		SortOrder:       item.SortOrder,
	}, nil
}

func (s *FirestoreStore) getCountryTx(ctx context.Context, tx *firestore.Transaction, code string) (Country, error) {
	doc, err := tx.Get(s.client.Collection("countries").Doc(code))
	if status.Code(err) == codes.NotFound {
		return Country{}, ErrInvalidReference
	}
	if err != nil {
		return Country{}, err
	}

	var item countryDoc
	if err := doc.DataTo(&item); err != nil {
		return Country{}, err
	}
	if !item.IsActive {
		return Country{}, ErrInactiveReference
	}
	return Country{
		Code:           code,
		LabelI18N:      cloneI18N(item.LabelI18N),
		ShippingFeeJPY: item.ShippingFeeJPY,
		Version:        item.Version,
		SortOrder:      item.SortOrder,
	}, nil
}

func defaultPublicConfig() PublicConfig {
	return PublicConfig{
		SupportedLocales: []string{"ja", "en"},
		DefaultLocale:    defaultLocale,
	}
}

func normalizePublicConfig(cfg PublicConfig) PublicConfig {
	normalized := make([]string, 0, len(cfg.SupportedLocales))
	seen := make(map[string]struct{}, len(cfg.SupportedLocales))
	for _, locale := range cfg.SupportedLocales {
		l := strings.ToLower(strings.TrimSpace(locale))
		if l == "" {
			continue
		}
		if _, ok := seen[l]; ok {
			continue
		}
		seen[l] = struct{}{}
		normalized = append(normalized, l)
	}
	if len(normalized) == 0 {
		normalized = []string{"ja", "en"}
	}
	def := strings.ToLower(strings.TrimSpace(cfg.DefaultLocale))
	if def == "" || !contains(normalized, def) {
		def = defaultLocale
	}
	if !contains(normalized, def) {
		normalized = append([]string{def}, normalized...)
	}
	return PublicConfig{SupportedLocales: normalized, DefaultLocale: def}
}

func normalizeCreateOrderInput(input CreateOrderInput) CreateOrderInput {
	return CreateOrderInput{
		Channel:        strings.ToLower(strings.TrimSpace(input.Channel)),
		Locale:         strings.ToLower(strings.TrimSpace(input.Locale)),
		IdempotencyKey: strings.TrimSpace(input.IdempotencyKey),
		TermsAgreed:    input.TermsAgreed,
		Seal: SealInput{
			Line1:   strings.TrimSpace(input.Seal.Line1),
			Line2:   strings.TrimSpace(input.Seal.Line2),
			Shape:   strings.ToLower(strings.TrimSpace(input.Seal.Shape)),
			FontKey: strings.TrimSpace(input.Seal.FontKey),
		},
		MaterialKey: strings.TrimSpace(input.MaterialKey),
		Shipping: ShippingInput{
			CountryCode:   strings.ToUpper(strings.TrimSpace(input.Shipping.CountryCode)),
			RecipientName: strings.TrimSpace(input.Shipping.RecipientName),
			Phone:         strings.TrimSpace(input.Shipping.Phone),
			PostalCode:    strings.TrimSpace(input.Shipping.PostalCode),
			State:         strings.TrimSpace(input.Shipping.State),
			City:          strings.TrimSpace(input.Shipping.City),
			AddressLine1:  strings.TrimSpace(input.Shipping.AddressLine1),
			AddressLine2:  strings.TrimSpace(input.Shipping.AddressLine2),
		},
		Contact: ContactInput{
			Email:           strings.TrimSpace(input.Contact.Email),
			PreferredLocale: strings.ToLower(strings.TrimSpace(input.Contact.PreferredLocale)),
		},
	}
}

func hashOrderRequest(input CreateOrderInput) (string, error) {
	payload, err := json.Marshal(input)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(payload)
	return hex.EncodeToString(sum[:]), nil
}

func cloneI18N(in map[string]string) map[string]string {
	if len(in) == 0 {
		return map[string]string{}
	}
	out := make(map[string]string, len(in))
	for k, v := range in {
		out[strings.ToLower(strings.TrimSpace(k))] = strings.TrimSpace(v)
	}
	return out
}

func contains(values []string, value string) bool {
	for _, item := range values {
		if item == value {
			return true
		}
	}
	return false
}

func normalizeWebhookEvent(event StripeWebhookEvent) StripeWebhookEvent {
	return StripeWebhookEvent{
		ProviderEventID: strings.TrimSpace(event.ProviderEventID),
		EventType:       strings.TrimSpace(event.EventType),
		PaymentIntentID: strings.TrimSpace(event.PaymentIntentID),
		OrderID:         strings.TrimSpace(event.OrderID),
	}
}

func stripeTransition(eventType string) (paymentStatus string, nextStatus string, auditEventType string) {
	switch eventType {
	case "payment_intent.succeeded":
		return "paid", "paid", "payment_paid"
	case "payment_intent.payment_failed", "payment_intent.canceled":
		return "failed", "canceled", "payment_failed"
	case "charge.refunded":
		return "refunded", "refunded", "payment_refunded"
	default:
		return "", "", "payment_event_recorded"
	}
}

func canTransition(current string, next string) bool {
	allowed := map[string]map[string]struct{}{
		"pending_payment": {
			"paid":     {},
			"canceled": {},
		},
		"paid": {
			"manufacturing": {},
			"refunded":      {},
		},
		"manufacturing": {
			"shipped":  {},
			"refunded": {},
		},
		"shipped": {
			"delivered": {},
			"refunded":  {},
		},
	}

	nextSet, ok := allowed[current]
	if !ok {
		return false
	}
	_, ok = nextSet[next]
	return ok
}
