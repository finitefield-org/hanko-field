# API Security Review – 2025-11-07

## Scope & Participants
- **Scope:** API service (`api`), Cloud Run delivery pipeline, inbound webhooks, internal maintenance endpoints, and dependency secrets touching PSPs and AI workers.
- **Artifacts reviewed:** runtime config (`api/internal/platform/config`, `doc/api/configuration.md`), OIDC/HMAC middleware in `api/cmd/api/main.go`, infrastructure Terraform, RBAC design (`doc/api/security/rbac.md`), and webhook handlers.
- **Participants:** Platform (runtime + Terraform), Security (review lead), Backend (owners for webhook + auth), SRE (firewall/ingress), Compliance (threat modeling).

## Executive Summary
- HMAC handling is multi-tenant aware and Secret Manager–backed, but we lacked an automated cadence + monitoring for rotation events. We designed a quarterly rotation workflow with Pub/Sub-triggered cache busting and audit log checkpoints.
- OAuth/OIDC scopes are defined (Firebase roles + custom scopes) and enforced by middleware, yet two service accounts (`api_runtime`, `ai_worker`) carry broader IAM roles than necessary. We documented least-privilege targets and created Terraform follow-ups.
- Cloud Run currently exposes `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` and relies on IP allowlists + HMAC for `/webhooks/*`, but no Cloud Armor policy or IAP binding guards the external HTTPS LB. We prescribed armor policy + VPC-SC steps.
- Threat modeling highlighted three priority attack paths (stolen webhook secret, SSRF into internal endpoints, staff token over-scoping). Mitigations exist but monitoring gaps remain; we added explicit detection tasks.

## Detailed Findings & Decisions

### 1. HMAC Secret Rotation & Observability
**What we validated**
- `config.Security.HMAC.Secrets` drives per-integration HMAC material and feeds middleware builders (`api/internal/platform/config/config.go:132-155`, `api/cmd/api/main.go:816-844`).
- Secrets flow through `secret://` references with cache invalidation hooks described in `doc/api/configuration.md:66-84`.
- Webhook middleware enforces nonce+timestamp and per-carrier CIDR/IP allowlists before handler execution (`api/cmd/api/main.go:550-595`).

**Gaps / Risks**
- No owner/schedule defined for rotating `API_SECURITY_HMAC_SECRETS`; the runbook exists but is not executed.
- Missing alerting on failed secret fetches or replay-store saturation (attack signal).
- Carrier secrets currently stored as a single Secret Manager entry per environment; compromise of one provider would force a broad rotation.

**Actions**
1. Split secrets into `secret://webhooks/<carrier>` entries and enforce requirement via `config.WithRequiredSecrets` (backend, 2025-11-14).
2. Wire Pub/Sub `secrets-rotation` topic to call `Fetcher.Notify` and emit audit logs each time `secret://webhooks/*` invalidates (platform, 2025-11-21).
3. Add Cloud Monitoring alert on `webhook.replay.detected` metric spikes + `secrets.fetch.errors` >=5/min (SRE, 2025-11-28).

### 2. OAuth/OIDC Scopes & Service Accounts
**What we validated**
- Firebase role/scopes and endpoint permissions are codified in `doc/api/security/rbac.md:5-82` and enforced by middleware hooking into `handlers.MustHave(...)`.
- Cloud Scheduler jobs invoke internal endpoints using Google-signed OIDC tokens with per-env audiences set via Terraform (`infra/terraform/main.tf:108-141`, `infra/terraform/envs/*/terraform.tfvars`).
- OIDC validator caches Google JWKS and enforces issuer/audience (`api/cmd/api/main.go:800-813`, `api/internal/platform/auth/oidc.go:372-519`).

**Gaps / Risks**
- `api_runtime` SA still has `roles/storage.objectAdmin` though only object read+signed URLs are necessary (`infra/terraform/variables.tf:160-191`).
- `ai_worker` lacks a constrained Pub/Sub scope (subscriber only) but no per-topic bindings—risk of lateral movement.
- OAuth scopes for staff temporary elevation are manual; no automated expiry for emergency grants.

**Actions**
1. Reduce `api_runtime` to `roles/storage.objectViewer` + scoped signed-URL key; move writes to Cloud Build SA (platform, 2025-11-30).
2. Replace broad Pub/Sub project role with topic-level IAM (`ai_jobs`, `ai_jobs_dlq`) and add org policy preventing extra grants (SRE, 2025-12-05).
3. Implement time-bound custom claims pipeline (expiresAt stored in Firestore) and add QA test case to ensure stale scopes are rejected (backend, 2025-12-12).

### 3. Firewall, Cloud Armor, and Ingress Controls
**What we validated**
- Cloud Run ingress is limited to internal LB by default (`infra/terraform/variables.tf:46-58`, `infra/terraform/modules/cloud_run_service/main.tf:1-50`). External traffic lands via HTTPS LB/IAP (yet to be codified here) before forwarding internally.
- Webhooks additionally gate on CIDR allowlists + replay detection as noted above.

**Gaps / Risks**
- No Cloud Armor security policy is attached to the HTTPS LB; volumetric protection and geo/IP rules missing.
- IAP is configured for internal maintenance paths but not for staff/admin web surfaces served via the same LB.
- Firewall rules for the Serverless VPC connector allow full egress; we need egress firewall tiers restricting Firestore and Stripe endpoints only.

**Actions**
1. Create Terraform module to attach Cloud Armor policy with the following controls: allow partner CIDRs, block Tor/anonymizers, rate-limit `/api/v1/webhooks/*` at 50 rps, challenge suspicious IPs (SRE, 2025-12-03).
2. Enforce IAP on the HTTPS LB backend service serving `/admin` + `/api/v1/internal/*`; update CI smoke tests to require `X-Goog-Authenticated-User-Email` header (platform, 2025-11-24).
3. Update Serverless VPC connector firewall rules to only allow egress to Firestore, Secret Manager, Stripe, DHL/UPS endpoints; log-deny everything else (network, 2025-12-10).

### 4. Threat Modeling Highlights
| Threat | Entry Point | Likelihood | Impact | Mitigations | Residual Action |
| --- | --- | --- | --- | --- | --- |
| Stolen webhook secret reused for replay | Carrier webhook endpoints | Medium | High | HMAC validator + nonce/timestamp + CIDR checks (`api/cmd/api/main.go:816-879`) | Add SIEM detection on `webhook.replay.detected` spikes (Action 1.3). |
| Compromised scheduler SA invokes privileged internal APIs | Cloud Scheduler → `/api/v1/internal/*` | Low | High | OIDC validator w/ env-specific audiences & RBAC `system.run` gate | Rotate scheduler SA key quarterly and log `ServiceIdentity` claims (Action 2.3). |
| Staff custom claims over-provisioned (no expiry) | Firebase Auth scopes | Medium | Medium | Manual issuance + audit logs | Automate expiry + nightly job to strip stale scopes (Action 2.3). |
| LB exposed to internet without WAF | HTTPS LB → Cloud Run | Medium | High | Currently only ingress=internal LB; but LB lacks Armor | Attach Cloud Armor + IAP (Actions 3.1 & 3.2). |

## Action Tracker
| # | Item | Owner | Target Date | Status |
| -- | ---- | ----- | ----------- | ------ |
| 1 | Split webhook secrets per carrier + enforce required Secret Manager entries | Backend | 2025-11-14 | Pending |
| 2 | Hook Pub/Sub rotation topic + audit logging | Platform | 2025-11-21 | Pending |
| 3 | Alert on webhook replay/secrets fetch anomalies | SRE | 2025-11-28 | Pending |
| 4 | Reduce `api_runtime` IAM surface | Platform | 2025-11-30 | Pending |
| 5 | Topic-level IAM for `ai_worker` SA | SRE | 2025-12-05 | Pending |
| 6 | Time-bound custom claim issuance + QA test | Backend | 2025-12-12 | Pending |
| 7 | Attach Cloud Armor policy to HTTPS LB | SRE | 2025-12-03 | Pending |
| 8 | Enforce IAP on admin/internal backends | Platform | 2025-11-24 | Pending |
| 9 | Tighten Serverless VPC egress firewall rules | Network | 2025-12-10 | Pending |
