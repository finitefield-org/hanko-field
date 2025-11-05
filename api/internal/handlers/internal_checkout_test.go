package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/services"
)

func TestInternalCheckoutCommit_Success(t *testing.T) {
	var (
		commitCount int
		capturedCmd services.OrderStatusTransitionCommand
	)

	inventory := &stubCheckoutInventoryService{
		commitFn: func(ctx context.Context, cmd services.InventoryCommitCommand) (services.InventoryReservation, error) {
			commitCount++
			if cmd.ReservationID != "res-123" {
				t.Fatalf("expected reservation res-123 got %s", cmd.ReservationID)
			}
			return services.InventoryReservation{
				ID:     cmd.ReservationID,
				Status: "committed",
			}, nil
		},
		getFn: func(ctx context.Context, reservationID string) (services.InventoryReservation, error) {
			return services.InventoryReservation{
				ID:     reservationID,
				Status: "committed",
			}, nil
		},
	}

	orderCreatedAt := time.Now().Add(-1 * time.Hour).UTC()
	orderService := &stubCheckoutOrderService{
		getFn: func(ctx context.Context, orderID string, _ services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:        orderID,
				Status:    domain.OrderStatusPendingPayment,
				CreatedAt: orderCreatedAt,
				Metadata: map[string]any{
					"reservationId": "res-123",
				},
			}, nil
		},
		transitionFn: func(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
			capturedCmd = cmd
			if cmd.ExpectedStatus == nil || *cmd.ExpectedStatus != services.OrderStatus(domain.OrderStatusPendingPayment) {
				t.Fatalf("expected expectedStatus pending_payment got %#v", cmd.ExpectedStatus)
			}
			if cmd.Metadata["reservationId"] != "res-123" {
				t.Fatalf("expected reservationId metadata, got %#v", cmd.Metadata)
			}
			if cmd.Metadata["paymentIntentId"] != "pi_456" {
				t.Fatalf("expected payment intent metadata, got %#v", cmd.Metadata["paymentIntentId"])
			}
			now := time.Now().UTC()
			return services.Order{
				ID:     cmd.OrderID,
				Status: domain.OrderStatusPaid,
				Metadata: map[string]any{
					"reservationId": "res-123",
				},
				PaidAt: &now,
			}, nil
		},
	}

	handler := NewInternalCheckoutHandlers(
		inventory,
		WithInternalCheckoutOrders(orderService),
	)

	body := map[string]string{
		"orderId":         "ord_123",
		"actorId":         "svc-1",
		"paymentIntentId": "pi_456",
	}
	payload, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/internal/checkout/commit", bytes.NewReader(payload))
	rec := httptest.NewRecorder()

	handler.commitCheckout(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200 got %d: %s", rec.Code, rec.Body.String())
	}
	if commitCount != 1 {
		t.Fatalf("expected commit called once got %d", commitCount)
	}

	var resp internalCheckoutCommitResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.OrderStatus != string(domain.OrderStatusPaid) {
		t.Fatalf("expected order status paid got %s", resp.OrderStatus)
	}
	if resp.ReservationStatus != "committed" {
		t.Fatalf("expected reservation status committed got %s", resp.ReservationStatus)
	}
	if resp.PaidAt == "" {
		t.Fatalf("expected paidAt timestamp")
	}
	if capturedCmd.TargetStatus != domain.OrderStatusPaid {
		t.Fatalf("expected transition to paid got %s", capturedCmd.TargetStatus)
	}
}

func TestInternalCheckoutCommit_IdempotentWhenPaid(t *testing.T) {
	inventory := &stubCheckoutInventoryService{
		getFn: func(ctx context.Context, reservationID string) (services.InventoryReservation, error) {
			return services.InventoryReservation{
				ID:     reservationID,
				Status: "committed",
			}, nil
		},
		commitFn: func(context.Context, services.InventoryCommitCommand) (services.InventoryReservation, error) {
			t.Fatalf("commit should not be invoked for already paid order")
			return services.InventoryReservation{}, nil
		},
	}

	orderService := &stubCheckoutOrderService{
		getFn: func(ctx context.Context, orderID string, _ services.OrderReadOptions) (services.Order, error) {
			now := time.Now().UTC()
			return services.Order{
				ID:     orderID,
				Status: domain.OrderStatusPaid,
				Metadata: map[string]any{
					"reservationId": "res-789",
				},
				PaidAt: &now,
			}, nil
		},
	}

	handler := NewInternalCheckoutHandlers(
		inventory,
		WithInternalCheckoutOrders(orderService),
	)

	req := httptest.NewRequest(http.MethodPost, "/internal/checkout/commit", strings.NewReader(`{"orderId":"ord_paid"}`))
	rec := httptest.NewRecorder()

	handler.commitCheckout(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 got %d", rec.Code)
	}

	var resp internalCheckoutCommitResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Message == "" {
		t.Fatalf("expected informational message in response")
	}
}

func TestInternalCheckoutCommit_UsesExistingCommitOnInvalidState(t *testing.T) {
	var commitCount int
	var transitionInvoked bool

	inventory := &stubCheckoutInventoryService{
		commitFn: func(ctx context.Context, cmd services.InventoryCommitCommand) (services.InventoryReservation, error) {
			commitCount++
			return services.InventoryReservation{}, services.ErrInventoryInvalidState
		},
		getFn: func(ctx context.Context, reservationID string) (services.InventoryReservation, error) {
			return services.InventoryReservation{
				ID:     reservationID,
				Status: "committed",
			}, nil
		},
	}

	orderService := &stubCheckoutOrderService{
		getFn: func(ctx context.Context, orderID string, _ services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:     orderID,
				Status: domain.OrderStatusPendingPayment,
				Metadata: map[string]any{
					"reservationId": "res-commit",
				},
			}, nil
		},
		transitionFn: func(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
			transitionInvoked = true
			return services.Order{
				ID:     cmd.OrderID,
				Status: domain.OrderStatusPaid,
				Metadata: map[string]any{
					"reservationId": "res-commit",
				},
			}, nil
		},
	}

	handler := NewInternalCheckoutHandlers(
		inventory,
		WithInternalCheckoutOrders(orderService),
	)

	req := httptest.NewRequest(http.MethodPost, "/internal/checkout/commit", strings.NewReader(`{"orderId":"ord_pending"}`))
	rec := httptest.NewRecorder()

	handler.commitCheckout(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 got %d: %s", rec.Code, rec.Body.String())
	}
	if commitCount != 1 {
		t.Fatalf("expected commit attempted once got %d", commitCount)
	}
	if !transitionInvoked {
		t.Fatalf("expected order transition to be invoked")
	}
}

func TestInternalCheckoutRelease_Success(t *testing.T) {
	var (
		releaseCmd  services.InventoryReleaseCommand
		recordedCmd services.PromotionUsageReleaseCommand
	)
	releasedAt := time.Now().UTC()
	inventory := &stubCheckoutInventoryService{
		releaseFn: func(_ context.Context, cmd services.InventoryReleaseCommand) (services.InventoryReservation, error) {
			releaseCmd = cmd
			return services.InventoryReservation{
				ID:         "sr_123",
				Status:     "released",
				OrderRef:   "/orders/ord_123",
				UserRef:    "/users/user_1",
				Reason:     cmd.Reason,
				ReleasedAt: &releasedAt,
				Lines: []services.InventoryReservationLine{
					{ProductRef: "/products/p1", SKU: "SKU-1", Quantity: 2},
				},
			}, nil
		},
	}

	var rollbackCalled bool
	promotions := &stubCheckoutPromotionService{
		rollbackFn: func(_ context.Context, cmd services.PromotionUsageReleaseCommand) error {
			rollbackCalled = true
			recordedCmd = cmd
			return nil
		},
	}

	handler := NewInternalCheckoutHandlers(
		inventory,
		WithInternalCheckoutPromotions(promotions),
	)

	req := httptest.NewRequest(http.MethodPost, "/internal/checkout/release", strings.NewReader(`{"reservationId":"sr_123","reason":"checkout_timeout","promotionCode":"spring10","promotionUserId":"user_1"}`))
	rec := httptest.NewRecorder()

	handler.releaseCheckout(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200 got %d: %s", rec.Code, rec.Body.String())
	}

	if releaseCmd.ReservationID != "sr_123" {
		t.Fatalf("expected reservation sr_123 got %s", releaseCmd.ReservationID)
	}
	if releaseCmd.Reason != "checkout_timeout" {
		t.Fatalf("expected reason checkout_timeout got %s", releaseCmd.Reason)
	}

	var resp internalCheckoutReleaseResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.ReservationID != "sr_123" {
		t.Fatalf("expected reservationId sr_123 got %s", resp.ReservationID)
	}
	if resp.Status != "released" {
		t.Fatalf("expected status released got %s", resp.Status)
	}
	if resp.Reason != "checkout_timeout" {
		t.Fatalf("expected response reason checkout_timeout got %s", resp.Reason)
	}
	if resp.ReleasedAt == "" {
		t.Fatalf("expected releasedAt timestamp")
	}
	if len(resp.Lines) != 1 || resp.Lines[0].SKU != "SKU-1" {
		t.Fatalf("expected reservation lines in response, got %+v", resp.Lines)
	}

	if !rollbackCalled {
		t.Fatalf("expected promotion rollback to be invoked")
	}
	if recordedCmd.Code != "SPRING10" {
		t.Fatalf("expected rollback code SPRING10 got %s", recordedCmd.Code)
	}
	if recordedCmd.UserID != "user_1" {
		t.Fatalf("expected rollback user user_1 got %s", recordedCmd.UserID)
	}
	if recordedCmd.OrderRef != "/orders/ord_123" {
		t.Fatalf("expected rollback orderRef /orders/ord_123 got %s", recordedCmd.OrderRef)
	}
	if recordedCmd.Reason != "checkout_timeout" {
		t.Fatalf("expected rollback reason checkout_timeout got %s", recordedCmd.Reason)
	}
}

func TestInternalCheckoutRelease_Idempotent(t *testing.T) {
	inventory := &stubCheckoutInventoryService{
		releaseFn: func(context.Context, services.InventoryReleaseCommand) (services.InventoryReservation, error) {
			return services.InventoryReservation{}, services.ErrInventoryInvalidState
		},
		getFn: func(context.Context, string) (services.InventoryReservation, error) {
			return services.InventoryReservation{
				ID:       "sr_789",
				Status:   "released",
				OrderRef: "/orders/ord_789",
				UserRef:  "/users/u789",
				Reason:   "checkout_payment_failed",
			}, nil
		},
	}

	var (
		rollbackCalled bool
		recordedCmd    services.PromotionUsageReleaseCommand
	)
	promotions := &stubCheckoutPromotionService{
		rollbackFn: func(_ context.Context, cmd services.PromotionUsageReleaseCommand) error {
			rollbackCalled = true
			recordedCmd = cmd
			return nil
		},
	}

	handler := NewInternalCheckoutHandlers(
		inventory,
		WithInternalCheckoutPromotions(promotions),
	)

	req := httptest.NewRequest(http.MethodPost, "/internal/checkout/release", strings.NewReader(`{"reservationId":"sr_789","promotionCode":"winter5","promotionUserId":"u789"}`))
	rec := httptest.NewRecorder()

	handler.releaseCheckout(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200 got %d: %s", rec.Code, rec.Body.String())
	}

	var resp internalCheckoutReleaseResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Message == "" {
		t.Fatalf("expected response message for idempotent release")
	}
	if resp.Status != "released" {
		t.Fatalf("expected reservation status released got %s", resp.Status)
	}

	if !rollbackCalled {
		t.Fatalf("expected promotion rollback on idempotent release")
	}
	if recordedCmd.Code != "WINTER5" {
		t.Fatalf("expected rollback code WINTER5 got %s", recordedCmd.Code)
	}
	if recordedCmd.UserID != "u789" {
		t.Fatalf("expected rollback user u789 got %s", recordedCmd.UserID)
	}
	if recordedCmd.OrderRef != "/orders/ord_789" {
		t.Fatalf("expected rollback orderRef /orders/ord_789 got %s", recordedCmd.OrderRef)
	}
}

func TestInternalCheckoutRelease_OrderLookup(t *testing.T) {
	var (
		releaseCmd services.InventoryReleaseCommand
		recorded   services.PromotionUsageReleaseCommand
	)
	inventory := &stubCheckoutInventoryService{
		releaseFn: func(_ context.Context, cmd services.InventoryReleaseCommand) (services.InventoryReservation, error) {
			releaseCmd = cmd
			return services.InventoryReservation{
				ID:       "sr_from_order",
				Status:   "released",
				OrderRef: "/orders/ord_lookup",
				UserRef:  "/users/order_user",
			}, nil
		},
	}

	orderService := &stubCheckoutOrderService{
		getFn: func(context.Context, string, services.OrderReadOptions) (services.Order, error) {
			return services.Order{
				ID:     "ord_lookup",
				UserID: "order_user",
				Metadata: map[string]any{
					"reservationId": "sr_from_order",
				},
				Promotion: &services.CartPromotion{Code: "spring20", Applied: true},
			}, nil
		},
	}

	promotions := &stubCheckoutPromotionService{
		rollbackFn: func(_ context.Context, cmd services.PromotionUsageReleaseCommand) error {
			recorded = cmd
			return nil
		},
	}

	handler := NewInternalCheckoutHandlers(
		inventory,
		WithInternalCheckoutOrders(orderService),
		WithInternalCheckoutPromotions(promotions),
	)

	req := httptest.NewRequest(http.MethodPost, "/internal/checkout/release", strings.NewReader(`{"orderId":"ord_lookup"}`))
	rec := httptest.NewRecorder()

	handler.releaseCheckout(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200 got %d: %s", rec.Code, rec.Body.String())
	}

	if releaseCmd.ReservationID != "sr_from_order" {
		t.Fatalf("expected reservation id from order metadata got %s", releaseCmd.ReservationID)
	}

	var resp internalCheckoutReleaseResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.ReservationID != "sr_from_order" {
		t.Fatalf("expected response reservationId sr_from_order got %s", resp.ReservationID)
	}
	if resp.PromotionCode != "spring20" {
		t.Fatalf("expected response promotion code spring20 got %s", resp.PromotionCode)
	}

	if recorded.Code != "SPRING20" {
		t.Fatalf("expected rollback code SPRING20 got %s", recorded.Code)
	}
	if recorded.UserID != "order_user" {
		t.Fatalf("expected rollback user order_user got %s", recorded.UserID)
	}
	if recorded.OrderRef != "/orders/ord_lookup" {
		t.Fatalf("expected rollback orderRef /orders/ord_lookup got %s", recorded.OrderRef)
	}
}

type stubCheckoutInventoryService struct {
	commitFn  func(context.Context, services.InventoryCommitCommand) (services.InventoryReservation, error)
	getFn     func(context.Context, string) (services.InventoryReservation, error)
	releaseFn func(context.Context, services.InventoryReleaseCommand) (services.InventoryReservation, error)
}

func (s *stubCheckoutInventoryService) ReserveStocks(context.Context, services.InventoryReserveCommand) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubCheckoutInventoryService) CommitReservation(ctx context.Context, cmd services.InventoryCommitCommand) (services.InventoryReservation, error) {
	if s.commitFn != nil {
		return s.commitFn(ctx, cmd)
	}
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubCheckoutInventoryService) GetReservation(ctx context.Context, reservationID string) (services.InventoryReservation, error) {
	if s.getFn != nil {
		return s.getFn(ctx, reservationID)
	}
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubCheckoutInventoryService) ReleaseReservation(ctx context.Context, cmd services.InventoryReleaseCommand) (services.InventoryReservation, error) {
	if s.releaseFn != nil {
		return s.releaseFn(ctx, cmd)
	}
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubCheckoutInventoryService) ReleaseExpiredReservations(context.Context, services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error) {
	return services.InventoryReleaseExpiredResult{}, errors.New("not implemented")
}

func (s *stubCheckoutInventoryService) ListLowStock(context.Context, services.InventoryLowStockFilter) (domain.CursorPage[services.InventorySnapshot], error) {
	return domain.CursorPage[services.InventorySnapshot]{}, errors.New("not implemented")
}

func (s *stubCheckoutInventoryService) ConfigureSafetyStock(context.Context, services.ConfigureSafetyStockCommand) (services.InventoryStock, error) {
	return services.InventoryStock{}, errors.New("not implemented")
}

type stubCheckoutOrderService struct {
	getFn        func(context.Context, string, services.OrderReadOptions) (services.Order, error)
	transitionFn func(context.Context, services.OrderStatusTransitionCommand) (services.Order, error)
}

func (s *stubCheckoutOrderService) CreateFromCart(context.Context, services.CreateOrderFromCartCommand) (services.Order, error) {
	return services.Order{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) ListOrders(context.Context, services.OrderListFilter) (domain.CursorPage[services.Order], error) {
	return domain.CursorPage[services.Order]{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) GetOrder(ctx context.Context, orderID string, opts services.OrderReadOptions) (services.Order, error) {
	if s.getFn != nil {
		return s.getFn(ctx, orderID, opts)
	}
	return services.Order{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) TransitionStatus(ctx context.Context, cmd services.OrderStatusTransitionCommand) (services.Order, error) {
	if s.transitionFn != nil {
		return s.transitionFn(ctx, cmd)
	}
	return services.Order{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) Cancel(context.Context, services.CancelOrderCommand) (services.Order, error) {
	return services.Order{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) AppendProductionEvent(context.Context, services.AppendProductionEventCommand) (services.OrderProductionEvent, error) {
	return services.OrderProductionEvent{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) AssignOrderToQueue(context.Context, services.AssignOrderToQueueCommand) (services.Order, error) {
	return services.Order{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) RequestInvoice(context.Context, services.RequestInvoiceCommand) (services.Order, error) {
	return services.Order{}, errors.New("not implemented")
}

func (s *stubCheckoutOrderService) CloneForReorder(context.Context, services.CloneForReorderCommand) (services.Order, error) {
	return services.Order{}, errors.New("not implemented")
}

type stubCheckoutPromotionService struct {
	rollbackFn func(context.Context, services.PromotionUsageReleaseCommand) error
}

func (s *stubCheckoutPromotionService) GetPublicPromotion(context.Context, string) (services.PromotionPublic, error) {
	return services.PromotionPublic{}, errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) ValidatePromotion(context.Context, services.ValidatePromotionCommand) (services.PromotionValidationResult, error) {
	return services.PromotionValidationResult{}, errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) ValidatePromotionDefinition(context.Context, services.Promotion) (services.PromotionDefinitionValidationResult, error) {
	return services.PromotionDefinitionValidationResult{}, errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) ListPromotions(context.Context, services.PromotionListFilter) (domain.CursorPage[services.Promotion], error) {
	return domain.CursorPage[services.Promotion]{}, errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) CreatePromotion(context.Context, services.UpsertPromotionCommand) (services.Promotion, error) {
	return services.Promotion{}, errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) UpdatePromotion(context.Context, services.UpsertPromotionCommand) (services.Promotion, error) {
	return services.Promotion{}, errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) DeletePromotion(context.Context, string, string) error {
	return errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) ListPromotionUsage(context.Context, services.PromotionUsageFilter) (services.PromotionUsagePage, error) {
	return services.PromotionUsagePage{}, errors.New("not implemented")
}

func (s *stubCheckoutPromotionService) RollbackUsage(ctx context.Context, cmd services.PromotionUsageReleaseCommand) error {
	if s.rollbackFn != nil {
		return s.rollbackFn(ctx, cmd)
	}
	return nil
}
