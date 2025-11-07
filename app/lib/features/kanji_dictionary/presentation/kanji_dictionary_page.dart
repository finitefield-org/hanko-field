import 'dart:async';

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:app/features/kanji_dictionary/application/kanji_dictionary_controller.dart';
import 'package:app/features/kanji_dictionary/application/kanji_dictionary_state.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KanjiDictionaryPage extends ConsumerStatefulWidget {
  const KanjiDictionaryPage({super.key});

  @override
  ConsumerState<KanjiDictionaryPage> createState() =>
      _KanjiDictionaryPageState();
}

class _KanjiDictionaryPageState extends ConsumerState<KanjiDictionaryPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(kanjiDictionaryControllerProvider);
    final notifier = ref.read(kanjiDictionaryControllerProvider.notifier);
    _syncController(state.query);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (state.errorMessage != null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              content: Text(
                state.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          );
        notifier.clearMessages();
      } else if (state.infoMessage != null) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(state.infoMessage!)));
        notifier.clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 96,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            AppTokens.spaceS,
            AppTokens.spaceS,
            AppTokens.spaceS,
          ),
          child: SearchBar(
            controller: _searchController,
            hintText: l10n.kanjiDictionarySearchHint,
            leading: const Icon(Icons.search),
            onChanged: notifier.updateQuery,
            onSubmitted: (_) => notifier.search(refresh: true),
            padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
              EdgeInsets.symmetric(horizontal: AppTokens.spaceM),
            ),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  tooltip: l10n.kanjiDictionaryClearSearch,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    notifier.updateQuery('');
                    notifier.search(refresh: true, allowEmptyQuery: true);
                  },
                ),
              IconButton(
                tooltip: l10n.kanjiDictionaryRefresh,
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    notifier.search(refresh: true, allowEmptyQuery: true),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: state.showFavoritesOnly
                ? l10n.kanjiDictionaryShowAllTooltip
                : l10n.kanjiDictionaryShowFavoritesTooltip,
            icon: Icon(
              state.showFavoritesOnly ? Icons.bookmark : Icons.bookmark_border,
            ),
            onPressed: notifier.toggleFavoritesView,
          ),
        ],
        bottom: state.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.search(refresh: true, allowEmptyQuery: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.hasHistory || state.hasRecentlyViewed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceS,
                  ),
                  child: _HistorySection(
                    state: state,
                    l10n: l10n,
                    onHistoryTap: notifier.applyHistoryQuery,
                    onViewedTap: (candidate) =>
                        _openDetail(context, candidate, l10n),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceL,
                  vertical: AppTokens.spaceS,
                ),
                child: _FilterSection(
                  state: state,
                  l10n: l10n,
                  onToggleGrade: notifier.toggleGradeFilter,
                  onToggleStroke: notifier.toggleStrokeFilter,
                  onToggleRadical: notifier.toggleRadicalFilter,
                ),
              ),
            ),
            if (state.featuredEntries.isNotEmpty &&
                state.query.isEmpty &&
                !state.showFavoritesOnly)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceL,
                    AppTokens.spaceM,
                    AppTokens.spaceL,
                    AppTokens.spaceS,
                  ),
                  child: _FeaturedCarousel(
                    entries: state.featuredEntries,
                    l10n: l10n,
                    onTap: (candidate) => _openDetail(context, candidate, l10n),
                    onFavoriteToggle: (candidate) =>
                        notifier.toggleBookmark(candidate.id),
                    favorites: state.favoriteIds,
                  ),
                ),
              ),
            if (!state.isLoading && state.visibleResults.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: AppEmptyState(
                    title: state.showFavoritesOnly
                        ? l10n.kanjiDictionaryEmptyFavoritesTitle
                        : l10n.kanjiDictionaryEmptyResultsTitle,
                    message: state.showFavoritesOnly
                        ? l10n.kanjiDictionaryEmptyFavoritesMessage
                        : l10n.kanjiDictionaryEmptyResultsMessage,
                    icon: Icon(
                      state.showFavoritesOnly
                          ? Icons.bookmark_border
                          : Icons.menu_book_outlined,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceL,
                  vertical: AppTokens.spaceM,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final candidate = state.visibleResults[index];
                    final isFavorite = state.favoriteIds.contains(candidate.id);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == state.visibleResults.length - 1
                            ? 0
                            : AppTokens.spaceM,
                      ),
                      child: _KanjiResultTile(
                        candidate: candidate,
                        l10n: l10n,
                        isFavorite: isFavorite,
                        onFavoriteToggle: () =>
                            notifier.toggleBookmark(candidate.id),
                        onOpenDetail: () =>
                            _openDetail(context, candidate, l10n),
                      ),
                    );
                  }, childCount: state.visibleResults.length),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppTokens.spaceXL),
            ),
          ],
        ),
      ),
    );
  }

  void _syncController(String value) {
    if (_searchController.text == value) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    KanjiCandidate candidate,
    AppLocalizations l10n,
  ) async {
    final notifier = ref.read(kanjiDictionaryControllerProvider.notifier);
    unawaited(notifier.recordViewed(candidate));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final sheetState = ref.watch(kanjiDictionaryControllerProvider);
            final sheetNotifier = ref.read(
              kanjiDictionaryControllerProvider.notifier,
            );
            final isFavorite = sheetState.favoriteIds.contains(candidate.id);
            return _KanjiDetailSheet(
              candidate: candidate,
              l10n: l10n,
              isFavorite: isFavorite,
              canInsert: sheetState.hasDesignDraft,
              isInserting: sheetState.isAttachingToDesign,
              onFavoriteToggle: () =>
                  sheetNotifier.toggleBookmark(candidate.id),
              onInsert: () async {
                final inserted = await sheetNotifier.attachToDesign(candidate);
                if (inserted && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        );
      },
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.state,
    required this.l10n,
    required this.onHistoryTap,
    required this.onViewedTap,
  });

  final KanjiDictionaryState state;
  final AppLocalizations l10n;
  final ValueChanged<String> onHistoryTap;
  final ValueChanged<KanjiCandidate> onViewedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.hasHistory) ...[
          Text(
            l10n.kanjiDictionaryHistorySection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: [
              for (final query in state.searchHistory)
                ActionChip(
                  label: Text(query),
                  onPressed: () => onHistoryTap(query),
                  avatar: const Icon(Icons.history, size: 16),
                ),
            ],
          ),
        ],
        if (state.hasRecentlyViewed) ...[
          Padding(
            padding: EdgeInsets.only(
              top: state.hasHistory ? AppTokens.spaceL : 0,
            ),
            child: Text(
              l10n.kanjiDictionaryRecentlyViewed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppTokens.spaceS),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final candidate = state.recentlyViewed[index];
                return InkWell(
                  borderRadius: AppTokens.radiusM,
                  onTap: () => onViewedTap(candidate),
                  child: Container(
                    width: 88,
                    decoration: BoxDecoration(
                      borderRadius: AppTokens.radiusM,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.all(AppTokens.spaceS),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          candidate.character,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppTokens.spaceXS),
                        Text(
                          candidate.meanings.first,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, _) =>
                  const SizedBox(width: AppTokens.spaceS),
              itemCount: state.recentlyViewed.length,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.state,
    required this.l10n,
    required this.onToggleGrade,
    required this.onToggleStroke,
    required this.onToggleRadical,
  });

  final KanjiDictionaryState state;
  final AppLocalizations l10n;
  final ValueChanged<KanjiGradeLevel> onToggleGrade;
  final ValueChanged<KanjiStrokeBucket> onToggleStroke;
  final ValueChanged<KanjiRadicalCategory> onToggleRadical;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.kanjiDictionaryFiltersTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        _FilterGroup(
          title: l10n.kanjiDictionaryGradeFilterLabel,
          chips: [
            for (final level in KanjiGradeLevel.values)
              FilterChip(
                label: Text(level.label),
                selected: state.gradeFilters.contains(level),
                onSelected: (_) => onToggleGrade(level),
              ),
          ],
        ),
        _FilterGroup(
          title: l10n.kanjiDictionaryStrokeFilterLabel,
          chips: [
            for (final bucket in KanjiStrokeBucket.values)
              FilterChip(
                label: Text(bucket.label),
                selected: state.strokeFilters.contains(bucket),
                onSelected: (_) => onToggleStroke(bucket),
              ),
          ],
        ),
        _FilterGroup(
          title: l10n.kanjiDictionaryRadicalFilterLabel,
          chips: [
            for (final radical in KanjiRadicalCategory.values)
              FilterChip(
                avatar: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSecondaryContainer,
                  child: Text(radical.radicalGlyph),
                ),
                label: Text(radical.displayLabel),
                selected: state.radicalFilters.contains(radical),
                onSelected: (_) => onToggleRadical(radical),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: chips,
          ),
        ],
      ),
    );
  }
}

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({
    required this.entries,
    required this.l10n,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.favorites,
  });

  final List<KanjiCandidate> entries;
  final AppLocalizations l10n;
  final ValueChanged<KanjiCandidate> onTap;
  final ValueChanged<KanjiCandidate> onFavoriteToggle;
  final Set<String> favorites;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.kanjiDictionaryFeaturedTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final candidate = entries[index];
              final isFavorite = favorites.contains(candidate.id);
              return _FeaturedCard(
                candidate: candidate,
                isFavorite: isFavorite,
                onTap: () => onTap(candidate),
                onFavoriteToggle: () => onFavoriteToggle(candidate),
              );
            },
            separatorBuilder: (context, _) =>
                const SizedBox(width: AppTokens.spaceM),
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.candidate,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final KanjiCandidate candidate;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: AppTokens.radiusL,
          color: colorScheme.surfaceContainerHigh,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  candidate.character,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                  ),
                  onPressed: onFavoriteToggle,
                ),
              ],
            ),
            Text(
              candidate.meanings.first,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              candidate.story ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanjiResultTile extends StatelessWidget {
  const _KanjiResultTile({
    required this.candidate,
    required this.l10n,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onOpenDetail,
  });

  final KanjiCandidate candidate;
  final AppLocalizations l10n;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: AppTokens.radiusL,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  padding: const EdgeInsets.all(AppTokens.spaceL),
                  child: Text(
                    candidate.character,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.meanings.join(' · '),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTokens.spaceXS),
                      Text(
                        candidate.readings.join(', '),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTokens.spaceS),
                      Wrap(
                        spacing: AppTokens.spaceS,
                        runSpacing: AppTokens.spaceS,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.school, size: 16),
                            label: Text(candidate.gradeLevel.label),
                          ),
                          Chip(
                            avatar: const Icon(Icons.gesture, size: 16),
                            label: Text(
                              l10n.kanjiDictionaryStrokeCount(
                                candidate.strokeCount,
                              ),
                            ),
                          ),
                          Chip(
                            avatar: Text(
                              candidate.radicalCategory.radicalGlyph,
                            ),
                            label: Text(candidate.radicalCategory.displayLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                  ),
                  onPressed: onFavoriteToggle,
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceM),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(l10n.kanjiDictionaryViewDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanjiDetailSheet extends StatelessWidget {
  const _KanjiDetailSheet({
    required this.candidate,
    required this.l10n,
    required this.isFavorite,
    required this.canInsert,
    required this.isInserting,
    required this.onFavoriteToggle,
    required this.onInsert,
  });

  final KanjiCandidate candidate;
  final AppLocalizations l10n;
  final bool isFavorite;
  final bool canInsert;
  final bool isInserting;
  final VoidCallback onFavoriteToggle;
  final Future<void> Function() onInsert;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppTokens.spaceL,
          right: AppTokens.spaceL,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.spaceL,
          top: AppTokens.spaceL,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: AppTokens.radiusL,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    padding: const EdgeInsets.all(AppTokens.spaceL),
                    child: Text(
                      candidate.character,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.meanings.join(' · '),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTokens.spaceXS),
                        Text(
                          candidate.readings.join(', '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                    ),
                    onPressed: onFavoriteToggle,
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceM),
              Wrap(
                spacing: AppTokens.spaceS,
                runSpacing: AppTokens.spaceS,
                children: [
                  Chip(
                    avatar: const Icon(Icons.school, size: 16),
                    label: Text(candidate.gradeLevel.label),
                  ),
                  Chip(
                    avatar: const Icon(Icons.gesture, size: 16),
                    label: Text(
                      l10n.kanjiDictionaryStrokeCount(candidate.strokeCount),
                    ),
                  ),
                  Chip(
                    avatar: Text(candidate.radicalCategory.radicalGlyph),
                    label: Text(candidate.radicalCategory.displayLabel),
                  ),
                ],
              ),
              if (candidate.story != null) ...[
                const SizedBox(height: AppTokens.spaceM),
                Text(
                  candidate.story!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (candidate.usageExamples.isNotEmpty) ...[
                const SizedBox(height: AppTokens.spaceL),
                Text(
                  l10n.kanjiDictionaryUsageExamples,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                for (var i = 0; i < candidate.usageExamples.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      child: Text('${i + 1}'),
                    ),
                    title: Text(candidate.usageExamples[i]),
                  ),
              ],
              if (candidate.strokeOrderHints.isNotEmpty) ...[
                const SizedBox(height: AppTokens.spaceL),
                Text(
                  l10n.kanjiDictionaryStrokeOrder,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                for (var i = 0; i < candidate.strokeOrderHints.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.trending_flat),
                    title: Text(candidate.strokeOrderHints[i]),
                  ),
              ],
              const SizedBox(height: AppTokens.spaceXL),
              FilledButton.icon(
                onPressed: !canInsert || isInserting ? null : onInsert,
                icon: isInserting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_done),
                label: Text(
                  canInsert
                      ? l10n.kanjiDictionaryInsertAction
                      : l10n.kanjiDictionaryInsertDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
