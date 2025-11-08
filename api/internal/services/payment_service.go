package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"strconv"
	"strings"
	"time"

	stripe "github.com/stripe/stripe-go/v78"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/payments"
	"github.com/hanko-field/api/internal/repositories"
)

var (
	// ErrPaymentInvalidInput indicates validation failures for manual payment operations.
	ErrPaymentInvalidInput = errors.New("payment: invalid input")
	// ErrPaymentNotFound indicates the requested order or payment record could not be located.
	ErrPaymentNotFound = errors.New("payment: not found")
	// ErrPaymentConflict signals concurrent modifications or repository conflicts.
	ErrPaymentConflict = errors.New("payment: conflict")
	// ErrPaymentInvalidState indicates the payment is not in a state that permits the requested action.
	ErrPaymentInvalidState = errors.New("payment: invalid state")
	// ErrPaymentUnavailable indicates a required repository dependency is not configured.
	ErrPaymentUnavailable = errors.New("payment: unavailable")
)

type paymentProcessor interface {
	Capture(ctx context.Context, paymentCtx payments.PaymentContext, req payments.CaptureRequest) (payments.PaymentDetails, error)
	Refund(ctx context.Context, paymentCtx payments.PaymentContext, req payments.RefundRequest) (payments.PaymentDetails, error)
}

// PaymentServiceDeps bundles the collaborators required to construct a PaymentService.
type PaymentServiceDeps struct {
	Orders     repositories.OrderRepository
	Payments   repositories.OrderPaymentRepository
	Processor  paymentProcessor
	UnitOfWork repositories.UnitOfWork
	Audit      AuditLogService
	Clock      func() time.Time
	Logger     func(ctx context.Context, event string, fields map[string]any)
}

type paymentService struct {
	orders    repositories.OrderRepository
	payments  repositories.OrderPaymentRepository
	processor paymentProcessor
	unit      repositories.UnitOfWork
	audit     AuditLogService
	now       func() time.Time
	logger    func(ctx context.Context, event string, fields map[string]any)
}

// NewPaymentService wires repositories and payment processor into a PaymentService implementation.
func NewPaymentService(deps PaymentServiceDeps) (PaymentService, error) {
	if deps.Orders == nil {
		return nil, errors.New("payment service: order repository is required")
	}
	if deps.Payments == nil {
		return nil, errors.New("payment service: payment repository is required")
	}
	if deps.Processor == nil {
		return nil, errors.New("payment service: payment processor is required")
	}

	unit := deps.UnitOfWork
	if unit == nil {
		unit = noopUnitOfWork{}
	}

	clock := deps.Clock
	if clock == nil {
		clock = time.Now
	}

	logger := deps.Logger
	if logger == nil {
		logger = func(context.Context, string, map[string]any) {}
	}

	return &paymentService{
		orders:    deps.Orders,
		payments:  deps.Payments,
		processor: deps.Processor,
		unit:      unit,
		audit:     deps.Audit,
		now: func() time.Time {
			return clock().UTC()
		},
		logger: logger,
	}, nil
}

// RecordWebhookEvent reconciles PSP webhooks with persisted payments and orders.
func (s *paymentService) RecordWebhookEvent(ctx context.Context, cmd PaymentWebhookCommand) error {
	if s == nil || s.orders == nil || s.payments == nil {
		return ErrPaymentUnavailable
	}

	provider := strings.ToLower(strings.TrimSpace(cmd.Provider))
	if provider == "" {
		return fmt.Errorf("%w: provider is required", ErrPaymentInvalidInput)
	}
	if provider != "stripe" {
		return fmt.Errorf("%w: provider %q not supported", ErrPaymentInvalidInput, cmd.Provider)
	}
	if len(cmd.Payload) == 0 {
		return fmt.Errorf("%w: payload is required", ErrPaymentInvalidInput)
	}

	var event stripe.Event
	if err := json.Unmarshal(cmd.Payload, &event); err != nil {
		return fmt.Errorf("%w: unable to parse stripe event: %v", ErrPaymentInvalidInput, err)
	}

	eventID := strings.TrimSpace(event.ID)
	if eventID == "" {
		return fmt.Errorf("%w: stripe event id missing", ErrPaymentInvalidInput)
	}

	switch event.Type {
	case stripe.EventTypePaymentIntentSucceeded, stripe.EventTypePaymentIntentPaymentFailed:
		if event.Data == nil || len(event.Data.Raw) == 0 {
			return fmt.Errorf("%w: payment intent payload missing", ErrPaymentInvalidInput)
		}
		var intent stripe.PaymentIntent
		if err := json.Unmarshal(event.Data.Raw, &intent); err != nil {
			return fmt.Errorf("%w: decode payment intent: %v", ErrPaymentInvalidInput, err)
		}
		meta := normalizeStripeMetadata(intent.Metadata)
		orderID := meta.lookup("order_id", "orderId", "order")
		if orderID == "" {
			return fmt.Errorf("%w: payment intent missing order reference", ErrPaymentInvalidInput)
		}
		paymentID := meta.lookup("payment_id", "paymentId", "payment")
		return s.handleStripePaymentIntentEvent(ctx, event, intent, orderID, paymentID)
	case stripe.EventTypeChargeRefunded:
		if event.Data == nil || len(event.Data.Raw) == 0 {
			return fmt.Errorf("%w: charge payload missing", ErrPaymentInvalidInput)
		}
		var charge stripe.Charge
		if err := json.Unmarshal(event.Data.Raw, &charge); err != nil {
			return fmt.Errorf("%w: decode charge: %v", ErrPaymentInvalidInput, err)
		}
		meta := normalizeStripeMetadata(charge.Metadata)
		orderID := meta.lookup("order_id", "orderId", "order")
		if orderID == "" {
			return fmt.Errorf("%w: charge missing order reference", ErrPaymentInvalidInput)
		}
		paymentID := meta.lookup("payment_id", "paymentId", "payment")
		intentID := ""
		if charge.PaymentIntent != nil {
			intentID = strings.TrimSpace(charge.PaymentIntent.ID)
		}
		return s.handleStripeChargeRefunded(ctx, event, charge, orderID, paymentID, intentID)
	default:
		s.logger(ctx, "payments.webhook.ignored", map[string]any{
			"provider":  provider,
			"eventId":   eventID,
			"eventType": string(event.Type),
		})
		return nil
	}
}

func (s *paymentService) handleStripePaymentIntentEvent(ctx context.Context, event stripe.Event, intent stripe.PaymentIntent, orderID, paymentID string) error {
	order, payment, err := s.loadOrderPaymentByReference(ctx, orderID, paymentID, intent.ID)
	if err != nil {
		return err
	}

	eventID := strings.TrimSpace(event.ID)
	if isPaymentEventProcessed(payment.Raw, eventID) {
		s.logger(ctx, "payments.webhook.duplicate", map[string]any{
			"orderId":   order.ID,
			"paymentId": payment.ID,
			"eventId":   eventID,
			"eventType": string(event.Type),
		})
		return nil
	}

	now := s.now()
	raw := mergeAnyMaps(payment.Raw, eventPayloadMap(event))
	status := mapStripeIntentStatus(intent.Status, event.Type)
	captured, capturedAt := stripeIntentCaptureInfo(intent, event)

	details := payments.PaymentDetails{
		Provider:   "stripe",
		IntentID:   strings.TrimSpace(intent.ID),
		Status:     status,
		Currency:   strings.ToUpper(string(intent.Currency)),
		Captured:   captured,
		CapturedAt: capturedAt,
		Raw:        raw,
	}
	if intent.AmountReceived > 0 {
		details.Amount = intent.AmountReceived
	} else if intent.Amount > 0 {
		details.Amount = intent.Amount
	}

	updated := applyPaymentDetails(payment, details, now)
	if details.IntentID != "" {
		updated.IntentID = details.IntentID
	}
	updated.Raw = markStripeEventProcessed(updated.Raw, event, now)

	if err := s.persistPaymentUpdate(ctx, order, updated); err != nil {
		return err
	}

	s.logger(ctx, "payments.webhook.payment_intent", map[string]any{
		"orderId":   order.ID,
		"paymentId": payment.ID,
		"eventId":   eventID,
		"eventType": string(event.Type),
		"status":    updated.Status,
	})
	return nil
}

func (s *paymentService) handleStripeChargeRefunded(ctx context.Context, event stripe.Event, charge stripe.Charge, orderID, paymentID, intentID string) error {
	order, payment, err := s.loadOrderPaymentByReference(ctx, orderID, paymentID, intentID)
	if err != nil {
		return err
	}

	eventID := strings.TrimSpace(event.ID)
	if isPaymentEventProcessed(payment.Raw, eventID) {
		s.logger(ctx, "payments.webhook.duplicate", map[string]any{
			"orderId":   order.ID,
			"paymentId": payment.ID,
			"eventId":   eventID,
			"eventType": string(event.Type),
		})
		return nil
	}

	now := s.now()
	raw := mergeAnyMaps(payment.Raw, eventPayloadMap(event))
	refundedAt := timeFromUnix(event.Created)

	details := payments.PaymentDetails{
		Provider:   "stripe",
		IntentID:   strings.TrimSpace(intentID),
		Status:     payments.StatusRefunded,
		Currency:   strings.ToUpper(string(charge.Currency)),
		Captured:   charge.Captured,
		RefundedAt: refundedAt,
		Raw:        raw,
	}
	if charge.PaymentIntent != nil && strings.TrimSpace(charge.PaymentIntent.ID) != "" {
		details.IntentID = strings.TrimSpace(charge.PaymentIntent.ID)
	}

	updated := applyPaymentDetails(payment, details, now)
	if details.IntentID != "" {
		updated.IntentID = details.IntentID
	}
	updated.Raw = markStripeEventProcessed(updated.Raw, event, now)

	if err := s.persistPaymentUpdate(ctx, order, updated); err != nil {
		return err
	}

	s.logger(ctx, "payments.webhook.charge_refunded", map[string]any{
		"orderId":      order.ID,
		"paymentId":    payment.ID,
		"eventId":      eventID,
		"refundAmount": charge.AmountRefunded,
		"currency":     strings.ToUpper(string(charge.Currency)),
	})
	return nil
}

// ManualCapture captures an authorised payment via the configured PSP.
func (s *paymentService) ManualCapture(ctx context.Context, cmd PaymentManualCaptureCommand) (Payment, error) {
	if s == nil || s.orders == nil || s.payments == nil {
		return Payment{}, ErrPaymentUnavailable
	}

	orderID := strings.TrimSpace(cmd.OrderID)
	paymentID := strings.TrimSpace(cmd.PaymentID)
	actorID := strings.TrimSpace(cmd.ActorID)
	reason := strings.TrimSpace(cmd.Reason)
	if orderID == "" || paymentID == "" || actorID == "" {
		return Payment{}, fmt.Errorf("%w: order id, payment id, and actor id are required", ErrPaymentInvalidInput)
	}
	if cmd.Amount != nil && *cmd.Amount <= 0 {
		return Payment{}, fmt.Errorf("%w: amount must be positive", ErrPaymentInvalidInput)
	}

	order, payment, err := s.loadOrderPayment(ctx, orderID, paymentID)
	if err != nil {
		return Payment{}, err
	}

	if !strings.EqualFold(payment.Currency, order.Currency) && strings.TrimSpace(payment.Currency) != "" {
		return Payment{}, fmt.Errorf("%w: payment currency does not match order currency", ErrPaymentInvalidInput)
	}

	if payment.Captured {
		return Payment{}, fmt.Errorf("%w: payment already captured", ErrPaymentInvalidState)
	}

	if cmd.Amount != nil && *cmd.Amount > payment.Amount && payment.Amount > 0 {
		return Payment{}, fmt.Errorf("%w: capture amount exceeds authorised amount", ErrPaymentInvalidInput)
	}

	idempotencyKey := deriveIdempotencyKey("manual_capture", cmd.IdempotencyKey, orderID, paymentID, cmd.Amount)
	metadata := normalizeStringMap(cmd.Metadata)
	if metadata == nil {
		metadata = make(map[string]string)
	}
	metadata["order_id"] = orderID
	metadata["payment_id"] = paymentID
	metadata["actor_id"] = actorID
	if reason != "" {
		metadata["reason"] = reason
	}

	details, err := s.processor.Capture(ctx, payments.PaymentContext{
		PreferredProvider: payment.Provider,
		Currency:          strings.ToUpper(order.Currency),
		Metadata:          metadata,
	}, payments.CaptureRequest{
		IntentID:       payment.IntentID,
		Amount:         cmd.Amount,
		IdempotencyKey: idempotencyKey,
		Metadata:       metadata,
	})
	if err != nil {
		return Payment{}, fmt.Errorf("payment: capture failed: %w", err)
	}

	now := s.now()
	before := payment
	updated := applyPaymentDetails(payment, details, now)
	if err := s.persistPaymentUpdate(ctx, order, updated); err != nil {
		return Payment{}, err
	}

	s.recordAudit(ctx, AuditLogRecord{
		Actor:      actorID,
		ActorType:  "staff",
		Action:     "payments.manual_capture",
		TargetRef:  fmt.Sprintf("/orders/%s/payments/%s", orderID, paymentID),
		OccurredAt: now,
		Metadata: map[string]any{
			"orderId":        orderID,
			"paymentId":      paymentID,
			"provider":       updated.Provider,
			"currency":       updated.Currency,
			"amount":         updated.Amount,
			"idempotencyKey": idempotencyKey,
			"reason":         reason,
			"status":         updated.Status,
		},
		Diff: map[string]AuditLogDiff{
			"status":   {Before: strings.TrimSpace(before.Status), After: strings.TrimSpace(updated.Status)},
			"captured": {Before: before.Captured, After: updated.Captured},
		},
	}, idempotencyKey)

	return updated, nil
}

// ManualRefund refunds a captured payment via the configured PSP.
func (s *paymentService) ManualRefund(ctx context.Context, cmd PaymentManualRefundCommand) (Payment, error) {
	if s == nil || s.orders == nil || s.payments == nil {
		return Payment{}, ErrPaymentUnavailable
	}

	orderID := strings.TrimSpace(cmd.OrderID)
	paymentID := strings.TrimSpace(cmd.PaymentID)
	actorID := strings.TrimSpace(cmd.ActorID)
	reason := strings.TrimSpace(cmd.Reason)
	if orderID == "" || paymentID == "" || actorID == "" {
		return Payment{}, fmt.Errorf("%w: order id, payment id, and actor id are required", ErrPaymentInvalidInput)
	}
	if cmd.Amount != nil && *cmd.Amount <= 0 {
		return Payment{}, fmt.Errorf("%w: amount must be positive", ErrPaymentInvalidInput)
	}

	order, payment, err := s.loadOrderPayment(ctx, orderID, paymentID)
	if err != nil {
		return Payment{}, err
	}

	if !payment.Captured && !strings.EqualFold(payment.Status, string(payments.StatusSucceeded)) {
		return Payment{}, fmt.Errorf("%w: payment not captured", ErrPaymentInvalidState)
	}

	capturedTotal := capturedAmount(payment)
	if capturedTotal == 0 {
		capturedTotal = payment.Amount
	}
	if cmd.Amount != nil && capturedTotal > 0 && *cmd.Amount > capturedTotal {
		return Payment{}, fmt.Errorf("%w: refund amount exceeds captured total", ErrPaymentInvalidInput)
	}

	idempotencyKey := deriveIdempotencyKey("manual_refund", cmd.IdempotencyKey, orderID, paymentID, cmd.Amount)
	metadata := normalizeStringMap(cmd.Metadata)
	if metadata == nil {
		metadata = make(map[string]string)
	}
	metadata["order_id"] = orderID
	metadata["payment_id"] = paymentID
	metadata["actor_id"] = actorID
	if reason != "" {
		metadata["reason"] = reason
	}

	details, err := s.processor.Refund(ctx, payments.PaymentContext{
		PreferredProvider: payment.Provider,
		Currency:          strings.ToUpper(order.Currency),
		Metadata:          metadata,
	}, payments.RefundRequest{
		IntentID:       payment.IntentID,
		Amount:         cmd.Amount,
		Reason:         reason,
		IdempotencyKey: idempotencyKey,
		Metadata:       metadata,
	})
	if err != nil {
		return Payment{}, fmt.Errorf("payment: refund failed: %w", err)
	}

	now := s.now()
	before := payment
	updated := applyPaymentDetails(payment, details, now)
	if err := s.persistPaymentUpdate(ctx, order, updated); err != nil {
		return Payment{}, err
	}

	s.recordAudit(ctx, AuditLogRecord{
		Actor:      actorID,
		ActorType:  "staff",
		Action:     "payments.manual_refund",
		TargetRef:  fmt.Sprintf("/orders/%s/payments/%s", orderID, paymentID),
		OccurredAt: now,
		Metadata: map[string]any{
			"orderId":        orderID,
			"paymentId":      paymentID,
			"provider":       updated.Provider,
			"currency":       updated.Currency,
			"amount":         valueOrDefault(cmd.Amount),
			"idempotencyKey": idempotencyKey,
			"reason":         reason,
			"status":         updated.Status,
		},
		Diff: map[string]AuditLogDiff{
			"status":   {Before: strings.TrimSpace(before.Status), After: strings.TrimSpace(updated.Status)},
			"refunded": {Before: refundedAmount(before), After: refundedAmount(updated)},
		},
	}, idempotencyKey)

	return updated, nil
}

// ListPayments returns the payments recorded for an order.
func (s *paymentService) ListPayments(ctx context.Context, orderID string) ([]Payment, error) {
	if s == nil || s.payments == nil {
		return nil, ErrPaymentUnavailable
	}
	orderID = strings.TrimSpace(orderID)
	if orderID == "" {
		return nil, fmt.Errorf("%w: order id is required", ErrPaymentInvalidInput)
	}
	paymentsList, err := s.payments.List(ctx, orderID)
	if err != nil {
		return nil, s.mapPaymentError(err)
	}
	return paymentsList, nil
}

func (s *paymentService) loadOrderPaymentByReference(ctx context.Context, orderID, paymentID, intentID string) (domain.Order, domain.Payment, error) {
	orderID = strings.TrimSpace(orderID)
	if orderID == "" {
		return domain.Order{}, domain.Payment{}, fmt.Errorf("%w: order id is required", ErrPaymentInvalidInput)
	}

	order, err := s.orders.FindByID(ctx, orderID)
	if err != nil {
		return domain.Order{}, domain.Payment{}, s.mapOrderError(err)
	}

	paymentsList, err := s.payments.List(ctx, orderID)
	if err != nil {
		return domain.Order{}, domain.Payment{}, s.mapPaymentError(err)
	}

	targetPaymentID := strings.TrimSpace(paymentID)
	targetIntentID := strings.TrimSpace(intentID)

	var payment domain.Payment
	found := false
	for _, p := range paymentsList {
		if targetPaymentID != "" && strings.EqualFold(strings.TrimSpace(p.ID), targetPaymentID) {
			payment = p
			found = true
			break
		}
		if targetPaymentID == "" && targetIntentID != "" && strings.EqualFold(strings.TrimSpace(p.IntentID), targetIntentID) {
			payment = p
			found = true
			break
		}
	}

	if !found {
		if targetPaymentID != "" {
			return domain.Order{}, domain.Payment{}, fmt.Errorf("%w: payment %s not found for order %s", ErrPaymentNotFound, targetPaymentID, orderID)
		}
		return domain.Order{}, domain.Payment{}, fmt.Errorf("%w: payment intent %s not found for order %s", ErrPaymentNotFound, targetIntentID, orderID)
	}

	return order, payment, nil
}

func (s *paymentService) loadOrderPayment(ctx context.Context, orderID, paymentID string) (domain.Order, domain.Payment, error) {
	order, err := s.orders.FindByID(ctx, orderID)
	if err != nil {
		return domain.Order{}, domain.Payment{}, s.mapOrderError(err)
	}

	paymentsList, err := s.payments.List(ctx, orderID)
	if err != nil {
		return domain.Order{}, domain.Payment{}, s.mapPaymentError(err)
	}

	var payment domain.Payment
	found := false
	for _, p := range paymentsList {
		if strings.EqualFold(strings.TrimSpace(p.ID), paymentID) {
			payment = p
			found = true
			break
		}
	}
	if !found {
		return domain.Order{}, domain.Payment{}, fmt.Errorf("%w: payment %s not found", ErrPaymentNotFound, paymentID)
	}

	if !strings.EqualFold(strings.TrimSpace(payment.OrderID), orderID) {
		return domain.Order{}, domain.Payment{}, fmt.Errorf("%w: payment does not belong to order", ErrPaymentInvalidInput)
	}

	return order, payment, nil
}

func (s *paymentService) persistPaymentUpdate(ctx context.Context, order domain.Order, payment domain.Payment) error {
	now := s.now()
	return s.unit.RunInTx(ctx, func(txCtx context.Context) error {
		if err := s.payments.Update(txCtx, payment); err != nil {
			return s.mapPaymentError(err)
		}

		currentPayments, err := s.payments.List(txCtx, order.ID)
		if err != nil {
			return s.mapPaymentError(err)
		}

		updatedOrder, err := s.orders.FindByID(txCtx, order.ID)
		if err != nil {
			return s.mapOrderError(err)
		}

		s.applyOrderPaymentSummary(&updatedOrder, currentPayments, now)

		if err := s.orders.Update(txCtx, updatedOrder); err != nil {
			return s.mapOrderError(err)
		}
		s.logger(txCtx, "payments.order.updated", map[string]any{
			"orderId":   updatedOrder.ID,
			"paymentId": payment.ID,
			"status":    updatedOrder.Status,
		})
		return nil
	})
}

func (s *paymentService) applyOrderPaymentSummary(order *domain.Order, paymentsList []domain.Payment, now time.Time) {
	if order == nil {
		return
	}
	var capturedTotal int64
	var refundedTotal int64
	latestStatus := ""
	var latestUpdated time.Time

	for _, payment := range paymentsList {
		capturedTotal += capturedAmount(payment)
		refundedTotal += refundedAmount(payment)
		if payment.UpdatedAt.After(latestUpdated) {
			latestUpdated = payment.UpdatedAt
			latestStatus = strings.TrimSpace(payment.Status)
		}
	}

	if capturedTotal >= order.Totals.Total && order.Totals.Total > 0 && order.Status == domain.OrderStatusPendingPayment {
		order.Status = domain.OrderStatusPaid
		if order.PaidAt == nil || order.PaidAt.IsZero() {
			order.PaidAt = valuePtr(now)
		}
	}

	order.UpdatedAt = now
	if order.Metadata == nil {
		order.Metadata = make(map[string]any)
	} else {
		order.Metadata = maps.Clone(order.Metadata)
	}

	netCaptured := capturedTotal - refundedTotal
	balanceDue := order.Totals.Total - netCaptured
	paymentSummary := map[string]any{
		"status":         latestStatus,
		"capturedAmount": capturedTotal,
		"refundedAmount": refundedTotal,
		"balanceDue":     balanceDue,
		"updatedAt":      now,
	}

	order.Metadata["payment"] = paymentSummary
}

func (s *paymentService) mapOrderError(err error) error {
	if err == nil {
		return nil
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		switch {
		case repoErr.IsNotFound():
			return fmt.Errorf("%w: %v", ErrPaymentNotFound, err)
		case repoErr.IsConflict():
			return fmt.Errorf("%w: %v", ErrPaymentConflict, err)
		case repoErr.IsUnavailable():
			return fmt.Errorf("%w: repository unavailable: %v", ErrPaymentUnavailable, err)
		}
	}
	return err
}

func (s *paymentService) mapPaymentError(err error) error {
	if err == nil {
		return nil
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		switch {
		case repoErr.IsNotFound():
			return fmt.Errorf("%w: %v", ErrPaymentNotFound, err)
		case repoErr.IsConflict():
			return fmt.Errorf("%w: %v", ErrPaymentConflict, err)
		case repoErr.IsUnavailable():
			return fmt.Errorf("%w: repository unavailable: %v", ErrPaymentUnavailable, err)
		}
	}
	return err
}

func (s *paymentService) recordAudit(ctx context.Context, record AuditLogRecord, idempotencyKey string) {
	if s.audit == nil {
		return
	}
	if record.Metadata == nil {
		record.Metadata = make(map[string]any)
	}
	if idempotencyKey != "" {
		record.Metadata["idempotencyKey"] = idempotencyKey
	}
	s.audit.Record(ctx, record)
}

func applyPaymentDetails(payment domain.Payment, details payments.PaymentDetails, now time.Time) domain.Payment {
	payment.Status = string(details.Status)
	if details.Amount > 0 {
		payment.Amount = details.Amount
	}
	if currency := strings.TrimSpace(details.Currency); currency != "" {
		payment.Currency = strings.ToUpper(currency)
	}
	payment.Captured = details.Captured
	payment.CapturedAt = cloneTime(details.CapturedAt)
	payment.RefundedAt = cloneTime(details.RefundedAt)
	if details.Raw != nil {
		payment.Raw = cloneAnyMap(details.Raw)
	}
	payment.UpdatedAt = now
	if payment.CreatedAt.IsZero() {
		payment.CreatedAt = now
	}
	return payment
}

func capturedAmount(payment domain.Payment) int64 {
	if !payment.Captured && !strings.EqualFold(strings.TrimSpace(payment.Status), string(payments.StatusSucceeded)) && !strings.EqualFold(strings.TrimSpace(payment.Status), string(payments.StatusRefunded)) {
		return 0
	}
	if amount := intFromAny(payment.Raw["amount_received"]); amount > 0 {
		return amount
	}
	if amount := extractChargeAmount(payment.Raw, "amount_captured"); amount > 0 {
		return amount
	}
	if amount := intFromAny(payment.Raw["amount_captured"]); amount > 0 {
		return amount
	}
	if amount := conditionalAmount(payment.Raw); amount > 0 {
		return amount
	}
	if payment.Captured && payment.Amount > 0 {
		return payment.Amount
	}
	return 0
}

func refundedAmount(payment domain.Payment) int64 {
	if amount := intFromAny(payment.Raw["amount_refunded"]); amount > 0 {
		return amount
	}
	if amount := extractChargeAmount(payment.Raw, "amount_refunded"); amount > 0 {
		return amount
	}
	return 0
}

func extractChargeAmount(raw map[string]any, key string) int64 {
	if raw == nil {
		return 0
	}

	if charges, ok := raw["charges"].(map[string]any); ok {
		if amount := intFromAny(charges[key]); amount > 0 {
			return amount
		}
		if data, ok := charges["data"].([]any); ok {
			var total int64
			for _, entry := range data {
				charge, ok := entry.(map[string]any)
				if !ok {
					continue
				}
				amount := intFromAny(charge[key])
				if amount > 0 {
					total += amount
				}
			}
			if total > 0 {
				return total
			}
		}
	}

	if latest, ok := raw["latest_charge"].(map[string]any); ok {
		if amount := intFromAny(latest[key]); amount > 0 {
			return amount
		}
	}

	return 0
}

func conditionalAmount(raw map[string]any) int64 {
	if raw == nil {
		return 0
	}
	latest, ok := raw["latest_charge"].(map[string]any)
	if !ok {
		return 0
	}
	if !boolFromAny(latest["captured"]) {
		return 0
	}
	return intFromAny(latest["amount"])
}

func cloneTime(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	cp := t.UTC()
	return &cp
}

func deriveIdempotencyKey(action, provided, orderID, paymentID string, amount *int64) string {
	if trimmed := strings.TrimSpace(provided); trimmed != "" {
		return trimmed
	}
	builder := strings.Builder{}
	builder.Grow(128)
	builder.WriteString(strings.TrimSpace(action))
	builder.WriteString(":")
	builder.WriteString(strings.TrimSpace(orderID))
	builder.WriteString(":")
	builder.WriteString(strings.TrimSpace(paymentID))
	builder.WriteString(":")
	if amount != nil {
		builder.WriteString(strconv.FormatInt(*amount, 10))
	}
	sum := sha256.Sum256([]byte(builder.String()))
	return hex.EncodeToString(sum[:])
}

func valueOrDefault(amount *int64) int64 {
	if amount == nil {
		return 0
	}
	return *amount
}

func intFromAny(value any) int64 {
	switch v := value.(type) {
	case int64:
		return v
	case int:
		return int64(v)
	case float64:
		return int64(v)
	case json.Number:
		if i, err := v.Int64(); err == nil {
			return i
		}
		if f, err := v.Float64(); err == nil {
			return int64(f)
		}
	case string:
		if trimmed := strings.TrimSpace(v); trimmed != "" {
			if parsed, err := strconv.ParseInt(trimmed, 10, 64); err == nil {
				return parsed
			}
		}
	case map[string]any:
		if val, ok := v["amount"]; ok {
			return intFromAny(val)
		}
	}
	return 0
}

func boolFromAny(value any) bool {
	switch v := value.(type) {
	case bool:
		return v
	case string:
		return strings.EqualFold(strings.TrimSpace(v), "true")
	default:
		return false
	}
}

func normalizeStringMap(values map[string]string) map[string]string {
	if len(values) == 0 {
		return nil
	}
	result := make(map[string]string, len(values))
	for key, value := range values {
		trimmedKey := strings.TrimSpace(key)
		if trimmedKey == "" {
			continue
		}
		result[trimmedKey] = strings.TrimSpace(value)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

type stripeMetadata map[string]string

func normalizeStripeMetadata(meta map[string]string) stripeMetadata {
	if len(meta) == 0 {
		return stripeMetadata{}
	}
	result := make(map[string]string, len(meta)*2)
	for key, value := range meta {
		trimmedKey := strings.TrimSpace(key)
		trimmedValue := strings.TrimSpace(value)
		if trimmedKey == "" || trimmedValue == "" {
			continue
		}
		lower := strings.ToLower(trimmedKey)
		result[lower] = trimmedValue
		result[strings.ReplaceAll(lower, "_", "")] = trimmedValue
	}
	return stripeMetadata(result)
}

func (m stripeMetadata) lookup(keys ...string) string {
	for _, key := range keys {
		k := strings.ToLower(strings.TrimSpace(key))
		if k == "" {
			continue
		}
		if v, ok := m[k]; ok && strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
		noUnderscore := strings.ReplaceAll(k, "_", "")
		if v, ok := m[noUnderscore]; ok && strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

func mergeAnyMaps(base, updates map[string]any) map[string]any {
	if len(base) == 0 && len(updates) == 0 {
		return nil
	}
	result := make(map[string]any, len(base)+len(updates))
	for k, v := range base {
		result[k] = v
	}
	for k, v := range updates {
		result[k] = v
	}
	return result
}

func eventPayloadMap(event stripe.Event) map[string]any {
	if event.Data == nil {
		return nil
	}
	if len(event.Data.Object) > 0 {
		return cloneAnyMap(event.Data.Object)
	}
	if len(event.Data.Raw) > 0 {
		var payload map[string]any
		if err := json.Unmarshal(event.Data.Raw, &payload); err == nil {
			return payload
		}
	}
	return nil
}

func mapStripeIntentStatus(status stripe.PaymentIntentStatus, eventType stripe.EventType) payments.Status {
	switch status {
	case stripe.PaymentIntentStatusSucceeded:
		return payments.StatusSucceeded
	case stripe.PaymentIntentStatusCanceled, stripe.PaymentIntentStatusRequiresPaymentMethod:
		return payments.StatusFailed
	}
	if eventType == stripe.EventTypePaymentIntentPaymentFailed {
		return payments.StatusFailed
	}
	return payments.StatusPending
}

func stripeIntentCaptureInfo(intent stripe.PaymentIntent, event stripe.Event) (bool, *time.Time) {
	if intent.LatestCharge != nil {
		if intent.LatestCharge.Captured || intent.LatestCharge.Status == stripe.ChargeStatusSucceeded {
			return true, timeFromUnix(intent.LatestCharge.Created)
		}
	}
	if intent.Status == stripe.PaymentIntentStatusSucceeded {
		if intent.Created > 0 {
			return true, timeFromUnix(intent.Created)
		}
		return true, timeFromUnix(event.Created)
	}
	return false, nil
}

func timeFromUnix(ts int64) *time.Time {
	if ts <= 0 {
		return nil
	}
	t := time.Unix(ts, 0).UTC()
	return &t
}

func timeFromUnixValue(ts int64) time.Time {
	if ts <= 0 {
		return time.Time{}
	}
	return time.Unix(ts, 0).UTC()
}

func markStripeEventProcessed(raw map[string]any, event stripe.Event, processedAt time.Time) map[string]any {
	result := mergeAnyMaps(raw, nil)
	if result == nil {
		result = make(map[string]any)
	}

	events := make(map[string]any)
	if existing, ok := result["webhookEvents"].(map[string]any); ok && existing != nil {
		events = cloneAnyMap(existing)
	}

	eventID := strings.TrimSpace(event.ID)
	if eventID != "" {
		events[eventID] = map[string]any{
			"type":        string(event.Type),
			"createdAt":   timeFromUnixValue(event.Created),
			"processedAt": processedAt.UTC(),
		}
		result["webhookEvents"] = events
		result["lastWebhookEvent"] = map[string]any{
			"id":          eventID,
			"type":        string(event.Type),
			"createdAt":   timeFromUnixValue(event.Created),
			"processedAt": processedAt.UTC(),
		}
	}

	return result
}

func isPaymentEventProcessed(raw map[string]any, eventID string) bool {
	if len(raw) == 0 || strings.TrimSpace(eventID) == "" {
		return false
	}
	events, ok := raw["webhookEvents"].(map[string]any)
	if !ok || events == nil {
		return false
	}
	_, exists := events[strings.TrimSpace(eventID)]
	return exists
}
