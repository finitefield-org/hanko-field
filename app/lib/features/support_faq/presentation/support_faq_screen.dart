import 'dart:async';

import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/support_faq/application/support_faq_controller.dart';
import 'package:app/features/support_faq/domain/support_faq.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SupportFaqScreen extends ConsumerStatefulWidget {
  const SupportFaqScreen({super.key});

  @override
  ConsumerState<SupportFaqScreen> createState() => _SupportFaqScreenState();
}

class _SupportFaqScreenState extends ConsumerState<SupportFaqScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(supportFaqControllerProvider);
    final controller = ref.read(supportFaqControllerProvider.notifier);
    final navigation = ref.read(appNavigationControllerProvider);

    return Scaffold(
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SupportFaqError(
          message: l10n.supportFaqLoadError,
          retryLabel: l10n.supportFaqRetry,
          onRetry: () =>
              _refreshWithFeedback(controller, l10n, showSnackBar: true),
        ),
        data: (state) =>
            _buildBody(context, state, controller, navigation, l10n),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SupportFaqState state,
    SupportFaqController controller,
    AppNavigationController navigation,
    AppLocalizations l10n,
  ) {
    if (_searchController.text != state.searchTerm) {
      _searchController.value = TextEditingValue(
        text: state.searchTerm,
        selection: TextSelection.collapsed(offset: state.searchTerm.length),
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () =>
          _refreshWithFeedback(controller, l10n, showSnackBar: true),
      edgeOffset: AppTokens.spaceXL,
      displacement: AppTokens.spaceXXL,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(state, controller, l10n),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceM,
                AppTokens.spaceL,
                AppTokens.spaceS,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.supportFaqSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  if (state.lastUpdated != null)
                    Text(
                      l10n.supportFaqUpdatedAt(
                        _formatTimestamp(state.lastUpdated!, l10n),
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (state.fromCache) ...[
                    const SizedBox(height: AppTokens.spaceS / 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        avatar: const Icon(Icons.offline_pin, size: 18),
                        label: Text(
                          l10n.supportFaqOfflineBadge(
                            _formatTimestamp(
                              state.lastUpdated ?? DateTime.now(),
                              l10n,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (state.suggestions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceS,
                  AppTokens.spaceL,
                  AppTokens.spaceS,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.supportFaqSuggestionsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.spaceS),
                    Wrap(
                      spacing: AppTokens.spaceS,
                      runSpacing: AppTokens.spaceS,
                      children: [
                        for (final suggestion in state.suggestions)
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () {
                              _searchFocusNode.requestFocus();
                              controller.applySuggestion(suggestion);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (state.categories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceM,
                  AppTokens.spaceL,
                  AppTokens.spaceS,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.supportFaqCategoriesTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.spaceS),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppTokens.spaceS,
                            ),
                            child: FilterChip(
                              selected: state.selectedCategoryId == null,
                              label: Text(l10n.supportFaqCategoryAllChip),
                              avatar: const Icon(Icons.all_inclusive, size: 18),
                              onSelected: (_) =>
                                  controller.selectCategory(null),
                            ),
                          ),
                          for (final category in state.categories)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppTokens.spaceS,
                              ),
                              child: FilterChip(
                                label: Text(category.title),
                                avatar: Icon(_categoryIcon(category.icon)),
                                tooltip: category.highlight,
                                selected:
                                    state.selectedCategoryId == category.id,
                                onSelected: (_) =>
                                    controller.selectCategory(category.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (state.filteredEntries.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceS,
                AppTokens.spaceL,
                AppTokens.spaceXL,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = state.filteredEntries[index];
                  final responded = state.feedback[entry.id];
                  final busy = state.pendingFeedbackEntryIds.contains(entry.id);
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == state.filteredEntries.length - 1
                          ? 0
                          : AppTokens.spaceM,
                    ),
                    child: _FaqEntryTile(
                      entry: entry,
                      searchTerm: state.searchTerm,
                      responded: responded,
                      isBusy: busy,
                      l10n: l10n,
                      onFeedback: (choice) =>
                          _handleFeedback(controller, entry, choice, l10n),
                    ),
                  );
                }, childCount: state.filteredEntries.length),
              ),
            )
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceXXL,
                ),
                child: _FaqEmptyState(
                  l10n: l10n,
                  onContact: () {
                    navigation.push(const SupportContactRoute());
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(
    SupportFaqState state,
    SupportFaqController controller,
    AppLocalizations l10n,
  ) {
    return SliverAppBar.large(
      title: Text(l10n.supportFaqTitle),
      centerTitle: true,
      pinned: true,
      actions: [
        IconButton(
          tooltip: l10n.supportFaqFilterTooltip,
          icon: const Icon(Icons.filter_list),
          onPressed: state.categories.isEmpty
              ? null
              : () => _openFilterSheet(state, controller, l10n),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(86),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            0,
            AppTokens.spaceL,
            AppTokens.spaceS,
          ),
          child: Column(
            children: [
              SearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: l10n.supportFaqSearchHint,
                leading: const Icon(Icons.search),
                onChanged: controller.updateSearch,
                onSubmitted: controller.updateSearch,
                trailing: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: l10n.supportFaqSearchClearTooltip,
                      onPressed: controller.clearSearch,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (state.isRefreshing) ...[
                const SizedBox(height: AppTokens.spaceS),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterSheet(
    SupportFaqState state,
    SupportFaqController controller,
    AppLocalizations l10n,
  ) async {
    final selection = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final groupValue = state.selectedCategoryId ?? _allCategoriesValue;
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                l10n.supportFaqFilterSheetTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _FaqFilterOptionTile(
              value: _allCategoriesValue,
              selectedValue: groupValue,
              title: l10n.supportFaqFilterAll,
              onSelected: (value) => Navigator.of(context).pop(value),
            ),
            for (final category in state.categories)
              _FaqFilterOptionTile(
                value: category.id,
                selectedValue: groupValue,
                title: category.title,
                subtitle: category.highlight,
                onSelected: (value) => Navigator.of(context).pop(value),
              ),
            const SizedBox(height: AppTokens.spaceM),
          ],
        );
      },
    );
    if (!mounted || selection == null) {
      return;
    }
    if (selection == _allCategoriesValue) {
      controller.selectCategory(null);
    } else {
      controller.selectCategory(selection);
    }
  }

  Future<void> _handleFeedback(
    SupportFaqController controller,
    FaqEntry entry,
    FaqFeedbackChoice choice,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.sendFeedback(entry.id, choice);
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supportFaqFeedbackThanks)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supportFaqFeedbackError)));
    }
  }

  Future<void> _refreshWithFeedback(
    SupportFaqController controller,
    AppLocalizations l10n, {
    bool showSnackBar = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.refresh();
    } catch (_) {
      if (!mounted || !showSnackBar) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supportFaqLoadError)));
    }
  }
}

class _FaqEntryTile extends StatelessWidget {
  const _FaqEntryTile({
    required this.entry,
    required this.searchTerm,
    required this.responded,
    required this.isBusy,
    required this.l10n,
    required this.onFeedback,
  });

  final FaqEntry entry;
  final String searchTerm;
  final FaqFeedbackChoice? responded;
  final bool isBusy;
  final AppLocalizations l10n;
  final ValueChanged<FaqFeedbackChoice> onFeedback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlightStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      backgroundColor: scheme.secondaryContainer,
      color: scheme.onSecondaryContainer,
      fontWeight: FontWeight.w600,
    );
    final selected = responded == null ? <FaqFeedbackChoice>{} : {responded!};

    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HighlightedText(
              text: entry.question,
              query: searchTerm,
              style: Theme.of(context).textTheme.titleMedium,
              highlightStyle: highlightStyle,
            ),
            const SizedBox(height: AppTokens.spaceS),
            _HighlightedText(
              text: entry.answer,
              query: searchTerm,
              style: Theme.of(context).textTheme.bodyMedium,
              highlightStyle: highlightStyle,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Wrap(
              spacing: AppTokens.spaceS,
              runSpacing: AppTokens.spaceS,
              children: [
                for (final tag in entry.tags)
                  Chip(
                    label: Text(tag),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceS,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              l10n.supportFaqHelpfulCount(entry.helpfulCount),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              l10n.supportFaqHelpfulPrompt,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            SegmentedButton<FaqFeedbackChoice>(
              segments: [
                ButtonSegment<FaqFeedbackChoice>(
                  value: FaqFeedbackChoice.helpful,
                  label: Text(l10n.supportFaqHelpfulYes),
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                ),
                ButtonSegment<FaqFeedbackChoice>(
                  value: FaqFeedbackChoice.unhelpful,
                  label: Text(l10n.supportFaqHelpfulNo),
                  icon: const Icon(Icons.thumb_down_alt_outlined),
                ),
              ],
              multiSelectionEnabled: false,
              showSelectedIcon: false,
              selected: selected,
              onSelectionChanged: isBusy || responded != null
                  ? null
                  : (values) {
                      if (values.isEmpty) {
                        return;
                      }
                      onFeedback(values.first);
                    },
            ),
            if (isBusy) ...[
              const SizedBox(height: AppTokens.spaceS),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.highlightStyle,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return Text(text, style: style);
    }
    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(normalized, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + normalized.length),
          style: highlightStyle,
        ),
      );
      start = index + normalized.length;
    }
    return Text.rich(
      TextSpan(children: spans, style: style),
      textAlign: TextAlign.start,
    );
  }
}

class _FaqEmptyState extends StatelessWidget {
  const _FaqEmptyState({required this.l10n, required this.onContact});

  final AppLocalizations l10n;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: scheme.primary),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              l10n.supportFaqNoResultsTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              l10n.supportFaqNoResultsBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceL),
            FilledButton(
              onPressed: onContact,
              child: Text(l10n.supportFaqContactCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportFaqError extends StatelessWidget {
  const _SupportFaqError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final FutureOr<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime timestamp, AppLocalizations l10n) {
  final format = DateFormat.yMMMd(l10n.localeName).add_Hm();
  return format.format(timestamp);
}

IconData _categoryIcon(FaqCategoryIcon icon) {
  switch (icon) {
    case FaqCategoryIcon.sparkles:
      return Icons.auto_awesome;
    case FaqCategoryIcon.shipping:
      return Icons.local_shipping_outlined;
    case FaqCategoryIcon.billing:
      return Icons.request_quote_outlined;
    case FaqCategoryIcon.account:
      return Icons.verified_user_outlined;
    case FaqCategoryIcon.ai:
      return Icons.memory_outlined;
    case FaqCategoryIcon.status:
      return Icons.fact_check_outlined;
  }
}

const _allCategoriesValue = '__all__';

class _FaqFilterOptionTile extends StatelessWidget {
  const _FaqFilterOptionTile({
    required this.value,
    required this.selectedValue,
    required this.title,
    required this.onSelected,
    this.subtitle,
  });

  final String value;
  final String selectedValue;
  final String title;
  final String? subtitle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: () => onSelected(value),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
    );
  }
}
