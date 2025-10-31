import 'dart:math';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/design_creation/application/design_editor_state.dart';
import 'package:flutter/material.dart';

class DesignCanvasPreview extends StatelessWidget {
  const DesignCanvasPreview({
    required this.config,
    required this.shape,
    required this.primaryText,
    super.key,
  });

  final DesignEditorConfig config;
  final DesignShape shape;
  final String primaryText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        final size = shortestSide.isFinite && shortestSide > 0
            ? shortestSide
            : 320.0;
        final fgColor = theme.colorScheme.onSurface;
        final gridColor = theme.colorScheme.outlineVariant.withValues(
          alpha: 0.5,
        );
        final fillColor = theme.colorScheme.surfaceContainerHighest;
        final textStyle =
            theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: _letterSpacingForText(primaryText),
            ) ??
            TextStyle(
              fontSize: size * 0.18,
              fontWeight: FontWeight.w600,
              color: fgColor,
            );

        return Align(
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTokens.spaceL),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: kElevationToShadow[1],
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceL),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DesignCanvasPainter(
                      config: config,
                      shape: shape,
                      primaryText: primaryText,
                      strokeColor: fgColor,
                      gridColor: gridColor,
                      fillColor: fillColor,
                      textStyle: textStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _letterSpacingForText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final isAscii = trimmed.codeUnits.every((unit) => unit < 128);
    return isAscii
        ? AppTokens.designPreviewLetterSpacingLatin
        : AppTokens.designPreviewLetterSpacingKanji;
  }
}

class _DesignCanvasPainter extends CustomPainter {
  _DesignCanvasPainter({
    required this.config,
    required this.shape,
    required this.primaryText,
    required this.strokeColor,
    required this.gridColor,
    required this.fillColor,
    required this.textStyle,
  });

  final DesignEditorConfig config;
  final DesignShape shape;
  final String primaryText;
  final Color strokeColor;
  final Color gridColor;
  final Color fillColor;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final containerRadius = Radius.circular(size.shortestSide * 0.05);
    final backgroundPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor.withValues(alpha: 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, containerRadius),
      backgroundPaint,
    );

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = strokeColor.withValues(alpha: 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, containerRadius),
      outlinePaint,
    );

    final framePadding = size.shortestSide * 0.08;
    final frameRect = Rect.fromLTWH(
      rect.left + framePadding,
      rect.top + framePadding,
      size.width - framePadding * 2,
      size.height - framePadding * 2,
    );
    final marginPx = _calculateMargin(frameRect);
    final contentRect = frameRect.deflate(marginPx);

    final shapePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor.withValues(alpha: 0.8);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = strokeColor;

    if (shape == DesignShape.round) {
      final radius = min(contentRect.width, contentRect.height) / 2;
      canvas.drawCircle(contentRect.center, radius, shapePaint);
      canvas.drawCircle(contentRect.center, radius, strokePaint);
    } else {
      final cornerRadius = Radius.circular(
        min(contentRect.width, contentRect.height) * 0.1,
      );
      final rrect = RRect.fromRectAndRadius(contentRect, cornerRadius);
      canvas.drawRRect(rrect, shapePaint);
      canvas.drawRRect(rrect, strokePaint);
    }

    if (config.showGrid) {
      _paintGrid(canvas, contentRect);
    }

    _paintPrimary(canvas, contentRect);
  }

  double _calculateMargin(Rect frameRect) {
    final maxDeflate = frameRect.shortestSide / 2 - 8;
    final marginScale = config.margin / 20;
    return max(0, min(maxDeflate, frameRect.shortestSide * 0.2 * marginScale));
  }

  void _paintGrid(Canvas canvas, Rect contentRect) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;

    if (config.grid == DesignGridType.square) {
      final step = contentRect.shortestSide / 6;
      for (var x = contentRect.left; x <= contentRect.right; x += step) {
        canvas.drawLine(
          Offset(x, contentRect.top),
          Offset(x, contentRect.bottom),
          gridPaint,
        );
      }
      for (var y = contentRect.top; y <= contentRect.bottom; y += step) {
        canvas.drawLine(
          Offset(contentRect.left, y),
          Offset(contentRect.right, y),
          gridPaint,
        );
      }
    } else if (config.grid == DesignGridType.radial) {
      final center = contentRect.center;
      final maxRadius = contentRect.shortestSide / 2;
      const rings = 4;
      for (var i = 1; i <= rings; i++) {
        final radius = maxRadius * i / rings;
        canvas.drawCircle(center, radius, gridPaint);
      }
      for (var angle = 0; angle < 360; angle += 45) {
        final radians = angle * pi / 180;
        final dx = cos(radians) * maxRadius;
        final dy = sin(radians) * maxRadius;
        canvas.drawLine(
          center,
          Offset(center.dx + dx, center.dy + dy),
          gridPaint,
        );
      }
    }
  }

  void _paintPrimary(Canvas canvas, Rect contentRect) {
    if (primaryText.trim().isEmpty) {
      return;
    }
    final span = TextSpan(text: primaryText, style: textStyle);
    final textPainter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    textPainter.layout(maxWidth: contentRect.width * 0.85);

    final offsetFromCenter = _alignmentOffset(
      textPainter.size,
      contentRect.size,
      config.alignment,
    );

    canvas.save();
    canvas.translate(contentRect.center.dx, contentRect.center.dy);
    canvas.rotate(config.rotation * pi / 180);
    final dx = offsetFromCenter.dx - textPainter.width / 2;
    final dy = offsetFromCenter.dy - textPainter.height / 2;
    textPainter.paint(canvas, Offset(dx, dy));
    canvas.restore();
  }

  Offset _alignmentOffset(
    Size contentSize,
    Size containerSize,
    DesignCanvasAlignment alignment,
  ) {
    final horizontalSpace = (containerSize.width - contentSize.width) / 2;
    final verticalSpace = (containerSize.height - contentSize.height) / 2;
    switch (alignment) {
      case DesignCanvasAlignment.center:
        return Offset.zero;
      case DesignCanvasAlignment.top:
        return Offset(0, -verticalSpace);
      case DesignCanvasAlignment.bottom:
        return Offset(0, verticalSpace);
      case DesignCanvasAlignment.left:
        return Offset(-horizontalSpace, 0);
      case DesignCanvasAlignment.right:
        return Offset(horizontalSpace, 0);
    }
  }

  @override
  bool shouldRepaint(covariant _DesignCanvasPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.shape != shape ||
        oldDelegate.primaryText != primaryText ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.textStyle != textStyle;
  }
}
