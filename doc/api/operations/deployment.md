# API Deployment & Rollback Checklists

This playbook defines the pre-flight checks, deployment flow, and rollback steps for every
API environment. It complements `doc/api/ci_cd.md` (pipeline internals) and
`doc/api/operations/runbooks.md` (incident response) by focusing on day-to-day releases.
Keep this document updated after each release retrospective so lessons learned flow back
into the checklists.

## Environment Overview

| Environment | Purpose | Trigger | Approvals | Observability Focus |
| --- | --- | --- | --- | --- |
| **Dev / Preview** | Shared sandbox for feature validation against cloud dependencies. | Manual `gcloud run deploy --tag=dev` or ad-hoc GitHub workflow dispatch. | None. | Basic `/healthz`, Firestore emulator logs, feature-flag smoke flows. |
| **Staging** | Production-like dress rehearsal backed by staging GCP project and data fixtures. | `build-and-deploy-staging` job on `main`. | Code review on PR merge. | Synthetic smoke tests, Cloud Monitoring dashboard `dashboards/api-core-stg`. |
| **Production** | Customer-facing Cloud Run service. | `promote-production` job after manual approval. | GitHub environment approval + release manager sign-off. | Error budgets, AP-CHK/AP-WBH alerts, real traffic dashboards. |

## Shared Pre-deployment Checklist

Complete these items before triggering any deploy (dev/stg/prod):

1. **Code readiness** – PR merged to `main`, CI green (`checks` job) and coverage artifact
   uploaded. Confirm `go test ./...` + integration tests pass locally when touching data
   access layers.
2. **Configuration parity** – Ensure required env vars/secrets listed in
   `doc/api/configuration.md` exist in the target environment (Secret Manager versions,
   feature flags, OAuth audience). Pin new secrets before rollout to avoid runtime fetches.
3. **Schema & data safety** – For Firestore index changes, verify Terraform applies in the
   target project ahead of the deploy. Capture backup/export IDs for any destructive data
   migrations.
4. **Operational notices** – Post intent in `#release-api` (or equivalent) with planned
   window, risk, rollback owner, and expected Cloud Run revision label.
5. **Freeze awareness** – Check incident channel and release calendar for active freezes.
   Abort deploys during Sev-1 incidents unless release commander approves.
6. **Smoke plan** – Identify which manual QA scenarios from `doc/api/manual_qa.md` must run
   post-deploy (at minimum: checkout happy path, webhook replay, AI suggestion fetch).

Only proceed once every box is checked and linked artifacts (dashboards, Terraform plan,
manual QA owner) are documented in the release ticket.

## Dev / Preview Deployment

**Purpose:** Quick feedback loop for integrated testing against cloud resources without
impacting staging/prod traffic.

### Steps
1. **Select commit** – Checkout the feature branch locally and confirm tests pass.
2. **Build image** – `make docker-build` (uses the multi-stage Dockerfile). Tag the image
   as `${GAR_LOCATION}-docker.pkg.dev/${DEV_PROJECT}/${GAR_REPO}/api:${USER}-preview` and
   push via `gcloud auth configure-docker`.
3. **Deploy** –
   ```bash
   gcloud run deploy api-service \
     --project=${DEV_PROJECT} \
     --region=${CLOUD_RUN_REGION} \
     --image=${IMAGE_URI} \
     --tag=dev \
     --set-env-vars="API_SECURITY_ENVIRONMENT=dev" \
     --labels="env=dev,commit=$(git rev-parse --short HEAD)"
   ```
4. **Smoke** – Hit `/healthz`, run `make qa-smoke DEV_BASE_URL=...`, and poke the feature
   under test.
5. **Document** – Share the deployed URL plus feature flag states in the ticket.

### Rollback / Cleanup
- Dev deploys usually target only the `dev` tag. To revert, shift traffic back to the previous
  revision captured during deployment (for example, with
  `gcloud run revisions list --tag=dev --limit=2` to grab the name) and send 100% of traffic to
  it:
  ```bash
  gcloud run services update-traffic api-service \
    --project=${DEV_PROJECT} \
    --region=${CLOUD_RUN_REGION} \
    --to-revisions ${PREVIOUS_REVISION}=100
  ```
- Remove temporary feature flags/config after validation so staging inherits a clean diff.

## Staging Deployment

**Owner:** Release engineer on rotation. **Source:** `main` branch.

### Pre-flight
- Confirm latest `main` commit has a successful `build-and-deploy-staging` run queued.
- Review Terraform apply status for staging indexes/queues.
- Ensure staging sample data reflects the new feature (seed scripts run nightly).

### Execution
1. Merge PR -> CI automatically triggers `build-and-deploy-staging`.
2. Monitor the workflow: image build, publish, deploy to Cloud Run tag `staging`.
3. When the workflow hits the smoke-test step, verify the log output shows HTTP 200 from
   `${STAGING_SMOKE_URL}`. If it fails, stop the pipeline and investigate before promotion.
4. After workflow success, run targeted manual QA:
   - Checkout + payment happy path (Stripe test keys).
   - Webhook replay using staging secret (`make qa-webhooks env=staging`).
   - AI suggestion request (ensures Pub/Sub + worker path).
5. Capture Cloud Monitoring snapshot `dashboards/api-core-stg` and attach to the release
   ticket for historical comparisons.

### Rollback
1. Fetch `previous_revision.txt` from the workflow artifact `api-staging-deploy-*`.
2. Shift 100% staging traffic back:
   ```bash
   gcloud run services update-traffic api-service \
     --project=${STAGING_PROJECT} \
     --region=${CLOUD_RUN_REGION} \
     --to-revisions ${PREVIOUS_REVISION}=100
   ```
3. Rerun the staging smoke workflow (manually dispatch `build-and-deploy-staging` on an
   earlier commit) to ensure the environment is healthy.
4. If Firestore mutations were part of the release, execute the rollback procedure documented
   in the release ticket or restore from the most recent export artifact captured during
   pre-flight.

## Production Deployment

**Owner:** Release manager + on-call engineer. **Source:** Same image generated in staging.

### Pre-flight
- Confirm staging QA sign-off is recorded and no Sev-1/Sev-2 incidents are active.
- Verify the GitHub `production` environment gate lists an approver before `promote-production`
  runs. Attach rollback owner + revision ID in the approval comment.
- Ensure customer comms templates (Statuspage, CS macros) are drafted for rapid use.

### Execution
1. Approve the pending `promote-production` job. GitHub records who approved and when.
2. Watch the workflow stages: deploy existing image to prod, run `/healthz` smoke, post Slack
   notification (if configured).
3. Perform live checks immediately after deployment:
   - Confirm Cloud Run revision label matches `${GITHUB_SHA}`.
   - Inspect Cloud Logging for `severity>=ERROR` within the first 5 minutes.
   - Validate critical dashboards: HTTP 5xx ratio, checkout latency, webhook backlog.
4. Run a customer-like manual scenario (checkout or design upload) via feature flag safe user.
5. Announce completion in `#release-api` with links to workflow run, revision, and snapshots.

### Rollback (within 30 minutes preferred)
1. Download the production workflow artifact to obtain `previous_revision.txt`.
2. Shift traffic back:
   ```bash
   gcloud run services update-traffic api-service \
     --project=${PROD_PROJECT} \
     --region=${CLOUD_RUN_REGION} \
     --to-revisions ${PREVIOUS_REVISION}=100
   ```
3. Re-run smoke + manual scenario to verify stability, then freeze further deploys until RCA.
4. If data/secret changes accompanied the deploy:
   - **Firestore**: execute rollback script or restore export `gs://firestore-backups/YYYYMMDD`
     as referenced in the release ticket.
   - **Secrets/config**: re-enable the previous Secret Manager version or revert the feature
     flag entry (wherever it is stored—ConfigMap, LaunchDarkly, etc.). Document the change in
     the incident ticket.
5. File an incident in the tracker, noting whether rollback required data restores, and ensure
   on-call updates runbook(s) if gaps were discovered.

## Rollback Decision Guide

1. **Identify blast radius** – Determine whether failure is stateless (code/config) or stateful
   (data migrations, backfills). Stateless issues default to revision rollback.
2. **Select action**:
   - *Stateless regression*: switch traffic to previous revision, invalidate CDN caches if
     applicable, monitor 15 minutes.
   - *Config/secrets error*: revert Secret Manager version, redeploy with corrected env vars.
   - *Data mutation gone wrong*: pause traffic (set `--to-revisions PREVIOUS=100,NEW=0`),
     restore data export, re-run verifications before reintroducing newer revision.
3. **Verify** – Always run `/healthz`, manual QA scenario, and check primary dashboard before
   resuming frozen deploys.
4. **Record** – Append lessons learned + concrete checklist updates to this doc (see below).

## Checklist Template for Future Updates

```
### <Environment Name>
- Pre-flight:
  - [] Item 1
  - [] Item 2
- Deployment:
  1. Step...
  2. Step...
- Rollback:
  - Command reference
  - Owner + verification steps
- Post-release notes to capture metrics + retrospectives
```

When a retro uncovers missing safeguards, add new checklist items above and cross-reference
the related incident or PR so future releases inherit the learning.
