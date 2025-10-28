import 'dart:async';
import 'dart:math';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/home/application/home_providers.dart';
import 'package:app/features/home/domain/home_content.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _featuredController;

  @override
  void initState() {
    super.initState();
    _featuredController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _featuredController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final usageNotifier = ref.read(homeUsageProvider.notifier);
    final featuredNotifier = ref.read(homeFeaturedItemsProvider.notifier);
    final recentsNotifier = ref.read(homeRecentDesignsProvider.notifier);
    final templatesNotifier = ref.read(
      homeTemplateRecommendationsProvider.notifier,
    );

    await Future.wait([
      usageNotifier.reload(),
      featuredNotifier.reload(),
      recentsNotifier.reload(),
      templatesNotifier.reload(),
    ]);

    try {
      final experience = await ref.read(experienceGateProvider.future);
      final usage = await ref.read(homeUsageProvider.future);
      final sections = computeHomeSectionOrder(
        experience: experience,
        usage: usage,
      );
      final analytics = ref.read(analyticsControllerProvider.notifier);
      await analytics.logEvent(
        HomeFeedRefreshedEvent(sectionCount: sections.length),
      );
    } catch (_) {
      // Ignore analytics/logging errors during refresh.
    }
  }

  void _logInteraction({
    required HomeSectionType section,
    required String itemId,
    required int position,
    String action = 'tap',
  }) {
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        HomeSectionInteractionEvent(
          section: section.analyticsId,
          itemId: itemId,
          position: position,
          action: action,
        ),
      ),
    );
  }

  void _openDestination(HomeContentDestination destination) {
    final notifier = ref.read(appStateProvider.notifier);
    final currentState = ref.read(appStateProvider);
    final targetTab = destination.overrideTab;

    if (targetTab != null && targetTab != currentState.currentTab) {
      notifier.selectTab(targetTab);
      Future.microtask(() => notifier.push(destination.route));
      return;
    }
    notifier.push(destination.route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final experienceAsync = ref.watch(experienceGateProvider);
    final usageAsync = ref.watch(homeUsageProvider);
    final featuredAsync = ref.watch(homeFeaturedItemsProvider);
    final recentsAsync = ref.watch(homeRecentDesignsProvider);
    final templatesAsync = ref.watch(homeTemplateRecommendationsProvider);

    final experience = experienceAsync.asData?.value;
    final usage = usageAsync.asData?.value;
    final orderedSections = experience != null && usage != null
        ? computeHomeSectionOrder(experience: experience, usage: usage)
        : HomeSectionType.values;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      displacement: 64,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppTokens.spaceM)),
          for (final section in orderedSections)
            ...switch (section) {
              HomeSectionType.featured => _buildFeaturedSection(
                context: context,
                l10n: l10n,
                experience: experience,
                asyncValue: featuredAsync,
              ),
              HomeSectionType.recents => _buildRecentsSection(
                context: context,
                l10n: l10n,
                asyncValue: recentsAsync,
              ),
              HomeSectionType.templates => _buildTemplateSection(
                context: context,
                l10n: l10n,
                asyncValue: templatesAsync,
              ),
            },
          const SliverToBoxAdapter(
            child: SizedBox(height: AppTokens.spaceXL * 2),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeaturedSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required ExperienceGate? experience,
    required AsyncValue<List<HomeFeaturedItem>> asyncValue,
  }) {
    final subtitle = experience == null
        ? l10n.homeFeaturedSectionSubtitleDefault
        : l10n.homeFeaturedSectionSubtitle(experience.personaLabel);
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          title: l10n.homeFeaturedSectionTitle,
          subtitle: subtitle,
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 280,
          child: asyncValue.when(
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceL,
                  ),
                  child: AppCard(
                    variant: AppCardVariant.outlined,
                    child: Center(
                      child: Text(
                        l10n.homeFeaturedEmptyMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }
              return PageView.builder(
                controller: _featuredController,
                itemCount: items.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? AppTokens.spaceL : AppTokens.spaceS,
                      right: index == items.length - 1
                          ? AppTokens.spaceL
                          : AppTokens.spaceS,
                    ),
                    child: _FeaturedCard(
                      item: item,
                      l10n: l10n,
                      onTap: () {
                        _logInteraction(
                          section: HomeSectionType.featured,
                          itemId: item.id,
                          position: index,
                        );
                        _openDestination(item.destination);
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const _FeaturedSkeleton(),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              child: AppCard(
                variant: AppCardVariant.outlined,
                child: _ErrorContent(
                  message: l10n.homeLoadErrorMessage,
                  onRetry: () =>
                      ref.read(homeFeaturedItemsProvider.notifier).reload(),
                  retryLabel: l10n.homeRetryButtonLabel,
                  error: error,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildRecentsSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required AsyncValue<List<HomeRecentDesign>> asyncValue,
  }) {
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          title: l10n.homeRecentDesignsTitle,
          subtitle: l10n.homeRecentDesignsSubtitle,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
          child: asyncValue.when(
            data: (designs) {
              if (designs.isEmpty) {
                return AppCard(
                  variant: AppCardVariant.outlined,
                  child: AppEmptyState(
                    title: l10n.homeRecentDesignsEmptyTitle,
                    message: l10n.homeRecentDesignsEmptyMessage,
                    icon: const Icon(Icons.history_edu_outlined),
                    primaryAction: AppButton(
                      label: l10n.homeRecentDesignsEmptyCta,
                      onPressed: () {
                        _logInteraction(
                          section: HomeSectionType.recents,
                          itemId: 'cta_create',
                          position: 0,
                          action: 'cta',
                        );
                        _openDestination(
                          HomeContentDestination(
                            route: CreationStageRoute(const ['new']),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final columnCount = max(2, (maxWidth / 200).floor());
                  final itemWidth =
                      (maxWidth - (AppTokens.spaceM * (columnCount - 1))) /
                      columnCount;
                  const itemHeight = 220.0;
                  return Wrap(
                    spacing: AppTokens.spaceM,
                    runSpacing: AppTokens.spaceM,
                    children: [
                      for (final (index, design) in designs.indexed)
                        SizedBox(
                          width: itemWidth,
                          height: itemHeight,
                          child: _RecentDesignCard(
                            design: design,
                            l10n: l10n,
                            onTap: () {
                              _logInteraction(
                                section: HomeSectionType.recents,
                                itemId: design.id,
                                position: index,
                              );
                              _openDestination(
                                HomeContentDestination(
                                  route: LibraryEntryRoute(designId: design.id),
                                  overrideTab: AppTab.library,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTokens.spaceL),
              child: AppListSkeleton(),
            ),
            error: (error, _) => AppCard(
              variant: AppCardVariant.outlined,
              child: _ErrorContent(
                message: l10n.homeLoadErrorMessage,
                onRetry: () =>
                    ref.read(homeRecentDesignsProvider.notifier).reload(),
                retryLabel: l10n.homeRetryButtonLabel,
                error: error,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildTemplateSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required AsyncValue<List<HomeTemplateRecommendation>> asyncValue,
  }) {
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          title: l10n.homeTemplateRecommendationsTitle,
          subtitle: l10n.homeTemplateRecommendationsSubtitle,
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 230,
          child: asyncValue.when(
            data: (templates) {
              if (templates.isEmpty) {
                return Center(
                  child: Text(
                    l10n.homeTemplateRecommendationsEmpty,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceL,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: templates.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTokens.spaceM),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return SizedBox(
                    width: 220,
                    child: _TemplateCard(
                      template: template,
                      l10n: l10n,
                      onTap: () {
                        _logInteraction(
                          section: HomeSectionType.templates,
                          itemId: template.id,
                          position: index,
                        );
                        _openDestination(template.destination);
                      },
                    ),
                  );
                },
              );
            },
            loading: () => ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppTokens.spaceM),
              itemBuilder: (_, __) =>
                  const SizedBox(width: 220, child: _TemplateSkeleton()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              child: AppCard(
                variant: AppCardVariant.filled,
                child: _ErrorContent(
                  message: l10n.homeLoadErrorMessage,
                  onRetry: () => ref
                      .read(homeTemplateRecommendationsProvider.notifier)
                      .reload(),
                  retryLabel: l10n.homeRetryButtonLabel,
                  error: error,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceL,
        vertical: AppTokens.spaceS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceXS),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.item,
    required this.l10n,
    required this.onTap,
  });

  final HomeFeaturedItem item;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _NetworkImage(url: item.imageUrl),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.badgeLabel != null && item.badgeLabel!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
                    child: Chip(
                      label: Text(item.badgeLabel!),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      labelStyle: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppTokens.spaceM),
                AppButton(
                  label: item.ctaLabel,
                  onPressed: onTap,
                  leadingIcon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeletonBlock(
              height: 160,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            Padding(
              padding: EdgeInsets.all(AppTokens.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: AppSkeletonBlock(height: 20),
                  ),
                  SizedBox(height: AppTokens.spaceS),
                  FractionallySizedBox(
                    widthFactor: 0.9,
                    child: AppSkeletonBlock(height: 14),
                  ),
                  SizedBox(height: AppTokens.spaceXS),
                  FractionallySizedBox(
                    widthFactor: 0.8,
                    child: AppSkeletonBlock(height: 14),
                  ),
                  SizedBox(height: AppTokens.spaceM),
                  AppSkeletonBlock(
                    height: 44,
                    width: 160,
                    borderRadius: AppTokens.radiusM,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentDesignCard extends StatelessWidget {
  const _RecentDesignCard({
    required this.design,
    required this.l10n,
    required this.onTap,
  });

  final HomeRecentDesign design;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.radiusM,
            child: AspectRatio(
              aspectRatio: 1,
              child: _NetworkImage(url: design.thumbnailUrl),
            ),
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            design.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            _formatUpdatedAt(design.updatedAt, l10n),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Chip(
            label: Text(_designStatusLabel(design.status, l10n)),
            backgroundColor: scheme.surfaceContainerHighest,
            shape: const RoundedRectangleBorder(
              borderRadius: AppTokens.radiusS,
            ),
          ),
        ],
      ),
    );
  }

  String _formatUpdatedAt(DateTime updatedAt, AppLocalizations l10n) {
    final locale = l10n.localeName;
    final formatter = DateFormat.yMMMd(locale);
    return l10n.homeUpdatedOn(formatter.format(updatedAt));
  }

  String _designStatusLabel(DesignStatus status, AppLocalizations l10n) {
    return switch (status) {
      DesignStatus.draft => l10n.homeDesignStatusDraft,
      DesignStatus.ready => l10n.homeDesignStatusReady,
      DesignStatus.ordered => l10n.homeDesignStatusOrdered,
      DesignStatus.locked => l10n.homeDesignStatusLocked,
    };
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.l10n,
    required this.onTap,
  });

  final HomeTemplateRecommendation template;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.filled,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.radiusM,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _NetworkImage(url: template.previewUrl),
            ),
          ),
          const SizedBox(height: AppTokens.spaceS),
          if (template.highlightLabel != null &&
              template.highlightLabel!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.spaceXS),
              child: Chip(
                label: Text(template.highlightLabel!),
                backgroundColor: scheme.primaryContainer,
                labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceS,
                ),
              ),
            ),
          Text(
            template.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            template.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Wrap(
            spacing: AppTokens.spaceS,
            children: [
              Chip(
                label: Text(_writingStyleLabel(template.writingStyle, l10n)),
                backgroundColor: scheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppTokens.radiusS,
                ),
              ),
              Chip(
                label: Text(_shapeLabel(template.shape, l10n)),
                backgroundColor: scheme.surfaceContainerHighest,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppTokens.radiusS,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _writingStyleLabel(DesignWritingStyle style, AppLocalizations l10n) {
    return switch (style) {
      DesignWritingStyle.tensho => l10n.homeWritingStyleTensho,
      DesignWritingStyle.reisho => l10n.homeWritingStyleReisho,
      DesignWritingStyle.kaisho => l10n.homeWritingStyleKaisho,
      DesignWritingStyle.gyosho => l10n.homeWritingStyleGyosho,
      DesignWritingStyle.koentai => l10n.homeWritingStyleKoentai,
      DesignWritingStyle.custom => l10n.homeWritingStyleCustom,
    };
  }

  String _shapeLabel(DesignShape shape, AppLocalizations l10n) {
    return switch (shape) {
      DesignShape.round => l10n.homeShapeRound,
      DesignShape.square => l10n.homeShapeSquare,
    };
  }
}

class _TemplateSkeleton extends StatelessWidget {
  const _TemplateSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      variant: AppCardVariant.filled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBlock(height: 120, borderRadius: AppTokens.radiusM),
          SizedBox(height: AppTokens.spaceS),
          FractionallySizedBox(
            widthFactor: 0.9,
            child: AppSkeletonBlock(height: 16),
          ),
          SizedBox(height: AppTokens.spaceXS),
          FractionallySizedBox(
            widthFactor: 0.7,
            child: AppSkeletonBlock(height: 12),
          ),
          Spacer(),
          AppSkeletonBlock(height: 24, width: 80),
        ],
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
    required this.error,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          error.toString(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: AppTokens.spaceM),
        AppButton(
          label: retryLabel,
          onPressed: onRetry,
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, _) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image_not_supported_outlined),
        );
      },
    );
  }
}
