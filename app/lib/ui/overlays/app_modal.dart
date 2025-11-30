// ignore_for_file: public_member_api_docs

import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:flutter/material.dart';

class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    required this.title,
    this.body,
    this.primaryAction,
    this.secondaryAction,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
  });

  final String title;
  final Widget? body;
  final String? primaryAction;
  final String? secondaryAction;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.xl,
        vertical: tokens.spacing.lg,
      ),
      backgroundColor: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (body != null) ...[
              SizedBox(height: tokens.spacing.md),
              DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!,
                child: body!,
              ),
            ],
            SizedBox(height: tokens.spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondaryAction != null)
                  AppButton(
                    label: secondaryAction!,
                    variant: AppButtonVariant.ghost,
                    onPressed:
                        onSecondaryPressed ??
                        () => Navigator.of(context).maybePop(),
                  ),
                if (secondaryAction != null) SizedBox(width: tokens.spacing.sm),
                if (primaryAction != null)
                  AppButton(label: primaryAction!, onPressed: onPrimaryPressed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> showAppModal<T>({
  required BuildContext context,
  required String title,
  Widget? body,
  String? primaryAction,
  String? secondaryAction,
  VoidCallback? onPrimaryPressed,
  VoidCallback? onSecondaryPressed,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AppModal(
      title: title,
      body: body,
      primaryAction: primaryAction,
      secondaryAction: secondaryAction,
      onPrimaryPressed: onPrimaryPressed,
      onSecondaryPressed: onSecondaryPressed,
    ),
  );
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  final tokens = DesignTokensTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: tokens.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radii.lg),
      ),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: tokens.spacing.lg,
          right: tokens.spacing.lg,
          top: tokens.spacing.md,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + tokens.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.colors.outline.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(tokens.radii.sm),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            builder(ctx),
          ],
        ),
      );
    },
  );
}
