# Document admin console deployment checklist, including environment variables, Firebase auth setup, and CDN configuration.

**Parent Section:** 15. Quality Assurance & Documentation
**Task ID:** 078

## Goal
Document deployment procedure for admin console.

## Implementation Steps
1. Outline prerequisites (Firebase config, OAuth clients, environment variables).
2. Provide step-by-step deploy instructions (CI pipeline, manual commands).
3. Include rollback plan and smoke test list.
4. Store doc in repo and keep versioned.

---

## Deployment Checklist

| Phase | Owner | Notes |
| --- | --- | --- |
| Pre-flight | Admin eng + DevOps | Verify infra, Firebase, CDN, and secrets exist for target environment. |
| Build | Admin eng | Run linters/tests, bake Tailwind assets, and build/push container image. |
| Release | DevOps | Deploy to Cloud Run (staging → production), update CDN + Firebase settings, capture revision IDs. |
| Verification | Admin QA | Execute smoke tests, review logs/metrics, confirm CDN cache state. |
| Rollback-ready | DevOps | Keep previous revision id + container digest handy; ensure traffic-splitting plan documented. |

Use a tracked checklist in the release ticket and attach command transcripts plus screenshots where required.

## Prerequisites

- **Access**: `roles/run.admin`, `roles/artifactregistry.writer`, `roles/secretmanager.secretAccessor`, and Firebase project owner/editor.
- **Infrastructure**: Cloud Run service (`admin-console`), Artifact Registry repo (`hanko-admin`), HTTPS Cloud CDN fronting Cloud Run via Serverless NEG, and Firebase project with Admin SDK service account.
- **Branch hygiene**: Tagged release commit on `main`. Feature flags merged/disabled as appropriate.
- **Tooling**: `gcloud` ≥ 451.0, `docker` or Cloud Build privileges, `make`, `templ`, Tailwind binary installed via `make ensure-tailwind`.
- **Monitoring hooks**: Cloud Monitoring dashboard + alerting policies enabled before promoting to production.

## Required Environment Variables & Secrets

Configure in Cloud Run (or IaC) and keep secrets (marked 🔒) in Secret Manager referencing the service account that runs the service.

| Variable | Description | Required | Typical Value/Secret |
| --- | --- | --- | --- |
| `ADMIN_HTTP_ADDR` | Listen address inside container. | No | `:8080` |
| `ADMIN_BASE_PATH` | URL prefix for routing + redirects. | No | `/admin` |
| `FIREBASE_PROJECT_ID` | Firebase project used for ID token verification. | ✅ | `hanko-prod` |
| `GOOGLE_APPLICATION_CREDENTIALS` 🔒 | Path to mounted service account JSON (use Secret Manager volume). | ✅ | `/var/secrets/firebase-admin.json` |
| `FIREBASE_AUTH_EMULATOR_HOST` | Only set in staging when using emulator (omit in prod). | No | `localhost:9099` |
| `ADMIN_ALLOW_INSECURE_AUTH` | `true` only for local dev; **must be unset/false in prod**. | No | _unset_ |
| `ADMIN_FIRESTORE_PROJECT_ID` | Override Firestore reads if different from Firebase project. | No | `ops-shared` |
| `ADMIN_SHIPMENTS_TRACKING_COLLECTION` | Tracking collection name. | No | `ops_tracking_shipments` |
| `ADMIN_SHIPMENTS_TRACKING_ALERTS_COLLECTION` | Dashboard alerts collection. | No | `ops_tracking_alerts` |
| `ADMIN_SHIPMENTS_TRACKING_METADATA_DOC` | Metadata doc path for refresh intervals. | No | `ops_tracking/meta/state` |
| `ADMIN_SHIPMENTS_TRACKING_FETCH_LIMIT` | Max rows per refresh. | No | `500` |
| `ADMIN_SHIPMENTS_TRACKING_ALERTS_LIMIT` | Max alerts to render. | No | `5` |
| `ADMIN_SHIPMENTS_TRACKING_CACHE_TTL` | Cache duration for tracking view. | No | `15s` |
| `ADMIN_SHIPMENTS_TRACKING_REFRESH_INTERVAL` | UI auto-refresh fallback. | No | `30s` |
| `ASSETS_CDN_BASE_URL` | HTTPS origin for static assets (if split from Cloud Run). | No | `https://cdn.hanko-field.com/admin` |
| `LOG_LEVEL` | `info` / `debug`. Keep `debug` off in prod. | No | `info` |
| `ADMIN_UPTIME_ENABLED` | Enables `/admin/uptime/*` probes used by Cloud Monitoring. | No | `true` |
| `ADMIN_UPTIME_TIMEOUT` | Timeout per probe when calling downstream services. | No | `3s` |
| `ADMIN_UPTIME_SERVICE_TOKEN` 🔒 | Optional bearer token used when probes call protected APIs. Store in Secret Manager. | No | `projects/.../secrets/admin-uptime-token` |

### Secrets handling

1. Create Secret Manager entries `firebase-admin-[env]` containing the service account JSON and grant the Cloud Run runtime principal `roles/secretmanager.secretAccessor`.
2. Mount the secret as a file (`/var/secrets/firebase-admin.json`) using the Cloud Run secret volume feature, then set `GOOGLE_APPLICATION_CREDENTIALS` to that path.
3. If CDN/API keys are required (e.g., Fastly purge token), store them separately and inject via env var or Secret Manager reference.

## Firebase Auth Setup

1. **Service account**: In the Firebase project, create a service account (e.g., `admin-console-auth`) with the **Firebase Admin SDK Administrator Service Agent** role. Generate a JSON key, upload it to Secret Manager as above, and delete the local copy.
2. **Allowlist domains**: Add `admin.$ENV.hanko-field.com`, Cloud Run default URL, and any preview domains under **Authentication → Settings → Authorized domains**.
3. **Web client/OAuth**:
   - Register a Web app (if not already) for the admin console to obtain the API key and Web client ID used by front-channel login.
   - Configure redirect URI `https://admin.$ENV.hanko-field.com/admin/login/callback` (or base path override).
   - Enable desired providers (Email/Password, Google, SAML, etc.) ensuring claims align with RBAC (e.g., `customClaims.roles`).
4. **ID token verification**: Confirm Cloud Run service account can access the Firebase project. `FIREBASE_PROJECT_ID` must match the project where tokens originate.
5. **Emulator/staging**: When staging uses Firebase Auth emulator, set `FIREBASE_AUTH_EMULATOR_HOST` and create seed users via `firebase auth:import` script. Ensure staging secrets use a non-production service account.

## Build & Release Steps

1. **Code validation**
   ```bash
   cd admin
   make lint
   make test-ui
   make css   # ensure Tailwind bundle is up to date
   ```
   Confirm `git status` is clean and tag release (`git tag admin-vYYYYMMDD`).

2. **Image build & push** (replace variables as needed):
   ```bash
   export PROJECT_ID=hanko-prod
   export REGION=asia-northeast1
   export IMAGE=asia-northeast1-docker.pkg.dev/$PROJECT_ID/admin/hanko-admin:$GIT_SHA

   gcloud builds submit admin --tag "$IMAGE"
   ```
   Capture the artifact digest for rollback notes.

3. **Deploy to staging**:
   ```bash
   gcloud run deploy admin-console-stg \
     --image "$IMAGE" \
     --region "$REGION" \
     --platform managed \
     --allow-unauthenticated \
     --set-env-vars "ADMIN_BASE_PATH=/admin,LOG_LEVEL=debug" \
     --set-secrets "GOOGLE_APPLICATION_CREDENTIALS=firebase-admin-stg:latest" \
     --min-instances=1 --max-instances=5
   ```
   Verify revision `REVISION_STG` and note it in the release doc.

4. **Promote to production** (after approvals + smoke on staging):
   ```bash
   gcloud run deploy admin-console \
     --image "$IMAGE" \
     --region "$REGION" \
     --platform managed \
     --set-env-vars "ADMIN_BASE_PATH=/admin,LOG_LEVEL=info" \
     --set-env-vars "ASSETS_CDN_BASE_URL=https://cdn.hanko-field.com/admin" \
     --set-secrets "GOOGLE_APPLICATION_CREDENTIALS=firebase-admin-prod:latest" \
     --min-instances=2 --max-instances=20 \
     --ingress internal-and-cloud-load-balancing
   ```
   Update change log with revision `REVISION_PROD`.

5. **CI integration**: GitHub Actions workflow `deploy-admin.yml` (placeholder) should:
   - Run `make lint && make test-ui`.
   - Build/push image via Cloud Build using workload identity.
   - Deploy to staging automatically on `main`.
   - Await manual approval for production via environments (ensuring artifact/revision metadata stored as workflow artifacts).

## CDN Configuration

1. **Static asset strategy**:
   - Tailwind output lives in `admin/public/static`. Keep file names hashed (Tailwind CLI `--minify --no-autoprefixer` optional) to leverage immutable caching.
   - During build, copy `public/static` into container (already handled) and optionally sync to `gs://hanko-admin-assets/$ENV`.
2. **Cloud CDN fronting Cloud Run**:
   - Use a global HTTPS load balancer with a serverless NEG pointing to the Cloud Run service.
   - Enable Cloud CDN on the backend service, set default `Cache-Control: public, max-age=600` for HTML and `public, max-age=31536000, immutable` for static assets (configure via response headers in Go handler or Cloud CDN policy).
   - Attach SSL certificate for `admin.$ENV.hanko-field.com`.
3. **Asset CDN (optional)**:
   - Serve `public/static` from Cloud Storage bucket + Cloud CDN for better caching. Upload via `gsutil rsync -r admin/public/static gs://hanko-admin-assets/$ENV/$(git rev-parse --short HEAD)/`.
   - Set `ASSETS_CDN_BASE_URL` so templates reference CDN URLs instead of embedded assets.
4. **Invalidation**:
   - Automate CDN cache invalidation (Cloud CDN cache invalidation or Fastly purge) whenever `public/static` changes or new release is promoted. Hook into CI to call `gcloud compute url-maps invalidate-cdn-cache`.
5. **Monitoring**:
   - Track cache hit ratio + latency. Alert if hit ratio drops <70% or if CDN origin errors spike (Cloud Monitoring metric `loadbalancing.googleapis.com/https/total_latencies`).

## Verification & Smoke Tests

Run in both staging and production immediately after deployment:

- Login flow with Firebase token (ensure redirect + session cookies work).
- Navigation smoke: dashboard, orders list, shipments tracking, notifications.
- htmx partial refresh: trigger a table filter/search and confirm `HX-Trigger` → toast events fire.
- CDN assets served from correct host with 200 responses and expected cache headers.
- Firestore-backed widgets (tracking dashboard) display fresh data (check `updatedAt` metadata).
- Logs show Firebase token verification success; no `ADMIN_ALLOW_INSECURE_AUTH` warnings.
- Cloud Run metrics: CPU < 60%, no surge in 5xx responses.

Document results in the release ticket with timestamps + screenshots when relevant.

## Rollback Plan

1. Keep `REVISION_PREV` (previous Cloud Run revision) recorded. To rollback:
   ```bash
   gcloud run services update-traffic admin-console \
     --to-revisions "$REVISION_PREV"=100 \
     --region "$REGION"
   ```
2. If container image itself is faulty, redeploy known-good digest:
   ```bash
   gcloud run deploy admin-console --image "asia-northeast1-docker.pkg.dev/$PROJECT_ID/admin/hanko-admin@sha256:..." --region "$REGION"
   ```
3. Invalidate CDN to flush bad assets (`gcloud compute url-maps invalidate-cdn-cache admin-console --path "/admin/*"`).
4. Revert Firebase config changes (e.g., disable new provider) if they contributed to outage.
5. Record RCA artifacts and update this checklist if rollback revealed gaps.

## Versioning & Ownership

- Store updates in `doc/admin/tasks/078-...md` and link from runbook index.
- Assign an owner per release (Admin eng on-call). Quarterly review checklist with SRE to keep env vars/CDN references accurate.
