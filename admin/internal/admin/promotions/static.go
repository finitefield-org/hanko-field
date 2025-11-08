package promotions

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"
)

// StaticService provides deterministic promotion data suitable for development and tests.
type StaticService struct {
	mu           sync.RWMutex
	promotions   []Promotion
	details      map[string]PromotionDetail
	usageData    map[string][]UsageRecord
	usageExports map[string]usageExportState
	nextID       int
}

const (
	shippingOptionFree   = "free"
	shippingOptionFlat   = "flat"
	defaultUsagePageSize = 25
)

type usageExportState struct {
	Job       UsageExportJob
	Attempts  int
	Completed bool
}

// NewStaticService builds a StaticService with representative promotions.
func NewStaticService() *StaticService {
	now := time.Now().Truncate(time.Minute)
	nextWeek := now.AddDate(0, 0, 7)
	nextMonth := now.AddDate(0, 1, 0)
	lastWeek := now.AddDate(0, 0, -7)
	lastMonth := now.AddDate(0, -1, 0)

	makePromotion := func(id, code, name string, status Status, statusLabel, tone string, kind Type, typeLabel string, channels []Channel, start, end *time.Time, usage, redemption int, createdBy string, lastMod time.Time, segment Segment, metrics PromotionMetrics) Promotion {
		return Promotion{
			ID:              id,
			Code:            code,
			Name:            name,
			Description:     name + " のプロモーション",
			Status:          status,
			StatusLabel:     statusLabel,
			StatusTone:      tone,
			Type:            kind,
			TypeLabel:       typeLabel,
			Channels:        append([]Channel(nil), channels...),
			StartAt:         copyTimePtr(start),
			EndAt:           copyTimePtr(end),
			UsageCount:      usage,
			RedemptionCount: redemption,
			LastModifiedAt:  lastMod,
			CreatedBy:       createdBy,
			Segment:         segment,
			Metrics:         metrics,
		}
	}

	segmentVIP := Segment{
		Key:         "vip_retention",
		Name:        "既存顧客 (VIP)",
		Description: "昨年度の購入回数が3回以上でLTV上位20%の顧客",
		Preview:     []string{"LTV上位20%", "年間購入回数3回以上", "メールサブスク登録済み"},
		Audience:    1280,
	}
	segmentRing := Segment{
		Key:         "ring_intent",
		Name:        "リング検討中ユーザー",
		Description: "過去30日以内にリングカテゴリを3回以上閲覧している未購入ユーザー",
		Preview:     []string{"カテゴリ: リング", "閲覧3回以上", "未購入"},
		Audience:    2543,
	}
	segmentApp := Segment{
		Key:         "app_members",
		Name:        "アプリ限定会員",
		Description: "アプリ経由で登録し、Push通知許諾済みの会員",
		Preview:     []string{"Push許諾済み", "アプリ登録", "カスタム刻印希望"},
		Audience:    980,
	}

	promotions := []Promotion{
		makePromotion(
			"promo-early-summer",
			"EARLYSUMMER15",
			"初夏フェア15%OFF",
			StatusActive,
			"アクティブ",
			"success",
			TypePercentage,
			"パーセンテージ割引",
			[]Channel{ChannelOnlineStore, ChannelApp},
			&lastWeek,
			&nextWeek,
			428,
			612,
			"marketing.miyamoto",
			now.Add(-6*time.Hour),
			segmentVIP,
			PromotionMetrics{
				AttributedRevenueMinor: 48200000,
				ConversionRate:         0.183,
				RetentionLift:          0.12,
			},
		),
		makePromotion(
			"promo-ring-bundle",
			"BUNDLEPAIR",
			"ペアリングまとめ買いセット",
			StatusScheduled,
			"公開予定",
			"info",
			TypeBundle,
			"セット販売",
			[]Channel{ChannelOnlineStore, ChannelRetail},
			&nextWeek,
			&nextMonth,
			0,
			0,
			"planner.tanaka",
			now.Add(-48*time.Hour),
			segmentRing,
			PromotionMetrics{
				AttributedRevenueMinor: 0,
				ConversionRate:         0.0,
				RetentionLift:          0.0,
			},
		),
		makePromotion(
			"promo-app-flash",
			"FLASHAPP20",
			"アプリ限定サマーFlash",
			StatusPaused,
			"一時停止",
			"warning",
			TypePercentage,
			"パーセンテージ割引",
			[]Channel{ChannelApp},
			&lastMonth,
			&nextWeek,
			182,
			275,
			"growth.kobayashi",
			now.Add(-12*time.Hour),
			segmentApp,
			PromotionMetrics{
				AttributedRevenueMinor: 18650000,
				ConversionRate:         0.212,
				RetentionLift:          0.08,
			},
		),
		makePromotion(
			"promo-shipping-rush",
			"FREESHIPRUSH",
			"お急ぎ無料配送キャンペーン",
			StatusActive,
			"アクティブ",
			"success",
			TypeShipping,
			"配送割引",
			[]Channel{ChannelOnlineStore},
			&now,
			&nextMonth,
			531,
			531,
			"operations.saito",
			now.Add(-3*time.Hour),
			Segment{
				Key:         "express_delivery",
				Name:        "即納希望ユーザー",
				Description: "最短納期フィルタを使用し、過去にお急ぎ配送オプションを選択した顧客",
				Preview:     []string{"お急ぎ配送選択経験", "納期フィルタ適用"},
				Audience:    1954,
			},
			PromotionMetrics{
				AttributedRevenueMinor: 32500000,
				ConversionRate:         0.246,
				RetentionLift:          0.19,
			},
		),
		makePromotion(
			"promo-winter-archive",
			"WINTER23END",
			"冬の在庫一掃セール",
			StatusExpired,
			"終了",
			"muted",
			TypeFixedAmount,
			"固定額割引",
			[]Channel{ChannelOnlineStore, ChannelRetail},
			&lastMonth,
			&lastWeek,
			980,
			1340,
			"marketing.miyamoto",
			lastWeek.Add(-6*time.Hour),
			Segment{
				Key:         "seasonal_inventory",
				Name:        "シーズン品在庫調整",
				Description: "冬物カテゴリを過去3ヶ月以内に購入した顧客",
				Preview:     []string{"冬物購入履歴あり", "VIP対象外"},
				Audience:    1680,
			},
			PromotionMetrics{
				AttributedRevenueMinor: 61800000,
				ConversionRate:         0.198,
				RetentionLift:          0.05,
			},
		),
	}

	promotions[0].Version = "v5"
	promotions[0].DiscountPercent = 15
	promotions[0].DiscountCurrency = "JPY"
	promotions[0].EligibilityRules = []string{"loyal_members"}
	promotions[0].MinOrderAmountMinor = 15000
	promotions[0].UsageLimitTotal = 1500
	promotions[0].UsageLimitPerCustomer = 1
	promotions[0].BudgetMinor = 8000000

	promotions[1].Version = "v3"
	promotions[1].BundleBuyQty = 2
	promotions[1].BundleGetQty = 1
	promotions[1].BundleDiscountPercent = 100
	promotions[1].EligibilityRules = []string{"app_push"}
	promotions[1].MinOrderAmountMinor = 20000
	promotions[1].UsageLimitTotal = 500
	promotions[1].UsageLimitPerCustomer = 1
	promotions[1].BudgetMinor = 6000000

	promotions[2].Version = "v4"
	promotions[2].DiscountPercent = 20
	promotions[2].DiscountCurrency = "JPY"
	promotions[2].EligibilityRules = []string{"app_push", "loyal_members"}
	promotions[2].MinOrderAmountMinor = 0
	promotions[2].UsageLimitTotal = 2000
	promotions[2].UsageLimitPerCustomer = 2
	promotions[2].BudgetMinor = 4500000

	promotions[3].Version = "v2"
	promotions[3].ShippingOption = shippingOptionFree
	promotions[3].ShippingCurrency = "JPY"
	promotions[3].EligibilityRules = []string{"expedited"}
	promotions[3].MinOrderAmountMinor = 10000
	promotions[3].UsageLimitTotal = 1200
	promotions[3].UsageLimitPerCustomer = 3
	promotions[3].BudgetMinor = 3000000

	promotions[4].Version = "v6"
	promotions[4].DiscountAmountMinor = 5000
	promotions[4].DiscountCurrency = "JPY"
	promotions[4].EligibilityRules = []string{"new_customers"}
	promotions[4].MinOrderAmountMinor = 12000
	promotions[4].UsageLimitTotal = 2500
	promotions[4].UsageLimitPerCustomer = 1
	promotions[4].BudgetMinor = 9000000

	detail := func(p Promotion, benefits []Benefit, log []AuditLogEntry) PromotionDetail {
		usage := []UsageSlice{
			{Label: "新規顧客", Value: "32%"},
			{Label: "既存顧客", Value: "68%"},
			{Label: "リピート購入", Value: "44%"},
		}
		if len(p.Channels) > 0 {
			channelLabels := make([]string, len(p.Channels))
			for idx, ch := range p.Channels {
				channelLabels[idx] = string(ch)
			}
			usage = append(usage, UsageSlice{Label: "チャネル", Value: strings.Join(channelLabels, ", ")})
		}
		targeting := []TargetingRule{
			{Label: "地域", Value: "日本国内", Icon: "🗾"},
			{Label: "購入回数", Value: "2回以上", Icon: "🛒"},
			{Label: "直近閲覧カテゴリ", Value: p.Segment.Name, Icon: "👀"},
		}
		return PromotionDetail{
			Promotion:   p,
			Targeting:   targeting,
			Benefits:    benefits,
			AuditLog:    log,
			LastEditor:  p.CreatedBy,
			LastEdited:  p.LastModifiedAt,
			UsageSlices: usage,
		}
	}

	details := map[string]PromotionDetail{
		"promo-early-summer": detail(promotions[0],
			[]Benefit{
				{Label: "15%OFF", Description: "カート内商品に対して一律15%オフ", Icon: "💸"},
				{Label: "刻印無料", Description: "リング刻印オプションを無料適用", Icon: "✨"},
			},
			[]AuditLogEntry{
				{Timestamp: now.Add(-5 * time.Hour), Actor: "marketing.miyamoto", Action: "ステータス変更", Summary: "一時停止 → アクティブ"},
				{Timestamp: now.Add(-2 * time.Hour), Actor: "analytics.yamada", Action: "予算調整", Summary: "予算上限を+15%に更新"},
			}),
		"promo-ring-bundle": detail(promotions[1],
			[]Benefit{
				{Label: "2個目半額", Description: "対象リングを2点以上購入で2点目が半額", Icon: "💍"},
				{Label: "無料鑑定", Description: "購入後のサイズ調整無料", Icon: "📏"},
			},
			[]AuditLogEntry{
				{Timestamp: now.Add(-36 * time.Hour), Actor: "planner.tanaka", Action: "作成", Summary: "プロモーション作成しQA依頼"},
				{Timestamp: now.Add(-30 * time.Hour), Actor: "qa.suzuki", Action: "QAレビュー", Summary: "文言調整と在庫アラート設定"},
			}),
		"promo-app-flash": detail(promotions[2],
			[]Benefit{
				{Label: "20%OFF", Description: "アプリカート限定で20%割引", Icon: "📱"},
				{Label: "限定ギフト", Description: "数量限定ギフトをプレゼント", Icon: "🎁"},
			},
			[]AuditLogEntry{
				{Timestamp: now.Add(-26 * time.Hour), Actor: "growth.kobayashi", Action: "一時停止", Summary: "コンバージョン率低下のため停止"},
				{Timestamp: now.Add(-12 * time.Hour), Actor: "data.matsumoto", Action: "分析", Summary: "Push ABテスト結果を追加"},
			}),
		"promo-shipping-rush": detail(promotions[3],
			[]Benefit{
				{Label: "配送無料", Description: "お急ぎ配送オプション料金無料", Icon: "🚚"},
			},
			[]AuditLogEntry{
				{Timestamp: now.Add(-8 * time.Hour), Actor: "operations.saito", Action: "在庫調整", Summary: "対象SKUを在庫優先に設定"},
				{Timestamp: now.Add(-3 * time.Hour), Actor: "ops.ishikawa", Action: "ステータス更新", Summary: "アクティブ化"},
			}),
		"promo-winter-archive": detail(promotions[4],
			[]Benefit{
				{Label: "3,000円OFF", Description: "冬物カテゴリ対象商品を3,000円割引", Icon: "❄️"},
			},
			[]AuditLogEntry{
				{Timestamp: lastWeek.Add(-24 * time.Hour), Actor: "marketing.miyamoto", Action: "終了", Summary: "終了処理と在庫調整完了"},
				{Timestamp: lastWeek.Add(-26 * time.Hour), Actor: "finance.okada", Action: "実績確認", Summary: "売上達成率を承認"},
			}),
	}

	vipSegment := promotions[0].Segment
	ringSegment := promotions[1].Segment
	appSegment := promotions[2].Segment
	rushSegment := promotions[3].Segment
	winterSegment := promotions[4].Segment

	usageData := map[string][]UsageRecord{
		promotions[0].ID: {
			makeUsageRecord(
				UsageUser{ID: "user_vip_001", Name: "星野 彩香", Email: "ayaka.hoshino@example.jp"},
				4,
				int64(168000),
				int64(1112000),
				now.AddDate(0, 0, -28),
				now.Add(-6*time.Hour),
				vipSegment.Key,
				vipSegment.Name,
				"success",
				[]Channel{ChannelOnlineStore, ChannelApp},
				[]string{"checkout_web", "app_push"},
				UsageOrder{
					ID:          "order-74821",
					Number:      "HF-74821",
					AmountMinor: int64(282000),
					Currency:    "JPY",
					Status:      "delivered",
					StatusLabel: "配送完了",
					StatusTone:  "success",
					PlacedAt:    now.Add(-6 * time.Hour),
					Channel:     ChannelOnlineStore,
					Source:      "checkout_web",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_vip_014", Name: "三浦 文雄", Email: "fumio.miura@example.jp"},
				3,
				int64(108000),
				int64(684000),
				now.AddDate(0, 0, -21),
				now.Add(-30*time.Hour),
				vipSegment.Key,
				vipSegment.Name,
				"success",
				[]Channel{ChannelApp},
				[]string{"app_push"},
				UsageOrder{
					ID:          "order-74210",
					Number:      "HF-74210",
					AmountMinor: int64(218000),
					Currency:    "JPY",
					Status:      "shipped",
					StatusLabel: "出荷準備中",
					StatusTone:  "info",
					PlacedAt:    now.Add(-30 * time.Hour),
					Channel:     ChannelApp,
					Source:      "app_push",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_vip_033", Name: "森下 純", Email: "jun.morishita@example.jp"},
				2,
				int64(72000),
				int64(392000),
				now.AddDate(0, 0, -14),
				now.AddDate(0, 0, -2),
				vipSegment.Key,
				vipSegment.Name,
				"success",
				[]Channel{ChannelOnlineStore},
				[]string{"checkout_web"},
				UsageOrder{
					ID:          "order-73654",
					Number:      "HF-73654",
					AmountMinor: int64(196000),
					Currency:    "JPY",
					Status:      "delivered",
					StatusLabel: "配送完了",
					StatusTone:  "success",
					PlacedAt:    now.AddDate(0, 0, -2),
					Channel:     ChannelOnlineStore,
					Source:      "checkout_web",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_vip_081", Name: "神田 舞", Email: "mai.kanda@example.jp"},
				1,
				int64(24000),
				int64(168000),
				now.AddDate(0, 0, -9),
				now.AddDate(0, 0, -1),
				vipSegment.Key,
				vipSegment.Name,
				"success",
				[]Channel{ChannelApp},
				[]string{"app_campaign"},
				UsageOrder{
					ID:          "order-75102",
					Number:      "HF-75102",
					AmountMinor: int64(168000),
					Currency:    "JPY",
					Status:      "processing",
					StatusLabel: "支払い確認中",
					StatusTone:  "warning",
					PlacedAt:    now.AddDate(0, 0, -1),
					Channel:     ChannelApp,
					Source:      "app_campaign",
				},
			),
		},
		promotions[1].ID: {
			makeUsageRecord(
				UsageUser{ID: "user_ring_004", Name: "井上 千春", Email: "chiharu.inoue@example.jp"},
				1,
				int64(50000),
				int64(300000),
				now.AddDate(0, 0, -3),
				now.AddDate(0, 0, -3),
				ringSegment.Key,
				ringSegment.Name,
				"info",
				[]Channel{ChannelOnlineStore},
				[]string{"campaign_preview"},
				UsageOrder{
					ID:          "order-77001",
					Number:      "HF-77001",
					AmountMinor: int64(300000),
					Currency:    "JPY",
					Status:      "pending",
					StatusLabel: "公開待ち",
					StatusTone:  "muted",
					PlacedAt:    now.AddDate(0, 0, -3),
					Channel:     ChannelOnlineStore,
					Source:      "campaign_preview",
				},
			),
		},
		promotions[2].ID: {
			makeUsageRecord(
				UsageUser{ID: "user_app_011", Name: "北川 誠", Email: "makoto.kitagawa@example.jp"},
				3,
				int64(90000),
				int64(540000),
				now.AddDate(0, 0, -18),
				now.Add(-12*time.Hour),
				appSegment.Key,
				appSegment.Name,
				"warning",
				[]Channel{ChannelApp},
				[]string{"app_flash", "push_message"},
				UsageOrder{
					ID:          "order-72882",
					Number:      "HF-72882",
					AmountMinor: int64(198000),
					Currency:    "JPY",
					Status:      "cancelled",
					StatusLabel: "キャンセル済み",
					StatusTone:  "danger",
					PlacedAt:    now.Add(-12 * time.Hour),
					Channel:     ChannelApp,
					Source:      "app_flash",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_app_027", Name: "谷口 菜々", Email: "nana.taniguchi@example.jp"},
				2,
				int64(56000),
				int64(352000),
				now.AddDate(0, 0, -15),
				now.AddDate(0, 0, -5),
				appSegment.Key,
				appSegment.Name,
				"warning",
				[]Channel{ChannelApp},
				[]string{"push_message"},
				UsageOrder{
					ID:          "order-73100",
					Number:      "HF-73100",
					AmountMinor: int64(176000),
					Currency:    "JPY",
					Status:      "processing",
					StatusLabel: "支払い確認中",
					StatusTone:  "warning",
					PlacedAt:    now.AddDate(0, 0, -5),
					Channel:     ChannelApp,
					Source:      "push_message",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_app_045", Name: "岡村 遥", Email: "haruka.okamura@example.jp"},
				1,
				int64(28000),
				int64(140000),
				now.AddDate(0, 0, -9),
				now.AddDate(0, 0, -1),
				appSegment.Key,
				appSegment.Name,
				"warning",
				[]Channel{ChannelApp},
				[]string{"app_flash"},
				UsageOrder{
					ID:          "order-73554",
					Number:      "HF-73554",
					AmountMinor: int64(140000),
					Currency:    "JPY",
					Status:      "refunded",
					StatusLabel: "返金済み",
					StatusTone:  "danger",
					PlacedAt:    now.AddDate(0, 0, -1),
					Channel:     ChannelApp,
					Source:      "app_flash",
				},
			),
		},
		promotions[3].ID: {
			makeUsageRecord(
				UsageUser{ID: "user_ship_006", Name: "佐竹 真", Email: "makoto.satake@example.jp"},
				5,
				int64(0),
				int64(640000),
				now.AddDate(0, 0, -12),
				now.Add(-3*time.Hour),
				rushSegment.Key,
				rushSegment.Name,
				"success",
				[]Channel{ChannelOnlineStore},
				[]string{"checkout_web", "express_checkout"},
				UsageOrder{
					ID:          "order-74452",
					Number:      "HF-74452",
					AmountMinor: int64(128000),
					Currency:    "JPY",
					Status:      "preparing",
					StatusLabel: "出荷準備中",
					StatusTone:  "info",
					PlacedAt:    now.Add(-3 * time.Hour),
					Channel:     ChannelOnlineStore,
					Source:      "express_checkout",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_ship_018", Name: "柳沼 晶", Email: "akira.yaginuma@example.jp"},
				2,
				int64(0),
				int64(256000),
				now.AddDate(0, 0, -10),
				now.AddDate(0, 0, -1),
				rushSegment.Key,
				rushSegment.Name,
				"success",
				[]Channel{ChannelOnlineStore},
				[]string{"checkout_web"},
				UsageOrder{
					ID:          "order-74601",
					Number:      "HF-74601",
					AmountMinor: int64(128000),
					Currency:    "JPY",
					Status:      "delivered",
					StatusLabel: "配送完了",
					StatusTone:  "success",
					PlacedAt:    now.AddDate(0, 0, -1),
					Channel:     ChannelOnlineStore,
					Source:      "checkout_web",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_ship_029", Name: "中村 美咲", Email: "misaki.nakamura@example.jp"},
				1,
				int64(0),
				int64(98000),
				now.AddDate(0, 0, -6),
				now.AddDate(0, 0, -2),
				rushSegment.Key,
				rushSegment.Name,
				"success",
				[]Channel{ChannelOnlineStore},
				[]string{"support_manual"},
				UsageOrder{
					ID:          "order-74870",
					Number:      "HF-74870",
					AmountMinor: int64(98000),
					Currency:    "JPY",
					Status:      "processing",
					StatusLabel: "支払い確認中",
					StatusTone:  "warning",
					PlacedAt:    now.AddDate(0, 0, -2),
					Channel:     ChannelOnlineStore,
					Source:      "support_manual",
				},
			),
		},
		promotions[4].ID: {
			makeUsageRecord(
				UsageUser{ID: "user_winter_002", Name: "市川 遼", Email: "ryo.ichikawa@example.jp"},
				3,
				int64(9000),
				int64(420000),
				lastMonth.AddDate(0, 0, 5),
				lastWeek,
				winterSegment.Key,
				winterSegment.Name,
				"muted",
				[]Channel{ChannelOnlineStore, ChannelRetail},
				[]string{"retail_pos", "checkout_web"},
				UsageOrder{
					ID:          "order-69220",
					Number:      "HF-69220",
					AmountMinor: int64(140000),
					Currency:    "JPY",
					Status:      "delivered",
					StatusLabel: "配送完了",
					StatusTone:  "success",
					PlacedAt:    lastWeek,
					Channel:     ChannelRetail,
					Source:      "retail_pos",
				},
			),
			makeUsageRecord(
				UsageUser{ID: "user_winter_014", Name: "佐々木 絵里", Email: "eri.sasaki@example.jp"},
				1,
				int64(3000),
				int64(138000),
				lastMonth.AddDate(0, 0, 12),
				lastMonth.AddDate(0, 0, 15),
				winterSegment.Key,
				winterSegment.Name,
				"muted",
				[]Channel{ChannelOnlineStore},
				[]string{"checkout_web"},
				UsageOrder{
					ID:          "order-68411",
					Number:      "HF-68411",
					AmountMinor: int64(138000),
					Currency:    "JPY",
					Status:      "refunded",
					StatusLabel: "返金済み",
					StatusTone:  "danger",
					PlacedAt:    lastMonth.AddDate(0, 0, 15),
					Channel:     ChannelOnlineStore,
					Source:      "checkout_web",
				},
			),
		},
	}

	return &StaticService{
		promotions:   promotions,
		details:      details,
		usageData:    usageData,
		usageExports: make(map[string]usageExportState),
		nextID:       len(promotions),
	}
}

// List returns a filtered slice of promotions.
func (s *StaticService) List(_ context.Context, _ string, query ListQuery) (ListResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	page := query.Page
	if page <= 0 {
		page = 1
	}
	pageSize := query.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}

	statusFilter := make(map[Status]struct{}, len(query.Statuses))
	for _, st := range query.Statuses {
		statusFilter[st] = struct{}{}
	}
	typeFilter := make(map[Type]struct{}, len(query.Types))
	for _, tp := range query.Types {
		typeFilter[tp] = struct{}{}
	}
	channelFilter := make(map[Channel]struct{}, len(query.Channels))
	for _, ch := range query.Channels {
		channelFilter[ch] = struct{}{}
	}
	ownerFilter := make(map[string]struct{}, len(query.CreatedBy))
	for _, owner := range query.CreatedBy {
		ownerFilter[strings.ToLower(strings.TrimSpace(owner))] = struct{}{}
	}

	var start, end time.Time
	hasStart := query.ScheduleStart != nil && !query.ScheduleStart.IsZero()
	hasEnd := query.ScheduleEnd != nil && !query.ScheduleEnd.IsZero()
	if hasStart {
		start = query.ScheduleStart.Truncate(24 * time.Hour)
	}
	if hasEnd {
		end = query.ScheduleEnd.Truncate(24 * time.Hour)
	}

	searchTerm := strings.ToLower(strings.TrimSpace(query.Search))

	filtered := make([]Promotion, 0, len(s.promotions))
	for _, promo := range s.promotions {
		if len(statusFilter) > 0 {
			if _, ok := statusFilter[promo.Status]; !ok {
				continue
			}
		}
		if len(typeFilter) > 0 {
			if _, ok := typeFilter[promo.Type]; !ok {
				continue
			}
		}
		if len(channelFilter) > 0 {
			match := false
			for _, ch := range promo.Channels {
				if _, ok := channelFilter[ch]; ok {
					match = true
					break
				}
			}
			if !match {
				continue
			}
		}
		if len(ownerFilter) > 0 {
			if _, ok := ownerFilter[strings.ToLower(promo.CreatedBy)]; !ok {
				continue
			}
		}
		if hasStart {
			if promo.EndAt != nil && promo.EndAt.Before(start) {
				continue
			}
		}
		if hasEnd {
			if promo.StartAt != nil && promo.StartAt.After(end) {
				continue
			}
		}
		if searchTerm != "" {
			if !strings.Contains(strings.ToLower(promo.Code), searchTerm) && !strings.Contains(strings.ToLower(promo.Name), searchTerm) {
				continue
			}
		}
		filtered = append(filtered, promo)
	}

	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].LastModifiedAt.After(filtered[j].LastModifiedAt)
	})

	total := len(filtered)
	startIdx := (page - 1) * pageSize
	if startIdx > total {
		startIdx = total
	}
	endIdx := startIdx + pageSize
	if endIdx > total {
		endIdx = total
	}
	paged := append([]Promotion(nil), filtered[startIdx:endIdx]...)

	var nextPage *int
	if endIdx < total {
		val := page + 1
		nextPage = &val
	}
	var prevPage *int
	if page > 1 && startIdx >= pageSize {
		val := page - 1
		prevPage = &val
	}

	result := ListResult{
		Promotions: paged,
		Pagination: Pagination{
			Page:       page,
			PageSize:   pageSize,
			TotalItems: total,
			NextPage:   nextPage,
			PrevPage:   prevPage,
		},
		Summary: summarise(filtered),
		Filters: s.buildFilterSummary(filtered),
	}

	return result, nil
}

// Detail returns the promotion record for the provided ID.
func (s *StaticService) Detail(_ context.Context, _ string, promotionID string) (PromotionDetail, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	promotionID = strings.TrimSpace(promotionID)
	if promotionID == "" {
		return PromotionDetail{}, ErrPromotionNotFound
	}
	detail, ok := s.details[promotionID]
	if !ok {
		return PromotionDetail{}, ErrPromotionNotFound
	}
	return detail, nil
}

// BulkStatus acknowledges bulk actions and echoes the selection.
func (s *StaticService) BulkStatus(_ context.Context, _ string, req BulkStatusRequest) (BulkStatusResult, error) {
	action := req.Action
	ids := append([]string(nil), req.PromotionIDs...)
	return BulkStatusResult{
		Action:      action,
		AffectedIDs: ids,
	}, nil
}

// Create persists a new promotion in the static catalogue.
func (s *StaticService) Create(_ context.Context, _ string, input PromotionInput) (Promotion, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if err := s.validatePromotionInput(input, ""); err != nil {
		return Promotion{}, err
	}

	s.nextID++
	id := fmt.Sprintf("promo-generated-%d", s.nextID)
	promo := Promotion{
		ID:              id,
		Code:            strings.TrimSpace(input.Code),
		Name:            strings.TrimSpace(input.Name),
		Description:     strings.TrimSpace(input.Description),
		Status:          input.Status,
		StatusLabel:     statusLabelValue(input.Status),
		StatusTone:      statusToneValue(input.Status),
		Type:            input.Type,
		TypeLabel:       typeLabelValue(input.Type),
		Channels:        copyChannels(input.Channels),
		StartAt:         copyTimePtr(&input.StartAt),
		EndAt:           copyTimePtr(input.EndAt),
		UsageCount:      0,
		RedemptionCount: 0,
		LastModifiedAt:  time.Now(),
		CreatedBy:       "marketing.auto",
		Segment:         segmentFromKey(input.SegmentKey),
		Metrics: PromotionMetrics{
			AttributedRevenueMinor: 0,
			ConversionRate:         0,
			RetentionLift:          0,
		},
		Version:               newPromotionVersion(),
		DiscountPercent:       input.DiscountPercent,
		DiscountAmountMinor:   input.DiscountAmountMinor,
		DiscountCurrency:      coalesceCurrency(input.DiscountCurrency),
		BundleBuyQty:          input.BundleBuyQty,
		BundleGetQty:          input.BundleGetQty,
		BundleDiscountPercent: input.BundleDiscountPercent,
		ShippingOption:        strings.TrimSpace(input.ShippingOption),
		ShippingAmountMinor:   input.ShippingAmountMinor,
		ShippingCurrency:      coalesceCurrency(input.ShippingCurrency),
		EligibilityRules:      append([]string(nil), input.EligibilityRules...),
		MinOrderAmountMinor:   input.MinOrderAmountMinor,
		UsageLimitTotal:       input.UsageLimitTotal,
		UsageLimitPerCustomer: input.UsageLimitPerCustomer,
		BudgetMinor:           input.BudgetMinor,
	}
	if strings.TrimSpace(promo.Description) == "" {
		promo.Description = promo.Name + " のプロモーション"
	}
	if promo.ShippingOption == "" {
		promo.ShippingOption = shippingOptionFree
	}

	s.promotions = append([]Promotion{promo}, s.promotions...)
	s.details[promo.ID] = buildDetailForPromotion(promo)

	return promo, nil
}

// Validate performs a synthetic eligibility check against stored promotion metadata.
func (s *StaticService) Validate(_ context.Context, _ string, req ValidationRequest) (ValidationResult, error) {
	promoID := strings.TrimSpace(req.PromotionID)
	if promoID == "" {
		return ValidationResult{}, ErrPromotionNotFound
	}

	s.mu.RLock()
	detail, ok := s.details[promoID]
	s.mu.RUnlock()
	if !ok {
		return ValidationResult{}, ErrPromotionNotFound
	}

	promo := detail.Promotion
	executedAt := time.Now().Truncate(time.Second)

	subtotal := req.SubtotalMinor
	if subtotal < 0 {
		subtotal = 0
	}

	currency := coalesceCurrency(req.Currency)
	sanitizedItems := sanitizeValidationItems(req.Items)

	rules := make([]ValidationRuleResult, 0, 6)
	eligible := true

	addRule := func(rule ValidationRuleResult) {
		if !rule.Passed && rule.Blocking {
			eligible = false
		}
		if rule.Severity == "" {
			if rule.Passed {
				rule.Severity = "success"
			} else if rule.Blocking {
				rule.Severity = "danger"
			} else {
				rule.Severity = "warning"
			}
		}
		rules = append(rules, rule)
	}

	now := time.Now()
	withinStart := promo.StartAt == nil || !now.Before(*promo.StartAt)
	withinEnd := promo.EndAt == nil || !now.After(*promo.EndAt)
	addRule(ValidationRuleResult{
		Key:      "schedule_window",
		Label:    "公開期間",
		Passed:   withinStart && withinEnd,
		Blocking: true,
		Message: func() string {
			if withinStart && withinEnd {
				return "現在の日時で適用可能な期間内です。"
			}
			if !withinStart {
				return "開始日時より前のため適用できません。"
			}
			return "終了日時を過ぎているため適用できません。"
		}(),
		Details: map[string]any{
			"startAt": promo.StartAt,
			"endAt":   promo.EndAt,
			"now":     now,
		},
	})

	minOrder := promo.MinOrderAmountMinor
	addRule(ValidationRuleResult{
		Key:      "subtotal_threshold",
		Label:    "最低購入金額",
		Passed:   minOrder <= 0 || subtotal >= minOrder,
		Blocking: minOrder > 0,
		Message: func() string {
			if minOrder <= 0 {
				return "最低購入金額の条件は設定されていません。"
			}
			if subtotal >= minOrder {
				return fmt.Sprintf("小計が条件を満たしています (¥%d ≧ ¥%d)", subtotal, minOrder)
			}
			return fmt.Sprintf("小計が条件を満たしていません (¥%d < ¥%d)", subtotal, minOrder)
		}(),
		Details: map[string]any{
			"subtotalMinor":  subtotal,
			"thresholdMinor": minOrder,
		},
	})

	segmentMatch := strings.TrimSpace(req.SegmentKey) == strings.TrimSpace(promo.Segment.Key)
	addRule(ValidationRuleResult{
		Key:      "segment_match",
		Label:    "対象セグメント",
		Passed:   segmentMatch,
		Blocking: true,
		Message: func() string {
			if segmentMatch {
				return fmt.Sprintf("セグメント %s に一致しました。", promo.Segment.Name)
			}
			if req.SegmentKey == "" {
				return "セグメントが未指定のため一致しません。"
			}
			return fmt.Sprintf("セグメントが一致しません (要求: %s / プロモーション: %s)", req.SegmentKey, promo.Segment.Key)
		}(),
		Details: map[string]any{
			"expected": promo.Segment.Key,
			"received": req.SegmentKey,
		},
	})

	itemCount := 0
	qualifyingItems := 0
	for _, item := range sanitizedItems {
		itemCount += item.Quantity
		if promo.Type == TypeBundle {
			if strings.Contains(strings.ToLower(item.SKU), "ring") {
				qualifyingItems += item.Quantity
			}
		} else {
			qualifyingItems += item.Quantity
		}
	}

	addRule(ValidationRuleResult{
		Key:      "cart_items",
		Label:    "カート内商品",
		Passed:   itemCount > 0,
		Blocking: true,
		Message: func() string {
			if itemCount > 0 {
				return fmt.Sprintf("%d 点の商品がカートに含まれています。", itemCount)
			}
			return "カートに商品がないため適用できません。"
		}(),
		Details: map[string]any{
			"itemCount": itemCount,
		},
	})

	if promo.Type == TypeBundle {
		required := promo.BundleBuyQty
		if required <= 0 {
			required = 2
		}
		addRule(ValidationRuleResult{
			Key:      "bundle_requirements",
			Label:    "セット条件",
			Passed:   qualifyingItems >= required,
			Blocking: true,
			Message: func() string {
				if qualifyingItems >= required {
					return fmt.Sprintf("必要数量を満たしています (%d/%d)。", qualifyingItems, required)
				}
				return fmt.Sprintf("必要数量を満たしていません (%d/%d)。", qualifyingItems, required)
			}(),
			Details: map[string]any{
				"qualifyingItems": qualifyingItems,
				"required":        required,
			},
		})
	}

	rulesEvaluated := make([]map[string]any, 0, len(rules))
	for _, rule := range rules {
		rulesEvaluated = append(rulesEvaluated, map[string]any{
			"key":      rule.Key,
			"label":    rule.Label,
			"passed":   rule.Passed,
			"blocking": rule.Blocking,
			"severity": rule.Severity,
			"message":  rule.Message,
			"details":  rule.Details,
		})
	}

	payload := map[string]any{
		"promotionId":   promo.ID,
		"promotionCode": promo.Code,
		"eligible":      eligible,
		"executedAt":    executedAt,
		"rules":         rulesEvaluated,
		"cart": map[string]any{
			"subtotalMinor": subtotal,
			"currency":      currency,
			"segmentKey":    req.SegmentKey,
			"items": func() []map[string]any {
				out := make([]map[string]any, 0, len(sanitizedItems))
				for _, item := range sanitizedItems {
					out = append(out, map[string]any{
						"sku":          item.SKU,
						"quantity":     item.Quantity,
						"priceMinor":   item.PriceMinor,
						"lineSubtotal": int64(item.Quantity) * item.PriceMinor,
					})
				}
				return out
			}(),
		},
	}

	raw, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		raw = []byte("{}")
	}

	summary := "カートはプロモーション適用対象です。"
	if !eligible {
		summary = "条件を満たしていないため、プロモーションは適用されません。"
	}

	return ValidationResult{
		PromotionID:   promo.ID,
		PromotionName: promo.Name,
		Eligible:      eligible,
		ExecutedAt:    executedAt,
		Summary:       summary,
		Rules:         rules,
		Raw:           raw,
	}, nil
}

func sanitizeValidationItems(items []ValidationRequestItem) []ValidationRequestItem {
	if len(items) == 0 {
		return nil
	}
	capacity := len(items)
	if capacity > ValidationMaxItems {
		capacity = ValidationMaxItems
	}
	sanitized := make([]ValidationRequestItem, 0, capacity)
	for _, item := range items {
		if len(sanitized) >= ValidationMaxItems {
			break
		}
		sku := strings.TrimSpace(item.SKU)
		if sku == "" {
			continue
		}
		if item.Quantity <= 0 {
			continue
		}
		if item.PriceMinor < 0 {
			continue
		}
		sanitized = append(sanitized, ValidationRequestItem{
			SKU:        sku,
			Quantity:   item.Quantity,
			PriceMinor: item.PriceMinor,
		})
	}
	return sanitized
}

// Update mutates an existing promotion.
func (s *StaticService) Update(_ context.Context, _ string, promotionID string, input PromotionInput) (Promotion, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	promotionID = strings.TrimSpace(promotionID)
	if promotionID == "" {
		return Promotion{}, ErrPromotionNotFound
	}

	index := -1
	for i, candidate := range s.promotions {
		if candidate.ID == promotionID {
			index = i
			break
		}
	}
	if index == -1 {
		return Promotion{}, ErrPromotionNotFound
	}

	existing := s.promotions[index]
	if strings.TrimSpace(existing.Version) != "" && strings.TrimSpace(input.Version) != "" && !strings.EqualFold(existing.Version, input.Version) {
		return Promotion{}, &PromotionValidationError{
			Message: "最新の情報を取得してから再度お試しください。",
			FieldErrors: map[string]string{
				"version": "他のユーザーにより更新されています。",
			},
		}
	}

	if err := s.validatePromotionInput(input, promotionID); err != nil {
		return Promotion{}, err
	}

	updated := applyPromotionInput(existing, input)
	updated.Version = newPromotionVersion()
	updated.LastModifiedAt = time.Now()

	s.promotions[index] = updated

	detail := s.details[promotionID]
	detail.Promotion = updated
	detail.LastEdited = updated.LastModifiedAt
	detail.LastEditor = "marketing.auto"
	detail.Targeting = buildTargetingForSegment(updated.Segment, updated.EligibilityRules)
	detail.AuditLog = append([]AuditLogEntry{{
		Timestamp: updated.LastModifiedAt,
		Actor:     detail.LastEditor,
		Action:    "更新",
		Summary:   "プロモーションを更新しました。",
	}}, detail.AuditLog...)
	s.details[promotionID] = detail

	return updated, nil
}

// Usage returns aggregated promotion usage records for the provided query.
func (s *StaticService) Usage(_ context.Context, _ string, promotionID string, query UsageQuery) (UsageResult, error) {
	promotionID = strings.TrimSpace(promotionID)
	if promotionID == "" {
		return UsageResult{}, ErrPromotionNotFound
	}

	s.mu.RLock()
	promo, ok := s.findPromotionLocked(promotionID)
	if !ok {
		s.mu.RUnlock()
		return UsageResult{}, ErrPromotionNotFound
	}
	source := append([]UsageRecord(nil), s.usageData[promotionID]...)
	s.mu.RUnlock()

	reference := time.Now()
	start, end := resolveUsageTimeframe(query, reference)
	filtered := filterUsageRecords(source, query, start, end)
	sortUsageRecords(filtered, query.SortKey, query.SortDirection)

	page := query.Page
	if page < 1 {
		page = 1
	}
	pageSize := query.PageSize
	if pageSize <= 0 {
		pageSize = defaultUsagePageSize
	}

	total := len(filtered)
	startIdx := (page - 1) * pageSize
	if startIdx > total {
		startIdx = total
	}
	endIdx := startIdx + pageSize
	if endIdx > total {
		endIdx = total
	}

	pageRecords := append([]UsageRecord(nil), filtered[startIdx:endIdx]...)
	summary := aggregateUsageSummary(filtered, promo)
	filters := buildUsageFilterSummary(source, reference)
	alert := buildUsageAlert(promo, query, summary)

	var nextPage *int
	if endIdx < total {
		val := page + 1
		nextPage = &val
	}
	var prevPage *int
	if page > 1 && startIdx > 0 {
		val := page - 1
		prevPage = &val
	}

	pagination := Pagination{
		Page:       page,
		PageSize:   pageSize,
		TotalItems: total,
		NextPage:   nextPage,
		PrevPage:   prevPage,
	}

	return UsageResult{
		Promotion:   promo,
		Summary:     summary,
		Filters:     filters,
		Records:     pageRecords,
		Pagination:  pagination,
		Alert:       alert,
		GeneratedAt: reference,
	}, nil
}

// StartUsageExport records a simulated export job for promotion usage.
func (s *StaticService) StartUsageExport(_ context.Context, _ string, req UsageExportRequest) (UsageExportJob, error) {
	promotionID := strings.TrimSpace(req.PromotionID)
	if promotionID == "" {
		return UsageExportJob{}, ErrPromotionNotFound
	}

	format := UsageExportFormat(strings.TrimSpace(string(req.Format)))
	if format == "" {
		format = UsageExportFormatCSV
	}
	if !strings.EqualFold(string(format), string(UsageExportFormatCSV)) {
		return UsageExportJob{}, ErrUsageExportFormatNotAllowed
	}
	format = UsageExportFormatCSV

	s.mu.RLock()
	promo, ok := s.findPromotionLocked(promotionID)
	if !ok {
		s.mu.RUnlock()
		return UsageExportJob{}, ErrPromotionNotFound
	}
	source := append([]UsageRecord(nil), s.usageData[promotionID]...)
	s.mu.RUnlock()

	reference := time.Now()
	start, end := resolveUsageTimeframe(req.Query, reference)
	filtered := filterUsageRecords(source, req.Query, start, end)
	if len(filtered) == 0 {
		return UsageExportJob{}, ErrUsageExportNoRecords
	}

	jobID := fmt.Sprintf("usage-export-%d", reference.UnixNano())
	submitter := strings.TrimSpace(req.ActorID)
	if submitter == "" {
		submitter = strings.TrimSpace(req.ActorEmail)
	}

	job := UsageExportJob{
		ID:               jobID,
		PromotionID:      promo.ID,
		PromotionName:    promo.Name,
		Format:           format,
		SubmittedAt:      reference,
		SubmittedBy:      submitter,
		SubmittedByEmail: strings.TrimSpace(req.ActorEmail),
		Status:           "キュー投入済み",
		StatusTone:       "info",
		Progress:         5,
		RecordCount:      len(filtered),
		Message:          "CSVエクスポートを準備しています。",
	}

	s.mu.Lock()
	s.usageExports[jobID] = usageExportState{
		Job: job,
	}
	s.mu.Unlock()

	return job, nil
}

// UsageExportStatus returns the simulated status of a promotion usage export job.
func (s *StaticService) UsageExportStatus(_ context.Context, _ string, jobID string) (UsageExportJobStatus, error) {
	jobID = strings.TrimSpace(jobID)
	if jobID == "" {
		return UsageExportJobStatus{}, ErrUsageExportJobNotFound
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	state, ok := s.usageExports[jobID]
	if !ok {
		return UsageExportJobStatus{}, ErrUsageExportJobNotFound
	}

	if !state.Completed {
		state.Attempts++
		state.Job.Status = "処理中"
		state.Job.StatusTone = "info"
		state.Job.Message = "使用状況レコードを集計しています..."

		step := 30
		if state.Job.RecordCount > 25 {
			step = 20
		}
		state.Job.Progress += step
		if state.Job.Progress >= 95 {
			state.Job.Progress = 95
		}

		if state.Attempts >= 3 || state.Job.Progress >= 90 {
			now := time.Now()
			state.Completed = true
			state.Job.Progress = 100
			state.Job.Status = "完了"
			state.Job.StatusTone = "success"
			state.Job.Message = "エクスポートが完了しました。ダウンロードを開始できます。"
			state.Job.CompletedAt = &now
			state.Job.DownloadURL = fmt.Sprintf("/admin/downloads/promotions/%s/%s.%s", state.Job.PromotionID, state.Job.ID, state.Job.Format)
		}

		s.usageExports[jobID] = state
	}

	return UsageExportJobStatus{
		Job:  state.Job,
		Done: state.Completed,
	}, nil
}

func (s *StaticService) validatePromotionInput(input PromotionInput, ignoreID string) *PromotionValidationError {
	fieldErrors := make(map[string]string)
	code := strings.TrimSpace(input.Code)
	if code == "" {
		fieldErrors["code"] = "コードを入力してください。"
	} else {
		for _, promo := range s.promotions {
			if promo.ID == ignoreID {
				continue
			}
			if strings.EqualFold(promo.Code, code) {
				fieldErrors["code"] = "このコードは既に使用されています。"
				break
			}
		}
	}
	if input.StartAt.IsZero() {
		fieldErrors["startDate"] = "開始日時を指定してください。"
	}
	if input.EndAt != nil && !input.StartAt.IsZero() && !input.EndAt.After(input.StartAt) {
		fieldErrors["endDate"] = "終了日時は開始より後に設定してください。"
	}
	if len(input.Channels) == 0 {
		fieldErrors["channels"] = "チャネルを選択してください。"
	}
	if strings.TrimSpace(input.SegmentKey) == "" {
		fieldErrors["segment"] = "対象セグメントを選択してください。"
	}
	if len(fieldErrors) > 0 {
		return &PromotionValidationError{Message: "入力内容を確認してください。", FieldErrors: fieldErrors}
	}
	return nil
}

func applyPromotionInput(base Promotion, input PromotionInput) Promotion {
	updated := base
	updated.Name = strings.TrimSpace(input.Name)
	if desc := strings.TrimSpace(input.Description); desc != "" {
		updated.Description = desc
	}
	updated.Code = strings.TrimSpace(input.Code)
	updated.Status = input.Status
	updated.StatusLabel = statusLabelValue(input.Status)
	updated.StatusTone = statusToneValue(input.Status)
	updated.Type = input.Type
	updated.TypeLabel = typeLabelValue(input.Type)
	updated.Channels = copyChannels(input.Channels)
	updated.StartAt = copyTimePtr(&input.StartAt)
	updated.EndAt = copyTimePtr(input.EndAt)
	updated.DiscountPercent = input.DiscountPercent
	updated.DiscountAmountMinor = input.DiscountAmountMinor
	updated.DiscountCurrency = coalesceCurrency(input.DiscountCurrency)
	updated.BundleBuyQty = input.BundleBuyQty
	updated.BundleGetQty = input.BundleGetQty
	updated.BundleDiscountPercent = input.BundleDiscountPercent
	updated.ShippingOption = strings.TrimSpace(input.ShippingOption)
	if updated.ShippingOption == "" {
		updated.ShippingOption = shippingOptionFree
	}
	updated.ShippingAmountMinor = input.ShippingAmountMinor
	updated.ShippingCurrency = coalesceCurrency(input.ShippingCurrency)
	updated.EligibilityRules = append([]string(nil), input.EligibilityRules...)
	updated.MinOrderAmountMinor = input.MinOrderAmountMinor
	updated.UsageLimitTotal = input.UsageLimitTotal
	updated.UsageLimitPerCustomer = input.UsageLimitPerCustomer
	updated.BudgetMinor = input.BudgetMinor
	updated.Segment = segmentFromKey(input.SegmentKey)
	return updated
}

func copyChannels(channels []Channel) []Channel {
	if len(channels) == 0 {
		return nil
	}
	cpy := make([]Channel, len(channels))
	copy(cpy, channels)
	return cpy
}

func makeUsageRecord(user UsageUser, usageCount int, totalDiscountMinor, totalOrderMinor int64, firstUsed, lastUsed time.Time, segmentKey, segmentLabel, segmentTone string, channels []Channel, sources []string, lastOrder UsageOrder) UsageRecord {
	if usageCount < 0 {
		usageCount = 0
	}
	record := UsageRecord{
		User:                  user,
		UsageCount:            usageCount,
		TotalDiscountMinor:    totalDiscountMinor,
		TotalOrderAmountMinor: totalOrderMinor,
		FirstUsedAt:           firstUsed,
		LastUsedAt:            lastUsed,
		SegmentKey:            segmentKey,
		SegmentLabel:          segmentLabel,
		SegmentTone:           segmentTone,
		Channels:              append([]Channel(nil), channels...),
		Sources:               append([]string(nil), sources...),
		LastOrder:             lastOrder,
	}
	if usageCount > 0 {
		count := int64(usageCount)
		record.AverageDiscountMinor = 0
		if totalDiscountMinor != 0 {
			record.AverageDiscountMinor = totalDiscountMinor / count
		}
		record.AverageOrderAmountMinor = 0
		if totalOrderMinor != 0 {
			record.AverageOrderAmountMinor = totalOrderMinor / count
		}
	}
	return record
}

func buildDetailForPromotion(p Promotion) PromotionDetail {
	usage := []UsageSlice{
		{Label: "新規顧客", Value: "--"},
		{Label: "既存顧客", Value: "--"},
	}
	return PromotionDetail{
		Promotion:   p,
		Targeting:   buildTargetingForSegment(p.Segment, p.EligibilityRules),
		Benefits:    nil,
		AuditLog:    []AuditLogEntry{{Timestamp: p.LastModifiedAt, Actor: p.CreatedBy, Action: "作成", Summary: "プロモーションを作成しました。"}},
		LastEditor:  p.CreatedBy,
		LastEdited:  p.LastModifiedAt,
		UsageSlices: usage,
	}
}

func buildTargetingForSegment(seg Segment, eligibility []string) []TargetingRule {
	rules := []TargetingRule{
		{Label: "セグメント", Value: seg.Name, Icon: "🎯"},
	}
	if len(seg.Preview) > 0 {
		rules = append(rules, TargetingRule{Label: "特性", Value: strings.Join(seg.Preview, ", "), Icon: "🧭"})
	}
	if len(eligibility) > 0 {
		labels := make([]string, 0, len(eligibility))
		for _, rule := range eligibility {
			labels = append(labels, eligibilityDisplay(rule))
		}
		rules = append(rules, TargetingRule{Label: "追加条件", Value: strings.Join(labels, ", "), Icon: "🧩"})
	}
	return rules
}

func eligibilityDisplay(value string) string {
	switch strings.TrimSpace(value) {
	case "app_push":
		return "アプリ通知許諾"
	case "loyal_members":
		return "ロイヤル会員"
	case "new_customers":
		return "新規顧客"
	case "expedited":
		return "お急ぎ配送利用"
	default:
		return value
	}
}

func statusLabelValue(status Status) string {
	switch status {
	case StatusActive:
		return "アクティブ"
	case StatusScheduled:
		return "公開予定"
	case StatusPaused:
		return "一時停止"
	case StatusDraft:
		return "下書き"
	case StatusExpired:
		return "終了"
	default:
		return string(status)
	}
}

func statusToneValue(status Status) string {
	switch status {
	case StatusActive:
		return "success"
	case StatusScheduled:
		return "info"
	case StatusPaused:
		return "warning"
	case StatusDraft, StatusExpired:
		return "muted"
	default:
		return "info"
	}
}

func typeLabelValue(kind Type) string {
	switch kind {
	case TypePercentage:
		return "割引(%)"
	case TypeFixedAmount:
		return "固定額割引"
	case TypeBundle:
		return "セット/バンドル"
	case TypeShipping:
		return "配送特典"
	default:
		return string(kind)
	}
}

func segmentFromKey(key string) Segment {
	switch strings.ToLower(strings.TrimSpace(key)) {
	case "vip_retention":
		return Segment{
			Key:         "vip_retention",
			Name:        "既存顧客 (VIP)",
			Description: "昨年度の購入回数が3回以上でLTV上位20%の顧客",
			Preview:     []string{"LTV上位20%", "年間購入3回以上"},
			Audience:    1280,
		}
	case "ring_intent":
		return Segment{
			Key:         "ring_intent",
			Name:        "リング検討中ユーザー",
			Description: "リングカテゴリを頻繁に閲覧しているユーザー",
			Preview:     []string{"リング閲覧3回以上", "未購入"},
			Audience:    2543,
		}
	case "app_members":
		return Segment{
			Key:         "app_members",
			Name:        "アプリ限定会員",
			Description: "アプリ登録済みでPush通知許諾済みの会員",
			Preview:     []string{"Push許諾", "アプリ登録"},
			Audience:    980,
		}
	case "express_delivery":
		return Segment{
			Key:         "express_delivery",
			Name:        "即納希望ユーザー",
			Description: "お急ぎ配送を選択した経験がある顧客",
			Preview:     []string{"お急ぎ配送", "納期短縮"},
			Audience:    1954,
		}
	case "seasonal_inventory":
		return Segment{
			Key:         "seasonal_inventory",
			Name:        "シーズン品在庫調整",
			Description: "季節商品を購入した実績のある顧客",
			Preview:     []string{"冬物購入", "VIP除外"},
			Audience:    1680,
		}
	case "new_customers":
		return Segment{
			Key:         "new_customers",
			Name:        "新規顧客",
			Description: "初回購入見込みの顧客",
			Preview:     []string{"初回", "未購入"},
			Audience:    2100,
		}
	default:
		clean := strings.TrimSpace(key)
		if clean == "" {
			clean = "カスタムセグメント"
		}
		return Segment{
			Key:         key,
			Name:        clean,
			Description: "カスタムセグメント",
			Preview:     []string{clean},
			Audience:    800,
		}
	}
}

func coalesceCurrency(value string) string {
	if strings.TrimSpace(value) == "" {
		return "JPY"
	}
	return strings.TrimSpace(strings.ToUpper(value))
}

func newPromotionVersion() string {
	return fmt.Sprintf("v%s", time.Now().Format("20060102150405"))
}

func (s *StaticService) buildFilterSummary(filtered []Promotion) FilterSummary {
	statusCounts := make(map[Status]int)
	typeCounts := make(map[Type]int)
	channelCounts := make(map[Channel]int)
	ownerCounts := make(map[string]int)
	for _, p := range filtered {
		statusCounts[p.Status]++
		typeCounts[p.Type]++
		for _, ch := range p.Channels {
			channelCounts[ch]++
		}
		if p.CreatedBy != "" {
			ownerCounts[p.CreatedBy]++
		}
	}

	now := time.Now()
	thisWeekStart := startOfWeek(now)
	nextWeekStart := thisWeekStart.AddDate(0, 0, 7)
	next30 := now.AddDate(0, 0, 30)

	presets := []SchedulePreset{
		{Key: "current", Label: "進行中", Start: &now, End: nil},
		{Key: "this_week", Label: "今週以降", Start: &thisWeekStart, End: &nextWeekStart},
		{Key: "next_30", Label: "30日以内", Start: &now, End: &next30},
	}

	return FilterSummary{
		StatusCounts:   statusCounts,
		TypeCounts:     typeCounts,
		ChannelCounts:  channelCounts,
		OwnerCounts:    ownerCounts,
		ScheduleRanges: presets,
	}
}

func summarise(promotions []Promotion) Summary {
	var active, paused, scheduled, expired int
	var totalRedemption int
	for _, p := range promotions {
		totalRedemption += p.RedemptionCount
		switch p.Status {
		case StatusActive:
			active++
		case StatusPaused:
			paused++
		case StatusScheduled:
			scheduled++
		case StatusExpired:
			expired++
		}
	}
	var avgRedeem float64
	if len(promotions) > 0 {
		avgRedeem = float64(totalRedemption) / float64(len(promotions))
	}
	// Static assumption for uplift used by the UI metric chip.
	uplift := 0.148
	return Summary{
		ActiveCount:       active,
		PausedCount:       paused,
		ScheduledCount:    scheduled,
		ExpiredCount:      expired,
		MonthlyUpliftRate: uplift,
		AverageRedemption: avgRedeem,
	}
}

func startOfWeek(t time.Time) time.Time {
	weekday := int(t.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location()).AddDate(0, 0, -weekday+1)
}

func copyTimePtr(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	cpy := *t
	return &cpy
}

func (s *StaticService) findPromotionLocked(id string) (Promotion, bool) {
	target := strings.TrimSpace(id)
	if target == "" {
		return Promotion{}, false
	}
	for _, promo := range s.promotions {
		if strings.EqualFold(strings.TrimSpace(promo.ID), target) {
			return promo, true
		}
	}
	return Promotion{}, false
}

func resolveUsageTimeframe(query UsageQuery, reference time.Time) (start *time.Time, end *time.Time) {
	if query.Start != nil {
		val := query.Start.In(reference.Location())
		start = &val
	}
	if query.End != nil {
		val := query.End.In(reference.Location())
		end = &val
	}
	if start != nil || end != nil {
		return start, end
	}

	key := strings.ToLower(strings.TrimSpace(query.Timeframe))
	switch key {
	case "last_7_days":
		s := reference.AddDate(0, 0, -7)
		start = &s
	case "last_14_days":
		s := reference.AddDate(0, 0, -14)
		start = &s
	case "last_30_days", "", "default":
		s := reference.AddDate(0, 0, -30)
		start = &s
	case "quarter_to_date":
		month := ((int(reference.Month()) - 1) / 3) * 3
		if month < 0 {
			month = 0
		}
		s := time.Date(reference.Year(), time.Month(month+1), 1, 0, 0, 0, 0, reference.Location())
		start = &s
	}
	if start != nil && end == nil {
		e := reference
		end = &e
	}
	return start, end
}

func filterUsageRecords(records []UsageRecord, query UsageQuery, start, end *time.Time) []UsageRecord {
	minUses := query.MinUses
	if minUses < 0 {
		minUses = 0
	}

	channelFilter := make(map[Channel]struct{}, len(query.Channels))
	for _, ch := range query.Channels {
		channelFilter[ch] = struct{}{}
	}

	sourceFilter := make(map[string]struct{}, len(query.Sources))
	for _, src := range query.Sources {
		key := strings.ToLower(strings.TrimSpace(src))
		if key != "" {
			sourceFilter[key] = struct{}{}
		}
	}

	segmentFilter := make(map[string]struct{}, len(query.SegmentKeys))
	for _, seg := range query.SegmentKeys {
		key := strings.ToLower(strings.TrimSpace(seg))
		if key != "" {
			segmentFilter[key] = struct{}{}
		}
	}

	result := make([]UsageRecord, 0, len(records))
	for _, rec := range records {
		if minUses > 0 && rec.UsageCount < minUses {
			continue
		}
		if len(segmentFilter) > 0 {
			key := strings.ToLower(strings.TrimSpace(rec.SegmentKey))
			if _, ok := segmentFilter[key]; !ok {
				continue
			}
		}
		if !matchesChannelFilter(rec.Channels, channelFilter) {
			continue
		}
		if !matchesSourceFilter(rec.Sources, sourceFilter) {
			continue
		}
		if start != nil && !rec.LastUsedAt.IsZero() && rec.LastUsedAt.Before(*start) {
			continue
		}
		if end != nil && !rec.LastUsedAt.IsZero() && rec.LastUsedAt.After(*end) {
			continue
		}
		result = append(result, rec)
	}
	return result
}

func matchesChannelFilter(channels []Channel, filter map[Channel]struct{}) bool {
	if len(filter) == 0 {
		return true
	}
	seen := make(map[Channel]struct{}, len(channels))
	for _, ch := range channels {
		seen[ch] = struct{}{}
	}
	for ch := range seen {
		if _, ok := filter[ch]; ok {
			return true
		}
	}
	return false
}

func matchesSourceFilter(sources []string, filter map[string]struct{}) bool {
	if len(filter) == 0 {
		return true
	}
	seen := make(map[string]struct{}, len(sources))
	for _, src := range sources {
		key := strings.ToLower(strings.TrimSpace(src))
		if key != "" {
			seen[key] = struct{}{}
		}
	}
	for key := range seen {
		if _, ok := filter[key]; ok {
			return true
		}
	}
	return false
}

func sortUsageRecords(records []UsageRecord, sortKey, sortDirection string) {
	if len(records) <= 1 {
		return
	}

	descending := true
	if strings.EqualFold(strings.TrimSpace(sortDirection), "asc") {
		descending = false
	}

	key := strings.ToLower(strings.TrimSpace(sortKey))
	switch key {
	case "usage", "usage_count":
		sort.SliceStable(records, func(i, j int) bool {
			if descending {
				if records[i].UsageCount == records[j].UsageCount {
					return records[i].LastUsedAt.After(records[j].LastUsedAt)
				}
				return records[i].UsageCount > records[j].UsageCount
			}
			if records[i].UsageCount == records[j].UsageCount {
				return records[i].LastUsedAt.Before(records[j].LastUsedAt)
			}
			return records[i].UsageCount < records[j].UsageCount
		})
	case "discount":
		sort.SliceStable(records, func(i, j int) bool {
			if descending {
				if records[i].TotalDiscountMinor == records[j].TotalDiscountMinor {
					return records[i].LastUsedAt.After(records[j].LastUsedAt)
				}
				return records[i].TotalDiscountMinor > records[j].TotalDiscountMinor
			}
			if records[i].TotalDiscountMinor == records[j].TotalDiscountMinor {
				return records[i].LastUsedAt.Before(records[j].LastUsedAt)
			}
			return records[i].TotalDiscountMinor < records[j].TotalDiscountMinor
		})
	case "customer":
		sort.SliceStable(records, func(i, j int) bool {
			left := strings.ToLower(records[i].User.Name)
			if left == "" {
				left = strings.ToLower(records[i].User.Email)
			}
			right := strings.ToLower(records[j].User.Name)
			if right == "" {
				right = strings.ToLower(records[j].User.Email)
			}
			if descending {
				return left > right
			}
			return left < right
		})
	default:
		sort.SliceStable(records, func(i, j int) bool {
			if descending {
				return records[i].LastUsedAt.After(records[j].LastUsedAt)
			}
			return records[i].LastUsedAt.Before(records[j].LastUsedAt)
		})
	}
}

func aggregateUsageSummary(records []UsageRecord, promotion Promotion) UsageSummary {
	var totalRedemptions int
	var totalDiscount int64
	var totalOrder int64

	for _, rec := range records {
		totalRedemptions += rec.UsageCount
		totalDiscount += rec.TotalDiscountMinor
		totalOrder += rec.TotalOrderAmountMinor
	}

	summary := UsageSummary{
		TotalRedemptions:   totalRedemptions,
		TotalDiscountMinor: totalDiscount,
	}
	if totalRedemptions > 0 {
		count := int64(totalRedemptions)
		summary.AverageDiscountMinor = totalDiscount / count
		summary.AverageOrderAmountMinor = totalOrder / count
	}

	audience := promotion.Segment.Audience
	if audience <= 0 {
		audience = 1
	}
	rate := float64(totalRedemptions) / float64(audience)
	if rate > 1 {
		rate = 1
	}
	summary.ConversionRate = rate
	return summary
}

func buildUsageFilterSummary(records []UsageRecord, reference time.Time) UsageFilterSummary {
	if len(records) == 0 {
		return UsageFilterSummary{
			TimeframePresets: usageTimeframePresets(reference),
			UsageThresholds:  defaultUsageThresholds(),
		}
	}

	channelCounts := make(map[Channel]int)
	sourceCounts := make(map[string]int)
	segmentCounts := make(map[string]struct {
		Label string
		Count int
	})

	for _, rec := range records {
		channelSeen := make(map[Channel]struct{})
		for _, ch := range rec.Channels {
			channelSeen[ch] = struct{}{}
		}
		for ch := range channelSeen {
			channelCounts[ch]++
		}

		sourceSeen := make(map[string]struct{})
		for _, src := range rec.Sources {
			key := strings.ToLower(strings.TrimSpace(src))
			if key != "" {
				sourceSeen[key] = struct{}{}
			}
		}
		for key := range sourceSeen {
			sourceCounts[key]++
		}

		key := strings.ToLower(strings.TrimSpace(rec.SegmentKey))
		if key == "" {
			continue
		}
		entry := segmentCounts[key]
		entry.Label = rec.SegmentLabel
		entry.Count++
		segmentCounts[key] = entry
	}

	channelOptions := make([]UsageFilterOption, 0, len(channelCounts))
	for ch, count := range channelCounts {
		channelOptions = append(channelOptions, UsageFilterOption{
			Value: string(ch),
			Label: channelDisplay(ch),
			Count: count,
		})
	}
	sort.SliceStable(channelOptions, func(i, j int) bool {
		if channelOptions[i].Count == channelOptions[j].Count {
			return channelOptions[i].Label < channelOptions[j].Label
		}
		return channelOptions[i].Count > channelOptions[j].Count
	})

	sourceOptions := make([]UsageFilterOption, 0, len(sourceCounts))
	for key, count := range sourceCounts {
		sourceOptions = append(sourceOptions, UsageFilterOption{
			Value: key,
			Label: usageSourceLabel(key),
			Count: count,
		})
	}
	sort.SliceStable(sourceOptions, func(i, j int) bool {
		if sourceOptions[i].Count == sourceOptions[j].Count {
			return sourceOptions[i].Label < sourceOptions[j].Label
		}
		return sourceOptions[i].Count > sourceOptions[j].Count
	})

	segmentOptions := make([]UsageFilterOption, 0, len(segmentCounts))
	for key, entry := range segmentCounts {
		segmentOptions = append(segmentOptions, UsageFilterOption{
			Value: key,
			Label: entry.Label,
			Count: entry.Count,
		})
	}
	sort.SliceStable(segmentOptions, func(i, j int) bool {
		if segmentOptions[i].Count == segmentOptions[j].Count {
			return segmentOptions[i].Label < segmentOptions[j].Label
		}
		return segmentOptions[i].Count > segmentOptions[j].Count
	})

	return UsageFilterSummary{
		ChannelOptions:   channelOptions,
		SourceOptions:    sourceOptions,
		SegmentOptions:   segmentOptions,
		TimeframePresets: usageTimeframePresets(reference),
		UsageThresholds:  defaultUsageThresholds(),
	}
}

func usageTimeframePresets(reference time.Time) []UsageTimeframePreset {
	end := reference
	start7 := reference.AddDate(0, 0, -7)
	start14 := reference.AddDate(0, 0, -14)
	start30 := reference.AddDate(0, 0, -30)

	month := ((int(reference.Month()) - 1) / 3) * 3
	startQuarter := time.Date(reference.Year(), time.Month(month+1), 1, 0, 0, 0, 0, reference.Location())

	return []UsageTimeframePreset{
		{Key: "last_7_days", Label: "直近7日間", Start: &start7, End: &end},
		{Key: "last_14_days", Label: "直近14日間", Start: &start14, End: &end},
		{Key: "last_30_days", Label: "直近30日間", Start: &start30, End: &end},
		{Key: "quarter_to_date", Label: "四半期累計", Start: &startQuarter, End: &end},
	}
}

func defaultUsageThresholds() []UsageThresholdOption {
	values := []int{1, 3, 5, 10}
	options := make([]UsageThresholdOption, 0, len(values))
	for _, v := range values {
		options = append(options, UsageThresholdOption{
			Value: v,
			Label: fmt.Sprintf("%d回以上", v),
		})
	}
	return options
}

func channelDisplay(ch Channel) string {
	switch ch {
	case ChannelOnlineStore:
		return "オンライン"
	case ChannelRetail:
		return "店舗"
	case ChannelApp:
		return "アプリ"
	default:
		return string(ch)
	}
}

func usageSourceLabel(code string) string {
	switch strings.ToLower(strings.TrimSpace(code)) {
	case "checkout_web":
		return "オンラインストア"
	case "express_checkout":
		return "クイックチェックアウト"
	case "app_push":
		return "アプリPush"
	case "app_campaign":
		return "アプリキャンペーン"
	case "app_flash":
		return "フラッシュセール"
	case "push_message":
		return "Pushメッセージ"
	case "support_manual":
		return "サポート代行"
	case "retail_pos":
		return "店舗POS"
	case "campaign_preview":
		return "キャンペーン検証"
	default:
		return code
	}
}

func buildUsageAlert(promotion Promotion, query UsageQuery, summary UsageSummary) *UsageAlert {
	if summary.TotalRedemptions == 0 {
		return nil
	}
	if promotion.Status == StatusPaused {
		link := fmt.Sprintf("/admin/promotions/%s/analytics", url.QueryEscape(promotion.ID))
		message := fmt.Sprintf("%s は一時停止中ですが直近で %d 件の利用が検知されています。", promotion.Name, summary.TotalRedemptions)
		return &UsageAlert{
			Tone:      "warning",
			Message:   message,
			LinkLabel: "分析を開く",
			LinkURL:   link,
		}
	}

	timeframe := strings.ToLower(strings.TrimSpace(query.Timeframe))
	threshold := promotion.UsageLimitTotal / 12
	if threshold < 25 {
		threshold = 25
	}
	if timeframe == "last_7_days" {
		threshold = promotion.UsageLimitTotal / 20
		if threshold < 15 {
			threshold = 15
		}
	}
	if promotion.UsageLimitTotal == 0 {
		threshold = 30
	}

	if summary.TotalRedemptions >= threshold && threshold > 0 {
		link := fmt.Sprintf("/admin/promotions/%s/analytics", url.QueryEscape(promotion.ID))
		message := fmt.Sprintf("%s の利用が想定より多く発生しています。(期間内 %d 件)", promotion.Name, summary.TotalRedemptions)
		return &UsageAlert{
			Tone:      "warning",
			Message:   message,
			LinkLabel: "詳細を確認",
			LinkURL:   link,
		}
	}
	return nil
}
