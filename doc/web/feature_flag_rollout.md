# Web Feature Flag Rollout Playbook

This playbook documents how the web surface consumes and operates feature flags, how to stage a gradual rollout, and which procedures to follow for a fast rollback.

## Components & Sources
- **Remote config (`HANKO_WEB_REMOTE_CONFIG_URL`)** – primary source. Payload must contain `flags`, optionally `variants`, and may include `meta.rollouts` (see schema below).
- **Environment override (`HANKO_WEB_FEATURE_FLAGS`)** – JSON fallback used when remote config is unreachable.
- **Config file (`HANKO_WEB_FEATURE_FLAG_FILE`)** – optional path to a JSON file bundled with the deploy artifact. The file must live under `HANKO_WEB_FEATURE_FLAG_BASE_DIR` (defaults to the process working directory); paths escaping that directory are rejected to avoid leaking arbitrary files.
- **Runtime overrides (`HANKO_WEB_FEATURE_FLAG_OVERRIDES`)** – comma/semicolon separated list of flag assignments (e.g. `new_checkout=false,ai_writer=true`). Prefix `!`/`-` can disable a flag (`!new_checkout`). When a prefix and explicit value conflict (e.g. `!new_checkout=true`) the entry is ignored and a warning is logged.
- **Feature flag API (`GET /api/feature-flags`)** – exposes the resolved payload (after overrides) for clients that need to refresh on demand or after a page reload (no polling/streaming).

Every successful load publishes Prometheus metrics:
- `hanko_web_feature_flag_enabled{flag,source,version}` – 1 when a flag is active, 0 when disabled.
- `hanko_web_feature_flags_last_refresh_timestamp` – unix timestamp of the last successful refresh.

## Remote Config Schema

Base structure used by the web layer:

```json5
{
  "version": "2024-09-28T08:00Z",
  "flags": {
    "new_checkout": false,
    "design_ai_gallery": true
  },
  "variants": {
    "checkout_flow": "legacy"
  },
  "meta": {
    "identity": {
      "seed": "user-<hashed-id>"
    },
    "rollouts": {
      "_seed": {
        "cookie": "hanko_rollout_id",
        "ttlDays": 180
      },
      "new_checkout": {
        "default": false,
        "percentage": 15,
        "metrics": [
          "checkout.success_rate",
          "checkout.error_rate"
        ],
        "guardrail": "support.tickets_daily < 10",
        "rollbackFlag": "legacy_checkout",
        "startAt": "2024-10-01T00:00:00Z"
      },
      "design_ai_gallery": {
        "force": "on"
      }
    }
  }
}
```

### Rollout semantics
- `_seed` (optional) customises the sticky identifier. When omitted we fall back to an auto-generated cookie (`hanko_rollout_id`, 365 days).
- `default` is the baseline state when no rollout rules apply.
- `force: "on" | "off"` immediately overrides every other rule (useful for rollback).
- `percentage` accepts a value between 0 and 100. The client derives a deterministic bucket from the rollout seed and activates the flag when `bucket < percentage * 100`.
- `seed` (per-flag) appends extra entropy (e.g. `"seed": "wave1"`) so new waves use a fresh distribution while keeping the same visitor id.
- `startAt` / `endAt` gate activation inside a time window (ISO 8601 strings).
- `metrics`, `guardrail`, and `rollbackFlag` are advisory metadata surfaced to the browser for instrumentation.

All rollout decisions, bucket values, and reasons attach to `payload.meta.rolloutState[]`. The value is also reachable via:

```js
window.hankoFlags.exposures(); // returns [{ flag, active, reason, bucket, threshold, ... }]
document.addEventListener('hanko:flags-applied', (evt) => {
  console.debug(evt.detail.rolloutState);
});
```

## Rollout Strategy
1. **Define default + guardrails** in remote config (`default`, `metrics`, `guardrail`, `rollbackFlag`).
2. **Segment early cohorts** by setting `percentage` to a single-digit value (e.g. 5) and optionally `seed: "beta"` to isolate a cohort.
3. **Promote progressively** by increasing `percentage`. Each change only requires updating the remote config (no redeploy).
4. **Monitor**:
   - Dashboards consuming the Prometheus series `hanko_web_feature_flag_enabled`.
   - Browser instrumentation listening to `hanko:flags-ready` / `hanko:flags-applied` events.
   - Business KPIs linked to the `metrics` metadata.
5. **Announce and document** the current wave, expected duration, and guardrails inside the release notes.

Clients that need to refresh without a reload can call:

```js
await window.hankoFlags.refreshRemote(); // fetches /api/feature-flags and reapplies bindings
```

## Rollback Procedures

| Scenario | Action | Time to live |
|---|---|---|
| Immediate customer impact | Set `HANKO_WEB_FEATURE_FLAG_OVERRIDES="new_checkout=false"` and redeploy config (no code build required). | Minutes |
| Remote config available | Update flag entry with `"force": "off"` and publish. Clients honour on next reload or manual refresh. | <5 minutes |
| Local testing / canary | Provide a JSON file via `HANKO_WEB_FEATURE_FLAG_FILE=/etc/hanko/flags.json`. | Until next deploy |

Additional safeguards:
- Keep `legacy` pathways behind inverse flags (e.g. `legacy_checkout`) so that a forced-off rollout has a clear fallback component.
- When forcing a flag off, also reset `percentage` to `0` to avoid surprises once the override is removed.
- Use `window.hankoFlags.rolloutSeed()` to confirm whether a visitor sits in the treated cohort (`hash`, `source`, `ttlDays`).

## Verification Checklist
- [ ] `GET /api/feature-flags` responds with the expected payload (source/version headers included).
- [ ] Prometheus shows `hanko_web_feature_flags_last_refresh_timestamp` moving after a remote update.
- [ ] `document.dispatchEvent('hanko:flags-applied')` includes the rollout metadata for targeted flags.
- [ ] Overrides via `HANKO_WEB_FEATURE_FLAG_OVERRIDES` are reflected without clearing caches (check HTML source).
- [ ] Browser cookie `hanko_rollout_id` exists (or `meta.identity.seed` is provided for authenticated visitors).
- [ ] File-sourced flags reject paths outside `HANKO_WEB_FEATURE_FLAG_BASE_DIR`.

Keep this document alongside `doc/web/deploy.md` when preparing the maintenance playbook so future operators have a single reference for toggling and rollbacks.
