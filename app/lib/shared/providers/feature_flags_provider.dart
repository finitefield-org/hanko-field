// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/firebase/firebase_providers.dart';
import 'package:app/firebase/remote_config.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

const featureFlagsScope = Scope<FeatureFlags>.required('feature.flags');

final _featureFlagsLogger = Logger('FeatureFlagsProvider');

class FeatureFlags {
  const FeatureFlags({
    required this.designAi,
    required this.checkoutEnabled,
    required this.minSupportedVersionIos,
    required this.minSupportedVersionAndroid,
    required this.latestVersionIos,
    required this.latestVersionAndroid,
    required this.appStoreUrlIos,
    required this.appStoreUrlAndroid,
    required this.lastUpdatedAt,
  });

  final bool designAi;
  final bool checkoutEnabled;
  final String minSupportedVersionIos;
  final String minSupportedVersionAndroid;
  final String latestVersionIos;
  final String latestVersionAndroid;
  final String appStoreUrlIos;
  final String appStoreUrlAndroid;
  final DateTime? lastUpdatedAt;

  FeatureFlags copyWith({
    bool? designAi,
    bool? checkoutEnabled,
    String? minSupportedVersionIos,
    String? minSupportedVersionAndroid,
    String? latestVersionIos,
    String? latestVersionAndroid,
    String? appStoreUrlIos,
    String? appStoreUrlAndroid,
    DateTime? lastUpdatedAt,
  }) {
    return FeatureFlags(
      designAi: designAi ?? this.designAi,
      checkoutEnabled: checkoutEnabled ?? this.checkoutEnabled,
      minSupportedVersionIos:
          minSupportedVersionIos ?? this.minSupportedVersionIos,
      minSupportedVersionAndroid:
          minSupportedVersionAndroid ?? this.minSupportedVersionAndroid,
      latestVersionIos: latestVersionIos ?? this.latestVersionIos,
      latestVersionAndroid: latestVersionAndroid ?? this.latestVersionAndroid,
      appStoreUrlIos: appStoreUrlIos ?? this.appStoreUrlIos,
      appStoreUrlAndroid: appStoreUrlAndroid ?? this.appStoreUrlAndroid,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FeatureFlags &&
            other.designAi == designAi &&
            other.checkoutEnabled == checkoutEnabled &&
            other.minSupportedVersionIos == minSupportedVersionIos &&
            other.minSupportedVersionAndroid == minSupportedVersionAndroid &&
            other.latestVersionIos == latestVersionIos &&
            other.latestVersionAndroid == latestVersionAndroid &&
            other.appStoreUrlIos == appStoreUrlIos &&
            other.appStoreUrlAndroid == appStoreUrlAndroid &&
            other.lastUpdatedAt == lastUpdatedAt);
  }

  @override
  int get hashCode => Object.hash(
    designAi,
    checkoutEnabled,
    minSupportedVersionIos,
    minSupportedVersionAndroid,
    latestVersionIos,
    latestVersionAndroid,
    appStoreUrlIos,
    appStoreUrlAndroid,
    lastUpdatedAt,
  );

  static FeatureFlags fromRemoteConfig(FirebaseRemoteConfig remoteConfig) {
    final iosMinVersion = remoteConfig.getString('min_supported_version_ios');
    final androidMinVersion = remoteConfig.getString(
      'min_supported_version_android',
    );
    final iosLatestVersion = remoteConfig.getString('latest_version_ios');
    final androidLatestVersion = remoteConfig.getString(
      'latest_version_android',
    );
    final iosStoreUrl = remoteConfig.getString('app_store_url_ios');
    final androidStoreUrl = remoteConfig.getString('app_store_url_android');

    return FeatureFlags(
      designAi: remoteConfig.getBool('feature_design_ai'),
      checkoutEnabled: remoteConfig.getBool('feature_checkout_enabled'),
      minSupportedVersionIos: iosMinVersion.isNotEmpty
          ? iosMinVersion
          : _defaultString('min_supported_version_ios'),
      minSupportedVersionAndroid: androidMinVersion.isNotEmpty
          ? androidMinVersion
          : _defaultString('min_supported_version_android'),
      latestVersionIos: iosLatestVersion.isNotEmpty
          ? iosLatestVersion
          : _defaultString('latest_version_ios'),
      latestVersionAndroid: androidLatestVersion.isNotEmpty
          ? androidLatestVersion
          : _defaultString('latest_version_android'),
      appStoreUrlIos: iosStoreUrl.isNotEmpty
          ? iosStoreUrl
          : _defaultString('app_store_url_ios'),
      appStoreUrlAndroid: androidStoreUrl.isNotEmpty
          ? androidStoreUrl
          : _defaultString('app_store_url_android'),
      lastUpdatedAt: remoteConfig.lastFetchTime,
    );
  }

  static FeatureFlags defaults({DateTime? lastUpdatedAt}) {
    return FeatureFlags(
      designAi: _defaultBool('feature_design_ai'),
      checkoutEnabled: _defaultBool('feature_checkout_enabled'),
      minSupportedVersionIos: _defaultString('min_supported_version_ios'),
      minSupportedVersionAndroid: _defaultString(
        'min_supported_version_android',
      ),
      latestVersionIos: _defaultString('latest_version_ios'),
      latestVersionAndroid: _defaultString('latest_version_android'),
      appStoreUrlIos: _defaultString('app_store_url_ios'),
      appStoreUrlAndroid: _defaultString('app_store_url_android'),
      lastUpdatedAt: lastUpdatedAt,
    );
  }
}

class FeatureFlagsProvider extends AsyncProvider<FeatureFlags> {
  FeatureFlagsProvider() : super.args(null, autoDispose: false);

  late final refreshMut = mutation<FeatureFlags>(#refresh);

  @override
  Future<FeatureFlags> build(Ref<AsyncValue<FeatureFlags>> ref) async {
    try {
      return ref.scope(featureFlagsScope);
    } on StateError {
      // Continue with Remote Config-backed flags.
    }

    final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
    try {
      await remoteConfig.ensureInitialized();
      await ref.watch(remoteConfigInitializerProvider.future);
    } catch (e, stack) {
      _featureFlagsLogger.warning(
        'Failed to initialize Remote Config; using defaults.',
        e,
        stack,
      );
      return FeatureFlags.defaults(lastUpdatedAt: remoteConfig.lastFetchTime);
    }

    _listenForUpdates(ref, remoteConfig);

    return FeatureFlags.fromRemoteConfig(remoteConfig);
  }

  Call<FeatureFlags, AsyncValue<FeatureFlags>> refresh() =>
      mutate(refreshMut, (ref) async {
        final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
        final av = ref.watch(this);
        ref.state = switch (av) {
          AsyncData(:final value) => AsyncData(value, isRefreshing: true),
          AsyncError(:final error, :final stack, :final previous) => AsyncError(
            error,
            stack,
            previous: previous,
          ),
          _ => const AsyncLoading<FeatureFlags>(),
        };

        try {
          await remoteConfig.fetchAndActivate();
        } catch (e, stack) {
          _featureFlagsLogger.warning(
            'Failed to refresh Remote Config; using cached values.',
            e,
            stack,
          );
        }
        final flags = FeatureFlags.fromRemoteConfig(remoteConfig);
        ref.state = AsyncData(flags);
        return flags;
      }, concurrency: Concurrency.restart);

  void _listenForUpdates(
    Ref<AsyncValue<FeatureFlags>> ref,
    FirebaseRemoteConfig remoteConfig,
  ) {
    try {
      ref.emit(
        remoteConfig.onConfigUpdated.asyncMap((_) async {
          try {
            await remoteConfig.activate();
          } catch (e, stack) {
            _featureFlagsLogger.warning(
              'Failed to activate Remote Config update',
              e,
              stack,
            );
          }
          return FeatureFlags.fromRemoteConfig(remoteConfig);
        }),
      );
    } on UnsupportedError {
      // Web does not support the update stream; rely on manual refresh.
      _featureFlagsLogger.fine('Remote Config update stream not supported');
    }
  }
}

final featureFlagsProvider = FeatureFlagsProvider();

/// Tests can inject a custom flag set via:
/// `ProviderScope(overrides: [featureFlagsScope.overrideWithValue(fakeFlags)])`.

String _defaultString(String key) {
  return remoteConfigDefaults[key] as String? ?? '';
}

bool _defaultBool(String key) {
  return remoteConfigDefaults[key] as bool? ?? false;
}
