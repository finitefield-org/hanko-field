package promotions

import (
	"context"
	"fmt"
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
	nextID     int
}

const (
	shippingOptionFree = "free"
	shippingOptionFlat = "flat"
)

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

	return &StaticService{
		promotions: promotions,
		details:    details,
		nextID:     len(promotions),
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
