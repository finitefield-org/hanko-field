import 'package:app/core/app_state/feature_flags.dart';
import 'package:app/core/firebase/firebase_providers.dart';
import 'package:app/core/storage/cache_bucket.dart';
import 'package:app/core/storage/cache_policy.dart';
import 'package:app/core/storage/local_cache_store.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

Object? _dummyEncoder(FeatureFlags _) => null;
FeatureFlags _dummyDecoder(Object? _) => FeatureFlags.empty();

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class _MockLocalCacheStore extends Mock implements LocalCacheStore {}

class _MockRemoteConfigValue extends Mock implements RemoteConfigValue {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(CacheBucket.featureFlags);
    registerFallbackValue(FeatureFlags.empty());
    registerFallbackValue(_dummyEncoder);
    registerFallbackValue(_dummyDecoder);
  });

  late _MockRemoteConfig remoteConfig;
  late _MockLocalCacheStore cacheStore;

  setUp(() {
    remoteConfig = _MockRemoteConfig();
    cacheStore = _MockLocalCacheStore();

    when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remoteConfig.getAll()).thenReturn({});
    when(
      () => cacheStore.write<FeatureFlags>(
        bucket: any(named: 'bucket'),
        key: any(named: 'key'),
        value: any(named: 'value'),
        encoder: any(named: 'encoder'),
      ),
    ).thenAnswer((_) async {});
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        firebaseInitializedProvider.overrideWith((ref) async {}),
        localCacheStoreInitializedProvider.overrideWith((ref) async {}),
        firebaseRemoteConfigProvider.overrideWithValue(remoteConfig),
        localCacheStoreProvider.overrideWithValue(cacheStore),
      ],
    );
  }

  test('uses cached feature flags when available', () async {
    when(
      () => cacheStore.read<FeatureFlags>(
        bucket: any(named: 'bucket'),
        key: any(named: 'key'),
        decoder: any(named: 'decoder'),
      ),
    ).thenAnswer((invocation) async {
      final decoder =
          invocation.namedArguments[#decoder] as FeatureFlags Function(Object?);
      final value = decoder({
        'flags': {'feature_sample_counter': false},
        'lastUpdatedAt': DateTime(2024).toIso8601String(),
      });
      return CacheReadResult.value(
        value: value,
        state: CacheState.fresh,
        lastUpdated: DateTime.now(),
      );
    });

    final container = createContainer();
    addTearDown(container.dispose);

    final flags = await container.read(featureFlagsProvider.future);
    expect(flags.source, FeatureFlagSource.cache);
    expect(flags.sampleCounter, isFalse);
  });

  test('fetches from remote config when cache miss', () async {
    when(
      () => cacheStore.read<FeatureFlags>(
        bucket: any(named: 'bucket'),
        key: any(named: 'key'),
        decoder: any(named: 'decoder'),
      ),
    ).thenAnswer((_) async => const CacheReadResult<FeatureFlags>.miss());

    final remoteValue = _MockRemoteConfigValue();
    when(remoteValue.asBool).thenReturn(true);
    when(() => remoteConfig.getAll()).thenReturn({
      'feature_sample_counter': remoteValue,
      'welcome_title': remoteValue,
    });

    final container = createContainer();
    addTearDown(container.dispose);

    final flags = await container.read(featureFlagsProvider.future);
    expect(flags.source, FeatureFlagSource.remote);
    expect(flags.sampleCounter, isTrue);
    verify(
      () => cacheStore.write<FeatureFlags>(
        bucket: CacheBucket.featureFlags,
        key: any(named: 'key'),
        value: any(named: 'value'),
        encoder: any(named: 'encoder'),
      ),
    ).called(1);
  });
}
