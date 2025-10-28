package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminOrderHandlers_ListOrders_MapsFilters(t *testing.T) {
	var captured services.OrderListFilter
	service := &stubOrderService{
		listFn: func(ctx context.Context, filter services.OrderListFilter) (domain.CursorPage[services.Order], error) {
			captured = filter
			return domain.CursorPage[services.Order]{}, nil
		},
	}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, nil)

	req := httptest.NewRequest(http.MethodGet, "/orders?status=paid,in_production&payment_status=captured,pending&paymentStatus=refunded&queue=queue-a&production_queue=queue-b&channel=dashboard&sales_channel=app&customer_email=%20ops@example.com%20&promotion_code=%20SPRING%20&page_size=150&page_token=%20token123%20&order=asc&sort=updated_at&since=2024-01-01T00:00:00Z&until=2024-02-01T00:00:00Z", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "ops", Roles: []string{auth.RoleStaff}}))
	rec := httptest.NewRecorder()

	handler.listOrders(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	if captured.Pagination.PageSize != 150 {
		t.Fatalf("expected page size 150, got %d", captured.Pagination.PageSize)
	}
	if captured.Pagination.PageToken != "token123" {
		t.Fatalf("expected page token trimmed, got %q", captured.Pagination.PageToken)
	}
	if captured.SortBy != services.OrderSortUpdatedAt {
		t.Fatalf("expected sort updated_at, got %q", captured.SortBy)
	}
	if captured.SortOrder != services.SortAsc {
		t.Fatalf("expected ascending sort, got %v", captured.SortOrder)
	}
	if len(captured.Status) != 2 || captured.Status[0] != "paid" || captured.Status[1] != "in_production" {
		t.Fatalf("expected status filters, got %v", captured.Status)
	}
	if len(captured.PaymentStatuses) != 3 ||
		captured.PaymentStatuses[0] != "captured" ||
		captured.PaymentStatuses[1] != "pending" ||
		captured.PaymentStatuses[2] != "refunded" {
		t.Fatalf("expected merged payment statuses, got %v", captured.PaymentStatuses)
	}
	if len(captured.ProductionQueues) != 2 || captured.ProductionQueues[0] != "queue-a" || captured.ProductionQueues[1] != "queue-b" {
		t.Fatalf("expected production queues, got %v", captured.ProductionQueues)
	}
	if len(captured.Channels) != 2 || captured.Channels[0] != "dashboard" || captured.Channels[1] != "app" {
		t.Fatalf("expected channels merged, got %v", captured.Channels)
	}
	if captured.CustomerEmail != "ops@example.com" {
		t.Fatalf("expected trimmed customer email, got %q", captured.CustomerEmail)
	}
	if captured.PromotionCode != "SPRING" {
		t.Fatalf("expected trimmed promotion code, got %q", captured.PromotionCode)
	}
	if captured.DateRange.From == nil || captured.DateRange.To == nil {
		t.Fatalf("expected date range to be set, got %+v", captured.DateRange)
	}
	expectedFrom := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	if !captured.DateRange.From.Equal(expectedFrom) {
		t.Fatalf("expected date range from %v, got %v", expectedFrom, captured.DateRange.From)
	}
	expectedTo := time.Date(2024, 2, 1, 0, 0, 0, 0, time.UTC)
	if !captured.DateRange.To.Equal(expectedTo) {
		t.Fatalf("expected date range to %v, got %v", expectedTo, captured.DateRange.To)
	}
}

func TestAdminOrderHandlers_ListOrders_ReturnsOperationalFields(t *testing.T) {
	now := time.Date(2024, 3, 5, 12, 0, 0, 0, time.UTC)
	lastEventAt := now.Add(-30 * time.Minute)
	placedAt := now.Add(-2 * time.Hour)
	paidAt := now.Add(-90 * time.Minute)
	queue := "production-q1"

	order := services.Order{
		ID:          " ord_001 ",
		OrderNumber: " HF-0001 ",
		Status:      domain.OrderStatusInProduction,
		Currency:    " jpy ",
		Totals: services.OrderTotals{
			Total: 12500,
		},
		Contact: &services.OrderContact{
			Email: "customer@example.com",
		},
		Promotion: &services.CartPromotion{
			Code: "SPRINGSALE",
		},
		Production: services.OrderProduction{
			QueueRef:      &queue,
			LastEventType: "qc",
			LastEventAt:   &lastEventAt,
			OnHold:        true,
		},
		Metadata: map[string]any{
			"channel":          "dashboard",
			"outstandingTasks": []any{"packaging", "QC Signoff"},
			"payment": map[string]any{
				"status": "captured",
			},
		},
		Notes: map[string]any{
			"internal": "white glove customer",
		},
		Payments: []services.Payment{
			{
				Status:    "authorized",
				CreatedAt: now.Add(-4 * time.Hour),
			},
			{
				Status:    "captured",
				CreatedAt: now.Add(-3 * time.Hour),
			},
		},
		CreatedAt: now,
		UpdatedAt: now.Add(15 * time.Minute),
		PlacedAt:  &placedAt,
		PaidAt:    &paidAt,
	}

	var nextToken string
	service := &stubOrderService{
		listFn: func(ctx context.Context, filter services.OrderListFilter) (domain.CursorPage[services.Order], error) {
			return domain.CursorPage[services.Order]{
				Items:         []services.Order{order},
				NextPageToken: " next-page ",
			}, nil
		},
	}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, nil)

	req := httptest.NewRequest(http.MethodGet, "/orders", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	rec := httptest.NewRecorder()

	handler.listOrders(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var payload struct {
		Items []struct {
			ID               string   `json:"id"`
			OrderNumber      string   `json:"order_number"`
			Status           string   `json:"status"`
			PaymentStatus    string   `json:"payment_status"`
			Currency         string   `json:"currency"`
			Total            int64    `json:"total"`
			CustomerEmail    string   `json:"customer_email"`
			PromotionCode    string   `json:"promotion_code"`
			Channel          string   `json:"channel"`
			ProductionQueue  string   `json:"production_queue"`
			ProductionStage  string   `json:"production_stage"`
			LastEventType    string   `json:"last_event_type"`
			LastEventAt      string   `json:"last_event_at"`
			OutstandingTasks []string `json:"outstanding_tasks"`
			OnHold           bool     `json:"on_hold"`
			CreatedAt        string   `json:"created_at"`
			UpdatedAt        string   `json:"updated_at"`
			PlacedAt         string   `json:"placed_at"`
			PaidAt           string   `json:"paid_at"`
		} `json:"items"`
		NextPageToken string `json:"next_page_token"`
	}

	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(payload.Items) != 1 {
		t.Fatalf("expected one item, got %d", len(payload.Items))
	}
	item := payload.Items[0]
	nextToken = payload.NextPageToken

	if item.ID != "ord_001" {
		t.Fatalf("expected trimmed id, got %q", item.ID)
	}
	if item.OrderNumber != "HF-0001" {
		t.Fatalf("expected trimmed order number, got %q", item.OrderNumber)
	}
	if item.Status != "in_production" {
		t.Fatalf("expected status in_production, got %q", item.Status)
	}
	if item.PaymentStatus != "captured" {
		t.Fatalf("expected payment status captured, got %q", item.PaymentStatus)
	}
	if item.Currency != "jpy" {
		t.Fatalf("expected trimmed currency, got %q", item.Currency)
	}
	if item.Total != 12500 {
		t.Fatalf("expected total 12500, got %d", item.Total)
	}
	if item.CustomerEmail != "customer@example.com" {
		t.Fatalf("expected customer email, got %q", item.CustomerEmail)
	}
	if item.PromotionCode != "SPRINGSALE" {
		t.Fatalf("expected promotion code, got %q", item.PromotionCode)
	}
	if item.Channel != "dashboard" {
		t.Fatalf("expected channel dashboard, got %q", item.Channel)
	}
	if item.ProductionQueue != "production-q1" {
		t.Fatalf("expected production queue, got %q", item.ProductionQueue)
	}
	if item.ProductionStage != "qc" {
		t.Fatalf("expected production stage qc, got %q", item.ProductionStage)
	}
	if item.LastEventType != "qc" {
		t.Fatalf("expected last event type qc, got %q", item.LastEventType)
	}
	if item.LastEventAt != formatTime(lastEventAt) {
		t.Fatalf("expected last event timestamp, got %q", item.LastEventAt)
	}
	if len(item.OutstandingTasks) != 2 {
		t.Fatalf("expected two outstanding tasks, got %v", item.OutstandingTasks)
	}
	if !item.OnHold {
		t.Fatalf("expected on_hold true")
	}
	if item.CreatedAt != formatTime(now) {
		t.Fatalf("expected created_at formatted, got %q", item.CreatedAt)
	}
	if item.UpdatedAt != formatTime(now.Add(15*time.Minute)) {
		t.Fatalf("expected updated_at formatted, got %q", item.UpdatedAt)
	}
	if item.PlacedAt != formatTime(placedAt) {
		t.Fatalf("expected placed_at formatted, got %q", item.PlacedAt)
	}
	if item.PaidAt != formatTime(paidAt) {
		t.Fatalf("expected paid_at formatted, got %q", item.PaidAt)
	}
	if nextToken != "next-page" {
		t.Fatalf("expected trimmed next page token, got %q", nextToken)
	}
}

func TestAdminOrderHandlers_ListOrders_RequiresPrivilegedRole(t *testing.T) {
	var invoked bool
	service := &stubOrderService{
		listFn: func(ctx context.Context, filter services.OrderListFilter) (domain.CursorPage[services.Order], error) {
			invoked = true
			return domain.CursorPage[services.Order]{}, nil
		},
	}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, nil)

	cases := []struct {
		name         string
		identity     *auth.Identity
		expectedCode int
		shouldInvoke bool
	}{
		{
			name:         "missing identity",
			identity:     nil,
			expectedCode: http.StatusUnauthorized,
			shouldInvoke: false,
		},
		{
			name:         "insufficient role",
			identity:     &auth.Identity{UID: "user", Roles: []string{auth.RoleUser}},
			expectedCode: http.StatusForbidden,
			shouldInvoke: false,
		},
		{
			name:         "admin allowed",
			identity:     &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}},
			expectedCode: http.StatusOK,
			shouldInvoke: true,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			invoked = false
			req := httptest.NewRequest(http.MethodGet, "/orders", nil)
			if tc.identity != nil {
				req = req.WithContext(auth.WithIdentity(req.Context(), tc.identity))
			}
			rec := httptest.NewRecorder()

			handler.listOrders(rec, req)

			if rec.Code != tc.expectedCode {
				t.Fatalf("expected status %d, got %d", tc.expectedCode, rec.Code)
			}
			if tc.shouldInvoke && !invoked {
				t.Fatalf("expected service to be invoked")
			}
			if !tc.shouldInvoke && invoked {
				t.Fatalf("expected service not to be invoked")
			}
		})
	}
}

func TestAdminOrderHandlers_UpdateOrderStatus_SucceedsWithAudit(t *testing.T) {
	var capturedCmd services.OrderStatusTransitionCommand
	now := time.Date(2024, 6, 10, 9, 0, 0, 0, time.UTC)
	service := &stubOrderService{
		getFn: func(ctx context.Context, orderID string, opts services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:          orderID,
				OrderNumber: "HF-2024-00010",
				Status:      domain.OrderStatusPaid,
				Currency:    "jpy",
				Totals: services.OrderTotals{
					Total: 2500,
				},
				CreatedAt: now.Add(-1 * time.Hour),
				UpdatedAt: now.Add(-30 * time.Minute),
			}, nil
		},
		transitionFn: func(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
			capturedCmd = cmd
			return services.Order{
				ID:          cmd.OrderID,
				OrderNumber: "HF-2024-00010",
				Status:      domain.OrderStatusInProduction,
				Currency:    "jpy",
				Totals: services.OrderTotals{
					Total: 2500,
				},
				CreatedAt: now.Add(-1 * time.Hour),
				UpdatedAt: now,
			}, nil
		},
	}
	audit := &captureAuditLogService{}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, audit)

	body := `{"target_status":"in_production","reason":" expedite ","metadata":{"queue":"laser","notify":true}}`
	req := httptest.NewRequest(http.MethodPut, "/orders/ord_123:status", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_123")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "staff-42", Roles: []string{auth.RoleStaff}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.updateOrderStatus(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var resp adminOrderStatusResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Order.Status != "in_production" {
		t.Fatalf("expected summary status in_production, got %q", resp.Order.Status)
	}

	if capturedCmd.OrderID != "ord_123" {
		t.Fatalf("expected order id ord_123, got %q", capturedCmd.OrderID)
	}
	if capturedCmd.TargetStatus != services.OrderStatus(domain.OrderStatusInProduction) {
		t.Fatalf("expected target status in_production, got %q", capturedCmd.TargetStatus)
	}
	if capturedCmd.ExpectedStatus == nil || *capturedCmd.ExpectedStatus != services.OrderStatus(domain.OrderStatusPaid) {
		t.Fatalf("expected expected status pointer to paid, got %#v", capturedCmd.ExpectedStatus)
	}
	if capturedCmd.Reason != "expedite" {
		t.Fatalf("expected trimmed reason expedite, got %q", capturedCmd.Reason)
	}
	if capturedCmd.Metadata == nil || capturedCmd.Metadata["queue"] != "laser" || capturedCmd.Metadata["notify"] != true {
		t.Fatalf("expected metadata preserved, got %#v", capturedCmd.Metadata)
	}

	if len(audit.records) != 1 {
		t.Fatalf("expected one audit record, got %d", len(audit.records))
	}
	record := audit.records[0]
	if record.Actor != "staff-42" {
		t.Fatalf("expected audit actor staff-42, got %q", record.Actor)
	}
	if record.ActorType != "staff" {
		t.Fatalf("expected actor type staff, got %q", record.ActorType)
	}
	if record.Action != "order.status.transition" {
		t.Fatalf("expected audit action order.status.transition, got %q", record.Action)
	}
	if record.TargetRef != "/orders/ord_123" {
		t.Fatalf("expected target ref /orders/ord_123, got %q", record.TargetRef)
	}
	if record.Diff["status"].Before != "paid" || record.Diff["status"].After != "in_production" {
		t.Fatalf("expected diff recorded, got %#v", record.Diff["status"])
	}
	if record.Metadata["reason"] != "expedite" {
		t.Fatalf("expected reason metadata, got %#v", record.Metadata["reason"])
	}
	if record.Metadata["queue"] != "laser" || record.Metadata["notify"] != true {
		t.Fatalf("expected metadata merged, got %#v", record.Metadata)
	}
}

func TestAdminOrderHandlers_CreateShipment_Success(t *testing.T) {
	shipments := &stubShipmentService{
		createFn: func(ctx context.Context, cmd services.CreateShipmentCommand) (services.Shipment, error) {
			return services.Shipment{
				ID:           "shp_001",
				OrderID:      cmd.OrderID,
				Carrier:      strings.TrimSpace(cmd.Carrier),
				Service:      strings.TrimSpace(cmd.ServiceLevel),
				TrackingCode: "TRK-001",
				Status:       "label_created",
				CreatedAt:    time.Date(2024, 7, 10, 8, 0, 0, 0, time.UTC),
				UpdatedAt:    time.Date(2024, 7, 10, 8, 0, 0, 0, time.UTC),
			}, nil
		},
	}
	handler := NewAdminOrderHandlers(nil, nil, shipments, nil, nil)

	body := `{
		"carrier": " yamato ",
		"service_level": "TA-Q-BIN",
		"tracking_preference": "auto",
		"package": {"length": 20, "width": 10, "height": 5, "weight": 1.2, "unit": "cm"},
		"items": [{"sku": " sku-1 ", "quantity": 1}]
	}`
	req := httptest.NewRequest(http.MethodPost, "/orders/ord_abc/shipments", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_abc")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "staff-1", Roles: []string{auth.RoleAdmin}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.createShipment(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d", rec.Code)
	}
	if shipments.captured == nil {
		t.Fatalf("expected shipment command to be captured")
	}
	cmd := *shipments.captured
	if cmd.OrderID != "ord_abc" {
		t.Fatalf("expected order id ord_abc, got %s", cmd.OrderID)
	}
	if len(cmd.Items) != 1 || cmd.Items[0].LineItemSKU != "sku-1" || cmd.Items[0].Quantity != 1 {
		t.Fatalf("unexpected shipment items: %#v", cmd.Items)
	}
	if cmd.Package == nil || cmd.Package.Unit != "cm" {
		t.Fatalf("expected package unit to be set")
	}
	var resp struct {
		Shipment orderShipmentPayload `json:"shipment"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Shipment.ID != "shp_001" {
		t.Fatalf("expected response shipment id shp_001, got %s", resp.Shipment.ID)
	}
	if !strings.EqualFold(resp.Shipment.Carrier, "yamato") {
		t.Fatalf("expected response carrier yamato, got %s", resp.Shipment.Carrier)
	}
}

func TestAdminOrderHandlers_CreateShipment_MapsServiceErrors(t *testing.T) {
	shipments := &stubShipmentService{
		err: services.ErrShipmentInvalidInput,
	}
	handler := NewAdminOrderHandlers(nil, nil, shipments, nil, nil)

	body := `{
		"carrier": "yamato",
		"service_level": "TA-Q-BIN",
		"tracking_preference": "auto",
		"items": [{"sku": "sku-1", "quantity": 1}]
	}`
	req := httptest.NewRequest(http.MethodPost, "/orders/ord_err/shipments", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_err")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "staff-2", Roles: []string{auth.RoleStaff}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.createShipment(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
}

func TestAdminOrderHandlers_UpdateOrderStatus_AllowsReadyToShipToShipped(t *testing.T) {
	var capturedCmd services.OrderStatusTransitionCommand
	service := &stubOrderService{
		getFn: func(ctx context.Context, orderID string, opts services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:     orderID,
				Status: domain.OrderStatusReadyToShip,
			}, nil
		},
		transitionFn: func(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
			capturedCmd = cmd
			return services.Order{
				ID:     cmd.OrderID,
				Status: domain.OrderStatusShipped,
			}, nil
		},
	}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, nil)

	body := `{"target_status":"shipped"}`
	req := httptest.NewRequest(http.MethodPut, "/orders/ord_ready:status", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_ready")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "ops", Roles: []string{auth.RoleAdmin}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.updateOrderStatus(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	if capturedCmd.TargetStatus != services.OrderStatus(domain.OrderStatusShipped) {
		t.Fatalf("expected target shipped, got %s", capturedCmd.TargetStatus)
	}
	if capturedCmd.ExpectedStatus == nil || *capturedCmd.ExpectedStatus != services.OrderStatus(domain.OrderStatusReadyToShip) {
		t.Fatalf("expected expected status ready_to_ship, got %#v", capturedCmd.ExpectedStatus)
	}
}

func TestAdminOrderHandlers_UpdateOrderStatus_RejectsOutOfSequenceTransition(t *testing.T) {
	service := &stubOrderService{
		getFn: func(ctx context.Context, orderID string, opts services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:     orderID,
				Status: domain.OrderStatusPaid,
			}, nil
		},
		transitionFn: func(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
			t.Fatalf("expected transition not to be called")
			return services.Order{}, nil
		},
	}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, nil)

	body := `{"target_status":"shipped"}`
	req := httptest.NewRequest(http.MethodPut, "/orders/ord_200:status", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_200")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "ops", Roles: []string{auth.RoleAdmin}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.updateOrderStatus(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", rec.Code)
	}
}

func TestAdminOrderHandlers_UpdateOrderStatus_ExpectedStatusMismatch(t *testing.T) {
	service := &stubOrderService{
		getFn: func(ctx context.Context, orderID string, opts services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:     orderID,
				Status: domain.OrderStatusPaid,
			}, nil
		},
		transitionFn: func(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
			t.Fatalf("expected transition not to be called")
			return services.Order{}, nil
		},
	}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, nil)

	body := `{"target_status":"in_production","expected_status":"in_production"}`
	req := httptest.NewRequest(http.MethodPut, "/orders/ord_300:status", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_300")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "staff", Roles: []string{auth.RoleStaff}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.updateOrderStatus(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", rec.Code)
	}
}

func TestAdminOrderHandlers_UpdateOrderStatus_ServiceConflict(t *testing.T) {
	service := &stubOrderService{
		getFn: func(ctx context.Context, orderID string, opts services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:     orderID,
				Status: domain.OrderStatusShipped,
			}, nil
		},
		transitionFn: func(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
			return services.Order{}, services.ErrOrderConflict
		},
	}
	handler := NewAdminOrderHandlers(nil, service, nil, nil, nil)

	body := `{"target_status":"delivered"}`
	req := httptest.NewRequest(http.MethodPut, "/orders/ord_400:status", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_400")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "ops", Roles: []string{auth.RoleAdmin}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.updateOrderStatus(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", rec.Code)
	}
}

func TestAdminOrderHandlers_ManualCapturePayment_Success(t *testing.T) {
	now := time.Date(2024, 4, 10, 15, 30, 0, 0, time.UTC)
	captureAt := now.Add(-2 * time.Minute)

	var capturedCmd services.PaymentManualCaptureCommand
	paymentSvc := &stubPaymentService{
		captureFn: func(ctx context.Context, cmd services.PaymentManualCaptureCommand) (services.Payment, error) {
			capturedCmd = cmd
			return services.Payment{
				ID:         "pay_123",
				OrderID:    "ord_900",
				Provider:   "stripe",
				IntentID:   "pi_abc",
				Status:     "succeeded",
				Amount:     1500,
				Currency:   "jpy",
				Captured:   true,
				CapturedAt: &captureAt,
				CreatedAt:  now.Add(-10 * time.Minute),
				UpdatedAt:  now,
			}, nil
		},
	}

	orderSvc := &stubOrderService{
		getFn: func(ctx context.Context, orderID string, opts services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID: orderID,
				Metadata: map[string]any{
					"payment": map[string]any{
						"status":         "succeeded",
						"capturedAmount": 1500,
						"refundedAmount": 0,
						"balanceDue":     500,
						"updatedAt":      now,
					},
				},
			}, nil
		},
	}

	handler := NewAdminOrderHandlers(nil, orderSvc, nil, paymentSvc, nil)

	body := `{"payment_id":" pay_123 ","amount":1500,"reason":" partial ","idempotency_key":" key-1 ","metadata":{"note":" expedite "}}`
	req := httptest.NewRequest(http.MethodPost, "/orders/ord_900/payments:manual-capture", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_900")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "staff-1", Roles: []string{auth.RoleStaff}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.manualCapturePayment(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var resp struct {
		Payment struct {
			ID            string `json:"id"`
			Provider      string `json:"provider"`
			Currency      string `json:"currency"`
			Captured      bool   `json:"captured"`
			CapturedAt    string `json:"captured_at"`
			TransactionID string `json:"transaction_id"`
		} `json:"payment"`
		PaymentSummary struct {
			Status         string `json:"status"`
			CapturedAmount int64  `json:"captured_amount"`
			BalanceDue     int64  `json:"balance_due"`
			UpdatedAt      string `json:"updated_at"`
		} `json:"payment_summary"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.Payment.ID != "pay_123" {
		t.Fatalf("expected payment id pay_123, got %q", resp.Payment.ID)
	}
	if resp.Payment.Provider != "stripe" {
		t.Fatalf("expected provider stripe, got %q", resp.Payment.Provider)
	}
	if resp.Payment.Currency != "JPY" {
		t.Fatalf("expected currency JPY, got %q", resp.Payment.Currency)
	}
	if !resp.Payment.Captured {
		t.Fatalf("expected captured true")
	}
	if resp.Payment.TransactionID != "pi_abc" {
		t.Fatalf("expected transaction id pi_abc, got %q", resp.Payment.TransactionID)
	}
	if resp.Payment.CapturedAt == "" {
		t.Fatalf("expected captured_at to be populated")
	}

	if resp.PaymentSummary.Status != "succeeded" {
		t.Fatalf("expected summary status succeeded, got %q", resp.PaymentSummary.Status)
	}
	if resp.PaymentSummary.CapturedAmount != 1500 {
		t.Fatalf("expected captured amount 1500, got %d", resp.PaymentSummary.CapturedAmount)
	}
	if resp.PaymentSummary.BalanceDue != 500 {
		t.Fatalf("expected balance due 500, got %d", resp.PaymentSummary.BalanceDue)
	}
	if resp.PaymentSummary.UpdatedAt == "" {
		t.Fatalf("expected updatedAt string")
	}

	if capturedCmd.OrderID != "ord_900" {
		t.Fatalf("expected command order ord_900, got %q", capturedCmd.OrderID)
	}
	if capturedCmd.PaymentID != "pay_123" {
		t.Fatalf("expected command payment id pay_123, got %q", capturedCmd.PaymentID)
	}
	if capturedCmd.Amount == nil || *capturedCmd.Amount != 1500 {
		t.Fatalf("expected command amount 1500, got %#v", capturedCmd.Amount)
	}
	if capturedCmd.Reason != "partial" {
		t.Fatalf("expected trimmed reason partial, got %q", capturedCmd.Reason)
	}
	if capturedCmd.IdempotencyKey != "key-1" {
		t.Fatalf("expected idempotency key key-1, got %q", capturedCmd.IdempotencyKey)
	}
	if capturedCmd.Metadata == nil || capturedCmd.Metadata["note"] != "expedite" {
		t.Fatalf("expected sanitized metadata, got %#v", capturedCmd.Metadata)
	}
	if capturedCmd.ActorID != "staff-1" {
		t.Fatalf("expected actor id staff-1, got %q", capturedCmd.ActorID)
	}
}

func TestAdminOrderHandlers_ManualRefundPayment_ServiceError(t *testing.T) {
	paymentSvc := &stubPaymentService{
		refundFn: func(ctx context.Context, cmd services.PaymentManualRefundCommand) (services.Payment, error) {
			if cmd.PaymentID != "pay_777" {
				t.Fatalf("expected payment id pay_777, got %q", cmd.PaymentID)
			}
			return services.Payment{}, services.ErrPaymentInvalidState
		},
	}

	handler := NewAdminOrderHandlers(nil, &stubOrderService{}, nil, paymentSvc, nil)

	body := `{"payment_id":"pay_777"}`
	req := httptest.NewRequest(http.MethodPost, "/orders/ord_777/payments:refund", strings.NewReader(body))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("orderID", "ord_777")
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx)
	ctx = auth.WithIdentity(ctx, &auth.Identity{UID: "admin-1", Roles: []string{auth.RoleAdmin}})
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()

	handler.manualRefundPayment(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", rec.Code)
	}
}

type captureAuditLogService struct {
	records []services.AuditLogRecord
}

func (c *captureAuditLogService) Record(_ context.Context, record services.AuditLogRecord) {
	c.records = append(c.records, record)
}

func (c *captureAuditLogService) List(context.Context, services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	return domain.CursorPage[domain.AuditLogEntry]{}, nil
}

type stubPaymentService struct {
	webhookFn func(context.Context, services.PaymentWebhookCommand) error
	captureFn func(context.Context, services.PaymentManualCaptureCommand) (services.Payment, error)
	refundFn  func(context.Context, services.PaymentManualRefundCommand) (services.Payment, error)
	listFn    func(context.Context, string) ([]services.Payment, error)
}

func (s *stubPaymentService) RecordWebhookEvent(ctx context.Context, cmd services.PaymentWebhookCommand) error {
	if s.webhookFn != nil {
		return s.webhookFn(ctx, cmd)
	}
	return errors.New("not implemented")
}

func (s *stubPaymentService) ManualCapture(ctx context.Context, cmd services.PaymentManualCaptureCommand) (services.Payment, error) {
	if s.captureFn != nil {
		return s.captureFn(ctx, cmd)
	}
	return services.Payment{}, errors.New("not implemented")
}

func (s *stubPaymentService) ManualRefund(ctx context.Context, cmd services.PaymentManualRefundCommand) (services.Payment, error) {
	if s.refundFn != nil {
		return s.refundFn(ctx, cmd)
	}
	return services.Payment{}, errors.New("not implemented")
}

func (s *stubPaymentService) ListPayments(ctx context.Context, orderID string) ([]services.Payment, error) {
	if s.listFn != nil {
		return s.listFn(ctx, orderID)
	}
	return nil, nil
}

type stubShipmentService struct {
	captured *services.CreateShipmentCommand
	createFn func(context.Context, services.CreateShipmentCommand) (services.Shipment, error)
	err      error
}

func (s *stubShipmentService) CreateShipment(ctx context.Context, cmd services.CreateShipmentCommand) (services.Shipment, error) {
	cloned := cmd
	s.captured = &cloned
	if s.err != nil {
		return services.Shipment{}, s.err
	}
	if s.createFn != nil {
		return s.createFn(ctx, cmd)
	}
	return services.Shipment{}, nil
}

func (s *stubShipmentService) UpdateShipmentStatus(context.Context, services.UpdateShipmentCommand) (services.Shipment, error) {
	return services.Shipment{}, nil
}

func (s *stubShipmentService) ListShipments(context.Context, string) ([]services.Shipment, error) {
	return nil, nil
}

func (s *stubShipmentService) RecordCarrierEvent(context.Context, services.ShipmentEventCommand) error {
	return nil
}
