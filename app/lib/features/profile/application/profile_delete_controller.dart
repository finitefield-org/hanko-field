import 'dart:async';

import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/account_deletion.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileDeleteState {
  ProfileDeleteState({
    Set<AccountDeletionAcknowledgement>? acknowledgements,
    this.isSubmitting = false,
    this.lastSubmittedAt,
  }) : acknowledgements = Set.unmodifiable(
         acknowledgements ?? const <AccountDeletionAcknowledgement>{},
       );

  final Set<AccountDeletionAcknowledgement> acknowledgements;
  final bool isSubmitting;
  final DateTime? lastSubmittedAt;

  bool get isChecklistComplete =>
      acknowledgements.containsAll(AccountDeletionAcknowledgement.values);

  ProfileDeleteState copyWith({
    Set<AccountDeletionAcknowledgement>? acknowledgements,
    bool? isSubmitting,
    DateTime? lastSubmittedAt,
  }) {
    return ProfileDeleteState(
      acknowledgements: acknowledgements ?? this.acknowledgements,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastSubmittedAt: lastSubmittedAt ?? this.lastSubmittedAt,
    );
  }
}

class ProfileDeleteController extends AsyncNotifier<ProfileDeleteState> {
  UserRepository get _repository => ref.read(userRepositoryProvider);

  @override
  FutureOr<ProfileDeleteState> build() => ProfileDeleteState();

  void toggleAcknowledgement(
    AccountDeletionAcknowledgement acknowledgement,
    bool accepted,
  ) {
    final current = state.asData?.value ?? ProfileDeleteState();
    final next = {...current.acknowledgements};
    if (accepted) {
      next.add(acknowledgement);
    } else {
      next.remove(acknowledgement);
    }
    state = AsyncData(current.copyWith(acknowledgements: next));
  }

  Future<void> submitDeletion({String? feedback}) async {
    final current = state.asData?.value ?? await future;
    if (current.isSubmitting || !current.isChecklistComplete) {
      return;
    }
    state = AsyncData(current.copyWith(isSubmitting: true));
    try {
      final request = AccountDeletionRequest(
        acknowledgements: current.acknowledgements,
        feedback: feedback,
      );
      await _repository.requestAccountDeletion(request);
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(
        current.copyWith(isSubmitting: false, lastSubmittedAt: DateTime.now()),
      );
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSubmitting: false));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final profileDeleteControllerProvider =
    AsyncNotifierProvider<ProfileDeleteController, ProfileDeleteState>(
      ProfileDeleteController.new,
    );
