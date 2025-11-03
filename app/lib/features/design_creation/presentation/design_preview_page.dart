import 'dart:math';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/design_editor_controller.dart';
import 'package:app/features/design_creation/application/design_editor_state.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/features/design_creation/presentation/widgets/design_canvas_preview.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _PreviewBackground { paper, wood, transparent }

enum _LightingPreset { none, soft, studio }

class DesignPreviewPage extends ConsumerStatefulWidget {
  const DesignPreviewPage({super.key});

  @override
  ConsumerState<DesignPreviewPage> createState() => _DesignPreviewPageState();
}

class _DesignPreviewPageState extends ConsumerState<DesignPreviewPage> {
  static const double _defaultRoundSizeMm = 18;
  static const double _defaultSquareSizeMm = 21;
  static const double _mmToLogicalPx = 160 / 25.4;

  _PreviewBackground _background = _PreviewBackground.paper;
  _LightingPreset _lighting = _LightingPreset.soft;
  bool _showMeasurements = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final creationState = ref.watch(designCreationControllerProvider);
    final config = ref.watch(
      designEditorControllerProvider.select((value) => value.config),
    );
    final designText = _resolveDesignText(creationState, l10n);
    final shape = creationState.selectedShape ?? DesignShape.round;

    if (!creationState.hasStyleSelection ||
        creationState.pendingInput == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.designPreviewTitle)),
        body: _MissingSelectionState(
          message: l10n.designPreviewMissingSelection,
        ),
      );
    }

    final sizeMm = _effectiveSizeMm(shape);
    final logicalExtent = sizeMm * _mmToLogicalPx;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designPreviewTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: l10n.designPreviewShareTooltip,
            onPressed: () => ref
                .read(appStateProvider.notifier)
                .push(CreationStageRoute(const ['share'])),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.designPreviewEditTooltip,
            onPressed: () => ref.read(appStateProvider.notifier).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 840;
            final content = _PreviewContent(
              background: _background,
              lighting: _lighting,
              showMeasurements: _showMeasurements,
              logicalExtent: logicalExtent,
              sizeMm: sizeMm,
              config: config,
              designText: designText,
              shape: shape,
              onBackgroundChanged: _handleBackgroundChange,
              onLightingChanged: _handleLightingChange,
              onToggleMeasurements: _handleToggleMeasurements,
            );
            if (isWide) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spaceL,
                  horizontal: AppTokens.spaceXXL,
                ),
                child: content,
              );
            }
            return Padding(
              padding: const EdgeInsets.all(AppTokens.spaceL),
              child: content,
            );
          },
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
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.designPreviewExportCta),
              onPressed: () => ref
                  .read(appStateProvider.notifier)
                  .push(CreationStageRoute(const ['export'])),
            ),
            const SizedBox(height: AppTokens.spaceM),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(l10n.designPreviewBackToEditor),
              onPressed: () => ref.read(appStateProvider.notifier).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBackgroundChange(_PreviewBackground background) {
    setState(() {
      _background = background;
    });
  }

  void _handleLightingChange(_LightingPreset preset) {
    setState(() {
      _lighting = preset;
    });
  }

  void _handleToggleMeasurements(bool value) {
    setState(() {
      _showMeasurements = value;
    });
  }

  double _effectiveSizeMm(DesignShape shape) {
    return switch (shape) {
      DesignShape.round => _defaultRoundSizeMm,
      DesignShape.square => _defaultSquareSizeMm,
    };
  }

  String _resolveDesignText(DesignCreationState state, AppLocalizations l10n) {
    return state.pendingInput?.kanji?.value ??
        state.pendingInput?.rawName ??
        state.nameDraft?.combined ??
        l10n.designEditorFallbackText;
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.background,
    required this.lighting,
    required this.showMeasurements,
    required this.logicalExtent,
    required this.sizeMm,
    required this.config,
    required this.designText,
    required this.shape,
    required this.onBackgroundChanged,
    required this.onLightingChanged,
    required this.onToggleMeasurements,
  });

  final _PreviewBackground background;
  final _LightingPreset lighting;
  final bool showMeasurements;
  final double logicalExtent;
  final double sizeMm;
  final DesignEditorConfig config;
  final String designText;
  final DesignShape shape;
  final ValueChanged<_PreviewBackground> onBackgroundChanged;
  final ValueChanged<_LightingPreset> onLightingChanged;
  final ValueChanged<bool> onToggleMeasurements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final preview = Expanded(
      child: _ActualSizePreview(
        logicalExtent: logicalExtent,
        sizeMm: sizeMm,
        config: config,
        designText: designText,
        shape: shape,
        background: background,
        lighting: lighting,
        showMeasurements: showMeasurements,
      ),
    );
    final controls = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.designPreviewActualSizeLabel(
              sizeMm.toStringAsFixed(1),
              (sizeMm / 25.4).toStringAsFixed(2),
            ),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.designPreviewActualSizeHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            l10n.designPreviewBackgroundLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppTokens.spaceS),
          SegmentedButton<_PreviewBackground>(
            segments: [
              ButtonSegment(
                value: _PreviewBackground.paper,
                label: Text(l10n.designPreviewBackgroundPaper),
                icon: const Icon(Icons.texture),
              ),
              ButtonSegment(
                value: _PreviewBackground.wood,
                label: Text(l10n.designPreviewBackgroundWood),
                icon: const Icon(Icons.park_outlined),
              ),
              ButtonSegment(
                value: _PreviewBackground.transparent,
                label: Text(l10n.designPreviewBackgroundTransparent),
                icon: const Icon(Icons.grid_on),
              ),
            ],
            selected: {background},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onBackgroundChanged(selection.first);
              }
            },
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            l10n.designPreviewLightingLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: [
              _LightingChip(
                preset: _LightingPreset.none,
                label: l10n.designPreviewLightingNone,
                selected: lighting == _LightingPreset.none,
                onSelected: onLightingChanged,
              ),
              _LightingChip(
                preset: _LightingPreset.soft,
                label: l10n.designPreviewLightingSoft,
                selected: lighting == _LightingPreset.soft,
                onSelected: onLightingChanged,
              ),
              _LightingChip(
                preset: _LightingPreset.studio,
                label: l10n.designPreviewLightingStudio,
                selected: lighting == _LightingPreset.studio,
                onSelected: onLightingChanged,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceL),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: showMeasurements,
            onChanged: onToggleMeasurements,
            title: Text(l10n.designPreviewMeasurementToggle),
            subtitle: Text(
              l10n.designPreviewMeasurementHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          preview,
          const SizedBox(width: AppTokens.spaceXL),
          SizedBox(
            width: min(MediaQuery.sizeOf(context).width * 0.32, 420),
            child: controls,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        preview,
        const SizedBox(height: AppTokens.spaceXL),
        controls,
      ],
    );
  }
}

class _ActualSizePreview extends StatelessWidget {
  const _ActualSizePreview({
    required this.logicalExtent,
    required this.sizeMm,
    required this.config,
    required this.designText,
    required this.shape,
    required this.background,
    required this.lighting,
    required this.showMeasurements,
  });

  final double logicalExtent;
  final double sizeMm;
  final DesignEditorConfig config;
  final String designText;
  final DesignShape shape;
  final _PreviewBackground background;
  final _LightingPreset lighting;
  final bool showMeasurements;

  static const double _padding = AppTokens.spaceXXL;

  @override
  Widget build(BuildContext context) {
    final extentWithPadding = logicalExtent + (_padding * 2);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainer,
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Center(
          child: InteractiveViewer(
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(240),
            child: SizedBox(
              width: max(extentWithPadding, logicalExtent + 120),
              height: max(extentWithPadding, logicalExtent + 120),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _BackgroundSurface(
                    extent: logicalExtent,
                    background: background,
                    lighting: lighting,
                  ),
                  SizedBox(
                    width: logicalExtent,
                    height: logicalExtent,
                    child: DesignCanvasPreview(
                      config: config,
                      shape: shape,
                      primaryText: designText,
                    ),
                  ),
                  if (showMeasurements)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _MeasurementOverlay(
                          designExtent: logicalExtent,
                          sizeMm: sizeMm,
                          accentColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundSurface extends StatelessWidget {
  const _BackgroundSurface({
    required this.extent,
    required this.background,
    required this.lighting,
  });

  final double extent;
  final _PreviewBackground background;
  final _LightingPreset lighting;

  @override
  Widget build(BuildContext context) {
    final baseDecoration = switch (background) {
      _PreviewBackground.paper => BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade200, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _PreviewBackground.wood => const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8D6E63), Color(0xFF6D4C41)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      _PreviewBackground.transparent => const BoxDecoration(
        color: Colors.transparent,
      ),
    };

    final lightingOverlay = switch (lighting) {
      _LightingPreset.none => null,
      _LightingPreset.soft => BoxDecoration(
        gradient: RadialGradient(
          radius: 1.1,
          center: Alignment.topLeft,
          colors: [Colors.white.withAlpha(153), Colors.transparent],
          stops: const [0, 1],
        ),
      ),
      _LightingPreset.studio => BoxDecoration(
        gradient: SweepGradient(
          colors: [
            Colors.white.withAlpha(140),
            Colors.transparent,
            Colors.black.withAlpha(64),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.6, 1],
        ),
      ),
    };

    return SizedBox(
      width: extent + AppTokens.spaceXXL,
      height: extent + AppTokens.spaceXXL,
      child: DecoratedBox(
        decoration: baseDecoration.copyWith(
          gradient: background == _PreviewBackground.transparent
              ? null
              : baseDecoration.gradient,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (background == _PreviewBackground.transparent)
              const _TransparentPattern(),
            if (lightingOverlay != null)
              DecoratedBox(decoration: lightingOverlay),
          ],
        ),
      ),
    );
  }
}

class _TransparentPattern extends StatelessWidget {
  const _TransparentPattern();

  static const double _tileSize = 18;

  @override
  Widget build(BuildContext context) {
    final light = Colors.grey.shade300;
    final dark = Colors.grey.shade200;
    return CustomPaint(
      painter: _CheckerPainter(light: light, dark: dark),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  _CheckerPainter({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const tile = _TransparentPattern._tileSize;
    for (var y = 0; y < size.height / tile + 1; y++) {
      for (var x = 0; x < size.width / tile + 1; x++) {
        paint.color = (x + y).isEven ? light : dark;
        canvas.drawRect(Rect.fromLTWH(x * tile, y * tile, tile, tile), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter oldDelegate) {
    return oldDelegate.light != light || oldDelegate.dark != dark;
  }
}

class _MeasurementOverlay extends StatelessWidget {
  const _MeasurementOverlay({
    required this.designExtent,
    required this.sizeMm,
    required this.accentColor,
  });

  final double designExtent;
  final double sizeMm;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MeasurementPainter(
        designExtent: designExtent,
        sizeMm: sizeMm,
        accentColor: accentColor,
      ),
    );
  }
}

class _MeasurementPainter extends CustomPainter {
  _MeasurementPainter({
    required this.designExtent,
    required this.sizeMm,
    required this.accentColor,
  });

  final double designExtent;
  final double sizeMm;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withAlpha(204)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final horizontalLeft = (size.width - designExtent) / 2;
    final horizontalRight = horizontalLeft + designExtent;
    final verticalTop = (size.height - designExtent) / 2;
    final verticalBottom = verticalTop + designExtent;

    final horizontalY = verticalBottom + 32;
    final verticalX = horizontalLeft - 32;

    _drawDimensionLine(
      canvas,
      Offset(horizontalLeft, horizontalY),
      Offset(horizontalRight, horizontalY),
      paint,
    );
    _drawArrowHead(canvas, Offset(horizontalLeft, horizontalY), true, paint);
    _drawArrowHead(canvas, Offset(horizontalRight, horizontalY), false, paint);

    _drawDimensionLine(
      canvas,
      Offset(verticalX, verticalTop),
      Offset(verticalX, verticalBottom),
      paint,
    );
    _drawArrowHead(
      canvas,
      Offset(verticalX, verticalTop),
      true,
      paint,
      vertical: true,
    );
    _drawArrowHead(
      canvas,
      Offset(verticalX, verticalBottom),
      false,
      paint,
      vertical: true,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text:
            '${sizeMm.toStringAsFixed(1)} mm · ${(sizeMm / 25.4).toStringAsFixed(2)} in',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      horizontalY - textPainter.height - 8,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        textOffset.dx - 8,
        textOffset.dy - 4,
        textPainter.width + 16,
        textPainter.height + 8,
      ),
      Paint()
        ..color = const Color(0xFFFDFDFD).withAlpha(230)
        ..style = PaintingStyle.fill,
    );
    textPainter.paint(canvas, textOffset);

    final verticalLabel = TextPainter(
      text: TextSpan(
        text: '${sizeMm.toStringAsFixed(1)} mm',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    verticalLabel.layout(maxWidth: 120);
    canvas.save();
    canvas.translate(verticalX - 36, (verticalTop + verticalBottom) / 2);
    canvas.rotate(-pi / 2);
    verticalLabel.paint(
      canvas,
      Offset(-verticalLabel.width / 2, -verticalLabel.height / 2),
    );
    canvas.restore();
  }

  void _drawDimensionLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    canvas.drawLine(start, end, paint);
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset point,
    bool isStart,
    Paint paint, {
    bool vertical = false,
  }) {
    const double size = 8;
    late Offset dirA;
    late Offset dirB;
    if (vertical) {
      dirA = Offset(size, isStart ? size : -size);
      dirB = Offset(-size, isStart ? size : -size);
    } else {
      dirA = Offset(isStart ? size : -size, size);
      dirB = Offset(isStart ? size : -size, -size);
    }
    canvas.drawLine(point, point + dirA, paint);
    canvas.drawLine(point, point + dirB, paint);
  }

  @override
  bool shouldRepaint(covariant _MeasurementPainter oldDelegate) {
    return oldDelegate.designExtent != designExtent ||
        oldDelegate.sizeMm != sizeMm ||
        oldDelegate.accentColor != accentColor;
  }
}

class _LightingChip extends StatelessWidget {
  const _LightingChip({
    required this.preset,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final _LightingPreset preset;
  final String label;
  final bool selected;
  final ValueChanged<_LightingPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(preset),
      showCheckmark: false,
      avatar: selected ? const Icon(Icons.check, size: 18) : null,
    );
  }
}

class _MissingSelectionState extends StatelessWidget {
  const _MissingSelectionState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
