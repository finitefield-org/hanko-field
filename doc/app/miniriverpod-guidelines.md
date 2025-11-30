# miniriverpod usage guidelines (no codegen)
Source: `../miniriverpod/miniriverpod/README.md`, complements `doc/app/architecture.md`

## Provider types and lifetimes
- **Global app providers** (`shared/providers`): session, locale, feature flags, config, analytics/logging. Long-lived, generally `autoDispose: false` unless tied to screen.
- **Feature providers** (`features/<feature>/view_model`): view models for screens/flows. Prefer `autoDispose: true` with short delays; keep alive only when background refresh is needed.
- **Ephemeral/UI providers**: derived UI state (filters, toggles) scoped to a screen; always `autoDispose: true`.
- Families via subclasses + `args` tuple. Avoid `StateProvider`; use `Provider`/`AsyncProvider` with explicit mutations.

## Async handling patterns
- Default to `AsyncProvider<T>` for IO-backed state; UI consumes `AsyncValue<T>` (`AsyncLoading/AsyncData/AsyncError`). Use `isRefreshing` for pull-to-refresh or background sync indicators.
- Streams: `ref.emit(stream)` inside `AsyncProvider.build` to ensure prior subscriptions are cancelled on rebuild.
- Refresh/invalidate: `ref.invalidate(provider, keepPrevious: true)` or `await ref.refreshValue(asyncProvider, keepPrevious: true)` for pull-to-refresh flows.
- Use small immutable state classes for composite UI state; avoid scattered bool flags.

## Mutations and concurrency
- Define `late final <action>Mut = mutation<T>(#action);` and expose `Call<T> <action>(...) => mutate(<action>Mut, (ref) async { ... }, concurrency: Concurrency.restart);`.
- Concurrency defaults:
  - `restart` (preferred): latest wins for searches, form submits, fetch-with-args.
  - `queue`: payment/checkout steps where order matters.
  - `dropLatest`: spammy taps on idempotent toggles.
  - `concurrent`: independent background fetches.
- UI must trigger with `ref.invoke(provider.action())`; handle `CancelledMutation`/`DroppedMutation` when using `restart`/`dropLatest`.
- Button/CTA disabling: watch `PendingMutationState` to prevent duplicate submits.

## Dependency injection with Scope/overrides
- Repositories/interfaces expose a `Scope<T>` fallback: `static final fallback = Scope<DesignRepository>.required('design.repo');`.
- Production wiring: inject concrete implementations at `ProviderScope(overrides: [...])` in `app.dart/bootstrap.dart`.
- Feature tests: override repositories/clients via `ProviderScope(overrides: [...])` or inject scoped provider instances for families.
- Avoid singletons; pass environment (base URLs, feature flags) via providers to keep tests overrideable.

## Error propagation and retry
- Repositories map transport errors to domain errors; providers surface domain errors (not raw exceptions) in `AsyncError`.
- UI retry: `ref.invalidate` or `ref.refreshValue` on the provider; show error messages derived from domain errors.
- Mutations: catch and surface domain errors; prefer optimistic updates only when they can be reconciled with a subsequent fetch.

## Anti-patterns to avoid
- No `StateProvider`/`ChangeNotifier`; keep state in Provider/AsyncProvider + mutations.
- Avoid putting feature state in global providers; scope to feature unless truly cross-cutting.
- No direct API client usage from UI; always via repositories/providers.
- Do not rely on code generation/families helpers; subclass + `args` keeps types predictable and overrideable.

## UI binding tips
- Use `ConsumerWidget`/`Consumer` and `ref.watch(...)` for reactive sections; minimize rebuilds by splitting widgets.
- Prefer pattern matching over `when` helpers (`switch (av) { AsyncData(:final v) => ... }`).
- For lists, consider `autoDisposeDelay` to keep cache during quick navigation.

## Testing checklist
- Unit test providers by creating a `ProviderContainer` and overriding dependencies (repositories, environment).
- Widget tests wrap widgets with `ProviderScope(overrides: [...])`.
- Verify concurrency behavior (restart/dropLatest) with fake delays to catch double-submits.
- Override global app providers in tests via scopes: `userSessionScope.overrideWithValue(...)`, `appLocaleScope.overrideWithValue(...)`, `featureFlagsScope.overrideWithValue(...)`.
