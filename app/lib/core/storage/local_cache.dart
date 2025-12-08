// ignore_for_file: public_member_api_docs

import 'package:app/core/storage/local_persistence.dart';

typedef JsonMap = Map<String, Object?>;
typedef Clock = DateTime Function();

class CachePolicy {
  const CachePolicy({required this.ttl, this.staleGrace = Duration.zero});

  final Duration ttl;
  final Duration staleGrace;

  CachePolicy copyWith({Duration? ttl, Duration? staleGrace}) {
    return CachePolicy(
      ttl: ttl ?? this.ttl,
      staleGrace: staleGrace ?? this.staleGrace,
    );
  }

  bool isFresh(DateTime storedAt, DateTime now) {
    return now.isBefore(storedAt.add(ttl));
  }

  bool isUsable(DateTime storedAt, DateTime now) {
    return now.isBefore(storedAt.add(ttl + staleGrace));
  }
}

class CachePolicies {
  const CachePolicies._();

  static const designs = CachePolicy(
    ttl: Duration(minutes: 20),
    staleGrace: Duration(minutes: 20),
  );

  static const cart = CachePolicy(
    ttl: Duration(hours: 24),
    staleGrace: Duration(hours: 24),
  );

  static const guides = CachePolicy(
    ttl: Duration(hours: 6),
    staleGrace: Duration(hours: 6),
  );

  static const notifications = CachePolicy(
    ttl: Duration(minutes: 10),
    staleGrace: Duration(minutes: 20),
  );

  static const kanji = CachePolicy(
    ttl: Duration(hours: 12),
    staleGrace: Duration(days: 2),
  );

  static const onboarding = CachePolicy(
    ttl: Duration(days: 365),
    staleGrace: Duration(days: 30),
  );
}

class CacheHit<T> {
  const CacheHit({
    required this.value,
    required this.storedAt,
    required this.age,
    required this.isFresh,
    required this.isStale,
    required this.tags,
  });

  final T value;
  final DateTime storedAt;
  final Duration age;
  final bool isFresh;
  final bool isStale;
  final List<String> tags;
}

abstract class CacheCodec<T> {
  const CacheCodec();

  JsonMap encode(T value);

  T decode(JsonMap map);
}

class JsonCacheCodec extends CacheCodec<JsonMap> {
  const JsonCacheCodec();

  @override
  JsonMap encode(JsonMap value) => value;

  @override
  JsonMap decode(JsonMap map) => map;
}

class LocalCacheStore<T> {
  LocalCacheStore({
    required LocalPersistence persistence,
    required CacheBox box,
    required CacheCodec<T> codec,
    CachePolicy defaultPolicy = const CachePolicy(ttl: Duration(minutes: 10)),
    Clock? clock,
  }) : _persistence = persistence,
       _box = box,
       _codec = codec,
       _defaultPolicy = defaultPolicy,
       _clock = clock ?? DateTime.now;

  final LocalPersistence _persistence;
  final CacheBox _box;
  final CacheCodec<T> _codec;
  final CachePolicy _defaultPolicy;
  final Clock _clock;

  Future<void> write(
    String key,
    T value, {
    CachePolicy? policy,
    List<String> tags = const [],
  }) async {
    final box = await _persistence.box(_box);
    final effectivePolicy = policy ?? _defaultPolicy;
    final normalizedTags = _normalizeTags(tags);

    final entry = <String, Object?>{
      _payloadKey: _codec.encode(value),
      _storedAtKey: _clock().millisecondsSinceEpoch,
      _ttlKey: effectivePolicy.ttl.inMilliseconds,
      _staleKey: effectivePolicy.staleGrace.inMilliseconds,
      _tagsKey: normalizedTags,
    };

    await box.put(key, entry);
  }

  Future<CacheHit<T>?> read(String key, {CachePolicy? policy}) async {
    final box = await _persistence.box(_box);
    final Map<String, Object?>? raw = box.get(key);
    if (raw == null) return null;

    final map = Map<String, Object?>.of(raw);
    final storedAtMs = map[_storedAtKey] as int?;
    final payload = map[_payloadKey];
    if (storedAtMs == null || payload is! Map) {
      await box.delete(key);
      return null;
    }

    final storedAt = DateTime.fromMillisecondsSinceEpoch(storedAtMs);
    final now = _clock();
    final effectivePolicy =
        policy ?? _policyFromEntry(map, fallback: _defaultPolicy);
    final isFresh = effectivePolicy.isFresh(storedAt, now);
    final isUsable = effectivePolicy.isUsable(storedAt, now);

    if (!isUsable) {
      await box.delete(key);
      return null;
    }

    final decodedPayload = _codec.decode(Map<String, Object?>.from(payload));
    final tags = _readTags(map);

    return CacheHit(
      value: decodedPayload,
      storedAt: storedAt,
      age: now.difference(storedAt),
      isFresh: isFresh,
      isStale: !isFresh,
      tags: tags,
    );
  }

  Future<void> delete(String key) async {
    final box = await _persistence.box(_box);
    await box.delete(key);
  }

  Future<int> clearByTag(String tag) async {
    final box = await _persistence.box(_box);
    final keysToDelete = <dynamic>[];

    for (final entryKey in box.keys) {
      final Map<String, Object?>? raw = box.get(entryKey);
      if (raw == null) continue;
      final tags = _readTags(Map<String, Object?>.of(raw));
      if (tags.contains(tag)) keysToDelete.add(entryKey);
    }

    if (keysToDelete.isEmpty) return 0;
    await box.deleteAll(keysToDelete);
    return keysToDelete.length;
  }

  Future<void> clearAll() async {
    final box = await _persistence.box(_box);
    await box.clear();
  }

  CachePolicy _policyFromEntry(
    Map<String, Object?> entry, {
    required CachePolicy fallback,
  }) {
    final ttlMs = entry[_ttlKey] as int?;
    final staleMs = entry[_staleKey] as int?;
    if (ttlMs == null && staleMs == null) return fallback;
    return fallback.copyWith(
      ttl: ttlMs != null ? Duration(milliseconds: ttlMs) : null,
      staleGrace: staleMs != null ? Duration(milliseconds: staleMs) : null,
    );
  }

  List<String> _normalizeTags(List<String> tags) {
    final nonEmpty = tags.where((tag) => tag.isNotEmpty);
    return {...nonEmpty}.toList(growable: false);
  }

  List<String> _readTags(Map<String, Object?> entry) {
    final rawTags = entry[_tagsKey];
    if (rawTags is List) {
      return rawTags.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }
}

const _payloadKey = 'payload';
const _storedAtKey = 'storedAt';
const _ttlKey = 'ttlMs';
const _staleKey = 'staleMs';
const _tagsKey = 'tags';
