package ui

import (
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/a-h/templ"

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
