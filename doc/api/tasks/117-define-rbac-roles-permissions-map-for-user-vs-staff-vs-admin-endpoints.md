# Define RBAC roles/permissions map for user vs staff vs admin endpoints.

**Parent Section:** 11. Security & Compliance
**Task ID:** 117

## Goal
Define role-based access control matrix for user, staff, admin endpoints and document enforcement strategy.

## Plan
- Enumerate roles (`user`, `staff`, `admin`, `system`) and permissions per endpoint group.
- Document in `doc/api/security/rbac.md` and expose as configuration in code.
- Implement automated tests verifying middleware denies unauthorized access.
- Align with Firebase custom claims and admin UI roles.

## Deliverable Summary (2025-10-05)

- Auth roles now normalized to `anonymous`, `user`, `staff`, `admin`, and `system`, each tied to a specific identity source plus default permission scopes.
- Added `doc/api/security/rbac.md` detailing the permission taxonomy (`domain.action`), endpoint group matrix, and enforcement workflow for middleware/config generation.
- Matrix specifies ownership guardrails (\"Own only\" vs. staff override) and highlights where staff require additional scoped claims instead of blanket rights.
- Configuration snippet shows how `internal/security/rbac.go` should serialize the role map so tests can assert `403` behavior for missing scopes.
- Follow-ups captured for admin UI role assignment alignment and break-glass elevation procedures.
