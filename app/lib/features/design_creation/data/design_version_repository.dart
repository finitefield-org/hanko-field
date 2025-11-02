import 'dart:async';

import 'package:app/core/domain/entities/design.dart';

/// Temporary repository that simulates design version history interactions.
class DesignVersionRepository {
  DesignVersionRepository() {
    _ensureSeeded();
  }

  final Map<String, List<DesignVersion>> _versionsByDesign =
      <String, List<DesignVersion>>{};

  Future<List<DesignVersion>> fetchVersionHistory(String designId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _ensureSeeded();
    final entries = _versionsByDesign[designId];
    if (entries == null) {
      return const <DesignVersion>[];
    }
    return List<DesignVersion>.unmodifiable(entries);
  }

  Future<DesignVersion> rollbackToVersion({
    required String designId,
    required int version,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final entries = _versionsByDesign[designId];
    if (entries == null || entries.isEmpty) {
      throw StateError('No versions found for design $designId');
    }
    final target = entries.firstWhere(
      (entry) => entry.version == version,
      orElse: () {
        throw ArgumentError.value(
          version,
          'version',
          'Version not found for design $designId',
        );
      },
    );
    final latest = entries.first;
    final now = DateTime.now();
    final restoredSnapshot = target.snapshot.copyWith(
      version: latest.snapshot.version + 1,
      updatedAt: now,
      createdAt: target.snapshot.createdAt,
    );
    final restored = DesignVersion(
      version: restoredSnapshot.version,
      snapshot: restoredSnapshot,
      createdAt: now,
      createdBy: 'user-rollback',
      changeNote: 'Restored from v${target.version}',
    );
    _versionsByDesign[designId] = <DesignVersion>[restored, ...entries];
    return restored;
  }

  Future<Design> duplicateVersion({
    required String designId,
    required int version,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final entries = _versionsByDesign[designId];
    if (entries == null || entries.isEmpty) {
      throw StateError('No versions found for design $designId');
    }
    final target = entries.firstWhere(
      (entry) => entry.version == version,
      orElse: () {
        throw ArgumentError.value(
          version,
          'version',
          'Version not found for design $designId',
        );
      },
    );
    final now = DateTime.now();
    return target.snapshot.copyWith(
      id: '${target.snapshot.id}-copy-${now.millisecondsSinceEpoch}',
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _ensureSeeded() {
    if (_versionsByDesign.isNotEmpty) {
      return;
    }
    final baseCreatedAt = DateTime.now().subtract(const Duration(days: 4));
    const owner = 'user-123';
    const designId = 'design-draft-primary';
    _versionsByDesign[designId] = <DesignVersion>[
      DesignVersion(
        version: 4,
        snapshot: _buildSnapshot(
          id: designId,
          version: 4,
          ownerRef: owner,
          createdAt: baseCreatedAt,
          updatedAt: baseCreatedAt.add(const Duration(days: 3, hours: 5)),
          layoutMargin: 5.0,
          layoutRotation: 6,
          strokeWeight: 3.2,
        ),
        createdAt: baseCreatedAt.add(const Duration(days: 3, hours: 5)),
        createdBy: owner,
        changeNote: 'Updated styling after feedback.',
      ),
      DesignVersion(
        version: 3,
        snapshot: _buildSnapshot(
          id: designId,
          version: 3,
          ownerRef: owner,
          createdAt: baseCreatedAt,
          updatedAt: baseCreatedAt.add(const Duration(days: 2, hours: 8)),
          templateRef: 'tpl_tensho_origin_round',
          fontRef: 'jp_tensho_classic',
          strokeWeight: 3.0,
          layoutMargin: 4.0,
        ),
        createdAt: baseCreatedAt.add(const Duration(days: 2, hours: 8)),
        createdBy: owner,
        changeNote: 'Switched to Tensho template and refined stroke.',
      ),
      DesignVersion(
        version: 2,
        snapshot: _buildSnapshot(
          id: designId,
          version: 2,
          ownerRef: owner,
          createdAt: baseCreatedAt,
          updatedAt: baseCreatedAt.add(const Duration(days: 1, hours: 6)),
          shape: DesignShape.square,
          templateRef: 'tpl_reisho_modern_square',
          fontRef: 'jp_reisho_fine',
          strokeWeight: 2.6,
        ),
        createdAt: baseCreatedAt.add(const Duration(days: 1, hours: 6)),
        createdBy: owner,
        changeNote: 'Experimented with square layout.',
      ),
      DesignVersion(
        version: 1,
        snapshot: _buildSnapshot(
          id: designId,
          version: 1,
          ownerRef: owner,
          createdAt: baseCreatedAt,
          updatedAt: baseCreatedAt.add(const Duration(hours: 16)),
          templateRef: 'tpl_gyosho_flow_round',
          fontRef: 'jp_kana_flow',
          strokeWeight: 2.4,
          layoutMargin: 7.0,
        ),
        createdAt: baseCreatedAt.add(const Duration(hours: 16)),
        createdBy: owner,
        changeNote: 'Initial guided setup output.',
      ),
    ];
  }
}

Design _buildSnapshot({
  required String id,
  required int version,
  required String ownerRef,
  required DateTime createdAt,
  required DateTime updatedAt,
  DesignShape shape = DesignShape.round,
  String? templateRef,
  String? fontRef,
  double strokeWeight = 2.5,
  double layoutMargin = 6.0,
  double layoutRotation = 0.0,
}) {
  return Design(
    id: id,
    ownerRef: ownerRef,
    status: DesignStatus.draft,
    shape: shape,
    size: const DesignSize(mm: 18),
    style: DesignStyle(
      writing: DesignWritingStyle.tensho,
      fontRef: fontRef ?? 'jp_tensho_classic',
      templateRef: templateRef ?? 'tpl_tensho_origin_round',
      stroke: DesignStroke(weight: strokeWeight, contrast: 0.8),
      layout: DesignLayout(
        grid: 'square',
        margin: layoutMargin,
        alignment: DesignCanvasAlignment.center,
        rotation: layoutRotation,
      ),
    ),
    version: version,
    createdAt: createdAt,
    updatedAt: updatedAt,
    input: const DesignInput(
      sourceType: DesignSourceType.typed,
      rawName: '田中 太郎',
      kanji: DesignKanjiMapping(value: '田中太郎'),
    ),
    ai: const DesignAiMetadata(
      enabled: true,
      lastJobRef: 'ai-job-123',
      qualityScore: 0.82,
      registrable: true,
      diagnostics: ['balance:0.76', 'contrast:0.88'],
    ),
    assets: const DesignAssets(
      previewPngUrl:
          'https://images.unsplash.com/photo-1503602642458-232111445657?w=640&auto=format&fit=crop',
      stampMockUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=640&auto=format&fit=crop',
    ),
    hash: 'hash-$version',
    lastOrderedAt: null,
  );
}
