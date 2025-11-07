//go:build integration

package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os/exec"
	"strings"
	"sync"
	"testing"
	"time"

	"google.golang.org/api/iterator"

	pconfig "github.com/hanko-field/api/internal/platform/config"
	pfirestore "github.com/hanko-field/api/internal/platform/firestore"
	"github.com/hanko-field/api/internal/repositories/firestore"
	"github.com/hanko-field/api/internal/services"
)

func TestInternalCheckoutReserveStock_Concurrency(t *testing.T) {
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("docker not available: " + err.Error())
	}

	ensureDockerDaemon(t)

	port := freePort(t)
	endpoint := fmt.Sprintf("127.0.0.1:%d", port)
	containerID := startFirestoreEmulator(t, port)
	t.Cleanup(func() { stopContainer(containerID) })

	waitForEndpoint(t, endpoint, 30*time.Second)

	cfg := pconfig.FirestoreConfig{
		ProjectID:    "internal-checkout-concurrency",
		EmulatorHost: endpoint,
	}

	provider := pfirestore.NewProvider(cfg)
	t.Cleanup(func() { _ = provider.Close(context.Background()) })

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	client, err := provider.Client(ctx)
	if err != nil {
		t.Fatalf("firestore client: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	baseTime := time.Now().UTC().Truncate(time.Second)
	seedStock := map[string]any{
		"sku":         "SKU-001",
		"productRef":  "/products/p1",
		"onHand":      3,
		"reserved":    0,
		"available":   3,
		"safetyStock": 0,
		"safetyDelta": 3,
		"updatedAt":   baseTime,
	}

	if _, err := client.Collection("inventory").Doc("SKU-001").Set(ctx, seedStock); err != nil {
		t.Fatalf("seed stock: %v", err)
	}

	repo, err := firestore.NewInventoryRepository(provider)
	if err != nil {
		t.Fatalf("inventory repository: %v", err)
	}

	clockNow := baseTime
	inventoryService, err := services.NewInventoryService(services.InventoryServiceDeps{
		Inventory: repo,
		Clock: func() time.Time {
			return clockNow
		},
	})
	if err != nil {
		t.Fatalf("inventory service: %v", err)
	}

	metrics := &recordingReservationMetrics{}
	handler := NewInternalCheckoutHandlers(
		inventoryService,
		WithInternalCheckoutMetrics(metrics),
	)

	router := NewRouter(WithInternalRoutes(handler.Routes))

	payloadTemplate := map[string]any{
		"userRef": "/users/u_concurrency",
		"lines": []map[string]any{
			{
				"productRef": "/products/p1",
				"sku":        "SKU-001",
				"qty":        2,
			},
		},
		"ttlSec": 900,
	}

	type result struct {
		status int
		body   []byte
	}

	results := make(chan result, 2)
	var wg sync.WaitGroup
	start := make(chan struct{})

	orders := []string{"o_first", "o_second"}
	for _, order := range orders {
		wg.Add(1)
		go func(orderID string) {
			defer wg.Done()
			<-start

			payload := cloneMapCopy(payloadTemplate)
			payload["orderId"] = orderID

			data, err := json.Marshal(payload)
			if err != nil {
				t.Errorf("marshal payload: %v", err)
				return
			}

			req := httptest.NewRequest(http.MethodPost, "/api/v1/internal/checkout/reserve-stock", bytes.NewReader(data))
			req.Header.Set("Content-Type", "application/json")
			rr := httptest.NewRecorder()
			router.ServeHTTP(rr, req)

			results <- result{status: rr.Code, body: rr.Body.Bytes()}
		}(order)
	}

	close(start)
	wg.Wait()
	close(results)

	var successBody []byte
	statuses := make(map[int]int)
	for res := range results {
		statuses[res.status]++
		if res.status == http.StatusOK {
			successBody = res.body
		}
	}

	if statuses[http.StatusOK] != 1 || statuses[http.StatusConflict] != 1 {
		t.Fatalf("expected one success and one conflict, got %+v", statuses)
	}

	var successResp internalReserveStockResponse
	if err := json.Unmarshal(successBody, &successResp); err != nil {
		t.Fatalf("parse success response: %v", err)
	}
	if successResp.ReservationID == "" {
		t.Fatalf("expected reservationId in success response")
	}

	stockSnap, err := client.Collection("inventory").Doc("SKU-001").Get(ctx)
	if err != nil {
		t.Fatalf("fetch stock: %v", err)
	}
	reservedVal := stockSnap.Data()["reserved"]
	var reserved int64
	switch v := reservedVal.(type) {
	case int64:
		reserved = v
	case int:
		reserved = int64(v)
	default:
		t.Fatalf("unexpected reserved type %T", reservedVal)
	}
	if reserved != 2 {
		t.Fatalf("expected reserved 2, got %d", reserved)
	}

	iter := client.Collection("stockReservations").Documents(ctx)
	reservedCount := 0
	for {
		_, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			t.Fatalf("list reservations: %v", err)
		}
		reservedCount++
	}
	if reservedCount != 1 {
		t.Fatalf("expected 1 reservation, got %d", reservedCount)
	}

	metrics.mu.Lock()
	created := metrics.created
	failureReasons := append([]string(nil), metrics.failures...)
	metrics.mu.Unlock()

	if created != 1 {
		t.Fatalf("expected metrics created=1, got %d", created)
	}
	if len(failureReasons) == 0 {
		t.Fatalf("expected failure metrics to be recorded")
	}
	if failureReasons[len(failureReasons)-1] != "insufficient_stock" {
		t.Fatalf("expected last failure reason insufficient_stock, got %v", failureReasons)
	}
}

func TestInternalCheckoutReserveStock_TTLPropagation(t *testing.T) {
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("docker not available: " + err.Error())
	}

	ensureDockerDaemon(t)

	port := freePort(t)
	endpoint := fmt.Sprintf("127.0.0.1:%d", port)
	containerID := startFirestoreEmulator(t, port)
	t.Cleanup(func() { stopContainer(containerID) })

	waitForEndpoint(t, endpoint, 30*time.Second)

	cfg := pconfig.FirestoreConfig{
		ProjectID:    "internal-checkout-ttl",
		EmulatorHost: endpoint,
	}

	provider := pfirestore.NewProvider(cfg)
	t.Cleanup(func() { _ = provider.Close(context.Background()) })

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	client, err := provider.Client(ctx)
	if err != nil {
		t.Fatalf("firestore client: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	baseTime := time.Date(2025, 1, 1, 9, 0, 0, 0, time.UTC)
	seedStock := map[string]any{
		"sku":         "SKU-002",
		"productRef":  "/products/p2",
		"onHand":      5,
		"reserved":    0,
		"available":   5,
		"safetyStock": 0,
		"safetyDelta": 5,
		"updatedAt":   baseTime,
	}

	if _, err := client.Collection("inventory").Doc("SKU-002").Set(ctx, seedStock); err != nil {
		t.Fatalf("seed stock: %v", err)
	}

	repo, err := firestore.NewInventoryRepository(provider)
	if err != nil {
		t.Fatalf("inventory repository: %v", err)
	}

	inventoryService, err := services.NewInventoryService(services.InventoryServiceDeps{
		Inventory: repo,
		Clock: func() time.Time {
			return baseTime
		},
	})
	if err != nil {
		t.Fatalf("inventory service: %v", err)
	}

	metrics := &recordingReservationMetrics{}
	handler := NewInternalCheckoutHandlers(
		inventoryService,
		WithInternalCheckoutMetrics(metrics),
	)

	router := NewRouter(WithInternalRoutes(handler.Routes))

	payload := map[string]any{
		"orderId": "o_ttl",
		"userRef": "/users/u_ttl",
		"ttlSec":  600,
		"lines": []map[string]any{
			{
				"productRef": "/products/p2",
				"sku":        "SKU-002",
				"qty":        3,
			},
		},
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/api/v1/internal/checkout/reserve-stock", bytes.NewReader(data))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d body=%s", rr.Code, rr.Body.String())
	}

	var resp internalReserveStockResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("parse response: %v", err)
	}

	if resp.TTLSeconds != 600 {
		t.Fatalf("expected ttlSec 600, got %d", resp.TTLSeconds)
	}

	if resp.ExpiresAt == "" {
		t.Fatalf("expected expiresAt value")
	}

	expiresAt, err := time.Parse(time.RFC3339Nano, resp.ExpiresAt)
	if err != nil {
		t.Fatalf("parse expiresAt: %v", err)
	}

	expectedExpiry := baseTime.Add(600 * time.Second)
	if !expiresAt.Equal(expectedExpiry) {
		t.Fatalf("expected expiresAt %s, got %s", expectedExpiry.Format(time.RFC3339Nano), expiresAt.Format(time.RFC3339Nano))
	}

	resSnap, err := client.Collection("stockReservations").Where("orderRef", "==", "/orders/o_ttl").Documents(ctx).Next()
	if err != nil {
		t.Fatalf("fetch reservation: %v", err)
	}
	stored := resSnap.Data()
	storedExpiry := stored["expiresAt"].(time.Time)
	if !storedExpiry.Equal(expectedExpiry) {
		t.Fatalf("expected stored expiresAt %s, got %s", expectedExpiry, storedExpiry)
	}

	metrics.mu.Lock()
	created := metrics.created
	failures := len(metrics.failures)
	metrics.mu.Unlock()

	if created != 1 {
		t.Fatalf("expected metrics created=1, got %d", created)
	}
	if failures != 0 {
		t.Fatalf("expected no failures recorded, got %d", failures)
	}
}

type recordingReservationMetrics struct {
	mu       sync.Mutex
	created  int
	failures []string
}

func (m *recordingReservationMetrics) RecordCreated(context.Context, time.Duration, int) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.created++
}

func (m *recordingReservationMetrics) RecordFailure(_ context.Context, reason string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.failures = append(m.failures, reason)
}

func cloneMapCopy(in map[string]any) map[string]any {
	out := make(map[string]any, len(in))
	for k, v := range in {
		switch value := v.(type) {
		case []map[string]any:
			copied := make([]map[string]any, len(value))
			for i, m := range value {
				copied[i] = cloneMapCopy(m)
			}
			out[k] = copied
		case map[string]any:
			out[k] = cloneMapCopy(value)
		default:
			out[k] = value
		}
	}
	return out
}

func startFirestoreEmulator(t *testing.T, port int) string {
	t.Helper()
	args := []string{
		"run", "-d", "--rm",
		"-p", fmt.Sprintf("%d:8080", port),
		firestoreEmulatorImage,
		"gcloud", "beta", "emulators", "firestore", "start",
		"--host-port=0.0.0.0:8080",
		"--quiet",
	}

	cmd := exec.Command("docker", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("failed to start firestore emulator: %v - %s", err, string(out))
	}
	id := strings.TrimSpace(string(out))
	if id == "" {
		t.Fatalf("docker returned empty container id")
	}
	if len(id) > 12 {
		id = id[:12]
	}
	return id
}

func stopContainer(id string) {
	if id == "" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "docker", "stop", id)
	_ = cmd.Run()
}

func ensureDockerDaemon(t *testing.T) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := exec.CommandContext(ctx, "docker", "info").Run(); err != nil {
		t.Skip("docker daemon unavailable: " + err.Error())
	}
}

func waitForEndpoint(t *testing.T, address string, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", address, 500*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return
		}
		time.Sleep(200 * time.Millisecond)
	}
	t.Fatalf("firestore emulator not reachable at %s", address)
}

func freePort(t *testing.T) int {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen tcp: %v", err)
	}
	defer ln.Close()
	return ln.Addr().(*net.TCPAddr).Port
}

const firestoreEmulatorImage = "gcr.io/google.com/cloudsdktool/cloud-sdk:emulators"
