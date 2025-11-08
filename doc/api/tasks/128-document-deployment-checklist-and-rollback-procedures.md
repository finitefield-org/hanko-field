# Document deployment checklist and rollback procedures.

**Parent Section:** 13. Documentation & Support
**Task ID:** 128

## Goal
Capture deployment and rollback procedures for each environment.

## Plan
- [x] Outline pre-deploy checklist (tests, approvals, config verification).
- [x] Document deployment steps (CI job, manual approvals, smoke tests).
- [x] Provide rollback steps (Cloud Run revision rollback, database fixes).
- [x] Keep template updated with lessons learned.

---

## Implementation Summary (2025-11-08)

- Authored `doc/api/operations/deployment.md`, adding an environment overview table plus a
  shared pre-flight checklist covering tests, config/secrets, data safety, comms, freezes,
  and smoke-test planning.
- Documented per-environment procedures for dev/preview, staging, and production deploys,
  detailing triggers, manual steps, smoke/QA expectations, and required communications.
- Captured rollback guidance for each environment (Cloud Run revision traffic shifts, data
  restore considerations, secret/config reverts) and added a decision guide + checklist
  template so retro learnings can extend the document.

## Verification

1. Dry-run the staging checklist by following the `build-and-deploy-staging` workflow logs
   and ensuring each step in the doc maps to an observable action/output.
2. Rehearse a rollback in staging once per sprint by listing the last two revisions with
   `gcloud run revisions list` and temporarily shifting traffic to the previous revision using
   the documented command, then back again.
3. Link the new document from the release ticket template so future releases reference it and
   discrepancies can be reported quickly.
