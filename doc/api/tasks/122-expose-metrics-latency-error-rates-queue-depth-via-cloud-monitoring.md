# Expose metrics (latency, error rates, queue depth) via Cloud Monitoring.

**Parent Section:** 12. Observability & Operations
**Task ID:** 122

## Goal
Publish application metrics (latency, error rate, queue depth) to Cloud Monitoring.

## Plan
- Integrate OpenTelemetry metrics exporter for HTTP server and custom domain metrics.
- Instrument key operations (checkout, AI queue, background jobs) with counters/histograms.
- Define metric naming conventions and labels (environment, endpoint, status).
- Provide `/metrics` endpoint if using Prometheus-to-Cloud Monitoring bridge.

---

## Implementation Summary (2025-10-05)

- Added a Cloud Monitoring exporter bootstrap (`api/internal/platform/observability/metrics.go`) that builds an OTel `MeterProvider` with Cloud project metadata, attaches service/resource attributes, and is initialised from `cmd/api/main.go` using the runtime build info/environment. The API process now flushes metrics during shutdown so Cloud Monitoring receives the final batch.
- Introduced HTTP server instrumentation (`api/internal/platform/observability/http_metrics.go`) that records `http.server.latency` (histogram, ms), `http.server.requests`, and `http.server.errors` counters keyed by method, chi route, and status class. The middleware wraps the entire chi stack (`observability.HTTPMetricsMiddleware`) so latency/error metrics match end-to-end request handling.
- Implemented production queue depth telemetry (`api/internal/platform/observability/queue_metrics.go`) plus the `services.QueueDepthRecorder` contract. `services.productionQueueService.QueueWIPSummary` now snapshots queue totals/status buckets and feeds the observable gauge `operations.production_queue.depth`, enabling Cloud Monitoring charts for queue health once the repository is wired.
- Hardened tests: new coverage for queue depth recording (`production_queue_service_test.go`) and ensured `go test ./api/...` continues to pass with the exporter enabled.

## Metrics Surface

| Metric | Type | Labels | Description |
| --- | --- | --- | --- |
| `http.server.latency` | Histogram (`ms`) | `http.method`, `http.route`, `http.status_code`, `http.status_class` | End-to-end latency for all HTTP requests. |
| `http.server.requests` | Counter | Same as above | Request volume per method/route/status (use Cloud Monitoring filters for error rates). |
| `http.server.errors` | Counter | `error.type ∈ {client_error,server_error}`, `http.method`, `http.route`, `http.status_code`, `http.status_class` | Explicit error-rate signal split by client/server origin. |
| `operations.production_queue.depth` | Observable gauge (`{work_items}`) | `queue.id`, `queue.status ∈ {total,…}` | Snapshot of production queue WIP buckets captured whenever `/production-queues/{id}/wip` is calculated (stale entries aged out after 5 minutes). |

All instruments inherit resource attributes (`service.name`, `service.version`, `deployment.environment`, `gcp.project_id`) from the shared meter provider initialised in `cmd/api/main.go`.

## Verification

1. Run unit tests: `cd api && go test ./...`.
2. Local sampling: hit any endpoint (e.g., `/healthz`) and confirm metrics flush without panics in logs.
3. Cloud Monitoring check (after deploy): `gcloud monitoring metrics list --project $GCP_PROJECT_ID --filter 'metric.type="workload.googleapis.com/http/server/latency"'` (replace with the metric type you are charting) shows the exported workload metrics.

## Follow-ups
- [ ] Wire the production queue repository + handler so the depth gauge is populated continuously.
- [ ] Backfill additional domain metrics (checkout, AI jobs) now that the exporter and plumbing are in place.
