import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/library/application/library_list_controller.dart';
import 'package:app/features/library/domain/library_list_filter.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class LibraryListScreen extends ConsumerStatefulWidget {
  const LibraryListScreen({super.key});

  @override
  ConsumerState<LibraryListScreen> createState() => _LibraryListScreenState();
}

class _LibraryListScreenState extends ConsumerState<LibraryListScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  ProviderSubscription<String>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _searchController = TextEditingController(
      text: ref.read(libraryListSearchProvider),
    );
    _searchSubscription = ref.listenManual<String>(libraryListSearchProvider, (
      previous,
      next,
    ) {
      if (next == _searchController.text) {
        return;
      }
      _searchController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchSubscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  LibraryListController get _controller =>
      ref.read(libraryListControllerProvider.notifier);

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final metrics = _scrollController.position;
    if (metrics.extentAfter < 320) {
      unawaited(_controller.loadMore());
    }
  }

  Future<void> _handleRefresh() {
    return _controller.refresh();
  }

  void _handleSearchChanged(String query) {
    _controller.updateSearch(query);
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _handleSearchChanged('');
  }

  void _openDesign(Design design) {
    ref
        .read(appStateProvider.notifier)
        .push(LibraryEntryRoute(designId: design.id));
  }

  void _openShares(Design design) {
    ref
        .read(appStateProvider.notifier)
        .push(
          LibraryEntryRoute(designId: design.id, trailing: const ['shares']),
        );
  }

  void _startCreation() {
    ref.read(appStateProvider.notifier).selectTab(AppTab.creation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(libraryListControllerProvider);
    final filter = ref.watch(libraryListFilterProvider);
    final sort = ref.watch(libraryListSortProvider);
    final viewMode = ref.watch(libraryListViewModeProvider);
    final experienceAsync = ref.watch(experienceGateProvider);
    final experience = experienceAsync.asData?.value;

    Widget sliverBody;
    sliverBody = asyncState.when(
      data: (state) {
        return _LibraryListBody(
          state: state,
          filter: filter,
          sort: sort,
          viewMode: viewMode,
          controller: _controller,
          scrollController: _scrollController,
          searchController: _searchController,
          onSearchChanged: _handleSearchChanged,
          onSearchCleared: _clearSearch,
          experience: experience,
          onDesignTap: _openDesign,
          onShareTap: _openShares,
          onCreateTap: _startCreation,
        );
      },
      loading: () => _LibraryListLoading(controller: _scrollController),
      error: (error, stackTrace) => _LibraryListError(
        controller: _scrollController,
        onRetry: () {
          unawaited(_controller.refresh());
        },
        message: l10n.libraryLoadError,
      ),
    );

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      displacement: 72,
      child: sliverBody,
    );
  }
}

class _LibraryListBody extends StatelessWidget {
  const _LibraryListBody({
    required this.state,
    required this.filter,
    required this.sort,
    required this.viewMode,
    required this.controller,
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.experience,
    required this.onDesignTap,
    required this.onShareTap,
    required this.onCreateTap,
  });

  final LibraryListState state;
  final LibraryListFilter filter;
  final LibrarySortOption sort;
  final LibraryViewMode viewMode;
  final LibraryListController controller;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ExperienceGate? experience;
  final void Function(Design design) onDesignTap;
  final void Function(Design design) onShareTap;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final designs = state.designs;
    final hasItems = designs.isNotEmpty;

    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceM,
            ),
            child: _LibraryHeader(experience: experience, state: state),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              0,
              AppTokens.spaceL,
              AppTokens.spaceL,
            ),
            child: _LibraryFilterPanel(
              filter: filter,
              sort: sort,
              viewMode: viewMode,
              controller: controller,
              searchController: searchController,
              onSearchChanged: onSearchChanged,
              onSearchCleared: onSearchCleared,
            ),
          ),
        ),
        if (!hasItems)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              child: Center(
                child: AppEmptyState(
                  title: l10n.libraryEmptyTitle,
                  message: l10n.libraryEmptyMessage,
                  icon: const Icon(Icons.inventory_outlined, size: 64),
                  primaryAction: AppButton(
                    label: l10n.libraryEmptyCta,
                    onPressed: onCreateTap,
                    fullWidth: true,
                  ),
                ),
              ),
            ),
          )
        else if (viewMode == LibraryViewMode.grid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppTokens.spaceL,
                crossAxisSpacing: AppTokens.spaceL,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final design = designs[index];
                return _LibraryGridCard(
                  design: design,
                  onPreview: () => onDesignTap(design),
                  onShare: () => onShareTap(design),
                );
              }, childCount: designs.length),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            sliver: SliverList.separated(
              itemBuilder: (context, index) {
                final design = designs[index];
                return _LibraryListCard(
                  design: design,
                  onPreview: () => onDesignTap(design),
                  onShare: () => onShareTap(design),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTokens.spaceM),
              itemCount: designs.length,
            ),
          ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppTokens.spaceL),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTokens.spaceXL * 2),
        ),
      ],
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.experience, required this.state});

  final ExperienceGate? experience;
  final LibraryListState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = l10n.localeName;
    final formatter = DateFormat.yMMMMd(locale);
    final updatedLabel = state.lastUpdated == null
        ? l10n.libraryUpdatedNever
        : l10n.libraryUpdatedAt(formatter.format(state.lastUpdated!));
    final subtitle = experience?.librarySubtitle ?? l10n.libraryListSubtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.libraryListTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTokens.spaceXS),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            Chip(
              avatar: const Icon(Icons.schedule_outlined, size: 18),
              label: Text(updatedLabel),
            ),
            if (experience != null)
              Chip(
                avatar: const Icon(Icons.person_outline, size: 18),
                label: Text(experience!.personaLabel),
              ),
          ],
        ),
      ],
    );
  }
}

class _LibraryFilterPanel extends StatelessWidget {
  const _LibraryFilterPanel({
    required this.filter,
    required this.sort,
    required this.viewMode,
    required this.controller,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  final LibraryListFilter filter;
  final LibrarySortOption sort;
  final LibraryViewMode viewMode;
  final LibraryListController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchBar(
          controller: searchController,
          hintText: l10n.librarySearchPlaceholder,
          leading: const Icon(Icons.search),
          trailing: [
            if (searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onSearchCleared,
              ),
          ],
          onChanged: onSearchChanged,
          onSubmitted: onSearchChanged,
        ),
        const SizedBox(height: AppTokens.spaceM),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<LibrarySortOption>(
                segments: [
                  ButtonSegment(
                    value: LibrarySortOption.recent,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(l10n.librarySortRecent),
                  ),
                  ButtonSegment(
                    value: LibrarySortOption.aiScore,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.librarySortAiScore),
                  ),
                  ButtonSegment(
                    value: LibrarySortOption.name,
                    icon: const Icon(Icons.sort_by_alpha),
                    label: Text(l10n.librarySortName),
                  ),
                ],
                selected: {sort},
                onSelectionChanged: (values) =>
                    controller.changeSort(values.first),
              ),
            ),
            const SizedBox(width: AppTokens.spaceM),
            SizedBox(
              width: 120,
              child: SegmentedButton<LibraryViewMode>(
                segments: [
                  ButtonSegment(
                    value: LibraryViewMode.grid,
                    icon: const Icon(Icons.grid_view),
                    label: Text(l10n.libraryViewGrid),
                  ),
                  ButtonSegment(
                    value: LibraryViewMode.list,
                    icon: const Icon(Icons.view_list),
                    label: Text(l10n.libraryViewList),
                  ),
                ],
                showSelectedIcon: false,
                selected: {viewMode},
                onSelectionChanged: (values) =>
                    controller.setViewMode(values.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceL),
        _FilterGroup(
          label: l10n.libraryFilterStatusLabel,
          child: Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: [
              FilterChip(
                label: Text(l10n.libraryStatusAll),
                selected: filter.statuses.isEmpty,
                onSelected: (_) => controller.clearStatuses(),
              ),
              for (final status in DesignStatus.values)
                FilterChip(
                  label: Text(_statusLabel(status, l10n)),
                  selected: filter.isStatusSelected(status),
                  onSelected: (_) => controller.toggleStatus(status),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceM),
        _FilterGroup(
          label: l10n.libraryFilterPersonaLabel,
          child: Wrap(
            spacing: AppTokens.spaceS,
            children: [
              for (final option in _personaOptions(l10n))
                ChoiceChip(
                  label: Text(option.label),
                  selected: option.value == filter.persona,
                  onSelected: (_) => controller.changePersona(option.value),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceM),
        _FilterGroup(
          label: l10n.libraryFilterDateLabel,
          child: Wrap(
            spacing: AppTokens.spaceS,
            children: [
              for (final option in LibraryDateRange.values)
                ChoiceChip(
                  label: Text(_dateRangeLabel(option, l10n)),
                  selected: filter.dateRange == option,
                  onSelected: (_) => controller.changeDateRange(option),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceM),
        _FilterGroup(
          label: l10n.libraryFilterAiLabel,
          child: Wrap(
            spacing: AppTokens.spaceS,
            children: [
              for (final option in LibraryAiScoreFilter.values)
                ChoiceChip(
                  label: Text(_aiLabel(option, l10n)),
                  selected: filter.aiScore == option,
                  onSelected: (_) => controller.changeAiScore(option),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          l10n.libraryFilterHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static List<_PersonaOption> _personaOptions(AppLocalizations l10n) {
    return [
      _PersonaOption(label: l10n.libraryPersonaAll, value: null),
      _PersonaOption(
        label: l10n.libraryPersonaJapanese,
        value: UserPersona.japanese,
      ),
      _PersonaOption(
        label: l10n.libraryPersonaForeigner,
        value: UserPersona.foreigner,
      ),
    ];
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        child,
      ],
    );
  }
}

class _LibraryGridCard extends StatelessWidget {
  const _LibraryGridCard({
    required this.design,
    required this.onPreview,
    required this.onShare,
  });

  final Design design;
  final VoidCallback onPreview;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: onPreview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.radiusM,
            child: AspectRatio(
              aspectRatio: 1,
              child: _LibraryPreviewImage(url: design.assets?.previewPngUrl),
            ),
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            design.input?.rawName ?? design.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            _updatedLabel(design.updatedAt, l10n),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            children: [
              Chip(label: Text(_statusLabel(design.status, l10n))),
              if (design.persona != null)
                Chip(label: Text(_personaLabel(design.persona!, l10n))),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _AiScoreBadge(score: design.ai?.qualityScore)),
              IconButton(
                tooltip: l10n.libraryActionPreview,
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
              ),
              IconButton(
                tooltip: l10n.libraryActionShare,
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryListCard extends StatelessWidget {
  const _LibraryListCard({
    required this.design,
    required this.onPreview,
    required this.onShare,
  });

  final Design design;
  final VoidCallback onPreview;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: onPreview,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.radiusS,
            child: SizedBox(
              width: 88,
              height: 88,
              child: _LibraryPreviewImage(url: design.assets?.previewPngUrl),
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  design.input?.rawName ?? design.id,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  _updatedLabel(design.updatedAt, l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Wrap(
                  spacing: AppTokens.spaceS,
                  runSpacing: AppTokens.spaceXS,
                  children: [
                    Chip(label: Text(_statusLabel(design.status, l10n))),
                    if (design.persona != null)
                      Chip(label: Text(_personaLabel(design.persona!, l10n))),
                    _AiScoreBadge(score: design.ai?.qualityScore),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceS),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.libraryActionPreview,
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
              ),
              IconButton(
                tooltip: l10n.libraryActionShare,
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiScoreBadge extends StatelessWidget {
  const _AiScoreBadge({required this.score});

  final double? score;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label = score == null
        ? l10n.libraryAiScoreUnknown
        : l10n.libraryAiScoreValue(score!.round());
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceS,
        vertical: AppTokens.spaceXS,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppTokens.radiusS,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 16),
          const SizedBox(width: AppTokens.spaceXS),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _LibraryPreviewImage extends StatelessWidget {
  const _LibraryPreviewImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const _PlaceholderPreview();
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _PlaceholderPreview(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return const _PlaceholderPreview();
      },
    );
  }
}

class _PlaceholderPreview extends StatelessWidget {
  const _PlaceholderPreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppTokens.radiusS,
      ),
      child: const Center(child: Icon(Icons.image_outlined, size: 32)),
    );
  }
}

class _LibraryListLoading extends StatelessWidget {
  const _LibraryListLoading({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppTokens.spaceL,
              crossAxisSpacing: AppTokens.spaceL,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const AppCard(
                variant: AppCardVariant.outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBlock(height: 160),
                    SizedBox(height: AppTokens.spaceS),
                    AppSkeletonBlock(height: 14, width: 120),
                    SizedBox(height: AppTokens.spaceXS),
                    AppSkeletonBlock(height: 12, width: 80),
                    SizedBox(height: AppTokens.spaceS),
                    AppSkeletonBlock(height: 20, width: 140),
                  ],
                ),
              ),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryListError extends StatelessWidget {
  const _LibraryListError({
    required this.controller,
    required this.onRetry,
    required this.message,
  });

  final ScrollController controller;
  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: AppEmptyState(
              title: l10n.libraryErrorTitle,
              message: message,
              icon: const Icon(Icons.cloud_off_outlined, size: 64),
              primaryAction: AppButton(
                label: l10n.libraryRetry,
                onPressed: onRetry,
                fullWidth: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonaOption {
  const _PersonaOption({required this.label, required this.value});

  final String label;
  final UserPersona? value;
}

String _statusLabel(DesignStatus status, AppLocalizations l10n) {
  return switch (status) {
    DesignStatus.draft => l10n.homeDesignStatusDraft,
    DesignStatus.ready => l10n.homeDesignStatusReady,
    DesignStatus.ordered => l10n.homeDesignStatusOrdered,
    DesignStatus.locked => l10n.homeDesignStatusLocked,
  };
}

String _personaLabel(UserPersona persona, AppLocalizations l10n) {
  return persona == UserPersona.japanese
      ? l10n.libraryPersonaJapanese
      : l10n.libraryPersonaForeigner;
}

String _updatedLabel(DateTime date, AppLocalizations l10n) {
  final formatter = DateFormat.yMMMd(l10n.localeName);
  return l10n.libraryUpdatedOn(formatter.format(date));
}

String _dateRangeLabel(LibraryDateRange range, AppLocalizations l10n) {
  return switch (range) {
    LibraryDateRange.last7Days => l10n.libraryDateLast7Days,
    LibraryDateRange.last30Days => l10n.libraryDateLast30Days,
    LibraryDateRange.last90Days => l10n.libraryDateLast90Days,
    LibraryDateRange.anytime => l10n.libraryDateAnytime,
  };
}

String _aiLabel(LibraryAiScoreFilter filter, AppLocalizations l10n) {
  return switch (filter) {
    LibraryAiScoreFilter.all => l10n.libraryAiAll,
    LibraryAiScoreFilter.high => l10n.libraryAiHigh,
    LibraryAiScoreFilter.medium => l10n.libraryAiMedium,
    LibraryAiScoreFilter.low => l10n.libraryAiLow,
  };
}
