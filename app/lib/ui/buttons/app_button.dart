// ignore_for_file: public_member_api_docs

import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colors = _ButtonColors.from(tokens, variant);
    final disabled = onPressed == null || isLoading;
    final textStyle = Theme.of(context).textTheme.labelLarge!;

    final padding = EdgeInsets.symmetric(
      horizontal: dense ? tokens.spacing.md : tokens.spacing.lg,
      vertical: dense ? tokens.spacing.sm : tokens.spacing.md,
    );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          Padding(
            padding: EdgeInsets.only(right: tokens.spacing.sm),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
              ),
            ),
          )
        else if (leading != null)
          Padding(
            padding: EdgeInsets.only(right: tokens.spacing.sm),
            child: leading,
          ),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, style: textStyle),
        ),
        if (trailing != null)
          Padding(
            padding: EdgeInsets.only(left: tokens.spacing.sm),
            child: trailing,
          ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: dense ? 40 : 48),
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: TextButton(
          onPressed: disabled ? null : onPressed,
          style: _buildStyle(tokens, colors, padding),
          child: child,
        ),
      ),
    );
  }

  ButtonStyle _buildStyle(
    DesignTokens tokens,
    _ButtonColors colors,
    EdgeInsets padding,
  ) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radii.md),
    );

    return ButtonStyle(
      padding: WidgetStateProperty.all(padding),
      shape: WidgetStateProperty.all(shape),
      side: WidgetStateProperty.resolveWith(
        (states) => colors.border == null
            ? null
            : BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? colors.border!.withValues(alpha: 0.45)
                    : colors.border!,
              ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.foreground.withValues(alpha: 0.45)
            : colors.foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.background.withValues(alpha: 0.45)
            : colors.background,
      ),
      overlayColor: WidgetStateProperty.all(
        colors.foreground.withValues(alpha: 0.08),
      ),
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(0)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;

  factory _ButtonColors.from(DesignTokens tokens, AppButtonVariant variant) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _ButtonColors(
          background: tokens.colors.primary,
          foreground: tokens.colors.onPrimary,
        );
      case AppButtonVariant.secondary:
        return _ButtonColors(
          background: tokens.colors.secondary,
          foreground: tokens.colors.onSecondary,
        );
      case AppButtonVariant.ghost:
        return _ButtonColors(
          background: Colors.transparent,
          foreground: tokens.colors.primary,
          border: tokens.colors.outline.withValues(alpha: 0.6),
        );
    }
  }
}
