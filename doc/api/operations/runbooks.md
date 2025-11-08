# API On-call Runbooks

This catalog provides actionable runbooks for the API on-call rotation. Each runbook follows
the same structure so that responders can move from detection to resolution quickly. Keep
alert routing (Slack `#ops-alerts`, PagerDuty `api-critical`) and the service directory
handy when executing these playbooks.

## Runbook Template

| Section | Purpose |
| --- | --- |
| **Signal & Severity** | Trace the alert or dashboard signal that engages on-call and state the expected impact surface. |
| **Owners & Dependencies** | Primary service owner plus critical upstream/downstream systems to check. |
| **Detection & Entry Criteria** | Exact metrics, dashboards, or logs that should be red/yellow before paging. |
| **Immediate Actions** | Contain the incident (ack alert, post comms template, capture snapshot links). |
| **Diagnostics** | Ordered checklist for separating transient vs. systemic failures. Always note required tooling. |
| **Mitigation / Workarounds** | Short-term fixes (failover, feature flag, manual replay) to restore service. |
| **Rollback / Recovery** | Steps to revert code/config or drain queues safely. |
| **Verification & Close-out** | Metrics/logs that must return to green plus ticket/notebook updates. |
| **Operational Tasks** | Preventative chores (weekly queue review, monthly secret rotation rehearsal, etc.). |

When adding a new runbook, copy this table, fill in each section with concrete commands (curl,
gcloud, Terraform), and link related alerts from `doc/api/operations/alerting.md`.

---

## Checkout Failure Runbook (Sev-1)

- **Signal & Severity**: `workload.googleapis.com/http/server/errors` ratio >=5% on
  `/checkout/*` routes or HTTP 502/503 spikes surfaced by dashboard `dashboards/api-checkout`.
  Impacts all buyers attempting to start or confirm checkout.
- **Owners & Dependencies**: API checkout service (`api/internal/services/checkout_service.go`),
  Firestore transactions, Stripe API, inventory reservations, and Firebase Auth. Coordinate
  with payments/product support immediately.

### Detection & Entry Criteria

1. Alert AP-CHK-001 (Checkout 5xx spike) in Cloud Monitoring, or an auto page from synthetic
   checkout path (Cloud Scheduler job `synthetic-checkout`) failing twice.
2. Manual confirmation via:
   ```bash
   gcloud monitoring time-series list \
     --filter='metric.type="workload.googleapis.com/http/server/errors" AND metric.labels.http_route=~"/checkout/%"' \
     --alignment_period=60s --per_series_aligner=ALIGN_RATE
   ```
3. Check `stripe_status` component on the external status page; if Stripe is down, expect
   cascading failures and tag the incident as `dependency=psp`.

### Immediate Actions

1. Acknowledge PagerDuty incident; post template in `#ops-alerts` with current impact window.
2. Freeze deployments: notify release channel and apply `traffic=0` to any in-progress rollout.
3. Capture links to Cloud Run revision metrics and Firestore error dashboard for the timeline.

### Diagnostics

1. **Config drift** - Run `kubectl` equivalent? (No, Cloud Run) use:
   ```bash
   gcloud run services describe api-service --region=asia-northeast1 --format="value(status.trafficPercent,tags)"
   ```
   Ensure latest revision matches release notes.
2. **Dependency health** - Check Stripe latency via `stripe status` or vendor dashboard; monitor
   Firestore errors via `Database Errors` chart (`Firestore 5xx`).
3. **Application logs** - Filter Cloud Logging:
   ```
   resource.type="cloud_run_revision"
   AND resource.labels.service_name="api-service"
   AND jsonPayload.httpRequest.requestUrl=~"/checkout/"
   AND severity>=ERROR
   ```
   Pay close attention to `checkout.session.create_failed`, `checkout.confirm.tx_failed`,
   or `checkout.payment_status_unhandled`.
4. **Inventory coupling** - If failures originate from reservation timeouts, inspect
   `/api/v1/internal/checkout/reservations` and verify TTL cleanup job results.

### Mitigation / Workarounds

1. **Rollback** - Shift 100% traffic to the previous healthy revision:
   ```bash
   gcloud run services update-traffic api-service \
     --region=asia-northeast1 \
     --to-revisions PREVIOUS_REVISION=100
   ```
2. **Disable optional features** - Toggle feature flags (ConfigMap/Secret or env) via redeploy:
   - `API_FEATURE_AISUGGESTIONS=false` to remove AI latency from checkout UI.
   - If PSP timeouts, set `API_CHECKOUT_USE_SYNC_CAPTURE=false` (if configured) to fall back to
     auth-only flows.
3. **Manual reservation cleanup** - Run maintenance endpoint to release stuck reservations
   (prevents cascading failures):
   ```bash
   TOKEN=$(gcloud auth print-identity-token --audiences=$API_OIDC_AUDIENCE)
   curl -X POST "$API_BASE/api/v1/internal/maintenance/cleanup-reservations" \
     -H "Authorization: Bearer $TOKEN"
   ```

### Rollback / Recovery

1. Once a stable revision is serving traffic, rerun the synthetic checkout Cloud Scheduler job
   (`synthetic-checkout`) or follow the "Stripe session retry" QA scenario in
   `doc/api/manual_qa.md`.
2. If Firestore indexes were updated during the faulty deploy, revert the Terraform change or
   disable the new index via console to remove contention.
3. Document any carts/orders touched manually in the incident document and reconcile later.

### Verification & Close-out

- HTTP 5xx ratio on `/checkout/*` <1% for 30 minutes.
- Firestore `Document write` error budget restored (no `RESOURCE_EXHAUSTED`).
- Synthetic checkout job succeeds twice consecutively.
- Postmortem issue created with links to relevant logs/dashboards; alert closed.

### Operational Tasks

- Weekly: audit Cloud Run min/max instances for `api-service` to guarantee headroom (target
  min=3, max=20 in prod).
- Before every release: capture a Cloud Monitoring dashboard snapshot for "Checkout health"
  and store the link in the ops journal.
- Quarterly: rehearse PSP failover by pointing staging to Stripe test outage toggles.

---

## Webhook Backlog Runbook (Sev-1/2)

- **Signal & Severity**: Pub/Sub subscription `webhook-retry-sub` shows
  `num_undelivered_messages > 50` for 5 minutes or `oldest_unacked_message_age > 300s`.
  Severity escalates to Sev-1 when backlog exceeds 250 (risking PSP retries timing out).
- **Owners & Dependencies**: Webhook processors inside the API service + background retry
  worker (`cmd/jobs/webhook_retry`), Stripe/shipping/AI webhook providers, Pub/Sub, Secret
  Manager for webhook secrets.

### Detection & Entry Criteria

1. Alert AP-WBH-002 (configured via Terraform) fires when backlog or age crosses thresholds.
2. Dashboard `dashboards/api-webhooks` highlights processing latency >60s.
3. Cloud Logging contains `webhooks.retry.enqueue_failed` or `webhooks.retry.dlq`.

### Immediate Actions

1. Acknowledge alert, post backlog counts in `#ops-alerts`, and notify affected external teams
   (payments, shipping).
2. Confirm whether providers already started retrying or threatening to pause webhooks.
3. If backlog >250, start manual drain procedure immediately (see Mitigation).

### Diagnostics

1. **Worker health** - Inspect Cloud Run job:
   ```bash
   gcloud beta run jobs executions list --job="webhook-retry" --region=asia-northeast1
   gcloud beta run jobs executions describe EXECUTION_ID
   ```
   Ensure latest execution succeeded and concurrency >0.
2. **Message mix** - Sample backlog:
   ```bash
   gcloud pubsub subscriptions pull projects/$PROJECT/subscriptions/webhook-retry-sub \
     --limit=5 --auto-ack
   ```
   Identify provider causing retries.
3. **Secret issues** - If payloads fail signature validation, check Secret Manager versions for
   `API_PSP_STRIPE_WEBHOOK_SECRET` and other HMAC secrets.
4. **Rate limits** - Verify `API_RATELIMIT_WEBHOOK_BURST` isn't throttling providers after
   traffic spikes; adjust temporarily if necessary.

### Mitigation / Workarounds

1. **Scale workers** - Increase Cloud Run job parallelism:
   ```bash
   gcloud beta run jobs update webhook-retry \
     --region=asia-northeast1 \
     --max-retries=3 --tasks=10 --task-timeout=600s
   gcloud beta run jobs execute webhook-retry --region=asia-northeast1
   ```
2. **Warm API instances** - Raise API min instances to absorb inbound webhook traffic.
3. **Replay failed messages** - After processor fix, pull messages from DLQ topic
   `webhook-retry-dlq` and re-publish:
   ```bash
   gcloud pubsub subscriptions pull webhook-retry-dlq-sub --limit=10 > dlq.json
   # sanitize payloads, then
   gcloud pubsub topics publish webhook-retry --message="$(cat msg.json)"
   ```
4. **Provider coordination** - If backlog due to upstream flood, ask provider to pause retries
   or reduce batch size temporarily.

### Rollback / Recovery

1. When backlog <10 and `oldest_unacked_message_age < 60s`, resume normal scaling limits.
2. Document any messages replayed manually; store IDs in the incident doc.
3. Re-enable upstream retries if they were paused.

### Verification & Close-out

- Pub/Sub backlog steady <10 for 30 minutes.
- Webhook processing latency chart back within SLO (p95 <30s).
- No new `webhooks.retry.dlq` entries in Cloud Logging.
- Terraform state updated if scaling adjustments need permanence.

### Operational Tasks

- Daily business days: check Pub/Sub backlog dashboard (timebox 2 minutes).
- Weekly: pull five messages from `webhook-retry-dlq-sub` (discard after inspection) to ensure
  the worker can still decode payloads end-to-end.
- Quarterly: rotate webhook signing secrets, verifying the downtime-free procedure using
  staging first.

---

## Stock Reservation Anomaly Runbook (Sev-2)

This expands on AP-002 in `alerting.md`.

- **Signal & Severity**: `checkout.reservations.failed` ratio >=10% or absolute failures >=20/min.
  Impacts ability to place orders and might cascade into checkout failures.
- **Owners & Dependencies**: Inventory service, Firestore `inventory` + `stockReservations`
  collections, maintenance cleanup job, admin tooling.

### Detection & Entry Criteria

1. Alert AP-002 triggered (see `doc/api/operations/alerting.md#ap-002-stock-reservation-error-rate-sev-2`).
2. Manual validation via:
   ```bash
   gcloud monitoring time-series list \
     --filter='metric.type="workload.googleapis.com/checkout/reservations/failed"' \
     --alignment_period=60s --per_series_aligner=ALIGN_RATE
   ```
3. Admin UI `Inventory > Reservation Backlog` page shows spikes or stale reservations.

### Immediate Actions

1. Announce in `#ops-alerts`; ask merch/fulfillment if any bulk uploads happened.
2. Run read-only diagnostics to capture top failing SKUs via Firestore export or the
   BigQuery mirror (`inventory_failures` table) if available; attach the CSV to the incident
   doc.

### Diagnostics

1. **Reason codes** - Call internal endpoint:
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     "$API_BASE/api/v1/internal/checkout/reservations?reason=insufficient_stock&limit=50"
   ```
2. **TTL cleanup** - Inspect Cloud Scheduler job `cleanup-reservations` last run.
3. **Catalog integrity** - Compare `inventory.onHand` vs. `products.stockQuantity`; ensure
   admin changes propagated (check Pub/Sub `catalog-updates` topic if exists).
4. **Firestore contention** - Look for `ABORTED` errors in Cloud Logging,
   `jsonPayload.error.code=10`.

### Mitigation / Workarounds

1. Run maintenance cleanup if expired reservations pile up (command shown earlier).
2. Patch offending SKUs via admin console or direct Firestore update (document changes).
3. For global incidents, temporarily relax cart quantity checks by setting
   `API_CHECKOUT_RESERVATION_MODE=best_effort` (requires redeploy) so buyers can complete
   orders, then reconcile inventory manually.

### Rollback / Recovery

1. After catalog fixes, revert any temporary config overrides.
2. Monitor `checkout.reservations.failed` for 30 minutes to ensure ratio <5%.
3. Trigger synthetic reservation test (documented in `alerting.md`) to prove path works.

### Verification & Close-out

- KPI dashboards show normal conversion again.
- Incident doc lists SKUs adjusted and cleanup job IDs.
- Support confirmed no new reservation complaints.

### Operational Tasks

- Daily: ensure cleanup scheduler succeeded (Ops checklist item).
- Weekly: spot-audit top 20 SKUs for `onHand - reserved` drift.
- Monthly: rehearse manual inventory import rollback procedure.

---

## AI Worker Delay Runbook (Sev-2)

- **Signal & Severity**: Pub/Sub topic `ai-jobs` backlog >200 messages or
  `jobs.worker.latency.p95 > 90s` (Observability SLO). Affects AI design suggestions reaching
  users; SLA target is <90s round-trip.
- **Owners & Dependencies**: AI dispatcher (`api/internal/jobs/ai_dispatcher.go`), AI worker
  Cloud Run jobs (`cmd/jobs/ai-worker`), external AI vendor endpoint (`API_AI_SUGGESTION_ENDPOINT`),
  Cloud Storage `ai_suggestions` bucket.

### Detection & Entry Criteria

1. Alert AP-AI-004 triggered (Pub/Sub backlog or latency).
2. Dashboard `dashboards/api-ai` shows p95 latency >90s or DLQ count >0.
3. AI worker logs contain `ai.jobs.send_failed` or `ai.jobs.vendor_timeout`.

### Immediate Actions

1. Page acknowledged, inform product/design teams that AI suggestions are delayed; set
   expectation on user impact (feature is additive; severity still Sev-2 due to SLA).
2. Pause optional marketing campaigns if they rely on real-time AI outputs.

### Diagnostics

1. **Queue inspection** - Pull sample message:
   ```bash
   gcloud pubsub subscriptions pull ai-jobs-sub --limit=1 --auto-ack
   ```
   Ensure payload schema still matches worker expectations.
2. **Worker scaling** - Check Cloud Run job revisions and concurrency:
   ```bash
   gcloud beta run jobs describe ai-worker --region=asia-northeast1
   ```
3. **Vendor health** - Hit health endpoint:
   ```bash
   curl -H "Authorization: Bearer $API_AI_AUTH_TOKEN" "$API_AI_SUGGESTION_ENDPOINT/healthz"
   ```
4. **Storage bottlenecks** - Confirm `gs://hanko-field-$ENV-ai_suggestions` is writable
   (`gcloud storage ls gs://...`); look for permission errors in logs.

### Mitigation / Workarounds

1. **Scale out workers** - Increase tasks and parallelism:
   ```bash
   gcloud beta run jobs update ai-worker \
     --tasks=20 --task-timeout=900s --region=asia-northeast1
   gcloud beta run jobs execute ai-worker --region=asia-northeast1
   ```
2. **Bypass vendor** - Toggle feature flag `API_FEATURE_AISUGGESTIONS=false` to hide AI UI
   while backlog drains; redeploy API service if necessary.
3. **Retry stuck jobs** - Move DLQ messages back:
   ```bash
   gcloud pubsub subscriptions pull ai-jobs-dlq-sub --limit=50 --auto-ack > dlq.json
   # sanitize, then re-publish
   gcloud pubsub topics publish ai-jobs --message="$(cat msg.json)"
   ```
4. **Vendor escalation** - If latency due to vendor SLA breach, open ticket with reference IDs
   (include request IDs from `ai.worker.request_id` log field) and throttle dispatch rate via
   config (`AI_DISPATCH_MAX_INFLIGHT` env).

### Rollback / Recovery

1. Once backlog <25 and p95 latency <60s, revert worker scaling to baseline (tasks=5).
2. Re-enable the AI feature flag and re-run the AI suggestion smoke test described in
   `doc/api/manual_qa.md`.
3. Delete any duplicate suggestion blobs created during retries (script in `scripts/ai/prune.sh`).

### Verification & Close-out

- Pub/Sub backlog steady <25 for 30 minutes.
- AI worker log stream free of `vendor_timeout` for 1 hour.
- Product/design stakeholders confirm feature functioning end-to-end.

### Operational Tasks

- Daily: monitor AI latency widget (2 min) and capture anomalies in ops journal.
- Weekly: sample one generated suggestion object from `gs://hanko-field-$ENV-ai_suggestions`
  to ensure schema parity.
- Monthly: refresh AI vendor auth token before expiry; verify runbook instructions stay current.
