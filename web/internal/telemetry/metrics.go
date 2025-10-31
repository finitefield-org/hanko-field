package telemetry

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	requestDuration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Namespace: "hanko",
		Subsystem: "web",
		Name:      "http_request_duration_seconds",
		Help:      "Duration of HTTP requests processed by the web service.",
		Buckets:   []float64{0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10},
	}, []string{"method", "route", "status"})

	requestTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Namespace: "hanko",
		Subsystem: "web",
		Name:      "http_requests_total",
		Help:      "Total number of HTTP requests handled by the web service.",
	}, []string{"method", "route", "status"})

	appStartTime = time.Now()

	appUptime = prometheus.NewGaugeFunc(prometheus.GaugeOpts{
		Namespace: "hanko",
		Subsystem: "web",
		Name:      "uptime_seconds",
		Help:      "Seconds since the web service process started.",
	}, func() float64 {
		return time.Since(appStartTime).Seconds()
	})
)

func init() {
	prometheus.MustRegister(requestDuration, requestTotal, appUptime)
}

// ObserveHTTPRequest records request metrics for Prometheus.
func ObserveHTTPRequest(method, route string, status int, duration time.Duration) {
	labels := prometheus.Labels{
		"method": method,
		"route":  route,
		"status": strconv.Itoa(status),
	}
	requestTotal.With(labels).Inc()
	requestDuration.With(labels).Observe(duration.Seconds())
}

// MetricsHandler exposes the Prometheus metrics endpoint.
func MetricsHandler() http.Handler {
	return promhttp.Handler()
}
