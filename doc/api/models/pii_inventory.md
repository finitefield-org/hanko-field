# PII Inventory & Masking Rules

Authoritative mapping of personal/sensitive fields handled by the API layer. Keep in sync with Firestore schemas and PSP contracts.

## Legend
- **Class**: P0–P3 levels defined in `doc/api/models/data-protection.md`.
- **Retention**: Maximum time raw value persists (regulators may require longer for financial records).
- **Masking**: Helper to apply (`mask.Email`, `mask.Phone`, etc.) or storage strategy (hash/encrypted).

## Core Entities

| Entity | Field | Description | Class | Lawful Basis | Storage Location(s) | Masking/Storage Notes | Retention |
| --- | --- | --- | --- | --- | --- | --- | --- |
| users | displayName | User-provided name | P2 | Contract (account provision) | Firestore `/users/{uid}` | `mask.Name` for logs/UI trace; raw only until deactivate | Until user deletion + 30d backup |
| users | email | Login + notification email | P2 | Contract (auth + notices) | Firebase Auth, Firestore `/users/{uid}` | Log via `mask.Email`; Firestore copy scrubbed on deactivate | Active lifecycle + 30d backup |
| users | phone | E.164 contact number | P2 | Contract (2FA/contact) | Firestore `/users/{uid}` | Mask in logs/exports; analytics uses `mask.Hash` | Active lifecycle + 30d backup |
| users | addressSnapshot.* | Default shipping | P2 | Contract + Legal obligation (fulfillment) | Firestore `/users/{uid}/addressSnapshot` | Raw for fulfillment; `mask.Address` elsewhere | Order + 7y (regulatory) |
| users | paymentRefs | PSP customer/payment ids | P3 | Contract + Legal obligation (financial) | Firestore `/users/{uid}`, PSP vault (Stripe) | Tokenized; never log; hashed for analytics joins | Active lifecycle + 7y |
| users | firebaseAuthUID | Auth identifier | P1 | Legitimate interest (security) | Firebase Auth, Firestore references | Safe to log but hashed for analytics | Indefinite while user exists |
| orders | shippingAddress.* | Fulfillment destination | P2 | Contract + Legal obligation | Firestore `/orders/{id}`, BigQuery exports | Mask in responses/logs; redacted post-deactivate SLA | Order + 7y |
| orders | contactEmail | Alternate email for order | P2 | Contract (fulfillment comms) | Firestore `/orders/{id}`, BigQuery exports | `mask.Email` in logs/exports | Order + 7y |
| orders | notes | Free text from user | P2 | Legitimate interest (support) | Firestore `/orders/{id}` | Validator strips PII; fallback `mask.Generic` | Order + 7y |
| payments | pspPayload | PSP response blob | P3 | Legal obligation (financial records) | GCS `gs://hanko-field-$ENV-logs/payments`, encrypted | Stored encrypted; Firestore stores IDs only | 7y |
| payments | billingAddress | Billing info | P2 | Legal obligation (tax/compliance) | Firestore `/payments/{id}` | Mask outside payment domain | Transaction + 7y |
| auditLogs | actor.displayName | User/staff name | P2 | Legitimate interest (traceability) | Firestore `/auditLogs/{id}`, GCS evidence bundle | Store `displayNameMasked`; raw only in encrypted diff | 7y |
| auditLogs | actor.ip | IP address | P2 | Legitimate interest (security monitoring) | Firestore `/auditLogs/{id}` | Store hashed IP; purge raw | 90d |
| favorites | designNotes | Optional text | P1 | Legitimate interest (UX) | Firestore `/favorites/{id}` | Validator ensures no PII | Until delete |
| carts | email | Guest checkout email | P2 | Contract (guest order) | Firestore `/carts/{id}` | Mask in logs; TTL cleanup | 30d |
| supportTickets | message | User-generated text | P2 | Contract (support) + Consent (attachments) | Firestore `/supportTickets/{id}`, GCS attachments | Raw in ticket; weekly redaction scan; logs store hash | 3y |
| analytics exports | userKey | Derived key for cohorting | P2 | Legitimate interest (analytics) | BigQuery `analytics_masked`, GCS exports | Deterministic hash via `mask.Hash`; no raw PII | Until re-export |

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
