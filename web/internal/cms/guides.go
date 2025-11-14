package cms

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"finitefield.org/hanko-web/internal/telemetry"
)

// ErrNotFound is returned when a CMS resource cannot be located.
var ErrNotFound = errors.New("cms: not found")

// Guide represents a localized guide article fetched from the CMS.
type Guide struct {
	Slug               string
	Lang               string
	Title              string
	Summary            string
	Body               string
	Category           string
	Personas           []string
	Tags               []string
	HeroImageURL       string
	ReadingTimeMinutes int
	Author             Author
	Sources            []string
	PublishAt          time.Time
	UpdatedAt          time.Time
	SEO                GuideSEO
}

// Author captures guide author metadata.
type Author struct {
	Name       string
	ProfileURL string
}

// GuideSEO contains optional per-locale SEO metadata.
type GuideSEO struct {
	MetaTitle       string
	MetaDescription string
	OGImage         string
}

// ListGuidesOptions controls guide listing requests.
type ListGuidesOptions struct {
	Lang     string
	Category string
	Persona  string
	Search   string
	Limit    int
}

// Client provides read-only access to CMS content endpoints.
type Client struct {
	baseURL    string
	http       *http.Client
	contentDir string
}

// NewClient constructs a Client with the provided base URL.
func NewClient(baseURL string) *Client {
	baseURL = strings.TrimSpace(baseURL)
	return &Client{
		baseURL:    strings.TrimRight(baseURL, "/"),
		http:       &http.Client{Timeout: 5 * time.Second},
		contentDir: defaultContentDir,
	}
}

// ListGuides returns localized guides, applying filters client-side when necessary.
func (c *Client) ListGuides(ctx context.Context, opts ListGuidesOptions) ([]Guide, error) {
	lang := normalizeLang(opts.Lang)
	fallback := filterGuides(fallbackGuidesForLang(lang), opts)

	if c == nil || c.baseURL == "" {
		return fallback, nil
	}
	if c.http == nil {
		c.http = &http.Client{Timeout: 5 * time.Second}
	}

	endpoint, err := url.JoinPath(c.baseURL, "content/guides")
	if err != nil {
		telemetry.Logger().Error("cms join guide list path failed", "error", err, "lang", lang)
		return fallback, fmt.Errorf("cms: list guides path: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		telemetry.Logger().Error("cms build guide list request failed", "error", err, "lang", lang)
		return fallback, fmt.Errorf("cms: list guides request build: %w", err)
	}
	q := req.URL.Query()
	if lang != "" {
		q.Set("lang", lang)
	}
	if opts.Category != "" {
		q.Set("category", opts.Category)
	}
	if opts.Limit > 0 {
		q.Set("limit", strconv.Itoa(opts.Limit))
	}
	req.URL.RawQuery = q.Encode()
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		telemetry.Logger().Error("cms guide list request failed", "error", err, "lang", lang)
		return fallback, fmt.Errorf("cms: list guides do: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return []Guide{}, nil
	}
	if resp.StatusCode >= 400 {
		telemetry.Logger().Warn("cms guide list non-success status", "status", resp.StatusCode, "lang", lang)
		return fallback, fmt.Errorf("cms: list guides status %d", resp.StatusCode)
	}

	var pg pageGuide
	if err := json.NewDecoder(resp.Body).Decode(&pg); err != nil {
		telemetry.Logger().Error("cms decode guide list failed", "error", err, "lang", lang)
		return fallback, fmt.Errorf("cms: list guides decode: %w", err)
	}

	guides := make([]Guide, 0, len(pg.Items))
	for _, raw := range pg.Items {
		g, ok := mapRawGuide(raw, lang)
		if !ok {
			continue
		}
		guides = append(guides, g)
	}
	if len(guides) == 0 {
		return fallback, nil
	}

	sortGuides(guides)
	return filterGuides(guides, opts), nil
}

// GetGuide retrieves a single localized guide by slug.
func (c *Client) GetGuide(ctx context.Context, slug, lang string) (Guide, error) {
	slug = strings.TrimSpace(slug)
	if slug == "" {
		return Guide{}, ErrNotFound
	}
	lang = normalizeLang(lang)

	if c == nil || c.baseURL == "" {
		return fallbackGuide(slug, lang)
	}
	if c.http == nil {
		c.http = &http.Client{Timeout: 5 * time.Second}
	}

	endpoint, err := url.JoinPath(c.baseURL, "content/guides", slug)
	if err != nil {
		telemetry.Logger().Error("cms join guide detail path failed", "error", err, "slug", slug, "lang", lang)
		if g, fbErr := fallbackGuide(slug, lang); fbErr == nil {
			return g, fmt.Errorf("cms: guide detail path: %w", err)
		}
		return Guide{}, fmt.Errorf("cms: guide detail path: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		telemetry.Logger().Error("cms build guide detail request failed", "error", err, "slug", slug, "lang", lang)
		if g, fbErr := fallbackGuide(slug, lang); fbErr == nil {
			return g, fmt.Errorf("cms: guide detail request build: %w", err)
		}
		return Guide{}, fmt.Errorf("cms: guide detail request build: %w", err)
	}
	q := req.URL.Query()
	if lang != "" {
		q.Set("lang", lang)
	}
	req.URL.RawQuery = q.Encode()
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		telemetry.Logger().Error("cms guide detail request failed", "error", err, "slug", slug, "lang", lang)
		if g, fbErr := fallbackGuide(slug, lang); fbErr == nil {
			return g, fmt.Errorf("cms: guide detail do: %w", err)
		}
		return Guide{}, fmt.Errorf("cms: guide detail do: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		if g, fbErr := fallbackGuide(slug, lang); fbErr == nil {
			return g, ErrNotFound
		}
		return Guide{}, ErrNotFound
	}
	if resp.StatusCode >= 400 {
		telemetry.Logger().Warn("cms guide detail non-success status", "status", resp.StatusCode, "slug", slug, "lang", lang)
		if g, fbErr := fallbackGuide(slug, lang); fbErr == nil {
			return g, fmt.Errorf("cms: guide detail status %d", resp.StatusCode)
		}
		return Guide{}, fmt.Errorf("cms: guide detail status %d", resp.StatusCode)
	}

	var raw rawGuide
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		telemetry.Logger().Error("cms decode guide detail failed", "error", err, "slug", slug, "lang", lang)
		if g, fbErr := fallbackGuide(slug, lang); fbErr == nil {
			return g, fmt.Errorf("cms: guide detail decode: %w", err)
		}
		return Guide{}, fmt.Errorf("cms: guide detail decode: %w", err)
	}

	guide, ok := mapRawGuide(raw, lang)
	if !ok {
		if g, fbErr := fallbackGuide(slug, lang); fbErr == nil {
			return g, fmt.Errorf("cms: guide detail map: invalid payload")
		}
		return Guide{}, fmt.Errorf("cms: guide detail map: invalid payload")
	}
	return guide, nil
}

type pageGuide struct {
	Items []rawGuide `json:"items"`
}

type rawGuide struct {
	Slug               string                    `json:"slug"`
	Category           string                    `json:"category"`
	Personas           []string                  `json:"personas"`
	Tags               []string                  `json:"tags"`
	HeroImageURL       string                    `json:"heroImageUrl"`
	ReadingTimeMinutes int                       `json:"readingTimeMinutes"`
	Author             rawAuthor                 `json:"author"`
	Sources            []string                  `json:"sources"`
	Translations       map[string]rawTranslation `json:"translations"`
	PublishAt          *time.Time                `json:"publishAt"`
	CreatedAt          *time.Time                `json:"createdAt"`
	UpdatedAt          *time.Time                `json:"updatedAt"`
}

type rawAuthor struct {
	Name       string `json:"name"`
	ProfileURL string `json:"profileUrl"`
}

type rawTranslation struct {
	Title   string `json:"title"`
	Summary string `json:"summary"`
	Body    string `json:"body"`
	SEO     rawSEO `json:"seo"`
}

type rawSEO struct {
	MetaTitle       string `json:"metaTitle"`
	MetaDescription string `json:"metaDescription"`
	OGImage         string `json:"ogImage"`
}

func mapRawGuide(raw rawGuide, preferredLang string) (Guide, bool) {
	translation, langUsed := pickTranslation(raw.Translations, preferredLang)
	if translation.Title == "" && translation.Summary == "" && translation.Body == "" {
		return Guide{}, false
	}

	guide := Guide{
		Slug:               raw.Slug,
		Category:           strings.ToLower(strings.TrimSpace(raw.Category)),
		Personas:           lowerSlice(raw.Personas),
		Tags:               append([]string(nil), raw.Tags...),
		HeroImageURL:       raw.HeroImageURL,
		ReadingTimeMinutes: raw.ReadingTimeMinutes,
		Author: Author{
			Name:       raw.Author.Name,
			ProfileURL: raw.Author.ProfileURL,
		},
		Sources: append([]string(nil), raw.Sources...),
		Title:   translation.Title,
		Summary: translation.Summary,
		Body:    translation.Body,
		Lang:    langUsed,
		SEO: GuideSEO{
			MetaTitle:       translation.SEO.MetaTitle,
			MetaDescription: translation.SEO.MetaDescription,
			OGImage:         translation.SEO.OGImage,
		},
	}
	if raw.PublishAt != nil {
		guide.PublishAt = *raw.PublishAt
	}
	if raw.UpdatedAt != nil {
		guide.UpdatedAt = *raw.UpdatedAt
	} else if raw.CreatedAt != nil {
		guide.UpdatedAt = *raw.CreatedAt
	}
	if guide.Lang == "" {
		guide.Lang = normalizeLang(preferredLang)
	}
	return guide, true
}

func pickTranslation(trans map[string]rawTranslation, preferred string) (rawTranslation, string) {
	if len(trans) == 0 {
		return rawTranslation{}, ""
	}
	preferred = strings.ToLower(strings.TrimSpace(preferred))
	if preferred != "" {
		if t, ok := trans[preferred]; ok && (t.Title != "" || t.Summary != "" || t.Body != "") {
			return t, preferred
		}
	}
	if preferred != "ja" {
		if t, ok := trans["ja"]; ok && (t.Title != "" || t.Summary != "" || t.Body != "") {
			return t, "ja"
		}
	}
	if preferred != "en" {
		if t, ok := trans["en"]; ok && (t.Title != "" || t.Summary != "" || t.Body != "") {
			return t, "en"
		}
	}
	for lang, t := range trans {
		if t.Title != "" || t.Summary != "" || t.Body != "" {
			return t, strings.ToLower(lang)
		}
	}
	return rawTranslation{}, ""
}

func filterGuides(guides []Guide, opts ListGuidesOptions) []Guide {
	persona := strings.ToLower(strings.TrimSpace(opts.Persona))
	category := strings.ToLower(strings.TrimSpace(opts.Category))
	search := strings.ToLower(strings.TrimSpace(opts.Search))

	filtered := make([]Guide, 0, len(guides))
	for _, g := range guides {
		if category != "" && strings.ToLower(g.Category) != category {
			continue
		}
		if persona != "" && !containsString(g.Personas, persona) {
			continue
		}
		if search != "" {
			hay := strings.ToLower(g.Title + " " + g.Summary + " " + strings.Join(g.Tags, " "))
			if !strings.Contains(hay, search) {
				continue
			}
		}
		filtered = append(filtered, g)
		if opts.Limit > 0 && len(filtered) >= opts.Limit {
			break
		}
	}
	if opts.Limit > 0 && len(filtered) > opts.Limit {
		filtered = filtered[:opts.Limit]
	}
	return copyGuides(filtered)
}

func copyGuides(src []Guide) []Guide {
	if len(src) == 0 {
		return []Guide{}
	}
	out := make([]Guide, len(src))
	for i, g := range src {
		out[i] = cloneGuide(g)
	}
	return out
}

func cloneGuide(g Guide) Guide {
	clone := g
	if g.Personas != nil {
		clone.Personas = append([]string(nil), g.Personas...)
	}
	if g.Tags != nil {
		clone.Tags = append([]string(nil), g.Tags...)
	}
	if g.Sources != nil {
		clone.Sources = append([]string(nil), g.Sources...)
	}
	return clone
}

func containsString(list []string, val string) bool {
	val = strings.ToLower(strings.TrimSpace(val))
	for _, item := range list {
		if strings.ToLower(strings.TrimSpace(item)) == val {
			return true
		}
	}
	return false
}

func sortGuides(items []Guide) {
	sort.SliceStable(items, func(i, j int) bool {
		a := items[i]
		b := items[j]

		switch {
		case !a.PublishAt.IsZero() && !b.PublishAt.IsZero():
			if !a.PublishAt.Equal(b.PublishAt) {
				return a.PublishAt.After(b.PublishAt)
			}
		case !a.PublishAt.IsZero():
			return true
		case !b.PublishAt.IsZero():
			return false
		}

		switch {
		case !a.UpdatedAt.IsZero() && !b.UpdatedAt.IsZero():
			if !a.UpdatedAt.Equal(b.UpdatedAt) {
				return a.UpdatedAt.After(b.UpdatedAt)
			}
		case !a.UpdatedAt.IsZero():
			return true
		case !b.UpdatedAt.IsZero():
			return false
		}

		return strings.Compare(a.Slug, b.Slug) < 0
	})
}

func lowerSlice(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, len(values))
	for i, v := range values {
		out[i] = strings.ToLower(strings.TrimSpace(v))
	}
	return out
}

func normalizeLang(lang string) string {
	lang = strings.ToLower(strings.TrimSpace(lang))
	if lang == "" {
		return "ja"
	}
	return lang
}
