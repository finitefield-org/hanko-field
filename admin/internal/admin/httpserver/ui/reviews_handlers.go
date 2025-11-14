package ui

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminreviews "finitefield.org/hanko-admin/internal/admin/reviews"
	reviewstpl "finitefield.org/hanko-admin/internal/admin/templates/reviews"
)

const (
	defaultReviewsPageSize = 20
)

type reviewsRequest struct {
	query    adminreviews.ListQuery
	state    reviewstpl.QueryState
	selected string
}

// ReviewsModerationPage renders the review moderation dashboard.
func (h *Handlers) ReviewsModerationPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildReviewsRequest(r)

	result, err := h.reviews.List(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("reviews: list failed: %v", err)
		errMsg = "レビューの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminreviews.ListResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	selectedID := req.selected
	if selectedID == "" && len(result.Reviews) > 0 {
		selectedID = result.Reviews[0].ID
	}

	detail := reviewstpl.DetailPayload(basePath, selectedID, result)
	actualSelected := detail.SelectedID
	state := req.state
	state.Selected = actualSelected

	table := reviewstpl.TablePayload(basePath, state, result, actualSelected, errMsg)
	page := reviewstpl.BuildPageData(basePath, state, result, table, detail)

	templ.Handler(reviewstpl.Index(page)).ServeHTTP(w, r)
}

// ReviewsModerationTable renders the moderation table fragment for HTMX requests.
func (h *Handlers) ReviewsModerationTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildReviewsRequest(r)

	result, err := h.reviews.List(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("reviews: list failed: %v", err)
		errMsg = "レビューの取得に失敗しました。時間を置いて再度お試しください。"
		result = adminreviews.ListResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	selectedID := req.selected
	if selectedID == "" && len(result.Reviews) > 0 {
		selectedID = result.Reviews[0].ID
	}

	detail := reviewstpl.DetailPayload(basePath, selectedID, result)
	actualSelected := detail.SelectedID
	state := req.state
	state.Selected = actualSelected

	table := reviewstpl.TablePayload(basePath, state, result, actualSelected, errMsg)
	req.selected = actualSelected
	if canonical := canonicalReviewsURL(basePath, req); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}
	templ.Handler(reviewstpl.TableFragment(table, detail)).ServeHTTP(w, r)
}

// ReviewsModerationModal renders the moderation modal for approve/reject decisions.
func (h *Handlers) ReviewsModerationModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	reviewID := strings.TrimSpace(chi.URLParam(r, "reviewID"))
	if reviewID == "" {
		http.Error(w, "レビューIDが不正です。", http.StatusBadRequest)
		return
	}

	decision := adminreviews.ModerationDecision(strings.TrimSpace(r.URL.Query().Get("decision")))
	if !isValidModerationDecision(decision) {
		http.Error(w, "モデレーション種別が不正です。", http.StatusBadRequest)
		return
	}

	modal, err := h.reviews.ModerationModal(ctx, user.Token, reviewID, decision)
	if err != nil {
		if errors.Is(err, adminreviews.ErrReviewNotFound) {
			http.Error(w, "指定されたレビューが見つかりません。", http.StatusNotFound)
			return
		}
		if errors.Is(err, adminreviews.ErrInvalidDecision) {
			http.Error(w, "モデレーション種別が不正です。", http.StatusBadRequest)
			return
		}
		log.Printf("reviews: load moderation modal failed: %v", err)
		http.Error(w, "モーダルを表示できません。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	csrf := custommw.CSRFTokenFromContext(ctx)
	currentURL := r.Header.Get("HX-Current-URL")

	data := reviewstpl.ModerationModalPayload(basePath, modal, csrf, currentURL)
	templ.Handler(reviewstpl.ModerationModal(data)).ServeHTTP(w, r)
}

// ReviewsModerate processes approve/reject submissions.
func (h *Handlers) ReviewsModerate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	reviewID := strings.TrimSpace(chi.URLParam(r, "reviewID"))
	if reviewID == "" {
		http.Error(w, "レビューIDが不正です。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "送信内容の解析に失敗しました。", http.StatusBadRequest)
		return
	}

	decision := adminreviews.ModerationDecision(strings.TrimSpace(r.FormValue("decision")))
	req := adminreviews.ModerationRequest{
		Decision:       decision,
		Notes:          strings.TrimSpace(r.FormValue("notes")),
		NotifyCustomer: parseCheckbox(r.FormValue("notifyCustomer")),
		ActorID:        user.UID,
		ActorName:      user.Email,
		ActorEmail:     user.Email,
	}

	result, err := h.reviews.Moderate(ctx, user.Token, reviewID, req)
	if err != nil {
		switch {
		case errors.Is(err, adminreviews.ErrReviewNotFound):
			http.Error(w, "指定されたレビューが見つかりません。", http.StatusNotFound)
		case errors.Is(err, adminreviews.ErrInvalidDecision):
			http.Error(w, "モデレーション種別が不正です。", http.StatusBadRequest)
		default:
			log.Printf("reviews: moderate failed: %v", err)
			http.Error(w, "モデレーションに失敗しました。", http.StatusBadGateway)
		}
		return
	}

	currentURL := r.Header.Get("HX-Current-URL")
	reviewsReq := buildReviewsRequestFromURL(currentURL)
	if selected := strings.TrimSpace(r.FormValue("selected")); selected != "" {
		reviewsReq.selected = selected
	}
	if reviewsReq.selected == "" {
		reviewsReq.selected = result.Review.ID
	}

	listResult, listErr := h.reviews.List(ctx, user.Token, reviewsReq.query)
	errMsg := ""
	if listErr != nil {
		log.Printf("reviews: refresh after moderation failed: %v", listErr)
		errMsg = "レビュー一覧を再取得できませんでした。"
		listResult = adminreviews.ListResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	detail := reviewstpl.DetailPayload(basePath, reviewsReq.selected, listResult)
	reviewsReq.state.Selected = detail.SelectedID
	table := reviewstpl.TablePayload(basePath, reviewsReq.state, listResult, detail.SelectedID, errMsg)
	payload := reviewstpl.ModerationSuccessPayload(table, detail)

	message := "レビューを承認しました。"
	tone := "success"
	if decision == adminreviews.ModerationDecisionReject {
		message = "レビューを却下しました。"
		tone = "warning"
	}

	w.Header().Set("HX-Trigger", fmt.Sprintf(`{"toast":{"message":"%s","tone":"%s"},"modal:close":true}`, message, tone))
	templ.Handler(reviewstpl.ModerationSuccess(payload)).ServeHTTP(w, r)
}

// ReviewsReplyModal renders the reply capture modal.
func (h *Handlers) ReviewsReplyModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	reviewID := strings.TrimSpace(chi.URLParam(r, "reviewID"))
	if reviewID == "" {
		http.Error(w, "レビューIDが不正です。", http.StatusBadRequest)
		return
	}

	modal, err := h.reviews.ReplyModal(ctx, user.Token, reviewID)
	if err != nil {
		if errors.Is(err, adminreviews.ErrReviewNotFound) {
			http.Error(w, "指定されたレビューが見つかりません。", http.StatusNotFound)
			return
		}
		log.Printf("reviews: load reply modal failed: %v", err)
		http.Error(w, "モーダルを表示できません。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	csrf := custommw.CSRFTokenFromContext(ctx)
	currentURL := r.Header.Get("HX-Current-URL")

	data := reviewstpl.ReplyModalPayload(basePath, modal, csrf, currentURL, "", false, false, "")
	templ.Handler(reviewstpl.ReplyModal(data)).ServeHTTP(w, r)
}

// ReviewsStoreReply persists a storefront reply.
func (h *Handlers) ReviewsStoreReply(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	reviewID := strings.TrimSpace(chi.URLParam(r, "reviewID"))
	if reviewID == "" {
		http.Error(w, "レビューIDが不正です。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "送信内容の解析に失敗しました。", http.StatusBadRequest)
		return
	}

	body := r.FormValue("body")
	isPublic := parseCheckbox(r.FormValue("isPublic"))
	notifyCustomer := parseCheckbox(r.FormValue("notifyCustomer"))

	req := adminreviews.ReplyRequest{
		Body:           body,
		IsPublic:       isPublic,
		NotifyCustomer: notifyCustomer,
		ActorID:        user.UID,
		ActorName:      user.Email,
		ActorEmail:     user.Email,
	}

	result, err := h.reviews.StoreReply(ctx, user.Token, reviewID, req)
	if err != nil {
		if errors.Is(err, adminreviews.ErrReviewNotFound) {
			http.Error(w, "指定されたレビューが見つかりません。", http.StatusNotFound)
			return
		}
		if errors.Is(err, adminreviews.ErrEmptyReplyBody) {
			basePath := custommw.BasePathFromContext(ctx)
			csrf := custommw.CSRFTokenFromContext(ctx)
			currentURL := r.Header.Get("HX-Current-URL")
			modal, loadErr := h.reviews.ReplyModal(ctx, user.Token, reviewID)
			if loadErr != nil {
				log.Printf("reviews: reload reply modal after validation failed: %v", loadErr)
				http.Error(w, "返信を保存できませんでした。", http.StatusBadGateway)
				return
			}
			data := reviewstpl.ReplyModalPayload(basePath, modal, csrf, currentURL, body, notifyCustomer, isPublic, "返信内容を入力してください。")
			w.WriteHeader(http.StatusUnprocessableEntity)
			templ.Handler(reviewstpl.ReplyModal(data)).ServeHTTP(w, r)
			return
		}
		log.Printf("reviews: store reply failed: %v", err)
		http.Error(w, "返信の登録に失敗しました。", http.StatusBadGateway)
		return
	}

	currentURL := r.Header.Get("HX-Current-URL")
	reviewsReq := buildReviewsRequestFromURL(currentURL)
	if selected := strings.TrimSpace(r.FormValue("selected")); selected != "" {
		reviewsReq.selected = selected
	}
	if reviewsReq.selected == "" {
		reviewsReq.selected = result.Review.ID
	}

	listResult, listErr := h.reviews.List(ctx, user.Token, reviewsReq.query)
	errMsg := ""
	if listErr != nil {
		log.Printf("reviews: refresh after reply failed: %v", listErr)
		errMsg = "レビュー一覧を再取得できませんでした。"
		listResult = adminreviews.ListResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	detail := reviewstpl.DetailPayload(basePath, reviewsReq.selected, listResult)
	reviewsReq.state.Selected = detail.SelectedID
	table := reviewstpl.TablePayload(basePath, reviewsReq.state, listResult, detail.SelectedID, errMsg)
	payload := reviewstpl.ReplySuccessPayload(table, detail)

	w.Header().Set("HX-Trigger", `{"toast":{"message":"返信を保存しました。","tone":"success"},"modal:close":true}`)
	templ.Handler(reviewstpl.ReplySuccess(payload)).ServeHTTP(w, r)
}

func buildReviewsRequest(r *http.Request) reviewsRequest {
	query := r.URL.Query()
	state := reviewstpl.QueryState{
		RawQuery:   r.URL.RawQuery,
		Search:     strings.TrimSpace(query.Get("q")),
		Moderation: strings.TrimSpace(query.Get("moderation")),
		AgeBucket:  strings.TrimSpace(query.Get("age")),
		Sort:       strings.TrimSpace(query.Get("sort")),
		Selected:   strings.TrimSpace(query.Get("selected")),
	}

	listQuery := adminreviews.ListQuery{
		Search: strings.TrimSpace(query.Get("q")),
	}

	listQuery.Moderation = parseModerationStatuses(query)
	if len(listQuery.Moderation) == 0 {
		listQuery.Moderation = []adminreviews.ModerationStatus{adminreviews.ModerationPending}
		state.Moderation = string(adminreviews.ModerationPending)
	}

	state.Ratings, listQuery.Ratings = parseIntFilters(query, "rating")
	state.Products, listQuery.ProductIDs = parseStringFilters(query, "product")
	state.Flags, listQuery.FlagTypes = parseStringFilters(query, "flag")
	state.Channels, listQuery.Channels = parseStringFilters(query, "channel")

	if state.AgeBucket != "" {
		listQuery.AgeBucket = state.AgeBucket
	}

	page := parsePositiveIntDefault(query.Get("page"), 1)
	pageSize := parsePositiveIntDefault(query.Get("pageSize"), defaultReviewsPageSize)

	state.Page = page
	state.PageSize = pageSize

	listQuery.Page = page
	listQuery.PageSize = pageSize

	key, direction := parseReviewSort(strings.TrimSpace(query.Get("sort")))
	listQuery.SortKey = key
	listQuery.SortDirection = direction

	state.Sort = formatSort(key, direction)

	return reviewsRequest{
		query:    listQuery,
		state:    state,
		selected: state.Selected,
	}
}

func canonicalReviewsURL(basePath string, req reviewsRequest) string {
	u, err := url.Parse(basePath)
	if err != nil {
		return ""
	}
	u.Path = strings.TrimRight(u.Path, "/") + "/reviews"
	q := url.Values{}

	if len(req.query.Moderation) > 0 {
		mod := make([]string, 0, len(req.query.Moderation))
		for _, status := range req.query.Moderation {
			mod = append(mod, string(status))
		}
		q.Set("moderation", strings.Join(mod, ","))
	}
	if req.query.Search != "" {
		q.Set("q", req.query.Search)
	}
	if len(req.query.Ratings) > 0 {
		values := make([]string, 0, len(req.query.Ratings))
		for _, rating := range req.query.Ratings {
			values = append(values, strconv.Itoa(rating))
		}
		q.Set("rating", strings.Join(values, ","))
	}
	if len(req.query.ProductIDs) > 0 {
		q.Set("product", strings.Join(req.query.ProductIDs, ","))
	}
	if len(req.query.FlagTypes) > 0 {
		q.Set("flag", strings.Join(req.query.FlagTypes, ","))
	}
	if len(req.query.Channels) > 0 {
		q.Set("channel", strings.Join(req.query.Channels, ","))
	}
	if req.query.AgeBucket != "" {
		q.Set("age", req.query.AgeBucket)
	}
	if req.query.SortKey != "" {
		q.Set("sort", formatSort(req.query.SortKey, req.query.SortDirection))
	}
	if req.query.Page > 1 {
		q.Set("page", strconv.Itoa(req.query.Page))
	}
	if req.query.PageSize != defaultReviewsPageSize && req.query.PageSize > 0 {
		q.Set("pageSize", strconv.Itoa(req.query.PageSize))
	}
	if req.selected != "" {
		q.Set("selected", req.selected)
	}

	u.RawQuery = q.Encode()
	return u.String()
}

func parseModerationStatuses(query url.Values) []adminreviews.ModerationStatus {
	values := query["moderation"]
	if len(values) == 0 {
		raw := strings.TrimSpace(query.Get("moderation"))
		if raw != "" {
			values = []string{raw}
		}
	}
	if len(values) == 0 {
		return nil
	}
	result := make([]adminreviews.ModerationStatus, 0, len(values))
	for _, raw := range values {
		for _, token := range strings.Split(raw, ",") {
			token = strings.TrimSpace(token)
			if token == "" {
				continue
			}
			switch strings.ToLower(token) {
			case string(adminreviews.ModerationPending):
				result = append(result, adminreviews.ModerationPending)
			case string(adminreviews.ModerationApproved):
				result = append(result, adminreviews.ModerationApproved)
			case string(adminreviews.ModerationRejected):
				result = append(result, adminreviews.ModerationRejected)
			}
		}
	}
	return result
}

func parseIntFilters(query url.Values, key string) ([]int, []int) {
	rawValues := query[key]
	if len(rawValues) == 0 {
		val := strings.TrimSpace(query.Get(key))
		if val != "" {
			rawValues = []string{val}
		}
	}
	if len(rawValues) == 0 {
		return nil, nil
	}

	unique := map[int]struct{}{}
	state := make([]int, 0)
	result := make([]int, 0)

	for _, raw := range rawValues {
		for _, token := range strings.Split(raw, ",") {
			token = strings.TrimSpace(token)
			if token == "" {
				continue
			}
			value, err := strconv.Atoi(token)
			if err != nil {
				continue
			}
			if _, ok := unique[value]; ok {
				continue
			}
			unique[value] = struct{}{}
			state = append(state, value)
			result = append(result, value)
		}
	}
	return state, result
}

func parseStringFilters(query url.Values, key string) ([]string, []string) {
	rawVals := query[key]
	if len(rawVals) == 0 {
		val := strings.TrimSpace(query.Get(key))
		if val != "" {
			rawVals = []string{val}
		}
	}
	if len(rawVals) == 0 {
		return nil, nil
	}

	unique := map[string]struct{}{}
	state := make([]string, 0)
	result := make([]string, 0)
	for _, raw := range rawVals {
		for _, token := range strings.Split(raw, ",") {
			token = strings.TrimSpace(token)
			if token == "" {
				continue
			}
			tokenLower := strings.ToLower(token)
			if _, ok := unique[tokenLower]; ok {
				continue
			}
			unique[tokenLower] = struct{}{}
			state = append(state, token)
			result = append(result, token)
		}
	}
	return state, result
}

func parseReviewSort(raw string) (adminreviews.SortKey, adminreviews.SortDirection) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return adminreviews.SortSubmittedAt, adminreviews.SortDirectionDesc
	}
	dir := adminreviews.SortDirectionAsc
	if strings.HasPrefix(raw, "-") {
		dir = adminreviews.SortDirectionDesc
		raw = strings.TrimPrefix(raw, "-")
	}

	switch strings.ToLower(raw) {
	case "rating":
		return adminreviews.SortRating, dir
	case "submitted_at":
		return adminreviews.SortSubmittedAt, dir
	default:
		return adminreviews.SortSubmittedAt, dir
	}
}

func formatSort(key adminreviews.SortKey, dir adminreviews.SortDirection) string {
	value := ""
	switch key {
	case adminreviews.SortRating:
		value = "rating"
	default:
		value = "submitted_at"
	}
	if dir == adminreviews.SortDirectionDesc {
		return "-" + value
	}
	return value
}

func buildReviewsRequestFromURL(raw string) reviewsRequest {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u == nil {
		return reviewsRequest{}
	}
	req := &http.Request{
		URL: &url.URL{
			Scheme:     u.Scheme,
			Host:       u.Host,
			Path:       u.Path,
			RawQuery:   u.RawQuery,
			ForceQuery: u.ForceQuery,
		},
	}
	return buildReviewsRequest(req)
}

func isValidModerationDecision(decision adminreviews.ModerationDecision) bool {
	switch decision {
	case adminreviews.ModerationDecisionApprove, adminreviews.ModerationDecisionReject:
		return true
	default:
		return false
	}
}
