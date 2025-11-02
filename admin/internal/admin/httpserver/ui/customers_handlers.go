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

	admincustomers "finitefield.org/hanko-admin/internal/admin/customers"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	customerstpl "finitefield.org/hanko-admin/internal/admin/templates/customers"
)

const (
	defaultCustomersPageSize = 20
	defaultCustomersSort     = "-last_order"
)

type customersRequest struct {
	query admincustomers.ListQuery
	state customerstpl.QueryState
}

// CustomersPage renders the customers index page.
func (h *Handlers) CustomersPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildCustomersRequest(r)

	result, err := h.customers.List(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("customers: list failed: %v", err)
		errMsg = "顧客の取得に失敗しました。時間を置いて再度お試しください。"
		result = admincustomers.ListResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	table := customerstpl.TablePayload(basePath, req.state, result, errMsg)
	page := customerstpl.BuildPageData(basePath, req.state, result, table)

	templ.Handler(customerstpl.Index(page)).ServeHTTP(w, r)
}

// CustomersTable renders the customers table fragment for HTMX requests.
func (h *Handlers) CustomersTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildCustomersRequest(r)

	result, err := h.customers.List(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("customers: list failed: %v", err)
		errMsg = "顧客の取得に失敗しました。時間を置いて再度お試しください。"
		result = admincustomers.ListResult{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	table := customerstpl.TablePayload(basePath, req.state, result, errMsg)

	if canonical := canonicalCustomersURL(basePath, req); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(customerstpl.Table(table)).ServeHTTP(w, r)
}

// CustomerDetailPage renders the detailed profile view for a single customer.
func (h *Handlers) CustomerDetailPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	customerID := strings.TrimSpace(chi.URLParam(r, "customerID"))
	if customerID == "" {
		http.Error(w, "顧客IDが指定されていません。", http.StatusBadRequest)
		return
	}

	detail, err := h.customers.Detail(ctx, user.Token, customerID)
	if err != nil {
		if errors.Is(err, admincustomers.ErrCustomerNotFound) {
			http.NotFound(w, r)
			return
		}
		if errors.Is(err, admincustomers.ErrNotConfigured) {
			http.Error(w, "顧客詳細サービスが構成されていません。", http.StatusNotImplemented)
			return
		}
		log.Printf("customers: detail fetch failed: %v", err)
		http.Error(w, "顧客詳細の取得に失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	activeTab := normalizeCustomerDetailTab(r.URL.Query().Get("tab"))
	page := customerstpl.BuildDetailPageData(basePath, detail, activeTab)

	if custommw.IsHTMXRequest(ctx) {
		target := strings.TrimSpace(custommw.HTMXInfoFromContext(ctx).Target)
		target = strings.TrimPrefix(target, "#")
		if strings.EqualFold(target, "customer-tabs") {
			templ.Handler(customerstpl.CustomerTabs(page)).ServeHTTP(w, r)
			return
		}
	}

	templ.Handler(customerstpl.DetailPage(page)).ServeHTTP(w, r)
}

// CustomerDeactivateModal renders the deactivate + mask confirmation modal.
func (h *Handlers) CustomerDeactivateModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	customerID := strings.TrimSpace(chi.URLParam(r, "customerID"))
	if customerID == "" {
		http.Error(w, "顧客IDが指定されていません。", http.StatusBadRequest)
		return
	}

	modal, err := h.customers.DeactivateModal(ctx, user.Token, customerID)
	if err != nil {
		switch {
		case errors.Is(err, admincustomers.ErrCustomerNotFound):
			http.NotFound(w, r)
		case errors.Is(err, admincustomers.ErrNotConfigured):
			http.Error(w, "顧客サービスが構成されていません。", http.StatusNotImplemented)
		default:
			log.Printf("customers: deactivate modal load failed: %v", err)
			http.Error(w, "退会モーダルの読み込みに失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
		}
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	csrf := custommw.CSRFTokenFromContext(ctx)
	form := customerstpl.DeactivateFormState{
		FieldErrors: make(map[string]string),
	}
	payload := customerstpl.DeactivateModalPayload(basePath, modal, csrf, form)

	templ.Handler(customerstpl.DeactivateModal(payload)).ServeHTTP(w, r)
}

// CustomerDeactivateAndMask submits the deactivate + mask action.
func (h *Handlers) CustomerDeactivateAndMask(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	customerID := strings.TrimSpace(chi.URLParam(r, "customerID"))
	if customerID == "" {
		http.Error(w, "顧客IDが指定されていません。", http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	csrf := custommw.CSRFTokenFromContext(ctx)

	meta := customerstpl.DeactivateModalMeta{
		CustomerID:         customerID,
		CustomerName:       strings.TrimSpace(r.PostFormValue("customer_name")),
		Email:              strings.TrimSpace(r.PostFormValue("customer_email")),
		StatusLabel:        strings.TrimSpace(r.PostFormValue("status_label")),
		StatusTone:         strings.TrimSpace(r.PostFormValue("status_tone")),
		TotalOrdersLabel:   strings.TrimSpace(r.PostFormValue("total_orders_label")),
		LifetimeValueLabel: strings.TrimSpace(r.PostFormValue("lifetime_value_label")),
		LastOrderLabel:     strings.TrimSpace(r.PostFormValue("last_order_label")),
		ConfirmationPhrase: strings.TrimSpace(r.PostFormValue("expected_confirmation")),
		ActionURL:          strings.TrimSpace(r.PostFormValue("action_url")),
	}

	if strings.TrimSpace(meta.ActionURL) == "" {
		base := strings.TrimRight(strings.TrimSpace(basePath), "/")
		if base == "" {
			base = "/admin"
		}
		meta.ActionURL = fmt.Sprintf("%s/customers/%s:deactivate-and-mask", base, customerID)
	}

	reason := strings.TrimSpace(r.PostFormValue("reason"))
	confirmation := strings.TrimSpace(r.PostFormValue("confirmation"))

	form := customerstpl.DeactivateFormState{
		Reason:       reason,
		Confirmation: confirmation,
		FieldErrors:  make(map[string]string),
	}

	if rawImpacts := strings.TrimSpace(r.PostFormValue("impacts_json")); rawImpacts != "" {
		var impacts []customerstpl.DeactivateImpactItem
		if err := json.Unmarshal([]byte(rawImpacts), &impacts); err == nil && len(impacts) > 0 {
			meta.Impacts = impacts
		}
	}

	if reason == "" {
		form.FieldErrors["reason"] = "理由を入力してください。"
	}
	if confirmation == "" {
		form.FieldErrors["confirmation"] = "確認フレーズを入力してください。"
	} else if expected := strings.TrimSpace(meta.ConfirmationPhrase); expected != "" && confirmation != expected {
		form.FieldErrors["confirmation"] = "確認フレーズが一致しません。"
	}

	refreshMeta := func() (customerstpl.DeactivateModalMeta, error) {
		modal, err := h.customers.DeactivateModal(ctx, user.Token, customerID)
		if err != nil {
			return customerstpl.DeactivateModalMeta{}, err
		}
		return customerstpl.DeactivateModalMetaFromModal(basePath, modal), nil
	}

	if meta.CustomerName == "" || meta.TotalOrdersLabel == "" || meta.LifetimeValueLabel == "" || meta.StatusLabel == "" || meta.ConfirmationPhrase == "" {
		if refreshed, fetchErr := refreshMeta(); fetchErr == nil {
			meta = refreshed
		} else {
			switch {
			case errors.Is(fetchErr, admincustomers.ErrCustomerNotFound):
				http.NotFound(w, r)
			case errors.Is(fetchErr, admincustomers.ErrNotConfigured):
				http.Error(w, "顧客サービスが構成されていません。", http.StatusNotImplemented)
			default:
				log.Printf("customers: deactivate modal metadata fetch failed: %v", fetchErr)
				http.Error(w, "退会モーダルの読み込みに失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
			}
			return
		}
	}

	if len(form.FieldErrors) > 0 {
		payload := meta.ToData(csrf, form)
		templ.Handler(customerstpl.DeactivateModal(payload)).ServeHTTP(w, r)
		return
	}

	result, err := h.customers.DeactivateAndMask(ctx, user.Token, customerID, admincustomers.DeactivateAndMaskRequest{
		Reason:       reason,
		Confirmation: confirmation,
		ActorID:      strings.TrimSpace(user.UID),
		ActorEmail:   strings.TrimSpace(user.Email),
		RequestedAt:  time.Now().UTC(),
	})
	if err != nil {
		switch {
		case errors.Is(err, admincustomers.ErrInvalidConfirmation):
			form.FieldErrors["confirmation"] = "確認フレーズが一致しません。"
			if refreshed, refreshErr := refreshMeta(); refreshErr == nil {
				meta = refreshed
			}
		case errors.Is(err, admincustomers.ErrAlreadyDeactivated):
			form.Error = "すでに退会・マスク済みの顧客です。"
			form.DisableSubmit = true
			if refreshed, refreshErr := refreshMeta(); refreshErr == nil {
				meta = refreshed
			}
		case errors.Is(err, admincustomers.ErrCustomerNotFound):
			http.NotFound(w, r)
			return
		case errors.Is(err, admincustomers.ErrNotConfigured):
			http.Error(w, "顧客サービスが構成されていません。", http.StatusNotImplemented)
			return
		default:
			log.Printf("customers: deactivate mask failed: %v", err)
			http.Error(w, "退会処理に失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
			return
		}

		payload := meta.ToData(csrf, form)
		templ.Handler(customerstpl.DeactivateModal(payload)).ServeHTTP(w, r)
		return
	}

	displayName := strings.TrimSpace(meta.CustomerName)
	if displayName == "" {
		displayName = strings.TrimSpace(meta.CustomerID)
	}

	trigger := map[string]any{
		"toast": map[string]string{
			"message": fmt.Sprintf("%s を退会＋マスクしました。", displayName),
			"tone":    "success",
		},
		"refresh:fragment": map[string]any{
			"targets": []string{"[data-customer-detail]"},
		},
	}
	if encoded, marshalErr := json.Marshal(trigger); marshalErr == nil {
		w.Header().Set("HX-Trigger", string(encoded))
	}

	payload := customerstpl.DeactivateSuccessPayload(basePath, displayName, result)
	templ.Handler(customerstpl.DeactivateSuccess(payload)).ServeHTTP(w, r)
}

func buildCustomersRequest(r *http.Request) customersRequest {
	values := r.URL.Query()

	search := strings.TrimSpace(values.Get("q"))
	status := parseCustomerStatus(values.Get("status"))
	tier := strings.TrimSpace(values.Get("tier"))

	sortKey, sortDir, sortToken := parseCustomersSort(values.Get("sort"))

	page := parsePositiveIntDefault(values.Get("page"), 1)
	pageSize := parsePositiveIntDefault(values.Get("pageSize"), defaultCustomersPageSize)

	query := admincustomers.ListQuery{
		Search:        search,
		Status:        status,
		Tier:          tier,
		Page:          page,
		PageSize:      pageSize,
		SortKey:       sortKey,
		SortDirection: sortDir,
	}

	state := customerstpl.QueryState{
		Search:    search,
		Status:    string(status),
		Tier:      tier,
		Page:      page,
		PageSize:  pageSize,
		Sort:      sortToken,
		SortKey:   sortKey,
		SortDir:   string(sortDir),
		HasFilter: search != "" || string(status) != "" || tier != "",
	}

	state.RawQuery = customersRawQuery(state)

	return customersRequest{
		query: query,
		state: state,
	}
}

func parseCustomerStatus(raw string) admincustomers.Status {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case string(admincustomers.StatusActive):
		return admincustomers.StatusActive
	case string(admincustomers.StatusDeactivated):
		return admincustomers.StatusDeactivated
	case string(admincustomers.StatusInvited):
		return admincustomers.StatusInvited
	default:
		return ""
	}
}

func parseCustomersSort(raw string) (string, admincustomers.SortDirection, string) {
	value := strings.TrimSpace(raw)
	if value == "" {
		value = defaultCustomersSort
	}

	key := value
	direction := admincustomers.SortDirectionAsc

	if strings.HasPrefix(value, "-") {
		key = strings.TrimPrefix(value, "-")
		direction = admincustomers.SortDirectionDesc
	} else if strings.HasPrefix(value, "+") {
		key = strings.TrimPrefix(value, "+")
		direction = admincustomers.SortDirectionAsc
	}

	switch strings.TrimSpace(key) {
	case "last_order", "lifetime_value", "total_orders", "name":
		// valid
	default:
		key = "last_order"
		direction = admincustomers.SortDirectionDesc
		value = defaultCustomersSort
	}

	if direction == admincustomers.SortDirectionDesc {
		value = "-" + key
	} else {
		value = key
	}

	return key, direction, value
}

func customersRawQuery(state customerstpl.QueryState) string {
	values := url.Values{}
	if state.Search != "" {
		values.Set("q", state.Search)
	}
	if state.Status != "" {
		values.Set("status", state.Status)
	}
	if state.Tier != "" {
		values.Set("tier", state.Tier)
	}
	if sort := strings.TrimSpace(state.Sort); sort != "" && sort != defaultCustomersSort {
		values.Set("sort", sort)
	}
	if state.Page > 1 {
		values.Set("page", strconv.Itoa(state.Page))
	}
	if state.PageSize > 0 && state.PageSize != defaultCustomersPageSize {
		values.Set("pageSize", strconv.Itoa(state.PageSize))
	}
	return values.Encode()
}

func canonicalCustomersURL(basePath string, req customersRequest) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/admin"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	base = strings.TrimRight(base, "/")

	query := customersRawQuery(req.state)
	if query != "" {
		return base + "/customers?" + query
	}
	return base + "/customers"
}

func normalizeCustomerDetailTab(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "orders":
		return "orders"
	case "addresses":
		return "addresses"
	case "payments":
		return "payments"
	case "notes":
		return "notes"
	case "activity":
		return "activity"
	case "overview":
		fallthrough
	default:
		return "overview"
	}
}
