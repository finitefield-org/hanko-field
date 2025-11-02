package ui

import (
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/a-h/templ"

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
