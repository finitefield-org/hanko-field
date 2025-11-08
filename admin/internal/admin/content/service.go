package content

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sort"
	"strings"
	"sync"
	"time"
)

// ErrNotConfigured indicates the content service dependency has not been provided.
var ErrNotConfigured = errors.New("content service not configured")

// ErrGuideNotFound signals that the requested guide could not be located.
var ErrGuideNotFound = errors.New("guide not found")

// ErrPageNotFound signals that the requested page could not be located.
var ErrPageNotFound = errors.New("page not found")

// ErrGuideHistoryNotFound indicates the requested historical version is missing.
var ErrGuideHistoryNotFound = errors.New("guide history entry not found")

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
	// PreviewGuide returns a localized preview payload for the requested guide.
	PreviewGuide(ctx context.Context, token string, guideID string, locale string) (GuidePreview, error)
	// EditorGuide returns the data required to render the guide editor experience.
	EditorGuide(ctx context.Context, token string, guideID string) (GuideEditor, error)
	// GuideHistory returns historical revisions associated with the guide.
	GuideHistory(ctx context.Context, token string, guideID string) ([]GuideHistoryEntry, error)
	// GuideRevert restores the draft to the snapshot stored in the specified history entry.
	GuideRevert(ctx context.Context, token string, guideID string, historyID string, actor string) (GuideDraft, error)
	// PreviewDraft renders a preview for the supplied draft values without persisting changes.
	PreviewDraft(ctx context.Context, token string, guideID string, draft GuideDraftInput) (GuidePreview, error)
	// ListPages returns the content page hierarchy matching the supplied query.
	ListPages(ctx context.Context, token string, query PageQuery) (PageTree, error)
	// PageEditor returns the data required to render the page editor workspace.
	PageEditor(ctx context.Context, token string, pageID string) (PageEditor, error)
	// PagePreview returns a localized preview payload for the requested page.
	PagePreview(ctx context.Context, token string, pageID string, locale string) (PagePreview, error)
	// PagePreviewDraft renders a preview using unsaved page draft values.
	PagePreviewDraft(ctx context.Context, token string, pageID string, draft PageDraftInput) (PagePreview, error)
	// PageSaveDraft persists draft metadata for the page (placeholder implementation).
	PageSaveDraft(ctx context.Context, token string, pageID string, draft PageDraftInput) (PageDraft, error)
	// PageTogglePublish toggles the publish status for a page.
	PageTogglePublish(ctx context.Context, token string, pageID string, publish bool) (Page, error)
	// PageSchedule updates or clears the scheduled publish timestamp for a page.
	PageSchedule(ctx context.Context, token string, pageID string, scheduledAt *time.Time) (Page, error)
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

// GuidePreview bundles data required to render a localized preview.
type GuidePreview struct {
	Guide       Guide
	Locales     []GuideLocale
	ShareURL    string
	ExternalURL string
	Content     GuidePreviewContent
	Notes       []string
	Feedback    GuidePreviewFeedback
}

// GuideLocale represents a selectable locale for a given guide.
type GuideLocale struct {
	Locale string
	Label  string
	Active bool
}

// GuidePreviewContent contains the rendered HTML payload.
type GuidePreviewContent struct {
	HeroImageURL string
	BodyHTML     string
}

// GuidePreviewFeedback provides links for workflow actions.
type GuidePreviewFeedback struct {
	ApproveURL         string
	RequestChangesURL  string
	CommentPlaceholder string
}

// GuideDraft represents the editable fields for a localized guide.
type GuideDraft struct {
	Locale       string
	Title        string
	Summary      string
	HeroImageURL string
	BodyHTML     string
	Persona      string
	Category     string
	Tags         []string
	LastSavedAt  time.Time
	LastSavedBy  string
}

// GuideEditor bundles guide data and supporting metadata for the editor UI.
type GuideEditor struct {
	Guide   Guide
	Draft   GuideDraft
	Locales []GuideLocale
	History []GuideHistoryEntry
}

// GuideDraftInput captures unsaved form values used to generate live previews.
type GuideDraftInput struct {
	Locale       string
	Title        string
	Summary      string
	HeroImageURL string
	BodyHTML     string
	Persona      string
	Category     string
	Tags         []string
}

// GuideHistoryEntry represents a stored version of a guide along with diff metadata.
type GuideHistoryEntry struct {
	ID         string
	Title      string
	Summary    string
	Actor      string
	Version    string
	OccurredAt time.Time
	Tone       string
	Icon       string
	DiffHTML   string
	Snapshot   GuideHistorySnapshot
}

// GuideHistorySnapshot captures the editable fields at the time of the change.
type GuideHistorySnapshot struct {
	Locale       string
	Title        string
	Summary      string
	HeroImageURL string
	BodyHTML     string
	Persona      string
	Category     string
	Tags         []string
}

// StaticService is an in-memory implementation of the Service interface suitable for local development.
type StaticService struct {
	mu             sync.RWMutex
	guides         []Guide
	previews       map[string]previewEntry
	drafts         map[string]GuideDraft
	guideHistory   map[string][]GuideHistoryEntry
	pages          []Page
	pageDrafts     map[string]PageDraft
	pagePreviews   map[string]pagePreviewEntry
	pageLocales    map[string][]PageLocale
	pageProperties map[string]PageProperties
	pageSchedules  map[string]PageSchedule
	pageHistory    map[string][]PageHistoryEntry
	pagePalette    []PageBlockPaletteGroup
	pageStructure  []pageTreeNodeDef
}

type previewEntry struct {
	HeroImageURL string
	BodyHTML     string
	Notes        []string
	ShareURL     string
	ExternalURL  string
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

	guides := []Guide{
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
			ID:           "guide-getting-started-en",
			Slug:         "welcome-to-hanko",
			Title:        "Getting Started with Hanko Field",
			Summary:      "A walkthrough of the onboarding flow and initial configuration for new teams.",
			Category:     "basics",
			Persona:      "newcomer",
			Locale:       "en-US",
			Author:       "Hannah Ito",
			Status:       GuideStatusDraft,
			UpdatedAt:    now.Add(-8 * time.Hour),
			UpdatedBy:    "Hannah Ito",
			HeroImageURL: "https://images.example.com/guides/onboarding.jpg",
			WordCount:    1750,
			Tags:         []string{"onboarding", "setup"},
			Highlights: []GuideHighlight{
				{Label: "Translation", Value: "In review", Icon: "🌐"},
			},
			LastChangeNote: "Proofread English copy and awaiting localization QA.",
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
	}

	previews := map[string]previewEntry{
		previewKey("welcome-to-hanko", "ja-JP"): {
			HeroImageURL: "https://images.example.com/guides/onboarding.jpg",
			BodyHTML: `<article class="prose prose-slate max-w-none">
  <h1>はじめての判子フィールド</h1>
  <p class="lead">オンボーディングの流れと初期設定を順番に説明します。現場チームが迷わないよう、スクリーンショットとチェックリストをセットで掲載しています。</p>
  <h2>セットアップ前の準備</h2>
  <ul>
    <li>管理者アカウントを作成し、2段階認証を有効化する</li>
    <li>工房プロフィールに住所・営業時間を登録する</li>
    <li>既存テンプレートを棚卸しし、公開済み／下書き状態を確認する</li>
  </ul>
  <h2>初回ログインとダッシュボード</h2>
  <p>ダッシュボードでは最新の生産状況と公開ガイドのパフォーマンスを確認できます。新規ユーザーは「ようこそツアー」を完了し、主要メニューの位置を把握しましょう。</p>
  <blockquote>ヒント: 生産ラインを登録する前に、サンプル印材を登録してテスト注文を行うとスムーズです。</blockquote>
  <h2>次のステップ</h2>
  <p>オンボーディング完了後は、品質チェックワークフローとローカライズの優先順位を調整してください。</p>
</article>`,
			Notes: []string{
				"公開前にQAが実施されます。ガイド内のリンク切れに注意してください。",
			},
			ShareURL:    "https://preview.hanko.example/guides/welcome-to-hanko?lang=ja-JP&token=draft-ja",
			ExternalURL: "https://www.hanko.example/guides/welcome-to-hanko?lang=ja-JP",
		},
		previewKey("welcome-to-hanko", "en-US"): {
			HeroImageURL: "https://images.example.com/guides/onboarding.jpg",
			BodyHTML: `<article class="prose prose-slate max-w-none">
  <h1>Getting Started with Hanko Field</h1>
  <p class="lead">This guide walks new teams through onboarding, workspace configuration, and the first set of publishing tasks.</p>
  <h2>Before You Begin</h2>
  <ol>
    <li>Create an admin account and enable multi-factor authentication.</li>
    <li>Complete the workspace profile with address, business hours, and contact information.</li>
    <li>Review existing guide drafts to understand tone and taxonomy.</li>
  </ol>
  <h2>First Login Checklist</h2>
  <p>On first login, complete the welcome tour to learn the layout. The dashboard highlights production queues, draft guides, and localization tasks.</p>
  <h2>Next Steps</h2>
  <p>Collaborate with the localization team to confirm terminology and schedule the launch campaign.</p>
</article>`,
			Notes: []string{
				"Localization review blocked until style guide updates land.",
			},
			ShareURL:    "https://preview.hanko.example/guides/welcome-to-hanko?lang=en-US&token=draft-en",
			ExternalURL: "https://www.hanko.example/guides/welcome-to-hanko?lang=en-US",
		},
	}

	guideDrafts := make(map[string]GuideDraft, len(guides))
	for _, guide := range guides {
		entry := previews[previewKey(guide.Slug, guide.Locale)]
		body := strings.TrimSpace(entry.BodyHTML)
		if body == "" {
			body = defaultPreviewBody(guide)
		}
		hero := strings.TrimSpace(entry.HeroImageURL)
		if hero == "" {
			hero = guide.HeroImageURL
		}
		guideDrafts[guide.ID] = GuideDraft{
			Locale:       guide.Locale,
			Title:        guide.Title,
			Summary:      guide.Summary,
			HeroImageURL: hero,
			BodyHTML:     body,
			Persona:      guide.Persona,
			Category:     guide.Category,
			Tags:         append([]string(nil), guide.Tags...),
			LastSavedAt:  guide.UpdatedAt,
			LastSavedBy:  guide.UpdatedBy,
		}
	}

	guideHistory := map[string][]GuideHistoryEntry{
		"guide-getting-started-ja": {
			{
				ID:         "hist-guide-getting-started-ja-v1-4-3",
				Title:      "QAチェックリストを更新",
				Summary:    "QA手順のセクションを最新化しました。",
				Actor:      "中村 麻衣",
				Version:    "v1.4.3",
				OccurredAt: now.Add(-30 * time.Hour),
				Tone:       "info",
				Icon:       "🛠",
				DiffHTML: `<div class="space-y-2 text-sm">
  <ins class="block rounded bg-emerald-50 px-3 py-2 text-emerald-700">追加: QAチェックリストに自動テスト項目を追加</ins>
  <del class="block rounded bg-red-50 px-3 py-2 text-red-600">削除: 二重記載されていた確認タスク</del>
</div>`,
				Snapshot: GuideHistorySnapshot{
					Locale:       "ja-JP",
					Title:        "はじめての判子フィールド",
					Summary:      "オンボーディングの流れと初期設定を順番に説明します。",
					HeroImageURL: "https://images.example.com/guides/onboarding.jpg",
					BodyHTML: `<article class="prose prose-slate max-w-none">
  <h2>QAチェックリスト</h2>
  <ol>
    <li>管理者アカウントでテスト注文を作成</li>
    <li>QA担当者が承認コメントを記録</li>
    <li>サインオフ後に公開タスクへ移行</li>
  </ol>
</article>`,
					Persona:  "newcomer",
					Category: "basics",
					Tags:     []string{"オンボーディング", "設定"},
				},
			},
			{
				ID:         "hist-guide-getting-started-ja-v1-4-2",
				Title:      "リード文のトーンを調整",
				Summary:    "導入文でオンボーディングの流れを明記しました。",
				Actor:      "中村 麻衣",
				Version:    "v1.4.2",
				OccurredAt: now.Add(-72 * time.Hour),
				Tone:       "success",
				Icon:       "✏️",
				DiffHTML:   `<p class="text-sm text-slate-600"><mark>リード文</mark>に「オンボーディングの流れ」を追加しました。</p>`,
				Snapshot: GuideHistorySnapshot{
					Locale:       "ja-JP",
					Title:        "はじめての判子フィールド",
					Summary:      "オンボーディングの流れと初期設定を順番に説明します。",
					HeroImageURL: "https://images.example.com/guides/onboarding.jpg",
					BodyHTML: `<article class="prose prose-slate max-w-none">
  <h1>はじめての判子フィールド</h1>
  <p class="lead">オンボーディングの流れを5つのステップで整理しました。</p>
  <p>初回設定を円滑に進めるための手順をまとめています。</p>
</article>`,
					Persona:  "newcomer",
					Category: "basics",
					Tags:     []string{"オンボーディング", "設定"},
				},
			},
		},
		"guide-brand-story": {
			{
				ID:         "hist-guide-brand-story-v2-1",
				Title:      "ブランドメッセージを刷新",
				Summary:    "ビジョンの段落にCrafted Togetherの表現を追加しました。",
				Actor:      "松本 彩",
				Version:    "v2.1.0",
				OccurredAt: now.Add(-96 * time.Hour),
				Tone:       "info",
				Icon:       "✨",
				DiffHTML:   `<p class="text-sm text-slate-600">ブランドビジョンに <ins>Crafted Together</ins> の表現を組み込みました。</p>`,
				Snapshot: GuideHistorySnapshot{
					Locale:       "ja-JP",
					Title:        "ブランドストーリー更新ガイド",
					Summary:      "ブランドストーリーの更新手順とコンテンツ要素のチェックリスト。",
					HeroImageURL: "https://images.example.com/guides/brand.jpg",
					BodyHTML: `<article class="prose prose-slate max-w-none">
  <h2>ブランドビジョン</h2>
  <p>Hanko Fieldは <strong>Crafted Together</strong> を合言葉に、全国の工房と共に新しいものづくり体験を届けます。</p>
  <p>言語トーンは温度感のある丁寧語で統一し、ストーリー性を重視してください。</p>
</article>`,
					Persona:  "marketer",
					Category: "marketing",
					Tags:     []string{"ブランド", "マーケティング"},
				},
			},
		},
	}

	pageDataset := buildStaticPages(now)

	return &StaticService{
		guides:         guides,
		previews:       previews,
		drafts:         guideDrafts,
		guideHistory:   guideHistory,
		pages:          pageDataset.pages,
		pageDrafts:     pageDataset.drafts,
		pagePreviews:   pageDataset.previews,
		pageLocales:    pageDataset.locales,
		pageProperties: pageDataset.properties,
		pageSchedules:  pageDataset.schedules,
		pageHistory:    pageDataset.history,
		pagePalette:    pageDataset.palette,
		pageStructure:  pageDataset.structure,
	}
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
		return Guide{}, ErrGuideNotFound
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
		return Guide{}, ErrGuideNotFound
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

// PreviewGuide implements Service.
func (s *StaticService) PreviewGuide(_ context.Context, _ string, guideID string, locale string) (GuidePreview, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	idx := s.indexOfLocked(guideID)
	if idx < 0 {
		return GuidePreview{}, ErrGuideNotFound
	}

	active := cloneGuide(s.guides[idx])
	requested := strings.TrimSpace(locale)
	if requested != "" && !strings.EqualFold(requested, active.Locale) {
		for _, candidate := range s.guides {
			if candidate.Slug == active.Slug && strings.EqualFold(candidate.Locale, requested) {
				active = cloneGuide(candidate)
				break
			}
		}
	}

	locales := s.localesForSlug(active.Slug, active.Locale)

	entry, ok := s.previews[previewKey(active.Slug, active.Locale)]
	if !ok {
		entry = previewEntry{}
	}

	hero := strings.TrimSpace(entry.HeroImageURL)
	if hero == "" {
		hero = active.HeroImageURL
	}

	body := strings.TrimSpace(entry.BodyHTML)
	if body == "" {
		body = defaultPreviewBody(active)
	}
	body = sanitizeMarkup(body)

	notes := append([]string(nil), entry.Notes...)
	if len(notes) == 0 && strings.TrimSpace(active.LastChangeNote) != "" {
		notes = []string{active.LastChangeNote}
	}

	shareURL := strings.TrimSpace(entry.ShareURL)
	if shareURL == "" {
		shareURL = fmt.Sprintf("https://preview.hanko.example/guides/%s?lang=%s&token=draft", active.Slug, active.Locale)
	}

	externalURL := strings.TrimSpace(entry.ExternalURL)
	if externalURL == "" {
		externalURL = fmt.Sprintf("https://www.hanko.example/guides/%s?lang=%s", active.Slug, active.Locale)
	}

	feedback := GuidePreviewFeedback{
		ApproveURL:         fmt.Sprintf("https://api.hanko.example/admin/content/guides/%s:approve", active.ID),
		RequestChangesURL:  fmt.Sprintf("https://api.hanko.example/admin/content/guides/%s:request-changes", active.ID),
		CommentPlaceholder: "レビューメモを残してください…",
	}

	return GuidePreview{
		Guide:       active,
		Locales:     locales,
		ShareURL:    shareURL,
		ExternalURL: externalURL,
		Content: GuidePreviewContent{
			HeroImageURL: hero,
			BodyHTML:     body,
		},
		Notes:    notes,
		Feedback: feedback,
	}, nil
}

// EditorGuide implements Service.
func (s *StaticService) EditorGuide(_ context.Context, _ string, guideID string) (GuideEditor, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	idx := s.indexOfLocked(guideID)
	if idx < 0 {
		return GuideEditor{}, ErrGuideNotFound
	}

	guide := cloneGuide(s.guides[idx])
	draft, ok := s.drafts[guide.ID]
	if !ok {
		entry := s.previews[previewKey(guide.Slug, guide.Locale)]
		body := strings.TrimSpace(entry.BodyHTML)
		if body == "" {
			body = defaultPreviewBody(guide)
		}
		hero := strings.TrimSpace(entry.HeroImageURL)
		if hero == "" {
			hero = guide.HeroImageURL
		}
		draft = GuideDraft{
			Locale:       guide.Locale,
			Title:        guide.Title,
			Summary:      guide.Summary,
			HeroImageURL: hero,
			BodyHTML:     body,
			Persona:      guide.Persona,
			Category:     guide.Category,
			Tags:         append([]string(nil), guide.Tags...),
			LastSavedAt:  guide.UpdatedAt,
			LastSavedBy:  guide.UpdatedBy,
		}
	}
	locales := s.localesForSlug(guide.Slug, guide.Locale)
	history := sanitizeGuideHistory(s.guideHistory[guide.ID])

	return GuideEditor{
		Guide:   guide,
		Draft:   draft,
		Locales: locales,
		History: history,
	}, nil
}

// GuideHistory implements Service.
func (s *StaticService) GuideHistory(_ context.Context, _ string, guideID string) ([]GuideHistoryEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	idx := s.indexOfLocked(guideID)
	if idx < 0 {
		return nil, ErrGuideNotFound
	}

	return sanitizeGuideHistory(s.guideHistory[guideID]), nil
}

// PreviewDraft implements Service.
func (s *StaticService) PreviewDraft(_ context.Context, _ string, guideID string, draft GuideDraftInput) (GuidePreview, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	idx := s.indexOfLocked(guideID)
	if idx < 0 {
		return GuidePreview{}, ErrGuideNotFound
	}

	active := cloneGuide(s.guides[idx])
	requestedLocale := strings.TrimSpace(draft.Locale)
	if requestedLocale != "" && !strings.EqualFold(requestedLocale, active.Locale) {
		for _, candidate := range s.guides {
			if candidate.Slug == active.Slug && strings.EqualFold(candidate.Locale, requestedLocale) {
				active = cloneGuide(candidate)
				break
			}
		}
	}

	if val := strings.TrimSpace(draft.Title); val != "" {
		active.Title = val
	}
	active.Summary = strings.TrimSpace(draft.Summary)
	active.Persona = strings.TrimSpace(draft.Persona)
	active.Category = strings.TrimSpace(draft.Category)
	active.HeroImageURL = strings.TrimSpace(draft.HeroImageURL)
	if draft.Tags != nil {
		if len(draft.Tags) == 0 {
			active.Tags = nil
		} else {
			active.Tags = append([]string(nil), draft.Tags...)
		}
	}

	locales := s.localesForSlug(active.Slug, active.Locale)

	entry := s.previews[previewKey(active.Slug, active.Locale)]

	hero := strings.TrimSpace(draft.HeroImageURL)
	if hero == "" {
		hero = strings.TrimSpace(entry.HeroImageURL)
	}
	if hero == "" {
		hero = active.HeroImageURL
	}

	body := strings.TrimSpace(draft.BodyHTML)
	if body == "" {
		body = strings.TrimSpace(entry.BodyHTML)
	}
	if body == "" {
		body = defaultPreviewBody(active)
	}
	body = sanitizeMarkup(body)

	notes := append([]string(nil), entry.Notes...)
	notes = append(notes, "ライブプレビュー: 未保存の変更が表示されています。")

	shareURL := strings.TrimSpace(entry.ShareURL)
	if shareURL == "" {
		shareURL = fmt.Sprintf("https://preview.hanko.example/guides/%s?lang=%s&token=draft", active.Slug, active.Locale)
	}

	externalURL := strings.TrimSpace(entry.ExternalURL)
	if externalURL == "" {
		externalURL = fmt.Sprintf("https://www.hanko.example/guides/%s?lang=%s", active.Slug, active.Locale)
	}

	feedback := GuidePreviewFeedback{
		ApproveURL:         fmt.Sprintf("https://api.hanko.example/admin/content/guides/%s:approve", active.ID),
		RequestChangesURL:  fmt.Sprintf("https://api.hanko.example/admin/content/guides/%s:request-changes", active.ID),
		CommentPlaceholder: "レビューメモを残してください…",
	}

	return GuidePreview{
		Guide:       active,
		Locales:     locales,
		ShareURL:    shareURL,
		ExternalURL: externalURL,
		Content: GuidePreviewContent{
			HeroImageURL: hero,
			BodyHTML:     body,
		},
		Notes:    notes,
		Feedback: feedback,
	}, nil
}

// GuideRevert implements Service.
func (s *StaticService) GuideRevert(_ context.Context, _ string, guideID string, historyID string, actor string) (GuideDraft, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	idx := s.indexOfLocked(guideID)
	if idx < 0 {
		return GuideDraft{}, ErrGuideNotFound
	}

	entries := s.guideHistory[guideID]
	var entry *GuideHistoryEntry
	for i := range entries {
		if entries[i].ID == historyID {
			entry = &entries[i]
			break
		}
	}
	if entry == nil {
		return GuideDraft{}, ErrGuideHistoryNotFound
	}

	if strings.TrimSpace(actor) == "" {
		actor = "system"
	}

	snapshot := entry.Snapshot
	body := sanitizeMarkup(snapshot.BodyHTML)
	now := time.Now()

	guide := s.guides[idx]
	if strings.TrimSpace(snapshot.Locale) != "" {
		guide.Locale = snapshot.Locale
	}
	if strings.TrimSpace(snapshot.Title) != "" {
		guide.Title = snapshot.Title
	}
	guide.Summary = snapshot.Summary
	guide.Persona = snapshot.Persona
	guide.Category = snapshot.Category
	if snapshot.Tags != nil {
		guide.Tags = append([]string(nil), snapshot.Tags...)
	} else {
		guide.Tags = nil
	}
	if strings.TrimSpace(snapshot.HeroImageURL) != "" {
		guide.HeroImageURL = snapshot.HeroImageURL
	}
	guide.UpdatedAt = now
	guide.UpdatedBy = actor
	guide.StatusLabel, guide.StatusTone = statusPresentation(guide.Status)
	s.guides[idx] = guide

	draft := s.drafts[guideID]
	if strings.TrimSpace(snapshot.Locale) != "" {
		draft.Locale = snapshot.Locale
	}
	draft.Title = snapshot.Title
	draft.Summary = snapshot.Summary
	draft.HeroImageURL = snapshot.HeroImageURL
	draft.BodyHTML = body
	draft.Persona = snapshot.Persona
	draft.Category = snapshot.Category
	if snapshot.Tags != nil {
		draft.Tags = append([]string(nil), snapshot.Tags...)
	} else {
		draft.Tags = nil
	}
	draft.LastSavedAt = now
	draft.LastSavedBy = actor
	s.drafts[guideID] = draft

	versionLabel := strings.TrimSpace(entry.Version)
	if versionLabel == "" {
		versionLabel = strings.TrimSpace(entry.Title)
	}
	if versionLabel == "" {
		versionLabel = "以前のバージョン"
	}

	newSnapshot := GuideHistorySnapshot{
		Locale:       draft.Locale,
		Title:        draft.Title,
		Summary:      draft.Summary,
		HeroImageURL: draft.HeroImageURL,
		BodyHTML:     draft.BodyHTML,
		Persona:      draft.Persona,
		Category:     draft.Category,
	}
	if draft.Tags != nil {
		newSnapshot.Tags = append([]string(nil), draft.Tags...)
	}

	revertEntry := GuideHistoryEntry{
		ID:         fmt.Sprintf("%s-revert-%d", guideID, now.UnixNano()),
		Title:      "以前のバージョンを復元",
		Summary:    fmt.Sprintf("%s が %s を復元しました。", actor, versionLabel),
		Actor:      actor,
		Version:    versionLabel,
		OccurredAt: now,
		Tone:       "warning",
		Icon:       "↩️",
		DiffHTML:   sanitizeMarkup(fmt.Sprintf(`<p class="text-sm text-slate-600">%s へロールバックしました。</p>`, versionLabel)),
		Snapshot:   newSnapshot,
	}

	s.guideHistory[guideID] = append([]GuideHistoryEntry{revertEntry}, entries...)

	log.Printf("guide: %s reverted to %s by %s", guideID, historyID, actor)

	return draft, nil
}

func (s *StaticService) localesForSlug(slug string, activeLocale string) []GuideLocale {
	seen := make(map[string]bool)
	locales := make([]GuideLocale, 0, len(s.guides))
	for _, guide := range s.guides {
		if guide.Slug != slug {
			continue
		}
		if seen[guide.Locale] {
			continue
		}
		locales = append(locales, GuideLocale{
			Locale: guide.Locale,
			Label:  previewLocaleLabel(guide.Locale),
			Active: guide.Locale == activeLocale,
		})
		seen[guide.Locale] = true
	}

	sort.SliceStable(locales, func(i, j int) bool {
		if locales[i].Active && !locales[j].Active {
			return true
		}
		if locales[j].Active && !locales[i].Active {
			return false
		}
		return locales[i].Label < locales[j].Label
	})
	return locales
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

func cloneGuideHistory(entries []GuideHistoryEntry) []GuideHistoryEntry {
	if len(entries) == 0 {
		return nil
	}
	cloned := make([]GuideHistoryEntry, len(entries))
	for i, entry := range entries {
		copyEntry := entry
		if entry.Snapshot.Tags != nil {
			copyEntry.Snapshot.Tags = append([]string(nil), entry.Snapshot.Tags...)
		}
		cloned[i] = copyEntry
	}
	return cloned
}

func sanitizeGuideHistory(entries []GuideHistoryEntry) []GuideHistoryEntry {
	cloned := cloneGuideHistory(entries)
	for i := range cloned {
		cloned[i].DiffHTML = sanitizeMarkup(cloned[i].DiffHTML)
		cloned[i].Snapshot.BodyHTML = sanitizeMarkup(cloned[i].Snapshot.BodyHTML)
	}
	return cloned
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

func previewKey(slug string, locale string) string {
	return strings.TrimSpace(slug) + "|" + strings.TrimSpace(locale)
}

func defaultPreviewBody(guide Guide) string {
	summary := strings.TrimSpace(guide.Summary)
	if summary == "" {
		summary = "コンテンツの準備が進行中です。"
	}
	return fmt.Sprintf(`<article class="prose prose-slate max-w-none">
  <h1>%s</h1>
  <p class="lead">%s</p>
  <p>このセクションはまもなく更新されます。最新の原稿を準備中です。</p>
</article>`, guide.Title, summary)
}

func previewLocaleLabel(locale string) string {
	switch strings.TrimSpace(locale) {
	case "ja-JP":
		return "日本語"
	case "en-US":
		return "English"
	default:
		return locale
	}
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
