import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class HankoFeaturePage extends StatelessWidget {
  const HankoFeaturePage({
    super.key,
    required this.title,
    required this.children,
    this.horizontalPadding = 26,
    this.topPadding = 48,
  });

  final String title;
  final List<Widget> children;
  final double horizontalPadding;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HankoColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            HankoSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: HankoTextStyles.pageTitle),
              if (children.isNotEmpty) const SizedBox(height: HankoSpacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
