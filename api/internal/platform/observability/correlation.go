package observability

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5/middleware"
	"github.com/oklog/ulid/v2"

	"github.com/hanko-field/api/internal/platform/requestctx"
)

const (
	defaultCorrelationIDHeader = "X-Correlation-ID"
	defaultRequestIDHeader     = "X-Request-ID"
)

type correlationOptions struct {
	headerName     string
	responseHeader string
	generator      func() string
}

// CorrelationOption customises correlation middleware behaviour.
type CorrelationOption func(*correlationOptions)

// WithCorrelationIDHeader overrides the header used for correlation IDs.
func WithCorrelationIDHeader(name string) CorrelationOption {
	return func(cfg *correlationOptions) {
		name = strings.TrimSpace(name)
		if name == "" {
			return
		}
		cfg.headerName = name
		cfg.responseHeader = name
	}
}

// WithCorrelationIDGenerator sets a custom generator used when no ID is provided.
func WithCorrelationIDGenerator(fn func() string) CorrelationOption {
	return func(cfg *correlationOptions) {
		if fn == nil {
			return
		}
		cfg.generator = fn
	}
}

// CorrelationIDMiddleware ensures every request has a correlation ID stored on the context and echoed via headers.
func CorrelationIDMiddleware(opts ...CorrelationOption) func(http.Handler) http.Handler {
	cfg := correlationOptions{
		headerName:     defaultCorrelationIDHeader,
		responseHeader: defaultCorrelationIDHeader,
		generator: func() string {
			return ulid.Make().String()
		},
	}
	for _, opt := range opts {
		if opt != nil {
			opt(&cfg)
		}
	}

	return func(next http.Handler) http.Handler {
		if next == nil {
			next = http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()
			correlationID := sanitizeCorrelationID(r.Header.Get(cfg.headerName))
			if correlationID == "" {
				// Fall back to standard request ID header populated by chi middleware.
				correlationID = sanitizeCorrelationID(r.Header.Get(defaultRequestIDHeader))
			}
			if correlationID == "" {
				correlationID = sanitizeCorrelationID(middleware.GetReqID(ctx))
			}
			if correlationID == "" && cfg.generator != nil {
				correlationID = sanitizeCorrelationID(cfg.generator())
			}
			if correlationID != "" {
				ctx = requestctx.WithCorrelationID(ctx, correlationID)
				w.Header().Set(cfg.responseHeader, correlationID)
			}
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func sanitizeCorrelationID(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	sanitized := sanitizeString(value, 80)
	if sanitized == "" {
		return ""
	}
	sanitized = strings.Map(func(r rune) rune {
		switch r {
		case '\r', '\n', '\t':
			return -1
		default:
			return r
		}
	}, sanitized)
	sanitized = strings.TrimSpace(sanitized)
	return sanitized
}
