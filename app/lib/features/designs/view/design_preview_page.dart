// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignPreviewPage extends ConsumerStatefulWidget {
  const DesignPreviewPage({super.key});

  @override
  ConsumerState<DesignPreviewPage> createState() => _DesignPreviewPageState();
}

class _DesignPreviewPageState extends ConsumerState<DesignPreviewPage> {
  final TransformationController _controller = TransformationController();
  PreviewBackground _background = PreviewBackground.paper;
  PreviewLighting _lighting = PreviewLighting.soft;
  Set<PreviewTexture> _textures = {PreviewTexture.fibers};
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final next = _controller.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() > 0.01) {
      setState(() => _scale = next);
    }
  }

  void _setScale(double value) {
    setState(() {
      _scale = value;
      _controller.value = Matrix4.diagonal3Values(value, value, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final creation = ref.watch(designCreationViewModel);
    final editor = ref.watch(designEditorViewModel);
    final preview = _resolvePreviewData(
      creation: creation,
      editor: editor,
      prefersEnglish: prefersEnglish,
    );

    final isLoading = _isLoading(creation, editor);
    final hasError =
        preview == null &&
        (creation is AsyncError<DesignCreationState> ||
            editor is AsyncError<DesignEditorState>);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _PreviewAppBar(
        prefersEnglish: prefersEnglish,
        subtitle: preview == null
            ? null
            : '${preview.sizeMm.toStringAsFixed(1)}mm • ${_background.label(prefersEnglish)}',
        onShare: () => _showToast(
          context,
          prefersEnglish ? 'Sharing preview…' : 'プレビューを共有します（モック）',
        ),
        onEdit: () => context.go(AppRoutePaths.designEditor),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (hasError) {
              final message = (creation is AsyncError<DesignCreationState>)
                  ? creation.error.toString()
                  : (editor is AsyncError<DesignEditorState>)
                  ? editor.error.toString()
                  : (prefersEnglish
                        ? 'Failed to load preview'
                        : 'プレビューの読み込みに失敗しました');
              return _ErrorContent(
                message: message,
                prefersEnglish: prefersEnglish,
                onRetry: () {
                  ref.invalidate(designCreationViewModel);
                  ref.invalidate(designEditorViewModel);
                },
              );
            }

            if (preview == null || isLoading) {
              return Padding(
                padding: EdgeInsets.all(tokens.spacing.lg),
                child: const AppSkeletonBlock(height: 320),
              );
            }

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.lg,
                tokens.spacing.md,
                tokens.spacing.lg,
                tokens.spacing.xxl + tokens.spacing.md,
              ),
              children: [
                _PreviewHeadline(
                  preview: preview,
                  prefersEnglish: prefersEnglish,
                  background: _background,
                  lighting: _lighting,
                ),
                SizedBox(height: tokens.spacing.lg),
                _PreviewCanvasCard(
                  preview: preview,
                  background: _background,
                  lighting: _lighting,
                  textures: _textures,
                  scale: _scale,
                  prefersEnglish: prefersEnglish,
                  controller: _controller,
                  onScaleChanged: _setScale,
                  onShare: () => _showToast(
                    context,
                    prefersEnglish
                        ? 'Share sheet opened (mock)'
                        : '共有シートを開きました（モック）',
                  ),
                ),
                SizedBox(height: tokens.spacing.lg),
                _BackgroundControls(
                  background: _background,
                  lighting: _lighting,
                  textures: _textures,
                  prefersEnglish: prefersEnglish,
                  onBackgroundChanged: (next) =>
                      setState(() => _background = next),
                  onLightingChanged: (next) => setState(() => _lighting = next),
                  onToggleTexture: (texture) => setState(() {
                    final next = Set<PreviewTexture>.from(_textures);
                    if (next.contains(texture)) {
                      next.remove(texture);
                    } else {
                      next.add(texture);
                    }
                    _textures = next;
                  }),
                ),
                SizedBox(height: tokens.spacing.lg),
                _ReadinessCard(
                  preview: preview,
                  prefersEnglish: prefersEnglish,
                  onOpenCheck: () => context.go(AppRoutePaths.designCheck),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: preview == null
          ? null
          : _PreviewActions(
              prefersEnglish: prefersEnglish,
              onExport: () => context.go(AppRoutePaths.designExport),
              onEdit: () => context.go(AppRoutePaths.designEditor),
            ),
    );
  }

  bool _isLoading(
    AsyncValue<DesignCreationState> creation,
    AsyncValue<DesignEditorState> editor,
  ) {
    final creationLoading =
        creation is AsyncLoading<DesignCreationState> &&
        creation.valueOrNull == null;
    final editorLoading =
        editor is AsyncLoading<DesignEditorState> && editor.valueOrNull == null;
    return creationLoading || editorLoading;
  }

  PreviewData? _resolvePreviewData({
    required AsyncValue<DesignCreationState> creation,
    required AsyncValue<DesignEditorState> editor,
    required bool prefersEnglish,
  }) {
    final creationState = creation.valueOrNull;
    final editorState = editor.valueOrNull;

    if (creationState == null && editorState == null) return null;

    final rawName = creationState?.savedInput?.rawName.trim();
    final nameDraft =
        creationState?.nameDraft.fullName(prefersEnglish: prefersEnglish) ??
        (prefersEnglish ? 'Taro Yamada' : '山田太郎');
    final displayName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : nameDraft;

    final shape = creationState?.selectedShape ?? editorState?.shape;
    final writing =
        creationState?.selectedStyle?.writing ??
        creationState?.previewStyle ??
        editorState?.writingStyle ??
        WritingStyle.tensho;
    final sizeMm =
        editorState?.sizeMm ?? creationState?.selectedSize?.mm ?? 15.0;

    return PreviewData(
      displayName: displayName,
      sizeMm: sizeMm,
      writing: writing,
      shape: shape ?? SealShape.round,
      templateName:
          creationState?.selectedTemplate?.name ??
          creationState?.selectedTemplate?.id ??
          editorState?.templateName,
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PreviewAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PreviewAppBar({
    required this.prefersEnglish,
    this.subtitle,
    required this.onShare,
    required this.onEdit,
  });

  final bool prefersEnglish;
  final String? subtitle;
  final VoidCallback onShare;
  final VoidCallback onEdit;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final title = prefersEnglish ? 'Design preview' : 'プレビュー';

    return AppBar(
      leading: const BackButton(),
      titleSpacing: tokens.spacing.md,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: prefersEnglish ? 'Edit' : '編集',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: prefersEnglish ? 'Share' : '共有',
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_rounded),
        ),
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _PreviewHeadline extends StatelessWidget {
  const _PreviewHeadline({
    required this.preview,
    required this.prefersEnglish,
    required this.background,
    required this.lighting,
  });

  final PreviewData preview;
  final bool prefersEnglish;
  final PreviewBackground background;
  final PreviewLighting lighting;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final chips = <Widget>[];
    chips.add(
      _InfoChip(
        icon: Icons.straighten,
        label: '${preview.sizeMm.toStringAsFixed(1)} mm',
      ),
    );
    chips.add(
      _InfoChip(
        icon: Icons.font_download_outlined,
        label: _writingLabel(preview.writing, prefersEnglish),
      ),
    );
    chips.add(
      _InfoChip(icon: Icons.texture, label: background.label(prefersEnglish)),
    );
    chips.add(
      _InfoChip(icon: Icons.wb_twilight, label: lighting.label(prefersEnglish)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview.displayName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: tokens.spacing.xs),
        Wrap(
          spacing: tokens.spacing.xs,
          runSpacing: tokens.spacing.xs,
          children: chips,
        ),
      ],
    );
  }
}

class _PreviewCanvasCard extends StatelessWidget {
  const _PreviewCanvasCard({
    required this.preview,
    required this.background,
    required this.lighting,
    required this.textures,
    required this.scale,
    required this.prefersEnglish,
    required this.controller,
    required this.onScaleChanged,
    required this.onShare,
  });

  final PreviewData preview;
  final PreviewBackground background;
  final PreviewLighting lighting;
  final Set<PreviewTexture> textures;
  final double scale;
  final bool prefersEnglish;
  final TransformationController controller;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final actualSizePx = _mmToLogicalPx(preview.sizeMm);
    final label = preview.displayName.split('').join('\n');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prefersEnglish ? 'Actual size preview' : '実寸プレビュー',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      prefersEnglish
                          ? 'Pinch to zoom. Measurement overlay stays tied to the selected size.'
                          : 'ピンチ操作で拡大縮小。実寸ガイドはサイズに合わせて固定されます。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onShare,
                tooltip: prefersEnglish ? 'Share preview' : 'プレビューを共有',
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Container(
            height: 360,
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              color: tokens.colors.surface,
              borderRadius: BorderRadius.circular(tokens.radii.lg),
              border: Border.all(
                color: tokens.colors.outline.withValues(alpha: 0.4),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.md),
              child: InteractiveViewer(
                transformationController: controller,
                minScale: 0.8,
                maxScale: 3.2,
                boundaryMargin: EdgeInsets.all(tokens.spacing.xl),
                onInteractionUpdate: (_) =>
                    onScaleChanged(controller.value.getMaxScaleOnAxis()),
                child: Center(
                  child: _PreviewSurface(
                    sizePx: actualSizePx,
                    sizeMm: preview.sizeMm,
                    shape: preview.shape,
                    label: label,
                    writing: preview.writing,
                    background: background,
                    lighting: lighting,
                    textures: textures,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Row(
            children: [
              Text(
                prefersEnglish ? 'Scale' : 'スケール',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: Slider(
                  min: 0.8,
                  max: 3.2,
                  value: scale.clamp(0.8, 3.2),
                  divisions: 12,
                  label: '${scale.toStringAsFixed(2)}x',
                  onChanged: onScaleChanged,
                ),
              ),
              TextButton(
                onPressed: () => onScaleChanged(1.0),
                child: Text(prefersEnglish ? 'Actual size' : '実寸'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.sizePx,
    required this.sizeMm,
    required this.shape,
    required this.label,
    required this.writing,
    required this.background,
    required this.lighting,
    required this.textures,
  });

  final double sizePx;
  final double sizeMm;
  final SealShape shape;
  final String label;
  final WritingStyle writing;
  final PreviewBackground background;
  final PreviewLighting lighting;
  final Set<PreviewTexture> textures;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final double canvasSize = math.max(sizePx + 120, 240).toDouble();

    return AnimatedContainer(
      duration: tokens.durations.regular,
      padding: EdgeInsets.all(tokens.spacing.lg),
      width: canvasSize,
      height: canvasSize,
      decoration: BoxDecoration(
        color: background.baseColor(tokens),
        gradient: background.gradient(tokens),
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        border: Border.all(
          color: tokens.colors.outline.withValues(alpha: 0.35),
        ),
        boxShadow: lighting.shadows(tokens),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (background == PreviewBackground.transparent)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CheckerPainter(
                    light: tokens.colors.surface,
                    dark: tokens.colors.surfaceVariant,
                  ),
                ),
              ),
            ),
          if (textures.contains(PreviewTexture.fibers))
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FiberPainter(
                    color: tokens.colors.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          if (textures.contains(PreviewTexture.inkPad))
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),
          if (lighting.overlayColor(tokens) != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      lighting.overlayColor(tokens)!,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          _MeasurementGuides(
            sizePx: sizePx,
            sizeMm: sizeMm,
            color: tokens.colors.onSurface.withValues(alpha: 0.8),
          ),
          _StampMock(
            sizePx: sizePx,
            shape: shape,
            label: label,
            writing: writing,
            color: tokens.colors.primary,
            shadow: textures.contains(PreviewTexture.inkPad),
          ),
        ],
      ),
    );
  }
}

class _StampMock extends StatelessWidget {
  const _StampMock({
    required this.sizePx,
    required this.shape,
    required this.label,
    required this.writing,
    required this.color,
    required this.shadow,
  });

  final double sizePx;
  final SealShape shape;
  final String label;
  final WritingStyle writing;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final radius = shape == SealShape.square ? sizePx * 0.14 : sizePx / 2;

    return AnimatedContainer(
      duration: tokens.durations.regular,
      width: sizePx,
      height: sizePx,
      padding: EdgeInsets.all(sizePx * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape == SealShape.round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape == SealShape.square
            ? BorderRadius.circular(radius)
            : null,
        border: Border.all(
          color: color.withValues(alpha: 0.7),
          width: sizePx * 0.04,
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 6,
                ),
              ]
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: _stampStyle(context, writing).copyWith(color: color),
        ),
      ),
    );
  }
}

class _MeasurementGuides extends StatelessWidget {
  const _MeasurementGuides({
    required this.sizePx,
    required this.sizeMm,
    required this.color,
  });

  final double sizePx;
  final double sizeMm;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Stack(
      children: [
        Align(
          alignment: const Alignment(0, -0.85),
          child: _RulerLine(
            length: sizePx,
            label: '${sizeMm.toStringAsFixed(1)} mm',
            color: color,
          ),
        ),
        Align(
          alignment: const Alignment(-0.9, 0),
          child: RotatedBox(
            quarterTurns: 1,
            child: _RulerLine(
              length: sizePx,
              label: '${sizeMm.toStringAsFixed(1)} mm',
              color: color,
            ),
          ),
        ),
        Positioned(
          bottom: tokens.spacing.sm,
          left: tokens.spacing.sm,
          child: const _InfoChip(icon: Icons.visibility_outlined, label: '1:1'),
        ),
      ],
    );
  }
}

class _RulerLine extends StatelessWidget {
  const _RulerLine({
    required this.length,
    required this.label,
    required this.color,
  });

  final double length;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final width = length + 28;
    return SizedBox(
      width: width,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RulerPainter(color: color)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paint);

    final tickCount = 4;
    for (var i = 0; i <= tickCount; i++) {
      final x = size.width / tickCount * i;
      final tick = i == 0 || i == tickCount ? 8.0 : 6.0;
      canvas.drawLine(
        Offset(x, centerY - tick),
        Offset(x, centerY + tick),
        paint,
      );
    }

    canvas.drawLine(Offset(0, centerY), Offset(8, centerY - 8), paint);
    canvas.drawLine(Offset(0, centerY), Offset(8, centerY + 8), paint);
    canvas.drawLine(
      Offset(size.width, centerY),
      Offset(size.width - 8, centerY - 8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, centerY),
      Offset(size.width - 8, centerY + 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    const square = 14.0;
    final lightPaint = Paint()..color = light;
    final darkPaint = Paint()..color = dark.withValues(alpha: 0.7);

    for (double y = 0; y < size.height; y += square) {
      for (double x = 0; x < size.width; x += square) {
        final isDark = ((x / square).floor() + (y / square).floor()) % 2 == 0;
        final paint = isDark ? darkPaint : lightPaint;
        canvas.drawRect(Rect.fromLTWH(x, y, square, square), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter oldDelegate) {
    return light != oldDelegate.light || dark != oldDelegate.dark;
  }
}

class _FiberPainter extends CustomPainter {
  const _FiberPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final paths = [
      Path()
        ..moveTo(size.width * 0.1, size.height * 0.05)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.15,
          size.width * 0.2,
          size.height * 0.45,
        ),
      Path()
        ..moveTo(size.width * 0.6, size.height * 0.05)
        ..quadraticBezierTo(
          size.width * 0.55,
          size.height * 0.35,
          size.width * 0.9,
          size.height * 0.4,
        ),
      Path()
        ..moveTo(size.width * 0.15, size.height * 0.7)
        ..quadraticBezierTo(
          size.width * 0.4,
          size.height * 0.85,
          size.width * 0.8,
          size.height * 0.95,
        ),
    ];

    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FiberPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _BackgroundControls extends StatelessWidget {
  const _BackgroundControls({
    required this.background,
    required this.lighting,
    required this.textures,
    required this.prefersEnglish,
    required this.onBackgroundChanged,
    required this.onLightingChanged,
    required this.onToggleTexture,
  });

  final PreviewBackground background;
  final PreviewLighting lighting;
  final Set<PreviewTexture> textures;
  final bool prefersEnglish;
  final ValueChanged<PreviewBackground> onBackgroundChanged;
  final ValueChanged<PreviewLighting> onLightingChanged;
  final ValueChanged<PreviewTexture> onToggleTexture;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Background & lighting' : '背景と光の演出',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          SegmentedButton<PreviewBackground>(
            segments: PreviewBackground.values.map((option) {
              return ButtonSegment(
                value: option,
                label: Text(option.label(prefersEnglish)),
                icon: Icon(option.icon),
              );
            }).toList(),
            selected: {background},
            onSelectionChanged: (selection) {
              final value = selection.isNotEmpty ? selection.first : background;
              onBackgroundChanged(value);
            },
          ),
          SizedBox(height: tokens.spacing.md),
          Text(
            prefersEnglish ? 'Lighting' : '光源',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Wrap(
            spacing: tokens.spacing.xs,
            runSpacing: tokens.spacing.xs,
            children: PreviewLighting.values.map((option) {
              final selected = option == lighting;
              return ChoiceChip(
                label: Text(option.label(prefersEnglish)),
                avatar: Icon(option.icon, size: 18),
                selected: selected,
                onSelected: (_) => onLightingChanged(option),
              );
            }).toList(),
          ),
          SizedBox(height: tokens.spacing.md),
          Text(
            prefersEnglish ? 'Textures' : '質感',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Wrap(
            spacing: tokens.spacing.xs,
            runSpacing: tokens.spacing.xs,
            children: PreviewTexture.values.map((texture) {
              final selected = textures.contains(texture);
              return FilterChip(
                label: Text(texture.label(prefersEnglish)),
                avatar: Icon(texture.icon, size: 18),
                selected: selected,
                onSelected: (_) => onToggleTexture(texture),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.preview,
    required this.prefersEnglish,
    required this.onOpenCheck,
  });

  final PreviewData preview;
  final bool prefersEnglish;
  final VoidCallback onOpenCheck;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final subtitle = prefersEnglish
        ? 'Actual size and background locked. Run registrability check before ordering.'
        : '実寸と背景を確認しました。注文前に登録可否チェックを走らせてください。';

    return AppListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.colors.surfaceVariant,
        child: Icon(Icons.verified_outlined, color: tokens.colors.onSurface),
      ),
      title: Text(prefersEnglish ? 'Ready to order?' : '注文に進みますか？'),
      subtitle: Text(subtitle),
      trailing: OutlinedButton.icon(
        onPressed: onOpenCheck,
        icon: const Icon(Icons.rule_folder_outlined),
        label: Text(prefersEnglish ? 'Run check' : '実印チェック'),
      ),
      dense: true,
    );
  }
}

class _PreviewActions extends StatelessWidget {
  const _PreviewActions({
    required this.prefersEnglish,
    required this.onExport,
    required this.onEdit,
  });

  final bool prefersEnglish;
  final VoidCallback onExport;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SafeArea(
      minimum: EdgeInsets.all(tokens.spacing.lg),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(prefersEnglish ? 'Reopen editor' : '編集に戻る'),
            ),
          ),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onExport,
              icon: const Icon(Icons.download_rounded),
              label: Text(prefersEnglish ? 'Export / Share' : '出力・共有'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: tokens.spacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.message,
    required this.prefersEnglish,
    required this.onRetry,
  });

  final String message;
  final bool prefersEnglish;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.xl),
      child: AppEmptyState(
        title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
        message: message,
        icon: Icons.error_outline,
        actionLabel: prefersEnglish ? 'Retry' : '再試行',
        onAction: onRetry,
      ),
    );
  }
}

class PreviewData {
  const PreviewData({
    required this.displayName,
    required this.sizeMm,
    required this.writing,
    required this.shape,
    this.templateName,
  });

  final String displayName;
  final double sizeMm;
  final WritingStyle writing;
  final SealShape shape;
  final String? templateName;
}

enum PreviewBackground { paper, wood, transparent }

extension PreviewBackgroundX on PreviewBackground {
  String label(bool prefersEnglish) {
    return switch (this) {
      PreviewBackground.paper => prefersEnglish ? 'Paper' : '和紙',
      PreviewBackground.wood => prefersEnglish ? 'Wood' : '木目',
      PreviewBackground.transparent => prefersEnglish ? 'Transparent' : '透過',
    };
  }

  IconData get icon {
    return switch (this) {
      PreviewBackground.paper => Icons.layers,
      PreviewBackground.wood => Icons.forest_outlined,
      PreviewBackground.transparent => Icons.check_box_outline_blank_rounded,
    };
  }

  Color baseColor(DesignTokens tokens) {
    return switch (this) {
      PreviewBackground.paper => tokens.colors.surface,
      PreviewBackground.wood => const Color(0xFFF5E3D0),
      PreviewBackground.transparent => tokens.colors.surface.withValues(
        alpha: 0.8,
      ),
    };
  }

  Gradient? gradient(DesignTokens tokens) {
    switch (this) {
      case PreviewBackground.paper:
        return LinearGradient(
          colors: [tokens.colors.surfaceVariant, tokens.colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PreviewBackground.wood:
        return const LinearGradient(
          colors: [Color(0xFFF7E6D4), Color(0xFFF0D6B8), Color(0xFFE7C6A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PreviewBackground.transparent:
        return null;
    }
  }
}

enum PreviewLighting { soft, warm, studio }

extension PreviewLightingX on PreviewLighting {
  String label(bool prefersEnglish) {
    return switch (this) {
      PreviewLighting.soft => prefersEnglish ? 'Soft light' : 'ソフトライト',
      PreviewLighting.warm => prefersEnglish ? 'Warm sunset' : '夕焼けトーン',
      PreviewLighting.studio => prefersEnglish ? 'Studio' : 'スタジオ',
    };
  }

  IconData get icon {
    return switch (this) {
      PreviewLighting.soft => Icons.light_mode_outlined,
      PreviewLighting.warm => Icons.wb_twilight,
      PreviewLighting.studio => Icons.highlight_outlined,
    };
  }

  List<BoxShadow> shadows(DesignTokens tokens) {
    return switch (this) {
      PreviewLighting.soft => [
        BoxShadow(
          color: tokens.colors.onSurface.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
      PreviewLighting.warm => [
        BoxShadow(
          color: tokens.colors.secondary.withValues(alpha: 0.14),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
      PreviewLighting.studio => [
        BoxShadow(
          color: tokens.colors.onSurface.withValues(alpha: 0.18),
          blurRadius: 26,
          spreadRadius: 2,
          offset: const Offset(0, 12),
        ),
      ],
    };
  }

  Color? overlayColor(DesignTokens tokens) {
    return switch (this) {
      PreviewLighting.soft => tokens.colors.surfaceVariant.withValues(
        alpha: 0.18,
      ),
      PreviewLighting.warm => const Color(0xFFF6C88F).withValues(alpha: 0.18),
      PreviewLighting.studio => Colors.white.withValues(alpha: 0.12),
    };
  }
}

enum PreviewTexture { fibers, inkPad }

extension PreviewTextureX on PreviewTexture {
  String label(bool prefersEnglish) {
    return switch (this) {
      PreviewTexture.fibers => prefersEnglish ? 'Washi fibers' : '和紙の繊維',
      PreviewTexture.inkPad => prefersEnglish ? 'Inked edge' : '朱肉のにじみ',
    };
  }

  IconData get icon {
    return switch (this) {
      PreviewTexture.fibers => Icons.grain,
      PreviewTexture.inkPad => Icons.blur_on_outlined,
    };
  }
}

String _writingLabel(WritingStyle writing, bool prefersEnglish) {
  return switch (writing) {
    WritingStyle.tensho => prefersEnglish ? 'Tensho' : '篆書',
    WritingStyle.reisho => prefersEnglish ? 'Reisho' : '隷書',
    WritingStyle.kaisho => prefersEnglish ? 'Kaisho' : '楷書',
    WritingStyle.gyosho => prefersEnglish ? 'Gyosho' : '行書',
    WritingStyle.koentai => prefersEnglish ? 'Koentai' : '古印体',
    WritingStyle.custom => prefersEnglish ? 'Custom' : 'カスタム',
  };
}

TextStyle _stampStyle(BuildContext context, WritingStyle writing) {
  final base = Theme.of(context).textTheme.headlineSmall!;
  switch (writing) {
    case WritingStyle.tensho:
      return base.copyWith(letterSpacing: 4, fontWeight: FontWeight.w800);
    case WritingStyle.reisho:
      return base.copyWith(letterSpacing: 3, fontStyle: FontStyle.italic);
    case WritingStyle.kaisho:
      return base.copyWith(letterSpacing: 2, fontWeight: FontWeight.w700);
    case WritingStyle.gyosho:
      return base.copyWith(
        letterSpacing: 3,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
      );
    case WritingStyle.koentai:
      return base.copyWith(
        letterSpacing: 1.5,
        fontWeight: FontWeight.w800,
        height: 1.05,
      );
    case WritingStyle.custom:
      return base.copyWith(letterSpacing: 2.5);
  }
}

double _mmToLogicalPx(double mm) {
  const mmPerInch = 25.4;
  const logicalDpi = 160.0;
  return mm / mmPerInch * logicalDpi;
}
