// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/data/repositories/design_repository.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum VersionChangeKind { layout, stroke, writing, template, metadata, size }

class VersionChange {
  const VersionChange({
    required this.label,
    required this.before,
    required this.after,
    required this.kind,
  });

  final String label;
  final String before;
  final String after;
  final VersionChangeKind kind;
}

class VersionDiff {
  const VersionDiff({
    required this.base,
    required this.target,
    required this.changes,
    required this.similarity,
    required this.summary,
  });

  final DesignVersion base;
  final DesignVersion target;
  final List<VersionChange> changes;
  final double similarity;
  final String summary;
}

enum VersionAuditLevel { info, success, warning }

class VersionAuditEntry {
  const VersionAuditEntry({
    required this.title,
    required this.detail,
    required this.actor,
    required this.level,
    required this.timestamp,
  });

  final String title;
  final String detail;
  final String actor;
  final VersionAuditLevel level;
  final DateTime timestamp;
}

class DesignVersionsState {
  const DesignVersionsState({
    required this.designId,
    required this.versions,
    required this.focusVersionId,
    required this.diff,
    required this.auditTrail,
    required this.isRollingBack,
    required this.isDuplicating,
    required this.feedbackId,
    this.feedbackMessage,
  });

  final String designId;
  final List<DesignVersion> versions;
  final String focusVersionId;
  final VersionDiff? diff;
  final List<VersionAuditEntry> auditTrail;
  final bool isRollingBack;
  final bool isDuplicating;
  final int feedbackId;
  final String? feedbackMessage;

  DesignVersion get current => versions.first;

  DesignVersion? get focused => versions.firstWhereOrNull(
    (version) =>
        version.id == focusVersionId || 'v${version.version}' == focusVersionId,
  );

  DesignVersionsState copyWith({
    String? designId,
    List<DesignVersion>? versions,
    String? focusVersionId,
    VersionDiff? diff,
    List<VersionAuditEntry>? auditTrail,
    bool? isRollingBack,
    bool? isDuplicating,
    int? feedbackId,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return DesignVersionsState(
      designId: designId ?? this.designId,
      versions: versions ?? List<DesignVersion>.from(this.versions),
      focusVersionId: focusVersionId ?? this.focusVersionId,
      diff: diff ?? this.diff,
      auditTrail: auditTrail ?? List<VersionAuditEntry>.from(this.auditTrail),
      isRollingBack: isRollingBack ?? this.isRollingBack,
      isDuplicating: isDuplicating ?? this.isDuplicating,
      feedbackId: feedbackId ?? this.feedbackId,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
    );
  }
}

class DesignVersionsViewModel extends AsyncProvider<DesignVersionsState> {
  DesignVersionsViewModel({this.designId})
    : super.args(
        designId == null ? null : (designId,),
        autoDispose: designId != null,
      );

  final String? designId;

  late final selectVersionMut = mutation<String>(#selectVersion);
  late final rollbackMut = mutation<DesignVersion?>(#rollback);
  late final duplicateMut = mutation<DesignVersion?>(#duplicate);
  late final refreshMut = mutation<DesignVersionsState>(#refresh);

  late _DesignVersionService _service;
  late AppExperienceGates _gates;
  late AnalyticsClient _analytics;
  final _logger = Logger('DesignVersionsViewModel');

  @override
  Future<DesignVersionsState> build(Ref<AsyncValue<DesignVersionsState>> ref) =>
      _hydrate(ref);

  Call<String, AsyncValue<DesignVersionsState>> selectVersion(
    String versionId,
  ) => mutate(selectVersionMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return versionId;

    final target = current.versions.firstWhereOrNull(
      (v) => _service.versionId(v) == versionId,
    );
    if (target == null) return versionId;

    final diff = _service.diff(current.current, target);
    ref.state = AsyncData(
      current.copyWith(
        focusVersionId: versionId,
        diff: diff,
        feedbackMessage: _gates.prefersEnglish
            ? 'Comparing with v${target.version}'
            : 'v${target.version} と比較中',
        feedbackId: current.feedbackId + 1,
      ),
    );
    return versionId;
  });

  Call<DesignVersion?, AsyncValue<DesignVersionsState>> rollback(
    String versionId,
  ) => mutate(rollbackMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return null;

    final target = current.versions.firstWhereOrNull(
      (v) => _service.versionId(v) == versionId,
    );
    if (target == null) return null;

    final previousCurrent = current.current;
    ref.state = AsyncData(
      current.copyWith(isRollingBack: true, clearFeedback: true),
    );

    try {
      final restored = await _service.rollback(
        designId: current.designId,
        current: previousCurrent,
        target: target,
      );
      await _analytics.track(
        DesignVersionRolledBackEvent(
          designId: current.designId,
          toVersion: restored.version,
          fromVersion: previousCurrent.version,
          reason: _service.versionId(target),
        ),
      );

      final updatedTimeline = [restored, ...current.versions];
      final auditEntry = _service.auditForRollback(
        from: previousCurrent,
        to: restored,
      );
      final nextFocusId = _service.versionId(previousCurrent);
      final diff = _service.diff(restored, previousCurrent);

      ref.state = AsyncData(
        current.copyWith(
          versions: updatedTimeline,
          focusVersionId: nextFocusId,
          diff: diff,
          isRollingBack: false,
          feedbackMessage: _gates.prefersEnglish
              ? 'Restored version v${target.version}'
              : 'v${target.version} を復元しました',
          feedbackId: current.feedbackId + 1,
          auditTrail: [auditEntry, ...current.auditTrail],
        ),
      );
      return restored;
    } catch (e, stack) {
      _logger.warning('Rollback failed', e, stack);
      ref.state = AsyncData(
        current.copyWith(
          isRollingBack: false,
          feedbackMessage: e.toString(),
          feedbackId: current.feedbackId + 1,
        ),
      );
      return null;
    }
  }, concurrency: Concurrency.dropLatest);

  Call<DesignVersion?, AsyncValue<DesignVersionsState>> duplicate(
    String versionId,
  ) => mutate(duplicateMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return null;
    final source = current.versions.firstWhereOrNull(
      (v) => _service.versionId(v) == versionId,
    );
    if (source == null) return null;

    ref.state = AsyncData(
      current.copyWith(isDuplicating: true, clearFeedback: true),
    );

    final duplicate = _service.duplicateFrom(
      source,
      nextVersion: current.current.version + 1,
    );
    final audit = VersionAuditEntry(
      title: _gates.prefersEnglish ? 'Duplicated version' : 'バージョンを複製',
      detail: _gates.prefersEnglish
          ? 'v${source.version} duplicated as draft'
          : 'v${source.version} をドラフトとして複製しました',
      actor: _gates.prefersEnglish ? 'You' : '自分',
      level: VersionAuditLevel.info,
      timestamp: DateTime.now(),
    );

    ref.state = AsyncData(
      current.copyWith(
        versions: [duplicate, ...current.versions],
        focusVersionId: _service.versionId(source),
        diff: _service.diff(duplicate, source),
        isDuplicating: false,
        feedbackMessage: _gates.prefersEnglish
            ? 'Drafted from v${source.version}'
            : 'v${source.version} を下書きにしました',
        feedbackId: current.feedbackId + 1,
        auditTrail: [audit, ...current.auditTrail],
      ),
    );
    return duplicate;
  }, concurrency: Concurrency.dropLatest);

  Call<DesignVersionsState, AsyncValue<DesignVersionsState>> refresh() =>
      mutate(refreshMut, (ref) async {
        final refreshed = await _hydrate(ref);
        ref.state = AsyncData(refreshed);
        return refreshed;
      }, concurrency: Concurrency.restart);

  Future<DesignVersionsState> _hydrate(
    Ref<AsyncValue<DesignVersionsState>> ref,
  ) async {
    _gates = ref.watch(appExperienceGatesProvider);
    _analytics = ref.watch(analyticsClientProvider);
    _service = _DesignVersionService(gates: _gates, logger: _logger);

    final repository = ref.watch(designRepositoryProvider);
    final creation = ref.watch(designCreationViewModel).valueOrNull;
    final editor = ref.watch(designEditorViewModel).valueOrNull;
    final session = ref.watch(userSessionProvider).valueOrNull;
    final resolvedDesignId = designId;

    final currentDesign = resolvedDesignId == null
        ? _service.buildSnapshot(
            designId: _service.resolveDesignId(creation),
            creation: creation,
            editor: editor,
            ownerRef: session?.user?.uid,
          )
        : await repository.getDesign(resolvedDesignId);

    final versions = _service.seedVersions(currentDesign);
    final focus = versions.length > 1
        ? _service.versionId(versions[1])
        : _service.versionId(versions.first);
    final diff = versions.length > 1
        ? _service.diff(versions.first, versions[1])
        : _service.diff(versions.first, versions.first);

    return DesignVersionsState(
      designId: currentDesign.id ?? (resolvedDesignId ?? 'design-current'),
      versions: versions,
      focusVersionId: focus,
      diff: diff,
      auditTrail: _service.seedAudit(versions),
      isRollingBack: false,
      isDuplicating: false,
      feedbackId: 0,
      feedbackMessage: null,
    );
  }
}

final designVersionsViewModel = DesignVersionsViewModel();

class _DesignVersionService {
  _DesignVersionService({required this.gates, Logger? logger})
    : _logger = logger ?? Logger('_DesignVersionService');

  final AppExperienceGates gates;
  final Logger _logger;

  String resolveDesignId(DesignCreationState? creation) {
    final raw = creation?.savedInput?.rawName;
    if (raw != null && raw.trim().isNotEmpty) {
      return 'design-${raw.trim().toLowerCase().hashCode}';
    }
    return 'design-current';
  }

  Design buildSnapshot({
    required String designId,
    required DesignCreationState? creation,
    required DesignEditorState? editor,
    String? ownerRef,
  }) {
    final prefersEnglish = gates.prefersEnglish;
    final rawName = creation?.savedInput?.rawName.trim();
    final fallbackName =
        creation?.nameDraft.fullName(prefersEnglish: prefersEnglish) ??
        (prefersEnglish ? 'Taro Yamada' : '山田太郎');

    final writing =
        editor?.writingStyle ??
        creation?.selectedStyle?.writing ??
        creation?.previewStyle ??
        WritingStyle.tensho;
    final shape = editor?.shape ?? creation?.selectedShape ?? SealShape.round;
    final size = editor?.sizeMm ?? creation?.selectedSize?.mm ?? 15.0;
    final stroke =
        editor?.strokeWeight ?? creation?.selectedStyle?.stroke?.weight ?? 2.4;
    final margin =
        editor?.margin ?? creation?.selectedStyle?.layout?.margin ?? 12.0;
    final layout = editor?.layout ?? DesignCanvasLayout.balanced;
    final grid =
        creation?.selectedStyle?.layout?.grid ??
        switch (layout) {
          DesignCanvasLayout.grid => 'grid',
          DesignCanvasLayout.vertical => 'vertical',
          DesignCanvasLayout.arc => 'arc',
          _ => 'balanced',
        };
    final templateRef =
        creation?.selectedTemplate?.id ?? creation?.selectedStyle?.templateRef;

    final now = DateTime.now();
    final versionSeed = 200 + (designId.hashCode % 12);

    return Design(
      id: designId,
      ownerRef: ownerRef,
      status: DesignStatus.ready,
      input: DesignInput(
        sourceType: creation?.selectedType ?? DesignSourceType.typed,
        rawName: rawName?.isNotEmpty == true ? rawName! : fallbackName,
        kanji: creation?.nameDraft.kanjiMapping,
      ),
      shape: shape,
      size: DesignSize(mm: size),
      style: DesignStyle(
        writing: writing,
        fontRef: creation?.selectedStyle?.fontRef,
        templateRef: templateRef,
        stroke: StrokeConfig(weight: stroke, contrast: 0.42),
        layout: LayoutConfig(grid: grid, margin: margin),
      ),
      ai: creation?.selectedStyle?.stroke?.contrast != null
          ? AiMetadata(
              enabled: true,
              lastJobRef: 'ai-balance',
              qualityScore: 0.82,
              registrable: gates.enableRegistrabilityCheck,
              diagnostics: const ['balanced'],
            )
          : null,
      assets: const DesignAssets(
        previewPngUrl:
            'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?auto=format&fit=crop&w=600&q=60',
      ),
      hash: 'h-$designId-${now.millisecondsSinceEpoch}',
      version: versionSeed,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
      lastOrderedAt: now.subtract(const Duration(days: 1, hours: 4)),
    );
  }

  List<DesignVersion> seedVersions(Design current) {
    final now = DateTime.now();
    final baseVersion = current.version;
    final prefersEnglish = gates.prefersEnglish;
    final timeline = <DesignVersion>[
      DesignVersion(
        id: 'ver-$baseVersion',
        version: baseVersion,
        snapshot: current,
        createdBy: prefersEnglish ? 'You' : '自分',
        createdAt: now.subtract(const Duration(minutes: 4)),
        changeNote: prefersEnglish
            ? 'Autosaved after grid tweak'
            : 'グリッド調整後に自動保存',
      ),
    ];

    final seeds = [
      (
        deltaMargin: 0.8,
        deltaStroke: -0.2,
        writing: WritingStyle.kaisho,
        template: current.style.templateRef ?? 'kit-free',
        note: prefersEnglish ? 'Adjusted for invoices' : '領収書用に調整',
        hoursAgo: 5,
      ),
      (
        deltaMargin: -1.2,
        deltaStroke: 0.4,
        writing: WritingStyle.tensho,
        template: 'ai-balance',
        note: prefersEnglish ? 'AI balance applied' : 'AIバランスを適用',
        hoursAgo: 14,
      ),
      (
        deltaMargin: 1.5,
        deltaStroke: 0.0,
        writing: WritingStyle.reisho,
        template: 'classic-reisho',
        note: prefersEnglish ? 'Switched to clerical' : '隷書体に変更',
        hoursAgo: 26,
      ),
      (
        deltaMargin: -0.6,
        deltaStroke: -0.3,
        writing: WritingStyle.gyosho,
        template: 'flow-gyo',
        note: prefersEnglish ? 'Flowing strokes' : '流れる筆致に変更',
        hoursAgo: 48,
      ),
    ];

    for (var i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      final version = baseVersion - (i + 1);
      if (version < 1) break;
      final snapshot = current.copyWith(
        version: version,
        style: current.style.copyWith(
          writing: seed.writing,
          templateRef: seed.template,
          stroke: StrokeConfig(
            weight: ((current.style.stroke?.weight ?? 2.4) + seed.deltaStroke)
                .clamp(1.4, 3.6),
            contrast: current.style.stroke?.contrast ?? 0.38,
          ),
          layout:
              current.style.layout?.copyWith(
                margin:
                    ((current.style.layout?.margin ?? 12) + seed.deltaMargin)
                        .clamp(8.0, 20.0),
              ) ??
              LayoutConfig(margin: 12 + seed.deltaMargin),
        ),
        updatedAt: now.subtract(Duration(hours: seed.hoursAgo)),
      );

      timeline.add(
        DesignVersion(
          id: 'ver-$version',
          version: version,
          snapshot: snapshot,
          createdBy: prefersEnglish ? 'You' : '自分',
          createdAt: now.subtract(Duration(hours: seed.hoursAgo)),
          changeNote: seed.note,
        ),
      );
    }

    return timeline;
  }

  List<VersionAuditEntry> seedAudit(List<DesignVersion> versions) {
    final prefersEnglish = gates.prefersEnglish;
    if (versions.isEmpty) return const [];
    final now = DateTime.now();

    return [
      VersionAuditEntry(
        title: prefersEnglish ? 'Autosave' : '自動保存',
        detail: prefersEnglish
            ? 'v${versions.first.version} captured before AI tweaks'
            : 'AI調整前に v${versions.first.version} を保存',
        actor: prefersEnglish ? 'System' : 'システム',
        level: VersionAuditLevel.info,
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
      VersionAuditEntry(
        title: prefersEnglish ? 'Shared preview' : 'プレビュー共有',
        detail: prefersEnglish
            ? 'Shared v${versions.length > 1 ? versions[1].version : versions.first.version} with client'
            : 'v${versions.length > 1 ? versions[1].version : versions.first.version} を共有しました',
        actor: prefersEnglish ? 'You' : '自分',
        level: VersionAuditLevel.success,
        timestamp: now.subtract(const Duration(hours: 12)),
      ),
    ];
  }

  VersionDiff diff(DesignVersion base, DesignVersion target) {
    final changes = _diffFields(base.snapshot, target.snapshot);
    const totalFields = 8;
    final similarity = 1 - (changes.length / totalFields);
    final summary = changes.isEmpty
        ? (gates.prefersEnglish ? 'No visible differences' : '差分はありません')
        : changes.map((c) => c.label).take(3).join(' • ');

    return VersionDiff(
      base: base,
      target: target,
      changes: changes,
      similarity: similarity.clamp(0, 1),
      summary: summary,
    );
  }

  Future<DesignVersion> rollback({
    required String designId,
    required DesignVersion current,
    required DesignVersion target,
  }) async {
    _logger.fine(
      'Rollback request for $designId: ${current.version} -> ${target.version}',
    );
    await Future<void>.delayed(const Duration(milliseconds: 480));
    if (Random().nextDouble() < 0.04) {
      throw Exception(
        gates.prefersEnglish
            ? 'Rollback temporarily unavailable'
            : 'ロールバックできませんでした。再試行してください。',
      );
    }

    final nextVersion = max(current.version + 1, target.version + 1);
    final snapshot = target.snapshot.copyWith(
      version: nextVersion,
      updatedAt: DateTime.now(),
    );
    return DesignVersion(
      id: 'ver-$nextVersion',
      version: nextVersion,
      snapshot: snapshot,
      createdBy: gates.prefersEnglish ? 'You' : '自分',
      createdAt: DateTime.now(),
      changeNote: gates.prefersEnglish
          ? 'Rollback to v${target.version}'
          : 'v${target.version} にロールバック',
    );
  }

  DesignVersion duplicateFrom(
    DesignVersion source, {
    required int nextVersion,
  }) {
    final snapshot = source.snapshot.copyWith(
      version: nextVersion,
      updatedAt: DateTime.now(),
    );
    return DesignVersion(
      id: 'ver-$nextVersion',
      version: nextVersion,
      snapshot: snapshot,
      createdBy: gates.prefersEnglish ? 'You' : '自分',
      createdAt: DateTime.now(),
      changeNote: gates.prefersEnglish ? 'Draft copy' : 'ドラフトコピー',
    );
  }

  VersionAuditEntry auditForRollback({
    required DesignVersion from,
    required DesignVersion to,
  }) {
    final prefersEnglish = gates.prefersEnglish;
    return VersionAuditEntry(
      title: prefersEnglish ? 'Rollback applied' : 'ロールバック完了',
      detail: prefersEnglish
          ? 'v${from.version} → v${to.version}'
          : 'v${from.version} から v${to.version} に復元しました',
      actor: prefersEnglish ? 'You' : '自分',
      level: VersionAuditLevel.success,
      timestamp: DateTime.now(),
    );
  }

  String versionId(DesignVersion version) =>
      version.id ?? 'v${version.version}';

  List<VersionChange> _diffFields(Design base, Design target) {
    final prefersEnglish = gates.prefersEnglish;
    final changes = <VersionChange>[];

    void addChange(
      String label,
      String before,
      String after,
      VersionChangeKind kind,
    ) {
      if (before == after) return;
      changes.add(
        VersionChange(label: label, before: before, after: after, kind: kind),
      );
    }

    addChange(
      prefersEnglish ? 'Name' : '刻印名',
      base.input?.rawName ?? (prefersEnglish ? 'Unset' : '未設定'),
      target.input?.rawName ?? (prefersEnglish ? 'Unset' : '未設定'),
      VersionChangeKind.metadata,
    );

    addChange(
      prefersEnglish ? 'Writing style' : '書体',
      _writingLabel(base.style.writing),
      _writingLabel(target.style.writing),
      VersionChangeKind.writing,
    );

    addChange(
      prefersEnglish ? 'Shape' : '形状',
      _shapeLabel(base.shape),
      _shapeLabel(target.shape),
      VersionChangeKind.layout,
    );

    addChange(
      prefersEnglish ? 'Size' : 'サイズ',
      '${base.size.mm.toStringAsFixed(1)}mm',
      '${target.size.mm.toStringAsFixed(1)}mm',
      VersionChangeKind.size,
    );

    addChange(
      prefersEnglish ? 'Stroke' : '線の太さ',
      _formatDouble(base.style.stroke?.weight, unit: 'pt'),
      _formatDouble(target.style.stroke?.weight, unit: 'pt'),
      VersionChangeKind.stroke,
    );

    addChange(
      prefersEnglish ? 'Margin' : '余白',
      _formatDouble(base.style.layout?.margin, unit: 'mm'),
      _formatDouble(target.style.layout?.margin, unit: 'mm'),
      VersionChangeKind.layout,
    );

    addChange(
      prefersEnglish ? 'Template' : 'テンプレート',
      base.style.templateRef ?? (prefersEnglish ? 'None' : 'なし'),
      target.style.templateRef ?? (prefersEnglish ? 'None' : 'なし'),
      VersionChangeKind.template,
    );

    addChange(
      prefersEnglish ? 'Grid' : 'ガイド',
      base.style.layout?.grid ?? (prefersEnglish ? 'Auto' : '自動'),
      target.style.layout?.grid ?? (prefersEnglish ? 'Auto' : '自動'),
      VersionChangeKind.layout,
    );

    return changes;
  }

  String _shapeLabel(SealShape shape) {
    return switch (shape) {
      SealShape.round => gates.prefersEnglish ? 'Round' : '丸印',
      SealShape.square => gates.prefersEnglish ? 'Square' : '角印',
    };
  }

  String _writingLabel(WritingStyle style) {
    return switch (style) {
      WritingStyle.tensho => gates.prefersEnglish ? 'Tensho' : '篆書',
      WritingStyle.reisho => gates.prefersEnglish ? 'Reisho' : '隷書',
      WritingStyle.kaisho => gates.prefersEnglish ? 'Kaisho' : '楷書',
      WritingStyle.gyosho => gates.prefersEnglish ? 'Gyosho' : '行書',
      WritingStyle.koentai => gates.prefersEnglish ? 'Kointai' : '古印体',
      WritingStyle.custom => gates.prefersEnglish ? 'Custom' : 'カスタム',
    };
  }

  String _formatDouble(double? value, {required String unit}) {
    if (value == null) return gates.prefersEnglish ? 'Not set' : '未設定';
    return '${value.toStringAsFixed(1)}$unit';
  }
}
