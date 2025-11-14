package reviews

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"
)

// StaticService provides canned review data for local development and previews.
type StaticService struct {
	reviews     []Review
	generatedAt time.Time
}

// NewStaticService seeds a StaticService with representative queue data.
func NewStaticService() *StaticService {
	now := time.Now()

	makeAttachment := func(id, url, thumb, kind, label string) Attachment {
		return Attachment{
			ID:       id,
			URL:      url,
			ThumbURL: thumb,
			Kind:     kind,
			Label:    label,
		}
	}

	makeFlag := func(flagType, label, tone, description, actor string, ago time.Duration) Flag {
		return Flag{
			Type:        flagType,
			Label:       label,
			Tone:        tone,
			Description: description,
			Actor:       actor,
			CreatedAt:   now.Add(-ago),
		}
	}

	makeModeration := func(status ModerationStatus, label, tone string, escalated bool, notes, actor string, ago time.Duration, history []ModerationEvent) Moderation {
		return Moderation{
			Status:        status,
			StatusLabel:   label,
			StatusTone:    tone,
			Escalated:     escalated,
			Notes:         notes,
			LastModerator: actor,
			LastActionAt:  now.Add(-ago),
			History:       history,
		}
	}

	makeHistory := func(id, action, outcome, reason, tone, actor string, ago time.Duration) ModerationEvent {
		return ModerationEvent{
			ID:        id,
			Action:    action,
			Outcome:   outcome,
			Reason:    reason,
			Tone:      tone,
			Actor:     actor,
			CreatedAt: now.Add(-ago),
		}
	}

	makeCustomer := func(id, name, email, avatar, location, segment string, orders int, lastAgo time.Duration) Customer {
		return Customer{
			ID:         id,
			Name:       name,
			Email:      email,
			AvatarURL:  avatar,
			Location:   location,
			Segment:    segment,
			OrderCount: orders,
			LastOrder:  now.Add(-lastAgo),
		}
	}

	makeProduct := func(id, name, variant, sku, imageURL, detailURL string, price int64, currency string) Product {
		return Product{
			ID:         id,
			Name:       name,
			Variant:    variant,
			SKU:        sku,
			ImageURL:   imageURL,
			DetailURL:  detailURL,
			PriceMinor: price,
			Currency:   currency,
		}
	}

	makeOrder := func(id, number, url string, ago time.Duration, total int64, currency string) Order {
		return Order{
			ID:         id,
			Number:     number,
			URL:        url,
			PlacedAt:   now.Add(-ago),
			TotalMinor: total,
			Currency:   currency,
		}
	}

	reviews := []Review{
		{
			ID:          "rvw-pending-1043",
			Rating:      5,
			Title:       "最高の仕上がりでした",
			Body:        "オンラインでの彫刻指輪のオーダーは初めてでしたが、仕上がりが想像以上でとても満足しています。刻印のフォントも写真通りで美しいです。",
			Locale:      "ja-JP",
			Channel:     "storefront",
			SubmittedAt: now.Add(-6 * time.Hour),
			UpdatedAt:   now.Add(-5 * time.Hour),
			Helpful: HelpfulStats{
				Yes: 4,
				No:  0,
			},
			Reported:    false,
			ReportNotes: "",
			Flags: []Flag{
				makeFlag("ai-language", "AI 判定: 広告表現", "warning", "自動判定で宣伝調の文体と判定しました。確認してください。", "自動チェック", 5*time.Hour+30*time.Minute),
			},
			Attachments: []Attachment{
				makeAttachment("att-1", "/public/static/previews/ring-classic.png", "/public/static/previews/ring-classic-thumb.png", "photo", "商品着用写真"),
				makeAttachment("att-2", "/public/static/previews/ring-box.png", "/public/static/previews/ring-box-thumb.png", "photo", "パッケージ写真"),
			},
			Customer: makeCustomer("cust-208", "山田 真理", "mari.yamada@example.com", "/public/static/avatars/mari.png", "東京都世田谷区", "ロイヤル会員", 6, 8*time.Hour),
			Product:  makeProduct("prod-signet", "シグネットリング", "K18 / イニシャル刻印", "SG-INITIAL-K18", "/public/static/previews/ring-classic.png", "/admin/catalog/products/SG-INITIAL-K18", 580000, "JPY"),
			Order:    makeOrder("order-1043", "1043", "/admin/orders/1043", 32*time.Hour, 672000, "JPY"),
			Moderation: makeModeration(
				ModerationPending,
				"レビュー待ち",
				"warning",
				false,
				"自動判定が宣伝調を指摘。内容確認が必要です。",
				"自動判定システム",
				2*time.Hour,
				[]ModerationEvent{
					makeHistory("hist-1043-1", "auto-screen", "flagged", "AI 判定が広告表現と検知", "warning", "自動判定システム", 2*time.Hour+15*time.Minute),
				},
			),
			Preview: Preview{
				DisplayName: "MARI",
				ProductName: "シグネットリング",
				Headline:    "最高の仕上がりでした",
				Body:        "オンラインでの彫刻指輪のオーダーは初めてでしたが、仕上がりが想像以上でとても満足しています。",
				Rating:      5,
				Photos: []Attachment{
					makeAttachment("att-1", "/public/static/previews/ring-classic.png", "/public/static/previews/ring-classic-thumb.png", "photo", "商品着用写真"),
				},
				SubmittedAt: now.Add(-6 * time.Hour),
			},
		},
		{
			ID:          "rvw-pending-1048",
			Rating:      4,
			Title:       "プレゼントに喜ばれました",
			Body:        "海外在住の友人への贈り物として購入しました。配送が1日遅れたので⭐︎一つ減ですが、サポート対応が丁寧でした。",
			Locale:      "ja-JP",
			Channel:     "storefront",
			SubmittedAt: now.Add(-21 * time.Hour),
			UpdatedAt:   now.Add(-20 * time.Hour),
			Helpful: HelpfulStats{
				Yes: 2,
				No:  1,
			},
			Reported:    true,
			ReportNotes: "配送遅延に関する表現の確認依頼（サポートチーム）",
			Flags: []Flag{
				makeFlag("cs-escalation", "サポートからの確認依頼", "info", "配送遅延に関する表現が正確か確認してください。", "サポートチーム", 18*time.Hour),
				makeFlag("photo-blur", "写真の解像度が低い", "default", "添付写真の画質がぼやけています。", "品質チェック", 17*time.Hour+20*time.Minute),
			},
			Attachments: []Attachment{
				makeAttachment("att-3", "/public/static/previews/ring-classic.png", "/public/static/previews/ring-classic-thumb.png", "photo", "着用写真"),
			},
			Customer: makeCustomer("cust-344", "高橋 真悟", "shingo.takahashi@example.com", "/public/static/avatars/shingo.png", "大阪府吹田市", "ギフト購入", 2, 28*time.Hour),
			Product:  makeProduct("prod-bangle", "ペアバングル", "シルバー / S", "BN-PAIR-001", "/public/static/previews/bangle.png", "/admin/catalog/products/BN-PAIR-001", 320000, "JPY"),
			Order:    makeOrder("order-1048", "1048", "/admin/orders/1048", 50*time.Hour, 353000, "JPY"),
			Moderation: makeModeration(
				ModerationPending,
				"レビュー待ち",
				"warning",
				false,
				"サポートからの確認依頼あり。内容レビューが必要です。",
				"佐藤（CS）",
				3*time.Hour,
				[]ModerationEvent{
					makeHistory("hist-1048-1", "reported", "pending_review", "配送遅延の表現確認", "info", "佐藤（CS）", 18*time.Hour),
				},
			),
			Preview: Preview{
				DisplayName: "SHINGO",
				ProductName: "ペアバングル",
				Headline:    "プレゼントに喜ばれました",
				Body:        "配送が1日遅れたので⭐︎一つ減ですが、サポート対応が丁寧でした。",
				Rating:      4,
				Photos: []Attachment{
					makeAttachment("att-3", "/public/static/previews/bangle.png", "/public/static/previews/bangle.png", "photo", "ペアバングル"),
				},
				SubmittedAt: now.Add(-21 * time.Hour),
			},
		},
		{
			ID:          "rvw-pending-1052",
			Rating:      2,
			Title:       "刻印が想像と違った",
			Body:        "刻印の深さが浅く感じました。写真ではもっとはっきり見えたので、事前に確認できると安心です。",
			Locale:      "ja-JP",
			Channel:     "email",
			SubmittedAt: now.Add(-3 * 24 * time.Hour),
			UpdatedAt:   now.Add(-3*24*time.Hour + 30*time.Minute),
			Helpful: HelpfulStats{
				Yes: 1,
				No:  3,
			},
			Reported:    true,
			ReportNotes: "トーン調整のためレビュー返信推奨（マーケチーム）",
			Flags: []Flag{
				makeFlag("tone-sensitive", "トーン調整推奨", "danger", "ブランドトーンが厳しい表現になっているため調整を検討。", "マーケティング", 48*time.Hour),
				makeFlag("photo-missing", "写真未添付", "default", "仕上がりが見えないため写真依頼を検討。", "品質チェック", 49*time.Hour),
			},
			Customer: makeCustomer("cust-489", "小林 花", "hana.kobayashi@example.com", "/public/static/avatars/hana.png", "愛知県名古屋市", "新規顧客", 1, 72*time.Hour),
			Product:  makeProduct("prod-signet", "カスタムサインネックレス", "ローズゴールド", "SN-ROSE-204", "/public/static/previews/eternity.png", "/admin/catalog/products/SN-ROSE-204", 268000, "JPY"),
			Order:    makeOrder("order-1052", "1052", "/admin/orders/1052", 5*24*time.Hour, 289000, "JPY"),
			Moderation: makeModeration(
				ModerationPending,
				"レビュー待ち",
				"danger",
				true,
				"ブランドトーン調整が必要なためエスカレーション中。",
				"マーケティング",
				6*time.Hour,
				[]ModerationEvent{
					makeHistory("hist-1052-1", "reported", "pending_review", "マーケチームによるトーン確認を追加", "warning", "マーケティング", 48*time.Hour),
					makeHistory("hist-1052-2", "escalated", "pending_review", "ブランド基準確認のためマネージャーにエスカレーション", "danger", "マーケティング", 6*time.Hour),
				},
			),
			Preview: Preview{
				DisplayName: "HANA",
				ProductName: "カスタムサインネックレス",
				Headline:    "刻印が想像と違った",
				Body:        "刻印の深さが浅く感じました。写真ではもっとはっきり見えたので、事前に確認できると安心です。",
				Rating:      2,
				Photos:      nil,
				SubmittedAt: now.Add(-3 * 24 * time.Hour),
			},
		},
		{
			ID:          "rvw-approved-1038",
			Rating:      5,
			Title:       "スタッフの対応が素晴らしい",
			Body:        "制作途中の確認で丁寧に相談に乗ってくれました。完成品も完璧です。",
			Locale:      "ja-JP",
			Channel:     "storefront",
			SubmittedAt: now.Add(-5 * 24 * time.Hour),
			UpdatedAt:   now.Add(-5*24*time.Hour + 10*time.Minute),
			Helpful: HelpfulStats{
				Yes: 6,
				No:  0,
			},
			Customer: makeCustomer("cust-166", "佐々木 美咲", "misaki.sasaki@example.com", "/public/static/avatars/misaki.png", "神奈川県横浜市", "ロイヤル会員", 8, 6*24*time.Hour),
			Product:  makeProduct("prod-engrave", "ハンドエングレーブドリング", "プラチナ", "HG-PLAT-003", "/public/static/previews/eternity.png", "/admin/catalog/products/HG-PLAT-003", 742000, "JPY"),
			Order:    makeOrder("order-1038", "1038", "/admin/orders/1038", 6*24*time.Hour, 785000, "JPY"),
			Moderation: makeModeration(
				ModerationApproved,
				"公開済み",
				"success",
				false,
				"レビューを公開しました。",
				"遠藤（マーケ）",
				4*24*time.Hour,
				[]ModerationEvent{
					makeHistory("hist-1038-1", "approved", "published", "ブランドトーン確認済み", "success", "遠藤（マーケ）", 4*24*time.Hour),
				},
			),
			Replies: []Reply{
				{
					ID:             "reply-1038-1",
					Body:           "素敵なレビューをありがとうございます！制作チームにも共有させていただきます。",
					IsPublic:       true,
					NotifyCustomer: true,
					AuthorName:     "遠藤（マーケ）",
					AuthorEmail:    "marketing@example.com",
					CreatedAt:      now.Add(-4 * 24 * time.Hour),
					LastUpdatedAt:  now.Add(-4 * 24 * time.Hour),
				},
			},
			Preview: Preview{
				DisplayName: "MISAKI",
				ProductName: "ハンドエングレーブドリング",
				Headline:    "スタッフの対応が素晴らしい",
				Body:        "制作途中の確認で丁寧に相談に乗ってくれました。完成品も完璧です。",
				Rating:      5,
				SubmittedAt: now.Add(-5 * 24 * time.Hour),
			},
		},
		{
			ID:          "rvw-rejected-1031",
			Rating:      1,
			Title:       "配送でトラブルがありました",
			Body:        "指定日時に届かず、サポートからも連絡が来ませんでした。最終的に返金になりました。",
			Locale:      "ja-JP",
			Channel:     "storefront",
			SubmittedAt: now.Add(-9 * 24 * time.Hour),
			UpdatedAt:   now.Add(-9*24*time.Hour + 2*time.Hour),
			Helpful: HelpfulStats{
				Yes: 0,
				No:  2,
			},
			Flags: []Flag{
				makeFlag("cs-refund", "返金対応済み", "info", "返金対応済みのためレビューは非公開にしました。", "サポートチーム", 8*24*time.Hour),
			},
			Customer: makeCustomer("cust-201", "井上 誠", "makoto.inoue@example.com", "/public/static/avatars/makoto.png", "北海道札幌市", "休眠顧客", 1, 15*24*time.Hour),
			Product:  makeProduct("prod-pendant", "モノグラムペンダント", "シルバー", "MP-SV-010", "/public/static/previews/monogram.png", "/admin/catalog/products/MP-SV-010", 180000, "JPY"),
			Order:    makeOrder("order-1031", "1031", "/admin/orders/1031", 12*24*time.Hour, 195000, "JPY"),
			Moderation: makeModeration(
				ModerationRejected,
				"非公開",
				"slate",
				false,
				"返金済みのため非公開としました。顧客には個別フォロー済みです。",
				"サポートチーム",
				7*24*time.Hour,
				[]ModerationEvent{
					makeHistory("hist-1031-1", "rejected", "hidden", "返金済みレビュー", "info", "サポートチーム", 7*24*time.Hour),
				},
			),
			Replies: []Reply{
				{
					ID:             "reply-1031-1",
					Body:           "ご不便をおかけし申し訳ありません。サポートより別途ご連絡差し上げます。",
					IsPublic:       false,
					NotifyCustomer: true,
					AuthorName:     "サポートチーム",
					AuthorEmail:    "support@example.com",
					CreatedAt:      now.Add(-6 * 24 * time.Hour),
					LastUpdatedAt:  now.Add(-6 * 24 * time.Hour),
				},
			},
			Preview: Preview{
				DisplayName: "匿名",
				ProductName: "モノグラムペンダント",
				Headline:    "配送でトラブルがありました",
				Body:        "指定日時に届かず、サポートからも連絡が来ませんでした。",
				Rating:      1,
				SubmittedAt: now.Add(-9 * 24 * time.Hour),
			},
		},
	}

	return &StaticService{
		reviews:     reviews,
		generatedAt: now,
	}
}

// List returns reviews filtered according to the provided query.
func (s *StaticService) List(ctx context.Context, token string, query ListQuery) (ListResult, error) {
	all := s.clone()
	summary := summarise(all)

	base := filterByStatus(all, query.Moderation)
	filtered := applyFilters(base, query)
	sortReviews(filtered, query)

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
	if start >= total && total > 0 {
		page = 1
		start = 0
	}
	end := start + pageSize
	if end > total {
		end = total
	}
	pageItems := make([]Review, 0)
	if start < end {
		pageItems = filtered[start:end]
	}

	var nextPage *int
	var prevPage *int
	if end < total {
		n := page + 1
		nextPage = &n
	}
	if start > 0 {
		p := page - 1
		if p < 1 {
			p = 1
		}
		prevPage = &p
	}

	filters := buildFilters(base, query)
	queue := buildQueueMetrics(summary)

	return ListResult{
		Reviews: pageItems,
		Pagination: Pagination{
			Page:       page,
			PageSize:   pageSize,
			TotalItems: total,
			NextPage:   nextPage,
			PrevPage:   prevPage,
		},
		Summary:     summary,
		Filters:     filters,
		Queue:       queue,
		GeneratedAt: s.generatedAt,
	}, nil
}

// ModerationModal loads contextual data for rendering the moderation modal.
func (s *StaticService) ModerationModal(ctx context.Context, _ string, reviewID string, decision ModerationDecision) (ModerationModal, error) {
	review, _ := s.findReview(strings.TrimSpace(reviewID))
	if review == nil {
		return ModerationModal{}, ErrReviewNotFound
	}
	if !isValidDecision(decision) {
		return ModerationModal{}, ErrInvalidDecision
	}

	flags := make([]ModerationFlag, 0, len(review.Flags))
	for _, flag := range review.Flags {
		flags = append(flags, ModerationFlag{
			Label:       firstNonEmpty(flag.Label, flag.Type),
			Description: flag.Description,
			Tone:        flag.Tone,
		})
	}

	return ModerationModal{
		ReviewID:           review.ID,
		Decision:           decision,
		DecisionLabel:      moderationDecisionLabel(decision),
		ReviewTitle:        review.Title,
		ReviewExcerpt:      trimText(review.Body, 220),
		Rating:             review.Rating,
		CustomerName:       review.Customer.Name,
		CustomerEmail:      review.Customer.Email,
		CurrentStatus:      review.Moderation.Status,
		CurrentStatusLabel: review.Moderation.StatusLabel,
		CurrentStatusTone:  review.Moderation.StatusTone,
		ExistingNotes:      review.Moderation.Notes,
		Escalated:          review.Moderation.Escalated,
		Flags:              flags,
	}, nil
}

// Moderate applies a decision and returns the updated review.
func (s *StaticService) Moderate(ctx context.Context, _ string, reviewID string, req ModerationRequest) (ModerationResult, error) {
	if !isValidDecision(req.Decision) {
		return ModerationResult{}, ErrInvalidDecision
	}
	review, idx := s.findReview(strings.TrimSpace(reviewID))
	if review == nil {
		return ModerationResult{}, ErrReviewNotFound
	}

	now := time.Now()
	notes := strings.TrimSpace(req.Notes)
	actor := actorLabel(req.ActorName, req.ActorEmail)
	status := ModerationApproved
	if req.Decision == ModerationDecisionReject {
		status = ModerationRejected
	}
	statusLabel, statusTone := moderationStatusPresentation(status)
	event := ModerationEvent{
		ID:        fmt.Sprintf("hist-%s-%d", review.ID, now.UnixNano()),
		Action:    string(req.Decision),
		Outcome:   moderationOutcome(req.Decision),
		Reason:    notes,
		Actor:     actor,
		Tone:      moderationEventTone(req.Decision),
		CreatedAt: now,
	}
	if req.NotifyCustomer {
		if event.Reason != "" {
			event.Reason += " / "
		}
		event.Reason += "顧客に通知しました"
	}

	review.Moderation.Status = status
	review.Moderation.StatusLabel = statusLabel
	review.Moderation.StatusTone = statusTone
	review.Moderation.Notes = notes
	review.Moderation.LastModerator = actor
	review.Moderation.LastActionAt = now
	review.Moderation.Escalated = false
	review.Moderation.History = append([]ModerationEvent{event}, review.Moderation.History...)
	if req.Decision == ModerationDecisionApprove {
		review.Reported = false
	}

	updated := *review
	s.reviews[idx] = updated
	s.generatedAt = now

	return ModerationResult{Review: updated}, nil
}

// ReplyModal returns context for storing a storefront reply.
func (s *StaticService) ReplyModal(ctx context.Context, _ string, reviewID string) (ReplyModal, error) {
	review, _ := s.findReview(strings.TrimSpace(reviewID))
	if review == nil {
		return ReplyModal{}, ErrReviewNotFound
	}
	var existing *Reply
	if len(review.Replies) > 0 {
		cp := review.Replies[0]
		existing = &cp
	}
	return ReplyModal{
		ReviewID:      review.ID,
		ReviewTitle:   review.Title,
		CustomerName:  review.Customer.Name,
		CustomerEmail: review.Customer.Email,
		Rating:        review.Rating,
		ExistingReply: existing,
	}, nil
}

// StoreReply records a reply and returns the updated review.
func (s *StaticService) StoreReply(ctx context.Context, _ string, reviewID string, req ReplyRequest) (ReplyResult, error) {
	body := strings.TrimSpace(req.Body)
	if body == "" {
		return ReplyResult{}, ErrEmptyReplyBody
	}
	review, idx := s.findReview(strings.TrimSpace(reviewID))
	if review == nil {
		return ReplyResult{}, ErrReviewNotFound
	}

	now := time.Now()
	actor := actorLabel(req.ActorName, req.ActorEmail)
	reply := Reply{
		ID:             fmt.Sprintf("reply-%s-%d", review.ID, now.UnixNano()),
		Body:           body,
		IsPublic:       req.IsPublic,
		NotifyCustomer: req.NotifyCustomer,
		AuthorName:     actor,
		AuthorEmail:    req.ActorEmail,
		CreatedAt:      now,
		LastUpdatedAt:  now,
	}
	review.Replies = append([]Reply{reply}, review.Replies...)

	event := ModerationEvent{
		ID:        fmt.Sprintf("reply-%s-%d", review.ID, now.UnixNano()),
		Action:    "reply",
		Outcome:   replyOutcome(req.IsPublic),
		Reason:    body,
		Actor:     actor,
		Tone:      "info",
		CreatedAt: now,
	}
	if req.NotifyCustomer {
		event.Reason += " / 顧客へ通知"
	}

	review.Moderation.History = append([]ModerationEvent{event}, review.Moderation.History...)
	review.Moderation.LastModerator = actor
	review.Moderation.LastActionAt = now
	if strings.TrimSpace(review.Moderation.Notes) == "" {
		review.Moderation.Notes = "返信を登録しました。"
	}

	updated := *review
	s.reviews[idx] = updated
	s.generatedAt = now

	return ReplyResult{Review: updated, Reply: reply}, nil
}

func (s *StaticService) clone() []Review {
	if len(s.reviews) == 0 {
		return []Review{}
	}
	list := make([]Review, len(s.reviews))
	copy(list, s.reviews)
	return list
}

func summarise(list []Review) Summary {
	var pending, approved, rejected, flagged, escalated int
	totalRating := 0
	count := 0
	for _, r := range list {
		switch r.Moderation.Status {
		case ModerationPending:
			pending++
		case ModerationApproved:
			approved++
		case ModerationRejected:
			rejected++
		}
		if len(r.Flags) > 0 {
			flagged++
		}
		if r.Moderation.Escalated {
			escalated++
		}
		totalRating += r.Rating
		count++
	}
	avg := 0.0
	if count > 0 {
		avg = float64(totalRating) / float64(count)
	}
	return Summary{
		PendingCount:   pending,
		ApprovedCount:  approved,
		RejectedCount:  rejected,
		FlaggedCount:   flagged,
		EscalatedCount: escalated,
		AverageRating:  avg,
	}
}

func buildQueueMetrics(summary Summary) QueueMetrics {
	slaSeconds := 35 * 60
	if summary.EscalatedCount > 0 {
		slaSeconds = 20 * 60
	}
	return QueueMetrics{
		ProcessedToday:      12,
		ProcessedThisWeek:   58,
		BacklogPending:      summary.PendingCount,
		BacklogFlagged:      summary.FlaggedCount,
		SLASecondsRemaining: slaSeconds,
		NextSLABreach:       time.Now().Add(time.Duration(slaSeconds) * time.Second),
	}
}

func filterByStatus(list []Review, statuses []ModerationStatus) []Review {
	if len(statuses) == 0 {
		return list
	}
	set := make(map[ModerationStatus]struct{}, len(statuses))
	for _, status := range statuses {
		set[status] = struct{}{}
	}
	out := make([]Review, 0, len(list))
	for _, r := range list {
		if _, ok := set[r.Moderation.Status]; ok {
			out = append(out, r)
		}
	}
	return out
}

func applyFilters(list []Review, query ListQuery) []Review {
	ratingSet := toIntSet(query.Ratings)
	productSet := toStringSet(query.ProductIDs)
	flagSet := toStringSet(query.FlagTypes)
	channelSet := toStringSet(query.Channels)
	search := strings.ToLower(strings.TrimSpace(query.Search))

	var ageBefore time.Time
	if query.AgeBucket != "" {
		switch strings.ToLower(query.AgeBucket) {
		case "24h":
			ageBefore = time.Now().Add(-24 * time.Hour)
		case "3d":
			ageBefore = time.Now().Add(-72 * time.Hour)
		case "7d":
			ageBefore = time.Now().Add(-7 * 24 * time.Hour)
		case "30d":
			ageBefore = time.Now().Add(-30 * 24 * time.Hour)
		}
	}

	result := make([]Review, 0, len(list))
	for _, r := range list {
		if len(ratingSet) > 0 && !ratingSet[r.Rating] {
			continue
		}
		if len(productSet) > 0 && !productSet[r.Product.ID] {
			continue
		}
		if len(flagSet) > 0 && !hasFlag(r.Flags, flagSet) {
			continue
		}
		if len(channelSet) > 0 && !channelSet[r.Channel] {
			continue
		}
		if !ageBefore.IsZero() && r.SubmittedAt.Before(ageBefore) {
			continue
		}
		if search != "" && !matchesSearch(r, search) {
			continue
		}
		result = append(result, r)
	}
	return result
}

func sortReviews(list []Review, query ListQuery) {
	key := query.SortKey
	if key == "" {
		key = SortSubmittedAt
	}
	dir := query.SortDirection
	if dir == "" {
		dir = SortDirectionDesc
	}

	sort.SliceStable(list, func(i, j int) bool {
		switch key {
		case SortRating:
			if list[i].Rating == list[j].Rating {
				return list[i].SubmittedAt.After(list[j].SubmittedAt)
			}
			if dir == SortDirectionAsc {
				return list[i].Rating < list[j].Rating
			}
			return list[i].Rating > list[j].Rating
		default:
			if dir == SortDirectionAsc {
				return list[i].SubmittedAt.Before(list[j].SubmittedAt)
			}
			return list[i].SubmittedAt.After(list[j].SubmittedAt)
		}
	})
}

func buildFilters(list []Review, query ListQuery) FilterSummary {
	ratingCounts := map[int]int{}
	productCounts := map[string]int{}
	productLabels := map[string]Product{}
	flagCounts := map[string]int{}
	flagMeta := map[string]Flag{}
	channelCounts := map[string]int{}

	for _, r := range list {
		ratingCounts[r.Rating]++
		productCounts[r.Product.ID]++
		if _, ok := productLabels[r.Product.ID]; !ok {
			productLabels[r.Product.ID] = r.Product
		}
		channelCounts[r.Channel]++
		for _, f := range r.Flags {
			flagCounts[f.Type]++
			if _, ok := flagMeta[f.Type]; !ok {
				flagMeta[f.Type] = f
			}
		}
	}

	ratings := make([]RatingOption, 0, 5)
	for rating := 5; rating >= 1; rating-- {
		ratings = append(ratings, RatingOption{
			Value:  rating,
			Label:  fmt.Sprintf("%d ★", rating),
			Count:  ratingCounts[rating],
			Active: containsInt(query.Ratings, rating),
		})
	}

	products := make([]ProductOption, 0, len(productCounts))
	for id, count := range productCounts {
		label := id
		sku := ""
		if product, ok := productLabels[id]; ok {
			if product.Variant != "" {
				label = fmt.Sprintf("%s（%s）", product.Name, product.Variant)
			} else {
				label = product.Name
			}
			sku = product.SKU
		}
		products = append(products, ProductOption{
			ID:     id,
			Label:  label,
			SKU:    sku,
			Count:  count,
			Active: containsString(query.ProductIDs, id),
		})
	}
	sort.Slice(products, func(i, j int) bool {
		return products[i].Label < products[j].Label
	})

	flags := make([]FlagOption, 0, len(flagCounts))
	for key, count := range flagCounts {
		meta := flagMeta[key]
		label := meta.Label
		if label == "" {
			label = key
		}
		flags = append(flags, FlagOption{
			Value:       key,
			Label:       label,
			Description: meta.Description,
			Tone:        meta.Tone,
			Count:       count,
			Active:      containsString(query.FlagTypes, key),
		})
	}
	sort.Slice(flags, func(i, j int) bool {
		return flags[i].Label < flags[j].Label
	})

	channels := make([]ChannelOption, 0, len(channelCounts))
	for key, count := range channelCounts {
		label := channelLabel(key)
		channels = append(channels, ChannelOption{
			Value:  key,
			Label:  label,
			Count:  count,
			Active: containsString(query.Channels, key),
		})
	}
	sort.Slice(channels, func(i, j int) bool {
		return channels[i].Label < channels[j].Label
	})

	ageOptions := []AgeBucketOption{
		{Value: "24h", Label: "24時間以内", Active: strings.EqualFold(query.AgeBucket, "24h")},
		{Value: "3d", Label: "過去3日", Active: strings.EqualFold(query.AgeBucket, "3d")},
		{Value: "7d", Label: "過去1週間", Active: strings.EqualFold(query.AgeBucket, "7d")},
		{Value: "30d", Label: "過去30日", Active: strings.EqualFold(query.AgeBucket, "30d")},
	}

	return FilterSummary{
		Ratings:    ratings,
		Products:   products,
		Flags:      flags,
		Channels:   channels,
		AgeBuckets: ageOptions,
	}
}

func matchesSearch(review Review, search string) bool {
	if search == "" {
		return true
	}
	fields := []string{
		review.Title,
		review.Body,
		review.Customer.Name,
		review.Order.Number,
		review.Product.Name,
		review.Product.SKU,
	}
	for _, field := range fields {
		if strings.Contains(strings.ToLower(field), search) {
			return true
		}
	}
	return false
}

func channelLabel(value string) string {
	switch value {
	case "storefront":
		return "ストア"
	case "email":
		return "メール"
	case "in_store":
		return "店舗"
	default:
		return value
	}
}

func hasFlag(flags []Flag, allowed map[string]bool) bool {
	for _, flag := range flags {
		if allowed[flag.Type] {
			return true
		}
	}
	return false
}

func toIntSet(values []int) map[int]bool {
	if len(values) == 0 {
		return nil
	}
	set := make(map[int]bool, len(values))
	for _, v := range values {
		set[v] = true
	}
	return set
}

func toStringSet(values []string) map[string]bool {
	if len(values) == 0 {
		return nil
	}
	set := make(map[string]bool, len(values))
	for _, v := range values {
		val := strings.TrimSpace(v)
		if val == "" {
			continue
		}
		set[val] = true
	}
	return set
}

func containsInt(list []int, value int) bool {
	for _, v := range list {
		if v == value {
			return true
		}
	}
	return false
}

func containsString(list []string, value string) bool {
	for _, v := range list {
		if strings.EqualFold(strings.TrimSpace(v), strings.TrimSpace(value)) {
			return true
		}
	}
	return false
}

func (s *StaticService) findReview(id string) (*Review, int) {
	for idx := range s.reviews {
		if strings.EqualFold(strings.TrimSpace(s.reviews[idx].ID), strings.TrimSpace(id)) {
			return &s.reviews[idx], idx
		}
	}
	return nil, -1
}

func isValidDecision(decision ModerationDecision) bool {
	switch decision {
	case ModerationDecisionApprove, ModerationDecisionReject:
		return true
	default:
		return false
	}
}

func moderationDecisionLabel(decision ModerationDecision) string {
	switch decision {
	case ModerationDecisionApprove:
		return "承認して公開"
	case ModerationDecisionReject:
		return "却下 / 修正依頼"
	default:
		return "モデレーション"
	}
}

func moderationStatusPresentation(status ModerationStatus) (string, string) {
	switch status {
	case ModerationApproved:
		return "公開済み", "success"
	case ModerationRejected:
		return "非公開", "slate"
	default:
		return "レビュー待ち", "warning"
	}
}

func moderationOutcome(decision ModerationDecision) string {
	switch decision {
	case ModerationDecisionApprove:
		return "published"
	case ModerationDecisionReject:
		return "hidden"
	default:
		return "pending"
	}
}

func moderationEventTone(decision ModerationDecision) string {
	switch decision {
	case ModerationDecisionApprove:
		return "success"
	case ModerationDecisionReject:
		return "warning"
	default:
		return "info"
	}
}

func replyOutcome(isPublic bool) string {
	if isPublic {
		return "public_reply"
	}
	return "private_reply"
}

func actorLabel(name, email string) string {
	if strings.TrimSpace(name) != "" {
		return strings.TrimSpace(name)
	}
	if strings.TrimSpace(email) != "" {
		return strings.TrimSpace(email)
	}
	return "スタッフ"
}

func trimText(text string, limit int) string {
	text = strings.TrimSpace(text)
	if limit <= 0 || len([]rune(text)) <= limit {
		return text
	}
	runes := []rune(text)
	return string(runes[:limit]) + "…"
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}
