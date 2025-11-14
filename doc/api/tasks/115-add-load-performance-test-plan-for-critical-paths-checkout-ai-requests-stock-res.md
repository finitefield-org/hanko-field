# Add load/performance test plan for critical paths (checkout, AI requests, stock reservations).

**Parent Section:** 10. Testing Strategy
**Task ID:** 115

## Scope
Define approach for load testing critical paths (checkout, AI requests, stock reservations).

## Objectives
- Validate that end-to-end checkout, AI request handling, and stock reservation flows sustain projected peak traffic + 30% headroom without breaching SLOs.
- Identify bottlenecks (Firestore contention, AI worker latency, Cloud Run autoscaling) before production incidents.
- Provide repeatable scripts and automation that can run on demand and in CI nightly.

## Tooling & Inputs
- Primary load tool: k6 (TypeScript scenarios) with threshold assertions; run via `k6 cloud` for large tests, `k6 run` for local smoke.
- Test data generator: Go helper producing seeded carts/orders and AI prompt payloads, checked into `/api/tools/loadgen`.
- Observability: Cloud Monitoring dashboards for latency/error/Saturation + Firestore indexes; k6 output exported to Influx/JSON for trend comparison.

## Environment & Data
- Target staging environment that mirrors production config (same Cloud Run revisions, IAM, Pub/Sub topics). Autoscaling min instances = production baseline.
- Seed Firestore with 50k products, 10k active customers, 5k open carts; preload AI suggestion cache with 10k prompts to mimic cache hit/miss mix.
- Disable non-essential cron jobs to reduce noise; keep background workers enabled to capture contention.

## Test Scenarios
### 1. Checkout happy path
- Flow: cart pricing → stock reservation → payment intent creation → order commit webhook.
- Load pattern: ramp 0 → 150 RPS over 10 min, sustain 150 RPS for 15 min, spike to 250 RPS for 5 min.
- Dependency mocks: real Stripe test keys, Firestore emulator off (use managed service), Cloud Tasks for async steps.
- Pass criteria: P95 end-to-end latency ≤ 1.8s, error rate < 0.5%, reservation conflicts < 1% automated retries.

### 2. AI design suggestion requests
- Flow: submit prompt → enqueue Pub/Sub job → worker callback webhook updates status + persists asset.
- Load pattern: constant 80 RPS with 20% bursts to 140 RPS every 2 min; job backlog target < 500.
- Include mix of prompt sizes (short 60%, long 30%, max size 10%) to stress storage.
- Pass criteria: worker completion P95 < 12s, webhook failure rate < 1%, storage write errors = 0.

### 3. Stock reservation contention
- Flow: rapid add-to-cart/reserve/release cycles from multiple users per SKU to test hot partitions.
- Load pattern: 500 concurrent virtual users looping with think time 200-400ms, focusing on top 50 SKUs.
- Firestore/Redis metrics monitored for write latency and throttling; simulate 5% network jitter.
- Pass criteria: Firestore write latency P99 < 80ms, reservation deadlocks < 0.2%, automatic retries succeed within 2 attempts.

## Metrics & Reporting
- k6 thresholds (latency, failure rate) enforce pass/fail inside scripts; upload summary JSON to `/reports/perf/YYYYMMDD/`.
- Capture Cloud Monitoring snapshots for CPU, memory, concurrency, Pub/Sub backlog, Firestore throttling, AI worker queue depth.
- Document findings + recommended mitigations (index changes, autoscaling min/max, AI worker pool size) in `doc/api/perf/summary.md`.

## Execution Cadence
- Smoke run per PR touching checkout/AI/stock code paths (short 5 min load).
- Full plan weekly or before major release; rerun after infra config changes.
- Trigger on-demand run post-incident to verify remediation.

## Follow-up & Ownership
- Performance czar (API lead) owns scripts + dashboards, ensures data freshness.
- Create GitHub issue automatically if thresholds fail, linking k6 artifacts and Cloud Monitoring charts.
- Feed insights into capacity planning and SLA review meetings.
