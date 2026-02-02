package main

import (
	"context"
	"encoding/base64"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"
	"go.uber.org/zap"

	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
	"finitefield.org/hanko-admin/internal/admin/httpserver"
	"finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminnotifications "finitefield.org/hanko-admin/internal/admin/notifications"
	"finitefield.org/hanko-admin/internal/admin/observability"
	adminorders "finitefield.org/hanko-admin/internal/admin/orders"
	adminorg "finitefield.org/hanko-admin/internal/admin/org"
	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/profile"
	adminreviews "finitefield.org/hanko-admin/internal/admin/reviews"
	"finitefield.org/hanko-admin/internal/admin/search"
	adminshipments "finitefield.org/hanko-admin/internal/admin/shipments"
)

func main() {
	rootCtx := context.Background()
	appLogger, err := observability.NewLogger()
	if err != nil {
		log.Fatalf("admin: failed to initialise logger: %v", err)
	}
	defer func() {
		if syncErr := appLogger.Sync(); syncErr != nil {
			log.Printf("admin: logger sync failed: %v", syncErr)
		}
	}()

	shipmentsService, shipmentsClose := buildShipmentsService(rootCtx)
	defer shipmentsClose()

	cfg := httpserver.Config{
		Address:              getEnv("ADMIN_HTTP_ADDR", ":3051"),
		BasePath:             getEnv("ADMIN_BASE_PATH", "/"),
		DefaultLocale:        getEnv("ADMIN_DEFAULT_LOCALE", "ja-JP"),
		SupportedLocales:     getEnvList("ADMIN_SUPPORTED_LOCALES", []string{"ja-JP", "en-US"}),
		Authenticator:        buildAuthenticator(rootCtx),
		AllowInsecureAuth:    getEnvBool("ADMIN_ALLOW_INSECURE_AUTH", false),
		CatalogService:       buildCatalogService(),
		ProfileService:       buildProfileService(),
		SearchService:        buildSearchService(),
		NotificationsService: buildNotificationsService(),
		OrdersService:        buildOrdersService(),
		ProductionService:    buildProductionService(),
		ShipmentsService:     shipmentsService,
		ReviewsService:       buildReviewsService(),
		OrgService:           buildOrgService(),
		Environment:          getEnv("ADMIN_ENVIRONMENT", "Development"),
		Logger:               appLogger,
		Session: httpserver.SessionConfig{
			CookieName:       getEnv("ADMIN_SESSION_COOKIE_NAME", ""),
			CookieDomain:     os.Getenv("ADMIN_SESSION_COOKIE_DOMAIN"),
			CookieSecure:     getEnvBool("ADMIN_SESSION_COOKIE_SECURE", false),
			CookieHTTPOnly:   boolPtr(true),
			IdleTimeout:      getEnvDuration("ADMIN_SESSION_IDLE_TIMEOUT", 0),
			Lifetime:         getEnvDuration("ADMIN_SESSION_LIFETIME", 0),
			RememberLifetime: getEnvDuration("ADMIN_SESSION_REMEMBER_LIFETIME", 0),
			HashKey:          getEnvBytes("ADMIN_SESSION_HASH_KEY"),
			BlockKey:         getEnvBytes("ADMIN_SESSION_BLOCK_KEY"),
		},
	}
	cfg.Session.CookiePath = cfg.BasePath

	cfg.UptimeProbes = httpserver.UptimeProbeConfig{
		Enabled:      getEnvBool("ADMIN_UPTIME_ENABLED", true),
		Timeout:      getEnvDuration("ADMIN_UPTIME_TIMEOUT", 5*time.Second),
		ServiceToken: strings.TrimSpace(os.Getenv("ADMIN_UPTIME_SERVICE_TOKEN")),
	}

	if cfg.Authenticator == nil {
		log.Fatal("admin: authenticator not configured; refusing to start")
	}

	metrics := buildMetrics(rootCtx, cfg.Environment)
	if metrics != nil {
		cfg.Metrics = metrics
		defer func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			if err := metrics.Shutdown(ctx); err != nil {
				log.Printf("metrics: shutdown failed: %v", err)
			}
		}()
	}

	srv := httpserver.New(cfg)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("http server failed: %v", err)
		}
	}()

	appLogger.Info("admin server listening",
		zap.String("addr", cfg.Address),
		zap.String("base_path", cfg.BasePath),
	)

	<-ctx.Done()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		appLogger.Error("graceful shutdown failed", zap.Error(err))
		cancel()
		stop()
		os.Exit(1)
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvBool(key string, fallback bool) bool {
	if v := os.Getenv(key); v != "" {
		val, err := strconv.ParseBool(v)
		if err != nil {
			log.Printf("invalid boolean for %s: %v", key, err)
			return fallback
		}
		return val
	}
	return fallback
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil {
			log.Printf("invalid duration for %s: %v", key, err)
			return fallback
		}
		return d
	}
	return fallback
}

func getEnvBytes(key string) []byte {
	val := os.Getenv(key)
	if val == "" {
		return nil
	}
	if decoded, err := base64.StdEncoding.DecodeString(val); err == nil {
		return decoded
	}
	if decoded, err := base64.RawStdEncoding.DecodeString(val); err == nil {
		return decoded
	}
	if decoded, err := base64.URLEncoding.DecodeString(val); err == nil {
		return decoded
	}
	if decoded, err := base64.RawURLEncoding.DecodeString(val); err == nil {
		return decoded
	}
	log.Printf("using literal value for %s; base64 decode failed", key)
	return []byte(val)
}

func boolPtr(v bool) *bool {
	return &v
}

func getEnvInt(key string, fallback int) int {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		log.Printf("invalid integer for %s: %v", key, err)
		return fallback
	}
	return value
}

func getEnvList(key string, fallback []string) []string {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return append([]string(nil), fallback...)
	}
	parts := strings.Split(raw, ",")
	values := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			values = append(values, trimmed)
		}
	}
	if len(values) == 0 && len(fallback) > 0 {
		return append([]string(nil), fallback...)
	}
	return values
}

func buildMetrics(ctx context.Context, environment string) *observability.Metrics {
	enabled := getEnvBool("ADMIN_METRICS_ENABLED", true)
	cfg := observability.Config{
		Enabled:        enabled,
		ProjectID:      firstNonEmpty(os.Getenv("ADMIN_METRICS_PROJECT_ID"), os.Getenv("GOOGLE_CLOUD_PROJECT"), os.Getenv("GCP_PROJECT")),
		ServiceName:    getEnv("ADMIN_METRICS_SERVICE_NAME", "hanko-admin"),
		ServiceVersion: firstNonEmpty(os.Getenv("ADMIN_METRICS_SERVICE_VERSION"), os.Getenv("K_REVISION")),
		Environment:    environment,
		ExportInterval: getEnvDuration("ADMIN_METRICS_EXPORT_INTERVAL", 0),
	}
	metrics, err := observability.NewMetrics(ctx, cfg)
	if err != nil {
		log.Printf("metrics: init failed: %v", err)
		return nil
	}
	return metrics
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func buildAuthenticator(ctx context.Context) middleware.Authenticator {
	projectID := os.Getenv("FIREBASE_PROJECT_ID")
	if projectID == "" {
		if getEnvBool("ADMIN_ALLOW_INSECURE_AUTH", false) {
			log.Printf("WARNING: ADMIN_ALLOW_INSECURE_AUTH enabled; using insecure passthrough authenticator. Do NOT use in production.")
			return middleware.DefaultAuthenticator()
		}
		log.Fatal("FIREBASE_PROJECT_ID not set and ADMIN_ALLOW_INSECURE_AUTH is false; refusing to start without authenticator")
	}

	app, err := firebase.NewApp(ctx, &firebase.Config{
		ProjectID: projectID,
	})
	if err != nil {
		log.Fatalf("failed to initialise Firebase app: %v", err)
	}

	client, err := app.Auth(ctx)
	if err != nil {
		log.Fatalf("failed to initialise Firebase auth client: %v", err)
	}

	log.Printf("Firebase authenticator enabled (project=%s)", projectID)
	return middleware.NewFirebaseAuthenticator(client)
}

func buildProfileService() profile.Service {
	baseURL := strings.TrimSpace(os.Getenv("ADMIN_SECURITY_API_BASE_URL"))
	if baseURL == "" {
		log.Printf("admin: ADMIN_SECURITY_API_BASE_URL not set; using static profile service placeholder")
		return profile.NewStaticService(nil)
	}

	httpClient := &http.Client{Timeout: 10 * time.Second}
	service, err := profile.NewHTTPService(baseURL, httpClient)
	if err != nil {
		log.Fatalf("admin: failed to initialise profile service: %v", err)
	}
	return service
}

func buildOrgService() adminorg.Service {
	baseURL := strings.TrimSpace(os.Getenv("ADMIN_ORG_API_BASE_URL"))
	if baseURL == "" {
		log.Printf("admin: ADMIN_ORG_API_BASE_URL not set; using static org service placeholder")
		return adminorg.NewStaticService()
	}

	httpClient := &http.Client{Timeout: 10 * time.Second}
	service, err := adminorg.NewHTTPService(baseURL, httpClient)
	if err != nil {
		log.Fatalf("admin: failed to initialise org service: %v", err)
	}
	return service
}

func buildSearchService() search.Service {
	if base := strings.TrimSpace(os.Getenv("ADMIN_SEARCH_API_BASE_URL")); base != "" {
		log.Printf("admin: ADMIN_SEARCH_API_BASE_URL is set (%s) but no HTTP client is implemented yet; using static search dataset", base)
	}
	return search.NewStaticService()
}

func buildNotificationsService() adminnotifications.Service {
	return adminnotifications.NewStaticService()
}

func buildOrdersService() adminorders.Service {
	return adminorders.NewStaticService()
}

func buildCatalogService() admincatalog.Service {
	return admincatalog.NewStaticService()
}

func buildProductionService() adminproduction.Service {
	return adminproduction.NewStaticService()
}

func buildReviewsService() adminreviews.Service {
	return adminreviews.NewStaticService()
}

func buildShipmentsService(ctx context.Context) (adminshipments.Service, func()) {
	projectID := getFirestoreProjectID()
	if projectID == "" {
		log.Printf("admin: no Firestore project configured; using static shipment tracking data")
		return adminshipments.NewStaticService(), func() {}
	}

	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Printf("admin: failed to initialise Firestore client (%s): %v", projectID, err)
		return adminshipments.NewStaticService(), func() {}
	}

	cfg := adminshipments.FirestoreConfig{
		TrackingCollection:     getEnv("ADMIN_SHIPMENTS_TRACKING_COLLECTION", "ops_tracking_shipments"),
		AlertsCollection:       getEnv("ADMIN_SHIPMENTS_TRACKING_ALERTS_COLLECTION", "ops_tracking_alerts"),
		MetadataDocPath:        strings.TrimSpace(os.Getenv("ADMIN_SHIPMENTS_TRACKING_METADATA_DOC")),
		FetchLimit:             getEnvInt("ADMIN_SHIPMENTS_TRACKING_FETCH_LIMIT", 500),
		AlertsLimit:            getEnvInt("ADMIN_SHIPMENTS_TRACKING_ALERTS_LIMIT", 5),
		CacheTTL:               getEnvDuration("ADMIN_SHIPMENTS_TRACKING_CACHE_TTL", 15*time.Second),
		DefaultRefreshInterval: getEnvDuration("ADMIN_SHIPMENTS_TRACKING_REFRESH_INTERVAL", 30*time.Second),
		QueryTimeout:           getEnvDuration("ADMIN_SHIPMENTS_TRACKING_QUERY_TIMEOUT", 0),
	}
	service := adminshipments.NewFirestoreService(client, cfg)
	cleanup := func() {
		if err := client.Close(); err != nil {
			log.Printf("admin: firestore client close error: %v", err)
		}
	}
	return service, cleanup
}

func getFirestoreProjectID() string {
	if v := strings.TrimSpace(os.Getenv("ADMIN_FIRESTORE_PROJECT_ID")); v != "" {
		return v
	}
	if v := strings.TrimSpace(os.Getenv("FIRESTORE_PROJECT_ID")); v != "" {
		return v
	}
	return strings.TrimSpace(os.Getenv("FIREBASE_PROJECT_ID"))
}
