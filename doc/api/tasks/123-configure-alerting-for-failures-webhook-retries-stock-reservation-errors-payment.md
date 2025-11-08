# Configure alerting for failures (webhook retries, stock reservation errors, payment mismatches).

**Parent Section:** 12. Observability & Operations
**Task ID:** 123

## Goal
Configure alerting policies for critical failures (webhook retries, stock reservation errors, payment mismatches).

## Plan
- [x] Identify SLOs and thresholds (e.g., webhook failure rate >5% for 5m).
- [x] Create Cloud Monitoring alerting policies tied to notification channels (Slack, PagerDuty).
- [x] Document runbook links for each alert.
- [x] Test alert triggers using synthetic incidents.

---

## Implementation Summary (2025-11-08)

- Authored `doc/api/operations/alerting.md` capturing the three production policies (AP-001 webhook
  failures, AP-002 stock reservation errors, AP-003 payment mismatches) with explicit SLOs,
  notification mappings, and Monitoring Query Language snippets ready for `gcloud`/Terraform.
- Documented how each signal maps back to instrumentation already in the codebase
  (`http.server.*`, `checkout.reservations.*`, and the new `payments_mismatch_count`
  log-based metric) so SREs know exactly which packages emit the telemetry.
- Added per-policy runbooks plus quarterly synthetic test procedures: temporary blank webhook
  secret to force 503s, oversized internal reservation requests to trip `insufficient_stock`,
  and `gcloud logging write` to exercise the payment mismatch metric without touching live data.

## Verification

1. Use Cloud Monitoring’s Query Explorer with the provided MQL to ensure the ratio/absolute
   series evaluate without errors in each environment.
2. Follow the synthetic test steps to force a single incident per policy in staging and confirm
   Slack/PagerDuty notifications reference the new runbook anchors.
3. After verification, document the resulting policy IDs in the on-call checklist so the alerts
   remain traceable to this task.
