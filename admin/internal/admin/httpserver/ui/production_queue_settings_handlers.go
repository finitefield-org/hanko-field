package ui

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	productiontpl "finitefield.org/hanko-admin/internal/admin/templates/productionqueues"
)

type queueSettingsContext struct {
	query adminproduction.QueueSettingsQuery
	state productiontpl.QueryState
}

func parseQueueSettings(raw string) queueSettingsContext {
	values, err := url.ParseQuery(raw)
	if err != nil {
		values = url.Values{}
	}

	workshopRaw := strings.TrimSpace(values.Get("workshop"))
	statusRaw := strings.TrimSpace(values.Get("status"))
	productRaw := strings.TrimSpace(values.Get("product_line"))
	searchRaw := strings.TrimSpace(values.Get("search"))
	selectedRaw := strings.TrimSpace(values.Get("selected"))

	state := productiontpl.QueryState{
		Workshop:    workshopRaw,
		Status:      statusRaw,
		ProductLine: productRaw,
		Search:      searchRaw,
		SelectedID:  selectedRaw,
	}

	ctx := queueSettingsContext{
		query: adminproduction.QueueSettingsQuery{
			Workshop:    decodeFacetValue(workshopRaw),
			Status:      decodeFacetValue(statusRaw),
			ProductLine: decodeFacetValue(productRaw),
			Search:      searchRaw,
			SelectedID:  selectedRaw,
		},
		state: state,
	}
	ctx.state.RawQuery = ctx.state.Encode()
	return ctx
}

func buildQueueSettingsRequest(r *http.Request) queueSettingsContext {
	return parseQueueSettings(r.URL.RawQuery)
}

func applySelection(ctx *queueSettingsContext, queueID string) {
	queueID = strings.TrimSpace(queueID)
	ctx.state.SelectedID = queueID
	ctx.query.SelectedID = queueID
	ctx.state.RawQuery = helpers.SetRawQuery(ctx.state.RawQuery, "selected", queueID)
}

func canonicalQueueURL(basePath string, rawQuery string) string {
	base := joinBase(basePath, "/production-queues")
	if strings.TrimSpace(rawQuery) == "" {
		return base
	}
	return fmt.Sprintf("%s?%s", base, rawQuery)
}

func (h *Handlers) ProductionQueueSettingsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildQueueSettingsRequest(r)
	basePath := custommw.BasePathFromContext(ctx)

	result, err := h.production.QueueSettings(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		errMsg = "制作キューの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminproduction.QueueSettingsResult{}
	}

	var detail *adminproduction.QueueDefinition
	if req.state.SelectedID != "" {
		if queue, err := h.production.QueueSettingsDetail(ctx, user.Token, req.state.SelectedID); err == nil {
			detail = &queue
		} else {
			if !errors.Is(err, adminproduction.ErrQueueNotFound) {
				errMsg = "キュー詳細の取得に失敗しました。"
			}
			req.state.SelectedID = ""
			req.query.SelectedID = ""
			req.state.RawQuery = helpers.SetRawQuery(req.state.RawQuery, "selected", "")
		}
	}

	page := productiontpl.BuildPageData(basePath, req.state, result, detail, errMsg)
	templ.Handler(productiontpl.Index(page)).ServeHTTP(w, r)
}

func (h *Handlers) ProductionQueueSettingsTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildQueueSettingsRequest(r)
	basePath := custommw.BasePathFromContext(ctx)

	result, err := h.production.QueueSettings(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		errMsg = "制作キューの取得に失敗しました。"
		result = adminproduction.QueueSettingsResult{}
	}

	var detail *adminproduction.QueueDefinition
	if req.state.SelectedID != "" {
		if queue, err := h.production.QueueSettingsDetail(ctx, user.Token, req.state.SelectedID); err == nil {
			detail = &queue
		} else {
			if !errors.Is(err, adminproduction.ErrQueueNotFound) {
				errMsg = "キュー詳細の取得に失敗しました。"
			}
			req.state.SelectedID = ""
			req.query.SelectedID = ""
			req.state.RawQuery = helpers.SetRawQuery(req.state.RawQuery, "selected", "")
		}
	}

	page := productiontpl.BuildPageData(basePath, req.state, result, detail, errMsg)
	canonical := canonicalQueueURL(basePath, page.Query.RawQuery)
	w.Header().Set("HX-Push-Url", canonical)

	templ.Handler(productiontpl.TableWithDrawer(page.Table, page.Drawer)).ServeHTTP(w, r)
}

func (h *Handlers) ProductionQueueSettingsDrawer(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		http.Error(w, "キューIDが不正です。", http.StatusBadRequest)
		return
	}

	queue, err := h.production.QueueSettingsDetail(ctx, user.Token, queueID)
	if err != nil {
		if errors.Is(err, adminproduction.ErrQueueNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "キュー詳細の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	req := parseQueueSettings(r.URL.RawQuery)
	applySelection(&req, queue.ID)
	drawer := productiontpl.BuildPageData(basePath, req.state, adminproduction.QueueSettingsResult{}, &queue, "").Drawer
	templ.Handler(productiontpl.Drawer(drawer)).ServeHTTP(w, r)
}

func (h *Handlers) ProductionQueueNewModal(w http.ResponseWriter, r *http.Request) {
	h.renderQueueUpsertModal(w, r, nil, "")
}

func (h *Handlers) ProductionQueueEditModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		http.Error(w, "キューIDが不正です。", http.StatusBadRequest)
		return
	}

	queue, err := h.production.QueueSettingsDetail(ctx, user.Token, queueID)
	if err != nil {
		if errors.Is(err, adminproduction.ErrQueueNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "キュー詳細の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	h.renderQueueUpsertModal(w, r, &queue, "")
}

func (h *Handlers) ProductionQueueDeleteModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		http.Error(w, "キューIDが不正です。", http.StatusBadRequest)
		return
	}

	queue, err := h.production.QueueSettingsDetail(ctx, user.Token, queueID)
	if err != nil {
		if errors.Is(err, adminproduction.ErrQueueNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "キュー詳細の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	req := parseQueueSettings(r.URL.RawQuery)
	modal := productiontpl.BuildDeleteModalData(basePath, queue, custommw.CSRFTokenFromContext(ctx), req.state.RawQuery, "")
	templ.Handler(productiontpl.DeleteModal(modal)).ServeHTTP(w, r)
}

func (h *Handlers) ProductionQueueCreate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	req := parseQueueSettings(r.FormValue("return_query"))

	input, userErr := queueInputFromForm(r)
	if userErr != nil {
		deps, err := h.queueFormDependencies(ctx, user.Token)
		if err != nil {
			http.Error(w, "フォームの組み立てに失敗しました。", http.StatusBadGateway)
			return
		}
		modal := productiontpl.BuildUpsertModalData(custommw.BasePathFromContext(ctx), custommw.CSRFTokenFromContext(ctx), nil, deps.options, deps.queues, req.state.RawQuery, userErr.Error())
		templ.Handler(productiontpl.UpsertModal(modal)).ServeHTTP(w, r)
		return
	}

	created, err := h.production.CreateQueueDefinition(ctx, user.Token, input)
	if err != nil {
		if errors.Is(err, adminproduction.ErrQueueInvalidInput) || errors.Is(err, adminproduction.ErrQueueNameExists) {
			deps, derr := h.queueFormDependencies(ctx, user.Token)
			if derr != nil {
				http.Error(w, "フォームの組み立てに失敗しました。", http.StatusBadGateway)
				return
			}
			modal := productiontpl.BuildUpsertModalData(custommw.BasePathFromContext(ctx), custommw.CSRFTokenFromContext(ctx), nil, deps.options, deps.queues, req.state.RawQuery, "キューを作成できませんでした。入力内容を確認してください。")
			templ.Handler(productiontpl.UpsertModal(modal)).ServeHTTP(w, r)
			return
		}
		http.Error(w, "キューの作成に失敗しました。", http.StatusBadGateway)
		return
	}

	applySelection(&req, created.ID)
	h.renderQueueTableSnapshot(ctx, w, r, user.Token, req, &created, "制作キューを追加しました。", "success", true)
}

func (h *Handlers) ProductionQueueUpdate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		http.Error(w, "キューIDが不正です。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	req := parseQueueSettings(r.FormValue("return_query"))

	input, userErr := queueInputFromForm(r)
	if userErr != nil {
		deps, err := h.queueFormDependencies(ctx, user.Token)
		if err != nil {
			http.Error(w, "フォームの組み立てに失敗しました。", http.StatusBadGateway)
			return
		}
		existing, _ := h.production.QueueSettingsDetail(ctx, user.Token, queueID)
		modal := productiontpl.BuildUpsertModalData(custommw.BasePathFromContext(ctx), custommw.CSRFTokenFromContext(ctx), &existing, deps.options, deps.queues, req.state.RawQuery, userErr.Error())
		templ.Handler(productiontpl.UpsertModal(modal)).ServeHTTP(w, r)
		return
	}

	updated, err := h.production.UpdateQueueDefinition(ctx, user.Token, queueID, input)
	if err != nil {
		if errors.Is(err, adminproduction.ErrQueueInvalidInput) || errors.Is(err, adminproduction.ErrQueueNameExists) {
			deps, derr := h.queueFormDependencies(ctx, user.Token)
			if derr != nil {
				http.Error(w, "フォームの組み立てに失敗しました。", http.StatusBadGateway)
				return
			}
			existing, _ := h.production.QueueSettingsDetail(ctx, user.Token, queueID)
			modal := productiontpl.BuildUpsertModalData(custommw.BasePathFromContext(ctx), custommw.CSRFTokenFromContext(ctx), &existing, deps.options, deps.queues, req.state.RawQuery, "キューの更新に失敗しました。入力内容を確認してください。")
			templ.Handler(productiontpl.UpsertModal(modal)).ServeHTTP(w, r)
			return
		}
		http.Error(w, "キューの更新に失敗しました。", http.StatusBadGateway)
		return
	}

	applySelection(&req, updated.ID)
	h.renderQueueTableSnapshot(ctx, w, r, user.Token, req, &updated, "制作キューを更新しました。", "success", true)
}

func (h *Handlers) ProductionQueueDelete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		http.Error(w, "キューIDが不正です。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	req := parseQueueSettings(r.FormValue("return_query"))

	if err := h.production.DeleteQueueDefinition(ctx, user.Token, queueID); err != nil {
		if errors.Is(err, adminproduction.ErrQueueInvalidInput) {
			queue, _ := h.production.QueueSettingsDetail(ctx, user.Token, queueID)
			modal := productiontpl.BuildDeleteModalData(custommw.BasePathFromContext(ctx), queue, custommw.CSRFTokenFromContext(ctx), req.state.RawQuery, "このキューは現在使用中のため削除できません。")
			templ.Handler(productiontpl.DeleteModal(modal)).ServeHTTP(w, r)
			return
		}
		if errors.Is(err, adminproduction.ErrQueueNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "キューの削除に失敗しました。", http.StatusBadGateway)
		return
	}

	if req.state.SelectedID == queueID {
		req.state.SelectedID = ""
		req.query.SelectedID = ""
		req.state.RawQuery = helpers.SetRawQuery(req.state.RawQuery, "selected", "")
	}

	h.renderQueueTableSnapshot(ctx, w, r, user.Token, req, nil, "制作キューを削除しました。", "success", true)
}

func (h *Handlers) ProductionQueueToggle(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	queueID := strings.TrimSpace(chi.URLParam(r, "queueID"))
	if queueID == "" {
		http.Error(w, "キューIDが不正です。", http.StatusBadRequest)
		return
	}

	req := buildQueueSettingsRequest(r)

	queue, err := h.production.QueueSettingsDetail(ctx, user.Token, queueID)
	if err != nil {
		if errors.Is(err, adminproduction.ErrQueueNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "キュー詳細の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	input := queueInputFromDefinition(queue)
	input.Active = !queue.Active

	updated, err := h.production.UpdateQueueDefinition(ctx, user.Token, queueID, input)
	if err != nil {
		http.Error(w, "ステータスの更新に失敗しました。", http.StatusBadGateway)
		return
	}

	applySelection(&req, updated.ID)
	h.renderQueueTableSnapshot(ctx, w, r, user.Token, req, &updated, "稼働ステータスを更新しました。", "info", false)
}

type queueFormDeps struct {
	options adminproduction.QueueSettingsOptions
	queues  []adminproduction.QueueDefinition
}

func (h *Handlers) queueFormDependencies(ctx context.Context, token string) (queueFormDeps, error) {
	options, err := h.production.QueueSettingsOptions(ctx, token)
	if err != nil {
		return queueFormDeps{}, err
	}
	result, err := h.production.QueueSettings(ctx, token, adminproduction.QueueSettingsQuery{})
	if err != nil {
		return queueFormDeps{}, err
	}
	return queueFormDeps{options: options, queues: result.Queues}, nil
}

func (h *Handlers) renderQueueUpsertModal(w http.ResponseWriter, r *http.Request, queue *adminproduction.QueueDefinition, errMsg string) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	deps, err := h.queueFormDependencies(ctx, user.Token)
	if err != nil {
		http.Error(w, "モーダルの読み込みに失敗しました。", http.StatusBadGateway)
		return
	}

	req := parseQueueSettings(r.URL.RawQuery)
	basePath := custommw.BasePathFromContext(ctx)
	modal := productiontpl.BuildUpsertModalData(basePath, custommw.CSRFTokenFromContext(ctx), queue, deps.options, deps.queues, req.state.RawQuery, errMsg)
	templ.Handler(productiontpl.UpsertModal(modal)).ServeHTTP(w, r)
}

func (h *Handlers) renderQueueTableSnapshot(ctx context.Context, w http.ResponseWriter, httpReq *http.Request, token string, req queueSettingsContext, detail *adminproduction.QueueDefinition, toastMessage, toastTone string, closeModal bool) {
	result, err := h.production.QueueSettings(ctx, token, req.query)
	errMsg := ""
	if err != nil {
		errMsg = "制作キューの取得に失敗しました。"
		result = adminproduction.QueueSettingsResult{}
	}

	if detail == nil && req.state.SelectedID != "" {
		if queue, err := h.production.QueueSettingsDetail(ctx, token, req.state.SelectedID); err == nil {
			detail = &queue
		} else {
			req.state.SelectedID = ""
			req.query.SelectedID = ""
			req.state.RawQuery = helpers.SetRawQuery(req.state.RawQuery, "selected", "")
		}
	}

	basePath := custommw.BasePathFromContext(ctx)
	page := productiontpl.BuildPageData(basePath, req.state, result, detail, errMsg)
	canonical := canonicalQueueURL(basePath, page.Query.RawQuery)
	w.Header().Set("HX-Push-Url", canonical)

	trigger := map[string]any{}
	if toastMessage != "" {
		tone := toastTone
		if tone == "" {
			tone = "success"
		}
		trigger["toast"] = map[string]string{"message": toastMessage, "tone": tone}
	}
	if closeModal {
		trigger["modal:close"] = true
	}
	if len(trigger) > 0 {
		if payload, err := json.Marshal(trigger); err == nil {
			w.Header().Set("HX-Trigger", string(payload))
		}
	}

	templ.Handler(productiontpl.TableWithDrawer(page.Table, page.Drawer)).ServeHTTP(w, httpReq)
}

func queueInputFromForm(r *http.Request) (adminproduction.QueueDefinitionInput, error) {
	input := adminproduction.QueueDefinitionInput{}
	input.Name = strings.TrimSpace(r.FormValue("name"))
	if input.Name == "" {
		return input, errors.New("キュー名を入力してください。")
	}
	input.Workshop = strings.TrimSpace(r.FormValue("workshop"))
	input.ProductLine = strings.TrimSpace(r.FormValue("product_line"))

	priority, err := strconv.Atoi(strings.TrimSpace(r.FormValue("priority")))
	if err != nil {
		return input, errors.New("優先度が不正です。")
	}
	input.Priority = priority

	capacity, err := strconv.Atoi(strings.TrimSpace(r.FormValue("capacity")))
	if err != nil || capacity <= 0 {
		return input, errors.New("容量は1以上の数値で入力してください。")
	}
	input.Capacity = capacity

	sla, err := strconv.Atoi(strings.TrimSpace(r.FormValue("target_sla_hours")))
	if err != nil || sla <= 0 {
		return input, errors.New("SLAは1以上の数値で入力してください。")
	}
	input.TargetSLAHours = sla

	input.Active = strings.EqualFold(strings.TrimSpace(r.FormValue("active")), "true")
	input.Description = strings.TrimSpace(r.FormValue("description"))
	input.Notes = splitLines(r.FormValue("notes"))

	for _, id := range r.Form["work_center_id"] {
		id = strings.TrimSpace(id)
		if id != "" {
			input.WorkCenterIDs = append(input.WorkCenterIDs, id)
		}
	}
	input.PrimaryWorkCenterID = strings.TrimSpace(r.FormValue("primary_work_center"))

	keys := r.Form["role_key"]
	counts := r.Form["role_headcount"]
	for i := 0; i < len(keys) && i < len(counts); i++ {
		key := strings.TrimSpace(keys[i])
		if key == "" {
			continue
		}
		headcount, err := strconv.Atoi(strings.TrimSpace(counts[i]))
		if err != nil || headcount < 0 {
			return input, fmt.Errorf("ロール %s の人数が不正です。", key)
		}
		if headcount == 0 {
			continue
		}
		input.Roles = append(input.Roles, adminproduction.QueueRoleAssignmentInput{
			Key:       key,
			Headcount: headcount,
		})
	}

	stageCodes := r.Form["stage_code"]
	stageLabels := r.Form["stage_label"]
	stageDescriptions := r.Form["stage_description"]
	stageWIP := r.Form["stage_wip_limit"]
	stageSLA := r.Form["stage_target_sla"]
	for i := 0; i < len(stageCodes) && i < len(stageLabels) && i < len(stageWIP) && i < len(stageSLA); i++ {
		code := adminproduction.Stage(strings.TrimSpace(stageCodes[i]))
		label := strings.TrimSpace(stageLabels[i])
		if label == "" {
			return input, errors.New("ステージ名を入力してください。")
		}
		wip, err := strconv.Atoi(strings.TrimSpace(stageWIP[i]))
		if err != nil || wip <= 0 {
			return input, fmt.Errorf("ステージ %s のWIP上限が不正です。", label)
		}
		target, err := strconv.Atoi(strings.TrimSpace(stageSLA[i]))
		if err != nil || target <= 0 {
			return input, fmt.Errorf("ステージ %s のSLAが不正です。", label)
		}
		input.Stages = append(input.Stages, adminproduction.QueueStageInput{
			Code:           code,
			Label:          label,
			Description:    strings.TrimSpace(stageDescriptions[i]),
			WIPLimit:       wip,
			TargetSLAHours: target,
		})
	}

	return input, nil
}

func queueInputFromDefinition(def adminproduction.QueueDefinition) adminproduction.QueueDefinitionInput {
	input := adminproduction.QueueDefinitionInput{
		Name:           def.Name,
		Description:    def.Description,
		Workshop:       def.Workshop,
		ProductLine:    def.ProductLine,
		Priority:       def.Priority,
		Capacity:       def.Capacity,
		TargetSLAHours: def.TargetSLAHours,
		Active:         def.Active,
		Notes:          copyStrings(def.Notes),
	}
	for _, center := range def.WorkCenters {
		input.WorkCenterIDs = append(input.WorkCenterIDs, center.WorkCenter.ID)
		if center.Primary {
			input.PrimaryWorkCenterID = center.WorkCenter.ID
		}
	}
	for _, role := range def.Roles {
		input.Roles = append(input.Roles, adminproduction.QueueRoleAssignmentInput{
			Key:       role.Key,
			Headcount: role.Headcount,
		})
	}
	for _, stage := range def.Stages {
		input.Stages = append(input.Stages, adminproduction.QueueStageInput{
			Code:           stage.Code,
			Label:          stage.Label,
			Description:    stage.Description,
			WIPLimit:       stage.WIPLimit,
			TargetSLAHours: stage.TargetSLAHours,
		})
	}
	return input
}

func splitLines(value string) []string {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	lines := strings.Split(value, "\n")
	out := make([]string, 0, len(lines))
	for _, line := range lines {
		if trimmed := strings.TrimSpace(line); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func copyStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func joinBase(base, suffix string) string {
	b := strings.TrimRight(base, "/")
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	return b + suffix
}

func decodeFacetValue(value string) string {
	trimmed := strings.TrimSpace(value)
	if strings.EqualFold(trimmed, productiontpl.UnsetFilterValue) {
		return ""
	}
	return trimmed
}
