// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

typedef RawCacheBox = Box<Map<String, Object?>>;

class CacheBox {
  const CacheBox(this.name, {this.encrypted = false});

  final String name;
  final bool encrypted;
}

class LocalCacheBoxes {
  const LocalCacheBoxes._();

  static const designs = CacheBox('designs_cache', encrypted: true);
  static const cart = CacheBox('cart_cache', encrypted: true);
  static const orders = CacheBox('orders_cache', encrypted: true);
  static const guides = CacheBox('guides_cache');
  static const notifications = CacheBox('notifications_cache');
  static const supportChat = CacheBox('support_chat_cache', encrypted: true);
  static const onboarding = CacheBox('onboarding_cache');
  static const kanji = CacheBox('kanji_cache');

  static const defaults = <CacheBox>[
    designs,
    cart,
    orders,
    guides,
    notifications,
    supportChat,
    onboarding,
    kanji,
  ];
}

class LocalEncryptionKeyManager {
  LocalEncryptionKeyManager(this._storage);

  final FlutterSecureStorage _storage;

  Future<HiveAesCipher> readOrCreateCipher() async {
    final key = await _readOrCreateKey();
    return HiveAesCipher(key);
  }

  Future<List<int>> _readOrCreateKey() async {
    final existing = await _storage.read(key: _cacheKeyName);
    if (existing != null) return base64Decode(existing);

    final key = Hive.generateSecureKey();
    await _storage.write(key: _cacheKeyName, value: base64Encode(key));
    return key;
  }
}

class LocalPersistence {
  LocalPersistence({
    required HiveInterface hive,
    required LocalEncryptionKeyManager encryptionKeyManager,
    Logger? logger,
  }) : _hive = hive,
       _encryptionKeyManager = encryptionKeyManager,
       _logger = logger ?? Logger('LocalPersistence');

  final HiveInterface _hive;
  final LocalEncryptionKeyManager _encryptionKeyManager;
  final Logger _logger;

  bool _initialized = false;
  Future<void>? _initFuture;
  Future<HiveAesCipher>? _cipherFuture;
  final Map<String, Future<RawCacheBox>> _boxes = {};

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initFuture ??= _initialize();
    await _initFuture;
  }

  Future<RawCacheBox> box(CacheBox box) async {
    await ensureInitialized();

    return _boxes.putIfAbsent(box.name, () async {
      final cipher = box.encrypted ? await _cipher() : null;
      final opened = await _hive.openBox<Map<String, Object?>>(
        box.name,
        encryptionCipher: cipher,
      );
      return opened;
    });
  }

  Future<void> clearAll(Iterable<CacheBox> boxes) async {
    for (final box in boxes) {
      final opened = await this.box(box);
      await opened.clear();
    }
  }

  Future<HiveAesCipher> _cipher() {
    _cipherFuture ??= _encryptionKeyManager.readOrCreateCipher();
    return _cipherFuture!;
  }

  Future<void> _initialize() async {
    await Hive.initFlutter();
    _initialized = true;
    _logger.fine('Hive initialized for local persistence');
  }
}

const _cacheKeyName = 'local_cache_encryption_key';
