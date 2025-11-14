# Implement admin CRUD for content pages with draft/publish states.

**Parent Section:** 6. Admin / Staff Endpoints > 6.1 Catalog & CMS
**Task ID:** 073

## Purpose
Manage marketing/static pages.

## Endpoints
- `POST /content/pages`
- `PUT /content/pages/{{id}}`
- `DELETE /content/pages/{{id}}`

## Implementation Steps
1. Model pages with fields: `slug`, `language`, `title`, `body`, `seoMeta`, `status` (`draft`, `published`, `archived`).
2. Provide preview tokens for reviewing unpublished pages.
3. Enforce unique slug per language.
4. Trigger CDN purge after publish/unpublish.
5. Tests covering slug uniqueness, preview access, and audit logs.

## Completion Notes
- Extended the content domain/service/repository stack to store preview tokens, enforce slug+locale uniqueness, emit audit logs, and trigger optional CDN invalidation whenever publish state changes (`api/internal/domain/types.go`, `api/internal/repositories/interfaces.go`, `api/internal/repositories/firestore/content_repository.go`, `api/internal/services/content_service.go`).
- Added admin `/content/pages` CRUD handlers with request validation, preview token regeneration controls, and JSON responses that expose sanitized content and preview tokens for staff use (`api/internal/handlers/admin_content.go`, `api/internal/handlers/admin_content_test.go`).
- Updated public page handler to honor `preview_token` for unpublished drafts (no-store caching) and added regression tests that cover preview access plus service-level slug uniqueness/audit scenarios (`api/internal/handlers/public_templates.go`, `api/internal/handlers/public_templates_test.go`, `api/internal/services/content_service_test.go`).
