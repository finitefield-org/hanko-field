import 'dart:async';

import 'package:app/core/app/app_version.dart';
import 'package:app/core/app_state/feature_flags.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/splash/domain/startup_decision.dart';
import 'package:clock/clock.dart' as clock_package;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashController extends AsyncNotifier<SplashRouteState> {
  static bool _appLaunchLogged = false;

  @override
  Future<SplashRouteState> build() async {
    await ref.read(firebaseInitializedProvider.future);
    await ref.read(localCacheStoreInitializedProvider.future);

    final featureFlags = await ref.watch(featureFlagsProvider.future);
    final onboardingDataSource = await ref.watch(
      onboardingLocalDataSourceProvider.future,
    );
    final onboardingFlags = await onboardingDataSource.load();
    final session = await ref.watch(userSessionProvider.future);

    await ref.watch(analyticsControllerProvider.future);
    await _logAppLaunchOnce();

    final versionStatus = await _evaluateVersionGate();
    final destination = _resolveDestination(
      versionStatus: versionStatus,
      onboardingFlags: onboardingFlags,
      session: session,
    );

    return SplashRouteState(
      destination: destination,
      versionStatus: versionStatus,
      onboardingFlags: onboardingFlags,
      featureFlags: featureFlags,
      userSession: session,
      checkedAt: clock_package.clock.now(),
    );
  }

  Future<void> _logAppLaunchOnce() async {
    if (_appLaunchLogged) {
      return;
    }
    _appLaunchLogged = true;
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(const AppLaunchedEvent(fromNotification: false)),
    );
  }

  Future<VersionGateStatus> _evaluateVersionGate() async {
    final config = ref.read(firebaseRemoteConfigProvider);
    try {
      await config.fetchAndActivate();
    } catch (error, stackTrace) {
      // 強制アップデートチェックは確実に実行したいが、ネットワーク失敗時は
      // 手元のキャッシュ値で続行し、例外はグローバルエラー処理に伝える。
      Zone.current.handleUncaughtError(error, stackTrace);
    }
    final current = ref.read(appVersionProvider);
    final minimum = AppVersion.parse(
      config.getString('minimum_supported_version'),
    );
    final latest = AppVersion.parse(
      config.getString('latest_available_version'),
    );
    final requiresUpdate = current < minimum;
    return VersionGateStatus(
      currentVersion: current,
      minimumSupportedVersion: minimum,
      latestAvailableVersion: latest,
      updateRequired: requiresUpdate,
    );
  }

  SplashDestination _resolveDestination({
    required VersionGateStatus versionStatus,
    required OnboardingFlags onboardingFlags,
    required UserSessionState session,
  }) {
    if (versionStatus.updateRequired) {
      return SplashDestination.appUpdate;
    }
    if (!onboardingFlags.isCompleted) {
      return SplashDestination.onboarding;
    }
    if (session.status != UserSessionStatus.authenticated) {
      return SplashDestination.auth;
    }
    return SplashDestination.home;
  }
}

final splashControllerProvider =
    AsyncNotifierProvider<SplashController, SplashRouteState>(
      SplashController.new,
    );
