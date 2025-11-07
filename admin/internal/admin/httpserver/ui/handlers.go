package ui

import (
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/a-h/templ"

	adminassets "finitefield.org/hanko-admin/internal/admin/assets"
	adminaudit "finitefield.org/hanko-admin/internal/admin/auditlogs"
	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
	admincontent "finitefield.org/hanko-admin/internal/admin/content"
	admincustomers "finitefield.org/hanko-admin/internal/admin/customers"
	admindashboard "finitefield.org/hanko-admin/internal/admin/dashboard"
	adminfinance "finitefield.org/hanko-admin/internal/admin/finance"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminnotifications "finitefield.org/hanko-admin/internal/admin/notifications"
	adminorders "finitefield.org/hanko-admin/internal/admin/orders"
	adminorg "finitefield.org/hanko-admin/internal/admin/org"
	adminpayments "finitefield.org/hanko-admin/internal/admin/payments"
	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/profile"
	adminpromotions "finitefield.org/hanko-admin/internal/admin/promotions"
	adminreviews "finitefield.org/hanko-admin/internal/admin/reviews"
	adminsearch "finitefield.org/hanko-admin/internal/admin/search"
	adminshipments "finitefield.org/hanko-admin/internal/admin/shipments"
	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	dashboardtpl "finitefield.org/hanko-admin/internal/admin/templates/dashboard"
	profiletpl "finitefield.org/hanko-admin/internal/admin/templates/profile"
)

// Dependencies collects external services required by the UI handlers.
type Dependencies struct {
	AuditLogsService     adminaudit.Service
	AssetsService        adminassets.Service
	CatalogService       admincatalog.Service
	ContentService       admincontent.Service
	CustomersService     admincustomers.Service
	DashboardService     admindashboard.Service
	ProfileService       profile.Service
	SearchService        adminsearch.Service
	NotificationsService adminnotifications.Service
	FinanceService       adminfinance.Service
	PaymentsService      adminpayments.Service
	OrdersService        adminorders.Service
	ShipmentsService     adminshipments.Service
	ProductionService    adminproduction.Service
	PromotionsService    adminpromotions.Service
	ReviewsService       adminreviews.Service
	OrgService           adminorg.Service
	SystemService        adminsystem.Service
}

// Handlers exposes HTTP handlers for admin UI pages and fragments.
type Handlers struct {
	auditlogs     adminaudit.Service
	assets        adminassets.Service
	catalog       admincatalog.Service
	content       admincontent.Service
	customers     admincustomers.Service
	dashboard     admindashboard.Service
	profile       profile.Service
	search        adminsearch.Service
	notifications adminnotifications.Service
	payments      adminpayments.Service
	finance       adminfinance.Service
	orders        adminorders.Service
	shipments     adminshipments.Service
	production    adminproduction.Service
	promotions    adminpromotions.Service
	reviews       adminreviews.Service
	org           adminorg.Service
	system        adminsystem.Service
}

// NewHandlers wires the UI handler set.
func NewHandlers(deps Dependencies) *Handlers {
	auditLogsService := deps.AuditLogsService
	if auditLogsService == nil {
		auditLogsService = adminaudit.NewStaticService()
	}
	assetsService := deps.AssetsService
	if assetsService == nil {
		assetsService = adminassets.NewStaticService("https://uploads.example.com", "https://cdn.example.com/assets")
	}
	profileService := deps.ProfileService
	if profileService == nil {
		profileService = profile.NewStaticService(nil)
	}
	dashboardService := deps.DashboardService
	if dashboardService == nil {
		dashboardService = admindashboard.NewStaticService()
	}
	searchService := deps.SearchService
	if searchService == nil {
		searchService = adminsearch.NewStaticService()
	}
	notificationsService := deps.NotificationsService
	if notificationsService == nil {
		notificationsService = adminnotifications.NewStaticService()
	}
	financeService := deps.FinanceService
	if financeService == nil {
		financeService = adminfinance.NewStaticService()
	}
	ordersService := deps.OrdersService
	if ordersService == nil {
		ordersService = adminorders.NewStaticService()
	}
	paymentsService := deps.PaymentsService
	if paymentsService == nil {
		paymentsService = adminpayments.NewStaticService()
	}
	customersService := deps.CustomersService
	if customersService == nil {
		customersService = admincustomers.NewStaticService()
	}
	shipmentsService := deps.ShipmentsService
	if shipmentsService == nil {
		shipmentsService = adminshipments.NewStaticService()
	}
	productionService := deps.ProductionService
	if productionService == nil {
		productionService = adminproduction.NewStaticService()
	}
	promotionsService := deps.PromotionsService
	if promotionsService == nil {
		promotionsService = adminpromotions.NewStaticService()
	}
	reviewsService := deps.ReviewsService
	if reviewsService == nil {
		reviewsService = adminreviews.NewStaticService()
	}
	catalogService := deps.CatalogService
	if catalogService == nil {
		catalogService = admincatalog.NewStaticService()
	}
	contentService := deps.ContentService
	if contentService == nil {
		contentService = admincontent.NewStaticService()
	}
	orgService := deps.OrgService
	if orgService == nil {
		orgService = adminorg.NewStaticService()
	}
	systemService := deps.SystemService
	if systemService == nil {
		systemService = adminsystem.NewStaticService()
	}
	return &Handlers{
		auditlogs:     auditLogsService,
		assets:        assetsService,
		catalog:       catalogService,
		content:       contentService,
		customers:     customersService,
		dashboard:     dashboardService,
		profile:       profileService,
		search:        searchService,
		notifications: notificationsService,
		finance:       financeService,
		payments:      paymentsService,
		orders:        ordersService,
		shipments:     shipmentsService,
		production:    productionService,
		promotions:    promotionsService,
		reviews:       reviewsService,
		org:           orgService,
		system:        systemService,
	}
}

// Dashboard renders the admin dashboard.
func (h *Handlers) Dashboard(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	since := parseSince(r.URL.Query().Get("since"))

	kpis, err := h.dashboard.FetchKPIs(ctx, user.Token, since)
	kpiFragment := dashboardtpl.KPIFragmentPayload(kpis)
	if err != nil {
		log.Printf("dashboard: fetch kpis failed: %v", err)
		kpiFragment.Error = "KPIの取得に失敗しました。時間を置いて再度お試しください。"
	}

	alerts, err := h.dashboard.FetchAlerts(ctx, user.Token, 0)
	alertsFragment := dashboardtpl.AlertsFragmentPayload(alerts)
	if err != nil {
		log.Printf("dashboard: fetch alerts failed: %v", err)
		alertsFragment.Error = "アラートの取得に失敗しました。"
	}

	activity, err := h.dashboard.FetchActivity(ctx, user.Token, 0)
	if err != nil {
		log.Printf("dashboard: fetch activity failed: %v", err)
		activity = nil
	}

	data := dashboardtpl.BuildPageData(ctx, custommw.BasePathFromContext(ctx), kpis, alerts, activity)
	data.KPIFragment = kpiFragment
	data.AlertsFragment = alertsFragment

	templ.Handler(dashboardtpl.Index(data)).ServeHTTP(w, r)
}

// DashboardKPIs serves the KPI fragment for htmx requests.
func (h *Handlers) DashboardKPIs(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	since := parseSince(r.URL.Query().Get("since"))
	limit := parseLimit(r.URL.Query().Get("limit"), 0)

	kpis, err := h.dashboard.FetchKPIs(ctx, user.Token, since)
	if limit > 0 && len(kpis) > limit {
		kpis = kpis[:limit]
	}

	payload := dashboardtpl.KPIFragmentPayload(kpis)
	if err != nil {
		log.Printf("dashboard: fetch kpis failed: %v", err)
		payload.Error = "KPIの取得に失敗しました。時間を置いて再度お試しください。"
	}

	templ.Handler(dashboardtpl.KPIFragment(payload)).ServeHTTP(w, r)
}

// DashboardAlerts serves the alerts fragment for htmx requests.
func (h *Handlers) DashboardAlerts(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	limit := parseLimit(r.URL.Query().Get("limit"), 0)

	alerts, err := h.dashboard.FetchAlerts(ctx, user.Token, limit)
	payload := dashboardtpl.AlertsFragmentPayload(alerts)
	if err != nil {
		log.Printf("dashboard: fetch alerts failed: %v", err)
		payload.Error = "アラートの取得に失敗しました。"
	}

	templ.Handler(dashboardtpl.AlertsFragment(payload)).ServeHTTP(w, r)
}

func parseSince(raw string) *time.Time {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}

	if ts, err := time.Parse(time.RFC3339, raw); err == nil {
		return &ts
	}
	return nil
}

func parseLimit(raw string, fallback int) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < 0 {
		return fallback
	}
	return value
}

func (h *Handlers) renderProfilePage(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	state, err := h.profile.SecurityOverview(r.Context(), user.Token)
	if err != nil {
		log.Printf("profile: fetch security overview failed: %v", err)
		http.Error(w, "セキュリティ情報の取得に失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
		return
	}

	email := strings.TrimSpace(user.Email)
	if email == "" && state != nil {
		email = strings.TrimSpace(state.UserEmail)
	}

	displayName := strings.TrimSpace(user.UID)
	if state != nil && strings.TrimSpace(state.UserName) != "" {
		displayName = strings.TrimSpace(state.UserName)
	}

	roles := append([]string(nil), user.Roles...)
	lastLogin := profiletpl.MostRecentSessionAt(state)
	featureFlags := profiletpl.FeatureFlagsFromMap(user.FeatureFlags)
	activeTab := normalizeProfileTab(r.URL.Query().Get("tab"))

	payload := profiletpl.PageData{
		UserEmail:    email,
		UserName:     user.UID,
		DisplayName:  displayName,
		Roles:        roles,
		LastLogin:    lastLogin,
		Security:     state,
		FeatureFlags: featureFlags,
		ActiveTab:    activeTab,
		CSRFToken:    custommw.CSRFTokenFromContext(r.Context()),
	}

	if custommw.IsHTMXRequest(r.Context()) {
		target := strings.TrimSpace(custommw.HTMXInfoFromContext(r.Context()).Target)
		target = strings.TrimPrefix(target, "#")
		if strings.EqualFold(target, "profile-tabs") {
			templ.Handler(profiletpl.ProfileTabs(payload)).ServeHTTP(w, r)
			return
		}
	}

	component := profiletpl.Index(payload)
	templ.Handler(component).ServeHTTP(w, r)
}

func normalizeProfileTab(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "account":
		return "account"
	case "sessions":
		return "sessions"
	case "flags":
		return "flags"
	case "security":
		fallthrough
	default:
		return "security"
	}
}
