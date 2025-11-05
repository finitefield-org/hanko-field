package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/services"
)

func TestInternalMaintenanceCleanup_Defaults(t *testing.T) {
	inventory := &stubMaintenanceInventory{}
	metrics := &stubMaintenanceMetrics{}
	inventory.releaseFn = func(ctx context.Context, cmd services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error) {
		inventory.lastCmd = cmd
		return services.InventoryReleaseExpiredResult{
			CheckedCount:         5,
			ReleasedCount:        3,
			AlreadyReleasedCount: 1,
			NotFoundCount:        1,
			ReservationIDs:       []string{"r1", "r2", "r3"},
			AlreadyReleasedIDs:   []string{"r4"},
			SKUs:                 []string{"sku1", "sku2"},
			SkippedCount:         2,
			SkippedIDs:           []string{"r5", "r6"},
		}, nil
	}

	handler := NewInternalMaintenanceHandlers(inventory, WithMaintenanceMetrics(metrics))

	req := httptest.NewRequest(http.MethodPost, "/internal/maintenance/cleanup-reservations", http.NoBody)
	resp := httptest.NewRecorder()

	handler.cleanupReservations(resp, req)

	if resp.Code != http.StatusOK {
		t.Fatalf("unexpected status: got %d, want %d", resp.Code, http.StatusOK)
	}

	var payload internalMaintenanceCleanupResponse
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if inventory.lastCmd.ActorID != defaultCleanupActorID {
		t.Fatalf("expected default actor %q, got %q", defaultCleanupActorID, inventory.lastCmd.ActorID)
	}
	if inventory.lastCmd.Reason != defaultCleanupReason {
		t.Fatalf("expected default reason %q, got %q", defaultCleanupReason, inventory.lastCmd.Reason)
	}

	if len(metrics.runs) != 1 {
		t.Fatalf("expected 1 metrics run, got %d", len(metrics.runs))
	}
	run := metrics.runs[0]
	if run.checked != 5 || run.released != 3 || run.already != 1 || run.skipped != 2 {
		t.Fatalf("unexpected metrics run: %+v", run)
	}
	if len(metrics.failures) != 0 {
		t.Fatalf("expected no failure metrics, got %v", metrics.failures)
	}

	if len(payload.ReservationIDs) == 0 || payload.ReservationIDs[0] != "r1" {
		t.Fatalf("expected reservation ids to be populated, got %+v", payload.ReservationIDs)
	}
	if len(payload.Skus) == 0 {
		t.Fatalf("expected skus to be populated")
	}
}

func TestInternalMaintenanceCleanup_CustomPayload(t *testing.T) {
	inventory := &stubMaintenanceInventory{}
	metrics := &stubMaintenanceMetrics{}
	handler := NewInternalMaintenanceHandlers(inventory, WithMaintenanceMetrics(metrics))

	payload := `{"limit": 25, "reason": " manual  ", "actorId": " scheduler "}`
	req := httptest.NewRequest(http.MethodPost, "/internal/maintenance/cleanup-reservations", strings.NewReader(payload))
	resp := httptest.NewRecorder()

	handler.cleanupReservations(resp, req)

	if resp.Code != http.StatusOK {
		t.Fatalf("unexpected status: got %d, want %d", resp.Code, http.StatusOK)
	}

	if inventory.lastCmd.Limit != 25 {
		t.Fatalf("expected limit 25, got %d", inventory.lastCmd.Limit)
	}
	if inventory.lastCmd.ActorID != "scheduler" {
		t.Fatalf("expected actor scheduler, got %q", inventory.lastCmd.ActorID)
	}
	if inventory.lastCmd.Reason != "manual" {
		t.Fatalf("expected reason manual, got %q", inventory.lastCmd.Reason)
	}

	var response internalMaintenanceCleanupResponse
	if err := json.Unmarshal(resp.Body.Bytes(), &response); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if response.ReservationIDs == nil || response.AlreadyReleasedIDs == nil || response.Skus == nil || response.SkippedIDs == nil {
		t.Fatalf("expected non-nil slices in response, got %+v", response)
	}
}

func TestInternalMaintenanceCleanup_InvalidLimit(t *testing.T) {
	inventory := &stubMaintenanceInventory{}
	handler := NewInternalMaintenanceHandlers(inventory)

	req := httptest.NewRequest(http.MethodPost, "/internal/maintenance/cleanup-reservations", strings.NewReader(`{"limit": -1}`))
	resp := httptest.NewRecorder()

	handler.cleanupReservations(resp, req)

	if resp.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", resp.Code)
	}
}

func TestInternalMaintenanceCleanup_ServiceError(t *testing.T) {
	inventory := &stubMaintenanceInventory{}
	metrics := &stubMaintenanceMetrics{}
	inventory.releaseFn = func(ctx context.Context, cmd services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error) {
		return services.InventoryReleaseExpiredResult{}, services.ErrInventoryInvalidInput
	}

	handler := NewInternalMaintenanceHandlers(inventory, WithMaintenanceMetrics(metrics))

	req := httptest.NewRequest(http.MethodPost, "/internal/maintenance/cleanup-reservations", http.NoBody)
	resp := httptest.NewRecorder()

	handler.cleanupReservations(resp, req)

	if resp.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", resp.Code)
	}
	if len(metrics.failures) != 1 || metrics.failures[0] != "invalid_request" {
		t.Fatalf("expected failure metric invalid_request, got %v", metrics.failures)
	}
}

func TestInternalMaintenanceCleanup_ServiceUnavailable(t *testing.T) {
	handler := NewInternalMaintenanceHandlers(nil)
	req := httptest.NewRequest(http.MethodPost, "/internal/maintenance/cleanup-reservations", http.NoBody)
	resp := httptest.NewRecorder()

	handler.cleanupReservations(resp, req)

	if resp.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected status 503, got %d", resp.Code)
	}
}

type stubMaintenanceInventory struct {
	releaseFn func(ctx context.Context, cmd services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error)
	lastCmd   services.ReleaseExpiredReservationsCommand
}

func (s *stubMaintenanceInventory) ReserveStocks(context.Context, services.InventoryReserveCommand) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubMaintenanceInventory) CommitReservation(context.Context, services.InventoryCommitCommand) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubMaintenanceInventory) GetReservation(context.Context, string) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubMaintenanceInventory) ReleaseReservation(context.Context, services.InventoryReleaseCommand) (services.InventoryReservation, error) {
	return services.InventoryReservation{}, errors.New("not implemented")
}

func (s *stubMaintenanceInventory) ReleaseExpiredReservations(ctx context.Context, cmd services.ReleaseExpiredReservationsCommand) (services.InventoryReleaseExpiredResult, error) {
	s.lastCmd = cmd
	if s.releaseFn != nil {
		return s.releaseFn(ctx, cmd)
	}
	return services.InventoryReleaseExpiredResult{}, nil
}

func (s *stubMaintenanceInventory) ListLowStock(context.Context, services.InventoryLowStockFilter) (domain.CursorPage[services.InventorySnapshot], error) {
	return domain.CursorPage[services.InventorySnapshot]{}, errors.New("not implemented")
}

func (s *stubMaintenanceInventory) ConfigureSafetyStock(context.Context, services.ConfigureSafetyStockCommand) (services.InventoryStock, error) {
	return services.InventoryStock{}, errors.New("not implemented")
}

type stubMaintenanceMetrics struct {
	runs     []maintenanceMetricsRun
	failures []string
}

type maintenanceMetricsRun struct {
	checked  int
	released int
	already  int
	skipped  int
}

func (m *stubMaintenanceMetrics) RecordRun(ctx context.Context, checked, released, alreadyReleased, skipped int) {
	m.runs = append(m.runs, maintenanceMetricsRun{checked: checked, released: released, already: alreadyReleased, skipped: skipped})
}

func (m *stubMaintenanceMetrics) RecordFailure(ctx context.Context, code string) {
	m.failures = append(m.failures, code)
}
