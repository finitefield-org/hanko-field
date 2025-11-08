# Enforce validation and sanitization for all user inputs to prevent injection/abuse.

**Parent Section:** 11. Security & Compliance
**Task ID:** 118

## Goal
Ensure all inputs validated and sanitised to prevent injection, XSS, or data corruption.

## Plan
- Create validation utilities (regex, length checks) and HTML sanitizer for content endpoints.
- Enforce validation in handlers/services with descriptive errors.
- Add automated tests for typical attack payloads (script tags, SQL-like injection, path traversal).
- Document validation rules per endpoint.

## Validation Rules
| Surface | Inputs Covered | Rules |
| --- | --- | --- |
| Public & authenticated routes | Path parameters, query strings | Trim + 256 char cap, strip control chars, reject `<script>`, SQL boolean payloads, and `../` traversal before handlers run (`api/internal/handlers/router.go`, `api/internal/handlers/router_validation_test.go`). |
| CMS/content endpoints | `slug`, `title`, `summary`, `body_html` on guides/pages | Slugs normalized to lowercase `[a-z0-9-]`, textual fields bounded (160/600 chars), body HTML sanitized via Bluemonday policy reused by admin + public handlers (`api/internal/services/content_service.go`, `api/internal/platform/validation/html.go`). |
| Asset uploads | `file_name`, upload metadata | Filenames reduced to ASCII-safe characters, traversal markers rejected, size/type gating enforced before issuing signed URLs (`api/internal/services/asset_service.go`). |
| Admin user search | `query` | Trimmed + <=200 chars, rejects SQL-like payloads (e.g. `' OR 1=1 --`) with descriptive errors (`api/internal/services/user_service.go`). |

## Completion Notes
- Added `api/internal/platform/validation` with reusable plain-text, slug, filename, HTML, and injection-detection helpers plus unit coverage for script/SQL/traversal payloads.
- Registered a global router middleware that sanitizes chi path params + query strings before any handler executes and added regression tests proving script-tag and traversal attempts are rejected (`api/internal/handlers/router.go`, `api/internal/handlers/router_validation_test.go`).
- Updated content, admin/public template handlers, and the content service to consume the shared HTML + slug sanitizers and enforce bounded text inputs before persisting (`api/internal/services/content_service.go`, `api/internal/handlers/public_templates.go`, `api/internal/handlers/admin_content.go`).
- Hardened asset uploads and admin search flows by sanitizing file names, validating search queries, and adding regression tests for SQL/path traversal attacks (`api/internal/services/asset_service.go`, `api/internal/services/asset_service_test.go`, `api/internal/services/user_service.go`, `api/internal/services/user_service_test.go`).
