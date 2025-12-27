// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class AppToast extends StatelessWidget {
  const AppToast({super.key, required this.message, required this.onDismiss});

  final AppMessage message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final background = switch (message.tone) {
      AppMessageTone.success => tokens.colors.success,
      AppMessageTone.warning => tokens.colors.warning,
      AppMessageTone.alert => tokens.colors.error,
    };
    final textColor = background.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;
    final icon = switch (message.tone) {
      AppMessageTone.success => Icons.check_circle_outline,
      AppMessageTone.warning => Icons.warning_amber_rounded,
      AppMessageTone.alert => Icons.error_outline,
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: message.semanticLabel ?? message.text,
      child: Material(
        color: background,
        elevation: 6,
        borderRadius: BorderRadius.circular(tokens.radii.md),
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(tokens.radii.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.lg,
              vertical: tokens.spacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 20),
                SizedBox(width: tokens.spacing.sm),
                Flexible(
                  child: Text(
                    message.text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Icon(Icons.close, color: textColor, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
