// ignore_for_file: public_member_api_docs

import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 480;
  static const double medium = 720;
  static const double expanded = 1024;
}

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= AppBreakpoints.expanded && expanded != null) {
      return expanded!(context);
    }
    if (width >= AppBreakpoints.medium && medium != null) {
      return medium!(context);
    }
    return compact(context);
  }
}

class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final width = MediaQuery.of(context).size.width;

    double horizontal;
    if (width >= AppBreakpoints.expanded) {
      horizontal = tokens.spacing.xxl;
    } else if (width >= AppBreakpoints.medium) {
      horizontal = tokens.spacing.xl;
    } else {
      horizontal = tokens.spacing.lg;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: tokens.spacing.lg,
      ),
      child: child,
    );
  }
}
