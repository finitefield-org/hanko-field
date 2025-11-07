# Admin Manual QA Scenarios

Manual QA focuses on end-to-end validation of admin-facing workflows that cut across API, admin UI (htmx/templ), and downstream services. These guides assume the API is deployed to staging with Firestore emulator parity.

## Environments & Data Management
- **Environments**: Run on `staging-admin` unless the scenario explicitly calls for `load-test` (for concurrency or webhook storm simulations). Record the backend commit hash in the checklist.
- **Accounts**: Use Firebase staff accounts seeded via `tools/scripts/seed.go`. Create one `Admin` role user with full permissions and one `Support` role user with restricted scopes for negative cases.
- **Data resets**: After every scenario, re-run `seed.go` with the `--fixtures orders,carts` flags or apply the rollback section below to keep Firestore clean. Storage objects use the `qa/` prefix for easy deletion.

## How to Read the Tables
Each domain lists scenarios with: 1) setup, 2) execution steps, 3) expected outcomes, and 4) rollback guidance. Check off every line during a UAT run and attach screenshots/log IDs to TestRail.

---

## Cart Scenarios

| Scenario | Setup | Steps | Expected Outcome | Rollback |
| --- | --- | --- | --- | --- |
| Cart duplication handling | Seed user `qa-cart-owner` with populated cart `C-1001` (3 items). | 1. Login as Admin.<br>2. Use Admin cart inspector → "Duplicate cart". | New cart `C-1001-copy` retains quantities, promotions, and metadata; original cart untouched; audit log entry created. | Delete cloned cart via API `DELETE /admin/carts/{id}`. |
| Cross-role edit conflict | Assign Support role to `qa-support`. Both Admin & Support open same cart. | 1. Admin updates shipping address.<br>2. Support tries to edit quantity simultaneously. | Support receives 409 with `version_mismatch`; Admin change persists; conflict telemetry logged. | Re-run `seed.go --fixtures carts` or revert cart version manually. |
| Expired promotion validation | Cart has promo code set to expire in 5 minutes. | 1. Wait past expiry.<br>2. Admin re-prices cart via "Recalculate totals". | Promo removed, totals recomputed, warning banner shown, audit includes `promo_expired`. | Re-apply fresh promo or reset cart fixture. |
| Inventory hold release | Inventory service has hold on SKU `SKU-LOW`. | 1. Admin removes item with hold.<br>2. Trigger "Release hold". | Firestore reservation doc deleted; inventory count increments; webhook queued. | If release fails, manually delete reservation doc `inventory/reservations/{cartId}`. |

## Checkout Scenarios

| Scenario | Setup | Steps | Expected Outcome | Rollback |
| --- | --- | --- | --- | --- |
| Stripe session retry | Cart prepared with PSP session `sess_retry`. | 1. Trigger checkout creation.<br>2. Force PSP timeout via mock toggle.<br>3. Retry via "Recreate session". | Second attempt succeeds, idempotency key reused, first session marked `abandoned`. | Delete orphaned sessions via `psp_sessions` collection. |
| Tax override by Admin | Enable manual tax override flag. | 1. During review, enter new tax amount.<br>2. Save override. | Totals recalc with override, changelog captures user+reason, rollback token displayed. | Use rollback token in `/admin/checkout/{id}/tax/rollback`. |
| Split shipment approval | Order flagged for split shipments. | 1. Approve split.<br>2. Assign items to shipment A/B. | Shipment docs created with correct SKUs; timeline shows decision; customer notification queued. | Delete shipments and toggle order status back to `ready_to_fulfill`. |
| Checkout fraud escalation | PSP returns `review_required`. | 1. Open fraud panel.<br>2. Assign reviewer.<br>3. Approve or cancel. | Approve path: order resumes; Cancel path: order set to `fraud_cancelled`, refund job queued. | If cancelled accidentally, use `reopen` action before 1 hour to restore. |

## Admin Operations Scenarios

| Scenario | Setup | Steps | Expected Outcome | Rollback |
| --- | --- | --- | --- | --- |
| RBAC enforcement regression | Have Admin & Support roles. | 1. Support attempts to edit promotions.<br>2. Admin performs same edit. | Support sees 403 with actionable message; Admin succeeds; audit log differentiates roles. | None needed; confirm audit entry removal is not required. |
| Bulk CSV import with errors | Prepare CSV with 2 valid rows, 1 malformed. | 1. Upload via Bulk Import.<br>2. Inspect validation report. | Valid rows imported; malformed row flagged with line number; process stops if >20% errors. | Delete imported records using `bulk_import_id`. |
| Feature flag toggle audit | Feature flag `admin.betaFlow` default OFF. | 1. Toggle ON, capture change reason.<br>2. Toggle OFF. | Flag takes effect within 30s (verify via status API); audit log contains both transitions + reasons. | If state stuck, call `/ops/feature-flags/refresh`. |
| Scheduled task override | Cron job `reconcile-orders` paused. | 1. Trigger manual run.<br>2. Observe job dashboard. | Manual run executes once, generates Cloud Task with manual tag, resume button remains disabled until success. | If manual run fails, hit `Reset state` to clear lock. |

## Webhook Scenarios

| Scenario | Setup | Steps | Expected Outcome | Rollback |
| --- | --- | --- | --- | --- |
| PSP payment.succeeded replay | Load webhook fixture `stripe_payment_succeeded.json`. | 1. Send webhook once (success).<br>2. Replay same payload. | First call updates payment + order; replay returns 200 with `duplicate_delivery=true`; no duplicate state changes. | None; verify idempotency store clears after TTL. |
| PSP payment.failed missing signature | Remove signature header. | 1. Post webhook without `Stripe-Signature`. | Request rejected (400) with `signature_missing`; alert emitted. | Re-run with valid signature to clear alert. |
| Storage asset processed | Upload processing webhook with unknown asset ID. | 1. Send payload referencing missing asset. | Webhook returns 404, auto-enqueues reconciliation task, admin dashboard shows `Asset Missing`. | Create stub asset record or close alert after triage. |
| AI suggestion ready | Firestore doc exists for `ai_job_123`. | 1. Send webhook to mark job `completed`. | Admin UI card updates to `completed`, notification sent, staff can accept suggestion. | To undo, set job status back to `pending` via admin tools. |

## Cross-Team UAT Checklist
- Coordinate with **Frontend** to ensure admin UI reflects API errors (e.g., 409 carts) and that htmx swaps show contextual messaging.
- Pair with **Platform** team when running PSP/webhook cases so Stripe dashboards and signing secrets stay in sync.
- Loop in **Data/Analytics** for scenarios that emit events to ensure Looker dashboards ingest the new audit entries.
- After any incident, append regression scenarios to this file and link the incident postmortem ID.

## Reporting & Sign-off
- Capture evidence (screenshots, Cloud Logging URLs, webhook IDs) per scenario.
- File bugs in Linear with tag `manual-qa` and include reproduction steps + expected vs actual.
- QA lead signs off only when all scenario checkboxes are complete and rollback verification logs are attached.
