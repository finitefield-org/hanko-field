# Document on-call runbooks for incident handling and operational tasks.

**Parent Section:** 12. Observability & Operations
**Task ID:** 125

## Goal
Document operational runbooks for incident handling and routine tasks.

## Plan
- [x] Create runbook template covering detection, diagnosis, mitigation, rollback.
- [x] Produce runbooks for checkout failures, webhook backlog, stock reservation anomalies, AI worker delays.
- [x] Store in shared knowledge base with revision control.

---

## Implementation Summary (2025-11-08)

- Authored `doc/api/operations/runbooks.md`, starting with a reusable template table that
  spells out the required sections (signal, diagnostics, mitigation, rollback, verification,
  operational tasks) for future playbooks.
- Added four detailed runbooks:
  1. **Checkout failure** - detection via `/checkout/*` 5xx ratio, Firestore contention,
     rollback guidance, and preventive scaling tasks.
  2. **Webhook backlog** - Pub/Sub backlog/age triggers, worker scaling + DLQ replay steps,
     and daily/weekly operational checks.
  3. **Stock reservation anomalies** - extends AP-002 procedures with catalog validation,
     maintenance cleanup, and config override guidance.
  4. **AI worker delay** - covers Pub/Sub backlog, vendor health, worker scaling, and feature
     flag fallbacks for AI suggestions.
- Each runbook includes concrete `gcloud`, `curl`, and logging queries plus routine chores
  (weekly/monthly) so ops tasks are documented alongside incident actions.

## Verification

1. Cross-link from alerts: AP-001..003 already reference runbook anchors; future policies can
   reference `doc/api/operations/runbooks.md#<slug>` to keep paths consistent.
2. Walk through one scenario (e.g., webhook backlog) by dry-running the listed `gcloud`
   commands against staging to ensure they execute without additional flags.
3. Add the new document to the on-call knowledge base index so future rotations know where
   the runbooks live.
