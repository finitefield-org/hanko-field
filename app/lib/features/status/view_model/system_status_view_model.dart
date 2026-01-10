// ignore_for_file: public_member_api_docs

import 'package:app/features/status/data/models/status_models.dart';
import 'package:app/features/status/data/repositories/status_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SystemStatusState {
  const SystemStatusState({
    required this.snapshot,
    required this.selectedService,
    required this.isRefreshing,
  });

  final StatusSnapshot snapshot;
  final StatusService selectedService;
  final bool isRefreshing;

  SystemStatusState copyWith({
    StatusSnapshot? snapshot,
    StatusService? selectedService,
    bool? isRefreshing,
  }) {
    return SystemStatusState(
      snapshot: snapshot ?? this.snapshot,
      selectedService: selectedService ?? this.selectedService,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

final systemStatusViewModel = SystemStatusViewModel();

class SystemStatusViewModel extends AsyncProvider<SystemStatusState> {
  SystemStatusViewModel() : super.args(null, autoDispose: true);

  late final refreshMut = mutation<void>(#refresh);
  late final setServiceMut = mutation<StatusService>(#setService);

  @override
  Future<SystemStatusState> build(
    Ref<AsyncValue<SystemStatusState>> ref,
  ) async {
    final repository = ref.watch(statusRepositoryProvider);
    final snapshot = await repository.fetchStatus();
    return SystemStatusState(
      snapshot: snapshot,
      selectedService: StatusService.api,
      isRefreshing: false,
    );
  }

  Call<void, AsyncValue<SystemStatusState>> refresh() =>
      mutate(refreshMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current != null) {
          ref.state = AsyncData(current.copyWith(isRefreshing: true));
        }

        final repository = ref.watch(statusRepositoryProvider);
        final snapshot = await repository.fetchStatus();
        final service = current?.selectedService ?? StatusService.api;
        ref.state = AsyncData(
          SystemStatusState(
            snapshot: snapshot,
            selectedService: service,
            isRefreshing: false,
          ),
        );
      }, concurrency: Concurrency.dropLatest);

  Call<StatusService, AsyncValue<SystemStatusState>> setService(
    StatusService service,
  ) => mutate(setServiceMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return service;
    ref.state = AsyncData(current.copyWith(selectedService: service));
    return service;
  }, concurrency: Concurrency.dropLatest);
}
