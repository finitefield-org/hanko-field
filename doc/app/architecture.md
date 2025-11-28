# Flutter app architecture (MVVM + miniriverpod)
Source refs: `doc/app/app_design.md`, `doc/customer_journey/persona.md`, `../miniriverpod/miniriverpod/README.md`

## Layering and directory layout
```
lib/
  app.dart                  # root ProviderScope/router/theme
  core/                     # cross-cutting
    env/, network/, storage/, analytics/, logging/, routing/, theme/, l10n/
    error/                  # error types, mappers
    util/                   # small helpers (pure functions)
  shared/
    widgets/                # design-system widgets (buttons, forms, modals, skeletons)
    providers/              # global providers (session, locale, feature flags)
    services/               # adapters (notification, deeplink, remote config)
  features/
    design/                 # feature-first slice
      view/                 # UI widgets/screens
      view_model/           # providers/view models
      data/
        models/             # DTO/domain models
        repositories/       # interfaces
        sources/            # api/local adapters
    shop/
      ...
  bootstrap.dart            # runApp entry, flavor wiring

test/
  features/<feature>/...    # mirrors lib/features
  core/, shared/            # unit tests for helpers/providers
```

ASCII flow: `View (WidgetRef.watch) -> ViewModel (Provider/AsyncProvider) -> Repository (interface) -> Data sources (API/local)`.

## Provider/view-model conventions (miniriverpod)
- Base types: `Provider<T>` for synchronous derived state; `AsyncProvider<T>` for async or cached data.
- Naming: `<Feature><Thing>ViewModel` classes extend `AsyncProvider<State>` (or `Provider<State>`). Instances are `final designInputVm = DesignInputViewModel(args...)`.
- Families: use subclasses with `args` tuple; keep args small (ids, filters). Example: `class OrderDetailViewModel extends AsyncProvider<OrderDetailState> { OrderDetailViewModel(this.id):super.args((id,)); }`.
- Exposure: UI watches the provider instance; mutations are methods on the provider class returning `Call<T>` and backed by `mutation()` fields.
- Scope/DI: repositories injected via global providers or `Scope` fallbacks; feature tests override with `ProviderScope(overrides:[DesignRepository.fallback.overrideWithValue(FakeDesignRepository())])`.

## State, loading, and error modeling
- Default loading surface: rely on `AsyncValue` from `AsyncProvider`; use `isRefreshing` to show background refresh.
- Derived UI state: wrap in immutable state classes with primitives/DTOs. Example: `class DesignInputState { final String name; final bool canContinue; final ValidationError? error; }`.
- Errors: map infra errors to typed domain errors in repositories. View models should emit domain-level failures (e.g., `DesignError.registrabilityUnavailable`) instead of raw exceptions.
- Long-running flows: keep UI responsive by optimistic updates where possible; always finalize with a fresh fetch when mutation completes.

## Mutation patterns and concurrency defaults
- Define `late final someActionMut = mutation<void>(#someAction);` in the provider and expose `Call<T> someAction(...) => mutate(someActionMut, (ref) async { ... }, concurrency: Concurrency.restart);`.
- Concurrency guidance:
  - `restart`: form submissions, search, async validation (latest wins).
  - `queue`: checkout/payment actions where order matters.
  - `dropLatest`: repeated taps on idempotent toggles.
  - `concurrent`: background fetches safe to run in parallel.
- UI must `ref.invoke(provider.action())`; handle `CancelledMutation/DroppedMutation` where relevant. Disable buttons using `PendingMutationState`.

## Repository and data source rules
- Interfaces live in `features/<feature>/data/repositories`, naming: `<Feature>Repository`.
- Implementations in `.../sources` (e.g., `DesignApiSource`, `DesignLocalSource`), composed inside repository impls.
- Repositories return domain models or sealed results; they own mapping from DTOs and HTTP errors to domain errors.
- Tests target interfaces; override in `ProviderScope` using fallbacks or overrides for deterministic behavior.

## Sample scaffold (feature: design input)
```
lib/features/design/
  view/design_input_page.dart
  view_model/design_input_view_model.dart
  data/models/design_name.dart
  data/repositories/design_repository.dart
  data/sources/design_api_source.dart
```

```dart
// data/repositories/design_repository.dart
abstract class DesignRepository {
  static final fallback = Scope<DesignRepository>.required('design.repo');
  Future<void> reserveName(String name);
}
```

```dart
// view_model/design_input_view_model.dart
class DesignInputState {
  const DesignInputState({this.name = '', this.error, this.isValid = false});
  final String name;
  final String? error;
  final bool isValid;
  DesignInputState copyWith({String? name, String? error, bool? isValid}) =>
      DesignInputState(
        name: name ?? this.name,
        error: error,
        isValid: isValid ?? this.isValid,
      );
}

class DesignInputViewModel extends Provider<DesignInputState> {
  DesignInputViewModel() : super.args(null, autoDispose: true);
  late final submitMut = mutation<void>(#submit);

  @override
  DesignInputState build(Ref ref) => const DesignInputState();

  Call<void> onNameChanged(String value) => mutate(
        submitMut,
        (ref) async {
          ref.state = ref.state.copyWith(name: value, error: null, isValid: value.isNotEmpty);
        },
        concurrency: Concurrency.dropLatest,
      );

  Call<void> submit() => mutate(
        submitMut,
        (ref) async {
          final repo = ref.scope(DesignRepository.fallback);
          final cur = ref.state;
          if (!cur.isValid) throw ArgumentError('name required');
          await repo.reserveName(cur.name);
        },
        concurrency: Concurrency.restart,
      );
}

final designInputVm = DesignInputViewModel();
```

```dart
// view/design_input_page.dart
class DesignInputPage extends ConsumerWidget {
  const DesignInputPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(designInputVm);
    final submitState = ref.watch(designInputVm.submitMut);
    return TextField(
      onChanged: (v) => ref.invoke(designInputVm.onNameChanged(v)),
      decoration: InputDecoration(
        errorText: state.error,
        suffixIcon: switch (submitState) {
          PendingMutationState() => const CircularProgressIndicator.adaptive(),
          _ => null,
        },
      ),
    );
  }
}
```

## Code review checklist (architecture)
- Feature code lives under `lib/features/<feature>/{view,view_model,data}`; shared-only code goes to `shared/` or `core/`.
- Providers/view models are subclass-based; families use `args`, not global `final fooProvider = Provider.family`.
- Mutations use `mutation/mutate/ref.invoke`; concurrency choice is explicit and appropriate.
- Repositories return domain models and map infra errors; UI never reaches into API clients directly.
- Async UI uses `AsyncValue` semantics (`isRefreshing`, error states) rather than custom booleans.
- Tests override repositories/providers via `ProviderScope(overrides: ...)` or `Scope` fallbacks.
