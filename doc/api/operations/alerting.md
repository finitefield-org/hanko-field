# API Alerting Policies

Cloud Monitoring is the source of truth for API run-time alerting. This document captures
the policies, thresholds, runbooks, and synthetic test flows for the top reliability risks
called out in Observability section 12 (webhook retries, stock reservation errors, payment
reconciliation mismatches).

## Notification Channels

- **Slack `#ops-alerts`** – noisy-but-actionable channel for engineering on-call and support.
- **PagerDuty `api-critical` service** – paged for Sev-1/Sev-2 policies (webhooks + reservation).
- **Email `ops@hanko-field.com`** – informational copies for on-call handoff digests.

Notification channel IDs live in the secure parameter store (`monitoring_channels.yaml`);
Cloud Monitoring policies reference the IDs directly so that environments can map to their
own Slack workspace or PagerDuty service without code changes.

## Signal Reference

| Signal | Metric / Source | Instrumentation owner |
| --- | --- | --- |
| Webhook failures (5xx responses under `/webhooks/*`) | `workload.googleapis.com/http/server/errors` + `http.server.requests` filtered by `http.route =~ "/webhooks/%"` and `error.type="server_error"` | `api/internal/platform/observability/http_metrics.go` |
| Stock reservation errors | `workload.googleapis.com/checkout/reservations/failed` + `.../created` | `api/internal/handlers/internal_checkout.go` (`checkoutReservationMetrics`) |
| Payment status mismatches | Log-based metric `logging.googleapis.com/user/payments_mismatch_count` built from `jsonPayload.event="checkout.payment_status_unhandled"` | `api/internal/services/checkout_service.go` |

All metrics inherit `resource.type="monitoring.googleapis.com/ProcessedMetric"` with the
Cloud Run service context via the OpenTelemetry exporter wired in
`api/internal/platform/observability/metrics.go`.

## Alert Policies

### AP-001 Webhook Failure Spike (Sev-1)

- **Definition**: Stripe, shipping, or AI worker webhooks returning ≥5% HTTP 5xx responses for
  five consecutive minutes will cause upstream retries and eventually dead-lettering.
- **SLO**: ≤1% 5xx rate per 15-min window, target 99.5% success.
- **MQL condition**:

```mql
errors = fetch workload.googleapis.com/http/server/errors
| filter resource.service_name = "api-service"
| filter metric.label."http.route" =~ "/webhooks/%"
| filter metric.label."error.type" = "server_error"
| align rate(1m)
| group_by [resource.project_id], sum()

requests = fetch workload.googleapis.com/http/server/requests
| filter resource.service_name = "api-service"
| filter metric.label."http.route" =~ "/webhooks/%"
| align rate(1m)
| group_by [resource.project_id], sum()

ratio = errors / requests
| condition gt(val(), 0.05)
```

- **Policy**: Alert when `ratio` breaches `0.05` for **5 minutes** (2 bad windows) with
  `auto_close_after = 30m`. Attach PagerDuty (`api-critical`) + Slack notifications. Include
  runbook link (section “Webhook Failure Runbook” below) and labels `severity=sev1`,
  `service=api`.

#### Runbook

1. Open Cloud Logging with filter
   `resource.type="cloud_run_revision" jsonPayload.httpRequest.requestUrl=~"/webhooks/"`.
2. Distinguish between `webhooks.security` denials (blocked networks) and handler failures.
3. For signature/secret issues (503 with `webhook_secret_unavailable`), verify Secret Manager
   version for `API_PSP_STRIPE_WEBHOOK_SECRET` and redeploy Cloud Run to pick up the value.
4. For handler failures (500/503), inspect the `payments` or `ai` service logs for panics.
   Roll back the previous deployment if incident coincides with a new release.
5. Once mitigated, reprocess dead letters via `/admin/system/errors` retry controls.

#### Synthetic test

1. In **stg**, add a temporary blank Secret Manager version for
   `hanko-field-stg-stripe_webhook_secret` and mark it as the primary version (keep the real
   version noted).
2. Send a test webhook through the Stripe CLI:
   `stripe trigger payment_intent.succeeded --forward-to https://stg.api.hanko-field.com/webhooks/payments/stripe`.
   The handler will return HTTP 503 because the secret resolver returns empty.
3. Monitor the Alerting policy detail page to confirm it enters “in preview” within ~2 minutes,
   then revert the secret to the prior version to clear the incident.

### AP-002 Stock Reservation Error Rate (Sev-2)

- **Definition**: Spikes in inventory reservation failures usually mean catalog data drift or
  stale safety stock; alert when ≥10% of reservation attempts fail or when there are ≥20
  failures per minute for 3 consecutive minutes.
- **MQL condition**:

```mql
fail = fetch workload.googleapis.com/checkout/reservations/failed
| filter resource.service_name = "api-service"
| align rate(1m)
| group_by [metric.label."reason"], sum()

create = fetch workload.googleapis.com/checkout/reservations/created
| filter resource.service_name = "api-service"
| align rate(1m)
| group_by [], sum()

ratio = (fail | join(create, value_on_left: "val", value_on_right: "val"))
| value val(0) / val(1)
| condition gt(val(), 0.10)

absolute = fail | condition gt(val(), 20)
```

- **Policy**: single alert with two conditions (ratio OR absolute). Notify Slack + PagerDuty
  (Sev-2). Document runbook link “Stock Reservation Runbook”.

#### Runbook

1. Hit `/api/v1/internal/checkout/reservations` via the admin service account to inspect
   current reservation backlog and reasons (`invalid_state`, `insufficient_stock`, etc.).
2. Inspect Firestore `inventory` documents for affected SKUs; verify `onHand`, `reserved`,
   and TTL cleanup job status.
3. If the reason is `insufficient_stock`, trigger the maintenance endpoint to release expired
   reservations:
   ```bash
   curl -X POST "$API_BASE/api/v1/internal/maintenance/cleanup-reservations" \
     -H "Authorization: Bearer $(gcloud auth print-identity-token --audiences=$API_OIDC_AUDIENCE)"
   ```
4. For catalog mistakes, patch the SKU via `/admin/inventory` and rerun checkout to confirm.
5. Close the incident after error rate falls below 5% for 15 minutes.

#### Synthetic test

1. Use a staging cart containing `SKU-TEST-001` with on-hand quantity set to 1.
2. Call the internal checkout reserve endpoint requesting quantity `999`:
   ```bash
   TOKEN=$(gcloud auth print-identity-token --audiences=$API_OIDC_AUDIENCE)
   curl -X POST "$API_BASE/api/v1/internal/checkout/reservations" \
     -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"user_id":"user-test","cart_id":"cart-test","lines":[{"sku":"SKU-TEST-001","product_id":"prod-test","quantity":999}]}'
   ```
3. Confirm the response is `409 insufficient_stock` and watch the `checkout.reservations.failed`
   time series spike in Metrics Explorer before acknowledging the synthetic alert.

### AP-003 Payment Reconciliation Mismatch (Sev-3)

- **Definition**: Whenever the checkout service receives a PSP status it cannot map to an
  internal state (`checkout.payment_status_unhandled`) we risk orders being stuck between
  “pending” and “paid”. Track every occurrence and alert immediately.
- **Log-based metric**: create `payments_mismatch_count` in Cloud Logging:

```bash
gcloud logging metrics create payments_mismatch_count \
  --description="Checkout payment status mismatches (jsonPayload.event=checkout.payment_status_unhandled)" \
  --log-filter='resource.type="cloud_run_revision"
    AND resource.labels.service_name="api-service"
    AND jsonPayload.event="checkout.payment_status_unhandled"'
```

- **Alert condition**: `fetch logging.googleapis.com/user/payments_mismatch_count
  | align rate(5m) | condition gt(val(), 0)` with `duration = 0m` (fire on first event) and
  notification to Slack only (Sev-3).

#### Runbook

1. Capture the **userId**, **cartId**, and PSP status from the alert/underlying log entry
   (`jsonPayload.userID`, `jsonPayload.cartID`, `jsonPayload.status`). These are the only
   structured fields emitted by `checkout.payment_status_unhandled`.
2. Retrieve the checkout metadata from the user’s cart (Firestore doc `carts/{userId}` or the
   internal carts admin endpoint) and record the stored `checkout.intentId`, `checkout.orderId`,
   and reservation ID if present.
3. Query the admin orders API (if `orderId` exists) or the carts admin API to confirm the API’s
   current understanding of the payment:
   ```bash
   curl -s -H "Authorization: Bearer $TOKEN" \
     "$API_BASE/api/v1/admin/orders/$ORDER_ID" | jq '.payments'
   ```
4. Compare with Stripe’s source of truth using the intent ID retrieved from the cart metadata:
   ```bash
   stripe payment_intents retrieve "$INTENT_ID"
   ```
5. If Stripe reports `succeeded` but the order/cart remains pending, replay the webhook via
   `stripe events resend --event $EVENT_ID --webhook-endpoint-id $ENDPOINT_ID` (targeting the
   Cloud Run endpoint) so the payment service reprocesses the payload.
6. For statuses that Stripe marks as `requires_action` or any unexpected enum, add an incident
   note to the order/cart, mute the alert for two hours, and escalate to the payments team to
   determine whether to cancel, capture manually, or write an ad-hoc migration script.

#### Synthetic test

Emit a synthetic log entry so the log-based metric increments without interfering with real
orders:

```bash
gcloud logging write payments-mismatch-test \
  '{"event":"checkout.payment_status_unhandled","orderId":"ord_test","status":"unknown_status","cartID":"cart_test"}' \
  --severity=ERROR \
  --resource=cloud_run_revision:"service_name=api-service,location=asia-northeast1,revision_name=synthetic"
```

The log-based metric will count the entry within ~1 minute; acknowledge the resulting
low-severity alert and delete the test log if desired.

## Policy Creation Workflow

1. Ensure notification channel IDs exist (Slack webhook, PagerDuty service) and are verified:
   `gcloud monitoring channels list`.
2. Author the alert policy JSON (see `infra/terraform` or export via `gcloud monitoring policies describe`).
3. Apply via Terraform once the module lands; for manual bootstrap use
   `gcloud monitoring policies create --policy-from-file webhooks_alert.json`.
4. Record the policy ID in the on-call checklist and link it back to this document.

## Verification Checklist

- [ ] Run each synthetic test quarterly (tracked via on-call calendar); paste screenshots in
      the on-call log.
- [ ] Keep this document in sync with Terraform definitions and add new runbooks for future
      alerting requirements.
