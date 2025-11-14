package status

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Summary captures an overview of the platform status and recent incidents.
type Summary struct {
	State         string
	StateLabel    string
	UpdatedAt     time.Time
	Components    []Component
	Incidents     []Incident
	Uptime        UptimeSummary
	Subscriptions []SubscriptionOption
}

// Component represents the status of an individual subsystem.
type Component struct {
	Name          string
	Status        string
	Slug          string
	Description   string
	Tags          []string
	Primary       bool
	IncidentCount int
	MTTR          time.Duration
	Uptime        ComponentUptime
	DocsURL       string
}

// Incident describes a status incident with optional updates.
type Incident struct {
	ID         string
	Title      string
	Status     string
	Impact     string
	StartedAt  time.Time
	ResolvedAt time.Time
	Updates    []IncidentUpdate
}

// IncidentUpdate captures a timeline entry for an incident.
type IncidentUpdate struct {
	Timestamp time.Time
	Status    string
	Body      string
}

// ComponentUptime captures uptime metrics for a given component.
type ComponentUptime struct {
	Period     string
	Percentage float64
	Trend      []UptimePoint
	Target     float64
}

// UptimeSummary provides aggregated uptime insights across periods.
type UptimeSummary struct {
	Periods []UptimePeriod
}

// UptimePeriod represents uptime over a specific window (7/30/90 days).
type UptimePeriod struct {
	Period     string
	Label      string
	Percentage float64
	Target     float64
	Trend      []UptimePoint
}

// UptimePoint captures a data point in an uptime trend.
type UptimePoint struct {
	Timestamp  time.Time
	Percentage float64
}

// SubscriptionOption describes an available notification channel.
type SubscriptionOption struct {
	Channel        string
	Title          string
	Description    string
	PrimaryLabel   string
	PrimaryURL     string
	SecondaryLabel string
	SecondaryURL   string
}

// Client fetches status summaries from an external endpoint with local fallbacks.
type Client struct {
	baseURL string
	http    *http.Client
}

// NewClient builds a status client with the provided base URL. When baseURL is empty,
// the client will exclusively serve fallback data.
func NewClient(baseURL string) *Client {
	return &Client{
		baseURL: strings.TrimSpace(baseURL),
		http:    &http.Client{Timeout: 5 * time.Second},
	}
}

var (
	cacheMu      sync.RWMutex
	summaryCache = map[string]statusCacheEntry{}
	cacheTTL     = 2 * time.Minute
)

type statusCacheEntry struct {
	summary Summary
	expires time.Time
}

// SetCacheTTL configures the cache duration (primarily for tests).
func SetCacheTTL(d time.Duration) {
	if d <= 0 {
		d = time.Minute
	}
	cacheTTL = d
}

// FetchSummary returns a localized status summary, prioritizing cached values,
// then remote data, and finally local fallback content.
func (c *Client) FetchSummary(ctx context.Context, lang string) (Summary, error) {
	lang = normalizeLang(lang)
	if summary, ok := cachedSummary(lang); ok {
		return cloneSummary(summary), nil
	}

	var summary Summary
	var err error
	if c != nil && c.baseURL != "" {
		summary, err = c.fetchRemote(ctx, lang)
		if err != nil && !errors.Is(err, ErrNotFound) {
			// ignore and fall back below
			summary = Summary{}
		}
	}
	if summary.State == "" {
		summary = fallbackSummary(lang)
	}
	storeSummary(lang, summary)
	return cloneSummary(summary), nil
}

// ErrNotFound indicates the status endpoint could not locate resources for the given locale.
var ErrNotFound = errors.New("status: not found")

func (c *Client) fetchRemote(ctx context.Context, lang string) (Summary, error) {
	endpoint := c.baseURL
	if endpoint == "" {
		return Summary{}, ErrNotFound
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return Summary{}, err
	}
	req.Header.Set("Accept", "application/json")
	if lang != "" {
		req.Header.Set("Accept-Language", lang)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return Summary{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return Summary{}, ErrNotFound
	}
	if resp.StatusCode >= 400 {
		return Summary{}, fmt.Errorf("status: remote status %d", resp.StatusCode)
	}

	var payload remoteSummary
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return Summary{}, err
	}
	return mapRemoteSummary(payload), nil
}

func mapRemoteSummary(raw remoteSummary) Summary {
	summary := Summary{
		State:         strings.TrimSpace(raw.State),
		StateLabel:    strings.TrimSpace(raw.StateLabel),
		UpdatedAt:     parseTime(raw.UpdatedAt),
		Uptime:        mapRemoteUptime(raw.Uptime),
		Subscriptions: mapRemoteSubscriptions(raw.Subscriptions),
	}
	for _, c := range raw.Components {
		summary.Components = append(summary.Components, Component{
			Name:          strings.TrimSpace(c.Name),
			Status:        strings.TrimSpace(c.Status),
			Slug:          strings.TrimSpace(c.Slug),
			Description:   strings.TrimSpace(c.Description),
			Tags:          trimStrings(c.Tags),
			Primary:       c.Primary,
			IncidentCount: c.IncidentsCount,
			MTTR:          parseMTTR(c.MTTRMinutes, c.MTTR),
			Uptime:        mapRemoteComponentUptime(c.Uptime),
			DocsURL:       strings.TrimSpace(c.DocsURL),
		})
	}
	for _, inc := range raw.Incidents {
		item := Incident{
			ID:         strings.TrimSpace(inc.ID),
			Title:      strings.TrimSpace(inc.Title),
			Status:     strings.TrimSpace(inc.Status),
			Impact:     strings.TrimSpace(inc.Impact),
			StartedAt:  parseTime(inc.StartedAt),
			ResolvedAt: parseTime(inc.ResolvedAt),
		}
		for _, upd := range inc.Updates {
			item.Updates = append(item.Updates, IncidentUpdate{
				Timestamp: parseTime(upd.Timestamp),
				Status:    strings.TrimSpace(upd.Status),
				Body:      strings.TrimSpace(upd.Body),
			})
		}
		summary.Incidents = append(summary.Incidents, item)
	}
	return summary
}

func mapRemoteComponentUptime(raw remoteComponentUptime) ComponentUptime {
	trend := make([]UptimePoint, 0, len(raw.Trend))
	for _, point := range raw.Trend {
		trend = append(trend, UptimePoint{
			Timestamp:  parseTime(point.Timestamp),
			Percentage: point.Percentage,
		})
	}
	return ComponentUptime{
		Period:     strings.TrimSpace(raw.Period),
		Percentage: raw.Percentage,
		Target:     raw.Target,
		Trend:      trend,
	}
}

func mapRemoteUptime(raw remoteUptimeSummary) UptimeSummary {
	periods := make([]UptimePeriod, 0, len(raw.Periods))
	for _, period := range raw.Periods {
		periods = append(periods, UptimePeriod{
			Period:     strings.TrimSpace(period.Period),
			Label:      strings.TrimSpace(period.Label),
			Percentage: period.Percentage,
			Target:     period.Target,
			Trend:      mapRemoteUptimeTrend(period.Trend),
		})
	}
	return UptimeSummary{Periods: periods}
}

func mapRemoteUptimeTrend(points []remoteUptimePoint) []UptimePoint {
	trend := make([]UptimePoint, 0, len(points))
	for _, point := range points {
		trend = append(trend, UptimePoint{
			Timestamp:  parseTime(point.Timestamp),
			Percentage: point.Percentage,
		})
	}
	return trend
}

func mapRemoteSubscriptions(items []remoteSubscription) []SubscriptionOption {
	opts := make([]SubscriptionOption, 0, len(items))
	for _, item := range items {
		opts = append(opts, SubscriptionOption{
			Channel:        strings.TrimSpace(item.Channel),
			Title:          strings.TrimSpace(item.Title),
			Description:    strings.TrimSpace(item.Description),
			PrimaryLabel:   strings.TrimSpace(item.PrimaryLabel),
			PrimaryURL:     strings.TrimSpace(item.PrimaryURL),
			SecondaryLabel: strings.TrimSpace(item.SecondaryLabel),
			SecondaryURL:   strings.TrimSpace(item.SecondaryURL),
		})
	}
	return opts
}

func trimStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, v := range values {
		if v = strings.TrimSpace(v); v != "" {
			out = append(out, v)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func parseMTTR(minutes float64, textual string) time.Duration {
	if minutes > 0 {
		return time.Duration(minutes * float64(time.Minute))
	}
	textual = strings.TrimSpace(textual)
	if textual == "" {
		return 0
	}
	if dur, err := time.ParseDuration(textual); err == nil {
		return dur
	}
	normalized := strings.ToLower(textual)
	replacements := []struct {
		from string
		to   string
	}{
		{"minutes", "m"},
		{"minute", "m"},
		{"mins", "m"},
		{"min", "m"},
		{"hours", "h"},
		{"hour", "h"},
		{"hrs", "h"},
		{"hr", "h"},
		{" ", ""},
	}
	for _, repl := range replacements {
		normalized = strings.ReplaceAll(normalized, repl.from, repl.to)
	}
	if dur, err := time.ParseDuration(normalized); err == nil {
		return dur
	}
	if val, err := strconv.ParseFloat(normalized, 64); err == nil {
		if val > 0 {
			return time.Duration(val * float64(time.Minute))
		}
	}
	return 0
}

type remoteSummary struct {
	State         string               `json:"state"`
	StateLabel    string               `json:"state_label"`
	UpdatedAt     string               `json:"updated_at"`
	Components    []remoteComponent    `json:"components"`
	Incidents     []remoteIncident     `json:"incidents"`
	Uptime        remoteUptimeSummary  `json:"uptime"`
	Subscriptions []remoteSubscription `json:"subscriptions"`
}

type remoteComponent struct {
	Name           string                `json:"name"`
	Status         string                `json:"status"`
	Slug           string                `json:"slug"`
	Description    string                `json:"description"`
	Tags           []string              `json:"tags"`
	Primary        bool                  `json:"primary"`
	IncidentsCount int                   `json:"incidents_count"`
	MTTRMinutes    float64               `json:"mttr_minutes"`
	MTTR           string                `json:"mttr"`
	Uptime         remoteComponentUptime `json:"uptime"`
	DocsURL        string                `json:"docs_url"`
}

type remoteIncident struct {
	ID         string                 `json:"id"`
	Title      string                 `json:"title"`
	Status     string                 `json:"status"`
	Impact     string                 `json:"impact"`
	StartedAt  string                 `json:"started_at"`
	ResolvedAt string                 `json:"resolved_at"`
	Updates    []remoteIncidentUpdate `json:"updates"`
}

type remoteIncidentUpdate struct {
	Timestamp string `json:"timestamp"`
	Status    string `json:"status"`
	Body      string `json:"body"`
}

type remoteComponentUptime struct {
	Period     string              `json:"period"`
	Percentage float64             `json:"percentage"`
	Target     float64             `json:"target"`
	Trend      []remoteUptimePoint `json:"trend"`
}

type remoteUptimeSummary struct {
	Periods []remoteUptimePeriod `json:"periods"`
}

type remoteUptimePeriod struct {
	Period     string              `json:"period"`
	Label      string              `json:"label"`
	Percentage float64             `json:"percentage"`
	Target     float64             `json:"target"`
	Trend      []remoteUptimePoint `json:"trend"`
}

type remoteUptimePoint struct {
	Timestamp  string  `json:"timestamp"`
	Percentage float64 `json:"percentage"`
}

type remoteSubscription struct {
	Channel        string `json:"channel"`
	Title          string `json:"title"`
	Description    string `json:"description"`
	PrimaryLabel   string `json:"primary_label"`
	PrimaryURL     string `json:"primary_url"`
	SecondaryLabel string `json:"secondary_label"`
	SecondaryURL   string `json:"secondary_url"`
}

func cachedSummary(lang string) (Summary, bool) {
	cacheMu.RLock()
	entry, ok := summaryCache[lang]
	cacheMu.RUnlock()
	if !ok || time.Now().After(entry.expires) {
		return Summary{}, false
	}
	return cloneSummary(entry.summary), true
}

func storeSummary(lang string, summary Summary) {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	summaryCache[lang] = statusCacheEntry{
		summary: cloneSummary(summary),
		expires: time.Now().Add(cacheTTL),
	}
}

func cloneSummary(src Summary) Summary {
	cp := Summary{
		State:      src.State,
		StateLabel: src.StateLabel,
		UpdatedAt:  src.UpdatedAt,
		Uptime:     cloneUptimeSummary(src.Uptime),
	}
	if len(src.Components) > 0 {
		cp.Components = make([]Component, len(src.Components))
		for i, comp := range src.Components {
			cp.Components[i] = Component{
				Name:          comp.Name,
				Status:        comp.Status,
				Slug:          comp.Slug,
				Description:   comp.Description,
				Tags:          cloneStringSlice(comp.Tags),
				Primary:       comp.Primary,
				IncidentCount: comp.IncidentCount,
				MTTR:          comp.MTTR,
				Uptime: ComponentUptime{
					Period:     comp.Uptime.Period,
					Percentage: comp.Uptime.Percentage,
					Trend:      cloneUptimePoints(comp.Uptime.Trend),
					Target:     comp.Uptime.Target,
				},
				DocsURL: comp.DocsURL,
			}
		}
	}
	if len(src.Incidents) > 0 {
		cp.Incidents = make([]Incident, len(src.Incidents))
		for i, inc := range src.Incidents {
			cp.Incidents[i] = Incident{
				ID:         inc.ID,
				Title:      inc.Title,
				Status:     inc.Status,
				Impact:     inc.Impact,
				StartedAt:  inc.StartedAt,
				ResolvedAt: inc.ResolvedAt,
			}
			if len(inc.Updates) > 0 {
				cp.Incidents[i].Updates = make([]IncidentUpdate, len(inc.Updates))
				copy(cp.Incidents[i].Updates, inc.Updates)
			}
		}
	}
	if len(src.Subscriptions) > 0 {
		cp.Subscriptions = make([]SubscriptionOption, len(src.Subscriptions))
		copy(cp.Subscriptions, src.Subscriptions)
	}
	return cp
}

func cloneUptimeSummary(src UptimeSummary) UptimeSummary {
	if len(src.Periods) == 0 {
		return UptimeSummary{}
	}
	out := UptimeSummary{
		Periods: make([]UptimePeriod, len(src.Periods)),
	}
	for i, period := range src.Periods {
		out.Periods[i] = UptimePeriod{
			Period:     period.Period,
			Label:      period.Label,
			Percentage: period.Percentage,
			Target:     period.Target,
			Trend:      cloneUptimePoints(period.Trend),
		}
	}
	return out
}

func cloneUptimePoints(points []UptimePoint) []UptimePoint {
	if len(points) == 0 {
		return nil
	}
	cp := make([]UptimePoint, len(points))
	copy(cp, points)
	return cp
}

func cloneStringSlice(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, len(values))
	copy(out, values)
	return out
}

func fallbackSummary(lang string) Summary {
	switch lang {
	case "ja":
		return jaFallback
	default:
		return enFallback
	}
}

var fallbackJST = time.FixedZone("JST", 9*60*60)

var enFallback = Summary{
	State:      "operational",
	StateLabel: "All systems operational",
	UpdatedAt:  time.Date(2025, 1, 18, 3, 45, 0, 0, time.UTC),
	Components: []Component{
		{
			Name:          "Web",
			Status:        "operational",
			Slug:          "web",
			Description:   "Marketing site, docs, and embedded widgets.",
			Tags:          []string{"web"},
			Primary:       true,
			IncidentCount: 0,
			MTTR:          12 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.982,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, time.UTC), Percentage: 99.99},
					{Timestamp: time.Date(2025, 1, 12, 0, 0, 0, 0, time.UTC), Percentage: 99.97},
					{Timestamp: time.Date(2025, 1, 15, 0, 0, 0, 0, time.UTC), Percentage: 100.0},
				},
			},
			DocsURL: "/guides/platform/web-status",
		},
		{
			Name:          "API",
			Status:        "operational",
			Slug:          "api",
			Description:   "REST and GraphQL endpoints powering integrations.",
			Tags:          []string{"api", "backend"},
			Primary:       true,
			IncidentCount: 1,
			MTTR:          32 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.954,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, time.UTC), Percentage: 99.90},
					{Timestamp: time.Date(2025, 1, 10, 0, 0, 0, 0, time.UTC), Percentage: 99.82},
					{Timestamp: time.Date(2025, 1, 11, 0, 0, 0, 0, time.UTC), Percentage: 99.94},
					{Timestamp: time.Date(2025, 1, 13, 0, 0, 0, 0, time.UTC), Percentage: 99.99},
				},
			},
			DocsURL: "/support/operations/runbooks/api-reliability",
		},
		{
			Name:          "Admin Console",
			Status:        "operational",
			Slug:          "admin-console",
			Description:   "Tenant management dashboard for operations teams.",
			Tags:          []string{"admin"},
			Primary:       true,
			IncidentCount: 0,
			MTTR:          26 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.968,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 8, 0, 0, 0, 0, time.UTC), Percentage: 100.0},
					{Timestamp: time.Date(2025, 1, 12, 0, 0, 0, 0, time.UTC), Percentage: 99.95},
					{Timestamp: time.Date(2025, 1, 16, 0, 0, 0, 0, time.UTC), Percentage: 99.98},
				},
			},
			DocsURL: "/guides/admin/overview",
		},
		{
			Name:          "Realtime Notifications",
			Status:        "operational",
			Slug:          "realtime",
			Description:   "Push delivery pipeline for stamping events.",
			Tags:          []string{"notifications"},
			Primary:       false,
			IncidentCount: 1,
			MTTR:          18 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.942,
				Target:     99.8,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, time.UTC), Percentage: 99.86},
					{Timestamp: time.Date(2025, 1, 11, 0, 0, 0, 0, time.UTC), Percentage: 99.94},
					{Timestamp: time.Date(2025, 1, 15, 0, 0, 0, 0, time.UTC), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 17, 0, 0, 0, 0, time.UTC), Percentage: 99.99},
				},
			},
			DocsURL: "/guides/platform/notifications",
		},
	},
	Incidents: []Incident{
		{
			ID:         "sched-maint-2025-01-15",
			Title:      "Scheduled maintenance: document stamping service",
			Status:     "completed",
			Impact:     "maintenance",
			StartedAt:  time.Date(2025, 1, 15, 2, 0, 0, 0, time.UTC),
			ResolvedAt: time.Date(2025, 1, 15, 3, 30, 0, 0, time.UTC),
			Updates: []IncidentUpdate{
				{
					Timestamp: time.Date(2025, 1, 14, 21, 0, 0, 0, time.UTC),
					Status:    "scheduled",
					Body:      "We will perform routine maintenance on the document stamping service. Downtime is expected to last up to 30 minutes.",
				},
				{
					Timestamp: time.Date(2025, 1, 15, 2, 5, 0, 0, time.UTC),
					Status:    "in_progress",
					Body:      "Maintenance is underway. Users may notice intermittent errors when generating new seals.",
				},
				{
					Timestamp: time.Date(2025, 1, 15, 3, 12, 0, 0, time.UTC),
					Status:    "completed",
					Body:      "Maintenance completed successfully. All systems are back to normal.",
				},
			},
		},
		{
			ID:         "incident-2025-01-10",
			Title:      "Delay in Cloud Storage uploads",
			Status:     "resolved",
			Impact:     "minor",
			StartedAt:  time.Date(2025, 1, 10, 10, 12, 0, 0, time.UTC),
			ResolvedAt: time.Date(2025, 1, 10, 11, 25, 0, 0, time.UTC),
			Updates: []IncidentUpdate{
				{
					Timestamp: time.Date(2025, 1, 10, 10, 20, 0, 0, time.UTC),
					Status:    "investigating",
					Body:      "We are investigating increased latency when uploading assets to Cloud Storage. Existing assets remain accessible.",
				},
				{
					Timestamp: time.Date(2025, 1, 10, 10, 52, 0, 0, time.UTC),
					Status:    "mitigating",
					Body:      "Identified a networking issue within the Tokyo region. We routed traffic to an alternate zone while the provider applies a fix.",
				},
				{
					Timestamp: time.Date(2025, 1, 10, 11, 25, 0, 0, time.UTC),
					Status:    "resolved",
					Body:      "Service is fully restored. Upload latency has returned to normal levels.",
				},
			},
		},
	},
	Uptime: UptimeSummary{
		Periods: []UptimePeriod{
			{
				Period:     "7d",
				Label:      "Last 7 days",
				Percentage: 99.982,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 11, 0, 0, 0, 0, time.UTC), Percentage: 99.95},
					{Timestamp: time.Date(2025, 1, 12, 0, 0, 0, 0, time.UTC), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 13, 0, 0, 0, 0, time.UTC), Percentage: 100.0},
					{Timestamp: time.Date(2025, 1, 14, 0, 0, 0, 0, time.UTC), Percentage: 99.99},
					{Timestamp: time.Date(2025, 1, 15, 0, 0, 0, 0, time.UTC), Percentage: 99.96},
					{Timestamp: time.Date(2025, 1, 16, 0, 0, 0, 0, time.UTC), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 17, 0, 0, 0, 0, time.UTC), Percentage: 99.99},
				},
			},
			{
				Period:     "30d",
				Label:      "Last 30 days",
				Percentage: 99.965,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2024, 12, 19, 0, 0, 0, 0, time.UTC), Percentage: 99.92},
					{Timestamp: time.Date(2024, 12, 26, 0, 0, 0, 0, time.UTC), Percentage: 99.94},
					{Timestamp: time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), Percentage: 99.97},
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, time.UTC), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 16, 0, 0, 0, 0, time.UTC), Percentage: 99.99},
				},
			},
			{
				Period:     "90d",
				Label:      "Last 90 days",
				Percentage: 99.947,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2024, 10, 19, 0, 0, 0, 0, time.UTC), Percentage: 99.88},
					{Timestamp: time.Date(2024, 11, 18, 0, 0, 0, 0, time.UTC), Percentage: 99.91},
					{Timestamp: time.Date(2024, 12, 18, 0, 0, 0, 0, time.UTC), Percentage: 99.95},
					{Timestamp: time.Date(2025, 1, 17, 0, 0, 0, 0, time.UTC), Percentage: 99.97},
				},
			},
		},
	},
	Subscriptions: []SubscriptionOption{
		{
			Channel:        "email",
			Title:          "Email alerts",
			Description:    "Get notified when incidents are opened, updated, or resolved.",
			PrimaryLabel:   "Subscribe via email",
			PrimaryURL:     "mailto:status@hanko-field.jp",
			SecondaryLabel: "View message archive",
			SecondaryURL:   "https://status.hanko-field.jp/history",
		},
		{
			Channel:        "webhook",
			Title:          "Webhook",
			Description:    "Receive JSON payloads for status changes in your monitoring pipeline.",
			PrimaryLabel:   "Copy webhook endpoint",
			PrimaryURL:     "https://status.hanko-field.jp/webhook",
			SecondaryLabel: "View schema",
			SecondaryURL:   "https://status.hanko-field.jp/webhook/schema",
		},
		{
			Channel:        "rss",
			Title:          "RSS feed",
			Description:    "Follow incidents using RSS readers or chat integrations.",
			PrimaryLabel:   "Copy RSS URL",
			PrimaryURL:     "https://status.hanko-field.jp/feed.xml",
			SecondaryLabel: "Add to Slack",
			SecondaryURL:   "https://status.hanko-field.jp/integrations/slack",
		},
	},
}

var jaFallback = Summary{
	State:      "operational",
	StateLabel: "全サービス正常稼働中",
	UpdatedAt:  time.Date(2025, 1, 18, 12, 45, 0, 0, fallbackJST),
	Components: []Component{
		{
			Name:          "ウェブ",
			Status:        "operational",
			Slug:          "web",
			Description:   "マーケティングサイト、ドキュメント、埋め込みウィジェットを提供するフロントエンド。",
			Tags:          []string{"web"},
			Primary:       true,
			IncidentCount: 0,
			MTTR:          12 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.982,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, fallbackJST), Percentage: 99.99},
					{Timestamp: time.Date(2025, 1, 12, 0, 0, 0, 0, fallbackJST), Percentage: 99.97},
					{Timestamp: time.Date(2025, 1, 15, 0, 0, 0, 0, fallbackJST), Percentage: 100.0},
				},
			},
			DocsURL: "/guides/platform/web-status",
		},
		{
			Name:          "API",
			Status:        "operational",
			Slug:          "api",
			Description:   "外部システムとの連携を担う REST / GraphQL エンドポイント。",
			Tags:          []string{"api", "backend"},
			Primary:       true,
			IncidentCount: 1,
			MTTR:          32 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.954,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, fallbackJST), Percentage: 99.90},
					{Timestamp: time.Date(2025, 1, 10, 0, 0, 0, 0, fallbackJST), Percentage: 99.82},
					{Timestamp: time.Date(2025, 1, 11, 0, 0, 0, 0, fallbackJST), Percentage: 99.94},
					{Timestamp: time.Date(2025, 1, 13, 0, 0, 0, 0, fallbackJST), Percentage: 99.99},
				},
			},
			DocsURL: "/support/operations/runbooks/api-reliability",
		},
		{
			Name:          "管理コンソール",
			Status:        "operational",
			Slug:          "admin-console",
			Description:   "運用チーム向けのテナント管理ダッシュボード。",
			Tags:          []string{"admin"},
			Primary:       true,
			IncidentCount: 0,
			MTTR:          26 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.968,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 8, 0, 0, 0, 0, fallbackJST), Percentage: 100.0},
					{Timestamp: time.Date(2025, 1, 12, 0, 0, 0, 0, fallbackJST), Percentage: 99.95},
					{Timestamp: time.Date(2025, 1, 16, 0, 0, 0, 0, fallbackJST), Percentage: 99.98},
				},
			},
			DocsURL: "/guides/admin/overview",
		},
		{
			Name:          "リアルタイム通知",
			Status:        "operational",
			Slug:          "realtime",
			Description:   "押印イベントを配信するプッシュ通知基盤。",
			Tags:          []string{"notifications"},
			Primary:       false,
			IncidentCount: 1,
			MTTR:          18 * time.Minute,
			Uptime: ComponentUptime{
				Period:     "30d",
				Percentage: 99.942,
				Target:     99.8,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, fallbackJST), Percentage: 99.86},
					{Timestamp: time.Date(2025, 1, 11, 0, 0, 0, 0, fallbackJST), Percentage: 99.94},
					{Timestamp: time.Date(2025, 1, 15, 0, 0, 0, 0, fallbackJST), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 17, 0, 0, 0, 0, fallbackJST), Percentage: 99.99},
				},
			},
			DocsURL: "/guides/platform/notifications",
		},
	},
	Incidents: []Incident{
		{
			ID:         "sched-maint-2025-01-15",
			Title:      "定期メンテナンス：ドキュメント押印サービス",
			Status:     "completed",
			Impact:     "maintenance",
			StartedAt:  time.Date(2025, 1, 15, 11, 0, 0, 0, fallbackJST),
			ResolvedAt: time.Date(2025, 1, 15, 12, 30, 0, 0, fallbackJST),
			Updates: []IncidentUpdate{
				{
					Timestamp: time.Date(2025, 1, 14, 18, 0, 0, 0, fallbackJST),
					Status:    "scheduled",
					Body:      "ドキュメント押印サービスの定期メンテナンスを実施します。最大30分ほど断続的な停止が発生する見込みです。",
				},
				{
					Timestamp: time.Date(2025, 1, 15, 11, 5, 0, 0, fallbackJST),
					Status:    "in_progress",
					Body:      "メンテナンス作業を開始しました。新規の印影生成がしづらい状態になる場合があります。",
				},
				{
					Timestamp: time.Date(2025, 1, 15, 12, 12, 0, 0, fallbackJST),
					Status:    "completed",
					Body:      "メンテナンスが完了しました。現在は通常どおり利用できます。",
				},
			},
		},
		{
			ID:         "incident-2025-01-10",
			Title:      "クラウドストレージへのアップロード遅延",
			Status:     "resolved",
			Impact:     "minor",
			StartedAt:  time.Date(2025, 1, 10, 19, 12, 0, 0, fallbackJST),
			ResolvedAt: time.Date(2025, 1, 10, 20, 25, 0, 0, fallbackJST),
			Updates: []IncidentUpdate{
				{
					Timestamp: time.Date(2025, 1, 10, 19, 20, 0, 0, fallbackJST),
					Status:    "investigating",
					Body:      "クラウドストレージへのアップロード遅延を調査しています。既存のファイル閲覧には影響ありません。",
				},
				{
					Timestamp: time.Date(2025, 1, 10, 19, 52, 0, 0, fallbackJST),
					Status:    "mitigating",
					Body:      "東京リージョンのネットワーク遅延を特定し、プロバイダの修正を待つ間は別ゾーンへ迂回させています。",
				},
				{
					Timestamp: time.Date(2025, 1, 10, 20, 25, 0, 0, fallbackJST),
					Status:    "resolved",
					Body:      "サービスは復旧しました。アップロード時間は平常値に戻っています。",
				},
			},
		},
	},
	Uptime: UptimeSummary{
		Periods: []UptimePeriod{
			{
				Period:     "7d",
				Label:      "直近7日間",
				Percentage: 99.982,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2025, 1, 11, 0, 0, 0, 0, fallbackJST), Percentage: 99.95},
					{Timestamp: time.Date(2025, 1, 12, 0, 0, 0, 0, fallbackJST), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 13, 0, 0, 0, 0, fallbackJST), Percentage: 100.0},
					{Timestamp: time.Date(2025, 1, 14, 0, 0, 0, 0, fallbackJST), Percentage: 99.99},
					{Timestamp: time.Date(2025, 1, 15, 0, 0, 0, 0, fallbackJST), Percentage: 99.96},
					{Timestamp: time.Date(2025, 1, 16, 0, 0, 0, 0, fallbackJST), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 17, 0, 0, 0, 0, fallbackJST), Percentage: 99.99},
				},
			},
			{
				Period:     "30d",
				Label:      "直近30日間",
				Percentage: 99.965,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2024, 12, 19, 0, 0, 0, 0, fallbackJST), Percentage: 99.92},
					{Timestamp: time.Date(2024, 12, 26, 0, 0, 0, 0, fallbackJST), Percentage: 99.94},
					{Timestamp: time.Date(2025, 1, 2, 0, 0, 0, 0, fallbackJST), Percentage: 99.97},
					{Timestamp: time.Date(2025, 1, 9, 0, 0, 0, 0, fallbackJST), Percentage: 99.98},
					{Timestamp: time.Date(2025, 1, 16, 0, 0, 0, 0, fallbackJST), Percentage: 99.99},
				},
			},
			{
				Period:     "90d",
				Label:      "直近90日間",
				Percentage: 99.947,
				Target:     99.9,
				Trend: []UptimePoint{
					{Timestamp: time.Date(2024, 10, 19, 0, 0, 0, 0, fallbackJST), Percentage: 99.88},
					{Timestamp: time.Date(2024, 11, 18, 0, 0, 0, 0, fallbackJST), Percentage: 99.91},
					{Timestamp: time.Date(2024, 12, 18, 0, 0, 0, 0, fallbackJST), Percentage: 99.95},
					{Timestamp: time.Date(2025, 1, 17, 0, 0, 0, 0, fallbackJST), Percentage: 99.97},
				},
			},
		},
	},
	Subscriptions: []SubscriptionOption{
		{
			Channel:        "email",
			Title:          "メール通知",
			Description:    "インシデントの開始・更新・解決をメールで受け取ります。",
			PrimaryLabel:   "メールで購読する",
			PrimaryURL:     "mailto:status@hanko-field.jp",
			SecondaryLabel: "配信履歴を確認",
			SecondaryURL:   "https://status.hanko-field.jp/history",
		},
		{
			Channel:        "webhook",
			Title:          "Webhook",
			Description:    "ステータス変更を JSON 形式で監視システムに送信します。",
			PrimaryLabel:   "Webhook エンドポイントをコピー",
			PrimaryURL:     "https://status.hanko-field.jp/webhook",
			SecondaryLabel: "スキーマを見る",
			SecondaryURL:   "https://status.hanko-field.jp/webhook/schema",
		},
		{
			Channel:        "rss",
			Title:          "RSS フィード",
			Description:    "RSS リーダーやチャット連携でインシデントを追跡できます。",
			PrimaryLabel:   "RSS URL をコピー",
			PrimaryURL:     "https://status.hanko-field.jp/feed.xml",
			SecondaryLabel: "Slack に追加",
			SecondaryURL:   "https://status.hanko-field.jp/integrations/slack",
		},
	},
}

func parseTime(value string) time.Time {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, value); err == nil {
			return t
		}
	}
	return time.Time{}
}

func normalizeLang(lang string) string {
	lang = strings.ToLower(strings.TrimSpace(lang))
	if lang == "" {
		return "ja"
	}
	switch lang {
	case "ja", "en":
		return lang
	}
	if strings.HasPrefix(lang, "ja") {
		return "ja"
	}
	return "en"
}
