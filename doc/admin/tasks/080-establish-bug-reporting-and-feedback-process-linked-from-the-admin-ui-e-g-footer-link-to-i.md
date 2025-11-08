# Establish bug reporting and feedback process linked from the admin UI (e.g., footer link to issue tracker).

**Parent Section:** 15. Quality Assurance & Documentation
**Task ID:** 080

## Goal
Define feedback process within admin UI.

## Implementation Steps
1. Add footer link/button opening feedback modal.
2. Capture context (URL, browser, console logs optional) and send to issue tracker or email.
3. Provide success message and instructions.

## Implementation Notes
- Added a persistent footer entry in the admin shell with a CTA that opens the new feedback modal and a direct link to the shared issue tracker.
- The modal collects summary, detailed description, optional expectations/console logs, and the reporter's contact email while automatically attaching the current URL and browser.
- Submissions are routed through the system service, which now returns an issue reference that is surfaced back to the user together with next-step guidance.
