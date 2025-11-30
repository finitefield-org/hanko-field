// ignore_for_file: public_member_api_docs

import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final labelStyle = Theme.of(context).textTheme.titleSmall;
    final fieldPadding = EdgeInsets.symmetric(
      horizontal: tokens.spacing.md,
      vertical: tokens.spacing.md,
    );

    InputBorder borderFor(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
        borderSide: BorderSide(color: color, width: 1.1),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        SizedBox(height: tokens.spacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            errorText: errorText,
            filled: true,
            fillColor: tokens.colors.surface,
            contentPadding: fieldPadding,
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(left: tokens.spacing.md),
                    child: prefix,
                  ),
            prefixIconConstraints: BoxConstraints(
              minHeight: 0,
              minWidth: tokens.spacing.xl,
            ),
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(right: tokens.spacing.md),
                    child: suffix,
                  ),
            suffixIconConstraints: BoxConstraints(
              minHeight: 0,
              minWidth: tokens.spacing.xl,
            ),
            enabledBorder: borderFor(
              tokens.colors.outline.withValues(alpha: 0.7),
            ),
            focusedBorder: borderFor(tokens.colors.primary),
            errorBorder: borderFor(tokens.colors.error),
            focusedErrorBorder: borderFor(tokens.colors.error),
            helperStyle: Theme.of(context).textTheme.bodySmall,
            errorStyle: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.colors.error),
          ),
        ),
      ],
    );
  }
}

enum AppValidationState { info, success, warning, error }

class AppValidationMessage extends StatelessWidget {
  const AppValidationMessage({
    super.key,
    required this.message,
    this.state = AppValidationState.info,
  });

  final String message;
  final AppValidationState state;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final color = switch (state) {
      AppValidationState.success => tokens.colors.success,
      AppValidationState.warning => tokens.colors.warning,
      AppValidationState.error => tokens.colors.error,
      _ => tokens.colors.onSurface.withValues(alpha: 0.7),
    };
    final icon = switch (state) {
      AppValidationState.success => Icons.check_circle,
      AppValidationState.warning => Icons.warning_amber,
      AppValidationState.error => Icons.error,
      _ => Icons.info_outline,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        SizedBox(width: tokens.spacing.xs),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color, height: 1.3),
          ),
        ),
      ],
    );
  }
}
