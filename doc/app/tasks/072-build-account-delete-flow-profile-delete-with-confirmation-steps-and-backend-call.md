# Build account delete flow (`/profile/delete`) with confirmation steps and backend call.

**Parent Section:** 11. Profile & Settings
**Task ID:** 072

## Goal
Implement account deletion flow with confirmations, UX warnings, and backend call.

## Implementation Steps
1. Build `/profile/delete` screen with warning copy, acknowledgement checklist, and destructive CTA.
2. Add a view model to track confirmations, handle delete mutations, and sign out on success.
3. Call backend account deactivation endpoint via user repository and clear local caches.

## Material Design 3 Components
- **App bar:** `Medium top app bar` with prominent danger color tokens.
- **Warning card:** `Outlined card` with iconography and `BodyLarge` copy.
- **Acknowledgement list:** `List items` containing `Checkbox` for policy confirmations.
- **CTA:** `Filled button` styled with `errorContainer` colors and secondary `Text button` to cancel.
