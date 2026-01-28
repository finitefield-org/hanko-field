package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"
	"unicode"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const (
	maxAdminCounterBodySize   = 2 * 1024
	defaultCounterSegmentName = "global"
)

// AdminCounterHandlers exposes endpoints for managing sequence counters used by operations staff.
type AdminCounterHandlers struct {
	authn         *auth.Authenticator
	counters      services.CounterService
	audit         services.AuditLogService
	allowedScopes map[string]struct{}
	clock         func() time.Time
}

// AdminCounterOption customises handler behaviour.
type AdminCounterOption func(*AdminCounterHandlers)

// NewAdminCounterHandlers constructs counter handlers for admin routes.
func NewAdminCounterHandlers(authn *auth.Authenticator, counters services.CounterService, audit services.AuditLogService, opts ...AdminCounterOption) *AdminCounterHandlers {
	handler := &AdminCounterHandlers{
		authn:    authn,
		counters: counters,
		audit:    audit,
		clock: func() time.Time {
			return time.Now().UTC()
		},
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	return handler
}

// WithAdminCounterAllowedScopes restricts the counter scopes that can be manually incremented.
func WithAdminCounterAllowedScopes(scopes ...string) AdminCounterOption {
	return func(h *AdminCounterHandlers) {
		if h == nil {
			return
		}
		if len(scopes) == 0 {
			h.allowedScopes = nil
			return
		}
		h.allowedScopes = make(map[string]struct{}, len(scopes))
		for _, scope := range scopes {
			token, ok := sanitiseCounterToken(scope)
			if ok {
				h.allowedScopes[strings.ToLower(token)] = struct{}{}
			}
		}
	}
}

// WithAdminCounterClock overrides the time source, primarily for deterministic tests.
func WithAdminCounterClock(clock func() time.Time) AdminCounterOption {
	return func(h *AdminCounterHandlers) {
		if h == nil || clock == nil {
			return
		}
		h.clock = func() time.Time {
			return clock().UTC()
		}
	}
}

// Routes registers counter routes under the provided router.
func (h *AdminCounterHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Group(func(rt chi.Router) {
		if h.authn != nil {
			rt.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
		}
		rt.Post("/counters/{name}:next", h.nextCounterValue)
	})
}

type adminNextCounterRequest struct {
	Scope        map[string]string `json:"scope"`
	Step         *int64            `json:"step"`
	MaxValue     *int64            `json:"maxValue"`
	InitialValue *int64            `json:"initialValue"`
	Prefix       *string           `json:"prefix"`
	Suffix       *string           `json:"suffix"`
	PadLength    *int              `json:"padLength"`
}

type adminNextCounterResponse struct {
	Number string `json:"number"`
}

func (h *AdminCounterHandlers) nextCounterValue(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	if h.counters == nil {
		httpx.WriteError(ctx, w, httpx.NewError("counter_service_unavailable", "counter service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	rawName := strings.TrimSpace(chi.URLParam(r, "name"))
	if rawName == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_counter", "counter name is required", http.StatusBadRequest))
		return
	}

	scope, segment, err := parseCounterPath(rawName)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_counter", err.Error(), http.StatusBadRequest))
		return
	}

	if !h.isScopeAllowed(scope) {
		httpx.WriteError(ctx, w, httpx.NewError("counter_not_allowed", "counter scope not permitted", http.StatusForbidden))
		return
	}

	body, err := readLimitedBody(r, maxAdminCounterBodySize)
	switch {
	case err == nil:
	case errors.Is(err, errEmptyBody):
		body = nil
	case errors.Is(err, errBodyTooLarge):
		httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body too large", http.StatusRequestEntityTooLarge))
		return
	default:
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request_body", "failed to read request body", http.StatusBadRequest))
		return
	}

	var payload adminNextCounterRequest
	if len(body) > 0 {
		if err := json.Unmarshal(body, &payload); err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_json", "request body must be valid JSON", http.StatusBadRequest))
			return
		}
	}

	if payloadScope, err := deriveCounterSegment(payload.Scope); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_scope", err.Error(), http.StatusBadRequest))
		return
	} else if payloadScope != "" {
		segment = payloadScope
	}

	if segment == "" {
		segment = defaultCounterSegmentName
	}

	opts, err := buildCounterOptions(payload)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_counter_options", err.Error(), http.StatusBadRequest))
		return
	}

	value, err := h.counters.Next(ctx, scope, segment, opts)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrCounterInvalidInput):
			httpx.WriteError(ctx, w, httpx.NewError("invalid_counter_request", err.Error(), http.StatusBadRequest))
		case errors.Is(err, services.ErrCounterExhausted):
			httpx.WriteError(ctx, w, httpx.NewError("counter_exhausted", err.Error(), http.StatusConflict))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("counter_next_failed", "failed to increment counter", http.StatusInternalServerError))
		}
		return
	}

	h.recordAudit(ctx, identity, scope, segment, value, opts)

	response := adminNextCounterResponse{Number: value.Formatted}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminCounterHandlers) isScopeAllowed(scope string) bool {
	if len(h.allowedScopes) == 0 {
		return true
	}
	_, ok := h.allowedScopes[strings.ToLower(scope)]
	return ok
}

func (h *AdminCounterHandlers) recordAudit(ctx context.Context, identity *auth.Identity, scope, segment string, value services.CounterValue, opts services.CounterGenerationOptions) {
	if h.audit == nil {
		return
	}
	actorID := ""
	actorType := "staff"
	if identity != nil {
		actorID = strings.TrimSpace(identity.UID)
		switch {
		case identity.HasRole(auth.RoleAdmin):
			actorType = "admin"
		case identity.HasRole(auth.RoleStaff):
			actorType = "staff"
		default:
			actorType = "user"
		}
	}

	metadata := map[string]any{
		"scope":     scope,
		"segment":   segment,
		"value":     value.Value,
		"formatted": value.Formatted,
	}
	if opts.Step > 0 {
		metadata["step"] = opts.Step
	}

	record := services.AuditLogRecord{
		Actor:      actorID,
		ActorType:  actorType,
		Action:     "counter.next",
		TargetRef:  fmt.Sprintf("/counters/%s:%s", scope, segment),
		OccurredAt: h.clock(),
		Metadata:   metadata,
	}
	h.audit.Record(ctx, record)
}

func parseCounterPath(raw string) (string, string, error) {
	if raw == "" {
		return "", "", errors.New("counter name is required")
	}
	if strings.Contains(raw, "/") {
		return "", "", errors.New("counter name must not contain '/'")
	}
	if strings.Contains(raw, "..") {
		return "", "", errors.New("counter name must not contain '..'")
	}
	if strings.Contains(raw, ":") {
		parts := strings.SplitN(raw, ":", 2)
		scope, ok := sanitiseCounterToken(parts[0])
		if !ok {
			return "", "", errors.New("counter scope must contain alphanumeric, hyphen, underscore, or dot characters")
		}
		segment := strings.TrimSpace(parts[1])
		if segment != "" {
			if trimmed, ok := sanitiseCounterSegment(segment); ok {
				return scope, trimmed, nil
			}
			return "", "", errors.New("counter name must contain alphanumeric, hyphen, underscore, or dot characters")
		}
		return scope, "", nil
	}

	scope, ok := sanitiseCounterToken(raw)
	if !ok {
		return "", "", errors.New("counter scope must contain alphanumeric, hyphen, underscore, or dot characters")
	}
	return scope, "", nil
}

func deriveCounterSegment(scope map[string]string) (string, error) {
	if len(scope) == 0 {
		return "", nil
	}

	if len(scope) == 1 {
		for key, value := range scope {
			tokenKey, ok := sanitiseCounterToken(key)
			if !ok {
				return "", fmt.Errorf("scope key %q contains invalid characters", key)
			}
			tokenValue, ok := sanitiseCounterToken(value)
			if !ok {
				return "", fmt.Errorf("scope value for %q contains invalid characters", key)
			}
			switch strings.ToLower(tokenKey) {
			case "id", "name", "segment", "key":
				return tokenValue, nil
			}
			return fmt.Sprintf("%s=%s", tokenKey, tokenValue), nil
		}
	}

	pairs := make([]string, 0, len(scope))
	for key, value := range scope {
		tokenKey, ok := sanitiseCounterToken(key)
		if !ok {
			return "", fmt.Errorf("scope key %q contains invalid characters", key)
		}
		tokenValue, ok := sanitiseCounterToken(value)
		if !ok {
			return "", fmt.Errorf("scope value for %q contains invalid characters", key)
		}
		pairs = append(pairs, fmt.Sprintf("%s=%s", tokenKey, tokenValue))
	}
	sort.Strings(pairs)
	return strings.Join(pairs, "|"), nil
}

func buildCounterOptions(req adminNextCounterRequest) (services.CounterGenerationOptions, error) {
	var opts services.CounterGenerationOptions

	if req.Step != nil {
		if *req.Step <= 0 {
			return services.CounterGenerationOptions{}, errors.New("step must be greater than zero")
		}
		opts.Step = *req.Step
	}

	if req.MaxValue != nil {
		if *req.MaxValue < 0 {
			return services.CounterGenerationOptions{}, errors.New("maxValue must be non-negative")
		}
		opts.MaxValue = ptrClone(*req.MaxValue)
	}

	if req.InitialValue != nil {
		if *req.InitialValue < 0 {
			return services.CounterGenerationOptions{}, errors.New("initialValue must be non-negative")
		}
		opts.InitialValue = ptrClone(*req.InitialValue)
	}

	if req.Prefix != nil {
		opts.Prefix = strings.TrimSpace(*req.Prefix)
	}
	if req.Suffix != nil {
		opts.Suffix = strings.TrimSpace(*req.Suffix)
	}
	if req.PadLength != nil {
		if *req.PadLength < 0 {
			return services.CounterGenerationOptions{}, errors.New("padLength must be non-negative")
		}
		opts.PadLength = *req.PadLength
	}

	return opts, nil
}

func ptrClone[T any](value T) *T {
	v := value
	return &v
}

func sanitiseCounterToken(token string) (string, bool) {
	trimmed := strings.TrimSpace(token)
	if trimmed == "" {
		return "", false
	}
	for _, r := range trimmed {
		if isAllowedCounterRune(r) {
			continue
		}
		return "", false
	}
	return trimmed, true
}

func isAllowedCounterRune(r rune) bool {
	switch {
	case unicode.IsLetter(r):
		return true
	case unicode.IsDigit(r):
		return true
	case r == '-', r == '_', r == '.':
		return true
	default:
		return false
	}
}

func sanitiseCounterSegment(segment string) (string, bool) {
	trimmed := strings.TrimSpace(segment)
	if trimmed == "" {
		return "", false
	}
	for _, r := range trimmed {
		if isAllowedCounterRune(r) || r == '=' || r == '|' {
			continue
		}
		return "", false
	}
	return trimmed, true
}
