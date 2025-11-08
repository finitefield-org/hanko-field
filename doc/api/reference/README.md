# Hanko Field API Reference

<!-- AUTO-GENERATED via doc/api/reference/generate_reference.py -->

Comprehensive endpoint catalog derived from `doc/api/api.yaml`. Use the generator script whenever the OpenAPI spec changes to keep docs current.

*Spec version:* 1.0.0

## Usage & Conventions

- Default base URL: `https://{service}.a.run.app/api/v1` (set `$BASE_URL` for curl snippets).
- All endpoints live under `/api/v1`. Versioning follows semantic release tags.
- Request/response bodies are JSON encoded in UTF-8 unless noted.
- Optional query params are omitted from samples for brevity.

### Authentication & RBAC

- Firebase Auth ID tokens back user/staff/admin roles; custom claims carry `role` + optional `scopes` (see `doc/api/security/rbac.md`).
- `OIDCServer` tokens (IAP / Workload Identity) secure `/internal/*` endpoints for automation.
- Webhooks require the shared `X-Signature` HMAC header plus rotating secrets via Secret Manager.

### Idempotency

- `Idempotency-Key` header is **required** for `POST`, `PUT`, `PATCH`, and `DELETE`. Middleware deduplicates requests per user+route for 24h.
- Safe verbs (`GET`, `HEAD`) ignore the header but accept it if present.

### Error Model

- Errors follow the `Error` schema `{ "code": "string", "message": "string", "details": { ... } }`.
- Typical error codes: `400` validation, `401` unauthenticated, `403` forbidden/missing scope, `404` not found, `409` conflict, `429` throttled, `500` internal.
- Unless stated otherwise, error payloads are JSON.

## Public
Cache-friendly catalog, template, promotion, and health endpoints that do not require authentication.

- **Default auth:** None (anonymous HTTPS).

### `GET /content/guides` — List guides (public)
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `lang` | query | string | No |  |
| `category` | query | string | No |  |

**Success response:** `200` OK (PageGuide)

```json
"string"
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/content/guides"
```
### `GET /content/guides/{slug}` — Get a guide by slug
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `slug` | path | string | Yes |  |

**Success response:** `200` OK (Guide)

```json
{
  "slug": "string",
  "category": "culture",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/content/guides/slug"
```
### `GET /content/pages/{slug}` — Get a fixed page by slug
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `slug` | path | string | Yes |  |

**Success response:** `200` OK (Page)

```json
{
  "slug": "string",
  "type": "landing",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/content/pages/slug"
```
### `GET /fonts` — List fonts
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `pageSize` | query | integer | No |  |
| `pageToken` | query | string | No |  |

**Success response:** `200` OK (PageFont)

```json
{
  "items": [
    {
      "family": "string",
      "writing": "tensho",
      "license": {
        "type": "...",
        "uri": "...",
        "text": "...",
        "restrictions": "...",
        "embeddable": "..."
      },
      "isPublic": true,
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "nextPageToken": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/fonts"
```
### `GET /fonts/{fontId}` — Get a font
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `fontId` | path | string | Yes |  |

**Success response:** `200` OK (Font)

```json
{
  "family": "string",
  "writing": "tensho",
  "license": {
    "type": "commercial",
    "uri": "https://example.com/resource",
    "text": "string",
    "restrictions": [
      "string"
    ],
    "embeddable": true
  },
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/fonts/font_id"
```
### `GET /healthz` — Liveness probe
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X GET "$BASE_URL/healthz"
```
### `GET /materials` — List materials
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK (PageMaterial)

```json
{
  "items": [
    {
      "name": "string",
      "type": "horn",
      "isActive": true,
      "createdAt": "2024-01-01T00:00:00Z",
      "finish": "matte"
    }
  ],
  "nextPageToken": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/materials"
```
### `GET /materials/{materialId}` — Get a material
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `materialId` | path | string | Yes |  |

**Success response:** `200` OK (Material)

```json
{
  "name": "string",
  "type": "horn",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "finish": "matte"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/materials/material_id"
```
### `GET /products` — List products (SKU)
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `shape` | query | string | No |  |
| `sizeMm` | query | number | No |  |
| `materialId` | query | string | No |  |

**Success response:** `200` OK (PageProduct)

```json
{
  "items": [
    {
      "sku": "string",
      "materialRef": "string",
      "shape": "round",
      "size": {
        "mm": "..."
      },
      "basePrice": {
        "amount": "...",
        "currency": "..."
      },
      "stockPolicy": "madeToOrder",
      "isActive": true,
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "nextPageToken": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/products"
```
### `GET /products/{productId}` — Get a product (SKU)
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `productId` | path | string | Yes |  |

**Success response:** `200` OK (Product)

```json
{
  "sku": "string",
  "materialRef": "string",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "basePrice": {
    "amount": 123,
    "currency": "string"
  },
  "stockPolicy": "madeToOrder",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/products/product_id"
```
### `GET /promotions/{code}/public` — Public info for a coupon code (no discount calc)
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `code` | path | string | Yes |  |

**Success response:** `200` OK

```json
{
  "exists": true,
  "active": true,
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/promotions/code/public"
```
### `GET /readyz` — Readiness probe
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X GET "$BASE_URL/readyz"
```
### `GET /templates` — List templates
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `pageSize` | query | integer | No |  |
| `pageToken` | query | string | No |  |

**Success response:** `200` OK (PageTemplate)

```json
{
  "items": [
    {
      "name": "string",
      "shape": "round",
      "writing": "tensho",
      "constraints": {
        "sizeMm": "...",
        "strokeWeight": "...",
        "margin": "...",
        "glyph": "...",
        "registrability": "..."
      },
      "isPublic": true,
      "sort": 123,
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T00:00:00Z"
    }
  ],
  "nextPageToken": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/templates"
```
### `GET /templates/{templateId}` — Get a template
- **Auth:** None (anonymous HTTPS).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `templateId` | path | string | Yes |  |

**Success response:** `200` OK (Template)

```json
{
  "name": "string",
  "shape": "round",
  "writing": "tensho",
  "constraints": {
    "sizeMm": {
      "min": 12.34,
      "max": 12.34,
      "step": 12.34
    },
    "strokeWeight": {
      "min": 12.34,
      "max": 12.34
    },
    "margin": {
      "min": 12.34,
      "max": 12.34
    },
    "glyph": {
      "maxChars": 123,
      "allowRepeat": true,
      "allowedScripts": [
        "..."
      ],
      "prohibitedChars": [
        "..."
      ]
    },
    "registrability": {
      "jpJitsuinAllowed": true,
      "bankInAllowed": true,
      "notes": "string"
    }
  },
  "isPublic": true,
  "sort": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/templates/template_id"
```

## Auth
Authenticated customer profile, addresses, favorites, payment methods, and transliteration helpers.

- **Default auth:** Firebase Auth ID token (role=user, own resources).

### `GET /me` — Get my profile
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK (User)

```json
{
  "persona": "foreigner",
  "preferredLang": "ja",
  "isActive": true,
  "piiMasked": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/me"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `PUT /me` — Update my profile (limited fields)
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `UserUpdate`

```json
{
  "displayName": "string",
  "preferredLang": "ja",
  "country": "string",
  "marketingOptIn": true
}
```

**Success response:** `200` Updated (User)

```json
{
  "persona": "foreigner",
  "preferredLang": "ja",
  "isActive": true,
  "piiMasked": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Sample curl**

```bash
curl -X PUT "$BASE_URL/me"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "displayName": "string",
  "preferredLang": "ja",
  "country": "string",
  "marketingOptIn": true
}
JSON
```
### `GET /me/addresses` — List my addresses
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK

```json
[
  {
    "recipient": "string",
    "line1": "string",
    "city": "string",
    "postalCode": "string",
    "country": "string"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/me/addresses"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /me/addresses` — Add address
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Address`

```json
{
  "recipient": "string",
  "line1": "string",
  "city": "string",
  "postalCode": "string",
  "country": "string"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/me/addresses"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "recipient": "string",
  "line1": "string",
  "city": "string",
  "postalCode": "string",
  "country": "string"
}
JSON
```
### `DELETE /me/addresses/{addressId}` — Delete address
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `addressId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/me/addresses/address_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /me/addresses/{addressId}` — Update address
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `addressId` | path | string | Yes |  |

**Request body schema:** `Address`

```json
{
  "recipient": "string",
  "line1": "string",
  "city": "string",
  "postalCode": "string",
  "country": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/me/addresses/address_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "recipient": "string",
  "line1": "string",
  "city": "string",
  "postalCode": "string",
  "country": "string"
}
JSON
```
### `GET /me/favorites` — List my favorite designs
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK

```json
[
  {
    "designRef": "string",
    "addedAt": "2024-01-01T00:00:00Z",
    "note": "string",
    "tags": [
      "string"
    ]
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/me/favorites"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `DELETE /me/favorites/{designId}` — Remove favorite
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/me/favorites/design_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /me/favorites/{designId}` — Add favorite
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X PUT "$BASE_URL/me/favorites/design_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `GET /me/payment-methods` — List my payment methods (PSP references)
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK

```json
[
  {
    "provider": "stripe",
    "methodType": "card",
    "providerRef": "string",
    "brand": "string",
    "last4": "string"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/me/payment-methods"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /me/payment-methods` — Add payment method reference
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `PaymentMethod`

```json
{
  "provider": "stripe",
  "methodType": "card",
  "providerRef": "string",
  "brand": "string",
  "last4": "string"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/me/payment-methods"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "provider": "stripe",
  "methodType": "card",
  "providerRef": "string",
  "brand": "string",
  "last4": "string"
}
JSON
```
### `DELETE /me/payment-methods/{pmId}` — Remove payment method
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `pmId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/me/payment-methods/pm_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /name-mappings/{mappingId}:select` — Select a candidate
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `mappingId` | path | string | Yes |  |

**Request body schema:** `inline`

```json
{
  "selected": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/name-mappings/mapping_id:select"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "selected": "string"
}
JSON
```
### `POST /name-mappings:convert` — Convert latin name to kanji candidates
- **Auth:** Firebase Auth ID token (role=user, own resources).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "latin": "string",
  "locale": "string"
}
```

**Success response:** `200` OK (NameMapping)

```json
{
  "input": {
    "latin": "string",
    "locale": "string"
  },
  "candidates": [
    {
      "kanji": "string",
      "meanings": [
        "..."
      ],
      "score": 12.34
    }
  ],
  "selected": "string",
  "ownerRef": "string",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Sample curl**

```bash
curl -X POST "$BASE_URL/name-mappings:convert"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "latin": "string",
  "locale": "string"
}
JSON
```

## Designs
User-owned design lifecycle plus AI suggestion orchestration.

- **Default auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.

### `GET /designs` — List my designs
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK (PageDesign)

```json
{
  "items": [
    {
      "ownerRef": "string",
      "status": "draft",
      "shape": "round",
      "size": {
        "mm": "..."
      },
      "style": {
        "writing": "...",
        "fontRef": "...",
        "templateRef": "...",
        "stroke": "...",
        "layout": "..."
      },
      "version": 123,
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T00:00:00Z"
    }
  ],
  "nextPageToken": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/designs"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /designs` — Create a design
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Design`

```json
{
  "ownerRef": "string",
  "status": "draft",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "style": {
    "writing": "tensho",
    "fontRef": "string",
    "templateRef": "string",
    "stroke": {
      "weight": 12.34,
      "contrast": 12.34
    },
    "layout": {
      "grid": "string",
      "margin": 12.34
    }
  },
  "version": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/designs"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "ownerRef": "string",
  "status": "draft",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "style": {
    "writing": "tensho",
    "fontRef": "string",
    "templateRef": "string",
    "stroke": {
      "weight": 12.34,
      "contrast": 12.34
    },
    "layout": {
      "grid": "string",
      "margin": 12.34
    }
  },
  "version": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /designs/{designId}` — Delete a design
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/designs/design_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `GET /designs/{designId}` — Get a design
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Success response:** `200` OK (Design)

```json
{
  "ownerRef": "string",
  "status": "draft",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "style": {
    "writing": "tensho",
    "fontRef": "string",
    "templateRef": "string",
    "stroke": {
      "weight": 12.34,
      "contrast": 12.34
    },
    "layout": {
      "grid": "string",
      "margin": 12.34
    }
  },
  "version": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/designs/design_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `PUT /designs/{designId}` — Update a design
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Request body schema:** `Design`

```json
{
  "ownerRef": "string",
  "status": "draft",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "style": {
    "writing": "tensho",
    "fontRef": "string",
    "templateRef": "string",
    "stroke": {
      "weight": 12.34,
      "contrast": 12.34
    },
    "layout": {
      "grid": "string",
      "margin": 12.34
    }
  },
  "version": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/designs/design_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "ownerRef": "string",
  "status": "draft",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "style": {
    "writing": "tensho",
    "fontRef": "string",
    "templateRef": "string",
    "stroke": {
      "weight": 12.34,
      "contrast": 12.34
    },
    "layout": {
      "grid": "string",
      "margin": 12.34
    }
  },
  "version": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `GET /designs/{designId}/ai-suggestions` — List AI suggestions
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Success response:** `200` OK

```json
[
  {
    "jobRef": "string",
    "designRef": "string",
    "baseVersion": 123,
    "baseHash": "string",
    "score": 12.34,
    "preview": {
      "previewUrl": "https://example.com/resource",
      "diffUrl": "https://example.com/resource",
      "assetRef": "string",
      "svgUrl": "https://example.com/resource"
    },
    "status": "proposed",
    "createdAt": "2024-01-01T00:00:00Z",
    "createdBy": "string"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/designs/design_id/ai-suggestions"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /designs/{designId}/ai-suggestions` — Enqueue AI suggestion generation
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Request body schema:** `inline`

```json
{
  "method": "balance",
  "model": "string"
}
```

**Success response:** `202` Accepted

**Sample curl**

```bash
curl -X POST "$BASE_URL/designs/design_id/ai-suggestions"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "method": "balance",
  "model": "string"
}
JSON
```
### `GET /designs/{designId}/ai-suggestions/{suggestionId}` — Get an AI suggestion
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |
| `suggestionId` | path | string | Yes |  |

**Success response:** `200` OK (AISuggestion)

```json
{
  "jobRef": "string",
  "designRef": "string",
  "baseVersion": 123,
  "baseHash": "string",
  "score": 12.34,
  "preview": {
    "previewUrl": "https://example.com/resource",
    "diffUrl": "https://example.com/resource",
    "assetRef": "string",
    "svgUrl": "https://example.com/resource"
  },
  "status": "proposed",
  "createdAt": "2024-01-01T00:00:00Z",
  "createdBy": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/designs/design_id/ai-suggestions/suggestion_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /designs/{designId}/ai-suggestions/{suggestionId}:accept` — Accept/apply suggestion
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |
| `suggestionId` | path | string | Yes |  |

**Success response:** `200` Applied

**Sample curl**

```bash
curl -X POST "$BASE_URL/designs/design_id/ai-suggestions/suggestion_id:accept"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /designs/{designId}/ai-suggestions/{suggestionId}:reject` — Reject suggestion
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |
| `suggestionId` | path | string | Yes |  |

**Success response:** `200` Rejected

**Sample curl**

```bash
curl -X POST "$BASE_URL/designs/design_id/ai-suggestions/suggestion_id:reject"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `GET /designs/{designId}/versions` — List versions (snapshots)
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Success response:** `200` OK

```json
[
  {
    "version": 123,
    "snapshot": {
      "ownerRef": "string",
      "status": "draft",
      "shape": "round",
      "size": {
        "mm": "..."
      },
      "style": {
        "writing": "...",
        "fontRef": "...",
        "templateRef": "...",
        "stroke": "...",
        "layout": "..."
      },
      "version": 123,
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T00:00:00Z"
    },
    "createdAt": "2024-01-01T00:00:00Z",
    "createdBy": "string",
    "changeNote": "string"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/designs/design_id/versions"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /designs/{designId}:registrability-check` — Check registrability for official seals
- **Auth:** Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `designId` | path | string | Yes |  |

**Success response:** `200` OK

```json
{
  "registrable": true,
  "diagnostics": [
    "string"
  ]
}
```

**Sample curl**

```bash
curl -X POST "$BASE_URL/designs/design_id:registrability-check"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```

## Cart
Cart header, line items, promotions, and checkout orchestration endpoints for signed-in buyers.

- **Default auth:** Firebase Auth ID token (role=user).

### `GET /cart` — Get cart header
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK (CartHeader)

```json
{
  "currency": "string",
  "itemsCount": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "promo": {
    "code": "string",
    "promotionRef": "string",
    "discountAmount": 123
  }
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/cart"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `PATCH /cart` — Update cart header (currency/promo)
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `CartHeaderPatch`

```json
{
  "currency": "string",
  "promoCode": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PATCH "$BASE_URL/cart"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "currency": "string",
  "promoCode": "string"
}
JSON
```
### `GET /cart/items` — List cart items
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK

```json
[
  {
    "designRef": "string",
    "productRef": "string",
    "qty": 123,
    "unitPrice": {
      "amount": 123,
      "currency": "string"
    },
    "snapshot": {
      "designHash": "string",
      "designSizeMm": 12.34,
      "shape": "round"
    },
    "createdAt": "2024-01-01T00:00:00Z"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/cart/items"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /cart/items` — Add item to cart
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `CartItem`

```json
{
  "designRef": "string",
  "productRef": "string",
  "qty": 123,
  "unitPrice": {
    "amount": 123,
    "currency": "string"
  },
  "snapshot": {
    "designHash": "string",
    "designSizeMm": 12.34,
    "shape": "round"
  },
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/cart/items"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "designRef": "string",
  "productRef": "string",
  "qty": 123,
  "unitPrice": {
    "amount": 123,
    "currency": "string"
  },
  "snapshot": {
    "designHash": "string",
    "designSizeMm": 12.34,
    "shape": "round"
  },
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /cart/items/{itemId}` — Remove cart item
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `itemId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/cart/items/item_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /cart/items/{itemId}` — Update cart item
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `itemId` | path | string | Yes |  |

**Request body schema:** `CartItem`

```json
{
  "designRef": "string",
  "productRef": "string",
  "qty": 123,
  "unitPrice": {
    "amount": 123,
    "currency": "string"
  },
  "snapshot": {
    "designHash": "string",
    "designSizeMm": 12.34,
    "shape": "round"
  },
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/cart/items/item_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "designRef": "string",
  "productRef": "string",
  "qty": 123,
  "unitPrice": {
    "amount": 123,
    "currency": "string"
  },
  "snapshot": {
    "designHash": "string",
    "designSizeMm": 12.34,
    "shape": "round"
  },
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `POST /cart:apply-promo` — Apply a coupon code
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "code": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/cart:apply-promo"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "code": "string"
}
JSON
```
### `POST /cart:estimate` — Estimate totals (tax/shipping/discount)
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Success response:** `200` OK (Estimate)

```json
{
  "currency": "string",
  "subtotal": 123,
  "discount": 123,
  "tax": 123,
  "shipping": 123,
  "total": 123
}
```

**Sample curl**

```bash
curl -X POST "$BASE_URL/cart:estimate"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `DELETE /cart:remove-promo` — Remove coupon from cart
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/cart:remove-promo"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /checkout/confirm` — Client confirmation ping (finalization via webhook)
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/checkout/confirm"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /checkout/session` — Create PSP checkout session
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "provider": "stripe"
}
```

**Success response:** `200` OK

```json
{
  "sessionId": "string",
  "url": "string"
}
```

**Sample curl**

```bash
curl -X POST "$BASE_URL/checkout/session"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "provider": "stripe"
}
JSON
```

## Orders
Customer-facing order, payment, shipment, and reorder operations scoped to the caller.

- **Default auth:** Firebase Auth ID token (role=user) scoped to order owner.

### `GET /orders` — List my orders
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK (PageOrder)

```json
{
  "items": [
    {
      "userRef": "string",
      "status": "pending",
      "currency": "string",
      "amounts": {
        "subtotal": "...",
        "tax": "...",
        "shipping": "...",
        "total": "...",
        "discount": "..."
      },
      "items": [
        "..."
      ],
      "shipping": {
        "address": "...",
        "method": "...",
        "requestedAt": "...",
        "tracking": "..."
      },
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "nextPageToken": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/orders"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `GET /orders/{orderId}` — Get my order
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Success response:** `200` OK (Order)

```json
{
  "userRef": "string",
  "status": "pending",
  "currency": "string",
  "amounts": {
    "subtotal": 123,
    "tax": 123,
    "shipping": 123,
    "total": 123,
    "discount": 123
  },
  "items": [
    {
      "lineId": "string",
      "productRef": "string",
      "sku": "string",
      "qty": 123,
      "unitPrice": 123,
      "designSnapshot": {
        "designId": "...",
        "hash": "...",
        "svg": "...",
        "shape": "...",
        "sizeMm": "...",
        "writing": "..."
      }
    }
  ],
  "shipping": {
    "address": {
      "recipient": "string",
      "line1": "string",
      "city": "string",
      "postalCode": "string",
      "country": "string"
    },
    "method": "intl",
    "requestedAt": "2024-01-01T00:00:00Z",
    "tracking": {}
  },
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Error codes:** `404` Resource not found

**Sample curl**

```bash
curl -X GET "$BASE_URL/orders/order_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `GET /orders/{orderId}/payments` — List payments for an order
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Success response:** `200` OK

```json
[
  {
    "provider": "stripe",
    "status": "requires_action",
    "amount": 123,
    "currency": "string",
    "createdAt": "2024-01-01T00:00:00Z"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/orders/order_id/payments"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `GET /orders/{orderId}/production-events` — List production events
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Success response:** `200` OK

```json
[
  {
    "type": "queued",
    "createdAt": "2024-01-01T00:00:00Z",
    "station": "string",
    "operatorRef": "string",
    "durationSec": 123
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/orders/order_id/production-events"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `GET /orders/{orderId}/shipments` — List shipments
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Success response:** `200` OK

```json
[
  {
    "carrier": "JPPOST",
    "status": "label_created",
    "createdAt": "2024-01-01T00:00:00Z",
    "service": "string",
    "trackingNumber": "string"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/orders/order_id/shipments"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `GET /orders/{orderId}/shipments/{shipmentId}` — Get shipment
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |
| `shipmentId` | path | string | Yes |  |

**Success response:** `200` OK (Shipment)

```json
{
  "carrier": "JPPOST",
  "status": "label_created",
  "createdAt": "2024-01-01T00:00:00Z",
  "service": "string",
  "trackingNumber": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/orders/order_id/shipments/shipment_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /orders/{orderId}:cancel` — Request order cancellation (pre-shipment)
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/orders/order_id:cancel"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /orders/{orderId}:reorder` — Reorder using design snapshot
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/orders/order_id:reorder"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /orders/{orderId}:request-invoice` — Request invoice/receipt issuance
- **Auth:** Firebase Auth ID token (role=user) scoped to order owner.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Success response:** `202` Accepted

**Sample curl**

```bash
curl -X POST "$BASE_URL/orders/order_id:request-invoice"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```

## Reviews
End-user review submission and retrieval endpoints.

- **Default auth:** Firebase Auth ID token (role=user).

### `GET /reviews` — List my reviews
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | query | string | No |  |

**Success response:** `200` OK

```json
[
  {
    "orderRef": "string",
    "userRef": "string",
    "rating": 123,
    "isPublic": true,
    "createdAt": "2024-01-01T00:00:00Z"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/reviews"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /reviews` — Create a review
- **Auth:** Firebase Auth ID token (role=user).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Review`

```json
{
  "orderRef": "string",
  "userRef": "string",
  "rating": 123,
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/reviews"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "orderRef": "string",
  "userRef": "string",
  "rating": 123,
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```

## Assets
Signed upload/download helpers for design previews and supporting documents.

- **Default auth:** Firebase Auth ID token (role=user or staff).

### `POST /assets/{assetId}:signed-download` — Issue a signed download URL
- **Auth:** Firebase Auth ID token (role=user or staff).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `assetId` | path | string | Yes |  |

**Success response:** `200` OK

```json
{
  "url": "string",
  "expiresAt": "2024-01-01T00:00:00Z"
}
```

**Sample curl**

```bash
curl -X POST "$BASE_URL/assets/asset_id:signed-download"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /assets:signed-upload` — Issue a signed upload URL
- **Auth:** Firebase Auth ID token (role=user or staff).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "kind": "svg",
  "purpose": "design-master",
  "mimeType": "string"
}
```

**Success response:** `200` OK

```json
{
  "uploadUrl": "string",
  "assetId": "string"
}
```

**Sample curl**

```bash
curl -X POST "$BASE_URL/assets:signed-upload"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "kind": "svg",
  "purpose": "design-master",
  "mimeType": "string"
}
JSON
```

## Admin
Staff/admin-only catalog, promotion, content, order, production, counter, and audit operations.

- **Default auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.

### `POST /admin/catalog/fonts` — Create font
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Font`

```json
{
  "family": "string",
  "writing": "tensho",
  "license": {
    "type": "commercial",
    "uri": "https://example.com/resource",
    "text": "string",
    "restrictions": [
      "string"
    ],
    "embeddable": true
  },
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/catalog/fonts"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "family": "string",
  "writing": "tensho",
  "license": {
    "type": "commercial",
    "uri": "https://example.com/resource",
    "text": "string",
    "restrictions": [
      "string"
    ],
    "embeddable": true
  },
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /admin/catalog/fonts/{fontId}` — Delete font
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `fontId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/catalog/fonts/font_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/catalog/fonts/{fontId}` — Update font
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `fontId` | path | string | Yes |  |

**Request body schema:** `Font`

```json
{
  "family": "string",
  "writing": "tensho",
  "license": {
    "type": "commercial",
    "uri": "https://example.com/resource",
    "text": "string",
    "restrictions": [
      "string"
    ],
    "embeddable": true
  },
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/catalog/fonts/font_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "family": "string",
  "writing": "tensho",
  "license": {
    "type": "commercial",
    "uri": "https://example.com/resource",
    "text": "string",
    "restrictions": [
      "string"
    ],
    "embeddable": true
  },
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `POST /admin/catalog/materials` — Create material
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Material`

```json
{
  "name": "string",
  "type": "horn",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "finish": "matte"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/catalog/materials"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "name": "string",
  "type": "horn",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "finish": "matte"
}
JSON
```
### `DELETE /admin/catalog/materials/{materialId}` — Delete material
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `materialId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/catalog/materials/material_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/catalog/materials/{materialId}` — Update material
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `materialId` | path | string | Yes |  |

**Request body schema:** `Material`

```json
{
  "name": "string",
  "type": "horn",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "finish": "matte"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/catalog/materials/material_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "name": "string",
  "type": "horn",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "finish": "matte"
}
JSON
```
### `POST /admin/catalog/products` — Create product
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Product`

```json
{
  "sku": "string",
  "materialRef": "string",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "basePrice": {
    "amount": 123,
    "currency": "string"
  },
  "stockPolicy": "madeToOrder",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/catalog/products"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "sku": "string",
  "materialRef": "string",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "basePrice": {
    "amount": 123,
    "currency": "string"
  },
  "stockPolicy": "madeToOrder",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /admin/catalog/products/{productId}` — Delete product
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `productId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/catalog/products/product_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/catalog/products/{productId}` — Update product
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `productId` | path | string | Yes |  |

**Request body schema:** `Product`

```json
{
  "sku": "string",
  "materialRef": "string",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "basePrice": {
    "amount": 123,
    "currency": "string"
  },
  "stockPolicy": "madeToOrder",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/catalog/products/product_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "sku": "string",
  "materialRef": "string",
  "shape": "round",
  "size": {
    "mm": 12.34
  },
  "basePrice": {
    "amount": 123,
    "currency": "string"
  },
  "stockPolicy": "madeToOrder",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `POST /admin/catalog/templates` — Create template
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Template`

```json
{
  "name": "string",
  "shape": "round",
  "writing": "tensho",
  "constraints": {
    "sizeMm": {
      "min": 12.34,
      "max": 12.34,
      "step": 12.34
    },
    "strokeWeight": {
      "min": 12.34,
      "max": 12.34
    },
    "margin": {
      "min": 12.34,
      "max": 12.34
    },
    "glyph": {
      "maxChars": 123,
      "allowRepeat": true,
      "allowedScripts": [
        "..."
      ],
      "prohibitedChars": [
        "..."
      ]
    },
    "registrability": {
      "jpJitsuinAllowed": true,
      "bankInAllowed": true,
      "notes": "string"
    }
  },
  "isPublic": true,
  "sort": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/catalog/templates"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "name": "string",
  "shape": "round",
  "writing": "tensho",
  "constraints": {
    "sizeMm": {
      "min": 12.34,
      "max": 12.34,
      "step": 12.34
    },
    "strokeWeight": {
      "min": 12.34,
      "max": 12.34
    },
    "margin": {
      "min": 12.34,
      "max": 12.34
    },
    "glyph": {
      "maxChars": 123,
      "allowRepeat": true,
      "allowedScripts": [
        "..."
      ],
      "prohibitedChars": [
        "..."
      ]
    },
    "registrability": {
      "jpJitsuinAllowed": true,
      "bankInAllowed": true,
      "notes": "string"
    }
  },
  "isPublic": true,
  "sort": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /admin/catalog/templates/{templateId}` — Delete template
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `templateId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/catalog/templates/template_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/catalog/templates/{templateId}` — Update template
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `templateId` | path | string | Yes |  |

**Request body schema:** `Template`

```json
{
  "name": "string",
  "shape": "round",
  "writing": "tensho",
  "constraints": {
    "sizeMm": {
      "min": 12.34,
      "max": 12.34,
      "step": 12.34
    },
    "strokeWeight": {
      "min": 12.34,
      "max": 12.34
    },
    "margin": {
      "min": 12.34,
      "max": 12.34
    },
    "glyph": {
      "maxChars": 123,
      "allowRepeat": true,
      "allowedScripts": [
        "..."
      ],
      "prohibitedChars": [
        "..."
      ]
    },
    "registrability": {
      "jpJitsuinAllowed": true,
      "bankInAllowed": true,
      "notes": "string"
    }
  },
  "isPublic": true,
  "sort": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/catalog/templates/template_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "name": "string",
  "shape": "round",
  "writing": "tensho",
  "constraints": {
    "sizeMm": {
      "min": 12.34,
      "max": 12.34,
      "step": 12.34
    },
    "strokeWeight": {
      "min": 12.34,
      "max": 12.34
    },
    "margin": {
      "min": 12.34,
      "max": 12.34
    },
    "glyph": {
      "maxChars": 123,
      "allowRepeat": true,
      "allowedScripts": [
        "..."
      ],
      "prohibitedChars": [
        "..."
      ]
    },
    "registrability": {
      "jpJitsuinAllowed": true,
      "bankInAllowed": true,
      "notes": "string"
    }
  },
  "isPublic": true,
  "sort": 123,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `POST /admin/content/guides` — Create guide
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Guide`

```json
{
  "slug": "string",
  "category": "culture",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/content/guides"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "slug": "string",
  "category": "culture",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /admin/content/guides/{guideId}` — Delete guide
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `guideId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/content/guides/guide_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/content/guides/{guideId}` — Update guide
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `guideId` | path | string | Yes |  |

**Request body schema:** `Guide`

```json
{
  "slug": "string",
  "category": "culture",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/content/guides/guide_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "slug": "string",
  "category": "culture",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `POST /admin/content/pages` — Create page
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Page`

```json
{
  "slug": "string",
  "type": "landing",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/content/pages"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "slug": "string",
  "type": "landing",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /admin/content/pages/{pageId}` — Delete page
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `pageId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/content/pages/page_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/content/pages/{pageId}` — Update page
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `pageId` | path | string | Yes |  |

**Request body schema:** `Page`

```json
{
  "slug": "string",
  "type": "landing",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/content/pages/page_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "slug": "string",
  "type": "landing",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `POST /admin/counters/{name}:next` — Get next sequence number
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `name` | path | string | Yes |  |

**Request body schema:** `inline`

```json
{
  "scope": {}
}
```

**Success response:** `200` OK

```json
{
  "number": "string"
}
```

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/counters/name:next"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "scope": {}
}
JSON
```
### `POST /admin/invoices:issue` — Issue invoice(s) and attach PDFs
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "orderIds": [
    "string"
  ]
}
```

**Success response:** `202` Accepted

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/invoices:issue"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "orderIds": [
    "string"
  ]
}
JSON
```
### `GET /admin/orders` — Admin list orders
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `status` | query | string | No |  |
| `since` | query | string | No |  |

**Success response:** `200` OK (PageOrder)

```json
{
  "items": [
    {
      "userRef": "string",
      "status": "pending",
      "currency": "string",
      "amounts": {
        "subtotal": "...",
        "tax": "...",
        "shipping": "...",
        "total": "...",
        "discount": "..."
      },
      "items": [
        "..."
      ],
      "shipping": {
        "address": "...",
        "method": "...",
        "requestedAt": "...",
        "tracking": "..."
      },
      "createdAt": "2024-01-01T00:00:00Z"
    }
  ],
  "nextPageToken": "string"
}
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/admin/orders"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /admin/orders/{orderId}/production-events` — Append production event
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Request body schema:** `ProductionEvent`

```json
{
  "type": "queued",
  "createdAt": "2024-01-01T00:00:00Z",
  "station": "string",
  "operatorRef": "string",
  "durationSec": 123
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/orders/order_id/production-events"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "type": "queued",
  "createdAt": "2024-01-01T00:00:00Z",
  "station": "string",
  "operatorRef": "string",
  "durationSec": 123
}
JSON
```
### `POST /admin/orders/{orderId}/shipments` — Create shipment & label
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Request body schema:** `Shipment`

```json
{
  "carrier": "JPPOST",
  "status": "label_created",
  "createdAt": "2024-01-01T00:00:00Z",
  "service": "string",
  "trackingNumber": "string"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/orders/order_id/shipments"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "carrier": "JPPOST",
  "status": "label_created",
  "createdAt": "2024-01-01T00:00:00Z",
  "service": "string",
  "trackingNumber": "string"
}
JSON
```
### `PUT /admin/orders/{orderId}:status` — Transition order status
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `orderId` | path | string | Yes |  |

**Request body schema:** `inline`

```json
{
  "status": "pending",
  "note": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/orders/order_id:status"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "status": "pending",
  "note": "string"
}
JSON
```
### `GET /admin/production-queues` — List production queues
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK

```json
[
  {
    "name": "string",
    "active": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "timezone": "string",
    "capacity": 123
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/admin/production-queues"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /admin/production-queues` — Create queue
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `ProductionQueue`

```json
{
  "name": "string",
  "active": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "timezone": "string",
  "capacity": 123
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/production-queues"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "name": "string",
  "active": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "timezone": "string",
  "capacity": 123
}
JSON
```
### `DELETE /admin/production-queues/{queueId}` — Delete queue
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `queueId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/production-queues/queue_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/production-queues/{queueId}` — Update queue
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `queueId` | path | string | Yes |  |

**Request body schema:** `ProductionQueue`

```json
{
  "name": "string",
  "active": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "timezone": "string",
  "capacity": 123
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/production-queues/queue_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "name": "string",
  "active": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "timezone": "string",
  "capacity": 123
}
JSON
```
### `GET /admin/promotions` — List promotions
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Not required (safe verb).

**Success response:** `200` OK

```json
[
  {
    "code": "string",
    "kind": "percent",
    "value": 12.34,
    "isActive": true,
    "startsAt": "2024-01-01T00:00:00Z",
    "endsAt": "2024-01-01T00:00:00Z",
    "usageLimit": 123,
    "usageCount": 123,
    "limitPerUser": 123,
    "createdAt": "2024-01-01T00:00:00Z"
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/admin/promotions"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `POST /admin/promotions` — Create promotion
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `Promotion`

```json
{
  "code": "string",
  "kind": "percent",
  "value": 12.34,
  "isActive": true,
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-01T00:00:00Z",
  "usageLimit": 123,
  "usageCount": 123,
  "limitPerUser": 123,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `201` Created

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/promotions"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "code": "string",
  "kind": "percent",
  "value": 12.34,
  "isActive": true,
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-01T00:00:00Z",
  "usageLimit": 123,
  "usageCount": 123,
  "limitPerUser": 123,
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `DELETE /admin/promotions/{promoId}` — Delete promotion
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `promoId` | path | string | Yes |  |

**Success response:** `204` No Content

_No response body_

**Sample curl**

```bash
curl -X DELETE "$BASE_URL/admin/promotions/promo_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `PUT /admin/promotions/{promoId}` — Update promotion
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `promoId` | path | string | Yes |  |

**Request body schema:** `Promotion`

```json
{
  "code": "string",
  "kind": "percent",
  "value": 12.34,
  "isActive": true,
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-01T00:00:00Z",
  "usageLimit": 123,
  "usageCount": 123,
  "limitPerUser": 123,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/promotions/promo_id"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "code": "string",
  "kind": "percent",
  "value": 12.34,
  "isActive": true,
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-01T00:00:00Z",
  "usageLimit": 123,
  "usageCount": 123,
  "limitPerUser": 123,
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `GET /admin/promotions/{promoId}/usages` — List per-user usages for a promotion
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `promoId` | path | string | Yes |  |

**Success response:** `200` OK

```json
[
  {
    "uid": "string",
    "times": 123,
    "lastUsedAt": "2024-01-01T00:00:00Z",
    "firstUsedAt": "2024-01-01T00:00:00Z",
    "orderRefs": [
      "string"
    ]
  }
]
```

**Sample curl**

```bash
curl -X GET "$BASE_URL/admin/promotions/promo_id/usages"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `GET /admin/reviews` — List reviews for moderation
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Not required (safe verb).

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `moderation` | query | string | No |  |

**Success response:** `200` OK

**Sample curl**

```bash
curl -X GET "$BASE_URL/admin/reviews"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
```
### `PUT /admin/reviews/{reviewId}:moderate` — Moderate review
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `reviewId` | path | string | Yes |  |

**Request body schema:** `inline`

```json
{
  "moderation": "approved"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X PUT "$BASE_URL/admin/reviews/review_id:moderate"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "moderation": "approved"
}
JSON
```
### `POST /admin/reviews/{reviewId}:store-reply` — Store a public reply from store
- **Auth:** Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `reviewId` | path | string | Yes |  |

**Request body schema:** `inline`

```json
{
  "body": "string",
  "isPublic": true
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/admin/reviews/review_id:store-reply"
  -H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "body": "string",
  "isPublic": true
}
JSON
```

## Webhooks
Inbound integrations from PSPs, shipping carriers, and AI workers with HMAC verification.

- **Default auth:** HMAC signature header (per integration secret).

### `POST /webhooks/ai/worker` — AI worker push
- **Auth:** HMAC signature header (per integration secret).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{}
```

**Success response:** `202` Accepted

**Sample curl**

```bash
curl -X POST "$BASE_URL/webhooks/ai/worker"
  -H "X-Signature: ${SIGNATURE}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{}
JSON
```
### `POST /webhooks/payments/stripe` — Stripe events webhook
- **Auth:** HMAC signature header (per integration secret).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/webhooks/payments/stripe"
  -H "X-Signature: ${SIGNATURE}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{}
JSON
```
### `POST /webhooks/shipping/{carrier}` — Shipping carrier webhook
- **Auth:** HMAC signature header (per integration secret).
- **Idempotency:** Required via `Idempotency-Key` header.

| Name | In | Type | Required | Description |
| --- | --- | --- | --- | --- |
| `carrier` | path | string | Yes |  |

**Request body schema:** `inline`

```json
{}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/webhooks/shipping/carrier"
  -H "X-Signature: ${SIGNATURE}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{}
JSON
```

## Internal
Service-to-service endpoints invoked by background jobs, Cloud Run jobs, or Cloud Scheduler.

- **Default auth:** Workload Identity / OIDC server-to-server token (system role).

### `POST /internal/checkout/commit` — Commit reservation after successful payment
- **Auth:** Workload Identity / OIDC server-to-server token (system role).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "orderId": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/internal/checkout/commit"
  -H "Authorization: Bearer ${OIDC_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "orderId": "string"
}
JSON
```
### `POST /internal/checkout/release` — Release reservation (payment timeout/failure)
- **Auth:** Workload Identity / OIDC server-to-server token (system role).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "orderId": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/internal/checkout/release"
  -H "Authorization: Bearer ${OIDC_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "orderId": "string"
}
JSON
```
### `POST /internal/checkout/reserve-stock` — Reserve stock and create /stockReservations
- **Auth:** Workload Identity / OIDC server-to-server token (system role).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `StockReservation`

```json
{
  "orderRef": "string",
  "userRef": "string",
  "status": "reserved",
  "lines": [
    {
      "productRef": "string",
      "sku": "string",
      "qty": 123
    }
  ],
  "expiresAt": "2024-01-01T00:00:00Z",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/internal/checkout/reserve-stock"
  -H "Authorization: Bearer ${OIDC_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "orderRef": "string",
  "userRef": "string",
  "status": "reserved",
  "lines": [
    {
      "productRef": "string",
      "sku": "string",
      "qty": 123
    }
  ],
  "expiresAt": "2024-01-01T00:00:00Z",
  "createdAt": "2024-01-01T00:00:00Z"
}
JSON
```
### `POST /internal/maintenance/cleanup-reservations` — Expire & release stale stock reservations
- **Auth:** Workload Identity / OIDC server-to-server token (system role).
- **Idempotency:** Required via `Idempotency-Key` header.

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/internal/maintenance/cleanup-reservations"
  -H "Authorization: Bearer ${OIDC_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
```
### `POST /internal/promotions/apply` — Atomically apply promotion usage & limits
- **Auth:** Workload Identity / OIDC server-to-server token (system role).
- **Idempotency:** Required via `Idempotency-Key` header.

**Request body schema:** `inline`

```json
{
  "promotionId": "string",
  "uid": "string"
}
```

**Success response:** `200` OK

**Sample curl**

```bash
curl -X POST "$BASE_URL/internal/promotions/apply"
  -H "Authorization: Bearer ${OIDC_TOKEN}"
  -H "Idempotency-Key: $(uuidgen)"
  -H "Content-Type: application/json"
  -d @- <<'JSON'
{
  "promotionId": "string",
  "uid": "string"
}
JSON
```
