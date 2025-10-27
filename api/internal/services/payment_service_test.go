package services

import (
	"context"
	"errors"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/payments"
	"github.com/hanko-field/api/internal/repositories"
)

func TestPaymentServiceManualCaptureSuccess(t *testing.T) {
	t.Helper()

	now := time.Date(2024, 9, 1, 10, 0, 0, 0, time.UTC)
	captureAt := now.Add(-2 * time.Minute)

	order := domain.Order{
		ID:       "ord_1",
		Status:   domain.OrderStatusPendingPayment,
		Currency: "JPY",
		Totals: domain.OrderTotals{
			Total: 10000,
		},
		CreatedAt: now.Add(-1 * time.Hour),
	}

	orderRepo := &paymentTestOrderRepo{
		orders: map[string]domain.Order{
			"ord_1": order,
		},
	}

	paymentRepo := &stubPaymentRepo{
		payments: map[string]domain.Payment{
			"pay_1": {
				ID:        "pay_1",
				OrderID:   "ord_1",
				Provider:  "stripe",
				IntentID:  "pi_123",
				Status:    "requires_capture",
				Amount:    10000,
				Currency:  "JPY",
				Captured:  false,
				CreatedAt: now.Add(-30 * time.Minute),
			},
		},
	}

	processor := &stubPaymentProcessor{
		captureFn: func(ctx context.Context, paymentCtx payments.PaymentContext, req payments.CaptureRequest) (payments.PaymentDetails, error) {
			if paymentCtx.PreferredProvider != "stripe" {
				t.Fatalf("unexpected provider %s", paymentCtx.PreferredProvider)
			}
			if paymentCtx.Metadata["actor_id"] != "staff_9" {
				t.Fatalf("expected actor metadata staff_9, got %s", paymentCtx.Metadata["actor_id"])
			}
			if req.IntentID != "pi_123" {
				t.Fatalf("unexpected intent id %s", req.IntentID)
			}
			if req.IdempotencyKey == "" {
				t.Fatalf("expected idempotency key")
			}
			return payments.PaymentDetails{
				Provider:   "stripe",
				IntentID:   "pi_123",
				Status:     payments.StatusSucceeded,
				Amount:     10000,
				Currency:   "JPY",
				Captured:   true,
				CapturedAt: &captureAt,
				Raw: map[string]any{
					"amount_received": float64(10000),
				},
			}, nil
		},
	}

	audit := &stubAuditRecorder{}

	svc, err := NewPaymentService(PaymentServiceDeps{
		Orders:     orderRepo,
		Payments:   paymentRepo,
		Processor:  processor,
		UnitOfWork: paymentTestUnitOfWork{},
		Audit:      audit,
		Clock: func() time.Time {
			return now
		},
	})
	if err != nil {
		t.Fatalf("failed to construct service: %v", err)
	}

	result, err := svc.ManualCapture(context.Background(), PaymentManualCaptureCommand{
		OrderID:   "ord_1",
		PaymentID: "pay_1",
		ActorID:   "staff_9",
	})
	if err != nil {
		t.Fatalf("manual capture failed: %v", err)
	}

	if !result.Captured {
		t.Fatalf("expected payment captured")
	}
	if result.Status != string(payments.StatusSucceeded) {
		t.Fatalf("expected status succeeded, got %s", result.Status)
	}
	if result.CapturedAt == nil || !result.CapturedAt.Equal(captureAt) {
		t.Fatalf("expected capturedAt %s, got %v", captureAt, result.CapturedAt)
	}

	if len(paymentRepo.updates) != 1 {
		t.Fatalf("expected payment update recorded")
	}
	if paymentRepo.updates[0].CapturedAt == nil {
		t.Fatalf("expected capturedAt stored on update")
	}
	if paymentRepo.updates[0].UpdatedAt != now {
		t.Fatalf("expected updatedAt to equal clock value")
	}

	updatedOrder, ok := orderRepo.orders["ord_1"]
	if !ok {
		t.Fatalf("order not persisted")
	}
	if updatedOrder.Status != domain.OrderStatusPaid {
		t.Fatalf("expected order status paid, got %s", updatedOrder.Status)
	}
	if updatedOrder.PaidAt == nil || !updatedOrder.PaidAt.Equal(now) {
		t.Fatalf("expected paidAt to be set to now")
	}

	summary := extractPaymentSummary(t, updatedOrder.Metadata)
	if summary["capturedAmount"] != int64(10000) {
		t.Fatalf("expected capturedAmount 10000, got %v", summary["capturedAmount"])
	}
	if summary["balanceDue"] != int64(0) {
		t.Fatalf("expected balanceDue 0, got %v", summary["balanceDue"])
	}
	if summary["status"] != string(payments.StatusSucceeded) {
		t.Fatalf("expected status metadata succeeded, got %v", summary["status"])
	}

	if len(audit.records) != 1 {
		t.Fatalf("expected audit record, got %d", len(audit.records))
	}
	if audit.records[0].Action != "payments.manual_capture" {
		t.Fatalf("unexpected audit action %s", audit.records[0].Action)
	}
	if audit.records[0].Metadata["status"] != string(payments.StatusSucceeded) {
		t.Fatalf("expected audit metadata status succeeded, got %v", audit.records[0].Metadata["status"])
	}
}

func TestPaymentServiceManualRefundPartial(t *testing.T) {
	t.Helper()

	now := time.Date(2024, 9, 1, 11, 0, 0, 0, time.UTC)
	refundAt := now.Add(-5 * time.Minute)

	orderRepo := &paymentTestOrderRepo{
		orders: map[string]domain.Order{
			"ord_2": {
				ID:       "ord_2",
				Status:   domain.OrderStatusPendingPayment,
				Currency: "JPY",
				Totals: domain.OrderTotals{
					Total: 10000,
				},
				CreatedAt: now.Add(-2 * time.Hour),
			},
		},
	}

	paymentRepo := &stubPaymentRepo{
		payments: map[string]domain.Payment{
			"pay_9": {
				ID:       "pay_9",
				OrderID:  "ord_2",
				Provider: "stripe",
				IntentID: "pi_999",
				Status:   string(payments.StatusSucceeded),
				Amount:   10000,
				Currency: "JPY",
				Captured: true,
				CapturedAt: func() *time.Time {
					ts := now.Add(-30 * time.Minute)
					return &ts
				}(),
				CreatedAt: now.Add(-40 * time.Minute),
				Raw: map[string]any{
					"amount_received": float64(10000),
				},
			},
		},
	}

	processor := &stubPaymentProcessor{
		refundFn: func(ctx context.Context, paymentCtx payments.PaymentContext, req payments.RefundRequest) (payments.PaymentDetails, error) {
			if req.Amount == nil || *req.Amount != 4000 {
				t.Fatalf("expected refund amount 4000, got %v", req.Amount)
			}
			return payments.PaymentDetails{
				Provider:   "stripe",
				IntentID:   "pi_999",
				Status:     payments.StatusRefunded,
				Amount:     10000,
				Currency:   "JPY",
				Captured:   true,
				RefundedAt: &refundAt,
				Raw: map[string]any{
					"amount_received": float64(10000),
					"amount_refunded": float64(4000),
				},
			}, nil
		},
	}

	audit := &stubAuditRecorder{}

	amount := int64(4000)
	svc, err := NewPaymentService(PaymentServiceDeps{
		Orders:     orderRepo,
		Payments:   paymentRepo,
		Processor:  processor,
		UnitOfWork: paymentTestUnitOfWork{},
		Audit:      audit,
		Clock: func() time.Time {
			return now
		},
	})
	if err != nil {
		t.Fatalf("failed to construct service: %v", err)
	}

	result, err := svc.ManualRefund(context.Background(), PaymentManualRefundCommand{
		OrderID:   "ord_2",
		PaymentID: "pay_9",
		ActorID:   "staff_x",
		Amount:    &amount,
		Reason:    "damaged",
	})
	if err != nil {
		t.Fatalf("manual refund failed: %v", err)
	}

	if result.Status != string(payments.StatusRefunded) {
		t.Fatalf("expected refunded status, got %s", result.Status)
	}
	if result.RefundedAt == nil || !result.RefundedAt.Equal(refundAt) {
		t.Fatalf("expected refundedAt %s", refundAt)
	}

	summary := extractPaymentSummary(t, orderRepo.orders["ord_2"].Metadata)
	if summary["refundedAmount"] != int64(4000) {
		t.Fatalf("expected refundedAmount 4000, got %v", summary["refundedAmount"])
	}
	if summary["balanceDue"] != int64(4000) {
		t.Fatalf("expected balanceDue 4000, got %v", summary["balanceDue"])
	}

	if len(audit.records) != 1 {
		t.Fatalf("expected audit record")
	}
	if audit.records[0].Action != "payments.manual_refund" {
		t.Fatalf("expected audit action manual_refund, got %s", audit.records[0].Action)
	}
	if audit.records[0].Metadata["amount"] != int64(4000) {
		t.Fatalf("expected audit metadata amount 4000, got %v", audit.records[0].Metadata["amount"])
	}
}

// --- Test helpers -----------------------------------------------------------------

type paymentTestOrderRepo struct {
	orders  map[string]domain.Order
	updates []domain.Order
}

func (s *paymentTestOrderRepo) Insert(context.Context, domain.Order) error {
	return errors.New("not implemented")
}

func (s *paymentTestOrderRepo) Update(_ context.Context, order domain.Order) error {
	if s.orders == nil {
		s.orders = make(map[string]domain.Order)
	}
	s.orders[order.ID] = copyOrder(order)
	s.updates = append(s.updates, copyOrder(order))
	return nil
}

func (s *paymentTestOrderRepo) FindByID(_ context.Context, orderID string) (domain.Order, error) {
	if s.orders == nil {
		return domain.Order{}, paymentTestRepoErr{notFound: true}
	}
	order, ok := s.orders[orderID]
	if !ok {
		return domain.Order{}, paymentTestRepoErr{notFound: true}
	}
	return copyOrder(order), nil
}

func (s *paymentTestOrderRepo) List(context.Context, repositories.OrderListFilter) (domain.CursorPage[domain.Order], error) {
	return domain.CursorPage[domain.Order]{}, errors.New("not implemented")
}

type stubPaymentRepo struct {
	payments map[string]domain.Payment
	updates  []domain.Payment
}

func (s *stubPaymentRepo) Insert(context.Context, domain.Payment) error {
	return errors.New("not implemented")
}

func (s *stubPaymentRepo) Update(_ context.Context, payment domain.Payment) error {
	if s.payments == nil {
		s.payments = make(map[string]domain.Payment)
	}
	s.payments[payment.ID] = copyPayment(payment)
	s.updates = append(s.updates, copyPayment(payment))
	return nil
}

func (s *stubPaymentRepo) List(_ context.Context, orderID string) ([]domain.Payment, error) {
	if len(s.payments) == 0 {
		return nil, nil
	}
	var out []domain.Payment
	for _, payment := range s.payments {
		if payment.OrderID == orderID {
			out = append(out, copyPayment(payment))
		}
	}
	return out, nil
}

type stubPaymentProcessor struct {
	captureFn func(ctx context.Context, paymentCtx payments.PaymentContext, req payments.CaptureRequest) (payments.PaymentDetails, error)
	refundFn  func(ctx context.Context, paymentCtx payments.PaymentContext, req payments.RefundRequest) (payments.PaymentDetails, error)
}

func (s *stubPaymentProcessor) Capture(ctx context.Context, paymentCtx payments.PaymentContext, req payments.CaptureRequest) (payments.PaymentDetails, error) {
	if s.captureFn == nil {
		return payments.PaymentDetails{}, errors.New("capture not implemented")
	}
	return s.captureFn(ctx, paymentCtx, req)
}

func (s *stubPaymentProcessor) Refund(ctx context.Context, paymentCtx payments.PaymentContext, req payments.RefundRequest) (payments.PaymentDetails, error) {
	if s.refundFn == nil {
		return payments.PaymentDetails{}, errors.New("refund not implemented")
	}
	return s.refundFn(ctx, paymentCtx, req)
}

type paymentTestUnitOfWork struct{}

func (paymentTestUnitOfWork) RunInTx(ctx context.Context, fn func(ctx context.Context) error) error {
	return fn(ctx)
}

type stubAuditRecorder struct {
	records []AuditLogRecord
}

func (s *stubAuditRecorder) Record(ctx context.Context, record AuditLogRecord) {
	s.records = append(s.records, record)
}

func (s *stubAuditRecorder) List(context.Context, AuditLogFilter) (domain.CursorPage[AuditLogEntry], error) {
	return domain.CursorPage[AuditLogEntry]{}, errors.New("not implemented")
}

type paymentTestRepoErr struct {
	notFound bool
}

func (e paymentTestRepoErr) Error() string {
	return "not found"
}

func (e paymentTestRepoErr) IsNotFound() bool {
	return e.notFound
}

func (paymentTestRepoErr) IsConflict() bool {
	return false
}

func (paymentTestRepoErr) IsUnavailable() bool {
	return false
}

func copyOrder(o domain.Order) domain.Order {
	cp := o
	if o.PaidAt != nil {
		ts := *o.PaidAt
		cp.PaidAt = &ts
	}
	if len(o.Metadata) > 0 {
		cp.Metadata = make(map[string]any, len(o.Metadata))
		for k, v := range o.Metadata {
			cp.Metadata[k] = v
		}
	}
	return cp
}

func copyPayment(p domain.Payment) domain.Payment {
	cp := p
	if p.CapturedAt != nil {
		ts := *p.CapturedAt
		cp.CapturedAt = &ts
	}
	if p.RefundedAt != nil {
		ts := *p.RefundedAt
		cp.RefundedAt = &ts
	}
	if len(p.Raw) > 0 {
		cp.Raw = make(map[string]any, len(p.Raw))
		for k, v := range p.Raw {
			cp.Raw[k] = v
		}
	}
	return cp
}

func extractPaymentSummary(t *testing.T, metadata map[string]any) map[string]any {
	t.Helper()
	if metadata == nil {
		t.Fatalf("metadata not set")
	}
	value, ok := metadata["payment"]
	if !ok {
		t.Fatalf("payment summary missing")
	}
	summary, ok := value.(map[string]any)
	if !ok {
		t.Fatalf("payment summary wrong type: %T", value)
	}
	return summary
}
