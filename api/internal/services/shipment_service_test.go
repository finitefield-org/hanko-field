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

func TestShipmentService_UpdateShipmentStatus_AppendsEventAndPublishesNotifications(t *testing.T) {
	now := time.Date(2024, 10, 7, 15, 30, 0, 0, time.UTC)
	updatedAt := now.Add(-2 * time.Hour)
	order := domain.Order{
		ID:          "ord_upd",
		OrderNumber: "HF-2024-000030",
		Status:      domain.OrderStatusShipped,
		Audit:       domain.OrderAudit{},
	}
	shipment := domain.Shipment{
		ID:           "shp_001",
		OrderID:      order.ID,
		Carrier:      "YAMATO",
		TrackingCode: "OLD-TRK",
		Status:       "in_transit",
		UpdatedAt:    updatedAt,
		CreatedAt:    now.Add(-24 * time.Hour),
		Events: []domain.ShipmentEvent{{
			Status:     "in_transit",
			OccurredAt: now.Add(-3 * time.Hour),
		}},
	}

	orderRepo := &shipmentTestOrderRepo{order: order}
	shipmentRepo := &shipmentTestShipmentRepo{existing: []domain.Shipment{shipment}}
	events := &shipmentTestEventPublisher{}

	service, err := NewShipmentService(ShipmentServiceDeps{
		Orders:    orderRepo,
		Shipments: shipmentRepo,
		Clock:     func() time.Time { return now },
		Events:    events,
	})
	if err != nil {
		t.Fatalf("NewShipmentService() error = %v", err)
	}

	eta := now.Add(48 * time.Hour)
	ifUnmodified := updatedAt.UTC()
	tracking := "NEW-TRK"
	note := "Carrier confirmed delivery"

	result, err := service.UpdateShipmentStatus(context.Background(), UpdateShipmentCommand{
		OrderID:               order.ID,
		ShipmentID:            shipment.ID,
		Status:                "delivered",
		TrackingCode:          &tracking,
		ExpectedDelivery:      &eta,
		Notes:                 &note,
		IfUnmodifiedSince:     &ifUnmodified,
		ActorID:               "staff-007",
		ClearExpectedDelivery: false,
	})
	if err != nil {
		t.Fatalf("UpdateShipmentStatus() error = %v", err)
	}

	if result.Status != "delivered" {
		t.Fatalf("expected status delivered, got %s", result.Status)
	}
	if result.TrackingCode != tracking {
		t.Fatalf("expected tracking updated to %s", tracking)
	}
	if result.ETA == nil || !result.ETA.Equal(eta.UTC()) {
		t.Fatalf("expected eta updated to %s", eta.Format(time.RFC3339))
	}
	if strings.TrimSpace(result.Notes) != note {
		t.Fatalf("expected notes to be set")
	}
	if len(result.Events) == 0 {
		t.Fatalf("expected manual event appended")
	}
	latest := result.Events[len(result.Events)-1]
	if latest.Status != "delivered" {
		t.Fatalf("expected latest event status delivered, got %s", latest.Status)
	}
	if latest.OccurredAt != now {
		t.Fatalf("expected event timestamp to match now")
	}
	if source := latest.Details["source"]; source != "manual_update" {
		t.Fatalf("expected manual update source, got %#v", source)
	}
	if latest.Details["note"] != note {
		t.Fatalf("expected note in event details")
	}

	if len(shipmentRepo.updated) != 1 {
		t.Fatalf("expected shipment repository update")
	}
	if orderRepo.updated == nil || orderRepo.updated.Status != domain.OrderStatusDelivered {
		t.Fatalf("expected order status transitioned to delivered")
	}

	if len(events.events) < 2 {
		t.Fatalf("expected shipment events to be published")
	}

	var hasUpdated, hasDelivered, hasStatusChange bool
	for _, evt := range events.events {
		switch evt.Type {
		case orderEventShipmentUpdated:
			hasUpdated = true
		case orderEventShipmentDelivered:
			hasDelivered = true
		case orderEventStatusChanged:
			hasStatusChange = true
		}
	}
	if !hasUpdated {
		t.Fatalf("expected order.shipment.updated event")
	}
	if !hasDelivered {
		t.Fatalf("expected order.shipment.delivered event")
	}
	if !hasStatusChange {
		t.Fatalf("expected order.status.changed event")
	}
}

func TestShipmentService_UpdateShipmentStatus_ConflictsOnStaleVersion(t *testing.T) {
	now := time.Date(2024, 10, 8, 8, 0, 0, 0, time.UTC)
	order := domain.Order{ID: "ord_conflict", OrderNumber: "HF-2024-000040", Status: domain.OrderStatusShipped}
	shipment := domain.Shipment{
		ID:        "shp_conflict",
		OrderID:   order.ID,
		Carrier:   "JPPOST",
		Status:    "in_transit",
		UpdatedAt: now.Add(-30 * time.Minute),
		CreatedAt: now.Add(-24 * time.Hour),
	}

	orderRepo := &shipmentTestOrderRepo{order: order}
	shipmentRepo := &shipmentTestShipmentRepo{existing: []domain.Shipment{shipment}}

	service, err := NewShipmentService(ShipmentServiceDeps{
		Orders:    orderRepo,
		Shipments: shipmentRepo,
		Clock:     func() time.Time { return now },
	})
	if err != nil {
		t.Fatalf("NewShipmentService() error = %v", err)
	}

	ifUnmodified := now.Add(-10 * time.Minute).UTC()

	_, err = service.UpdateShipmentStatus(context.Background(), UpdateShipmentCommand{
		OrderID:           order.ID,
		ShipmentID:        shipment.ID,
		Status:            "exception",
		IfUnmodifiedSince: &ifUnmodified,
		ActorID:           "staff-008",
	})
	if err == nil || !errors.Is(err, ErrShipmentConflict) {
		t.Fatalf("expected ErrShipmentConflict, got %v", err)
	}
	if len(shipmentRepo.updated) != 0 {
		t.Fatalf("expected no shipment updates on conflict")
	}
}

func TestShipmentService_RecordCarrierEvent_Delivered(t *testing.T) {
	now := time.Date(2024, 11, 3, 9, 30, 0, 0, time.UTC)
	occurredAt := now.Add(-30 * time.Minute)

	order := domain.Order{
		ID:          "ord_track",
		OrderNumber: "HF-2024-000099",
		Status:      domain.OrderStatusShipped,
	}
	shipment := domain.Shipment{
		ID:           "shp_track",
		OrderID:      order.ID,
		Carrier:      "DHL",
		TrackingCode: "DHL123456789",
		Status:       "in_transit",
		Events: []domain.ShipmentEvent{{
			Status:     "in_transit",
			OccurredAt: now.Add(-2 * time.Hour),
		}},
		UpdatedAt: now.Add(-1 * time.Hour),
		CreatedAt: now.Add(-48 * time.Hour),
	}

	orderRepo := &shipmentTestOrderRepo{order: order}
	shipmentRepo := &shipmentTestShipmentRepo{existing: []domain.Shipment{shipment}}
	events := &shipmentTestEventPublisher{}

	service, err := NewShipmentService(ShipmentServiceDeps{
		Orders:    orderRepo,
		Shipments: shipmentRepo,
		Clock:     func() time.Time { return now },
		Events:    events,
	})
	if err != nil {
		t.Fatalf("NewShipmentService() error = %v", err)
	}

	err = service.RecordCarrierEvent(context.Background(), ShipmentEventCommand{
		Carrier:      "dhl",
		TrackingCode: "dhl123456789",
		Event: ShipmentEvent{
			Status:     "delivered",
			OccurredAt: occurredAt,
			Details: map[string]any{
				"location": "Tokyo",
			},
		},
	})
	if err != nil {
		t.Fatalf("RecordCarrierEvent() error = %v", err)
	}

	if len(shipmentRepo.updated) != 1 {
		t.Fatalf("expected shipment updated once, got %d", len(shipmentRepo.updated))
	}
	updated := shipmentRepo.updated[0]
	if updated.Status != "delivered" {
		t.Fatalf("expected shipment status delivered, got %s", updated.Status)
	}
	if updated.TrackingCode != "DHL123456789" {
		t.Fatalf("expected tracking preserved, got %s", updated.TrackingCode)
	}
	if len(updated.Events) != len(shipment.Events)+1 {
		t.Fatalf("expected event appended, got %d events", len(updated.Events))
	}
	lastEvent := updated.Events[len(updated.Events)-1]
	if lastEvent.Status != "delivered" {
		t.Fatalf("expected last event status delivered, got %s", lastEvent.Status)
	}
	if !lastEvent.OccurredAt.Equal(occurredAt) {
		t.Fatalf("expected occurredAt %s, got %s", occurredAt.Format(time.RFC3339), lastEvent.OccurredAt.Format(time.RFC3339))
	}
	if source := lastEvent.Details["source"]; source != "carrier:dhl" {
		t.Fatalf("expected source carrier:dhl, got %#v", source)
	}
	if carrier := lastEvent.Details["carrier"]; carrier != "DHL" {
		t.Fatalf("expected carrier detail DHL, got %#v", carrier)
	}

	if orderRepo.updated == nil {
		t.Fatalf("expected order updated")
	}
	if orderRepo.updated.Status != domain.OrderStatusDelivered {
		t.Fatalf("expected order status delivered, got %s", orderRepo.updated.Status)
	}
	if orderRepo.updated.DeliveredAt == nil || !orderRepo.updated.DeliveredAt.Equal(occurredAt) {
		t.Fatalf("expected DeliveredAt %s, got %#v", occurredAt.Format(time.RFC3339), orderRepo.updated.DeliveredAt)
	}

	var hasUpdated, hasDelivered, hasStatusChange bool
	for _, evt := range events.events {
		switch evt.Type {
		case orderEventShipmentUpdated:
			hasUpdated = true
			if evt.ActorID != "carrier:dhl" {
				t.Fatalf("expected updated event actor carrier:dhl, got %s", evt.ActorID)
			}
		case orderEventShipmentDelivered:
			hasDelivered = true
		case orderEventStatusChanged:
			hasStatusChange = true
			if evt.CurrentStatus != string(domain.OrderStatusDelivered) {
				t.Fatalf("expected status change to delivered, got %s", evt.CurrentStatus)
			}
		}
	}
	if !hasUpdated || !hasDelivered || !hasStatusChange {
		t.Fatalf("expected shipment updated/delivered and status change events, got %#v", events.events)
	}
}

func TestShipmentService_RecordCarrierEvent_Exception(t *testing.T) {
	now := time.Date(2024, 11, 4, 12, 0, 0, 0, time.UTC)
	occurredAt := now.Add(-10 * time.Minute)

	order := domain.Order{
		ID:          "ord_exception",
		OrderNumber: "HF-2024-000120",
		Status:      domain.OrderStatusReadyToShip,
	}
	shipment := domain.Shipment{
		ID:           "shp_exception",
		OrderID:      order.ID,
		Carrier:      "YAMATO",
		TrackingCode: "YAM999888777",
		Status:       "out_for_delivery",
		Events: []domain.ShipmentEvent{{
			Status:     "out_for_delivery",
			OccurredAt: now.Add(-1 * time.Hour),
		}},
		UpdatedAt: now.Add(-30 * time.Minute),
		CreatedAt: now.Add(-24 * time.Hour),
	}

	orderRepo := &shipmentTestOrderRepo{order: order}
	shipmentRepo := &shipmentTestShipmentRepo{existing: []domain.Shipment{shipment}}
	events := &shipmentTestEventPublisher{}

	service, err := NewShipmentService(ShipmentServiceDeps{
		Orders:    orderRepo,
		Shipments: shipmentRepo,
		Clock:     func() time.Time { return now },
		Events:    events,
	})
	if err != nil {
		t.Fatalf("NewShipmentService() error = %v", err)
	}

	err = service.RecordCarrierEvent(context.Background(), ShipmentEventCommand{
		Carrier:      "yamato",
		TrackingCode: "yam999888777",
		Event: ShipmentEvent{
			Status:     "exception",
			OccurredAt: occurredAt,
			Details: map[string]any{
				"reason": "Address not found",
			},
		},
	})
	if err != nil {
		t.Fatalf("RecordCarrierEvent() error = %v", err)
	}

	if len(shipmentRepo.updated) != 1 {
		t.Fatalf("expected shipment updated once, got %d", len(shipmentRepo.updated))
	}
	updated := shipmentRepo.updated[0]
	if updated.Status != "exception" {
		t.Fatalf("expected shipment status exception, got %s", updated.Status)
	}
	if len(updated.Events) != len(shipment.Events)+1 {
		t.Fatalf("expected event appended, got %d events", len(updated.Events))
	}
	lastEvent := updated.Events[len(updated.Events)-1]
	if lastEvent.Details["reason"] != "Address not found" {
		t.Fatalf("expected reason in event details")
	}
	if lastEvent.Details["source"] != "carrier:yamato" {
		t.Fatalf("expected source carrier:yamato, got %#v", lastEvent.Details["source"])
	}

	if orderRepo.updated == nil {
		t.Fatalf("expected order updated")
	}
	if orderRepo.updated.Status != domain.OrderStatusShipped {
		t.Fatalf("expected order status shipped, got %s", orderRepo.updated.Status)
	}

	var hasUpdated, hasException bool
	for _, evt := range events.events {
		switch evt.Type {
		case orderEventShipmentUpdated:
			hasUpdated = true
		case orderEventShipmentException:
			hasException = true
		}
	}
	if !hasUpdated || !hasException {
		t.Fatalf("expected shipment updated and exception events, got %#v", events.events)
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
	updated  []domain.Shipment
}

func (r *shipmentTestShipmentRepo) Insert(ctx context.Context, shipment domain.Shipment) error {
	r.inserted = append(r.inserted, shipment)
	return nil
}

func (r *shipmentTestShipmentRepo) Update(ctx context.Context, shipment domain.Shipment) error {
	cloned := shipment
	r.updated = append(r.updated, cloned)
	for i := range r.existing {
		if strings.EqualFold(r.existing[i].ID, shipment.ID) {
			r.existing[i] = cloned
			break
		}
	}
	return nil
}

func (r *shipmentTestShipmentRepo) List(ctx context.Context, orderID string) ([]domain.Shipment, error) {
	result := make([]domain.Shipment, len(r.existing))
	copy(result, r.existing)
	return result, nil
}

func (r *shipmentTestShipmentRepo) FindByTracking(ctx context.Context, trackingCode string) (domain.Shipment, error) {
	code := strings.ToUpper(strings.TrimSpace(trackingCode))
	if code == "" {
		return domain.Shipment{}, ErrShipmentNotFound
	}
	for _, shipment := range r.existing {
		if strings.ToUpper(strings.TrimSpace(shipment.TrackingCode)) == code {
			return shipment, nil
		}
	}
	return domain.Shipment{}, ErrShipmentNotFound
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
