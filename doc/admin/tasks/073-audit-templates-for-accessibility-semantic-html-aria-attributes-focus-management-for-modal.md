# Audit templates for accessibility (semantic HTML, ARIA attributes, focus management for modals and drag/drop).

**Parent Section:** 14. Accessibility, Localization, and UX Enhancements
**Task ID:** 073

## Goal
Ensure admin UI meets accessibility standards.

## Implementation Steps
1. Audit templates for semantic HTML usage and ARIA roles.
2. Implement focus management for modals and keyboard navigation patterns.
3. Provide accessible labels for forms, tables, drag-and-drop.
4. Run automated checks (axe) and manual screen reader testing.

## Outcome
- Added explicit landmark roles/labels to the global shell (sidebar, banner, skip target) and modal layout, including `aria-labelledby`/`aria-describedby` wiring so dialogs always expose a programmatic name/description.
- Reworked the production board template with screen-reader instructions, per-lane region semantics, labelled lists, and enriched card metadata to describe drag targets in plain language. Cards now expose labels, assistive summaries, and keyboard-focusable drag handles with announcements on state changes.
- Extended the production board controller (`app.js`) with aria-grabbed state management, live announcements, and keyboard reordering (←/→) so drag & drop is operable without a pointer while preserving focus.
- Ensured form controls (e.g., queue selector) and data tables have captions/labels so they can be discovered via assistive tech, and updated task tracking/checklist.

## Verification
- [x] `npx --yes @axe-core/cli file:///tmp/hanko-accessibility.html`
- [ ] Manual screen reader smoke test (run against a served admin page once UI is available)
