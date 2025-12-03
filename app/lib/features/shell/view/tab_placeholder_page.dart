// ignore_for_file: public_member_api_docs

import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class TabPlaceholderPage extends ConsumerWidget {
  const TabPlaceholderPage({
    super.key,
    required this.title,
    required this.routePath,
    this.detail,
    this.showBack = false,
  });

  final String title;
  final String routePath;
  final String? detail;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final gatingHighlights = _gatingHighlights(gates);

    return Scaffold(
      appBar: AppTopBar(title: title, showBack: showBack),
      body: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(routePath, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: tokens.spacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail ?? 'Screen coming soon',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    'Path: $routePath',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: tokens.colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (gatingHighlights.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.lg),
              Text(
                'Experience gates',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: gatingHighlights
                    .map(
                      (text) => Chip(
                        label: Text(text),
                        avatar: const Icon(Icons.tune),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _gatingHighlights(AppExperienceGates gates) {
  final highlights = <String>[];

  highlights.add(
    gates.persona == UserPersona.japanese
        ? 'Persona: Japanese (registrability + domestic defaults)'
        : 'Persona: International (kanji helpers + guides)',
  );

  highlights.add(
    gates.prefersJapanese
        ? 'Language: Japanese experience'
        : 'Language: English experience',
  );

  highlights.add(
    gates.isJapanRegion ? 'Region: JP' : 'Region: ${gates.regionCode}',
  );

  if (gates.enableRegistrabilityCheck) {
    highlights.add('Registrability checks prioritized');
  }

  if (gates.emphasizeInternationalFlows) {
    highlights.add('International shipping and guidance enabled');
  }

  return highlights;
}
