# Instrument server metrics (page render time, htmx fragment duration, error rates) and expose to Cloud Monitoring.

**Parent Section:** 16. Observability & Maintenance
**Task ID:** 081

## Goal
Instrument server to emit metrics for Cloud Monitoring.

## Implementation Steps
1. Use OpenTelemetry or expvar to publish latency, error rate, fragment render duration.
2. Add counters for key events (order status change submissions, promotions created).
3. Export metrics to Cloud Monitoring with labels (endpoint, environment).

## Implementation Notes
- Added `internal/admin/observability` with OpenTelemetry meter + Cloud Monitoring exporter. Controlled via `ADMIN_METRICS_*` env vars with environment labels (`ADMIN_ENVIRONMENT`).
- Introduced `Metrics` middleware to measure every handler, tagging request kind (page/fragment), endpoint, and HX target. Latency histograms split between `admin.http.page_render.duration` and `admin.http.fragment.duration` with a shared error counter.
- Orders status updates and promotion creation handlers now emit mutation counters (`admin.orders.status_change.count`, `admin.promotions.created.count`) annotated with result status for Cloud Monitoring dashboards.
