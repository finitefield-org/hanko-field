package catalog

import (
	"context"
	"sort"
	"strings"
	"time"
)

type staticService struct {
	assets         map[Kind][]catalogAsset
	lookup         map[Kind]map[string]catalogAsset
	updatedPresets []UpdatedRange
}

type catalogAsset struct {
	item   Item
	detail ItemDetail
}

// NewStaticService seeds the catalog UI with representative fixtures.
func NewStaticService() Service {
	now := time.Date(2024, time.March, 18, 12, 0, 0, 0, time.UTC)
	service := &staticService{
		assets: map[Kind][]catalogAsset{
			KindTemplates: buildTemplateAssets(now),
			KindFonts:     buildFontAssets(now),
			KindMaterials: buildMaterialAssets(now),
			KindProducts:  buildProductAssets(now),
		},
		updatedPresets: []UpdatedRange{
			{Value: "24h", Label: "24時間以内", Hint: "直近 24h 更新"},
			{Value: "3d", Label: "直近3日", Hint: "レビュー対象"},
			{Value: "7d", Label: "今週", Hint: "SLA 7日"},
			{Value: "30d", Label: "今月", Hint: "キャンペーン準備"},
		},
	}

	service.lookup = make(map[Kind]map[string]catalogAsset, len(service.assets))
	for kind, list := range service.assets {
		m := make(map[string]catalogAsset, len(list))
		for _, asset := range list {
			m[asset.item.ID] = asset
		}
		service.lookup[kind] = m
	}
	return service
}

func (s *staticService) ListAssets(ctx context.Context, token string, query ListQuery) (ListResult, error) {
	kind := query.Kind
	if kind == "" {
		kind = KindTemplates
	}

	view := NormalizeViewMode(string(query.View))
	assets := s.assets[kind]
	filtered := filterAssets(assets, query)

	items := make([]Item, 0, len(filtered))
	for _, asset := range filtered {
		items = append(items, asset.item)
	}

	selectedID := strings.TrimSpace(query.SelectedID)
	var selectedDetail *ItemDetail

	if selectedID != "" {
		if detail, ok := s.lookup[kind][selectedID]; ok {
			copyDetail := detail.detail
			selectedDetail = &copyDetail
		}
	}
	if selectedDetail == nil && len(filtered) > 0 {
		selectedID = filtered[0].item.ID
		copyDetail := filtered[0].detail
		selectedDetail = &copyDetail
	}

	summary := buildSummary(kind, filtered)
	filters := s.buildFilters(kind, assets, query)
	bulk := BulkSummary{
		Eligible: len(filtered),
		Actions:  defaultBulkActions(kind),
	}

	emptyMsg := ""
	if len(filtered) == 0 {
		emptyMsg = "該当するアセットが見つかりません。フィルタ条件を調整してください。"
	}

	return ListResult{
		Kind:           kind,
		Items:          items,
		Summary:        summary,
		Filters:        filters,
		Bulk:           bulk,
		View:           view,
		SelectedID:     selectedID,
		SelectedDetail: selectedDetail,
		EmptyMessage:   emptyMsg,
	}, nil
}

func filterAssets(assets []catalogAsset, query ListQuery) []catalogAsset {
	if len(assets) == 0 {
		return nil
	}

	statusFilter := make(map[Status]struct{}, len(query.Statuses))
	for _, status := range query.Statuses {
		statusFilter[status] = struct{}{}
	}

	tagFilter := normalizeStrings(query.Tags)
	search := strings.ToLower(strings.TrimSpace(query.Search))
	owner := strings.ToLower(strings.TrimSpace(query.Owner))

	result := make([]catalogAsset, 0, len(assets))
	for _, asset := range assets {
		if len(statusFilter) > 0 {
			if _, ok := statusFilter[asset.item.Status]; !ok {
				continue
			}
		}

		if owner != "" && owner != strings.ToLower(asset.item.Owner.Name) {
			continue
		}

		if len(tagFilter) > 0 {
			if !containsAnyTag(asset.item.Tags, tagFilter) {
				continue
			}
		}

		if search != "" && !matchesSearch(asset.item, search) {
			continue
		}

		result = append(result, asset)
	}
	return result
}

func matchesSearch(item Item, query string) bool {
	values := []string{
		strings.ToLower(item.Name),
		strings.ToLower(item.Identifier),
		strings.ToLower(item.Description),
	}
	for _, tag := range item.Tags {
		values = append(values, strings.ToLower(tag))
	}
	for _, value := range values {
		if strings.Contains(value, query) {
			return true
		}
	}
	return false
}

func containsAnyTag(tags []string, filter map[string]struct{}) bool {
	for _, tag := range tags {
		if _, ok := filter[strings.ToLower(tag)]; ok {
			return true
		}
	}
	return false
}

func normalizeStrings(values []string) map[string]struct{} {
	result := make(map[string]struct{}, len(values))
	for _, value := range values {
		value = strings.ToLower(strings.TrimSpace(value))
		if value == "" {
			continue
		}
		result[value] = struct{}{}
	}
	return result
}

func buildSummary(kind Kind, assets []catalogAsset) Summary {
	summary := Summary{
		PrimaryLabel: kind.Label(),
	}
	summary.Total = len(assets)
	var latest time.Time
	for _, asset := range assets {
		switch asset.item.Status {
		case StatusPublished:
			summary.Published++
		case StatusDraft:
			summary.Drafts++
		case StatusArchived:
			summary.Archived++
		case StatusInReview:
			summary.InReview++
		}
		if asset.item.UpdatedAt.After(latest) {
			latest = asset.item.UpdatedAt
		}
	}
	summary.LastUpdated = latest
	return summary
}

func (s *staticService) buildFilters(kind Kind, assets []catalogAsset, query ListQuery) FilterSummary {
	filter := FilterSummary{}
	filter.Statuses = buildStatusOptions(assets, query.Statuses)
	filter.Owners = buildOwnerOptions(assets, query.Owner)
	filter.Tags = buildTagOptions(assets, query.Tags)
	filter.UpdatedRanges = markActiveRanges(s.updatedPresets, query.UpdatedRange)
	return filter
}

func buildStatusOptions(assets []catalogAsset, active []Status) []FilterOption {
	counts := map[Status]int{}
	for _, asset := range assets {
		counts[asset.item.Status]++
	}

	activeSet := make(map[Status]struct{}, len(active))
	for _, s := range active {
		activeSet[s] = struct{}{}
	}

	statuses := []Status{StatusPublished, StatusDraft, StatusInReview, StatusArchived}
	result := make([]FilterOption, 0, len(statuses))
	for _, status := range statuses {
		result = append(result, FilterOption{
			Value:  string(status),
			Label:  statusLabel(status),
			Count:  counts[status],
			Active: hasStatus(activeSet, status),
		})
	}
	return result
}

func statusLabel(status Status) string {
	switch status {
	case StatusDraft:
		return "下書き"
	case StatusInReview:
		return "レビュー中"
	case StatusArchived:
		return "アーカイブ"
	default:
		return "公開中"
	}
}

func hasStatus(set map[Status]struct{}, status Status) bool {
	_, ok := set[status]
	return ok
}

func buildOwnerOptions(assets []catalogAsset, active string) []FilterOption {
	counts := map[string]int{}
	labels := map[string]string{}
	for _, asset := range assets {
		key := strings.ToLower(asset.item.Owner.Name)
		counts[key]++
		labels[key] = asset.item.Owner.Name
	}

	keys := make([]string, 0, len(labels))
	for key := range labels {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	activeKey := strings.ToLower(strings.TrimSpace(active))
	result := make([]FilterOption, 0, len(keys))
	for _, key := range keys {
		result = append(result, FilterOption{
			Value:  key,
			Label:  labels[key],
			Count:  counts[key],
			Active: key == activeKey && activeKey != "",
		})
	}
	return result
}

func buildTagOptions(assets []catalogAsset, active []string) []FilterOption {
	counts := map[string]int{}
	for _, asset := range assets {
		for _, tag := range asset.item.Tags {
			key := strings.ToLower(tag)
			counts[key]++
		}
	}

	keys := make([]string, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	activeSet := normalizeStrings(active)
	result := make([]FilterOption, 0, len(keys))
	for _, key := range keys {
		_, selected := activeSet[key]
		result = append(result, FilterOption{
			Value:  key,
			Label:  key,
			Count:  counts[key],
			Active: selected,
		})
	}
	return result
}

func markActiveRanges(ranges []UpdatedRange, active string) []UpdatedRange {
	result := make([]UpdatedRange, len(ranges))
	activeValue := strings.TrimSpace(active)
	for i, preset := range ranges {
		result[i] = preset
		result[i].Active = preset.Value == activeValue && activeValue != ""
	}
	return result
}

func defaultBulkActions(kind Kind) []BulkAction {
	return []BulkAction{
		{
			Value:       "publish",
			Label:       "公開",
			Tone:        "primary",
			Description: "選択したアセットをまとめて公開します。",
		},
		{
			Value:       "unpublish",
			Label:       "公開停止",
			Tone:        "secondary",
			Description: "非公開にし、下書きに戻します。",
		},
		{
			Value:       "archive",
			Label:       "アーカイブ",
			Tone:        "danger",
			Description: "公開停止し、アーカイブへ移動します。",
		},
	}
}

func makeCatalogAsset(item Item, detail ItemDetail) catalogAsset {
	detail.Item = item
	if detail.Owner.Name == "" {
		detail.Owner = item.Owner
	}
	if len(detail.Tags) == 0 {
		detail.Tags = item.Tags
	}
	if detail.UpdatedAt.IsZero() {
		detail.UpdatedAt = item.UpdatedAt
	}
	return catalogAsset{item: item, detail: detail}
}

func buildTemplateAssets(now time.Time) []catalogAsset {
	base := now
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:          "tmpl-2024-fuji",
				Name:        "2024年 年賀状（富士）",
				Identifier:  "TMP-2024-FUJI",
				Kind:        KindTemplates,
				Status:      StatusPublished,
				StatusLabel: "公開中",
				StatusTone:  "success",
				Description: "富士山と朝日の伝統的な構図に、箔押しテクスチャを合わせた人気テンプレート。",
				Owner: OwnerInfo{
					Name:  "Akari Sato",
					Email: "akari.sato@example.com",
				},
				UpdatedAt:    base.Add(-4 * time.Hour),
				Version:      "v12",
				UsageCount:   4821,
				UsageLabel:   "4,821件の注文",
				Tags:         []string{"newyear", "featured", "2024"},
				PreviewURL:   "/public/static/placeholders/catalog-template-fuji.png",
				PreviewAlt:   "富士山テンプレート",
				Channels:     []string{"アプリ", "Web"},
				Format:       "148x100mm",
				PrimaryColor: "#F97316",
				Metrics: []ItemMetric{
					{Label: "CVR", Value: "3.2%", Icon: "📈"},
					{Label: "保存", Value: "1,204", Icon: "⭐"},
				},
				Badge:     "キャンペーン",
				BadgeTone: "info",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-template-fuji.png",
				PreviewAlt:  "富士山テンプレート",
				Description: "年末年始のトップセラー。メインの背景イラストはベクター化されているため、箔や特色にも対応可能です。",
				Usage: []UsageMetric{
					{Label: "今週", Value: "912 件", Icon: "🗓"},
					{Label: "リピート率", Value: "28%", Icon: "🔁"},
				},
				Metadata: []MetadataEntry{
					{Key: "カテゴリ", Value: "年賀状 > プレミアム", Icon: "🏷"},
					{Key: "チャネル", Value: "iOS / Web", Icon: "🌐"},
					{Key: "最終更新", Value: base.Add(-4 * time.Hour).Format("2006-01-02 15:04"), Icon: "⏱"},
				},
				Dependencies: []Dependency{
					{Label: "フォント: Hanko Serif", Kind: "font", Status: "承認済み", Tone: "success"},
					{Label: "素材: 和紙パール", Kind: "material", Status: "在庫 64%", Tone: "warning"},
				},
				AuditTrail: []AuditEntry{
					{Timestamp: base.Add(-4 * time.Hour), Actor: "Akari Sato", Action: "配色を更新", Channel: "web"},
					{Timestamp: base.Add(-26 * time.Hour), Actor: "Nobu Kato", Action: "レビュー承認", Channel: "mobile"},
				},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "tmpl-minimal-stamp",
				Name:        "ミニマル判子フレーム",
				Identifier:  "TMP-MINIMAL-STAMP",
				Kind:        KindTemplates,
				Status:      StatusDraft,
				StatusLabel: "下書き",
				StatusTone:  "warning",
				Description: "シンプルな三日月判子をアクセントにしたミニマルデザイン。法人挨拶状に最適。",
				Owner: OwnerInfo{
					Name:  "Nobu Kato",
					Email: "nobu.kato@example.com",
				},
				UpdatedAt:    base.Add(-30 * time.Hour),
				Version:      "v3",
				UsageCount:   0,
				UsageLabel:   "未公開",
				Tags:         []string{"b2b", "minimal", "draft"},
				PreviewURL:   "/public/static/placeholders/catalog-template-stamp.png",
				PreviewAlt:   "ミニマルテンプレート",
				Channels:     []string{"Web"},
				Format:       "210x148mm",
				PrimaryColor: "#0F172A",
				Metrics: []ItemMetric{
					{Label: "想定単価", Value: "¥1,280", Icon: "💰"},
				},
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-template-stamp.png",
				Description: "法人用テンプレート。ロゴ差し替えと箔押し指定に対応予定。",
				Usage: []UsageMetric{
					{Label: "カスタマイズ", Value: "12 件", Icon: "✏️"},
				},
				Metadata: []MetadataEntry{
					{Key: "対象", Value: "B2B", Icon: "🏢"},
					{Key: "最終更新", Value: base.Add(-30 * time.Hour).Format("2006-01-02 15:04"), Icon: "⏱"},
				},
				Dependencies: []Dependency{
					{Label: "フォント: Maru Gothic", Kind: "font", Status: "レビュー待ち", Tone: "info"},
				},
				AuditTrail: []AuditEntry{
					{Timestamp: base.Add(-30 * time.Hour), Actor: "Nobu Kato", Action: "下書きを保存", Channel: "web"},
				},
				Tags: []string{"b2b", "minimal"},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "tmpl-collage-story",
				Name:        "写真コラージュ・ストーリー",
				Identifier:  "TMP-COLLAGE-STORY",
				Kind:        KindTemplates,
				Status:      StatusInReview,
				StatusLabel: "レビュー中",
				StatusTone:  "info",
				Description: "最大 6 枚の写真を柔軟にレイアウトできるファミリー向けテンプレート。",
				Owner: OwnerInfo{
					Name:  "Akari Sato",
					Email: "akari.sato@example.com",
				},
				UpdatedAt:    base.Add(-12 * time.Hour),
				Version:      "v5",
				UsageCount:   240,
				UsageLabel:   "テスト利用 240 件",
				Tags:         []string{"family", "photo", "beta"},
				PreviewURL:   "/public/static/placeholders/catalog-template-collage.png",
				PreviewAlt:   "コラージュテンプレート",
				Channels:     []string{"iOS", "Android"},
				Format:       "148x100mm",
				PrimaryColor: "#0EA5E9",
				Metrics: []ItemMetric{
					{Label: "保存率", Value: "62%", Icon: "💾"},
					{Label: "レビュー", Value: "⭐4.6", Icon: "💬"},
				},
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-template-collage.png",
				Description: "写真アップロードを前提とした UI 変更を伴うテンプレート。利用ログは計測済み。",
				Usage: []UsageMetric{
					{Label: "ベータ", Value: "240 件", Icon: "🧪"},
				},
				Metadata: []MetadataEntry{
					{Key: "チャネル", Value: "Mobile", Icon: "📱"},
					{Key: "承認ステータス", Value: "QA中", Icon: "🧪"},
				},
				Dependencies: []Dependency{
					{Label: "素材: リネンホワイト", Kind: "material", Status: "在庫良好", Tone: "success"},
					{Label: "フォント: Rounded Sans", Kind: "font", Status: "公開中", Tone: "success"},
				},
				AuditTrail: []AuditEntry{
					{Timestamp: base.Add(-12 * time.Hour), Actor: "QA Bot", Action: "UI自動テスト", Channel: "ci"},
				},
			},
		),
	}
}

func buildFontAssets(now time.Time) []catalogAsset {
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:          "font-hanko-serif",
				Name:        "Hanko Serif JP",
				Identifier:  "FNT-HANKO-SERIF",
				Kind:        KindFonts,
				Status:      StatusPublished,
				StatusLabel: "公開中",
				StatusTone:  "success",
				Description: "判子のエッジをモチーフにしたセリフ体。小サイズでも可読性を維持。",
				Owner: OwnerInfo{
					Name:  "Mika Ito",
					Email: "mika.ito@example.com",
				},
				UpdatedAt:    now.Add(-48 * time.Hour),
				Version:      "1.8.2",
				UsageCount:   1280,
				UsageLabel:   "利用 1,280 件",
				Tags:         []string{"serif", "brand", "jp"},
				PreviewURL:   "/public/static/placeholders/catalog-font-serif.png",
				PreviewAlt:   "Hanko Serif",
				Channels:     []string{"Canvas", "Renderer"},
				Format:       "OTF",
				PrimaryColor: "#F97316",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-font-serif.png",
				Description: "本文・見出し兼用のブランドフォント。可変版も準備中。",
				Metadata: []MetadataEntry{
					{Key: "フォーマット", Value: "OTF / WOFF2", Icon: "📦"},
					{Key: "ライセンス", Value: "商用 / Web", Icon: "⚖️"},
				},
				Usage: []UsageMetric{
					{Label: "テンプレ適用", Value: "58%", Icon: "🧩"},
				},
				Dependencies: []Dependency{
					{Label: "Renderer pipeline", Kind: "service", Status: "v2.3", Tone: "info"},
				},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "font-brushwave",
				Name:        "Brush Wave",
				Identifier:  "FNT-BRUSH-WAVE",
				Kind:        KindFonts,
				Status:      StatusPublished,
				StatusLabel: "公開中",
				StatusTone:  "success",
				Description: "毛筆の揺らぎを活かした手書き風フォント。賀詞に人気。",
				Owner: OwnerInfo{
					Name:  "Mika Ito",
					Email: "mika.ito@example.com",
				},
				UpdatedAt:    now.Add(-72 * time.Hour),
				Version:      "2.0.0",
				UsageCount:   824,
				UsageLabel:   "使用 824 件",
				Tags:         []string{"brush", "seasonal"},
				PreviewURL:   "/public/static/placeholders/catalog-font-brush.png",
				PreviewAlt:   "Brush Wave",
				Channels:     []string{"Renderer"},
				Format:       "TTF",
				PrimaryColor: "#A855F7",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-font-brush.png",
				Description: "濃淡を保持したSVGグリフを同梱。Web Canvas で最適化済み。",
				Dependencies: []Dependency{
					{Label: "OpenType Layout", Kind: "feature", Status: "完成", Tone: "success"},
				},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "font-classic-slab",
				Name:        "Classic Slab",
				Identifier:  "FNT-CLASSIC-SLAB",
				Kind:        KindFonts,
				Status:      StatusArchived,
				StatusLabel: "アーカイブ",
				StatusTone:  "muted",
				Description: "旧世代テンプレート用のセリフ体。互換性維持のためのみ提供。",
				Owner: OwnerInfo{
					Name:  "Mika Ito",
					Email: "mika.ito@example.com",
				},
				UpdatedAt:    now.Add(-500 * time.Hour),
				Version:      "0.9.1",
				UsageCount:   12,
				UsageLabel:   "互換用",
				Tags:         []string{"legacy"},
				PreviewURL:   "/public/static/placeholders/catalog-font-slab.png",
				PreviewAlt:   "Classic Slab",
				Channels:     []string{"Renderer"},
				Format:       "OTF",
				PrimaryColor: "#475569",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-font-slab.png",
				Description: "旧バッチとの互換性を保つためアーカイブ。依存テンプレートの移行完了後に削除予定。",
				Dependencies: []Dependency{
					{Label: "テンプレ: TMP-LEGACY-01", Kind: "template", Status: "移行中", Tone: "warning"},
				},
			},
		),
	}
}

func buildMaterialAssets(now time.Time) []catalogAsset {
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:          "mat-washi-pearl",
				Name:        "和紙パール 0.26mm",
				Identifier:  "MAT-WASHI-PEARL",
				Kind:        KindMaterials,
				Status:      StatusPublished,
				StatusLabel: "供給中",
				StatusTone:  "success",
				Description: "細かなパール粒子を含んだ和紙。高級感と発色を両立。",
				Owner: OwnerInfo{
					Name:  "Hiro Tanaka",
					Email: "hiro.tanaka@example.com",
				},
				UpdatedAt:    now.Add(-6 * time.Hour),
				Version:      "Lot 2024-03",
				UsageCount:   1920,
				UsageLabel:   "稼働率 84%",
				Tags:         []string{"premium", "washi"},
				PreviewURL:   "/public/static/placeholders/catalog-material-washi.png",
				PreviewAlt:   "和紙サンプル",
				Channels:     []string{"Factory A"},
				Format:       "Sheet",
				PrimaryColor: "#60A5FA",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-material-washi.png",
				Description: "富士和紙工房からの限定ロット。吸湿による伸縮があるため、保管環境注意。",
				Metadata: []MetadataEntry{
					{Key: "坪量", Value: "216 g/m²", Icon: "⚖️"},
					{Key: "在庫", Value: "4,600枚", Icon: "📦"},
				},
				Dependencies: []Dependency{
					{Label: "仕入れ: FW-PEARL-24-03", Kind: "PO", Status: "入庫済み", Tone: "success"},
				},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "mat-recycled-kraft",
				Name:        "再生クラフト 0.18mm",
				Identifier:  "MAT-RECYCLE-KRAFT",
				Kind:        KindMaterials,
				Status:      StatusDraft,
				StatusLabel: "テスト中",
				StatusTone:  "warning",
				Description: "100%再生紙のクラフト。温かみとエコ訴求向き。",
				Owner: OwnerInfo{
					Name:  "Hiro Tanaka",
					Email: "hiro.tanaka@example.com",
				},
				UpdatedAt:    now.Add(-20 * time.Hour),
				Version:      "Prototype",
				UsageCount:   48,
				UsageLabel:   "試験ロット",
				Tags:         []string{"eco", "draft"},
				PreviewURL:   "/public/static/placeholders/catalog-material-kraft.png",
				PreviewAlt:   "クラフト紙",
				Channels:     []string{"Factory B"},
				Format:       "Roll",
				PrimaryColor: "#B45309",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-material-kraft.png",
				Description: "オンデマンド印刷での乾燥テスト中。表面コーティングを追加予定。",
				Dependencies: []Dependency{
					{Label: "印刷ラインB", Kind: "line", Status: "調整中", Tone: "info"},
				},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "mat-metallic-gold",
				Name:        "メタリックゴールドフィルム",
				Identifier:  "MAT-METALLIC-GOLD",
				Kind:        KindMaterials,
				Status:      StatusPublished,
				StatusLabel: "供給中",
				StatusTone:  "success",
				Description: "鏡面ゴールドのフィルム。箔押し圧を強めることで発色が安定。",
				Owner: OwnerInfo{
					Name:  "Hiro Tanaka",
					Email: "hiro.tanaka@example.com",
				},
				UpdatedAt:    now.Add(-90 * time.Hour),
				Version:      "Lot 2024-02B",
				UsageCount:   312,
				UsageLabel:   "リードタイム 5日",
				Tags:         []string{"metallic", "foil"},
				PreviewURL:   "/public/static/placeholders/catalog-material-metallic.png",
				PreviewAlt:   "ゴールドフィルム",
				Channels:     []string{"Factory A"},
				Format:       "Roll",
				PrimaryColor: "#FACC15",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-material-metallic.png",
				Description: "華やかなゴールド加工用フィルム。粘着層が厚いため低温保管が必須。",
				Metadata: []MetadataEntry{
					{Key: "推奨温度", Value: "18℃", Icon: "🌡"},
				},
				Dependencies: []Dependency{
					{Label: "サプライヤー: TK Metals", Kind: "vendor", Status: "契約更新", Tone: "warning"},
				},
			},
		),
	}
}

func buildProductAssets(now time.Time) []catalogAsset {
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:          "prd-nenga-kit",
				Name:        "年賀状プレミアムセット",
				Identifier:  "PRD-NENGA-PREMIUM",
				Kind:        KindProducts,
				Status:      StatusPublished,
				StatusLabel: "販売中",
				StatusTone:  "success",
				Description: "テンプレ + 素材 + 投函代行を含む人気セット。平均単価 ¥4,980。",
				Owner: OwnerInfo{
					Name:  "Kana Fujii",
					Email: "kana.fujii@example.com",
				},
				UpdatedAt:    now.Add(-10 * time.Hour),
				Version:      "Bundle v6",
				UsageCount:   1420,
				UsageLabel:   "販売 1,420 件",
				Tags:         []string{"bundle", "seasonal"},
				PreviewURL:   "/public/static/placeholders/catalog-product-kit.png",
				PreviewAlt:   "年賀状セット",
				Channels:     []string{"App", "Web"},
				Format:       "Bundle",
				PrimaryColor: "#EF4444",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-product-kit.png",
				Description: "テンプレート3種 + プレミアム素材 + 投函代行クレジットを含むセット。オプションにフォント追加を予定。",
				Usage: []UsageMetric{
					{Label: "平均単価", Value: "¥5,420", Icon: "💴"},
					{Label: "粗利", Value: "48%", Icon: "📊"},
				},
				Dependencies: []Dependency{
					{Label: "素材: 和紙パール", Kind: "material", Status: "供給中", Tone: "success"},
					{Label: "テンプレ: TMP-2024-FUJI", Kind: "template", Status: "公開中", Tone: "success"},
				},
				AuditTrail: []AuditEntry{
					{Timestamp: now.Add(-10 * time.Hour), Actor: "Kana Fujii", Action: "価格を更新 (¥4,980→¥5,200)", Channel: "web"},
				},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "prd-engraved-stamp",
				Name:        "真鍮製はんこ + 桐箱",
				Identifier:  "PRD-ENGRAVED-STAMP",
				Kind:        KindProducts,
				Status:      StatusInReview,
				StatusLabel: "準備中",
				StatusTone:  "info",
				Description: "真鍮の印鑑と桐箱のセット。発送リードタイム 7 日。",
				Owner: OwnerInfo{
					Name:  "Kana Fujii",
					Email: "kana.fujii@example.com",
				},
				UpdatedAt:    now.Add(-36 * time.Hour),
				Version:      "Pilot",
				UsageCount:   120,
				UsageLabel:   "先行販売 120 件",
				Tags:         []string{"gift", "pilot"},
				PreviewURL:   "/public/static/placeholders/catalog-product-stamp.png",
				PreviewAlt:   "真鍮はんこ",
				Channels:     []string{"App"},
				Format:       "Bundle",
				PrimaryColor: "#F59E0B",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-product-stamp.png",
				Description: "ギフト需要向け。刻印 API の検証が完了次第ローンチ予定。",
				Dependencies: []Dependency{
					{Label: "刻印API", Kind: "service", Status: "QA中", Tone: "info"},
					{Label: "素材: 真鍮ロッド", Kind: "material", Status: "在庫要補充", Tone: "warning"},
				},
			},
		),
		makeCatalogAsset(
			Item{
				ID:          "prd-premium-bundle",
				Name:        "プレミアム名入れギフトセット",
				Identifier:  "PRD-PREMIUM-GIFT",
				Kind:        KindProducts,
				Status:      StatusDraft,
				StatusLabel: "構成中",
				StatusTone:  "warning",
				Description: "名入れポスター + 木製フレーム + ギフトボックスの組み合わせ。夏ローンチ予定。",
				Owner: OwnerInfo{
					Name:  "Kana Fujii",
					Email: "kana.fujii@example.com",
				},
				UpdatedAt:    now.Add(-5 * time.Hour),
				Version:      "Spec draft",
				UsageCount:   0,
				UsageLabel:   "未公開",
				Tags:         []string{"gift", "draft"},
				PreviewURL:   "/public/static/placeholders/catalog-product-gift.png",
				PreviewAlt:   "ギフトセット",
				Channels:     []string{"Web"},
				Format:       "Bundle",
				PrimaryColor: "#7C3AED",
			},
			ItemDetail{
				PreviewURL:  "/public/static/placeholders/catalog-product-gift.png",
				Description: "撮影中のためダミー画像。SKU 構成と在庫引当ルールを検討中。",
				Dependencies: []Dependency{
					{Label: "木工パートナー", Kind: "vendor", Status: "契約交渉", Tone: "warning"},
				},
			},
		),
	}
}
