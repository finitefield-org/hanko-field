import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/features/design_creation/application/style_selection_controller.dart';
import 'package:app/features/design_creation/application/style_selection_state.dart';
import 'package:app/features/design_creation/domain/style_template.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesignStyleSelectionPage extends ConsumerStatefulWidget {
  const DesignStyleSelectionPage({super.key});

  @override
  ConsumerState<DesignStyleSelectionPage> createState() =>
      _DesignStyleSelectionPageState();
}

class _DesignStyleSelectionPageState
    extends ConsumerState<DesignStyleSelectionPage> {
  @override
  void initState() {
    super.initState();
    ref.listen<StyleSelectionState>(styleSelectionControllerProvider, (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message != null && message != previous?.errorMessage && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          ref
              .read(styleSelectionControllerProvider.notifier)
              .clearErrorMessage();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(styleSelectionControllerProvider);
    final notifier = ref.read(styleSelectionControllerProvider.notifier);
    final theme = Theme.of(context);
    final scripts = state.availableScripts.isEmpty
        ? StyleScriptFamily.values.toSet()
        : state.availableScripts;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.designStyleHelpTooltip,
            onPressed: () =>
                showHelpOverlay(context, contextLabel: l10n.designStyleTitle),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppTokens.medium,
          child: state.isLoading
              ? const _LoadingView()
              : state.templates.isEmpty
              ? _EmptyView(onRetry: _handleRetry, l10n: l10n)
              : RefreshIndicator(
                  onRefresh: notifier.retry,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTokens.spaceL,
                            AppTokens.spaceL,
                            AppTokens.spaceL,
                            AppTokens.spaceM,
                          ),
                          child: Text(
                            l10n.designStyleSubtitle,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.spaceL,
                          ),
                          child: _ScriptSegmentControl(
                            scripts: scripts,
                            selected: state.scriptFilter,
                            onChanged: notifier.changeScript,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTokens.spaceL,
                            AppTokens.spaceM,
                            AppTokens.spaceL,
                            AppTokens.spaceL,
                          ),
                          child: _ShapeFilterChips(
                            available: state.availableShapes,
                            active: state.activeShapes,
                            onToggle: notifier.toggleShapeFilter,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 320,
                          child: _TemplateCarousel(
                            templates: state.visibleTemplates,
                            selectedTemplateId: state.selectedTemplateId,
                            favoriteTemplateIds: state.favoriteTemplateIds,
                            prefetchingTemplateId: state.prefetchingTemplateId,
                            favoriteTogglingTemplateIds:
                                state.togglingFavoriteTemplateIds,
                            onSelect: notifier.selectTemplate,
                            onToggleFavorite: notifier.toggleFavorite,
                          ),
                        ),
                      ),
                      if (state.selectedTemplate() != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppTokens.spaceL,
                              AppTokens.spaceL,
                              AppTokens.spaceL,
                              AppTokens.spaceXXL,
                            ),
                            child: _SelectionDetailsCard(
                              template: state.selectedTemplate()!,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceM,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: FilledButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.designStyleContinue),
          onPressed: state.hasSelection ? () => _handleContinue(context) : null,
        ),
      ),
    );
  }

  void _handleContinue(BuildContext context) {
    final notifier = ref.read(appStateProvider.notifier);
    notifier.push(CreationStageRoute(const ['editor']));
  }

  void _handleRetry() {
    ref.read(styleSelectionControllerProvider.notifier).retry();
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry, required this.l10n});

  final VoidCallback onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.style_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            l10n.designStyleEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.designStyleEmptyBody,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceL),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.designStyleRetry),
          ),
        ],
      ),
    );
  }
}

class _ScriptSegmentControl extends ConsumerWidget {
  const _ScriptSegmentControl({
    required this.scripts,
    required this.selected,
    required this.onChanged,
  });

  final Set<StyleScriptFamily> scripts;
  final StyleScriptFamily selected;
  final void Function(StyleScriptFamily script) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final segments = scripts
        .map(
          (script) => ButtonSegment<StyleScriptFamily>(
            value: script,
            label: Text(_scriptLabel(l10n, script)),
            icon: Icon(_scriptIcon(script)),
          ),
        )
        .toList(growable: false);
    return SegmentedButton<StyleScriptFamily>(
      segments: segments,
      selected: {selected},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        onChanged(selection.first);
      },
    );
  }

  String _scriptLabel(AppLocalizations l10n, StyleScriptFamily script) {
    return switch (script) {
      StyleScriptFamily.kanji => l10n.designStyleScriptKanji,
      StyleScriptFamily.kana => l10n.designStyleScriptKana,
      StyleScriptFamily.roman => l10n.designStyleScriptRoman,
    };
  }

  IconData _scriptIcon(StyleScriptFamily script) {
    return switch (script) {
      StyleScriptFamily.kanji => Icons.translate,
      StyleScriptFamily.kana => Icons.auto_stories_outlined,
      StyleScriptFamily.roman => Icons.language,
    };
  }
}

class _ShapeFilterChips extends ConsumerWidget {
  const _ShapeFilterChips({
    required this.available,
    required this.active,
    required this.onToggle,
  });

  final Set<DesignShape> available;
  final Set<DesignShape> active;
  final void Function(DesignShape shape) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chips = available.toList();
    chips.sort((a, b) => a.name.compareTo(b.name));
    return Wrap(
      spacing: AppTokens.spaceS,
      runSpacing: AppTokens.spaceS,
      children: [
        for (final shape in chips)
          FilterChip(
            label: Text(_shapeLabel(l10n, shape)),
            showCheckmark: false,
            selected: active.isEmpty || active.contains(shape),
            onSelected: (_) => onToggle(shape),
          ),
      ],
    );
  }

  String _shapeLabel(AppLocalizations l10n, DesignShape shape) {
    return switch (shape) {
      DesignShape.round => l10n.designStyleShapeRound,
      DesignShape.square => l10n.designStyleShapeSquare,
    };
  }
}

class _TemplateCarousel extends StatelessWidget {
  const _TemplateCarousel({
    required this.templates,
    required this.selectedTemplateId,
    required this.favoriteTemplateIds,
    required this.prefetchingTemplateId,
    required this.favoriteTogglingTemplateIds,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  final List<StyleTemplate> templates;
  final String? selectedTemplateId;
  final Set<String> favoriteTemplateIds;
  final String? prefetchingTemplateId;
  final Set<String> favoriteTogglingTemplateIds;
  final void Function(String templateId) onSelect;
  final Future<void> Function(String templateId) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _TemplateCard(
          template: template,
          selected: template.id == selectedTemplateId,
          isFavorite: favoriteTemplateIds.contains(template.id),
          isPrefetching: prefetchingTemplateId == template.id,
          isFavoriteBusy: favoriteTogglingTemplateIds.contains(template.id),
          onTap: () => onSelect(template.id),
          onToggleFavorite: () {
            onToggleFavorite(template.id);
          },
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: AppTokens.spaceM),
      itemCount: templates.length,
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.isFavorite,
    required this.isPrefetching,
    required this.isFavoriteBusy,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final StyleTemplate template;
  final bool selected;
  final bool isFavorite;
  final bool isPrefetching;
  final bool isFavoriteBusy;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    final highlight = selected
        ? scheme.primary.withValues(alpha: 0.08)
        : scheme.surface;
    return SizedBox(
      width: 260,
      child: Card(
        elevation: selected ? 4 : 1,
        color: highlight,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.radiusL,
          side: BorderSide(width: selected ? 2 : 1, color: borderColor),
        ),
        child: InkWell(
          borderRadius: AppTokens.radiusL,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppTokens.radiusM,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            template.previewUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) {
                                return child;
                              }
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: scheme.outline,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (isPrefetching)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.6),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceM),
                Text(
                  template.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  template.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTokens.spaceS),
                Wrap(
                  spacing: AppTokens.spaceS,
                  runSpacing: AppTokens.spaceS,
                  children: [
                    for (final tag in template.tags.take(3))
                      Chip(
                        label: Text(tag),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: isFavoriteBusy
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.primary,
                              ),
                            ),
                          )
                        : Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? scheme.error : null,
                          ),
                    label: Text(
                      isFavorite
                          ? AppLocalizations.of(
                              context,
                            ).designStyleFavoritesRemove
                          : AppLocalizations.of(
                              context,
                            ).designStyleFavoritesAdd,
                    ),
                    onPressed: isFavoriteBusy ? null : onToggleFavorite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionDetailsCard extends StatelessWidget {
  const _SelectionDetailsCard({required this.template});

  final StyleTemplate template;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: AppTokens.elevations[1],
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.designStyleSelectedHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              template.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              template.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTokens.spaceL),
            Wrap(
              spacing: AppTokens.spaceS,
              runSpacing: AppTokens.spaceS,
              children: [
                Chip(
                  avatar: const Icon(Icons.shutter_speed, size: 18),
                  label: Text(switch (template.scriptFamily) {
                    StyleScriptFamily.kanji => l10n.designStyleScriptKanji,
                    StyleScriptFamily.kana => l10n.designStyleScriptKana,
                    StyleScriptFamily.roman => l10n.designStyleScriptRoman,
                  }),
                ),
                Chip(
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: Text(switch (template.shape) {
                    DesignShape.round => l10n.designStyleShapeRound,
                    DesignShape.square => l10n.designStyleShapeSquare,
                  }),
                ),
                if (template.fontRefs.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.text_fields_outlined, size: 18),
                    label: Text(template.fontRefs.join(', ')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
