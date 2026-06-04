import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _AppAvailabilityScreenFrame(
      icon: Icons.construction_outlined,
      title: l10n.maintenanceTitle,
      message: l10n.maintenanceMessage,
      actionLabel: onRetry == null ? null : l10n.tryAgain,
      onAction: onRetry,
    );
  }
}

class AppUpdateRequiredScreen extends StatelessWidget {
  const AppUpdateRequiredScreen({super.key, this.onUpdate});

  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _AppAvailabilityScreenFrame(
      icon: Icons.system_update_alt_outlined,
      title: l10n.appUpdateRequiredTitle,
      message: l10n.appUpdateRequiredMessage,
      actionLabel: onUpdate == null ? null : l10n.appUpdateRequiredAction,
      onAction: onUpdate,
    );
  }
}

class _AppAvailabilityScreenFrame extends StatelessWidget {
  const _AppAvailabilityScreenFrame({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HankoColors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 432),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 36, 18, HankoSpacing.xl),
              child: HankoSurfaceCard(
                radius: HankoRadii.sm,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _AvailabilityIcon(icon: icon)),
                    const SizedBox(height: HankoSpacing.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: HankoTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: HankoSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: HankoTextStyles.body,
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(height: HankoSpacing.lg),
                      HankoPrimaryButton(
                        label: actionLabel!,
                        icon: Icons.arrow_forward,
                        onPressed: onAction,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityIcon extends StatelessWidget {
  const _AvailabilityIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFF7E8),
        boxShadow: [
          BoxShadow(
            color: Color(0x1FB8894B),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 72,
        child: Icon(icon, color: HankoColors.gold, size: 34),
      ),
    );
  }
}
