// ignore_for_file: public_member_api_docs

import 'package:app/core/util/version_compare.dart';
import 'package:app/shared/providers/feature_flags_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.currentVersion,
    required this.minSupportedVersion,
    required this.latestVersion,
    required this.isUpdateRequired,
    required this.isUpdateRecommended,
    required this.storePrimaryUrl,
    required this.storeFallbackUrl,
  });

  final String currentVersion;
  final String minSupportedVersion;
  final String latestVersion;
  final bool isUpdateRequired;
  final bool isUpdateRecommended;
  final Uri? storePrimaryUrl;
  final Uri? storeFallbackUrl;

  bool get hasStoreLinks => storePrimaryUrl != null || storeFallbackUrl != null;
}

final appUpdateStatusProvider = AsyncProvider<AppUpdateStatus>((ref) async {
  final flags = await ref.watch(featureFlagsProvider.future);
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;
  final minSupportedVersion = minimumSupportedVersion(flags);
  final latestVersion = latestAvailableVersion(flags);
  final storeLinks = storeLinksForPlatform(
    flags,
    packageName: packageInfo.packageName,
  );
  final isUpdateRequired = !isVersionAtLeast(
    currentVersion,
    minSupportedVersion,
  );
  final isUpdateRecommended =
      latestVersion.isNotEmpty &&
      compareVersions(currentVersion, latestVersion) < 0;

  return AppUpdateStatus(
    currentVersion: currentVersion,
    minSupportedVersion: minSupportedVersion,
    latestVersion: latestVersion,
    isUpdateRequired: isUpdateRequired,
    isUpdateRecommended: isUpdateRecommended,
    storePrimaryUrl: storeLinks.primary,
    storeFallbackUrl: storeLinks.fallback,
  );
});

final appUpdateRouterRefreshProvider = Provider<AppUpdateRouterRefreshNotifier>(
  (ref) {
    final notifier = AppUpdateRouterRefreshNotifier();
    ref.listen(appUpdateStatusProvider, (_, __) => notifier.trigger());
    ref.onDispose(notifier.dispose);
    return notifier;
  },
);

class AppUpdateRouterRefreshNotifier extends ChangeNotifier {
  void trigger() {
    notifyListeners();
  }
}

String minimumSupportedVersion(FeatureFlags flags) {
  if (kIsWeb) {
    return flags.minSupportedVersionAndroid;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => flags.minSupportedVersionIos,
    _ => flags.minSupportedVersionAndroid,
  };
}

String latestAvailableVersion(FeatureFlags flags) {
  if (kIsWeb) {
    return flags.latestVersionAndroid;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => flags.latestVersionIos,
    _ => flags.latestVersionAndroid,
  };
}

StoreLinks storeLinksForPlatform(FeatureFlags flags, {String? packageName}) {
  final resolvedPackage = packageName?.trim() ?? '';
  if (kIsWeb) {
    return StoreLinks(primary: _parseUrl(flags.appStoreUrlAndroid));
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => _iosStoreLinks(flags),
    TargetPlatform.android => _androidStoreLinks(flags, resolvedPackage),
    _ => StoreLinks(primary: _parseUrl(flags.appStoreUrlAndroid)),
  };
}

StoreLinks _iosStoreLinks(FeatureFlags flags) {
  final raw = _parseUrl(flags.appStoreUrlIos);
  if (raw == null) return const StoreLinks();

  if (raw.scheme == 'itms-apps') {
    final fallback = raw.replace(scheme: 'https');
    return StoreLinks(
      primary: raw,
      fallback: fallback == raw ? null : fallback,
    );
  }

  if (raw.scheme == 'https' || raw.scheme == 'http') {
    return StoreLinks(
      primary: raw.replace(scheme: 'itms-apps'),
      fallback: raw,
    );
  }

  return StoreLinks(primary: raw);
}

StoreLinks _androidStoreLinks(FeatureFlags flags, String packageName) {
  final raw = _parseUrl(flags.appStoreUrlAndroid);
  final marketUrl = packageName.isEmpty
      ? null
      : Uri.parse('market://details?id=$packageName');
  final webUrl = packageName.isEmpty
      ? null
      : Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

  if (raw != null && raw.scheme == 'market') {
    return StoreLinks(primary: raw, fallback: webUrl);
  }

  final primary = marketUrl ?? raw;
  final fallback = raw ?? webUrl;
  return StoreLinks(
    primary: primary,
    fallback: fallback == primary ? null : fallback,
  );
}

Uri? _parseUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return Uri.tryParse(trimmed);
}

class StoreLinks {
  const StoreLinks({this.primary, this.fallback});

  final Uri? primary;
  final Uri? fallback;
}
