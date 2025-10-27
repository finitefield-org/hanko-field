import 'dart:ui';

import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/core/storage/cache_bucket.dart';
import 'package:app/core/storage/cache_policy.dart';
import 'package:app/core/storage/local_cache_store.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/onboarding_local_data_source.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/onboarding/application/locale_selection_controller.dart';
import 'package:app/features/onboarding/application/persona_selection_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleSelectionController', () {
    test(
      'persists selected locale locally and marks onboarding step',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final onboarding = TestOnboardingLocalDataSource(preferences: prefs);
        const initialLocaleState = AppLocaleState(
          locale: Locale('en', 'US'),
          systemLocale: Locale('en', 'US'),
          source: AppLocaleSource.system,
        );
        late TestAppLocaleNotifier appLocaleNotifier;
        final fakeRepository = FakeUserRepository();
        late FakeUserSessionNotifier fakeSession;

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            onboardingLocalDataSourceProvider.overrideWith(
              (ref) async => onboarding,
            ),
            appLocaleProvider.overrideWith(() {
              appLocaleNotifier = TestAppLocaleNotifier(
                initialState: initialLocaleState,
              );
              return appLocaleNotifier;
            }),
            userSessionProvider.overrideWith(() {
              fakeSession = FakeUserSessionNotifier(
                UserSessionState.unauthenticated(),
              );
              return fakeSession;
            }),
            userRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          localeSelectionControllerProvider.notifier,
        );
        await container.read(localeSelectionControllerProvider.future);
        controller.selectLocale(const Locale('ja', 'JP'));
        await controller.saveSelection();

        expect(appLocaleNotifier.setLocaleCalls, isNotEmpty);
        expect(
          appLocaleNotifier.setLocaleCalls.last.toLanguageTag(),
          equals('ja-JP'),
        );
        expect(onboarding.flags.stepCompletion[OnboardingStep.locale], isTrue);
        expect(fakeRepository.lastUpdatedProfile, isNull);
      },
    );

    test(
      'forces confirmation without changes and keeps locale intact',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final onboarding = TestOnboardingLocalDataSource(preferences: prefs);
        const initialLocaleState = AppLocaleState(
          locale: Locale('en', 'US'),
          systemLocale: Locale('en', 'US'),
          source: AppLocaleSource.system,
        );
        late TestAppLocaleNotifier appLocaleNotifier;
        final fakeRepository = FakeUserRepository();
        late FakeUserSessionNotifier fakeSession;

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            onboardingLocalDataSourceProvider.overrideWith(
              (ref) async => onboarding,
            ),
            appLocaleProvider.overrideWith(() {
              appLocaleNotifier = TestAppLocaleNotifier(
                initialState: initialLocaleState,
              );
              return appLocaleNotifier;
            }),
            userSessionProvider.overrideWith(() {
              fakeSession = FakeUserSessionNotifier(
                UserSessionState.unauthenticated(),
              );
              return fakeSession;
            }),
            userRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          localeSelectionControllerProvider.notifier,
        );
        await container.read(localeSelectionControllerProvider.future);
        await controller.saveSelection(force: true);

        expect(appLocaleNotifier.setLocaleCalls, isEmpty);
        expect(onboarding.flags.stepCompletion[OnboardingStep.locale], isTrue);
      },
    );

    test('syncs preferred language to backend when authenticated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = TestOnboardingLocalDataSource(preferences: prefs);
      const initialLocaleState = AppLocaleState(
        locale: Locale('en', 'US'),
        systemLocale: Locale('en', 'US'),
        source: AppLocaleSource.system,
      );
      late TestAppLocaleNotifier appLocaleNotifier;
      final profile = _buildProfile(
        persona: UserPersona.japanese,
        language: UserLanguage.en,
      );
      final session = UserSessionState.authenticated(
        identity: const SessionIdentity(
          uid: 'user-123',
          isAnonymous: false,
          providerIds: [],
        ),
        profile: profile,
        idToken: 'token',
      );
      final fakeRepository = FakeUserRepository();
      late FakeUserSessionNotifier fakeSession;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          onboardingLocalDataSourceProvider.overrideWith(
            (ref) async => onboarding,
          ),
          appLocaleProvider.overrideWith(() {
            appLocaleNotifier = TestAppLocaleNotifier(
              initialState: initialLocaleState,
            );
            return appLocaleNotifier;
          }),
          userSessionProvider.overrideWith(() {
            fakeSession = FakeUserSessionNotifier(session);
            return fakeSession;
          }),
          userRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        localeSelectionControllerProvider.notifier,
      );
      await container.read(localeSelectionControllerProvider.future);
      controller.selectLocale(const Locale('ja', 'JP'));
      await controller.saveSelection();

      expect(fakeRepository.lastUpdatedProfile, isNotNull);
      expect(
        fakeRepository.lastUpdatedProfile!.preferredLanguage,
        equals(UserLanguage.ja),
      );
      expect(fakeSession.refreshCalled, isTrue);
    });
  });

  group('PersonaSelectionController', () {
    test('persists persona selection and marks onboarding step', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = TestOnboardingLocalDataSource(preferences: prefs);
      final fakeRepository = FakeUserRepository();
      late FakeUserSessionNotifier fakeSession;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          onboardingLocalDataSourceProvider.overrideWith(
            (ref) async => onboarding,
          ),
          userSessionProvider.overrideWith(() {
            fakeSession = FakeUserSessionNotifier(
              UserSessionState.unauthenticated(),
            );
            return fakeSession;
          }),
          userRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        personaSelectionControllerProvider.notifier,
      );
      await container.read(personaSelectionControllerProvider.future);
      controller.selectPersona(UserPersona.foreigner);
      await controller.saveSelection();

      expect(
        prefs.getString('user.persona.selection'),
        equals(UserPersona.foreigner.name),
      );
      expect(onboarding.flags.stepCompletion[OnboardingStep.persona], isTrue);
      expect(fakeRepository.lastUpdatedProfile, isNull);
    });

    test('forces confirmation without change', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = TestOnboardingLocalDataSource(preferences: prefs);
      final fakeRepository = FakeUserRepository();
      late FakeUserSessionNotifier fakeSession;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          onboardingLocalDataSourceProvider.overrideWith(
            (ref) async => onboarding,
          ),
          userSessionProvider.overrideWith(() {
            fakeSession = FakeUserSessionNotifier(
              UserSessionState.unauthenticated(),
            );
            return fakeSession;
          }),
          userRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        personaSelectionControllerProvider.notifier,
      );
      await container.read(personaSelectionControllerProvider.future);
      await controller.saveSelection(force: true);

      expect(onboarding.flags.stepCompletion[OnboardingStep.persona], isTrue);
      expect(fakeRepository.lastUpdatedProfile, isNull);
    });

    test('syncs persona to backend when authenticated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = TestOnboardingLocalDataSource(preferences: prefs);
      final profile = _buildProfile(
        persona: UserPersona.japanese,
        language: UserLanguage.en,
      );
      final session = UserSessionState.authenticated(
        identity: const SessionIdentity(
          uid: 'user-123',
          isAnonymous: false,
          providerIds: [],
        ),
        profile: profile,
        idToken: 'token',
      );
      final fakeRepository = FakeUserRepository();
      late FakeUserSessionNotifier fakeSession;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          onboardingLocalDataSourceProvider.overrideWith(
            (ref) async => onboarding,
          ),
          userSessionProvider.overrideWith(() {
            fakeSession = FakeUserSessionNotifier(session);
            return fakeSession;
          }),
          userRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        personaSelectionControllerProvider.notifier,
      );
      await container.read(personaSelectionControllerProvider.future);
      controller.selectPersona(UserPersona.foreigner);
      await controller.saveSelection();

      expect(fakeRepository.lastUpdatedProfile, isNotNull);
      expect(
        fakeRepository.lastUpdatedProfile!.persona,
        equals(UserPersona.foreigner),
      );
      expect(fakeSession.refreshCalled, isTrue);
    });
  });
}

UserProfile _buildProfile({
  required UserPersona persona,
  required UserLanguage language,
}) {
  final now = DateTime.now();
  return UserProfile(
    id: 'user',
    persona: persona,
    preferredLanguage: language,
    isActive: true,
    piiMasked: false,
    createdAt: now,
    updatedAt: now,
  );
}

class TestAppLocaleNotifier extends AppLocaleNotifier {
  TestAppLocaleNotifier({required this.initialState});

  final AppLocaleState initialState;
  final List<Locale> setLocaleCalls = [];
  bool useSystemLocaleCalled = false;

  @override
  Future<AppLocaleState> build() async => initialState;

  @override
  Future<void> setLocale(Locale locale) async {
    setLocaleCalls.add(locale);
    state = AsyncData(
      (state.asData?.value ?? initialState).copyWith(
        locale: locale,
        source: AppLocaleSource.user,
        lastUpdatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> useSystemLocale() async {
    useSystemLocaleCalled = true;
  }
}

class FakeUserSessionNotifier extends UserSessionNotifier {
  FakeUserSessionNotifier(this._initialState);

  final UserSessionState _initialState;
  bool refreshCalled = false;

  @override
  Future<UserSessionState> build() async => _initialState;

  @override
  Future<void> refreshProfile() async {
    refreshCalled = true;
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(_initialState);
  }

  @override
  Future<void> signOut() async {
    // no-op for tests
  }
}

class FakeUserRepository extends UserRepository {
  UserProfile? lastUpdatedProfile;

  @override
  Future<UserProfile> fetchCurrentUser() async {
    return lastUpdatedProfile ??
        _buildProfile(persona: UserPersona.japanese, language: UserLanguage.ja);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    lastUpdatedProfile = profile;
    return profile;
  }

  @override
  Future<List<UserAddress>> fetchAddresses() {
    throw UnimplementedError();
  }

  @override
  Future<UserAddress> upsertAddress(UserAddress address) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAddress(String addressId) {
    throw UnimplementedError();
  }

  @override
  Future<List<UserPaymentMethod>> fetchPaymentMethods() {
    throw UnimplementedError();
  }

  @override
  Future<void> removePaymentMethod(String methodId) {
    throw UnimplementedError();
  }

  @override
  Future<List<UserFavoriteDesign>> fetchFavorites() {
    throw UnimplementedError();
  }

  @override
  Future<void> addFavorite(UserFavoriteDesign favorite) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeFavorite(String favoriteId) {
    throw UnimplementedError();
  }
}

class TestOnboardingLocalDataSource extends OnboardingLocalDataSource {
  TestOnboardingLocalDataSource({required super.preferences})
    : _prefs = preferences,
      super(cacheRepository: FakeOfflineCacheRepository());

  final SharedPreferences _prefs;
  OnboardingFlags flags = OnboardingFlags.initial();
  final List<OnboardingStep> recordedSteps = [];

  @override
  Future<OnboardingFlags> load() async {
    return flags;
  }

  @override
  Future<OnboardingFlags> updateStep(
    OnboardingStep step, {
    bool completed = true,
  }) async {
    recordedSteps.add(step);
    flags = flags.markStep(step, completed);
    // Mirror state into preferences to align with production behavior.
    await _prefs.setString('test.onboarding.flags', flags.toJson().toString());
    return flags;
  }

  @override
  Future<void> replace(OnboardingFlags newFlags) async {
    flags = newFlags;
  }

  @override
  Future<void> reset() async {
    flags = OnboardingFlags.initial();
  }
}

class FakeOfflineCacheRepository extends OfflineCacheRepository {
  FakeOfflineCacheRepository() : super(FakeLocalCacheStore());
}

class FakeLocalCacheStore extends LocalCacheStore {
  FakeLocalCacheStore()
    : _memory = {},
      super(
        secureStorage: SecureStorageService(),
        hive: _FakeHive(),
        initializeHive: (_) async {},
      );

  final Map<_CacheKey, _CacheEntry> _memory;

  @override
  Future<CacheReadResult<T>> read<T>({
    required CacheBucket bucket,
    required CacheDecoder<T> decoder,
    String key = LocalCacheStore.defaultEntryKey,
  }) async {
    final entry = _memory[_CacheKey(bucket, key)];
    if (entry == null) {
      return const CacheReadResult.miss();
    }
    return CacheReadResult.value(
      value: decoder(entry.data),
      state: CacheState.fresh,
      lastUpdated: entry.updatedAt,
    );
  }

  @override
  Future<void> write<T>({
    required CacheBucket bucket,
    required CacheEncoder<T> encoder,
    required T value,
    String key = LocalCacheStore.defaultEntryKey,
    String? etag,
  }) async {
    _memory[_CacheKey(bucket, key)] = _CacheEntry(
      data: encoder(value),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> invalidate(
    CacheBucket bucket, {
    String key = LocalCacheStore.defaultEntryKey,
  }) async {
    _memory.remove(_CacheKey(bucket, key));
  }

  @override
  Future<void> clear(CacheBucket bucket) async {
    _memory.removeWhere((key, _) => key.bucket == bucket);
  }

  @override
  Future<void> clearAll() async {
    _memory.clear();
  }
}

class _CacheKey {
  const _CacheKey(this.bucket, this.key);

  final CacheBucket bucket;
  final String key;

  @override
  bool operator ==(Object other) {
    return other is _CacheKey && other.bucket == bucket && other.key == key;
  }

  @override
  int get hashCode => Object.hash(bucket, key);
}

class _CacheEntry {
  _CacheEntry({required this.data, required this.updatedAt});

  final Object? data;
  final DateTime updatedAt;
}

class _FakeHive implements HiveInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
