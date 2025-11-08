package httpserver

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"

	adminnotifications "finitefield.org/hanko-admin/internal/admin/notifications"
	adminorders "finitefield.org/hanko-admin/internal/admin/orders"
)

func TestOrdersProbeSuccess(t *testing.T) {
	handlers := newUptimeHandlers(UptimeProbeConfig{Enabled: true, ServiceToken: "secret"}, uptimeDependencies{
		Orders:        adminorders.NewStaticService(),
		Notifications: adminnotifications.NewStaticService(),
	})
	if handlers == nil {
		t.Fatal("expected uptime handlers")
	}

	router := chi.NewRouter()
	mountUptimeRoutes(router, "/admin", handlers)

	req := httptest.NewRequest(http.MethodGet, "/admin/uptime/orders", nil)
	req.Header.Set(uptimeAuthHeader, "secret")
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", res.Code)
	}

	var payload map[string]any
	if err := json.Unmarshal(res.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if payload["component"] != "orders" {
		t.Fatalf("unexpected component: %v", payload["component"])
	}
	if payload["status"] != "ok" {
		t.Fatalf("expected status ok, got %v", payload["status"])
	}
	if _, ok := payload["sampledOrders"]; !ok {
		t.Fatalf("expected sampledOrders in payload: %+v", payload)
	}
}

func TestNotificationsProbeFailure(t *testing.T) {
	handlers := newUptimeHandlers(UptimeProbeConfig{Enabled: true, ServiceToken: "secret"}, uptimeDependencies{
		Orders:        adminorders.NewStaticService(),
		Notifications: failingNotificationsService{},
	})
	router := chi.NewRouter()
	mountUptimeRoutes(router, "/admin", handlers)

	req := httptest.NewRequest(http.MethodGet, "/admin/uptime/notifications", nil)
	req.Header.Set(uptimeAuthHeader, "secret")
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", res.Code)
	}

	var payload map[string]any
	if err := json.Unmarshal(res.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if payload["status"] != "error" {
		t.Fatalf("expected error status, got %v", payload["status"])
	}
	if payload["component"] != "notifications" {
		t.Fatalf("unexpected component: %v", payload["component"])
	}
	if payload["error"] == nil {
		t.Fatalf("expected error message in payload: %+v", payload)
	}
}

func TestUptimeProbeUnauthorized(t *testing.T) {
	handlers := newUptimeHandlers(UptimeProbeConfig{Enabled: true, ServiceToken: "secret"}, uptimeDependencies{
		Orders: adminorders.NewStaticService(),
	})
	router := chi.NewRouter()
	mountUptimeRoutes(router, "/admin", handlers)

	req := httptest.NewRequest(http.MethodGet, "/admin/uptime/orders", nil)
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", res.Code)
	}
}

type failingNotificationsService struct{}

func (failingNotificationsService) List(ctx context.Context, token string, query adminnotifications.Query) (adminnotifications.Feed, error) {
	return adminnotifications.Feed{}, errors.New("notifications backend unavailable")
}

func (failingNotificationsService) Badge(ctx context.Context, token string) (adminnotifications.BadgeCount, error) {
	return adminnotifications.BadgeCount{}, errors.New("notifications backend unavailable")
}
