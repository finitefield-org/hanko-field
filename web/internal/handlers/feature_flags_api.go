package handlers

import (
	"encoding/json"
	"net/http"
	"time"
)

// FeatureFlagsAPIHandler returns the current feature flag payload for dynamic fetches.
func FeatureFlagsAPIHandler(w http.ResponseWriter, r *http.Request) {
	ff := LoadFeatureFlags()
	payload := map[string]any{
		"flags":    ff.Flags,
		"variants": ff.Variants,
		"source":   ff.Source,
		"version":  ff.Version,
	}
	if !ff.FetchedAt.IsZero() {
		payload["fetchedAt"] = ff.FetchedAt.UTC().Format(time.RFC3339)
	}
	if len(ff.Raw) > 0 {
		payload["meta"] = ff.Raw
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store, max-age=0, must-revalidate")
	w.Header().Set("Pragma", "no-cache")
	w.Header().Set("X-Feature-Flags-Version", ff.Version)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		http.Error(w, `{"error":"failed to encode feature flags"}`, http.StatusInternalServerError)
	}
}
