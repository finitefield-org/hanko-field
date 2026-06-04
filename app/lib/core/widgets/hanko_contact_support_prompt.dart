import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'hanko_primary_button.dart';
import 'hanko_surface_card.dart';

class HankoContactSupportPrompt extends StatelessWidget {
  const HankoContactSupportPrompt({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onContactSupport,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ContactPromptIcon(),
              const SizedBox(width: HankoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HankoTextStyles.cardTitle),
                    const SizedBox(height: HankoSpacing.xs),
                    Text(message, style: HankoTextStyles.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HankoSpacing.md),
          HankoPrimaryButton(
            label: actionLabel,
            icon: Icons.support_agent_outlined,
            onPressed: onContactSupport,
          ),
        ],
      ),
    );
  }
}

class _ContactPromptIcon extends StatelessWidget {
  const _ContactPromptIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HankoColors.medallion,
        borderRadius: BorderRadius.circular(HankoRadii.sm),
        border: Border.all(color: HankoColors.surfaceBorder),
      ),
      child: const Icon(Icons.support_agent_outlined, color: HankoColors.gold),
    );
  }
}
