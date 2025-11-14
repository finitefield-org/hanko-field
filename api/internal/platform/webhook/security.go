package webhook

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/platform/requestctx"
)

const defaultReplayTTL = 5 * time.Minute

// SecurityConfig controls the behaviour of the webhook security middleware.
type SecurityConfig struct {
	AllowedNetworks []*net.IPNet
	ReplayStore     ReplayStore
	ReplayTTL       time.Duration
	Logger          *zap.Logger
	Metrics         MetricsRecorder
	Clock           func() time.Time
}

// NewSecurityMiddleware constructs middleware enforcing webhook security policies.
func NewSecurityMiddleware(cfg SecurityConfig) func(http.Handler) http.Handler {
	clock := cfg.Clock
	if clock == nil {
		clock = time.Now
	}
	logger := cfg.Logger
	if logger == nil {
		logger = zap.NewNop()
	}
	ttl := cfg.ReplayTTL
	if ttl <= 0 {
		ttl = defaultReplayTTL
	}
	networks := cfg.AllowedNetworks
	store := cfg.ReplayStore
	metrics := cfg.Metrics

	return func(next http.Handler) http.Handler {
		if next == nil {
			next = http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := clock()
			ctx := r.Context()
			reqLogger := requestLogger(ctx, logger)
			outcome := "allowed"

			defer func() {
				if metrics != nil {
					metrics.Record(ctx, outcome, clock().Sub(start))
				}
			}()

			if len(networks) > 0 {
				ip, err := ExtractClientIP(r)
				if err != nil {
					outcome = "blocked_ip_parse"
					reqLogger.Warn("webhook blocked: unable to parse client ip",
						zap.String("reason", "ip_parse_error"),
						zap.Error(err),
					)
					httpx.WriteError(ctx, w, httpx.NewError("webhook_forbidden", "source ip not allowed", http.StatusForbidden))
					return
				}
				if !containsIP(networks, ip) {
					outcome = "blocked_ip"
					reqLogger.Warn("webhook blocked: source ip not allowed",
						zap.String("reason", "ip_forbidden"),
						zap.String("remote_ip", ip.String()),
					)
					httpx.WriteError(ctx, w, httpx.NewError("webhook_forbidden", "source ip not allowed", http.StatusForbidden))
					return
				}
			}

			token, ok := replayTokenFromRequest(r)
			if !ok || store == nil {
				if !ok {
					outcome = "allowed_no_signature"
				}
				next.ServeHTTP(w, r)
				return
			}

			expiry := token.Timestamp.Add(ttl)
			now := clock()
			if expiry.Before(now) {
				expiry = now.Add(ttl)
			}

			key := buildReplayKey(token, r)
			stored, err := store.Record(ctx, key, expiry)
			if err != nil {
				outcome = "replay_store_error"
				reqLogger.Error("webhook replay store error",
					zap.String("reason", "store_error"),
					zap.Error(err),
				)
				httpx.WriteError(ctx, w, httpx.NewError("webhook_replay_unavailable", "webhook replay protection unavailable", http.StatusServiceUnavailable))
				return
			}
			if !stored {
				outcome = "replay_detected"
				reqLogger.Warn("webhook blocked: replay detected",
					zap.String("reason", "replay"),
					zap.String("signature_hash", token.SignatureHash()),
					zap.String("source", token.Source),
				)
				httpx.WriteError(ctx, w, httpx.NewError("webhook_replay_detected", "duplicate webhook detected", http.StatusConflict))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func requestLogger(ctx context.Context, fallback *zap.Logger) *zap.Logger {
	logger := requestctx.Logger(ctx)
	if logger == nil || logger == requestctx.NoopLogger() {
		return fallback
	}
	return logger
}

func containsIP(networks []*net.IPNet, ip net.IP) bool {
	if ip == nil {
		return false
	}
	for _, network := range networks {
		if network == nil {
			continue
		}
		if network.Contains(ip) {
			return true
		}
	}
	return false
}

type replayToken struct {
	Signature string
	Timestamp time.Time
	Source    string
}

func (t replayToken) SignatureHash() string {
	if t.Signature == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(t.Signature))
	return hex.EncodeToString(sum[:8])
}

func replayTokenFromRequest(r *http.Request) (replayToken, bool) {
	if r == nil {
		return replayToken{}, false
	}
	if meta, ok := auth.HMACMetadataFromContext(r.Context()); ok && meta != nil {
		if len(meta.RawSignature) > 0 && !meta.Timestamp.IsZero() {
			return replayToken{
				Signature: meta.RawSignature,
				Timestamp: meta.Timestamp.UTC(),
				Source:    "hmac",
			}, true
		}
	}

	signatureHeader := strings.TrimSpace(r.Header.Get("Stripe-Signature"))
	if signatureHeader != "" {
		token, err := parseStripeSignature(signatureHeader)
		if err == nil {
			return token, true
		}
	}

	return replayToken{}, false
}

func parseStripeSignature(header string) (replayToken, error) {
	if header == "" {
		return replayToken{}, errors.New("webhook: stripe signature empty")
	}

	var (
		timestamp string
		signature string
	)
	parts := strings.Split(header, ",")
	for _, part := range parts {
		kv := strings.SplitN(strings.TrimSpace(part), "=", 2)
		if len(kv) != 2 {
			continue
		}
		switch strings.ToLower(kv[0]) {
		case "t":
			timestamp = kv[1]
		case "v1":
			if signature == "" {
				signature = kv[1]
			}
		}
	}
	if timestamp == "" || signature == "" {
		return replayToken{}, errors.New("webhook: stripe signature missing fields")
	}

	sec, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return replayToken{}, fmt.Errorf("webhook: stripe timestamp invalid: %w", err)
	}

	return replayToken{
		Signature: signature,
		Timestamp: time.Unix(sec, 0).UTC(),
		Source:    "stripe",
	}, nil
}

func buildReplayKey(token replayToken, r *http.Request) string {
	path := "/"
	if r != nil && r.URL != nil && r.URL.Path != "" {
		path = strings.ToLower(strings.TrimSpace(r.URL.Path))
	}
	ts := token.Timestamp.UTC().Format(time.RFC3339Nano)
	return strings.Join([]string{token.Signature, ts, path}, "|")
}
