package auditlogs

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

// StaticService provides deterministic audit log data for local development and tests.
type StaticService struct {
	mu            sync.RWMutex
	entries       []Entry
	retentionDays int
}

// NewStaticService constructs a StaticService seeded with representative audit data.
func NewStaticService() *StaticService {
	now := time.Now().Truncate(time.Minute)
	makeDiff := func(before, after string) Diff {
		return Diff{
			Before: strings.TrimSpace(before),
			After:  strings.TrimSpace(after),
		}
	}

	entries := []Entry{
		{
			ID:          "aud-20240422-001",
			Action:      "order.status.updated",
			ActionLabel: "注文ステータス更新",
			ActionTone:  "info",
			Actor: Actor{
				ID:        "staff-ops-001",
				Name:      "工房オペレーション",
				Email:     "ops@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/ops.svg",
			},
			Target: Target{
				Reference: "orders/ORD-10421",
				Label:     "#10421 / 山田 太郎",
				Type:      "order",
				URL:       "/orders/order-10421",
			},
			Summary:    "製造ステータスを「刻印待ち」に更新しました。",
			OccurredAt: now.Add(-95 * time.Minute),
			IPAddress:  "203.0.113.24",
			UserAgent:  "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_4) Firefox/124.0",
			Diff: makeDiff(`
{
  "fulfillment_state": "queued",
  "engraving": {
    "scheduled_at": null,
    "operator": null
  }
}`, `
{
  "fulfillment_state": "engraving_waiting",
  "engraving": {
    "scheduled_at": "2024-04-22T10:30:00+09:00",
    "operator": "staff-ops-001"
  }
}`),
			Metadata: map[string]string{
				"実行ID":    "job-ops-4382",
				"リクエストID": "req-13ef9482",
			},
		},
		{
			ID:          "aud-20240422-002",
			Action:      "order.memo.updated",
			ActionLabel: "注文メモ更新",
			ActionTone:  "info",
			Actor: Actor{
				ID:        "staff-cs-004",
				Name:      "カスタマーサポートA",
				Email:     "support.a@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/cs-a.svg",
			},
			Target: Target{
				Reference: "orders/ORD-10421",
				Label:     "#10421 / 山田 太郎",
				Type:      "order",
				URL:       "/orders/order-10421",
			},
			Summary:    "特注文言の修正リクエストを追記しました。",
			OccurredAt: now.Add(-80 * time.Minute),
			IPAddress:  "198.51.100.18",
			UserAgent:  "Chrome/123.0.6312.86 (Windows 11)",
			Diff: makeDiff(`
{
  "notes": [
    {
      "author": "staff-cs-004",
      "body": "刻印は旧漢字で"
    }
  ]
}`, `
{
  "notes": [
    {
      "author": "staff-cs-004",
      "body": "刻印は旧漢字で。発送前に画像共有すること。"
    }
  ]
}`),
			Metadata: map[string]string{
				"チャネル": "メール要望",
			},
		},
		{
			ID:          "aud-20240421-201",
			Action:      "customer.profile.masked",
			ActionLabel: "顧客プロフィールのマスク",
			ActionTone:  "warning",
			Actor: Actor{
				ID:        "staff-privacy-002",
				Name:      "個人情報保護担当",
				Email:     "privacy@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/pd.svg",
			},
			Target: Target{
				Reference: "customers/CUST-9903",
				Label:     "顧客 #9903",
				Type:      "customer",
				URL:       "/customers/CUST-9903",
			},
			Summary:    "退会申請により個人情報を匿名化しました。",
			OccurredAt: now.Add(-6 * time.Hour),
			IPAddress:  "203.0.113.54",
			UserAgent:  "Mozilla/5.0 (X11; Linux x86_64) Safari/604.1",
			Diff: makeDiff(`
{
  "email": "kazuki@example.com",
  "phone": "+81-90-1234-xxxx",
  "addresses": [
    {
      "postal_code": "1500001",
      "line1": "東京都渋谷区神宮前1-1-1"
    }
  ]
}`, `
{
  "email": "masked-9903@example.com",
  "phone": null,
  "addresses": []
}`),
			Metadata: map[string]string{
				"理由":     "本人依頼（メール）",
				"承認者":    "privacy-lead",
				"対応チケット": "CS-5821",
			},
		},
		{
			ID:          "aud-20240421-310",
			Action:      "admin.role.assigned",
			ActionLabel: "管理者ロール付与",
			ActionTone:  "success",
			Actor: Actor{
				ID:        "staff-admin-001",
				Name:      "システム管理者",
				Email:     "admin@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/sa.svg",
			},
			Target: Target{
				Reference: "staff/STF-203",
				Label:     "スタッフ STF-203",
				Type:      "staff",
				URL:       "/org/staff?selected=STF-203",
			},
			Summary:    "ロールを「Audit Viewer」から「Org Admin」に変更しました。",
			OccurredAt: now.Add(-8 * time.Hour),
			IPAddress:  "198.51.100.34",
			UserAgent:  "Chrome/123.0.6312.112 (macOS 14.3)",
			Diff: makeDiff(`
{
  "roles": [
    "audit.viewer"
  ]
}`, `
{
  "roles": [
    "audit.viewer",
    "org.admin"
  ]
}`),
			Metadata: map[string]string{
				"承認ワークフロー": "RBAC-2024-03",
			},
		},
		{
			ID:          "aud-20240420-015",
			Action:      "inventory.adjustment.approved",
			ActionLabel: "在庫調整承認",
			ActionTone:  "success",
			Actor: Actor{
				ID:        "staff-ops-002",
				Name:      "倉庫マネージャー",
				Email:     "warehouse@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/wm.svg",
			},
			Target: Target{
				Reference: "inventory/sku-RING-18K",
				Label:     "SKU RING-18K",
				Type:      "inventory",
				URL:       "/catalog/materials/sku-RING-18K",
			},
			Summary:    "棚卸差異の調整（+5）を承認しました。",
			OccurredAt: now.Add(-26 * time.Hour),
			IPAddress:  "198.51.100.18",
			UserAgent:  "Edge/122.0.2365.66 (Windows 10)",
			Diff: makeDiff(`
{
  "pending_adjustment": {
    "delta": 5,
    "status": "requested",
    "requested_by": "staff-ops-012"
  }
}`, `
{
  "pending_adjustment": {
    "delta": 5,
    "status": "approved",
    "approved_by": "staff-ops-002"
  },
  "quantity_on_hand": 152
}`),
			Metadata: map[string]string{
				"調整理由": "棚卸差異",
			},
		},
		{
			ID:          "aud-20240418-901",
			Action:      "system.integration.disabled",
			ActionLabel: "外部連携停止",
			ActionTone:  "danger",
			Actor: Actor{
				ID:        "staff-admin-002",
				Name:      "プラットフォーム担当",
				Email:     "platform@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/pf.svg",
			},
			Target: Target{
				Reference: "integrations/slack-audit",
				Label:     "Slack連携（監査チャンネル）",
				Type:      "integration",
				URL:       "/system/integrations?selected=slack-audit",
			},
			Summary:    "Slack監査ログ通知のWebhookを停止しました。",
			OccurredAt: now.Add(-3 * 24 * time.Hour),
			IPAddress:  "203.0.113.101",
			UserAgent:  "Firefox/123.0 (Windows 11)",
			Diff: makeDiff(`
{
  "webhook_url": "https://hooks.slack.com/services/...",
  "status": "active",
  "failure_count": 4
}`, `
{
  "webhook_url": null,
  "status": "disabled",
  "failure_count": 4,
  "disabled_reason": "Manual intervention"
}`),
			Metadata: map[string]string{
				"検知": "5xxアラート",
			},
		},
		{
			ID:          "aud-20240418-115",
			Action:      "system.api.key.rotated",
			ActionLabel: "APIキー再発行",
			ActionTone:  "info",
			Actor: Actor{
				ID:        "staff-engineering-001",
				Name:      "バックエンド開発",
				Email:     "backend@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/be.svg",
			},
			Target: Target{
				Reference: "api-keys/fulfillment-service",
				Label:     "Fulfillment Service Key",
				Type:      "api_key",
				URL:       "/profile/api-keys?selected=fulfillment-service",
			},
			Summary:    "Fulfillment Service APIキーをローテーションしました。",
			OccurredAt: now.Add(-4 * 24 * time.Hour),
			IPAddress:  "198.51.100.76",
			UserAgent:  "curl/8.5.0",
			Diff: makeDiff(`
{
  "secret": "****d4c1",
  "rotated_at": "2023-12-02T11:20:00+09:00"
}`, `
{
  "secret": "****8fb5",
  "rotated_at": "2024-04-18T08:10:00+09:00"
}`),
			Metadata: map[string]string{
				"自動失効": "2024-07-18T08:10:00+09:00",
			},
		},
		{
			ID:          "aud-20240415-044",
			Action:      "order.refund.approved",
			ActionLabel: "返金承認",
			ActionTone:  "warning",
			Actor: Actor{
				ID:        "staff-finance-010",
				Name:      "会計担当",
				Email:     "finance@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/fa.svg",
			},
			Target: Target{
				Reference: "orders/ORD-10388",
				Label:     "#10388 / 佐藤 美咲",
				Type:      "order",
				URL:       "/orders/order-10388",
			},
			Summary:    "配送遅延による10%返金を承認しました。",
			OccurredAt: now.Add(-7 * 24 * time.Hour),
			IPAddress:  "203.0.113.88",
			UserAgent:  "Safari/17.3 (iPadOS)",
			Diff: makeDiff(`
{
  "refunds": [],
  "balance_minor": 248000
}`, `
{
  "refunds": [
    {
      "amount_minor": 24800,
      "reason": "delivery_delay",
      "approved_by": "staff-finance-010"
    }
  ],
  "balance_minor": 223200
}`),
			Metadata: map[string]string{
				"支払い方法": "クレジットカード",
			},
		},
		{
			ID:          "aud-20240410-301",
			Action:      "compliance.kyc.verified",
			ActionLabel: "KYC審査完了",
			ActionTone:  "success",
			Actor: Actor{
				ID:        "staff-compliance-003",
				Name:      "コンプライアンス担当",
				Email:     "compliance@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/co.svg",
			},
			Target: Target{
				Reference: "customers/CUST-9821",
				Label:     "顧客 #9821",
				Type:      "customer",
				URL:       "/customers/CUST-9821",
			},
			Summary:    "書類不備が解消されKYCを承認しました。",
			OccurredAt: now.Add(-12 * 24 * time.Hour),
			IPAddress:  "198.51.100.55",
			UserAgent:  "Chrome/121.0.6167.140 (macOS)",
			Diff: makeDiff(`
{
  "kyc_status": "pending",
  "kyc_notes": "住所証明書類不鮮明"
}`, `
{
  "kyc_status": "approved",
  "kyc_notes": "再提出済み"
}`),
			Metadata: map[string]string{
				"チケット": "KYC-441",
			},
		},
		{
			ID:          "aud-20240331-110",
			Action:      "system.retention.cleanup",
			ActionLabel: "ログ自動削除",
			ActionTone:  "danger",
			Actor: Actor{
				ID:        "system-cron",
				Name:      "システムジョブ",
				Email:     "system@hanko.example.com",
				AvatarURL: "",
			},
			Target: Target{
				Reference: "logs/audit",
				Label:     "監査ログ",
				Type:      "system",
				URL:       "/audit-logs",
			},
			Summary:    "保持期間超過のログ 1,240 件を削除しました。",
			OccurredAt: now.Add(-22 * 24 * time.Hour),
			IPAddress:  "",
			UserAgent:  "cron/1.0",
			Diff: makeDiff(`
{
  "retained": 6240,
  "deleted": 0
}`, `
{
  "retained": 5000,
  "deleted": 1240
}`),
			Metadata: map[string]string{
				"保持ポリシー": "30日",
			},
		},
		{
			ID:          "aud-20240327-210",
			Action:      "order.address.updated",
			ActionLabel: "配送先住所更新",
			ActionTone:  "info",
			Actor: Actor{
				ID:        "staff-cs-006",
				Name:      "カスタマーサポートB",
				Email:     "support.b@hanko.example.com",
				AvatarURL: "https://avatars.dicebear.com/api/initials/cs-b.svg",
			},
			Target: Target{
				Reference: "orders/ORD-10192",
				Label:     "#10192 / 岡本 玲",
				Type:      "order",
				URL:       "/orders/order-10192",
			},
			Summary:    "配送先を実家住所に更新しました。",
			OccurredAt: now.Add(-26 * 24 * time.Hour),
			IPAddress:  "203.0.113.208",
			UserAgent:  "Safari/17.3 (macOS)",
			Diff: makeDiff(`
{
  "shipping_address": {
    "postal_code": "1600004",
    "line1": "東京都新宿区四谷1-1-1"
  }
}`, `
{
  "shipping_address": {
    "postal_code": "7300017",
    "line1": "広島県広島市中区鉄砲町4-1"
  }
}`),
			Metadata: map[string]string{
				"受付チャネル": "電話",
			},
		},
	}

	sort.SliceStable(entries, func(i, j int) bool {
		return entries[i].OccurredAt.After(entries[j].OccurredAt)
	})

	return &StaticService{
		entries:       entries,
		retentionDays: 30,
	}
}

// List returns paginated audit log entries based on query filters.
func (s *StaticService) List(_ context.Context, _ string, query ListQuery) (ListResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	norm := normalizeQuery(query)
	filtered := filterEntries(s.entries, norm)
	total := len(filtered)

	pageSize := norm.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}
	page := norm.Page
	if page <= 0 {
		page = 1
	}

	start := (page - 1) * pageSize
	if start > total {
		start = total
	}
	end := start + pageSize
	if end > total {
		end = total
	}

	entries := make([]Entry, end-start)
	copy(entries, filtered[start:end])

	pagination := Pagination{
		Page:       page,
		PageSize:   pageSize,
		TotalItems: total,
	}
	if end < total {
		next := page + 1
		pagination.NextPage = &next
	}
	if page > 1 {
		prev := page - 1
		pagination.PrevPage = &prev
	}

	summary := buildSummary(s.entries, filtered, s.retentionDays, norm)
	filters := buildFilters(s.entries, norm)
	alerts := buildAlerts(s.entries, filtered, summary)

	return ListResult{
		Summary:    summary,
		Filters:    filters,
		Entries:    entries,
		Pagination: pagination,
		Alerts:     alerts,
		Exportable: total > 0,
		Generated:  time.Now(),
	}, nil
}

// Export produces a CSV export for the filtered audit log set.
func (s *StaticService) Export(_ context.Context, _ string, query ListQuery) (ExportResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	norm := normalizeQuery(query)
	filtered := filterEntries(s.entries, norm)

	buffer := &bytes.Buffer{}
	writer := csv.NewWriter(buffer)
	headers := []string{"timestamp", "actor", "actor_email", "action", "target", "summary", "ip_address", "user_agent"}
	if err := writer.Write(headers); err != nil {
		return ExportResult{}, err
	}
	for _, entry := range filtered {
		record := []string{
			entry.OccurredAt.Format(time.RFC3339),
			entry.Actor.Name,
			entry.Actor.Email,
			entry.ActionLabel,
			entry.Target.Label,
			entry.Summary,
			entry.IPAddress,
			entry.UserAgent,
		}
		if err := writer.Write(record); err != nil {
			return ExportResult{}, err
		}
	}
	writer.Flush()
	if err := writer.Error(); err != nil {
		return ExportResult{}, err
	}

	now := time.Now()
	filename := fmt.Sprintf("audit-logs-%s.csv", now.Format("20060102-150405"))

	return ExportResult{
		Filename:    filename,
		ContentType: "text/csv; charset=utf-8",
		Data:        buffer.Bytes(),
		Generated:   now,
	}, nil
}

func normalizeQuery(query ListQuery) ListQuery {
	norm := query
	if norm.Page <= 0 {
		norm.Page = 1
	}
	if norm.PageSize <= 0 {
		norm.PageSize = 20
	}
	norm.Search = strings.TrimSpace(norm.Search)
	if norm.From != nil && norm.To != nil && norm.From.After(*norm.To) {
		norm.From, norm.To = norm.To, norm.From
	}
	return norm
}

func filterEntries(entries []Entry, query ListQuery) []Entry {
	var filtered []Entry
	for _, entry := range entries {
		if !matchTargets(entry, query.Targets) {
			continue
		}
		if !matchActors(entry, query.Actors) {
			continue
		}
		if !matchActions(entry, query.Actions) {
			continue
		}
		if !matchDate(entry, query.From, query.To) {
			continue
		}
		if !matchSearch(entry, query.Search) {
			continue
		}
		filtered = append(filtered, entry)
	}

	sort.SliceStable(filtered, func(i, j int) bool {
		if strings.EqualFold(query.Sort, "timestamp_asc") {
			return filtered[i].OccurredAt.Before(filtered[j].OccurredAt)
		}
		return filtered[i].OccurredAt.After(filtered[j].OccurredAt)
	})
	return filtered
}

func matchTargets(entry Entry, targets []string) bool {
	if len(targets) == 0 {
		return true
	}
	ref := strings.ToLower(strings.TrimSpace(entry.Target.Reference))
	for _, target := range targets {
		if ref == strings.ToLower(strings.TrimSpace(target)) {
			return true
		}
	}
	return false
}

func matchActors(entry Entry, actors []string) bool {
	if len(actors) == 0 {
		return true
	}
	id := strings.ToLower(strings.TrimSpace(entry.Actor.ID))
	email := strings.ToLower(strings.TrimSpace(entry.Actor.Email))
	for _, actor := range actors {
		value := strings.ToLower(strings.TrimSpace(actor))
		if value == id || value == email {
			return true
		}
	}
	return false
}

func matchActions(entry Entry, actions []string) bool {
	if len(actions) == 0 {
		return true
	}
	action := strings.ToLower(strings.TrimSpace(entry.Action))
	for _, a := range actions {
		if action == strings.ToLower(strings.TrimSpace(a)) {
			return true
		}
	}
	return false
}

func matchDate(entry Entry, from, to *time.Time) bool {
	if from != nil && entry.OccurredAt.Before(from.UTC()) {
		return false
	}
	if to != nil {
		end := to.UTC().Add(24*time.Hour - time.Nanosecond)
		if entry.OccurredAt.After(end) {
			return false
		}
	}
	return true
}

func matchSearch(entry Entry, search string) bool {
	if strings.TrimSpace(search) == "" {
		return true
	}
	needle := strings.ToLower(strings.TrimSpace(search))
	parts := []string{
		entry.Action, entry.ActionLabel, entry.Summary,
		entry.Actor.Name, entry.Actor.Email,
		entry.Target.Label, entry.Target.Reference, entry.Target.Type,
		entry.Diff.Before, entry.Diff.After,
	}
	for _, value := range entry.Metadata {
		parts = append(parts, value)
	}
	for _, part := range parts {
		if strings.Contains(strings.ToLower(part), needle) {
			return true
		}
	}
	return false
}

func buildSummary(all, filtered []Entry, retentionDays int, query ListQuery) Summary {
	uniqueActors := make(map[string]struct{})
	uniqueTargets := make(map[string]struct{})
	for _, entry := range filtered {
		if entry.Actor.ID != "" {
			uniqueActors[entry.Actor.ID] = struct{}{}
		}
		if entry.Target.Reference != "" {
			uniqueTargets[entry.Target.Reference] = struct{}{}
		}
	}

	windowLabel := "直近30日"
	if query.From != nil && query.To != nil {
		windowLabel = fmt.Sprintf("%s 〜 %s", query.From.Format("2006/01/02"), query.To.Format("2006/01/02"))
	} else if query.From != nil {
		windowLabel = fmt.Sprintf("%s 以降", query.From.Format("2006/01/02"))
	} else if query.To != nil {
		windowLabel = fmt.Sprintf("%s まで", query.To.Format("2006/01/02"))
	}

	retentionLabel := ""
	if retentionDays > 0 {
		retentionLabel = fmt.Sprintf("保持期間: %d日", retentionDays)
	}

	return Summary{
		TotalEntries:   len(all),
		FilteredCount:  len(filtered),
		UniqueActors:   len(uniqueActors),
		UniqueTargets:  len(uniqueTargets),
		WindowLabel:    windowLabel,
		RetentionDays:  retentionDays,
		RetentionLabel: retentionLabel,
	}
}

func buildFilters(entries []Entry, query ListQuery) FilterSummary {
	targetStats := make(map[string]Option)
	actorStats := make(map[string]Option)
	actionStats := make(map[string]ActionOption)

	for _, entry := range entries {
		if entry.Target.Reference != "" {
			stat := targetStats[entry.Target.Reference]
			stat.Value = entry.Target.Reference
			stat.Label = entry.Target.Label
			stat.Count++
			targetStats[entry.Target.Reference] = stat
		}
		if entry.Actor.ID != "" {
			stat := actorStats[entry.Actor.ID]
			stat.Value = entry.Actor.ID
			if entry.Actor.Name != "" {
				stat.Label = entry.Actor.Name
			} else {
				stat.Label = entry.Actor.Email
			}
			stat.Count++
			actorStats[entry.Actor.ID] = stat
		}
		if entry.Action != "" {
			stat := actionStats[entry.Action]
			stat.Value = entry.Action
			if stat.Label == "" {
				stat.Label = entry.ActionLabel
			}
			if stat.Tone == "" {
				stat.Tone = entry.ActionTone
			}
			stat.Count++
			actionStats[entry.Action] = stat
		}
	}

	targets := make([]Option, 0, len(targetStats))
	for _, stat := range targetStats {
		option := stat
		option.Selected = containsValue(query.Targets, option.Value)
		targets = append(targets, option)
	}
	sort.SliceStable(targets, func(i, j int) bool {
		return targets[i].Label < targets[j].Label
	})

	actors := make([]Option, 0, len(actorStats))
	for id, stat := range actorStats {
		option := stat
		option.Selected = containsValue(query.Actors, id) || containsValue(query.Actors, stat.Label)
		actors = append(actors, option)
	}
	sort.SliceStable(actors, func(i, j int) bool {
		return actors[i].Label < actors[j].Label
	})

	actions := make([]ActionOption, 0, len(actionStats))
	for _, stat := range actionStats {
		option := stat
		option.Active = containsValue(query.Actions, option.Value)
		actions = append(actions, option)
	}
	sort.SliceStable(actions, func(i, j int) bool {
		return actions[i].Label < actions[j].Label
	})

	return FilterSummary{
		Targets: targets,
		Actors:  actors,
		Actions: actions,
	}
}

func buildAlerts(all, filtered []Entry, summary Summary) []Alert {
	var alerts []Alert
	now := time.Now()
	if summary.RetentionDays > 0 && len(all) > 0 {
		oldest := all[0].OccurredAt
		for _, entry := range all {
			if entry.OccurredAt.Before(oldest) {
				oldest = entry.OccurredAt
			}
		}
		daysSince := int(now.Sub(oldest).Hours() / 24)
		remaining := summary.RetentionDays - daysSince
		if remaining <= 5 {
			if remaining < 0 {
				remaining = 0
			}
			alerts = append(alerts, Alert{
				Tone:    "warning",
				Icon:    "⏳",
				Message: fmt.Sprintf("保持期間の残りが %d 日です。必要なログはエクスポートして保管してください。", remaining),
			})
		}
	}

	if len(filtered) == len(all) && len(filtered) >= 8 {
		alerts = append(alerts, Alert{
			Tone:    "info",
			Icon:    "🔍",
			Message: "条件が広すぎます。対象リソースや実行者で絞り込むと目的のログを見つけやすくなります。",
		})
	}
	return alerts
}

func containsValue(values []string, target string) bool {
	if len(values) == 0 {
		return false
	}
	target = strings.ToLower(strings.TrimSpace(target))
	for _, value := range values {
		if strings.ToLower(strings.TrimSpace(value)) == target {
			return true
		}
	}
	return false
}
