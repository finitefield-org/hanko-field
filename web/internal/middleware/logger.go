package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"

	"finitefield.org/hanko-web/internal/telemetry"
)

// Logger emits a structured JSON log per request and feeds metrics observers.
func Logger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := NewResponseRecorder(w)

		next.ServeHTTP(rw, r)

		rid := chimw.GetReqID(r.Context())
		if rid != "" {
			r = r.WithContext(WithRequestID(r.Context(), rid))
		}

		status := rw.Status()
		duration := time.Since(start)
		route := routePattern(r)

		telemetry.ObserveHTTPRequest(r.Method, route, status, duration)

		logger := ContextLogger(r.Context()).
			With(
				"method", r.Method,
				"path", r.URL.Path,
				"route", route,
				"status", status,
				"duration_ms", duration.Milliseconds(),
			)

		if ip := clientIP(r); ip != "" {
			logger = logger.With("remote_ip", ip)
		}

		logger.Info("http_request")
	})
}

// status capturing now uses ResponseRecorder in wrap.go

func clientIP(r *http.Request) string {
	// Trust X-Forwarded-For set by Cloud Run (last IP is client)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		p := strings.Split(xff, ",")
		return strings.TrimSpace(p[len(p)-1])
	}
	if xrip := r.Header.Get("X-Real-IP"); xrip != "" {
		return xrip
	}
	host := r.RemoteAddr
	if i := strings.LastIndex(host, ":"); i != -1 {
		return host[:i]
	}
	return host
}

func routePattern(r *http.Request) string {
	if rc := chi.RouteContext(r.Context()); rc != nil {
		if pattern := rc.RoutePattern(); pattern != "" {
			return pattern
		}
	}
	return r.URL.Path
}
