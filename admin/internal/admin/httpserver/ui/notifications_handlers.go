package ui

import (
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminnotifications "finitefield.org/hanko-admin/internal/admin/notifications"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	notificationstpl "finitefield.org/hanko-admin/internal/admin/templates/notifications"
	"finitefield.org/hanko-admin/internal/admin/webtmpl"
)

// NotificationsPage renders the notifications index page.
func (h *Handlers) NotificationsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	params := buildNotificationsRequest(r)

	feed, err := h.notifications.List(ctx, user.Token, params.query)
	errMsg := ""
	if err != nil {
		log.Printf("notifications: list failed: %v", err)
		errMsg = "通知の取得に失敗しました。時間を置いて再度お試しください。"
		feed = adminnotifications.Feed{}
	}

	table := notificationstpl.TablePayload(params.state, feed, errMsg, params.selectedID)
	drawer := notificationstpl.DrawerPayload(feed, table.SelectedID)
	payload := notificationstpl.BuildPageData(custommw.BasePathFromContext(ctx), params.state, table, drawer)
	crumbs := make([]webtmpl.Breadcrumb, 0, len(payload.Breadcrumbs))
	for _, crumb := range payload.Breadcrumbs {
		crumbs = append(crumbs, webtmpl.Breadcrumb{Label: crumb.Label, Href: crumb.Href})
	}
	base := webtmpl.BuildBaseView(ctx, payload.Title, crumbs)
	base.ContentTemplate = "notifications/content"
	view := webtmpl.NotificationsPageView{
		BaseView:      base,
		Title:         payload.Title,
		Description:   payload.Description,
		Legend:        payload.Legend,
		Filters:       payload.Filters,
		Query:         payload.Query,
		TableEndpoint: payload.TableEndpoint,
		Table:         toNotificationsTableView(table),
		Drawer:        toNotificationsDrawerView(drawer),
	}
	if err := dashboardTemplates.Render(w, "notifications/index", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// NotificationsTable renders the table fragment for htmx updates.
func (h *Handlers) NotificationsTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	params := buildNotificationsRequest(r)

	feed, err := h.notifications.List(ctx, user.Token, params.query)
	errMsg := ""
	if err != nil {
		log.Printf("notifications: list failed: %v", err)
		errMsg = "通知の取得に失敗しました。時間を置いて再度お試しください。"
		feed = adminnotifications.Feed{}
	}

	table := notificationstpl.TablePayload(params.state, feed, errMsg, params.selectedID)
	params.selectedID = table.SelectedID

	if canonical := canonicalNotificationsURL(custommw.BasePathFromContext(ctx), params); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	view := toNotificationsTableView(table)
	if err := dashboardTemplates.Render(w, "notifications/table", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// NotificationsBadge renders the top-bar badge fragment.
func (h *Handlers) NotificationsBadge(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	count, err := h.notifications.Badge(ctx, user.Token)
	if err != nil {
		log.Printf("notifications: badge failed: %v", err)
		count = adminnotifications.BadgeCount{}
	}

	payload := notificationstpl.BadgePayload(custommw.BasePathFromContext(ctx), count)
	view := webtmpl.NotificationsBadgeView{
		Total:          payload.Total,
		Critical:       payload.Critical,
		Warning:        payload.Warning,
		ReviewsPending: payload.ReviewsPending,
		TasksPending:   payload.TasksPending,
		Endpoint:       payload.Endpoint,
		StreamEndpoint: payload.StreamEndpoint,
		Href:           payload.Href,
	}
	if err := dashboardTemplates.Render(w, "notifications/badge", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

type notificationsRequest struct {
	query      adminnotifications.Query
	state      notificationstpl.QueryState
	selectedID string
}

func toNotificationsTableView(table notificationstpl.TableData) webtmpl.NotificationsTableView {
	rows := make([]webtmpl.NotificationRowView, 0, len(table.Items))
	for _, row := range table.Items {
		attrs := map[string]string{}
		for key, val := range row.Attributes {
			attrs[key] = fmt.Sprint(val)
		}
		rows = append(rows, webtmpl.NotificationRowView{
			ID:                row.ID,
			CategoryLabel:     row.CategoryLabel,
			CategoryTone:      row.CategoryTone,
			CategoryIcon:      row.CategoryIcon,
			SeverityLabel:     row.SeverityLabel,
			SeverityTone:      row.SeverityTone,
			Title:             row.Title,
			Summary:           row.Summary,
			StatusLabel:       row.StatusLabel,
			StatusTone:        row.StatusTone,
			ResourceLabel:     row.ResourceLabel,
			ResourceURL:       row.ResourceURL,
			ResourceKind:      row.ResourceKind,
			Owner:             row.Owner,
			CreatedAtRelative: row.CreatedAtRelative,
			CreatedAtTooltip:  row.CreatedAtTooltip,
			Actions:           row.Actions,
			Attributes:        attrs,
		})
	}
	return webtmpl.NotificationsTableView{
		Total:        table.Total,
		NextCursor:   table.NextCursor,
		Error:        table.Error,
		EmptyMessage: table.EmptyMessage,
		SelectedID:   table.SelectedID,
		Items:        rows,
	}
}

func toNotificationsDrawerView(drawer notificationstpl.DrawerData) webtmpl.NotificationsDrawerView {
	tooltip := ""
	if !drawer.CreatedAt.IsZero() {
		tooltip = helpers.Date(drawer.CreatedAt, "2006-01-02 15:04")
	}
	return webtmpl.NotificationsDrawerView{
		Empty:             drawer.Empty,
		ID:                drawer.ID,
		Title:             drawer.Title,
		Summary:           drawer.Summary,
		CategoryLabel:     drawer.CategoryLabel,
		CategoryTone:      drawer.CategoryTone,
		SeverityLabel:     drawer.SeverityLabel,
		SeverityTone:      drawer.SeverityTone,
		StatusLabel:       drawer.StatusLabel,
		StatusTone:        drawer.StatusTone,
		Owner:             drawer.Owner,
		Resource:          drawer.Resource,
		CreatedRelative:   drawer.CreatedRelative,
		CreatedTooltip:    tooltip,
		AcknowledgedLabel: drawer.AcknowledgedLabel,
		ResolvedLabel:     drawer.ResolvedLabel,
		Metadata:          drawer.Metadata,
		Timeline:          drawer.Timeline,
		Links:             drawer.Links,
	}
}

func buildNotificationsRequest(r *http.Request) notificationsRequest {
	values := r.URL.Query()
	rawCategory := strings.TrimSpace(values.Get("category"))
	rawSeverity := strings.TrimSpace(values.Get("severity"))
	rawStatus := strings.TrimSpace(values.Get("status"))
	rawSearch := strings.TrimSpace(values.Get("q"))
	rawStart := strings.TrimSpace(values.Get("start"))
	rawEnd := strings.TrimSpace(values.Get("end"))
	rawSelected := strings.TrimSpace(values.Get("selected"))
	rawLimit := strings.TrimSpace(values.Get("limit"))

	category := normaliseCategory(rawCategory)
	severity := normaliseSeverity(rawSeverity)
	status := normaliseStatus(rawStatus)

	var startPtr *time.Time
	if ts := parseDate(rawStart); !ts.IsZero() {
		startPtr = &ts
	}
	var endPtr *time.Time
	if ts := parseDate(rawEnd); !ts.IsZero() {
		if startPtr != nil && ts.Before(*startPtr) {
			adjusted := startPtr.Add(24 * time.Hour)
			endPtr = &adjusted
		} else {
			endPtr = &ts
		}
	}

	limit := 0
	if rawLimit != "" {
		if parsed, err := parsePositiveInt(rawLimit); err == nil {
			limit = parsed
		}
	}

	state := notificationstpl.QueryState{
		Category:  category,
		Severity:  severity,
		Status:    status,
		Search:    rawSearch,
		StartDate: normalizeDateInput(rawStart),
		EndDate:   normalizeDateInput(rawEnd),
	}

	query := adminnotifications.Query{
		Search: rawSearch,
		Start:  startPtr,
		End:    endPtr,
		Limit:  limit,
	}
	if category != "" {
		query.Categories = []adminnotifications.Category{adminnotifications.Category(category)}
	}
	if severity != "" {
		query.Severities = []adminnotifications.Severity{adminnotifications.Severity(severity)}
	}
	if status != "" {
		query.Statuses = []adminnotifications.Status{adminnotifications.Status(status)}
	}

	return notificationsRequest{
		query:      query,
		state:      state,
		selectedID: rawSelected,
	}
}

func canonicalNotificationsURL(basePath string, req notificationsRequest) string {
	basePath = strings.TrimSpace(basePath)
	if basePath == "" {
		basePath = "/admin"
	}
	values := url.Values{}
	if req.state.Category != "" {
		values.Set("category", req.state.Category)
	}
	if req.state.Severity != "" {
		values.Set("severity", req.state.Severity)
	}
	if req.state.Status != "" {
		values.Set("status", req.state.Status)
	}
	if req.state.Search != "" {
		values.Set("q", req.state.Search)
	}
	if req.state.StartDate != "" {
		values.Set("start", req.state.StartDate)
	}
	if req.state.EndDate != "" {
		values.Set("end", req.state.EndDate)
	}
	if strings.TrimSpace(req.selectedID) != "" {
		values.Set("selected", strings.TrimSpace(req.selectedID))
	}
	if len(values) == 0 {
		return joinRoute(basePath, "/notifications")
	}
	return joinRoute(basePath, "/notifications") + "?" + values.Encode()
}

func joinRoute(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" {
		base = "/admin"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	if len(base) > 1 && strings.HasSuffix(base, "/") {
		base = strings.TrimRight(base, "/")
	}

	raw := strings.TrimSpace(suffix)
	if raw == "" {
		return base
	}
	if !strings.HasPrefix(raw, "/") {
		raw = "/" + raw
	}
	if base == "/" {
		return raw
	}
	return base + raw
}

func normaliseCategory(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminnotifications.CategoryFailedJob):
		return string(adminnotifications.CategoryFailedJob)
	case string(adminnotifications.CategoryStockAlert):
		return string(adminnotifications.CategoryStockAlert)
	case string(adminnotifications.CategoryShippingException):
		return string(adminnotifications.CategoryShippingException)
	default:
		return ""
	}
}

func normaliseSeverity(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminnotifications.SeverityCritical):
		return string(adminnotifications.SeverityCritical)
	case string(adminnotifications.SeverityHigh):
		return string(adminnotifications.SeverityHigh)
	case string(adminnotifications.SeverityMedium):
		return string(adminnotifications.SeverityMedium)
	case string(adminnotifications.SeverityLow):
		return string(adminnotifications.SeverityLow)
	default:
		return ""
	}
}

func normaliseStatus(value string) string {
	switch strings.TrimSpace(value) {
	case string(adminnotifications.StatusOpen):
		return string(adminnotifications.StatusOpen)
	case string(adminnotifications.StatusAcknowledged):
		return string(adminnotifications.StatusAcknowledged)
	case string(adminnotifications.StatusResolved):
		return string(adminnotifications.StatusResolved)
	case string(adminnotifications.StatusSuppressed):
		return string(adminnotifications.StatusSuppressed)
	default:
		return ""
	}
}

func parsePositiveInt(value string) (int, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, err
	}
	if parsed < 0 {
		parsed = 0
	}
	return parsed, nil
}
