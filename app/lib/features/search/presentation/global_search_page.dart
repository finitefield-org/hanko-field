import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/core/ui/widgets/app_top_app_bar.dart';
import 'package:app/features/search/application/category_search_notifier.dart';
import 'package:app/features/search/application/providers.dart';
import 'package:app/features/search/application/search_repository_provider.dart';
import 'package:app/features/search/domain/search_category.dart';
import 'package:app/features/search/domain/search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(searchQueryProvider);
    _controller = TextEditingController(text: initialQuery);
    _focusNode = FocusNode();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _controller.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _controller.text;
    });
    ref.listen<SearchCategory>(searchSelectedCategoryProvider, (
      previous,
      next,
    ) {
      if (previous != next && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final metrics = _scrollController.position;
    if (metrics.extentAfter > 120) {
      return;
    }
    final category = ref.read(searchSelectedCategoryProvider);
    final query = ref.read(searchQueryProvider);
    final request = SearchCategoryRequest(category: category, query: query);
    ref.read(categorySearchProvider(request).notifier).loadMore();
  }

  void _commitQuery(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    ref.read(searchHistoryProvider.notifier).add(normalized);
  }

  void _onSelectCategory(SearchCategory category) {
    ref.read(searchSelectedCategoryProvider.notifier).state = category;
  }

  void _applyQuery(String value) {
    _controller
      ..text = value
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    _commitQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(searchSelectedCategoryProvider);
    final history = ref.watch(searchHistoryProvider);
    final suggestionsAsync = ref.watch(searchSuggestionsProvider(query));
    final repository = ref.read(searchRepositoryProvider);
    final notifier = ref.read(appStateProvider.notifier);

    final resultsByCategory = <SearchCategory, AsyncValue<CategorySearchState>>{
      for (final category in SearchCategory.values)
        category: ref.watch(
          categorySearchProvider(
            SearchCategoryRequest(category: category, query: query),
          ),
        ),
    };
    final selectedState = resultsByCategory[selectedCategory]!;

    void openNotifications() {
      notifier.push(const NotificationsRoute());
    }

    void focusSearchField() {
      _focusNode.requestFocus();
    }

    void openHelp() {
      showHelpOverlay(context, contextLabel: '検索');
    }

    return AppShortcutRegistrar(
      onNotificationsTap: openNotifications,
      onSearchTap: focusSearchField,
      onHelpTap: openHelp,
      child: Scaffold(
        appBar: AppTopAppBar(
          title: '検索',
          customTitle: _SearchBarHeader(
            controller: _controller,
            focusNode: _focusNode,
            onClear: () {
              _controller.clear();
              ref.read(searchQueryProvider.notifier).state = '';
            },
            onSubmitted: _commitQuery,
          ),
          showSearchAction: false,
          helpContextLabel: '検索',
          onNotificationsTap: openNotifications,
          onHelpTap: openHelp,
          trailingActions: [
            IconButton(
              icon: const Icon(Icons.mic_none_outlined),
              tooltip: '音声検索 (近日対応)',
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('音声検索は近日対応予定です')));
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 16),
                    _buildHistoryOrSuggestions(
                      context,
                      query: query,
                      history: history,
                      suggestionsAsync: suggestionsAsync,
                      trending: repository.trendingQueries(),
                      onSelect: _applyQuery,
                    ),
                    const SizedBox(height: 16),
                    _SearchSegmentedControl(
                      selected: selectedCategory,
                      results: resultsByCategory,
                      onChanged: _onSelectCategory,
                    ),
                    const SizedBox(height: 12),
                    _SearchResultsSection(
                      query: query,
                      state: selectedState,
                      onResultTap: (result) {
                        _commitQuery(query.isEmpty ? result.title : query);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${result.title} に移動します')),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryOrSuggestions(
    BuildContext context, {
    required String query,
    required List<String> history,
    required AsyncValue<List<String>> suggestionsAsync,
    required List<String> trending,
    required ValueChanged<String> onSelect,
  }) {
    final theme = Theme.of(context);
    if (query.isEmpty) {
      if (history.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('トレンド検索', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final suggestion in trending.take(6))
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => onSelect(suggestion),
                  ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('検索履歴', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (history.isNotEmpty)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(searchHistoryProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('履歴をクリア'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in history)
                InputChip(
                  label: Text(entry),
                  onPressed: () => onSelect(entry),
                  onDeleted: () =>
                      ref.read(searchHistoryProvider.notifier).remove(entry),
                ),
            ],
          ),
        ],
      );
    }

    return suggestionsAsync.when(
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('検索候補', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '候補が見つかりません。別のキーワードをお試しください。',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('検索候補', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...suggestions.map(
              (suggestion) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.search),
                title: Text(suggestion),
                onTap: () => onSelect(suggestion),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('検索候補', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '候補の取得に失敗しました。',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarHeader extends StatelessWidget {
  const _SearchBarHeader({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SearchBar(
      controller: controller,
      focusNode: focusNode,
      hintText: 'テンプレート・素材・記事・FAQ を検索',
      leading: const Icon(Icons.search),
      onSubmitted: onSubmitted,
      onChanged: (_) {},
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      textInputAction: TextInputAction.search,
      trailing: [
        if (controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear_outlined),
            tooltip: '入力をクリア',
            onPressed: onClear,
          ),
      ],
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

class _SearchSegmentedControl extends StatelessWidget {
  const _SearchSegmentedControl({
    required this.selected,
    required this.results,
    required this.onChanged,
  });

  final SearchCategory selected;
  final Map<SearchCategory, AsyncValue<CategorySearchState>> results;
  final ValueChanged<SearchCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SearchCategory>(
      segments: SearchCategory.values
          .map(
            (category) => ButtonSegment<SearchCategory>(
              value: category,
              icon: Icon(category.icon),
              label: Text(_segmentLabel(category, results[category])),
            ),
          )
          .toList(),
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }

  String _segmentLabel(
    SearchCategory category,
    AsyncValue<CategorySearchState>? state,
  ) {
    final total = state?.asData?.value.totalCount;
    if (total == null && (state?.isLoading ?? false)) {
      return '${category.label} (...)';
    }
    if (total == null) {
      return category.label;
    }
    return '${category.label} ($total)';
  }
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({
    required this.query,
    required this.state,
    required this.onResultTap,
  });

  final String query;
  final AsyncValue<CategorySearchState> state;
  final ValueChanged<SearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (data) {
        if (data.results.isEmpty) {
          final message = query.isEmpty
              ? 'このセクションのおすすめ項目はまだありません。'
              : '「$query」に一致する結果が見つかりませんでした。';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text(message)),
          );
        }
        final itemCount =
            data.results.length +
            ((data.isLoadingMore || data.hasMore) ? 1 : 0);
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= data.results.length) {
              if (data.isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (data.hasMore) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('さらにスクロールして読み込み')),
                );
              }
              return const SizedBox.shrink();
            }
            final result = data.results[index];
            return _SearchResultTile(
              result: result,
              onTap: () => onResultTap(result),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '検索結果の取得に失敗しました。',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(result.category.icon, color: theme.colorScheme.primary),
        ),
        title: Text(result.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(result.description),
            if (result.metadata != null) ...[
              const SizedBox(height: 4),
              Text(result.metadata!, style: theme.textTheme.bodySmall),
            ],
            if (result.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in result.tags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ],
        ),
        trailing: result.badge == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.badge!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
