// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/designs/data/dtos/design_dtos.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum DesignSort { recent, aiScore, name }

abstract class DesignRepository {
  static const fallback = Scope<DesignRepository>.required('design.repository');

  Future<Page<Design>> listDesigns({
    DesignStatus? status,
    DesignSourceType? sourceType,
    String? query,
    DesignSort? sort,
    DateTime? updatedAfter,
    double? minAiScore,
    double? maxAiScore,
    String? pageToken,
  });

  Future<Design> getDesign(String designId);

  Future<Design> createDesign(Design design);

  Future<Design> updateDesign(Design design);

  Future<void> deleteDesign(String designId);

  Future<Design> duplicateDesign(String designId);

  Future<Page<DesignVersion>> listVersions(
    String designId, {
    String? pageToken,
  });

  Future<List<AiSuggestion>> listAiSuggestions(String designId);

  Future<AiSuggestion> getAiSuggestion(String designId, String suggestionId);

  Future<AiSuggestion> requestAiSuggestion(
    String designId, {
    required AiSuggestionMethod method,
    String? model,
  });

  Future<AiSuggestion> acceptSuggestion(String designId, String suggestionId);

  Future<AiSuggestion> rejectSuggestion(
    String designId,
    String suggestionId, {
    String? reason,
  });

  Future<void> runRegistrabilityCheck(String designId);
}

final designRepositoryProvider = Provider<DesignRepository>((ref) {
  final cache = ref.watch(designsCacheProvider);
  final gates = ref.watch(appExperienceGatesProvider);
  final logger = Logger('DesignRepository');

  return LocalDesignRepository(cache: cache, gates: gates, logger: logger);
});

class LocalDesignRepository implements DesignRepository {
  LocalDesignRepository({
    required LocalCacheStore<JsonMap> cache,
    required AppExperienceGates gates,
    Logger? logger,
  }) : _cache = cache,
       _gates = gates,
       _logger = logger ?? Logger('LocalDesignRepository');

  final LocalCacheStore<JsonMap> _cache;
  final AppExperienceGates _gates;
  final Logger _logger;
  final Random _rand = Random();

  static const int _pageSize = 18;

  bool _seeded = false;
  late List<Design> _designs;
  late final LocalCacheKey _cacheKey = LocalCacheKeys.designsList(
    persona: _gates.personaKey,
  );

  @override
  Future<Page<Design>> listDesigns({
    DesignStatus? status,
    DesignSourceType? sourceType,
    String? query,
    DesignSort? sort,
    DateTime? updatedAfter,
    double? minAiScore,
    double? maxAiScore,
    String? pageToken,
  }) async {
    await _ensureSeeded();
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final normalizedQuery = query?.trim();
    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;
    final qLower = hasQuery ? normalizedQuery.toLowerCase() : null;

    final filtered = _designs.where((design) {
      if (status != null && design.status != status) return false;
      if (sourceType != null && design.input?.sourceType != sourceType) {
        return false;
      }
      if (updatedAfter != null && design.updatedAt.isBefore(updatedAfter)) {
        return false;
      }
      if (minAiScore != null) {
        final score = design.ai?.qualityScore;
        if (score == null || score < minAiScore) return false;
      }
      if (maxAiScore != null) {
        final score = design.ai?.qualityScore;
        if (score != null && score > maxAiScore) return false;
      }
      if (qLower != null) {
        final name = design.input?.rawName.toLowerCase() ?? '';
        if (!name.contains(qLower)) return false;
      }
      return true;
    }).toList();

    _applySort(filtered, sort ?? DesignSort.recent);

    final start = int.tryParse(pageToken ?? '') ?? 0;
    final items = filtered.skip(start).take(_pageSize).toList();
    final next = start + items.length < filtered.length
        ? '${start + items.length}'
        : null;

    unawaited(_persistCache());

    return Page(items: items, nextPageToken: next);
  }

  @override
  Future<Design> getDesign(String designId) async {
    await _ensureSeeded();
    final found = _designs.firstWhereOrNull((design) => design.id == designId);
    if (found == null) throw StateError('Unknown design id: $designId');
    return found;
  }

  @override
  Future<Design> createDesign(Design design) async {
    await _ensureSeeded();
    final now = DateTime.now();
    final created = design.copyWith(
      id: design.id ?? _newId(),
      createdAt: design.createdAt,
      updatedAt: now,
    );
    _designs = [created, ..._designs];
    await _persistCache();
    return created;
  }

  @override
  Future<Design> updateDesign(Design design) async {
    await _ensureSeeded();
    final id = design.id;
    if (id == null) throw StateError('Cannot update a design without id');

    final index = _designs.indexWhere((d) => d.id == id);
    if (index < 0) throw StateError('Unknown design id: $id');

    final now = DateTime.now();
    final updated = design.copyWith(updatedAt: now);
    _designs[index] = updated;
    await _persistCache();
    return updated;
  }

  @override
  Future<void> deleteDesign(String designId) async {
    await _ensureSeeded();
    _designs.removeWhere((d) => d.id == designId);
    await _persistCache();
  }

  @override
  Future<Design> duplicateDesign(String designId) async {
    await _ensureSeeded();
    final source = await getDesign(designId);
    final now = DateTime.now();
    final duplicated = source.copyWith(
      id: _newId(),
      status: DesignStatus.draft,
      version: 1,
      createdAt: now,
      updatedAt: now,
      lastOrderedAt: null,
    );
    _designs = [duplicated, ..._designs];
    await _persistCache();
    return duplicated;
  }

  @override
  Future<Page<DesignVersion>> listVersions(
    String designId, {
    String? pageToken,
  }) {
    throw UnimplementedError('Design versions are not implemented yet.');
  }

  @override
  Future<List<AiSuggestion>> listAiSuggestions(String designId) {
    throw UnimplementedError('AI suggestions are not implemented yet.');
  }

  @override
  Future<AiSuggestion> getAiSuggestion(String designId, String suggestionId) {
    throw UnimplementedError('AI suggestions are not implemented yet.');
  }

  @override
  Future<AiSuggestion> requestAiSuggestion(
    String designId, {
    required AiSuggestionMethod method,
    String? model,
  }) {
    throw UnimplementedError('AI suggestions are not implemented yet.');
  }

  @override
  Future<AiSuggestion> acceptSuggestion(String designId, String suggestionId) {
    throw UnimplementedError('AI suggestions are not implemented yet.');
  }

  @override
  Future<AiSuggestion> rejectSuggestion(
    String designId,
    String suggestionId, {
    String? reason,
  }) {
    throw UnimplementedError('AI suggestions are not implemented yet.');
  }

  @override
  Future<void> runRegistrabilityCheck(String designId) {
    throw UnimplementedError('Registrability checks are not implemented yet.');
  }

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    final cached = await _cache.read(
      _cacheKey.value,
      policy: CachePolicies.designs,
    );
    if (cached != null) {
      _designs = _decodeDesigns(cached.value);
      if (_designs.isNotEmpty) {
        _seeded = true;
        return;
      }
    }

    _designs = _seedDesigns(_gates);
    _seeded = true;
    unawaited(_persistCache());
  }

  Future<void> _persistCache() async {
    try {
      await _cache.write(
        _cacheKey.value,
        <String, Object?>{
          'items': _designs.map(_encodeDesign).toList(),
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
        },
        policy: CachePolicies.designs,
        tags: _cacheKey.tags,
      );
    } catch (e, stack) {
      _logger.fine('Failed to persist designs cache', e, stack);
    }
  }

  JsonMap _encodeDesign(Design design) {
    final dto = DesignDto.fromDomain(design);
    final json = dto.toJson();
    final id = design.id;
    if (id != null) {
      json['id'] = id;
    }
    return json;
  }

  List<Design> _decodeDesigns(JsonMap map) {
    final raw = map['items'];
    if (raw is! List) return const <Design>[];
    return raw.whereType<Map<dynamic, dynamic>>().map((entry) {
      final typed = Map<String, Object?>.from(entry);
      final id = typed['id'] as String?;
      typed.remove('id');
      return DesignDto.fromJson(typed, id: id).toDomain();
    }).toList();
  }

  void _applySort(List<Design> designs, DesignSort sort) {
    switch (sort) {
      case DesignSort.recent:
        designs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case DesignSort.aiScore:
        designs.sort((a, b) {
          final aScore = a.ai?.qualityScore;
          final bScore = b.ai?.qualityScore;
          if (aScore == null && bScore == null) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (aScore == null) return 1;
          if (bScore == null) return -1;
          final cmp = bScore.compareTo(aScore);
          return cmp != 0 ? cmp : b.updatedAt.compareTo(a.updatedAt);
        });
      case DesignSort.name:
        designs.sort((a, b) {
          final aName = (a.input?.rawName ?? '').toLowerCase();
          final bName = (b.input?.rawName ?? '').toLowerCase();
          final cmp = aName.compareTo(bName);
          return cmp != 0 ? cmp : b.updatedAt.compareTo(a.updatedAt);
        });
    }
  }

  String _newId() =>
      'd_${DateTime.now().millisecondsSinceEpoch}_${_rand.nextInt(99999)}';

  List<Design> _seedDesigns(AppExperienceGates gates) {
    final now = DateTime.now();
    final prefersEnglish = gates.prefersEnglish;

    final names = prefersEnglish
        ? const [
            'Akiyama',
            'Mori',
            'Tanaka',
            'Sato',
            'Hayashi',
            'Suzuki',
            'Yamada',
            'Kato',
            'Ishikawa',
            'Nakamura',
            'Hanko Draft',
            'Office Seal',
            'Wedding Set',
          ]
        : const [
            '秋山',
            '森',
            '田中',
            '佐藤',
            '林',
            '鈴木',
            '山田',
            '加藤',
            '石川',
            '中村',
            '仮デザイン',
            '会社印',
            '結婚セット',
          ];

    final statuses = DesignStatus.values;
    final sources = DesignSourceType.values;
    final shapes = SealShape.values;
    final writings = WritingStyle.values;

    return List<Design>.generate(34, (index) {
      final createdAt = now.subtract(Duration(days: 55 - index, hours: index));
      final updatedAt = createdAt.add(Duration(days: index % 12, hours: index));
      final status = statuses[index % statuses.length];
      final name = names[index % names.length];
      final source = sources[index % sources.length];
      final hasKanji = gates.enableKanjiAssist && index.isEven;

      final aiScore = status == DesignStatus.draft
          ? null
          : (40 + _rand.nextInt(61)) / 100.0;

      return Design(
        id: 'seed_$index',
        ownerRef: gates.isAuthenticated ? 'user/current' : 'user/guest',
        status: status,
        input: DesignInput(
          sourceType: source,
          rawName: hasKanji
              ? '$name (${prefersEnglish ? 'kanji' : '漢字'})'
              : name,
          kanji: hasKanji
              ? const KanjiMapping(value: '印', mappingRef: 'seed')
              : null,
        ),
        shape: shapes[index % shapes.length],
        size: DesignSize(mm: [10.5, 12.0, 13.5, 15.0][index % 4]),
        style: DesignStyle(
          writing: writings[index % writings.length],
          fontRef: null,
          templateRef: null,
          stroke: StrokeConfig(
            weight: 0.4 + ((index % 5) * 0.1),
            contrast: 0.3 + ((index % 3) * 0.1),
          ),
          layout: LayoutConfig(
            grid: index.isEven ? '3x3' : 'none',
            margin: 2.0,
          ),
        ),
        ai: AiMetadata(
          enabled: aiScore != null,
          lastJobRef: aiScore != null ? 'job_$index' : null,
          qualityScore: aiScore,
          registrable: aiScore == null ? null : aiScore >= 0.7,
          diagnostics: const [],
        ),
        assets: DesignAssets(
          previewPngUrl: _previewImage(index),
          stampMockUrl: _stampMock(index),
        ),
        hash: 'hash_$index',
        version: 1 + (index % 4),
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastOrderedAt: status == DesignStatus.ordered
            ? updatedAt.add(const Duration(days: 2))
            : null,
      );
    });
  }

  String _previewImage(int index) {
    final id = 420 + (index % 40);
    return 'https://picsum.photos/id/$id/640/640';
  }

  String _stampMock(int index) {
    final id = 660 + (index % 40);
    return 'https://picsum.photos/id/$id/900/600';
  }
}
