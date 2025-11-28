# Implement global app state providers (user session, locale, feature flags) with miniriverpod.

**Parent Section:** 2. Core Infrastructure & Shared Components
**Task ID:** 016

## Goal
Provide miniriverpod providers for session, locale, and feature flags.

## Implementation Steps
1. `AsyncProvider` for user session that listens to Firebase auth state and backend profile; expose mutations for refresh/sign-out.
2. Locale provider synced with device settings and `/profile/locale` screen updates, with fallback in `Scope`.
3. Feature flag provider using Remote Config with defaults, caching, and refresh via `ref.invoke`.
4. Document provider overrides for widget tests using `Scope`/override APIs.
