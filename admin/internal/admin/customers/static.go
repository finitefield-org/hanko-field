package customers

import (
	"context"
	"sort"
	"strings"
	"time"
	"unicode"
)

// StaticService provides canned customer data for development and previews.
type StaticService struct {
	Customers []Customer
}

// NewStaticService builds a StaticService populated with representative customers.
func NewStaticService() *StaticService {
	now := time.Now()
	customers := []Customer{
		{
			ID:                 "cus_1001",
			DisplayName:        "佐藤 花子",
			Email:              "hanako.sato@example.com",
			AvatarURL:          "https://cdn.example.com/avatars/hanako.png",
			Company:            "Hanako Design Studio",
			Location:           "東京",
			Tier:               "gold",
			Status:             StatusActive,
			TotalOrders:        24,
			LifetimeValueMinor: 1280000,
			Currency:           "JPY",
			LastOrderAt:        now.Add(-36 * time.Hour),
			LastOrderNumber:    "HF-240512-1048",
			LastOrderID:        "ord_1048",
			LastInteraction:    "サポート: 名刺の再印刷を依頼（3日前）",
			RiskLevel:          "low",
			Flags: []Flag{
				{Label: "VIP", Tone: "success", Icon: "💎", Description: "年間LTV 100万円超え"},
			},
			Tags:     []string{"b2b", "design"},
			JoinedAt: now.AddDate(-3, -2, 0),
		},
		{
			ID:                 "cus_1002",
			DisplayName:        "高橋 健",
			Email:              "ken.takahashi@example.com",
			AvatarURL:          "https://cdn.example.com/avatars/ken.png",
			Company:            "Takumi Craft Works",
			Location:           "大阪",
			Tier:               "silver",
			Status:             StatusActive,
			TotalOrders:        12,
			LifetimeValueMinor: 420000,
			Currency:           "JPY",
			LastOrderAt:        now.Add(-6 * 24 * time.Hour),
			LastOrderNumber:    "HF-240428-0998",
			LastOrderID:        "ord_0998",
			LastInteraction:    "メール: 新商品カタログ送付（10日前）",
			RiskLevel:          "medium",
			Flags: []Flag{
				{Label: "アップセル候補", Tone: "info", Icon: "⬆", Description: "定期的に大ロット注文"},
			},
			Tags:     []string{"manufacturing"},
			JoinedAt: now.AddDate(-2, -1, 0),
		},
		{
			ID:                 "cus_1003",
			DisplayName:        "鈴木 愛",
			Email:              "ai.suzuki@example.com",
			AvatarURL:          "https://cdn.example.com/avatars/ai.png",
			Company:            "",
			Location:           "神奈川",
			Tier:               "bronze",
			Status:             StatusActive,
			TotalOrders:        5,
			LifetimeValueMinor: 86000,
			Currency:           "JPY",
			LastOrderAt:        now.Add(-14 * 24 * time.Hour),
			LastOrderNumber:    "HF-240322-0882",
			LastOrderID:        "ord_0882",
			LastInteraction:    "チャット: 配送日変更（12日前）",
			RiskLevel:          "low",
			Flags: []Flag{
				{Label: "レビュー投稿", Tone: "success", Icon: "⭐", Description: "直近で高評価レビュー"},
			},
			Tags:     []string{"consumer"},
			JoinedAt: now.AddDate(-1, -3, 0),
		},
		{
			ID:                 "cus_1004",
			DisplayName:        "山本 大輔",
			Email:              "daisuke.yamamoto@example.com",
			AvatarURL:          "https://cdn.example.com/avatars/daisuke.png",
			Company:            "Yamamoto Consulting",
			Location:           "名古屋",
			Tier:               "gold",
			Status:             StatusDeactivated,
			TotalOrders:        3,
			LifetimeValueMinor: 54000,
			Currency:           "JPY",
			LastOrderAt:        now.Add(-180 * 24 * time.Hour),
			LastOrderNumber:    "HF-230930-0611",
			LastOrderID:        "ord_0611",
			LastInteraction:    "サポート: アカウント停止を希望",
			RiskLevel:          "high",
			Flags: []Flag{
				{Label: "チャーン", Tone: "danger", Icon: "⚠", Description: "アカウント停止処理済み"},
			},
			Tags:     []string{"b2b", "dormant"},
			JoinedAt: now.AddDate(-4, 0, 0),
		},
		{
			ID:                 "cus_1005",
			DisplayName:        "井上 茜",
			Email:              "akane.inoue@example.com",
			AvatarURL:          "https://cdn.example.com/avatars/akane.png",
			Company:            "Akane Handmade",
			Location:           "札幌",
			Tier:               "vip",
			Status:             StatusActive,
			TotalOrders:        31,
			LifetimeValueMinor: 1860000,
			Currency:           "JPY",
			LastOrderAt:        now.Add(-5 * time.Hour),
			LastOrderNumber:    "HF-240513-1051",
			LastOrderID:        "ord_1051",
			LastInteraction:    "Slack: 新規プロダクトの共同開発相談",
			RiskLevel:          "low",
			Flags: []Flag{
				{Label: "共同開発", Tone: "info", Icon: "🤝", Description: "プロダクト共同開発中"},
				{Label: "VIP", Tone: "success", Icon: "💎", Description: "年間売上最大顧客"},
			},
			Tags:     []string{"partner", "artisanal"},
			JoinedAt: now.AddDate(-5, 0, 0),
		},
		{
			ID:                 "cus_1006",
			DisplayName:        "小林 誠",
			Email:              "makoto.kobayashi@example.com",
			AvatarURL:          "https://cdn.example.com/avatars/makoto.png",
			Company:            "Koba Retail",
			Location:           "福岡",
			Tier:               "silver",
			Status:             StatusInvited,
			TotalOrders:        0,
			LifetimeValueMinor: 0,
			Currency:           "JPY",
			LastOrderAt:        time.Time{},
			LastOrderNumber:    "",
			LastOrderID:        "",
			LastInteraction:    "招待メール送信済み（1日前）",
			RiskLevel:          "medium",
			Flags: []Flag{
				{Label: "未アクティブ", Tone: "warning", Icon: "⌛", Description: "初回注文待ち"},
			},
			Tags:     []string{"prospect"},
			JoinedAt: now.AddDate(0, -1, -12),
		},
	}

	return &StaticService{Customers: customers}
}

// List implements Service.
func (s *StaticService) List(_ context.Context, _ string, query ListQuery) (ListResult, error) {
	if s.Customers == nil {
		s.Customers = []Customer{}
	}

	filtered := make([]Customer, 0, len(s.Customers))
	search := strings.ToLower(strings.TrimSpace(query.Search))
	for _, customer := range s.Customers {
		if query.Status != "" && customer.Status != query.Status {
			continue
		}
		if strings.TrimSpace(query.Tier) != "" && !strings.EqualFold(customer.Tier, query.Tier) {
			continue
		}
		if search != "" {
			targets := []string{
				strings.ToLower(customer.DisplayName),
				strings.ToLower(customer.Email),
				strings.ToLower(customer.Company),
			}
			matched := false
			for _, t := range targets {
				if strings.Contains(t, search) {
					matched = true
					break
				}
			}
			if !matched {
				continue
			}
		}
		filtered = append(filtered, customer)
	}

	sortKey := strings.TrimSpace(query.SortKey)
	sortDir := query.SortDirection
	if sortDir == "" {
		sortDir = SortDirectionDesc
	}

	sort.SliceStable(filtered, func(i, j int) bool {
		a := filtered[i]
		b := filtered[j]
		less := false
		switch sortKey {
		case "name":
			less = strings.ToLower(a.DisplayName) < strings.ToLower(b.DisplayName)
		case "lifetime_value":
			less = a.LifetimeValueMinor < b.LifetimeValueMinor
		case "total_orders":
			less = a.TotalOrders < b.TotalOrders
		case "status":
			less = strings.ToLower(string(a.Status)) < strings.ToLower(string(b.Status))
		default:
			// last_order (default)
			less = a.LastOrderAt.Before(b.LastOrderAt)
		}
		if sortDir == SortDirectionAsc {
			return less
		}
		return !less
	})

	pageSize := query.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}
	page := query.Page
	if page <= 0 {
		page = 1
	}

	total := len(filtered)
	start := (page - 1) * pageSize
	if start > total {
		start = total
	}
	end := start + pageSize
	if end > total {
		end = total
	}

	paged := append([]Customer(nil), filtered[start:end]...)

	var next, prev *int
	if end < total {
		n := page + 1
		next = &n
	}
	if page > 1 && start <= total {
		p := page - 1
		prev = &p
	}

	result := ListResult{
		Customers:   paged,
		Pagination:  Pagination{Page: page, PageSize: pageSize, TotalItems: total, NextPage: next, PrevPage: prev},
		Summary:     calculateSummary(filtered),
		Filters:     buildFilterSummary(s.Customers),
		GeneratedAt: time.Now(),
	}
	return result, nil
}

func calculateSummary(customers []Customer) Summary {
	summary := Summary{}
	if len(customers) == 0 {
		return summary
	}

	var totalOrders int
	for _, c := range customers {
		summary.TotalCustomers++
		switch c.Status {
		case StatusActive:
			summary.ActiveCustomers++
		case StatusDeactivated:
			summary.DeactivatedCustomers++
		}
		if c.LifetimeValueMinor >= 1000000 {
			summary.HighValueCustomers++
		}
		totalOrders += c.TotalOrders
		summary.TotalLifetimeMinor += c.LifetimeValueMinor
		if summary.PrimaryCurrency == "" && strings.TrimSpace(c.Currency) != "" {
			summary.PrimaryCurrency = c.Currency
		}
	}
	if totalOrders > 0 {
		summary.AverageOrderValue = float64(summary.TotalLifetimeMinor) / float64(totalOrders)
	}

	tierCounts := map[string]int{}
	for _, c := range customers {
		key := strings.ToLower(strings.TrimSpace(c.Tier))
		if key == "" {
			key = "other"
		}
		tierCounts[key]++
	}
	for key, count := range tierCounts {
		label := map[string]string{
			"vip":    "VIP",
			"gold":   "ゴールド",
			"silver": "シルバー",
			"bronze": "ブロンズ",
			"other":  "その他",
		}[key]
		if label == "" {
			label = titleize(key)
		}
		summary.Segments = append(summary.Segments, SegmentMetric{
			Key:   key,
			Label: label,
			Count: count,
		})
	}
	sort.Slice(summary.Segments, func(i, j int) bool {
		return summary.Segments[i].Count > summary.Segments[j].Count
	})

	return summary
}

func buildFilterSummary(customers []Customer) FilterSummary {
	statusCounts := map[Status]int{
		StatusActive:      0,
		StatusDeactivated: 0,
		StatusInvited:     0,
	}
	tierCounts := map[string]int{}

	for _, c := range customers {
		statusCounts[c.Status]++
		key := strings.ToLower(strings.TrimSpace(c.Tier))
		if key == "" {
			key = "other"
		}
		tierCounts[key]++
	}

	statusOptions := []StatusOption{
		{Value: "", Label: "全て", Count: len(customers)},
		{Value: StatusActive, Label: "アクティブ", Count: statusCounts[StatusActive]},
		{Value: StatusInvited, Label: "未アクティブ", Count: statusCounts[StatusInvited]},
		{Value: StatusDeactivated, Label: "無効化", Count: statusCounts[StatusDeactivated]},
	}

	var tierOptions []TierOption
	for key, count := range tierCounts {
		label := map[string]string{
			"vip":    "VIP",
			"gold":   "ゴールド",
			"silver": "シルバー",
			"bronze": "ブロンズ",
			"other":  "その他",
		}[key]
		if label == "" {
			label = titleize(key)
		}
		tierOptions = append(tierOptions, TierOption{
			Value: key,
			Label: label,
			Count: count,
		})
	}
	sort.Slice(tierOptions, func(i, j int) bool {
		return tierOptions[i].Label < tierOptions[j].Label
	})

	return FilterSummary{
		StatusOptions: statusOptions,
		TierOptions:   tierOptions,
	}
}

func titleize(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	runes := []rune(value)
	runes[0] = unicode.ToUpper(runes[0])
	return string(runes)
}
