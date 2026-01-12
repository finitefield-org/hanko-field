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

	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminpromotions "finitefield.org/hanko-admin/internal/admin/promotions"
	promotionusage "finitefield.org/hanko-admin/internal/admin/templates/promotionusage"
	"finitefield.org/hanko-admin/internal/admin/webtmpl"
)

const (
	defaultPromotionUsagePageSize = 25
)

type promotionUsageRequest struct {
	state promotionusage.QueryState
	query adminpromotions.UsageQuery
}

func toPromotionUsageTableView(table promotionusage.TableData) webtmpl.PromotionUsageTableView {
	attrs := map[string]string{}
	for key, val := range table.Pagination.Attrs {
		attrs[key] = fmt.Sprint(val)
	}
	props := webtmpl.PaginationProps{
		Info: webtmpl.PageInfo{
			PageSize:   table.Pagination.Info.PageSize,
			Current:    table.Pagination.Info.Current,
			Count:      table.Pagination.Info.Count,
			TotalItems: table.Pagination.Info.TotalItems,
			Next:       table.Pagination.Info.Next,
			Prev:       table.Pagination.Info.Prev,
		},
		BasePath:      table.Pagination.BasePath,
		RawQuery:      table.Pagination.RawQuery,
		FragmentPath:  table.Pagination.FragmentPath,
		FragmentQuery: table.Pagination.FragmentQuery,
		Param:         table.Pagination.Param,
		SizeParam:     table.Pagination.SizeParam,
		HxTarget:      table.Pagination.HxTarget,
		HxSwap:        table.Pagination.HxSwap,
		HxPushURL:     table.Pagination.HxPushURL,
		Label:         table.Pagination.Label,
		Attrs:         attrs,
	}
	return webtmpl.PromotionUsageTableView{
		Table:      table,
		Pagination: webtmpl.PaginationView{Props: props},
	}
}

// PromotionsUsagePage renders the promotion usage analytics page.
func (h *Handlers) PromotionsUsagePage(w http.ResponseWriter, r *http.Request) {
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

	req := buildPromotionUsageRequest(r)

	result, err := h.promotions.Usage(ctx, user.Token, promotionID, req.query)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrPromotionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: usage list failed: %v", err)
		result = adminpromotions.UsageResult{}
		if detail, derr := h.promotions.Detail(ctx, user.Token, promotionID); derr == nil {
			result.Promotion = detail.Promotion
		} else {
			result.Promotion = adminpromotions.Promotion{ID: promotionID}
		}
	}

	basePath := custommw.BasePathFromContext(ctx)
	table := promotionusage.TablePayload(basePath, promotionID, req.state, result, errMessage(err))
	page := promotionusage.BuildPageData(basePath, promotionID, req.state, result, table, nil)

	crumbs := make([]webtmpl.Breadcrumb, 0, len(page.Breadcrumbs))
	for _, crumb := range page.Breadcrumbs {
		crumbs = append(crumbs, webtmpl.Breadcrumb{Label: crumb.Label, Href: crumb.Href})
	}
	base := webtmpl.BuildBaseView(ctx, page.Title, crumbs)
	base.ContentTemplate = "promotionusage/content"
	view := webtmpl.PromotionUsagePageView{
		BaseView: base,
		Page:     page,
		Table:    toPromotionUsageTableView(table),
	}
	if err := dashboardTemplates.Render(w, "promotionusage/index", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// PromotionsUsageTable renders the usage table fragment.
func (h *Handlers) PromotionsUsageTable(w http.ResponseWriter, r *http.Request) {
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

	req := buildPromotionUsageRequest(r)

	result, err := h.promotions.Usage(ctx, user.Token, promotionID, req.query)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrPromotionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: usage list failed: %v", err)
		result = adminpromotions.UsageResult{
			Promotion: adminpromotions.Promotion{ID: promotionID},
		}
	}

	basePath := custommw.BasePathFromContext(ctx)
	table := promotionusage.TablePayload(basePath, promotionID, req.state, result, errMessage(err))

	if canonical := canonicalPromotionUsageURL(basePath, promotionID, req.state); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	view := toPromotionUsageTableView(table)
	if err := dashboardTemplates.Render(w, "promotionusage/table", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// PromotionsUsageExport handles CSV export submissions for promotion usage.
func (h *Handlers) PromotionsUsageExport(w http.ResponseWriter, r *http.Request) {
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
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	detail, err := h.promotions.Detail(ctx, user.Token, promotionID)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrPromotionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: usage export detail lookup failed: %v", err)
		http.Error(w, "プロモーション情報の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	formReq := buildPromotionUsageRequestFromValues(r.PostForm)
	exportReq := adminpromotions.UsageExportRequest{
		PromotionID:   promotionID,
		PromotionCode: detail.Promotion.Code,
		PromotionName: detail.Promotion.Name,
		Query:         formReq.query,
		ActorID:       user.UID,
		ActorEmail:    user.Email,
	}

	job, err := h.promotions.StartUsageExport(ctx, user.Token, exportReq)
	if err != nil {
		switch {
		case errors.Is(err, adminpromotions.ErrPromotionNotFound):
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
		case errors.Is(err, adminpromotions.ErrUsageExportNoRecords):
			triggerToast(w, "エクスポート対象の利用履歴が見つかりませんでした。", "warning")
			http.Error(w, "エクスポート対象がありません。", http.StatusBadRequest)
		case errors.Is(err, adminpromotions.ErrUsageExportFormatNotAllowed):
			triggerToast(w, "このエクスポート形式には対応していません。", "danger")
			http.Error(w, "対応していないエクスポート形式です。", http.StatusBadRequest)
		default:
			log.Printf("promotions: usage export start failed: %v", err)
			triggerToast(w, "エクスポートの開始に失敗しました。時間を置いて再度お試しください。", "danger")
			http.Error(w, "エクスポートの開始に失敗しました。", http.StatusBadGateway)
		}
		return
	}

	triggerPayload := map[string]any{
		"toast": map[string]string{
			"message": fmt.Sprintf("CSVエクスポートを開始しました。(ジョブID: %s)", job.ID),
			"tone":    "info",
		},
	}
	if data, err := json.Marshal(triggerPayload); err == nil {
		w.Header().Set("HX-Trigger", string(data))
	}

	basePath := custommw.BasePathFromContext(ctx)
	payload := promotionusage.BuildExportJobPayload(basePath, promotionID, job)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := dashboardTemplates.Render(w, "promotionusage/export-status", payload); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// PromotionsUsageExportJobStatus renders the progress fragment for a usage export job.
func (h *Handlers) PromotionsUsageExportJobStatus(w http.ResponseWriter, r *http.Request) {
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

	jobID := strings.TrimSpace(chi.URLParam(r, "jobID"))
	if jobID == "" {
		http.Error(w, "jobID is required", http.StatusBadRequest)
		return
	}

	status, err := h.promotions.UsageExportStatus(ctx, user.Token, jobID)
	if err != nil {
		if errors.Is(err, adminpromotions.ErrUsageExportJobNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("promotions: usage export status failed: %v", err)
		http.Error(w, "エクスポートの進捗取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	payload := promotionusage.BuildExportJobPayload(basePath, promotionID, status.Job)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := dashboardTemplates.Render(w, "promotionusage/export-status", payload); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

func buildPromotionUsageRequest(r *http.Request) promotionUsageRequest {
	raw := r.URL.Query()
	state := promotionusage.BuildQueryState(raw)

	page := state.Page
	if page <= 0 {
		page = 1
	}
	pageSize := state.PageSize
	if pageSize <= 0 {
		pageSize = defaultPromotionUsagePageSize
	}

	query := adminpromotions.UsageQuery{
		MinUses:       state.MinUses,
		Timeframe:     state.Timeframe,
		Page:          page,
		PageSize:      pageSize,
		SortKey:       state.SortKey,
		SortDirection: state.SortDirection,
		AutoRefresh:   state.AutoRefresh,
	}

	for _, ch := range state.Channels {
		if channel := normalizePromotionChannel(ch); channel != "" {
			query.Channels = append(query.Channels, adminpromotions.Channel(channel))
		}
	}

	for _, src := range state.Sources {
		src = strings.TrimSpace(src)
		if src != "" {
			query.Sources = append(query.Sources, src)
		}
	}

	for _, segment := range state.Segments {
		segment = strings.TrimSpace(segment)
		if segment != "" {
			query.SegmentKeys = append(query.SegmentKeys, segment)
		}
	}

	if state.Start != nil {
		query.Start = state.Start
	}
	if state.End != nil {
		query.End = state.End
	}

	return promotionUsageRequest{
		state: state,
		query: query,
	}
}

func buildPromotionUsageRequestFromValues(values url.Values) promotionUsageRequest {
	state := promotionusage.BuildQueryState(values)

	page := state.Page
	if page <= 0 {
		page = 1
	}
	pageSize := state.PageSize
	if pageSize <= 0 {
		pageSize = defaultPromotionUsagePageSize
	}

	query := adminpromotions.UsageQuery{
		MinUses:       state.MinUses,
		Timeframe:     state.Timeframe,
		Page:          page,
		PageSize:      pageSize,
		SortKey:       state.SortKey,
		SortDirection: state.SortDirection,
		AutoRefresh:   state.AutoRefresh,
	}

	for _, ch := range state.Channels {
		if channel := normalizePromotionChannel(ch); channel != "" {
			query.Channels = append(query.Channels, adminpromotions.Channel(channel))
		}
	}
	for _, src := range state.Sources {
		src = strings.TrimSpace(src)
		if src != "" {
			query.Sources = append(query.Sources, src)
		}
	}
	for _, seg := range state.Segments {
		seg = strings.TrimSpace(seg)
		if seg != "" {
			query.SegmentKeys = append(query.SegmentKeys, seg)
		}
	}
	if state.Start != nil {
		query.Start = state.Start
	}
	if state.End != nil {
		query.End = state.End
	}

	return promotionUsageRequest{
		state: state,
		query: query,
	}
}

func canonicalPromotionUsageURL(basePath, promotionID string, state promotionusage.QueryState) string {
	values, err := url.ParseQuery(state.RawQuery)
	if err != nil {
		values = url.Values{}
	}

	if state.MinUses > 0 {
		values.Set("minUses", strconv.Itoa(state.MinUses))
	} else {
		values.Del("minUses")
	}

	if state.Timeframe != "" {
		values.Set("timeframe", state.Timeframe)
	} else {
		values.Del("timeframe")
	}

	values.Del("channel")
	for _, ch := range state.Channels {
		if strings.TrimSpace(ch) != "" {
			values.Add("channel", ch)
		}
	}

	values.Del("source")
	for _, src := range state.Sources {
		if strings.TrimSpace(src) != "" {
			values.Add("source", src)
		}
	}

	values.Del("segment")
	for _, seg := range state.Segments {
		if strings.TrimSpace(seg) != "" {
			values.Add("segment", seg)
		}
	}

	if state.SortKey != "" {
		values.Set("sort", state.SortKey)
	} else {
		values.Del("sort")
	}
	if state.SortDirection != "" {
		values.Set("direction", state.SortDirection)
	} else {
		values.Del("direction")
	}

	if state.Page <= 1 {
		values.Del("page")
	} else {
		values.Set("page", strconv.Itoa(state.Page))
	}
	if state.PageSize <= 0 || state.PageSize == defaultPromotionUsagePageSize {
		values.Del("pageSize")
	} else {
		values.Set("pageSize", strconv.Itoa(state.PageSize))
	}

	if state.AutoRefresh {
		values.Set("autoRefresh", "1")
	} else {
		values.Del("autoRefresh")
	}

	raw := values.Encode()
	base := joinBasePath(basePath, fmt.Sprintf("/promotions/%s/usages", url.PathEscape(promotionID)))
	if raw == "" {
		return base
	}
	return base + "?" + raw
}

func normalizePromotionChannel(value string) string {
	switch strings.TrimSpace(strings.ToLower(value)) {
	case "online_store", "online":
		return string(adminpromotions.ChannelOnlineStore)
	case "retail", "store":
		return string(adminpromotions.ChannelRetail)
	case "app", "mobile_app":
		return string(adminpromotions.ChannelApp)
	default:
		return strings.TrimSpace(value)
	}
}

func errMessage(err error) string {
	if err == nil {
		return ""
	}
	return "利用履歴の取得に失敗しました。時間を置いて再度お試しください。"
}
