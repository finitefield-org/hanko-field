# Set up monitoring (logging, metrics, uptime checks) and real user metrics reporting.

**Parent Section:** 9. Performance, Accessibility, and QA
**Task ID:** 051

## Goal
Set up monitoring and RUM.

## Implementation Steps
1. Integrate logging with structured context (request ID, user ID hash).
2. Configure uptime checks for key routes.
3. Add real-user metrics (Core Web Vitals) via analytics platform.

## Outcome
- Added a reusable structured logger (`internal/telemetry`) and ensured all server logs include request IDs, hashed user identifiers, and HTMX context.
- Captured per-request Prometheus metrics with a new `/internal/metrics` endpoint and documented Cloud Monitoring uptime checks in `web/config/monitoring/uptime_checks.yaml`.
- Instrumented the telemetry beacon to stream Core Web Vitals (LCP, FID, CLS, INP, TTFB) through the existing telemetry pipeline.
