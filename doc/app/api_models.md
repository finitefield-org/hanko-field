# Mobile API models, DTOs, and repository interfaces

This layer bridges API payloads to immutable domain entities (no codegen). DTOs parse/serialize JSON, repositories hide transport details, and domain classes keep the UI independent from response shapes.

## Versioning strategy
- API path stays on `/api/v1`; DTOs accept unknown keys and default missing optional fields to avoid crashes during backend rollouts.
- Entities carry backend `version` fields when present (templates/fonts/content) and timestamps use ISO-8601 (`DateTime.parse`).
- `Page<T>` is the standard pagination container (`items`, `nextPageToken`). Repositories return domain objects only.
- Copy updates use `copyWith` on domain classes; never mutate DTO maps directly in UI code.

## Required fields per feature (initial pass)
- **Users**: persona, preferredLang, isActive, piiMasked, createdAt/updatedAt. Addresses need recipient/line1/city/postalCode/country; payment methods require provider/methodType/providerRef. Favorites use `designRef` + `addedAt`.
- **Designs**: id, status, shape, size.mm, style.writing, version, createdAt/updatedAt. Lists rely on `assets.previewPngUrl` and `hash`; detail/versions include `input`, `ai`, `assets`, and `aiSuggestions` status/preview/score.
- **Catalog**: templates need name/shape/writing/constraints.previewUrl/sort; fonts need family/writing/license.isPublic/previewUrl; materials require name/type/isActive/photos; products require sku/materialRef/shape/size.mm/basePrice/stockPolicy/isActive (+ salePrice if present).
- **Orders**: orderNumber/status/currency/totals/lineItems (sku/name/quantity/unitPrice/total)/shippingAddress required. Detail screens also need promotion snapshot, contact, fulfillment estimates, shipments (carrier/status/tracking/events), payments (provider/status/amount), and production events.
- **Promotions**: code/kind/value/isActive window (startsAt/endsAt) plus usageLimit/usageCount/limitPerUser. Conditions cover minSubtotal/currency/shape/size/product/material filters; stacking flags drive UI for combinability.
- **Content**: guides need slug/category/isPublic/translations[lang].title/body + timestamps; pages need slug/type/isPublic/translations[lang].title/(body|blocks) + navOrder if present.
