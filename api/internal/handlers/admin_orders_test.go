package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

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
	handler := NewAdminOrderHandlers(nil, service)

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
	handler := NewAdminOrderHandlers(nil, service)

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
	handler := NewAdminOrderHandlers(nil, service)

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
