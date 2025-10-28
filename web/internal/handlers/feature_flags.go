package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// FeatureFlags exposes remote configuration and experiment variants to templates.
type FeatureFlags struct {
	Flags     map[string]bool
	Variants  map[string]string
	Raw       map[string]any
	Source    string
	Version   string
	FetchedAt time.Time
}

// Enabled reports whether the named flag is true.
func (ff FeatureFlags) Enabled(key string) bool {
	if ff.Flags == nil {
		return false
	}
	return ff.Flags[key]
}

// Variant returns the assigned variant for an experiment, or fallback when unset.
func (ff FeatureFlags) Variant(key, fallback string) string {
	if ff.Variants != nil {
		if v, ok := ff.Variants[key]; ok {
			return v
		}
	}
	return fallback
}

// JSON serialises the feature flag payload for client-side consumption.
func (ff FeatureFlags) JSON() string {
	flags := ff.Flags
	if flags == nil {
		flags = map[string]bool{}
	}
	variants := ff.Variants
	if variants == nil {
		variants = map[string]string{}
	}
	payload := map[string]any{
		"flags":    flags,
		"variants": variants,
		"source":   ff.Source,
	}
	if !ff.FetchedAt.IsZero() {
		payload["fetchedAt"] = ff.FetchedAt.UTC().Format(time.RFC3339)
	}
	if ff.Version != "" {
		payload["version"] = ff.Version
	}
	if len(ff.Raw) > 0 {
		payload["meta"] = ff.Raw
	}
	b, err := json.Marshal(payload)
	if err != nil {
		log.Printf("featureflags: marshal json: %v", err)
		return "{}"
	}
	return string(b)
}

func (ff FeatureFlags) clone() FeatureFlags {
	out := FeatureFlags{
		Flags:     cloneBoolMap(ff.Flags),
		Variants:  cloneStringMap(ff.Variants),
		Raw:       cloneAnyMap(ff.Raw),
		Source:    ff.Source,
		Version:   ff.Version,
		FetchedAt: ff.FetchedAt,
	}
	return out
}

var (
	featureFlagMu        sync.RWMutex
	featureFlagCache     FeatureFlags
	featureFlagExpiry    time.Time
	featureFlagsLoaded   bool
	featureFlagLastError string
)

const featureFlagTTL = time.Minute

// LoadFeatureFlags fetches remote configuration (with caching) and falls back to local env values.
func LoadFeatureFlags() FeatureFlags {
	now := time.Now()

	featureFlagMu.RLock()
	if featureFlagsLoaded && now.Before(featureFlagExpiry) {
		defer featureFlagMu.RUnlock()
		return featureFlagCache.clone()
	}
	featureFlagMu.RUnlock()

	featureFlagMu.Lock()
	defer featureFlagMu.Unlock()

	if featureFlagsLoaded && now.Before(featureFlagExpiry) {
		return featureFlagCache.clone()
	}

	flags, err := fetchFeatureFlags()
	if err != nil {
		msg := err.Error()
		if msg != featureFlagLastError {
			log.Printf("featureflags: %v", err)
			featureFlagLastError = msg
		}
		if featureFlagsLoaded {
			featureFlagExpiry = now.Add(featureFlagTTL)
			return featureFlagCache.clone()
		}
		flags = defaultFeatureFlags()
	} else {
		featureFlagLastError = ""
	}

	if flags.Flags == nil {
		flags.Flags = map[string]bool{}
	}
	if flags.Variants == nil {
		flags.Variants = map[string]string{}
	}
	if flags.Raw == nil {
		flags.Raw = map[string]any{}
	}
	if flags.Source == "" {
		flags.Source = "default"
	}
	if flags.Version == "" {
		flags.Version = "default"
	}
	if flags.FetchedAt.IsZero() {
		flags.FetchedAt = time.Now()
	}

	featureFlagCache = flags
	featureFlagExpiry = now.Add(featureFlagTTL)
	featureFlagsLoaded = true

	return featureFlagCache.clone()
}

func fetchFeatureFlags() (FeatureFlags, error) {
	var (
		errs      []string
		remoteErr error
	)

	if remoteURL := strings.TrimSpace(os.Getenv("HANKO_WEB_REMOTE_CONFIG_URL")); remoteURL != "" {
		ff, err := loadRemoteFeatureFlags(remoteURL)
		if err == nil {
			return ff, nil
		}
		remoteErr = err
		errs = append(errs, fmt.Sprintf("remote: %v", err))
	}

	if raw := strings.TrimSpace(os.Getenv("HANKO_WEB_FEATURE_FLAGS")); raw != "" {
		ff, err := parseFeatureFlags([]byte(raw))
		if err == nil {
			if remoteErr != nil {
				log.Printf("featureflags: remote fetch failed (%v); using env fallback", remoteErr)
			}
			ff.Source = "env"
			return ff, nil
		}
		errs = append(errs, fmt.Sprintf("env: %v", err))
	}

	ff := defaultFeatureFlags()
	if len(errs) > 0 {
		return ff, errors.New(strings.Join(errs, "; "))
	}
	if remoteErr != nil {
		log.Printf("featureflags: remote fetch failed (%v); falling back to defaults", remoteErr)
	}
	return ff, nil
}

func loadRemoteFeatureFlags(url string) (FeatureFlags, error) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return FeatureFlags{}, err
	}
	req.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return FeatureFlags{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return FeatureFlags{}, fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20)) // 1 MiB cap
	if err != nil {
		return FeatureFlags{}, err
	}

	ff, err := parseFeatureFlags(body)
	if err != nil {
		return FeatureFlags{}, err
	}
	ff.Source = "remote"
	return ff, nil
}

func parseFeatureFlags(raw []byte) (FeatureFlags, error) {
	if len(strings.TrimSpace(string(raw))) == 0 {
		return FeatureFlags{}, errors.New("empty feature flag payload")
	}
	var payload struct {
		Version     string            `json:"version"`
		Flags       map[string]bool   `json:"flags"`
		Variants    map[string]string `json:"variants"`
		Experiments map[string]string `json:"experiments"`
	}
	if err := json.Unmarshal(raw, &payload); err != nil {
		return FeatureFlags{}, err
	}
	var rawMap map[string]any
	if err := json.Unmarshal(raw, &rawMap); err != nil {
		log.Printf("featureflags: parse raw metadata: %v", err)
		rawMap = map[string]any{}
	}
	ff := FeatureFlags{
		Flags:     cloneBoolMap(payload.Flags),
		Variants:  cloneStringMap(payload.Variants),
		Raw:       cloneAnyMap(rawMap),
		Source:    "default",
		Version:   payload.Version,
		FetchedAt: time.Now(),
	}
	if len(payload.Experiments) > 0 {
		if ff.Variants == nil {
			ff.Variants = make(map[string]string, len(payload.Experiments))
		}
		for k, v := range payload.Experiments {
			ff.Variants[k] = v
		}
	}
	return ff, nil
}

func defaultFeatureFlags() FeatureFlags {
	return FeatureFlags{
		Flags:     map[string]bool{},
		Variants:  map[string]string{},
		Raw:       map[string]any{},
		Source:    "default",
		Version:   "default",
		FetchedAt: time.Now(),
	}
}

func cloneBoolMap(src map[string]bool) map[string]bool {
	if len(src) == 0 {
		return map[string]bool{}
	}
	dst := make(map[string]bool, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}

func cloneStringMap(src map[string]string) map[string]string {
	if len(src) == 0 {
		return map[string]string{}
	}
	dst := make(map[string]string, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}

func cloneAnyMap(src map[string]any) map[string]any {
	if len(src) == 0 {
		return map[string]any{}
	}
	dst := make(map[string]any, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}
