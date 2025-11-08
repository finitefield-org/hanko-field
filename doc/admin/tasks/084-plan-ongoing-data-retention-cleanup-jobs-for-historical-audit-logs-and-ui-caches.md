# Plan ongoing data retention/cleanup jobs for historical audit logs and UI caches.

**Parent Section:** 16. Observability & Maintenance
**Task ID:** 084

## Summary
The admin console depends on long-lived audit trails plus several Firestore-backed caches (notifications feed, shipment tracking/materialized dashboards) that grow without bound unless we enforce retention. This plan defines the target retention windows, automation required to trim stale data, and the operational runbooks that keep exports and caches healthy across environments.

## Data classes & retention targets
| Data set | Primary store | Hot retention (interactive) | Compliance/archive retention | Mechanism |
| --- | --- | --- | --- | --- |
| Audit logs (`/auditLogs` collection) | Firestore | 180 days | 7 years (BigQuery + GCS) | Firestore TTL + Cloud Scheduler cleanup + BigQuery partition expiry + GCS lifecycle |
| Audit log exports (`ops_audit_logs.audit_events`) | BigQuery (partitioned) | 24 months | 24 months | Partition expiration (730d) + view to recent partitions |
| Audit log cold archive | GCS `gs://hanko-field-exports/audit-logs/YYYY/MM/` | n/a | 7 years | Bucket retention policy + monthly Dataflow export |
| Notifications feed powering `/admin/notifications` | Firestore `admin_notifications` (name TBD) | 90 days for open/ack; 30 days after resolution/suppression | n/a | TTL on `expiresAt`, cleanup job to enforce workflow rules |
| UI caches (tracking, dashboard KPIs, badge counts) | Firestore collections `ops_tracking_shipments`, `ops_tracking_alerts`, `ops_dashboard_kpis`, etc. | 45 days for tracking docs, 14 days for alert banners, 7 days for KPI snapshots | n/a | TTL on cache docs + nightly compaction job |
| UI streaming caches (notifications stream cursor, WebSocket snapshots) | Redis/Firestore ephemeral doc | 7 days | n/a | TTL policy, purge job after incidents |

Retention windows align with `doc/api/models/data-protection.md` (7-year requirement for audit evidence) while keeping Firestore indexes small enough for low-latency admin queries.

## Audit log retention & cleanup
### Policy
1. **Firestore hot tier (interactive search):** keep 180 days of entries so `/admin/audit-logs` remains responsive. Older entries will be served from BigQuery export UI if needed.
2. **BigQuery warm tier:** retain 24 months of partitions in `ops_audit_logs.audit_events` for analysts and investigations without touching cold storage.
3. **GCS cold tier:** keep Dataflow-delivered Parquet/JSON exports for 7 years to satisfy compliance and legal hold requests.

### Automation
- **Export pipeline (existing):** Cloud Scheduler job `export-audit-logs` runs daily → Cloud Run job `jobs/export-audit-logs` bundles the previous day of Firestore writes into BigQuery (partitioned by `createdAt`). Continue to emit Pub/Sub metrics `audit_logs.export.success` for monitoring.
- **New hot-trim job:** add Cloud Scheduler job `trim-audit-logs-hot` (daily at 02:15 JST) that invokes an authenticated internal endpoint `POST /internal/maintenance/audit-logs:trim`. Handler responsibilities:
  - Query Firestore for documents with `createdAt < now-180d` and `complianceHold != true`.
  - Delete in batches of 500 writes, pausing between batches to stay under 15k writes/min.
  - Emit structured log summarising counts, min/max timestamps, and whether any compliance holds were skipped.
- **Firestore TTL safety net:** add `hotExpiresAt` field on write (set to `createdAt + 180d`) and enable Firestore TTL. This ensures cleanup still occurs if the scheduled job fails, while the job provides deterministic pacing and logging.
- **BigQuery partition expiration:** set table partition expiration to 730 days via Terraform. Monthly Dataflow job already copies the same partitions to GCS, so deleting them from BigQuery after 24 months still preserves the 7-year archive.
- **GCS lifecycle:** confirm bucket `hanko-field-exports` enforces object retention of 7 years and optional Glacier-like class transition after 2 years to reduce cost.

### Monitoring & runbook
- Metrics/alerts: add Cloud Monitoring alert if `trim-audit-logs-hot` job fails twice or if Firestore `auditLogs` doc count exceeds 5M. Another alert tracks Dataflow export lag (`dataflow.googleapis.com/job/current_rows`).
- Manual replay: use `gcloud scheduler jobs run trim-audit-logs-hot --location=asia-northeast1` to rerun after failure. When replaying exports, re-run `jobs/export-audit-logs --start=YYYY-MM-DD --end=YYYY-MM-DD` to backfill BigQuery before trimming Firestore.

## Notifications feed retention
### Policy
- **Open/Acknowledged:** guarantee at least 90 days so teams can correlate incidents with long-running investigations.
- **Resolved/Suppressed:** prune 30 days after `resolvedAt`/`suppressedAt` unless a manual hold flag is present on the document (`retainUntil` overrides `expiresAt`).
- **Badge counters:** keep only 7 days of per-user badge snapshots (used for diffing) since counts can be recomputed.

### Implementation
1. Modify the notifications writer to stamp `expiresAt` on every document:
   - `status in {open, acknowledged}` → `expiresAt = createdAt + 90d`.
   - When status transitions to `resolved`/`suppressed`, update `expiresAt = max(expiresAt, now + 30d)`.
   - Allow operators to set `retainUntil` for investigations; cleanup must respect `retainUntil` if present.
2. Enable Firestore TTL on `expiresAt` for the `admin_notifications` collection.
3. Add Cloud Scheduler job `cleanup-notifications-feed` every 6 hours to:
   - Call `POST /internal/maintenance/notifications:compact`.
   - Handler archives soon-to-expire documents (e.g., copy summary to BigQuery `ops_notifications.archive` for optional analytics) before deletion.
   - Remove orphaned timeline subcollections and ensure badge snapshots older than 7 days are deleted.
4. Update `/admin/notifications` API to fall back to the archive dataset when users request ranges beyond the hot window (requires BigQuery access token exchange).

### Monitoring & manual tasks
- Alert when the cleanup job deletes zero documents for 3 consecutive runs (could indicate TTL misconfiguration) or when Firestore doc count exceeds 200k.
- Manual hold workflow: toggling `retainUntil` via admin UI should emit an audit log; runbook documents how to lift the hold after investigations conclude.

## UI cache cleanup (dashboard fragments, shipment/alert caches)
### Scope
The admin UI relies on denormalised Firestore caches to avoid heavy joins:
- `ops_tracking_shipments` + `ops_tracking_alerts` for the shipment monitor (`doc/admin/tasks/033`).
- `ops_dashboard_kpis` snapshot documents powering `/admin` KPI cards.
- `ops_dashboard_alerts` / `ops_dashboard_history` for sparkline data.
- Streaming cursor docs for notifications/WebSocket fallbacks.

Without pruning, these caches steadily accumulate copy-on-write versions every time carriers update a package or background jobs recompute KPIs.

### Policy & automation
| Cache | Retention target | Automation |
| --- | --- | --- |
| Shipment tracking rows | Delete 45 days after `lastEventAt` (shipments past delivery rarely need UI cache) | Webhook processor stamps `expiresAt = lastEventAt + 45d`; enable Firestore TTL; nightly job validates counts |
| Shipment alerts (`ops_tracking_alerts`) | Remove 14 days after `expiresAt` or once `status=cleared` | TTL + cleanup job clears stale alerts and recalculates badge counts |
| Dashboard KPI snapshots (`ops_dashboard_kpis`) | Keep rolling 7 days (daily doc per metric) | Scheduled job `refresh-dashboard-kpis` overwrites today's doc; companion `purge-dashboard-kpis` deletes docs older than 7 days |
| Streaming cursor cache (`ops_ui_stream_state`) | Keep 7 days | TTL only |

Implementation details:
1. **Webhook writers:** ensure every cache document includes both `expiresAt` (for TTL) and `updatedAt`. Existing Go service already understands metadata doc for cache invalidation; extend it to drop cache hits once TTL passes.
2. **Nightly compaction job (`cleanup-ui-caches`)**:
   - Runs at 01:30 JST via Cloud Scheduler.
   - Calls `POST /internal/maintenance/ui-caches:purge`.
   - Handler iterates each cache collection with a `expiresAt < now` filter, deletes in batches, and emits metrics (`ui_cache.purged_count{collection="ops_tracking_shipments"}`).
   - Rebuilds KPI aggregates if fewer than 2 docs remain for a metric (guards against accidental over-deletion).
3. **Index hygiene:** update Firestore index configs to include `expiresAt` as a collection group index so TTL and manual queries share the same plan.
4. **Disaster recovery:** maintain a daily export of cache collections (Cloud Storage) to allow repopulating after schema mistakes; exporter can piggyback on the same Cloud Run job as audit logs but separate destination folder.

## Maintenance checklist
| Task | Owner | Frequency | Tooling | Success criteria |
| --- | --- | --- | --- | --- |
| Verify `trim-audit-logs-hot` + export jobs | SRE | Daily (automated) / Weekly review | Cloud Scheduler logs, BigQuery row counts | Hot tier rows < 5M, latest BigQuery partition <24h old |
| Review notification cleanup | CS Ops | Weekly | `/admin/system/tasks` dashboard | Deletion log shows activity, notification count trending down after resolutions |
| UI cache purge | Ops Eng | Daily automated + Monday review | `cleanup-ui-caches` logs, Firestore stats | No cache doc older than policy window, shipments dashboard loads <300 ms |
| Compliance archive spot-check | Security | Quarterly | Sample GCS object + hash, compare to audit viewer | Latest monthly folder present, hash matches exported digest |

## Next actions
1. Terraform: add Scheduler jobs + IAM invoker bindings, enable Firestore TTL on the listed collections, and set BigQuery partition expiration.
2. API/Admin services: implement the three maintenance endpoints (`audit-logs:trim`, `notifications:compact`, `ui-caches:purge`) with structured logging + metrics.
3. Documentation/runbooks: link this plan from `doc/admin/guide.md` operations chapter and from on-call handbook; include command snippets for manual reruns.
4. Monitoring: create alerting policies for job failures and Firestore document count thresholds; surface them on the admin `/system/tasks` page for visibility.
