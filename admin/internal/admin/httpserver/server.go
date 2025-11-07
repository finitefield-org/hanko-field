package httpserver

import (
	"crypto/rand"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"

	adminassets "finitefield.org/hanko-admin/internal/admin/assets"
	adminaudit "finitefield.org/hanko-admin/internal/admin/auditlogs"
	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
	admincontent "finitefield.org/hanko-admin/internal/admin/content"
	admincustomers "finitefield.org/hanko-admin/internal/admin/customers"
	"finitefield.org/hanko-admin/internal/admin/dashboard"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/httpserver/ui"
	"finitefield.org/hanko-admin/internal/admin/i18n"
	adminnotifications "finitefield.org/hanko-admin/internal/admin/notifications"
	adminorders "finitefield.org/hanko-admin/internal/admin/orders"
	adminorg "finitefield.org/hanko-admin/internal/admin/org"
	adminpayments "finitefield.org/hanko-admin/internal/admin/payments"
	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/profile"
	"finitefield.org/hanko-admin/internal/admin/rbac"
	adminreviews "finitefield.org/hanko-admin/internal/admin/reviews"
	"finitefield.org/hanko-admin/internal/admin/search"
	appsession "finitefield.org/hanko-admin/internal/admin/session"
	adminshipments "finitefield.org/hanko-admin/internal/admin/shipments"
	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	"finitefield.org/hanko-admin/public"
)

// Config holds runtime options for the admin HTTP server.
type Config struct {
	Address              string
	BasePath             string
	LoginPath            string
	DefaultLocale        string
	SupportedLocales     []string
	Authenticator        custommw.Authenticator
	AuditLogsService     adminaudit.Service
	AssetsService        adminassets.Service
	CatalogService       admincatalog.Service
	ContentService       admincontent.Service
	CustomersService     admincustomers.Service
	DashboardService     dashboard.Service
	ProfileService       profile.Service
	SearchService        search.Service
	NotificationsService adminnotifications.Service
	PaymentsService      adminpayments.Service
	OrdersService        adminorders.Service
	ShipmentsService     adminshipments.Service
	ProductionService    adminproduction.Service
	ReviewsService       adminreviews.Service
	OrgService           adminorg.Service
	SystemService        adminsystem.Service
	Session              SessionConfig
	SessionStore         custommw.SessionStore
	CSRFCookieName       string
	CSRFCookiePath       string
	CSRFCookieSecure     bool
	CSRFHeaderName       string
	Environment          string
}

// SessionConfig represents optional overrides for the admin session manager.
type SessionConfig struct {
	CookieName       string
	CookiePath       string
	CookieDomain     string
	CookieSecure     bool
	CookieHTTPOnly   *bool
	CookieSameSite   http.SameSite
	IdleTimeout      time.Duration
	Lifetime         time.Duration
	RememberLifetime time.Duration
	HashKey          []byte
	BlockKey         []byte
}

// New constructs the HTTP server with middleware stack and embedded assets.
func New(cfg Config) *http.Server {
	router := chi.NewRouter()
	router.Use(chimw.RequestID)
	router.Use(chimw.RealIP)
	router.Use(chimw.Logger)
	router.Use(chimw.Recoverer)
	router.Use(chimw.Timeout(60 * time.Second))

	staticContent, err := public.StaticFS()
	if err != nil {
		log.Fatalf("embed static: %v", err)
	}
	router.Handle("/public/static/*", http.StripPrefix("/public/static/", http.FileServer(http.FS(staticContent))))

	basePath := normalizeBasePath(cfg.BasePath)
	loginPath := resolveLoginPath(basePath, cfg.LoginPath)

	authenticator := cfg.Authenticator
	if authenticator == nil {
		log.Fatalf("admin: authenticator is required; refusing to start without configured authenticator")
	}

	sessionStore := cfg.SessionStore
	if sessionStore == nil {
		sessionStore = mustBuildSessionStore(cfg.Session, basePath)
	}

	environment := strings.TrimSpace(cfg.Environment)

	csrfCfg := custommw.CSRFConfig{
		CookieName: cfg.CSRFCookieName,
		CookiePath: firstNonEmpty(cfg.CSRFCookiePath, basePath),
		HeaderName: cfg.CSRFHeaderName,
		Secure:     cfg.CSRFCookieSecure,
	}

	uiHandlers := ui.NewHandlers(ui.Dependencies{
		AuditLogsService:     cfg.AuditLogsService,
		AssetsService:        cfg.AssetsService,
		CatalogService:       cfg.CatalogService,
		ContentService:       cfg.ContentService,
		CustomersService:     cfg.CustomersService,
		DashboardService:     cfg.DashboardService,
		ProfileService:       cfg.ProfileService,
		SearchService:        cfg.SearchService,
		NotificationsService: cfg.NotificationsService,
		PaymentsService:      cfg.PaymentsService,
		OrdersService:        cfg.OrdersService,
		ShipmentsService:     cfg.ShipmentsService,
		ProductionService:    cfg.ProductionService,
		ReviewsService:       cfg.ReviewsService,
		OrgService:           cfg.OrgService,
		SystemService:        cfg.SystemService,
	})

	catalog := i18n.Default()

	normalizeLocale := func(locale string) string {
		return catalog.Canonicalize(locale)
	}

	seenLocales := make(map[string]struct{})
	addLocale := func(list *[]string, locale string) {
		trimmed := strings.TrimSpace(locale)
		if trimmed == "" {
			return
		}
		canonical := normalizeLocale(trimmed)
		if _, exists := seenLocales[canonical]; exists {
			return
		}
		seenLocales[canonical] = struct{}{}
		*list = append(*list, canonical)
	}

	var supportedLocales []string
	for _, locale := range cfg.SupportedLocales {
		addLocale(&supportedLocales, locale)
	}

	defaultLocale := strings.TrimSpace(cfg.DefaultLocale)
	if defaultLocale != "" {
		defaultLocale = normalizeLocale(defaultLocale)
	}

	if len(supportedLocales) == 0 {
		if defaultLocale != "" {
			addLocale(&supportedLocales, defaultLocale)
		} else {
			for _, locale := range catalog.SupportedLocales() {
				addLocale(&supportedLocales, locale)
			}
		}
	}

	if len(supportedLocales) == 0 {
		defaultLocale = normalizeLocale("ja-JP")
		addLocale(&supportedLocales, defaultLocale)
	}

	if defaultLocale == "" {
		defaultLocale = supportedLocales[0]
	}

	if _, ok := seenLocales[defaultLocale]; !ok {
		supportedLocales = append([]string{defaultLocale}, supportedLocales...)
		seenLocales[defaultLocale] = struct{}{}
	} else if supportedLocales[0] != defaultLocale {
		for i, locale := range supportedLocales {
			if locale == defaultLocale {
				supportedLocales = append([]string{defaultLocale}, append(append([]string(nil), supportedLocales[:i]...), supportedLocales[i+1:]...)...)
				break
			}
		}
	}

	mountAdminRoutes(router, basePath, routeOptions{
		SessionStore:  sessionStore,
		Authenticator: authenticator,
		LoginPath:     loginPath,
		CSRF:          csrfCfg,
		UI:            uiHandlers,
		Environment:   environment,
		Locale: custommw.LocaleConfig{
			Default:   defaultLocale,
			Supported: supportedLocales,
		},
	})

	return &http.Server{
		Addr:         cfg.Address,
		Handler:      router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
}

type routeOptions struct {
	SessionStore  custommw.SessionStore
	Authenticator custommw.Authenticator
	LoginPath     string
	CSRF          custommw.CSRFConfig
	UI            *ui.Handlers
	Environment   string
	Locale        custommw.LocaleConfig
}

func mountAdminRoutes(router chi.Router, base string, opts routeOptions) {
	authHandlers := newAuthHandlers(opts.Authenticator, base, opts.LoginPath)

	var shared []func(http.Handler) http.Handler
	if opts.SessionStore != nil {
		shared = append(shared, custommw.Session(opts.SessionStore))
	}
	shared = append(shared,
		custommw.RequestInfoMiddleware(base),
		custommw.HTMX(),
		custommw.NoStore(),
		custommw.Environment(opts.Environment),
		custommw.Locale(opts.Locale),
	)

	loginChain := router.With(shared...)
	loginChain = loginChain.With(custommw.CSRF(opts.CSRF))
	loginChain.Get(authHandlers.loginPath, authHandlers.LoginForm)
	loginChain.Post(authHandlers.loginPath, authHandlers.LoginSubmit)

	uiHandlers := opts.UI
	if uiHandlers == nil {
		uiHandlers = ui.NewHandlers(ui.Dependencies{})
	}

	router.Route(base, func(r chi.Router) {
		for _, mw := range shared {
			r.Use(mw)
		}

		r.Group(func(protected chi.Router) {
			protected.Use(custommw.Auth(opts.Authenticator, opts.LoginPath))
			protected.Use(custommw.CSRF(opts.CSRF))

			protected.Get("/", uiHandlers.Dashboard)
			protected.Get("/fragments/kpi", uiHandlers.DashboardKPIs)
			protected.Get("/fragments/alerts", uiHandlers.DashboardAlerts)
			protected.Post("/preferences/locale", uiHandlers.UpdateLocalePreference)
			protected.Route("/profile", func(pr chi.Router) {
				pr.Get("/", uiHandlers.ProfilePage)
				pr.Get("/mfa/totp", uiHandlers.MFATOTPStart)
				pr.Post("/mfa/totp", uiHandlers.MFATOTPConfirm)
				pr.Post("/mfa/email", uiHandlers.EmailMFAEnable)
				pr.Post("/mfa/disable", uiHandlers.DisableMFA)
				pr.Get("/api-keys/new", uiHandlers.NewAPIKeyForm)
				pr.Post("/api-keys", uiHandlers.CreateAPIKey)
				pr.Post("/api-keys/{keyID}/revoke", uiHandlers.RevokeAPIKey)
				pr.Post("/sessions/{sessionID}/revoke", uiHandlers.RevokeSession)
			})
			protected.Post("/assets/signed-upload", uiHandlers.AssetsSignedUpload)
			protected.Get("/logout", authHandlers.Logout)
			protected.Post("/logout", authHandlers.Logout)
			protected.Route("/search", func(sr chi.Router) {
				sr.Get("/", uiHandlers.SearchPage)
				sr.Get("/table", uiHandlers.SearchTable)
			})
			protected.Route("/notifications", func(nr chi.Router) {
				nr.Get("/", uiHandlers.NotificationsPage)
				nr.Get("/table", uiHandlers.NotificationsTable)
				nr.Get("/badge", uiHandlers.NotificationsBadge)
				nr.Get("/stream", uiHandlers.NotificationsStream)
			})
			protected.Route("/orders", func(or chi.Router) {
				or.Get("/", uiHandlers.OrdersPage)
				or.Get("/table", uiHandlers.OrdersTable)
				or.Post("/bulk/status", uiHandlers.OrdersBulkStatus)
				or.Post("/bulk/labels", uiHandlers.OrdersBulkLabels)
				or.Post("/bulk/export", uiHandlers.OrdersBulkExport)
				or.Get("/bulk/export/jobs/{jobID}", uiHandlers.OrdersBulkExportJobStatus)
				or.Get("/{orderID}/modal/status", uiHandlers.OrdersStatusModal)
				or.Put("/{orderID}:status", uiHandlers.OrdersStatusUpdate)
				or.Get("/{orderID}/modal/manual-capture", uiHandlers.OrdersManualCaptureModal)
				or.Post("/{orderID}/payments:manual-capture", uiHandlers.OrdersSubmitManualCapture)
				or.Get("/{orderID}/modal/refund", uiHandlers.OrdersRefundModal)
				or.Post("/{orderID}/payments:refund", uiHandlers.OrdersSubmitRefund)
				or.Get("/{orderID}/modal/invoice", uiHandlers.OrdersInvoiceModal)
				or.Post("/{orderID}/shipments", uiHandlers.ShipmentsCreateOrderShipment)
				or.Post("/{orderID}/production-events", uiHandlers.OrdersProductionEvent)
			})
			protected.Route("/customers", func(cr chi.Router) {
				cr.Get("/", uiHandlers.CustomersPage)
				cr.Get("/{customerID}", uiHandlers.CustomerDetailPage)
				RegisterFragment(cr, "/table", uiHandlers.CustomersTable)
				RegisterFragment(cr, "/{customerID}/modal/deactivate-mask", uiHandlers.CustomerDeactivateModal)
				cr.Post("/{customerID}:deactivate-and-mask", uiHandlers.CustomerDeactivateAndMask)
			})
			protected.Route("/shipments", func(sr chi.Router) {
				sr.Get("/tracking", uiHandlers.ShipmentsTrackingPage)
				sr.Get("/tracking/table", uiHandlers.ShipmentsTrackingTable)
				sr.Get("/batches", uiHandlers.ShipmentsBatchesPage)
				sr.Get("/batches/table", uiHandlers.ShipmentsBatchesTable)
				sr.Get("/batches/{batchID}/drawer", uiHandlers.ShipmentsBatchDrawer)
				sr.Post("/batches", uiHandlers.ShipmentsCreateBatch)
				sr.Post("/batches/regenerate", uiHandlers.ShipmentsRegenerateLabels)
			})
			protected.Route("/production-queues", func(pqr chi.Router) {
				pqr.Get("/", uiHandlers.ProductionQueueSettingsPage)
				RegisterFragment(pqr, "/table", uiHandlers.ProductionQueueSettingsTable)
				RegisterFragment(pqr, "/{queueID}/drawer", uiHandlers.ProductionQueueSettingsDrawer)
				RegisterFragment(pqr, "/modal/new", uiHandlers.ProductionQueueNewModal)
				RegisterFragment(pqr, "/{queueID}/modal/edit", uiHandlers.ProductionQueueEditModal)
				RegisterFragment(pqr, "/{queueID}/modal/delete", uiHandlers.ProductionQueueDeleteModal)
				pqr.Post("/", uiHandlers.ProductionQueueCreate)
				pqr.Put("/{queueID}", uiHandlers.ProductionQueueUpdate)
				pqr.Delete("/{queueID}", uiHandlers.ProductionQueueDelete)
				pqr.Post("/{queueID}/toggle", uiHandlers.ProductionQueueToggle)
			})
			protected.Route("/production", func(pr chi.Router) {
				pr.Get("/queues/summary", uiHandlers.ProductionQueuesSummaryPage)
				pr.Get("/queues", uiHandlers.ProductionQueuesPage)
				RegisterFragment(pr, "/queues/board", uiHandlers.ProductionQueuesBoard)
				pr.Get("/workorders/{orderID}", uiHandlers.ProductionWorkOrderPage)
				pr.Get("/qc", uiHandlers.ProductionQCPage)
				RegisterFragment(pr, "/qc/orders/{orderID}/drawer", uiHandlers.ProductionQCDrawer)
				pr.Post("/qc/orders/{orderID}/decision", uiHandlers.ProductionQCDecision)
				RegisterFragment(pr, "/qc/orders/{orderID}/modal/rework", uiHandlers.ProductionQCReworkModal)
				pr.Post("/qc/orders/{orderID}/rework", uiHandlers.ProductionQCSubmitRework)
			})
			protected.Route("/catalog", func(cr chi.Router) {
				cr.Get("/", uiHandlers.CatalogRootRedirect)
				cr.Get("/{kind}", uiHandlers.CatalogPage)
				RegisterFragment(cr, "/{kind}/table", uiHandlers.CatalogTable)
				RegisterFragment(cr, "/{kind}/cards", uiHandlers.CatalogCards)
				RegisterFragment(cr, "/{kind}/modal/new", uiHandlers.CatalogNewModal)
				RegisterFragment(cr, "/{kind}/{itemID}/modal/edit", uiHandlers.CatalogEditModal)
				RegisterFragment(cr, "/{kind}/{itemID}/modal/delete", uiHandlers.CatalogDeleteModal)
				cr.Post("/{kind}", uiHandlers.CatalogCreate)
				cr.Put("/{kind}/{itemID}", uiHandlers.CatalogUpdate)
				cr.Delete("/{kind}/{itemID}", uiHandlers.CatalogDelete)
				cr.Post("/{kind}/{itemID}/schedule/cancel", uiHandlers.CatalogCancelSchedule)
			})
			protected.Route("/content", func(cr chi.Router) {
				cr.Get("/guides", uiHandlers.GuidesPage)
				cr.Get("/guides/{guideID}/preview", uiHandlers.GuidesPreview)
				cr.Get("/guides/{guideID}/edit", uiHandlers.GuidesEdit)
				cr.With(custommw.RequireHTMX()).Post("/guides/{guideID}/edit/preview", uiHandlers.GuidesEditPreview)
				RegisterFragment(cr, "/guides/{guideID}/history", uiHandlers.GuidesHistory)
				RegisterFragment(cr, "/guides/table", uiHandlers.GuidesTable)
				cr.Post("/guides/{guideID}:publish", uiHandlers.GuidesPublish)
				cr.Post("/guides/{guideID}:unpublish", uiHandlers.GuidesUnpublish)
				cr.Post("/guides/{guideID}:schedule", uiHandlers.GuidesSchedule)
				cr.Post("/guides/{guideID}:unschedule", uiHandlers.GuidesUnschedule)
				cr.Post("/guides/{guideID}/history/{historyID}:revert", uiHandlers.GuidesRevert)
				cr.Post("/guides/bulk:publish", uiHandlers.GuidesBulkPublish)
				cr.Post("/guides/bulk:unschedule", uiHandlers.GuidesBulkUnschedule)
				cr.Post("/guides/bulk:archive", uiHandlers.GuidesBulkArchive)
				cr.Get("/pages", uiHandlers.PagesPage)
				cr.Get("/pages/{pageID}/preview", uiHandlers.PagesPreview)
				cr.With(custommw.RequireHTMX()).Post("/pages/{pageID}/edit/preview", uiHandlers.PagesEditPreview)
				cr.Post("/pages/{pageID}:save", uiHandlers.PagesSaveDraft)
				cr.Post("/pages/{pageID}:publish", uiHandlers.PagesPublish)
				cr.Post("/pages/{pageID}:unpublish", uiHandlers.PagesUnpublish)
				cr.Post("/pages/{pageID}:schedule", uiHandlers.PagesSchedule)
				cr.Post("/pages/{pageID}:unschedule", uiHandlers.PagesUnschedule)
				cr.With(custommw.RequireHTMX()).Get("/pages/{pageID}/history", uiHandlers.PagesHistoryModal)
			})
			protected.Route("/promotions", func(pr chi.Router) {
				pr.Get("/", uiHandlers.PromotionsPage)
				RegisterFragment(pr, "/table", uiHandlers.PromotionsTable)
				RegisterFragment(pr, "/drawer", uiHandlers.PromotionsDrawer)
				RegisterFragment(pr, "/modal/new", uiHandlers.PromotionsNewModal)
				RegisterFragment(pr, "/modal/edit", uiHandlers.PromotionsEditModal)
				RegisterFragment(pr, "/modal/validate", uiHandlers.PromotionsValidateModal)
				pr.Post("/", uiHandlers.PromotionsCreate)
				pr.Put("/{promotionID}", uiHandlers.PromotionsUpdate)
				pr.Post("/bulk/status", uiHandlers.PromotionsBulkStatus)
				pr.Post("/modal/validate", uiHandlers.PromotionsValidateSubmit)
				pr.Route("/{promotionID}/usages", func(ur chi.Router) {
					ur.Use(custommw.RequireCapability(rbac.CapPromotionsUsage))
					ur.Get("/", uiHandlers.PromotionsUsagePage)
					RegisterFragment(ur, "/table", uiHandlers.PromotionsUsageTable)
					RegisterFragment(ur, "/export/jobs/{jobID}", uiHandlers.PromotionsUsageExportJobStatus)
					ur.Post("/export", uiHandlers.PromotionsUsageExport)
				})
			})
			protected.Route("/payments", func(pr chi.Router) {
				pr.Use(custommw.RequireCapability(rbac.CapFinanceTransactions))
				pr.Get("/transactions", uiHandlers.PaymentsTransactionsPage)
				RegisterFragment(pr, "/transactions/table", uiHandlers.PaymentsTransactionsTable)
				RegisterFragment(pr, "/transactions/drawer", uiHandlers.PaymentsTransactionsDrawer)
			})
			protected.Route("/finance", func(fr chi.Router) {
				fr.Group(func(recon chi.Router) {
					recon.Use(custommw.RequireCapability(rbac.CapFinanceReconciliation))
					recon.Get("/reconciliation", uiHandlers.ReconciliationPage)
					recon.Post("/reconciliation:trigger", uiHandlers.ReconciliationTrigger)
				})

				fr.Group(func(tax chi.Router) {
					tax.Use(custommw.RequireCapability(rbac.CapFinanceTaxSettings))
					tax.Get("/taxes", uiHandlers.TaxSettingsPage)
					RegisterFragment(tax, "/taxes/grid", uiHandlers.TaxSettingsGrid)
					RegisterFragment(tax, "/taxes/jurisdictions/{jurisdictionID}/modal/new", uiHandlers.TaxRuleNewModal)
					RegisterFragment(tax, "/taxes/jurisdictions/{jurisdictionID}/modal/edit", uiHandlers.TaxRuleEditModal)
					RegisterFragment(tax, "/taxes/jurisdictions/{jurisdictionID}/modal/delete", uiHandlers.TaxRuleDeleteModal)
					tax.Post("/taxes/jurisdictions/{jurisdictionID}/rules", uiHandlers.TaxRuleCreate)
					tax.Put("/taxes/jurisdictions/{jurisdictionID}/rules/{ruleID}", uiHandlers.TaxRuleUpdate)
					tax.Delete("/taxes/jurisdictions/{jurisdictionID}/rules/{ruleID}", uiHandlers.TaxRuleDelete)
				})
			})
			protected.Route("/audit-logs", func(ar chi.Router) {
				ar.Use(custommw.RequireCapability(rbac.CapAuditLogView))
				ar.Get("/", uiHandlers.AuditLogsPage)
				RegisterFragment(ar, "/table", uiHandlers.AuditLogsTable)
				ar.Get("/export", uiHandlers.AuditLogsExport)
			})
			protected.Route("/system", func(sr chi.Router) {
				sr.Group(func(cfg chi.Router) {
					cfg.Use(custommw.RequireCapability(rbac.CapSystemSettings))
					cfg.Get("/settings", uiHandlers.SystemEnvironmentSettingsPage)
				})
				sr.Group(func(tr chi.Router) {
					tr.Use(custommw.RequireCapability(rbac.CapSystemTasks))
					tr.Get("/tasks", uiHandlers.SystemTasksPage)
					RegisterFragment(tr, "/tasks/table", uiHandlers.SystemTasksTable)
					RegisterFragment(tr, "/tasks/jobs/{jobID}/drawer", uiHandlers.SystemTasksDrawer)
					tr.Post("/tasks/jobs/{jobID}:trigger", uiHandlers.SystemTasksTrigger)
					tr.Get("/tasks/stream", uiHandlers.SystemTasksStream)
				})
				sr.Group(func(cr chi.Router) {
					cr.Use(custommw.RequireCapability(rbac.CapSystemCounters))
					cr.Get("/counters", uiHandlers.SystemCountersPage)
					RegisterFragment(cr, "/counters/table", uiHandlers.SystemCountersTable)
					RegisterFragment(cr, "/counters/{name}/drawer", uiHandlers.SystemCountersDrawer)
					cr.Post("/counters/{name}:next", uiHandlers.SystemCountersNext)
				})
				sr.Group(func(er chi.Router) {
					er.Use(custommw.RequireCapability(rbac.CapSystemErrors))
					er.Get("/errors", uiHandlers.SystemErrorsPage)
					RegisterFragment(er, "/errors/table", uiHandlers.SystemErrorsTable)
					RegisterFragment(er, "/errors/{failureID}/drawer", uiHandlers.SystemErrorsDrawer)
					er.Post("/errors/{failureID}:retry", uiHandlers.SystemErrorsRetry)
					er.Post("/errors/{failureID}:acknowledge", uiHandlers.SystemErrorsAcknowledge)
				})
			})
			protected.Route("/reviews", func(rr chi.Router) {
				rr.Use(custommw.RequireCapability(rbac.CapReviewsModerate))
				rr.Get("/", uiHandlers.ReviewsModerationPage)
				RegisterFragment(rr, "/table", uiHandlers.ReviewsModerationTable)
				RegisterFragment(rr, "/{reviewID}/modal/moderate", uiHandlers.ReviewsModerationModal)
				RegisterFragment(rr, "/{reviewID}/modal/reply", uiHandlers.ReviewsReplyModal)
				rr.Put("/{reviewID}:moderate", uiHandlers.ReviewsModerate)
				rr.Post("/{reviewID}:store-reply", uiHandlers.ReviewsStoreReply)
			})
			protected.Route("/org", func(or chi.Router) {
				or.Use(custommw.RequireCapability(rbac.CapStaffManage))
				or.Get("/staff", uiHandlers.OrgStaffPage)
				RegisterFragment(or, "/staff/table", uiHandlers.OrgStaffTable)
				RegisterFragment(or, "/staff/modal/invite", uiHandlers.OrgStaffInviteModal)
				RegisterFragment(or, "/staff/{memberID}/modal/edit", uiHandlers.OrgStaffEditModal)
				RegisterFragment(or, "/staff/{memberID}/modal/revoke", uiHandlers.OrgStaffRevokeModal)
				or.Post("/staff/invite", uiHandlers.OrgStaffInviteSubmit)
				or.Post("/staff/{memberID}:update", uiHandlers.OrgStaffUpdateSubmit)
				or.Post("/staff/{memberID}:revoke", uiHandlers.OrgStaffRevokeSubmit)
				or.Get("/roles", uiHandlers.OrgRolesPage)
			})
			protected.Post("/invoices:issue", uiHandlers.InvoicesIssue)
			protected.Get("/invoices/jobs/{jobID}", uiHandlers.InvoiceJobStatus)
			// Future admin routes will be registered here.
		})
	})
}

func normalizeBasePath(path string) string {
	p := strings.TrimSpace(path)
	if p == "" {
		return "/admin"
	}
	if !strings.HasPrefix(p, "/") {
		p = "/" + p
	}
	if len(p) > 1 && strings.HasSuffix(p, "/") {
		p = strings.TrimRight(p, "/")
	}
	if p == "" {
		return "/"
	}
	return p
}

func resolveLoginPath(base string, override string) string {
	if strings.TrimSpace(override) != "" {
		return override
	}
	if base == "/" {
		return "/login"
	}
	return base + "/login"
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

// RegisterFragment registers a GET handler intended for htmx fragment rendering.
func RegisterFragment(r chi.Router, pattern string, handler http.HandlerFunc) {
	r.With(custommw.RequireHTMX()).Get(pattern, handler)
}

func mustBuildSessionStore(cfg SessionConfig, basePath string) custommw.SessionStore {
	hashKey := cfg.HashKey
	if len(hashKey) == 0 {
		hashKey = randomBytes(32)
		log.Printf("session: generated ephemeral hash key; set ADMIN_SESSION_HASH_KEY to persist sessions across restarts")
	}

	blockKey := cfg.BlockKey
	if blockKey == nil || len(blockKey) == 0 {
		blockKey = randomBytes(32)
	}

	path := firstNonEmpty(cfg.CookiePath, basePath, "/")
	httpOnly := true
	if cfg.CookieHTTPOnly != nil {
		httpOnly = *cfg.CookieHTTPOnly
	}

	manager, err := appsession.NewManager(appsession.Config{
		CookieName:       cfg.CookieName,
		HashKey:          hashKey,
		BlockKey:         blockKey,
		CookiePath:       path,
		CookieDomain:     cfg.CookieDomain,
		CookieSecure:     cfg.CookieSecure,
		CookieHTTPOnly:   &httpOnly,
		CookieSameSite:   cfg.CookieSameSite,
		IdleTimeout:      cfg.IdleTimeout,
		Lifetime:         cfg.Lifetime,
		RememberLifetime: cfg.RememberLifetime,
	})
	if err != nil {
		log.Fatalf("session manager init failed: %v", err)
	}
	return manager
}

func randomBytes(length int) []byte {
	buf := make([]byte, length)
	if _, err := rand.Read(buf); err != nil {
		log.Fatalf("generate random bytes: %v", err)
	}
	return buf
}
