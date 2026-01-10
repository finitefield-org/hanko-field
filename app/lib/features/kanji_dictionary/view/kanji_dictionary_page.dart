// ignore_for_file: public_member_api_docs, unnecessary_import

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/kanji_mapping_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/kanji_dictionary/data/models/kanji_dictionary_models.dart';
import 'package:app/features/kanji_dictionary/view_model/kanji_dictionary_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class KanjiDictionaryPage extends ConsumerStatefulWidget {
  const KanjiDictionaryPage({
    super.key,
    this.initialQuery,
    this.insertField,
    this.returnTo,
  });

  final String? initialQuery;
  final NameField? insertField;
  final String? returnTo;

  @override
  ConsumerState<KanjiDictionaryPage> createState() =>
      _KanjiDictionaryPageState();
}

class _KanjiDictionaryPageState extends ConsumerState<KanjiDictionaryPage> {
  late final TextEditingController _searchCtrl;
  late final KanjiDictionaryViewModel _viewModel;
  Timer? _debounce;
  String? _pendingQuery;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
    _viewModel = KanjiDictionaryViewModel(
      initialQuery: widget.initialQuery?.trim() ?? '',
    );
    _searchCtrl.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final navigation = context.navigation;
    final l10n = AppLocalizations.of(context);

    final state = ref.watch(_viewModel);
    final data = state.valueOrNull;

    if (_pendingQuery != null && data != null) {
      final query = _pendingQuery!;
      _pendingQuery = null;
      scheduleMicrotask(() {
        if (!mounted) return;
        _requestSearch(query);
      });
    }

    final favoritesOnlyState = ref.watch(_viewModel.favoritesOnlyMut);
    final favoriteState = ref.watch(_viewModel.favoriteMut);
    final isBusy =
        favoritesOnlyState is PendingMutationState ||
        favoriteState is PendingMutationState;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(l10n.kanjiDictionaryTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _handleBack(navigation),
        ),
        actions: [
          IconButton(
            tooltip: data?.favoritesOnly == true
                ? l10n.kanjiDictionaryToggleShowAll
                : l10n.kanjiDictionaryToggleShowFavorites,
            icon: Icon(
              data?.favoritesOnly == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
            ),
            onPressed: data == null || isBusy
                ? null
                : () => ref.invoke(_viewModel.toggleFavoritesOnly()),
          ),
          IconButton(
            tooltip: l10n.kanjiDictionaryOpenGuides,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => navigation.go(AppRoutePaths.guides),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(74),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              0,
              tokens.spacing.lg,
              tokens.spacing.md,
            ),
            child: SearchBar(
              controller: _searchCtrl,
              onSubmitted: _requestSearch,
              textInputAction: TextInputAction.search,
              hintText: l10n.kanjiDictionarySearchHint,
              trailing: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _requestSearch(_searchCtrl.text),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncLoading() when data == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const AppListSkeleton(items: 6, itemHeight: 84),
          ),
          AsyncError(:final error) when data == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: AppEmptyState(
              title: l10n.commonLoadFailed,
              message: error.toString(),
              actionLabel: l10n.commonRetry,
              onAction: () => ref.invalidate(_viewModel),
            ),
          ),
          _ when data != null => RefreshIndicator.adaptive(
            onRefresh: () async {
              await ref.invoke(_viewModel.search(data.query));
            },
            edgeOffset: tokens.spacing.md,
            displacement: tokens.spacing.xl,
            child: _Content(
              state: data,
              l10n: l10n,
              isBusy: isBusy,
              onFilterChanged: (filter) =>
                  ref.invoke(_viewModel.setFilter(filter)),
              onSelectHistory: (query) {
                _searchCtrl.text = query;
                _requestSearch(query);
              },
              onClearHistory: () => ref.invoke(_viewModel.clearHistory()),
              onToggleFavorite: (id) =>
                  ref.invoke(_viewModel.toggleFavorite(id)),
              onOpenDetail: (candidate) =>
                  _openDetail(candidate: candidate, l10n: l10n),
            ),
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  void _handleBack(NavigationController navigation) {
    if (navigation.canPop()) {
      navigation.pop();
      return;
    }
    final dest = widget.returnTo?.trim();
    if (dest != null && dest.isNotEmpty) {
      navigation.go(Uri.decodeComponent(dest));
      return;
    }
    navigation.go(AppRoutePaths.profile);
  }

  void _handleQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      _requestSearch(_searchCtrl.text);
    });
  }

  void _requestSearch(String rawQuery) {
    final current = ref.container.read(_viewModel).valueOrNull;
    if (current == null) {
      _pendingQuery = rawQuery;
      return;
    }
    ref.invoke(_viewModel.search(rawQuery));
  }

  Future<void> _openDetail({
    required KanjiCandidate candidate,
    required AppLocalizations l10n,
  }) async {
    final tokens = DesignTokensTheme.of(context);
    final entry = _toEntry(candidate, l10n: l10n);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _KanjiDetailSheet(
          entry: entry,
          l10n: l10n,
          insertField: widget.insertField,
          returnTo: widget.returnTo,
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.state,
    required this.l10n,
    required this.isBusy,
    required this.onFilterChanged,
    required this.onSelectHistory,
    required this.onClearHistory,
    required this.onToggleFavorite,
    required this.onOpenDetail,
  });

  final KanjiDictionaryState state;
  final AppLocalizations l10n;
  final bool isBusy;
  final ValueChanged<KanjiFilter> onFilterChanged;
  final ValueChanged<String> onSelectHistory;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<KanjiCandidate> onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final favorites = state.favorites;

    final results = state.favoritesOnly
        ? state.results.where((c) => favorites.contains(c.id)).toList()
        : state.results;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.lg,
              tokens.spacing.lg,
              tokens.spacing.sm,
            ),
            child: _HistorySection(
              history: state.history,
              l10n: l10n,
              onSelect: onSelectHistory,
              onClear: onClearHistory,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              0,
              tokens.spacing.lg,
              tokens.spacing.lg,
            ),
            child: _FilterChips(
              filter: state.filter,
              l10n: l10n,
              onFilterChanged: onFilterChanged,
            ),
          ),
        ),
        if (state.message != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
              child: AppValidationMessage(
                message: state.message!,
                state: AppValidationState.warning,
              ),
            ),
          ),
        SliverList.separated(
          itemBuilder: (context, index) {
            final candidate = results[index];
            final isFavorite = favorites.contains(candidate.id);
            return _KanjiListItem(
              candidate: candidate,
              l10n: l10n,
              isFavorite: isFavorite,
              isBusy: isBusy,
              onToggleFavorite: () => onToggleFavorite(candidate.id),
              onOpenDetail: () => onOpenDetail(candidate),
            );
          },
          separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.xs),
          itemCount: results.length,
        ),
        SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.xxl * 2)),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.history,
    required this.l10n,
    required this.onSelect,
    required this.onClear,
  });

  final List<String> history;
  final AppLocalizations l10n;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    if (history.isEmpty) {
      return Text(
        l10n.kanjiDictionaryHistoryHint,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.kanjiDictionaryHistoryTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.commonClear),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.xs),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: history
              .map(
                (item) => ActionChip(
                  label: Text(item),
                  avatar: const Icon(Icons.history, size: 18),
                  onPressed: () => onSelect(item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.l10n,
    required this.onFilterChanged,
  });

  final KanjiFilter filter;
  final AppLocalizations l10n;
  final ValueChanged<KanjiFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final grades = [
      (null, l10n.kanjiDictionaryGradesAll),
      (1, l10n.kanjiDictionaryGrade1),
      (2, l10n.kanjiDictionaryGrade2),
      (3, l10n.kanjiDictionaryGrade3),
      (4, l10n.kanjiDictionaryGrade4),
      (5, l10n.kanjiDictionaryGrade5),
      (6, l10n.kanjiDictionaryGrade6),
    ];

    final strokeBuckets = [
      (null, l10n.kanjiDictionaryStrokesAll),
      ('1-5', '1-5'),
      ('6-10', '6-10'),
      ('11-15', '11-15'),
      ('16+', '16+'),
    ];

    final radicals = [
      (null, l10n.kanjiDictionaryRadicalAny),
      ('water', l10n.kanjiDictionaryRadicalWater),
      ('sun', l10n.kanjiDictionaryRadicalSun),
      ('plant', l10n.kanjiDictionaryRadicalPlant),
      ('heart', l10n.kanjiDictionaryRadicalHeart),
      ('earth', l10n.kanjiDictionaryRadicalEarth),
    ];

    Widget chips<T>({
      required List<(T, String)> items,
      required T selectedValue,
      required ValueChanged<T> onSelect,
    }) {
      return Wrap(
        spacing: tokens.spacing.sm,
        runSpacing: tokens.spacing.sm,
        children: items.map((item) {
          final selected = item.$1 == selectedValue;
          return FilterChip(
            label: Text(item.$2),
            selected: selected,
            onSelected: (_) => onSelect(item.$1),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.kanjiDictionaryFiltersTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.xs),
        chips<int?>(
          items: grades,
          selectedValue: filter.grade,
          onSelect: (value) => onFilterChanged(filter.copyWith(grade: value)),
        ),
        SizedBox(height: tokens.spacing.xs),
        chips<String?>(
          items: strokeBuckets,
          selectedValue: filter.strokeBucket,
          onSelect: (value) =>
              onFilterChanged(filter.copyWith(strokeBucket: value)),
        ),
        SizedBox(height: tokens.spacing.xs),
        chips<String?>(
          items: radicals,
          selectedValue: filter.radical,
          onSelect: (value) => onFilterChanged(filter.copyWith(radical: value)),
        ),
      ],
    );
  }
}

class _KanjiListItem extends StatelessWidget {
  const _KanjiListItem({
    required this.candidate,
    required this.l10n,
    required this.isFavorite,
    required this.isBusy,
    required this.onToggleFavorite,
    required this.onOpenDetail,
  });

  final KanjiCandidate candidate;
  final AppLocalizations l10n;
  final bool isFavorite;
  final bool isBusy;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final subtitle = [
      candidate.pronunciation,
      l10n.kanjiDictionaryStrokeCount(candidate.strokeCount),
      if (candidate.radical.isNotEmpty)
        l10n.kanjiDictionaryRadicalLabel(candidate.radical),
    ].where((v) => v.trim().isNotEmpty).join(' · ');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.md,
          vertical: tokens.spacing.sm,
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onOpenDetail,
          leading: CircleAvatar(
            backgroundColor: tokens.colors.surface,
            child: Text(
              candidate.glyph.characters.take(2).toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          title: Text(
            candidate.glyph,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            '${candidate.meaning}\n$subtitle',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: isFavorite
                    ? l10n.kanjiDictionaryUnfavorite
                    : l10n.kanjiDictionaryFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                ),
                onPressed: isBusy ? null : onToggleFavorite,
              ),
              IconButton(
                tooltip: l10n.kanjiDictionaryDetails,
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: onOpenDetail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanjiDetailSheet extends ConsumerWidget {
  const _KanjiDetailSheet({
    required this.entry,
    required this.l10n,
    required this.insertField,
    required this.returnTo,
  });

  final KanjiDictionaryEntry entry;
  final AppLocalizations l10n;
  final NameField? insertField;
  final String? returnTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final navigation = context.navigation;
    final candidate = entry.candidate;

    final canInsert = insertField != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.colors.surface,
                borderRadius: BorderRadius.circular(tokens.radii.md),
              ),
              child: Text(
                candidate.glyph.characters.take(2).toString(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            SizedBox(width: tokens.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.glyph,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    candidate.meaning,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    candidate.pronunciation,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: [
            InputChip(
              label: Text(
                l10n.kanjiDictionaryChipStrokes(candidate.strokeCount),
              ),
              onPressed: () {},
            ),
            InputChip(
              label: Text(l10n.kanjiDictionaryChipRadical(candidate.radical)),
              onPressed: () {},
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        Text(
          l10n.kanjiDictionaryStrokeOrderTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.xs),
        Text(entry.strokeOrderPreview),
        SizedBox(height: tokens.spacing.lg),
        Text(
          l10n.kanjiDictionaryExamplesTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.xs),
        ...entry.examples.map(
          (example) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.xs),
            child: Text('• $example'),
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        if (canInsert)
          FilledButton.icon(
            onPressed: () async {
              await _insertIntoDesign(ref, insertField!, candidate.glyph);
              if (!context.mounted) return;
              await Navigator.of(context).maybePop();
              final dest = returnTo?.trim();
              if (dest != null && dest.isNotEmpty) {
                await navigation.go(Uri.decodeComponent(dest));
              } else {
                await navigation.go(AppRoutePaths.designInput);
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.kanjiDictionaryInsertIntoNameInput),
          )
        else
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.kanjiDictionaryDone),
          ),
      ],
    );
  }

  Future<void> _insertIntoDesign(
    WidgetRef ref,
    NameField field,
    String glyph,
  ) async {
    final current = ref.container.read(designCreationViewModel).valueOrNull;
    final draft = current?.nameDraft ?? const NameInputDraft();
    final existing = _fieldValue(draft, field);
    final next = glyph.trim().isEmpty ? existing : glyph.trim();
    await ref.invoke(designCreationViewModel.updateNameField(field, next));
  }

  String _fieldValue(NameInputDraft draft, NameField field) {
    return switch (field) {
      NameField.surnameKanji => draft.surnameKanji,
      NameField.givenKanji => draft.givenKanji,
      NameField.surnameKana => draft.surnameKana,
      NameField.givenKana => draft.givenKana,
    };
  }
}

KanjiDictionaryEntry _toEntry(
  KanjiCandidate candidate, {
  required AppLocalizations l10n,
}) {
  final examples = <String>[
    if (candidate.glyph.trim().isNotEmpty) '${candidate.glyph}印',
    if (candidate.keywords.isNotEmpty)
      ...candidate.keywords.take(3).map((k) => k),
    l10n.kanjiDictionaryExampleUsage,
  ].where((value) => value.trim().isNotEmpty).toList();

  final strokePreview = _strokeOrderPreview(candidate.strokeCount, l10n: l10n);

  return KanjiDictionaryEntry(
    candidate: candidate,
    examples: examples,
    strokeOrderPreview: strokePreview,
  );
}

String _strokeOrderPreview(int strokes, {required AppLocalizations l10n}) {
  if (strokes <= 0) {
    return l10n.kanjiDictionaryNoStrokeData;
  }
  final shown = strokes.clamp(1, 12);
  final steps = List.generate(shown, (i) => '${i + 1}');
  final tail = strokes > shown ? '…' : '';
  return l10n.kanjiDictionaryStrokeOrderPrefix('${steps.join(' → ')}$tail');
}

NameField? parseNameFieldParam(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return NameField.values.firstWhereOrNull((field) => field.name == value);
}
