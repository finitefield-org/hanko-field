package finance

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

// StaticService provides deterministic fixture data for local development and tests.
type StaticService struct {
	mu             sync.RWMutex
	ruleSeq        int
	jurisdictions  map[string]*jurisdictionRecord
	regions        map[string]string
	policyLinks    []PolicyLink
	reconciliation reconciliationRecord
}

type jurisdictionRecord struct {
	id            string
	regionID      string
	metadata      JurisdictionMetadata
	rules         []TaxRule
	registrations []TaxRegistration
	history       []AuditEvent
}

type reconciliationRecord struct {
	summary ReconciliationSummary
	reports map[string]*ReconciliationReport
	jobs    map[string]*ReconciliationJob
	history []AuditEvent
}

// NewStaticService constructs a StaticService seeded with representative tax configuration data.
func NewStaticService() *StaticService {
	now := time.Now().UTC()
	makeTime := func(year int, month time.Month, day int) time.Time {
		return time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	}

	service := &StaticService{
		jurisdictions: make(map[string]*jurisdictionRecord),
		regions: map[string]string{
			"apac": "アジア太平洋",
			"emea": "欧州・中東・アフリカ",
			"amer": "北米",
		},
		policyLinks: []PolicyLink{
			{Label: "OECD Tax Database", Href: "https://www.oecd.org/tax/tax-policy/tax-database/"},
			{Label: "Japan Consumption Tax Guide", Href: "https://www.nta.go.jp/taxes/shiraberu/zeimokubetsu/shohi/"},
			{Label: "EU VAT Rates", Href: "https://taxation-customs.ec.europa.eu/taxation-1/value-added-tax-vat_en"},
		},
	}

	lastReconRun := now.Add(-4 * time.Hour)
	nextReconRun := lastReconRun.Add(20 * time.Hour)
	staleReconRun := now.Add(-26 * time.Hour)
	staleNextRun := staleReconRun.Add(24 * time.Hour)
	dailyExpiry := lastReconRun.Add(14 * 24 * time.Hour)
	staleExpiry := staleReconRun.Add(7 * 24 * time.Hour)

	service.reconciliation = reconciliationRecord{
		summary: ReconciliationSummary{
			LastRunAt:             lastReconRun,
			LastRunBy:             "自動ジョブ",
			LastRunStatus:         "成功",
			LastRunStatusTone:     "success",
			LastRunDuration:       3*time.Minute + 42*time.Second,
			PendingExceptions:     2,
			PendingAmountMinor:    128_900,
			PendingAmountCurrency: "JPY",
			NextScheduledAt:       &nextReconRun,
		},
		reports: map[string]*ReconciliationReport{
			"daily-payouts": {
				ID:              "daily-payouts",
				Label:           "日次ペイアウトレポート",
				Description:     "Stripe/ZEUSのペイアウトと内部台帳を照合するCSVエクスポートです。",
				Format:          "CSV",
				Status:          "最新",
				StatusTone:      "success",
				LastGeneratedAt: lastReconRun,
				LastGeneratedBy: "自動ジョブ",
				DownloadURL:     "https://downloads.example.com/reports/daily-payouts-20240401.csv",
				FileSizeBytes:   38_912,
				ExpiresAt:       &dailyExpiry,
				BackgroundJobID: "job-reconciliation-daily",
			},
			"unsettled-transactions": {
				ID:              "unsettled-transactions",
				Label:           "未決済トランザクション",
				Description:     "未入金・保留中の支払いを一覧化し、照合漏れを検知するためのレポートです。",
				Format:          "CSV",
				Status:          "要更新",
				StatusTone:      "warning",
				LastGeneratedAt: staleReconRun,
				LastGeneratedBy: "自動ジョブ",
				DownloadURL:     "https://downloads.example.com/reports/unsettled-transactions-20240331.csv",
				FileSizeBytes:   52_224,
				ExpiresAt:       &staleExpiry,
				BackgroundJobID: "job-reconciliation-unsettled",
			},
		},
		jobs: map[string]*ReconciliationJob{
			"job-reconciliation-daily": {
				ID:              "job-reconciliation-daily",
				Label:           "日次ペイアウト照合",
				Schedule:        "毎日 06:00 JST",
				Status:          "成功",
				StatusTone:      "success",
				LastRunAt:       lastReconRun,
				LastRunDuration: 2*time.Minute + 8*time.Second,
				NextRunAt:       &nextReconRun,
			},
			"job-reconciliation-unsettled": {
				ID:              "job-reconciliation-unsettled",
				Label:           "未決済トランザクション集計",
				Schedule:        "毎日 07:00 JST",
				Status:          "警告",
				StatusTone:      "warning",
				LastRunAt:       staleReconRun,
				LastRunDuration: 95 * time.Second,
				NextRunAt:       &staleNextRun,
				LastError:       "PSP APIのレートリミットにより一部データが欠落しました。",
			},
		},
		history: []AuditEvent{
			{
				ID:        "audit-recon-002",
				Timestamp: lastReconRun,
				Actor:     "自動ジョブ",
				Action:    "日次リコンシリエーションを実行",
				Details:   "Stripeペイアウト #po_8F2 を同期。2件の調整が必要です。",
				Tone:      "info",
			},
			{
				ID:        "audit-recon-001",
				Timestamp: now.Add(-48 * time.Hour),
				Actor:     "吉田 恵",
				Action:    "手動で照合レポートを再生成",
				Details:   "ZEUS支払いの差異を確認し調整しました。",
				Tone:      "success",
			},
		},
	}

	service.jurisdictions["jp"] = &jurisdictionRecord{
		id:       "jp",
		regionID: "apac",
		metadata: JurisdictionMetadata{
			ID:             "jp",
			Country:        "日本",
			Region:         service.regions["apac"],
			Code:           "JP",
			Currency:       "JPY",
			DefaultRate:    10.0,
			ReducedRate:    ptrFloat(8.0),
			UpdatedAt:      now.Add(-48 * time.Hour),
			UpdatedBy:      "中田 千佳",
			RegistrationID: "T123456789012",
			Notes: []string{
				"標準税率は2023/10改定後の10%を適用。",
				"酒類および嗜好品は軽減税率適用外。",
			},
		},
		rules: []TaxRule{
			{
				ID:                   "rule-jp-standard-20231001",
				Label:                "標準税率",
				Scope:                "standard",
				ScopeLabel:           "標準課税",
				Type:                 "consumption",
				RatePercent:          10.0,
				ThresholdMinor:       0,
				ThresholdCurrency:    "JPY",
				EffectiveFrom:        makeTime(2023, 10, 1),
				EffectiveTo:          nil,
				RegistrationNumber:   "T123456789012",
				RegistrationLabel:    "適格請求書登録番号",
				RequiresRegistration: true,
				Default:              true,
				Status:               "運用中",
				StatusTone:           "success",
				UpdatedAt:            now.Add(-48 * time.Hour),
				UpdatedBy:            "中田 千佳",
			},
			{
				ID:                   "rule-jp-standard-20241001",
				Label:                "標準税率（改定予定）",
				Scope:                "standard",
				ScopeLabel:           "標準課税",
				Type:                 "consumption",
				RatePercent:          11.0,
				ThresholdMinor:       0,
				ThresholdCurrency:    "JPY",
				EffectiveFrom:        makeTime(2024, 10, 1),
				EffectiveTo:          nil,
				RequiresRegistration: true,
				Default:              true,
				Status:               "予定",
				StatusTone:           "warning",
				Notes: []string{
					"政府案ベース。確定次第更新。",
				},
				UpdatedAt: now.Add(-2 * time.Hour),
				UpdatedBy: "財務企画チーム",
			},
			{
				ID:                   "rule-jp-reduced",
				Label:                "軽減税率（飲食料品）",
				Scope:                "reduced",
				ScopeLabel:           "軽減課税",
				Type:                 "consumption",
				RatePercent:          8.0,
				ThresholdMinor:       0,
				ThresholdCurrency:    "JPY",
				EffectiveFrom:        makeTime(2019, 10, 1),
				EffectiveTo:          nil,
				RegistrationNumber:   "T123456789012",
				RegistrationLabel:    "適格請求書登録番号",
				RequiresRegistration: true,
				Status:               "運用中",
				StatusTone:           "success",
				Notes: []string{
					"テイクアウト含む。",
					"酒類は対象外。",
				},
				UpdatedAt: now.Add(-72 * time.Hour),
				UpdatedBy: "佐藤 真一",
			},
		},
		registrations: []TaxRegistration{
			{
				ID:         "reg-jp-qualified-invoice",
				Label:      "適格請求書発行事業者登録",
				Number:     "T123456789012",
				IssuedAt:   makeTime(2023, 7, 1),
				Status:     "有効",
				StatusTone: "success",
			},
		},
		history: []AuditEvent{
			{
				ID:        "audit-jp-001",
				Timestamp: now.Add(-48 * time.Hour),
				Actor:     "中田 千佳",
				Action:    "税率を10%に更新",
				Details:   "標準税率を2023/10/01から適用",
				Tone:      "success",
			},
			{
				ID:        "audit-jp-002",
				Timestamp: now.Add(-2 * time.Hour),
				Actor:     "財務企画チーム",
				Action:    "標準税率改定案を下書き",
				Details:   "2024/10/01から11%案を登録",
				Tone:      "warning",
			},
		},
	}

	service.jurisdictions["au"] = &jurisdictionRecord{
		id:       "au",
		regionID: "apac",
		metadata: JurisdictionMetadata{
			ID:          "au",
			Country:     "オーストラリア",
			Region:      service.regions["apac"],
			Code:        "AU",
			Currency:    "AUD",
			DefaultRate: 10.0,
			UpdatedAt:   now.Add(-24 * time.Hour),
			UpdatedBy:   "Liam Chen",
			Notes: []string{
				"GSTは地域差なし。売上閾値は$75,000。",
			},
		},
		rules: []TaxRule{
			{
				ID:                "rule-au-standard",
				Label:             "GST標準税率",
				Scope:             "standard",
				ScopeLabel:        "標準課税",
				Type:              "gst",
				RatePercent:       10.0,
				ThresholdMinor:    7500000,
				ThresholdCurrency: "AUD",
				EffectiveFrom:     makeTime(2000, 7, 1),
				Default:           true,
				Status:            "運用中",
				StatusTone:        "success",
				UpdatedAt:         now.Add(-24 * time.Hour),
				UpdatedBy:         "Liam Chen",
			},
		},
		history: []AuditEvent{
			{
				ID:        "audit-au-001",
				Timestamp: now.Add(-24 * time.Hour),
				Actor:     "Liam Chen",
				Action:    "GST 閾値を更新",
				Details:   "$75k売上閾値を再確認",
				Tone:      "info",
			},
		},
	}

	service.jurisdictions["de"] = &jurisdictionRecord{
		id:       "de",
		regionID: "emea",
		metadata: JurisdictionMetadata{
			ID:             "de",
			Country:        "ドイツ",
			Region:         service.regions["emea"],
			Code:           "DE",
			Currency:       "EUR",
			DefaultRate:    19.0,
			ReducedRate:    ptrFloat(7.0),
			UpdatedAt:      now.Add(-6 * time.Hour),
			UpdatedBy:      "Anna Weiss",
			RegistrationID: "DE123456789",
			Notes: []string{
				"OSS制度経由で申告予定。",
			},
		},
		rules: []TaxRule{
			{
				ID:                   "rule-de-standard",
				Label:                "標準税率",
				Scope:                "standard",
				ScopeLabel:           "標準課税",
				Type:                 "vat",
				RatePercent:          19.0,
				ThresholdMinor:       0,
				ThresholdCurrency:    "EUR",
				EffectiveFrom:        makeTime(2014, 1, 1),
				Default:              true,
				Status:               "運用中",
				StatusTone:           "success",
				RegistrationNumber:   "DE123456789",
				RequiresRegistration: true,
				UpdatedAt:            now.Add(-6 * time.Hour),
				UpdatedBy:            "Anna Weiss",
			},
			{
				ID:                   "rule-de-reduced",
				Label:                "軽減税率",
				Scope:                "reduced",
				ScopeLabel:           "軽減課税",
				Type:                 "vat",
				RatePercent:          7.0,
				ThresholdMinor:       0,
				ThresholdCurrency:    "EUR",
				EffectiveFrom:        makeTime(2014, 1, 1),
				Status:               "運用中",
				StatusTone:           "success",
				RegistrationNumber:   "DE123456789",
				RequiresRegistration: true,
				UpdatedAt:            now.Add(-6 * time.Hour),
				UpdatedBy:            "Anna Weiss",
			},
		},
		registrations: []TaxRegistration{
			{
				ID:         "reg-de-vat",
				Label:      "VAT 登録番号",
				Number:     "DE123456789",
				IssuedAt:   makeTime(2022, 4, 15),
				Status:     "有効",
				StatusTone: "success",
			},
		},
		history: []AuditEvent{
			{
				ID:        "audit-de-001",
				Timestamp: now.Add(-6 * time.Hour),
				Actor:     "Anna Weiss",
				Action:    "OSS経由の申告切替",
				Details:   "2024/04からOSS申告へ移行",
				Tone:      "info",
			},
		},
	}

	service.jurisdictions["us-ca"] = &jurisdictionRecord{
		id:       "us-ca",
		regionID: "amer",
		metadata: JurisdictionMetadata{
			ID:          "us-ca",
			Country:     "米国（カリフォルニア州）",
			Region:      service.regions["amer"],
			Code:        "US-CA",
			Currency:    "USD",
			DefaultRate: 7.25,
			UpdatedAt:   now.Add(-12 * time.Hour),
			UpdatedBy:   "Jordan Smith",
			Notes: []string{
				"州税 6.0% + 地方税平均 1.25%。",
			},
		},
		rules: []TaxRule{
			{
				ID:                "rule-us-ca-state",
				Label:             "州税",
				Scope:             "state",
				ScopeLabel:        "州税",
				Type:              "sales_tax",
				RatePercent:       6.0,
				ThresholdMinor:    5000000,
				ThresholdCurrency: "USD",
				EffectiveFrom:     makeTime(2017, 1, 1),
				Default:           true,
				Status:            "運用中",
				StatusTone:        "success",
				UpdatedAt:         now.Add(-12 * time.Hour),
				UpdatedBy:         "Jordan Smith",
			},
			{
				ID:                "rule-us-ca-local",
				Label:             "地方税平均",
				Scope:             "local",
				ScopeLabel:        "地方税",
				Type:              "sales_tax",
				RatePercent:       1.25,
				ThresholdMinor:    0,
				ThresholdCurrency: "USD",
				EffectiveFrom:     makeTime(2017, 1, 1),
				Status:            "運用中",
				StatusTone:        "info",
				UpdatedAt:         now.Add(-12 * time.Hour),
				UpdatedBy:         "Jordan Smith",
			},
		},
		history: []AuditEvent{
			{
				ID:        "audit-us-ca-001",
				Timestamp: now.Add(-12 * time.Hour),
				Actor:     "Jordan Smith",
				Action:    "地方税平均値を更新",
				Details:   "2024/01の最新データ反映",
				Tone:      "info",
			},
		},
	}

	// Compute initial stats to ensure metadata matches rule set.
	for _, record := range service.jurisdictions {
		recomputeJurisdictionMetadata(record)
	}

	return service
}

// ReconciliationDashboard returns the current reconciliation overview.
func (s *StaticService) ReconciliationDashboard(_ context.Context, _ string) (ReconciliationDashboard, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.reconciliation.snapshot(), nil
}

// TriggerReconciliation simulates enqueuing a reconciliation job run and returns the refreshed dashboard.
func (s *StaticService) TriggerReconciliation(_ context.Context, _ string) (ReconciliationDashboard, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	state := &s.reconciliation
	if state.summary.TriggerDisabled {
		dashboard := state.snapshot()
		reason := strings.TrimSpace(state.summary.TriggerDisabledReason)
		if reason != "" {
			alert := Alert{
				Tone:  "danger",
				Title: "手動実行は現在無効化されています",
				Body:  reason,
			}
			dashboard.Alerts = append([]Alert{alert}, dashboard.Alerts...)
		}
		return dashboard, nil
	}

	now := time.Now().UTC()
	actor := "山田 芽衣"
	state.summary.LastRunAt = now
	state.summary.LastRunBy = actor
	state.summary.LastRunStatus = "成功"
	state.summary.LastRunStatusTone = "success"
	state.summary.LastRunDuration = 2*time.Minute + 18*time.Second
	state.summary.PendingExceptions = 0
	state.summary.PendingAmountMinor = 0
	nextRun := now.Add(24 * time.Hour)
	state.summary.NextScheduledAt = &nextRun

	for id, report := range state.reports {
		report.LastGeneratedAt = now
		report.LastGeneratedBy = actor
		report.Status = "最新"
		report.StatusTone = "success"
		if report.FileSizeBytes == 0 {
			report.FileSizeBytes = 42_000
		} else {
			report.FileSizeBytes += 1_024
		}
		filenameSuffix := now.Format("20060102-150405")
		report.DownloadURL = fmt.Sprintf("https://downloads.example.com/reports/%s-%s.%s", id, filenameSuffix, strings.ToLower(report.Format))
		expiry := now.Add(14 * 24 * time.Hour)
		report.ExpiresAt = &expiry
	}

	for _, job := range state.jobs {
		job.Status = "成功"
		job.StatusTone = "success"
		job.LastRunAt = now
		job.LastError = ""
		switch job.ID {
		case "job-reconciliation-daily":
			job.LastRunDuration = 2*time.Minute + 5*time.Second
		case "job-reconciliation-unsettled":
			job.LastRunDuration = 2*time.Minute + 20*time.Second
		default:
			job.LastRunDuration = 90 * time.Second
		}
		next := now.Add(24 * time.Hour)
		job.NextRunAt = &next
	}

	event := AuditEvent{
		ID:        fmt.Sprintf("audit-recon-%d", now.Unix()),
		Timestamp: now,
		Actor:     actor,
		Action:    "照合レポートを手動実行",
		Details:   "日次ペイアウトおよび未決済レポートを再生成しました。",
		Tone:      "success",
	}
	state.history = append([]AuditEvent{event}, state.history...)
	if len(state.history) > 20 {
		state.history = state.history[:20]
	}

	return state.snapshot(), nil
}

func (r *reconciliationRecord) snapshot() ReconciliationDashboard {
	dashboard := ReconciliationDashboard{}
	dashboard.Summary = r.summary
	dashboard.Summary.NextScheduledAt = cloneTimePtr(r.summary.NextScheduledAt)

	reports := make([]ReconciliationReport, 0, len(r.reports))
	for _, report := range r.reports {
		cp := *report
		cp.ExpiresAt = cloneTimePtr(report.ExpiresAt)
		reports = append(reports, cp)
	}
	sort.Slice(reports, func(i, j int) bool {
		if reports[i].Label == reports[j].Label {
			return reports[i].ID < reports[j].ID
		}
		return reports[i].Label < reports[j].Label
	})
	dashboard.Reports = reports

	jobs := make([]ReconciliationJob, 0, len(r.jobs))
	for _, job := range r.jobs {
		cp := *job
		cp.NextRunAt = cloneTimePtr(job.NextRunAt)
		jobs = append(jobs, cp)
	}
	sort.Slice(jobs, func(i, j int) bool {
		if jobs[i].Label == jobs[j].Label {
			return jobs[i].ID < jobs[j].ID
		}
		return jobs[i].Label < jobs[j].Label
	})
	dashboard.Jobs = jobs

	if len(r.history) > 0 {
		history := make([]AuditEvent, len(r.history))
		copy(history, r.history)
		dashboard.History = history
	}

	dashboard.Alerts = r.buildAlerts(reports, jobs)
	return dashboard
}

func (r *reconciliationRecord) buildAlerts(reports []ReconciliationReport, jobs []ReconciliationJob) []Alert {
	alerts := make([]Alert, 0, 4)
	summary := r.summary
	if summary.PendingExceptions > 0 {
		amount := ""
		if summary.PendingAmountMinor > 0 && summary.PendingAmountCurrency != "" {
			amount = fmt.Sprintf("%s %.2f", summary.PendingAmountCurrency, float64(summary.PendingAmountMinor)/100)
		}
		body := "未処理の照合例外を確認してください。"
		if amount != "" {
			body = fmt.Sprintf("差異合計: %s。未処理キューで確認してください。", amount)
		}
		alerts = append(alerts, Alert{
			Tone:  "warning",
			Title: fmt.Sprintf("%d件の照合例外", summary.PendingExceptions),
			Body:  body,
		})
	}
	if summary.TriggerDisabled {
		reason := strings.TrimSpace(summary.TriggerDisabledReason)
		if reason != "" {
			alerts = append(alerts, Alert{
				Tone:  "danger",
				Title: "手動実行がロックされています",
				Body:  reason,
			})
		}
	}
	for _, report := range reports {
		switch report.StatusTone {
		case "warning":
			alerts = append(alerts, Alert{
				Tone:  "warning",
				Title: fmt.Sprintf("%sの再生成が必要です", report.Label),
				Body:  fmt.Sprintf("最終生成: %s", report.LastGeneratedAt.Local().Format("2006/01/02 15:04")),
			})
		case "danger":
			alerts = append(alerts, Alert{
				Tone:  "danger",
				Title: fmt.Sprintf("%sが最新ではありません", report.Label),
				Body:  "バックグラウンドジョブのログを確認してください。",
			})
		}
	}
	for _, job := range jobs {
		switch job.StatusTone {
		case "warning":
			alerts = append(alerts, Alert{
				Tone:  "warning",
				Title: fmt.Sprintf("%sが警告状態です", job.Label),
				Body:  firstNonEmpty(job.LastError, "次回の実行結果を確認してください。"),
			})
		case "danger":
			alerts = append(alerts, Alert{
				Tone:  "danger",
				Title: fmt.Sprintf("%sが失敗しています", job.Label),
				Body:  firstNonEmpty(job.LastError, "ジョブの再実行が必要です。"),
			})
		}
	}
	return alerts
}

func cloneTimePtr(src *time.Time) *time.Time {
	if src == nil {
		return nil
	}
	val := *src
	return &val
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		candidate := strings.TrimSpace(v)
		if candidate != "" {
			return candidate
		}
	}
	return ""
}

// Jurisdictions returns grouped nav and summary data.
func (s *StaticService) Jurisdictions(_ context.Context, _ string, query JurisdictionsQuery) (JurisdictionsResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	now := time.Now().UTC()
	result := JurisdictionsResult{
		Summary: JurisdictionSummaryStats{
			LastSyncedAt: now,
		},
		PolicyLinks: append([]PolicyLink(nil), s.policyLinks...),
	}

	regionBuckets := make(map[string]*RegionGroup, len(s.regions))
	lowerSearch := strings.ToLower(strings.TrimSpace(query.Search))

	soonestPending := make([]string, 0)
	soonestWindow := now.Add(30 * 24 * time.Hour)

	for _, record := range s.jurisdictions {
		if query.Region != "" && !strings.EqualFold(query.Region, record.regionID) {
			continue
		}
		if query.Country != "" {
			if !strings.EqualFold(query.Country, record.metadata.ID) && !strings.EqualFold(query.Country, record.metadata.Code) {
				continue
			}
		}

		if lowerSearch != "" && !record.matches(lowerSearch) {
			continue
		}

		active := isJurisdictionActive(record, now)
		if query.OnlyActive && !active {
			continue
		}

		pending := hasPendingRule(record, now)
		if pending {
			for _, rule := range record.rules {
				if rule.EffectiveFrom.After(now) && rule.EffectiveFrom.Before(soonestWindow) {
					soonestPending = append(soonestPending, fmt.Sprintf("%s (%s)", record.metadata.Country, rule.EffectiveFrom.Format("2006/01/02")))
					break
				}
			}
		}

		if active {
			result.Summary.ActiveJurisdictions++
		} else if pending {
			result.Summary.PendingJurisdictions++
		} else {
			result.Summary.ExpiredJurisdictions++
		}

		if requiresRegistration(record) {
			result.Summary.RegistrationsRequired++
		}

		group := regionBuckets[record.regionID]
		if group == nil {
			group = &RegionGroup{
				ID:    record.regionID,
				Label: record.metadata.Region,
			}
			regionBuckets[record.regionID] = group
		}

		group.Countries = append(group.Countries, CountryNav{
			ID:              record.metadata.ID,
			Label:           record.metadata.Country,
			Region:          record.metadata.Region,
			Code:            record.metadata.Code,
			Active:          active,
			PendingChanges:  pending,
			JurisdictionID:  record.metadata.ID,
			RegistrationTag: firstRegistrationTag(record),
			Selected:        strings.EqualFold(query.SelectedID, record.metadata.ID),
		})

		result.Jurisdictions = append(result.Jurisdictions, buildJurisdictionSummary(record, now))
	}

	if len(soonestPending) > 0 && query.IncludeSoon {
		result.Alerts = append(result.Alerts, Alert{
			Tone:  "warning",
			Title: "間もなく税率が更新される地域があります。",
			Body:  strings.Join(soonestPending, " / "),
			Action: &AlertAction{
				Label: "ステータスを確認",
				Href:  "#upcoming",
			},
		})
	}

	regions := make([]RegionGroup, 0, len(regionBuckets))
	for _, group := range regionBuckets {
		sort.Slice(group.Countries, func(i, j int) bool {
			return compareLex(group.Countries[i].Label, group.Countries[j].Label) < 0
		})
		group.Count = len(group.Countries)
		regions = append(regions, *group)
	}
	sort.Slice(regions, func(i, j int) bool {
		return compareLex(regions[i].Label, regions[j].Label) < 0
	})
	sort.Slice(result.Jurisdictions, func(i, j int) bool {
		if result.Jurisdictions[i].Region == result.Jurisdictions[j].Region {
			return compareLex(result.Jurisdictions[i].Country, result.Jurisdictions[j].Country) < 0
		}
		return compareLex(result.Jurisdictions[i].Region, result.Jurisdictions[j].Region) < 0
	})

	result.Regions = regions

	return result, nil
}

// JurisdictionDetail returns the detail payload for the jurisdiction.
func (s *StaticService) JurisdictionDetail(_ context.Context, _ string, jurisdictionID string) (JurisdictionDetail, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	record, ok := s.jurisdictions[jurisdictionID]
	if !ok {
		return JurisdictionDetail{}, ErrJurisdictionNotFound
	}

	detail := JurisdictionDetail{
		Metadata:      copyMetadata(record.metadata),
		Rules:         copyRules(record.rules),
		Registrations: copyRegistrations(record.registrations),
		History:       copyHistory(record.history),
		Alerts:        buildJurisdictionAlerts(record),
	}

	sort.Slice(detail.Rules, func(i, j int) bool {
		ri := detail.Rules[i]
		rj := detail.Rules[j]
		if ri.Scope == rj.Scope {
			if ri.EffectiveFrom.Equal(rj.EffectiveFrom) {
				return compareLex(ri.Label, rj.Label) < 0
			}
			return ri.EffectiveFrom.Before(rj.EffectiveFrom)
		}
		return compareLex(ri.ScopeLabel, rj.ScopeLabel) < 0
	})

	sort.Slice(detail.History, func(i, j int) bool {
		return detail.History[i].Timestamp.After(detail.History[j].Timestamp)
	})

	return detail, nil
}

// UpsertTaxRule creates or updates a rule.
func (s *StaticService) UpsertTaxRule(_ context.Context, _ string, jurisdictionID string, input TaxRuleInput) (JurisdictionDetail, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.jurisdictions[jurisdictionID]
	if !ok {
		return JurisdictionDetail{}, ErrJurisdictionNotFound
	}

	if verr := validateTaxRuleInput(record, input); verr != nil {
		return JurisdictionDetail{}, verr
	}

	now := time.Now().UTC()
	rule := TaxRule{
		ID:                   input.RuleID,
		Label:                strings.TrimSpace(input.Label),
		Scope:                strings.TrimSpace(input.Scope),
		ScopeLabel:           resolveScopeLabel(input.Scope, input.Type),
		Type:                 strings.TrimSpace(input.Type),
		RatePercent:          input.RatePercent,
		ThresholdMinor:       input.ThresholdMinor,
		ThresholdCurrency:    strings.ToUpper(strings.TrimSpace(input.ThresholdCurrency)),
		EffectiveFrom:        input.EffectiveFrom.UTC(),
		EffectiveTo:          normalizeOptionalTime(input.EffectiveTo),
		RegistrationNumber:   strings.TrimSpace(input.RegistrationNumber),
		RequiresRegistration: input.RequiresRegistration,
		Default:              input.Default,
		Notes:                append([]string(nil), input.Notes...),
		Status:               statusForRule(input.EffectiveFrom, input.EffectiveTo),
		StatusTone:           statusToneForRule(input.EffectiveFrom, input.EffectiveTo),
		UpdatedAt:            now,
		UpdatedBy:            "Finance Bot",
	}
	rule.RegistrationLabel = registrationLabel(rule.RequiresRegistration)

	replaced := false
	if rule.ID != "" {
		for idx := range record.rules {
			if record.rules[idx].ID == rule.ID {
				record.rules[idx] = rule
				replaced = true
				break
			}
		}
	}

	if !replaced {
		rule.ID = s.nextRuleID(jurisdictionID)
		record.rules = append(record.rules, rule)
	}

	applyDefaultRule(record, rule)
	if !rule.Default {
		ensureDefaultRule(record)
	}

	record.metadata.UpdatedAt = now
	record.metadata.UpdatedBy = rule.UpdatedBy
	recomputeJurisdictionMetadata(record)
	record.history = append(record.history, AuditEvent{
		ID:        fmt.Sprintf("audit-%s-%d", jurisdictionID, now.UnixNano()),
		Timestamp: now,
		Actor:     rule.UpdatedBy,
		Action:    describeRuleChange(replaced, rule),
		Details:   fmt.Sprintf("%s %0.2f%% (%s)", rule.ScopeLabel, rule.RatePercent, rule.EffectiveFrom.Format("2006/01/02")),
		Tone:      rule.StatusTone,
	})

	return s.jurisdictionDetailUnsafe(record), nil
}

// DeleteTaxRule removes a rule.
func (s *StaticService) DeleteTaxRule(_ context.Context, _ string, jurisdictionID, ruleID string) (JurisdictionDetail, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.jurisdictions[jurisdictionID]
	if !ok {
		return JurisdictionDetail{}, ErrJurisdictionNotFound
	}

	if len(record.rules) <= 1 {
		return JurisdictionDetail{}, &TaxRuleValidationError{
			FieldErrors: map[string]string{
				"rule": "少なくとも1つの税率が必要です。",
			},
			Message: ErrTaxRuleInvalid.Error(),
		}
	}

	idx := -1
	for i := range record.rules {
		if record.rules[i].ID == ruleID {
			idx = i
			break
		}
	}
	if idx == -1 {
		return JurisdictionDetail{}, ErrTaxRuleNotFound
	}

	removed := record.rules[idx]
	record.rules = append(record.rules[:idx], record.rules[idx+1:]...)
	if removed.Default {
		ensureDefaultRule(record)
	}

	now := time.Now().UTC()
	record.metadata.UpdatedAt = now
	record.metadata.UpdatedBy = "Finance Bot"
	recomputeJurisdictionMetadata(record)
	record.history = append(record.history, AuditEvent{
		ID:        fmt.Sprintf("audit-%s-%d", jurisdictionID, now.UnixNano()),
		Timestamp: now,
		Actor:     "Finance Bot",
		Action:    fmt.Sprintf("%sを削除", removed.Label),
		Details:   fmt.Sprintf("削除ID: %s", removed.ID),
		Tone:      "danger",
	})

	return s.jurisdictionDetailUnsafe(record), nil
}

func (s *StaticService) nextRuleID(jurisdictionID string) string {
	s.ruleSeq++
	return fmt.Sprintf("rule-%s-%04d", jurisdictionID, s.ruleSeq)
}

func (s *StaticService) jurisdictionDetailUnsafe(record *jurisdictionRecord) JurisdictionDetail {
	return JurisdictionDetail{
		Metadata:      copyMetadata(record.metadata),
		Rules:         copyRules(record.rules),
		Registrations: copyRegistrations(record.registrations),
		History:       copyHistory(record.history),
		Alerts:        buildJurisdictionAlerts(record),
	}
}

func (record *jurisdictionRecord) matches(search string) bool {
	if search == "" {
		return true
	}
	pool := []string{
		record.metadata.Country,
		record.metadata.Region,
		record.metadata.Code,
		record.metadata.ID,
	}
	for _, note := range record.metadata.Notes {
		pool = append(pool, note)
	}
	for _, candidate := range pool {
		if candidate == "" {
			continue
		}
		if strings.Contains(strings.ToLower(candidate), search) {
			return true
		}
	}
	return false
}

func buildJurisdictionSummary(record *jurisdictionRecord, now time.Time) JurisdictionSummary {
	defaultRule := selectDefaultRule(record, now)
	reduced := selectReducedRate(record, defaultRule)
	summary := JurisdictionSummary{
		ID:                record.metadata.ID,
		Country:           record.metadata.Country,
		Region:            record.metadata.Region,
		Code:              record.metadata.Code,
		DefaultRate:       defaultRule.RatePercent,
		ThresholdMinor:    defaultRule.ThresholdMinor,
		ThresholdCurrency: defaultRule.ThresholdCurrency,
		EffectiveFrom:     defaultRule.EffectiveFrom,
		EffectiveTo:       defaultRule.EffectiveTo,
		HasPendingRule:    hasPendingRule(record, now),
		Status:            recordStatus(record, now),
		StatusTone:        recordStatusTone(record, now),
		LastUpdatedAt:     record.metadata.UpdatedAt,
		LastUpdatedBy:     record.metadata.UpdatedBy,
		RegistrationID:    record.metadata.RegistrationID,
		RegistrationName:  firstRegistrationTag(record),
		Notes:             append([]string(nil), record.metadata.Notes...),
	}
	if reduced != nil {
		summary.ReducedRate = ptrFloat(reduced.RatePercent)
	}
	return summary
}

func copyMetadata(meta JurisdictionMetadata) JurisdictionMetadata {
	cpy := meta
	cpy.Notes = append([]string(nil), meta.Notes...)
	return cpy
}

func copyRules(rules []TaxRule) []TaxRule {
	out := make([]TaxRule, len(rules))
	for i := range rules {
		out[i] = rules[i]
		out[i].Notes = append([]string(nil), rules[i].Notes...)
		if rules[i].EffectiveTo != nil {
			end := *rules[i].EffectiveTo
			out[i].EffectiveTo = &end
		}
	}
	return out
}

func copyRegistrations(reg []TaxRegistration) []TaxRegistration {
	out := make([]TaxRegistration, len(reg))
	copy(out, reg)
	return out
}

func copyHistory(events []AuditEvent) []AuditEvent {
	out := make([]AuditEvent, len(events))
	copy(out, events)
	return out
}

func buildJurisdictionAlerts(record *jurisdictionRecord) []Alert {
	now := time.Now().UTC()
	alerts := make([]Alert, 0, 2)
	for _, rule := range record.rules {
		if rule.EffectiveFrom.After(now) && rule.EffectiveFrom.Before(now.Add(30*24*time.Hour)) {
			alerts = append(alerts, Alert{
				Tone:  "warning",
				Title: fmt.Sprintf("%sが%sから有効になります。", rule.Label, rule.EffectiveFrom.Format("2006/01/02")),
				Body:  "商品の税額テストを事前に実施してください。",
			})
		}
		if rule.EffectiveTo != nil && rule.EffectiveTo.Before(now.Add(14*24*time.Hour)) && rule.EffectiveTo.After(now) {
			alerts = append(alerts, Alert{
				Tone:  "danger",
				Title: fmt.Sprintf("%sの有効期限がまもなく切れます。", rule.Label),
				Body:  "後継ルールを登録しないとギャップが発生します。",
			})
		}
	}
	for _, reg := range record.registrations {
		if reg.ExpiresAt != nil && reg.ExpiresAt.Before(now.Add(60*24*time.Hour)) {
			alerts = append(alerts, Alert{
				Tone:  "warning",
				Title: fmt.Sprintf("%sの登録期限が近づいています。", reg.Label),
				Body:  fmt.Sprintf("期限: %s", reg.ExpiresAt.Format("2006/01/02")),
				Action: &AlertAction{
					Label: "更新手続き",
					Href:  "https://www.e-tax.nta.go.jp/",
				},
			})
		}
	}
	return alerts
}

func ptrFloat(val float64) *float64 {
	return &val
}

func compareLex(a, b string) int {
	return strings.Compare(strings.ToLower(a), strings.ToLower(b))
}

func selectDefaultRule(record *jurisdictionRecord, now time.Time) TaxRule {
	var selected *TaxRule
	for idx := range record.rules {
		rule := &record.rules[idx]
		if rule.Default {
			if rule.EffectiveTo != nil && rule.EffectiveTo.Before(now) {
				continue
			}
			if rule.EffectiveFrom.After(now) && selected != nil {
				continue
			}
			if selected == nil || rule.EffectiveFrom.Before(selected.EffectiveFrom) {
				selected = rule
			}
		}
	}
	if selected != nil {
		return *selected
	}
	sort.Slice(record.rules, func(i, j int) bool {
		return record.rules[i].EffectiveFrom.Before(record.rules[j].EffectiveFrom)
	})
	return record.rules[0]
}

func selectReducedRate(record *jurisdictionRecord, defaultRule TaxRule) *TaxRule {
	var candidate *TaxRule
	for idx := range record.rules {
		rule := &record.rules[idx]
		if rule.ID == defaultRule.ID {
			continue
		}
		if candidate == nil || rule.RatePercent < candidate.RatePercent {
			temp := *rule
			candidate = &temp
		}
	}
	return candidate
}

func isJurisdictionActive(record *jurisdictionRecord, now time.Time) bool {
	for idx := range record.rules {
		if ruleActive(&record.rules[idx], now) {
			return true
		}
	}
	return false
}

func hasPendingRule(record *jurisdictionRecord, now time.Time) bool {
	for idx := range record.rules {
		if record.rules[idx].EffectiveFrom.After(now) {
			return true
		}
	}
	return false
}

func ruleActive(rule *TaxRule, now time.Time) bool {
	if rule.EffectiveFrom.After(now) {
		return false
	}
	if rule.EffectiveTo != nil && !rule.EffectiveTo.After(now) {
		return false
	}
	return true
}

func recordStatus(record *jurisdictionRecord, now time.Time) string {
	switch {
	case isJurisdictionActive(record, now):
		return "運用中"
	case hasPendingRule(record, now):
		return "予定"
	default:
		return "停止中"
	}
}

func recordStatusTone(record *jurisdictionRecord, now time.Time) string {
	switch {
	case isJurisdictionActive(record, now):
		return "success"
	case hasPendingRule(record, now):
		return "warning"
	default:
		return "muted"
	}
}

func firstRegistrationTag(record *jurisdictionRecord) string {
	for _, reg := range record.registrations {
		if reg.Number != "" {
			return reg.Number
		}
	}
	return record.metadata.RegistrationID
}

func requiresRegistration(record *jurisdictionRecord) bool {
	if record.metadata.RegistrationID != "" {
		return true
	}
	for _, rule := range record.rules {
		if rule.RequiresRegistration {
			return true
		}
	}
	return false
}

func recomputeJurisdictionMetadata(record *jurisdictionRecord) {
	now := time.Now().UTC()
	defaultRule := selectDefaultRule(record, now)
	record.metadata.DefaultRate = defaultRule.RatePercent
	record.metadata.RegistrationID = firstRegistrationTag(record)
	reduced := selectReducedRate(record, defaultRule)
	if reduced != nil {
		record.metadata.ReducedRate = ptrFloat(reduced.RatePercent)
	} else {
		record.metadata.ReducedRate = nil
	}
}

func applyDefaultRule(record *jurisdictionRecord, candidate TaxRule) {
	if !candidate.Default {
		return
	}
	for idx := range record.rules {
		if record.rules[idx].ID == candidate.ID {
			record.rules[idx].Default = true
			continue
		}
		record.rules[idx].Default = false
	}
}

func ensureDefaultRule(record *jurisdictionRecord) {
	for idx := range record.rules {
		if record.rules[idx].Default {
			return
		}
	}
	if len(record.rules) == 0 {
		return
	}
	record.rules[0].Default = true
}

func describeRuleChange(updated bool, rule TaxRule) string {
	if updated {
		return fmt.Sprintf("%sを更新", rule.Label)
	}
	return fmt.Sprintf("%sを追加", rule.Label)
}

func validateTaxRuleInput(record *jurisdictionRecord, input TaxRuleInput) error {
	fieldErrors := make(map[string]string)

	if strings.TrimSpace(input.Scope) == "" {
		fieldErrors["scope"] = "課税区分を選択してください。"
	}
	if input.RatePercent < 0 {
		fieldErrors["rate"] = "税率は0以上で指定してください。"
	}
	if input.ThresholdMinor < 0 {
		fieldErrors["threshold"] = "閾値は0以上で指定してください。"
	}
	if input.EffectiveFrom.IsZero() {
		fieldErrors["effective_from"] = "適用開始日を入力してください。"
	}
	if input.EffectiveTo != nil && input.EffectiveTo.Before(input.EffectiveFrom) {
		fieldErrors["effective_to"] = "終了日は開始日以降で指定してください。"
	}

	if input.Default {
		for _, rule := range record.rules {
			if rule.ID == input.RuleID {
				continue
			}
			if rule.Default {
				fieldErrors["default"] = "既に既定の税率が存在します。"
				break
			}
		}
	}

	hasOverlap := overlapsRule(record.rules, input)
	if hasOverlap {
		fieldErrors["effective_from"] = "既存の期間と重複しています。"
		fieldErrors["effective_to"] = "既存の期間と重複しています。"
	}

	if len(fieldErrors) > 0 {
		message := ErrTaxRuleInvalid.Error()
		if hasOverlap {
			message = ErrTaxRuleOverlap.Error()
		}
		return &TaxRuleValidationError{
			FieldErrors: fieldErrors,
			Message:     message,
		}
	}
	return nil
}

func overlapsRule(rules []TaxRule, input TaxRuleInput) bool {
	for _, rule := range rules {
		if rule.Scope != input.Scope {
			continue
		}
		if rule.ID == input.RuleID {
			continue
		}
		if timeRangesOverlap(rule.EffectiveFrom, rule.EffectiveTo, input.EffectiveFrom, input.EffectiveTo) {
			return true
		}
	}
	return false
}

func timeRangesOverlap(startA time.Time, endA *time.Time, startB time.Time, endB *time.Time) bool {
	aEnd := endA
	bEnd := endB
	if aEnd == nil && bEnd == nil {
		return true
	}
	if aEnd == nil {
		aEnd = ptrTime(time.Date(9999, 12, 31, 0, 0, 0, 0, time.UTC))
	}
	if bEnd == nil {
		bEnd = ptrTime(time.Date(9999, 12, 31, 0, 0, 0, 0, time.UTC))
	}
	if startA.After(*bEnd) || startB.After(*aEnd) {
		return false
	}
	return !startA.After(*bEnd) && !startB.After(*aEnd)
}

func ptrTime(t time.Time) *time.Time {
	value := t
	return &value
}

func normalizeOptionalTime(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	value := t.UTC()
	return &value
}

func resolveScopeLabel(scope, kind string) string {
	scope = strings.TrimSpace(scope)
	switch strings.ToLower(scope) {
	case "standard":
		return "標準課税"
	case "reduced":
		return "軽減課税"
	case "state":
		return "州税"
	case "local":
		return "地方税"
	default:
		if strings.TrimSpace(kind) != "" {
			return strings.ToUpper(kind)
		}
		return "その他"
	}
}

func statusForRule(from time.Time, to *time.Time) string {
	now := time.Now().UTC()
	switch {
	case from.After(now):
		return "予定"
	case to != nil && to.Before(now):
		return "終了"
	default:
		return "運用中"
	}
}

func statusToneForRule(from time.Time, to *time.Time) string {
	now := time.Now().UTC()
	switch {
	case from.After(now):
		return "warning"
	case to != nil && to.Before(now):
		return "muted"
	default:
		return "success"
	}
}

func registrationLabel(required bool) string {
	if !required {
		return ""
	}
	return "登録番号必須"
}
