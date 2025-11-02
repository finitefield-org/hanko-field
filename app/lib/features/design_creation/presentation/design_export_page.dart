import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/design_editor_controller.dart';
import 'package:app/features/design_creation/application/design_editor_state.dart';
import 'package:app/features/design_creation/application/design_export_controller.dart';
import 'package:app/features/design_creation/application/design_export_state.dart';
import 'package:app/features/design_creation/application/design_export_types.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/features/design_creation/presentation/widgets/design_canvas_preview.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const double _kBaseExportExtent = 1024;
const double _kBleedFraction = 0.05;
const double _kSvgCornerRadiusFactor = 0.1;
const double _kMarginNormalizationFactor = 20;
const double _kMarginRelativeCap = 0.2;
const double _kMarginSafetyInset = 8;

class DesignExportPage extends ConsumerStatefulWidget {
  const DesignExportPage({super.key});

  @override
  ConsumerState<DesignExportPage> createState() => _DesignExportPageState();
}

class _DesignExportPageState extends ConsumerState<DesignExportPage> {
  final GlobalKey _previewBoundaryKey = GlobalKey(debugLabel: 'design-export');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exportState = ref.watch(designExportControllerProvider);
    final creationState = ref.watch(designCreationControllerProvider);
    final config = ref.watch(
      designEditorControllerProvider.select((value) => value.config),
    );
    final designText = _resolveDesignText(creationState, l10n);
    final shape = creationState.selectedShape ?? DesignShape.round;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designExportTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(appStateProvider.notifier).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: l10n.designExportHistoryTooltip,
            onPressed: exportState.lastResult == null
                ? null
                : () => _showHistorySheet(context, exportState, l10n),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceL,
            vertical: AppTokens.spaceL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExportPreview(
                boundaryKey: _previewBoundaryKey,
                config: config,
                shape: shape,
                designText: designText,
                transparentBackground: exportState.transparentBackground,
                includeBleed: exportState.includeBleed,
                l10n: l10n,
              ),
              const SizedBox(height: AppTokens.spaceXL),
              _FormatSelector(state: exportState, l10n: l10n),
              const SizedBox(height: AppTokens.spaceL),
              _ExportOptions(state: exportState, l10n: l10n),
              if (exportState.errorMessage != null) ...[
                const SizedBox(height: AppTokens.spaceM),
                _ErrorBanner(message: exportState.errorMessage!),
              ],
              if (exportState.shareErrorMessage != null) ...[
                const SizedBox(height: AppTokens.spaceM),
                _ErrorBanner(message: exportState.shareErrorMessage!),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceM,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: exportState.isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(l10n.designExportExportButton),
              onPressed: exportState.isProcessing
                  ? null
                  : () => _handleExport(
                      context,
                      config,
                      creationState,
                      designText,
                      shape,
                      exportState,
                    ),
            ),
            const SizedBox(height: AppTokens.spaceM),
            OutlinedButton.icon(
              icon: exportState.isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_outlined),
              label: Text(l10n.designExportShareButton),
              onPressed: exportState.isSharing
                  ? null
                  : () => _handleShare(
                      context,
                      config,
                      creationState,
                      designText,
                      shape,
                      exportState,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveDesignText(DesignCreationState state, AppLocalizations l10n) {
    return state.pendingInput?.kanji?.value ??
        state.pendingInput?.rawName ??
        state.nameDraft?.combined ??
        l10n.designEditorFallbackText;
  }

  Future<void> _handleExport(
    BuildContext context,
    DesignEditorConfig config,
    DesignCreationState creationState,
    String designText,
    DesignShape shape,
    DesignExportState exportState,
  ) async {
    final controller = ref.read(designExportControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hasPermission = await ref
        .read(designCreationControllerProvider.notifier)
        .ensureStoragePermission();
    if (!hasPermission) {
      controller.failProcessing(l10n.designExportPermissionDenied);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designExportPermissionDenied)),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    // ignore: use_build_context_synchronously
    final destination = await _selectDestination(context, l10n);
    if (!mounted) {
      return;
    }
    if (destination == null) {
      return;
    }

    controller.beginProcessing();
    try {
      final format = exportState.format;
      final bytes = await _renderBytes(
        format: format,
        config: config,
        shape: shape,
        designText: designText,
        transparentBackground: exportState.transparentBackground,
        includeBleed: exportState.includeBleed,
        includeMetadata: exportState.includeMetadata,
        creationState: creationState,
      );
      final directory = await _resolveDirectory(destination);
      final fileName = _buildFileName(creationState, format);
      final file = await _writeBytes(directory, fileName, bytes);
      String? metadataPath;
      if (exportState.includeMetadata) {
        final metadata = _metadataSnapshot(
          creationState: creationState,
          format: format,
          transparentBackground: exportState.transparentBackground,
          includeBleed: exportState.includeBleed,
        );
        metadataPath = await _writeMetadata(directory, fileName, metadata);
      }

      final result = DesignExportResult(
        format: format,
        filePath: file.path,
        generatedAt: DateTime.now(),
        metadataPath: metadataPath,
        options: DesignExportOptionsSnapshot(
          transparentBackground: exportState.transparentBackground,
          includeBleed: exportState.includeBleed,
          includeMetadata: exportState.includeMetadata,
        ),
      );

      controller.completeProcessing(result);

      final analytics = ref.read(analyticsControllerProvider.notifier);
      await analytics.logEvent(
        DesignExportedEvent(
          designId: creationState.pendingInput?.rawName ?? 'draft',
          format: format.extension,
        ),
      );

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designExportExportSuccess(file.path))),
      );
      if (metadataPath != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.designExportMetadataSaved(metadataPath))),
        );
      }
    } on UnsupportedError {
      controller.failProcessing(l10n.designExportPdfUnavailable);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designExportPdfUnavailable)),
      );
    } catch (error) {
      controller.failProcessing(l10n.designExportGenericError);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designExportGenericError)),
      );
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    DesignEditorConfig config,
    DesignCreationState creationState,
    String designText,
    DesignShape shape,
    DesignExportState exportState,
  ) async {
    final controller = ref.read(designExportControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hasPermission = await ref
        .read(designCreationControllerProvider.notifier)
        .ensureStoragePermission();
    if (!hasPermission) {
      controller.failSharing(l10n.designExportPermissionDenied);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designExportPermissionDenied)),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    controller.beginSharing();
    try {
      final pngBytes = await _renderPng(
        config: config,
        shape: shape,
        designText: designText,
        transparentBackground: exportState.transparentBackground,
        includeBleed: exportState.includeBleed,
        applyWatermark: exportState.watermarkOnShare,
      );
      final tempDir = await getTemporaryDirectory();
      final fileName = '${_sanitizedDesignId(creationState)}-share.png';
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsBytes(pngBytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: fileName)],
        subject: l10n.designExportShareSubject,
        text: l10n.designExportShareBody,
      );
      controller.completeSharing(DateTime.now());
    } catch (error) {
      controller.failSharing(l10n.designExportShareError);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designExportShareError)),
      );
    }
  }

  Future<_ExportDestination?> _selectDestination(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final destination = await showModalBottomSheet<_ExportDestination>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _DestinationSheet(l10n: l10n);
      },
    );
    return destination;
  }

  Future<Directory> _resolveDirectory(_ExportDestination? destination) async {
    switch (destination) {
      case _ExportDestination.downloads:
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          return downloads;
        }
        if (Platform.isAndroid) {
          final fallback = Directory('/storage/emulated/0/Download');
          if (fallback.existsSync()) {
            return fallback;
          }
        }
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          final home = Platform.environment['HOME'];
          if (home != null) {
            final candidate = Directory(p.join(home, 'Downloads'));
            if (candidate.existsSync()) {
              return candidate;
            }
          }
        }
        return await getApplicationDocumentsDirectory();
      case _ExportDestination.appDocuments:
      case null:
        return await getApplicationDocumentsDirectory();
    }
  }

  Future<Uint8List> _renderBytes({
    required DesignExportFormat format,
    required DesignEditorConfig config,
    required DesignShape shape,
    required String designText,
    required bool transparentBackground,
    required bool includeBleed,
    required bool includeMetadata,
    required DesignCreationState creationState,
  }) async {
    switch (format) {
      case DesignExportFormat.png:
        return _renderPng(
          config: config,
          shape: shape,
          designText: designText,
          transparentBackground: transparentBackground,
          includeBleed: includeBleed,
        );
      case DesignExportFormat.svg:
        final svg = _renderSvg(
          config: config,
          shape: shape,
          designText: designText,
          transparentBackground: transparentBackground,
          includeBleed: includeBleed,
          includeMetadata: includeMetadata,
          creationState: creationState,
        );
        return Uint8List.fromList(utf8.encode(svg));
      case DesignExportFormat.pdf:
        throw UnsupportedError('PDF export is not implemented yet.');
    }
  }

  Future<File> _writeBytes(
    Directory directory,
    String fileName,
    Uint8List data,
  ) async {
    final file = File(p.join(directory.path, fileName));
    await file.create(recursive: true);
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  Future<String?> _writeMetadata(
    Directory directory,
    String fileName,
    Map<String, Object?> metadata,
  ) async {
    final base = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final metadataFile = File(p.join(directory.path, '${base}_meta.json'));
    await metadataFile.create(recursive: true);
    await metadataFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
      flush: true,
    );
    return metadataFile.path;
  }

  Future<Uint8List> _renderPng({
    required DesignEditorConfig config,
    required DesignShape shape,
    required String designText,
    required bool transparentBackground,
    required bool includeBleed,
    bool applyWatermark = false,
  }) async {
    final bleedPadding = includeBleed
        ? _kBaseExportExtent * _kBleedFraction
        : 0;
    final totalExtent = _kBaseExportExtent + (bleedPadding * 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, totalExtent, totalExtent),
    );

    if (!transparentBackground) {
      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalExtent, totalExtent),
        backgroundPaint,
      );
    }

    final painter = DesignCanvasPainter(
      config: config,
      shape: shape,
      primaryText: designText,
      strokeColor: Colors.black,
      gridColor: Colors.transparent,
      fillColor: Colors.white,
      textStyle: _exportTextStyle(designText, totalExtent),
      drawContainer: false,
      framePaddingFactor: 0,
      shapeFillOpacity: 1,
      containerFillOpacity: 0,
      outlineOpacity: 0,
      strokeScale: totalExtent / 320,
      marginScale: totalExtent / 320,
    );

    painter.paint(canvas, Size(totalExtent, totalExtent));

    if (applyWatermark) {
      _paintWatermark(canvas, Size(totalExtent, totalExtent));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      totalExtent.round(),
      totalExtent.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  String _renderSvg({
    required DesignEditorConfig config,
    required DesignShape shape,
    required String designText,
    required bool transparentBackground,
    required bool includeBleed,
    required bool includeMetadata,
    required DesignCreationState creationState,
  }) {
    final bleedPadding = includeBleed
        ? _kBaseExportExtent * _kBleedFraction
        : 0;
    final totalExtent = _kBaseExportExtent + (bleedPadding * 2);
    const double frameSize = _kBaseExportExtent;
    final margin = _calculateMargin(frameSize, config, totalExtent / 320);
    final contentSize = frameSize - (margin * 2);
    final center = totalExtent / 2;
    final strokeWidth = config.strokeWidth * (totalExtent / 320);
    final fontSize = totalExtent * 0.18;
    final letterSpacing =
        _letterSpacingForText(designText) * (totalExtent / 320);
    final buffer = StringBuffer()
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="$totalExtent" height="$totalExtent" viewBox="0 0 $totalExtent $totalExtent">',
      );

    if (!transparentBackground) {
      buffer.writeln('<rect width="100%" height="100%" fill="#FFFFFF" />');
    }

    switch (shape) {
      case DesignShape.round:
        buffer.writeln(
          '<circle cx="$center" cy="$center" r="${contentSize / 2}" fill="#FFFFFF" stroke="#111111" stroke-width="$strokeWidth" />',
        );
      case DesignShape.square:
        final corner = contentSize * _kSvgCornerRadiusFactor;
        buffer.writeln(
          '<rect x="${center - contentSize / 2}" y="${center - contentSize / 2}" width="$contentSize" height="$contentSize" rx="$corner" ry="$corner" fill="#FFFFFF" stroke="#111111" stroke-width="$strokeWidth" />',
        );
    }

    if (designText.trim().isNotEmpty) {
      final offset = _alignmentOffsetSvg(contentSize, config.alignment);
      final rotation = config.rotation;
      final textX = center + offset.dx;
      final textY = center + offset.dy;
      final rotationAttr = rotation == 0
          ? ''
          : ' transform="rotate($rotation $textX $textY)"';
      buffer.writeln(
        '<text x="$textX" y="$textY" fill="#111111" font-family="sans-serif" font-size="$fontSize" letter-spacing="$letterSpacing" text-anchor="middle" dominant-baseline="middle"$rotationAttr>${_escapeSvgText(designText)}</text>',
      );
    }

    if (includeMetadata) {
      final metadata = _metadataSnapshot(
        creationState: creationState,
        format: DesignExportFormat.svg,
        transparentBackground: transparentBackground,
        includeBleed: includeBleed,
      );
      buffer.writeln('<metadata>${jsonEncode(metadata)}</metadata>');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  double _calculateMargin(
    double frameSize,
    DesignEditorConfig config,
    double scale,
  ) {
    final normalized = (config.margin / _kMarginNormalizationFactor).clamp(
      0,
      1,
    );
    final relativeCap = frameSize * _kMarginRelativeCap;
    final absoluteCap = frameSize / 2 - (_kMarginSafetyInset * scale);
    return max(0, min(absoluteCap, relativeCap * normalized));
  }

  TextStyle _exportTextStyle(String text, double extent) {
    final scale = extent / 320;
    final baseSpacing = _letterSpacingForText(text);
    return TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.w600,
      fontSize: extent * 0.18,
      letterSpacing: baseSpacing * scale,
    );
  }

  double _letterSpacingForText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final containsCjk = trimmed.runes.any(_isCjkCodePoint);
    return containsCjk
        ? AppTokens.designPreviewLetterSpacingKanji
        : AppTokens.designPreviewLetterSpacingLatin;
  }

  bool _isCjkCodePoint(int codePoint) {
    return (codePoint >= 0x3000 && codePoint <= 0x30FF) ||
        (codePoint >= 0x3400 && codePoint <= 0x9FFF) ||
        (codePoint >= 0xF900 && codePoint <= 0xFAFF) ||
        (codePoint >= 0xFF66 && codePoint <= 0xFF9D);
  }

  Offset _alignmentOffsetSvg(
    double contentSize,
    DesignCanvasAlignment alignment,
  ) {
    switch (alignment) {
      case DesignCanvasAlignment.center:
        return Offset.zero;
      case DesignCanvasAlignment.top:
        return Offset(0, -contentSize / 4);
      case DesignCanvasAlignment.bottom:
        return Offset(0, contentSize / 4);
      case DesignCanvasAlignment.left:
        return Offset(-contentSize / 4, 0);
      case DesignCanvasAlignment.right:
        return Offset(contentSize / 4, 0);
    }
  }

  void _paintWatermark(Canvas canvas, Size size) {
    const watermark = 'Hanko Field';
    final textPainter = TextPainter(
      text: TextSpan(
        text: watermark,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.3),
          fontWeight: FontWeight.w600,
          fontSize: size.shortestSide * 0.06,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padding = size.shortestSide * 0.04;
    final offset = Offset(
      size.width - textPainter.width - padding,
      size.height - textPainter.height - padding,
    );
    final background = Paint()..color = Colors.white.withValues(alpha: 0.5);
    final rect = Rect.fromLTWH(
      offset.dx - padding / 3,
      offset.dy - padding / 6,
      textPainter.width + padding * 0.66,
      textPainter.height + padding / 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(padding / 4)),
      background,
    );
    textPainter.paint(canvas, offset);
  }

  Map<String, Object?> _metadataSnapshot({
    required DesignCreationState creationState,
    required DesignExportFormat format,
    required bool transparentBackground,
    required bool includeBleed,
  }) {
    return {
      'generated_at': DateTime.now().toIso8601String(),
      'format': format.extension,
      'design_text': creationState.pendingInput?.rawName ?? 'draft',
      'transparent_background': transparentBackground,
      'include_bleed': includeBleed,
      'writing_style': creationState.styleDraft?.writing.name,
      'template_ref': creationState.styleDraft?.templateRef,
      'shape': creationState.selectedShape?.name,
    };
  }

  String _buildFileName(
    DesignCreationState creationState,
    DesignExportFormat format,
  ) {
    final base = _sanitizedDesignId(creationState);
    return '$base.${format.extension}';
  }

  String _sanitizedDesignId(DesignCreationState creationState) {
    final raw = creationState.pendingInput?.rawName ?? 'design';
    final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
    return sanitized.isEmpty ? 'design' : sanitized.toLowerCase();
  }

  String _escapeSvgText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  Future<void> _showHistorySheet(
    BuildContext context,
    DesignExportState state,
    AppLocalizations l10n,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final result = state.lastResult;
        if (result == null) {
          return _HistorySheet.empty(l10n: l10n);
        }
        return _HistorySheet(result: result, l10n: l10n);
      },
    );
  }
}

enum _ExportDestination { downloads, appDocuments }

class _ExportPreview extends StatelessWidget {
  const _ExportPreview({
    required this.boundaryKey,
    required this.config,
    required this.shape,
    required this.designText,
    required this.transparentBackground,
    required this.includeBleed,
    required this.l10n,
  });

  final GlobalKey boundaryKey;
  final DesignEditorConfig config;
  final DesignShape shape;
  final String designText;
  final bool transparentBackground;
  final bool includeBleed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bleedPadding = includeBleed ? AppTokens.spaceL : 0.0;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.designExportPreviewLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.spaceM),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                padding: EdgeInsets.all(bleedPadding),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (transparentBackground) const _TransparentBackdrop(),
                    DesignCanvasPreview(
                      config: config,
                      shape: shape,
                      primaryText: designText,
                      boundaryKey: boundaryKey,
                      drawContainer: false,
                      outerPadding: EdgeInsets.zero,
                      strokeColor: Colors.black,
                      gridColor: Colors.transparent,
                      fillColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransparentBackdrop extends StatelessWidget {
  const _TransparentBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CheckerPainter());
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tile = 18.0;
    final light = Colors.grey.shade200;
    final dark = Colors.grey.shade300;
    final paint = Paint();
    for (var y = 0; y <= size.height / tile; y++) {
      for (var x = 0; x <= size.width / tile; x++) {
        paint.color = (x + y).isEven ? light : dark;
        canvas.drawRect(Rect.fromLTWH(x * tile, y * tile, tile, tile), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter oldDelegate) => false;
}

class _FormatSelector extends ConsumerWidget {
  const _FormatSelector({required this.state, required this.l10n});

  final DesignExportState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(designExportControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.designExportFormatLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        SegmentedButton<DesignExportFormat>(
          segments: [
            ButtonSegment(
              value: DesignExportFormat.png,
              label: Text(l10n.designExportFormatPng),
              icon: const Icon(Icons.image_outlined),
            ),
            ButtonSegment(
              value: DesignExportFormat.svg,
              label: Text(l10n.designExportFormatSvg),
              icon: const Icon(Icons.layers_outlined),
            ),
            ButtonSegment(
              value: DesignExportFormat.pdf,
              label: Text(l10n.designExportFormatPdf),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          selected: {state.format},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }
            controller.selectFormat(selection.first);
          },
        ),
      ],
    );
  }
}

class _ExportOptions extends ConsumerWidget {
  const _ExportOptions({required this.state, required this.l10n});

  final DesignExportState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(designExportControllerProvider.notifier);
    return Column(
      children: [
        _OptionTile(
          title: l10n.designExportOptionTransparent,
          subtitle: l10n.designExportOptionTransparentSubtitle,
          value: state.transparentBackground,
          onChanged: controller.toggleTransparentBackground,
        ),
        _OptionTile(
          title: l10n.designExportOptionBleed,
          subtitle: l10n.designExportOptionBleedSubtitle,
          value: state.includeBleed,
          onChanged: controller.toggleBleed,
        ),
        _OptionTile(
          title: l10n.designExportOptionMetadata,
          subtitle: l10n.designExportOptionMetadataSubtitle,
          value: state.includeMetadata,
          onChanged: controller.toggleMetadata,
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: AppTokens.radiusM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationSheet extends StatelessWidget {
  const _DestinationSheet({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.spaceL,
          horizontal: AppTokens.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.designExportDestinationTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceM),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.designExportDestinationDownloads),
              onTap: () =>
                  Navigator.of(context).pop(_ExportDestination.downloads),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(l10n.designExportDestinationAppStorage),
              onTap: () =>
                  Navigator.of(context).pop(_ExportDestination.appDocuments),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.result, required this.l10n});

  const _HistorySheet.empty({required this.l10n}) : result = null;

  final DesignExportResult? result;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Text(l10n.designExportHistoryEmpty),
        ),
      );
    }

    final export = result!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.designExportHistoryTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceM),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(p.basename(export.filePath)),
              subtitle: Text(
                l10n.designExportHistorySubtitle(
                  export.format.extension.toUpperCase(),
                  export.generatedAt.toLocal().toString(),
                ),
              ),
            ),
            if (export.metadataPath != null)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(p.basename(export.metadataPath!)),
                subtitle: Text(export.metadataPath!),
              ),
          ],
        ),
      ),
    );
  }
}
