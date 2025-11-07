import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/design_repository.dart';
import 'package:app/core/storage/cache_policy.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/library/domain/library_query_fields.dart';

class FakeDesignRepository extends DesignRepository {
  FakeDesignRepository({
    required OfflineCacheRepository cache,
    Duration latency = const Duration(milliseconds: 240),
    DateTime Function()? now,
  }) : _cache = cache,
       _latency = latency,
       _now = now ?? DateTime.now {
    final base = _now();
    _designs = _seedDesigns(base);
    _designs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _designsById = {
      for (final design in _designs) design.id.toUpperCase(): design,
    };
  }

  final OfflineCacheRepository _cache;
  final Duration _latency;
  final DateTime Function() _now;

  late final List<Design> _designs;
  late final Map<String, Design> _designsById;

  static const _defaultPageSize = 20;

  @override
  Future<List<Design>> fetchDesigns({
    int? pageSize,
    String? pageToken,
    Map<String, dynamic>? filters,
  }) async {
    await Future<void>.delayed(_latency);
    final limit = pageSize ?? _defaultPageSize;
    final normalizedFilters = Map<String, dynamic>.from(filters ?? const {});
    final cacheKey = _cacheKeyForFilters(normalizedFilters);

    List<Design> source;
    final cacheResult = await _cache.readDesignList(key: cacheKey);
    if (cacheResult.hasValue && cacheResult.value != null) {
      source = cacheResult.value!.items.map(mapDesign).toList();
      if (cacheResult.state == CacheState.stale) {
        source = await _refreshCache(normalizedFilters, cacheKey);
      }
    } else {
      source = await _refreshCache(normalizedFilters, cacheKey);
    }

    final startIndex = _startIndexForCursor(source, pageToken);
    return source.skip(startIndex).take(limit).toList(growable: false);
  }

  Future<List<Design>> _refreshCache(
    Map<String, dynamic> filters,
    String cacheKey,
  ) async {
    final filtered = _applyFilters(List<Design>.from(_designs), filters);
    await _cache.writeDesignList(
      CachedDesignList(
        items: filtered.map(mapDesignToDto).toList(growable: false),
        appliedFilters: filters.isEmpty ? null : Map.of(filters),
      ),
      key: cacheKey,
    );
    return filtered;
  }

  List<Design> _applyFilters(
    List<Design> source,
    Map<String, dynamic> filters,
  ) {
    var result = source;
    final statuses = _parseStatuses(filters[LibraryQueryFields.statuses]);
    if (statuses != null && statuses.isNotEmpty) {
      result = result
          .where((design) => statuses.contains(design.status))
          .toList();
    }

    final persona = _parsePersona(filters[LibraryQueryFields.persona]);
    if (persona != null) {
      result = result.where((design) => design.persona == persona).toList();
    }

    final dateRange = _parseDateRange(filters[LibraryQueryFields.dateRange]);
    if (dateRange != null) {
      final cutoff = _now().subtract(dateRange);
      result = result
          .where((design) => !design.updatedAt.isBefore(cutoff))
          .toList();
    }

    final aiThreshold = _parseAiFilter(filters[LibraryQueryFields.aiScore]);
    if (aiThreshold != null) {
      result = result
          .where(
            (design) =>
                (design.ai?.qualityScore ?? 0) >= aiThreshold.minimumScore,
          )
          .toList();
    }

    final query = (filters[LibraryQueryFields.search] as String?)?.trim();
    if (query != null && query.isNotEmpty) {
      final needle = query.toLowerCase();
      result = result.where((design) {
        final title = design.input?.rawName.toLowerCase() ?? '';
        final lastOrder = design.lastOrderedAt?.toIso8601String() ?? '';
        return title.contains(needle) ||
            design.id.toLowerCase().contains(needle) ||
            lastOrder.contains(needle);
      }).toList();
    }

    final sort = filters[LibraryQueryFields.sort] as String?;
    result.sort((a, b) => _compareDesigns(a, b, sort));
    return result;
  }

  int _compareDesigns(Design a, Design b, String? sort) {
    switch (sort) {
      case 'aiScore':
        final aScore = a.ai?.qualityScore ?? -1;
        final bScore = b.ai?.qualityScore ?? -1;
        final scoreCompare = bScore.compareTo(aScore);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      case 'name':
        final aName = a.input?.rawName.toLowerCase() ?? '';
        final bName = b.input?.rawName.toLowerCase() ?? '';
        final nameCompare = aName.compareTo(bName);
        if (nameCompare != 0) {
          return nameCompare;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      case 'recent':
      default:
        return b.updatedAt.compareTo(a.updatedAt);
    }
  }

  int _startIndexForCursor(List<Design> source, String? cursor) {
    if (cursor == null) {
      return 0;
    }
    final index = source.indexWhere((design) => design.id == cursor);
    if (index == -1) {
      return 0;
    }
    return index + 1;
  }

  static Set<DesignStatus>? _parseStatuses(Object? raw) {
    if (raw is List) {
      final statuses = <DesignStatus>{};
      for (final value in raw) {
        if (value is String) {
          for (final status in DesignStatus.values) {
            if (status.name == value) {
              statuses.add(status);
              break;
            }
          }
        }
      }
      return statuses;
    }
    return null;
  }

  UserPersona? _parsePersona(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      for (final persona in UserPersona.values) {
        if (persona.name == raw) {
          return persona;
        }
      }
    }
    return null;
  }

  Duration? _parseDateRange(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    switch (raw) {
      case 'last7Days':
        return const Duration(days: 7);
      case 'last30Days':
        return const Duration(days: 30);
      case 'last90Days':
        return const Duration(days: 90);
      default:
        return null;
    }
  }

  _AiThreshold? _parseAiFilter(Object? raw) {
    if (raw is! String || raw.isEmpty || raw == 'all') {
      return null;
    }
    switch (raw) {
      case 'high':
        return const _AiThreshold(minimumScore: 80);
      case 'medium':
        return const _AiThreshold(minimumScore: 60);
      case 'low':
        return const _AiThreshold(minimumScore: 40);
    }
    return null;
  }

  String _cacheKeyForFilters(Map<String, dynamic> filters) {
    if (filters.isEmpty) {
      return 'library-default';
    }
    final entries = filters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer('library');
    for (final entry in entries) {
      buffer
        ..write('|')
        ..write(entry.key)
        ..write(':')
        ..write(_serializeFilterValue(entry.value));
    }
    return buffer.toString();
  }

  String _serializeFilterValue(Object? value) {
    if (value is Iterable) {
      return value.map(_serializeFilterValue).join(',');
    }
    return value?.toString() ?? 'null';
  }

  @override
  Future<Design> fetchDesign(String designId) async {
    await Future<void>.delayed(_latency);
    final normalized = designId.toUpperCase();
    final existing = _designsById[normalized];
    if (existing == null) {
      throw StateError('Design $designId not found');
    }
    return existing;
  }

  @override
  Future<Design> createDesign(Design design) async {
    await Future<void>.delayed(_latency);
    _designs.add(design);
    _designsById[design.id.toUpperCase()] = design;
    return design;
  }

  @override
  Future<Design> updateDesign(Design design) async {
    await Future<void>.delayed(_latency);
    final index = _designs.indexWhere((item) => item.id == design.id);
    if (index != -1) {
      _designs[index] = design;
    }
    _designsById[design.id.toUpperCase()] = design;
    return design;
  }

  @override
  Future<void> deleteDesign(String designId) async {
    await Future<void>.delayed(_latency);
    final normalized = designId.toUpperCase();
    _designs.removeWhere((design) => design.id.toUpperCase() == normalized);
    _designsById.remove(normalized);
  }

  @override
  Future<List<Design>> fetchVersions(String designId) async {
    await Future<void>.delayed(_latency);
    final existing = await fetchDesign(designId);
    return List<Design>.generate(3, (index) {
      final versionNumber = existing.version - index;
      return existing.copyWith(
        version: versionNumber,
        updatedAt: existing.updatedAt.subtract(Duration(days: index * 2)),
      );
    });
  }

  @override
  Future<Design> duplicateDesign(
    String designId, {
    String? name,
    List<String> tags = const [],
    bool copyHistory = true,
    bool copyAssets = true,
  }) async {
    await Future<void>.delayed(_latency);
    final existing = await fetchDesign(designId);
    final duplicateId = '${existing.id}-COPY-${_now().millisecondsSinceEpoch}';
    final nextName = (name ?? existing.input?.rawName)?.trim();
    final duplicateTags = tags.isEmpty
        ? existing.tags
        : List<String>.from(tags);
    final duplicate = existing.copyWith(
      id: duplicateId,
      version: 1,
      status: DesignStatus.draft,
      createdAt: _now(),
      updatedAt: _now(),
      input: nextName == null
          ? existing.input
          : (existing.input ??
                    DesignInput(
                      sourceType: DesignSourceType.typed,
                      rawName: nextName,
                    ))
                .copyWith(rawName: nextName),
      tags: duplicateTags,
      ai: copyHistory ? existing.ai : null,
      assets: copyAssets ? existing.assets : null,
      lastOrderedAt: copyHistory ? existing.lastOrderedAt : null,
    );
    await createDesign(duplicate);
    return duplicate;
  }

  @override
  Future<void> requestAiSuggestions(
    String designId,
    Map<String, dynamic> payload,
  ) async {
    await Future<void>.delayed(_latency);
  }

  List<Design> _seedDesigns(DateTime anchor) {
    final base = anchor.subtract(const Duration(days: 1));
    return [
      _buildDesign(
        id: 'JP-INK-01',
        rawName: '山田 太郎',
        status: DesignStatus.ready,
        updatedAt: base,
        createdAt: base.subtract(const Duration(days: 4)),
        qualityScore: 92,
        persona: UserPersona.japanese,
        sourceType: DesignSourceType.typed,
        stampUrl:
            'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=600',
        lastOrderedAt: base.subtract(const Duration(days: 2)),
      ),
      _buildDesign(
        id: 'JP-INK-02',
        rawName: 'Haruka Trading',
        status: DesignStatus.draft,
        updatedAt: base.subtract(const Duration(days: 2)),
        createdAt: base.subtract(const Duration(days: 5)),
        qualityScore: 67,
        persona: UserPersona.foreigner,
        sourceType: DesignSourceType.logo,
        stampUrl:
            'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-03',
        rawName: '鈴木 花子',
        status: DesignStatus.ordered,
        updatedAt: base.subtract(const Duration(days: 3)),
        createdAt: base.subtract(const Duration(days: 15)),
        qualityScore: 84,
        persona: UserPersona.japanese,
        sourceType: DesignSourceType.typed,
        stampUrl:
            'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600',
        lastOrderedAt: base.subtract(const Duration(days: 1)),
      ),
      _buildDesign(
        id: 'JP-INK-04',
        rawName: 'Atlas Robotics',
        status: DesignStatus.ready,
        updatedAt: base.subtract(const Duration(days: 6)),
        createdAt: base.subtract(const Duration(days: 40)),
        qualityScore: 58,
        persona: UserPersona.foreigner,
        sourceType: DesignSourceType.uploaded,
        stampUrl:
            'https://images.unsplash.com/photo-1469478715127-803f98a2ed9c?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-05',
        rawName: 'ことばスタジオ',
        status: DesignStatus.ready,
        updatedAt: base.subtract(const Duration(days: 8)),
        createdAt: base.subtract(const Duration(days: 60)),
        qualityScore: 76,
        persona: UserPersona.japanese,
        sourceType: DesignSourceType.typed,
        stampUrl:
            'https://images.unsplash.com/photo-1500336624523-d727130c3328?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-06',
        rawName: 'Blue Crane LLC',
        status: DesignStatus.locked,
        updatedAt: base.subtract(const Duration(days: 10)),
        createdAt: base.subtract(const Duration(days: 95)),
        qualityScore: 45,
        persona: UserPersona.foreigner,
        sourceType: DesignSourceType.logo,
        stampUrl:
            'https://images.unsplash.com/photo-1436397543931-01c4a5162b5d?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-07',
        rawName: '加藤 工房',
        status: DesignStatus.draft,
        updatedAt: base.subtract(const Duration(days: 12)),
        createdAt: base.subtract(const Duration(days: 120)),
        qualityScore: 33,
        persona: UserPersona.japanese,
        sourceType: DesignSourceType.uploaded,
        stampUrl:
            'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-08',
        rawName: 'Nexus Research',
        status: DesignStatus.ready,
        updatedAt: base.subtract(const Duration(days: 14)),
        createdAt: base.subtract(const Duration(days: 180)),
        qualityScore: 88,
        persona: UserPersona.foreigner,
        sourceType: DesignSourceType.typed,
        stampUrl:
            'https://images.unsplash.com/photo-1469479035560-0e9692b692de?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-09',
        rawName: '星野 結衣',
        status: DesignStatus.ordered,
        updatedAt: base.subtract(const Duration(days: 18)),
        createdAt: base.subtract(const Duration(days: 210)),
        qualityScore: 71,
        persona: UserPersona.japanese,
        sourceType: DesignSourceType.typed,
        stampUrl:
            'https://images.unsplash.com/photo-1455849318743-b2233052fcff?w=600',
        lastOrderedAt: base.subtract(const Duration(days: 5)),
      ),
      _buildDesign(
        id: 'JP-INK-10',
        rawName: 'Aurora Legal',
        status: DesignStatus.ready,
        updatedAt: base.subtract(const Duration(days: 22)),
        createdAt: base.subtract(const Duration(days: 260)),
        qualityScore: 81,
        persona: UserPersona.foreigner,
        sourceType: DesignSourceType.typed,
        stampUrl:
            'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-11',
        rawName: '古賀 美咲',
        status: DesignStatus.ready,
        updatedAt: base.subtract(const Duration(days: 24)),
        createdAt: base.subtract(const Duration(days: 300)),
        qualityScore: 95,
        persona: UserPersona.japanese,
        sourceType: DesignSourceType.typed,
        stampUrl:
            'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600',
      ),
      _buildDesign(
        id: 'JP-INK-12',
        rawName: 'Summit Export',
        status: DesignStatus.ready,
        updatedAt: base.subtract(const Duration(days: 30)),
        createdAt: base.subtract(const Duration(days: 360)),
        qualityScore: 62,
        persona: UserPersona.foreigner,
        sourceType: DesignSourceType.uploaded,
        stampUrl:
            'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=600',
      ),
    ];
  }

  Design _buildDesign({
    required String id,
    required String rawName,
    required DesignStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    required double qualityScore,
    required UserPersona persona,
    required DesignSourceType sourceType,
    required String stampUrl,
    DateTime? lastOrderedAt,
  }) {
    return Design(
      id: id,
      ownerRef: 'user-001',
      status: status,
      shape: DesignShape.round,
      size: const DesignSize(mm: 18),
      style: const DesignStyle(writing: DesignWritingStyle.tensho),
      version: 3,
      createdAt: createdAt,
      updatedAt: updatedAt,
      persona: persona,
      input: DesignInput(sourceType: sourceType, rawName: rawName),
      ai: DesignAiMetadata(
        enabled: true,
        qualityScore: qualityScore,
        registrable: qualityScore >= 60,
        diagnostics: qualityScore >= 60
            ? const ['Balanced stroke contrast']
            : const ['Needs clearer margins'],
      ),
      assets: DesignAssets(previewPngUrl: stampUrl, stampMockUrl: stampUrl),
      hash: '$id-${updatedAt.millisecondsSinceEpoch}',
      lastOrderedAt: lastOrderedAt,
      tags: [persona.name, status.name, sourceType.name],
    );
  }
}

class _AiThreshold {
  const _AiThreshold({required this.minimumScore});

  final double minimumScore;
}
