package ui

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminpayments "finitefield.org/hanko-admin/internal/admin/payments"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	paymentstpl "finitefield.org/hanko-admin/internal/admin/templates/payments"
	"finitefield.org/hanko-admin/internal/admin/webtmpl"
)

const (
	defaultPaymentsTransactionsPageSize = 25
)

type paymentsRequest struct {
	state paymentstpl.QueryState
	query adminpayments.TransactionsQuery
}

// PaymentsTransactionsPage renders the PSP transactions index page.
func (h *Handlers) PaymentsTransactionsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildPaymentsRequest(r)
	result, err := h.payments.ListTransactions(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("payments: list transactions failed: %v", err)
		errMsg = "決済トランザクションの取得に失敗しました。時間を置いて再実行してください。"
		result = adminpayments.TransactionsResult{}
	}

	selectedID := strings.TrimSpace(req.state.SelectedID)
	if selectedID == "" && len(result.Transactions) > 0 {
		selectedID = result.Transactions[0].ID
	}
	if selectedID != "" {
		req.state.RawQuery = helpers.SetRawQuery(req.state.RawQuery, "selected", selectedID)
	}
	req.state.SelectedID = selectedID

	basePath := custommw.BasePathFromContext(ctx)
	table := paymentstpl.TablePayload(basePath, req.state, result, errMsg)

	drawer := paymentstpl.DrawerData{Empty: true}
	if selectedID != "" {
		if detail, derr := h.payments.TransactionDetail(ctx, user.Token, selectedID); derr == nil {
			drawer = paymentstpl.DrawerPayload(basePath, detail)
		} else if errors.Is(derr, adminpayments.ErrTransactionNotFound) {
			drawer = paymentstpl.DrawerData{Empty: true}
		} else {
			log.Printf("payments: transaction detail %s failed: %v", selectedID, derr)
		}
	}

	toolbar := paymentsToolbar(0, result.Pagination.TotalItems)
	data := paymentstpl.BuildPageData(basePath, req.state, result, table, drawer, toolbar)
	crumbs := make([]webtmpl.Breadcrumb, 0, len(data.Breadcrumbs))
	for _, crumb := range data.Breadcrumbs {
		crumbs = append(crumbs, webtmpl.Breadcrumb{
			Label: crumb.Label,
			Href:  crumb.Href,
		})
	}
	base := webtmpl.BuildBaseView(ctx, data.Title, crumbs)
	base.ContentTemplate = "payments/content"
	tableView := toPaymentsTableView(table)
	view := webtmpl.PaymentsPageView{
		BaseView: base,
		Page:     data,
		Table:    tableView,
	}
	if err := dashboardTemplates.Render(w, "payments/index", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// PaymentsTransactionsTable renders the transactions table fragment.
func (h *Handlers) PaymentsTransactionsTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildPaymentsRequest(r)
	result, err := h.payments.ListTransactions(ctx, user.Token, req.query)
	errMsg := ""
	if err != nil {
		log.Printf("payments: list transactions fragment failed: %v", err)
		errMsg = "決済トランザクションの取得に失敗しました。"
		result = adminpayments.TransactionsResult{}
	}

	selectedID := strings.TrimSpace(req.state.SelectedID)
	if selectedID == "" && len(result.Transactions) > 0 {
		selectedID = result.Transactions[0].ID
	}
	if selectedID != "" {
		req.state.RawQuery = helpers.SetRawQuery(req.state.RawQuery, "selected", selectedID)
	} else {
		req.state.RawQuery = helpers.SetRawQuery(req.state.RawQuery, "selected", "")
	}
	req.state.SelectedID = selectedID

	basePath := custommw.BasePathFromContext(ctx)
	table := paymentstpl.TablePayload(basePath, req.state, result, errMsg)
	if canonical := canonicalPaymentsURL(basePath, req.state.RawQuery); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}
	view := toPaymentsTableView(table)
	if err := dashboardTemplates.Render(w, "payments/table", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// PaymentsTransactionsDrawer renders the transaction drawer fragment.
func (h *Handlers) PaymentsTransactionsDrawer(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	transactionID := strings.TrimSpace(r.URL.Query().Get("selected"))
	if transactionID == "" {
		transactionID = strings.TrimSpace(r.URL.Query().Get("transactionID"))
	}
	if transactionID == "" {
		http.Error(w, "selected is required", http.StatusBadRequest)
		return
	}

	detail, err := h.payments.TransactionDetail(ctx, user.Token, transactionID)
	if err != nil {
		if errors.Is(err, adminpayments.ErrTransactionNotFound) {
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		log.Printf("payments: transaction detail %s failed: %v", transactionID, err)
		http.Error(w, "決済詳細の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	payload := paymentstpl.DrawerPayload(basePath, detail)
	if err := dashboardTemplates.Render(w, "payments/drawer", payload); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

func buildPaymentsRequest(r *http.Request) paymentsRequest {
	raw := r.URL.Query()
	state := paymentstpl.BuildQueryState(raw)
	if state.PageSize <= 0 {
		state.PageSize = defaultPaymentsTransactionsPageSize
	}
	if state.Page < 0 {
		state.Page = 0
	}
	query := paymentstpl.ParseListQuery(state)
	query.Page = state.Page
	query.PageSize = state.PageSize
	return paymentsRequest{
		state: state,
		query: query,
	}
}

func canonicalPaymentsURL(basePath string, rawQuery string) string {
	base := joinBasePath(basePath, "/payments/transactions")
	raw := strings.TrimSpace(rawQuery)
	if raw == "" {
		return base
	}
	return base + "?" + raw
}

func paymentsToolbar(selected, total int) components.BulkToolbarProps {
	disabled := selected == 0
	return components.BulkToolbarProps{
		SelectedCount:   selected,
		TotalCount:      total,
		Message:         "選択した決済に対してアクションを実行できます。",
		RenderWhenEmpty: true,
		Actions: []components.BulkToolbarAction{
			{
				Label: "売上確定",
				Options: components.ButtonOptions{
					Variant:  "primary",
					Size:     "sm",
					Disabled: disabled,
					Attrs: map[string]string{
						"type":        "button",
						"data-action": "capture",
					},
				},
			},
			{
				Label: "返金処理",
				Options: components.ButtonOptions{
					Variant:  "secondary",
					Size:     "sm",
					Disabled: disabled,
					Attrs: map[string]string{
						"type":        "button",
						"data-action": "refund",
					},
				},
			},
			{
				Label: "領収書再送",
				Options: components.ButtonOptions{
					Variant:  "ghost",
					Size:     "sm",
					Disabled: disabled,
					Attrs: map[string]string{
						"type":        "button",
						"data-action": "resend-receipt",
					},
				},
			},
		},
	}
}

func toPaymentsTableView(table paymentstpl.TableData) webtmpl.PaymentsTableView {
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
		Attrs:         attrs,
		Label:         table.Pagination.Label,
	}
	return webtmpl.PaymentsTableView{
		Table:      table,
		Pagination: props,
	}
}
