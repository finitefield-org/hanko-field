import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'hanko_primary_button.dart';
import 'hanko_surface_card.dart';

enum HankoStateKind { loading, empty, error, success }

class HankoStateView extends StatelessWidget {
  const HankoStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  const HankoStateView.empty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : kind = HankoStateKind.empty;

  const HankoStateView.error({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : kind = HankoStateKind.error;

  const HankoStateView.loading({
    super.key,
    required this.title,
    required this.message,
  }) : kind = HankoStateKind.loading,
       actionLabel = null,
       onAction = null;

  final HankoStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      padding: const EdgeInsets.all(HankoSpacing.lg),
      radius: HankoRadii.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StateMarker(kind: kind),
          const SizedBox(height: HankoSpacing.md),
          Text(title, style: HankoTextStyles.sectionTitle),
          const SizedBox(height: HankoSpacing.sm),
          Text(message, style: HankoTextStyles.body),
          if (actionLabel != null) ...[
            const SizedBox(height: HankoSpacing.lg),
            SizedBox(
              width: 172,
              child: HankoPrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateMarker extends StatelessWidget {
  const _StateMarker({required this.kind});

  final HankoStateKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind == HankoStateKind.loading) {
      return const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    }

    final color = kind == HankoStateKind.error
        ? HankoColors.error
        : HankoColors.gold;
    final icon = switch (kind) {
      HankoStateKind.empty => Icons.inbox_outlined,
      HankoStateKind.error => Icons.error_outline,
      HankoStateKind.success => Icons.check_circle_outline,
      HankoStateKind.loading => Icons.hourglass_empty,
    };
    return Icon(icon, color: color, size: 32);
  }
}
