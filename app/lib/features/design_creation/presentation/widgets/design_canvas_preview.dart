import 'dart:math';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/design_creation/application/design_editor_state.dart';
import 'package:flutter/material.dart';

const double _kContainerCornerRadiusFactor = 0.05;
const double _kFramePaddingFactor = 0.08;
const double _kShapeCornerRadiusFactor = 0.1;
const double _kMarginNormalizationFactor = 20;
const double _kMarginRelativeCap = 0.2;
const double _kMarginSafetyInset = 8;
const double _kTextMaxWidthFactor = 0.85;
const int _kSquareGridDivisions = 6;
const int _kRadialGridRings = 4;
const int _kRadialGridAngleStep = 45;

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
    final containsCjk = trimmed.runes.any(_isCjkCodePoint);
    return containsCjk
        ? AppTokens.designPreviewLetterSpacingKanji
        : AppTokens.designPreviewLetterSpacingLatin;
  }

  bool _isCjkCodePoint(int codePoint) {
    return (codePoint >= 0x3000 && codePoint <= 0x30FF) || // punctuation + kana
        (codePoint >= 0x3400 && codePoint <= 0x9FFF) || // unified ideographs
        (codePoint >= 0xF900 &&
            codePoint <= 0xFAFF) || // compatibility ideographs
        (codePoint >= 0xFF66 && codePoint <= 0xFF9D); // half-width katakana
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
    final containerRadius = Radius.circular(
      size.shortestSide * _kContainerCornerRadiusFactor,
    );
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

    final framePadding = size.shortestSide * _kFramePaddingFactor;
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
        min(contentRect.width, contentRect.height) * _kShapeCornerRadiusFactor,
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
    final normalized = (config.margin / _kMarginNormalizationFactor).clamp(
      0.0,
      1.0,
    );
    final relativeCap = frameRect.shortestSide * _kMarginRelativeCap;
    final absoluteCap = frameRect.shortestSide / 2 - _kMarginSafetyInset;
    return max(0, min(absoluteCap, relativeCap * normalized));
  }

  void _paintGrid(Canvas canvas, Rect contentRect) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;

    if (config.grid == DesignGridType.square) {
      final step = contentRect.shortestSide / _kSquareGridDivisions;
      for (var i = 0; i <= _kSquareGridDivisions; i++) {
        final x = contentRect.left + (step * i);
        if (x > contentRect.right) {
          break;
        }
        canvas.drawLine(
          Offset(x, contentRect.top),
          Offset(x, contentRect.bottom),
          gridPaint,
        );
      }
      for (var i = 0; i <= _kSquareGridDivisions; i++) {
        final y = contentRect.top + (step * i);
        if (y > contentRect.bottom) {
          break;
        }
        canvas.drawLine(
          Offset(contentRect.left, y),
          Offset(contentRect.right, y),
          gridPaint,
        );
      }
    } else if (config.grid == DesignGridType.radial) {
      final center = contentRect.center;
      final maxRadius = contentRect.shortestSide / 2;
      for (var i = 1; i <= _kRadialGridRings; i++) {
        final radius = maxRadius * i / _kRadialGridRings;
        canvas.drawCircle(center, radius, gridPaint);
      }
      for (var angle = 0; angle < 360; angle += _kRadialGridAngleStep) {
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
    textPainter.layout(maxWidth: contentRect.width * _kTextMaxWidthFactor);

    final offsetFromCenter = _alignmentOffset(
      textPainter.size,
      contentRect.size,
      config.alignment,
    );
    final offsetForRotation = _rotateOffset(offsetFromCenter, config.rotation);
    final textAnchor = contentRect.center + offsetForRotation;

    canvas.save();
    canvas.translate(textAnchor.dx, textAnchor.dy);
    canvas.rotate(config.rotation * pi / 180);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
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

  Offset _rotateOffset(Offset offset, double degrees) {
    if (offset == Offset.zero || degrees % 360 == 0) {
      return offset;
    }
    final radians = degrees * pi / 180;
    final sinTheta = sin(radians);
    final cosTheta = cos(radians);
    final dx = (offset.dx * cosTheta) - (offset.dy * sinTheta);
    final dy = (offset.dx * sinTheta) + (offset.dy * cosTheta);
    return Offset(dx, dy);
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
