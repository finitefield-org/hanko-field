// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/library/data/models/design_share_link_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class DesignShareLinkRepository {
  Future<List<DesignShareLink>> listLinks(String designId);

  Future<DesignShareLink> createLink(String designId, {required Duration ttl});

  Future<DesignShareLink> extendLink(
    String designId,
    String linkId, {
    required Duration extendBy,
  });

  Future<void> revokeLink(String designId, String linkId);
}

final designShareLinkRepositoryProvider = Provider<DesignShareLinkRepository>((
  ref,
) {
  final cache = ref.watch(designsCacheProvider);
  final gates = ref.watch(appExperienceGatesProvider);
  final logger = Logger('DesignShareLinkRepository');
  return LocalDesignShareLinkRepository(
    cache: cache,
    personaKey: gates.personaKey,
    logger: logger,
  );
});

class LocalDesignShareLinkRepository implements DesignShareLinkRepository {
  LocalDesignShareLinkRepository({
    required LocalCacheStore<JsonMap> cache,
    required String personaKey,
    Logger? logger,
  }) : _cache = cache,
       _personaKey = personaKey,
       _logger = logger ?? Logger('LocalDesignShareLinkRepository');

  final LocalCacheStore<JsonMap> _cache;
  final String _personaKey;
  final Logger _logger;

  @override
  Future<List<DesignShareLink>> listLinks(String designId) async {
    final state = await _readOrSeed(designId);
    return state;
  }

  @override
  Future<DesignShareLink> createLink(
    String designId, {
    required Duration ttl,
  }) async {
    final current = await _readOrSeed(designId);
    final now = DateTime.now();
    final token = _randomToken(12);
    final link = DesignShareLink(
      id: 'sl_${now.millisecondsSinceEpoch}_$token',
      url: 'https://hanko.field/library/$designId?share=$token',
      createdAt: now,
      expiresAt: now.add(ttl),
      revokedAt: null,
      openCount: 0,
      lastOpenedAt: null,
    );

    final next = [link, ...current];
    await _write(designId, next);
    return link;
  }

  @override
  Future<DesignShareLink> extendLink(
    String designId,
    String linkId, {
    required Duration extendBy,
  }) async {
    final current = await _readOrSeed(designId);
    final index = current.indexWhere((link) => link.id == linkId);
    if (index < 0) throw StateError('Unknown share link id: $linkId');

    final now = DateTime.now();
    final link = current[index];
    final base = link.expiresAt == null || link.expiresAt!.isBefore(now)
        ? now
        : link.expiresAt!;
    final extended = link.copyWith(expiresAt: base.add(extendBy));

    final next = [...current];
    next[index] = extended;
    await _write(designId, next);
    return extended;
  }

  @override
  Future<void> revokeLink(String designId, String linkId) async {
    final current = await _readOrSeed(designId);
    final index = current.indexWhere((link) => link.id == linkId);
    if (index < 0) throw StateError('Unknown share link id: $linkId');

    final link = current[index];
    if (link.revokedAt != null) return;

    final revoked = link.copyWith(revokedAt: DateTime.now());
    final next = [...current];
    next[index] = revoked;
    await _write(designId, next);
  }

  Future<List<DesignShareLink>> _readOrSeed(String designId) async {
    final cacheKey = LocalCacheKeys.designShareLinks(
      designId: designId,
      persona: _personaKey,
    );

    try {
      final hit = await _cache.read(cacheKey.value);
      if (hit != null) {
        final raw = hit.value['links'];
        if (raw is List) {
          return raw
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => DesignShareLink.fromJson(Map<String, Object?>.from(e)),
              )
              .toList(growable: false);
        }
      }
    } catch (e, stack) {
      _logger.warning('Failed to read share links cache: $e', e, stack);
    }

    final seeded = _seedLinks(designId);
    await _write(designId, seeded);
    return seeded;
  }

  Future<void> _write(String designId, List<DesignShareLink> links) async {
    final cacheKey = LocalCacheKeys.designShareLinks(
      designId: designId,
      persona: _personaKey,
    );

    await _cache.write(cacheKey.value, {
      'links': links.map((e) => e.toJson()).toList(growable: false),
    }, tags: cacheKey.tags);
  }

  List<DesignShareLink> _seedLinks(String designId) {
    final now = DateTime.now();
    final rng = Random(_stableSeed(designId));

    String makeToken() => _randomToken(10, rng: rng);

    String makeId(String token) => 'sl_seed_${token}_${rng.nextInt(9999)}';

    String makeUrl(String token) =>
        'https://hanko.field/library/$designId?share=$token';

    final active = List<DesignShareLink>.generate(2, (i) {
      final token = makeToken();
      final createdAt = now.subtract(Duration(days: 1 + i * 2));
      final expiresAt = now.add(Duration(days: 3 + rng.nextInt(20)));
      final openCount = rng.nextInt(18);
      final lastOpenedAt = openCount == 0
          ? null
          : now.subtract(Duration(hours: 2 + rng.nextInt(40)));
      return DesignShareLink(
        id: makeId(token),
        url: makeUrl(token),
        createdAt: createdAt,
        expiresAt: expiresAt,
        revokedAt: null,
        openCount: openCount,
        lastOpenedAt: lastOpenedAt,
      );
    });

    final expired = List<DesignShareLink>.generate(3, (i) {
      final token = makeToken();
      final createdAt = now.subtract(Duration(days: 12 + i * 3));
      final expiresAt = now.subtract(Duration(days: 1 + i));
      final openCount = rng.nextInt(48);
      final lastOpenedAt = openCount == 0
          ? null
          : now.subtract(Duration(days: 2 + rng.nextInt(18)));
      return DesignShareLink(
        id: makeId(token),
        url: makeUrl(token),
        createdAt: createdAt,
        expiresAt: expiresAt,
        revokedAt: null,
        openCount: openCount,
        lastOpenedAt: lastOpenedAt,
      );
    });

    final revokedToken = makeToken();
    final revoked = DesignShareLink(
      id: makeId(revokedToken),
      url: makeUrl(revokedToken),
      createdAt: now.subtract(const Duration(days: 4)),
      expiresAt: now.add(const Duration(days: 3)),
      revokedAt: now.subtract(const Duration(hours: 8)),
      openCount: rng.nextInt(10),
      lastOpenedAt: null,
    );

    final merged = [...active, revoked, ...expired]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  int _stableSeed(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash;
  }

  String _randomToken(int length, {Random? rng}) {
    final random = rng ?? Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
