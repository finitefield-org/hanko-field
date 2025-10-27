import 'dart:async';

import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingTutorialState {
  const OnboardingTutorialState({
    required this.currentPage,
    this.isSaving = false,
  });

  final int currentPage;
  final bool isSaving;

  OnboardingTutorialState copyWith({int? currentPage, bool? isSaving}) {
    return OnboardingTutorialState(
      currentPage: currentPage ?? this.currentPage,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class OnboardingTutorialController extends Notifier<OnboardingTutorialState> {
  @override
  OnboardingTutorialState build() {
    return const OnboardingTutorialState(currentPage: 0);
  }

  void setCurrentPage(
    int index, {
    required int totalSteps,
    bool force = false,
  }) {
    if (!force && state.currentPage == index) {
      return;
    }
    state = state.copyWith(currentPage: index);

    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        OnboardingTutorialStepViewedEvent(
          stepIndex: index + 1,
          totalSteps: totalSteps,
        ),
      ),
    );
    unawaited(
      analytics.logScreenView(
        ScreenViewAnalyticsEvent(
          screenName: 'onboarding_step_${index + 1}',
          screenClass: 'OnboardingTutorialScreen',
        ),
      ),
    );
  }

  Future<void> completeTutorial({
    required int totalSteps,
    required bool skipped,
  }) async {
    if (state.isSaving) {
      return;
    }

    state = state.copyWith(isSaving: true);
    try {
      final dataSource = await ref.read(
        onboardingLocalDataSourceProvider.future,
      );
      await dataSource.updateStep(OnboardingStep.tutorial);

      await _syncRemoteOnboardingFlag();

      final analytics = ref.read(analyticsControllerProvider.notifier);
      if (skipped) {
        await analytics.logEvent(
          OnboardingTutorialSkippedEvent(
            skippedAtStep: state.currentPage + 1,
            totalSteps: totalSteps,
          ),
        );
      } else {
        await analytics.logEvent(
          OnboardingTutorialCompletedEvent(totalSteps: totalSteps),
        );
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
    }
  }

  Future<void> _syncRemoteOnboardingFlag() async {
    try {
      final session = await ref.read(userSessionProvider.future);
      if (session.status != UserSessionStatus.authenticated) {
        return;
      }
      final profile = session.profile;
      if (profile == null) {
        return;
      }

      final onboardingData = Map<String, dynamic>.from(
        profile.onboarding ?? const <String, dynamic>{},
      );
      final alreadyComplete = onboardingData['tutorial'] == true;
      if (!alreadyComplete) {
        onboardingData['tutorial'] = true;
      }

      if (!alreadyComplete) {
        final repository = ref.read(userRepositoryProvider);
        await repository.updateProfile(
          profile.copyWith(onboarding: onboardingData),
        );
      }

      if (!ref.mounted) {
        return;
      }
      unawaited(ref.read(userSessionProvider.notifier).refreshProfile());
    } catch (error, stackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }
}

final onboardingTutorialControllerProvider =
    NotifierProvider<OnboardingTutorialController, OnboardingTutorialState>(
      OnboardingTutorialController.new,
    );
