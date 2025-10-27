import 'package:app/core/app/app_version.dart';
import 'package:app/core/app_state/feature_flags.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/storage/offline_cache_repository.dart';

/// スプラッシュ判定後に遷移すべきフロー。
enum SplashDestination { appUpdate, onboarding, auth, home }

class VersionGateStatus {
  const VersionGateStatus({
    required this.currentVersion,
    required this.minimumSupportedVersion,
    required this.latestAvailableVersion,
    required this.updateRequired,
  });

  final AppVersion currentVersion;
  final AppVersion minimumSupportedVersion;
  final AppVersion latestAvailableVersion;
  final bool updateRequired;
}

/// スプラッシュの最終結果。UI 側は destination を見て遷移を決める。
class SplashRouteState {
  const SplashRouteState({
    required this.destination,
    required this.versionStatus,
    required this.onboardingFlags,
    required this.featureFlags,
    required this.userSession,
    required this.checkedAt,
  });

  final SplashDestination destination;
  final VersionGateStatus versionStatus;
  final OnboardingFlags onboardingFlags;
  final FeatureFlags featureFlags;
  final UserSessionState userSession;
  final DateTime checkedAt;
}
