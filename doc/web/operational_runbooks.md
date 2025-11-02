# Web Operational Runbooks

This playbook centralises the day-to-day operational procedures for the Hanko Field web surface. It covers how we respond to production incidents, refresh caches, push SEO updates, and ship content-only changes without full redeploys. Keep this document in sync with the shared workspace (`Notion › Runbooks › Web Ops`) so non-engineering stakeholders always have an accessible reference.

## Scope & Ownership
- **Service:** `web` (Go + templ) running on Cloud Run (`asia-northeast1`).
- **Primary owner:** Web engineering on-call (rotation in PagerDuty schedule `WEB-ONCALL`).
- **Backup:** Platform/SRE on-call (`PLATFORM-PRIMARY`).
- **Business liaison:** Customer Support lead for communicating externally when incidents affect end users.
- **Escalation window:** Acknowledge within 5 minutes, mitigation started within 15 minutes.

## Contacts & Escalation Path
| Severity | Who leads | How to page | Escalate when |
|---|---|---|---|
| SEV1 (checkout down, data loss risk) | Web on-call | PagerDuty `WEB-ONCALL` (auto triggered by uptime checks) | >15 minutes to mitigate or concurrent incident |
| SEV2 (major feature degraded, high error rates) | Web on-call | `#web-ops` Slack `/pd trigger web` | Customer impact persists >30 minutes |
| SEV3 (minor degradation, informational) | Feature owner | Manual Slack update in `#web-ops` | Exceeds 1 business day or escalates in severity |

Additional contacts:
- **Status page updates:** product marketing (`@pm-status`).
- **Legal/comms escalation:** operations director (`@ops-director`) for incidents involving PII or long-lasting outages.
- **Cache/CDN access:** Only engineers in `web-ops` Google Cloud group can run invalidations; submit short-lived IAM grant via Access Request if missing.

## Tooling Cheat Sheet
- **Dashboards:** DataDog `Web › Production Overview`, Grafana `web/traffic`, Google Cloud Trace.
- **Logs:** Cloud Logging `resource.type="cloud_run_revision" AND resource.labels.service_name="hanko-web"`.
- **Deploy/rollback:** `doc/web/deploy.md` for Cloud Run procedures, `doc/web/feature_flag_rollout.md` for toggles.
- **SEO assets:** `web/templates/seo/`, `web/assets/sitemap/`, and CMS guidelines in `doc/web/navigation_seo_map.md`.
- **Cache layer:** Cloud CDN fronting the Cloud Run service via load balancer `web-global-lb` (Terraform module `infra/terraform/modules/cloud_run_service`).

---

## Runbooks

### 1. Incident Response
1. **Triage**
   - Confirm alert details (DataDog, uptime checks, customer support reports).
   - Capture current Cloud Run revision ID and request IDs (`gcloud run services describe hanko-web --region=asia-northeast1 --format='value(status.latestCreatedRevision)'`).
   - Note start time in incident doc (`Notion › Incidents` template).
2. **Stabilise**
   - If a recent deploy correlates (<30 min), trigger rollback: `gcloud run services update-traffic hanko-web --region=asia-northeast1 --to-latest=false --revision <previous-revision>=100`.
   - For flag-related regressions, set emergency override: `HANKO_WEB_FEATURE_FLAG_OVERRIDES="flag=false"` and redeploy config (see feature flag playbook).
   - Capture logs around the failing route: `gcloud logging read 'severity>=ERROR AND resource.labels.service_name="hanko-web"' --freshness=10m`.
3. **Communicate**
   - Post initial incident message in `#incidents` (use template: impact, start time, owner, next update).
   - Trigger Statuspage if SEV1/SEV2 persists >15 minutes or checkout is affected.
4. **Resolve**
   - Validate recovery using smoke tests (`infra/scripts/web_smoke.sh` or GitHub Action workflow dispatch).
   - Confirm error rate back within baseline for 2 consecutive 5-minute windows.
   - Close PagerDuty incident, post final summary, and update Statuspage.
5. **Post-Incident**
   - File retrospective within 48 hours; include root cause, mitigations, backlog tasks.
   - Ensure alerts captured the issue. If not, adjust monitors before closing.

### 2. Cache Purge & CDN Refresh
Use when stale markup/assets appear after deploys, or SEO/marketing requests immediate updates.

Prerequisites:
- IAM role `roles/compute.loadBalancerAdmin` or custom role with `compute.urlMaps.invalidateCache`.
- Latest production artifact deployed (runbook cannot fix missing deploys).

Steps:
1. **Identify scope**
   - Prefer path-scoped invalidations to preserve cache hit rate. Gather list of URLs or prefixes.
   - Confirm content already available from origin (`curl -I https://app.hanko-field.com/<path>` should return `200` with fresh `ETag`).
2. **Issue invalidate**
   ```bash
   gcloud compute url-maps invalidate-cdn-cache web-global-lb \
     --path "/guides/*" \
     --async
   ```
   - For multiple paths, repeat or use `--path "/*"` for full purge (SEV-level only).
3. **Track progress**
   - `gcloud compute operations describe <operation-id>` until `DONE`.
   - Monitor CDN hit/miss dashboards; expect elevated misses temporarily.
4. **Verify**
   - Force refresh (e.g. `curl -H 'Cache-Control: no-cache'`), inspect headers `age: 0`, `x-cache: MISS`.
   - Ask Support to confirm customer-facing fix if they reported the issue.
5. **Document**
   - Log purge details (paths, reason, operator) in `Notion › Runbooks › Cache Purges` for audit trail.

Fallbacks:
- If CDN invalidation fails, disable cache for specific path by setting `Cache-Control: no-store` via feature flag or config until a proper fix arrives.
- For DNS-level caches (e.g. Cloudflare), use respective dashboard; document cross-tool steps in same log entry.

### 3. SEO Metadata & Sitemap Updates
Trigger this runbook when marketing ships new campaigns, updates structured data, or Google Search Console flags issues.

1. **Plan changes**
   - Confirm source of truth: metadata templates live in `web/templates/seo/`, canonical URLs in `doc/web/navigation_seo_map.md`.
   - Identify whether change is content-only (templated copy) or requires code (new partial).
2. **Implement**
   - For simple metadata updates, edit template partials and run `make lint-web` to ensure templ compile succeeds.
   - Update sitemap data (`web/assets/sitemap/*.xml.tmpl`). Regenerate via `go run ./cmd/sitemap`.
3. **Review**
   - Request review from marketing owner (`@pm-seo`) and one engineer.
   - Validate structured data with Google Rich Results test using staging URL.
4. **Deploy**
   - Ship via standard Cloud Run deploy. Tag commit `seo/<yyyy-mm-dd>-<slug>` for traceability.
   - If only sitemap changed, use cache purge runbook for `/sitemap.xml`.
5. **Post-deploy**
   - Verify `Last-Modified` and `ETag` headers changed.
   - Submit updated sitemap in Google Search Console.
   - Update log in `Notion › SEO Updates` with summary, owner, and link to PR.

### 4. Content-Only Deployment / Hotfix
For emergency copy changes or CMS-driven updates that should not wait for the full release cycle.

1. **Eligibility check**
   - Change touches templates, markdown, or localization files only (no Go code or assets requiring rebuild).
   - Tests or lint still pass (`make test-web-light`).
2. **Prepare branch**
   ```bash
   git checkout -b hotfix/content-<slug>
   # edit templates/content
   make test-web-light
   ```
3. **Deploy shortcut**
   - Use `web/cloudbuild.yaml` manual trigger with substitution `_DEPLOY_MESSAGE="Content hotfix: <summary>"`.
   - Include approver in trigger notes; requires one reviewer (web lead or product).
4. **Smoke test**
   - Hit staging URL, then production once Cloud Run revision is ready.
   - Confirm CDN cache invalidated if necessary (see Section 2).
5. **Communicate**
   - Post in `#web-ops` with link to PR/trigger, expected impact, and whether follow-up deploy is planned.
   - Update changelog (`web/CHANGELOG.md`) under “Hotfix” section.

---

## Knowledge Base & Maintenance
- Mirror this document in Notion (link pinned in `#web-ops` topic). Update both locations when procedures change.
- Review quarterly during `Web Ops Review` meeting; archive outdated steps and document new tooling.
- Store runbook evidence (pager screenshots, cache purge logs, SEO approvals) under `Shared Drive › Web Ops › Runbook Evidence`.

## Quick Reference Checklist
- [ ] Incident playbook updated after every SEV > 2.
- [ ] Cache purge operations recorded with timestamps and operators.
- [ ] SEO updates logged and sitemap submitted post-deploy.
- [ ] Content-only deploys follow hotfix trigger and are announced in `#web-ops`.
- [ ] Knowledge base link verified during quarterly review.

