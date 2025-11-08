import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/guides/application/guides_list_controller.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GuidesListScreen extends ConsumerStatefulWidget {
  const GuidesListScreen({super.key});

  @override
  ConsumerState<GuidesListScreen> createState() => _GuidesListScreenState();
}

class _GuidesListScreenState extends ConsumerState<GuidesListScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final initial = ref.read(guidesListControllerProvider).value;
    _searchController = TextEditingController(text: initial?.searchQuery ?? '');
    ref.listen<AsyncValue<GuideListState>>(guidesListControllerProvider, (
      previous,
      next,
    ) {
      if (previous == null) {
        return;
      }
      final nextQuery = next.value?.searchQuery;
      if (nextQuery == null || nextQuery == _searchController.text) {
        return;
      }
      _searchController.value = TextEditingValue(
        text: nextQuery,
        selection: TextSelection.collapsed(offset: nextQuery.length),
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() {
    return ref.read(guidesListControllerProvider.notifier).refresh();
  }

  void _handleSearchChanged(String value) {
    ref.read(guidesListControllerProvider.notifier).updateSearch(value);
    setState(() {});
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) {
      return;
    }
    _searchController.clear();
    _handleSearchChanged('');
  }

  void _openGuide(GuideListEntry entry) {
    ref
        .read(appStateProvider.notifier)
        .push(GuidesRoute(sectionSegments: [entry.slug]));
  }

  void _openDictionary() {
    ref.read(appStateProvider.notifier).push(const KanjiDictionaryRoute());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(guidesListControllerProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        displacement: 80,
        child: asyncState.when(
          data: (state) {
            return _GuidesListBody(
              state: state,
              scrollController: _scrollController,
              searchController: _searchController,
              onSearchChanged: _handleSearchChanged,
              onSearchClear: _clearSearch,
              onGuideTap: _openGuide,
              onOpenDictionary: _openDictionary,
            );
          },
          loading: () => const _GuidesListLoading(),
          error: (error, _) => _GuidesListError(
            message: l10n.guidesLoadError,
            onRetry: () =>
                ref.read(guidesListControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _GuidesListBody extends ConsumerWidget {
  const _GuidesListBody({
    required this.state,
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onGuideTap,
    required this.onOpenDictionary,
  });

  final GuideListState state;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final void Function(GuideListEntry entry) onGuideTap;
  final VoidCallback onOpenDictionary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(guidesListControllerProvider.notifier);
    final personaOptions = UserPersona.values
        .where(
          (persona) =>
              persona == UserPersona.foreigner ||
              persona == UserPersona.japanese,
        )
        .toList();
    final localeOptions = state.availableLocales;
    final topicOptions = state.availableTopics;

    final lastUpdated = state.lastUpdated;
    final localeTag = state.filter.locale.toLanguageTag();
    final dateLabel = lastUpdated == null
        ? null
        : DateFormat.yMMMd(_dateLocale(localeTag)).add_Hm().format(lastUpdated);

    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar.large(
          title: Text(l10n.guidesListTitle),
          pinned: true,
          actions: [
            IconButton(
              tooltip: l10n.guidesRefreshTooltip,
              icon: const Icon(Icons.refresh),
              onPressed: controller.refresh,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                0,
                AppTokens.spaceL,
                AppTokens.spaceL,
              ),
              child: SearchBar(
                controller: searchController,
                hintText: l10n.guidesSearchHint,
                leading: const Icon(Icons.search),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
                ),
                onChanged: onSearchChanged,
                trailing: [
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: l10n.guidesClearSearchTooltip,
                      icon: const Icon(Icons.close),
                      onPressed: onSearchClear,
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceS,
            ),
            child: _HowToPromoCard(
              title: l10n.howToScreenTitle,
              subtitle: l10n.howToScreenSubtitle,
              onTap: () =>
                  ref.read(appStateProvider.notifier).push(const HowToRoute()),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceL,
              vertical: AppTokens.spaceM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterSection(
                  label: l10n.guidesFilterPersonaLabel,
                  child: Wrap(
                    spacing: AppTokens.spaceS,
                    runSpacing: AppTokens.spaceS,
                    children: [
                      for (final persona in personaOptions)
                        FilterChip(
                          label: Text(_personaLabel(persona, l10n)),
                          selected: state.filter.persona == persona,
                          onSelected: (selected) {
                            if (selected) {
                              controller.selectPersona(persona);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.spaceM),
                _FilterSection(
                  label: l10n.guidesFilterLocaleLabel,
                  child: Wrap(
                    spacing: AppTokens.spaceS,
                    runSpacing: AppTokens.spaceS,
                    children: [
                      for (final locale in localeOptions)
                        FilterChip(
                          label: Text(_localeLabel(locale, l10n)),
                          selected: state.filter.locale == locale,
                          onSelected: (selected) {
                            if (selected) {
                              controller.selectLocale(locale);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                if (topicOptions.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.spaceM),
                  _FilterSection(
                    label: l10n.guidesFilterTopicLabel,
                    child: Wrap(
                      spacing: AppTokens.spaceS,
                      runSpacing: AppTokens.spaceS,
                      children: [
                        FilterChip(
                          label: Text(l10n.guidesTopicAllLabel),
                          selected: state.filter.topic == null,
                          onSelected: (selected) {
                            if (selected) {
                              controller.selectTopic(null);
                            }
                          },
                        ),
                        for (final topic in topicOptions)
                          FilterChip(
                            label: Text(_topicLabel(topic, l10n)),
                            selected: state.filter.topic == topic,
                            onSelected: (selected) {
                              if (selected) {
                                controller.selectTopic(topic);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                if (dateLabel != null || state.fromCache)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceL),
                    child: Row(
                      children: [
                        if (dateLabel != null)
                          Text(
                            l10n.guidesLastUpdatedLabel(dateLabel),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        const Spacer(),
                        if (state.fromCache)
                          Chip(
                            label: Text(l10n.guidesCachedBadge),
                            avatar: const Icon(Icons.offline_pin, size: 18),
                          ),
                      ],
                    ),
                  ),
                if (state.isRefreshing)
                  const Padding(
                    padding: EdgeInsets.only(top: AppTokens.spaceM),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceL,
              vertical: AppTokens.spaceS,
            ),
            child: _KanjiDictionaryPromoCard(
              l10n: l10n,
              onTap: onOpenDictionary,
            ),
          ),
        ),
        if (state.recommended.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppTokens.spaceL,
                left: AppTokens.spaceL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.guidesRecommendedTitle(
                      _personaLabel(state.filter.persona, l10n),
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTokens.spaceM),
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(right: AppTokens.spaceL),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final entry = state.recommended[index];
                        return SizedBox(
                          width: 280,
                          child: _GuideCard(
                            entry: entry,
                            l10n: l10n,
                            onTap: () => onGuideTap(entry),
                            compact: true,
                          ),
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppTokens.spaceM),
                      itemCount: state.recommended.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (state.visibleGuides.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: l10n.guidesEmptyTitle,
              message: l10n.guidesEmptyMessage,
              icon: const Icon(Icons.library_books_outlined),
              primaryAction: AppButton(
                label: l10n.guidesClearFiltersButton,
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  controller.selectTopic(null);
                  onSearchClear();
                },
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceXL,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = state.visibleGuides[index];
                final isLast = index == state.visibleGuides.length - 1;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : AppTokens.spaceM,
                  ),
                  child: _GuideCard(
                    entry: entry,
                    l10n: l10n,
                    onTap: () => onGuideTap(entry),
                  ),
                );
              }, childCount: state.visibleGuides.length),
            ),
          ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTokens.spaceS),
        child,
      ],
    );
  }
}

class _KanjiDictionaryPromoCard extends StatelessWidget {
  const _KanjiDictionaryPromoCard({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTokens.radiusL,
        color: colorScheme.secondaryContainer,
      ),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.translate, color: colorScheme.onSecondaryContainer),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.kanjiDictionaryPromoTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            l10n.kanjiDictionaryPromoDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppTokens.spaceM),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(l10n.kanjiDictionaryPromoCta),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.entry,
    required this.l10n,
    required this.onTap,
    this.compact = false,
  });

  final GuideListEntry entry;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationLabel = entry.readingTimeMinutes == null
        ? null
        : l10n.guidesReadingTimeLabel(entry.readingTimeMinutes!);
    final displayTags = entry.tags
        .where((tag) => !tag.startsWith('persona:'))
        .where((tag) => tag != 'recommended')
        .toList();
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideHeroImage(imageUrl: entry.heroImageUrl),
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(_topicLabel(entry.category, l10n)),
                      avatar: const Icon(Icons.category_outlined, size: 16),
                    ),
                    const Spacer(),
                    if (entry.featured)
                      Chip(
                        label: Text(l10n.guidesRecommendedChip),
                        avatar: const Icon(Icons.star, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  entry.title,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  entry.summary,
                  maxLines: compact ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (durationLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceM),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16),
                        const SizedBox(width: AppTokens.spaceS),
                        Text(durationLabel, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                if (displayTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceM),
                    child: Wrap(
                      spacing: AppTokens.spaceS,
                      runSpacing: AppTokens.spaceS,
                      children: [
                        for (final tag in displayTags.take(4))
                          Chip(
                            label: Text('#$tag'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppTokens.spaceL),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(l10n.guidesReadButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideHeroImage extends StatelessWidget {
  const _GuideHeroImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: const Center(child: Icon(Icons.landscape_outlined, size: 48)),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        ),
      ),
    );
  }
}

class _GuidesListLoading extends StatelessWidget {
  const _GuidesListLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      children: const [
        AppSkeletonBlock(height: 36, width: 160),
        SizedBox(height: AppTokens.spaceL),
        AppListSkeleton(items: 3),
      ],
    );
  }
}

class _GuidesListError extends StatelessWidget {
  const _GuidesListError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      children: [
        AppEmptyState(
          title: l10n.guidesLoadErrorTitle,
          message: message,
          icon: const Icon(Icons.wifi_off_outlined),
          primaryAction: AppButton(
            label: l10n.guidesRetryButtonLabel,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

String _personaLabel(UserPersona persona, AppLocalizations l10n) {
  return switch (persona) {
    UserPersona.japanese => l10n.guidesPersonaJapaneseLabel,
    UserPersona.foreigner => l10n.guidesPersonaInternationalLabel,
  };
}

String _localeLabel(Locale locale, AppLocalizations l10n) {
  if (locale.languageCode == 'ja') {
    return l10n.guidesLocaleJapaneseLabel;
  }
  return l10n.guidesLocaleEnglishLabel;
}

String _topicLabel(GuideCategory category, AppLocalizations l10n) {
  switch (category) {
    case GuideCategory.culture:
      return l10n.guidesCategoryCulture;
    case GuideCategory.howto:
      return l10n.guidesCategoryHowTo;
    case GuideCategory.policy:
      return l10n.guidesCategoryPolicy;
    case GuideCategory.faq:
      return l10n.guidesCategoryFaq;
    case GuideCategory.news:
      return l10n.guidesCategoryNews;
    case GuideCategory.other:
      return l10n.guidesCategoryOther;
  }
}

String _dateLocale(String localeTag) {
  return localeTag.replaceAll('-', '_');
}

class _HowToPromoCard extends StatelessWidget {
  const _HowToPromoCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AppCard(
      variant: AppCardVariant.filled,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceM),
                AppButton(
                  label: l10n.howToEntryCtaLabel,
                  size: AppButtonSize.small,
                  onPressed: onTap,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Icon(
            Icons.play_circle_outline,
            size: 48,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
