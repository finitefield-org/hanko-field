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

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	catalogtpl "finitefield.org/hanko-admin/internal/admin/templates/catalog"
)

// CatalogRootRedirect sends /admin/catalog to the templates tab by default.
func (h *Handlers) CatalogRootRedirect(w http.ResponseWriter, r *http.Request) {
	base := custommw.BasePathFromContext(r.Context())
	http.Redirect(w, r, joinBasePath(base, "/catalog/templates"), http.StatusFound)
}

// CatalogPage renders the full catalog overview page for the requested kind.
func (h *Handlers) CatalogPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	kind, state, query := parseCatalogRequest(r)
	result, err := h.catalog.ListAssets(ctx, user.Token, query)
	if err != nil {
		log.Printf("catalog: list assets failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	data := catalogtpl.BuildPageData(custommw.BasePathFromContext(ctx), kind, state, result)
	templ.Handler(catalogtpl.Index(data)).ServeHTTP(w, r)
}

// CatalogTable returns the table fragment for htmx requests.
func (h *Handlers) CatalogTable(w http.ResponseWriter, r *http.Request) {
	renderCatalogFragment(w, r, h, fragmentTable)
}

// CatalogCards returns the card grid fragment for htmx requests.
func (h *Handlers) CatalogCards(w http.ResponseWriter, r *http.Request) {
	renderCatalogFragment(w, r, h, fragmentCards)
}

type fragmentKind int

const (
	fragmentTable fragmentKind = iota
	fragmentCards
)

const (
	catalogDefaultPageSize = 10
	catalogMaxPageSize     = 50
)

func renderCatalogFragment(w http.ResponseWriter, r *http.Request, h *Handlers, kind fragmentKind) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	assetKind, state, query := parseCatalogRequest(r)
	result, err := h.catalog.ListAssets(ctx, user.Token, query)
	if err != nil {
		log.Printf("catalog: fragment list failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	data := catalogtpl.BuildPageData(custommw.BasePathFromContext(ctx), assetKind, state, result)
	switch kind {
	case fragmentCards:
		templ.Handler(catalogtpl.CardsFragment(data)).ServeHTTP(w, r)
	default:
		templ.Handler(catalogtpl.TableFragment(data)).ServeHTTP(w, r)
	}
}

// CatalogNewModal renders the create modal for a catalog kind.
func (h *Handlers) CatalogNewModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	_, ok := custommw.UserFromContext(ctx)
	if !ok {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	kind := catalogKindFromRequest(r)
	values := defaultCatalogValues(kind)
	basePath := custommw.BasePathFromContext(ctx)
	action := joinBasePath(basePath, fmt.Sprintf("/catalog/%s", kind))
	csrf := custommw.CSRFTokenFromContext(ctx)
	data := buildCatalogUpsertModal(kind, catalogModalModeNew, values, nil, "", action, http.MethodPost, csrf)

	templ.Handler(catalogtpl.UpsertModal(data)).ServeHTTP(w, r)
}

// CatalogEditModal renders the edit modal for a specific asset.
func (h *Handlers) CatalogEditModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	kind := catalogKindFromRequest(r)
	itemID := catalogItemID(r)
	if itemID == "" {
		http.Error(w, "アセットIDが不正です。", http.StatusBadRequest)
		return
	}

	detail, err := h.catalog.GetAsset(ctx, user.Token, kind, itemID)
	if err != nil {
		handleCatalogServiceError(w, err)
		return
	}

	values := catalogValuesFromDetail(kind, detail)
	basePath := custommw.BasePathFromContext(ctx)
	action := joinBasePath(basePath, fmt.Sprintf("/catalog/%s/%s", kind, itemID))
	csrf := custommw.CSRFTokenFromContext(ctx)
	data := buildCatalogUpsertModal(kind, catalogModalModeEdit, values, nil, "", action, http.MethodPut, csrf)

	templ.Handler(catalogtpl.UpsertModal(data)).ServeHTTP(w, r)
}

// CatalogDeleteModal renders the delete confirmation modal.
func (h *Handlers) CatalogDeleteModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	kind := catalogKindFromRequest(r)
	itemID := catalogItemID(r)
	if itemID == "" {
		http.Error(w, "アセットIDが不正です。", http.StatusBadRequest)
		return
	}

	detail, err := h.catalog.GetAsset(ctx, user.Token, kind, itemID)
	if err != nil {
		handleCatalogServiceError(w, err)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	action := joinBasePath(basePath, fmt.Sprintf("/catalog/%s/%s", kind, itemID))
	csrf := custommw.CSRFTokenFromContext(ctx)
	data := buildCatalogDeleteModal(kind, detail, action, csrf, "")

	templ.Handler(catalogtpl.DeleteModal(data)).ServeHTTP(w, r)
}

// CatalogCreate handles asset creation submissions.
func (h *Handlers) CatalogCreate(w http.ResponseWriter, r *http.Request) {
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

	kind := catalogKindFromRequest(r)
	values := catalogFormValues(kind, r.PostForm)
	input, fieldErrors := parseCatalogForm(kind, r.PostForm, false)
	if len(fieldErrors) > 0 {
		reRenderCatalogModal(w, r, kind, values, fieldErrors, "入力内容を確認してください。", http.MethodPost, catalogModalModeNew)
		return
	}

	input.Kind = kind
	if _, err := h.catalog.SaveAsset(ctx, user.Token, input); err != nil {
		handleCatalogMutationError(w, r, kind, values, nil, err, http.MethodPost, catalogModalModeNew)
		return
	}

	triggerCatalogRefresh(w, fmt.Sprintf("%sを作成しました。", strings.TrimSpace(input.Name)), "success")
}

// CatalogUpdate handles asset update submissions.
func (h *Handlers) CatalogUpdate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	itemID := catalogItemID(r)
	if itemID == "" {
		http.Error(w, "アセットIDが不正です。", http.StatusBadRequest)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	kind := catalogKindFromRequest(r)
	values := catalogFormValues(kind, r.PostForm)
	input, fieldErrors := parseCatalogForm(kind, r.PostForm, true)
	input.ID = itemID
	if len(fieldErrors) > 0 {
		reRenderCatalogModal(w, r, kind, values, fieldErrors, "入力内容を確認してください。", http.MethodPut, catalogModalModeEdit)
		return
	}

	input.Kind = kind
	if _, err := h.catalog.SaveAsset(ctx, user.Token, input); err != nil {
		handleCatalogMutationError(w, r, kind, values, fieldErrors, err, http.MethodPut, catalogModalModeEdit)
		return
	}

	triggerCatalogRefresh(w, fmt.Sprintf("%sを更新しました。", strings.TrimSpace(input.Name)), "success")
}

// CatalogDelete handles delete submissions.
func (h *Handlers) CatalogDelete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}
	itemID := catalogItemID(r)
	if itemID == "" {
		http.Error(w, "アセットIDが不正です。", http.StatusBadRequest)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	kind := catalogKindFromRequest(r)
	version := strings.TrimSpace(r.PostFormValue("version"))
	req := admincatalog.DeleteRequest{Kind: kind, ID: itemID, Version: version}
	if err := h.catalog.DeleteAsset(ctx, user.Token, req); err != nil {
		h.handleCatalogDeleteError(w, r, kind, itemID, err)
		return
	}

	triggerCatalogRefresh(w, "アセットを削除しました。", "info")
}

func parseCatalogRequest(r *http.Request) (admincatalog.Kind, catalogtpl.QueryState, admincatalog.ListQuery) {
	params := r.URL.Query()
	kind := admincatalog.NormalizeKind(chi.URLParam(r, "kind"))
	statuses := params["status"]
	tags := params["tag"]
	category := strings.TrimSpace(params.Get("category"))
	owner := strings.TrimSpace(params.Get("owner"))
	updated := strings.TrimSpace(params.Get("updated"))
	query := strings.TrimSpace(params.Get("q"))
	view := strings.TrimSpace(params.Get("view"))
	selected := strings.TrimSpace(params.Get("selected"))
	page := parseCatalogPage(params.Get("page"))
	pageSize := parseCatalogPageSize(params.Get("pageSize"))
	sortKey, sortDirection, sortValue := parseCatalogSort(params.Get("sort"))

	state := catalogtpl.QueryState{
		Status:   statuses,
		Category: category,
		Owner:    owner,
		Tags:     tags,
		Updated:  updated,
		Search:   query,
		View:     view,
		Selected: selected,
		RawQuery: r.URL.RawQuery,
		Page:     page,
		PageSize: pageSize,
		Sort:     sortValue,
		SortKey:  sortKey,
		SortDir:  string(sortDirection),
	}

	list := admincatalog.ListQuery{
		Kind:          kind,
		Statuses:      toCatalogStatuses(statuses),
		Category:      category,
		Owner:         owner,
		Tags:          tags,
		UpdatedRange:  updated,
		Search:        query,
		View:          admincatalog.NormalizeViewMode(view),
		SelectedID:    selected,
		Page:          page,
		PageSize:      pageSize,
		SortKey:       sortKey,
		SortDirection: sortDirection,
	}
	state.View = string(list.View)
	return kind, state, list
}

func toCatalogStatuses(values []string) []admincatalog.Status {
	if len(values) == 0 {
		return nil
	}
	set := make([]admincatalog.Status, 0, len(values))
	for _, value := range values {
		switch strings.ToLower(strings.TrimSpace(value)) {
		case string(admincatalog.StatusDraft):
			set = append(set, admincatalog.StatusDraft)
		case string(admincatalog.StatusInReview):
			set = append(set, admincatalog.StatusInReview)
		case string(admincatalog.StatusArchived):
			set = append(set, admincatalog.StatusArchived)
		case string(admincatalog.StatusPublished):
			set = append(set, admincatalog.StatusPublished)
		}
	}
	return set
}

func parseCatalogPage(raw string) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 1
	}
	page, err := strconv.Atoi(raw)
	if err != nil || page <= 0 {
		return 1
	}
	return page
}

func parseCatalogPageSize(raw string) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return catalogDefaultPageSize
	}
	size, err := strconv.Atoi(raw)
	if err != nil || size <= 0 {
		return catalogDefaultPageSize
	}
	if size > catalogMaxPageSize {
		return catalogMaxPageSize
	}
	return size
}

func parseCatalogSort(raw string) (string, admincatalog.SortDirection, string) {
	raw = strings.TrimSpace(raw)
	direction := admincatalog.SortDirectionDesc
	value := raw
	if raw == "" {
		return "updated_at", admincatalog.SortDirectionDesc, "-updated_at"
	}
	if strings.HasPrefix(raw, "-") {
		direction = admincatalog.SortDirectionDesc
		raw = strings.TrimPrefix(raw, "-")
	} else {
		direction = admincatalog.SortDirectionAsc
	}

	key := strings.ToLower(strings.TrimSpace(raw))
	switch key {
	case "name", "status", "owner", "updated_at":
		// allowed
	default:
		key = "updated_at"
		direction = admincatalog.SortDirectionDesc
	}

	if direction == admincatalog.SortDirectionDesc {
		value = "-" + key
	} else {
		value = key
	}
	return key, direction, value
}

func catalogKindFromRequest(r *http.Request) admincatalog.Kind {
	return admincatalog.NormalizeKind(chi.URLParam(r, "kind"))
}

func catalogItemID(r *http.Request) string {
	return strings.TrimSpace(chi.URLParam(r, "itemID"))
}

func handleCatalogServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, admincatalog.ErrItemNotFound):
		http.Error(w, "指定されたアセットが見つかりません。", http.StatusNotFound)
	default:
		log.Printf("catalog: fetch asset failed: %v", err)
		http.Error(w, "アセットの取得に失敗しました。", http.StatusBadGateway)
	}
}

func reRenderCatalogModal(w http.ResponseWriter, r *http.Request, kind admincatalog.Kind, values map[string]string, fieldErrors map[string]string, message string, method string, mode catalogModalMode) {
	ctx := r.Context()
	basePath := custommw.BasePathFromContext(ctx)
	csrf := custommw.CSRFTokenFromContext(ctx)
	itemID := catalogItemID(r)
	action := joinBasePath(basePath, fmt.Sprintf("/catalog/%s", kind))
	if mode == catalogModalModeEdit && itemID != "" {
		action = joinBasePath(basePath, fmt.Sprintf("/catalog/%s/%s", kind, itemID))
	}
	data := buildCatalogUpsertModal(kind, mode, values, fieldErrors, message, action, method, csrf)
	w.WriteHeader(http.StatusUnprocessableEntity)
	templ.Handler(catalogtpl.UpsertModal(data)).ServeHTTP(w, r)
}

func handleCatalogMutationError(w http.ResponseWriter, r *http.Request, kind admincatalog.Kind, values map[string]string, fieldErrors map[string]string, err error, method string, mode catalogModalMode) {
	switch {
	case errors.Is(err, admincatalog.ErrItemNotFound):
		http.Error(w, "指定されたアセットが見つかりません。", http.StatusNotFound)
	case errors.Is(err, admincatalog.ErrVersionConflict):
		reRenderCatalogModal(w, r, kind, values, fieldErrors, "別のユーザーによって更新されました。最新データを確認してください。", method, mode)
	default:
		log.Printf("catalog: mutation failed: %v", err)
		http.Error(w, "処理に失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
	}
}

func (h *Handlers) handleCatalogDeleteError(w http.ResponseWriter, r *http.Request, kind admincatalog.Kind, itemID string, err error) {
	switch {
	case errors.Is(err, admincatalog.ErrItemNotFound):
		http.Error(w, "指定されたアセットが見つかりません。", http.StatusNotFound)
		return
	case errors.Is(err, admincatalog.ErrVersionConflict):
		ctx := r.Context()
		user, ok := custommw.UserFromContext(ctx)
		if ok && user != nil {
			if detail, fetchErr := h.catalog.GetAsset(ctx, user.Token, kind, itemID); fetchErr == nil {
				basePath := custommw.BasePathFromContext(ctx)
				action := joinBasePath(basePath, fmt.Sprintf("/catalog/%s/%s", kind, itemID))
				csrf := custommw.CSRFTokenFromContext(ctx)
				data := buildCatalogDeleteModal(kind, detail, action, csrf, "別のユーザーが更新しました。内容を確認してください。")
				w.WriteHeader(http.StatusConflict)
				templ.Handler(catalogtpl.DeleteModal(data)).ServeHTTP(w, r)
				return
			}
		}
		log.Printf("catalog: delete version conflict but refetch failed: %v", err)
		http.Error(w, "削除に失敗しました。", http.StatusConflict)
	default:
		log.Printf("catalog: delete failed: %v", err)
		http.Error(w, "削除に失敗しました。", http.StatusBadGateway)
	}
}

func triggerCatalogRefresh(w http.ResponseWriter, message, tone string) {
	payload := map[string]any{
		"toast": map[string]string{
			"message": strings.TrimSpace(message),
			"tone":    strings.TrimSpace(tone),
		},
		"modal:close": true,
		"refresh:fragment": map[string]any{
			"targets": []string{"#catalog-view"},
		},
	}
	if data, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(data))
	} else {
		log.Printf("catalog: failed to marshal HX-Trigger payload: %v", err)
	}
	w.WriteHeader(http.StatusNoContent)
}

func parseCatalogForm(kind admincatalog.Kind, form url.Values, requireVersion bool) (admincatalog.AssetInput, map[string]string) {
	input := admincatalog.AssetInput{Kind: kind}
	errs := make(map[string]string)
	read := func(key string) string { return strings.TrimSpace(form.Get(key)) }

	input.Name = read("name")
	if input.Name == "" {
		errs["name"] = "必須です。"
	}
	input.Identifier = read("identifier")
	if input.Identifier == "" {
		errs["identifier"] = "必須です。"
	}
	input.Description = read("description")
	if input.Description == "" {
		errs["description"] = "必須です。"
	}
	if status, ok := admincatalog.ParseStatus(read("status")); ok {
		input.Status = status
	} else {
		errs["status"] = "無効な値です。"
	}
	input.Category = read("category")
	input.Tags = catalogSplitCSV(read("tags"))
	input.PreviewURL = read("previewURL")
	if input.PreviewURL == "" {
		errs["previewURL"] = "必須です。"
	}
	input.PrimaryColor = read("primaryColor")
	input.OwnerName = read("ownerName")
	if input.OwnerName == "" {
		errs["ownerName"] = "必須です。"
	}
	input.OwnerEmail = read("ownerEmail")
	if input.OwnerEmail != "" && !strings.Contains(input.OwnerEmail, "@") {
		errs["ownerEmail"] = "メールアドレス形式で入力してください。"
	}
	input.TemplateID = read("templateID")
	input.SVGPath = read("svgPath")
	input.FontFamily = read("fontFamily")
	input.FontWeights = catalogSplitCSV(read("fontWeights"))
	input.License = read("license")
	input.MaterialSKU = read("materialSKU")
	input.Color = read("color")
	input.ProductSKU = read("productSKU")
	input.Currency = strings.ToUpper(read("currency"))
	input.PrimaryColor = read("primaryColor")
	input.PhotoURLs = catalogSplitLines(form.Get("photoURLs"))
	input.Version = read("version")
	if requireVersion && input.Version == "" {
		errs["version"] = "バージョン情報を指定してください。"
	}

	switch kind {
	case admincatalog.KindTemplates:
		if input.TemplateID == "" {
			errs["templateID"] = "必須です。"
		}
		if input.SVGPath == "" {
			errs["svgPath"] = "必須です。"
		}
	case admincatalog.KindFonts:
		if input.FontFamily == "" {
			errs["fontFamily"] = "必須です。"
		}
		if input.License == "" {
			errs["license"] = "必須です。"
		}
	case admincatalog.KindMaterials:
		if input.MaterialSKU == "" {
			errs["materialSKU"] = "必須です。"
		}
		input.Inventory = catalogParsePositiveInt(read("inventory"), "inventory", true, errs)
	case admincatalog.KindProducts:
		if input.ProductSKU == "" {
			errs["productSKU"] = "必須です。"
		}
		if input.Currency == "" {
			errs["currency"] = "必須です。"
		}
		input.PriceMinor = catalogParsePositiveInt64(read("price"), "price", true, errs)
		input.LeadTimeDays = catalogParsePositiveInt(read("leadTime"), "leadTime", true, errs)
		if len(input.PhotoURLs) == 0 {
			errs["photoURLs"] = "1件以上のURLを入力してください。"
		}
	default:
		if input.TemplateID == "" {
			input.TemplateID = input.Identifier
		}
	}

	if kind != admincatalog.KindMaterials {
		if inv := strings.TrimSpace(read("inventory")); inv != "" {
			input.Inventory = catalogParsePositiveInt(inv, "inventory", false, errs)
		}
	}
	if kind != admincatalog.KindProducts {
		if price := strings.TrimSpace(read("price")); price != "" {
			input.PriceMinor = catalogParsePositiveInt64(price, "price", false, errs)
		}
	}
	if kind != admincatalog.KindProducts {
		if lead := strings.TrimSpace(read("leadTime")); lead != "" {
			input.LeadTimeDays = catalogParsePositiveInt(lead, "leadTime", false, errs)
		}
	}

	return input, errs
}

func catalogParsePositiveInt(value string, field string, required bool, errs map[string]string) int {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		if required {
			errs[field] = "必須です。"
		}
		return 0
	}
	num, err := strconv.Atoi(trimmed)
	if err != nil || num < 0 {
		errs[field] = "数値で入力してください。"
		return 0
	}
	return num
}

func catalogParsePositiveInt64(value string, field string, required bool, errs map[string]string) int64 {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		if required {
			errs[field] = "必須です。"
		}
		return 0
	}
	num, err := strconv.ParseInt(trimmed, 10, 64)
	if err != nil || num < 0 {
		errs[field] = "数値で入力してください。"
		return 0
	}
	return num
}

func catalogSplitCSV(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	result := make([]string, 0, len(parts))
	seen := map[string]struct{}{}
	for _, part := range parts {
		value := strings.TrimSpace(part)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}

func catalogSplitLines(raw string) []string {
	clean := strings.ReplaceAll(raw, "\r\n", "\n")
	parts := strings.FieldsFunc(clean, func(r rune) bool { return r == '\n' || r == ',' })
	result := make([]string, 0, len(parts))
	seen := map[string]struct{}{}
	for _, part := range parts {
		value := strings.TrimSpace(part)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}
