// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/core/storage/onboarding_preferences.dart';
import 'package:app/features/users/data/repositories/user_repository.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final _logger = Logger('OnboardingViewModel');

class OnboardingState {
  const OnboardingState({required this.preferences});

  final OnboardingPreferences preferences;
}

class OnboardingViewModel extends AsyncProvider<OnboardingState> {
  OnboardingViewModel() : super.args(null, autoDispose: true);

  late final markStepMut = mutation<void>(#markStep);
  late final completeMut = mutation<void>(#complete);
  late final skipMut = mutation<void>(#skip);

  @override
  Future<OnboardingState> build(Ref ref) async {
    final prefs = await ref.watch(onboardingPreferencesProvider.future);
    return OnboardingState(preferences: prefs);
  }

  Call<void> markStep({required int step, required int totalSteps}) {
    return mutate(markStepMut, (ref) async {
      final analytics = ref.watch(analyticsClientProvider);
      final cache = ref.watch(onboardingCacheProvider);
      final key = LocalCacheKeys.onboarding;
      final now = DateTime.now().toUtc().toIso8601String();

      await cache.write(key.value, {
        'last_step': step,
        'total_steps': totalSteps,
        'updated_at': now,
        'completed': false,
      }, tags: key.tags);

      unawaited(
        analytics.track(
          OnboardingStepViewedEvent(step: step, totalSteps: totalSteps),
        ),
      );
    }, concurrency: Concurrency.restart);
  }

  Call<void> complete({required int step, required int totalSteps}) {
    return mutate(completeMut, (ref) async {
      await _finish(ref, skipped: false, step: step, totalSteps: totalSteps);
    }, concurrency: Concurrency.dropLatest);
  }

  Call<void> skip({required int step, required int totalSteps}) {
    return mutate(skipMut, (ref) async {
      await _finish(ref, skipped: true, step: step, totalSteps: totalSteps);
    }, concurrency: Concurrency.dropLatest);
  }

  Future<void> _finish(
    Ref ref, {
    required bool skipped,
    required int step,
    required int totalSteps,
  }) async {
    final prefsService = ref.watch(onboardingPreferencesServiceProvider);
    final cache = ref.watch(onboardingCacheProvider);
    final analytics = ref.watch(analyticsClientProvider);
    final key = LocalCacheKeys.onboarding;
    final timestamp = DateTime.now().toUtc();

    await prefsService.markOnboardingComplete();

    final payload = <String, Object?>{
      'completed': true,
      'skipped': skipped,
      'version': OnboardingPreferences.currentVersion,
      'completed_at': timestamp.toIso8601String(),
      'last_step': step,
      'total_steps': totalSteps,
    };

    await cache.write(key.value, payload, tags: key.tags);

    unawaited(
      analytics.track(
        skipped
            ? OnboardingSkippedEvent(
                totalSteps: totalSteps,
                skippedAtStep: step,
              )
            : OnboardingCompletedEvent(totalSteps: totalSteps),
      ),
    );

    await _syncToBackend(ref, payload);
  }

  Future<void> _syncToBackend(Ref ref, JsonMap onboardingState) async {
    UserRepository repository;
    try {
      repository = ref.scope(UserRepository.fallback);
    } on StateError {
      _logger.fine('UserRepository not available; skipping onboarding sync');
      return;
    }

    final session = ref.watch(userSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile == null) {
      _logger.fine('User not authenticated; onboarding sync skipped');
      return;
    }

    final merged = <String, Object?>{
      ...?profile.onboarding,
      ...onboardingState,
    };

    try {
      await repository.updateProfile(profile.copyWith(onboarding: merged));
      ref.invalidate(userSessionProvider);
    } catch (e, stack) {
      _logger.warning('Failed to sync onboarding to backend', e, stack);
    }
  }
}

final onboardingViewModel = OnboardingViewModel();
