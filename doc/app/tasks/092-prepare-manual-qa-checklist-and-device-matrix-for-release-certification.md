# Prepare manual QA checklist and device matrix for release certification.

**Parent Section:** 16. Accessibility, Localization, and QA
**Task ID:** 092

## Goal
Prepare manual QA plan and device matrix.

## Implementation Steps
1. Define manual test cases per milestone, focusing on edge cases and cross-feature interactions.
2. Create device matrix covering iOS/Android variants, including minimum supported OS and form factors.
3. Document bug triage workflow and escalation.

## Manual QA Checklist
### Pre-release Smoke
- [ ] Clean install and app launch (first run).
- [ ] Login: Apple, Google, email, guest.
- [ ] Logout and re-login persists session correctly.
- [ ] Navigation: bottom tabs, back stack, deep links.
- [ ] Remote config gates load and default values apply.

### Core Journeys
- [ ] Onboarding tutorial skip/complete paths.
- [ ] Design creation: text input, style selection, preview, export/share.
- [ ] Catalog browse and search; filters and empty states.
- [ ] Cart add/edit/remove; promo code; totals update.
- [ ] Checkout: address, shipping, payment, review, completion.
- [ ] Orders: list, detail, shipment tracking, reorder.

### Account and Profile
- [ ] Profile update: avatar, name, locale, persona.
- [ ] Addresses CRUD and default selection.
- [ ] Notifications settings and opt-in/out.
- [ ] Linked accounts connect/disconnect.
- [ ] Account deletion flow with confirmation.

### Permissions and System Integration
- [ ] Camera/photo/storage permissions prompts.
- [ ] Push notifications: permission flow, foreground/background handling.
- [ ] Deep links to target screens with and without auth.
- [ ] Files export/share across apps.

### Offline and Error Handling
- [ ] Offline screen and retry behavior.
- [ ] API error states show correct messaging and recovery.
- [ ] Rate limit/network timeout handling.

### Accessibility and Localization
- [ ] Dynamic type scaling (small to largest).
- [ ] Screen reader labels and focus order.
- [ ] Color contrast for primary actions and alerts.
- [ ] RTL layout readiness if enabled.
- [ ] Date, currency, and number formatting by locale.

### Performance and Stability
- [ ] Cold start time within target.
- [ ] Memory-intensive flows (image heavy screens).
- [ ] Background/foreground resume state consistency.
- [ ] Crash-free smoke pass across primary flows.

## Device Matrix
### iOS
Minimum supported OS: iOS 16

| Category | Model | OS Version | Notes |
| --- | --- | --- | --- |
| Small phone | iPhone SE (3rd gen) | iOS 16.x | Small screen, home button |
| Standard phone | iPhone 14 | iOS 17.x | Baseline device |
| Large phone | iPhone 14 Pro Max | iOS 17.x | Large screen, notch |
| Latest | iPhone 15 Pro | iOS 17.x | Latest hardware |
| Tablet | iPad (9th/10th gen) | iPadOS 17.x | Tablet layout validation |

### Android
Minimum supported OS: Android 10

| Category | Model | OS Version | Notes |
| --- | --- | --- | --- |
| Small phone | Pixel 4a | Android 12 | Small screen, low memory |
| Standard phone | Pixel 6 | Android 13 | Baseline device |
| Large phone | Pixel 7 Pro | Android 14 | Large screen |
| OEM skin | Samsung Galaxy S23 | Android 14 | One UI validation |
| Tablet | Samsung Galaxy Tab S8 | Android 13 | Tablet layout validation |

### Test Coverage Notes
- Cover at least one low-memory Android device.
- Validate at least one device per OS major version range.
- Ensure one device with physical notch/cutout handling.

## Bug Triage and Escalation
1. **Log**: capture repro steps, build number, device, OS, logs, and screenshots.
2. **Classify**: label severity (S0 crash, S1 blocker, S2 major, S3 minor).
3. **Prioritize**: align to release gate and user impact.
4. **Assign**: route to feature owner with SLA targets.
5. **Verify**: retest on fix build and update status.
6. **Escalate**: S0/S1 notify release manager immediately; consider rollout pause.
