import 'dart:async';

import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/core/storage/cache_bucket.dart';
import 'package:app/core/storage/local_cache_store.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FeatureFlagSource { defaults, cache, remote }

class FeatureFlags {
  const FeatureFlags({
    required this.flags,
    required this.source,
    this.lastUpdatedAt,
  });

  factory FeatureFlags.empty() {
    return const FeatureFlags(
      flags: {'feature_sample_counter': true},
      source: FeatureFlagSource.defaults,
    );
  }

  final Map<String, bool> flags;
  final FeatureFlagSource source;
  final DateTime? lastUpdatedAt;

  bool isEnabled(String key, {bool fallback = false}) {
    return flags[key] ?? fallback;
  }

  bool get sampleCounter => isEnabled('feature_sample_counter');

  FeatureFlags copyWith({
    Map<String, bool>? flags,
    FeatureFlagSource? source,
    DateTime? lastUpdatedAt,
  }) {
    return FeatureFlags(
      flags: flags ?? this.flags,
      source: source ?? this.source,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'flags': flags,
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    };
  }

  static FeatureFlags fromJson(
    Map<String, dynamic> json, {
    FeatureFlagSource source = FeatureFlagSource.cache,
  }) {
    final raw = Map<String, dynamic>.from(json['flags'] as Map? ?? const {});
    final parsed = <String, bool>{};
    raw.forEach((key, value) {
      parsed[key] = value == true;
    });
    final lastUpdated = json['lastUpdatedAt'] as String?;
    return FeatureFlags(
      flags: parsed,
      source: source,
      lastUpdatedAt: lastUpdated == null ? null : DateTime.parse(lastUpdated),
    );
  }
}

class FeatureFlagsNotifier extends AsyncNotifier<FeatureFlags> {
  static const _cacheKey = 'feature_flags';

  FirebaseRemoteConfig get _remoteConfig =>
      ref.read(firebaseRemoteConfigProvider);
  LocalCacheStore get _cache => ref.read(localCacheStoreProvider);

  @override
  Future<FeatureFlags> build() async {
    await ref.read(firebaseInitializedProvider.future);
    await ref.read(localCacheStoreInitializedProvider.future);

    final cached = await _loadFromCache();
    if (cached != null) {
      // Fire-and-forget refresh to keep flags up-to-date.
      unawaited(_refreshFromRemote(silent: true));
      return cached;
    }
    return _refreshFromRemote(fallback: FeatureFlags.empty());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final next = await _refreshFromRemote();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(next);
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<FeatureFlags?> _loadFromCache() async {
    final result = await _cache.read<FeatureFlags>(
      bucket: CacheBucket.featureFlags,
      key: _cacheKey,
      decoder: (data) {
        return FeatureFlags.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    if (!result.hasValue) {
      return null;
    }
    return result.value!.copyWith(source: FeatureFlagSource.cache);
  }

  Future<FeatureFlags> _refreshFromRemote({
    bool silent = false,
    FeatureFlags? fallback,
  }) async {
    try {
      final config = _remoteConfig;
      await config.fetchAndActivate();
      final flags = _extractFlags(config);
      final snapshot = FeatureFlags(
        flags: flags,
        source: FeatureFlagSource.remote,
        lastUpdatedAt: DateTime.now(),
      );
      await _cache.write<FeatureFlags>(
        bucket: CacheBucket.featureFlags,
        key: _cacheKey,
        value: snapshot,
        encoder: (value) => value.toJson(),
      );
      return snapshot;
    } catch (error, stackTrace) {
      if (!silent) {
        Zone.current.handleUncaughtError(error, stackTrace);
      }
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }

  Map<String, bool> _extractFlags(FirebaseRemoteConfig config) {
    final all = config.getAll();
    final result = <String, bool>{};
    for (final entry in all.entries) {
      if (!entry.key.startsWith('feature_')) {
        continue;
      }
      result[entry.key] = entry.value.asBool();
    }
    return result;
  }
}

final featureFlagsProvider =
    AsyncNotifierProvider<FeatureFlagsNotifier, FeatureFlags>(
      FeatureFlagsNotifier.new,
    );
