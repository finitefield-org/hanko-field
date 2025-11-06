package system

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"
	"unicode"
)

// StaticService provides canned responses for development previews and tests.
type StaticService struct {
	failures       []Failure
	details        map[string]FailureDetail
	metrics        MetricsSummary
	jobs           []Job
	jobIndex       map[string]JobDetail
	scheduler      SchedulerHealth
	alerts         []JobAlert
	counters       []Counter
	counterAlerts  []CounterAlert
	counterHistory map[string][]CounterEvent
	counterJobs    map[string][]CounterJob
	counterNotes   map[string][]string
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
			{Label: "ジョブ詳細", URL: "/system/tasks/jobs/inventory-rebuild", Icon: "🗂"},
			{Label: "Cloud Run ログ", URL: "https://console.cloud.google.com/run/detail/asia-northeast1/inventory-rebuild"},
		},
		Target: TargetRef{
			Kind:  "ジョブ",
			Label: "inventory-rebuild",
			ID:    "inventory-rebuild",
			URL:   "/system/tasks/jobs/inventory-rebuild",
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

	inventoryRuns := []JobRun{
		{
			ID:          "inventory-rebuild-20241104-0500",
			Status:      JobRunFailed,
			StartedAt:   now.Add(-40 * time.Minute),
			CompletedAt: ptrTime(now.Add(-28 * time.Minute)),
			Duration:    12 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     3,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/inventory-rebuild/logs",
			Worker:      "inventory-runner-1",
			Region:      "asia-northeast1",
			Error:       "Firestore batch commit exceeded maximum retries",
		},
		{
			ID:          "inventory-rebuild-20241103-0500",
			Status:      JobRunSuccess,
			StartedAt:   now.Add(-24*time.Hour - 35*time.Minute),
			CompletedAt: ptrTime(now.Add(-24*time.Hour - 23*time.Minute)),
			Duration:    12 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/inventory-rebuild/logs",
			Worker:      "inventory-runner-2",
			Region:      "asia-northeast1",
		},
		{
			ID:          "inventory-rebuild-20241102-0500",
			Status:      JobRunSuccess,
			StartedAt:   now.Add(-48*time.Hour - 36*time.Minute),
			CompletedAt: ptrTime(now.Add(-48*time.Hour - 24*time.Minute)),
			Duration:    12 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/inventory-rebuild/logs",
			Worker:      "inventory-runner-3",
			Region:      "asia-northeast1",
		},
		{
			ID:          "inventory-rebuild-20241101-0500",
			Status:      JobRunFailed,
			StartedAt:   now.Add(-72*time.Hour - 40*time.Minute),
			CompletedAt: ptrTime(now.Add(-72*time.Hour - 32*time.Minute)),
			Duration:    8 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     2,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/inventory-rebuild/logs",
			Worker:      "inventory-runner-1",
			Region:      "asia-northeast1",
			Error:       "Firestore ABORTED after 5 retries",
		},
	}

	cleanupRuns := []JobRun{
		{
			ID:          "cleanup-reservations-20241104-0200",
			Status:      JobRunSuccess,
			StartedAt:   now.Add(-2 * time.Hour),
			CompletedAt: ptrTime(now.Add(-1*time.Hour - 40*time.Minute)),
			Duration:    20 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/cleanup-reservations/logs",
			Worker:      "ops-runner-1",
			Region:      "asia-northeast1",
		},
		{
			ID:          "cleanup-reservations-20241103-0200",
			Status:      JobRunSuccess,
			StartedAt:   now.Add(-24*time.Hour - 2*time.Hour),
			CompletedAt: ptrTime(now.Add(-24*time.Hour - time.Hour - 45*time.Minute)),
			Duration:    15 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/cleanup-reservations/logs",
			Worker:      "ops-runner-1",
			Region:      "asia-northeast1",
		},
		{
			ID:          "cleanup-reservations-manual-20241102",
			Status:      JobRunSuccess,
			StartedAt:   now.Add(-36 * time.Hour),
			CompletedAt: ptrTime(now.Add(-35*time.Hour - 35*time.Minute)),
			Duration:    25 * time.Minute,
			TriggeredBy: "mihara@hanko.jp",
			Trigger:     JobTriggerManual,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/cleanup-reservations/logs",
			Worker:      "ops-runner-2",
			Region:      "asia-northeast1",
		},
	}

	reportingRuns := []JobRun{
		{
			ID:          "reporting-delta-20241104-0030",
			Status:      JobRunRunning,
			StartedAt:   now.Add(-18 * time.Minute),
			Duration:    18 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/reporting-delta/logs",
			Worker:      "analytics-runner-1",
			Region:      "asia-northeast1",
		},
		{
			ID:          "reporting-delta-20241103-0030",
			Status:      JobRunSuccess,
			StartedAt:   now.Add(-24*time.Hour - 25*time.Minute),
			CompletedAt: ptrTime(now.Add(-24*time.Hour - 3*time.Minute)),
			Duration:    22 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/reporting-delta/logs",
			Worker:      "analytics-runner-1",
			Region:      "asia-northeast1",
		},
		{
			ID:          "reporting-delta-20241102-0030",
			Status:      JobRunSuccess,
			StartedAt:   now.Add(-48*time.Hour - 27*time.Minute),
			CompletedAt: ptrTime(now.Add(-48*time.Hour - 5*time.Minute)),
			Duration:    22 * time.Minute,
			TriggeredBy: "scheduler@system",
			Trigger:     JobTriggerScheduler,
			Attempt:     1,
			LogsURL:     "https://console.cloud.google.com/run/detail/asia-northeast1/reporting-delta/logs",
			Worker:      "analytics-runner-1",
			Region:      "asia-northeast1",
		},
	}

	inventoryHistory := make([]JobHistoryPoint, 0, len(inventoryRuns))
	for _, run := range inventoryRuns {
		inventoryHistory = append(inventoryHistory, JobHistoryPoint{
			RunID:     run.ID,
			Status:    run.Status,
			Duration:  run.Duration,
			Timestamp: run.StartedAt,
		})
	}

	cleanupHistory := make([]JobHistoryPoint, 0, len(cleanupRuns))
	for _, run := range cleanupRuns {
		cleanupHistory = append(cleanupHistory, JobHistoryPoint{
			RunID:     run.ID,
			Status:    run.Status,
			Duration:  run.Duration,
			Timestamp: run.StartedAt,
		})
	}

	reportingHistory := make([]JobHistoryPoint, 0, len(reportingRuns))
	for _, run := range reportingRuns {
		reportingHistory = append(reportingHistory, JobHistoryPoint{
			RunID:     run.ID,
			Status:    run.Status,
			Duration:  run.Duration,
			Timestamp: run.StartedAt,
		})
	}

	inventoryJob := Job{
		ID:                  "inventory-rebuild",
		Name:                "Inventory rebuild",
		Description:         "Rebuilds aggregated stock levels and product health nightly.",
		Type:                JobTypeScheduled,
		State:               JobStateDegraded,
		Host:                "scheduler-01",
		Schedule:            "毎日 05:00 JST",
		Queue:               "critical-batch",
		Tags:                []string{"catalog", "inventory"},
		LastRun:             inventoryRuns[0],
		NextRun:             now.Add(4 * time.Hour),
		AverageDuration:     11*time.Minute + 30*time.Second,
		SuccessRate:         0.82,
		ManualTrigger:       true,
		RetryAvailable:      true,
		LogsURL:             "https://console.cloud.google.com/run/detail/asia-northeast1/inventory-rebuild/logs",
		PrimaryRunbookURL:   "https://runbooks.hanko.local/jobs/inventory-rebuild",
		CreatedAt:           now.Add(-180 * 24 * time.Hour),
		UpdatedAt:           now.Add(-12 * time.Minute),
		SLASeconds:          600,
		PendingExecutions:   0,
		RecoveredAt:         nil,
		LastFailureMessage:  inventoryRuns[0].Error,
		LastFailureOccurred: ptrTime(inventoryRuns[0].StartedAt),
	}

	cleanupJob := Job{
		ID:                "cleanup-reservations",
		Name:              "Cleanup pending reservations",
		Description:       "Removes stale order reservations and releases blocked stock every hour.",
		Type:              JobTypeScheduled,
		State:             JobStateHealthy,
		Host:              "scheduler-02",
		Schedule:          "毎時 02 分",
		Queue:             "ops-default",
		Tags:              []string{"ops", "inventory"},
		LastRun:           cleanupRuns[0],
		NextRun:           now.Add(40 * time.Minute),
		AverageDuration:   18 * time.Minute,
		SuccessRate:       0.97,
		ManualTrigger:     true,
		RetryAvailable:    true,
		LogsURL:           "https://console.cloud.google.com/run/detail/asia-northeast1/cleanup-reservations/logs",
		PrimaryRunbookURL: "https://runbooks.hanko.local/jobs/cleanup-reservations",
		CreatedAt:         now.Add(-120 * 24 * time.Hour),
		UpdatedAt:         now.Add(-40 * time.Minute),
		SLASeconds:        900,
		PendingExecutions: 0,
	}

	reportingJob := Job{
		ID:                "reporting-delta",
		Name:              "Reporting delta",
		Description:       "Streams incremental orders and revenue data into BigQuery.",
		Type:              JobTypeEvent,
		State:             JobStateRunning,
		Host:              "scheduler-01",
		Schedule:          "毎時 30 分",
		Queue:             "analytics",
		Tags:              []string{"analytics", "bi"},
		LastRun:           reportingRuns[0],
		NextRun:           now.Add(42 * time.Minute),
		AverageDuration:   21 * time.Minute,
		SuccessRate:       0.99,
		ManualTrigger:     false,
		RetryAvailable:    false,
		LogsURL:           "https://console.cloud.google.com/run/detail/asia-northeast1/reporting-delta/logs",
		PrimaryRunbookURL: "https://runbooks.hanko.local/jobs/reporting-delta",
		CreatedAt:         now.Add(-90 * 24 * time.Hour),
		UpdatedAt:         now.Add(-18 * time.Minute),
		SLASeconds:        1800,
		PendingExecutions: 1,
	}

	jobIndex := map[string]JobDetail{
		inventoryJob.ID: {
			Job:         inventoryJob,
			Parameters:  map[string]string{"batch": "daily", "segment": "catalog-products"},
			Environment: map[string]string{"GCP_PROJECT": "hanko-prod", "QUEUE": inventoryJob.Queue},
			RecentRuns:  inventoryRuns,
			History:     inventoryHistory,
			Timeline: []JobTimelineEntry{
				{Title: "自動監視がレイテンシ上昇を検知", Description: "05:00のジョブでFirestoreのコンテンションによるレイテンシ増大を検知しました。", OccurredAt: now.Add(-50 * time.Minute), Actor: "scheduler", Tone: "warning", Icon: "⏱"},
				{Title: "OpsがRunbookを確認", Description: "三原さんがRunbookに沿って影響範囲を確認しました。", OccurredAt: now.Add(-45 * time.Minute), Actor: "mihara@hanko.jp", Tone: "info", Icon: "🧭"},
			},
			Insights: []JobInsight{
				{Title: "Firestore コンテンションが継続", Description: "直近3回中2回でABORTEDが発生しています。コレクション分割または同時実行数の調整を検討してください。", Tone: "warning", Icon: "⚠️"},
			},
			ManualActions: []JobAction{
				{Label: "今すぐ再実行", URL: "/system/tasks/jobs/" + inventoryJob.ID + ":trigger", Method: "POST", Icon: "⟳", Confirm: "inventory-rebuild を今すぐ再実行しますか？"},
			},
		},
		cleanupJob.ID: {
			Job:         cleanupJob,
			Parameters:  map[string]string{"window": "1h", "dry_run": "false"},
			Environment: map[string]string{"GCP_PROJECT": "hanko-prod", "QUEUE": cleanupJob.Queue},
			RecentRuns:  cleanupRuns,
			History:     cleanupHistory,
			Timeline: []JobTimelineEntry{
				{Title: "サポートからの手動実行", Description: "サポートから在庫ブロック解除の依頼があり手動実行されました。", OccurredAt: cleanupRuns[2].StartedAt, Actor: cleanupRuns[2].TriggeredBy, Tone: "info", Icon: "🧑‍💻"},
			},
			Insights: []JobInsight{
				{Title: "成功率安定", Description: "直近30日で失敗はありません。SLA 15分以内達成。", Tone: "success", Icon: "✅"},
			},
			ManualActions: []JobAction{
				{Label: "今すぐクリーンアップ", URL: "/system/tasks/jobs/" + cleanupJob.ID + ":trigger", Method: "POST", Icon: "🧹", Confirm: "未確定の予約を即時クリーンアップします。実行しますか？"},
			},
		},
		reportingJob.ID: {
			Job:         reportingJob,
			Parameters:  map[string]string{"dataset": "daily_delta", "mode": "append"},
			Environment: map[string]string{"GCP_PROJECT": "hanko-prod", "QUEUE": reportingJob.Queue},
			RecentRuns:  reportingRuns,
			History:     reportingHistory,
			Timeline: []JobTimelineEntry{
				{Title: "BigQuery スキーマ更新", Description: "analytics チームが新しい指標列を追加しました。", OccurredAt: now.Add(-6 * time.Hour), Actor: "analytics@hanko.jp", Tone: "info", Icon: "🧮"},
			},
			Insights: []JobInsight{
				{Title: "実行中", Description: "現在 delta export が進行中です。完了まで待機します。", Tone: "info", Icon: "⏳"},
			},
			ManualActions: nil,
		},
	}

	scheduler := SchedulerHealth{
		Status:    JobStateDegraded,
		Label:     "同期遅延あり",
		Message:   "scheduler-01 のハートビートが3分遅延しています。",
		CheckedAt: now.Add(-3 * time.Minute),
		Latency:   3 * time.Minute,
	}

	alerts := []JobAlert{
		{
			ID:      "alert-inventory-rebuild",
			Tone:    "warning",
			Title:   "在庫再構築ジョブが連続失敗",
			Message: "直近4回中2回失敗しています。Ops へエスカレーションしてください。",
			Action: JobAlertAction{
				Label:  "Ops チャンネルに通知",
				URL:    "https://slack.com/app_redirect?channel=ops-incidents",
				Method: "GET",
				Icon:   "📣",
			},
		},
	}

	counterAlerts := []CounterAlert{
		{
			ID:      "invoices-fy-threshold",
			Tone:    "warning",
			Title:   "請求書番号が閾値に近づいています",
			Message: "FY2024 の請求書番号は 80% を超えました。年次ローテーションを準備してください。",
			Action: Link{
				Label: "運用手順を確認",
				URL:   "https://runbooks.hanko.local/finance/invoices#rotate",
				Icon:  "📘",
			},
		},
	}

	ordersCounter := Counter{
		Name:         "orders",
		Label:        "注文番号",
		Namespace:    "commerce",
		Description:  "オンライン注文のヒューマンリーダブルな番号を採番します。",
		ScopeKeys:    []string{"site"},
		ScopeExample: map[string]string{"site": "jp"},
		Increment:    1,
		CurrentValue: 48217,
		LastUpdated:  now.Add(-2 * time.Minute),
		Owner:        "Operations",
		Tags:         []string{"orders", "public-id"},
	}

	invoicesCounter := Counter{
		Name:         "invoices",
		Label:        "請求書番号",
		Namespace:    "finance",
		Description:  "請求書 PDF および会計連携で利用する連番。",
		ScopeKeys:    []string{"fiscal_year"},
		ScopeExample: map[string]string{"fiscal_year": fmt.Sprintf("%d", now.Year())},
		Increment:    1,
		CurrentValue: 958,
		LastUpdated:  now.Add(-10 * time.Minute),
		Owner:        "Finance",
		Tags:         []string{"invoices", "finance"},
		Alert:        &counterAlerts[0],
	}

	exportsCounter := Counter{
		Name:         "exports/daily",
		Label:        "日次エクスポート",
		Namespace:    "ops",
		Description:  "データエクスポートジョブ用の採番。スコープでリージョンと日付を指定します。",
		ScopeKeys:    []string{"region", "date"},
		ScopeExample: map[string]string{"region": "apac", "date": now.Format("2006-01-02")},
		Increment:    100,
		CurrentValue: 3200,
		LastUpdated:  now.Add(-30 * time.Minute),
		Owner:        "DataOps",
		Tags:         []string{"exports", "batch"},
	}

	counters := []Counter{ordersCounter, invoicesCounter, exportsCounter}

	counterHistory := map[string][]CounterEvent{
		counterHistoryKey(ordersCounter.Namespace, ordersCounter.Name, map[string]string{"site": "jp"}): {
			{
				ID:         "evt-orders-jp-001",
				OccurredAt: now.Add(-5 * time.Minute),
				Actor:      "ops@hanko.local",
				ActorEmail: "ops@hanko.local",
				Scope:      map[string]string{"site": "jp"},
				Delta:      1,
				Value:      ordersCounter.CurrentValue,
				Message:    "Admin UI テスト採番",
				Source:     "admin-ui",
				AuditID:    "AUD-000982",
			},
			{
				ID:         "evt-orders-jp-000",
				OccurredAt: now.Add(-90 * time.Minute),
				Actor:      "checkout-service",
				ActorEmail: "",
				Scope:      map[string]string{"site": "jp"},
				Delta:      1,
				Value:      ordersCounter.CurrentValue - 1,
				Message:    "チェックアウト完了",
				Source:     "service",
				AuditID:    "AUD-000921",
			},
		},
		counterHistoryKey(invoicesCounter.Namespace, invoicesCounter.Name, map[string]string{"fiscal_year": fmt.Sprintf("%d", now.Year())}): {
			{
				ID:         "evt-invoices-fy-001",
				OccurredAt: now.Add(-20 * time.Minute),
				Actor:      "finance@hanko.local",
				ActorEmail: "finance@hanko.local",
				Scope:      map[string]string{"fiscal_year": fmt.Sprintf("%d", now.Year())},
				Delta:      1,
				Value:      invoicesCounter.CurrentValue,
				Message:    "請求書発行",
				Source:     "billing-service",
				AuditID:    "AUD-000872",
			},
		},
		counterHistoryKey(exportsCounter.Namespace, exportsCounter.Name, map[string]string{"region": "apac", "date": now.Format("2006-01-02")}): {
			{
				ID:         "evt-exports-apac-001",
				OccurredAt: now.Add(-3 * time.Hour),
				Actor:      "batch@hanko.local",
				ActorEmail: "",
				Scope:      map[string]string{"region": "apac", "date": now.Format("2006-01-02")},
				Delta:      exportsCounter.Increment,
				Value:      exportsCounter.CurrentValue,
				Message:    "日次バッチ出力",
				Source:     "scheduler",
				AuditID:    "AUD-000601",
			},
		},
	}

	counterJobs := map[string][]CounterJob{
		counterBaseKey(ordersCounter.Namespace, ordersCounter.Name): {
			{
				ID:          "inventory-rebuild",
				Name:        "注文番号同期",
				Description: "チェックアウトのバックフィル時にカウンタを検証します。",
				URL:         "/system/tasks?selected=inventory-rebuild",
				StatusLabel: "成功",
				StatusTone:  "success",
				LastRun:     now.Add(-6 * time.Hour),
			},
		},
		counterBaseKey(invoicesCounter.Namespace, invoicesCounter.Name): {
			{
				ID:          "invoice-closeout",
				Name:        "請求書締め処理",
				Description: "月次締め時に請求書番号の残量を確認します。",
				URL:         "/system/tasks?selected=invoice-closeout",
				StatusLabel: "警告",
				StatusTone:  "warning",
				LastRun:     now.Add(-26 * time.Hour),
			},
		},
	}

	counterNotes := map[string][]string{
		counterBaseKey(ordersCounter.Namespace, ordersCounter.Name): {
			"JP サイトの番号は年度ごとにリセットします。",
		},
		counterBaseKey(invoicesCounter.Namespace, invoicesCounter.Name): {
			"年次切り替え時に `fiscal_year` スコープを更新してください。",
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
		jobs:           []Job{inventoryJob, cleanupJob, reportingJob},
		jobIndex:       jobIndex,
		scheduler:      scheduler,
		alerts:         alerts,
		counters:       counters,
		counterAlerts:  counterAlerts,
		counterHistory: counterHistory,
		counterJobs:    counterJobs,
		counterNotes:   counterNotes,
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

// ListJobs returns the filtered job collection for the scheduler monitor.
func (s *StaticService) ListJobs(_ context.Context, _ string, query JobQuery) (JobResult, error) {
	if s == nil {
		return JobResult{}, ErrNotConfigured
	}
	now := time.Now()
	filtered := make([]Job, 0, len(s.jobs))
	for _, job := range s.jobs {
		if !matchesJobType(query.Types, job.Type) {
			continue
		}
		if !matchesJobState(query.States, job.State) {
			continue
		}
		if !matchesJobHost(query.Hosts, job.Host) {
			continue
		}
		if !matchesJobWindow(query.Window, job.NextRun, now) {
			continue
		}
		if !matchesJobSearch(query.Search, job) {
			continue
		}
		filtered = append(filtered, job)
	}

	sort.Slice(filtered, func(i, j int) bool {
		ei := filtered[i].NextRun
		ej := filtered[j].NextRun
		if ei.IsZero() && ej.IsZero() {
			return strings.ToLower(filtered[i].Name) < strings.ToLower(filtered[j].Name)
		}
		if ei.IsZero() {
			return false
		}
		if ej.IsZero() {
			return true
		}
		if ei.Equal(ej) {
			return strings.ToLower(filtered[i].Name) < strings.ToLower(filtered[j].Name)
		}
		return ei.Before(ej)
	})

	if query.Limit > 0 && len(filtered) > query.Limit {
		filtered = filtered[:query.Limit]
	}

	result := JobResult{
		Jobs:        filtered,
		Total:       len(filtered),
		NextCursor:  "",
		Scheduler:   s.scheduler,
		Alerts:      append([]JobAlert(nil), s.alerts...),
		Filters:     s.buildJobFilterSummary(now),
		GeneratedAt: now,
	}
	return result, nil
}

// JobDetail returns the detail payload for the provided job identifier.
func (s *StaticService) JobDetail(_ context.Context, _ string, jobID string) (JobDetail, error) {
	if detail, ok := s.jobIndex[jobID]; ok {
		return detail, nil
	}
	return JobDetail{}, ErrJobNotFound
}

// TriggerJob simulates manual triggering for a job when enabled.
func (s *StaticService) TriggerJob(_ context.Context, _ string, jobID string, opts TriggerOptions) (TriggerOutcome, error) {
	detail, ok := s.jobIndex[jobID]
	if !ok {
		return TriggerOutcome{}, ErrJobNotFound
	}
	if !(detail.Job.ManualTrigger || detail.Job.RetryAvailable) {
		return TriggerOutcome{}, ErrJobTriggerNotAllowed
	}
	now := time.Now()
	runID := fmt.Sprintf("%s-manual-%s", jobID, now.Format("20060102-150405"))
	scheduled := now.Add(30 * time.Second)
	message := fmt.Sprintf("%s の手動実行をキューに登録しました。", detail.Job.Name)
	if !detail.Job.ManualTrigger && detail.Job.RetryAvailable {
		message = fmt.Sprintf("%s の再実行をキューに登録しました。", detail.Job.Name)
	}
	if strings.TrimSpace(opts.Reason) != "" {
		message = fmt.Sprintf("%s (%s)", message, opts.Reason)
	}
	return TriggerOutcome{
		Message:      message,
		RunID:        runID,
		ScheduledFor: scheduled,
		Status:       JobRunQueued,
	}, nil
}

// ListCounters returns the configured counters with optional filtering.
func (s *StaticService) ListCounters(_ context.Context, _ string, query CounterQuery) (CounterResult, error) {
	if s == nil {
		return CounterResult{}, ErrNotConfigured
	}
	namespaceFilter := strings.ToLower(strings.TrimSpace(query.Namespace))
	search := strings.ToLower(strings.TrimSpace(query.Search))

	result := CounterResult{
		GeneratedAt: time.Now(),
		Alerts:      append([]CounterAlert(nil), s.counterAlerts...),
	}

	if len(s.counters) == 0 {
		return result, nil
	}

	counts := make(map[string]int)
	for _, counter := range s.counters {
		key := strings.ToLower(strings.TrimSpace(counter.Namespace))
		counts[key]++
	}

	seenNamespace := make(map[string]struct{})
	for _, counter := range s.counters {
		nsKey := strings.ToLower(strings.TrimSpace(counter.Namespace))
		if _, ok := seenNamespace[nsKey]; !ok {
			seenNamespace[nsKey] = struct{}{}
			result.Namespaces = append(result.Namespaces, CounterNamespace{
				ID:       counter.Namespace,
				Label:    titleCase(counter.Namespace),
				Sublabel: fmt.Sprintf("%d 種", counts[nsKey]),
				Active:   namespaceFilter != "" && nsKey == namespaceFilter,
			})
		}
		if namespaceFilter != "" && nsKey != namespaceFilter {
			continue
		}
		if search != "" && !matchesCounterSearch(search, counter) {
			continue
		}
		result.Counters = append(result.Counters, counter)
	}

	sort.Slice(result.Counters, func(i, j int) bool {
		leftNS := strings.ToLower(result.Counters[i].Namespace)
		rightNS := strings.ToLower(result.Counters[j].Namespace)
		if leftNS == rightNS {
			return strings.ToLower(result.Counters[i].Name) < strings.ToLower(result.Counters[j].Name)
		}
		return leftNS < rightNS
	})

	result.Total = len(result.Counters)
	return result, nil
}

// CounterDetail returns drawer data for a counter.
func (s *StaticService) CounterDetail(_ context.Context, _ string, name string, scope map[string]string) (CounterDetail, error) {
	if s == nil {
		return CounterDetail{}, ErrNotConfigured
	}
	idx := s.findCounterIndex(name)
	if idx == -1 {
		return CounterDetail{}, ErrCounterNotFound
	}
	counter := s.counters[idx]

	key := counterHistoryKey(counter.Namespace, counter.Name, scope)
	history := append([]CounterEvent(nil), s.counterHistory[key]...)
	if len(history) == 0 {
		fallbackKey := counterHistoryKey(counter.Namespace, counter.Name, nil)
		history = append([]CounterEvent(nil), s.counterHistory[fallbackKey]...)
	}

	baseKey := counterBaseKey(counter.Namespace, counter.Name)
	detail := CounterDetail{
		Counter:     counter,
		History:     history,
		RelatedJobs: append([]CounterJob(nil), s.counterJobs[baseKey]...),
		Notes:       append([]string(nil), s.counterNotes[baseKey]...),
	}
	return detail, nil
}

// NextCounter advances the counter and records audit-friendly history.
func (s *StaticService) NextCounter(_ context.Context, _ string, name string, opts CounterNextOptions) (CounterNextOutcome, error) {
	if s == nil {
		return CounterNextOutcome{}, ErrNotConfigured
	}
	idx := s.findCounterIndex(name)
	if idx == -1 {
		return CounterNextOutcome{}, ErrCounterNotFound
	}
	if s.counterHistory == nil {
		s.counterHistory = make(map[string][]CounterEvent)
	}
	if s.counterNotes == nil {
		s.counterNotes = make(map[string][]string)
	}

	amount := opts.Amount
	if amount == 0 {
		increment := s.counters[idx].Increment
		if increment == 0 {
			increment = 1
		}
		amount = increment
	}

	now := time.Now()
	s.counters[idx].CurrentValue += amount
	s.counters[idx].LastUpdated = now

	scope := copyScope(opts.Scope)
	auditID := fmt.Sprintf("AUD-%d", now.UnixNano())
	actor := fallbackString(opts.Actor, "admin@hanko.local")
	message := fallbackString(opts.Reason, "手動採番テスト")

	outcome := CounterNextOutcome{
		Name:       s.counters[idx].Name,
		Scope:      scope,
		Value:      s.counters[idx].CurrentValue,
		Message:    fmt.Sprintf("次の番号: %d", s.counters[idx].CurrentValue),
		AuditID:    auditID,
		OccurredAt: now,
	}

	event := CounterEvent{
		ID:         fmt.Sprintf("evt-%d", now.UnixNano()),
		OccurredAt: now,
		Actor:      actor,
		ActorEmail: actor,
		Scope:      scope,
		Delta:      amount,
		Value:      outcome.Value,
		Message:    message,
		Source:     "admin-ui",
		AuditID:    auditID,
	}

	historyKey := counterHistoryKey(s.counters[idx].Namespace, s.counters[idx].Name, scope)
	s.counterHistory[historyKey] = prependCounterEvent(s.counterHistory[historyKey], event)

	baseKey := counterBaseKey(s.counters[idx].Namespace, s.counters[idx].Name)
	note := fmt.Sprintf("%s が %d 進めて %d になりました。", actor, amount, outcome.Value)
	s.counterNotes[baseKey] = prependCounterNote(s.counterNotes[baseKey], fmt.Sprintf("%s (%s)", note, now.Format(time.RFC3339)))

	return outcome, nil
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

func matchesJobType(filter []JobType, value JobType) bool {
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

func matchesJobState(filter []JobState, value JobState) bool {
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

func (s *StaticService) findCounterIndex(name string) int {
	target := strings.ToLower(strings.TrimSpace(name))
	for i, counter := range s.counters {
		if strings.ToLower(counter.Name) == target {
			return i
		}
	}
	return -1
}

func matchesCounterSearch(search string, counter Counter) bool {
	fields := []string{
		counter.Name,
		counter.Label,
		counter.Description,
		counter.Namespace,
		counter.Owner,
	}
	for _, tag := range counter.Tags {
		fields = append(fields, tag)
	}
	if counter.Alert != nil {
		fields = append(fields, counter.Alert.Title, counter.Alert.Message)
	}
	for _, field := range fields {
		if strings.Contains(strings.ToLower(field), search) {
			return true
		}
	}
	for key, value := range counter.ScopeExample {
		if strings.Contains(strings.ToLower(key), search) || strings.Contains(strings.ToLower(value), search) {
			return true
		}
	}
	return false
}

func copyScope(input map[string]string) map[string]string {
	if len(input) == 0 {
		return nil
	}
	cloned := make(map[string]string, len(input))
	for key, value := range input {
		cloned[key] = value
	}
	return cloned
}

func counterHistoryKey(namespace, name string, scope map[string]string) string {
	ns := strings.ToLower(strings.TrimSpace(namespace))
	if ns == "" {
		ns = "default"
	}
	nm := strings.ToLower(strings.TrimSpace(name))
	parts := make([]string, 0, len(scope))
	for key, value := range scope {
		parts = append(parts, fmt.Sprintf("%s=%s", strings.ToLower(strings.TrimSpace(key)), strings.ToLower(strings.TrimSpace(value))))
	}
	sort.Strings(parts)
	scopeKey := strings.Join(parts, "&")
	if scopeKey == "" {
		scopeKey = "default"
	}
	return fmt.Sprintf("%s/%s?%s", ns, nm, scopeKey)
}

func counterBaseKey(namespace, name string) string {
	ns := strings.ToLower(strings.TrimSpace(namespace))
	if ns == "" {
		ns = "default"
	}
	nm := strings.ToLower(strings.TrimSpace(name))
	return fmt.Sprintf("%s/%s", ns, nm)
}

func prependCounterEvent(events []CounterEvent, event CounterEvent) []CounterEvent {
	updated := append([]CounterEvent{event}, events...)
	if len(updated) > 10 {
		updated = updated[:10]
	}
	return updated
}

func prependCounterNote(notes []string, note string) []string {
	updated := append([]string{note}, notes...)
	if len(updated) > 10 {
		updated = updated[:10]
	}
	return updated
}

func fallbackString(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}

func titleCase(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "default"
	}
	lower := strings.ToLower(value)
	runes := []rune(lower)
	if len(runes) == 0 {
		return value
	}
	runes[0] = unicode.ToUpper(runes[0])
	return string(runes)
}

func matchesJobHost(filter []string, value string) bool {
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

func matchesJobWindow(window string, nextRun time.Time, now time.Time) bool {
	window = strings.TrimSpace(window)
	if window == "" || window == "all" {
		return true
	}
	if nextRun.IsZero() {
		return false
	}
	switch window {
	case "overdue":
		return nextRun.Before(now)
	case "30m":
		return !nextRun.Before(now) && nextRun.Before(now.Add(30*time.Minute))
	case "1h":
		return !nextRun.Before(now) && nextRun.Before(now.Add(time.Hour))
	case "6h":
		return !nextRun.Before(now) && nextRun.Before(now.Add(6*time.Hour))
	case "24h":
		return !nextRun.Before(now) && nextRun.Before(now.Add(24*time.Hour))
	default:
		return true
	}
}

func matchesJobSearch(search string, job Job) bool {
	search = strings.TrimSpace(strings.ToLower(search))
	if search == "" {
		return true
	}
	fields := []string{
		job.ID,
		job.Name,
		job.Description,
		job.Host,
		job.Schedule,
		job.Queue,
		job.LastRun.TriggeredBy,
		job.LastRun.Worker,
	}
	for _, f := range fields {
		if strings.Contains(strings.ToLower(f), search) {
			return true
		}
	}
	for _, tag := range job.Tags {
		if strings.Contains(strings.ToLower(tag), search) {
			return true
		}
	}
	return false
}

func (s *StaticService) buildJobFilterSummary(now time.Time) JobFilterSummary {
	typeCounts := make(map[JobType]int)
	stateCounts := make(map[JobState]int)
	hostCounts := make(map[string]int)
	for _, job := range s.jobs {
		typeCounts[job.Type]++
		stateCounts[job.State]++
		hostCounts[job.Host]++
	}
	windows := []JobWindowOption{
		{Value: "overdue", Label: "期限超過", Count: countJobsByWindow(s.jobs, now, "overdue")},
		{Value: "30m", Label: "30分以内", Count: countJobsByWindow(s.jobs, now, "30m")},
		{Value: "1h", Label: "1時間以内", Count: countJobsByWindow(s.jobs, now, "1h")},
		{Value: "6h", Label: "6時間以内", Count: countJobsByWindow(s.jobs, now, "6h")},
		{Value: "24h", Label: "24時間以内", Count: countJobsByWindow(s.jobs, now, "24h")},
	}
	return JobFilterSummary{
		TypeCounts:  typeCounts,
		StateCounts: stateCounts,
		HostCounts:  hostCounts,
		Windows:     windows,
	}
}

func countJobsByWindow(jobs []Job, now time.Time, window string) int {
	count := 0
	for _, job := range jobs {
		if matchesJobWindow(window, job.NextRun, now) {
			count++
		}
	}
	return count
}

func ptrTime(t time.Time) *time.Time {
	return &t
}
