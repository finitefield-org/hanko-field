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
    required this.lastUpdatedAt,
  });

  final bool designAi;
  final bool checkoutEnabled;
  final String minSupportedVersionIos;
  final String minSupportedVersionAndroid;
  final DateTime? lastUpdatedAt;

  FeatureFlags copyWith({
    bool? designAi,
    bool? checkoutEnabled,
    String? minSupportedVersionIos,
    String? minSupportedVersionAndroid,
    DateTime? lastUpdatedAt,
  }) {
    return FeatureFlags(
      designAi: designAi ?? this.designAi,
      checkoutEnabled: checkoutEnabled ?? this.checkoutEnabled,
      minSupportedVersionIos:
          minSupportedVersionIos ?? this.minSupportedVersionIos,
      minSupportedVersionAndroid:
          minSupportedVersionAndroid ?? this.minSupportedVersionAndroid,
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
            other.lastUpdatedAt == lastUpdatedAt);
  }

  @override
  int get hashCode => Object.hash(
    designAi,
    checkoutEnabled,
    minSupportedVersionIos,
    minSupportedVersionAndroid,
    lastUpdatedAt,
  );

  static FeatureFlags fromRemoteConfig(FirebaseRemoteConfig remoteConfig) {
    final iosMinVersion = remoteConfig.getString('min_supported_version_ios');
    final androidMinVersion = remoteConfig.getString(
      'min_supported_version_android',
    );

    return FeatureFlags(
      designAi: remoteConfig.getBool('feature_design_ai'),
      checkoutEnabled: remoteConfig.getBool('feature_checkout_enabled'),
      minSupportedVersionIos: iosMinVersion.isNotEmpty
          ? iosMinVersion
          : (remoteConfigDefaults['min_supported_version_ios'] as String? ??
                ''),
      minSupportedVersionAndroid: androidMinVersion.isNotEmpty
          ? androidMinVersion
          : (remoteConfigDefaults['min_supported_version_android'] as String? ??
                ''),
      lastUpdatedAt: remoteConfig.lastFetchTime,
    );
  }
}

class FeatureFlagsProvider extends AsyncProvider<FeatureFlags> {
  FeatureFlagsProvider() : super.args(null, autoDispose: false);

  late final refreshMut = mutation<FeatureFlags>(#refresh);

  @override
  Future<FeatureFlags> build(Ref ref) async {
    try {
      return ref.scope(featureFlagsScope);
    } on StateError {
      // Continue with Remote Config-backed flags.
    }

    final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
    await remoteConfig.ensureInitialized();
    await ref.watch(remoteConfigInitializerProvider.future);

    _listenForUpdates(ref, remoteConfig);

    return FeatureFlags.fromRemoteConfig(remoteConfig);
  }

  Call<FeatureFlags> refresh() => mutate(refreshMut, (ref) async {
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

    await remoteConfig.fetchAndActivate();
    final flags = FeatureFlags.fromRemoteConfig(remoteConfig);
    ref.state = AsyncData(flags);
    return flags;
  }, concurrency: Concurrency.restart);

  void _listenForUpdates(Ref ref, FirebaseRemoteConfig remoteConfig) {
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
