package production

import (
	"context"
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
)

// StaticService provides deterministic production data for local development and tests.
type StaticService struct {
	mu           sync.RWMutex
	queues       map[string]Queue
	cards        map[string]*cardRecord
	workorders   map[string]WorkOrder
	laneDefs     []laneDefinition
	defaultQueue string
	qcReasons    []QCReason
	qcRoutes     []QCReworkRoute
	queueDefs    map[string]QueueDefinition
	workCenters  map[string]QueueWorkCenter
	roleOptions  []QueueRoleOption
	queueSeq     int
}

type cardRecord struct {
	card       Card
	timeline   []ProductionEvent
	inspection *qcInspectionRecord
}

type qcInspectionRecord struct {
	Status      QCStatus
	Checklist   []QCChecklistItem
	Issues      []QCIssueRecord
	Attachments []QCAttachment
	Notes       []string
	IssueType   string
	IssueHint   string
	SLALabel    string
	SLATone     string
	ReceivedAt  time.Time
}

type counter map[string]int

type laneDefinition struct {
	stage       Stage
	label       string
	description string
	capacity    int
	slaLabel    string
	slaTone     string
}

// NewStaticService returns a production service seeded with representative data.
func NewStaticService() *StaticService {
	svc := &StaticService{
		queues:      make(map[string]Queue),
		cards:       make(map[string]*cardRecord),
		workorders:  make(map[string]WorkOrder),
		queueDefs:   make(map[string]QueueDefinition),
		workCenters: make(map[string]QueueWorkCenter),
		laneDefs: []laneDefinition{
			{stage: StageQueued, label: "待機", description: "支給待ち / 図面確認", capacity: 10, slaLabel: "平均6h", slaTone: "info"},
			{stage: StageEngraving, label: "刻印", description: "CNC + ハンドエングレーブ", capacity: 8, slaLabel: "平均9h", slaTone: "info"},
			{stage: StagePolishing, label: "研磨", description: "仕上げ・石留め調整", capacity: 8, slaLabel: "平均5h", slaTone: "warning"},
			{stage: StageQC, label: "検品", description: "寸法/SLA チェック", capacity: 6, slaLabel: "平均3h", slaTone: "success"},
			{stage: StagePacked, label: "梱包", description: "付属品セット / 梱包", capacity: 6, slaLabel: "平均2h", slaTone: "success"},
		},
	}
	svc.seed()
	return svc
}

// Board implements Service.
func (s *StaticService) Board(_ context.Context, _ string, query BoardQuery) (BoardResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	queueID := strings.TrimSpace(query.QueueID)
	if queueID == "" {
		queueID = s.defaultQueue
	}

	queue, ok := s.queues[queueID]
	if !ok {
		return BoardResult{}, ErrQueueNotFound
	}

	allRecords := s.queueRecords(queueID)
	filtered := filterRecords(allRecords, query)

	lanes := s.buildLanes(filtered)
	summary := s.buildSummary(queue, filtered)
	filters := s.buildFilters(allRecords, query)
	queueOptions := s.queueOptions(queueID)
	selectedID, drawer := s.buildDrawer(filtered, query.Selected)

	return BoardResult{
		Queue:           queue,
		Queues:          queueOptions,
		Summary:         summary,
		Filters:         filters,
		Lanes:           lanes,
		Drawer:          drawer,
		SelectedCardID:  selectedID,
		GeneratedAt:     time.Now(),
		RefreshInterval: 30 * time.Second,
	}, nil
}

// AppendEvent implements Service.
func (s *StaticService) AppendEvent(_ context.Context, _ string, orderID string, req AppendEventRequest) (AppendEventResult, error) {
	stage := Stage(strings.TrimSpace(string(req.Stage)))
	if !isValidStage(stage) {
		return AppendEventResult{}, ErrStageInvalid
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.cards[strings.TrimSpace(orderID)]
	if !ok {
		return AppendEventResult{}, ErrCardNotFound
	}

	now := time.Now()
	event := ProductionEvent{
		ID:          fmt.Sprintf("evt-%s-%d", record.card.ID, now.UnixNano()),
		Stage:       stage,
		StageLabel:  StageLabel(stage),
		Type:        fmt.Sprintf("%s.progress", stage),
		Description: fmt.Sprintf("%s へ移動", StageLabel(stage)),
		Actor:       coalesce(req.ActorRef, "工房オペレーター"),
		Station:     coalesce(req.Station, record.card.Workstation),
		Tone:        "info",
		OccurredAt:  now,
		Note:        strings.TrimSpace(req.Note),
	}
	record.timeline = append([]ProductionEvent{event}, record.timeline...)

	record.card.Stage = stage
	record.card.LastEvent = event
	record.card.Workstation = event.Station
	record.card.Blocked = false
	record.card.BlockedReason = ""
	record.card.Notes = appendUnique(record.card.Notes, event.Note)
	record.card.Timeline = append([]ProductionEvent(nil), record.timeline...)
	s.workorders[record.card.ID] = s.buildWorkOrder(record)

	return AppendEventResult{
		Event: event,
		Card:  cloneCard(record.card),
	}, nil
}

// WorkOrder implements Service.
func (s *StaticService) WorkOrder(_ context.Context, _ string, orderID string) (WorkOrder, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	orderID = strings.TrimSpace(orderID)
	if orderID == "" {
		return WorkOrder{}, ErrWorkOrderNotFound
	}

	work, ok := s.workorders[orderID]
	if !ok {
		return WorkOrder{}, ErrWorkOrderNotFound
	}
	return cloneWorkOrder(work), nil
}

// QCOverview implements Service.
func (s *StaticService) QCOverview(_ context.Context, _ string, query QCQuery) (QCResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	queueID := strings.TrimSpace(query.QueueID)
	if queueID == "" {
		queueID = s.defaultQueue
	}

	queue, ok := s.queues[queueID]
	if !ok {
		return QCResult{}, ErrQueueNotFound
	}

	all := s.qcRecords(queueID)
	filtered := filterQCRecords(all, query)
	items := s.buildQCItems(filtered)
	selectedID, drawer := s.buildQCDrawer(filtered, query.Selected)

	result := QCResult{
		Queue:       queue,
		Queues:      s.queueOptions(queueID),
		Alert:       s.qcAlert(queueID),
		Summary:     s.qcSummary(all),
		Performance: s.qcPerformance(all),
		Filters:     s.qcFilters(all, query),
		Items:       items,
		Drawer:      drawer,
		SelectedID:  selectedID,
		GeneratedAt: time.Now(),
	}
	return result, nil
}

// RecordQCDecision implements Service.
func (s *StaticService) RecordQCDecision(_ context.Context, _ string, orderID string, req QCDecisionRequest) (QCDecisionResult, error) {
	orderID = strings.TrimSpace(orderID)
	if orderID == "" {
		return QCDecisionResult{}, ErrQCItemNotFound
	}

	outcome := QCDecisionOutcome(strings.TrimSpace(string(req.Outcome)))
	if outcome != QCDecisionPass && outcome != QCDecisionFail {
		return QCDecisionResult{}, ErrQCInvalidAction
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.cards[orderID]
	if !ok || record.inspection == nil {
		return QCDecisionResult{}, ErrQCItemNotFound
	}

	inspection := record.inspection
	now := time.Now()
	if added := buildQCAttachments(req.Attachments, record.card.ID, now); len(added) > 0 {
		inspection.Attachments = append(added, inspection.Attachments...)
	}
	switch outcome {
	case QCDecisionPass:
		if inspection.Status == QCStatusComplete {
			return QCDecisionResult{}, ErrQCInvalidAction
		}
		inspection.Status = QCStatusComplete
		event := ProductionEvent{
			ID:          fmt.Sprintf("qc-pass-%s-%d", record.card.ID, now.UnixNano()),
			Stage:       StageQC,
			StageLabel:  StageLabel(StageQC),
			Type:        "qc.pass",
			Description: "QC合格",
			Actor:       "QCオペレーター",
			OccurredAt:  now,
			Note:        strings.TrimSpace(req.Note),
			Tone:        "success",
		}
		s.prependTimeline(record, event)
		record.card.Stage = StagePacked
		record.card.DueLabel = "梱包へ引き渡し"
		record.card.DueTone = "success"
		record.card.Flags = removeFlag(record.card.Flags, "QC再検")
		return QCDecisionResult{
			Item:    s.qcItemFromRecord(record),
			Message: fmt.Sprintf("注文 #%s をQC合格として登録しました。", record.card.OrderNumber),
		}, nil
	case QCDecisionFail:
		if inspection.Status == QCStatusFailed {
			return QCDecisionResult{}, ErrQCInvalidAction
		}
		inspection.Status = QCStatusFailed
		reasonLabel := s.reasonLabel(req.ReasonCode)
		if reasonLabel == "" {
			reasonLabel = "その他"
		}
		inspection.IssueType = reasonLabel
		note := strings.TrimSpace(req.Note)
		summary := reasonLabel
		if note != "" {
			summary = fmt.Sprintf("%s / %s", reasonLabel, note)
		}
		issue := QCIssueRecord{
			ID:        fmt.Sprintf("qc-issue-%s-%d", record.card.ID, now.UnixNano()),
			Category:  reasonLabel,
			Summary:   summary,
			Actor:     "QCオペレーター",
			Tone:      "danger",
			CreatedAt: now,
		}
		inspection.Issues = append([]QCIssueRecord{issue}, inspection.Issues...)
		if note != "" {
			inspection.Notes = append([]string{note}, inspection.Notes...)
		}
		record.card.Flags = appendFlag(record.card.Flags, CardFlag{Label: "QC再検", Tone: "warning", Icon: "🧪"})
		event := ProductionEvent{
			ID:          fmt.Sprintf("qc-fail-%s-%d", record.card.ID, now.UnixNano()),
			Stage:       StageQC,
			StageLabel:  StageLabel(StageQC),
			Type:        "qc.fail",
			Description: fmt.Sprintf("QC再検 (%s)", reasonLabel),
			Actor:       "QCオペレーター",
			OccurredAt:  now,
			Note:        note,
			Tone:        "danger",
		}
		s.prependTimeline(record, event)
		return QCDecisionResult{
			Item:    s.qcItemFromRecord(record),
			Message: fmt.Sprintf("注文 #%s をQC再検として登録しました。", record.card.OrderNumber),
		}, nil
	default:
		return QCDecisionResult{}, ErrQCInvalidAction
	}
}

// TriggerRework implements Service.
func (s *StaticService) TriggerRework(_ context.Context, _ string, orderID string, req QCReworkRequest) (QCReworkResult, error) {
	orderID = strings.TrimSpace(orderID)
	if orderID == "" {
		return QCReworkResult{}, ErrQCItemNotFound
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	record, ok := s.cards[orderID]
	if !ok || record.inspection == nil {
		return QCReworkResult{}, ErrQCItemNotFound
	}
	inspection := record.inspection
	if inspection.Status != QCStatusFailed {
		return QCReworkResult{}, ErrQCInvalidAction
	}

	route, ok := s.findReworkRoute(strings.TrimSpace(req.RouteID))
	if !ok {
		return QCReworkResult{}, ErrQCInvalidAction
	}
	inspection.Status = QCStatusComplete

	now := time.Now()
	reasonLabel := s.reasonLabel(req.IssueCode)
	event := ProductionEvent{
		ID:          fmt.Sprintf("qc-rework-%s-%d", record.card.ID, now.UnixNano()),
		Stage:       route.Stage,
		StageLabel:  StageLabel(route.Stage),
		Type:        "qc.rework",
		Description: fmt.Sprintf("再作業: %s", route.Label),
		Actor:       "QCオペレーター",
		OccurredAt:  now,
		Note:        strings.TrimSpace(req.Note),
		Tone:        "warning",
	}
	if reasonLabel != "" {
		event.Description = fmt.Sprintf("%s (%s)", event.Description, reasonLabel)
	}
	s.prependTimeline(record, event)
	record.card.Stage = route.Stage
	record.card.Workstation = strings.ToUpper(fmt.Sprintf("%s-RET", string(route.Stage)))
	record.card.Flags = appendFlag(record.card.Flags, CardFlag{Label: "再作業", Tone: "danger", Icon: "♻"})

	return QCReworkResult{
		Item:    s.qcItemFromRecord(record),
		Message: fmt.Sprintf("注文 #%s を%sへ差し戻しました。", record.card.OrderNumber, route.Label),
	}, nil
}

func (s *StaticService) seed() {
	now := time.Now()

	s.queues["atelier-aoyama"] = Queue{
		ID:            "atelier-aoyama",
		Name:          "青山アトリエ",
		Description:   "リング刻印ライン / 表参道工房",
		Location:      "東京都港区",
		Shift:         "08:00-22:00",
		Capacity:      28,
		Load:          0,
		Utilisation:   58,
		LeadTimeHours: 36,
		Notes:         []string{"VIP優先ライン常設", "CNC 2台 + レーザー1台"},
	}
	s.queues["atelier-kyoto"] = Queue{
		ID:            "atelier-kyoto",
		Name:          "京都スタジオ",
		Description:   "和彫り / 仕上げ特化ライン",
		Location:      "京都府京都市",
		Shift:         "09:00-19:00",
		Capacity:      18,
		Load:          0,
		Utilisation:   44,
		LeadTimeHours: 40,
		Notes:         []string{"彫金士3名常駐", "QC 兼任体制"},
	}
	s.defaultQueue = "atelier-aoyama"
	s.qcReasons = []QCReason{
		{Code: "engrave_mismatch", Label: "刻印内容差異", Category: "刻印"},
		{Code: "finish_scratch", Label: "表面キズ", Category: "仕上げ"},
		{Code: "stone_loose", Label: "石のぐらつき", Category: "石留め"},
		{Code: "pack_issue", Label: "付属品不足", Category: "梱包"},
	}
	s.qcRoutes = []QCReworkRoute{
		{ID: "rework-engraving", Label: "刻印ラインに差し戻し", Description: "刻印内容/フォントの修正を依頼します。", Stage: StageEngraving},
		{ID: "rework-polishing", Label: "研磨ラインに差し戻し", Description: "表面キズ/仕上げ調整を再作業します。", Stage: StagePolishing},
	}

	cards := []*cardRecord{
		newCardRecord(Card{
			ID:            "order-1052",
			OrderNumber:   "1052",
			Stage:         StageEngraving,
			Priority:      PriorityRush,
			PriorityLabel: "特急",
			PriorityTone:  "warning",
			Customer:      "長谷川 純",
			ProductLine:   "Classic Ring",
			Design:        "18K カスタム刻印リング",
			PreviewURL:    "/public/static/previews/ring-classic.png",
			PreviewAlt:    "Classic Ring Preview",
			QueueID:       "atelier-aoyama",
			QueueName:     "青山アトリエ",
			Workstation:   "CNC-02",
			Assignees: []Assignee{
				{Name: "木村 遼", Initials: "RK", Role: "刻印"},
				{Name: "星野 彩", Initials: "AH", Role: "段取り"},
			},
			Flags:      []CardFlag{{Label: "VIP", Tone: "info", Icon: "👑"}},
			DueAt:      now.Add(20 * time.Hour),
			DueLabel:   "残り20時間",
			DueTone:    "warning",
			Notes:      []string{"フォント: S-12", "ダイヤ加飾"},
			Blocked:    false,
			AgingHours: 18,
		}, []ProductionEvent{
			{ID: "evt-1052-1", Stage: StageQueued, StageLabel: StageLabel(StageQueued), Type: "queued", Description: "支給待ち", Actor: "自動割当", OccurredAt: now.Add(-26 * time.Hour)},
			{ID: "evt-1052-2", Stage: StageEngraving, StageLabel: StageLabel(StageEngraving), Type: "engraving.start", Description: "刻印開始", Actor: "木村 遼", Station: "CNC-02", OccurredAt: now.Add(-2 * time.Hour)},
		}),
		newCardRecord(Card{
			ID:            "order-1060",
			OrderNumber:   "1060",
			Stage:         StageQueued,
			Priority:      PriorityNormal,
			PriorityLabel: "通常",
			PriorityTone:  "info",
			Customer:      "山本 遥",
			ProductLine:   "Signet",
			Design:        "サインリング スクエア",
			PreviewURL:    "/public/static/previews/signet.png",
			PreviewAlt:    "Signet Ring",
			QueueID:       "atelier-aoyama",
			QueueName:     "青山アトリエ",
			Workstation:   "準備中",
			Assignees:     []Assignee{{Name: "益田 拓", Initials: "TM", Role: "図面確認"}},
			Flags:         []CardFlag{{Label: "素材待ち", Tone: "danger", Icon: "⛔"}},
			DueAt:         now.Add(48 * time.Hour),
			DueLabel:      "残り2日",
			Notes:         []string{"ロゴデータ差し替え待ち"},
			Blocked:       true,
			BlockedReason: "素材支給待ち",
			AgingHours:    6,
		}, []ProductionEvent{
			{ID: "evt-1060-1", Stage: StageQueued, StageLabel: StageLabel(StageQueued), Type: "queued", Description: "支給待ち", Actor: "益田 拓", OccurredAt: now.Add(-6 * time.Hour), Note: "素材調達中"},
		}),
		newCardRecord(Card{
			ID:            "order-1041",
			OrderNumber:   "1041",
			Stage:         StagePolishing,
			Priority:      PriorityRush,
			PriorityLabel: "特急",
			PriorityTone:  "warning",
			Customer:      "李 美咲",
			ProductLine:   "Aurora",
			Design:        "グラデーションバングル",
			PreviewURL:    "/public/static/previews/bangle.png",
			PreviewAlt:    "Aurora Bangle",
			QueueID:       "atelier-aoyama",
			QueueName:     "青山アトリエ",
			Workstation:   "POL-01",
			Assignees:     []Assignee{{Name: "原田 琴", Initials: "KH", Role: "研磨"}},
			Flags:         []CardFlag{{Label: "QC要注意", Tone: "warning", Icon: "⚠"}},
			DueAt:         now.Add(12 * time.Hour),
			DueLabel:      "残り12時間",
			DueTone:       "danger",
			Notes:         []string{"内側に小傷あり"},
			AgingHours:    27,
		}, []ProductionEvent{
			{ID: "evt-1041-1", Stage: StageEngraving, StageLabel: StageLabel(StageEngraving), Type: "engraving.complete", Description: "刻印完了", Actor: "北原 悠", OccurredAt: now.Add(-15 * time.Hour)},
			{ID: "evt-1041-2", Stage: StagePolishing, StageLabel: StageLabel(StagePolishing), Type: "polishing.start", Description: "研磨開始", Actor: "原田 琴", Station: "POL-01", OccurredAt: now.Add(-4 * time.Hour)},
		}),
		newQCRecord(Card{
			ID:            "order-1033",
			OrderNumber:   "1033",
			Stage:         StageQC,
			Priority:      PriorityNormal,
			PriorityLabel: "通常",
			PriorityTone:  "info",
			Customer:      "フィリップ 仁",
			ProductLine:   "Heritage",
			Design:        "ペアリング",
			PreviewURL:    "/public/static/previews/pair.png",
			PreviewAlt:    "Pair Ring",
			QueueID:       "atelier-aoyama",
			QueueName:     "青山アトリエ",
			Workstation:   "QC-02",
			Assignees: []Assignee{
				{Name: "宮川 光", Initials: "HM", Role: "QC"},
				{Name: "鈴木 亮", Initials: "RS", Role: "梱包"},
			},
			Flags:      []CardFlag{{Label: "刻印差異", Tone: "warning", Icon: "✏"}},
			DueAt:      now.Add(6 * time.Hour),
			DueLabel:   "残り6時間",
			Notes:      []string{"サイズ#10/#12"},
			AgingHours: 30,
		}, []ProductionEvent{
			{ID: "evt-1033-1", Stage: StagePolishing, StageLabel: StageLabel(StagePolishing), Type: "polishing.complete", Description: "研磨完了", Actor: "土屋 凛", OccurredAt: now.Add(-8 * time.Hour)},
			{ID: "evt-1033-2", Stage: StageQC, StageLabel: StageLabel(StageQC), Type: "qc.start", Description: "検品中", Actor: "宮川 光", Station: "QC-02", OccurredAt: now.Add(-1 * time.Hour)},
		}, qcInspectionRecord{
			Status: QCStatusPending,
			Checklist: []QCChecklistItem{
				{ID: "dim", Label: "寸法/ゲージ", Description: "±0.02mm 以内", Required: true, Status: "in_progress"},
				{ID: "finish", Label: "仕上げ面", Description: "内側キズ無し", Required: true, Status: "pending"},
				{ID: "engrave", Label: "刻印整合", Description: "指定フォント/位置", Required: true, Status: "warning"},
			},
			Issues: []QCIssueRecord{
				{ID: "issue-1033-1", Category: "刻印", Summary: "先週フォント差異で再検", Actor: "宮川 光", Tone: "warning", CreatedAt: now.Add(-72 * time.Hour)},
			},
			Attachments: []QCAttachment{
				{ID: "pair-front", URL: "/public/static/previews/pair.png", Label: "正面", Kind: "photo"},
			},
			Notes:      []string{"内側刻印の太さを再確認"},
			IssueType:  "刻印",
			IssueHint:  "刻印線の太さ/深さを重点確認",
			SLALabel:   "SLA 30分",
			SLATone:    "warning",
			ReceivedAt: now.Add(-90 * time.Minute),
		}),
		newQCRecord(Card{
			ID:            "order-1090",
			OrderNumber:   "1090",
			Stage:         StageQC,
			Priority:      PriorityRush,
			PriorityLabel: "特急",
			PriorityTone:  "warning",
			Customer:      "小林 咲",
			ProductLine:   "Brilliant",
			Design:        "ダイヤエタニティ",
			PreviewURL:    "/public/static/previews/eternity.png",
			PreviewAlt:    "Diamond Eternity",
			QueueID:       "atelier-aoyama",
			QueueName:     "青山アトリエ",
			Workstation:   "QC-01",
			Assignees:     []Assignee{{Name: "田村 結衣", Initials: "YT", Role: "QC"}},
			Flags:         []CardFlag{{Label: "VIP", Tone: "info", Icon: "👑"}},
			DueAt:         now.Add(4 * time.Hour),
			DueLabel:      "残り4時間",
			DueTone:       "warning",
			Notes:         []string{"石座の段差を要確認"},
			AgingHours:    12,
		}, []ProductionEvent{
			{ID: "evt-1090-1", Stage: StagePolishing, StageLabel: StageLabel(StagePolishing), Type: "polishing.complete", Description: "研磨完了", Actor: "佐藤 佑", OccurredAt: now.Add(-3 * time.Hour)},
			{ID: "evt-1090-2", Stage: StageQC, StageLabel: StageLabel(StageQC), Type: "qc.start", Description: "検品中", Actor: "田村 結衣", Station: "QC-01", OccurredAt: now.Add(-40 * time.Minute)},
		}, qcInspectionRecord{
			Status: QCStatusPending,
			Checklist: []QCChecklistItem{
				{ID: "stone", Label: "石留め", Description: "ぐらつき/欠けなし", Required: true, Status: "pending"},
				{ID: "surface", Label: "鏡面仕上げ", Description: "肉眼キズなし", Required: true, Status: "pending"},
			},
			Attachments: []QCAttachment{
				{ID: "macro", URL: "/public/static/previews/eternity.png", Label: "マクロ", Kind: "photo"},
			},
			Notes:      []string{"VIPオーダーにつき撮影必須"},
			IssueType:  "石留め",
			IssueHint:  "石の段差/浮きを撮影で確認",
			SLALabel:   "SLA 20分",
			SLATone:    "info",
			ReceivedAt: now.Add(-40 * time.Minute),
		}),
		newQCRecord(Card{
			ID:            "order-1092",
			OrderNumber:   "1092",
			Stage:         StageQC,
			Priority:      PriorityNormal,
			PriorityLabel: "通常",
			PriorityTone:  "info",
			Customer:      "志村 蒼",
			ProductLine:   "Signet",
			Design:        "K18 サインリング",
			PreviewURL:    "/public/static/previews/signet.png",
			PreviewAlt:    "Signet Ring",
			QueueID:       "atelier-kyoto",
			QueueName:     "京都スタジオ",
			Workstation:   "QC-03",
			Assignees:     []Assignee{{Name: "松永 遥", Initials: "HM", Role: "QC/梱包"}},
			DueAt:         now.Add(9 * time.Hour),
			DueLabel:      "残り9時間",
			Notes:         []string{"手彫り部分の墨入れ乾燥済"},
			AgingHours:    5,
		}, []ProductionEvent{
			{ID: "evt-1092-1", Stage: StagePolishing, StageLabel: StageLabel(StagePolishing), Type: "polishing.complete", Description: "研磨完了", Actor: "辻村 慎", OccurredAt: now.Add(-5 * time.Hour)},
			{ID: "evt-1092-2", Stage: StageQC, StageLabel: StageLabel(StageQC), Type: "qc.start", Description: "検品中", Actor: "松永 遥", Station: "QC-03", OccurredAt: now.Add(-2 * time.Hour)},
		}, qcInspectionRecord{
			Status: QCStatusFailed,
			Checklist: []QCChecklistItem{
				{ID: "color", Label: "色味/仕上げ", Description: "酸洗いムラなし", Required: true, Status: "pass"},
				{ID: "engrave", Label: "手彫り", Description: "かすれ/欠けなし", Required: true, Status: "fail"},
			},
			Issues: []QCIssueRecord{
				{ID: "issue-1092-1", Category: "刻印", Summary: "手彫りラインの欠け", Actor: "松永 遥", Tone: "danger", CreatedAt: now.Add(-20 * time.Minute)},
			},
			Notes:      []string{"再彫り手配待ち"},
			IssueType:  "刻印",
			IssueHint:  "筆致の欠けあり。手彫り工房へ差し戻し予定。",
			SLALabel:   "SLA 45分",
			SLATone:    "danger",
			ReceivedAt: now.Add(-2 * time.Hour),
		}),
		newCardRecord(Card{
			ID:            "order-1025",
			OrderNumber:   "1025",
			Stage:         StagePacked,
			Priority:      PriorityNormal,
			PriorityLabel: "通常",
			PriorityTone:  "success",
			Customer:      "杉山 桃子",
			ProductLine:   "Brilliant",
			Design:        "ハーフエタニティ",
			PreviewURL:    "/public/static/previews/eternity.png",
			PreviewAlt:    "Eternity Ring",
			QueueID:       "atelier-aoyama",
			QueueName:     "青山アトリエ",
			Workstation:   "PACK-01",
			Assignees:     []Assignee{{Name: "鈴木 亮", Initials: "RS", Role: "梱包"}},
			Flags:         []CardFlag{{Label: "ラッピング指定", Tone: "info", Icon: "🎀"}},
			DueAt:         now.Add(3 * time.Hour),
			DueLabel:      "本日出荷",
			Notes:         []string{"カード同梱"},
			AgingHours:    34,
		}, []ProductionEvent{
			{ID: "evt-1025-1", Stage: StageQC, StageLabel: StageLabel(StageQC), Type: "qc.pass", Description: "QC合格", Actor: "宮川 光", OccurredAt: now.Add(-5 * time.Hour)},
			{ID: "evt-1025-2", Stage: StagePacked, StageLabel: StageLabel(StagePacked), Type: "packing.start", Description: "梱包中", Actor: "鈴木 亮", Station: "PACK-01", OccurredAt: now.Add(-1 * time.Hour)},
		}),
		newCardRecord(Card{
			ID:            "order-1071",
			OrderNumber:   "1071",
			Stage:         StageEngraving,
			Priority:      PriorityHold,
			PriorityLabel: "保留",
			PriorityTone:  "danger",
			Customer:      "アレックス 中島",
			ProductLine:   "Monogram",
			Design:        "K18 シグネット",
			PreviewURL:    "/public/static/previews/monogram.png",
			PreviewAlt:    "Monogram Ring",
			QueueID:       "atelier-kyoto",
			QueueName:     "京都スタジオ",
			Workstation:   "HAND-01",
			Assignees:     []Assignee{{Name: "辻村 慎", Initials: "ST", Role: "手彫り"}},
			Flags:         []CardFlag{{Label: "校正待ち", Tone: "danger", Icon: "✉"}},
			DueAt:         now.Add(72 * time.Hour),
			DueLabel:      "残り3日",
			Notes:         []string{"校了次第再開"},
			Blocked:       true,
			BlockedReason: "モノグラム校正待ち",
			AgingHours:    5,
		}, []ProductionEvent{
			{ID: "evt-1071-1", Stage: StageQueued, StageLabel: StageLabel(StageQueued), Type: "queued", Description: "京都工房待機", Actor: "自動割当", OccurredAt: now.Add(-8 * time.Hour)},
			{ID: "evt-1071-2", Stage: StageEngraving, StageLabel: StageLabel(StageEngraving), Type: "engraving.paused", Description: "校正待ち", Actor: "辻村 慎", OccurredAt: now.Add(-2 * time.Hour), Note: "モノグラム修正要"},
		}),
	}

	s.workCenters["wc-aoyama-engrave"] = QueueWorkCenter{ID: "wc-aoyama-engrave", Name: "青山CNCセル", Location: "青山", Capability: "CNC / レーザー刻印", Active: true}
	s.workCenters["wc-aoyama-polish"] = QueueWorkCenter{ID: "wc-aoyama-polish", Name: "青山研磨室", Location: "青山", Capability: "研磨 / 仕上げ", Active: true}
	s.workCenters["wc-aoyama-qc"] = QueueWorkCenter{ID: "wc-aoyama-qc", Name: "青山QCベイ", Location: "青山", Capability: "QC / 梱包", Active: true}
	s.workCenters["wc-kyoto-hand"] = QueueWorkCenter{ID: "wc-kyoto-hand", Name: "京都手彫り工房", Location: "京都", Capability: "手彫り / 和彫り", Active: true}
	s.workCenters["wc-kyoto-qc"] = QueueWorkCenter{ID: "wc-kyoto-qc", Name: "京都QCデスク", Location: "京都", Capability: "QC / 梱包", Active: true}

	s.roleOptions = []QueueRoleOption{
		{Key: "lead", Label: "工房リーダー", SuggestedHeadcount: 1},
		{Key: "engraver", Label: "刻印士", SuggestedHeadcount: 3},
		{Key: "polisher", Label: "研磨士", SuggestedHeadcount: 2},
		{Key: "qc", Label: "QC担当", SuggestedHeadcount: 2},
		{Key: "packer", Label: "梱包担当", SuggestedHeadcount: 1},
	}

	roleLabel := func(key string) string {
		for _, opt := range s.roleOptions {
			if opt.Key == key {
				return opt.Label
			}
		}
		return key
	}

	aoyamaStages := []QueueStage{
		{Code: StageQueued, Label: "段取り", Sequence: 1, Description: "素材支給・図面確認", WIPLimit: 12, TargetSLAHours: 6},
		{Code: StageEngraving, Label: "刻印", Sequence: 2, Description: "CNC/レーザー刻印", WIPLimit: 10, TargetSLAHours: 9},
		{Code: StagePolishing, Label: "研磨", Sequence: 3, Description: "研磨/石留め調整", WIPLimit: 8, TargetSLAHours: 5},
		{Code: StageQC, Label: "QC", Sequence: 4, Description: "寸法検査・外観確認", WIPLimit: 6, TargetSLAHours: 3},
		{Code: StagePacked, Label: "梱包", Sequence: 5, Description: "付属品セット・出荷準備", WIPLimit: 6, TargetSLAHours: 2},
	}

	kyotoStages := []QueueStage{
		{Code: StageQueued, Label: "校了待ち", Sequence: 1, Description: "図案確認・素材支給", WIPLimit: 8, TargetSLAHours: 8},
		{Code: StageEngraving, Label: "和彫り", Sequence: 2, Description: "手彫り/和彫り工程", WIPLimit: 6, TargetSLAHours: 12},
		{Code: StagePolishing, Label: "研磨", Sequence: 3, Description: "艶出し/仕上げ", WIPLimit: 4, TargetSLAHours: 6},
		{Code: StageQC, Label: "QC", Sequence: 4, Description: "外観/寸法検査", WIPLimit: 3, TargetSLAHours: 3},
		{Code: StagePacked, Label: "梱包", Sequence: 5, Description: "検品後梱包", WIPLimit: 3, TargetSLAHours: 2},
	}

	s.queueDefs["atelier-aoyama"] = QueueDefinition{
		ID:             "atelier-aoyama",
		Name:           "青山アトリエ",
		Description:    "リング刻印のメインライン。VIP優先枠を備えたハイスループット編成。",
		Workshop:       "青山工房",
		ProductLine:    "Classic / Brilliant",
		Priority:       1,
		PriorityLabel:  "P1",
		Capacity:       28,
		TargetSLAHours: 36,
		Active:         true,
		Notes:          []string{"VIP優先ライン常設", "CNC 2台 + レーザー1台"},
		Metrics: QueueDefinitionMetrics{
			ThroughputPerShift: 42.0,
			WIPUtilisation:     0.62,
			SLACompliance:      0.88,
		},
		WorkCenters: []QueueWorkCenterAssignment{
			{WorkCenter: s.workCenters["wc-aoyama-engrave"], Primary: true},
			{WorkCenter: s.workCenters["wc-aoyama-polish"], Primary: false},
			{WorkCenter: s.workCenters["wc-aoyama-qc"], Primary: false},
		},
		Roles: []QueueRoleAssignment{
			{Key: "lead", Label: roleLabel("lead"), Headcount: 1},
			{Key: "engraver", Label: roleLabel("engraver"), Headcount: 4},
			{Key: "polisher", Label: roleLabel("polisher"), Headcount: 3},
			{Key: "qc", Label: roleLabel("qc"), Headcount: 2},
			{Key: "packer", Label: roleLabel("packer"), Headcount: 1},
		},
		Stages:    aoyamaStages,
		CreatedAt: now.Add(-720 * time.Hour),
		UpdatedAt: now.Add(-6 * time.Hour),
	}

	s.queueDefs["atelier-kyoto"] = QueueDefinition{
		ID:             "atelier-kyoto",
		Name:           "京都スタジオ",
		Description:    "和彫り・仕上げ特化の工房。手彫り技術者とQCを兼任する体制。",
		Workshop:       "京都工房",
		ProductLine:    "Heritage / Monogram",
		Priority:       2,
		PriorityLabel:  "P2",
		Capacity:       18,
		TargetSLAHours: 40,
		Active:         true,
		Notes:          []string{"彫金士3名常駐", "QC 兼任体制"},
		Metrics: QueueDefinitionMetrics{
			ThroughputPerShift: 24.0,
			WIPUtilisation:     0.48,
			SLACompliance:      0.82,
		},
		WorkCenters: []QueueWorkCenterAssignment{
			{WorkCenter: s.workCenters["wc-kyoto-hand"], Primary: true},
			{WorkCenter: s.workCenters["wc-kyoto-qc"], Primary: false},
		},
		Roles: []QueueRoleAssignment{
			{Key: "lead", Label: roleLabel("lead"), Headcount: 1},
			{Key: "engraver", Label: roleLabel("engraver"), Headcount: 3},
			{Key: "qc", Label: roleLabel("qc"), Headcount: 1},
			{Key: "packer", Label: roleLabel("packer"), Headcount: 1},
		},
		Stages:    kyotoStages,
		CreatedAt: now.Add(-960 * time.Hour),
		UpdatedAt: now.Add(-12 * time.Hour),
	}

	s.queueSeq = len(s.queueDefs)
	s.upsertQueueSummaryLocked(s.queueDefs["atelier-aoyama"])
	s.upsertQueueSummaryLocked(s.queueDefs["atelier-kyoto"])

	for _, record := range cards {
		timeline := record.timeline
		if len(timeline) > 0 {
			record.card.LastEvent = timeline[0]
		}
		record.card.Timeline = append([]ProductionEvent(nil), timeline...)
		s.cards[record.card.ID] = record
		s.workorders[record.card.ID] = s.buildWorkOrder(record)
		if queue, ok := s.queues[record.card.QueueID]; ok {
			queue.Load++
			s.queues[record.card.QueueID] = queue
		}
	}
}

func (s *StaticService) queueRecords(queueID string) []*cardRecord {
	records := make([]*cardRecord, 0, len(s.cards))
	for _, record := range s.cards {
		if record.card.QueueID != queueID {
			continue
		}
		records = append(records, record)
	}
	sort.Slice(records, func(i, j int) bool {
		return records[i].card.AgingHours > records[j].card.AgingHours
	})
	return records
}

func filterRecords(records []*cardRecord, query BoardQuery) []*cardRecord {
	var result []*cardRecord
	for _, record := range records {
		card := record.card
		if query.Priority != "" && string(card.Priority) != query.Priority {
			continue
		}
		if query.ProductLine != "" && !strings.EqualFold(card.ProductLine, query.ProductLine) {
			continue
		}
		if query.Workstation != "" && !strings.EqualFold(card.Workstation, query.Workstation) {
			continue
		}
		result = append(result, record)
	}
	return result
}

func (s *StaticService) buildLanes(records []*cardRecord) []Lane {
	lanes := make([]Lane, 0, len(s.laneDefs))
	for _, def := range s.laneDefs {
		laneRecords := make([]*cardRecord, 0)
		for _, record := range records {
			if record.card.Stage == def.stage {
				laneRecords = append(laneRecords, record)
			}
		}
		sort.SliceStable(laneRecords, func(i, j int) bool {
			if laneRecords[i].card.Priority != laneRecords[j].card.Priority {
				if laneRecords[i].card.Priority == PriorityRush {
					return true
				}
				if laneRecords[j].card.Priority == PriorityRush {
					return false
				}
			}
			if !laneRecords[i].card.DueAt.Equal(laneRecords[j].card.DueAt) {
				return laneRecords[i].card.DueAt.Before(laneRecords[j].card.DueAt)
			}
			return laneRecords[i].card.OrderNumber < laneRecords[j].card.OrderNumber
		})

		cards := make([]Card, 0, len(laneRecords))
		for _, record := range laneRecords {
			card := cloneCard(record.card)
			card.Timeline = append([]ProductionEvent(nil), record.timeline...)
			cards = append(cards, card)
		}

		lanes = append(lanes, Lane{
			Stage:       def.stage,
			Label:       def.label,
			Description: def.description,
			Capacity:    LaneCapacity{Used: len(cards), Limit: def.capacity},
			SLA:         SLAMeta{Label: def.slaLabel, Tone: def.slaTone},
			Cards:       cards,
		})
	}
	return lanes
}

func (s *StaticService) buildSummary(queue Queue, records []*cardRecord) Summary {
	var dueSoon, blocked int
	now := time.Now()
	for _, record := range records {
		if record.card.Blocked {
			blocked++
		}
		if record.card.DueAt.Sub(now) <= 24*time.Hour {
			dueSoon++
		}
	}
	utilisation := 0
	if queue.Capacity > 0 {
		utilisation = int(float64(queue.Load) / float64(queue.Capacity) * 100)
	}
	return Summary{
		TotalWIP:     len(records),
		DueSoon:      dueSoon,
		Blocked:      blocked,
		AvgLeadHours: queue.LeadTimeHours,
		Utilisation:  utilisation,
		UpdatedAt:    time.Now(),
	}
}

func (s *StaticService) buildFilters(records []*cardRecord, query BoardQuery) FilterSummary {
	countProduct := counter{}
	countPriority := counter{}
	countWorkstation := counter{}

	for _, record := range records {
		countProduct[record.card.ProductLine]++
		countPriority[string(record.card.Priority)]++
		ws := strings.TrimSpace(record.card.Workstation)
		if ws == "" {
			ws = "未割当"
		}
		countWorkstation[ws]++
	}

	priorities := buildFilterOptions(countPriority, query.Priority)
	for i := range priorities {
		priorities[i].Label = priorityDisplay(priorities[i].Value)
	}

	return FilterSummary{
		ProductLines: buildFilterOptions(countProduct, query.ProductLine),
		Priorities:   priorities,
		Workstations: buildFilterOptions(countWorkstation, query.Workstation),
	}
}

func buildFilterOptions(c counter, active string) []FilterOption {
	options := make([]FilterOption, 0, len(c))
	keys := make([]string, 0, len(c))
	for key := range c {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		options = append(options, FilterOption{
			Value:  key,
			Label:  key,
			Count:  c[key],
			Active: strings.EqualFold(key, active),
		})
	}
	return options
}

func priorityDisplay(value string) string {
	switch value {
	case string(PriorityRush):
		return "特急"
	case string(PriorityHold):
		return "保留"
	case string(PriorityNormal):
		fallthrough
	default:
		return "通常"
	}
}

func (s *StaticService) queueOptions(active string) []QueueOption {
	options := make([]QueueOption, 0, len(s.queues))
	for _, queue := range s.queues {
		options = append(options, QueueOption{
			ID:       queue.ID,
			Label:    queue.Name,
			Sublabel: queue.Location,
			Load:     fmt.Sprintf("%d枚進行", queue.Load),
			Active:   queue.ID == active,
		})
	}
	sort.Slice(options, func(i, j int) bool {
		return options[i].Label < options[j].Label
	})
	return options
}

func (s *StaticService) buildDrawer(records []*cardRecord, selected string) (string, Drawer) {
	if len(records) == 0 {
		return "", Drawer{Empty: true}
	}

	var target *cardRecord
	if selected != "" {
		for _, record := range records {
			if record.card.ID == selected {
				target = record
				break
			}
		}
	}
	if target == nil {
		target = records[0]
	}

	card := target.card
	timeline := make([]ProductionEvent, len(target.timeline))
	copy(timeline, target.timeline)

	drawer := Drawer{
		Card: DrawerCard{
			ID:            card.ID,
			OrderNumber:   card.OrderNumber,
			Customer:      card.Customer,
			PriorityLabel: card.PriorityLabel,
			PriorityTone:  card.PriorityTone,
			Stage:         card.Stage,
			StageLabel:    StageLabel(card.Stage),
			ProductLine:   card.ProductLine,
			QueueName:     card.QueueName,
			Workstation:   card.Workstation,
			PreviewURL:    card.PreviewURL,
			PreviewAlt:    card.PreviewAlt,
			DueLabel:      card.DueLabel,
			Notes:         append([]string(nil), card.Notes...),
			Flags:         cloneFlags(card.Flags),
			Assignees:     cloneAssignees(card.Assignees),
			LastUpdated:   card.LastEvent.OccurredAt,
		},
		Timeline: timeline,
		Details: []DrawerDetail{
			{Label: "ステージ", Value: StageLabel(card.Stage)},
			{Label: "ライン", Value: card.QueueName},
			{Label: "ステーション", Value: card.Workstation},
		},
	}

	return card.ID, drawer
}

func newCardRecord(card Card, timeline []ProductionEvent) *cardRecord {
	return &cardRecord{card: card, timeline: timeline}
}

func newQCRecord(card Card, timeline []ProductionEvent, inspection qcInspectionRecord) *cardRecord {
	record := newCardRecord(card, timeline)
	record.inspection = &inspection
	return record
}

func cloneCard(card Card) Card {
	clone := card
	clone.Assignees = cloneAssignees(card.Assignees)
	clone.Flags = cloneFlags(card.Flags)
	clone.Notes = append([]string(nil), card.Notes...)
	clone.Timeline = append([]ProductionEvent(nil), card.Timeline...)
	return clone
}

func cloneAssignees(src []Assignee) []Assignee {
	out := make([]Assignee, len(src))
	copy(out, src)
	return out
}

func cloneFlags(src []CardFlag) []CardFlag {
	out := make([]CardFlag, len(src))
	copy(out, src)
	return out
}

func (s *StaticService) buildWorkOrder(record *cardRecord) WorkOrder {
	card := cloneCard(record.card)
	timeline := append([]ProductionEvent(nil), record.timeline...)
	now := time.Now()

	work := WorkOrder{
		Card:            card,
		ResponsibleTeam: fmt.Sprintf("%s 制作チーム", strings.TrimSpace(card.QueueName)),
		CustomerNote:    strings.Join(card.Notes, " / "),
		Materials:       workOrderMaterials(card),
		Assets:          workOrderAssets(card, now),
		Instructions:    workInstructions(card),
		Checklist:       workChecklist(card, timeline),
		Safety:          workOrderNotices(card),
		Activity:        timeline,
		PDFURL:          fmt.Sprintf("/public/static/workorders/%s.pdf", card.ID),
		LastPrintedAt:   now.Add(-45 * time.Minute),
	}
	return work
}

func workOrderMaterials(card Card) []WorkOrderMaterial {
	source := "青山資材庫"
	if strings.Contains(strings.ToLower(card.QueueID), "kyoto") {
		source = "京都資材庫"
	}
	return []WorkOrderMaterial{
		{
			Name:     "地金",
			Detail:   fmt.Sprintf("%s / %s", card.ProductLine, card.Design),
			Quantity: "1本",
			Source:   source,
			Status:   "準備完了",
		},
		{
			Name:     "石材・加飾",
			Detail:   "1.5mm VS-FG x12 / 漆黒エナメル",
			Quantity: "セット",
			Source:   "宝飾棚B",
			Status:   "ピック済",
		},
		{
			Name:     "消耗材",
			Detail:   "研磨ペースト F-800 / LUX 布バフ",
			Quantity: "適量",
			Source:   "仕上げラック",
			Status:   "常備",
		},
	}
}

func workOrderAssets(card Card, now time.Time) []WorkOrderAsset {
	slug := strings.ReplaceAll(strings.ToLower(card.ID), " ", "-")
	return []WorkOrderAsset{
		{
			ID:          slug + "-cad",
			Name:        fmt.Sprintf("%s CAD", card.Design),
			Kind:        "CAD",
			PreviewURL:  card.PreviewURL,
			DownloadURL: fmt.Sprintf("/public/static/assets/%s-cad.zip", slug),
			Size:        "4.2MB",
			UpdatedAt:   now.Add(-6 * time.Hour),
			Description: "最新版CADデータ（.step/.svg 同梱）",
		},
		{
			ID:          slug + "-render",
			Name:        "顧客共有レンダー",
			Kind:        "Render",
			PreviewURL:  "/public/static/previews/render-default.png",
			DownloadURL: fmt.Sprintf("/public/static/assets/%s-render.png", slug),
			Size:        "1.1MB",
			UpdatedAt:   now.Add(-22 * time.Hour),
			Description: "Notion ブリーフ添付済の PNG レンダリング",
		},
		{
			ID:          slug + "-qc",
			Name:        "QC 測定シート",
			Kind:        "QC",
			PreviewURL:  "/public/static/previews/qc-sheet.png",
			DownloadURL: fmt.Sprintf("/public/static/assets/%s-qc.pdf", slug),
			Size:        "320KB",
			UpdatedAt:   now.Add(-3 * time.Hour),
			Description: "寸法・刻印深さのチェックリスト",
		},
	}
}

func workInstructions(card Card) []WorkInstruction {
	notes := strings.Join(card.Notes, " / ")
	return []WorkInstruction{
		{
			ID:          "prep-brief",
			Title:       "図面・支給品の確認",
			Description: fmt.Sprintf("Notion ブリーフと Firestore 上の顧客指示を突き合わせ、支給品・寸法を記録します。備考: %s", strings.TrimSpace(notes)),
			Stage:       StageQueued,
			StageLabel:  StageLabel(StageQueued),
			Duration:    "15分",
			Tools:       []string{"Notion Brief", "ノギス", "顧客写真"},
		},
		{
			ID:          "engrave-setup",
			Title:       "刻印セットアップ",
			Description: "CNC-02 でフォント設定（S-12 or 指定フォント）を読み込み、試印を実施。深さ 0.25mm 以内に収めること。",
			Stage:       StageEngraving,
			StageLabel:  StageLabel(StageEngraving),
			Duration:    "40分",
			Tools:       []string{"CNC-02", "Gravograph", "吸引カバー"},
		},
		{
			ID:          "polish-finish",
			Title:       "研磨・仕上げ",
			Description: "バフ→ミラー仕上げ。ダイヤ加飾がある場合は F-800 で軽く整えてから超音波洗浄。",
			Stage:       StagePolishing,
			StageLabel:  StageLabel(StagePolishing),
			Duration:    "25分",
			Tools:       []string{"POL-01", "超音波洗浄", "ルーペ 10x"},
		},
		{
			ID:          "qc-hand-off",
			Title:       "QC 連携 & 梱包",
			Description: "QC シートに測定値を記入し、写真添付。問題なければ付属品と一緒に梱包担当へ引き渡し。",
			Stage:       StageQC,
			StageLabel:  StageLabel(StageQC),
			Duration:    "20分",
			Tools:       []string{"QC-02", "測定シート", "付属品リスト"},
		},
	}
}

func workChecklist(card Card, timeline []ProductionEvent) []WorkChecklistItem {
	items := []WorkChecklistItem{
		{ID: "prep", Label: "段取り完了", Description: "支給品照合・材料ピック", Stage: StageQueued},
		{ID: "engrave", Label: "刻印完了", Description: "CNC/手彫りの仕上がり確認", Stage: StageEngraving},
		{ID: "polish", Label: "研磨完了", Description: "表面処理と洗浄", Stage: StagePolishing},
		{ID: "qc", Label: "QC合格", Description: "寸法/刻印深さ記録、写真添付", Stage: StageQC},
		{ID: "pack", Label: "梱包完了", Description: "付属品セット・伝票添付", Stage: StagePacked},
	}
	for i := range items {
		items[i].StageLabel = StageLabel(items[i].Stage)
		items[i].Completed = stageReached(card.Stage, items[i].Stage)
		if items[i].Completed {
			items[i].CompletedAt = stageCompletionTime(timeline, items[i].Stage)
		}
	}
	return items
}

func workOrderNotices(card Card) []WorkOrderNotice {
	return []WorkOrderNotice{
		{
			Title: "レーザー刻印の安全対策",
			Body:  "CNC/レーザー稼働中は必ず防護カバーを閉じ、排気ファンをオンにしてください。",
			Tone:  "warning",
			Icon:  "⚠️",
		},
		{
			Title: "QC ダブルチェック",
			Body:  "VIP/特急案件は寸法記録と刻印写真を Slack #production-qc にアップロードしてから梱包へ回します。",
			Tone:  "info",
			Icon:  "🧪",
		},
	}
}

func stageReached(current Stage, target Stage) bool {
	return stageWeight(current) >= stageWeight(target)
}

func stageWeight(stage Stage) int {
	switch stage {
	case StageQueued:
		return 0
	case StageEngraving:
		return 1
	case StagePolishing:
		return 2
	case StageQC:
		return 3
	case StagePacked:
		return 4
	default:
		return -1
	}
}

func stageCompletionTime(events []ProductionEvent, stage Stage) time.Time {
	for _, event := range events {
		if event.Stage == stage {
			return event.OccurredAt
		}
	}
	return time.Time{}
}

func cloneWorkOrder(src WorkOrder) WorkOrder {
	clone := WorkOrder{
		Card:            cloneCard(src.Card),
		ResponsibleTeam: src.ResponsibleTeam,
		CustomerNote:    src.CustomerNote,
		PDFURL:          src.PDFURL,
		LastPrintedAt:   src.LastPrintedAt,
	}
	clone.Materials = append([]WorkOrderMaterial(nil), src.Materials...)
	clone.Assets = append([]WorkOrderAsset(nil), src.Assets...)
	clone.Safety = append([]WorkOrderNotice(nil), src.Safety...)
	clone.Activity = append([]ProductionEvent(nil), src.Activity...)

	if len(src.Instructions) > 0 {
		clone.Instructions = make([]WorkInstruction, len(src.Instructions))
		for i, instr := range src.Instructions {
			clone.Instructions[i] = instr
			clone.Instructions[i].Tools = append([]string(nil), instr.Tools...)
		}
	}
	if len(src.Checklist) > 0 {
		clone.Checklist = make([]WorkChecklistItem, len(src.Checklist))
		copy(clone.Checklist, src.Checklist)
	}
	return clone
}

func appendUnique(list []string, value string) []string {
	value = strings.TrimSpace(value)
	if value == "" {
		return list
	}
	for _, existing := range list {
		if existing == value {
			return list
		}
	}
	return append(list, value)
}

func isValidStage(stage Stage) bool {
	switch stage {
	case StageQueued, StageEngraving, StagePolishing, StageQC, StagePacked:
		return true
	default:
		return false
	}
}

func coalesce(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func (s *StaticService) qcRecords(queueID string) []*cardRecord {
	records := make([]*cardRecord, 0, len(s.cards))
	for _, record := range s.cards {
		if record.card.QueueID != queueID || record.inspection == nil {
			continue
		}
		if record.inspection.Status == QCStatusComplete {
			continue
		}
		records = append(records, record)
	}
	sort.Slice(records, func(i, j int) bool {
		return records[i].inspection.ReceivedAt.Before(records[j].inspection.ReceivedAt)
	})
	return records
}

func filterQCRecords(records []*cardRecord, query QCQuery) []*cardRecord {
	var filtered []*cardRecord
	statusFilter := strings.TrimSpace(query.Status)
	for _, record := range records {
		inspection := record.inspection
		if inspection == nil {
			continue
		}
		if query.ProductLine != "" && !strings.EqualFold(record.card.ProductLine, query.ProductLine) {
			continue
		}
		if query.IssueType != "" && !strings.EqualFold(inspection.IssueType, query.IssueType) {
			continue
		}
		if query.Assignee != "" && !strings.EqualFold(qcAssignee(record), query.Assignee) {
			continue
		}
		if statusFilter != "" && string(inspection.Status) != statusFilter {
			continue
		}
		filtered = append(filtered, record)
	}
	return filtered
}

func (s *StaticService) buildQCItems(records []*cardRecord) []QCItem {
	items := make([]QCItem, 0, len(records))
	for _, record := range records {
		items = append(items, s.qcItemFromRecord(record))
	}
	return items
}

func (s *StaticService) buildQCDrawer(records []*cardRecord, selected string) (string, QCInspector) {
	if len(records) == 0 {
		return "", QCInspector{Empty: true, Reasons: cloneReasons(s.qcReasons), ReworkRoutes: cloneRoutes(s.qcRoutes)}
	}

	var target *cardRecord
	if selected != "" {
		for _, record := range records {
			if record.card.ID == selected {
				target = record
				break
			}
		}
	}
	if target == nil {
		target = records[0]
	}
	if target.inspection == nil {
		return "", QCInspector{Empty: true, Reasons: cloneReasons(s.qcReasons), ReworkRoutes: cloneRoutes(s.qcRoutes)}
	}

	card := target.card
	inspection := target.inspection
	drawer := QCInspector{
		Item: QCItemDetail{
			ID:            card.ID,
			OrderNumber:   card.OrderNumber,
			Customer:      card.Customer,
			ProductLine:   card.ProductLine,
			PriorityLabel: card.PriorityLabel,
			PriorityTone:  card.PriorityTone,
			StageLabel:    StageLabel(card.Stage),
			StageTone:     stageBadgeTone(card.Stage),
			Assigned:      qcAssignee(target),
			DueLabel:      card.DueLabel,
			DueTone:       card.DueTone,
			PreviewURL:    card.PreviewURL,
		},
		Checklist:    cloneChecklist(inspection.Checklist),
		Issues:       cloneIssues(inspection.Issues),
		Attachments:  cloneAttachments(inspection.Attachments),
		Reasons:      cloneReasons(s.qcReasons),
		ReworkRoutes: cloneRoutes(s.qcRoutes),
		Notes:        append([]string(nil), inspection.Notes...),
	}
	return card.ID, drawer
}

func (s *StaticService) qcAlert(queueID string) string {
	if queueID == "atelier-aoyama" {
		return "QC-02 カメラ調整中。写真検品はQC-01へ振り替えてください。"
	}
	return "QCライン稼働率 78%。遅延は発生していません。"
}

func (s *StaticService) qcSummary(records []*cardRecord) []QCSummary {
	total := len(records)
	failed := 0
	for _, record := range records {
		if record.inspection != nil && record.inspection.Status == QCStatusFailed {
			failed++
		}
	}
	return []QCSummary{
		{Label: "待機中", Value: fmt.Sprintf("%d件", total), Icon: "🧪", Tone: "info", SubText: "QCキュー全体"},
		{Label: "要再検", Value: fmt.Sprintf("%d件", failed), Icon: "⚠", Tone: "warning", SubText: "再作業手配待ち"},
		{Label: "平均滞留", Value: "22分", Icon: "⏱", Tone: "success", SubText: "SLA 30分以内"},
	}
}

func (s *StaticService) qcPerformance(records []*cardRecord) []QCSummary {
	return []QCSummary{
		{Label: "合格率", Value: "94%", Delta: "+2pt vs 昨日", Tone: "success"},
		{Label: "再作業比率", Value: "8%", Delta: "-1pt vs 週間", Tone: "warning"},
		{Label: "平均ハンドルタイム", Value: "18分", Delta: "-3分 vs 週間", Tone: "info"},
	}
}

func (s *StaticService) qcFilters(records []*cardRecord, query QCQuery) QCFilters {
	productMap := make(map[string]FilterOption)
	issueMap := make(map[string]FilterOption)
	assigneeMap := make(map[string]FilterOption)
	statusMap := make(map[string]FilterOption)

	for _, record := range records {
		card := record.card
		inspection := record.inspection
		if inspection == nil {
			continue
		}
		addFilterOption(productMap, card.ProductLine, card.ProductLine)
		addFilterOption(issueMap, inspection.IssueType, inspection.IssueType)
		addFilterOption(assigneeMap, qcAssignee(record), qcAssignee(record))
		statusLabel := statusLabel(inspection.Status)
		addFilterOption(statusMap, string(inspection.Status), statusLabel)
	}

	return QCFilters{
		ProductLines: filterOptionMapToSlice(productMap, query.ProductLine),
		IssueTypes:   filterOptionMapToSlice(issueMap, query.IssueType),
		Assignees:    filterOptionMapToSlice(assigneeMap, query.Assignee),
		Statuses:     filterOptionMapToSlice(statusMap, query.Status),
		Query:        query,
	}
}

func (s *StaticService) qcItemFromRecord(record *cardRecord) QCItem {
	card := record.card
	inspection := record.inspection
	item := QCItem{
		ID:            card.ID,
		OrderNumber:   card.OrderNumber,
		Customer:      card.Customer,
		ProductLine:   card.ProductLine,
		ItemType:      card.Design,
		Stage:         card.Stage,
		StageLabel:    StageLabel(card.Stage),
		StageTone:     stageBadgeTone(card.Stage),
		Assigned:      qcAssignee(record),
		Workstation:   card.Workstation,
		PriorityLabel: card.PriorityLabel,
		PriorityTone:  card.PriorityTone,
		Flags:         cloneFlags(card.Flags),
		IssueHint:     inspection.IssueHint,
		QueueID:       card.QueueID,
		PreviewURL:    card.PreviewURL,
		Status:        inspection.Status,
		StatusLabel:   statusLabel(inspection.Status),
		StatusTone:    statusTone(inspection.Status),
	}
	if inspection.SLALabel != "" {
		item.SLA = inspection.SLALabel
		item.SLATone = inspection.SLATone
	} else {
		item.SLA = card.DueLabel
		item.SLATone = card.DueTone
	}
	item.AgingLabel = card.DueLabel
	item.AgingTone = card.DueTone
	return item
}

func statusLabel(status QCStatus) string {
	switch status {
	case QCStatusPending:
		return "待機中"
	case QCStatusFailed:
		return "要再検"
	case QCStatusComplete:
		return "処理済"
	default:
		return string(status)
	}
}

func statusTone(status QCStatus) string {
	switch status {
	case QCStatusPending:
		return "info"
	case QCStatusFailed:
		return "warning"
	case QCStatusComplete:
		return "success"
	default:
		return "default"
	}
}

func stageBadgeTone(stage Stage) string {
	switch stage {
	case StageQC:
		return "info"
	case StagePolishing:
		return "warning"
	case StageEngraving:
		return "info"
	case StagePacked:
		return "success"
	default:
		return "info"
	}
}

func qcAssignee(record *cardRecord) string {
	if len(record.card.Assignees) > 0 {
		return record.card.Assignees[0].Name
	}
	return record.card.Workstation
}

func (s *StaticService) findReworkRoute(id string) (QCReworkRoute, bool) {
	for _, route := range s.qcRoutes {
		if route.ID == id {
			return route, true
		}
	}
	return QCReworkRoute{}, false
}

func (s *StaticService) reasonLabel(code string) string {
	for _, reason := range s.qcReasons {
		if reason.Code == code {
			return reason.Label
		}
	}
	return ""
}

func (s *StaticService) prependTimeline(record *cardRecord, event ProductionEvent) {
	record.timeline = append([]ProductionEvent{event}, record.timeline...)
	record.card.LastEvent = event
	record.card.Timeline = append([]ProductionEvent(nil), record.timeline...)
}

func appendFlag(flags []CardFlag, flag CardFlag) []CardFlag {
	flag.Label = strings.TrimSpace(flag.Label)
	if flag.Label == "" {
		return flags
	}
	for _, existing := range flags {
		if existing.Label == flag.Label {
			return flags
		}
	}
	return append(flags, flag)
}

func removeFlag(flags []CardFlag, label string) []CardFlag {
	if label == "" || len(flags) == 0 {
		return flags
	}
	result := make([]CardFlag, 0, len(flags))
	for _, flag := range flags {
		if flag.Label == label {
			continue
		}
		result = append(result, flag)
	}
	return result
}

func cloneChecklist(items []QCChecklistItem) []QCChecklistItem {
	out := make([]QCChecklistItem, len(items))
	copy(out, items)
	return out
}

func cloneIssues(items []QCIssueRecord) []QCIssueRecord {
	out := make([]QCIssueRecord, len(items))
	copy(out, items)
	return out
}

func cloneAttachments(items []QCAttachment) []QCAttachment {
	out := make([]QCAttachment, len(items))
	copy(out, items)
	return out
}

func buildQCAttachments(values []string, cardID string, now time.Time) []QCAttachment {
	var attachments []QCAttachment
	for _, raw := range values {
		if strings.TrimSpace(raw) == "" {
			continue
		}
		chunks := strings.Split(raw, "\n")
		for _, chunk := range chunks {
			url := strings.TrimSpace(chunk)
			if url == "" {
				continue
			}
			attachments = append(attachments, QCAttachment{
				ID:    fmt.Sprintf("attach-%s-%d", cardID, now.UnixNano()),
				URL:   url,
				Label: "参考画像",
				Kind:  "photo",
			})
		}
	}
	return attachments
}

func (s *StaticService) QueueSettings(_ context.Context, _ string, query QueueSettingsQuery) (QueueSettingsResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	normalized := QueueSettingsQuery{
		Workshop:    strings.TrimSpace(query.Workshop),
		Status:      strings.TrimSpace(query.Status),
		ProductLine: strings.TrimSpace(query.ProductLine),
		Search:      strings.TrimSpace(query.Search),
		SelectedID:  strings.TrimSpace(query.SelectedID),
	}

	workshopCounts := make(map[string]int)
	productCounts := make(map[string]int)
	statusCounts := map[string]int{"active": 0, "inactive": 0}

	filtered := make([]QueueDefinition, 0, len(s.queueDefs))

	for _, def := range s.queueDefs {
		workshopCounts[def.Workshop]++
		productCounts[def.ProductLine]++
		if def.Active {
			statusCounts["active"]++
		} else {
			statusCounts["inactive"]++
		}

		if normalized.Workshop != "" && !strings.EqualFold(def.Workshop, normalized.Workshop) {
			continue
		}

		if normalized.Status != "" {
			switch strings.ToLower(normalized.Status) {
			case "active":
				if !def.Active {
					continue
				}
			case "inactive":
				if def.Active {
					continue
				}
			}
		}

		if normalized.ProductLine != "" && !strings.Contains(strings.ToLower(def.ProductLine), strings.ToLower(normalized.ProductLine)) {
			continue
		}

		if normalized.Search != "" {
			needle := strings.ToLower(normalized.Search)
			if !strings.Contains(strings.ToLower(def.Name), needle) && !strings.Contains(strings.ToLower(def.Description), needle) {
				continue
			}
		}

		filtered = append(filtered, cloneQueueDefinition(def))
	}

	sort.Slice(filtered, func(i, j int) bool {
		if filtered[i].Priority != filtered[j].Priority {
			return filtered[i].Priority < filtered[j].Priority
		}
		return strings.Compare(strings.ToLower(filtered[i].Name), strings.ToLower(filtered[j].Name)) < 0
	})

	var (
		slaTotal       float64
		throughputSum  float64
		utilisationSum float64
	)

	summary := QueueSettingsSummary{}

	for _, def := range filtered {
		summary.TotalCapacity += def.Capacity
		if def.Active {
			summary.ActiveQueues++
		}
		slaTotal += float64(def.TargetSLAHours)
		throughputSum += def.Metrics.ThroughputPerShift
		utilisationSum += def.Metrics.WIPUtilisation
	}

	summary.TotalQueues = len(filtered)
	if summary.TotalQueues > 0 {
		summary.AverageSLAHours = slaTotal / float64(summary.TotalQueues)
	}

	var analytics QueueAnalytics
	if len(filtered) > 0 {
		analytics.AverageThroughputPerShift = throughputSum / float64(len(filtered))
		analytics.AverageWIPUtilisation = utilisationSum / float64(len(filtered))
	}

	result := QueueSettingsResult{
		Queues: filtered,
		Filters: QueueSettingsFilters{
			Workshops:    queueFilterOptionsFromMap(workshopCounts),
			ProductLines: queueFilterOptionsFromMap(productCounts),
			Statuses: []QueueFilterOption{
				{Value: "active", Label: "稼働中", Count: statusCounts["active"]},
				{Value: "inactive", Label: "停止中", Count: statusCounts["inactive"]},
			},
		},
		Summary:   summary,
		Analytics: analytics,
	}

	return result, nil
}

func (s *StaticService) QueueSettingsDetail(_ context.Context, _ string, queueID string) (QueueDefinition, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	id := strings.TrimSpace(queueID)
	if id == "" {
		return QueueDefinition{}, ErrQueueNotFound
	}

	def, ok := s.queueDefs[id]
	if !ok {
		return QueueDefinition{}, ErrQueueNotFound
	}

	return cloneQueueDefinition(def), nil
}

func (s *StaticService) QueueSettingsOptions(_ context.Context, _ string) (QueueSettingsOptions, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	centers := make([]QueueWorkCenter, 0, len(s.workCenters))
	for _, center := range s.workCenters {
		centers = append(centers, center)
	}
	sort.Slice(centers, func(i, j int) bool {
		return strings.Compare(strings.ToLower(centers[i].Name), strings.ToLower(centers[j].Name)) < 0
	})

	roleOptions := make([]QueueRoleOption, len(s.roleOptions))
	copy(roleOptions, s.roleOptions)
	sort.Slice(roleOptions, func(i, j int) bool {
		return strings.Compare(strings.ToLower(roleOptions[i].Label), strings.ToLower(roleOptions[j].Label)) < 0
	})

	stageTemplates := s.defaultStageTemplatesLocked()

	return QueueSettingsOptions{
		WorkCenters:    centers,
		RoleOptions:    roleOptions,
		StageTemplates: stageTemplates,
	}, nil
}

func (s *StaticService) CreateQueueDefinition(_ context.Context, _ string, input QueueDefinitionInput) (QueueDefinition, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	name := strings.TrimSpace(input.Name)
	if name == "" {
		return QueueDefinition{}, ErrQueueInvalidInput
	}
	if input.Capacity <= 0 {
		return QueueDefinition{}, ErrQueueInvalidInput
	}

	for _, def := range s.queueDefs {
		if strings.EqualFold(def.Name, name) {
			return QueueDefinition{}, ErrQueueNameExists
		}
	}

	s.queueSeq++
	id := fmt.Sprintf("queue-%04d", s.queueSeq)
	now := time.Now()

	def := QueueDefinition{
		ID:             id,
		Name:           name,
		Description:    strings.TrimSpace(input.Description),
		Workshop:       strings.TrimSpace(input.Workshop),
		ProductLine:    strings.TrimSpace(input.ProductLine),
		Priority:       input.Priority,
		PriorityLabel:  queuePriorityLabel(input.Priority),
		Capacity:       input.Capacity,
		TargetSLAHours: maxInt(input.TargetSLAHours, 1),
		Active:         input.Active,
		Notes:          copyStrings(uniqueStrings(input.Notes)),
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	def.WorkCenters = s.resolveWorkCentersLocked(input.WorkCenterIDs, input.PrimaryWorkCenterID)
	def.Roles = s.resolveRoleAssignmentsLocked(input.Roles)
	def.Stages = s.buildStagesFromInputLocked(input.Stages, s.defaultStageTemplatesLocked())
	def.Metrics = calculateQueueMetrics(def.Capacity, def.Metrics)

	s.queueDefs[id] = def
	s.upsertQueueSummaryLocked(def)

	return cloneQueueDefinition(def), nil
}

func (s *StaticService) UpdateQueueDefinition(_ context.Context, _ string, queueID string, input QueueDefinitionInput) (QueueDefinition, error) {
	id := strings.TrimSpace(queueID)
	if id == "" {
		return QueueDefinition{}, ErrQueueNotFound
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	def, ok := s.queueDefs[id]
	if !ok {
		return QueueDefinition{}, ErrQueueNotFound
	}

	name := strings.TrimSpace(input.Name)
	if name == "" {
		return QueueDefinition{}, ErrQueueInvalidInput
	}
	if input.Capacity <= 0 {
		return QueueDefinition{}, ErrQueueInvalidInput
	}

	for otherID, existing := range s.queueDefs {
		if otherID == id {
			continue
		}
		if strings.EqualFold(existing.Name, name) {
			return QueueDefinition{}, ErrQueueNameExists
		}
	}

	def.Name = name
	def.Description = strings.TrimSpace(input.Description)
	def.Workshop = strings.TrimSpace(input.Workshop)
	def.ProductLine = strings.TrimSpace(input.ProductLine)
	def.Priority = input.Priority
	def.PriorityLabel = queuePriorityLabel(input.Priority)
	def.Capacity = input.Capacity
	def.TargetSLAHours = maxInt(input.TargetSLAHours, 1)
	def.Active = input.Active
	def.Notes = copyStrings(uniqueStrings(input.Notes))
	def.WorkCenters = s.resolveWorkCentersLocked(input.WorkCenterIDs, input.PrimaryWorkCenterID)
	def.Roles = s.resolveRoleAssignmentsLocked(input.Roles)
	def.Stages = s.buildStagesFromInputLocked(input.Stages, def.Stages)
	def.Metrics = calculateQueueMetrics(def.Capacity, def.Metrics)
	def.UpdatedAt = time.Now()

	s.queueDefs[id] = def
	s.upsertQueueSummaryLocked(def)

	return cloneQueueDefinition(def), nil
}

func (s *StaticService) DeleteQueueDefinition(_ context.Context, _ string, queueID string) error {
	id := strings.TrimSpace(queueID)
	if id == "" {
		return ErrQueueNotFound
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.queueDefs[id]; !ok {
		return ErrQueueNotFound
	}

	if s.queueHasCardsLocked(id) {
		return ErrQueueInvalidInput
	}

	delete(s.queueDefs, id)
	delete(s.queues, id)

	if strings.EqualFold(s.defaultQueue, id) {
		s.defaultQueue = s.pickDefaultQueueLocked()
	}

	return nil
}

func (s *StaticService) resolveWorkCentersLocked(ids []string, primary string) []QueueWorkCenterAssignment {
	if len(ids) == 0 {
		return nil
	}
	assignments := make([]QueueWorkCenterAssignment, 0, len(ids))
	seen := make(map[string]bool)
	primaryID := strings.TrimSpace(primary)

	for idx, rawID := range ids {
		id := strings.TrimSpace(rawID)
		if id == "" || seen[strings.ToLower(id)] {
			continue
		}
		center, ok := s.workCenters[id]
		if !ok {
			continue
		}
		assignment := QueueWorkCenterAssignment{
			WorkCenter: center,
			Primary:    false,
		}
		if primaryID == "" && idx == 0 {
			assignment.Primary = true
		} else if primaryID != "" && strings.EqualFold(primaryID, id) {
			assignment.Primary = true
		}
		assignments = append(assignments, assignment)
		seen[strings.ToLower(id)] = true
	}

	if len(assignments) == 0 {
		return nil
	}

	if primaryID != "" {
		found := false
		for i := range assignments {
			if strings.EqualFold(assignments[i].WorkCenter.ID, primaryID) {
				assignments[i].Primary = true
				found = true
			} else {
				assignments[i].Primary = false
			}
		}
		if !found {
			assignments[0].Primary = true
		}
	} else {
		assignments[0].Primary = true
	}

	return assignments
}

func (s *StaticService) resolveRoleAssignmentsLocked(inputs []QueueRoleAssignmentInput) []QueueRoleAssignment {
	if len(inputs) == 0 {
		return nil
	}

	options := make(map[string]QueueRoleOption, len(s.roleOptions))
	for _, opt := range s.roleOptions {
		options[opt.Key] = opt
	}

	assignments := make([]QueueRoleAssignment, 0, len(inputs))

	for _, input := range inputs {
		key := strings.TrimSpace(input.Key)
		if key == "" || input.Headcount <= 0 {
			continue
		}
		label := key
		if opt, ok := options[key]; ok {
			label = opt.Label
		}
		assignments = append(assignments, QueueRoleAssignment{
			Key:       key,
			Label:     label,
			Headcount: input.Headcount,
		})
	}

	if len(assignments) == 0 {
		return nil
	}

	sort.Slice(assignments, func(i, j int) bool {
		return strings.Compare(strings.ToLower(assignments[i].Label), strings.ToLower(assignments[j].Label)) < 0
	})

	return assignments
}

func (s *StaticService) buildStagesFromInputLocked(inputs []QueueStageInput, fallback []QueueStage) []QueueStage {
	if len(inputs) == 0 {
		return cloneQueueStages(fallback)
	}

	stages := make([]QueueStage, 0, len(inputs))
	for idx, stage := range inputs {
		label := strings.TrimSpace(stage.Label)
		code := stage.Code
		if code == "" && label != "" {
			code = Stage(strings.ToLower(strings.ReplaceAll(label, " ", "_")))
		}
		if label == "" {
			label = StageLabel(code)
		}
		description := strings.TrimSpace(stage.Description)
		wipLimit := stage.WIPLimit
		if wipLimit <= 0 {
			wipLimit = 4
		}
		target := stage.TargetSLAHours
		if target <= 0 {
			target = 4
		}
		stages = append(stages, QueueStage{
			Code:           code,
			Label:          label,
			Sequence:       idx + 1,
			Description:    description,
			WIPLimit:       wipLimit,
			TargetSLAHours: target,
		})
	}
	return stages
}

func (s *StaticService) defaultStageTemplatesLocked() []QueueStage {
	if def, ok := s.queueDefs[s.defaultQueue]; ok && len(def.Stages) > 0 {
		return cloneQueueStages(def.Stages)
	}
	templates := make([]QueueStage, 0, len(s.laneDefs))
	for idx, lane := range s.laneDefs {
		templates = append(templates, QueueStage{
			Code:           lane.stage,
			Label:          lane.label,
			Sequence:       idx + 1,
			Description:    lane.description,
			WIPLimit:       maxInt(lane.capacity, 1),
			TargetSLAHours: parseHoursFromLabel(lane.slaLabel, 6),
		})
	}
	return templates
}

func parseHoursFromLabel(label string, fallback int) int {
	digits := strings.Builder{}
	for _, r := range label {
		if unicode.IsDigit(r) {
			digits.WriteRune(r)
		}
	}
	if digits.Len() == 0 {
		return fallback
	}
	value, err := strconv.Atoi(digits.String())
	if err != nil {
		return fallback
	}
	return value
}

func (s *StaticService) upsertQueueSummaryLocked(def QueueDefinition) {
	queue := Queue{
		ID:            def.ID,
		Name:          def.Name,
		Description:   def.Description,
		Location:      def.Workshop,
		Shift:         "09:00-18:00",
		Capacity:      def.Capacity,
		Load:          0,
		Utilisation:   math.Round(def.Metrics.WIPUtilisation * 100),
		LeadTimeHours: def.TargetSLAHours,
		Notes:         copyStrings(def.Notes),
	}

	if existing, ok := s.queues[def.ID]; ok {
		queue.Load = existing.Load
		if strings.TrimSpace(existing.Shift) != "" {
			queue.Shift = existing.Shift
		}
		if len(existing.Notes) > 0 && len(queue.Notes) == 0 {
			queue.Notes = append([]string{}, existing.Notes...)
		}
	}

	s.queues[def.ID] = queue
}

func (s *StaticService) queueHasCardsLocked(queueID string) bool {
	for _, record := range s.cards {
		if strings.EqualFold(record.card.QueueID, queueID) {
			return true
		}
	}
	return false
}

func (s *StaticService) pickDefaultQueueLocked() string {
	if _, ok := s.queueDefs[s.defaultQueue]; ok {
		return s.defaultQueue
	}
	for id := range s.queueDefs {
		return id
	}
	return ""
}

func queuePriorityLabel(priority int) string {
	if priority <= 0 {
		return "P3"
	}
	return fmt.Sprintf("P%d", priority)
}

func queueFilterOptionsFromMap(values map[string]int) []QueueFilterOption {
	if len(values) == 0 {
		return nil
	}
	options := make([]QueueFilterOption, 0, len(values))
	for value, count := range values {
		label := strings.TrimSpace(value)
		if label == "" {
			label = "未設定"
		}
		options = append(options, QueueFilterOption{
			Value: value,
			Label: label,
			Count: count,
		})
	}
	sort.Slice(options, func(i, j int) bool {
		return strings.Compare(strings.ToLower(options[i].Label), strings.ToLower(options[j].Label)) < 0
	})
	return options
}

func cloneQueueDefinition(def QueueDefinition) QueueDefinition {
	out := def
	out.Notes = copyStrings(def.Notes)
	out.WorkCenters = cloneQueueWorkCenters(def.WorkCenters)
	out.Roles = cloneQueueRoles(def.Roles)
	out.Stages = cloneQueueStages(def.Stages)
	return out
}

func cloneQueueStages(stages []QueueStage) []QueueStage {
	if len(stages) == 0 {
		return nil
	}
	out := make([]QueueStage, len(stages))
	copy(out, stages)
	return out
}

func cloneQueueWorkCenters(items []QueueWorkCenterAssignment) []QueueWorkCenterAssignment {
	if len(items) == 0 {
		return nil
	}
	out := make([]QueueWorkCenterAssignment, len(items))
	copy(out, items)
	return out
}

func cloneQueueRoles(items []QueueRoleAssignment) []QueueRoleAssignment {
	if len(items) == 0 {
		return nil
	}
	out := make([]QueueRoleAssignment, len(items))
	copy(out, items)
	return out
}

func copyStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, v := range values {
		trimmed := strings.TrimSpace(v)
		if trimmed == "" {
			continue
		}
		out = append(out, trimmed)
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func uniqueStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	seen := make(map[string]bool)
	result := make([]string, 0, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		key := strings.ToLower(trimmed)
		if seen[key] {
			continue
		}
		seen[key] = true
		result = append(result, trimmed)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func maxInt(value, fallback int) int {
	if value <= 0 {
		return fallback
	}
	return value
}

func calculateQueueMetrics(capacity int, existing QueueDefinitionMetrics) QueueDefinitionMetrics {
	if capacity <= 0 {
		capacity = 1
	}
	throughput := float64(capacity) * 1.3
	if existing.ThroughputPerShift > 0 {
		throughput = math.Max(existing.ThroughputPerShift*0.85, throughput)
	}
	utilisation := math.Min(0.95, float64(capacity)/float64(capacity+12))
	sla := existing.SLACompliance
	if sla <= 0 {
		sla = 0.85
	}
	return QueueDefinitionMetrics{
		ThroughputPerShift: throughput,
		WIPUtilisation:     utilisation,
		SLACompliance:      sla,
	}
}

func cloneReasons(items []QCReason) []QCReason {
	out := make([]QCReason, len(items))
	copy(out, items)
	return out
}

func cloneRoutes(items []QCReworkRoute) []QCReworkRoute {
	out := make([]QCReworkRoute, len(items))
	copy(out, items)
	return out
}

func addFilterOption(store map[string]FilterOption, value, label string) {
	key := strings.ToLower(strings.TrimSpace(value))
	if key == "" {
		key = strings.ToLower(strings.TrimSpace(label))
	}
	option, ok := store[key]
	if !ok {
		option = FilterOption{Value: strings.TrimSpace(value)}
		if option.Value == "" {
			option.Value = strings.TrimSpace(label)
		}
		option.Label = strings.TrimSpace(label)
	}
	option.Count++
	store[key] = option
}

func filterOptionMapToSlice(store map[string]FilterOption, active string) []FilterOption {
	if len(store) == 0 {
		return nil
	}
	options := make([]FilterOption, 0, len(store))
	for _, option := range store {
		option.Active = strings.EqualFold(option.Value, active)
		options = append(options, option)
	}
	sort.Slice(options, func(i, j int) bool {
		return strings.Compare(strings.ToLower(options[i].Label), strings.ToLower(options[j].Label)) < 0
	})
	return options
}
