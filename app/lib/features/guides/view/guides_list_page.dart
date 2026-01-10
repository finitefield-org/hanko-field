// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/guides/view_model/guides_list_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class GuidesListPage extends ConsumerStatefulWidget {
  const GuidesListPage({super.key});

  @override
  ConsumerState<GuidesListPage> createState() => _GuidesListPageState();
}

class _GuidesListPageState extends ConsumerState<GuidesListPage> {
  late final TextEditingController _searchController;
  String _query = '';

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
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final navigation = context.navigation;

    final state = ref.watch(guidesListViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.invoke(guidesListViewModel.refresh()),
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
              title: Text(prefersEnglish ? 'Guides' : 'ガイド'),
              leading: IconButton(
                tooltip: prefersEnglish ? 'Back' : '戻る',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => navigation.pop(),
              ),
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
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        onSubmitted: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        hintText: prefersEnglish ? 'Search guides' : 'ガイドを検索',
                        leading: const Icon(Icons.search_rounded),
                        trailing: _query.isEmpty
                            ? null
                            : [
                                IconButton(
                                  tooltip: prefersEnglish ? 'Clear' : 'クリア',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                              ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  tokens.spacing.md,
                  tokens.spacing.lg,
                  tokens.spacing.sm,
                ),
                child: _Filters(
                  state: state,
                  prefersEnglish: prefersEnglish,
                  onLocaleChanged: (locale) =>
                      ref.invoke(guidesListViewModel.setLocale(locale)),
                  onPersonaChanged: (persona) =>
                      ref.invoke(guidesListViewModel.setPersona(persona)),
                  onTopicChanged: (topic) =>
                      ref.invoke(guidesListViewModel.setTopic(topic)),
                ),
              ),
            ),
            ...switch (state) {
              AsyncLoading() => [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
                  sliver: const SliverToBoxAdapter(
                    child: AppListSkeleton(items: 5, itemHeight: 120),
                  ),
                ),
              ],
              AsyncError(:final error) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacing.lg),
                    child: AppEmptyState(
                      title: prefersEnglish ? 'Unable to load' : '読み込めませんでした',
                      message: error.toString(),
                      icon: Icons.cloud_off_outlined,
                    ),
                  ),
                ),
              ],
              AsyncData(:final value) => _buildContent(
                context: context,
                state: value,
                prefersEnglish: prefersEnglish,
                query: _query,
                onOpenGuide: (slug) => navigation.go(
                  '${AppRoutePaths.profile}/guides/$slug?lang=${value.locale.resolveLang(gates)}',
                ),
                onLoadMore: () => ref.invoke(guidesListViewModel.loadMore()),
              ),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent({
    required BuildContext context,
    required GuidesListState state,
    required bool prefersEnglish,
    required String query,
    required ValueChanged<String> onOpenGuide,
    required VoidCallback onLoadMore,
  }) {
    final tokens = DesignTokensTheme.of(context);

    final filtered = _applyFilters(state.items, state.persona);
    final searched = query.isEmpty ? filtered : _applyQuery(filtered, query);

    final recommended = query.isEmpty
        ? _recommendedForPersona(filtered, state.persona, limit: 3)
        : const <Guide>[];

    return [
      if (recommended.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.md,
              tokens.spacing.lg,
              tokens.spacing.sm,
            ),
            child: _SectionHeader(
              title: prefersEnglish ? 'Recommended' : 'おすすめ',
              subtitle: prefersEnglish
                  ? 'Picked for your persona and locale'
                  : 'ペルソナと地域に合わせたおすすめ',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 168,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: recommended.length,
              separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.md),
              itemBuilder: (context, index) {
                final guide = recommended[index];
                return SizedBox(
                  width: 260,
                  child: _GuideCard(
                    guide: guide,
                    prefersEnglish: prefersEnglish,
                    onTap: () => onOpenGuide(guide.slug),
                  ),
                );
              },
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.lg,
            tokens.spacing.lg,
            tokens.spacing.sm,
          ),
          child: _SectionHeader(
            title: prefersEnglish ? 'All guides' : 'すべてのガイド',
            subtitle: prefersEnglish
                ? 'Culture, how-tos, and FAQs'
                : '文化・使い方・FAQなど',
          ),
        ),
      ),
      if (searched.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.xl),
            child: AppEmptyState(
              title: prefersEnglish ? 'No results' : '見つかりませんでした',
              message: prefersEnglish
                  ? 'Try changing filters or search keywords.'
                  : 'フィルタや検索キーワードを変えてみてください。',
              icon: Icons.search_off_rounded,
            ),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          sliver: SliverList.separated(
            itemCount: searched.length + 1,
            separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.md),
            itemBuilder: (context, index) {
              if (index == searched.length) {
                return _LoadMore(
                  prefersEnglish: prefersEnglish,
                  nextPageToken: state.nextPageToken,
                  isLoading: state.isLoadingMore,
                  onPressed: onLoadMore,
                );
              }

              final guide = searched[index];
              return _GuideCard(
                guide: guide,
                prefersEnglish: prefersEnglish,
                onTap: () => onOpenGuide(guide.slug),
              );
            },
          ),
        ),
      SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.xl)),
    ];
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.state,
    required this.prefersEnglish,
    required this.onLocaleChanged,
    required this.onPersonaChanged,
    required this.onTopicChanged,
  });

  final AsyncValue<GuidesListState> state;
  final bool prefersEnglish;
  final ValueChanged<GuidesLocaleFilter> onLocaleChanged;
  final ValueChanged<GuidesPersonaFilter> onPersonaChanged;
  final ValueChanged<GuideCategory?> onTopicChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final value = state.valueOrNull;

    final locale = value?.locale ?? GuidesLocaleFilter.auto;
    final persona = value?.persona ?? GuidesPersonaFilter.all;
    final topic = value?.topic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: [
            ...GuidesLocaleFilter.values.map(
              (item) => FilterChip(
                label: Text(item.label(prefersEnglish: prefersEnglish)),
                selected: locale == item,
                onSelected: (_) => onLocaleChanged(item),
              ),
            ),
            ...GuidesPersonaFilter.values.map(
              (item) => FilterChip(
                label: Text(item.label(prefersEnglish: prefersEnglish)),
                selected: persona == item,
                onSelected: (_) => onPersonaChanged(item),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: [
            FilterChip(
              label: Text(prefersEnglish ? 'All topics' : 'すべてのトピック'),
              selected: topic == null,
              onSelected: (_) => onTopicChanged(null),
            ),
            ...GuideCategory.values.map(
              (category) => FilterChip(
                label: Text(_topicLabel(category, prefersEnglish)),
                selected: topic == category,
                onSelected: (_) => onTopicChanged(category),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.spacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.guide,
    required this.prefersEnglish,
    required this.onTap,
  });

  final Guide guide;
  final bool prefersEnglish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final translation = _translationFor(guide, prefersEnglish);
    final duration = guide.readingTimeMinutes != null
        ? '${guide.readingTimeMinutes} min'
        : (prefersEnglish ? 'Quick read' : 'すぐ読める');

    final label = _topicLabel(guide.category, prefersEnglish);
    final heroUrl = guide.heroImageUrl;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heroUrl != null && heroUrl.trim().isNotEmpty)
              SizedBox(
                height: 96,
                width: double.infinity,
                child: Image.network(
                  heroUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: tokens.colors.surfaceVariant,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 96,
                width: double.infinity,
                color: tokens.colors.surfaceVariant,
                alignment: Alignment.center,
                child: Icon(
                  Icons.menu_book_outlined,
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      translation.summary ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: tokens.colors.onSurface.withValues(alpha: 0.7),
                        ),
                        SizedBox(width: tokens.spacing.xs),
                        Text(
                          duration,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        SizedBox(width: tokens.spacing.sm),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.sm,
                            vertical: tokens.spacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              tokens.radii.sm,
                            ),
                          ),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({
    required this.prefersEnglish,
    required this.nextPageToken,
    required this.isLoading,
    required this.onPressed,
  });

  final bool prefersEnglish;
  final String? nextPageToken;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    if (nextPageToken == null || nextPageToken!.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.md),
        child: Center(
          child: Text(
            prefersEnglish ? 'No more guides' : 'これ以上はありません',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.md),
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Text(prefersEnglish ? 'Load more' : 'もっと見る'),
      ),
    );
  }
}

String _topicLabel(GuideCategory category, bool prefersEnglish) {
  return switch (category) {
    GuideCategory.culture => prefersEnglish ? 'Culture' : '文化',
    GuideCategory.howto => prefersEnglish ? 'How-to' : '使い方',
    GuideCategory.policy => prefersEnglish ? 'Policy' : '規約',
    GuideCategory.faq => 'FAQ',
    GuideCategory.news => prefersEnglish ? 'News' : 'お知らせ',
    GuideCategory.other => prefersEnglish ? 'Other' : 'その他',
  };
}

GuideTranslation _translationFor(Guide guide, bool prefersEnglish) {
  final key = prefersEnglish ? 'en' : 'ja';
  return guide.translations[key] ?? guide.translations.values.first;
}

List<Guide> _applyFilters(List<Guide> guides, GuidesPersonaFilter persona) {
  if (persona == GuidesPersonaFilter.all) return guides;
  return guides.where((g) => _matchesPersona(g, persona)).toList();
}

List<Guide> _applyQuery(List<Guide> guides, String query) {
  return guides.where((guide) {
    final haystack = [
      ...guide.translations.values.map((t) => t.title),
      ...guide.translations.values.map((t) => t.summary ?? ''),
      ...guide.tags,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }).toList();
}

List<Guide> _recommendedForPersona(
  List<Guide> guides,
  GuidesPersonaFilter persona, {
  required int limit,
}) {
  final scored =
      guides
          .map((g) => (score: _recommendationScore(g, persona), guide: g))
          .where((t) => t.score > 0)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  final picked = scored.take(limit).map((t) => t.guide).toList();
  if (picked.isNotEmpty) return picked;

  return guides.take(limit).toList();
}

int _recommendationScore(Guide guide, GuidesPersonaFilter persona) {
  var score = 0;
  final tags = guide.tags.map((t) => t.toLowerCase()).toList();
  if (tags.contains('featured') || tags.contains('recommended')) score += 3;

  if (persona != GuidesPersonaFilter.all && _matchesPersona(guide, persona)) {
    score += 3;
  }

  score += switch (guide.category) {
    GuideCategory.howto => 2,
    GuideCategory.culture => 2,
    GuideCategory.faq => 1,
    _ => 0,
  };

  final published = guide.publishAt ?? guide.updatedAt;
  final ageDays = DateTime.now().difference(published).inDays;
  if (ageDays <= 30) score += 1;
  return score;
}

bool _matchesPersona(Guide guide, GuidesPersonaFilter persona) {
  final tags = guide.tags.map((t) => t.toLowerCase()).toList();
  return switch (persona) {
    GuidesPersonaFilter.japanese =>
      tags.any((t) => t.contains('jp') || t.contains('japanese')) ||
          tags.contains('official') ||
          tags.contains('registry') ||
          guide.category == GuideCategory.policy,
    GuidesPersonaFilter.foreigner =>
      tags.any(
            (t) =>
                t.contains('intl') ||
                t.contains('international') ||
                t.contains('foreigner') ||
                t.contains('global'),
          ) ||
          tags.contains('shipping') ||
          guide.category == GuideCategory.culture,
    GuidesPersonaFilter.all => true,
  };
}
