# Add Hebrew localization and RTL validation across app flows

**Parent Section:** 16. Accessibility, Localization, and QA
**Task ID:** 090a

## Goal
Add Hebrew language support with correct RTL behavior and typography coverage.

## Implementation Steps
1. Add `he` locale to supported locales and locale selection UI.
2. Provide Hebrew translations in ARB files and ensure pluralization works.
3. Validate RTL layouts across key flows (onboarding, design editor, checkout, profile) and fix any layout mirroring issues.
4. Confirm font fallback includes Hebrew glyphs and adjust typography settings if needed.
5. Run manual QA in Hebrew for truncation, alignment, and icon direction.
