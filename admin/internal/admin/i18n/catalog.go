package i18n

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"sort"
	"strings"
	"sync"

	"golang.org/x/text/language"
	"golang.org/x/text/message"
)

//go:embed locales/*.json
var localeFS embed.FS

var (
	defaultCatalog *Catalog
	once           sync.Once
)

// Catalog holds translation dictionaries for each supported locale.
type Catalog struct {
	matcher      language.Matcher
	fallback     language.Tag
	translations map[string]map[string]string
	printers     map[string]*message.Printer
	mu           sync.RWMutex
}

// LoadCatalog initialises the translation catalog from the embedded locale files.
func LoadCatalog() (*Catalog, error) {
	var err error
	once.Do(func() {
		entries, readErr := localeFS.ReadDir("locales")
		if readErr != nil {
			err = fmt.Errorf("i18n: read locales: %w", readErr)
			return
		}
		translations := make(map[string]map[string]string)
		tags := make([]language.Tag, 0, len(entries))
		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			name := entry.Name()
			if !strings.HasSuffix(name, ".json") {
				continue
			}
			data, fileErr := fs.ReadFile(localeFS, "locales/"+name)
			if fileErr != nil {
				err = fmt.Errorf("i18n: read %s: %w", name, fileErr)
				return
			}
			var dict map[string]string
			if jsonErr := json.Unmarshal(data, &dict); jsonErr != nil {
				err = fmt.Errorf("i18n: parse %s: %w", name, jsonErr)
				return
			}
			locale := strings.TrimSuffix(name, ".json")
			tag, parseErr := language.Parse(locale)
			if parseErr != nil {
				err = fmt.Errorf("i18n: invalid locale %s: %w", locale, parseErr)
				return
			}
			canonical := strings.ToLower(tag.String())
			translations[canonical] = dict
			tags = append(tags, tag)
		}
		if len(tags) == 0 {
			err = fmt.Errorf("i18n: no locales found")
			return
		}
		sort.Slice(tags, func(i, j int) bool {
			return tags[i].String() < tags[j].String()
		})
		fallback := tags[0]
		matcher := language.NewMatcher(tags)
		printers := make(map[string]*message.Printer, len(tags))
		for _, tag := range tags {
			printers[strings.ToLower(tag.String())] = message.NewPrinter(tag)
		}
		defaultCatalog = &Catalog{
			matcher:      matcher,
			fallback:     fallback,
			translations: translations,
			printers:     printers,
		}
	})
	if err != nil {
		return nil, err
	}
	return defaultCatalog, nil
}

// Default returns the process-wide catalog instance.
func Default() *Catalog {
	cat, err := LoadCatalog()
	if err != nil {
		panic(err)
	}
	return cat
}

// SupportedLocales returns the sorted list of canonical locale strings.
func (c *Catalog) SupportedLocales() []string {
	if c == nil {
		return nil
	}
	c.mu.RLock()
	defer c.mu.RUnlock()
	locales := make([]string, 0, len(c.translations))
	for locale := range c.translations {
		locales = append(locales, locale)
	}
	sort.Strings(locales)
	return locales
}

// Canonicalize normalises the provided locale and matches it against the supported set.
func (c *Catalog) Canonicalize(locale string) string {
	if c == nil {
		return ""
	}
	locale = strings.TrimSpace(locale)
	if locale == "" {
		return strings.ToLower(c.fallback.String())
	}
	tag, err := language.Parse(locale)
	if err != nil {
		tag = c.fallback
	}
	matched, _, _ := c.matcher.Match(tag)
	return strings.ToLower(matched.String())
}

// Translate returns the translated string for the provided key and locale.
func (c *Catalog) Translate(locale string, key string, args ...any) string {
	if c == nil {
		return key
	}
	canonical := c.Canonicalize(locale)
	c.mu.RLock()
	dict, ok := c.translations[canonical]
	if !ok {
		dict = c.translations[strings.ToLower(c.fallback.String())]
	}
	value, ok := dict[key]
	c.mu.RUnlock()
	if !ok || strings.TrimSpace(value) == "" {
		value = key
	}
	if len(args) == 0 {
		return value
	}
	return fmt.Sprintf(value, args...)
}

// Printer returns the message.Printer for the provided locale.
func (c *Catalog) Printer(locale string) *message.Printer {
	if c == nil {
		return message.NewPrinter(language.English)
	}
	canonical := c.Canonicalize(locale)
	c.mu.RLock()
	printer, ok := c.printers[canonical]
	if !ok {
		printer = c.printers[strings.ToLower(c.fallback.String())]
	}
	c.mu.RUnlock()
	if printer == nil {
		return message.NewPrinter(language.English)
	}
	return printer
}

type localeContextKey struct{}

// ContextWithLocale stores the canonical locale on the context.
func ContextWithLocale(ctx context.Context, locale string) context.Context {
	catalog := Default()
	canonical := catalog.Canonicalize(locale)
	return context.WithValue(ctx, localeContextKey{}, canonical)
}

// FromContext returns the locale stored on the context, defaulting to fallback.
func FromContext(ctx context.Context) string {
	if ctx == nil {
		return Default().Canonicalize("")
	}
	if value, ok := ctx.Value(localeContextKey{}).(string); ok && value != "" {
		return value
	}
	return Default().Canonicalize("")
}

// TranslateContext is a convenience wrapper around Translate for contexts.
func TranslateContext(ctx context.Context, key string, args ...any) string {
	catalog := Default()
	return catalog.Translate(FromContext(ctx), key, args...)
}

// PrinterFromContext returns the printer for the locale stored on the context.
func PrinterFromContext(ctx context.Context) *message.Printer {
	catalog := Default()
	return catalog.Printer(FromContext(ctx))
}
