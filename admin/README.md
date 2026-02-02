# Hanko Admin (Go + html/template Scaffold)

## Prerequisites

- Go 1.23+
- Node.js 20+ and npm (devbox manages Tailwind CLI)

## Setup

```bash
cd admin
make ensure-tailwind   # verifies tailwindcss CLI is available
```

## Common Commands

- `make dev` – tidy modules, start Tailwind watcher, then launch the Go server.
- `make css` – single build of Tailwind output (minified) to `public/static/app.css`.
- `make css-watch` – Tailwind watch mode without starting the Go server.
- `make lint` – `gofmt` and `go vet`.
- `make test-ui` – run integration smoke tests with `httptest` + DOM assertions.

The Go server does not hot reload. Restart `make dev` after Go or template changes.

Tailwind scans the paths listed in `tailwind.config.js`.

## Configuration

Environment variables:

- `ADMIN_HTTP_ADDR` – bind address (default `:3051`)
- `ADMIN_BASE_PATH` – mount point for the admin UI (default `/admin`)
- `FIREBASE_PROJECT_ID` – enables Firebase ID token verification when provided (requires service account credentials)
- `ADMIN_FIRESTORE_PROJECT_ID` – optional override for the Firestore project used by shipment tracking (falls back to `FIRESTORE_PROJECT_ID` or `FIREBASE_PROJECT_ID`)
- `GOOGLE_APPLICATION_CREDENTIALS` – path to service account JSON used by the Firebase Admin SDK
- `FIREBASE_AUTH_EMULATOR_HOST` – optional host for the Firebase Auth emulator during local development
- `ADMIN_SHIPMENTS_TRACKING_COLLECTION` – Firestore collection containing the pre-aggregated tracking view (default `ops_tracking_shipments`)
- `ADMIN_SHIPMENTS_TRACKING_ALERTS_COLLECTION` – optional collection for dashboard alert banners (default `ops_tracking_alerts`)
- `ADMIN_SHIPMENTS_TRACKING_METADATA_DOC` – document path storing `updatedAt`/interval metadata to invalidate caches (e.g. `ops_tracking/meta/state`)
- `ADMIN_SHIPMENTS_TRACKING_FETCH_LIMIT` – maximum number of active tracking rows to hydrate per refresh (default `500`)
- `ADMIN_SHIPMENTS_TRACKING_ALERTS_LIMIT` – maximum number of alert banners to render (default `5`)
- `ADMIN_SHIPMENTS_TRACKING_CACHE_TTL` – in-memory cache duration for the tracking dataset (default `15s`)
- `ADMIN_SHIPMENTS_TRACKING_REFRESH_INTERVAL` – fallback auto-refresh interval exposed to the UI when metadata does not supply one (default `30s`)
- `ADMIN_SHIPMENTS_TRACKING_QUERY_TIMEOUT` – max duration for Firestore tracking queries before timing out (default `5s`)
- `ADMIN_METRICS_ENABLED` – toggles Cloud Monitoring export for admin metrics (default `true` when a project ID is available)
- `ADMIN_METRICS_PROJECT_ID` – overrides the project used for Cloud Monitoring (falls back to `GOOGLE_CLOUD_PROJECT` / `GCP_PROJECT`)
- `ADMIN_METRICS_SERVICE_NAME` / `ADMIN_METRICS_SERVICE_VERSION` – optional overrides for the resource labels attached to emitted metrics
- `ADMIN_METRICS_EXPORT_INTERVAL` – interval for flushing metrics to Cloud Monitoring (default `60s`)

Install the Tailwind CLI once if missing:

```bash
npm install
```

### Authentication

The default authenticator accepts any non-empty bearer token for local development. Include an `Authorization: Bearer <token>` header in requests (e.g., via browser extension) until Firebase integration is wired in. Unauthenticated browsers are redirected to `<ADMIN_BASE_PATH>/login`.

If `ADMIN_ALLOW_INSECURE_AUTH=1`, the admin UI skips the login gate and injects a local dev user for all requests. Do not enable this in production.

## Layout

- `cmd/admin` – entrypoint.
- `internal/admin/httpserver` – chi router + handlers.
- `internal/admin/templates` – template payload builders organised by feature.
- `internal/admin/webtmpl/templates` – html/template files organised by feature.
- `public/static` – compiled CSS/JS assets served by Go via `embed`.
- `web/styles` – Tailwind source files.
- Design tokens and component guidelines are catalogued in `doc/admin/design_tokens.md`.
