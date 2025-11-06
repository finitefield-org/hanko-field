# Implement retry/backoff strategy and dead-letter handling for background workers.

**Parent Section:** 9. Background Jobs & Scheduling
**Task ID:** 111

## Purpose
Define retry/backoff policies and dead-letter queues for background jobs to ensure resilience.

## Implementation Steps
1. Standardize retry configuration (exponential backoff, max attempts) per job type.
2. Configure Pub/Sub subscription dead-letter topics; implement handler to surface alerts when messages land there.
3. For Cloud Run jobs, implement manual retry/cron schedule and stateful tracking.
4. Document policies and integrate with logging/metrics (retry count, DLQ size).
5. Tests verifying retry wrappers with mocked failures.

## Completion Notes
- Added default subscription policies in `api/internal/jobs/policy.go`; AI/invoice/export workers now apply exponential backoff (5s→2m, 10s→5m, 15s→10m respectively) with dead-letter topics (`*-jobs-dlq`) and bounded delivery attempts.
- `runtime.Options` enforces subscription retry/dead-letter configuration on startup, with coverage in `runtime_policy_test.go`.
- Introduced `internal/jobs/deadletter` package and `cmd/jobs/dlq` worker to log/alert when messages land in dead-letter topics; metrics now include delivery attempt attribution.
- Extended job metrics to tag outcomes with delivery attempt counts and record dead-letter occurrences.
- Added unit tests for policy defaults/overrides and dead-letter processor behaviour using mocked sinks.
