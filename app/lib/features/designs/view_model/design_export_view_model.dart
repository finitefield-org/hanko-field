// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/analytics/analytics.dart';
import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart' hide Characters;
import 'package:miniriverpod/miniriverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

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
    required this.layout,
    required this.strokeWeight,
    required this.margin,
    required this.rotation,
    this.templateName,
  });

  final String displayName;
  final SealShape shape;
  final double sizeMm;
  final WritingStyle writingStyle;
  final DesignCanvasLayout layout;
  final double strokeWeight;
  final double margin;
  final double rotation;
  final String? templateName;

  ExportableDesign copyWith({
    String? displayName,
    SealShape? shape,
    double? sizeMm,
    WritingStyle? writingStyle,
    DesignCanvasLayout? layout,
    double? strokeWeight,
    double? margin,
    double? rotation,
    String? templateName,
  }) {
    return ExportableDesign(
      displayName: displayName ?? this.displayName,
      shape: shape ?? this.shape,
      sizeMm: sizeMm ?? this.sizeMm,
      writingStyle: writingStyle ?? this.writingStyle,
      layout: layout ?? this.layout,
      strokeWeight: strokeWeight ?? this.strokeWeight,
      margin: margin ?? this.margin,
      rotation: rotation ?? this.rotation,
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
  Future<DesignExportState> build(
    Ref<AsyncValue<DesignExportState>> ref,
  ) async {
    _gates = ref.watch(appExperienceGatesProvider);
    final permissionClient = ref.watch(storagePermissionClientProvider);
    final storageStatus = await permissionClient.status();

    final creation = ref.watch(designCreationViewModel);
    final editor = ref.watch(designEditorViewModel);
    final design = _resolveDesign(creation, editor, _gates);

    ref.listen(designCreationViewModel, (_, next) {
      final current = ref.watch(this).valueOrNull;
      if (current == null) return;
      final updated = _resolveDesign(
        next,
        ref.watch(designEditorViewModel),
        _gates,
      );
      ref.state = AsyncData(current.copyWith(design: updated));
    });

    ref.listen(designEditorViewModel, (_, next) {
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

  Call<ExportFormat, AsyncValue<DesignExportState>> setFormat(
    ExportFormat format,
  ) => mutate(setFormatMut, (ref) async {
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

  Call<bool, AsyncValue<DesignExportState>> toggleTransparent(bool enabled) =>
      mutate(toggleTransparentMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(transparentBackground: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool, AsyncValue<DesignExportState>> toggleBleed(bool enabled) =>
      mutate(toggleBleedMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(includeBleed: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool, AsyncValue<DesignExportState>> toggleMetadata(bool enabled) =>
      mutate(toggleMetadataMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(includeMetadata: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool, AsyncValue<DesignExportState>> toggleWatermark(bool enabled) =>
      mutate(toggleWatermarkMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(current.copyWith(watermarkOnShare: enabled));
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<StoragePermissionStatus, AsyncValue<DesignExportState>>
  ensurePermission() => mutate(ensurePermissionMut, (ref) async {
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

  Call<bool, AsyncValue<DesignExportState>> export({
    required String destination,
  }) => mutate(exportMut, (ref) async {
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
      progress: 0.14,
      storageStatus: permission,
      clearFeedback: true,
      lastSharedVia: null,
    );
    ref.state = AsyncData(working);

    try {
      final rendered = await _renderExportAsset(working, watermark: false);
      working = working.copyWith(progress: 0.62);
      ref.state = AsyncData(working);

      final saved = await _saveExportFile(
        rendered,
        destination: destination,
        state: working,
      );

      final record = ExportRecord(
        filename: rendered.filenameBase,
        destination: destination,
        format: rendered.format,
        createdAt: DateTime.now(),
        fileSizeMb: rendered.sizeMb,
        sharedVia: null,
        watermarked: false,
      );

      final updatedHistory = <ExportRecord>[record, ...working.history];
      ref.state = AsyncData(
        working.copyWith(
          isExporting: false,
          progress: 1.0,
          lastExportPath: saved.filePath,
          history: updatedHistory.take(6).toList(),
          feedbackMessage: _gates.prefersEnglish
              ? 'Saved ${record.label} to $destination'
              : '$destination に ${record.label} を保存しました',
          feedbackId: working.feedbackId + 1,
        ),
      );
      final analytics = ref.watch(analyticsClientProvider);
      unawaited(
        analytics.track(
          DesignExportCompletedEvent(
            format: record.format.name,
            destination: destination,
            fileSizeMb: record.fileSizeMb,
            includeBleed: working.includeBleed,
            includeMetadata: working.includeMetadata,
            transparentBackground: working.transparentBackground,
            watermarkOnShare: working.watermarkOnShare,
            persona: _gates.personaKey,
            locale: _gates.localeTag,
          ),
        ),
      );
      return true;
    } catch (error) {
      ref.state = AsyncData(
        working.copyWith(
          isExporting: false,
          progress: 0,
          feedbackMessage: _gates.prefersEnglish
              ? 'Export failed: $error'
              : '書き出しに失敗しました: $error',
          feedbackId: working.feedbackId + 1,
        ),
      );
      return false;
    }
  }, concurrency: Concurrency.restart);

  Call<bool, AsyncValue<DesignExportState>> share({required String target}) =>
      mutate(shareMut, (ref) async {
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

        try {
          final rendered = await _renderExportAsset(
            working,
            watermark: working.watermarkOnShare,
          );
          working = working.copyWith(progress: 0.68);
          ref.state = AsyncData(working);

          await _shareExport(
            rendered,
            target: target,
            includeMetadata: working.includeMetadata,
            state: working,
          );

          final record = ExportRecord(
            filename: rendered.filenameBase,
            destination: target,
            format: rendered.format,
            createdAt: DateTime.now(),
            fileSizeMb: rendered.sizeMb,
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
          final analytics = ref.watch(analyticsClientProvider);
          unawaited(
            analytics.track(
              DesignExportSharedEvent(
                format: record.format.name,
                target: target,
                includeMetadata: working.includeMetadata,
                watermarked: working.watermarkOnShare,
                persona: _gates.personaKey,
                locale: _gates.localeTag,
              ),
            ),
          );
          return true;
        } catch (error) {
          ref.state = AsyncData(
            working.copyWith(
              isSharing: false,
              progress: 0,
              feedbackMessage: _gates.prefersEnglish
                  ? 'Share failed: $error'
                  : '共有に失敗しました: $error',
              feedbackId: working.feedbackId + 1,
            ),
          );
          return false;
        }
      }, concurrency: Concurrency.restart);

  void _emitFeedback(Ref<AsyncValue<DesignExportState>> ref, String message) {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;

    ref.state = AsyncData(
      current.copyWith(
        feedbackMessage: message,
        feedbackId: current.feedbackId + 1,
      ),
    );
  }

  Future<_RenderedBytes> _renderExportAsset(
    DesignExportState state, {
    required bool watermark,
  }) async {
    final pixelSize = exportPixelSize(state.design, state.format);
    final bleedPx = state.includeBleed ? _bleedPx(state.format) : 0;
    final rasterized = await _rasterizeDesign(
      state: state,
      baseSize: pixelSize,
      bleedPx: bleedPx,
      watermark: watermark,
    );

    final filenameBase = _fileSafeName(state.design.displayName);
    final side = pixelSize + bleedPx * 2;

    switch (state.format) {
      case ExportFormat.png:
        return _RenderedBytes(
          bytes: rasterized.pngBytes,
          format: state.format,
          filenameBase: filenameBase,
          mimeType: 'image/png',
          pixelSize: side,
          bleedPx: bleedPx,
        );
      case ExportFormat.svg:
        final markup = _buildSvgMarkup(
          state: state,
          side: side.toDouble(),
          bleedPx: bleedPx.toDouble(),
          watermark: watermark,
        );
        return _RenderedBytes(
          bytes: Uint8List.fromList(utf8.encode(markup)),
          format: state.format,
          filenameBase: filenameBase,
          mimeType: 'image/svg+xml',
          pixelSize: side,
          bleedPx: bleedPx,
        );
      case ExportFormat.pdf:
        final pdfBytes = await _buildPdfBytes(
          rasterized: rasterized,
          state: state,
        );
        return _RenderedBytes(
          bytes: pdfBytes,
          format: state.format,
          filenameBase: filenameBase,
          mimeType: 'application/pdf',
          pixelSize: side,
          bleedPx: bleedPx,
        );
    }
  }

  Future<_RasterizedDesign> _rasterizeDesign({
    required DesignExportState state,
    required int baseSize,
    required int bleedPx,
    required bool watermark,
  }) async {
    final side = baseSize + bleedPx * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    );

    if (!state.transparentBackground) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
        Paint()..color = Colors.white,
      );
    }

    final inset = (state.design.margin + 8).clamp(0, side / 3).toDouble();
    final area = Rect.fromLTWH(
      bleedPx.toDouble() + inset,
      bleedPx.toDouble() + inset,
      side.toDouble() - (bleedPx.toDouble() + inset) * 2,
      side.toDouble() - (bleedPx.toDouble() + inset) * 2,
    );
    final center = area.center;
    const ink = Color(0xFFB71C1C);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(state.design.rotation * pi / 180);
    canvas.translate(-center.dx, -center.dy);

    _paintShape(canvas, center, area, state.design, ink);
    _paintName(canvas, center, area, state.design, ink);

    canvas.restore();

    if (watermark) {
      _paintWatermark(canvas, side.toDouble());
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(side, side);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return _RasterizedDesign(
      pngBytes: byteData!.buffer.asUint8List(),
      side: side,
      bleedPx: bleedPx,
    );
  }

  Future<_SavedExport> _saveExportFile(
    _RenderedBytes rendered, {
    required String destination,
    required DesignExportState state,
  }) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final destinationDir = Directory(
      p.join(baseDir.path, 'exports', _fileSafeName(destination)),
    );
    await destinationDir.create(recursive: true);

    final path = p.join(destinationDir.path, rendered.filenameWithExtension);
    await File(path).writeAsBytes(rendered.bytes, flush: true);

    String? metadataPath;
    if (state.includeMetadata) {
      metadataPath = await _writeMetadataSidecar(
        rendered: rendered,
        destinationDir: destinationDir,
        state: state,
        sharedVia: null,
        watermarked: false,
      );
    }

    return _SavedExport(filePath: path, metadataPath: metadataPath);
  }

  Future<void> _shareExport(
    _RenderedBytes rendered, {
    required String target,
    required bool includeMetadata,
    required DesignExportState state,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final exportPath = p.join(tempDir.path, rendered.filenameWithExtension);
    await File(exportPath).writeAsBytes(rendered.bytes, flush: true);

    final attachments = <XFile>[
      XFile(
        exportPath,
        mimeType: rendered.mimeType,
        name: rendered.filenameWithExtension,
      ),
    ];

    if (includeMetadata) {
      final metadataPath = await _writeMetadataSidecar(
        rendered: rendered,
        destinationDir: tempDir,
        state: state,
        sharedVia: target,
        watermarked: state.watermarkOnShare,
      );
      attachments.add(
        XFile(
          metadataPath,
          mimeType: 'application/json',
          name: '${rendered.filenameBase}.metadata.json',
        ),
      );
    }

    await Share.shareXFiles(
      attachments,
      subject: rendered.filenameWithExtension,
      text: _gates.prefersEnglish
          ? 'Shared from Hanko Field ($target)'
          : 'Hanko Field から$targetに共有しました',
    );
  }

  Future<String> _writeMetadataSidecar({
    required _RenderedBytes rendered,
    required Directory destinationDir,
    required DesignExportState state,
    required bool watermarked,
    String? sharedVia,
  }) async {
    final payload = _buildMetadataPayload(
      state: state,
      format: rendered.format,
      watermarked: watermarked,
      sharedVia: sharedVia,
    );
    final metadataPath = p.join(
      destinationDir.path,
      '${rendered.filenameBase}.metadata.json',
    );
    final encoder = const JsonEncoder.withIndent('  ');
    await File(metadataPath).writeAsString(encoder.convert(payload));
    return metadataPath;
  }

  Map<String, Object?> _buildMetadataPayload({
    required DesignExportState state,
    required ExportFormat format,
    required bool watermarked,
    String? sharedVia,
  }) {
    return {
      'design': {
        'displayName': state.design.displayName,
        'shape': state.design.shape.name,
        'sizeMm': state.design.sizeMm,
        'writingStyle': state.design.writingStyle.name,
        'layout': state.design.layout.name,
        'strokeWeight': state.design.strokeWeight,
        'margin': state.design.margin,
        'rotation': state.design.rotation,
        'templateName': state.design.templateName,
      },
      'export': {
        'format': format.name,
        'colorProfile': state.colorProfile,
        'transparentBackground': state.transparentBackground,
        'includeBleed': state.includeBleed,
        'includeMetadata': state.includeMetadata,
        'watermarked': watermarked,
        'sharedVia': sharedVia,
        'createdAt': DateTime.now().toIso8601String(),
      },
    };
  }

  void _paintShape(
    Canvas canvas,
    Offset center,
    Rect area,
    ExportableDesign design,
    Color ink,
  ) {
    final radius = min(area.width, area.height) / 2;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = design.strokeWeight
      ..strokeJoin = StrokeJoin.round;

    switch (design.shape) {
      case SealShape.round:
        canvas.drawCircle(center, radius, stroke);
      case SealShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: area.shortestSide,
              height: area.shortestSide,
            ),
            const Radius.circular(8),
          ),
          stroke,
        );
    }
  }

  void _paintName(
    Canvas canvas,
    Offset center,
    Rect area,
    ExportableDesign design,
    Color ink,
  ) {
    final characters = Characters(design.displayName).toList();
    final inkPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;
    final textStyle = TextStyle(
      color: inkPaint.color,
      fontWeight: _fontWeightForStyle(design.writingStyle),
      letterSpacing: design.layout == DesignCanvasLayout.grid
          ? 1
          : (design.layout == DesignCanvasLayout.vertical ? 0.5 : 0),
      fontSize: area.shortestSide * 0.12,
      height: design.layout == DesignCanvasLayout.vertical ? 1.15 : 1.0,
    );

    switch (design.layout) {
      case DesignCanvasLayout.balanced:
        _drawCentered(canvas, center, area, textStyle, characters.join(''));
      case DesignCanvasLayout.vertical:
        _drawVertical(canvas, center, area, textStyle, characters);
      case DesignCanvasLayout.grid:
        _drawGridLayout(canvas, center, area, textStyle, characters);
      case DesignCanvasLayout.arc:
        _drawArc(canvas, center, area, textStyle, characters);
    }
  }

  void _drawCentered(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    String text,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: area.width * 0.8);
    final offset = Offset(
      center.dx - painter.width / 2,
      center.dy - painter.height / 2,
    );
    painter.paint(canvas, offset);
  }

  void _drawVertical(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    List<String> chars,
  ) {
    final spacing = area.height / (chars.length + 1);
    for (int i = 0; i < chars.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx - painter.width / 2,
        area.top + spacing * (i + 0.8),
      );
      painter.paint(canvas, offset);
    }
  }

  void _drawGridLayout(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    List<String> chars,
  ) {
    final columns = 2;
    final rows = (chars.length / columns).ceil();
    final cellWidth = area.width / columns;
    final cellHeight = area.height / rows;
    for (int i = 0; i < chars.length; i++) {
      final col = i % columns;
      final row = (i / columns).floor();
      final painter = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cellWidth);
      final dx = area.left + cellWidth * col + (cellWidth - painter.width) / 2;
      final dy =
          area.top + cellHeight * row + (cellHeight - painter.height) / 2;
      painter.paint(canvas, Offset(dx, dy));
    }
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    List<String> chars,
  ) {
    final radius = min(area.width, area.height) / 2.4;
    final sweep = pi * 1.3;
    final startAngle = -sweep / 2;
    for (int i = 0; i < chars.length; i++) {
      final angle = startAngle + sweep * (i / max(chars.length - 1, 1));
      final offset = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle + pi / 2);
      final painter = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  void _paintWatermark(Canvas canvas, double side) {
    const watermark = 'Hanko Field • preview';
    final painter = TextPainter(
      text: const TextSpan(
        text: watermark,
        style: TextStyle(
          color: Color(0x66B71C1C),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: side);
    painter.paint(
      canvas,
      Offset(side - painter.width - 16, side - painter.height - 16),
    );
  }

  String _buildSvgMarkup({
    required DesignExportState state,
    required double side,
    required double bleedPx,
    required bool watermark,
  }) {
    final inset = (state.design.margin + 8).clamp(0, side / 3);
    final areaSize = side - (bleedPx + inset) * 2;
    final center = side / 2;
    final buffer = StringBuffer()
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="$side" height="$side" viewBox="0 0 $side $side">',
      );
    if (!state.transparentBackground) {
      buffer.writeln('<rect width="100%" height="100%" fill="white" />');
    }

    buffer.write(
      '<g transform="rotate(${state.design.rotation},$center,$center)">',
    );
    final strokeWidth = state.design.strokeWeight;
    if (state.design.shape == SealShape.round) {
      final radius = areaSize / 2;
      buffer.writeln(
        '<circle cx="$center" cy="$center" r="$radius" '
        'fill="none" stroke="#b71c1c" stroke-width="$strokeWidth" />',
      );
    } else {
      final start = bleedPx + inset;
      buffer.writeln(
        '<rect x="$start" y="$start" width="$areaSize" height="$areaSize" '
        'fill="none" stroke="#b71c1c" stroke-width="$strokeWidth" '
        'rx="8" ry="8" />',
      );
    }

    final chars = Characters(state.design.displayName).toList();
    final fontSize = areaSize * 0.12;
    final fontWeight = _fontWeightForStyle(state.design.writingStyle);
    final weightValue = fontWeight.value;

    switch (state.design.layout) {
      case DesignCanvasLayout.balanced:
        buffer.writeln(
          '<text x="$center" y="$center" '
          'fill="#b71c1c" font-size="$fontSize" font-weight="$weightValue" '
          'text-anchor="middle" dominant-baseline="central">'
          '${_escapeSvg(chars.join(''))}</text>',
        );
      case DesignCanvasLayout.vertical:
        final spacing = areaSize / (chars.length + 1);
        for (int i = 0; i < chars.length; i++) {
          final y = bleedPx + inset + spacing * (i + 0.8);
          buffer.writeln(
            '<text x="$center" y="$y" fill="#b71c1c" '
            'font-size="$fontSize" font-weight="$weightValue" '
            'text-anchor="middle" dominant-baseline="central">'
            '${_escapeSvg(chars[i])}</text>',
          );
        }
      case DesignCanvasLayout.grid:
        final columns = 2;
        final rows = (chars.length / columns).ceil();
        final cellWidth = areaSize / columns;
        final cellHeight = areaSize / rows;
        for (int i = 0; i < chars.length; i++) {
          final col = i % columns;
          final row = (i / columns).floor();
          final x = bleedPx + inset + cellWidth * col + cellWidth / 2;
          final y = bleedPx + inset + cellHeight * row + cellHeight / 2;
          buffer.writeln(
            '<text x="$x" y="$y" fill="#b71c1c" '
            'font-size="$fontSize" font-weight="$weightValue" '
            'text-anchor="middle" dominant-baseline="central">'
            '${_escapeSvg(chars[i])}</text>',
          );
        }
      case DesignCanvasLayout.arc:
        final radius = areaSize / 2.4;
        final sweep = pi * 1.3;
        final startAngle = -sweep / 2;
        for (int i = 0; i < chars.length; i++) {
          final angle = startAngle + sweep * (i / max(chars.length - 1, 1));
          final x = center + radius * cos(angle);
          final y = center + radius * sin(angle);
          final rotate = angle * 180 / pi + 90;
          buffer.writeln(
            '<text x="$x" y="$y" fill="#b71c1c" '
            'font-size="$fontSize" font-weight="$weightValue" '
            'text-anchor="middle" dominant-baseline="central" '
            'transform="rotate($rotate,$x,$y)">'
            '${_escapeSvg(chars[i])}</text>',
          );
        }
    }
    buffer.writeln('</g>');

    if (watermark) {
      final watermarkSize = fontSize * 0.7;
      buffer.writeln(
        '<text x="${side - 12}" y="${side - 12}" '
        'fill="rgba(183,28,28,0.4)" font-size="$watermarkSize" '
        'font-weight="600" text-anchor="end" '
        'dominant-baseline="ideographic">Hanko Field • preview</text>',
      );
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  Future<Uint8List> _buildPdfBytes({
    required _RasterizedDesign rasterized,
    required DesignExportState state,
  }) async {
    final doc = pw.Document(
      creator: 'Hanko Field',
      title: state.design.displayName,
      author: 'Hanko Field',
    );
    final mmSide = state.design.sizeMm + (state.includeBleed ? 3.0 : 0.0);
    final format = PdfPageFormat(
      mmSide * PdfPageFormat.mm,
      mmSide * PdfPageFormat.mm,
    );
    final image = pw.MemoryImage(rasterized.pngBytes);
    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Center(
          child: pw.Image(
            image,
            width: format.width,
            height: format.height,
            fit: pw.BoxFit.cover,
          ),
        ),
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  FontWeight _fontWeightForStyle(WritingStyle style) {
    return switch (style) {
      WritingStyle.tensho => FontWeight.w600,
      WritingStyle.reisho => FontWeight.w500,
      WritingStyle.kaisho => FontWeight.w700,
      WritingStyle.gyosho => FontWeight.w500,
      WritingStyle.koentai => FontWeight.w800,
      WritingStyle.custom => FontWeight.w600,
    };
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
    final defaultLayout =
        (creationState?.selectedShape ?? editorState?.shape) == SealShape.square
        ? DesignCanvasLayout.grid
        : DesignCanvasLayout.balanced;
    final layout =
        editorState?.layout ??
        switch (creationState?.selectedStyle?.layout?.grid) {
          'grid' => DesignCanvasLayout.grid,
          'vertical' => DesignCanvasLayout.vertical,
          'arc' => DesignCanvasLayout.arc,
          _ => defaultLayout,
        };
    final strokeWeight =
        editorState?.strokeWeight ??
        creationState?.selectedStyle?.stroke?.weight ??
        2.4;
    final margin =
        editorState?.margin ??
        creationState?.selectedStyle?.layout?.margin ??
        12;
    final rotation = editorState?.rotation ?? 0.0;
    final templateName =
        creationState?.selectedTemplate?.name ??
        creationState?.selectedTemplate?.id ??
        editorState?.templateName;

    return ExportableDesign(
      displayName: displayName,
      shape: shape,
      sizeMm: sizeMm,
      writingStyle: writing,
      layout: layout,
      strokeWeight: strokeWeight,
      margin: margin,
      rotation: rotation,
      templateName: templateName,
    );
  }
}

class _RenderedBytes {
  _RenderedBytes({
    required this.bytes,
    required this.format,
    required this.filenameBase,
    required this.mimeType,
    required this.pixelSize,
    required this.bleedPx,
  });

  final Uint8List bytes;
  final ExportFormat format;
  final String filenameBase;
  final String mimeType;
  final int pixelSize;
  final int bleedPx;

  double get sizeMb => bytes.lengthInBytes / (1024 * 1024);

  String get filenameWithExtension => '$filenameBase.${format.fileExtension}';
}

class _RasterizedDesign {
  _RasterizedDesign({
    required this.pngBytes,
    required this.side,
    required this.bleedPx,
  });

  final Uint8List pngBytes;
  final int side;
  final int bleedPx;
}

class _SavedExport {
  _SavedExport({required this.filePath, this.metadataPath});

  final String filePath;
  final String? metadataPath;
}

final designExportViewModel = DesignExportViewModel();

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
  final ppi = _ppiForFormat(format);
  return max(512, (inches * ppi).round());
}

int exportPixelSize(ExportableDesign design, ExportFormat format) =>
    _pixelSize(design, format);

double estimateExportSizeMb(DesignExportState state) => _estimateSizeMb(state);

int _ppiForFormat(ExportFormat format) => switch (format) {
  ExportFormat.png => 1200,
  ExportFormat.svg => 960,
  ExportFormat.pdf => 900,
};

int _bleedPx(ExportFormat format) {
  final ppi = _ppiForFormat(format);
  return (1.5 / 25.4 * ppi).round();
}

String _escapeSvg(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _fileSafeName(String name) {
  final sanitized = name.replaceAll(
    RegExp(r'[^\p{L}\p{N}_-]+', unicode: true),
    '_',
  );
  final trimmed = sanitized.replaceAll(RegExp('_+'), '_').trim();
  return trimmed.isEmpty ? 'hanko_design' : trimmed.toLowerCase();
}
