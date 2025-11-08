package httpserver

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	adminnotifications "finitefield.org/hanko-admin/internal/admin/notifications"
	adminorders "finitefield.org/hanko-admin/internal/admin/orders"
)

const defaultUptimeTimeout = 3 * time.Second

// UptimeProbeConfig captures configuration for synthetic uptime probes.
type UptimeProbeConfig struct {
	Enabled      bool
	Timeout      time.Duration
	ServiceToken string
}

type uptimeDependencies struct {
	Orders        adminorders.Service
	Notifications adminnotifications.Service
}

type uptimeHandlers struct {
	enabled       bool
	token         string
	timeout       time.Duration
	orders        adminorders.Service
	notifications adminnotifications.Service
}

const uptimeAuthHeader = "X-Hanko-Uptime-Token"

func newUptimeHandlers(cfg UptimeProbeConfig, deps uptimeDependencies) *uptimeHandlers {
	if !cfg.Enabled {
		return nil
	}

	timeout := cfg.Timeout
	if timeout <= 0 {
		timeout = defaultUptimeTimeout
	}

	orders := deps.Orders
	if orders == nil {
		orders = adminorders.NewStaticService()
	}

	notifications := deps.Notifications
	if notifications == nil {
		notifications = adminnotifications.NewStaticService()
	}

	return &uptimeHandlers{
		enabled:       true,
		token:         strings.TrimSpace(cfg.ServiceToken),
		timeout:       timeout,
		orders:        orders,
		notifications: notifications,
	}
}

func mountUptimeRoutes(router chi.Router, base string, handlers *uptimeHandlers) {
	if router == nil || handlers == nil || !handlers.enabled {
		return
	}

	prefix := normalizeBasePath(base)
	if prefix == "/" {
		prefix = ""
	}
	route := prefix + "/uptime"

	router.Route(route, func(r chi.Router) {
		r.Get("/orders", handlers.ordersProbe)
		r.Get("/notifications", handlers.notificationsProbe)
	})
}

func (h *uptimeHandlers) ordersProbe(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}
	h.runProbe(w, r, "orders", func(ctx context.Context) (map[string]any, error) {
		if h.orders == nil {
			return nil, errors.New("orders service unavailable")
		}
		result, err := h.orders.List(ctx, h.token, adminorders.Query{PageSize: 1})
		if err != nil {
			return nil, err
		}
		details := map[string]any{
			"totalOrders":   result.Summary.TotalOrders,
			"sampledOrders": len(result.Orders),
		}
		if !result.Summary.LastRefreshedAt.IsZero() {
			details["lastRefreshedAt"] = result.Summary.LastRefreshedAt.UTC().Format(time.RFC3339Nano)
		}
		return details, nil
	})
}

func (h *uptimeHandlers) notificationsProbe(w http.ResponseWriter, r *http.Request) {
	if !h.authorize(w, r) {
		return
	}
	h.runProbe(w, r, "notifications", func(ctx context.Context) (map[string]any, error) {
		if h.notifications == nil {
			return nil, errors.New("notifications service unavailable")
		}
		feed, err := h.notifications.List(ctx, h.token, adminnotifications.Query{Limit: 1})
		if err != nil {
			return nil, err
		}
		return map[string]any{
			"openNotifications":    feed.Counts.Open,
			"totalNotifications":   feed.Total,
			"sampledNotifications": len(feed.Items),
		}, nil
	})
}

func (h *uptimeHandlers) runProbe(w http.ResponseWriter, r *http.Request, component string, probe func(context.Context) (map[string]any, error)) {
	start := time.Now()
	ctx, cancel := context.WithTimeout(r.Context(), h.timeout)
	defer cancel()

	status := http.StatusOK
	state := "ok"
	details := map[string]any{}

	if probe != nil {
		payload, err := probe(ctx)
		if err != nil {
			status = http.StatusServiceUnavailable
			state = "error"
			details["error"] = err.Error()
		} else if payload != nil {
			for k, v := range payload {
				details[k] = v
			}
		}
	}

	h.writeProbeResponse(w, status, component, state, time.Since(start), details)
}

func (h *uptimeHandlers) writeProbeResponse(w http.ResponseWriter, status int, component, state string, latency time.Duration, details map[string]any) {
	if details == nil {
		details = map[string]any{}
	}
	details["component"] = component
	details["status"] = state
	details["latencyMs"] = latency.Milliseconds()
	details["checkedAt"] = time.Now().UTC().Format(time.RFC3339Nano)

	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(details)
}

func (h *uptimeHandlers) authorize(w http.ResponseWriter, r *http.Request) bool {
	if h == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return false
	}
	if h.token == "" {
		return true
	}
	token := strings.TrimSpace(r.Header.Get(uptimeAuthHeader))
	if token == "" {
		token = parseBearerToken(r.Header.Get("Authorization"))
	}
	if token == "" {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return false
	}
	if subtle.ConstantTimeCompare([]byte(token), []byte(h.token)) != 1 {
		http.Error(w, http.StatusText(http.StatusForbidden), http.StatusForbidden)
		return false
	}
	return true
}

func parseBearerToken(header string) string {
	if header == "" {
		return ""
	}
	head := strings.TrimSpace(header)
	if len(head) < 7 {
		return ""
	}
	if strings.HasPrefix(strings.ToLower(head), "bearer ") {
		return strings.TrimSpace(head[7:])
	}
	return ""
}
