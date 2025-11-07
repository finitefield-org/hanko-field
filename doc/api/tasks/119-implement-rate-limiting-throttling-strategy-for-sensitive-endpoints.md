# Implement rate limiting/throttling strategy for sensitive endpoints.

**Parent Section:** 11. Security & Compliance
**Task ID:** 119

## Goal
Implement rate limiting/throttling for sensitive endpoints (login, design AI requests, promotions) to mitigate abuse.

## Plan
- Evaluate Cloud Armor, API Gateway, or in-app token bucket limiter (Redis/Memory) depending on deployment.
- Configure limits per route and per identity (IP/user ID).
- Provide override controls for staff/backoffice operations.
- Instrument metrics for throttled requests.

## Implementation
- Added configurable rate limit slots (`API_RATELIMIT_*`) covering default, authenticated, AI suggestion, registrability, promotion lookup, and login categories plus a shared window duration.
- Wired in-process token bucket limiter + middleware options for AI requests, registrability checks, and public promotion lookups with staff bypass where appropriate.
- Surfaced OpenTelemetry counter (`security.rate_limit.throttled`) to record endpoint + scope whenever throttling occurs.
- Exposed configuration through `cmd/api` so limits can be tuned without redeploying; defaults keep registrability very low (5/min) and AI requests moderate (30/min).

## Status
- [x] Completed
