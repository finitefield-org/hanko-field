# App scope, personas, platforms, and release milestones (Task 001)
Source: `doc/app/app_design.md`, personas: `doc/customer_journey/persona.md`

## Supported platforms and accessibility (provisional)
- OS targets: iOS 15+ (ARM64) and Android 8.0/API 26+; revisit with market data before first beta.
- Device classes: phones are primary; tablet layouts are P2 (stretch layouts acceptable, no tablet-only features).
- Form factors: portrait-first; allow landscape for media previews only after GA.
- Accessibility: text scaling to 200%, screen reader labels for nav, buttons, form fields; focus order verified on auth/checkout; minimum 4.5:1 contrast for core surfaces.
- Performance: cold start <3s on mid-tier Android (4 GB), <2s on recent iPhones; initial bundle keeps heavy assets lazy-loaded.
- Permissions: photos/files (design import/export) and notifications gated with rationale screens; no background location.

## Personas mapped to app flows
| Area | Japanese persona (実用＋デザイン) | Foreigner persona (文化体験＋ギフト) |
| --- | --- | --- |
| Onboarding | Default JA, quick path to auth; emphasize registrability and quality | Highlight kanji/guide content, guest mode, cultural tips |
| Design input | Bank/official name validation; registrability check | Kanji mapping helper with meanings; romanized input support |
| Style/editor | Precise layout controls, size specs, material fit | Template presets that look traditional; easy preview/share |
| Shop/checkout | Domestic shipping defaults, invoicing, reorder | Clear intl shipping, duties notice, gift messaging |
| Library | Registrability status, usage history, export | Easy sharing/watermark, versioning for experiments |
| Guides/support | FAQ/legal in JA; support contact | Cultural guides, how-to articles, chat/FAQ in EN |

## Scope and release milestones (feature slices)
- Alpha (internal/dev):
  - Navigation shell with tabs, locale/persona selection, guest/Email auth stub.
  - Core design flow: text input, style select, editor basics, preview, save to library.
  - Shop + cart + checkout minimal: product/material detail, domestic address, payment stub, order creation stub.
  - Orders list/detail (read-only), profile basics (avatar/name), offline/error screens.
  - Telemetry baseline: crash reporting on, manual QA device matrix drafted.
- Beta (closed/TestFlight & Play internal):
  - Full auth (Apple/Google), push handling, notification inbox badge sync.
  - Checkout completion (real payment token refs), shipping (domestic + international), invoice view download.
  - Design enhancements: kanji mapping, AI suggestions queue, registrability check, version history, share exports (PNG/SVG).
  - Library export/share links, reorder flow, production timeline, shipment tracking.
  - Localization coverage JA/EN, accessibility pass on onboarding/auth/checkout.
- GA (public stores):
  - Guides/how-to/kanji dictionary content, chat support, system status.
  - Remote config/feature flags for staged rollout, performance monitoring, analytics events across design/checkout/share.
  - Forced app update gate, changelog, full notification/alert toasts, offline resilience.
  - App Store/Play metadata and release automation active; support SLAs in place.

## Deferred/optional items
- Tablet-optimized layouts beyond responsive stretch.
- Landscape editing mode.
- Additional personas (corporate procurement) and bulk ordering.

## Risks and dependencies
- AI suggestions and registrability check depend on backend endpoints; mitigation: mock providers for Alpha, feature-flag rollout.
- Payment/shipping (intl) relies on PSP/carrier integrations; need test sandboxes before Beta.
- CMS content (guides/how-to/dictionary) must be ready before GA; fallback to static Markdown otherwise.
- Localization accuracy requires final copy source of truth (ARB) and reviewer bandwidth.
