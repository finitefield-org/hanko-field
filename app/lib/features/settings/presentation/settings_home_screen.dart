import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';

class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HankoFeaturePage(
      title: 'Settings',
      children: [
        HankoSurfaceCard(
          padding: EdgeInsets.symmetric(vertical: 8),
          radius: HankoRadii.md,
          child: Column(
            children: [
              _SettingsRow(label: 'Language', icon: Icons.language),
              _SettingsRow(label: 'About', icon: Icons.info_outline),
              _SettingsRow(label: 'FAQ', icon: Icons.help_outline),
              _SettingsRow(label: 'Privacy', icon: Icons.privacy_tip_outlined),
              _SettingsRow(label: 'Terms', icon: Icons.description_outlined),
              _SettingsRow(label: 'Contact', icon: Icons.mail_outline),
              _SettingsRow(label: 'Version', icon: Icons.tag_outlined),
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
