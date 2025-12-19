# Implement payment methods management (`/profile/payments`) referencing PSP tokens, default selection, and removal.

**Parent Section:** 11. Profile & Settings
**Task ID:** 065

## Goal
Implement payment methods management in `/profile/payments` with PSP token-backed methods, default selection, and removal.

## Implementation Steps
1. Load saved payment methods and display brand/last4 with default selection.
2. Support adding methods with PSP token references stored securely.
3. Allow setting a default method and removing saved methods with confirmation.

## Material Design 3 Components
- **App bar:** `Small top app bar` with add payment `Icon button`.
- **Method list:** `Two-line list items` with brand icon leading and trailing `Radio button` for default.
- **Dialogs:** `Modal bottom sheet` for card entry using `Outlined text fields` and `Segmented buttons`.
