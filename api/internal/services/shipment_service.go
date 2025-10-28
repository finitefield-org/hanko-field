package services

import (
	"context"
	"errors"
	"fmt"
	"maps"
	"slices"
	"strings"
	"time"

	"github.com/oklog/ulid/v2"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

const (
	shipmentIDPrefix = "shp_"
)

var (
	// ErrShipmentInvalidInput indicates the request payload failed validation.
	ErrShipmentInvalidInput = errors.New("shipment: invalid input")
	// ErrShipmentNotFound indicates the target shipment could not be located.
	ErrShipmentNotFound = errors.New("shipment: not found")
	// ErrShipmentConflict indicates the operation would exceed ordered quantities or violate state.
	ErrShipmentConflict = errors.New("shipment: conflict")
)

// ShippingLabelProvider generates carrier labels and tracking numbers for shipments.
type ShippingLabelProvider interface {
	CreateShippingLabel(ctx context.Context, req ShippingLabelRequest) (ShippingLabel, error)
}

// ShippingLabelRequest captures metadata required to generate a carrier label.
type ShippingLabelRequest struct {
	OrderID            string
	OrderNumber        string
	Carrier            string
	ServiceLevel       string
	TrackingPreference string
	Package            *ShipmentPackage
	Items              []ShipmentItem
	ActorID            string
	RequestedAt        time.Time
}

// ShippingLabel contains the generated assets and metadata from the carrier integration.
type ShippingLabel struct {
	TrackingNumber    string
	LabelURL          string
	Documents         []string
	EstimatedDelivery *time.Time
	Metadata          map[string]any
}

// ShipmentServiceDeps bundles dependencies required for shipment orchestration.
type ShipmentServiceDeps struct {
	Orders      repositories.OrderRepository
	Shipments   repositories.OrderShipmentRepository
	UnitOfWork  repositories.UnitOfWork
	Clock       func() time.Time
	IDGenerator func() string
	Labels      ShippingLabelProvider
	Events      OrderEventPublisher
	Logger      func(ctx context.Context, event string, fields map[string]any)
}

type shipmentService struct {
	orders     repositories.OrderRepository
	shipments  repositories.OrderShipmentRepository
	unitOfWork repositories.UnitOfWork
	labels     ShippingLabelProvider
	events     OrderEventPublisher
	clock      func() time.Time
	newID      func() string
	logger     func(ctx context.Context, event string, fields map[string]any)
}

// NewShipmentService wires dependencies and returns a ShipmentService implementation.
func NewShipmentService(deps ShipmentServiceDeps) (ShipmentService, error) {
	if deps.Orders == nil {
		return nil, errors.New("shipment service: order repository is required")
	}
	if deps.Shipments == nil {
		return nil, errors.New("shipment service: shipment repository is required")
	}

	unit := deps.UnitOfWork
	if unit == nil {
		unit = noopUnitOfWork{}
	}
	clock := deps.Clock
	if clock == nil {
		clock = time.Now
	}
	idGen := deps.IDGenerator
	if idGen == nil {
		idGen = func() string { return ulidMake() }
	}
	logger := deps.Logger
	if logger == nil {
		logger = func(context.Context, string, map[string]any) {}
	}

	return &shipmentService{
		orders:     deps.Orders,
		shipments:  deps.Shipments,
		unitOfWork: unit,
		labels:     deps.Labels,
		events:     deps.Events,
		clock: func() time.Time {
			return clock().UTC()
		},
		newID:  idGen,
		logger: logger,
	}, nil
}

func (s *shipmentService) CreateShipment(ctx context.Context, cmd CreateShipmentCommand) (Shipment, error) {
	orderID := strings.TrimSpace(cmd.OrderID)
	if orderID == "" {
		return Shipment{}, fmt.Errorf("%w: order id is required", ErrShipmentInvalidInput)
	}
	carrier := strings.ToUpper(strings.TrimSpace(cmd.Carrier))
	if carrier == "" {
		return Shipment{}, fmt.Errorf("%w: carrier is required", ErrShipmentInvalidInput)
	}
	if len(cmd.Items) == 0 {
		return Shipment{}, fmt.Errorf("%w: at least one shipment item is required", ErrShipmentInvalidInput)
	}

	items, err := normalizeShipmentItems(cmd.Items)
	if err != nil {
		return Shipment{}, err
	}

	now := s.now()
	serviceLevel := strings.TrimSpace(cmd.ServiceLevel)
	trackingPref := strings.TrimSpace(cmd.TrackingPreference)
	actor := strings.TrimSpace(cmd.CreatedBy)

	var created Shipment
	var orderNumber string
	var prevStatus domain.OrderStatus
	var orderStatusChanged bool

	err = s.runInTx(ctx, func(txCtx context.Context) error {
		order, err := s.orders.FindByID(txCtx, orderID)
		if err != nil {
			return s.mapOrderError(err)
		}

		orderNumber = strings.TrimSpace(order.OrderNumber)
		prevStatus = order.Status

		existing, err := s.shipments.List(txCtx, orderID)
		if err != nil {
			return s.mapShipmentError(err)
		}

		if err := s.validateQuantities(order.Items, existing, items); err != nil {
			return err
		}

		created = Shipment{
			ID:        s.nextShipmentID(),
			OrderID:   orderID,
			Carrier:   carrier,
			Service:   serviceLevel,
			Status:    "label_created",
			Items:     slices.Clone(items),
			CreatedAt: now,
			UpdatedAt: now,
		}

		labelDetails := map[string]any{
			"carrier":            carrier,
			"trackingPreference": trackingPref,
		}
		if serviceLevel != "" {
			labelDetails["serviceLevel"] = serviceLevel
		}
		if pkg := cmd.Package; pkg != nil {
			labelDetails["package"] = map[string]any{
				"length": pkg.Length,
				"width":  pkg.Width,
				"height": pkg.Height,
				"weight": pkg.Weight,
				"unit":   strings.TrimSpace(pkg.Unit),
			}
		}

		if shouldRequestLabel(s.labels, trackingPref) {
			label, labelErr := s.labels.CreateShippingLabel(txCtx, ShippingLabelRequest{
				OrderID:            orderID,
				OrderNumber:        orderNumber,
				Carrier:            carrier,
				ServiceLevel:       serviceLevel,
				TrackingPreference: trackingPref,
				Package:            cmd.Package,
				Items:              slices.Clone(items),
				ActorID:            actor,
				RequestedAt:        now,
			})
			if labelErr != nil {
				return fmt.Errorf("%w: label generation failed: %v", ErrShipmentInvalidInput, labelErr)
			}
			if v := strings.TrimSpace(label.TrackingNumber); v != "" {
				created.TrackingCode = v
			}
			if v := strings.TrimSpace(label.LabelURL); v != "" {
				url := v
				created.LabelURL = &url
			}
			if label.EstimatedDelivery != nil {
				eta := label.EstimatedDelivery.UTC()
				created.ETA = &eta
			}
			if len(label.Documents) > 0 {
				created.Documents = slices.Clone(label.Documents)
			}
			if len(label.Metadata) > 0 {
				for k, v := range label.Metadata {
					labelDetails[k] = v
				}
			}
		}

		if cmd.ManualTrackingCode != nil {
			if manual := strings.TrimSpace(*cmd.ManualTrackingCode); manual != "" {
				created.TrackingCode = manual
			}
		}

		created.Events = append(created.Events, ShipmentEvent{
			Status:     "label_created",
			OccurredAt: now,
			Details:    maps.Clone(labelDetails),
		})

		if err := s.shipments.Insert(txCtx, domain.Shipment(created)); err != nil {
			return s.mapShipmentError(err)
		}

		existing = append(existing, created)

		if s.isOrderFullyShipped(order.Items, existing) {
			if order.Status != domain.OrderStatusShipped &&
				order.Status != domain.OrderStatusDelivered &&
				order.Status != domain.OrderStatusCompleted {
				if !canTransition(order.Status, domain.OrderStatusShipped) {
					return fmt.Errorf("%w: cannot transition order %s from %s to shipped", ErrShipmentConflict, order.ID, order.Status)
				}
				order.Status = domain.OrderStatusShipped
				order.UpdatedAt = now
				if order.ShippedAt == nil {
					order.ShippedAt = &now
				}
				if actor != "" {
					ref := actor
					order.Audit.UpdatedBy = &ref
				}
				if err := s.orders.Update(txCtx, order); err != nil {
					return s.mapOrderError(err)
				}
				orderStatusChanged = true
			}
		}

		return nil
	})
	if err != nil {
		return Shipment{}, err
	}

	s.publishShipmentCreated(ctx, orderID, orderNumber, created, actor)
	if orderStatusChanged {
		s.publishOrderStatusChange(ctx, orderID, orderNumber, prevStatus, domain.OrderStatusShipped, actor, now)
	}

	return created, nil
}

func (s *shipmentService) UpdateShipmentStatus(ctx context.Context, cmd UpdateShipmentCommand) (Shipment, error) {
	return Shipment{}, errors.New("shipment: update status not implemented")
}

func (s *shipmentService) ListShipments(ctx context.Context, orderID string) ([]Shipment, error) {
	orderID = strings.TrimSpace(orderID)
	if orderID == "" {
		return nil, fmt.Errorf("%w: order id is required", ErrShipmentInvalidInput)
	}
	shipments, err := s.shipments.List(ctx, orderID)
	if err != nil {
		return nil, s.mapShipmentError(err)
	}
	return shipments, nil
}

func (s *shipmentService) RecordCarrierEvent(ctx context.Context, cmd ShipmentEventCommand) error {
	return errors.New("shipment: carrier event recording not implemented")
}

func (s *shipmentService) validateQuantities(lines []OrderLineItem, existing []Shipment, items []ShipmentItem) error {
	if len(lines) == 0 {
		return fmt.Errorf("%w: order has no line items", ErrShipmentConflict)
	}
	remaining := s.computeRemaining(lines, existing)
	requested := make(map[string]int)
	for _, item := range items {
		key := normalizeSKU(item.LineItemSKU)
		requested[key] += item.Quantity
	}
	for key, qty := range requested {
		if qty <= 0 {
			return fmt.Errorf("%w: quantity for sku %s must be positive", ErrShipmentInvalidInput, key)
		}
		available, ok := remaining[key]
		if !ok {
			return fmt.Errorf("%w: line item %s is not part of this order", ErrShipmentInvalidInput, key)
		}
		if qty > available {
			return fmt.Errorf("%w: remaining quantity for sku %s is %d", ErrShipmentConflict, key, available)
		}
	}
	return nil
}

func (s *shipmentService) isOrderFullyShipped(lines []OrderLineItem, shipments []Shipment) bool {
	remaining := s.computeRemaining(lines, shipments)
	for _, qty := range remaining {
		if qty > 0 {
			return false
		}
	}
	return true
}

func (s *shipmentService) computeRemaining(lines []OrderLineItem, shipments []Shipment) map[string]int {
	remaining := make(map[string]int)
	for _, line := range lines {
		key := normalizeSKU(line.SKU)
		if key == "" {
			continue
		}
		remaining[key] += line.Quantity
	}
	for _, shipment := range shipments {
		for _, item := range shipment.Items {
			key := normalizeSKU(item.LineItemSKU)
			if key == "" {
				continue
			}
			remaining[key] -= item.Quantity
		}
	}
	for key, qty := range remaining {
		if qty < 0 {
			remaining[key] = 0
		}
	}
	return remaining
}

func (s *shipmentService) publishShipmentCreated(ctx context.Context, orderID, orderNumber string, shipment Shipment, actor string) {
	if s.events == nil {
		return
	}
	meta := map[string]any{
		"shipmentId": shipment.ID,
		"carrier":    shipment.Carrier,
	}
	if shipment.TrackingCode != "" {
		meta["trackingNumber"] = shipment.TrackingCode
	}
	if shipment.Service != "" {
		meta["serviceLevel"] = shipment.Service
	}
	s.publishOrderEvent(ctx, OrderEvent{
		Type:        orderEventShipmentCreated,
		OrderID:     orderID,
		OrderNumber: orderNumber,
		ActorID:     actor,
		OccurredAt:  shipment.CreatedAt,
		Metadata:    meta,
	})
}

func (s *shipmentService) publishOrderStatusChange(ctx context.Context, orderID, orderNumber string, previous, current domain.OrderStatus, actor string, at time.Time) {
	if s.events == nil || previous == current {
		return
	}
	s.publishOrderEvent(ctx, OrderEvent{
		Type:           orderEventStatusChanged,
		OrderID:        orderID,
		OrderNumber:    orderNumber,
		PreviousStatus: string(previous),
		CurrentStatus:  string(current),
		ActorID:        actor,
		OccurredAt:     at,
	})
}

func (s *shipmentService) publishOrderEvent(ctx context.Context, event OrderEvent) {
	if s.events == nil {
		return
	}
	if event.Metadata != nil {
		event.Metadata = maps.Clone(event.Metadata)
	}
	if err := s.events.PublishOrderEvent(ctx, event); err != nil {
		s.logger(ctx, "shipment.event.publish.failed", map[string]any{
			"type":   event.Type,
			"order":  event.OrderID,
			"error":  err.Error(),
			"status": event.CurrentStatus,
		})
	}
}

func (s *shipmentService) runInTx(ctx context.Context, fn func(context.Context) error) error {
	if s.unitOfWork == nil {
		return fn(ctx)
	}
	return s.unitOfWork.RunInTx(ctx, fn)
}

func (s *shipmentService) now() time.Time {
	return s.clock()
}

func (s *shipmentService) nextShipmentID() string {
	return shipmentIDPrefix + s.newID()
}

func (s *shipmentService) mapOrderError(err error) error {
	return mapRepositoryError(err, ErrOrderNotFound, ErrOrderConflict)
}

func (s *shipmentService) mapShipmentError(err error) error {
	return mapRepositoryError(err, ErrShipmentNotFound, ErrShipmentConflict)
}

func normalizeShipmentItems(items []ShipmentItem) ([]ShipmentItem, error) {
	if len(items) == 0 {
		return nil, fmt.Errorf("%w: at least one shipment item is required", ErrShipmentInvalidInput)
	}
	normalized := make([]ShipmentItem, 0, len(items))
	for _, item := range items {
		sku := strings.TrimSpace(item.LineItemSKU)
		if sku == "" {
			return nil, fmt.Errorf("%w: line item sku is required", ErrShipmentInvalidInput)
		}
		if item.Quantity <= 0 {
			return nil, fmt.Errorf("%w: quantity for sku %s must be positive", ErrShipmentInvalidInput, sku)
		}
		normalized = append(normalized, ShipmentItem{
			LineItemSKU: sku,
			Quantity:    item.Quantity,
		})
	}
	return normalized, nil
}

func normalizeSKU(sku string) string {
	return strings.ToUpper(strings.TrimSpace(sku))
}

func mapRepositoryError(err error, notFound error, conflict error) error {
	if err == nil {
		return nil
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		switch {
		case repoErr.IsNotFound():
			return fmt.Errorf("%w: %v", notFound, err)
		case repoErr.IsConflict():
			return fmt.Errorf("%w: %v", conflict, err)
		case repoErr.IsUnavailable():
			return fmt.Errorf("repository unavailable: %w", err)
		}
	}
	return err
}

func shouldRequestLabel(provider ShippingLabelProvider, preference string) bool {
	if provider == nil {
		return false
	}
	switch strings.ToLower(strings.TrimSpace(preference)) {
	case "manual", "skip":
		return false
	default:
		return true
	}
}

// ulidMake wraps ulid.Make to avoid direct dependency import for deterministic testing.
func ulidMake() string {
	return ulid.Make().String()
}
