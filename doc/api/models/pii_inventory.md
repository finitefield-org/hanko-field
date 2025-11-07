# PII Inventory & Masking Rules

Authoritative mapping of personal/sensitive fields handled by the API layer. Keep in sync with Firestore schemas and PSP contracts.

## Legend
- **Class**: P0–P3 levels defined in `doc/api/models/data-protection.md`.
- **Retention**: Maximum time raw value persists (regulators may require longer for financial records).
- **Masking**: Helper to apply (`mask.Email`, `mask.Phone`, etc.) or storage strategy (hash/encrypted).

## Core Entities

| Entity | Field | Description | Class | Masking/Storage | Retention |
| --- | --- | --- | --- | --- | --- |
| users | displayName | User-provided name | P2 | `mask.Name` in logs; Firestore retains raw until deactivate request | Until user deletion + 30d backup |
| users | email | Login + notification email | P2 | Stored raw (Firebase Auth canonical); Firestore copy masked after deactivate; logs use `mask.Email` | Active lifecycle + 30d backup |
| users | phone | E.164 contact number | P2 | Stored raw; masked in logs/exports; hashed for analytics | Active lifecycle + 30d backup |
| users | addressSnapshot.* | Default shipping | P2 | Persist raw for fulfillment; `mask.Address` for logs/exports | Order + 7y (regulatory) |
| users | paymentRefs | PSP customer/payment ids | P3 | Token only; never log raw; hashed (HMAC) for analytics | Active lifecycle + 7y |
| users | firebaseAuthUID | Auth identifier | P1 | Safe to log; still hashed for analytics joins | Indefinite while user exists |
| orders | shippingAddress.* | Fulfillment destination | P2 | Raw in order doc; `mask.Address` for responses/logs; redacted after deactivate & SLA expiry | Order + 7y |
| orders | contactEmail | Alternate email for order | P2 | Masked in logs/exports; hashed for dedupe | Order + 7y |
| orders | notes | Free text from user | P2 | Strip PII server-side (validator) + `mask.Generic` if stored | Order + 7y |
| payments | pspPayload | PSP response blob | P3 | Stored encrypted Storage object; Firestore only references IDs | 7y |
| payments | billingAddress | Billing info | P2 | Stored raw in payment doc; masked elsewhere | Transaction + 7y |
| auditLogs | actor.displayName | User/staff name | P2 | Mask before persistence (`displayNameMasked`); raw only in encrypted evidence file | 7y |
| auditLogs | actor.ip | IP address | P2 | Store hashed IP; drop raw | 90d |
| favorites | designNotes | Optional text | P1 | No PII expected; run validator to sanitize | Until delete |
| carts | email | Guest checkout email | P2 | Mask in logs; auto-delete 30d after inactivity | 30d |
| supportTickets | message | User-generated text | P2 | Stored raw; redaction pipeline scans weekly; logs store hashed reference only | 3y |
| analytics exports | userKey | Derived key for cohorting | P2 | Use deterministic hash via `mask.Hash` | Until re-export |

## Derived/Secondary Stores

- **BigQuery datasets**: Store masked fields only; add view enforcing `piiMasked=true`.
- **Search indexes (Algolia/Meilisearch)**: Include only template/design metadata; no contact fields allowed.
- **Cache layers (Redis/Memcached)**: TTL <= 15m, values redacted before insert.

## Masking Helpers Reference

| Helper | Example Input | Output | Notes |
| --- | --- | --- | --- |
| `mask.Email("kanae@example.com")` | `kanae@example.com` | `k***@example.com` | Preserve domain for routing. |
| `mask.Phone("+819012345678")` | `+819012345678` | `+81*******678` | Reveal country + last 3 digits. |
| `mask.Name("Kanako Sugiyama")` | `Kanako Sugiyama` | `K*** S***` | Keep initials for audit readability. |
| `mask.Address(Address{Pref:"Tokyo", City:"Shibuya", Line1:"1-2-3"})` | `…` | `Pref=Tokyo, City=Shibuya, Line1=***` | Always redact postal code + lines. |
| `mask.Hash("cust_123")` | `cust_123` | `c43d…` | HMAC-SHA256 with per-env key. |

## Operational Controls

- **PII detectors**: Staticcheck custom rule ensuring `mask.` helper used before logging structs tagged `pii:"true"`.
- **Schema tags**: Extend Firestore models with struct tags `pii:"email"` enabling automatic scrub in middleware.
- **Evidence storage**: Compliance job outputs stored in `gs://hanko-field-$ENV-compliance/pii/{date}/report.json`.

Update this document when new fields are introduced or retention policies change. Add reviewers from Security & Legal for approval.
