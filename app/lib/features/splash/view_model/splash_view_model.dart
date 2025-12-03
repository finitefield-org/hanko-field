// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/core/storage/onboarding_preferences.dart';
import 'package:app/core/util/version_compare.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/firebase/remote_config.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/shared/providers/feature_flags_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum SplashDestination { appUpdate, onboarding, locale, persona, auth, home }

class SplashResult {
  const SplashResult({required this.targetRoute, required this.reason});

  final String targetRoute;
  final SplashDestination reason;
}

final _logger = Logger('SplashViewModel');

class SplashViewModel extends AsyncProvider<SplashResult> {
  SplashViewModel() : super.args(null, autoDispose: true);

  late final retryMut = mutation<SplashResult>(#retry);

  @override
  Future<SplashResult> build(Ref ref) async {
    return _run(ref);
  }

  Call<SplashResult> retry() =>
      mutate(retryMut, _run, concurrency: Concurrency.restart);

  Future<SplashResult> _run(Ref ref) async {
    try {
      await _initialize(ref);
      final decision = await _resolveNext(ref);
      final gates = ref.watch(appExperienceGatesProvider);

      unawaited(
        ref
            .watch(analyticsClientProvider)
            .track(
              AppOpenedEvent(
                entryPoint: 'splash_${decision.reason.name}',
                locale: gates.localeTag,
                region: gates.regionCode,
                persona: gates.personaKey,
              ),
            ),
      );

      return decision;
    } catch (e, stack) {
      _logger.severe('Failed to resolve splash navigation', e, stack);
      rethrow;
    }
  }

  Future<void> _initialize(Ref ref) async {
    await Future.wait([
      ref.watch(remoteConfigInitializerProvider.future),
      ref.watch(localPersistenceInitializerProvider.future),
    ]);
  }

  Future<SplashResult> _resolveNext(Ref ref) async {
    final flags = await ref.watch(featureFlagsProvider.future);
    final onboarding = await ref.watch(onboardingPreferencesProvider.future);
    final packageInfo = await PackageInfo.fromPlatform();

    final currentVersion = packageInfo.version;
    final minimumVersion = _minimumSupportedVersion(flags);

    if (!isVersionAtLeast(currentVersion, minimumVersion)) {
      return const SplashResult(
        targetRoute: AppRoutePaths.appUpdate,
        reason: SplashDestination.appUpdate,
      );
    }

    if (!onboarding.onboardingCompleted) {
      return const SplashResult(
        targetRoute: AppRoutePaths.onboarding,
        reason: SplashDestination.onboarding,
      );
    }

    if (!onboarding.localeSelected) {
      return const SplashResult(
        targetRoute: AppRoutePaths.locale,
        reason: SplashDestination.locale,
      );
    }

    if (!onboarding.personaSelected) {
      return const SplashResult(
        targetRoute: AppRoutePaths.persona,
        reason: SplashDestination.persona,
      );
    }

    final auth = ref.watch(firebaseAuthProvider);
    if (auth.currentUser == null) {
      return const SplashResult(
        targetRoute: AppRoutePaths.auth,
        reason: SplashDestination.auth,
      );
    }

    return const SplashResult(
      targetRoute: AppRoutePaths.home,
      reason: SplashDestination.home,
    );
  }
}

final splashViewModel = SplashViewModel();

String _minimumSupportedVersion(FeatureFlags flags) {
  if (kIsWeb) {
    return flags.minSupportedVersionAndroid;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => flags.minSupportedVersionIos,
    _ => flags.minSupportedVersionAndroid,
  };
}
