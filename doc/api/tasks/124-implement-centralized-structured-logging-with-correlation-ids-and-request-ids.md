# Implement centralized structured logging with correlation IDs and request IDs.

**Parent Section:** 12. Observability & Operations
**Task ID:** 124

## Goal
Ensure logs include correlation IDs and are viewable in centralized dashboards.

## Plan
- Configure log sinks to BigQuery or Splunk if required.
- Enforce log format with request/trace IDs, user IDs, and severity mapping.
- Provide dashboards for error rates and request traces.
- Implement log retention and redaction policies.

## Implementation Notes
- Added a correlation ID middleware that accepts incoming `X-Correlation-ID` values, falls back to the generated request ID, and emits a deterministic ID (ULID) otherwise. The ID is stored on the request context and echoed on the response header for client-side tracing.
- Request loggers now attach both `request_id` and `correlation_id` fields so every downstream log emitted through `requestctx.Logger` inherits the identifiers automatically.
- Structured errors continue to expose the `request_id`, while correlation IDs are visible through logs and headers for cross-service debugging.

## Verification
- `go test ./api/internal/platform/observability`
