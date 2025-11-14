package payments

import (
	"context"
	"sort"
	"strings"
	"sync"
	"time"
)

// StaticService provides deterministic data for local development and tests.
type StaticService struct {
	mu           sync.RWMutex
	transactions []Transaction
	details      map[string]TransactionDetail
}

// NewStaticService constructs a StaticService with fixture data.
func NewStaticService() *StaticService {
	now := time.Now().Truncate(time.Minute)
	makeTimestamp := func(daysAgo, hoursAgo int) time.Time {
		return now.AddDate(0, 0, -daysAgo).Add(-time.Duration(hoursAgo) * time.Hour)
	}

	stripeCapture := makeTimestamp(0, 2)
	stripeSettle := makeTimestamp(0, 1)
	squareCapture := makeTimestamp(1, 4)
	airpayCapture := makeTimestamp(2, 8)
	zeusCapture := makeTimestamp(5, 6)
	refundCapture := makeTimestamp(3, 3)
	disputeCapture := makeTimestamp(4, 5)

	transactions := []Transaction{
		{
			ID:                "txn_1KJ7S01",
			PSPReference:      "pi_3NZPAA9lM8sd",
			Provider:          ProviderStripe,
			ProviderLabel:     "Stripe",
			ProviderIcon:      "🟦",
			Status:            StatusSettled,
			StatusLabel:       "入金済み",
			StatusTone:        "success",
			OrderID:           "order-20482",
			OrderNumber:       "#20482",
			CustomerName:      "髙橋 真理子",
			AmountMinor:       498000,
			Currency:          "JPY",
			FeeMinor:          14940,
			NetMinor:          483060,
			CapturedAt:        stripeCapture,
			SettledAt:         &stripeSettle,
			RiskFlag:          false,
			RiskLabel:         "",
			PayoutBatchID:     "payout-20240415-1",
			PayoutScheduledAt: &stripeSettle,
			Installments:      "一括",
			PaymentMethod:     "VISA •••• 4212",
			AuthID:            "auth_3NZPAA9lM8sd",
			Channel:           "web",
			OrderURL:          "/admin/orders/order-20482",
			PSPDashboardURL:   "https://dashboard.stripe.com/payments/pi_3NZPAA9lM8sd",
		},
		{
			ID:              "txn_1SQ0189",
			PSPReference:    "sq0idp-h6vFmq",
			Provider:        ProviderSquare,
			ProviderLabel:   "Square",
			ProviderIcon:    "🟥",
			Status:          StatusCaptured,
			StatusLabel:     "確定済み",
			StatusTone:      "info",
			OrderID:         "order-20431",
			OrderNumber:     "#20431",
			CustomerName:    "横浜 太郎",
			AmountMinor:     328000,
			Currency:        "JPY",
			FeeMinor:        9840,
			NetMinor:        318160,
			CapturedAt:      squareCapture,
			SettledAt:       nil,
			RiskFlag:        true,
			RiskLabel:       "チャージバックリスク",
			RiskTone:        "warning",
			PayoutBatchID:   "payout-20240414-0",
			Installments:    "3回分割",
			PaymentMethod:   "Mastercard •••• 2240",
			AuthID:          "auth_sq_001843",
			Channel:         "store",
			OrderURL:        "/admin/orders/order-20431",
			PSPDashboardURL: "https://squareup.com/dashboard/sales/transactions/sq0idp-h6vFmq",
		},
		{
			ID:              "txn_1AIR672",
			PSPReference:    "airpay-0823-ffff",
			Provider:        ProviderAirpay,
			ProviderLabel:   "AirPay",
			ProviderIcon:    "🟢",
			Status:          StatusFailed,
			StatusLabel:     "失敗",
			StatusTone:      "danger",
			OrderID:         "order-20388",
			OrderNumber:     "#20388",
			CustomerName:    "中島 佳子",
			AmountMinor:     188000,
			Currency:        "JPY",
			FeeMinor:        0,
			NetMinor:        0,
			CapturedAt:      airpayCapture,
			RiskFlag:        false,
			RiskLabel:       "",
			PayoutBatchID:   "",
			PaymentMethod:   "JCB •••• 9191",
			AuthID:          "auth_airpay_0823",
			Channel:         "web",
			OrderURL:        "/admin/orders/order-20388",
			PSPDashboardURL: "https://airpay-gmo.jp/admin/transactions/airpay-0823-ffff",
		},
		{
			ID:              "txn_1ZEUS004",
			PSPReference:    "zeus-2048-ix",
			Provider:        ProviderZeus,
			ProviderLabel:   "ZEUS",
			ProviderIcon:    "🟪",
			Status:          StatusRefunded,
			StatusLabel:     "返金済み",
			StatusTone:      "warning",
			OrderID:         "order-20291",
			OrderNumber:     "#20291",
			CustomerName:    "倉田 美緒",
			AmountMinor:     127500,
			Currency:        "JPY",
			FeeMinor:        3825,
			NetMinor:        123675,
			CapturedAt:      refundCapture,
			SettledAt:       nil,
			RiskFlag:        true,
			RiskLabel:       "要再請求",
			RiskTone:        "danger",
			PayoutBatchID:   "payout-20240412-2",
			PaymentMethod:   "銀行振込",
			AuthID:          "auth_zeus_2048",
			Channel:         "customer-support",
			OrderURL:        "/admin/orders/order-20291",
			PSPDashboardURL: "https://www.cardservice.co.jp/mypage/settlement/zeus-2048-ix",
		},
		{
			ID:              "txn_1STRIPE92",
			PSPReference:    "pi_3NZPAYdispute",
			Provider:        ProviderStripe,
			ProviderLabel:   "Stripe",
			ProviderIcon:    "🟦",
			Status:          StatusDisputed,
			StatusLabel:     "異議申し立て",
			StatusTone:      "danger",
			OrderID:         "order-20345",
			OrderNumber:     "#20345",
			CustomerName:    "松田 充",
			AmountMinor:     284000,
			Currency:        "JPY",
			FeeMinor:        8520,
			NetMinor:        275480,
			CapturedAt:      disputeCapture,
			SettledAt:       nil,
			RiskFlag:        true,
			RiskLabel:       "チャージバック進行中",
			RiskTone:        "danger",
			PayoutBatchID:   "payout-20240410-0",
			PaymentMethod:   "AMEX •••• 8220",
			Installments:    "一括",
			AuthID:          "auth_3NZPAYdispute",
			Channel:         "web",
			OrderURL:        "/admin/orders/order-20345",
			PSPDashboardURL: "https://dashboard.stripe.com/payments/pi_3NZPAYdispute",
		},
		{
			ID:              "txn_1STRIPE93",
			PSPReference:    "pi_3NZPAYrefund",
			Provider:        ProviderStripe,
			ProviderLabel:   "Stripe",
			ProviderIcon:    "🟦",
			Status:          StatusCaptured,
			StatusLabel:     "確定済み",
			StatusTone:      "info",
			OrderID:         "order-20264",
			OrderNumber:     "#20264",
			CustomerName:    "山本 花",
			AmountMinor:     98600,
			Currency:        "JPY",
			FeeMinor:        2958,
			NetMinor:        95642,
			CapturedAt:      zeusCapture,
			SettledAt:       nil,
			RiskFlag:        false,
			PayoutBatchID:   "payout-20240408-4",
			PaymentMethod:   "Apple Pay",
			Installments:    "一括",
			AuthID:          "auth_3NZPAYrefund",
			Channel:         "app",
			OrderURL:        "/admin/orders/order-20264",
			PSPDashboardURL: "https://dashboard.stripe.com/payments/pi_3NZPAYrefund",
		},
	}

	details := map[string]TransactionDetail{
		"txn_1KJ7S01":   buildStripeSettledDetail(transactions[0]),
		"txn_1SQ0189":   buildSquareFlaggedDetail(transactions[1]),
		"txn_1AIR672":   buildFailureDetail(transactions[2]),
		"txn_1ZEUS004":  buildRefundDetail(transactions[3]),
		"txn_1STRIPE92": buildDisputeDetail(transactions[4]),
		"txn_1STRIPE93": buildStripeCapturedDetail(transactions[5]),
	}

	return &StaticService{
		transactions: transactions,
		details:      details,
	}
}

// ListTransactions returns filtered transactions.
func (s *StaticService) ListTransactions(ctx context.Context, token string, query TransactionsQuery) (TransactionsResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	filtered := make([]Transaction, 0, len(s.transactions))
	for _, tx := range s.transactions {
		if !matchesProvider(tx, query.Providers) {
			continue
		}
		if !matchesStatus(tx, query.Statuses) {
			continue
		}
		if query.OnlyFlagged && !tx.RiskFlag {
			continue
		}
		if query.AmountMinMinor != nil && tx.AmountMinor < *query.AmountMinMinor {
			continue
		}
		if query.AmountMaxMinor != nil && tx.AmountMinor > *query.AmountMaxMinor {
			continue
		}
		if query.CapturedFrom != nil && tx.CapturedAt.Before(*query.CapturedFrom) {
			continue
		}
		if query.CapturedTo != nil && tx.CapturedAt.After(*query.CapturedTo) {
			continue
		}
		filtered = append(filtered, tx)
	}

	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].CapturedAt.After(filtered[j].CapturedAt)
	})

	pageSize := query.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}
	page := query.Page
	if page < 0 {
		page = 0
	}
	start := page * pageSize
	if start > len(filtered) {
		start = len(filtered)
	}
	end := start + pageSize
	if end > len(filtered) {
		end = len(filtered)
	}
	paged := append([]Transaction(nil), filtered[start:end]...)

	var (
		totalGross   int64
		successCount int
		failureCount int
		flaggedCount int
		disputeCount int
	)
	for _, tx := range filtered {
		if tx.Status != StatusFailed {
			totalGross += tx.AmountMinor
			successCount++
		} else {
			failureCount++
		}
		if tx.RiskFlag {
			flaggedCount++
		}
		if tx.Status == StatusDisputed {
			disputeCount++
		}
	}

	avgTicket := int64(0)
	if successCount > 0 {
		avgTicket = totalGross / int64(successCount)
	}

	earliest, latest := amountDateBounds(s.transactions)
	minAmount, maxAmount := amountBounds(s.transactions)

	pagination := Pagination{
		Page:       page,
		PageSize:   pageSize,
		TotalItems: len(filtered),
	}
	if end < len(filtered) {
		next := page + 1
		pagination.NextPage = &next
	}
	if page > 0 {
		prev := page - 1
		pagination.PrevPage = &prev
	}

	result := TransactionsResult{
		Transactions: paged,
		Pagination:   pagination,
		Summary: Summary{
			GrossVolumeMinor:      totalGross,
			GrossVolumeCurrency:   currencyFor(filtered),
			FailureRatePercent:    failureRatePercent(successCount, failureCount),
			FailureRateDelta:      -1.2,
			AverageTicketMinor:    avgTicket,
			AverageTicketCurrency: currencyFor(filtered),
			FlaggedCount:          flaggedCount,
			DisputeOpenCount:      disputeCount,
		},
		Filters: FilterSummary{
			ProviderCounts: providerCounts(s.transactions),
			StatusCounts:   statusCounts(s.transactions),
			FlaggedCount:   flaggedTransactions(s.transactions),
			AmountMinMinor: minAmount,
			AmountMaxMinor: maxAmount,
			EarliestDate:   earliest,
			LatestDate:     latest,
		},
	}

	return result, nil
}

// TransactionDetail returns drawer fixture.
func (s *StaticService) TransactionDetail(ctx context.Context, token, transactionID string) (TransactionDetail, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	detail, ok := s.details[strings.TrimSpace(transactionID)]
	if !ok {
		return TransactionDetail{}, ErrTransactionNotFound
	}
	return cloneDetail(detail), nil
}

func matchesProvider(tx Transaction, providers []Provider) bool {
	if len(providers) == 0 {
		return true
	}
	for _, p := range providers {
		if tx.Provider == p {
			return true
		}
	}
	return false
}

func matchesStatus(tx Transaction, statuses []Status) bool {
	if len(statuses) == 0 {
		return true
	}
	for _, st := range statuses {
		if tx.Status == st {
			return true
		}
	}
	return false
}

func currencyFor(transactions []Transaction) string {
	for _, tx := range transactions {
		if tx.Currency != "" {
			return tx.Currency
		}
	}
	return "JPY"
}

func failureRatePercent(success, failure int) float64 {
	total := success + failure
	if total == 0 {
		return 0
	}
	return float64(failure) / float64(total) * 100
}

func providerCounts(transactions []Transaction) map[Provider]int {
	out := make(map[Provider]int)
	for _, tx := range transactions {
		out[tx.Provider]++
	}
	return out
}

func statusCounts(transactions []Transaction) map[Status]int {
	out := make(map[Status]int)
	for _, tx := range transactions {
		out[tx.Status]++
	}
	return out
}

func flaggedTransactions(transactions []Transaction) int {
	count := 0
	for _, tx := range transactions {
		if tx.RiskFlag {
			count++
		}
	}
	return count
}

func amountBounds(transactions []Transaction) (int64, int64) {
	if len(transactions) == 0 {
		return 0, 0
	}
	min := transactions[0].AmountMinor
	max := transactions[0].AmountMinor
	for _, tx := range transactions[1:] {
		if tx.AmountMinor < min {
			min = tx.AmountMinor
		}
		if tx.AmountMinor > max {
			max = tx.AmountMinor
		}
	}
	return min, max
}

func amountDateBounds(transactions []Transaction) (*time.Time, *time.Time) {
	if len(transactions) == 0 {
		return nil, nil
	}
	earliest := transactions[0].CapturedAt
	latest := transactions[0].CapturedAt
	for _, tx := range transactions[1:] {
		if tx.CapturedAt.Before(earliest) {
			earliest = tx.CapturedAt
		}
		if tx.CapturedAt.After(latest) {
			latest = tx.CapturedAt
		}
	}
	return &earliest, &latest
}

func cloneDetail(detail TransactionDetail) TransactionDetail {
	copyDetail := detail
	copyDetail.Timeline = append([]TimelineEvent(nil), detail.Timeline...)
	copyDetail.Breakdown = append([]BreakdownEntry(nil), detail.Breakdown...)
	copyDetail.Adjustments = append([]Adjustment(nil), detail.Adjustments...)
	copyDetail.Disputes = append([]Dispute(nil), detail.Disputes...)
	copyDetail.Notes = append([]Note(nil), detail.Notes...)
	copyDetail.RawPayload = append([]PayloadField(nil), detail.RawPayload...)
	return copyDetail
}

func buildStripeSettledDetail(tx Transaction) TransactionDetail {
	events := []TimelineEvent{
		{
			Timestamp:   tx.CapturedAt.Add(-2 * time.Minute),
			Label:       "支払い承認",
			Description: "Stripe上でカードが認証されました。",
			Tone:        "info",
			Icon:        "✅",
		},
		{
			Timestamp:   tx.CapturedAt,
			Label:       "売上確定",
			Description: "注文の売上を確定しました。",
			Tone:        "success",
			Icon:        "💳",
		},
	}
	if tx.SettledAt != nil {
		settled := *tx.SettledAt
		events = append(events,
			TimelineEvent{
				Timestamp:   settled.Add(-30 * time.Minute),
				Label:       "振込処理開始",
				Description: "当日分のバッチに含まれました。",
				Tone:        "info",
				Icon:        "🏦",
			},
			TimelineEvent{
				Timestamp:   settled,
				Label:       "入金済み",
				Description: "三井住友銀行 口座 ***224 に着金済み。",
				Tone:        "success",
				Icon:        "💰",
			},
		)
	}

	return TransactionDetail{
		Transaction: tx,
		Timeline:    events,
		Breakdown: []BreakdownEntry{
			{Label: "売上", AmountMinor: tx.AmountMinor, Currency: tx.Currency},
			{Label: "決済手数料", AmountMinor: -tx.FeeMinor, Currency: tx.Currency, Tone: "muted"},
			{Label: "入金予定", AmountMinor: tx.NetMinor, Currency: tx.Currency, Tone: "success"},
		},
		Adjustments: []Adjustment{
			{
				ID:          "adj_capture",
				Type:        "capture",
				Label:       "全額キャプチャ",
				AmountMinor: tx.AmountMinor,
				Currency:    tx.Currency,
				Actor:       "ops.kimura",
				Timestamp:   tx.CapturedAt,
				StatusLabel: "完了",
				StatusTone:  "success",
			},
		},
		Disputes: nil,
		Notes: []Note{
			{
				Author:    "ops.kimura",
				Message:   "配送前にキャプチャするよう変更済み。",
				Timestamp: tx.CapturedAt.Add(10 * time.Minute),
			},
		},
		RawPayload: []PayloadField{
			{Key: "charge.id", Value: tx.PSPReference},
			{Key: "payment_intent", Value: "pi-intent-394"},
			{Key: "amount", Value: "4980.00"},
			{Key: "currency", Value: "jpy"},
			{Key: "customer_email", Value: "mariko.takahashi@example.com"},
		},
	}
}

func buildSquareFlaggedDetail(tx Transaction) TransactionDetail {
	due := tx.CapturedAt.AddDate(0, 0, 7)
	return TransactionDetail{
		Transaction: tx,
		Timeline: []TimelineEvent{
			{
				Timestamp:   tx.CapturedAt.Add(-5 * time.Minute),
				Label:       "カード承認",
				Description: "Square Reader端末で承認されました。",
				Tone:        "info",
				Icon:        "✅",
			},
			{
				Timestamp:   tx.CapturedAt,
				Label:       "売上確定",
				Description: "担当: store.ueno",
				Tone:        "warning",
				Icon:        "⚠️",
			},
		},
		Breakdown: []BreakdownEntry{
			{Label: "売上", AmountMinor: tx.AmountMinor, Currency: tx.Currency},
			{Label: "決済手数料", AmountMinor: -tx.FeeMinor, Currency: tx.Currency, Tone: "muted"},
			{Label: "入金予定", AmountMinor: tx.NetMinor, Currency: tx.Currency, Tone: "info"},
		},
		Adjustments: []Adjustment{
			{
				ID:          "adj_manual_review",
				Type:        "hold",
				Label:       "手動レビュー",
				AmountMinor: tx.AmountMinor,
				Currency:    tx.Currency,
				Actor:       "fraud.akiyama",
				Reason:      "不自然な分割支払い",
				Timestamp:   tx.CapturedAt.Add(30 * time.Minute),
				StatusLabel: "レビュー中",
				StatusTone:  "warning",
			},
		},
		Disputes: []Dispute{
			{
				ID:            "dspt-sq-001",
				StatusLabel:   "調査中",
				StatusTone:    "warning",
				AmountMinor:   tx.AmountMinor,
				Currency:      tx.Currency,
				ResponseDueAt: &due,
				LastUpdatedAt: tx.CapturedAt.Add(time.Hour),
				MoreInfoURL:   "https://squareup.com/help/jp/jp/article/dispute",
			},
		},
		Notes: []Note{
			{
				Author:    "cs.sato",
				Message:   "お客様へ領収書再送済み。確認の折り返し待ち。",
				Timestamp: tx.CapturedAt.Add(time.Hour + 20*time.Minute),
			},
		},
		RawPayload: []PayloadField{
			{Key: "payment_id", Value: tx.PSPReference},
			{Key: "card_brand", Value: "mastercard"},
			{Key: "entry_method", Value: "contactless"},
			{Key: "risk_evaluation", Value: "needs_review"},
		},
	}
}

func buildFailureDetail(tx Transaction) TransactionDetail {
	return TransactionDetail{
		Transaction: tx,
		Timeline: []TimelineEvent{
			{
				Timestamp:   tx.CapturedAt.Add(-time.Minute),
				Label:       "カード承認",
				Description: "3Dセキュア失敗",
				Tone:        "danger",
				Icon:        "⛔",
			},
		},
		Breakdown: []BreakdownEntry{
			{Label: "売上", AmountMinor: tx.AmountMinor, Currency: tx.Currency},
			{Label: "決済手数料", AmountMinor: 0, Currency: tx.Currency, Tone: "muted"},
		},
		Adjustments: nil,
		Disputes:    nil,
		Notes: []Note{
			{
				Author:    "cs.mori",
				Message:   "お客様からカード会社へ問い合わせ案内済み。",
				Timestamp: tx.CapturedAt.Add(15 * time.Minute),
			},
		},
		RawPayload: []PayloadField{
			{Key: "failure_code", Value: "authentication_failed"},
			{Key: "acquirer_response", Value: "do_not_honor"},
			{Key: "avs_result", Value: "N"},
		},
	}
}

func buildRefundDetail(tx Transaction) TransactionDetail {
	return TransactionDetail{
		Transaction: tx,
		Timeline: []TimelineEvent{
			{
				Timestamp:   tx.CapturedAt.Add(-10 * time.Minute),
				Label:       "オペレーターキャプチャ",
				Description: "電話注文で手動決済。",
				Tone:        "info",
				Icon:        "☎️",
			},
			{
				Timestamp:   tx.CapturedAt.Add(2 * time.Hour),
				Label:       "全額返金",
				Description: "受注ミスのためオペが返金処理。",
				Tone:        "warning",
				Icon:        "↩",
			},
		},
		Breakdown: []BreakdownEntry{
			{Label: "売上", AmountMinor: tx.AmountMinor, Currency: tx.Currency},
			{Label: "返金額", AmountMinor: -tx.AmountMinor, Currency: tx.Currency, Tone: "danger"},
			{Label: "手数料返還", AmountMinor: -tx.FeeMinor, Currency: tx.Currency, Tone: "muted"},
		},
		Adjustments: []Adjustment{
			{
				ID:          "adj_refund_full",
				Type:        "refund",
				Label:       "全額返金",
				AmountMinor: -tx.AmountMinor,
				Currency:    tx.Currency,
				Actor:       "support.kanda",
				Reason:      "二重注文のため",
				Timestamp:   tx.CapturedAt.Add(2 * time.Hour),
				StatusLabel: "完了",
				StatusTone:  "success",
			},
		},
		Disputes: nil,
		Notes: []Note{
			{
				Author:    "support.kanda",
				Message:   "返金承認済み。注文#20293へ振替予定。",
				Timestamp: tx.CapturedAt.Add(3 * time.Hour),
			},
		},
		RawPayload: []PayloadField{
			{Key: "transaction_id", Value: tx.PSPReference},
			{Key: "refund_id", Value: "refund-20930"},
			{Key: "operator_id", Value: "support.kanda"},
		},
	}
}

func buildDisputeDetail(tx Transaction) TransactionDetail {
	due := tx.CapturedAt.AddDate(0, 0, 5)
	return TransactionDetail{
		Transaction: tx,
		Timeline: []TimelineEvent{
			{
				Timestamp:   tx.CapturedAt,
				Label:       "売上確定",
				Description: "Stripe経由でキャプチャ。",
				Tone:        "info",
				Icon:        "💳",
			},
			{
				Timestamp:   tx.CapturedAt.AddDate(0, 0, 3),
				Label:       "異議申し立て発生",
				Description: "理由: 商品未着。",
				Tone:        "danger",
				Icon:        "⚠️",
			},
		},
		Breakdown: []BreakdownEntry{
			{Label: "売上", AmountMinor: tx.AmountMinor, Currency: tx.Currency},
			{Label: "異議金額", AmountMinor: -tx.AmountMinor, Currency: tx.Currency, Tone: "danger"},
			{Label: "手数料", AmountMinor: -tx.FeeMinor, Currency: tx.Currency, Tone: "muted"},
		},
		Adjustments: []Adjustment{
			{
				ID:          "adj_dispute_hold",
				Type:        "hold",
				Label:       "保留中",
				AmountMinor: -tx.AmountMinor,
				Currency:    tx.Currency,
				Actor:       "fraud.akiyama",
				Reason:      "カード会社調査中",
				Timestamp:   tx.CapturedAt.AddDate(0, 0, 3),
				StatusLabel: "進行中",
				StatusTone:  "warning",
			},
		},
		Disputes: []Dispute{
			{
				ID:            "dp_1NZPAYdispute",
				StatusLabel:   "証拠提出待ち",
				StatusTone:    "warning",
				AmountMinor:   tx.AmountMinor,
				Currency:      tx.Currency,
				ResponseDueAt: &due,
				LastUpdatedAt: tx.CapturedAt.AddDate(0, 0, 3),
				MoreInfoURL:   "https://dashboard.stripe.com/disputes/dp_1NZPAYdispute",
			},
		},
		Notes: []Note{
			{
				Author:    "fraud.akiyama",
				Message:   "配送伝票と受領証を添付予定。4/20までに送付。",
				Timestamp: tx.CapturedAt.AddDate(0, 0, 3).Add(2 * time.Hour),
			},
		},
		RawPayload: []PayloadField{
			{Key: "charge", Value: tx.PSPReference},
			{Key: "evidence_due_by", Value: due.Format(time.RFC3339)},
			{Key: "reason", Value: "product_not_received"},
		},
	}
}

func buildStripeCapturedDetail(tx Transaction) TransactionDetail {
	return TransactionDetail{
		Transaction: tx,
		Timeline: []TimelineEvent{
			{
				Timestamp:   tx.CapturedAt,
				Label:       "売上確定",
				Description: "アプリ経由のApple Pay決済。",
				Tone:        "info",
				Icon:        "📲",
			},
		},
		Breakdown: []BreakdownEntry{
			{Label: "売上", AmountMinor: tx.AmountMinor, Currency: tx.Currency},
			{Label: "決済手数料", AmountMinor: -tx.FeeMinor, Currency: tx.Currency, Tone: "muted"},
			{Label: "入金予定", AmountMinor: tx.NetMinor, Currency: tx.Currency, Tone: "success"},
		},
		Adjustments: []Adjustment{
			{
				ID:          "adj_partial_refund",
				Type:        "refund",
				Label:       "部分返金予定",
				AmountMinor: -18600,
				Currency:    tx.Currency,
				Actor:       "support.matsuda",
				Reason:      "刻印ミス",
				Timestamp:   tx.CapturedAt.Add(6 * time.Hour),
				StatusLabel: "ドラフト",
				StatusTone:  "info",
			},
		},
		Disputes: nil,
		Notes: []Note{
			{
				Author:    "support.matsuda",
				Message:   "4/25に部分返金を予定。確認完了まで保留。",
				Timestamp: tx.CapturedAt.Add(6 * time.Hour),
			},
		},
		RawPayload: []PayloadField{
			{Key: "payment_method", Value: "apple_pay"},
			{Key: "statement_descriptor", Value: "HANKO TOKYO"},
			{Key: "installments", Value: "single"},
		},
	}
}
