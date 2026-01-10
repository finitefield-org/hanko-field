// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/guides/data/models/guide_presentation.dart';
import 'package:app/features/support/view_model/faq_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class FaqPage extends ConsumerStatefulWidget {
  const FaqPage({super.key});

  @override
  ConsumerState<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends ConsumerState<FaqPage> {
  static const _allCategoryId = 'all';

  late final TextEditingController _searchController;
  String _query = '';
  String _selectedCategoryId = _allCategoryId;
  final Map<String, bool> _helpfulVotes = <String, bool>{};

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
    final tokens = DesignTokensTheme.of(context);
    final navigation = context.navigation;
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final lang = prefersEnglish ? 'en' : 'ja';

    final state = ref.watch(faqListViewModel);
    final categories = _buildCategories(
      state.valueOrNull?.items ?? const <Guide>[],
      prefersEnglish: prefersEnglish,
    );
    final resolvedCategoryId =
        categories.any((category) => category.id == _selectedCategoryId)
        ? _selectedCategoryId
        : _allCategoryId;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.invoke(faqListViewModel.refresh()),
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
              title: Text(prefersEnglish ? 'FAQ' : 'よくある質問'),
              leading: IconButton(
                tooltip: prefersEnglish ? 'Back' : '戻る',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => navigation.pop(),
              ),
              actions: [
                IconButton(
                  tooltip: prefersEnglish ? 'Filter' : '絞り込み',
                  icon: const Icon(Icons.filter_list_rounded),
                  onPressed: categories.length <= 1
                      ? null
                      : () => _showCategorySheet(
                          context,
                          categories: categories,
                          selectedId: resolvedCategoryId,
                          prefersEnglish: prefersEnglish,
                        ),
                ),
                SizedBox(width: tokens.spacing.sm),
              ],
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.lg,
                      kToolbarHeight + tokens.spacing.sm,
                      tokens.spacing.lg,
                      tokens.spacing.md,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SearchBar(
                        controller: _searchController,
                        hintText: prefersEnglish ? 'Search questions' : '質問を検索',
                        leading: const Icon(Icons.search_rounded),
                        onChanged: _updateQuery,
                        onSubmitted: _updateQuery,
                        trailing: _query.isEmpty
                            ? null
                            : [
                                IconButton(
                                  tooltip: prefersEnglish ? 'Clear' : 'クリア',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _updateQuery('');
                                  },
                                ),
                              ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (categories.length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.lg,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: tokens.spacing.sm),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return FilterChip(
                        label: Text(category.label),
                        selected: category.id == resolvedCategoryId,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = category.id),
                      );
                    },
                  ),
                ),
              ),
            if (_query.isEmpty &&
                categories
                    .where(
                      (category) =>
                          category.id != _allCategoryId &&
                          category.id != 'general',
                    )
                    .isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.lg,
                    tokens.spacing.md,
                    tokens.spacing.lg,
                    tokens.spacing.sm,
                  ),
                  child: _SuggestionTags(
                    tags: categories
                        .where(
                          (category) =>
                              category.id != _allCategoryId &&
                              category.id != 'general',
                        )
                        .take(6)
                        .map((category) => category.label)
                        .toList(),
                    prefersEnglish: prefersEnglish,
                    onTap: _applySuggestion,
                  ),
                ),
              ),
            ...switch (state) {
              AsyncLoading() => [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
                  sliver: const SliverToBoxAdapter(
                    child: AppListSkeleton(items: 6, itemHeight: 120),
                  ),
                ),
              ],
              AsyncError() when state.valueOrNull != null => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.lg,
                      tokens.spacing.lg,
                      tokens.spacing.lg,
                      tokens.spacing.sm,
                    ),
                    child: _InlineErrorBanner(
                      message: prefersEnglish
                          ? 'Could not load more. Showing saved results.'
                          : '追加の読み込みに失敗しました。既存の結果を表示します。',
                    ),
                  ),
                ),
                ..._buildFaqContent(
                  context: context,
                  items: state.valueOrNull!.items,
                  prefersEnglish: prefersEnglish,
                  lang: lang,
                  query: _query,
                  selectedCategoryId: resolvedCategoryId,
                  helpfulVotes: _helpfulVotes,
                  onHelpfulSelected: _setHelpfulness,
                  isLoadingMore: false,
                  onLoadMore: state.valueOrNull!.nextPageToken == null
                      ? null
                      : () => ref.invoke(faqListViewModel.loadMore()),
                ),
              ],
              AsyncError(:final error) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacing.lg),
                    child: AppEmptyState(
                      title: prefersEnglish
                          ? 'Unable to load FAQ'
                          : 'FAQを読み込めませんでした',
                      message: error.toString(),
                      icon: Icons.cloud_off_outlined,
                    ),
                  ),
                ),
              ],
              AsyncData(:final value) => _buildFaqContent(
                context: context,
                items: value.items,
                prefersEnglish: prefersEnglish,
                lang: lang,
                query: _query,
                selectedCategoryId: resolvedCategoryId,
                helpfulVotes: _helpfulVotes,
                onHelpfulSelected: _setHelpfulness,
                isLoadingMore: value.isLoadingMore,
                onLoadMore: value.nextPageToken == null
                    ? null
                    : () => ref.invoke(faqListViewModel.loadMore()),
              ),
            },
            SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.xxl)),
          ],
        ),
      ),
    );
  }

  void _updateQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _applySuggestion(String value) {
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    _updateQuery(value);
  }

  void _setHelpfulness(String slug, bool value) {
    setState(() => _helpfulVotes[slug] = value);
  }

  Future<void> _showCategorySheet(
    BuildContext context, {
    required List<_FaqCategory> categories,
    required String selectedId,
    required bool prefersEnglish,
  }) {
    final tokens = DesignTokensTheme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          minimum: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefersEnglish ? 'Filter by category' : 'カテゴリで絞り込む',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: categories.map((category) {
                  return FilterChip(
                    label: Text(category.label),
                    selected: category.id == selectedId,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = category.id);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFaqContent({
    required BuildContext context,
    required List<Guide> items,
    required bool prefersEnglish,
    required String lang,
    required String query,
    required String selectedCategoryId,
    required Map<String, bool> helpfulVotes,
    required void Function(String slug, bool value) onHelpfulSelected,
    required bool isLoadingMore,
    required VoidCallback? onLoadMore,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final navigation = context.navigation;

    final filtered = _applyCategory(items, selectedCategoryId);
    final searched = query.isEmpty
        ? filtered
        : _applyQuery(filtered, query: query, lang: lang);

    if (searched.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prefersEnglish ? 'No matching questions' : '該当する質問がありません',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    prefersEnglish
                        ? 'Try another keyword or contact support directly.'
                        : '別のキーワードを試すか、サポートにお問い合わせください。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: tokens.spacing.md),
                  Wrap(
                    spacing: tokens.spacing.sm,
                    runSpacing: tokens.spacing.sm,
                    children: [
                      AppButton(
                        label: prefersEnglish ? 'Chat' : 'チャット',
                        variant: AppButtonVariant.secondary,
                        leading: const Icon(Icons.chat_bubble_outline),
                        onPressed: () =>
                            navigation.push(AppRoutePaths.supportChat),
                      ),
                      AppButton(
                        label: prefersEnglish ? 'Contact form' : '問い合わせ',
                        variant: AppButtonVariant.ghost,
                        leading: const Icon(Icons.support_agent_outlined),
                        onPressed: () =>
                            navigation.push(AppRoutePaths.supportContact),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.lg,
            tokens.spacing.lg,
            tokens.spacing.sm,
          ),
          child: Text(
            prefersEnglish
                ? '${searched.length} questions'
                : '${searched.length}件の質問',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        sliver: SliverList.separated(
          itemBuilder: (context, index) {
            final guide = searched[index];
            return _FaqEntryCard(
              guide: guide,
              lang: lang,
              query: query,
              prefersEnglish: prefersEnglish,
              helpful: helpfulVotes[guide.slug],
              onHelpfulSelected: (value) =>
                  onHelpfulSelected(guide.slug, value),
            );
          },
          separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.md),
          itemCount: searched.length,
        ),
      ),
      if (onLoadMore != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: Center(
              child: AppButton(
                label: prefersEnglish ? 'Load more' : 'さらに読み込む',
                variant: AppButtonVariant.ghost,
                isLoading: isLoadingMore,
                onPressed: onLoadMore,
              ),
            ),
          ),
        ),
    ];
  }
}

class _FaqEntryCard extends StatelessWidget {
  const _FaqEntryCard({
    required this.guide,
    required this.lang,
    required this.query,
    required this.prefersEnglish,
    required this.helpful,
    required this.onHelpfulSelected,
  });

  final Guide guide;
  final String lang;
  final String query;
  final bool prefersEnglish;
  final bool? helpful;
  final ValueChanged<bool> onHelpfulSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final translation = guideTranslationForLang(guide, lang);
    final summary = translation.summary?.trim() ?? '';
    final body = translation.body.trim();
    final answer = summary.isNotEmpty
        ? summary
        : body.isNotEmpty
        ? body
        : prefersEnglish
        ? 'Answer coming soon.'
        : '回答は準備中です。';

    final theme = Theme.of(context);
    final baseTitleStyle = theme.textTheme.titleMedium!;
    final baseBodyStyle = theme.textTheme.bodyMedium!;
    final titleHighlightStyle = baseTitleStyle.copyWith(
      color: tokens.colors.primary,
      fontWeight: FontWeight.w700,
    );
    final bodyHighlightStyle = baseBodyStyle.copyWith(
      color: tokens.colors.primary,
      fontWeight: FontWeight.w600,
    );

    return Material(
      color: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
        side: BorderSide(color: tokens.colors.outline.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.lg,
          vertical: tokens.spacing.sm,
        ),
        childrenPadding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          0,
          tokens.spacing.lg,
          tokens.spacing.lg,
        ),
        title: RichText(
          text: _highlightedSpan(
            translation.title,
            query,
            baseTitleStyle,
            titleHighlightStyle,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: guide.tags.isEmpty
            ? null
            : Padding(
                padding: EdgeInsets.only(top: tokens.spacing.xs),
                child: Wrap(
                  spacing: tokens.spacing.xs,
                  runSpacing: tokens.spacing.xs,
                  children: guide.tags
                      .take(3)
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
              ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: _highlightedSpan(
                answer,
                query,
                baseBodyStyle,
                bodyHighlightStyle,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          _HelpfulnessRow(
            prefersEnglish: prefersEnglish,
            helpful: helpful,
            onHelpfulSelected: onHelpfulSelected,
          ),
        ],
      ),
    );
  }
}

class _HelpfulnessRow extends StatelessWidget {
  const _HelpfulnessRow({
    required this.prefersEnglish,
    required this.helpful,
    required this.onHelpfulSelected,
  });

  final bool prefersEnglish;
  final bool? helpful;
  final ValueChanged<bool> onHelpfulSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.sm,
      runSpacing: tokens.spacing.sm,
      children: [
        Text(
          prefersEnglish ? 'Was this helpful?' : '役に立ちましたか？',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        ChoiceChip(
          label: Text(prefersEnglish ? 'Yes' : 'はい'),
          selected: helpful == true,
          onSelected: (_) => onHelpfulSelected(true),
        ),
        ChoiceChip(
          label: Text(prefersEnglish ? 'No' : 'いいえ'),
          selected: helpful == false,
          onSelected: (_) => onHelpfulSelected(false),
        ),
      ],
    );
  }
}

class _SuggestionTags extends StatelessWidget {
  const _SuggestionTags({
    required this.tags,
    required this.prefersEnglish,
    required this.onTap,
  });

  final List<String> tags;
  final bool prefersEnglish;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    if (tags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefersEnglish ? 'Suggested tags' : 'おすすめキーワード',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: tags
              .map(
                (tag) =>
                    ActionChip(label: Text(tag), onPressed: () => onTap(tag)),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      backgroundColor: tokens.colors.surface,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: tokens.colors.primary),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _FaqCategory {
  const _FaqCategory({required this.id, required this.label});

  final String id;
  final String label;
}

List<_FaqCategory> _buildCategories(
  List<Guide> guides, {
  required bool prefersEnglish,
}) {
  final counts = <String, int>{};
  final labels = <String, String>{};
  var untagged = 0;

  for (final guide in guides) {
    if (guide.tags.isEmpty) {
      untagged += 1;
      continue;
    }
    for (final tag in guide.tags) {
      final key = tag.trim().toLowerCase();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      labels.putIfAbsent(key, () => tag.trim());
    }
  }

  final sortedKeys = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

  final categories = <_FaqCategory>[
    _FaqCategory(
      id: _FaqPageState._allCategoryId,
      label: prefersEnglish ? 'All' : 'すべて',
    ),
  ];

  if (untagged > 0) {
    categories.add(
      _FaqCategory(id: 'general', label: prefersEnglish ? 'General' : '全般'),
    );
  }

  categories.addAll(
    sortedKeys.map((key) => _FaqCategory(id: key, label: labels[key] ?? key)),
  );

  return categories;
}

List<Guide> _applyCategory(List<Guide> guides, String selectedCategoryId) {
  if (selectedCategoryId == _FaqPageState._allCategoryId) {
    return guides;
  }
  if (selectedCategoryId == 'general') {
    return guides.where((guide) => guide.tags.isEmpty).toList();
  }

  return guides
      .where(
        (guide) => guide.tags.any(
          (tag) => tag.trim().toLowerCase() == selectedCategoryId,
        ),
      )
      .toList();
}

List<Guide> _applyQuery(
  List<Guide> guides, {
  required String query,
  required String lang,
}) {
  final tokens = query
      .split(RegExp(r'\s+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty);
  final queryTokens = tokens.map((token) => token.toLowerCase()).toList();
  if (queryTokens.isEmpty) return guides;

  bool matches(Guide guide) {
    final translation = guideTranslationForLang(guide, lang);
    final haystack = [
      translation.title,
      translation.summary ?? '',
      translation.body,
      ...guide.tags,
    ].join(' ').toLowerCase();
    return queryTokens.every(haystack.contains);
  }

  return guides.where(matches).toList();
}

TextSpan _highlightedSpan(
  String text,
  String query,
  TextStyle baseStyle,
  TextStyle highlightStyle,
) {
  if (query.trim().isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final tokens = query
      .split(RegExp(r'\s+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .map(RegExp.escape)
      .toList();
  if (tokens.isEmpty) return TextSpan(text: text, style: baseStyle);

  final regex = RegExp(tokens.join('|'), caseSensitive: false);
  final spans = <TextSpan>[];
  var start = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > start) {
      spans.add(
        TextSpan(text: text.substring(start, match.start), style: baseStyle),
      );
    }
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
    );
    start = match.end;
  }

  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: baseStyle));
  }

  return TextSpan(children: spans);
}
