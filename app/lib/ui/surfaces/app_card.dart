// ignore_for_file: public_member_api_docs

import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final surfaceColor = backgroundColor ?? tokens.colors.surface;
    final borderColor = tokens.colors.outline.withValues(alpha: 0.3);
    final radius = BorderRadius.circular(tokens.radii.md);

    final content = Padding(
      padding: padding ?? EdgeInsets.all(tokens.spacing.lg),
      child: child,
    );

    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap != null,
      child: Material(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(borderRadius: radius, onTap: onTap, child: content),
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding,
    this.dense = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final spacing = dense ? tokens.spacing.sm : tokens.spacing.md;

    return AppCard(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: tokens.spacing.lg,
            vertical: spacing,
          ),
      onTap: onTap,
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: subtitle == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              Padding(
                padding: EdgeInsets.only(right: tokens.spacing.md),
                child: leading,
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.titleMedium!,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: tokens.spacing.xs),
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: tokens.spacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
