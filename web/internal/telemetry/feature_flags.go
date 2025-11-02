package telemetry

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	featureFlagState = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: "hanko",
		Subsystem: "web",
		Name:      "feature_flag_enabled",
		Help:      "Feature flag state (1 enabled, 0 disabled) labelled by flag, source, and version.",
	}, []string{"flag", "source", "version"})

	featureFlagLastRefresh = prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: "hanko",
		Subsystem: "web",
		Name:      "feature_flags_last_refresh_timestamp",
		Help:      "Unix timestamp of the last successful feature flag refresh.",
	})
)

func init() {
	prometheus.MustRegister(featureFlagState, featureFlagLastRefresh)
}

// RecordFeatureFlagMetrics emits Prometheus metrics reflecting the current feature flag state.
func RecordFeatureFlagMetrics(source, version string, flags map[string]bool) {
	if source == "" {
		source = "unknown"
	}
	if version == "" {
		version = "unknown"
	}

	featureFlagState.Reset()
	for flag, enabled := range flags {
		value := 0.0
		if enabled {
			value = 1.0
		}
		featureFlagState.WithLabelValues(flag, source, version).Set(value)
	}
	featureFlagLastRefresh.Set(float64(time.Now().Unix()))
}
