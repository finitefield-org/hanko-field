// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart' as models;
import 'package:app/features/search/data/search_models.dart';
import 'package:app/features/search/view_model/search_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();

  String _lastQuery = '';
  String _activeQueryForScroll = '';
  SearchSegment _currentSegment = SearchSegment.templates;

  List<TemplateSearchHit> _templateHits = [];
  List<MaterialSearchHit> _materialHits = [];
  List<ArticleSearchHit> _articleHits = [];
  List<FaqSearchHit> _faqHits = [];

  final Map<SearchSegment, String?> _nextPageTokens = {};
  final Map<SearchSegment, bool> _loadingMore = {};
  final Set<SearchSegment> _initialized = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final ui = ref.watch(searchViewModel);
    final prefersEnglish = ref.watch(appExperienceGatesProvider).prefersEnglish;

    final suggestions = ref.watch(
      SearchSuggestionsProvider(query: ui.valueOrNull?.query ?? ''),
    );
    final activeQuery = ui.valueOrNull?.activeQuery ?? '';
    final selectedSegment =
        ui.valueOrNull?.selectedSegment ?? SearchSegment.templates;
    final state = ui.valueOrNull;

    if (state != null) {
      if (_controller.text != state.query) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _controller.value = TextEditingValue(
            text: state.query,
            selection: TextSelection.collapsed(offset: state.query.length),
          );
        });
      }

      if (_lastQuery != state.activeQuery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _lastQuery = state.activeQuery;
            _activeQueryForScroll = state.activeQuery;
            _resetResults();
          });
        });
      } else {
        _activeQueryForScroll = activeQuery;
      }

      _currentSegment = state.selectedSegment;
    } else {
      _currentSegment = selectedSegment;
      _activeQueryForScroll = activeQuery;
    }

    final templatePage = ref.watch(
      TemplateResultsProvider(query: activeQuery, pageToken: null),
    );
    final materialPage = ref.watch(
      MaterialResultsProvider(query: activeQuery, pageToken: null),
    );
    final articlePage = ref.watch(
      ArticleResultsProvider(query: activeQuery, pageToken: null),
    );
    final faqPage = ref.watch(
      FaqResultsProvider(query: activeQuery, pageToken: null),
    );

    _captureInitial(
      segment: SearchSegment.templates,
      page: templatePage,
      setter: (items) => _templateHits = items,
    );
    _captureInitial(
      segment: SearchSegment.materials,
      page: materialPage,
      setter: (items) => _materialHits = items,
    );
    _captureInitial(
      segment: SearchSegment.articles,
      page: articlePage,
      setter: (items) => _articleHits = items,
    );
    _captureInitial(
      segment: SearchSegment.faq,
      page: faqPage,
      setter: (items) => _faqHits = items,
    );

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _SearchAppBar(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _handleQueryChanged,
        onSubmitted: _handleSubmit,
        onVoicePressed: _handleVoicePressed,
        prefersEnglish: prefersEnglish,
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
              child: _HistoryAndSuggestions(
                suggestions: suggestions,
                ui: ui,
                prefersEnglish: prefersEnglish,
                onChipTap: _handleChipTap,
                onClearHistory: _handleClearHistory,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
              child: _SegmentedSwitcher(
                selected: selectedSegment,
                prefersEnglish: prefersEnglish,
                onSelected: (segment) =>
                    ref.invoke(searchViewModel.selectSegment(segment)),
              ),
            ),
            SizedBox(height: tokens.spacing.sm),
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: () => _refresh(activeQuery),
                displacement: tokens.spacing.xl,
                edgeOffset: tokens.spacing.md,
                child: _buildResults(
                  context: context,
                  ui: ui,
                  selected: selectedSegment,
                  activeQuery: activeQuery,
                  templatePage: templatePage,
                  materialPage: materialPage,
                  articlePage: articlePage,
                  faqPage: faqPage,
                  prefersEnglish: prefersEnglish,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQueryChanged(String value) {
    ref.invoke(searchViewModel.updateQuery(value));
  }

  void _handleSubmit([String? value]) {
    final query = value ?? _controller.text;
    ref.invoke(searchViewModel.submit(query));
    _focusNode.unfocus();
  }

  void _handleChipTap(String value) {
    _controller.text = value;
    _handleSubmit(value);
  }

  void _handleClearHistory([String? entry]) {
    ref.invoke(searchViewModel.clearHistory(entry));
  }

  void _handleVoicePressed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).searchVoiceComingSoon),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildResults({
    required BuildContext context,
    required AsyncValue<SearchUiState> ui,
    required SearchSegment selected,
    required String activeQuery,
    required AsyncValue<models.Page<TemplateSearchHit>> templatePage,
    required AsyncValue<models.Page<MaterialSearchHit>> materialPage,
    required AsyncValue<models.Page<ArticleSearchHit>> articlePage,
    required AsyncValue<models.Page<FaqSearchHit>> faqPage,
    required bool prefersEnglish,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final padding = EdgeInsets.symmetric(horizontal: tokens.spacing.lg);

    if (ui is AsyncLoading<SearchUiState>) {
      return Padding(padding: padding, child: const AppListSkeleton(items: 4));
    }

    if (activeQuery.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.xl),
          child: AppEmptyState(
            title: prefersEnglish ? 'Search anything' : '探したいものを入力',
            message: prefersEnglish
                ? 'Templates, materials, guides, and FAQ are searchable from here.'
                : 'テンプレート・素材・記事・FAQをまとめて検索できます。',
            icon: Icons.search_rounded,
          ),
        ),
      );
    }

    switch (selected) {
      case SearchSegment.templates:
        return _ResultList<TemplateSearchHit>(
          controller: _scrollController,
          page: templatePage,
          items: _templateHits,
          padding: padding,
          prefersEnglish: prefersEnglish,
          hasMore: _nextPageTokens[SearchSegment.templates] != null,
          loadingMore: _loadingMore[SearchSegment.templates] ?? false,
          onLoadMore: () => _loadMore(SearchSegment.templates, activeQuery),
          onRetry: () => _refresh(activeQuery),
          itemBuilder: (context, hit) =>
              _TemplateResultTile(hit: hit, prefersEnglish: prefersEnglish),
        );
      case SearchSegment.materials:
        return _ResultList<MaterialSearchHit>(
          controller: _scrollController,
          page: materialPage,
          items: _materialHits,
          padding: padding,
          prefersEnglish: prefersEnglish,
          hasMore: _nextPageTokens[SearchSegment.materials] != null,
          loadingMore: _loadingMore[SearchSegment.materials] ?? false,
          onLoadMore: () => _loadMore(SearchSegment.materials, activeQuery),
          onRetry: () => _refresh(activeQuery),
          itemBuilder: (context, hit) =>
              _MaterialResultTile(hit: hit, prefersEnglish: prefersEnglish),
        );
      case SearchSegment.articles:
        return _ResultList<ArticleSearchHit>(
          controller: _scrollController,
          page: articlePage,
          items: _articleHits,
          padding: padding,
          prefersEnglish: prefersEnglish,
          hasMore: _nextPageTokens[SearchSegment.articles] != null,
          loadingMore: _loadingMore[SearchSegment.articles] ?? false,
          onLoadMore: () => _loadMore(SearchSegment.articles, activeQuery),
          onRetry: () => _refresh(activeQuery),
          itemBuilder: (context, hit) =>
              _ArticleResultTile(hit: hit, prefersEnglish: prefersEnglish),
        );
      case SearchSegment.faq:
        return _ResultList<FaqSearchHit>(
          controller: _scrollController,
          page: faqPage,
          items: _faqHits,
          padding: padding,
          prefersEnglish: prefersEnglish,
          hasMore: _nextPageTokens[SearchSegment.faq] != null,
          loadingMore: _loadingMore[SearchSegment.faq] ?? false,
          onLoadMore: () => _loadMore(SearchSegment.faq, activeQuery),
          onRetry: () => _refresh(activeQuery),
          itemBuilder: (context, hit) =>
              _FaqResultTile(hit: hit, prefersEnglish: prefersEnglish),
        );
    }
  }

  void _captureInitial<T>({
    required SearchSegment segment,
    required AsyncValue<models.Page<T>> page,
    required void Function(List<T>) setter,
  }) {
    if (page case AsyncData<models.Page<T>>(
      :final value,
      :final isRefreshing,
    )) {
      final shouldReplace =
          !_initialized.contains(segment) || isRefreshing || _lastQuery.isEmpty;

      if (shouldReplace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            setter(value.items);
            _nextPageTokens[segment] = value.nextPageToken;
            _initialized.add(segment);
          });
        });
      } else if (_nextPageTokens[segment] == null &&
          value.nextPageToken != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _nextPageTokens[segment] = value.nextPageToken;
          });
        });
      }
    }
  }

  Future<void> _loadMore(SearchSegment segment, String query) async {
    if (query.isEmpty) return;
    if (_loadingMore[segment] == true) return;
    final next = _nextPageTokens[segment];
    if (next == null) return;

    setState(() => _loadingMore[segment] = true);
    try {
      switch (segment) {
        case SearchSegment.templates:
          final page = await ref.container.read(
            TemplateResultsProvider(query: query, pageToken: next).future,
          );
          if (!mounted) return;
          setState(() {
            _templateHits = [..._templateHits, ...page.items];
            _nextPageTokens[segment] = page.nextPageToken;
          });
          break;
        case SearchSegment.materials:
          final page = await ref.container.read(
            MaterialResultsProvider(query: query, pageToken: next).future,
          );
          if (!mounted) return;
          setState(() {
            _materialHits = [..._materialHits, ...page.items];
            _nextPageTokens[segment] = page.nextPageToken;
          });
          break;
        case SearchSegment.articles:
          final page = await ref.container.read(
            ArticleResultsProvider(query: query, pageToken: next).future,
          );
          if (!mounted) return;
          setState(() {
            _articleHits = [..._articleHits, ...page.items];
            _nextPageTokens[segment] = page.nextPageToken;
          });
          break;
        case SearchSegment.faq:
          final page = await ref.container.read(
            FaqResultsProvider(query: query, pageToken: next).future,
          );
          if (!mounted) return;
          setState(() {
            _faqHits = [..._faqHits, ...page.items];
            _nextPageTokens[segment] = page.nextPageToken;
          });
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore[segment] = false);
      }
    }
  }

  Future<void> _refresh(String activeQuery) async {
    if (activeQuery.isEmpty) return;
    _resetResults();
    await Future.wait([
      ref.refreshValue(
        TemplateResultsProvider(query: activeQuery, pageToken: null),
        keepPrevious: true,
      ),
      ref.refreshValue(
        MaterialResultsProvider(query: activeQuery, pageToken: null),
        keepPrevious: true,
      ),
      ref.refreshValue(
        ArticleResultsProvider(query: activeQuery, pageToken: null),
        keepPrevious: true,
      ),
      ref.refreshValue(
        FaqResultsProvider(query: activeQuery, pageToken: null),
        keepPrevious: true,
      ),
    ]);
  }

  void _resetResults() {
    _templateHits = [];
    _materialHits = [];
    _articleHits = [];
    _faqHits = [];
    _nextPageTokens.clear();
    _loadingMore.clear();
    _initialized.clear();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.extentAfter < 260) {
      _loadMore(_currentSegment, _activeQueryForScroll);
    }
  }
}

class _SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SearchAppBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onVoicePressed,
    required this.prefersEnglish,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String?> onSubmitted;
  final VoidCallback onVoicePressed;
  final bool prefersEnglish;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 12);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => GoRouter.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.only(right: tokens.spacing.md),
        child: _SearchField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onVoicePressed: onVoicePressed,
          prefersEnglish: prefersEnglish,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onVoicePressed,
    required this.prefersEnglish,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String?> onSubmitted;
  final VoidCallback onVoicePressed;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radii.lg),
      borderSide: BorderSide.none,
    );

    return Material(
      color: tokens.colors.surfaceVariant,
      borderRadius: BorderRadius.circular(tokens.radii.lg),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchHintText,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.transparent,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: BorderSide(color: tokens.colors.primary),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.md,
                  vertical: tokens.spacing.sm,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_none_rounded),
            tooltip: AppLocalizations.of(context).searchVoiceTooltip,
            onPressed: onVoicePressed,
          ),
        ],
      ),
    );
  }
}

class _HistoryAndSuggestions extends StatelessWidget {
  const _HistoryAndSuggestions({
    required this.suggestions,
    required this.ui,
    required this.prefersEnglish,
    required this.onChipTap,
    required this.onClearHistory,
  });

  final AsyncValue<List<SearchSuggestion>> suggestions;
  final AsyncValue<SearchUiState> ui;
  final bool prefersEnglish;
  final ValueChanged<String> onChipTap;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final history = ui.valueOrNull?.history ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).searchRecentTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              TextButton(
                onPressed: onClearHistory,
                child: Text(AppLocalizations.of(context).commonClear),
              ),
            ],
          ),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: history
                .map(
                  (q) => ActionChip(
                    label: Text(q),
                    onPressed: () => onChipTap(q),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          SizedBox(height: tokens.spacing.md),
        ],
        Text(
          AppLocalizations.of(context).searchSuggestionsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: tokens.spacing.xs),
        switch (suggestions) {
          AsyncLoading() => const AppSkeletonBlock(width: 160),
          AsyncError() => Text(
            AppLocalizations.of(context).searchSuggestionsLoadFailed,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AsyncData(:final value) => Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: value
                .map(
                  (s) => FilterChip(
                    label: Text(s.label),
                    avatar: s.segment == null
                        ? null
                        : Icon(s.segment!.icon(), size: 16),
                    onSelected: (_) => onChipTap(s.label),
                  ),
                )
                .toList(),
          ),
        },
      ],
    );
  }
}

class _SegmentedSwitcher extends StatelessWidget {
  const _SegmentedSwitcher({
    required this.selected,
    required this.prefersEnglish,
    required this.onSelected,
  });

  final SearchSegment selected;
  final bool prefersEnglish;
  final ValueChanged<SearchSegment> onSelected;

  @override
  Widget build(BuildContext context) {
    final segments = SearchSegment.values
        .map(
          (segment) => ButtonSegment<SearchSegment>(
            value: segment,
            label: Text(segment.label(prefersEnglish: prefersEnglish)),
            icon: Icon(segment.icon()),
          ),
        )
        .toList();

    return SegmentedButton<SearchSegment>(
      segments: segments,
      selected: {selected},
      onSelectionChanged: (value) => onSelected(value.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ResultList<T> extends StatelessWidget {
  const _ResultList({
    required this.controller,
    required this.page,
    required this.items,
    required this.padding,
    required this.prefersEnglish,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    this.onRetry,
    required this.itemBuilder,
  });

  final ScrollController controller;
  final AsyncValue<models.Page<T>> page;
  final List<T> items;
  final EdgeInsets padding;
  final bool prefersEnglish;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback? onRetry;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return switch (page) {
      AsyncLoading() => Padding(
        padding: padding,
        child: const AppListSkeleton(items: 4),
      ),
      AsyncError(:final error) => Padding(
        padding: padding,
        child: AppEmptyState(
          title: AppLocalizations.of(context).searchResultsErrorTitle,
          message: error.toString(),
          icon: Icons.error_outline,
          actionLabel: AppLocalizations.of(context).commonRetry,
          onAction: onRetry ?? onLoadMore,
        ),
      ),
      AsyncData(:final value) when value.items.isEmpty && items.isEmpty =>
        Padding(
          padding: padding,
          child: AppEmptyState(
            title: AppLocalizations.of(context).searchResultsEmptyTitle,
            message: AppLocalizations.of(context).searchResultsEmptyMessage,
            icon: Icons.inbox_outlined,
          ),
        ),
      AsyncData() => ListView.separated(
        controller: controller,
        padding: padding.add(EdgeInsets.only(bottom: tokens.spacing.xl)),
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < items.length) {
            return itemBuilder(context, items[index]);
          }
          if (!hasMore) {
            return const SizedBox.shrink();
          }
          if (loadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          return TextButton(
            onPressed: onLoadMore,
            child: Text(AppLocalizations.of(context).commonLoadMore),
          );
        },
        separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
      ),
    };
  }
}

class _TemplateResultTile extends StatelessWidget {
  const _TemplateResultTile({required this.hit, required this.prefersEnglish});

  final TemplateSearchHit hit;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.colors.surfaceVariant,
        child: Icon(
          hit.template.shape == SealShape.square
              ? Icons.crop_square_rounded
              : Icons.circle_outlined,
          color: tokens.colors.primary,
        ),
      ),
      title: Text(hit.template.name),
      subtitle: Text(hit.reason),
      trailing: Icon(
        hit.template.writing == WritingStyle.tensho
            ? Icons.edit_square
            : Icons.gesture_rounded,
        color: tokens.colors.outline,
      ),
    );
  }
}

class _MaterialResultTile extends StatelessWidget {
  const _MaterialResultTile({required this.hit, required this.prefersEnglish});

  final MaterialSearchHit hit;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final badge = hit.badge;

    return AppListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.colors.surfaceVariant,
        child: const Icon(Icons.layers_outlined),
      ),
      title: Text(hit.material.name),
      subtitle: Text(hit.summary),
      trailing: badge == null
          ? null
          : Chip(
              label: Text(badge),
              visualDensity: VisualDensity.compact,
              backgroundColor: tokens.colors.surfaceVariant,
              side: BorderSide(
                color: tokens.colors.outline.withValues(alpha: 0.4),
              ),
            ),
    );
  }
}

class _ArticleResultTile extends StatelessWidget {
  const _ArticleResultTile({required this.hit, required this.prefersEnglish});

  final ArticleSearchHit hit;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final translation = prefersEnglish
        ? (hit.guide.translations['en'] ?? hit.guide.translations.values.first)
        : (hit.guide.translations['ja'] ?? hit.guide.translations.values.first);

    return AppListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.colors.surfaceVariant,
        child: const Icon(Icons.menu_book_outlined),
      ),
      title: Text(translation.title),
      subtitle: Text(hit.summary),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: tokens.colors.outline,
      ),
    );
  }
}

class _FaqResultTile extends StatelessWidget {
  const _FaqResultTile({required this.hit, required this.prefersEnglish});

  final FaqSearchHit hit;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.colors.surfaceVariant,
        child: const Icon(Icons.live_help_outlined),
      ),
      title: Text(hit.question),
      subtitle: Text(hit.answer),
      trailing: Icon(
        Icons.question_answer_outlined,
        color: tokens.colors.outline,
      ),
    );
  }
}
