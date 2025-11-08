package ui

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	productiontpl "finitefield.org/hanko-admin/internal/admin/templates/production"
)

// ProductionQueuesPage renders the production kanban board page.
func (h *Handlers) ProductionQueuesPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildProductionBoardRequest(r)
	result, err := h.production.Board(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("production: fetch board failed: %v", err)
		errMsg = "制作ボードの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminproduction.BoardResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	data := productiontpl.BuildPageData(basePath, req.state, result, errMsg)

	templ.Handler(productiontpl.Index(data)).ServeHTTP(w, r)
}

// ProductionQueuesSummaryPage renders the WIP summary page across production queues.
func (h *Handlers) ProductionQueuesSummaryPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildProductionSummaryRequest(r)
	result, err := h.production.QueueWIPSummary(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("production: fetch wip summary failed: %v", err)
		errMsg = "WIPサマリーの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminproduction.QueueWIPSummaryResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	data := productiontpl.BuildWIPSummaryPage(ctx, basePath, req.state, result, errMsg)

	templ.Handler(productiontpl.WIPSummary(data)).ServeHTTP(w, r)
}

// ProductionQueuesBoard renders the kanban fragment for HTMX swaps.
func (h *Handlers) ProductionQueuesBoard(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildProductionBoardRequest(r)
	result, err := h.production.Board(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("production: fetch board fragment failed: %v", err)
		errMsg = "制作ボードの取得に失敗しました。"
		result = adminproduction.BoardResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	board := productiontpl.BuildBoard(basePath, req.state, result, errMsg)

	if canonical := canonicalProductionURL(basePath, req); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(productiontpl.Board(board)).ServeHTTP(w, r)
}

// ProductionWorkOrderPage renders the detailed work order view for a single order.
func (h *Handlers) ProductionWorkOrderPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		http.Error(w, "注文IDが不正です。", http.StatusBadRequest)
		return
	}

	workOrder, err := h.production.WorkOrder(ctx, user.Token, orderID)
	if err != nil {
		if errors.Is(err, adminproduction.ErrWorkOrderNotFound) || errors.Is(err, adminproduction.ErrCardNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("production: fetch work order failed: %v", err)
		http.Error(w, "作業指示書の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	data := productiontpl.BuildWorkOrderPage(basePath, workOrder)

	templ.Handler(productiontpl.WorkOrder(data)).ServeHTTP(w, r)
}

// ProductionQCPage renders the QC worklist page.
func (h *Handlers) ProductionQCPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	query := buildProductionQCQuery(r)
	result, err := h.production.QCOverview(ctx, user.Token, query)
	errMsg := ""
	if err != nil {
		log.Printf("production: fetch qc overview failed: %v", err)
		errMsg = "QCキューの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminproduction.QCResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	data := productiontpl.BuildQCPageData(basePath, result, errMsg)
	templ.Handler(productiontpl.QCPage(data)).ServeHTTP(w, r)
}

// ProductionQCDrawer renders the QC drawer fragment.
func (h *Handlers) ProductionQCDrawer(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		http.Error(w, "注文IDが不正です。", http.StatusBadRequest)
		return
	}

	query := buildProductionQCQuery(r)
	query.Selected = orderID

	result, err := h.production.QCOverview(ctx, user.Token, query)
	if err != nil {
		if errors.Is(err, adminproduction.ErrQueueNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("production: fetch qc drawer failed: %v", err)
		http.Error(w, "QCデータの取得に失敗しました。", http.StatusBadGateway)
		return
	}
	if result.Drawer.Empty || result.Drawer.Item.ID == "" || result.Drawer.Item.ID != orderID {
		http.NotFound(w, r)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	drawer := productiontpl.BuildQCDrawer(basePath, result.Drawer, query)
	templ.Handler(productiontpl.QCDrawer(drawer)).ServeHTTP(w, r)
}

// ProductionQCDecision handles pass/fail submissions.
func (h *Handlers) ProductionQCDecision(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		http.Error(w, "注文IDが不正です。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	outcome := strings.TrimSpace(r.FormValue("outcome"))
	if outcome == "" {
		http.Error(w, "結果を選択してください。", http.StatusBadRequest)
		return
	}

	req := adminproduction.QCDecisionRequest{
		Outcome:     adminproduction.QCDecisionOutcome(outcome),
		Note:        strings.TrimSpace(r.FormValue("note")),
		ReasonCode:  strings.TrimSpace(r.FormValue("reason_code")),
		Attachments: parseAttachmentValues(r.Form["attachments"]),
	}

	result, err := h.production.RecordQCDecision(ctx, user.Token, orderID, req)
	if err != nil {
		switch {
		case errors.Is(err, adminproduction.ErrQCItemNotFound):
			http.NotFound(w, r)
		case errors.Is(err, adminproduction.ErrQCInvalidAction):
			http.Error(w, "このステータスでは実行できません。", http.StatusBadRequest)
		default:
			log.Printf("production: record qc decision failed: %v", err)
			http.Error(w, "QCの更新に失敗しました。", http.StatusBadGateway)
		}
		return
	}

	triggerToast(w, result.Message, "success")
	w.Header().Set("HX-Refresh", "true")
	w.WriteHeader(http.StatusNoContent)
}

// ProductionQCReworkModal renders the rework modal.
func (h *Handlers) ProductionQCReworkModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		http.Error(w, "注文IDが不正です。", http.StatusBadRequest)
		return
	}

	query := buildProductionQCQuery(r)
	query.Selected = orderID

	result, err := h.production.QCOverview(ctx, user.Token, query)
	if err != nil {
		log.Printf("production: fetch qc modal failed: %v", err)
		http.Error(w, "再作業データの取得に失敗しました。", http.StatusBadGateway)
		return
	}
	if result.Drawer.Empty || result.Drawer.Item.ID == "" || result.Drawer.Item.ID != orderID {
		http.NotFound(w, r)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	modal := productiontpl.BuildQCReworkModal(basePath, orderID, result.Drawer, query)
	templ.Handler(productiontpl.QCReworkModal(modal)).ServeHTTP(w, r)
}

// ProductionQCSubmitRework handles rework submissions from the modal.
func (h *Handlers) ProductionQCSubmitRework(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		http.Error(w, "注文IDが不正です。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	req := adminproduction.QCReworkRequest{
		RouteID:   strings.TrimSpace(r.FormValue("route_id")),
		IssueCode: strings.TrimSpace(r.FormValue("issue_code")),
		Note:      strings.TrimSpace(r.FormValue("note")),
	}
	if req.RouteID == "" {
		http.Error(w, "差し戻し先を選択してください。", http.StatusBadRequest)
		return
	}

	result, err := h.production.TriggerRework(ctx, user.Token, orderID, req)
	if err != nil {
		switch {
		case errors.Is(err, adminproduction.ErrQCItemNotFound):
			http.NotFound(w, r)
		case errors.Is(err, adminproduction.ErrQCInvalidAction):
			http.Error(w, "再作業を起票できません。", http.StatusBadRequest)
		default:
			log.Printf("production: trigger rework failed: %v", err)
			http.Error(w, "再作業の登録に失敗しました。", http.StatusBadGateway)
		}
		return
	}

	triggerToast(w, result.Message, "warning")
	w.Header().Set("HX-Refresh", "true")
	fmt.Fprint(w, `<div id="modal" class="modal hidden" hx-swap-oob="true" aria-hidden="true" data-modal-open="false" data-modal-state="closed"></div>`)
}

// OrdersProductionEvent handles drag-and-drop submissions from the kanban board.
func (h *Handlers) OrdersProductionEvent(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	orderID := strings.TrimSpace(chi.URLParam(r, "orderID"))
	if orderID == "" {
		http.Error(w, "注文IDが不正です。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	stageValue := strings.TrimSpace(r.FormValue("type"))
	if stageValue == "" {
		http.Error(w, "ステージが指定されていません。", http.StatusBadRequest)
		return
	}
	if !isValidStage(stageValue) {
		http.Error(w, "指定されたステージに移動できません。", http.StatusBadRequest)
		return
	}

	req := adminproduction.AppendEventRequest{
		Stage:    adminproduction.Stage(stageValue),
		Note:     strings.TrimSpace(r.FormValue("note")),
		Station:  strings.TrimSpace(r.FormValue("station")),
		ActorID:  user.UID,
		ActorRef: user.Email,
	}

	if _, err := h.production.AppendEvent(ctx, user.Token, orderID, req); err != nil {
		switch {
		case errors.Is(err, adminproduction.ErrCardNotFound):
			http.Error(w, "指定された注文が見つかりません。", http.StatusNotFound)
		case errors.Is(err, adminproduction.ErrStageInvalid):
			http.Error(w, "指定されたステージに移動できません。", http.StatusBadRequest)
		default:
			log.Printf("production: append event failed: %v", err)
			http.Error(w, "制作更新に失敗しました。", http.StatusBadGateway)
		}
		return
	}

	triggerToast(w, "制作ステージを更新しました。", "success")
	w.WriteHeader(http.StatusNoContent)
}

type productionSummaryRequest struct {
	query adminproduction.QueueWIPSummaryQuery
	state productiontpl.SummaryQueryState
}

func buildProductionSummaryRequest(r *http.Request) productionSummaryRequest {
	values := r.URL.Query()
	facility := strings.TrimSpace(values.Get("facility"))
	shift := strings.TrimSpace(values.Get("shift"))
	queueType := strings.TrimSpace(values.Get("queue_type"))
	window := strings.TrimSpace(values.Get("window"))

	raw := url.Values{}
	if facility != "" {
		raw.Set("facility", facility)
	}
	if shift != "" {
		raw.Set("shift", shift)
	}
	if queueType != "" {
		raw.Set("queue_type", queueType)
	}
	if window != "" {
		raw.Set("window", window)
	}

	state := productiontpl.SummaryQueryState{
		Facility:  facility,
		Shift:     shift,
		QueueType: queueType,
		DateRange: window,
		RawQuery:  raw.Encode(),
	}

	query := adminproduction.QueueWIPSummaryQuery{
		Facility:  facility,
		Shift:     shift,
		QueueType: queueType,
		DateRange: window,
	}

	return productionSummaryRequest{query: query, state: state}
}

type productionBoardRequest struct {
	query adminproduction.BoardQuery
	state productiontpl.QueryState
}

func buildProductionBoardRequest(r *http.Request) productionBoardRequest {
	values := r.URL.Query()
	queue := strings.TrimSpace(values.Get("queue"))
	priority := strings.TrimSpace(values.Get("priority"))
	productLine := strings.TrimSpace(values.Get("product_line"))
	workstation := strings.TrimSpace(values.Get("workstation"))
	selected := strings.TrimSpace(values.Get("selected"))

	state := productiontpl.QueryState{
		Queue:       queue,
		Priority:    priority,
		ProductLine: productLine,
		Workstation: workstation,
		Selected:    selected,
		RawQuery:    rebuildRawQuery(values),
	}

	query := adminproduction.BoardQuery{
		QueueID:     queue,
		Priority:    priority,
		ProductLine: productLine,
		Workstation: workstation,
		Selected:    selected,
	}

	return productionBoardRequest{query: query, state: state}
}

func canonicalProductionURL(basePath string, req productionBoardRequest) string {
	base := joinBasePath(basePath, "/production/queues")
	if req.state.RawQuery == "" {
		return base
	}
	return base + "?" + req.state.RawQuery
}

func rebuildRawQuery(values url.Values) string {
	return values.Encode()
}

func buildProductionQCQuery(r *http.Request) adminproduction.QCQuery {
	values := r.URL.Query()
	return adminproduction.QCQuery{
		QueueID:     strings.TrimSpace(values.Get("queue")),
		ProductLine: strings.TrimSpace(values.Get("product_line")),
		IssueType:   strings.TrimSpace(values.Get("issue_type")),
		Assignee:    strings.TrimSpace(values.Get("assignee")),
		Status:      strings.TrimSpace(values.Get("status")),
		Selected:    strings.TrimSpace(values.Get("selected")),
	}
}

func parseAttachmentValues(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	attachments := make([]string, 0, len(values))
	for _, raw := range values {
		for _, chunk := range strings.Split(raw, "\n") {
			trimmed := strings.TrimSpace(chunk)
			if trimmed == "" {
				continue
			}
			attachments = append(attachments, trimmed)
		}
	}
	return attachments
}

func isValidStage(stage string) bool {
	switch adminproduction.Stage(stage) {
	case adminproduction.StageQueued,
		adminproduction.StageEngraving,
		adminproduction.StagePolishing,
		adminproduction.StageQC,
		adminproduction.StagePacked:
		return true
	default:
		return false
	}
}
