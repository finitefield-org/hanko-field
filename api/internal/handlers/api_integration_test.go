//go:build integration

package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	firebaseauth "firebase.google.com/go/v4/auth"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/hanko-field/api/internal/internaltest/firestoretest"
	"github.com/hanko-field/api/internal/payments"
	"github.com/hanko-field/api/internal/platform/auth"
	pfirestore "github.com/hanko-field/api/internal/platform/firestore"
	firestoreRepo "github.com/hanko-field/api/internal/repositories/firestore"
	"github.com/hanko-field/api/internal/services"
)

func TestAPIIntegrationEndpointFlows(t *testing.T) {
	ctx := context.Background()
	cfg, cleanup := firestoretest.StartEmulator(t, "api-endpoint-flows")
	defer cleanup()

	provider := pfirestore.NewProvider(cfg)
	t.Cleanup(func() {
		_ = provider.Close(context.Background())
	})

	client, err := provider.Client(ctx)
	if err != nil {
		t.Fatalf("firestore client: %v", err)
	}
	t.Cleanup(func() {
		_ = client.Close()
	})

	baseTime := time.Date(2024, time.January, 2, 15, 4, 5, 0, time.UTC)

	firebaseStub := &stubFirebaseClient{
		records: map[string]*firebaseauth.UserRecord{
			"user-integration": {
				UserInfo: &firebaseauth.UserInfo{
					UID:         "user-integration",
					DisplayName: "Integration User",
					Email:       "integration@example.com",
					PhoneNumber: "+81-90-1234-5678",
					PhotoURL:    "https://example.com/avatar.png",
				},
				CustomClaims: map[string]any{
					"locale":            "ja-JP",
					"preferredLanguage": "ja",
					"role":              "user",
				},
			},
		},
	}

	userRepo, err := firestoreRepo.NewUserRepository(provider)
	if err != nil {
		t.Fatalf("user repository: %v", err)
	}
	userService, err := services.NewUserService(services.UserServiceDeps{
		Users:    userRepo,
		Firebase: firebaseStub,
		Clock: func() time.Time {
			return baseTime
		},
	})
	if err != nil {
		t.Fatalf("user service: %v", err)
	}
	meHandlers := NewMeHandlers(nil, userService)

	addressBook := &stubAddressProvider{
		addresses: map[string]services.Address{
			"addr-1": {
				ID:              "addr-1",
				Label:           "Home",
				Recipient:       "Integration User",
				Line1:           "1-2-3 Example",
				City:            "Tokyo",
				PostalCode:      "1000001",
				Country:         "JP",
				DefaultShipping: true,
				DefaultBilling:  true,
			},
		},
	}

	cartRepo, err := firestoreRepo.NewCartRepository(provider)
	if err != nil {
		t.Fatalf("cart repository: %v", err)
	}
	cartIDs := &deterministicIDGenerator{prefix: "cart-item"}
	cartService, err := services.NewCartService(services.CartServiceDeps{
		Repository:      cartRepo,
		Addresses:       addressBook,
		Clock:           func() time.Time { return baseTime },
		DefaultCurrency: "JPY",
		IDGenerator:     cartIDs.Next,
		Logger:          func(context.Context, string, map[string]any) {},
	})
	if err != nil {
		t.Fatalf("cart service: %v", err)
	}
	cartHandlers := NewCartHandlers(nil, cartService)

	inventoryRepo, err := firestoreRepo.NewInventoryRepository(provider)
	if err != nil {
		t.Fatalf("inventory repository: %v", err)
	}
	inventoryIDs := &deterministicIDGenerator{prefix: "resv"}
	inventoryEvents := &recordingInventoryPublisher{}
	inventoryService, err := services.NewInventoryService(services.InventoryServiceDeps{
		Inventory:   inventoryRepo,
		Clock:       func() time.Time { return baseTime },
		IDGenerator: inventoryIDs.Next,
		Events:      inventoryEvents,
		Logger:      func(context.Context, string, map[string]any) {},
	})
	if err != nil {
		t.Fatalf("inventory service: %v", err)
	}

	paymentDetails := payments.PaymentDetails{
		Provider: "stripe",
		IntentID: "pi_test",
		Status:   payments.StatusPending,
		Amount:   3000,
		Currency: "JPY",
	}
	paymentStub := newStubCheckoutPayments(baseTime, paymentDetails)
	workflowRecorder := &recordingWorkflow{}
	checkoutService, err := services.NewCheckoutService(services.CheckoutServiceDeps{
		Carts:          cartRepo,
		Inventory:      inventoryService,
		Payments:       paymentStub,
		Workflow:       workflowRecorder,
		Clock:          func() time.Time { return baseTime },
		ReservationTTL: 20 * time.Minute,
		Logger:         func(context.Context, string, map[string]any) {},
	})
	if err != nil {
		t.Fatalf("checkout service: %v", err)
	}
	checkoutHandlers := NewCheckoutHandlers(nil, checkoutService)

	exportPublisher := &stubExportPublisher{}
	exportService, err := services.NewExportService(services.ExportServiceDeps{
		Publisher: exportPublisher,
		Clock:     func() time.Time { return baseTime },
		IDGenerator: func() string {
			return fmt.Sprintf("task_%d", baseTime.UnixNano())
		},
	})
	if err != nil {
		t.Fatalf("export service: %v", err)
	}
	adminHandlers := NewAdminOperationsHandlers(nil, exportService)

	router := NewRouter(
		WithMeRoutes(meHandlers.Routes),
		WithCartRoutes(cartHandlers.Routes),
		WithAdditionalRoutes(checkoutHandlers.Routes),
		WithAdminRoutes(adminHandlers.Routes),
	)

	userIdentity := &auth.Identity{
		UID:   "user-integration",
		Email: "integration@example.com",
		Roles: []string{auth.RoleUser},
	}

	// 1. Signup/profile flow.
	profileResp := doRequest(t, router, http.MethodGet, "/api/v1/me/", nil, userIdentity, nil)
	if profileResp.Code != http.StatusOK {
		t.Fatalf("GET /me status: got %d want 200, body %s", profileResp.Code, profileResp.Body.String())
	}
	var mePayload meResponse
	if err := json.Unmarshal(profileResp.Body.Bytes(), &mePayload); err != nil {
		t.Fatalf("decode me response: %v", err)
	}
	if mePayload.Profile.ID != userIdentity.UID {
		t.Fatalf("expected profile ID %q got %q", userIdentity.UID, mePayload.Profile.ID)
	}
	if mePayload.Profile.DisplayName != "Integration User" {
		t.Fatalf("unexpected display name: %s", mePayload.Profile.DisplayName)
	}

	profileDoc, err := client.Collection("users").Doc(userIdentity.UID).Get(ctx)
	if err != nil {
		t.Fatalf("firestore user doc: %v", err)
	}
	if got := profileDoc.Data()["displayName"]; got != "Integration User" {
		t.Fatalf("expected firestore displayName stored, got %v", got)
	}

	updateBody := map[string]any{
		"display_name":       "Integration Tester",
		"preferred_language": "en",
		"notification_prefs": map[string]bool{"marketing.email": true},
	}
	updateBytes, _ := json.Marshal(updateBody)
	updateResp := doRequest(t, router, http.MethodPut, "/api/v1/me/", updateBytes, userIdentity, nil)
	if updateResp.Code != http.StatusOK {
		t.Fatalf("PUT /me status: got %d want 200, body %s", updateResp.Code, updateResp.Body.String())
	}
	updatedProfile, err := userRepo.FindByID(ctx, userIdentity.UID)
	if err != nil {
		t.Fatalf("user repo find: %v", err)
	}
	if updatedProfile.DisplayName != "Integration Tester" {
		t.Fatalf("expected updated display name, got %s", updatedProfile.DisplayName)
	}
	if updatedProfile.PreferredLanguage != "en" {
		t.Fatalf("expected preferred language en, got %s", updatedProfile.PreferredLanguage)
	}

	// 2. Cart flow.
	cartResp := doRequest(t, router, http.MethodGet, "/api/v1/cart/", nil, userIdentity, nil)
	if cartResp.Code != http.StatusOK {
		t.Fatalf("GET /cart status: %d body %s", cartResp.Code, cartResp.Body.String())
	}

	itemBody := map[string]any{
		"product_id": "prod-1",
		"sku":        "sku-1",
		"quantity":   2,
		"unit_price": 1500,
		"currency":   "JPY",
	}
	itemBytes, _ := json.Marshal(itemBody)
	itemResp := doRequest(t, router, http.MethodPost, "/api/v1/cart/items", itemBytes, userIdentity, map[string]string{
		"Content-Type": "application/json",
	})
	if itemResp.Code != http.StatusCreated {
		t.Fatalf("POST /cart/items status: %d body %s", itemResp.Code, itemResp.Body.String())
	}

	var cartPayload cartResponse
	if err := json.Unmarshal(itemResp.Body.Bytes(), &cartPayload); err != nil {
		t.Fatalf("decode cart response: %v", err)
	}
	if len(cartPayload.Cart.Items) != 1 {
		t.Fatalf("expected 1 cart item, got %d", len(cartPayload.Cart.Items))
	}
	lastModified := itemResp.Header().Get("Last-Modified")
	if lastModified == "" {
		t.Fatalf("expected Last-Modified header after cart mutation")
	}
	updatedAt := cartPayload.Cart.UpdatedAt

	cartDoc, err := client.Collection("carts").Doc(userIdentity.UID).Get(ctx)
	if err != nil {
		t.Fatalf("firestore cart doc: %v", err)
	}
	if count, ok := cartDoc.Data()["itemsCount"].(int64); !ok || count != 1 {
		t.Fatalf("expected itemsCount 1, got %v", cartDoc.Data()["itemsCount"])
	}

	patchBody := map[string]any{
		"shipping_address_id": "addr-1",
		"updated_at":          updatedAt,
	}
	patchBytes, _ := json.Marshal(patchBody)
	patchResp := doRequest(t, router, http.MethodPatch, "/api/v1/cart/", patchBytes, userIdentity, map[string]string{
		"If-Unmodified-Since": lastModified,
		"Content-Type":        "application/json",
	})
	if patchResp.Code != http.StatusOK {
		t.Fatalf("PATCH /cart status: %d body %s", patchResp.Code, patchResp.Body.String())
	}
	var patched cartResponse
	if err := json.Unmarshal(patchResp.Body.Bytes(), &patched); err != nil {
		t.Fatalf("decode patch response: %v", err)
	}
	if patched.Cart.ShippingAddress == nil || patched.Cart.ShippingAddress.ID != "addr-1" {
		t.Fatalf("expected shipping address set, got %#v", patched.Cart.ShippingAddress)
	}

	// Seed inventory stock for checkout.
	seedStock := map[string]any{
		"sku":         "sku-1",
		"productRef":  "/products/prod-1",
		"onHand":      10,
		"reserved":    0,
		"available":   10,
		"safetyStock": 0,
		"safetyDelta": 5,
		"updatedAt":   baseTime,
	}
	if _, err := client.Collection("inventory").Doc("sku-1").Set(ctx, seedStock); err != nil {
		t.Fatalf("seed inventory: %v", err)
	}

	// 3. Checkout flow.
	sessionReq := map[string]any{
		"provider":   "stripe",
		"successUrl": "https://example.com/success",
		"cancelUrl":  "https://example.com/cancel",
	}
	sessionBytes, _ := json.Marshal(sessionReq)
	sessionResp := doRequest(t, router, http.MethodPost, "/api/v1/checkout/session", sessionBytes, userIdentity, map[string]string{
		"Content-Type": "application/json",
	})
	if sessionResp.Code != http.StatusOK {
		t.Fatalf("POST /checkout/session status: %d body %s", sessionResp.Code, sessionResp.Body.String())
	}
	var checkoutPayload checkoutSessionResponse
	if err := json.Unmarshal(sessionResp.Body.Bytes(), &checkoutPayload); err != nil {
		t.Fatalf("decode checkout response: %v", err)
	}
	if checkoutPayload.SessionID == "" {
		t.Fatalf("expected session id in response")
	}

	reservationDoc, err := client.Collection("stockReservations").Doc("resv-1").Get(ctx)
	if err != nil {
		t.Fatalf("reservation doc: %v", err)
	}
	if status, ok := reservationDoc.Data()["status"].(string); !ok || status != "reserved" {
		t.Fatalf("expected reservation status reserved, got %v", reservationDoc.Data()["status"])
	}

	inventoryDoc, err := client.Collection("inventory").Doc("sku-1").Get(ctx)
	if err != nil {
		t.Fatalf("inventory doc: %v", err)
	}
	if reserved, ok := inventoryDoc.Data()["reserved"].(int64); !ok || reserved != 2 {
		t.Fatalf("expected reserved 2, got %v", inventoryDoc.Data()["reserved"])
	}

	storedCart, err := cartRepo.GetCart(ctx, userIdentity.UID)
	if err != nil {
		t.Fatalf("cart repo get: %v", err)
	}
	checkoutMeta, _ := storedCart.Metadata["checkout"].(map[string]any)
	if checkoutMeta == nil {
		t.Fatalf("expected checkout metadata stored")
	}
	if checkoutMeta["sessionId"] != checkoutPayload.SessionID {
		t.Fatalf("expected session metadata stored, got %v", checkoutMeta["sessionId"])
	}

	confirmReq := map[string]any{
		"sessionId":       checkoutPayload.SessionID,
		"paymentIntentId": "pi_test",
		"orderId":         "order-123",
	}
	confirmBytes, _ := json.Marshal(confirmReq)
	confirmResp := doRequest(t, router, http.MethodPost, "/api/v1/checkout/confirm", confirmBytes, userIdentity, map[string]string{
		"Content-Type": "application/json",
	})
	if confirmResp.Code != http.StatusOK {
		t.Fatalf("POST /checkout/confirm status: %d body %s", confirmResp.Code, confirmResp.Body.String())
	}
	var confirmPayload checkoutConfirmResponse
	if err := json.Unmarshal(confirmResp.Body.Bytes(), &confirmPayload); err != nil {
		t.Fatalf("decode confirm response: %v", err)
	}
	if confirmPayload.Status != "pending_capture" {
		t.Fatalf("expected pending_capture status, got %s", confirmPayload.Status)
	}
	if confirmPayload.OrderID != "order-123" {
		t.Fatalf("expected order id propagated, got %s", confirmPayload.OrderID)
	}

	finalCart, err := cartRepo.GetCart(ctx, userIdentity.UID)
	if err != nil {
		t.Fatalf("cart repo get final: %v", err)
	}
	finalCheckout, _ := finalCart.Metadata["checkout"].(map[string]any)
	if finalCheckout == nil || finalCheckout["status"] != "pending_capture" {
		t.Fatalf("expected checkout status pending_capture, got %v", finalCheckout)
	}

	if len(workflowRecorder.Payloads()) != 1 {
		t.Fatalf("expected workflow dispatched once, got %d", len(workflowRecorder.Payloads()))
	}

	// 4. Admin operations flow.
	adminIdentity := &auth.Identity{
		UID:   "admin-1",
		Email: "admin@example.com",
		Roles: []string{auth.RoleAdmin},
	}
	from := time.Date(2024, time.January, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2024, time.February, 1, 0, 0, 0, 0, time.UTC)
	adminReq := map[string]any{
		"entities": []string{"orders", "users"},
		"timeWindow": map[string]string{
			"from": from.Format(time.RFC3339Nano),
			"to":   to.Format(time.RFC3339Nano),
		},
		"idempotencyKey": "export-123",
	}
	adminBytes, _ := json.Marshal(adminReq)
	adminResp := doRequest(t, router, http.MethodPost, "/api/v1/admin/exports:bigquery-sync", adminBytes, adminIdentity, map[string]string{
		"Content-Type":     "application/json",
		"Idempotency-Key":  "export-123",
		"Accept":           "application/json",
		"Content-Language": "en",
	})
	if adminResp.Code != http.StatusAccepted {
		t.Fatalf("POST /admin/exports status: %d body %s", adminResp.Code, adminResp.Body.String())
	}
	var exportPayload adminBigQueryExportResponse
	if err := json.Unmarshal(adminResp.Body.Bytes(), &exportPayload); err != nil {
		t.Fatalf("decode export response: %v", err)
	}
	if exportPayload.Task.Kind != "export.bigquery" {
		t.Fatalf("expected task kind export.bigquery, got %s", exportPayload.Task.Kind)
	}
	if len(exportPublisher.Messages()) != 1 {
		t.Fatalf("expected one published export message, got %d", len(exportPublisher.Messages()))
	}
	published := exportPublisher.Messages()[0]
	if published.IdempotencyKey != "export-123" {
		t.Fatalf("expected exported idempotency key preserved, got %s", published.IdempotencyKey)
	}
	if len(published.Entities) != 2 {
		t.Fatalf("expected published entities recorded, got %#v", published.Entities)
	}
}

func doRequest(t *testing.T, router http.Handler, method, path string, body []byte, identity *auth.Identity, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	if len(body) > 0 && headers != nil {
		if _, ok := headers["Content-Type"]; !ok {
			req.Header.Set("Content-Type", "application/json")
		}
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	req = req.WithContext(auth.WithIdentity(req.Context(), identity))
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)
	return rr
}

type stubFirebaseClient struct {
	mu       sync.Mutex
	records  map[string]*firebaseauth.UserRecord
	disabled []string
}

func (s *stubFirebaseClient) GetUser(_ context.Context, uid string) (*firebaseauth.UserRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if record, ok := s.records[uid]; ok {
		return record, nil
	}
	return nil, fmt.Errorf("user %s not found", uid)
}

func (s *stubFirebaseClient) DisableUser(_ context.Context, uid string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.disabled = append(s.disabled, uid)
	return nil
}

type stubAddressProvider struct {
	mu        sync.Mutex
	addresses map[string]services.Address
}

func (s *stubAddressProvider) ListAddresses(_ context.Context, _ string) ([]services.Address, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	list := make([]services.Address, 0, len(s.addresses))
	for _, addr := range s.addresses {
		list = append(list, addr)
	}
	return list, nil
}

type deterministicIDGenerator struct {
	mu     sync.Mutex
	prefix string
	count  int
}

func (g *deterministicIDGenerator) Next() string {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.count++
	return fmt.Sprintf("%s-%d", g.prefix, g.count)
}

type recordingInventoryPublisher struct {
	mu     sync.Mutex
	events []services.InventoryStockEvent
}

func (p *recordingInventoryPublisher) PublishInventoryEvent(_ context.Context, event services.InventoryStockEvent) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.events = append(p.events, event)
	return nil
}

func (p *recordingInventoryPublisher) Events() []services.InventoryStockEvent {
	p.mu.Lock()
	defer p.mu.Unlock()
	cpy := make([]services.InventoryStockEvent, len(p.events))
	copy(cpy, p.events)
	return cpy
}

type stubCheckoutPayments struct {
	mu             sync.Mutex
	baseTime       time.Time
	createCalls    []payments.CheckoutSessionRequest
	contexts       []payments.PaymentContext
	lookupCalls    []payments.LookupRequest
	responseDetail payments.PaymentDetails
}

func newStubCheckoutPayments(base time.Time, detail payments.PaymentDetails) *stubCheckoutPayments {
	return &stubCheckoutPayments{
		baseTime:       base,
		responseDetail: detail,
	}
}

func (s *stubCheckoutPayments) CreateCheckoutSession(_ context.Context, ctx payments.PaymentContext, req payments.CheckoutSessionRequest) (payments.CheckoutSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.createCalls = append(s.createCalls, req)
	s.contexts = append(s.contexts, ctx)
	return payments.CheckoutSession{
		ID:           "sess_test",
		Provider:     "stripe",
		ClientSecret: "sec_test",
		RedirectURL:  "https://payments.example/sess_test",
		IntentID:     s.responseDetail.IntentID,
		ExpiresAt:    s.baseTime.Add(15 * time.Minute),
	}, nil
}

func (s *stubCheckoutPayments) LookupPayment(_ context.Context, ctx payments.PaymentContext, req payments.LookupRequest) (payments.PaymentDetails, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lookupCalls = append(s.lookupCalls, req)
	s.contexts = append(s.contexts, ctx)
	return s.responseDetail, nil
}

type recordingWorkflow struct {
	mu       sync.Mutex
	payloads []services.CheckoutWorkflowPayload
}

func (w *recordingWorkflow) DispatchCheckoutWorkflow(_ context.Context, payload services.CheckoutWorkflowPayload) (string, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.payloads = append(w.payloads, payload)
	return fmt.Sprintf("wf-%d", len(w.payloads)), nil
}

func (w *recordingWorkflow) Payloads() []services.CheckoutWorkflowPayload {
	w.mu.Lock()
	defer w.mu.Unlock()
	cpy := make([]services.CheckoutWorkflowPayload, len(w.payloads))
	copy(cpy, w.payloads)
	return cpy
}

type stubExportPublisher struct {
	mu       sync.Mutex
	messages []services.BigQueryExportMessage
}

func (p *stubExportPublisher) PublishBigQueryExport(_ context.Context, msg services.BigQueryExportMessage) (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.messages = append(p.messages, msg)
	return fmt.Sprintf("msg-%d", len(p.messages)), nil
}

func (p *stubExportPublisher) Messages() []services.BigQueryExportMessage {
	p.mu.Lock()
	defer p.mu.Unlock()
	cpy := make([]services.BigQueryExportMessage, len(p.messages))
	copy(cpy, p.messages)
	return cpy
}
