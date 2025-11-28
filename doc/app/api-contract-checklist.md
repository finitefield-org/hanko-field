# API contract checklist for mobile flows
Purpose: ensure app payloads align with backend; use this list when drafting/confirming each endpoint.

## Global
- Auth: token type (Firebase/PSP), refresh/expiry; guest capabilities; required headers.
- Versioning: app version + platform in headers; backward-compatible schema changes; feature flags via Remote Config.
- Errors: standard envelope (code/message/field errors); retryable vs fatal; locale of messages.
- Time/locale: timezone offsets in requests; server timestamps ISO8601 with TZ; currency and locale fields when relevant.
- Pagination: cursor/offset, page size caps, total counts; stable sort keys.
- Idempotency: keys for mutations (checkout, uploads); duplicate submission handling.
- Assets: upload/download flow (pre-signed URLs), max sizes, MIME types; image/vector support for design export.
- Security: PII fields encryption at rest; permission/role checks for each endpoint; rate limits and lockouts.

## Auth & onboarding
- `/auth`: Apple/Google/Email/guest; link/unlink social; MFA?; error codes for declined scopes.
- `/persona`, `/locale`: read/write endpoints; caching rules; defaults.
- Splash/update: app-update constraints payload; feature flag fetch.

## Design creation (作成タブ)
- `/designs` CRUD: request schema (name, style, canvas params), validation errors.
- Kanji mapping: `/designs/kanji-map` query + meanings; localization of meanings.
- AI suggestions: queue/stream endpoints; status polling or SSE; acceptance/rejection payload.
- Registrability check: sync/async result, SLAs; badges/status codes.
- Versions: list/diff/rollback; snapshot references for checkout.
- Export/share: PNG/SVG generation; watermarks; access control for shared links.

## Shop & checkout
- Catalog: `/materials`, `/products`, `/products/{id}/addons` with availability/lead times; price currency; tax/shipping inclusions.
- Cart: add/update/delete lines; promo codes; estimate totals breakdown.
- Shipping: addresses (JP/international validation), delivery options with ETA; duties/fees flags.
- Payment: token references (PSP), supported methods; 3DS flow; idempotency keys; cancellation rules.
- Checkout review/complete: order creation payload; snapshot IDs; duplicate prevention; post-create hooks.

## Orders & tracking
- Orders list/detail: filters (status/date), pagination; include snapshots, totals, addresses.
- Production timeline: stage names/timestamps; permissible transitions.
- Tracking: carrier events, last-updated timestamp; external tracking link.
- Invoice: download links (PDF), caching/expiry.
- Reorder: endpoint cloning prior order/cart; validation for discontinued SKUs.

## Library (マイ印鑑)
- Library list/detail: sort/filter params; AI score/registrability status; usage history.
- Duplicate/export/share links: permission checks; expiry/revoke APIs; download quotas.
- Versions: list and rollback; audit trail.

## Content & guides
- Guides/how-to/kanji dictionary: localization fields; offline caching headers; search/favorite endpoints.
- CMS content types (markdown/HTML) and allowed embeds for videos.

## Notifications & messaging
- Push registration: token registration per platform; opt-in categories; locale/persona in payload for targeting.
- Inbox sync: list, read/unread, badge counts; pagination; push-to-screen deep links.
- In-app toasts/messages: fetch rules and expiry; rate limits.
- Support chat/contact/FAQ: ticket creation with attachments; file size/types; auth/guest rules.

## Profile & settings
- Profile: avatar upload (presigned), display name, persona toggle.
- Addresses/payments: CRUD with validation; default selection; linkage to checkout.
- Locale/currency overrides; notification preferences.
- Linked accounts: list/unlink; re-auth requirements.
- Data export/delete: async job status; download link expiry; confirmation steps.

## System utilities
- Permissions logging (optional) with rationale; offline status payload for cached content; changelog feed.
- Status page: incidents and uptime history schemas.
