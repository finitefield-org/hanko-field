# Implement in-app messaging/toast system for success, warnings, alerts tied to miniriverpod providers.

**Parent Section:** 14. Notifications & Messaging
**Task ID:** 083

## Goal
Provide in-app messaging/toast notifications tied to miniriverpod providers.

## Implementation Steps
1. Implement overlay manager listening to provider events (`AsyncValue`, mutation results) via miniriverpod subscriptions.
2. Define standardized message model and display components; wire helpers to emit messages from view models.
3. Ensure accessibility with semantics and durations; support test overrides to inject fake sinks.
