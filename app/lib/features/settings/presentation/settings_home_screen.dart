import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';

class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.settings,
      children: [
        HankoSurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          radius: HankoRadii.md,
          child: Column(
            children: [
              _SettingsRow(label: l10n.language, icon: Icons.language),
              _SettingsRow(label: l10n.about, icon: Icons.info_outline),
              _SettingsRow(label: l10n.faq, icon: Icons.help_outline),
              _SettingsRow(
                label: l10n.privacy,
                icon: Icons.privacy_tip_outlined,
              ),
              _SettingsRow(label: l10n.terms, icon: Icons.description_outlined),
              _SettingsRow(label: l10n.contact, icon: Icons.mail_outline),
              _SettingsRow(label: l10n.version, icon: Icons.tag_outlined),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Icon(icon, color: HankoColors.gold, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: HankoTextStyles.label)),
            const Icon(Icons.chevron_right, color: HankoColors.gold, size: 22),
          ],
        ),
      ),
    );
  }
}
