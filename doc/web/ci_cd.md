# Web CI/CD Pipeline

The web service pipeline lives in `.github/workflows/web.yml` and is split into three jobs: `checks`, `deploy-staging`, and `deploy-production`. It validates every pull request, continuously deploys `main` to staging, and promotes builds to production behind an approval gate with automated smoke checks.

## Jobs

### `checks`
- **Trigger:** Pull requests touching `web/**` or the workflow itself, pushes to `main`, and manual dispatches.
- **Toolchain:** `actions/setup-go@v5` reads the Go version from `web/go.mod` (currently Go 1.23.2) and enables module caching.
- **Static analysis:** Fails if `gofmt -l .` reports changes or if `go vet ./...` finds issues.
- **Tests:** Runs `go test ./...` across the web module and ensures the main binary builds with `go build ./cmd/web`.

### `deploy-staging`
- **Trigger:** Pushes to `main` and manual runs where `target_environment` is `both` or `staging`.
- **Auth:** Uses `google-github-actions/auth@v2` with the `WEB_GCP_SA_KEY` service account JSON and configures Artifact Registry docker auth.
- **Image handling:** Builds and pushes `asia-northeast1-docker.pkg.dev/${WEB_ARTIFACT_PROJECT}/${WEB_GAR_REPOSITORY}/web:${GITHUB_SHA}` unless a pre-built image is supplied via the manual dispatch input.
- **Deployment:** `gcloud run deploy` targets `${WEB_STAGING_SERVICE}` in `${WEB_STAGING_PROJECT}`, tags the revision `staging`, updates labels (`app=hanko-web`, `commit`, `env=staging`), and exports `HANKO_WEB_ENV=staging` and `HANKO_WEB_RELEASE=${GITHUB_SHA}`.
- **Smoke test:** Probes `<service>/healthz` (or `WEB_STAGING_SMOKE_URL` if set) with up to five attempts, failing the job on any non-200 response.
- **Artifacts:** Uploads `previous_revision.txt`, the before/after service descriptions, and `deployment.json` (image + commit metadata) for rollback context.

### `deploy-production`
- **Trigger:** Runs after staging on `main` and manual runs where `target_environment` is `both` or `production`. It uses the GitHub **production** environment, so execution pauses until an approver authorises the deployment.
- **Image handling:** Reuses the staging image (`needs.deploy-staging.outputs.image`) by default, but honours a manual `image` input. If neither is available (for example, a production-only manual run), it rebuilds and pushes the image before deploying.
- **Deployment:** Updates `${WEB_PRODUCTION_SERVICE}` in `${WEB_PRODUCTION_PROJECT}` with the selected image, tags the revision `production`, refreshes labels (`app`, `commit`, `env=production`), and sets `HANKO_WEB_ENV=prod` plus `HANKO_WEB_RELEASE=${GITHUB_SHA}`.
- **Smoke test:** Hits `<service>/healthz` (or `WEB_PRODUCTION_SMOKE_URL`) with the same retry loop. A failure blocks production promotion.
- **Artifacts:** Publishes the same metadata bundle as staging under `web-production-deploy-<run id>`.

## Manual runs
`workflow_dispatch` supports three inputs:
- `target_environment` (`both`, `staging`, or `production`) controls which deploy jobs run.
- `ref` optionally checks out a different git ref before build/deploy.
- `image` lets you deploy an already-pushed container image, skipping local build/push steps.

## Required GitHub secrets and variables

| Name | Type | Purpose |
| --- | --- | --- |
| `WEB_GCP_SA_KEY` | Secret | Base64-encoded service account JSON with Artifact Registry + Cloud Run permissions for staging and production projects. |
| `WEB_GAR_HOST` | Variable | Artifact Registry host (e.g. `asia-northeast1-docker.pkg.dev`). |
| `WEB_ARTIFACT_PROJECT` | Variable | Google Cloud project that owns the Artifact Registry repository. |
| `WEB_GAR_REPOSITORY` | Variable | Artifact Registry repository name (e.g. `web`). |
| `WEB_REGION` | Variable | Cloud Run region (e.g. `asia-northeast1`). |
| `WEB_STAGING_PROJECT` | Variable | Google Cloud staging project ID (`hanko-field-stg`). |
| `WEB_STAGING_SERVICE` | Variable | Staging Cloud Run service name (e.g. `hanko-web-stg`). |
| `WEB_PRODUCTION_PROJECT` | Variable | Google Cloud production project ID (`hanko-field-prod`). |
| `WEB_PRODUCTION_SERVICE` | Variable | Production Cloud Run service name (e.g. `hanko-web`). |
| `WEB_STAGING_SMOKE_URL` | Variable (optional) | Overrides the staging smoke test base URL. |
| `WEB_PRODUCTION_SMOKE_URL` | Variable (optional) | Overrides the production smoke test base URL. |

Set up GitHub environments:
- **staging:** no approval requirement; optional environment secrets if you prefer to scope smoke URLs per environment.
- **production:** require at least one reviewer to approve deployments for this environment. Store `WEB_PRODUCTION_SMOKE_URL` here if you want the value hidden from the repository variable list.

## Smoke test expectations
The probe hits `/healthz`, which is already covered by `TestHealthzOK` in `web/cmd/web/main_test.go`. Ensure the Cloud Run service exposes that endpoint publicly or via an authorised URL set in the smoke URL variables.

## Rollback procedure
1. Download the relevant deployment artifact (`web-staging-deploy-*` or `web-production-deploy-*`) from the failed workflow run and read `previous_revision.txt` to determine the prior revision.
2. Execute:
   ```bash
   gcloud run services update-traffic ${SERVICE_NAME} \
     --platform=managed \
     --region=${WEB_REGION} \
     --project=${PROJECT_ID} \
     --to-revisions=${PREVIOUS_REVISION}=100
   ```
   Replace `${SERVICE_NAME}` and `${PROJECT_ID}` with either the staging or production values, and `${PREVIOUS_REVISION}` with the string from the artifact.
3. Re-run the smoke test (`curl -fSs <service>/healthz`) to confirm recovery, and document the rollback in your incident or change log.

## Release notes (2025-02-14)
- Added `.github/workflows/web.yml` with staged deployments and health probes for both environments.
- Captured deployment metadata and previous revisions to streamline rollback.
- Documented required GitHub configuration, manual triggers, and Cloud Run rollback commands.
