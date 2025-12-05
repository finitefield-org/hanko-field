// ignore_for_file: public_member_api_docs

import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignCreationState {
  const DesignCreationState({
    required this.selectedType,
    required this.activeFilters,
    required this.storagePermissionGranted,
  });

  final DesignSourceType selectedType;
  final Set<String> activeFilters;
  final bool storagePermissionGranted;

  DesignCreationState copyWith({
    DesignSourceType? selectedType,
    Set<String>? activeFilters,
    bool? storagePermissionGranted,
  }) {
    return DesignCreationState(
      selectedType: selectedType ?? this.selectedType,
      activeFilters: activeFilters ?? this.activeFilters,
      storagePermissionGranted:
          storagePermissionGranted ?? this.storagePermissionGranted,
    );
  }
}

class DesignCreationViewModel extends AsyncProvider<DesignCreationState> {
  DesignCreationViewModel() : super.args(null, autoDispose: false);

  late final selectTypeMut = mutation<DesignSourceType>(#selectType);
  late final toggleFilterMut = mutation<Set<String>>(#toggleFilter);
  late final ensureStorageMut = mutation<bool>(#ensureStorage);

  @override
  Future<DesignCreationState> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final defaults = _defaultFilters(gates);

    return DesignCreationState(
      selectedType: DesignSourceType.typed,
      activeFilters: defaults,
      storagePermissionGranted: false,
    );
  }

  Call<DesignSourceType> selectType(DesignSourceType type) =>
      mutate(selectTypeMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return type;
        ref.state = AsyncData(current.copyWith(selectedType: type));
        return type;
      }, concurrency: Concurrency.dropLatest);

  Call<Set<String>> toggleFilter(String filterId) =>
      mutate(toggleFilterMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return <String>{};

        final next = Set<String>.from(current.activeFilters);
        if (next.contains(filterId) && next.length > 1) {
          next.remove(filterId);
        } else {
          next.add(filterId);
        }

        ref.state = AsyncData(current.copyWith(activeFilters: next));
        return next;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> ensureStorageAccess() => mutate(ensureStorageMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;

    final requiresStorage = switch (current.selectedType) {
      DesignSourceType.typed => false,
      DesignSourceType.uploaded => true,
      DesignSourceType.logo => true,
    };
    if (!requiresStorage) return true;

    final client = ref.watch(storagePermissionClientProvider);
    final status = await client.status();
    if (status.isGranted) {
      ref.state = AsyncData(current.copyWith(storagePermissionGranted: true));
      return true;
    }

    final requested = await client.request();
    final granted = requested.isGranted;
    ref.state = AsyncData(current.copyWith(storagePermissionGranted: granted));
    return granted;
  }, concurrency: Concurrency.dropLatest);
}

final designCreationViewModel = DesignCreationViewModel();

Set<String> _defaultFilters(AppExperienceGates gates) {
  final defaults = <String>{
    gates.enableRegistrabilityCheck ? 'official' : 'personal',
  };
  if (gates.emphasizeInternationalFlows) {
    defaults.add('digital');
  }
  return defaults;
}
