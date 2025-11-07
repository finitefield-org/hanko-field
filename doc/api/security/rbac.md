# API RBAC Strategy

This document captures the role-based access control (RBAC) strategy for the Hanko Field API. It covers the canonical roles, permission keys, and the mapping between endpoint groups and required scopes so handlers, middleware, and tests remain consistent across services.

## Roles & Identity Sources

| Role | Source | Description |
| --- | --- | --- |
| `anonymous` | Unauthenticated requests (public catalog, health) | Limited to cacheable read-only endpoints; no user context injected. |
| `user` | Firebase Auth ID token without elevated custom claims | End customers interacting with the mobile app or web storefront. Access limited to their own resources plus public reads. |
| `staff` | Firebase Auth ID token with custom claim `role=staff` | Support/operations users with access to read most resources and perform low-risk mutations (order status updates, review moderation, manual payments) that do not reconfigure the platform. |
| `admin` | Firebase Auth ID token with custom claim `role=admin` | Trusted employees with catalog/content/promotion management rights and the ability to manage staff accounts, counters, and system settings. Implies all `staff` permissions. |
| `system` | Service-to-service tokens (IAP, workload identity, HMAC) | Non-human callers such as Cloud Scheduler jobs, AI workers, and PSP/webhook integrations. Permissions granted per service account via dedicated scopes instead of `role`. |

Firebase custom claims also expose fine-grained scopes via `scopes: ["orders.read", "orders.write", ...]`. Middleware must intersect the role defaults with explicit scopes to support temporary overrides (ex: give `staff` write access to promotions for a migration window).

## Permission Taxonomy

Permissions are expressed as `domain.action`. Handlers ask the RBAC middleware for a permission key; middleware resolves it against role defaults + explicit scopes.

- `catalog.read|write` – Templates, fonts, materials, products.
- `content.read|write` – Guides, pages, localized content blocks.
- `promotions.read|write` – Promotions CRUD, validation, usage reporting.
- `designs.read|write` – User designs plus staff overrides.
- `cart.*` – Cart lifecycle (user only).
- `orders.read|write` – Orders, payments, shipments, production events.
- `inventory.read|write` – Stock, production queues, counters.
- `users.read|write` – User search, profile overrides, staff management.
- `reviews.moderate` – Moderation queue actions and replies.
- `audit.read` – Audit log export/search.
- `system.run` – Internal maintenance endpoints, scheduler hooks.

## Endpoint Group Matrix

| Endpoint Group | Examples | Permission Key(s) | Anonymous | User | Staff | Admin | System |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Public catalog | `/api/v1/public/templates`, `/fonts`, `/materials` (GET) | `catalog.read` | Yes | Yes | Yes | Yes | Yes |
| User profile & addresses | `/api/v1/me`, `/me/addresses` | `users.read`, `users.write` | No | Own only | Support-only read/write (for troubleshooting) | Yes | No |
| Payment methods | `/me/payments` | `users.write` | No | Own only | No (view masked only) | Yes | No |
| Favorites & designs | `/me/designs`, `/designs/:id` | `designs.read`, `designs.write` | No | Own only | Read/write overrides for escalations | Yes | No |
| AI suggestions | `/designs/:id/ai/*` | `designs.write` | No | Own only | Read-only to inspect | Yes | System jobs create/update |
| Cart & checkout | `/cart`, `/checkout/*` | `cart.read`, `cart.write`, `orders.write` | No | Yes | Read-only for impersonation | Yes | System for reserve/commit APIs |
| Orders (user scope) | `/orders`, `/orders/:id/cancel` | `orders.read`, `orders.write` | No | Own only | Read/write for support cases | Yes | System (webhooks) |
| Orders ops (staff) | `/admin/orders/*`, `/admin/payments/*`, `/admin/shipments` | `orders.read`, `orders.write`, `inventory.write` | No | No | Yes | Yes | System for automations |
| Production & inventory | `/admin/production-events`, `/admin/stock`, `/admin/queues` | `inventory.read`, `inventory.write` | No | No | Limited (update events, view stock) | Yes | System |
| Catalog/content admin | `/admin/templates`, `/admin/products`, `/admin/pages`, `/admin/guides` | `catalog.write`, `content.write` | No | No | Read-only (preview) | Yes | System (publishing jobs) |
| Promotions | `/admin/promotions/*`, `/admin/promotions/usages` | `promotions.read`, `promotions.write` | No | No | Read + validate only | Yes | System |
| Reviews moderation | `/admin/reviews/*` | `reviews.moderate` | No | Submit only | Yes | Yes | No |
| Users admin | `/admin/users/*`, `/admin/staff/*` | `users.read`, `users.write` | No | No | Limited (lookup) | Yes | No |
| Audit logs & counters | `/admin/audit-logs`, `/admin/counters` | `audit.read`, `system.run` | No | No | No | Yes | System |
| Webhooks | `/api/v1/webhooks/*` | `system.run` | No | No | No | No | Yes by signature |
| Internal maintenance | `/api/v1/internal/*` | `system.run` | No | No | No | Limited (ops break-glass) | Yes |

Legend:
- "Own only" means middleware enforces `request.user == resource.owner`. Staff overrides require `designs.read` + `users.read`.
- Staff read/write limits are implemented via scoped permissions (`promotions.write` absent by default).

## Enforcement Strategy

1. **Authentication middleware** verifies Firebase ID tokens (users/staff/admin) or service tokens (system) and injects `Identity{UID, Role, Scopes}` into the request context.
2. **RBAC middleware** receives the required permission key from the route metadata (`handlers.MustHave("orders.write")`). It checks:
   - Explicit scope allowance (`Identity.Scopes`),
   - Otherwise role defaults loaded from configuration (`rbac.yaml` or `rbac.json`).
   - Resource ownership rules via helper callbacks (e.g., `AllowOwnerOrSupport`).
3. **Configuration source** lives in `internal/security/rbac.go` and is generated from `doc/api/security/rbac.md` to keep docs and implementation aligned. Structure example:

```yaml
roles:
  user:
    allow: ["catalog.read", "designs.read", "designs.write", "cart.*", "orders.read", "orders.write"]
  staff:
    inherit: ["user"]
    allow: ["orders.read", "orders.write", "inventory.read", "reviews.moderate"]
  admin:
    inherit: ["staff"]
    allow: ["catalog.write", "content.write", "promotions.write", "users.write", "audit.read", "system.run"]
  system:
    allow: ["system.run", "orders.write", "inventory.write"]
```

4. **Testing**: unit tests exercise RBAC middleware with table-driven cases per permission key, while integration tests hit representative endpoints asserting `403` behavior for missing scopes (see `doc/api/manual_qa.md` scenario #3).
5. **Operational controls**: support temporary elevation by issuing short-lived custom claims with additional scopes; audit log each RBAC denial and elevation for compliance.

## Open Items

- Align admin UI role management with this matrix (ensure staff cannot assign themselves new scopes).
- Decide whether `system` tokens can call select admin endpoints for automation; default is deny until justified.
- Document emergency break-glass flow for granting `promotions.write` to staff for a bounded window.
