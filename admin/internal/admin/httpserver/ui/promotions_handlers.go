package ui

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminpromotions "finitefield.org/hanko-admin/internal/admin/promotions"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	promotionstpl "finitefield.org/hanko-admin/internal/admin/templates/promotions"
)

const (
	defaultPromotionsPageSize = 20
	promotionsDateLayout      = "2006-01-02"
)

type promotionsRequest struct {
	state promotionstpl.QueryState
	query adminpromotions.ListQuery
}

// PromotionsPage renders the promotions index page.
func (h *Handlers) PromotionsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildPromotionsRequest(r)

	result, err := h.promotions.List(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("promotions: list failed: %v", err)
		errMsg = "プロモーションの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminpromotions.ListResult{}
	}

	selectedID := req.state.SelectedID
	if selectedID == "" && len(result.Promotions) > 0 {
		selectedID = result.Promotions[0].ID
	}
	req.state.SelectedID = selectedID

	basePath := custommw.BasePathFromContext(ctx)
	table := promotionstpl.TablePayload(basePath, req.state, result, errMsg)

	drawer := promotionstpl.EmptyDrawer()
	if selectedID != "" {
		if detail, derr := h.promotions.Detail(ctx, user.Token, selectedID); derr == nil {
			drawer = promotionstpl.DrawerPayload(detail)
		} else if !errors.Is(derr, adminpromotions.ErrPromotionNotFound) {
			log.Printf("promotions: detail failed: %v", derr)
		}
	}
	if drawer.ID != "" {
		drawer.EditURL = joinBasePath(basePath, fmt.Sprintf("/promotions/modal/edit?promotionID=%s", url.QueryEscape(drawer.ID)))
		drawer.ValidateURL = joinBasePath(basePath, fmt.Sprintf("/promotions/modal/validate?promotionID=%s", url.QueryEscape(drawer.ID)))
	}

	toolbar := promotionsToolbarProps(basePath, 0, result.Pagination.TotalItems)

	data := promotionstpl.BuildPageData(basePath, req.state, result, table, toolbar, drawer)

	templ.Handler(promotionstpl.Index(data)).ServeHTTP(w, r)
}

// PromotionsTable renders the promotions table fragment.
func (h *Handlers) PromotionsTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildPromotionsRequest(r)

	result, err := h.promotions.List(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("promotions: list failed: %v", err)
		errMsg = "プロモーションの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminpromotions.ListResult{}
	}

	selectedID := req.state.SelectedID
	if selectedID == "" && len(result.Promotions) > 0 {
		selectedID = result.Promotions[0].ID
	}
	req.state.SelectedID = selectedID

	basePath := custommw.BasePathFromContext(ctx)
	table := promotionstpl.TablePayload(basePath, req.state, result, errMsg)

	if canonical := canonicalPromotionsURL(basePath, req.state); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(promotionstpl.Table(table)).ServeHTTP(w, r)
}

// PromotionsDrawer renders the detail drawer fragment for a specific promotion.
func (h *Handlers) PromotionsDrawer(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	promotionID := strings.TrimSpace(r.URL.Query().Get("promotionID"))
	if promotionID == "" {
		http.Error(w, "promotionID is required", http.StatusBadRequest)
		return
	}

	detail, err := h.promotions.Detail(ctx, user.Token, promotionID)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrPromotionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: detail failed: %v", err)
		http.Error(w, "プロモーション詳細の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	payload := promotionstpl.DrawerPayload(detail)
	basePath := custommw.BasePathFromContext(ctx)
	payload.EditURL = joinBasePath(basePath, fmt.Sprintf("/promotions/modal/edit?promotionID=%s", url.QueryEscape(detail.Promotion.ID)))
	payload.ValidateURL = joinBasePath(basePath, fmt.Sprintf("/promotions/modal/validate?promotionID=%s", url.QueryEscape(detail.Promotion.ID)))
	templ.Handler(promotionstpl.Drawer(payload)).ServeHTTP(w, r)
}

// PromotionsBulkStatus handles bulk status actions.
func (h *Handlers) PromotionsBulkStatus(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	action := parseBulkAction(r.FormValue("action"))
	if action == "" {
		http.Error(w, "不正なアクションです。", http.StatusBadRequest)
		return
	}

	ids := r.PostForm["promotionID"]
	if len(ids) == 0 {
		http.Error(w, "対象が選択されていません。", http.StatusBadRequest)
		return
	}

	req := adminpromotions.BulkStatusRequest{
		Action:       action,
		PromotionIDs: append([]string(nil), ids...),
		Reason:       strings.TrimSpace(r.FormValue("reason")),
	}

	if _, err := h.promotions.BulkStatus(ctx, user.Token, req); err != nil {
		log.Printf("promotions: bulk action failed: %v", err)
		http.Error(w, "一括操作に失敗しました。", http.StatusBadGateway)
		return
	}

	message := fmt.Sprintf("プロモーションを%sしました。", bulkActionMessage(action))
	trigger := map[string]any{
		"toast": map[string]string{
			"message": message,
			"tone":    "success",
		},
	}
	if data, err := json.Marshal(trigger); err == nil {
		w.Header().Set("HX-Trigger", string(data))
	}
	w.WriteHeader(http.StatusNoContent)
}

// PromotionsNewModal renders the create modal for promotions.
func (h *Handlers) PromotionsNewModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	_, ok := custommw.UserFromContext(ctx)
	if !ok {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	state := defaultPromotionFormState()
	csrf := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)
	action := joinBasePath(basePath, "/promotions")
	data := buildPromotionModal(promotionModalModeNew, state, nil, "", action, http.MethodPost, csrf)

	templ.Handler(promotionstpl.Modal(data)).ServeHTTP(w, r)
}

// PromotionsEditModal renders the edit modal for a promotion.
func (h *Handlers) PromotionsEditModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	promotionID := strings.TrimSpace(r.URL.Query().Get("promotionID"))
	if promotionID == "" {
		http.Error(w, "promotionID is required", http.StatusBadRequest)
		return
	}

	detail, err := h.promotions.Detail(ctx, user.Token, promotionID)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrPromotionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: detail fetch for edit failed: %v", err)
		http.Error(w, "プロモーションの取得に失敗しました。", http.StatusBadGateway)
		return
	}

	state := promotionValuesFromDetail(detail)
	csrf := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)
	action := joinBasePath(basePath, fmt.Sprintf("/promotions/%s", url.PathEscape(promotionID)))
	data := buildPromotionModal(promotionModalModeEdit, state, nil, "", action, http.MethodPut, csrf)

	templ.Handler(promotionstpl.Modal(data)).ServeHTTP(w, r)
}

// PromotionsValidateModal renders the dry-run validation modal for a promotion.
func (h *Handlers) PromotionsValidateModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	promotionID := strings.TrimSpace(r.URL.Query().Get("promotionID"))
	if promotionID == "" {
		http.Error(w, "promotionID is required", http.StatusBadRequest)
		return
	}

	detail, err := h.promotions.Detail(ctx, user.Token, promotionID)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrPromotionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: validation detail fetch failed: %v", err)
		http.Error(w, "プロモーションの取得に失敗しました。", http.StatusBadGateway)
		return
	}

	state := defaultPromotionValidationState(detail)
	csrf := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)
	data := buildPromotionValidationModal(basePath, detail, csrf, state, nil, "", nil)

	templ.Handler(promotionstpl.ValidationModal(data)).ServeHTTP(w, r)
}

// PromotionsValidateSubmit handles dry-run validation submissions.
func (h *Handlers) PromotionsValidateSubmit(w http.ResponseWriter, r *http.Request) {
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

	promotionID := strings.TrimSpace(r.PostForm.Get("promotionID"))
	if promotionID == "" {
		http.Error(w, "promotionID is required", http.StatusBadRequest)
		return
	}

	detail, err := h.promotions.Detail(ctx, user.Token, promotionID)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrPromotionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: validation detail fetch failed: %v", err)
		http.Error(w, "プロモーションの取得に失敗しました。", http.StatusBadGateway)
		return
	}

	req, state, fieldErrors, generalErr := parsePromotionValidationForm(r.PostForm)
	csrf := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)

	if len(fieldErrors) > 0 || strings.TrimSpace(generalErr) != "" {
		data := buildPromotionValidationModal(basePath, detail, csrf, state, fieldErrors, generalErr, nil)
		templ.Handler(promotionstpl.ValidationModal(data)).ServeHTTP(w, r)
		return
	}

	result, err := h.promotions.Validate(ctx, user.Token, req)
	if err != nil {
		log.Printf("promotions: dry-run validate failed: %v", err)
		message := "検証に失敗しました。時間を置いて再度お試しください。"
		data := buildPromotionValidationModal(basePath, detail, csrf, state, nil, message, nil)
		templ.Handler(promotionstpl.ValidationModal(data)).ServeHTTP(w, r)
		return
	}

	// Use normalised currency from the request/result for subsequent renders.
	state.Currency = req.Currency
	data := buildPromotionValidationModal(basePath, detail, csrf, state, nil, "", &result)

	templ.Handler(promotionstpl.ValidationModal(data)).ServeHTTP(w, r)
}

// PromotionsCreate handles creation submissions.
func (h *Handlers) PromotionsCreate(w http.ResponseWriter, r *http.Request) {
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

	input, state, fieldErrors := parsePromotionForm(r.PostForm, false)
	if len(fieldErrors) > 0 {
		reRenderPromotionModal(w, r, promotionModalModeNew, state, fieldErrors, "入力内容を確認してください。", http.MethodPost, "")
		return
	}

	created, err := h.promotions.Create(ctx, user.Token, input)
	if err != nil {
		handlePromotionMutationError(w, r, promotionModalModeNew, "", input, state, err)
		return
	}

	triggerPromotionsRefresh(w, fmt.Sprintf("プロモーション「%s」を作成しました。", strings.TrimSpace(input.Name)), "success", created.ID)
}

// PromotionsUpdate handles update submissions.
func (h *Handlers) PromotionsUpdate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	promotionID := strings.TrimSpace(chi.URLParam(r, "promotionID"))
	if promotionID == "" {
		http.Error(w, "promotionID is required", http.StatusBadRequest)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	input, state, fieldErrors := parsePromotionForm(r.PostForm, true)
	if len(fieldErrors) > 0 {
		reRenderPromotionModal(w, r, promotionModalModeEdit, state, fieldErrors, "入力内容を確認してください。", http.MethodPut, promotionID)
		return
	}

	updated, err := h.promotions.Update(ctx, user.Token, promotionID, input)
	if err != nil {
		handlePromotionMutationError(w, r, promotionModalModeEdit, promotionID, input, state, err)
		return
	}

	triggerPromotionsRefresh(w, fmt.Sprintf("プロモーション「%s」を更新しました。", strings.TrimSpace(input.Name)), "success", updated.ID)
}

func reRenderPromotionModal(w http.ResponseWriter, r *http.Request, mode promotionModalMode, state promotionFormState, fieldErrors map[string]string, generalErr string, method string, promotionID string) {
	ctx := r.Context()
	csrf := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)
	action := joinBasePath(basePath, "/promotions")
	if mode == promotionModalModeEdit && strings.TrimSpace(promotionID) != "" {
		action = joinBasePath(basePath, fmt.Sprintf("/promotions/%s", url.PathEscape(strings.TrimSpace(promotionID))))
	}
	data := buildPromotionModal(mode, state, fieldErrors, generalErr, action, method, csrf)
	templ.Handler(promotionstpl.Modal(data)).ServeHTTP(w, r)
}

func handlePromotionMutationError(w http.ResponseWriter, r *http.Request, mode promotionModalMode, promotionID string, input adminpromotions.PromotionInput, state promotionFormState, err error) {
	var valErr *adminpromotions.PromotionValidationError
	if errors.As(err, &valErr) && valErr != nil {
		msg := strings.TrimSpace(valErr.Message)
		if msg == "" {
			msg = "入力内容を確認してください。"
		}
		reRenderPromotionModal(w, r, mode, state, valErr.FieldErrors, msg, methodForMode(mode), promotionID)
		return
	}
	log.Printf("promotions: %s mutation failed: %v", mode, err)
	message := "保存に失敗しました。時間を置いて再度お試しください。"
	if mode == promotionModalModeEdit {
		message = "更新に失敗しました。時間を置いて再度お試しください。"
	}
	reRenderPromotionModal(w, r, mode, state, nil, message, methodForMode(mode), promotionID)
}

func triggerPromotionsRefresh(w http.ResponseWriter, message, tone, promotionID string) {
	payload := map[string]any{
		"toast": map[string]string{
			"message": strings.TrimSpace(message),
			"tone":    strings.TrimSpace(tone),
		},
		"modal:close": true,
	}
	if id := strings.TrimSpace(promotionID); id != "" {
		payload["promotions:select"] = map[string]string{"id": id}
	}
	if data, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(data))
	} else {
		log.Printf("promotions: failed to marshal HX-Trigger payload: %v", err)
	}
	w.WriteHeader(http.StatusNoContent)
}

func methodForMode(mode promotionModalMode) string {
	if mode == promotionModalModeEdit {
		return http.MethodPut
	}
	return http.MethodPost
}

func buildPromotionsRequest(r *http.Request) promotionsRequest {
	raw := r.URL.Query()
	state := promotionstpl.BuildQueryState(raw)

	page := state.Page
	if page <= 0 {
		page = 1
	}
	pageSize := state.PageSize
	if pageSize <= 0 {
		pageSize = defaultPromotionsPageSize
	}

	query := adminpromotions.ListQuery{
		Search:   state.Search,
		Page:     page,
		PageSize: pageSize,
	}

	for _, status := range state.Statuses {
		status = strings.TrimSpace(status)
		if status == "" {
			continue
		}
		query.Statuses = append(query.Statuses, adminpromotions.Status(status))
	}

	for _, typ := range state.Types {
		typ = strings.TrimSpace(typ)
		if typ == "" {
			continue
		}
		query.Types = append(query.Types, adminpromotions.Type(typ))
	}

	for _, ch := range state.Channels {
		ch = strings.TrimSpace(ch)
		if ch == "" {
			continue
		}
		query.Channels = append(query.Channels, adminpromotions.Channel(ch))
	}

	for _, owner := range state.Owners {
		owner = strings.TrimSpace(owner)
		if owner == "" {
			continue
		}
		query.CreatedBy = append(query.CreatedBy, owner)
	}

	if ts := parsePromotionsDate(state.ScheduleStart); ts != nil {
		query.ScheduleStart = ts
	}
	if ts := parsePromotionsDate(state.ScheduleEnd); ts != nil {
		query.ScheduleEnd = ts
	}

	return promotionsRequest{
		state: state,
		query: query,
	}
}

func canonicalPromotionsURL(basePath string, state promotionstpl.QueryState) string {
	values, err := url.ParseQuery(state.RawQuery)
	if err != nil {
		values = url.Values{}
	}
	if state.Search == "" {
		values.Del("q")
	} else {
		values.Set("q", state.Search)
	}

	values.Del("status")
	for _, st := range state.Statuses {
		if strings.TrimSpace(st) == "" {
			continue
		}
		values.Add("status", st)
	}

	values.Del("type")
	for _, typ := range state.Types {
		if strings.TrimSpace(typ) == "" {
			continue
		}
		values.Add("type", typ)
	}

	values.Del("channel")
	for _, ch := range state.Channels {
		if strings.TrimSpace(ch) == "" {
			continue
		}
		values.Add("channel", ch)
	}

	values.Del("createdBy")
	for _, owner := range state.Owners {
		if strings.TrimSpace(owner) == "" {
			continue
		}
		values.Add("createdBy", owner)
	}

	if state.ScheduleStart == "" {
		values.Del("scheduleStart")
	} else {
		values.Set("scheduleStart", state.ScheduleStart)
	}
	if state.ScheduleEnd == "" {
		values.Del("scheduleEnd")
	} else {
		values.Set("scheduleEnd", state.ScheduleEnd)
	}

	if state.Page <= 1 {
		values.Del("page")
	} else {
		values.Set("page", strconv.Itoa(state.Page))
	}
	if state.PageSize <= 0 || state.PageSize == defaultPromotionsPageSize {
		values.Del("pageSize")
	} else {
		values.Set("pageSize", strconv.Itoa(state.PageSize))
	}
	values.Del("selected")

	raw := values.Encode()
	if raw != "" {
		return joinBasePath(basePath, "/promotions") + "?" + raw
	}
	return joinBasePath(basePath, "/promotions")
}

func parsePromotionsDate(value string) *time.Time {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	ts, err := time.Parse(promotionsDateLayout, value)
	if err != nil {
		return nil
	}
	return &ts
}

func promotionsToolbarProps(basePath string, selectedCount, total int) components.BulkToolbarProps {
	props := components.BulkToolbarProps{
		SelectedCount:   selectedCount,
		TotalCount:      total,
		Message:         "",
		RenderWhenEmpty: true,
		Actions: []components.BulkToolbarAction{
			buttonAction("アクティブ化", "選択したプロモーションをアクティブにします", "activate", "primary"),
			buttonAction("一時停止", "選択したプロモーションを一時停止します", "pause", "secondary"),
			buttonAction("複製", "選択したプロモーションを複製します", "clone", "secondary"),
			buttonAction("削除", "選択したプロモーションを削除します", "delete", "danger"),
		},
	}
	props.Attrs = templ.Attributes{
		"data-promotions-bulk-toolbar": "true",
		"data-initial-count":           strconv.Itoa(selectedCount),
		"data-bulk-endpoint":           joinBasePath(basePath, "/promotions/bulk/status"),
		"style":                        "display:none;",
	}
	props.ClearAction = &components.BulkToolbarAction{
		Label: "選択をクリア",
		Options: components.ButtonOptions{
			Variant: "ghost",
			Size:    "sm",
			Type:    "button",
			Attrs: templ.Attributes{
				"data-promotions-clear-selection": "true",
			},
		},
	}
	return props
}

func buttonAction(label, description, action, variant string) components.BulkToolbarAction {
	return components.BulkToolbarAction{
		Label:       label,
		Description: description,
		Options: components.ButtonOptions{
			Variant: variant,
			Size:    "sm",
			Type:    "button",
			Attrs: templ.Attributes{
				"data-promotions-bulk-action": action,
			},
		},
	}
}

func parseBulkAction(value string) adminpromotions.BulkAction {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case string(adminpromotions.BulkActionActivate):
		return adminpromotions.BulkActionActivate
	case string(adminpromotions.BulkActionPause):
		return adminpromotions.BulkActionPause
	case string(adminpromotions.BulkActionClone):
		return adminpromotions.BulkActionClone
	case string(adminpromotions.BulkActionDelete):
		return adminpromotions.BulkActionDelete
	default:
		return ""
	}
}

func bulkActionMessage(action adminpromotions.BulkAction) string {
	switch action {
	case adminpromotions.BulkActionActivate:
		return "アクティブ化"
	case adminpromotions.BulkActionPause:
		return "一時停止"
	case adminpromotions.BulkActionClone:
		return "複製"
	case adminpromotions.BulkActionDelete:
		return "削除"
	default:
		return "更新"
	}
}
