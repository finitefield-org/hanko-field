# Build notifications settings (`/profile/notifications`) for push/email categories and scheduling.

**Parent Section:** 11. Profile & Settings
**Task ID:** 066

## Goal
Implement notification settings screen for push/email categories and digest scheduling.

## Implementation Steps
1. Add local notification preferences model stored in shared preferences.
2. Build the notifications settings UI with push/email category toggles.
3. Include digest frequency segmented controls and save/reset flows.

## Material Design 3 Components
- **App bar:** `Center-aligned top app bar` with reset `Text button`.
- **Category list:** `List items` each containing `Switch` for channel enablement and supporting text.
- **Digest controls:** `Segmented buttons` for frequency selection (daily, weekly, monthly).
- **Footer:** `Filled tonal button` to save preferences with `Snackbar` on success.
