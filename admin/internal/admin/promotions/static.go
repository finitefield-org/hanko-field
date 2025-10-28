package promotions

import (
	"context"
	"sort"
	"strings"
	"sync"
	"time"
)

// StaticService provides deterministic promotion data suitable for development and tests.
type StaticService struct {
	mu         sync.RWMutex
	promotions []Promotion
	details    map[string]PromotionDetail
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
		Name:        "既存顧客 (VIP)",
		Description: "昨年度の購入回数が3回以上でLTV上位20%の顧客",
		Preview:     []string{"LTV上位20%", "年間購入回数3回以上", "メールサブスク登録済み"},
		Audience:    1280,
	}
	segmentRing := Segment{
		Name:        "リング検討中ユーザー",
		Description: "過去30日以内にリングカテゴリを3回以上閲覧している未購入ユーザー",
		Preview:     []string{"カテゴリ: リング", "閲覧3回以上", "未購入"},
		Audience:    2543,
	}
	segmentApp := Segment{
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

	return &StaticService{
		promotions: promotions,
		details:    details,
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
