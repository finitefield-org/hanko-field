import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class HankoSurfaceCard extends StatelessWidget {
  const HankoSurfaceCard({
    super.key,
    required this.child,
    this.height,
    this.radius = HankoRadii.lg,
    this.padding,
  });

  final Widget child;
  final double? height;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: HankoColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: HankoColors.surfaceBorder, width: 0.7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
