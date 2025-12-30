// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration ?? const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final baseColor = tokens.colors.surfaceVariant;
    final highlight = Color.alphaBlend(
      tokens.colors.onSurface.withValues(alpha: 0.08),
      baseColor,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final textDirection = Directionality.of(context);
        final value = _controller.value * 2 * math.pi;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [baseColor, highlight, baseColor],
              stops: const [0.2, 0.5, 0.8],
              transform: _SlidingGradientTransform(
                slidePercent: math.sin(value),
              ),
            ).createShader(bounds, textDirection: textDirection);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final direction = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    return Matrix4.translationValues(
      bounds.width * slidePercent * 0.25 * direction,
      0,
      0,
    );
  }
}

class AppSkeletonBlock extends StatelessWidget {
  const AppSkeletonBlock({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: tokens.colors.surfaceVariant,
          borderRadius: borderRadius ?? BorderRadius.circular(tokens.radii.sm),
        ),
      ),
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.items = 3, this.itemHeight = 72});

  final int items;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Column(
      children: List.generate(items, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == items - 1 ? 0 : tokens.spacing.md,
          ),
          child: AppSkeletonBlock(
            height: itemHeight,
            borderRadius: BorderRadius.circular(tokens.radii.md),
          ),
        );
      }),
    );
  }
}
