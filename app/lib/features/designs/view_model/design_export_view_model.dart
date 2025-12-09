// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum ExportFormat { png, svg, pdf }

extension ExportFormatX on ExportFormat {
  String label(bool prefersEnglish) => switch (this) {
    ExportFormat.png => prefersEnglish ? 'PNG' : 'PNG',
    ExportFormat.svg => prefersEnglish ? 'SVG' : 'SVG',
    ExportFormat.pdf => prefersEnglish ? 'PDF' : 'PDF',
  };

  String get fileExtension => switch (this) {
    ExportFormat.png => 'png',
    ExportFormat.svg => 'svg',
    ExportFormat.pdf => 'pdf',
  };

  String colorProfile(bool prefersEnglish) => switch (this) {
    ExportFormat.png => prefersEnglish ? 'sRGB IEC 61966-2-1' : 'sRGB（画面用）',
    ExportFormat.svg => prefersEnglish ? 'Display-P3' : 'Display-P3（ベクター）',
    ExportFormat.pdf =>
      prefersEnglish ? 'Japan Color 2011 Coated' : 'Japan Color 2011 Coated',
  };
}

class ExportableDesign {
  const ExportableDesign({
    required this.displayName,
    required this.shape,
    required this.sizeMm,
    required this.writingStyle,
    this.templateName,
  });

  final String displayName;
  final SealShape shape;
  final double sizeMm;
  final WritingStyle writingStyle;
  final String? templateName;

  ExportableDesign copyWith({
    String? displayName,
    SealShape? shape,
    double? sizeMm,
    WritingStyle? writingStyle,
    String? templateName,
  }) {
    return ExportableDesign(
      displayName: displayName ?? this.displayName,
      shape: shape ?? this.shape,
      sizeMm: sizeMm ?? this.sizeMm,
      writingStyle: writingStyle ?? this.writingStyle,
      templateName: templateName ?? this.templateName,
    );
  }
}

class ExportRecord {
  const ExportRecord({
    required this.filename,
    required this.destination,
    required this.format,
    required this.createdAt,
    required this.fileSizeMb,
    this.sharedVia,
    this.watermarked = false,
  });

  final String filename;
  final String destination;
  final ExportFormat format;
  final DateTime createdAt;
  final double fileSizeMb;
  final String? sharedVia;
  final bool watermarked;

  String get label => '$filename.${format.fileExtension}';
}

class DesignExportState {
  const DesignExportState({
    required this.design,
    required this.format,
    required this.transparentBackground,
    required this.includeBleed,
    required this.includeMetadata,
    required this.watermarkOnShare,
    required this.storageStatus,
    required this.isExporting,
    required this.isSharing,
    required this.progress,
    required this.history,
    required this.colorProfile,
    required this.feedbackId,
    this.lastExportPath,
    this.lastSharedVia,
    this.feedbackMessage,
  });

  final ExportableDesign design;
  final ExportFormat format;
  final bool transparentBackground;
  final bool includeBleed;
  final bool includeMetadata;
  final bool watermarkOnShare;
  final StoragePermissionStatus storageStatus;
  final bool isExporting;
  final bool isSharing;
  final double progress;
  final List<ExportRecord> history;
  final String colorProfile;
  final int feedbackId;
  final String? lastExportPath;
  final String? lastSharedVia;
  final String? feedbackMessage;

  DesignExportState copyWith({
    ExportableDesign? design,
    ExportFormat? format,
    bool? transparentBackground,
    bool? includeBleed,
    bool? includeMetadata,
    bool? watermarkOnShare,
    StoragePermissionStatus? storageStatus,
    bool? isExporting,
    bool? isSharing,
    double? progress,
    List<ExportRecord>? history,
    String? colorProfile,
    int? feedbackId,
    String? lastExportPath,
    String? lastSharedVia,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return DesignExportState(
      design: design ?? this.design,
      format: format ?? this.format,
      transparentBackground:
          transparentBackground ?? this.transparentBackground,
      includeBleed: includeBleed ?? this.includeBleed,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      watermarkOnShare: watermarkOnShare ?? this.watermarkOnShare,
      storageStatus: storageStatus ?? this.storageStatus,
      isExporting: isExporting ?? this.isExporting,
      isSharing: isSharing ?? this.isSharing,
      progress: progress ?? this.progress,
      history: history ?? this.history,
      colorProfile: colorProfile ?? this.colorProfile,
      feedbackId: feedbackId ?? this.feedbackId,
      lastExportPath: lastExportPath ?? this.lastExportPath,
      lastSharedVia: lastSharedVia ?? this.lastSharedVia,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
    );
  }
}

class DesignExportViewModel extends AsyncProvider<DesignExportState> {
  DesignExportViewModel() : super.args(null, autoDispose: false);

  late final setFormatMut = mutation<ExportFormat>(#setFormat);
  late final toggleTransparentMut = mutation<bool>(#toggleTransparent);
  late final toggleBleedMut = mutation<bool>(#toggleBleed);
  late final toggleMetadataMut = mutation<bool>(#toggleMetadata);
  late final toggleWatermarkMut = mutation<bool>(#toggleWatermark);
  late final ensurePermissionMut = mutation<StoragePermissionStatus>(
    #ensurePermission,
  );
  late final exportMut = mutation<bool>(#export);
  late final shareMut = mutation<bool>(#share);

  late AppExperienceGates _gates;

  @override
  Future<DesignExportState> build(Ref ref) async {
    _gates = ref.watch(appExperienceGatesProvider);
    final permissionClient = ref.watch(storagePermissionClientProvider);
    final storageStatus = await permissionClient.status();

    final creation = ref.watch(designCreationViewModel);
    final editor = ref.watch(designEditorViewModel);
    final design = _resolveDesign(creation, editor, _gates);

    ref.listen(designCreationViewModel, (next) {
      final current = ref.watch(this).valueOrNull;
      if (current == null) return;
      final updated = _resolveDesign(
        next,
        ref.watch(designEditorViewModel),
        _gates,
      );
      ref.state = AsyncData(current.copyWith(design: updated));
    });

    ref.listen(designEditorViewModel, (next) {
      final current = ref.watch(this).valueOrNull;
      if (current == null) return;
      final updated = _resolveDesign(
        ref.watch(designCreationViewModel),
        next,
        _gates,
      );
      ref.state = AsyncData(current.copyWith(design: updated));
    });

    return DesignExportState(
      design: design,
      format: ExportFormat.png,
      transparentBackground: true,
      includeBleed: true,
      includeMetadata: true,
      watermarkOnShare: true,
      storageStatus: storageStatus,
      isExporting: false,
      isSharing: false,
      progress: 0,
      history: const <ExportRecord>[],
      colorProfile: ExportFormat.png.colorProfile(_gates.prefersEnglish),
      feedbackId: 0,
      lastExportPath: null,
      lastSharedVia: null,
      feedbackMessage: null,
    );
  }

  Call<ExportFormat> setFormat(ExportFormat format) =>
      mutate(setFormatMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return format;

        final prefersEnglish = _gates.prefersEnglish;
        ref.state = AsyncData(
          current.copyWith(
            format: format,
            colorProfile: format.colorProfile(prefersEnglish),
          ),
        );
        return format;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleTransparent(bool enabled) =>
      mutate(toggleTransparentMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(transparentBackground: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleBleed(bool enabled) => mutate(toggleBleedMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return enabled;
    ref.state = AsyncData(current.copyWith(includeBleed: enabled));
    return enabled;
  }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleMetadata(bool enabled) =>
      mutate(toggleMetadataMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(includeMetadata: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleWatermark(bool enabled) =>
      mutate(toggleWatermarkMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(watermarkOnShare: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<StoragePermissionStatus> ensurePermission() =>
      mutate(ensurePermissionMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return StoragePermissionStatus.denied;

        final client = ref.watch(storagePermissionClientProvider);
        final status = await client.status();
        if (status.isGranted) {
          ref.state = AsyncData(current.copyWith(storageStatus: status));
          return status;
        }

        final requested = await client.request();
        ref.state = AsyncData(current.copyWith(storageStatus: requested));
        return requested;
      }, concurrency: Concurrency.restart);

  Call<bool> export({required String destination}) =>
      mutate(exportMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return false;

        final permission = await ref.invoke(ensurePermission());
        if (permission.isGranted != true) {
          _emitFeedback(
            ref,
            _gates.prefersEnglish
                ? 'Storage permission is required to save files.'
                : 'ファイル保存のためにストレージ権限が必要です。',
          );
          return false;
        }

        var working = current.copyWith(
          isExporting: true,
          progress: 0.18,
          storageStatus: permission,
          clearFeedback: true,
          lastSharedVia: null,
        );
        ref.state = AsyncData(working);

        await _simulateProgress(ref, working, intent: _ExportIntent.download);
        working = ref.watch(this).valueOrNull ?? working;

        final filename = _fileSafeName(working.design.displayName);
        final record = ExportRecord(
          filename: filename,
          destination: destination,
          format: working.format,
          createdAt: DateTime.now(),
          fileSizeMb: _estimateSizeMb(working),
          sharedVia: null,
          watermarked: false,
        );

        final updatedHistory = <ExportRecord>[record, ...working.history];
        ref.state = AsyncData(
          working.copyWith(
            isExporting: false,
            progress: 1.0,
            lastExportPath: '$destination/${record.label}',
            history: updatedHistory.take(6).toList(),
            feedbackMessage: _gates.prefersEnglish
                ? 'Saved ${record.label} to $destination'
                : '$destination に ${record.label} を保存しました',
            feedbackId: working.feedbackId + 1,
          ),
        );
        return true;
      }, concurrency: Concurrency.restart);

  Call<bool> share({required String target}) => mutate(shareMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;

    final permission = await ref.invoke(ensurePermission());
    if (permission.isGranted != true) {
      _emitFeedback(
        ref,
        _gates.prefersEnglish
            ? 'Storage permission is required before sharing.'
            : '共有前にストレージ権限が必要です。',
      );
      return false;
    }

    var working = current.copyWith(
      isSharing: true,
      progress: max(0.22, current.progress),
      storageStatus: permission,
      clearFeedback: true,
    );
    ref.state = AsyncData(working);

    await _simulateProgress(ref, working, intent: _ExportIntent.share);
    working = ref.watch(this).valueOrNull ?? working;

    final filename = _fileSafeName(working.design.displayName);
    final record = ExportRecord(
      filename: filename,
      destination: target,
      format: working.format,
      createdAt: DateTime.now(),
      fileSizeMb: _estimateSizeMb(working),
      sharedVia: target,
      watermarked: working.watermarkOnShare,
    );
    final updatedHistory = <ExportRecord>[record, ...working.history];

    ref.state = AsyncData(
      working.copyWith(
        isSharing: false,
        progress: 1.0,
        lastSharedVia: target,
        lastExportPath: 'share://${record.label}',
        history: updatedHistory.take(6).toList(),
        feedbackMessage: _gates.prefersEnglish
            ? 'Shared ${record.label} via $target'
            : '${record.label} を$targetで共有しました',
        feedbackId: working.feedbackId + 1,
      ),
    );
    return true;
  }, concurrency: Concurrency.restart);

  Future<void> _simulateProgress(
    Ref ref,
    DesignExportState base, {
    required _ExportIntent intent,
  }) async {
    final steps = intent == _ExportIntent.download
        ? <double>[0.32, 0.58, 0.86, 1.0]
        : <double>[0.42, 0.68, 0.92, 1.0];
    var working = base;

    for (final step in steps) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      working = working.copyWith(progress: step);
      ref.state = AsyncData(working);
    }
  }

  void _emitFeedback(Ref ref, String message) {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;

    ref.state = AsyncData(
      current.copyWith(
        feedbackMessage: message,
        feedbackId: current.feedbackId + 1,
      ),
    );
  }

  ExportableDesign _resolveDesign(
    AsyncValue<DesignCreationState> creation,
    AsyncValue<DesignEditorState> editor,
    AppExperienceGates gates,
  ) {
    final creationState = creation.valueOrNull;
    final editorState = editor.valueOrNull;

    final nameDraft = creationState?.nameDraft.fullName(
      prefersEnglish: gates.prefersEnglish,
    );
    final savedName = creationState?.savedInput?.rawName;
    final normalizedSaved = savedName?.trim();
    final displayName = (normalizedSaved != null && normalizedSaved.isNotEmpty)
        ? normalizedSaved
        : (nameDraft != null && nameDraft.isNotEmpty)
        ? nameDraft
        : (gates.prefersEnglish ? 'Taro Yamada' : '山田太郎');
    final shape =
        creationState?.selectedShape ?? editorState?.shape ?? SealShape.round;
    final writing =
        creationState?.selectedStyle?.writing ??
        creationState?.previewStyle ??
        editorState?.writingStyle ??
        WritingStyle.tensho;
    final sizeMm =
        editorState?.sizeMm ?? creationState?.selectedSize?.mm ?? 15.0;
    final templateName =
        creationState?.selectedTemplate?.name ??
        creationState?.selectedTemplate?.id ??
        editorState?.templateName;

    return ExportableDesign(
      displayName: displayName,
      shape: shape,
      sizeMm: sizeMm,
      writingStyle: writing,
      templateName: templateName,
    );
  }
}

final designExportViewModel = DesignExportViewModel();

enum _ExportIntent { download, share }

double _estimateSizeMb(DesignExportState state) {
  final basePx = _pixelSize(state.design, state.format);
  final multiplier = switch (state.format) {
    ExportFormat.png => 0.0000021,
    ExportFormat.svg => 0.0000014,
    ExportFormat.pdf => 0.0000028,
  };
  final bleedBoost = state.includeBleed ? 1.08 : 1.0;
  final metadataBoost = state.includeMetadata ? 1.06 : 1.0;
  final watermarkBoost = state.watermarkOnShare && state.isSharing ? 1.04 : 1.0;
  final estimate =
      basePx *
      basePx *
      multiplier *
      bleedBoost *
      metadataBoost *
      watermarkBoost;
  return double.parse(estimate.clamp(0.4, 18.0).toStringAsFixed(2));
}

int _pixelSize(ExportableDesign design, ExportFormat format) {
  final inches = design.sizeMm / 25.4;
  final ppi = switch (format) {
    ExportFormat.png => 1200,
    ExportFormat.svg => 960,
    ExportFormat.pdf => 900,
  };
  return max(512, (inches * ppi).round());
}

int exportPixelSize(ExportableDesign design, ExportFormat format) =>
    _pixelSize(design, format);

double estimateExportSizeMb(DesignExportState state) => _estimateSizeMb(state);

String _fileSafeName(String name) {
  final sanitized = name.replaceAll(
    RegExp(r'[^\p{L}\p{N}_-]+', unicode: true),
    '_',
  );
  final trimmed = sanitized.replaceAll(RegExp('_+'), '_').trim();
  return trimmed.isEmpty ? 'hanko_design' : trimmed.toLowerCase();
}
