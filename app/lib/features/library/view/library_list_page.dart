// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/data/repositories/design_repository.dart';
import 'package:app/features/library/view_model/library_list_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LibraryListPage extends ConsumerStatefulWidget {
  const LibraryListPage({super.key});

  @override
  ConsumerState<LibraryListPage> createState() => _LibraryListPageState();
}

class _LibraryListPageState extends ConsumerState<LibraryListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _syncingQuery = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(libraryListViewModel);
    final view = state.valueOrNull;

    if (view != null && _searchController.text != view.query) {
      _syncingQuery = true;
      _searchController.text = view.query;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
      _syncingQuery = false;
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        titleSpacing: tokens.spacing.sm,
        title: SearchBar(
          controller: _searchController,
          hintText: prefersEnglish ? 'Search designs' : '印鑑を検索',
          leading: const Icon(Icons.search_rounded),
          trailing: [
            if (_searchController.text.trim().isNotEmpty)
              IconButton(
                tooltip: prefersEnglish ? 'Clear' : 'クリア',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _searchController.clear();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.lg,
                tokens.spacing.md,
                tokens.spacing.lg,
                tokens.spacing.sm,
              ),
              child: _LibraryControls(
                prefersEnglish: prefersEnglish,
                state: view,
                onStatusSelected: (status) => unawaited(
                  ref.invoke(libraryListViewModel.setStatus(status)),
                ),
                onDateSelected: (date) =>
                    unawaited(ref.invoke(libraryListViewModel.setDate(date))),
                onAiSelected: (ai) =>
                    unawaited(ref.invoke(libraryListViewModel.setAi(ai))),
                onPersonaSelected: (persona) => unawaited(
                  ref.invoke(libraryListViewModel.setPersona(persona)),
                ),
                onSortSelected: (sort) =>
                    unawaited(ref.invoke(libraryListViewModel.setSort(sort))),
                onLayoutSelected: (layout) => unawaited(
                  ref.invoke(libraryListViewModel.setLayout(layout)),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator.adaptive(
                displacement: tokens.spacing.xl,
                edgeOffset: tokens.spacing.md,
                onRefresh: () => ref.invoke(libraryListViewModel.refresh()),
                child: _LibraryContent(
                  scrollController: _scrollController,
                  prefersEnglish: prefersEnglish,
                  tokens: tokens,
                  state: state,
                  onRetry: () =>
                      unawaited(ref.invoke(libraryListViewModel.refresh())),
                  onCreateNew: () =>
                      GoRouter.of(context).go(AppRoutePaths.designNew),
                  onOpenDetail: (design) {
                    final id = design.id;
                    if (id == null) return;
                    GoRouter.of(context).go('${AppRoutePaths.library}/$id');
                  },
                  onPreview: (design) => _showPreview(context, design),
                  onShare: (design) => _showToast(
                    context,
                    prefersEnglish
                        ? 'Share link copied (mock)'
                        : '共有リンクをコピーしました（モック）',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final current = ref.container.read(libraryListViewModel).valueOrNull;
    if (current == null ||
        current.nextPageToken == null ||
        current.isLoadingMore) {
      return;
    }

    if (_scrollController.position.extentAfter < 320) {
      unawaited(ref.invoke(libraryListViewModel.loadMore()));
    }
  }

  void _onQueryChanged() {
    if (_syncingQuery) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final query = _searchController.text;
      final current = ref.container.read(libraryListViewModel).valueOrNull;
      if (current != null && current.query == query) return;
      unawaited(ref.invoke(libraryListViewModel.setQuery(query)));
    });
  }

  Future<void> _showPreview(BuildContext context, Design design) async {
    final tokens = DesignTokensTheme.of(context);
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;
    final url = design.assets?.previewPngUrl ?? design.assets?.stampMockUrl;
    if (url == null) {
      _showToast(
        context,
        prefersEnglish ? 'No preview available' : 'プレビューはありません',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.all(tokens.spacing.lg),
          child: AspectRatio(
            aspectRatio: 1,
            child: Hero(
              tag: _heroTag(design),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.md),
                child: Image.network(url, fit: BoxFit.cover),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.prefersEnglish,
    required this.state,
    required this.onStatusSelected,
    required this.onDateSelected,
    required this.onAiSelected,
    required this.onPersonaSelected,
    required this.onSortSelected,
    required this.onLayoutSelected,
  });

  final bool prefersEnglish;
  final LibraryListState? state;
  final ValueChanged<DesignStatus?> onStatusSelected;
  final ValueChanged<LibraryDateFilter> onDateSelected;
  final ValueChanged<LibraryAiFilter> onAiSelected;
  final ValueChanged<LibraryPersonaFilter> onPersonaSelected;
  final ValueChanged<DesignSort> onSortSelected;
  final ValueChanged<LibraryLayout> onLayoutSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final view = state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SortMenu(
              prefersEnglish: prefersEnglish,
              value: view?.sort ?? DesignSort.recent,
              onSelected: onSortSelected,
            ),
            SegmentedButton<LibraryLayout>(
              segments: [
                ButtonSegment(
                  value: LibraryLayout.grid,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text(prefersEnglish ? 'Grid' : 'グリッド'),
                ),
                ButtonSegment(
                  value: LibraryLayout.list,
                  icon: const Icon(Icons.view_list_rounded),
                  label: Text(prefersEnglish ? 'List' : 'リスト'),
                ),
              ],
              selected: {view?.layout ?? LibraryLayout.grid},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                onLayoutSelected(value.first);
              },
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: [
            _chip<DesignStatus?>(
              label: prefersEnglish ? 'All statuses' : 'すべて',
              selected: view?.status == null,
              onSelected: () => onStatusSelected(null),
            ),
            for (final status in DesignStatus.values)
              _chip<DesignStatus?>(
                label: _statusLabel(status, prefersEnglish),
                selected: view?.status == status,
                onSelected: () => onStatusSelected(status),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: [
            for (final filter in LibraryDateFilter.values)
              _chip<LibraryDateFilter>(
                label: _dateLabel(filter, prefersEnglish),
                selected: (view?.date ?? LibraryDateFilter.all) == filter,
                onSelected: () => onDateSelected(filter),
              ),
            for (final ai in LibraryAiFilter.values)
              _chip<LibraryAiFilter>(
                label: _aiLabel(ai, prefersEnglish),
                selected: (view?.ai ?? LibraryAiFilter.any) == ai,
                onSelected: () => onAiSelected(ai),
              ),
            for (final persona in LibraryPersonaFilter.values)
              _chip<LibraryPersonaFilter>(
                label: _personaLabel(persona, prefersEnglish),
                selected:
                    (view?.persona ?? LibraryPersonaFilter.all) == persona,
                onSelected: () => onPersonaSelected(persona),
              ),
          ],
        ),
      ],
    );
  }

  Widget _chip<T>({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }

  String _statusLabel(DesignStatus status, bool prefersEnglish) {
    return switch (status) {
      DesignStatus.draft => prefersEnglish ? 'Draft' : '下書き',
      DesignStatus.ready => prefersEnglish ? 'Ready' : '準備完了',
      DesignStatus.ordered => prefersEnglish ? 'Ordered' : '注文済み',
      DesignStatus.locked => prefersEnglish ? 'Locked' : 'ロック',
    };
  }

  String _dateLabel(LibraryDateFilter filter, bool prefersEnglish) {
    return switch (filter) {
      LibraryDateFilter.all => prefersEnglish ? 'All time' : '全期間',
      LibraryDateFilter.last7Days => prefersEnglish ? '7 days' : '7日',
      LibraryDateFilter.last30Days => prefersEnglish ? '30 days' : '30日',
      LibraryDateFilter.last365Days => prefersEnglish ? '1 year' : '1年',
    };
  }

  String _aiLabel(LibraryAiFilter filter, bool prefersEnglish) {
    return switch (filter) {
      LibraryAiFilter.any => prefersEnglish ? 'AI: any' : 'AI: 全て',
      LibraryAiFilter.score80Plus => prefersEnglish ? 'AI: 80%+' : 'AI: 80%+',
      LibraryAiFilter.score60Plus => prefersEnglish ? 'AI: 60%+' : 'AI: 60%+',
      LibraryAiFilter.score40Plus => prefersEnglish ? 'AI: 40%+' : 'AI: 40%+',
    };
  }

  String _personaLabel(LibraryPersonaFilter filter, bool prefersEnglish) {
    return switch (filter) {
      LibraryPersonaFilter.all => prefersEnglish ? 'Persona: all' : 'モード: 全て',
      LibraryPersonaFilter.japanese =>
        prefersEnglish ? 'Persona: JP' : 'モード: 日本',
      LibraryPersonaFilter.foreigner =>
        prefersEnglish ? 'Persona: INTL' : 'モード: 海外',
    };
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.prefersEnglish,
    required this.value,
    required this.onSelected,
  });

  final bool prefersEnglish;
  final DesignSort value;
  final ValueChanged<DesignSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<DesignSort>(
      initialSelection: value,
      requestFocusOnTap: false,
      dropdownMenuEntries: [
        DropdownMenuEntry(
          value: DesignSort.recent,
          label: prefersEnglish ? 'Recent' : '新しい順',
          leadingIcon: const Icon(Icons.schedule_rounded),
        ),
        DropdownMenuEntry(
          value: DesignSort.aiScore,
          label: prefersEnglish ? 'AI score' : 'AIスコア',
          leadingIcon: const Icon(Icons.auto_awesome_rounded),
        ),
        DropdownMenuEntry(
          value: DesignSort.name,
          label: prefersEnglish ? 'Name' : '名前',
          leadingIcon: const Icon(Icons.sort_by_alpha_rounded),
        ),
      ],
      onSelected: (sort) {
        if (sort == null) return;
        onSelected(sort);
      },
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.scrollController,
    required this.prefersEnglish,
    required this.tokens,
    required this.state,
    required this.onRetry,
    required this.onCreateNew,
    required this.onOpenDetail,
    required this.onPreview,
    required this.onShare,
  });

  final ScrollController scrollController;
  final bool prefersEnglish;
  final DesignTokens tokens;
  final AsyncValue<LibraryListState> state;
  final VoidCallback onRetry;
  final VoidCallback onCreateNew;
  final ValueChanged<Design> onOpenDetail;
  final ValueChanged<Design> onPreview;
  final ValueChanged<Design> onShare;

  @override
  Widget build(BuildContext context) {
    final loading = state is AsyncLoading<LibraryListState>;
    final error = state is AsyncError<LibraryListState>;
    final view = state.valueOrNull;

    if (loading && view == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        child: const AppListSkeleton(items: 6, itemHeight: 96),
      );
    }

    if (error && view == null) {
      final message = switch (state) {
        AsyncError<LibraryListState>(:final error) => error.toString(),
        _ => prefersEnglish ? 'Failed to load' : '読み込みに失敗しました',
      };
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish
              ? 'Could not load library'
              : 'ライブラリの読み込みに失敗しました',
          message: message,
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: onRetry,
        ),
      );
    }

    final items = view?.items ?? const <Design>[];
    final hasMore = view?.nextPageToken != null;
    final isLoadingMore = view?.isLoadingMore == true;

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: tokens.spacing.xl),
          AppEmptyState(
            title: prefersEnglish ? 'No designs yet' : 'まだ印鑑がありません',
            message: prefersEnglish
                ? 'Create your first design to build your library.'
                : '最初の印鑑を作成して、ライブラリに追加しましょう。',
            icon: Icons.collections_bookmark_outlined,
            actionLabel: prefersEnglish ? 'Create new' : '新規作成',
            onAction: onCreateNew,
          ),
        ],
      );
    }

    final layout = view?.layout ?? LibraryLayout.grid;
    final content = layout == LibraryLayout.list
        ? _buildList(
            context,
            items,
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
          )
        : _buildGrid(
            context,
            items,
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
          );

    return content;
  }

  Widget _buildList(
    BuildContext context,
    List<Design> items, {
    required bool hasMore,
    required bool isLoadingMore,
  }) {
    return ListView.separated(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.xs,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      itemCount: items.length + (hasMore || isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _loadMoreFooter(context, isLoadingMore);
        }
        final design = items[index];
        return _LibraryListTile(
          prefersEnglish: prefersEnglish,
          design: design,
          onTap: () => onOpenDetail(design),
          onPreview: () => onPreview(design),
          onShare: () => onShare(design),
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<Design> items, {
    required bool hasMore,
    required bool isLoadingMore,
  }) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= AppBreakpoints.expanded
        ? 4
        : width >= AppBreakpoints.medium
        ? 3
        : 2;

    return GridView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.xs,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: tokens.spacing.sm,
        mainAxisSpacing: tokens.spacing.sm,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length + (hasMore || isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _loadMoreFooter(context, isLoadingMore);
        }
        final design = items[index];
        return _LibraryGridCard(
          prefersEnglish: prefersEnglish,
          design: design,
          onTap: () => onOpenDetail(design),
          onPreview: () => onPreview(design),
          onShare: () => onShare(design),
        );
      },
    );
  }

  Widget _loadMoreFooter(BuildContext context, bool isLoadingMore) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.md),
        child: isLoadingMore
            ? const CircularProgressIndicator.adaptive()
            : Text(
                prefersEnglish ? 'Scroll to load more' : 'スクロールして続きを読み込む',
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }
}

class _LibraryGridCard extends StatelessWidget {
  const _LibraryGridCard({
    required this.prefersEnglish,
    required this.design,
    required this.onTap,
    required this.onPreview,
    required this.onShare,
  });

  final bool prefersEnglish;
  final Design design;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final preview = design.assets?.previewPngUrl;

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.md),
              child: Hero(
                tag: _heroTag(design),
                child: preview == null
                    ? Container(
                        color: tokens.colors.surfaceVariant,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : Image.network(
                        preview,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            design.input?.rawName ?? (prefersEnglish ? 'Untitled' : '無題'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Wrap(
            spacing: tokens.spacing.xs,
            runSpacing: tokens.spacing.xs,
            children: [
              Chip(label: Text(_statusLabel(design.status, prefersEnglish))),
              if (design.ai?.qualityScore != null)
                Chip(
                  label: Text(
                    'AI ${(design.ai!.qualityScore! * 100).round()}%',
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.xs),
          Row(
            children: [
              IconButton(
                tooltip: prefersEnglish ? 'Preview' : 'プレビュー',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: onPreview,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: prefersEnglish ? 'Share' : '共有',
                icon: const Icon(Icons.share_outlined),
                onPressed: onShare,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              Text(
                _formatShortDate(design.updatedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryListTile extends StatelessWidget {
  const _LibraryListTile({
    required this.prefersEnglish,
    required this.design,
    required this.onTap,
    required this.onPreview,
    required this.onShare,
  });

  final bool prefersEnglish;
  final Design design;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final name = design.input?.rawName ?? (prefersEnglish ? 'Untitled' : '無題');

    return AppListTile(
      title: Text(name),
      subtitle: Text(
        '${_statusLabel(design.status, prefersEnglish)} • ${_formatShortDate(design.updatedAt)}',
      ),
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.md),
          child: Hero(tag: _heroTag(design), child: _thumbnail(design, tokens)),
        ),
      ),
      trailing: Wrap(
        spacing: tokens.spacing.xs,
        children: [
          IconButton(
            tooltip: prefersEnglish ? 'Preview' : 'プレビュー',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: onPreview,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: prefersEnglish ? 'Share' : '共有',
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _thumbnail(Design design, DesignTokens tokens) {
    final url = design.assets?.previewPngUrl;
    if (url == null) {
      return Container(
        color: tokens.colors.surfaceVariant,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined),
      );
    }
    return Image.network(url, fit: BoxFit.cover);
  }
}

String _heroTag(Design design) =>
    'library:design:${design.id ?? design.hash ?? 'unknown'}';

String _statusLabel(DesignStatus status, bool prefersEnglish) {
  return switch (status) {
    DesignStatus.draft => prefersEnglish ? 'Draft' : '下書き',
    DesignStatus.ready => prefersEnglish ? 'Ready' : '準備完了',
    DesignStatus.ordered => prefersEnglish ? 'Ordered' : '注文済み',
    DesignStatus.locked => prefersEnglish ? 'Locked' : 'ロック',
  };
}

String _formatShortDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}

void _showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
