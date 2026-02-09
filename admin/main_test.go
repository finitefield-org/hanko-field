package main

import "testing"

func TestFilterOrders(t *testing.T) {
	s, err := newServer()
	if err != nil {
		t.Fatalf("newServer() error = %v", err)
	}

	results := s.filterOrders(orderFilter{Status: "paid"})
	if len(results) == 0 {
		t.Fatal("expected paid orders but got none")
	}

	for _, order := range results {
		if order.Status != "paid" {
			t.Fatalf("unexpected status in filtered results: %s", order.Status)
		}
	}
}

func TestUpdateOrderStatus_ValidTransition(t *testing.T) {
	s, err := newServer()
	if err != nil {
		t.Fatalf("newServer() error = %v", err)
	}

	if err := s.updateOrderStatus("ord_1006", "manufacturing", "test.admin"); err != nil {
		t.Fatalf("updateOrderStatus() error = %v", err)
	}

	detail, ok := s.getOrderDetail("ord_1006", "", "")
	if !ok {
		t.Fatal("order not found after update")
	}

	if detail.Status != "manufacturing" {
		t.Fatalf("status = %s, want manufacturing", detail.Status)
	}
	if detail.PaymentStatus != "paid" {
		t.Fatalf("payment status = %s, want paid", detail.PaymentStatus)
	}
	if detail.FulfillmentStatus != "manufacturing" {
		t.Fatalf("fulfillment status = %s, want manufacturing", detail.FulfillmentStatus)
	}
}

func TestUpdateOrderStatus_InvalidTransition(t *testing.T) {
	s, err := newServer()
	if err != nil {
		t.Fatalf("newServer() error = %v", err)
	}

	err = s.updateOrderStatus("ord_1003", "delivered", "test.admin")
	if err == nil {
		t.Fatal("expected invalid transition error, got nil")
	}
}

func TestUpdateMaterial(t *testing.T) {
	s, err := newServer()
	if err != nil {
		t.Fatalf("newServer() error = %v", err)
	}

	input := materialPatchInput{
		LabelJA:       "新しい材質名",
		LabelEN:       "New Name",
		DescriptionJA: "新しい説明",
		DescriptionEN: "New Description",
		PriceJPY:      7777,
		SortOrder:     15,
		IsActive:      true,
	}
	if err := s.updateMaterial("boxwood", input); err != nil {
		t.Fatalf("updateMaterial() error = %v", err)
	}

	detail, ok := s.getMaterialDetail("boxwood", "", "")
	if !ok {
		t.Fatal("material not found after update")
	}

	if detail.LabelJA != input.LabelJA {
		t.Fatalf("label_ja = %s, want %s", detail.LabelJA, input.LabelJA)
	}
	if detail.PriceJPY != input.PriceJPY {
		t.Fatalf("price = %d, want %d", detail.PriceJPY, input.PriceJPY)
	}
	if detail.SortOrder != input.SortOrder {
		t.Fatalf("sort order = %d, want %d", detail.SortOrder, input.SortOrder)
	}
	if !detail.IsActive {
		t.Fatal("is_active = false, want true")
	}
}

func TestUpdateShipping_InvalidTransitionDoesNotMutate(t *testing.T) {
	s, err := newServer()
	if err != nil {
		t.Fatalf("newServer() error = %v", err)
	}

	before, ok := s.getOrderDetail("ord_1007", "", "")
	if !ok {
		t.Fatal("order not found")
	}

	err = s.updateShipping("ord_1007", "DHL", "DHL-999", "delivered", "test.admin")
	if err == nil {
		t.Fatal("expected transition error, got nil")
	}

	after, ok := s.getOrderDetail("ord_1007", "", "")
	if !ok {
		t.Fatal("order not found after update")
	}

	if after.Carrier != before.Carrier {
		t.Fatalf("carrier changed on error: before=%s after=%s", before.Carrier, after.Carrier)
	}
	if after.TrackingNo != before.TrackingNo {
		t.Fatalf("tracking_no changed on error: before=%s after=%s", before.TrackingNo, after.TrackingNo)
	}
	if len(after.Events) != len(before.Events) {
		t.Fatalf("event count changed on error: before=%d after=%d", len(before.Events), len(after.Events))
	}
}
