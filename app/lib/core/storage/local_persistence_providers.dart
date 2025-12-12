// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence.dart';
import 'package:app/security/secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final localPersistenceProvider = Provider<LocalPersistence>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final encryption = LocalEncryptionKeyManager(secureStorage);
  final logger = Logger('LocalPersistence');

  return LocalPersistence(
    hive: Hive,
    encryptionKeyManager: encryption,
    logger: logger,
  );
});

final localPersistenceInitializerProvider = AsyncProvider<void>((ref) async {
  final persistence = ref.watch(localPersistenceProvider);
  await persistence.ensureInitialized();
  await Future.wait(LocalCacheBoxes.defaults.map(persistence.box));
});

final designsCacheProvider = Provider<LocalCacheStore<JsonMap>>((ref) {
  final persistence = ref.watch(localPersistenceProvider);
  return LocalCacheStore<JsonMap>(
    persistence: persistence,
    box: LocalCacheBoxes.designs,
    codec: const JsonCacheCodec(),
    defaultPolicy: CachePolicies.designs,
  );
});

final cartCacheProvider = Provider<LocalCacheStore<JsonMap>>((ref) {
  final persistence = ref.watch(localPersistenceProvider);
  return LocalCacheStore<JsonMap>(
    persistence: persistence,
    box: LocalCacheBoxes.cart,
    codec: const JsonCacheCodec(),
    defaultPolicy: CachePolicies.cart,
  );
});

final ordersCacheProvider = Provider<LocalCacheStore<JsonMap>>((ref) {
  final persistence = ref.watch(localPersistenceProvider);
  return LocalCacheStore<JsonMap>(
    persistence: persistence,
    box: LocalCacheBoxes.orders,
    codec: const JsonCacheCodec(),
    defaultPolicy: CachePolicies.orders,
  );
});

final guidesCacheProvider = Provider<LocalCacheStore<JsonMap>>((ref) {
  final persistence = ref.watch(localPersistenceProvider);
  return LocalCacheStore<JsonMap>(
    persistence: persistence,
    box: LocalCacheBoxes.guides,
    codec: const JsonCacheCodec(),
    defaultPolicy: CachePolicies.guides,
  );
});

final notificationsCacheProvider = Provider<LocalCacheStore<JsonMap>>((ref) {
  final persistence = ref.watch(localPersistenceProvider);
  return LocalCacheStore<JsonMap>(
    persistence: persistence,
    box: LocalCacheBoxes.notifications,
    codec: const JsonCacheCodec(),
    defaultPolicy: CachePolicies.notifications,
  );
});

final kanjiCacheProvider = Provider<LocalCacheStore<JsonMap>>((ref) {
  final persistence = ref.watch(localPersistenceProvider);
  return LocalCacheStore<JsonMap>(
    persistence: persistence,
    box: LocalCacheBoxes.kanji,
    codec: const JsonCacheCodec(),
    defaultPolicy: CachePolicies.kanji,
  );
});

final onboardingCacheProvider = Provider<LocalCacheStore<JsonMap>>((ref) {
  final persistence = ref.watch(localPersistenceProvider);
  return LocalCacheStore<JsonMap>(
    persistence: persistence,
    box: LocalCacheBoxes.onboarding,
    codec: const JsonCacheCodec(),
    defaultPolicy: CachePolicies.onboarding,
  );
});
