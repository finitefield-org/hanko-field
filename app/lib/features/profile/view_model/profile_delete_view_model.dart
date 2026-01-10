// ignore_for_file: public_member_api_docs

import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum ProfileDeleteAcknowledgement { dataLoss, openOrders, irreversible }

class ProfileDeleteState {
  const ProfileDeleteState({
    required this.confirmDataLoss,
    required this.confirmOpenOrders,
    required this.confirmIrreversible,
    required this.isDeleting,
  });

  final bool confirmDataLoss;
  final bool confirmOpenOrders;
  final bool confirmIrreversible;
  final bool isDeleting;

  bool get canDelete =>
      confirmDataLoss && confirmOpenOrders && confirmIrreversible;

  ProfileDeleteState copyWith({
    bool? confirmDataLoss,
    bool? confirmOpenOrders,
    bool? confirmIrreversible,
    bool? isDeleting,
  }) {
    return ProfileDeleteState(
      confirmDataLoss: confirmDataLoss ?? this.confirmDataLoss,
      confirmOpenOrders: confirmOpenOrders ?? this.confirmOpenOrders,
      confirmIrreversible: confirmIrreversible ?? this.confirmIrreversible,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }
}

final _logger = Logger('ProfileDeleteViewModel');

class ProfileDeleteViewModel extends AsyncProvider<ProfileDeleteState> {
  ProfileDeleteViewModel() : super.args(null, autoDispose: true);

  late final toggleMut = mutation<void>(#toggleAcknowledgement);
  late final deleteMut = mutation<void>(#deleteAccount);

  @override
  Future<ProfileDeleteState> build(
    Ref<AsyncValue<ProfileDeleteState>> ref,
  ) async {
    return const ProfileDeleteState(
      confirmDataLoss: false,
      confirmOpenOrders: false,
      confirmIrreversible: false,
      isDeleting: false,
    );
  }

  Call<void, AsyncValue<ProfileDeleteState>> toggleAcknowledgement(
    ProfileDeleteAcknowledgement acknowledgement,
    bool value,
  ) => mutate(toggleMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    ref.state = AsyncData(
      _applyAcknowledgement(current, acknowledgement, value),
    );
  }, concurrency: Concurrency.dropLatest);

  Call<void, AsyncValue<ProfileDeleteState>> deleteAccount() =>
      mutate(deleteMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;
        if (!current.canDelete) {
          throw StateError('Cannot delete account without confirmations.');
        }

        ref.state = AsyncData(current.copyWith(isDeleting: true));

        final repository = ref.watch(userRepositoryProvider);
        try {
          await repository.deleteAccount();
          await ref.invoke(userSessionProvider.signOut());
          ref.state = AsyncData(current.copyWith(isDeleting: false));
        } catch (e, stack) {
          _logger.warning('Account deletion failed', e, stack);
          ref.state = AsyncData(current.copyWith(isDeleting: false));
          rethrow;
        }
      }, concurrency: Concurrency.dropLatest);
}

final profileDeleteViewModel = ProfileDeleteViewModel();

ProfileDeleteState _applyAcknowledgement(
  ProfileDeleteState state,
  ProfileDeleteAcknowledgement acknowledgement,
  bool value,
) {
  switch (acknowledgement) {
    case ProfileDeleteAcknowledgement.dataLoss:
      return state.copyWith(confirmDataLoss: value);
    case ProfileDeleteAcknowledgement.openOrders:
      return state.copyWith(confirmOpenOrders: value);
    case ProfileDeleteAcknowledgement.irreversible:
      return state.copyWith(confirmIrreversible: value);
  }
}
