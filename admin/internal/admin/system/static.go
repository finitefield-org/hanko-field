package system

import (
	"context"
	"sort"
	"strings"
	"time"
)

// StaticService provides canned responses for development previews and tests.
type StaticService struct {
	failures []Failure
	details  map[string]FailureDetail
	metrics  MetricsSummary
}

// NewStaticService constructs a StaticService populated with representative failures.
func NewStaticService() *StaticService {
	now := time.Now()

	webhookFailure := Failure{
		ID:             "wh-checkout-update-241104",
		Source:         SourceWebhook,
		Service:        "shopify-webhooks",
		Name:           "Shopify checkout/update",
		Severity:       SeverityHigh,
		Status:         StatusOpen,
		Message:        "POST https://api.hanko.local/webhooks/shopify/checkout-update returned 410 Gone",
		Code:           "HTTP_410",
		FirstSeen:      now.Add(-6 * time.Hour),
		LastSeen:       now.Add(-12 * time.Minute),
		RetryCount:     2,
		MaxRetries:     5,
		Recoverable:    true,
		RetryAvailable: true,
		AckAvailable:   true,
		Links: []Link{
			{Label: "注文 #1042", URL: "/admin/orders/1042", Icon: "🧾"},
			{Label: "配送ラベル", URL: "/admin/shipments/tracking?order=1042"},
		},
		Target: TargetRef{
			Kind:  "注文",
			Label: "#1042",
			ID:    "1042",
			URL:   "/admin/orders/1042",
		},
		RunbookURL:  "https://runbooks.hanko.local/webhooks/shopify/checkout-update",
		LastPayload: `{"event":"checkout_update","checkout_id":"chk_82jd8","line_items":3,"total_price":12800}`,
		Attributes: map[string]string{
			"Queue":         "webhooks-default",
			"Region":        "asia-northeast1",
			"Last Response": "410 Gone",
		},
	}

	jobFailure := Failure{
		ID:             "job-inventory-rebuild-20241104-0500",
		Source:         SourceJob,
		Service:        "inventory-scheduler",
		Name:           "inventory-rebuild (05:00)",
		Severity:       SeverityCritical,
		Status:         StatusAcknowledged,
		Message:        "Firestore batch commit exceeded maximum retries due to contention",
		Code:           "FIRESTORE_ABORTED",
		FirstSeen:      now.Add(-11 * time.Hour),
		LastSeen:       now.Add(-40 * time.Minute),
		RetryCount:     3,
		MaxRetries:     5,
		Recoverable:    true,
		RetryAvailable: true,
		AckAvailable:   false,
		Links: []Link{
			{Label: "ジョブ詳細", URL: "/admin/system/tasks/jobs/inventory-rebuild", Icon: "🗂"},
			{Label: "Cloud Run ログ", URL: "https://console.cloud.google.com/run/detail/asia-northeast1/inventory-rebuild"},
		},
		Target: TargetRef{
			Kind:  "ジョブ",
			Label: "inventory-rebuild",
			ID:    "inventory-rebuild",
			URL:   "/admin/system/tasks/jobs/inventory-rebuild",
		},
		RunbookURL:  "https://runbooks.hanko.local/jobs/inventory-rebuild",
		LastPayload: `{"batch":"2024-11-04T05:00:00+09:00"}`,
		Attributes: map[string]string{
			"Queue":         "critical-batch",
			"Environment":   "production",
			"Last Response": "ABORTED (deadline exceeded)",
		},
	}

	workerFailure := Failure{
		ID:             "worker-fulfillment-sync-err-7781",
		Source:         SourceWorker,
		Service:        "fulfillment-sync",
		Name:           "fulfillment-sync worker",
		Severity:       SeverityMedium,
		Status:         StatusOpen,
		Message:        "Timeout waiting for carrier API response after 30s",
		Code:           "HTTP_TIMEOUT",
		FirstSeen:      now.Add(-3 * time.Hour),
		LastSeen:       now.Add(-7 * time.Minute),
		RetryCount:     1,
		MaxRetries:     4,
		Recoverable:    true,
		RetryAvailable: true,
		AckAvailable:   true,
		Links: []Link{
			{Label: "配送例外を確認", URL: "/admin/shipments/tracking?status=delayed", Icon: "🚚"},
		},
		Target: TargetRef{
			Kind:  "API",
			Label: "Yamato 集荷 API",
			ID:    "yamato-pickup",
			URL:   "https://developer.kuronekoyamato.co.jp/",
		},
		RunbookURL:  "https://runbooks.hanko.local/workers/fulfillment-sync",
		LastPayload: `{"carrier":"yamato","order":"1055","attempt":4}`,
		Attributes: map[string]string{
			"Queue":         "workers-default",
			"Region":        "asia-northeast1",
			"Last Response": "timeout after 30s",
		},
	}

	details := map[string]FailureDetail{
		webhookFailure.ID: {
			Failure:    webhookFailure,
			StackTrace: []string{"github.com/hanko/platform/webhooks/shopify.(*Handler).Dispatch", "github.com/hanko/platform/internal/webhooks.Dispatcher.handle", "net/http.HandlerFunc.ServeHTTP"},
			Payload: map[string]any{
				"event":        "checkout_update",
				"checkout_id":  "chk_82jd8",
				"line_items":   3,
				"total_price":  12800,
				"currency":     "JPY",
				"customer_id":  "cus_19028",
				"abandoned_at": now.Add(-18 * time.Minute).Format(time.RFC3339),
			},
			Headers: map[string]string{
				"X-Shopify-Topic":   "checkout/update",
				"X-Webhook-ID":      "wh_241104_9982",
				"User-Agent":        "Shopify-Custom-Webhook/1.0",
				"X-Retry-Count":     "2",
				"X-Hanko-RequestID": "req_82dj3",
			},
			LastAttempt: now.Add(-12 * time.Minute),
			NextRetryAt: ptrTime(now.Add(3 * time.Minute)),
			RecentAttempts: []Attempt{
				{
					Number:     1,
					OccurredAt: now.Add(-32 * time.Minute),
					Status:     "502 from API (retryable)",
					Response:   "upstream timeout",
					Duration:   12 * time.Second,
				},
				{
					Number:     2,
					OccurredAt: now.Add(-18 * time.Minute),
					Status:     "410 Gone",
					Response:   "order not found",
					Duration:   6 * time.Second,
				},
				{
					Number:     3,
					OccurredAt: now.Add(-12 * time.Minute),
					Status:     "410 Gone",
					Response:   "order cancelled",
					Duration:   5 * time.Second,
				},
			},
			RunbookSteps: []RunbookStep{
				{
					Title:       "注文ステータスを確認",
					Description: "関連する注文が既にキャンセルされていないか確認します。キャンセル済みであれば安全に無視できます。",
					Links: []Link{
						{Label: "注文 #1042 を開く", URL: "/admin/orders/1042"},
					},
				},
				{
					Title:       "Shopify 側の再送をキューイング",
					Description: "Shopify 管理画面で該当テーマの Webhook Delivery を再送します。",
				},
				{
					Title:       "Webhook 実行を手動リトライ",
					Description: "下の「再実行」ボタンでワーカーに再投入します。成功時は自動でアクション履歴に記録されます。",
				},
			},
		},
		jobFailure.ID: {
			Failure:    jobFailure,
			StackTrace: []string{"github.com/hanko/inventory/jobs/rebuild.(*Runner).Run", "github.com/hanko/platform/internal/tasks.(*Executor).execute"},
			Payload: map[string]any{
				"batch":             "2024-11-04T05:00:00+09:00",
				"retry":             3,
				"segment":           "catalog-products",
				"estimated_records": 128942,
			},
			Headers: map[string]string{
				"X-Job-Runner":   "cloud-run",
				"X-Task-Attempt": "3",
			},
			LastAttempt: now.Add(-40 * time.Minute),
			NextRetryAt: ptrTime(now.Add(20 * time.Minute)),
			RecentAttempts: []Attempt{
				{
					Number:     1,
					OccurredAt: now.Add(-2 * time.Hour),
					Status:     "ABORTED by Firestore (contention)",
					Response:   "retry recommended",
					Duration:   2*time.Minute + 15*time.Second,
				},
				{
					Number:     2,
					OccurredAt: now.Add(-80 * time.Minute),
					Status:     "ABORTED by Firestore (deadline exceeded)",
					Response:   "new transaction started",
					Duration:   2*time.Minute + 40*time.Second,
				},
				{
					Number:     3,
					OccurredAt: now.Add(-40 * time.Minute),
					Status:     "ABORTED by Firestore (contention)",
					Response:   "retry scheduled",
					Duration:   2*time.Minute + 8*time.Second,
				},
			},
			RunbookSteps: []RunbookStep{
				{
					Title:       "メンテナンス通知を確認",
					Description: "カタログ編集が集中していないか確認し、必要に応じて編集を一時停止します。",
				},
				{
					Title:       "Firestore コンソールで競合ドキュメントを確認",
					Description: "該当するアイテム ID を調査し、ロックされているトランザクションを解放します。",
				},
				{
					Title:       "再実行を送信",
					Description: "競合解消後に再実行をトリガーします。再実行後も失敗する場合は SRE チームへエスカレーションしてください。",
				},
			},
		},
		workerFailure.ID: {
			Failure:    workerFailure,
			StackTrace: []string{"github.com/hanko/logistics/worker/fulfillment.sync", "github.com/hanko/platform/internal/workers.(*Runner).process"},
			Payload: map[string]any{
				"carrier":  "yamato",
				"order":    "1055",
				"attempt":  4,
				"endpoint": "https://api.kuronekoyamato.co.jp/pickup",
			},
			Headers: map[string]string{
				"X-Worker-ID":  "fulfillment-sync-17",
				"X-Attempt":    "4",
				"X-Request-ID": "req_yy28a",
				"Retry-After":  "PT120S",
			},
			LastAttempt: now.Add(-7 * time.Minute),
			NextRetryAt: ptrTime(now.Add(5 * time.Minute)),
			RecentAttempts: []Attempt{
				{
					Number:     1,
					OccurredAt: now.Add(-28 * time.Minute),
					Status:     "timeout",
					Response:   "carrier API no response",
					Duration:   30 * time.Second,
				},
				{
					Number:     2,
					OccurredAt: now.Add(-18 * time.Minute),
					Status:     "timeout",
					Response:   "carrier API no response",
					Duration:   30 * time.Second,
				},
				{
					Number:     3,
					OccurredAt: now.Add(-7 * time.Minute),
					Status:     "timeout",
					Response:   "carrier API no response",
					Duration:   30 * time.Second,
				},
			},
			RunbookSteps: []RunbookStep{
				{
					Title:       "キャリア稼働状況の確認",
					Description: "ヤマト運輸のステータスページで障害情報が出ていないか確認します。",
				},
				{
					Title:       "バックログを監視",
					Description: "配送トラッキング画面で遅延リスクを確認し、お客様への連絡が必要か評価します。",
					Links: []Link{
						{Label: "配送トラッキング", URL: "/admin/shipments/tracking"},
					},
				},
				{
					Title:       "スロットリング設定を調整",
					Description: "Workers 設定で同時実行数を 20% 減らし、API の負荷を下げます。",
				},
			},
		},
	}

	return &StaticService{
		failures: []Failure{webhookFailure, jobFailure, workerFailure},
		details:  details,
		metrics: MetricsSummary{
			TotalFailures:      58,
			RetrySuccessRate:   87.5,
			RetrySuccessDelta:  -2.3,
			QueueBacklog:       7,
			ActiveIncidents:    3,
			RetrySuccessSample: 120,
		},
	}
}

// ListFailures returns the filtered failures for the dashboard.
func (s *StaticService) ListFailures(_ context.Context, _ string, query FailureQuery) (FailureResult, error) {
	filtered := make([]Failure, 0, len(s.failures))
	for _, failure := range s.failures {
		if !matchesSource(query.Sources, failure.Source) {
			continue
		}
		if !matchesSeverity(query.Severities, failure.Severity) {
			continue
		}
		if !matchesStatus(query.Statuses, failure.Status) {
			continue
		}
		if !matchesService(query.Services, failure.Service) {
			continue
		}
		if !matchesSearch(query.Search, failure) {
			continue
		}
		if !matchesTimeRange(query.Start, query.End, failure.LastSeen) {
			continue
		}
		filtered = append(filtered, failure)
	}

	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].LastSeen.After(filtered[j].LastSeen)
	})

	if query.Limit > 0 && len(filtered) > query.Limit {
		filtered = filtered[:query.Limit]
	}

	result := FailureResult{
		Failures:    filtered,
		Total:       len(filtered),
		NextCursor:  "",
		Metrics:     s.metrics,
		Filters:     s.buildFilterSummary(),
		GeneratedAt: time.Now(),
	}
	return result, nil
}

// FailureDetail returns the detailed payload for a failure.
func (s *StaticService) FailureDetail(_ context.Context, _ string, failureID string) (FailureDetail, error) {
	if detail, ok := s.details[failureID]; ok {
		return detail, nil
	}
	return FailureDetail{}, ErrFailureNotFound
}

// RetryFailure simulates enqueuing a retry for the failure.
func (s *StaticService) RetryFailure(_ context.Context, _ string, failureID string, _ RetryOptions) (RetryOutcome, error) {
	detail, ok := s.details[failureID]
	if !ok {
		return RetryOutcome{}, ErrFailureNotFound
	}
	next := time.Now().Add(2 * time.Minute)
	return RetryOutcome{
		Queued:     true,
		Message:    "再実行をキューに登録しました。",
		NextRunAt:  &next,
		RetryCount: detail.Failure.RetryCount + 1,
		Status:     detail.Failure.Status,
	}, nil
}

// AcknowledgeFailure simulates acknowledging a failure.
func (s *StaticService) AcknowledgeFailure(_ context.Context, _ string, failureID string, _ AcknowledgeOptions) (AcknowledgeOutcome, error) {
	detail, ok := s.details[failureID]
	if !ok {
		return AcknowledgeOutcome{}, ErrFailureNotFound
	}
	status := detail.Failure.Status
	if status == StatusOpen {
		status = StatusAcknowledged
	}
	return AcknowledgeOutcome{
		Acknowledged: true,
		Message:      "アラートを確認済みに更新しました。",
		Status:       status,
	}, nil
}

func (s *StaticService) buildFilterSummary() FilterSummary {
	sourceCounts := make(map[Source]int)
	severityCounts := make(map[Severity]int)
	serviceCounts := make(map[string]int)
	statusCounts := make(map[Status]int)

	for _, failure := range s.failures {
		sourceCounts[failure.Source]++
		severityCounts[failure.Severity]++
		serviceCounts[failure.Service]++
		statusCounts[failure.Status]++
	}

	return FilterSummary{
		SourceCounts:   sourceCounts,
		SeverityCounts: severityCounts,
		ServiceCounts:  serviceCounts,
		StatusCounts:   statusCounts,
	}
}

func matchesSource(filter []Source, value Source) bool {
	if len(filter) == 0 {
		return true
	}
	for _, candidate := range filter {
		if candidate == value {
			return true
		}
	}
	return false
}

func matchesSeverity(filter []Severity, value Severity) bool {
	if len(filter) == 0 {
		return true
	}
	for _, candidate := range filter {
		if candidate == value {
			return true
		}
	}
	return false
}

func matchesStatus(filter []Status, value Status) bool {
	if len(filter) == 0 {
		return true
	}
	for _, candidate := range filter {
		if candidate == value {
			return true
		}
	}
	return false
}

func matchesService(filter []string, value string) bool {
	if len(filter) == 0 {
		return true
	}
	value = strings.ToLower(strings.TrimSpace(value))
	for _, candidate := range filter {
		if strings.ToLower(strings.TrimSpace(candidate)) == value {
			return true
		}
	}
	return false
}

func matchesSearch(search string, failure Failure) bool {
	search = strings.TrimSpace(strings.ToLower(search))
	if search == "" {
		return true
	}
	fields := []string{
		failure.ID,
		failure.Name,
		failure.Message,
		failure.Code,
		failure.Service,
		failure.Target.Label,
		failure.Target.ID,
	}
	for _, value := range fields {
		if strings.Contains(strings.ToLower(value), search) {
			return true
		}
	}
	return false
}

func matchesTimeRange(start, end *time.Time, value time.Time) bool {
	if start != nil && value.Before(*start) {
		return false
	}
	if end != nil && value.After(*end) {
		return false
	}
	return true
}

func ptrTime(t time.Time) *time.Time {
	return &t
}
