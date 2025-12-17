# Implement profile home (`/profile`) showing avatar, display name, persona toggle, quick links.

**Parent Section:** 11. Profile & Settings
**Task ID:** 063

## Goal
Implement profile home summarizing account info and quick links.

## Implementation Steps
1. Display avatar, display name, persona toggle, membership status.
2. Provide shortcuts to addresses, payments, notifications, support.
3. Fetch data via profile provider with optimistic updates.

## Notes
- Photo update action is currently a placeholder modal (no upload flow yet).
- Settings destination screens may still be placeholders depending on task progress.

## Material Design 3 Components
- **Header:** `Large top app bar` with avatar `Icon button` for photo update.
- **Persona toggle:** `Segmented buttons` to switch between Japanese/foreigner persona.
- **Quick actions:** `Elevated cards` in a grid for orders, library, support.
- **Footer:** `Navigation bar` consistent with app shell.
