package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"finitefield.org/hanko-web/internal/telemetry"
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
		telemetry.Logger().Error("feature flags marshal failed", "error", err)
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
			telemetry.Logger().Warn("feature flags load error", "error", err)
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

	flags = applyFeatureFlagOverrides(flags)

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

	telemetry.RecordFeatureFlagMetrics(featureFlagCache.Source, featureFlagCache.Version, featureFlagCache.Flags)

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
			ff.Source = "remote"
			return ff, nil
		}
		remoteErr = err
		errs = append(errs, fmt.Sprintf("remote: %v", err))
	}

	if raw := strings.TrimSpace(os.Getenv("HANKO_WEB_FEATURE_FLAGS")); raw != "" {
		ff, err := parseFeatureFlags([]byte(raw))
		if err == nil {
			if remoteErr != nil {
				telemetry.Logger().Warn("feature flags remote fetch failed, falling back to env", "error", remoteErr)
			}
			ff.Source = "env"
			return ff, nil
		}
		errs = append(errs, fmt.Sprintf("env: %v", err))
	}

	if file := strings.TrimSpace(os.Getenv("HANKO_WEB_FEATURE_FLAG_FILE")); file != "" {
		ff, err := loadFeatureFlagsFromFile(file)
		if err == nil {
			if remoteErr != nil {
				telemetry.Logger().Warn("feature flags remote fetch failed, falling back to file", "error", remoteErr, "path", file)
			}
			ff.Source = "file"
			return ff, nil
		}
		errs = append(errs, fmt.Sprintf("file: %v", err))
	}

	ff := defaultFeatureFlags()
	if len(errs) > 0 {
		return ff, errors.New(strings.Join(errs, "; "))
	}
	if remoteErr != nil {
		telemetry.Logger().Warn("feature flags remote fetch failed, using defaults", "error", remoteErr)
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

func loadFeatureFlagsFromFile(path string) (FeatureFlags, error) {
	resolvedPath, err := resolveFeatureFlagFile(path)
	if err != nil {
		return FeatureFlags{}, err
	}
	data, err := os.ReadFile(resolvedPath)
	if err != nil {
		return FeatureFlags{}, err
	}
	ff, err := parseFeatureFlags(data)
	if err != nil {
		return FeatureFlags{}, err
	}
	ff.Source = "file"
	if ff.Raw == nil {
		ff.Raw = map[string]any{}
	}
	ff.Raw["file"] = map[string]any{
		"path":   resolvedPath,
		"base":   featureFlagBaseDir(),
		"source": "env:HANKO_WEB_FEATURE_FLAG_FILE",
	}
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
		telemetry.Logger().Warn("feature flags raw metadata parse failed", "error", err)
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

func applyFeatureFlagOverrides(ff FeatureFlags) FeatureFlags {
	raw := strings.TrimSpace(os.Getenv("HANKO_WEB_FEATURE_FLAG_OVERRIDES"))
	if raw == "" {
		return ff
	}
	overrides := parseOverrideList(raw)
	if len(overrides) == 0 {
		return ff
	}
	if ff.Flags == nil {
		ff.Flags = map[string]bool{}
	}
	applied := make(map[string]bool, len(overrides))
	for key, val := range overrides {
		if key == "" {
			continue
		}
		ff.Flags[key] = val
		applied[key] = val
	}
	if len(applied) == 0 {
		return ff
	}
	if !strings.Contains(ff.Source, "override") {
		ff.Source = ff.Source + "+override"
	}
	if ff.Raw == nil {
		ff.Raw = map[string]any{}
	}
	ff.Raw["overrides"] = map[string]any{
		"source": "env:HANKO_WEB_FEATURE_FLAG_OVERRIDES",
		"flags":  applied,
	}
	return ff
}

func parseOverrideList(raw string) map[string]bool {
	result := map[string]bool{}
	splitFn := func(r rune) bool {
		switch r {
		case ',', ';', '\n':
			return true
		default:
			return false
		}
	}
	parts := strings.FieldsFunc(raw, splitFn)
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		keyPart := part
		val := true
		valueProvided := false
		if eq := strings.IndexAny(part, ":="); eq >= 0 {
			keyPart = strings.TrimSpace(part[:eq])
			value := strings.TrimSpace(part[eq+1:])
			parsed, ok := parseOverrideBool(value)
			if !ok {
				continue
			}
			valueProvided = true
			val = parsed
		}
		key := strings.TrimSpace(keyPart)
		if strings.HasPrefix(key, "!") || strings.HasPrefix(key, "-") {
			key = strings.TrimLeft(key, "!-")
			if valueProvided && val {
				telemetry.Logger().Warn("feature flag override conflict", "flag", key, "raw", part)
				continue
			}
			val = false
		}
		key = strings.TrimSpace(key)
		if key == "" {
			continue
		}
		result[key] = val
	}
	return result
}

func parseOverrideBool(raw string) (bool, bool) {
	r := strings.ToLower(strings.TrimSpace(raw))
	switch r {
	case "1", "true", "on", "yes", "enable", "enabled":
		return true, true
	case "0", "false", "off", "no", "disable", "disabled":
		return false, true
	default:
		return false, false
	}
}

func resolveFeatureFlagFile(path string) (string, error) {
	if strings.TrimSpace(path) == "" {
		return "", errors.New("feature flag file path is empty")
	}
	baseDir := featureFlagBaseDir()
	absBase, err := filepath.Abs(baseDir)
	if err != nil {
		return "", fmt.Errorf("failed to resolve feature flag base dir: %w", err)
	}
	if info, err := os.Stat(absBase); err == nil {
		if !info.IsDir() {
			return "", fmt.Errorf("feature flag base dir %q is not a directory", absBase)
		}
	} else if !os.IsNotExist(err) {
		return "", fmt.Errorf("feature flag base dir stat failed: %w", err)
	}
	candidate := path
	if !filepath.IsAbs(candidate) {
		candidate = filepath.Join(absBase, candidate)
	}
	absCandidate, err := filepath.Abs(candidate)
	if err != nil {
		return "", fmt.Errorf("failed to resolve feature flag file path: %w", err)
	}
	rel, err := filepath.Rel(absBase, absCandidate)
	if err != nil {
		return "", fmt.Errorf("failed to evaluate feature flag file path: %w", err)
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("feature flag file %q must be within %q", absCandidate, absBase)
	}
	info, err := os.Stat(absCandidate)
	if err != nil {
		return "", err
	}
	if info.IsDir() {
		return "", fmt.Errorf("feature flag file path %q is a directory", absCandidate)
	}
	return absCandidate, nil
}

func featureFlagBaseDir() string {
	base := strings.TrimSpace(os.Getenv("HANKO_WEB_FEATURE_FLAG_BASE_DIR"))
	if base == "" {
		return "."
	}
	return base
}
