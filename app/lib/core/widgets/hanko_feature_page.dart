import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'hanko_page_insets.dart';

class HankoFeaturePage extends StatelessWidget {
  const HankoFeaturePage({
    super.key,
    required this.title,
    required this.children,
    this.horizontalPadding = 26,
    this.topPadding = HankoPageInsets.titleTop,
  });

  final String title;
  final List<Widget> children;
  final double horizontalPadding;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: title,
      explicitChildNodes: true,
      child: Material(
        color: HankoColors.background,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              HankoPageInsets.bottom(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: HankoTextStyles.pageTitle),
                ),
                if (children.isNotEmpty)
                  const SizedBox(height: HankoSpacing.lg),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
