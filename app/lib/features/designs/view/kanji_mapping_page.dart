// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/features/designs/data/models/kanji_mapping_models.dart';
import 'package:app/features/designs/view_model/kanji_mapping_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class KanjiMappingPage extends ConsumerStatefulWidget {
  const KanjiMappingPage({super.key});

  @override
  ConsumerState<KanjiMappingPage> createState() => _KanjiMappingPageState();
}

class _KanjiMappingPageState extends ConsumerState<KanjiMappingPage> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _manualCtrl;
  bool _bookmarksOnly = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _manualCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final ui = ref.watch(kanjiMappingViewModel);
    final applyState = ref.watch(kanjiMappingViewModel.applyMut);
    final applying = applyState is PendingMutationState;
    final state = ui.valueOrNull;

    _syncControllers(state);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(prefersEnglish ? 'Kanji helper' : '漢字マップ'),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: _bookmarksOnly
                ? (prefersEnglish ? 'Show all candidates' : 'すべて表示')
                : (prefersEnglish ? 'Show bookmarks only' : 'ブックマークのみ'),
            icon: Icon(
              _bookmarksOnly ? Icons.bookmarks : Icons.bookmarks_outlined,
            ),
            onPressed: state == null
                ? null
                : () => setState(() => _bookmarksOnly = !_bookmarksOnly),
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
              onSubmitted: _handleSearch,
              textInputAction: TextInputAction.search,
              hintText: prefersEnglish
                  ? 'Search by meaning, reading, or name'
                  : '意味・読み・名前で検索',
              trailing: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _handleSearch(_searchCtrl.text),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: switch (ui) {
          AsyncLoading<KanjiMapState>() when state == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const AppListSkeleton(items: 5, itemHeight: 96),
          ),
          AsyncError(:final error) when state == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: AppEmptyState(
              title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
              message: error.toString(),
              actionLabel: prefersEnglish ? 'Retry' : '再試行',
              onAction: () => ref.invalidate(kanjiMappingViewModel),
            ),
          ),
          _ when state != null => RefreshIndicator.adaptive(
            onRefresh: () async {
              await ref.invoke(kanjiMappingViewModel.search(state.query));
            },
            edgeOffset: tokens.spacing.md,
            displacement: tokens.spacing.xl,
            child: _Content(
              state: state,
              prefersEnglish: prefersEnglish,
              bookmarksOnly: _bookmarksOnly,
            ),
          ),
          _ => const SizedBox.shrink(),
        },
      ),
      bottomNavigationBar: state == null
          ? null
          : SafeArea(
              minimum: EdgeInsets.all(tokens.spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ManualEntryRow(
                    controller: _manualCtrl,
                    prefersEnglish: prefersEnglish,
                    onChanged: (value) => ref.invoke(
                      kanjiMappingViewModel.updateManualEntry(value),
                    ),
                    onSubmit: _manualCtrl.text.trim().isEmpty
                        ? null
                        : () =>
                              _applySelection(manual: _manualCtrl.text.trim()),
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  FilledButton.icon(
                    onPressed: applying || state.selectedId == null
                        ? null
                        : () => _applySelection(),
                    icon: applying
                        ? SizedBox(
                            width: tokens.spacing.md,
                            height: tokens.spacing.md,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(
                                tokens.colors.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(prefersEnglish ? 'Use selection' : '候補を反映'),
                  ),
                ],
              ),
            ),
    );
  }

  void _syncControllers(KanjiMapState? state) {
    if (state == null) return;
    if (_searchCtrl.text != state.query) {
      _searchCtrl.value = TextEditingValue(
        text: state.query,
        selection: TextSelection.collapsed(offset: state.query.length),
      );
    }
    if (_manualCtrl.text != state.manualEntry) {
      _manualCtrl.value = TextEditingValue(
        text: state.manualEntry,
        selection: TextSelection.collapsed(offset: state.manualEntry.length),
      );
    }
  }

  void _handleSearch(String value) {
    ref.invoke(kanjiMappingViewModel.search(value));
  }

  Future<void> _applySelection({String? manual}) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;
    try {
      await ref.invoke(
        kanjiMappingViewModel.applySelection(manualValue: manual),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            manual == null
                ? (prefersEnglish
                      ? 'Applied the selected kanji.'
                      : '選んだ漢字を入力に反映しました')
                : (prefersEnglish
                      ? 'Applied your manual entry.'
                      : '入力した漢字を反映しました'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Navigator.of(context).maybePop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.state,
    required this.prefersEnglish,
    required this.bookmarksOnly,
  });

  final KanjiMapState state;
  final bool prefersEnglish;
  final bool bookmarksOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final filtered = state.candidates.where((candidate) {
      if (!bookmarksOnly) return true;
      return state.bookmarks.contains(candidate.id);
    }).toList();

    final compare = state.compareIds
        .map((id) => state.candidates.firstWhereOrNull((c) => c.id == id))
        .nonNulls
        .toList();

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.fromCache || state.message != null)
                  _StatusBanner(
                    fromCache: state.fromCache,
                    cachedAt: state.cachedAt,
                    message: state.message,
                    prefersEnglish: prefersEnglish,
                  ),
                _FilterSection(
                  filter: state.filter,
                  prefersEnglish: prefersEnglish,
                  onFilterChanged: (filter) =>
                      ref.invoke(kanjiMappingViewModel.setFilter(filter)),
                ),
                if (compare.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.sm),
                  _ComparePanel(items: compare, prefersEnglish: prefersEnglish),
                ],
              ],
            ),
          ),
        ),
        if (state.isLoading && state.candidates.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: const AppListSkeleton(items: 4, itemHeight: 90),
            ),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.lg),
                child: AppEmptyState(
                  title: prefersEnglish ? 'No matches' : '候補が見つかりません',
                  message: prefersEnglish
                      ? 'Try adjusting filters or enter manually below.'
                      : 'フィルターを変更するか手入力をご利用ください。',
                  actionLabel: prefersEnglish ? 'Clear filters' : 'フィルターをクリア',
                  onAction: () => ref.invoke(
                    kanjiMappingViewModel.setFilter(const KanjiFilter()),
                  ),
                ),
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final candidate = filtered[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  index == 0 ? tokens.spacing.sm : tokens.spacing.xs,
                  tokens.spacing.lg,
                  0,
                ),
                child: _KanjiCandidateTile(
                  candidate: candidate,
                  groupValue: state.selectedId,
                  comparing: state.compareIds.contains(candidate.id),
                  bookmarked: state.bookmarks.contains(candidate.id),
                  prefersEnglish: prefersEnglish,
                  onSelect: (id) =>
                      ref.invoke(kanjiMappingViewModel.selectCandidate(id)),
                  onToggleCompare: (id) =>
                      ref.invoke(kanjiMappingViewModel.toggleCompare(id)),
                  onToggleBookmark: (id) =>
                      ref.invoke(kanjiMappingViewModel.toggleBookmark(id)),
                ),
              );
            },
            separatorBuilder: (context, index) =>
                SizedBox(height: tokens.spacing.xs),
          ),
        SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.xl)),
      ],
    );
  }
}

class _KanjiCandidateTile extends StatelessWidget {
  const _KanjiCandidateTile({
    required this.candidate,
    required this.groupValue,
    required this.comparing,
    required this.bookmarked,
    required this.prefersEnglish,
    required this.onSelect,
    required this.onToggleCompare,
    required this.onToggleBookmark,
  });

  final KanjiCandidate candidate;
  final String? groupValue;
  final bool comparing;
  final bool bookmarked;
  final bool prefersEnglish;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onToggleCompare;
  final ValueChanged<String> onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final popularity = '${(candidate.popularity * 100).round()}%';

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: tokens.colors.primary.withValues(alpha: 0.1),
              child: Text(
                candidate.glyph,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: tokens.colors.primary),
              ),
            ),
            title: Text(
              candidate.meaning,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              '${candidate.pronunciation} · ${candidate.strokeCount} ${prefersEnglish ? 'strokes' : '画'} · $popularity',
            ),
            trailing: Radio<String>(
              value: candidate.id,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: (value) => onSelect(value),
            ),
            onTap: () => onSelect(candidate.id),
          ),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: [
              FilterChip(
                label: Text(
                  comparing
                      ? (prefersEnglish ? 'Comparing' : '比較中')
                      : (prefersEnglish ? 'Compare' : '比較する'),
                ),
                selected: comparing,
                onSelected: (_) => onToggleCompare(candidate.id),
              ),
              FilterChip(
                avatar: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                ),
                label: Text(
                  bookmarked
                      ? (prefersEnglish ? 'Saved' : '保存済み')
                      : (prefersEnglish ? 'Bookmark' : '保存'),
                ),
                selected: bookmarked,
                onSelected: (_) => onToggleBookmark(candidate.id),
              ),
              InputChip(
                label: Text(
                  '${prefersEnglish ? 'Radical' : '部首'}: ${candidate.radical}',
                ),
                onPressed: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.filter,
    required this.prefersEnglish,
    required this.onFilterChanged,
  });

  final KanjiFilter filter;
  final bool prefersEnglish;
  final ValueChanged<KanjiFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final strokeBuckets = [
      _FilterOption(null, prefersEnglish ? 'All strokes' : 'すべて'),
      const _FilterOption('1-5', '1-5'),
      const _FilterOption('6-10', '6-10'),
      const _FilterOption('11-15', '11-15'),
      const _FilterOption('16+', '16+'),
    ];

    final radicals = [
      _FilterOption(null, prefersEnglish ? 'Any radical' : '部首を選択'),
      _FilterOption('water', prefersEnglish ? 'Water' : '水'),
      _FilterOption('sun', prefersEnglish ? 'Sun' : '日'),
      _FilterOption('plant', prefersEnglish ? 'Plant' : '草'),
      _FilterOption('heart', prefersEnglish ? 'Heart' : '心'),
      _FilterOption('earth', prefersEnglish ? 'Earth' : '土'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefersEnglish ? 'Filters' : '絞り込み',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.xs),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: strokeBuckets.map((option) {
            final selected = filter.strokeBucket == option.value;
            return FilterChip(
              label: Text(option.label),
              selected: selected,
              onSelected: (_) =>
                  onFilterChanged(filter.copyWith(strokeBucket: option.value)),
            );
          }).toList(),
        ),
        SizedBox(height: tokens.spacing.xs),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: radicals.map((option) {
            final selected = filter.radical == option.value;
            return FilterChip(
              label: Text(option.label),
              selected: selected,
              onSelected: (_) =>
                  onFilterChanged(filter.copyWith(radical: option.value)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ComparePanel extends StatelessWidget {
  const _ComparePanel({required this.items, required this.prefersEnglish});

  final List<KanjiCandidate> items;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded),
              SizedBox(width: tokens.spacing.sm),
              Text(
                prefersEnglish ? 'Comparing' : '比較中の候補',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: items.map((item) {
              return Chip(
                label: Text(
                  '${item.glyph} · ${item.meaning}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.fromCache,
    required this.cachedAt,
    required this.message,
    required this.prefersEnglish,
  });

  final bool fromCache;
  final DateTime? cachedAt;
  final String? message;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final cacheLabel = cachedAt != null
        ? '${prefersEnglish ? 'Cached' : 'キャッシュ'} ${cachedAt!.toLocal()}'
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.sm),
      child: AppCard(
        padding: EdgeInsets.all(tokens.spacing.sm),
        child: Row(
          children: [
            Icon(
              fromCache ? Icons.offline_bolt : Icons.info_outline,
              color: fromCache
                  ? tokens.colors.primary
                  : tokens.colors.onSurface,
            ),
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fromCache
                        ? (prefersEnglish
                              ? 'Offline suggestions'
                              : 'オフライン候補を表示中')
                        : (prefersEnglish ? 'Live suggestions' : '最新の候補を表示'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (cacheLabel != null)
                    Text(
                      cacheLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (message != null)
                    Text(
                      message!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.8),
                      ),
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

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String? value;
  final String label;
}

class _ManualEntryRow extends StatelessWidget {
  const _ManualEntryRow({
    required this.controller,
    required this.prefersEnglish,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool prefersEnglish;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: controller,
            label: prefersEnglish ? 'Manual entry' : '手入力',
            hintText: prefersEnglish ? 'Type kanji or Latin' : '漢字または英字',
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit?.call(),
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
        OutlinedButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.edit_note_outlined),
          label: Text(prefersEnglish ? 'Apply manual' : '手入力を適用'),
        ),
      ],
    );
  }
}
