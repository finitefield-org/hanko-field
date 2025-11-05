package customers

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"
	"unicode"
)

// StaticService provides canned customer data for development and previews.
type StaticService struct {
	Customers []Customer
	Details   map[string]Detail
	AuditLog  map[string][]AuditRecord
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

	return &StaticService{
		Customers: customers,
		Details:   buildStaticDetails(customers, now),
		AuditLog:  make(map[string][]AuditRecord),
	}
}

func buildStaticDetails(customers []Customer, now time.Time) map[string]Detail {
	details := make(map[string]Detail, len(customers))
	for _, c := range customers {
		switch c.ID {
		case "cus_1001":
			details[c.ID] = Detail{
				Profile: Profile{
					ID:                 c.ID,
					DisplayName:        c.DisplayName,
					Email:              c.Email,
					Phone:              "03-1234-5678",
					AvatarURL:          c.AvatarURL,
					Company:            c.Company,
					Location:           c.Location,
					Tier:               c.Tier,
					Status:             c.Status,
					TotalOrders:        c.TotalOrders,
					LifetimeValueMinor: c.LifetimeValueMinor,
					Currency:           c.Currency,
					LastOrderAt:        c.LastOrderAt,
					LastOrderNumber:    c.LastOrderNumber,
					LastOrderID:        c.LastOrderID,
					JoinedAt:           c.JoinedAt,
					RiskLevel:          c.RiskLevel,
					Flags:              append([]Flag(nil), c.Flags...),
					Tags:               append([]string(nil), c.Tags...),
					QuickActions: []QuickAction{
						{Label: "メールを送信", Href: "mailto:" + c.Email, Variant: "secondary", Icon: "✉"},
						{Label: "注文を作成", Href: "/admin/orders/new?customer=" + c.ID, Variant: "primary", Icon: "🛒"},
						{Label: "Slack で共有", Href: "https://slack.com/app_redirect?channel=support", Variant: "ghost", Icon: "💬"},
						{Label: "退会＋マスク", Href: "/admin/customers/" + c.ID + "/modal/deactivate-mask", Variant: "danger", Icon: "🛡️", Method: "modal"},
					},
				},
				Metrics: []Metric{
					{Key: "orders", Label: "累計注文", Value: "24件", SubLabel: "今月 3件", Tone: "info", Trend: Trend{Label: "+12% vs LY", Tone: "success", Icon: "⬆"}},
					{Key: "ltv", Label: "累計売上", Value: "¥1,280,000", SubLabel: "平均 ¥53,333", Tone: "success", Trend: Trend{Label: "+8% QoQ", Tone: "success", Icon: "⬆"}},
					{Key: "returns", Label: "返品率", Value: "1.2%", SubLabel: "過去12ヶ月 2件", Tone: "success", Trend: Trend{Label: "-0.8pt", Tone: "success", Icon: "⬇"}},
					{Key: "tickets", Label: "サポート対応", Value: "5件", SubLabel: "未解決 1件", Tone: "warning", Trend: Trend{Label: "今月 2件", Tone: "info", Icon: "🛈"}},
				},
				RecentOrders: []OrderSummary{
					{
						ID:                "ord_1051",
						Number:            "HF-240513-1051",
						PlacedAt:          now.Add(-5 * time.Hour),
						Status:            "制作中",
						StatusTone:        "info",
						FulfillmentStatus: "工場: プレート加工",
						FulfillmentTone:   "info",
						PaymentStatus:     "支払い済み (カード)",
						PaymentTone:       "success",
						TotalMinor:        580000,
						Currency:          "JPY",
						ItemSummary:       "特注表札 200枚 / ギフト包装",
						DeliveryTarget:    "5月20日 納品予定",
						LastUpdated:       now.Add(-90 * time.Minute),
					},
					{
						ID:                "ord_1048",
						Number:            "HF-240512-1048",
						PlacedAt:          now.Add(-36 * time.Hour),
						Status:            "出荷済み",
						StatusTone:        "success",
						FulfillmentStatus: "配送中 (佐川急便)",
						FulfillmentTone:   "success",
						PaymentStatus:     "支払い済み (請求書)",
						PaymentTone:       "success",
						TotalMinor:        420000,
						Currency:          "JPY",
						ItemSummary:       "ショップカード 5,000枚",
						DeliveryTarget:    "5月18日 到着予定",
						LastUpdated:       now.Add(-10 * time.Hour),
					},
					{
						ID:                "ord_0988",
						Number:            "HF-240430-0988",
						PlacedAt:          now.Add(-14 * 24 * time.Hour),
						Status:            "完了",
						StatusTone:        "success",
						FulfillmentStatus: "納品済み",
						FulfillmentTone:   "success",
						PaymentStatus:     "支払い済み",
						PaymentTone:       "success",
						TotalMinor:        160000,
						Currency:          "JPY",
						ItemSummary:       "封筒 2,000枚 / 活版名刺 300セット",
						DeliveryTarget:    "4月28日 納品済み",
						LastUpdated:       now.Add(-12 * 24 * time.Hour),
					},
				},
				Addresses: []Address{
					{
						ID:         "addr_hanako_main",
						Label:      "本社出荷先",
						Name:       "佐藤 花子",
						Company:    c.Company,
						Phone:      "03-1234-5678",
						Lines:      []string{"東京都渋谷区桜丘町 5-10", "Hanako Design Studio"},
						City:       "渋谷区",
						Prefecture: "東京都",
						PostalCode: "150-0031",
						Country:    "日本",
						Type:       "shipping",
						Primary:    true,
						UpdatedAt:  now.Add(-30 * 24 * time.Hour),
						Notes:      []string{"平日 10:00-17:00 受け取り可"},
					},
					{
						ID:         "addr_hanako_billing",
						Label:      "請求書送付先",
						Name:       "経理担当: 中村様",
						Company:    c.Company,
						Phone:      "03-1234-5679",
						Lines:      []string{"東京都渋谷区渋谷 1-2-3", "WeWork 12F"},
						City:       "渋谷区",
						Prefecture: "東京都",
						PostalCode: "150-0002",
						Country:    "日本",
						Type:       "billing",
						Primary:    false,
						UpdatedAt:  now.Add(-90 * 24 * time.Hour),
					},
				},
				PaymentMethods: []PaymentMethod{
					{
						ID:         "pm_card_visa",
						Type:       "card",
						Brand:      "Visa",
						Last4:      "4242",
						ExpMonth:   4,
						ExpYear:    now.AddDate(3, 0, 0).Year(),
						HolderName: "HANAKO SATO",
						Status:     "有効",
						StatusTone: "success",
						Primary:    true,
						AddedAt:    now.AddDate(-1, -2, 0),
					},
					{
						ID:         "pm_bank_mizuho",
						Type:       "bank_transfer",
						Brand:      "みずほ銀行",
						Last4:      "1023",
						HolderName: "ハナコデザインスタジオ",
						Status:     "承認済み (法人口座)",
						StatusTone: "info",
						Primary:    false,
						AddedAt:    now.AddDate(-2, 0, 0),
					},
				},
				SupportNotes: []SupportNote{
					{
						ID:         "note_vip_follow",
						Title:      "VIP向けオンボーディング完了",
						Body:       "制作工程の見学を希望。来月頭に工場ツアーを実施予定。要フォローアップ。",
						CreatedAt:  now.Add(-7 * 24 * time.Hour),
						Author:     "三浦 (CS)",
						AuthorRole: "カスタマーサクセス",
						Tone:       "info",
						Visibility: "internal",
						Tags:       []string{"VIP", "ツアー"},
					},
					{
						ID:         "note_color_profile",
						Title:      "特色インクの指定あり",
						Body:       "DIC F57を固定使用。色ブレがあった場合は即時連絡のこと。サンプル保管済み。",
						CreatedAt:  now.Add(-30 * 24 * time.Hour),
						Author:     "大森 (プリズム工場)",
						AuthorRole: "工場マネージャー",
						Tone:       "warning",
						Visibility: "internal",
						Tags:       []string{"製造メモ"},
					},
				},
				Activity: []ActivityItem{
					{
						ID:          "act_support_ticket",
						Timestamp:   now.Add(-72 * time.Hour),
						Actor:       "CS高木",
						ActorRole:   "サポート",
						Title:       "名刺の再印刷を完了",
						Description: "特急料金にて 200 部再印刷。FedExで発送済み。",
						Tone:        "success",
						Icon:        "📬",
					},
					{
						ID:          "act_order_create",
						Timestamp:   now.Add(-6 * 24 * time.Hour),
						Actor:       "花子 佐藤",
						ActorRole:   "顧客",
						Title:       "オンライン注文 #HF-240512-1048",
						Description: "店舗カード 5,000枚を発注。請求書払いを選択。",
						Tone:        "info",
						Icon:        "🧾",
					},
					{
						ID:          "act_design_approval",
						Timestamp:   now.Add(-15 * 24 * time.Hour),
						Actor:       "デザイン審査",
						ActorRole:   "オペレーション",
						Title:       "特色検版を承認",
						Description: "特色インク DIC F57 の試刷り承認済み。",
						Tone:        "success",
						Icon:        "✅",
					},
				},
				InfoRail: InfoRail{
					RiskLevel:       c.RiskLevel,
					RiskTone:        "low",
					RiskDescription: "支払い遅延なし。年間LTV100万円超えのパートナー顧客。",
					Segments:        []string{"VIP", "共同開発パートナー"},
					Flags:           append([]Flag(nil), c.Flags...),
					Escalations: []RailItem{
						{
							ID:          "esc_feb_issue",
							Label:       "2月: 色ブレクレーム",
							Description: "再印刷対応で解決。原因: 特色インクの撹拌不足。",
							Tone:        "warning",
							Timestamp:   now.AddDate(0, -3, -12),
						},
					},
					FraudChecks: []RailItem{
						{
							ID:          "fraud_kb",
							Label:       "KYC 済み (法人登録)",
							Description: "登記簿謄本確認済み 2024/01/10",
							Tone:        "success",
							Timestamp:   now.AddDate(0, -4, 0),
						},
					},
					IdentityDocs: []RailItem{
						{
							ID:          "doc_vendor_contract",
							Label:       "業務委託契約書",
							Description: "2023/12/01 締結 - 次回更新 2024/12/01",
							Tone:        "info",
						},
					},
					Contacts: []RailItem{
						{
							ID:          "contact_cs",
							Label:       "CS担当: 三浦",
							Description: "Slack #vip-customers で連絡済み。",
							Tone:        "info",
							LinkLabel:   "Slackで開く",
							LinkURL:     "https://slack.com/app_redirect?channel=vip-customers",
						},
					},
				},
				LastUpdated: now,
			}
		case "cus_1002":
			details[c.ID] = Detail{
				Profile: Profile{
					ID:                 c.ID,
					DisplayName:        c.DisplayName,
					Email:              c.Email,
					Phone:              "06-2222-3333",
					AvatarURL:          c.AvatarURL,
					Company:            c.Company,
					Location:           c.Location,
					Tier:               c.Tier,
					Status:             c.Status,
					TotalOrders:        c.TotalOrders,
					LifetimeValueMinor: c.LifetimeValueMinor,
					Currency:           c.Currency,
					LastOrderAt:        c.LastOrderAt,
					LastOrderNumber:    c.LastOrderNumber,
					LastOrderID:        c.LastOrderID,
					JoinedAt:           c.JoinedAt,
					RiskLevel:          c.RiskLevel,
					Flags:              append([]Flag(nil), c.Flags...),
					Tags:               append([]string(nil), c.Tags...),
					QuickActions: []QuickAction{
						{Label: "メールを送信", Href: "mailto:" + c.Email, Variant: "secondary", Icon: "✉"},
						{Label: "営業へ共有", Href: "https://slack.com/app_redirect?channel=upsell", Variant: "ghost", Icon: "📈"},
						{Label: "退会＋マスク", Href: "/admin/customers/" + c.ID + "/modal/deactivate-mask", Variant: "danger", Icon: "🛡️", Method: "modal"},
					},
				},
				Metrics: []Metric{
					{Key: "orders", Label: "累計注文", Value: "12件", SubLabel: "今月 1件", Tone: "info", Trend: Trend{Label: "+5% vs LY", Tone: "success", Icon: "⬆"}},
					{Key: "ltv", Label: "累計売上", Value: "¥420,000", SubLabel: "平均 ¥35,000", Tone: "info", Trend: Trend{Label: "+3% QoQ", Tone: "success", Icon: "⬆"}},
					{Key: "returns", Label: "返品率", Value: "3.4%", SubLabel: "過去12ヶ月 1件", Tone: "warning", Trend: Trend{Label: "+1pt", Tone: "warning", Icon: "⚠"}},
					{Key: "tickets", Label: "サポート対応", Value: "2件", SubLabel: "未解決 0件", Tone: "success", Trend: Trend{Label: "今月 0件", Tone: "success", Icon: "✅"}},
				},
				RecentOrders: []OrderSummary{
					{
						ID:                "ord_0998",
						Number:            "HF-240428-0998",
						PlacedAt:          now.Add(-6 * 24 * time.Hour),
						Status:            "配送中",
						StatusTone:        "info",
						FulfillmentStatus: "大阪DCより出荷済み",
						FulfillmentTone:   "info",
						PaymentStatus:     "支払い待ち (期日 5/20)",
						PaymentTone:       "warning",
						TotalMinor:        320000,
						Currency:          "JPY",
						ItemSummary:       "木製什器セット 20台",
						DeliveryTarget:    "5月21日 納期",
						LastUpdated:       now.Add(-12 * time.Hour),
					},
					{
						ID:                "ord_0931",
						Number:            "HF-240312-0931",
						PlacedAt:          now.Add(-60 * 24 * time.Hour),
						Status:            "完了",
						StatusTone:        "success",
						FulfillmentStatus: "納品済み",
						FulfillmentTone:   "success",
						PaymentStatus:     "支払い済み",
						PaymentTone:       "success",
						TotalMinor:        68000,
						Currency:          "JPY",
						ItemSummary:       "販促カード 1,000枚",
						DeliveryTarget:    "3月25日 納品済み",
						LastUpdated:       now.Add(-58 * 24 * time.Hour),
					},
				},
				Addresses: []Address{
					{
						ID:         "addr_takumi_shop",
						Label:      "工房",
						Name:       "高橋 健",
						Company:    c.Company,
						Phone:      "06-2222-3333",
						Lines:      []string{"大阪府堺市北区木町 2-5-1"},
						City:       "堺市",
						Prefecture: "大阪府",
						PostalCode: "591-8002",
						Country:    "日本",
						Type:       "shipping",
						Primary:    true,
						UpdatedAt:  now.Add(-120 * 24 * time.Hour),
					},
				},
				PaymentMethods: []PaymentMethod{
					{
						ID:         "pm_card_mc",
						Type:       "card",
						Brand:      "Mastercard",
						Last4:      "7788",
						ExpMonth:   11,
						ExpYear:    now.AddDate(2, 0, 0).Year(),
						HolderName: "TAKUMI CRAFT WORKS",
						Status:     "有効",
						StatusTone: "success",
						Primary:    true,
						AddedAt:    now.AddDate(-1, 0, 0),
					},
				},
				SupportNotes: []SupportNote{
					{
						ID:         "note_upsell",
						Title:      "大型什器案件の見積もり進行",
						Body:       "6月の展示会向け。月末までに初回提案を送付予定。",
						CreatedAt:  now.Add(-10 * 24 * time.Hour),
						Author:     "森下 (営業)",
						AuthorRole: "アカウントエグゼクティブ",
						Tone:       "info",
						Visibility: "internal",
						Tags:       []string{"アップセル"},
					},
				},
				Activity: []ActivityItem{
					{
						ID:          "act_invoice_reminder",
						Timestamp:   now.Add(-2 * 24 * time.Hour),
						Actor:       "請求チーム",
						ActorRole:   "バックオフィス",
						Title:       "請求書送付",
						Description: "注文 #HF-240428-0998 の請求書 (支払い期限 5/20) を送付。",
						Tone:        "info",
						Icon:        "📨",
					},
				},
				InfoRail: InfoRail{
					RiskLevel:       c.RiskLevel,
					RiskTone:        "warning",
					RiskDescription: "支払い遅延はないが大型案件で与信要確認。",
					Segments:        []string{"B2B", "アップセル候補"},
					Flags:           append([]Flag(nil), c.Flags...),
					FraudChecks: []RailItem{
						{
							ID:          "fraud_basic",
							Label:       "KYC 済み (代表者免許証)",
							Description: "2023/11/01 実施",
							Tone:        "success",
						},
					},
				},
				LastUpdated: now,
			}
		default:
			details[c.ID] = detailFromCustomer(c, now)
		}
	}
	return details
}

func detailFromCustomer(c Customer, now time.Time) Detail {
	quickActions := []QuickAction{
		{Label: "メールを送信", Href: "mailto:" + c.Email, Variant: "secondary", Icon: "✉"},
	}
	if c.Status != StatusDeactivated {
		quickActions = append(quickActions, QuickAction{Label: "退会＋マスク", Href: "/admin/customers/" + c.ID + "/modal/deactivate-mask", Variant: "danger", Icon: "🛡️", Method: "modal"})
	}

	profile := Profile{
		ID:                 c.ID,
		DisplayName:        c.DisplayName,
		Email:              c.Email,
		Phone:              "",
		AvatarURL:          c.AvatarURL,
		Company:            c.Company,
		Location:           c.Location,
		Tier:               c.Tier,
		Status:             c.Status,
		TotalOrders:        c.TotalOrders,
		LifetimeValueMinor: c.LifetimeValueMinor,
		Currency:           c.Currency,
		LastOrderAt:        c.LastOrderAt,
		LastOrderNumber:    c.LastOrderNumber,
		LastOrderID:        c.LastOrderID,
		JoinedAt:           c.JoinedAt,
		RiskLevel:          c.RiskLevel,
		Flags:              append([]Flag(nil), c.Flags...),
		Tags:               append([]string(nil), c.Tags...),
		QuickActions:       quickActions,
	}

	defaultCurrency := c.Currency
	if defaultCurrency == "" {
		defaultCurrency = "JPY"
	}

	metrics := []Metric{
		{Key: "orders", Label: "累計注文", Value: fmt.Sprintf("%d件", c.TotalOrders), SubLabel: "", Tone: "info"},
		{Key: "ltv", Label: "累計売上", Value: formatCurrency(c.LifetimeValueMinor, defaultCurrency), SubLabel: "", Tone: "info"},
	}

	addresses := []Address{
		{
			ID:         c.ID + "_primary_address",
			Label:      "登録住所",
			Name:       c.DisplayName,
			Company:    c.Company,
			Phone:      "",
			Lines:      []string{strings.TrimSpace(c.Location)},
			City:       "",
			Prefecture: "",
			PostalCode: "",
			Country:    "日本",
			Type:       "shipping",
			Primary:    true,
			UpdatedAt:  now.Add(-48 * time.Hour),
		},
	}

	return Detail{
		Profile:        profile,
		Metrics:        metrics,
		RecentOrders:   nil,
		Addresses:      addresses,
		PaymentMethods: nil,
		SupportNotes:   nil,
		Activity:       nil,
		InfoRail: InfoRail{
			RiskLevel:       c.RiskLevel,
			RiskTone:        riskToneValue(c.RiskLevel),
			RiskDescription: "詳細情報は登録されていません。",
			Flags:           append([]Flag(nil), c.Flags...),
		},
		LastUpdated: now,
	}
}

// DeactivateModal returns a canned deactivate + mask modal dataset.
func (s *StaticService) DeactivateModal(_ context.Context, _ string, customerID string) (DeactivateModal, error) {
	detail, ok := s.Details[customerID]
	if !ok {
		return DeactivateModal{}, ErrCustomerNotFound
	}

	profile := detail.Profile
	phrase := confirmationPhrase(profile.ID)
	impacts := []DeactivateImpact{
		{
			Title:       "サインイン権限を即時停止",
			Description: "顧客は以後、アプリやウェブからログインできなくなります。",
			Icon:        "🚫",
			Tone:        "danger",
		},
		{
			Title:       "個人情報を匿名化",
			Description: "氏名・メール・電話番号などのPIIをマスクし、通知も停止します。",
			Icon:        "🛡️",
			Tone:        "warning",
		},
		{
			Title:       "注文・請求データは保持",
			Description: "会計・レポート用途のため、注文履歴と請求記録は削除されません。",
			Icon:        "📦",
			Tone:        "info",
		},
	}

	return DeactivateModal{
		CustomerID:         profile.ID,
		DisplayName:        profile.DisplayName,
		Email:              profile.Email,
		Status:             profile.Status,
		TotalOrders:        profile.TotalOrders,
		LifetimeValueMinor: profile.LifetimeValueMinor,
		Currency:           profile.Currency,
		LastOrderNumber:    profile.LastOrderNumber,
		LastOrderAt:        profile.LastOrderAt,
		ConfirmationPhrase: phrase,
		Impacts:            impacts,
	}, nil
}

// DeactivateAndMask updates the in-memory dataset to simulate a deactivate + mask request.
func (s *StaticService) DeactivateAndMask(_ context.Context, _ string, customerID string, req DeactivateAndMaskRequest) (DeactivateAndMaskResult, error) {
	detail, ok := s.Details[customerID]
	if !ok {
		return DeactivateAndMaskResult{}, ErrCustomerNotFound
	}

	expected := confirmationPhrase(customerID)
	if !strings.EqualFold(strings.TrimSpace(req.Confirmation), expected) {
		return DeactivateAndMaskResult{}, ErrInvalidConfirmation
	}

	if detail.Profile.Status == StatusDeactivated {
		return DeactivateAndMaskResult{}, ErrAlreadyDeactivated
	}

	now := time.Now().UTC()

	actorEmail := strings.TrimSpace(req.ActorEmail)
	if actorEmail == "" {
		actorEmail = "system@example.com"
	}
	actorID := strings.TrimSpace(req.ActorID)
	if actorID == "" {
		actorID = "system"
	}

	reason := strings.TrimSpace(req.Reason)

	detail.Profile.Status = StatusDeactivated
	detail.Profile.DisplayName = "マスク済み顧客"
	detail.Profile.Email = fmt.Sprintf("masked+%s@hanko-field.invalid", customerID)
	detail.Profile.Phone = ""
	detail.Profile.AvatarURL = ""
	detail.Profile.QuickActions = []QuickAction{
		{Label: "監査ログを開く", Href: fmt.Sprintf("/admin/audit-logs?targetRef=user:%s", customerID), Variant: "ghost", Icon: "📜"},
	}
	if !contains(detail.Profile.Tags, "masked") {
		detail.Profile.Tags = append(detail.Profile.Tags, "masked")
	}
	maskFlag := Flag{Label: "マスク済み", Tone: "warning", Icon: "🛡️", Description: "PIIを匿名化済み"}
	if !flagExists(detail.Profile.Flags, maskFlag.Label) {
		detail.Profile.Flags = append(detail.Profile.Flags, maskFlag)
	}

	detail.InfoRail.RiskLevel = "low"
	detail.InfoRail.RiskTone = "muted"
	detail.InfoRail.RiskDescription = "アカウントは退会・マスク済みです。"
	if !flagExists(detail.InfoRail.Flags, maskFlag.Label) {
		detail.InfoRail.Flags = append(detail.InfoRail.Flags, maskFlag)
	}

	detail.LastUpdated = now

	event := ActivityItem{
		ID:          fmt.Sprintf("activity_%s", now.Format("20060102T150405")),
		Timestamp:   now,
		Actor:       actorEmail,
		ActorRole:   "管理者",
		Title:       "アカウントを無効化・マスク",
		Description: fallbackActivityDescription(reason),
		Tone:        "danger",
		Icon:        "🛡️",
	}
	detail.Activity = append([]ActivityItem{event}, detail.Activity...)

	for idx := range s.Customers {
		if s.Customers[idx].ID == customerID {
			s.Customers[idx].Status = StatusDeactivated
			s.Customers[idx].Email = detail.Profile.Email
			s.Customers[idx].DisplayName = detail.Profile.DisplayName
			if !flagExists(s.Customers[idx].Flags, maskFlag.Label) {
				s.Customers[idx].Flags = append(s.Customers[idx].Flags, maskFlag)
			}
			break
		}
	}

	audit := AuditRecord{
		ID:         fmt.Sprintf("audit_%s", now.Format("20060102T150405")),
		Action:     "customers.deactivate_mask",
		Message:    "顧客アカウントを無効化し、PIIをマスクしました。",
		Timestamp:  now,
		ActorID:    actorID,
		ActorEmail: actorEmail,
		Metadata:   map[string]string{},
	}
	if reason != "" {
		audit.Metadata["reason"] = reason
	}
	audit.Metadata["customerID"] = customerID

	s.AuditLog[customerID] = append([]AuditRecord{audit}, s.AuditLog[customerID]...)

	s.Details[customerID] = detail

	return DeactivateAndMaskResult{
		Detail: detail,
		Audit:  audit,
	}, nil
}

func confirmationPhrase(customerID string) string {
	id := strings.TrimSpace(customerID)
	if id == "" {
		return "DEACTIVATE"
	}
	return fmt.Sprintf("DEACTIVATE %s", strings.ToUpper(id))
}

func contains(list []string, value string) bool {
	for _, item := range list {
		if strings.EqualFold(strings.TrimSpace(item), strings.TrimSpace(value)) {
			return true
		}
	}
	return false
}

func flagExists(flags []Flag, label string) bool {
	for _, flag := range flags {
		if strings.EqualFold(strings.TrimSpace(flag.Label), strings.TrimSpace(label)) {
			return true
		}
	}
	return false
}

func fallbackActivityDescription(reason string) string {
	if strings.TrimSpace(reason) == "" {
		return "管理コンソールから退会＋マスク処理を実行しました。"
	}
	return reason
}

func formatCurrency(amount int64, currency string) string {
	code := strings.ToUpper(strings.TrimSpace(currency))
	if code == "" {
		code = "JPY"
	}
	symbol := code + " "
	switch code {
	case "JPY":
		symbol = "¥"
	case "USD":
		symbol = "$"
	case "EUR":
		symbol = "€"
	}

	sign := ""
	if amount < 0 {
		sign = "-"
		amount = -amount
	}

    // Values are stored in minor units. JPY is zero-decimal for display.
    major := amount / 100
    if code == "JPY" {
        return fmt.Sprintf("%s%s%d", sign, symbol, major)
    }
    minor := amount % 100
    return fmt.Sprintf("%s%s%d.%02d", sign, symbol, major, minor)
}

func riskToneValue(level string) string {
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "high":
		return "danger"
	case "medium":
		return "warning"
	case "low":
		return "success"
	default:
		return "muted"
	}
}

// Detail implements Service.
func (s *StaticService) Detail(_ context.Context, _ string, customerID string) (Detail, error) {
	if s.Customers == nil {
		s.Customers = []Customer{}
	}
	if s.Details == nil {
		s.Details = buildStaticDetails(s.Customers, time.Now())
	}
	if detail, ok := s.Details[customerID]; ok {
		return detail, nil
	}
	for _, c := range s.Customers {
		if c.ID == customerID {
			detail := detailFromCustomer(c, time.Now())
			s.Details[customerID] = detail
			return detail, nil
		}
	}
	return Detail{}, ErrCustomerNotFound
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
