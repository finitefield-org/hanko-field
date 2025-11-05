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

type stubCheckoutInventoryService struct {
	commitFn func(context.Context, services.InventoryCommitCommand) (services.InventoryReservation, error)
	getFn    func(context.Context, string) (services.InventoryReservation, error)
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

func (s *stubCheckoutInventoryService) ReleaseReservation(context.Context, services.InventoryReleaseCommand) (services.InventoryReservation, error) {
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
