package middleware

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"

	"finitefield.org/hanko-admin/internal/admin/observability"
)

// Metrics instruments HTTP handlers with latency/error metrics.
func Metrics(recorder *observability.Metrics) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		if next == nil {
			next = http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})
		}
		if recorder == nil || !recorder.Enabled() {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			wrapped := chimw.NewWrapResponseWriter(w, r.ProtoMajor)

			next.ServeHTTP(wrapped, r)

			status := wrapped.Status()
			if status == 0 {
				status = http.StatusOK
			}

			kind := observability.RequestKindPage
			htmxInfo := HTMXInfoFromContext(r.Context())
			if htmxInfo.IsHTMX {
				kind = observability.RequestKindFragment
			}

			recorder.RecordHTTPRequest(r.Context(), observability.HTTPRequestAttributes{
				Method:         r.Method,
				Route:          routePattern(r),
				Status:         status,
				Kind:           kind,
				FragmentTarget: htmxInfo.Target,
			}, time.Since(start))
		})
	}
}

func routePattern(r *http.Request) string {
	if r == nil {
		return "/"
	}
	if ctx := chiRouteContext(r.Context()); ctx != "" {
		return ctx
	}
	if r.URL != nil && strings.TrimSpace(r.URL.Path) != "" {
		return r.URL.Path
	}
	return "/"
}

func chiRouteContext(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	if routeCtx := chi.RouteContext(ctx); routeCtx != nil {
		if pattern := strings.TrimSpace(routeCtx.RoutePattern()); pattern != "" {
			return pattern
		}
	}
	return ""
}
