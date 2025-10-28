import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesignTypeSelectionPage extends ConsumerWidget {
  const DesignTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(designCreationControllerProvider);
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final options = _buildOptions(context, l10n);
    final features = _buildFeatures(l10n, colorScheme);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designNewTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.designNewHelpTooltip,
            onPressed: () =>
                showHelpOverlay(context, contextLabel: l10n.designNewTitle),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.hasSelection
            ? () => _startFlow(context, ref, state.selectedMode!)
            : null,
        icon: const Icon(Icons.arrow_forward),
        label: Text(l10n.designNewContinueLabel),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceM,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.designNewSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppTokens.spaceL),
                  _FilterSection(state: state),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.crossAxisExtent > 640
                    ? 2
                    : 1;
                final aspectRatio = crossAxisCount > 1 ? 1.4 : 1.8;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final option = options[index];
                    final selected = state.selectedMode == option.mode;
                    return _OptionCard(
                      option: option,
                      selected: selected,
                      onTap: () => ref
                          .read(designCreationControllerProvider.notifier)
                          .selectMode(option.mode),
                    );
                  }, childCount: options.length),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    mainAxisSpacing: AppTokens.spaceM,
                    crossAxisSpacing: AppTokens.spaceM,
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceXL,
                AppTokens.spaceL,
                AppTokens.spaceXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.designNewHighlightsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceM),
                  ...features,
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Future<void> _startFlow(
    BuildContext context,
    WidgetRef ref,
    DesignSourceType mode,
  ) async {
    final controller = ref.read(designCreationControllerProvider.notifier);
    if (mode != DesignSourceType.typed) {
      final granted = await controller.ensureStoragePermission();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).designNewPermissionDenied,
            ),
          ),
        );
        return;
      }
    }

    final state = ref.read(designCreationControllerProvider);
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        DesignCreationModeSelectedEvent(
          mode: mode.name,
          filter: state.selectedFilter?.analyticsId,
        ),
      ),
    );

    final notifier = ref.read(appStateProvider.notifier);
    final route = switch (mode) {
      DesignSourceType.typed => CreationStageRoute(const ['input']),
      DesignSourceType.uploaded => CreationStageRoute(const ['upload']),
      DesignSourceType.logo => CreationStageRoute(const ['logo']),
    };
    notifier.push(route);
  }

  List<_CreationOption> _buildOptions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      _CreationOption(
        mode: DesignSourceType.typed,
        icon: Icons.draw_rounded,
        foreground: scheme.primary,
        title: l10n.designNewOptionTypedTitle,
        description: l10n.designNewOptionTypedDescription,
      ),
      _CreationOption(
        mode: DesignSourceType.uploaded,
        icon: Icons.file_upload_outlined,
        foreground: scheme.tertiary,
        title: l10n.designNewOptionUploadTitle,
        description: l10n.designNewOptionUploadDescription,
      ),
      _CreationOption(
        mode: DesignSourceType.logo,
        icon: Icons.account_balance_outlined,
        foreground: scheme.secondary,
        title: l10n.designNewOptionLogoTitle,
        description: l10n.designNewOptionLogoDescription,
      ),
    ];
  }

  List<Widget> _buildFeatures(AppLocalizations l10n, ColorScheme scheme) {
    final items = [
      (
        icon: Icons.auto_fix_high_outlined,
        title: l10n.designNewHighlightsAiTitle,
        body: l10n.designNewHighlightsAiBody,
      ),
      (
        icon: Icons.layers_outlined,
        title: l10n.designNewHighlightsTemplateTitle,
        body: l10n.designNewHighlightsTemplateBody,
      ),
      (
        icon: Icons.cloud_done_outlined,
        title: l10n.designNewHighlightsCloudTitle,
        body: l10n.designNewHighlightsCloudBody,
      ),
    ];

    return [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceL),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: AppTokens.radiusM,
                ),
                child: Icon(item.icon, color: scheme.primary),
              ),
              const SizedBox(width: AppTokens.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppTokens.spaceXS),
                    Text(item.body),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _FilterSection extends ConsumerWidget {
  const _FilterSection({required this.state});

  final DesignCreationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filters = [
      (DesignCreationFilter.personal, l10n.designNewFilterPersonal),
      (DesignCreationFilter.business, l10n.designNewFilterBusiness),
      (DesignCreationFilter.gift, l10n.designNewFilterGift),
    ];
    return Wrap(
      spacing: AppTokens.spaceS,
      runSpacing: AppTokens.spaceS,
      children: [
        for (final (filter, label) in filters)
          FilterChip(
            label: Text(label),
            selected: state.selectedFilter == filter,
            onSelected: (selected) {
              ref
                  .read(designCreationControllerProvider.notifier)
                  .selectFilter(selected ? filter : null);
            },
          ),
      ],
    );
  }
}

class _CreationOption {
  const _CreationOption({
    required this.mode,
    required this.icon,
    required this.foreground,
    required this.title,
    required this.description,
  });

  final DesignSourceType mode;
  final IconData icon;
  final Color foreground;
  final String title;
  final String description;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _CreationOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    final background = selected
        ? scheme.primary.withValues(alpha: 0.08)
        : scheme.surface;

    return Card(
      color: background,
      elevation: selected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.radiusL,
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: AppTokens.radiusL,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: option.foreground.withValues(alpha: 0.12),
                foregroundColor: option.foreground,
                child: Icon(option.icon),
              ),
              const SizedBox(height: AppTokens.spaceL),
              Text(
                option.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTokens.spaceS),
              Expanded(
                child: Text(
                  option.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? option.foreground : scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
