package middleware

import (
	"context"
	"net/http"
	"sort"
	"strings"

	"finitefield.org/hanko-admin/internal/admin/i18n"
)

// LocaleConfig controls how the locale middleware resolves language preferences.
type LocaleConfig struct {
	Default               string
	Supported             []string
	QueryParam            string
	DisableAcceptLanguage bool
}

type supportedLocalesKey struct{}

// Locale attaches the resolved locale to the request context and session.
func Locale(cfg LocaleConfig) func(http.Handler) http.Handler {
	catalog := i18n.Default()
	fallback := catalog.Canonicalize(cfg.Default)
	supported := cfg.Supported
	if len(supported) == 0 {
		supported = catalog.SupportedLocales()
	}
	allowed := make(map[string]struct{}, len(supported))
	for _, locale := range supported {
		allowed[catalog.Canonicalize(locale)] = struct{}{}
	}
	supportedList := make([]string, 0, len(allowed))
	for locale := range allowed {
		supportedList = append(supportedList, locale)
	}
	sort.Strings(supportedList)
	queryParam := strings.TrimSpace(cfg.QueryParam)
	if queryParam == "" {
		queryParam = "lang"
	}
	allowAccept := !cfg.DisableAcceptLanguage
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()
			sess, _ := SessionFromContext(ctx)

			resolve := func(raw string) string {
				if strings.TrimSpace(raw) == "" {
					return ""
				}
				canonical := catalog.Canonicalize(raw)
				if _, ok := allowed[canonical]; ok {
					return canonical
				}
				return ""
			}

			query := r.URL.Query()
			locale := resolve(query.Get(queryParam))
			if locale == "" {
				locale = resolve(query.Get("locale"))
			} else if sess != nil {
				sess.SetLocale(locale)
			}
			if locale == "" && sess != nil {
				locale = resolve(sess.Locale())
			}
			if locale == "" && allowAccept {
				locale = resolve(i18n.MatchAcceptLanguage(r.Header.Get("Accept-Language")))
			}
			if locale == "" {
				locale = fallback
			}

			if sess != nil && sess.Locale() == "" {
				sess.SetLocale(locale)
			}

			ctx = i18n.ContextWithLocale(ctx, locale)
			ctx = context.WithValue(ctx, supportedLocalesKey{}, supportedList)
			w.Header().Set("Content-Language", locale)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// SupportedLocalesFromContext returns the configured locale list for the current request.
func SupportedLocalesFromContext(ctx context.Context) []string {
	if ctx == nil {
		return nil
	}
	if locales, ok := ctx.Value(supportedLocalesKey{}).([]string); ok {
		return locales
	}
	return nil
}
