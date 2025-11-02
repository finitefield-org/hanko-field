import 'package:app/core/storage/cache_policy.dart';
import 'package:app/features/design_creation/domain/registrability_check.dart';
import 'package:flutter/foundation.dart';

@immutable
class RegistrabilityCheckState {
  const RegistrabilityCheckState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.currentFingerprint,
    this.cachedFingerprint,
    this.result,
    this.cacheState,
    this.errorMessage,
    this.isOfflineFallback = false,
    this.lastAttemptAt,
  });

  final bool isLoading;
  final bool isRefreshing;
  final String? currentFingerprint;
  final String? cachedFingerprint;
  final RegistrabilityCheckResult? result;
  final CacheState? cacheState;
  final String? errorMessage;
  final bool isOfflineFallback;
  final DateTime? lastAttemptAt;

  bool get hasResult => result != null;

  bool get isOutdated =>
      hasResult &&
      currentFingerprint != null &&
      cachedFingerprint != null &&
      currentFingerprint != cachedFingerprint;

  bool get canRunCheck => currentFingerprint != null && !isLoading;

  RegistrabilityCheckState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? currentFingerprint,
    String? cachedFingerprint,
    RegistrabilityCheckResult? result,
    bool clearResult = false,
    CacheState? cacheState,
    bool clearCacheState = false,
    String? errorMessage,
    bool clearError = false,
    bool? isOfflineFallback,
    DateTime? lastAttemptAt,
  }) {
    return RegistrabilityCheckState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      currentFingerprint: currentFingerprint ?? this.currentFingerprint,
      cachedFingerprint: cachedFingerprint ?? this.cachedFingerprint,
      result: clearResult ? null : result ?? this.result,
      cacheState: clearCacheState ? null : cacheState ?? this.cacheState,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RegistrabilityCheckState &&
            other.isLoading == isLoading &&
            other.isRefreshing == isRefreshing &&
            other.currentFingerprint == currentFingerprint &&
            other.cachedFingerprint == cachedFingerprint &&
            other.result == result &&
            other.cacheState == cacheState &&
            other.errorMessage == errorMessage &&
            other.isOfflineFallback == isOfflineFallback &&
            other.lastAttemptAt == lastAttemptAt);
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    isRefreshing,
    currentFingerprint,
    cachedFingerprint,
    result,
    cacheState,
    errorMessage,
    isOfflineFallback,
    lastAttemptAt,
  );
}
