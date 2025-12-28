// ignore_for_file: public_member_api_docs

import 'package:app/features/updates/data/models/changelog_models.dart';
import 'package:app/features/updates/view_model/changelog_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ChangelogPage extends ConsumerStatefulWidget {
  const ChangelogPage({super.key});

  @override
  ConsumerState<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends ConsumerState<ChangelogPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invoke(changelogViewModel.trackViewed());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;

    final state = ref.watch(changelogViewModel);
    final latestVersion = state.valueOrNull?.latestVersion;
    final releases = state.valueOrNull?.releases ?? const <ChangelogRelease>[];
    ChangelogRelease? latestRelease;
    if (latestVersion != null) {
      for (final release in releases) {
        if (release.version == latestVersion) {
          latestRelease = release;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.invoke(changelogViewModel.refresh()),
        edgeOffset: tokens.spacing.lg,
        displacement: tokens.spacing.xl,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              pinned: true,
              backgroundColor: tokens.colors.surface,
              leading: IconButton(
                tooltip: l10n.commonBack,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(l10n.changelogTitle),
              actions: [
                if (latestVersion != null && latestRelease != null)
                  Builder(
                    builder: (context) {
                      final release = latestRelease;
                      if (release == null) return const SizedBox.shrink();
                      return Badge(
                        label: Text(l10n.commonVersionLabel(latestVersion)),
                        backgroundColor: tokens.colors.primary,
                        textColor: tokens.colors.onPrimary,
                        child: IconButton(
                          tooltip: l10n.changelogLatestReleaseTooltip,
                          icon: const Icon(Icons.new_releases_outlined),
                          onPressed: () => _handleLearnMore(
                            context,
                            release: release,
                            prefersEnglish: prefersEnglish,
                          ),
                        ),
                      );
                    },
                  ),
                SizedBox(width: tokens.spacing.sm),
              ],
            ),
            ...switch (state) {
              AsyncLoading() => [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.lg,
                    tokens.spacing.md,
                    tokens.spacing.lg,
                    tokens.spacing.xl,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: AppListSkeleton(items: 4, itemHeight: 200),
                  ),
                ),
              ],
              AsyncError(:final error) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    title: l10n.changelogUnableToLoad,
                    message: error.toString(),
                    icon: Icons.update_disabled_outlined,
                    actionLabel: l10n.commonRetry,
                    onAction: () => ref.invoke(changelogViewModel.refresh()),
                  ),
                ),
              ],
              AsyncData(:final value) => _buildContent(
                context,
                value,
                l10n: l10n,
                prefersEnglish: prefersEnglish,
              ),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    ChangelogState state, {
    required AppLocalizations l10n,
    required bool prefersEnglish,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final visibleReleases = state.releasesFor(state.filter);
    final highlightReleases = state.releases
        .where((release) => release.isMajor)
        .take(2)
        .toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.sm,
          ),
          child: Text(
            l10n.changelogHighlightsTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        sliver: SliverToBoxAdapter(
          child: SegmentedButton<ChangelogFilter>(
            segments: [
              ButtonSegment(
                value: ChangelogFilter.all,
                label: Text(l10n.changelogAllUpdates),
                icon: const Icon(Icons.layers_outlined),
              ),
              ButtonSegment(
                value: ChangelogFilter.major,
                label: Text(l10n.changelogMajorOnly),
                icon: const Icon(Icons.new_releases_outlined),
              ),
            ],
            selected: {state.filter},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                ref.invoke(changelogViewModel.setFilter(value.first)),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
      if (highlightReleases.isNotEmpty)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          sliver: SliverList.separated(
            itemCount: highlightReleases.length,
            separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.md),
            itemBuilder: (context, index) {
              final release = highlightReleases[index];
              return _HighlightCard(
                release: release,
                prefersEnglish: prefersEnglish,
                onLearnMore: () => _handleLearnMore(
                  context,
                  release: release,
                  prefersEnglish: prefersEnglish,
                ),
              );
            },
          ),
        ),
      if (visibleReleases.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            title: l10n.changelogNoUpdatesTitle,
            message: l10n.changelogNoUpdatesMessage,
            icon: Icons.auto_awesome,
          ),
        ),
      if (visibleReleases.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.md,
              tokens.spacing.lg,
              tokens.spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.changelogVersionHistoryTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  l10n.changelogVersionHistorySubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (visibleReleases.isNotEmpty)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.sm,
            tokens.spacing.lg,
            tokens.spacing.xl,
          ),
          sliver: SliverList.separated(
            itemCount: visibleReleases.length,
            separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.md),
            itemBuilder: (context, index) {
              final release = visibleReleases[index];
              return _ReleaseTile(
                release: release,
                prefersEnglish: prefersEnglish,
                onExpanded: (expanded) => ref.invoke(
                  changelogViewModel.trackExpanded(
                    release: release,
                    expanded: expanded,
                  ),
                ),
                onLearnMore: () => _handleLearnMore(
                  context,
                  release: release,
                  prefersEnglish: prefersEnglish,
                ),
              );
            },
          ),
        ),
    ];
  }

  void _handleLearnMore(
    BuildContext context, {
    required ChangelogRelease release,
    required bool prefersEnglish,
  }) {
    ref.invoke(changelogViewModel.trackLearnMore(release: release));
    _showReleaseDetails(
      context,
      release: release,
      prefersEnglish: prefersEnglish,
    );
  }

  void _showReleaseDetails(
    BuildContext context, {
    required ChangelogRelease release,
    required bool prefersEnglish,
  }) {
    final tokens = DesignTokensTheme.of(context);
    showAppModal<void>(
      context: context,
      title: 'v${release.version} · ${release.title.resolve(prefersEnglish)}',
      primaryAction: AppLocalizations.of(context).commonClose,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(release.summary.resolve(prefersEnglish)),
          SizedBox(height: tokens.spacing.md),
          ...release.sections.map(
            (section) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title.resolve(prefersEnglish),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  ...section.items.map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: tokens.colors.primary,
                          ),
                          SizedBox(width: tokens.spacing.sm),
                          Expanded(child: Text(item.resolve(prefersEnglish))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.release,
    required this.prefersEnglish,
    required this.onLearnMore,
  });

  final ChangelogRelease release;
  final bool prefersEnglish;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final style = _heroStyle(release.heroTone, tokens);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.md),
              gradient: LinearGradient(
                colors: style.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: tokens.spacing.lg,
                  top: tokens.spacing.lg,
                  child: Icon(
                    style.icon,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 48,
                  ),
                ),
                Positioned(
                  left: tokens.spacing.lg,
                  bottom: tokens.spacing.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.sm,
                          vertical: tokens.spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(tokens.radii.sm),
                        ),
                        child: Text(
                          release.tier.label(prefersEnglish: prefersEnglish),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: tokens.spacing.sm),
                      Text(
                        'v${release.version}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      Text(
                        _formatDate(release.releasedAt, prefersEnglish),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Text(
            release.title.resolve(prefersEnglish),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            release.summary.resolve(prefersEnglish),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.75),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          ...release.highlights.map(
            (highlight) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: tokens.colors.primary,
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          highlight.title.resolve(prefersEnglish),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        SizedBox(height: tokens.spacing.xs),
                        Text(
                          highlight.description.resolve(prefersEnglish),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.colors.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          AppButton(
            label: AppLocalizations.of(context).commonLearnMore,
            variant: AppButtonVariant.ghost,
            trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
            onPressed: onLearnMore,
          ),
        ],
      ),
    );
  }
}

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile({
    required this.release,
    required this.prefersEnglish,
    required this.onExpanded,
    required this.onLearnMore,
  });

  final ChangelogRelease release;
  final bool prefersEnglish;
  final ValueChanged<bool> onExpanded;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.lg,
            vertical: tokens.spacing.sm,
          ),
          childrenPadding: EdgeInsets.only(
            left: tokens.spacing.lg,
            right: tokens.spacing.lg,
            bottom: tokens.spacing.lg,
          ),
          onExpansionChanged: onExpanded,
          title: Text(
            'v${release.version}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: tokens.spacing.xs),
            child: Row(
              children: [
                Text(
                  _formatDate(release.releasedAt, prefersEnglish),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.sm,
                    vertical: tokens.spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(tokens.radii.sm),
                  ),
                  child: Text(
                    release.tier.label(prefersEnglish: prefersEnglish),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                release.summary.resolve(prefersEnglish),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            ...release.sections.map(
              (section) => Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title.resolve(prefersEnglish),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    ...section.items.map(
                      (item) => Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: tokens.colors.primary,
                            ),
                            SizedBox(width: tokens.spacing.sm),
                            Expanded(
                              child: Text(
                                item.resolve(prefersEnglish),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppButton(
              label: AppLocalizations.of(context).commonLearnMore,
              variant: AppButtonVariant.ghost,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onPressed: onLearnMore,
            ),
          ],
        ),
      ),
    );
  }
}

({List<Color> gradient, IconData icon}) _heroStyle(
  ChangelogHeroTone tone,
  DesignTokens tokens,
) {
  switch (tone) {
    case ChangelogHeroTone.sunset:
      return (
        gradient: [
          tokens.colors.secondary.withValues(alpha: 0.9),
          tokens.colors.primary.withValues(alpha: 0.85),
        ],
        icon: Icons.local_fire_department_outlined,
      );
    case ChangelogHeroTone.jade:
      return (
        gradient: [
          tokens.colors.success.withValues(alpha: 0.9),
          tokens.colors.primary.withValues(alpha: 0.8),
        ],
        icon: Icons.spa_outlined,
      );
    case ChangelogHeroTone.cedar:
      return (
        gradient: [
          tokens.colors.warning.withValues(alpha: 0.9),
          tokens.colors.secondary.withValues(alpha: 0.75),
        ],
        icon: Icons.park_outlined,
      );
    case ChangelogHeroTone.indigo:
      return (
        gradient: [
          tokens.colors.primary.withValues(alpha: 0.9),
          tokens.colors.secondary.withValues(alpha: 0.8),
        ],
        icon: Icons.bolt_outlined,
      );
  }
}

String _formatDate(DateTime date, bool prefersEnglish) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return prefersEnglish ? '$y-$m-$d' : '$y/$m/$d';
}
