import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_text_field.dart';
import 'package:app/features/design_creation/application/kanji_mapping_controller.dart';
import 'package:app/features/design_creation/application/kanji_mapping_state.dart';
import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesignKanjiMappingPage extends ConsumerStatefulWidget {
  const DesignKanjiMappingPage({super.key});

  @override
  ConsumerState<DesignKanjiMappingPage> createState() =>
      _DesignKanjiMappingPageState();
}

class _DesignKanjiMappingPageState
    extends ConsumerState<DesignKanjiMappingPage> {
  late final TextEditingController _queryController;
  late final TextEditingController _manualKanjiController;
  late final TextEditingController _manualMeaningController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _manualKanjiController = TextEditingController();
    _manualMeaningController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _manualKanjiController.dispose();
    _manualMeaningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(kanjiMappingControllerProvider);
    final notifier = ref.read(kanjiMappingControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _syncController(_queryController, state.query);
    _syncController(_manualKanjiController, state.manualKanji);
    _syncController(_manualMeaningController, state.manualMeaning);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.errorMessage != null) {
        _showSnackBar(
          context,
          state.errorMessage!,
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
        );
        notifier.clearTransientMessages();
      } else if (state.infoMessage != null) {
        _showSnackBar(
          context,
          state.infoMessage!,
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        );
        notifier.clearTransientMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designKanjiMappingTitle),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceM,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: FilledButton.icon(
          onPressed: state.isSaving || !state.hasSelection
              ? null
              : notifier.confirmSelection,
          icon: state.isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(l10n.designKanjiMappingConfirm),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarHeaderDelegate(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceS,
                  ),
                  child: _SearchSection(
                    controller: _queryController,
                    onChanged: notifier.updateQuery,
                    onSubmitted: () =>
                        notifier.search(refresh: true, allowEmptyQuery: true),
                    isLoading: state.isLoading,
                    l10n: l10n,
                  ),
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
                  onToggleStroke: notifier.toggleStrokeFilter,
                  onToggleRadical: notifier.toggleRadicalFilter,
                ),
              ),
            ),
            if (state.compareSelection.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceL,
                    vertical: AppTokens.spaceS,
                  ),
                  child: _CompareSection(state: state, l10n: l10n),
                ),
              ),
            if (state.results.isEmpty && !state.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceL,
                    vertical: AppTokens.spaceXL,
                  ),
                  child: _EmptyResultsPlaceholder(l10n: l10n),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final candidate = state.results[index];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTokens.spaceL,
                      index == 0 ? AppTokens.spaceS : AppTokens.spaceXS,
                      AppTokens.spaceL,
                      AppTokens.spaceXS,
                    ),
                    child: KanjiCandidateTile(
                      candidate: candidate,
                      selectedId: state.selectedCandidateId,
                      bookmarked: state.bookmarks.contains(candidate.id),
                      inCompare: state.compareSelection.contains(candidate.id),
                      l10n: l10n,
                      onSelect: () => notifier.selectCandidate(candidate.id),
                      onToggleBookmark: () =>
                          notifier.toggleBookmark(candidate.id),
                      onToggleCompare: () =>
                          notifier.toggleCompare(candidate.id),
                    ),
                  );
                }, childCount: state.results.length),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceXL,
                  AppTokens.spaceL,
                  AppTokens.spaceXXL,
                ),
                child: _ManualEntryCard(
                  kanjiController: _manualKanjiController,
                  meaningController: _manualMeaningController,
                  onKanjiChanged: notifier.updateManualKanji,
                  onMeaningChanged: notifier.updateManualMeaning,
                  l10n: l10n,
                  colorScheme: colorScheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message,
    Color background,
    Color foreground,
  ) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: foreground)),
          backgroundColor: background,
        ),
      );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.isLoading,
    required this.l10n,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool isLoading;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchBar(
          controller: controller,
          hintText: l10n.designKanjiMappingSearchHint,
          leading: const Icon(Icons.search),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: AppTokens.spaceM),
          ),
          trailing: [
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onSubmitted,
              tooltip: l10n.designKanjiMappingRefreshTooltip,
            ),
          ],
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: AppTokens.spaceS),
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.state,
    required this.onToggleStroke,
    required this.onToggleRadical,
  });

  final KanjiMappingState state;
  final ValueChanged<KanjiStrokeBucket> onToggleStroke;
  final ValueChanged<KanjiRadicalCategory> onToggleRadical;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final bucket in KanjiStrokeBucket.values)
              FilterChip(
                label: Text(bucket.label),
                selected: state.strokeFilters.contains(bucket),
                onSelected: (_) => onToggleStroke(bucket),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final radical in KanjiRadicalCategory.values)
              FilterChip(
                label: Text(radical.displayLabel),
                avatar: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSecondaryContainer,
                  child: Text(radical.radicalGlyph),
                ),
                selected: state.radicalFilters.contains(radical),
                onSelected: (_) => onToggleRadical(radical),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompareSection extends StatelessWidget {
  const _CompareSection({required this.state, required this.l10n});

  final KanjiMappingState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTokens.radiusL,
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppTokens.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.designKanjiMappingCompareHeader,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: [
              for (final candidate in state.compareCandidates)
                Chip(
                  avatar: const Icon(Icons.balance_outlined),
                  label: Text(
                    '${candidate.character} · ${candidate.meanings.first}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualEntryCard extends StatelessWidget {
  const _ManualEntryCard({
    required this.kanjiController,
    required this.meaningController,
    required this.onKanjiChanged,
    required this.onMeaningChanged,
    required this.l10n,
    required this.colorScheme,
  });

  final TextEditingController kanjiController;
  final TextEditingController meaningController;
  final ValueChanged<String> onKanjiChanged;
  final ValueChanged<String> onMeaningChanged;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: AppTokens.radiusL,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.designKanjiMappingManualTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.designKanjiMappingManualDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.spaceL),
          AppTextField(
            controller: kanjiController,
            label: l10n.designKanjiMappingManualKanjiLabel,
            helper: l10n.designKanjiMappingManualKanjiHelper,
            onChanged: onKanjiChanged,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: meaningController,
            label: l10n.designKanjiMappingManualMeaningLabel,
            helper: l10n.designKanjiMappingManualMeaningHelper,
            onChanged: onMeaningChanged,
          ),
        ],
      ),
    );
  }
}

class _EmptyResultsPlaceholder extends StatelessWidget {
  const _EmptyResultsPlaceholder({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: AppTokens.spaceM),
        Text(
          l10n.designKanjiMappingEmptyResultsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          l10n.designKanjiMappingEmptyResultsDescription,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class KanjiCandidateTile extends StatelessWidget {
  const KanjiCandidateTile({
    required this.candidate,
    required this.selectedId,
    required this.bookmarked,
    required this.inCompare,
    required this.l10n,
    required this.onSelect,
    required this.onToggleBookmark,
    required this.onToggleCompare,
    super.key,
  });

  final KanjiCandidate candidate;
  final String? selectedId;
  final bool bookmarked;
  final bool inCompare;
  final AppLocalizations l10n;
  final VoidCallback onSelect;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = selectedId == candidate.id;
    final surface = selected
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerLowest;
    final onSurface = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurface;

    return Material(
      color: surface,
      borderRadius: AppTokens.radiusL,
      child: InkWell(
        borderRadius: AppTokens.radiusL,
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: AppTokens.radiusM,
                      color: colorScheme.surfaceTint.withValues(alpha: 0.08),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      candidate.character,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              candidate.meanings.first,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: onSurface),
                            ),
                            const SizedBox(width: AppTokens.spaceS),
                            _PopularityBadge(score: candidate.popularityScore),
                          ],
                        ),
                        const SizedBox(height: AppTokens.spaceXS),
                        Text(
                          candidate.meanings.join(' / '),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppTokens.spaceXS),
                        Text(
                          candidate.readings.join(', '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (candidate.story != null &&
                            candidate.story!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTokens.spaceXS,
                            ),
                            child: Text(
                              candidate.story!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        const SizedBox(height: AppTokens.spaceS),
                        Wrap(
                          spacing: AppTokens.spaceS,
                          runSpacing: AppTokens.spaceS,
                          children: [
                            FilterChip(
                              label: Text(
                                inCompare
                                    ? l10n.designKanjiMappingCompareSelectedLabel
                                    : l10n.designKanjiMappingCompareToggleLabel,
                              ),
                              selected: inCompare,
                              onSelected: (_) => onToggleCompare(),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.psychology_outlined,
                                size: 16,
                              ),
                              label: Text(
                                l10n.designKanjiMappingStrokeCountLabel(
                                  candidate.strokeCount,
                                ),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Chip(
                              avatar: Text(
                                candidate.radicalCategory.radicalGlyph,
                              ),
                              label: Text(
                                candidate.radicalCategory.displayLabel,
                              ),
                            ),
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
                        onPressed: onSelect,
                        icon: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        tooltip: l10n.designKanjiMappingSelectTooltip,
                      ),
                      IconButton(
                        onPressed: onToggleBookmark,
                        icon: Icon(
                          bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                        ),
                        tooltip: bookmarked
                            ? l10n.designKanjiMappingBookmarkRemove
                            : l10n.designKanjiMappingBookmarkAdd,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularityBadge extends StatelessWidget {
  const _PopularityBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: AppTokens.radiusS,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceS,
        vertical: AppTokens.spaceXS,
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: 16, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            '$score/5',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchBarHeaderDelegate({required this.child});

  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 3 : 0,
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }

  @override
  double get maxExtent => 98;

  @override
  double get minExtent => 98;

  @override
  bool shouldRebuild(covariant _SearchBarHeaderDelegate oldDelegate) {
    return false;
  }
}
