package services

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

func TestShipmentService_CreateShipmentGeneratesLabelAndUpdatesStatus(t *testing.T) {
	now := time.Date(2024, 10, 5, 12, 0, 0, 0, time.UTC)
	order := domain.Order{
		ID:          "ord_123",
		OrderNumber: "HF-2024-000001",
		Status:      domain.OrderStatusReadyToShip,
		Items: []domain.OrderLineItem{
			{SKU: "SKU-1", Quantity: 1},
		},
		Audit: domain.OrderAudit{},
	}

	orderRepo := &shipmentTestOrderRepo{order: order}
	shipmentRepo := &shipmentTestShipmentRepo{}
	labelProvider := &shipmentTestLabelProvider{
		label: ShippingLabel{
			TrackingNumber: "TRK-123",
			LabelURL:       "https://example.com/label.pdf",
			Documents:      []string{"https://example.com/commercial-invoice.pdf"},
		},
	}
	events := &shipmentTestEventPublisher{}

	service, err := NewShipmentService(ShipmentServiceDeps{
		Orders:    orderRepo,
		Shipments: shipmentRepo,
		Clock:     func() time.Time { return now },
		Labels:    labelProvider,
		Events:    events,
	})
	if err != nil {
		t.Fatalf("NewShipmentService() error = %v", err)
	}

	result, err := service.CreateShipment(context.Background(), CreateShipmentCommand{
		OrderID:            order.ID,
		Carrier:            "yamato",
		ServiceLevel:       "TA-Q-BIN",
		TrackingPreference: "auto",
		Package: &ShipmentPackage{
			Length: 20,
			Width:  10,
			Height: 5,
			Weight: 1.25,
			Unit:   "cm",
		},
		Items: []ShipmentItem{
			{LineItemSKU: "SKU-1", Quantity: 1},
		},
		CreatedBy: "staff-001",
	})
	if err != nil {
		t.Fatalf("CreateShipment() error = %v", err)
	}

	if !labelProvider.called {
		t.Fatalf("expected label provider to be invoked")
	}
	if result.TrackingCode != "TRK-123" {
		t.Fatalf("expected tracking code TRK-123, got %s", result.TrackingCode)
	}
	if result.Service != "TA-Q-BIN" {
		t.Fatalf("expected service level to be propagated")
	}
	if result.LabelURL == nil || *result.LabelURL != "https://example.com/label.pdf" {
		t.Fatalf("expected label url to be set")
	}
	if len(result.Events) != 1 || result.Events[0].Status != "label_created" {
		t.Fatalf("expected label_created event, got %#v", result.Events)
	}

	if orderRepo.updated == nil {
		t.Fatalf("expected order update to be triggered")
	}
	if orderRepo.updated.Status != domain.OrderStatusShipped {
		t.Fatalf("expected order status shipped, got %s", orderRepo.updated.Status)
	}
	if orderRepo.updated.ShippedAt == nil || !orderRepo.updated.ShippedAt.Equal(now) {
		t.Fatalf("expected shippedAt to be set to %s, got %#v", now.Format(time.RFC3339Nano), orderRepo.updated.ShippedAt)
	}
	if len(shipmentRepo.inserted) != 1 {
		t.Fatalf("expected shipment insert, got %d", len(shipmentRepo.inserted))
	}
	if len(events.events) == 0 || events.events[0].Type != orderEventShipmentCreated {
		t.Fatalf("expected shipment created event, got %#v", events.events)
	}
}

func TestShipmentService_CreateShipmentManualPartialDoesNotUpdateStatus(t *testing.T) {
	now := time.Date(2024, 10, 6, 9, 0, 0, 0, time.UTC)
	order := domain.Order{
		ID:          "ord_partial",
		OrderNumber: "HF-2024-000010",
		Status:      domain.OrderStatusReadyToShip,
		Items: []domain.OrderLineItem{
			{SKU: "SKU-1", Quantity: 2},
		},
		Audit: domain.OrderAudit{},
	}
	orderRepo := &shipmentTestOrderRepo{order: order}
	shipmentRepo := &shipmentTestShipmentRepo{}

	service, err := NewShipmentService(ShipmentServiceDeps{
		Orders:    orderRepo,
		Shipments: shipmentRepo,
		Clock:     func() time.Time { return now },
	})
	if err != nil {
		t.Fatalf("NewShipmentService() error = %v", err)
	}

	manual := "MANUAL-001"
	result, err := service.CreateShipment(context.Background(), CreateShipmentCommand{
		OrderID:            order.ID,
		Carrier:            "JPPOST",
		ServiceLevel:       "EMS",
		TrackingPreference: "manual",
		Items: []ShipmentItem{
			{LineItemSKU: "SKU-1", Quantity: 1},
		},
		ManualTrackingCode: &manual,
		CreatedBy:          "staff-002",
	})
	if err != nil {
		t.Fatalf("CreateShipment() error = %v", err)
	}
	if result.TrackingCode != manual {
		t.Fatalf("expected manual tracking code to propagate")
	}
	if orderRepo.updated != nil {
		t.Fatalf("order status should not be updated for partial shipment")
	}
	if len(shipmentRepo.inserted) != 1 {
		t.Fatalf("expected one shipment insert, got %d", len(shipmentRepo.inserted))
	}
}

func TestShipmentService_CreateShipmentLabelFailure(t *testing.T) {
	order := domain.Order{
		ID:          "ord_error",
		OrderNumber: "HF-2024-000020",
		Status:      domain.OrderStatusReadyToShip,
		Items: []domain.OrderLineItem{
			{SKU: "SKU-ERR", Quantity: 1},
		},
		Audit: domain.OrderAudit{},
	}
	orderRepo := &shipmentTestOrderRepo{order: order}
	shipmentRepo := &shipmentTestShipmentRepo{}
	labelProvider := &shipmentTestLabelProvider{err: errors.New("carrier timeout")}

	service, err := NewShipmentService(ShipmentServiceDeps{
		Orders:    orderRepo,
		Shipments: shipmentRepo,
		Clock:     func() time.Time { return time.Now().UTC() },
		Labels:    labelProvider,
	})
	if err != nil {
		t.Fatalf("NewShipmentService() error = %v", err)
	}

	_, err = service.CreateShipment(context.Background(), CreateShipmentCommand{
		OrderID:            order.ID,
		Carrier:            "YAMATO",
		ServiceLevel:       "TA-Q-BIN",
		TrackingPreference: "auto",
		Items: []ShipmentItem{
			{LineItemSKU: "SKU-ERR", Quantity: 1},
		},
		CreatedBy: "staff-003",
	})
	if err == nil || !errors.Is(err, ErrShipmentInvalidInput) {
		t.Fatalf("expected ErrShipmentInvalidInput, got %v", err)
	}
	if len(shipmentRepo.inserted) != 0 {
		t.Fatalf("expected no shipments inserted on error")
	}
}

type shipmentTestOrderRepo struct {
	order   domain.Order
	updated *domain.Order
}

func (r *shipmentTestOrderRepo) Insert(ctx context.Context, order domain.Order) error {
	return nil
}

func (r *shipmentTestOrderRepo) Update(ctx context.Context, order domain.Order) error {
	cloned := order
	r.updated = &cloned
	return nil
}

func (r *shipmentTestOrderRepo) FindByID(ctx context.Context, orderID string) (domain.Order, error) {
	if strings.EqualFold(orderID, r.order.ID) {
		return r.order, nil
	}
	return domain.Order{}, errors.New("not found")
}

func (r *shipmentTestOrderRepo) List(ctx context.Context, filter repositories.OrderListFilter) (domain.CursorPage[domain.Order], error) {
	return domain.CursorPage[domain.Order]{}, nil
}

type shipmentTestShipmentRepo struct {
	existing []domain.Shipment
	inserted []domain.Shipment
}

func (r *shipmentTestShipmentRepo) Insert(ctx context.Context, shipment domain.Shipment) error {
	r.inserted = append(r.inserted, shipment)
	return nil
}

func (r *shipmentTestShipmentRepo) Update(ctx context.Context, shipment domain.Shipment) error {
	return nil
}

func (r *shipmentTestShipmentRepo) List(ctx context.Context, orderID string) ([]domain.Shipment, error) {
	result := make([]domain.Shipment, len(r.existing))
	copy(result, r.existing)
	return result, nil
}

type shipmentTestLabelProvider struct {
	label ShippingLabel
	err   error

	called      bool
	lastRequest ShippingLabelRequest
}

func (p *shipmentTestLabelProvider) CreateShippingLabel(ctx context.Context, req ShippingLabelRequest) (ShippingLabel, error) {
	p.called = true
	p.lastRequest = req
	if p.err != nil {
		return ShippingLabel{}, p.err
	}
	return p.label, nil
}

type shipmentTestEventPublisher struct {
	events []OrderEvent
}

func (p *shipmentTestEventPublisher) PublishOrderEvent(_ context.Context, event OrderEvent) error {
	p.events = append(p.events, event)
	return nil
}
