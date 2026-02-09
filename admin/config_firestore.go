package main

import (
	"context"
	"errors"
	"fmt"
	"html/template"
	"os"
	"sort"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

type runMode string

const (
	runModeMock runMode = "mock"
	runModeDev  runMode = "dev"
	runModeProd runMode = "prod"
)

type appConfig struct {
	HTTPAddr           string
	Mode               runMode
	Locale             string
	DefaultLocale      string
	FirestoreProjectID string
	CredentialsFile    string
}

type adminSnapshot struct {
	orders    map[string]*order
	materials map[string]*material
	countries map[string]string
}

type firestoreAdminSource struct {
	client        *firestore.Client
	locale        string
	defaultLocale string
	label         string
}

func loadConfig() (appConfig, error) {
	cfg := appConfig{
		HTTPAddr:      strings.TrimSpace(os.Getenv("ADMIN_HTTP_ADDR")),
		Locale:        strings.TrimSpace(os.Getenv("HANKO_ADMIN_LOCALE")),
		DefaultLocale: strings.TrimSpace(os.Getenv("HANKO_ADMIN_DEFAULT_LOCALE")),
	}

	if cfg.HTTPAddr == "" {
		cfg.HTTPAddr = ":3051"
	}
	if cfg.Locale == "" {
		cfg.Locale = "ja"
	}
	if cfg.DefaultLocale == "" {
		cfg.DefaultLocale = "ja"
	}

	modeValue := strings.ToLower(strings.TrimSpace(envFirst("HANKO_ADMIN_MODE", "HANKO_ADMIN_ENV")))
	if modeValue == "" {
		modeValue = string(runModeMock)
	}

	switch runMode(modeValue) {
	case runModeMock:
		cfg.Mode = runModeMock
		return cfg, nil
	case runModeDev:
		cfg.Mode = runModeDev
	case runModeProd:
		cfg.Mode = runModeProd
	default:
		return appConfig{}, fmt.Errorf("invalid HANKO_ADMIN_MODE %q: use mock, dev, or prod", modeValue)
	}

	projectIDKeys := []string{}
	credentialsKeys := []string{}
	switch cfg.Mode {
	case runModeDev:
		projectIDKeys = []string{
			"HANKO_ADMIN_FIREBASE_PROJECT_ID_DEV",
			"HANKO_ADMIN_FIREBASE_PROJECT_ID",
			"FIRESTORE_PROJECT_ID",
			"FIREBASE_PROJECT_ID",
			"GOOGLE_CLOUD_PROJECT",
		}
		credentialsKeys = []string{
			"HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE_DEV",
			"HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE",
			"GOOGLE_APPLICATION_CREDENTIALS",
		}
	case runModeProd:
		projectIDKeys = []string{
			"HANKO_ADMIN_FIREBASE_PROJECT_ID_PROD",
			"HANKO_ADMIN_FIREBASE_PROJECT_ID",
			"FIRESTORE_PROJECT_ID",
			"FIREBASE_PROJECT_ID",
			"GOOGLE_CLOUD_PROJECT",
		}
		credentialsKeys = []string{
			"HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE_PROD",
			"HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE",
			"GOOGLE_APPLICATION_CREDENTIALS",
		}
	}

	cfg.FirestoreProjectID = envFirst(projectIDKeys...)
	if cfg.FirestoreProjectID == "" {
		return appConfig{}, fmt.Errorf(
			"firebase mode (%s) requires project id env var: %s",
			cfg.Mode,
			strings.Join(projectIDKeys, ", "),
		)
	}

	cfg.CredentialsFile = envFirst(credentialsKeys...)
	return cfg, nil
}

func envFirst(keys ...string) string {
	for _, key := range keys {
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			return value
		}
	}
	return ""
}

func newServerWithConfig(cfg appConfig) (*server, error) {
	switch cfg.Mode {
	case runModeMock:
		return newMockServer()
	case runModeDev, runModeProd:
		label := "Firebase Dev"
		if cfg.Mode == runModeProd {
			label = "Firebase Prod"
		}

		source, err := newFirestoreAdminSource(cfg, label)
		if err != nil {
			return nil, err
		}

		tmpl, err := newAdminTemplate()
		if err != nil {
			_ = source.Close()
			return nil, err
		}

		s := &server{
			tmpl:        tmpl,
			mode:        cfg.Mode,
			sourceLabel: label,
			firestore:   source,
			orders:      map[string]*order{},
			materials:   map[string]*material{},
			countries:   map[string]string{},
		}

		if err := s.refreshFromSource(context.Background()); err != nil {
			_ = source.Close()
			return nil, err
		}

		return s, nil
	default:
		return nil, fmt.Errorf("unsupported mode: %s", cfg.Mode)
	}
}

func newAdminTemplate() (*template.Template, error) {
	return template.New("index.html").Funcs(template.FuncMap{
		"yen":              formatYen,
		"datetime":         formatDateTime,
		"orderStatusLabel": lookupOrderStatusLabel,
		"paymentStatusLabel": func(status string) string {
			if label, ok := paymentStatusLabels[status]; ok {
				return label
			}
			return status
		},
		"fulfillmentStatusLabel": func(status string) string {
			if label, ok := fulfillmentStatusLabels[status]; ok {
				return label
			}
			return status
		},
	}).ParseFiles("templates/index.html")
}

func newFirestoreAdminSource(cfg appConfig, label string) (*firestoreAdminSource, error) {
	clientOptions := []option.ClientOption{}
	if cfg.CredentialsFile != "" {
		clientOptions = append(clientOptions, option.WithCredentialsFile(cfg.CredentialsFile))
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := firestore.NewClient(ctx, cfg.FirestoreProjectID, clientOptions...)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize firestore client: %w", err)
	}

	return &firestoreAdminSource{
		client:        client,
		locale:        cfg.Locale,
		defaultLocale: cfg.DefaultLocale,
		label:         label,
	}, nil
}

func (s *server) Close() error {
	if s.firestore == nil {
		return nil
	}
	return s.firestore.Close()
}

func (s *server) refreshFromSource(ctx context.Context) error {
	if s.firestore == nil {
		return nil
	}

	loadCtx, cancel := context.WithTimeout(ctx, 7*time.Second)
	defer cancel()

	snapshot, err := s.firestore.loadSnapshot(loadCtx)
	if err != nil {
		return err
	}

	s.mu.Lock()
	s.orders = snapshot.orders
	s.materials = snapshot.materials
	s.countries = snapshot.countries
	s.refreshOrderIDsLocked()
	s.refreshMaterialIDsLocked()
	s.mu.Unlock()

	return nil
}

func (s *firestoreAdminSource) Close() error {
	if s == nil || s.client == nil {
		return nil
	}
	return s.client.Close()
}

func (s *firestoreAdminSource) loadSnapshot(ctx context.Context) (adminSnapshot, error) {
	orders, err := s.loadOrders(ctx)
	if err != nil {
		return adminSnapshot{}, err
	}

	materials, err := s.loadMaterials(ctx)
	if err != nil {
		return adminSnapshot{}, err
	}

	countries, err := s.loadCountries(ctx)
	if err != nil {
		return adminSnapshot{}, err
	}

	if len(countries) == 0 {
		for _, o := range orders {
			if o.CountryCode == "" {
				continue
			}
			countries[o.CountryCode] = o.CountryCode
		}
	}

	return adminSnapshot{
		orders:    orders,
		materials: materials,
		countries: countries,
	}, nil
}

func (s *firestoreAdminSource) loadOrders(ctx context.Context) (map[string]*order, error) {
	iter := s.client.Collection("orders").OrderBy("created_at", firestore.Desc).Documents(ctx)
	defer iter.Stop()

	orders := map[string]*order{}
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to load orders: %w", err)
		}

		o := s.decodeOrder(doc.Ref.ID, doc.Data())
		events, err := s.loadOrderEvents(ctx, doc.Ref)
		if err != nil {
			return nil, err
		}
		o.Events = events
		orders[o.ID] = o
	}

	return orders, nil
}

func (s *firestoreAdminSource) loadOrderEvents(ctx context.Context, orderRef *firestore.DocumentRef) ([]orderEvent, error) {
	iter := orderRef.Collection("events").OrderBy("created_at", firestore.Asc).Documents(ctx)
	defer iter.Stop()

	events := []orderEvent{}
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to load order events (%s): %w", orderRef.ID, err)
		}

		data := doc.Data()
		event := orderEvent{
			Type:         readStringField(data, "type"),
			ActorType:    readStringField(data, "actor_type"),
			ActorID:      readStringField(data, "actor_id"),
			BeforeStatus: readStringField(data, "before_status"),
			AfterStatus:  readStringField(data, "after_status"),
			Note:         readStringField(data, "note"),
			CreatedAt:    readTimeField(data, "created_at"),
		}
		if event.Type == "" {
			event.Type = "event"
		}
		if event.Note == "" {
			payload := readMapField(data, "payload")
			carrier := readStringField(payload, "carrier")
			trackingNo := readStringField(payload, "tracking_no")
			if carrier != "" || trackingNo != "" {
				event.Note = strings.TrimSpace(carrier + " / " + trackingNo)
			}
		}
		events = append(events, event)
	}

	return events, nil
}

func (s *firestoreAdminSource) decodeOrder(orderID string, data map[string]interface{}) *order {
	payment := readMapField(data, "payment")
	fulfillment := readMapField(data, "fulfillment")
	shipping := readMapField(data, "shipping")
	contact := readMapField(data, "contact")
	seal := readMapField(data, "seal")
	materialData := readMapField(data, "material")
	pricing := readMapField(data, "pricing")

	totalJPY, ok := readIntField(pricing, "total_jpy")
	if !ok {
		totalJPY, _ = readIntField(data, "total_jpy")
	}

	materialLabelJA := resolveLocalizedField(
		materialData,
		"label_i18n",
		"label",
		s.locale,
		s.defaultLocale,
		readStringField(materialData, "key"),
	)
	if materialLabelJA == "" {
		materialLabelJA = readStringField(data, "material_label_ja")
	}

	o := &order{
		ID:                orderID,
		OrderNo:           readStringField(data, "order_no"),
		Channel:           readStringField(data, "channel"),
		Locale:            readStringField(data, "locale"),
		Status:            readStringField(data, "status"),
		StatusUpdatedAt:   readTimeField(data, "status_updated_at"),
		PaymentStatus:     readStringField(payment, "status"),
		FulfillmentStatus: readStringField(fulfillment, "status"),
		TrackingNo:        readStringField(fulfillment, "tracking_no"),
		Carrier:           readStringField(fulfillment, "carrier"),
		CountryCode:       strings.ToUpper(readStringField(shipping, "country_code")),
		ContactEmail:      readStringField(contact, "email"),
		SealLine1:         readStringField(seal, "line1"),
		SealLine2:         readStringField(seal, "line2"),
		MaterialLabelJA:   materialLabelJA,
		TotalJPY:          totalJPY,
		CreatedAt:         readTimeField(data, "created_at"),
		UpdatedAt:         readTimeField(data, "updated_at"),
	}

	if o.OrderNo == "" {
		o.OrderNo = orderID
	}
	if o.Locale == "" {
		o.Locale = s.defaultLocale
	}
	if o.Status == "" {
		o.Status = "pending_payment"
	}
	if o.UpdatedAt.IsZero() {
		o.UpdatedAt = o.CreatedAt
	}
	if o.StatusUpdatedAt.IsZero() {
		o.StatusUpdatedAt = o.UpdatedAt
	}

	fillDerivedStatuses(o)
	return o
}

func fillDerivedStatuses(o *order) {
	if o.PaymentStatus != "" && o.FulfillmentStatus != "" {
		return
	}

	copy := *o
	applyDerivedStatuses(&copy)
	if o.PaymentStatus == "" {
		o.PaymentStatus = copy.PaymentStatus
	}
	if o.FulfillmentStatus == "" {
		o.FulfillmentStatus = copy.FulfillmentStatus
	}
}

func (s *firestoreAdminSource) loadMaterials(ctx context.Context) (map[string]*material, error) {
	iter := s.client.Collection("materials").OrderBy("sort_order", firestore.Asc).Documents(ctx)
	defer iter.Stop()

	materials := map[string]*material{}
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to load materials: %w", err)
		}

		data := doc.Data()
		price, ok := readIntField(data, "price_jpy")
		if !ok {
			price, _ = readIntField(data, "price")
		}

		sortOrder, ok := readIntField(data, "sort_order")
		if !ok {
			sortOrder = 0
		}

		version, ok := readIntField(data, "version")
		if !ok {
			version = 1
		}

		isActive, ok := readBoolField(data, "is_active")
		if !ok {
			isActive = true
		}

		m := &material{
			Key:             doc.Ref.ID,
			LabelI18N:       readStringMapField(data, "label_i18n"),
			DescriptionI18N: readStringMapField(data, "description_i18n"),
			PriceJPY:        price,
			IsActive:        isActive,
			SortOrder:       sortOrder,
			Version:         version,
			UpdatedAt:       readTimeField(data, "updated_at"),
		}
		if len(m.LabelI18N) == 0 {
			legacyLabel := readStringField(data, "label")
			if legacyLabel != "" {
				m.LabelI18N = map[string]string{"ja": legacyLabel}
			}
		}
		if len(m.DescriptionI18N) == 0 {
			legacyDescription := readStringField(data, "description")
			if legacyDescription != "" {
				m.DescriptionI18N = map[string]string{"ja": legacyDescription}
			}
		}
		if m.UpdatedAt.IsZero() {
			m.UpdatedAt = time.Now().UTC()
		}
		materials[m.Key] = m
	}

	return materials, nil
}

func (s *firestoreAdminSource) loadCountries(ctx context.Context) (map[string]string, error) {
	iter := s.client.Collection("countries").OrderBy("sort_order", firestore.Asc).Documents(ctx)
	defer iter.Stop()

	countries := map[string]string{}
	for {
		doc, err := iter.Next()
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to load countries: %w", err)
		}

		data := doc.Data()
		label := resolveLocalizedField(data, "label_i18n", "label", s.locale, s.defaultLocale, doc.Ref.ID)
		countries[strings.ToUpper(doc.Ref.ID)] = label
	}

	return countries, nil
}

func (s *firestoreAdminSource) persistOrderMutation(ctx context.Context, o *order, events []orderEvent) error {
	if o == nil {
		return errors.New("order is nil")
	}

	writeCtx, cancel := context.WithTimeout(ctx, 7*time.Second)
	defer cancel()

	orderRef := s.client.Collection("orders").Doc(o.ID)
	batch := s.client.Batch()

	fulfillment := map[string]interface{}{
		"status":      o.FulfillmentStatus,
		"carrier":     o.Carrier,
		"tracking_no": o.TrackingNo,
	}
	if o.FulfillmentStatus == "shipped" {
		fulfillment["shipped_at"] = o.UpdatedAt
	}
	if o.FulfillmentStatus == "delivered" {
		fulfillment["delivered_at"] = o.UpdatedAt
	}

	batch.Set(orderRef, map[string]interface{}{
		"status":            o.Status,
		"status_updated_at": o.StatusUpdatedAt,
		"updated_at":        o.UpdatedAt,
		"payment": map[string]interface{}{
			"status": o.PaymentStatus,
		},
		"fulfillment": fulfillment,
	}, firestore.MergeAll)

	for _, event := range events {
		batch.Set(orderRef.Collection("events").NewDoc(), encodeOrderEvent(event))
	}

	_, err := batch.Commit(writeCtx)
	if err != nil {
		return fmt.Errorf("failed to persist order mutation: %w", err)
	}
	return nil
}

func encodeOrderEvent(event orderEvent) map[string]interface{} {
	data := map[string]interface{}{
		"type":       event.Type,
		"actor_type": event.ActorType,
		"created_at": event.CreatedAt,
	}
	if event.ActorID != "" {
		data["actor_id"] = event.ActorID
	}
	if event.BeforeStatus != "" {
		data["before_status"] = event.BeforeStatus
	}
	if event.AfterStatus != "" {
		data["after_status"] = event.AfterStatus
	}
	if event.Note != "" {
		data["note"] = event.Note
	}
	if event.Type == "shipment_registered" {
		parts := strings.SplitN(event.Note, " / ", 2)
		payload := map[string]interface{}{}
		if len(parts) > 0 && strings.TrimSpace(parts[0]) != "" {
			payload["carrier"] = strings.TrimSpace(parts[0])
		}
		if len(parts) > 1 && strings.TrimSpace(parts[1]) != "" {
			payload["tracking_no"] = strings.TrimSpace(parts[1])
		}
		if len(payload) > 0 {
			data["payload"] = payload
		}
	}
	return data
}

func (s *firestoreAdminSource) persistMaterialMutation(ctx context.Context, m *material) error {
	if m == nil {
		return errors.New("material is nil")
	}

	writeCtx, cancel := context.WithTimeout(ctx, 7*time.Second)
	defer cancel()

	_, err := s.client.Collection("materials").Doc(m.Key).Set(writeCtx, map[string]interface{}{
		"label_i18n":       cloneStringMap(m.LabelI18N),
		"description_i18n": cloneStringMap(m.DescriptionI18N),
		"price_jpy":        m.PriceJPY,
		"is_active":        m.IsActive,
		"sort_order":       m.SortOrder,
		"version":          m.Version,
		"updated_at":       m.UpdatedAt,
	}, firestore.MergeAll)
	if err != nil {
		return fmt.Errorf("failed to persist material mutation: %w", err)
	}
	return nil
}

func cloneOrder(src *order) *order {
	if src == nil {
		return nil
	}
	copy := *src
	copy.Events = append([]orderEvent(nil), src.Events...)
	return &copy
}

func cloneMaterial(src *material) *material {
	if src == nil {
		return nil
	}
	copy := *src
	copy.LabelI18N = cloneStringMap(src.LabelI18N)
	copy.DescriptionI18N = cloneStringMap(src.DescriptionI18N)
	return &copy
}

func cloneStringMap(values map[string]string) map[string]string {
	if len(values) == 0 {
		return map[string]string{}
	}
	copy := make(map[string]string, len(values))
	for key, value := range values {
		trimmedKey := strings.TrimSpace(key)
		if trimmedKey == "" {
			continue
		}
		copy[trimmedKey] = strings.TrimSpace(value)
	}
	return copy
}

func resolveLocalizedField(
	data map[string]interface{},
	i18nField string,
	legacyField string,
	locale string,
	defaultLocale string,
	fallback string,
) string {
	if value := resolveLocalizedText(readStringMapField(data, i18nField), locale, defaultLocale); value != "" {
		return value
	}

	if legacyField != "" {
		if value := readStringField(data, legacyField); value != "" {
			return value
		}
	}

	return fallback
}

func resolveLocalizedText(values map[string]string, locale, defaultLocale string) string {
	if len(values) == 0 {
		return ""
	}

	lookup := func(target string) string {
		target = strings.ToLower(strings.TrimSpace(target))
		if target == "" {
			return ""
		}

		for key, value := range values {
			if strings.ToLower(strings.TrimSpace(key)) == target {
				if trimmed := strings.TrimSpace(value); trimmed != "" {
					return trimmed
				}
			}
		}

		if i := strings.Index(target, "-"); i > 0 {
			base := target[:i]
			for key, value := range values {
				if strings.ToLower(strings.TrimSpace(key)) == base {
					if trimmed := strings.TrimSpace(value); trimmed != "" {
						return trimmed
					}
				}
			}
		}

		return ""
	}

	if value := lookup(locale); value != "" {
		return value
	}
	if value := lookup(defaultLocale); value != "" {
		return value
	}
	if value := lookup("ja"); value != "" {
		return value
	}

	keys := make([]string, 0, len(values))
	for key, value := range values {
		if strings.TrimSpace(value) != "" {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	if len(keys) == 0 {
		return ""
	}

	return strings.TrimSpace(values[keys[0]])
}

func readStringField(data map[string]interface{}, key string) string {
	raw, ok := data[key]
	if !ok || raw == nil {
		return ""
	}

	switch value := raw.(type) {
	case string:
		return strings.TrimSpace(value)
	default:
		return ""
	}
}

func readIntField(data map[string]interface{}, key string) (int, bool) {
	raw, ok := data[key]
	if !ok || raw == nil {
		return 0, false
	}

	switch value := raw.(type) {
	case int:
		return value, true
	case int32:
		return int(value), true
	case int64:
		return int(value), true
	case float32:
		return int(value), true
	case float64:
		return int(value), true
	default:
		return 0, false
	}
}

func readBoolField(data map[string]interface{}, key string) (bool, bool) {
	raw, ok := data[key]
	if !ok || raw == nil {
		return false, false
	}

	value, ok := raw.(bool)
	if !ok {
		return false, false
	}
	return value, true
}

func readTimeField(data map[string]interface{}, key string) time.Time {
	raw, ok := data[key]
	if !ok || raw == nil {
		return time.Time{}
	}

	switch value := raw.(type) {
	case time.Time:
		return value
	default:
		return time.Time{}
	}
}

func readMapField(data map[string]interface{}, key string) map[string]interface{} {
	raw, ok := data[key]
	if !ok || raw == nil {
		return nil
	}

	switch value := raw.(type) {
	case map[string]interface{}:
		return value
	default:
		return nil
	}
}

func readStringMapField(data map[string]interface{}, key string) map[string]string {
	raw, ok := data[key]
	if !ok || raw == nil {
		return nil
	}

	result := map[string]string{}
	switch value := raw.(type) {
	case map[string]string:
		for mapKey, mapValue := range value {
			if trimmed := strings.TrimSpace(mapValue); trimmed != "" {
				result[mapKey] = trimmed
			}
		}
	case map[string]interface{}:
		for mapKey, mapValue := range value {
			if text, ok := mapValue.(string); ok {
				if trimmed := strings.TrimSpace(text); trimmed != "" {
					result[mapKey] = trimmed
				}
			}
		}
	}

	if len(result) == 0 {
		return nil
	}

	return result
}
