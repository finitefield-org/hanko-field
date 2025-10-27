package content

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

// ErrNotConfigured indicates the content service dependency has not been provided.
var ErrNotConfigured = errors.New("content service not configured")

// Service exposes CMS guide management capabilities.
type Service interface {
	// ListGuides returns guides matching the supplied query.
	ListGuides(ctx context.Context, token string, query GuideQuery) (GuideFeed, error)
	// TogglePublish updates the publish state for a single guide.
	TogglePublish(ctx context.Context, token string, guideID string, publish bool) (Guide, error)
	// Schedule updates or clears the scheduled publish timestamp for a guide.
	Schedule(ctx context.Context, token string, guideID string, scheduledAt *time.Time) (Guide, error)
	// Archive marks guides as archived in bulk.
	BulkArchive(ctx context.Context, token string, guideIDs []string) ([]Guide, error)
	// BulkPublish toggles guides to the published state in bulk.
	BulkPublish(ctx context.Context, token string, guideIDs []string) ([]Guide, error)
	// BulkUnschedule clears scheduled publish dates for the provided guides.
	BulkUnschedule(ctx context.Context, token string, guideIDs []string) ([]Guide, error)
}

// GuideStatus enumerates the lifecycle states for guides.
type GuideStatus string

const (
	// GuideStatusDraft indicates the guide is a draft.
	GuideStatusDraft GuideStatus = "draft"
	// GuideStatusScheduled indicates the guide has a future publish schedule.
	GuideStatusScheduled GuideStatus = "scheduled"
	// GuideStatusPublished indicates the guide is published.
	GuideStatusPublished GuideStatus = "published"
	// GuideStatusArchived indicates the guide is archived.
	GuideStatusArchived GuideStatus = "archived"
)

// Guide represents a localized guide entry.
type Guide struct {
	ID             string
	Slug           string
	Title          string
	Summary        string
	Category       string
	Persona        string
	Locale         string
	Author         string
	Status         GuideStatus
	StatusLabel    string
	StatusTone     string
	PublishedAt    *time.Time
	ScheduledAt    *time.Time
	UpdatedAt      time.Time
	UpdatedBy      string
	HeroImageURL   string
	ReadingTime    string
	WordCount      int
	Tags           []string
	Upcoming       []GuideChange
	Highlights     []GuideHighlight
	LastChangeNote string
}

// GuideChange represents an upcoming change or historical entry.
type GuideChange struct {
	Title       string
	Description string
	OccursAt    time.Time
	Actor       string
	Tone        string
	Icon        string
}

// GuideHighlight summarises key metrics for the drawer.
type GuideHighlight struct {
	Label string
	Value string
	Icon  string
	Tone  string
}

// GuideFeed represents a list response for guides.
type GuideFeed struct {
	Items          []Guide
	Total          int
	Counts         GuideSummaryCounts
	StatusCounts   map[GuideStatus]int
	CategoryCounts map[string]int
	PersonaCounts  map[string]int
	LocaleCounts   map[string]int
}

// GuideSummaryCounts aggregates totals for summary chips.
type GuideSummaryCounts struct {
	Total     int
	Published int
	Draft     int
	Scheduled int
	Archived  int
}

// GuideQuery captures filter arguments when listing guides.
type GuideQuery struct {
	Search       string
	Persona      string
	Status       GuideStatus
	Category     string
	Locale       string
	ScheduleDate *time.Time
	SelectedIDs  []string
}

// StaticService is an in-memory implementation of the Service interface suitable for local development.
type StaticService struct {
	mu     sync.RWMutex
	guides []Guide
}

// NewStaticService constructs a StaticService populated with representative data.
func NewStaticService() *StaticService {
	now := time.Now()
	inHours := func(hours int) *time.Time {
		ts := now.Add(time.Duration(hours) * time.Hour)
		return &ts
	}

	makeGuide := func(base Guide) Guide {
		if strings.TrimSpace(base.ID) == "" {
			base.ID = "guide-" + strings.ReplaceAll(strings.ToLower(base.Title), " ", "-")
		}
		base.StatusLabel, base.StatusTone = statusPresentation(base.Status)
		if base.ReadingTime == "" && base.WordCount > 0 {
			base.ReadingTime = estimateReadingTime(base.WordCount)
		}
		if base.UpdatedAt.IsZero() {
			base.UpdatedAt = now.Add(-time.Duration(len(base.ID)) * time.Hour)
		}
		return base
	}

	svc := &StaticService{
		guides: []Guide{
			makeGuide(Guide{
				ID:           "guide-getting-started-ja",
				Slug:         "welcome-to-hanko",
				Title:        "はじめての判子フィールド",
				Summary:      "オンボーディングの流れと初期設定を順番に説明します。",
				Category:     "basics",
				Persona:      "newcomer",
				Locale:       "ja-JP",
				Author:       "中村 麻衣",
				Status:       GuideStatusPublished,
				PublishedAt:  inHours(-72),
				UpdatedAt:    now.Add(-6 * time.Hour),
				UpdatedBy:    "中村 麻衣",
				HeroImageURL: "https://images.example.com/guides/onboarding.jpg",
				WordCount:    1800,
				Tags:         []string{"オンボーディング", "設定"},
				Highlights: []GuideHighlight{
					{Label: "平均読了", Value: estimateReadingTime(1800), Icon: "⏱"},
					{Label: "直帰率", Value: "12%", Icon: "📉"},
				},
				LastChangeNote: "画像を最新版に差し替えました。",
				Upcoming: []GuideChange{
					{
						Title:       "FAQ セクション追記",
						Description: "よくある質問を追加して問い合わせ削減を図ります。",
						OccursAt:    now.Add(48 * time.Hour),
						Actor:       "中村 麻衣",
						Tone:        "info",
						Icon:        "📝",
					},
				},
			}),
			makeGuide(Guide{
				ID:           "guide-workshop-safety",
				Slug:         "workshop-safety-checklist",
				Title:        "工房安全チェックリスト",
				Summary:      "安全な工房運営のための毎日の確認事項。",
				Category:     "operations",
				Persona:      "artisan",
				Locale:       "ja-JP",
				Author:       "田中 隼人",
				Status:       GuideStatusScheduled,
				ScheduledAt:  inHours(36),
				UpdatedAt:    now.Add(-12 * time.Hour),
				UpdatedBy:    "田中 隼人",
				HeroImageURL: "https://images.example.com/guides/safety.jpg",
				WordCount:    2400,
				Tags:         []string{"工房", "安全"},
				Highlights: []GuideHighlight{
					{Label: "レビュー待ち", Value: "品質管理", Icon: "👀"},
				},
				LastChangeNote: "監査チームによる最終レビュー待ちです。",
				Upcoming: []GuideChange{
					{
						Title:       "公開予定",
						Description: now.Add(36 * time.Hour).Format("2006-01-02 15:04"),
						OccursAt:    now.Add(36 * time.Hour),
						Actor:       "自動公開",
						Tone:        "warning",
						Icon:        "⏳",
					},
				},
			}),
			makeGuide(Guide{
				ID:           "guide-locale-en",
				Slug:         "custom-engraving-en",
				Title:        "Custom Engraving Workflow",
				Summary:      "A walkthrough of the custom engraving process for English-speaking operators.",
				Category:     "operations",
				Persona:      "operator",
				Locale:       "en-US",
				Author:       "Hannah Ito",
				Status:       GuideStatusDraft,
				UpdatedAt:    now.Add(-3 * time.Hour),
				UpdatedBy:    "Hannah Ito",
				HeroImageURL: "https://images.example.com/guides/engraving.jpg",
				WordCount:    2100,
				Tags:         []string{"engraving", "workflow"},
				Highlights: []GuideHighlight{
					{Label: "翻訳進捗", Value: "80%", Icon: "🌐"},
				},
				LastChangeNote: "英語翻訳を追加しました。最終レビューが必要です。",
			}),
			makeGuide(Guide{
				ID:           "guide-brand-story",
				Slug:         "brand-story",
				Title:        "ブランドストーリー更新ガイド",
				Summary:      "ブランドストーリーの更新手順とコンテンツ要素のチェックリスト。",
				Category:     "marketing",
				Persona:      "marketer",
				Locale:       "ja-JP",
				Author:       "松本 彩",
				Status:       GuideStatusPublished,
				PublishedAt:  inHours(-240),
				UpdatedAt:    now.Add(-72 * time.Hour),
				UpdatedBy:    "松本 彩",
				HeroImageURL: "https://images.example.com/guides/brand.jpg",
				WordCount:    3200,
				Tags:         []string{"ブランド", "マーケティング"},
				Highlights: []GuideHighlight{
					{Label: "平均評価", Value: "4.8/5", Icon: "⭐", Tone: "success"},
				},
				LastChangeNote: "ブランドボイスガイドラインを最新のものに差し替えました。",
			}),
			makeGuide(Guide{
				ID:           "guide-seasonal-campaign",
				Slug:         "seasonal-campaign-launch",
				Title:        "季節キャンペーンの準備",
				Summary:      "季節ごとのキャンペーン準備とチェックリスト。",
				Category:     "marketing",
				Persona:      "marketer",
				Locale:       "ja-JP",
				Author:       "佐藤 未来",
				Status:       GuideStatusArchived,
				PublishedAt:  inHours(-720),
				UpdatedAt:    now.Add(-500 * time.Hour),
				UpdatedBy:    "佐藤 未来",
				HeroImageURL: "https://images.example.com/guides/campaign.jpg",
				WordCount:    2600,
				Tags:         []string{"キャンペーン"},
				Highlights: []GuideHighlight{
					{Label: "最終更新", Value: relative(now.Add(-500 * time.Hour)), Icon: "🗓"},
				},
				LastChangeNote: "昨年のキャンペーンアーカイブとして保存しています。",
			}),
		},
	}
	return svc
}

// ListGuides implements Service.
func (s *StaticService) ListGuides(_ context.Context, _ string, query GuideQuery) (GuideFeed, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	filtered := make([]Guide, 0, len(s.guides))
	normalized := normalizeQuery(query)

	for _, guide := range s.guides {
		if !matchesQuery(guide, normalized) {
			continue
		}
		filtered = append(filtered, cloneGuide(guide))
	}

	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].UpdatedAt.After(filtered[j].UpdatedAt)
	})

	summary, statusCounts, categoryCounts, personaCounts, localeCounts := s.aggregateLocked()

	return GuideFeed{
		Items:          filtered,
		Total:          len(filtered),
		Counts:         summary,
		StatusCounts:   statusCounts,
		CategoryCounts: categoryCounts,
		PersonaCounts:  personaCounts,
		LocaleCounts:   localeCounts,
	}, nil
}

// TogglePublish implements Service.
func (s *StaticService) TogglePublish(_ context.Context, _ string, guideID string, publish bool) (Guide, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	idx := s.indexOfLocked(guideID)
	if idx < 0 {
		return Guide{}, errors.New("guide not found")
	}

	now := time.Now()
	guide := s.guides[idx]
	if publish {
		guide.Status = GuideStatusPublished
		guide.PublishedAt = timePtr(now)
		guide.ScheduledAt = nil
		guide.LastChangeNote = "公開ステータスに更新しました。"
	} else {
		guide.Status = GuideStatusDraft
		guide.PublishedAt = nil
		guide.LastChangeNote = "公開解除されました。"
	}
	guide.StatusLabel, guide.StatusTone = statusPresentation(guide.Status)
	guide.UpdatedAt = now
	guide.UpdatedBy = "システム"

	s.guides[idx] = guide
	return cloneGuide(guide), nil
}

// Schedule implements Service.
func (s *StaticService) Schedule(_ context.Context, _ string, guideID string, scheduledAt *time.Time) (Guide, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	idx := s.indexOfLocked(guideID)
	if idx < 0 {
		return Guide{}, errors.New("guide not found")
	}

	now := time.Now()
	guide := s.guides[idx]
	if scheduledAt != nil && !scheduledAt.IsZero() {
		guide.Status = GuideStatusScheduled
		guide.ScheduledAt = timePtr(scheduledAt.In(time.Local))
		guide.PublishedAt = nil
		guide.LastChangeNote = "公開予定を更新しました。"
		guide.Upcoming = append(guide.Upcoming, GuideChange{
			Title:       "公開予定",
			Description: guide.ScheduledAt.Format("2006-01-02 15:04"),
			OccursAt:    guide.ScheduledAt.In(time.Local),
			Actor:       "自動公開",
			Tone:        "info",
			Icon:        "📆",
		})
	} else {
		guide.ScheduledAt = nil
		if guide.Status == GuideStatusScheduled {
			guide.Status = GuideStatusDraft
		}
		guide.LastChangeNote = "公開予定を解除しました。"
	}
	guide.StatusLabel, guide.StatusTone = statusPresentation(guide.Status)
	guide.UpdatedAt = now
	guide.UpdatedBy = "システム"

	s.guides[idx] = guide
	return cloneGuide(guide), nil
}

// BulkArchive implements Service.
func (s *StaticService) BulkArchive(_ context.Context, _ string, guideIDs []string) ([]Guide, error) {
	return s.bulkUpdate(guideIDs, func(g Guide) Guide {
		g.Status = GuideStatusArchived
		g.PublishedAt = nil
		g.ScheduledAt = nil
		g.LastChangeNote = "アーカイブしました。"
		return g
	})
}

// BulkPublish implements Service.
func (s *StaticService) BulkPublish(_ context.Context, _ string, guideIDs []string) ([]Guide, error) {
	return s.bulkUpdate(guideIDs, func(g Guide) Guide {
		ts := time.Now()
		g.Status = GuideStatusPublished
		g.PublishedAt = timePtr(ts)
		g.ScheduledAt = nil
		g.LastChangeNote = "一括公開しました。"
		return g
	})
}

// BulkUnschedule implements Service.
func (s *StaticService) BulkUnschedule(_ context.Context, _ string, guideIDs []string) ([]Guide, error) {
	return s.bulkUpdate(guideIDs, func(g Guide) Guide {
		g.ScheduledAt = nil
		if g.Status == GuideStatusScheduled {
			g.Status = GuideStatusDraft
		}
		g.LastChangeNote = "公開予定を一括解除しました。"
		return g
	})
}

func (s *StaticService) bulkUpdate(guideIDs []string, mutate func(Guide) Guide) ([]Guide, error) {
	if len(guideIDs) == 0 {
		return nil, nil
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	updated := make([]Guide, 0, len(guideIDs))
	for _, id := range guideIDs {
		idx := s.indexOfLocked(id)
		if idx < 0 {
			continue
		}
		guide := s.guides[idx]
		guide = mutate(guide)
		guide.StatusLabel, guide.StatusTone = statusPresentation(guide.Status)
		guide.UpdatedAt = now
		guide.UpdatedBy = "システム"
		s.guides[idx] = guide
		updated = append(updated, cloneGuide(guide))
	}
	return updated, nil
}

func (s *StaticService) indexOfLocked(id string) int {
	for idx, guide := range s.guides {
		if guide.ID == id {
			return idx
		}
	}
	return -1
}

func (s *StaticService) aggregateLocked() (GuideSummaryCounts, map[GuideStatus]int, map[string]int, map[string]int, map[string]int) {
	summary := GuideSummaryCounts{}
	statusCounts := make(map[GuideStatus]int)
	categoryCounts := make(map[string]int)
	personaCounts := make(map[string]int)
	localeCounts := make(map[string]int)

	for _, guide := range s.guides {
		summary.Total++
		statusCounts[guide.Status]++
		categoryCounts[guide.Category]++
		personaCounts[guide.Persona]++
		localeCounts[guide.Locale]++

		switch guide.Status {
		case GuideStatusDraft:
			summary.Draft++
		case GuideStatusPublished:
			summary.Published++
		case GuideStatusScheduled:
			summary.Scheduled++
		case GuideStatusArchived:
			summary.Archived++
		}
	}
	return summary, statusCounts, categoryCounts, personaCounts, localeCounts
}

func cloneGuide(src Guide) Guide {
	dst := src
	if len(src.Tags) > 0 {
		dst.Tags = append([]string(nil), src.Tags...)
	}
	if len(src.Upcoming) > 0 {
		dst.Upcoming = append([]GuideChange(nil), src.Upcoming...)
	}
	if len(src.Highlights) > 0 {
		dst.Highlights = append([]GuideHighlight(nil), src.Highlights...)
	}
	return dst
}

func matchesQuery(guide Guide, query GuideQuery) bool {
	if query.Status != "" && guide.Status != query.Status {
		return false
	}
	if query.Persona != "" && guide.Persona != query.Persona {
		return false
	}
	if query.Category != "" && guide.Category != query.Category {
		return false
	}
	if query.Locale != "" && guide.Locale != query.Locale {
		return false
	}
	if query.ScheduleDate != nil {
		if guide.ScheduledAt == nil {
			return false
		}
		target := guide.ScheduledAt.In(time.Local)
		sought := query.ScheduleDate.In(time.Local)
		if target.Year() != sought.Year() || target.YearDay() != sought.YearDay() {
			return false
		}
	}
	if query.Search != "" {
		if !strings.Contains(strings.ToLower(guide.Title), query.Search) &&
			!strings.Contains(strings.ToLower(guide.Summary), query.Search) &&
			!strings.Contains(strings.ToLower(guide.Author), query.Search) {
			return false
		}
	}
	return true
}

func normalizeQuery(q GuideQuery) GuideQuery {
	q.Search = strings.ToLower(strings.TrimSpace(q.Search))
	q.Persona = strings.TrimSpace(q.Persona)
	q.Category = strings.TrimSpace(q.Category)
	q.Locale = strings.TrimSpace(q.Locale)
	if q.Status != "" {
		q.Status = GuideStatus(strings.TrimSpace(string(q.Status)))
	}
	return q
}

func statusPresentation(status GuideStatus) (label string, tone string) {
	switch status {
	case GuideStatusPublished:
		return "公開中", "success"
	case GuideStatusScheduled:
		return "公開予定", "warning"
	case GuideStatusArchived:
		return "アーカイブ", "info"
	default:
		return "下書き", "info"
	}
}

func estimateReadingTime(wordCount int) string {
	if wordCount <= 0 {
		return ""
	}
	minutes := wordCount / 280
	if minutes < 1 {
		minutes = 1
	}
	return fmt.Sprintf("%d分", minutes)
}

func relative(ts time.Time) string {
	diff := time.Since(ts)
	if diff < time.Minute {
		return "たった今"
	}
	if diff < time.Hour {
		return fmt.Sprintf("%d分前", int(diff.Minutes()))
	}
	if diff < 24*time.Hour {
		return fmt.Sprintf("%d時間前", int(diff.Hours()))
	}
	return ts.In(time.Local).Format("2006-01-02")
}

func timePtr(ts time.Time) *time.Time {
	v := ts
	return &v
}
