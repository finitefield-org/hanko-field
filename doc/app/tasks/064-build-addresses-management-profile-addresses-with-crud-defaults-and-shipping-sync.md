# Build addresses management (`/profile/addresses`) with CRUD, defaults, and shipping sync.

**Parent Section:** 11. Profile & Settings
**Task ID:** 064

## Goal
Implement an addresses management screen that lets users add/edit/delete addresses, choose a default, and keep checkout shipping selection in sync.

## Implementation Steps
1. Show a list of saved addresses with default selection and edit/delete actions.
2. Provide an add/edit dialog with validation and default toggle.
3. When the default address changes, sync in-progress checkout shipping selection if it was using the previous default.
4. When the selected shipping address is deleted, fall back to the new default (or clear selection).

## Material Design 3 Components
- **App bar:** `Small top app bar` with add address `Icon button`.
- **Address list:** `List items` with trailing `Radio button` for default and `Icon buttons` for edit/delete.
- **Sync banner:** `Banner` indicating shipping sync status.
- **Dialog:** `Standard dialog` housing `Outlined text fields` for quick edits.
