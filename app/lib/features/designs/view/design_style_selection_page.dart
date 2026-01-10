// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_style_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignStyleSelectionPage extends ConsumerStatefulWidget {
  const DesignStyleSelectionPage({
    super.key,
    this.sourceType,
    this.queryFilters = const <String>{},
  });

  final DesignSourceType? sourceType;
  final Set<String> queryFilters;

  @override
  ConsumerState<DesignStyleSelectionPage> createState() =>
      _DesignStyleSelectionPageState();
}

class _DesignStyleSelectionPageState
    extends ConsumerState<DesignStyleSelectionPage> {
  late final PageController _pageController = PageController(
    viewportFraction: 0.85,
  );

  @override
  void initState() {
    super.initState();
    if (widget.queryFilters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invoke(designStyleViewModel.updateFilters(widget.queryFilters));
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final styles = ref.watch(designStyleViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppTopBar(
        title: prefersEnglish ? 'Choose style' : '書体・テンプレ選択',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: prefersEnglish ? 'Typography guidance' : '書体の選び方',
            onPressed: () =>
                _showGuidance(context, prefersEnglish: prefersEnglish),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      body: SafeArea(
        child: switch (styles) {
          AsyncLoading<DesignStyleState>() => _StyleSkeleton(),
          AsyncError(:final error) when styles.valueOrNull == null =>
            _StyleError(error: error.toString()),
          _ => _StyleContent(
            state: styles.valueOrNull!,
            prefersEnglish: prefersEnglish,
            pageController: _pageController,
            onScriptChanged: (script) =>
                ref.invoke(designStyleViewModel.setScript(script)),
            onShapeChanged: (shape) =>
                ref.invoke(designStyleViewModel.setShape(shape)),
            onTemplateSelected: (template) async {
              final id = template.id ?? template.slug ?? template.name;
              await ref.invoke(designStyleViewModel.selectTemplate(id));
              await ref.invoke(designStyleViewModel.prefetchTemplate(id));
              _animateToTemplate(template);
            },
            onContinue: (selection) =>
                _continueToEditor(context: context, selection: selection),
            onResetFilters: () => ref.invalidate(designStyleViewModel),
            filters: styles.valueOrNull?.activeFilters ?? const <String>{},
            sourceType: widget.sourceType,
          ),
        },
      ),
    );
  }

  void _animateToTemplate(Template template) {
    final state = ref.container.read(designStyleViewModel).valueOrNull;
    if (state == null) return;
    final index = state.visibleTemplates.indexOf(template);
    if (index < 0 || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _continueToEditor({
    required BuildContext context,
    required _StyleSelection selection,
  }) async {
    final navigation = context.navigation;
    final messenger = ScaffoldMessenger.of(context);
    final gates = ref.container.read(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final selectionRef = selection.template.id ?? selection.template.slug;
    await ref.invoke(
      designCreationViewModel.setStyleSelection(
        shape: selection.shape,
        size: selection.size,
        style: selection.style,
        template: selection.template,
      ),
    );
    await ref.invoke(
      designStyleViewModel.prefetchTemplate(
        selectionRef ?? selection.template.name,
      ),
    );

    await navigation.go(
      '${AppRoutePaths.designEditor}?template=${selectionRef ?? 'draft'}',
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          selectionRef != null
              ? (prefersEnglish
                    ? 'Loaded ${selection.template.name}'
                    : '${selection.template.name} を読み込みました')
              : (prefersEnglish ? 'Using ad-hoc style' : 'このスタイルで進みます'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showGuidance(
    BuildContext context, {
    required bool prefersEnglish,
  }) {
    final tokens = DesignTokensTheme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radii.lg),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefersEnglish ? 'Script tips' : '書体選びのヒント',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(
                prefersEnglish
                    ? 'Tensho/Reisho for official seals, Kaisho/Gyosho for readability, Koentai for bold or digital use.'
                    : '公式用途は篆書/隷書、読みやすさ重視は楷書/行書、デジタルや太め仕上げは古印体がおすすめです。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.82),
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: [
                  Chip(
                    label: Text(prefersEnglish ? 'Registrability' : '実印向け'),
                    avatar: const Icon(Icons.verified_user_outlined),
                  ),
                  Chip(
                    label: Text(prefersEnglish ? 'Digital export' : 'デジタル仕上げ'),
                    avatar: const Icon(Icons.cloud_download_outlined),
                  ),
                  Chip(
                    label: Text(prefersEnglish ? 'Materials' : '素材おすすめ'),
                    avatar: const Icon(Icons.inventory_2_outlined),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StyleContent extends StatelessWidget {
  const _StyleContent({
    required this.state,
    required this.prefersEnglish,
    required this.pageController,
    required this.onScriptChanged,
    required this.onShapeChanged,
    required this.onTemplateSelected,
    required this.onContinue,
    required this.onResetFilters,
    required this.filters,
    required this.sourceType,
  });

  final DesignStyleState state;
  final bool prefersEnglish;
  final PageController pageController;
  final ValueChanged<ScriptFamily> onScriptChanged;
  final ValueChanged<SealShape> onShapeChanged;
  final ValueChanged<Template> onTemplateSelected;
  final ValueChanged<_StyleSelection> onContinue;
  final VoidCallback onResetFilters;
  final Set<String> filters;
  final DesignSourceType? sourceType;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final selected = state.selectedTemplate;
    final sampleName =
        state.input?.rawName ?? (prefersEnglish ? 'SATO TARO' : '山田 太郎');

    if (state.visibleTemplates.isEmpty) {
      return Center(
        child: AppEmptyState(
          title: prefersEnglish ? 'No styles found' : '該当する書体がありません',
          message: prefersEnglish
              ? 'Try switching script or shape filters. We only show templates with available fonts.'
              : 'スクリプト/形状フィルターを変えてください。利用可能なフォントがあるものだけを表示しています。',
          actionLabel: prefersEnglish ? 'Reset filters' : 'フィルターをリセット',
          onAction: onResetFilters,
        ),
      );
    }

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
                _Header(
                  prefersEnglish: prefersEnglish,
                  sampleName: sampleName,
                  filters: filters,
                  sourceType: sourceType,
                ),
                SizedBox(height: tokens.spacing.md),
                _ScriptFilters(
                  selected: state.selectedScript,
                  prefersEnglish: prefersEnglish,
                  onChanged: onScriptChanged,
                ),
                SizedBox(height: tokens.spacing.sm),
                _ShapeFilters(
                  selected: state.selectedShape,
                  prefersEnglish: prefersEnglish,
                  onChanged: onShapeChanged,
                ),
                SizedBox(height: tokens.spacing.md),
                if (state.isPrefetching) ...[
                  LinearProgressIndicator(
                    minHeight: 3,
                    color: tokens.colors.primary,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                ],
                Text(
                  prefersEnglish ? 'Preview carousel' : 'プレビューから選択',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.sm),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 320,
            child: PageView.builder(
              controller: pageController,
              padEnds: false,
              itemCount: state.visibleTemplates.length,
              itemBuilder: (context, index) {
                final template = state.visibleTemplates[index];
                final isSelected = template == selected;
                final font = _fontFor(template);
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? tokens.spacing.lg : tokens.spacing.sm,
                    right: tokens.spacing.sm,
                  ),
                  child: _TemplateCard(
                    template: template,
                    font: font,
                    prefersEnglish: prefersEnglish,
                    sampleName: sampleName,
                    isSelected: isSelected,
                    onSelect: () => onTemplateSelected(template),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: _SelectionDetails(
              template: selected,
              font: selected != null ? _fontFor(selected) : null,
              prefersEnglish: prefersEnglish,
              onContinue: selected != null
                  ? () => onContinue(
                      _selectionFromTemplate(selected, state.selectedShape),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Font? _fontFor(Template template) {
    if (state.fonts.isEmpty) return null;
    final ref = template.defaults?.fontRef;
    if (ref != null) {
      final found = state.fonts.firstWhereOrNull(
        (font) => font.id == ref || font.family == ref,
      );
      if (found != null) return found;
    }
    return state.fonts.firstWhereOrNull(
      (font) => font.writing == template.writing,
    );
  }

  _StyleSelection _selectionFromTemplate(Template template, SealShape shape) {
    final defaults = template.defaults;
    final sizeMm = defaults?.sizeMm ?? template.constraints.sizeMm.min;

    return _StyleSelection(
      template: template,
      shape: shape,
      size: DesignSize(mm: sizeMm),
      style: DesignStyle(
        writing: template.writing,
        fontRef: defaults?.fontRef,
        templateRef: template.id ?? template.slug,
        stroke: defaults?.stroke != null
            ? StrokeConfig(
                weight: defaults!.stroke?.weight,
                contrast: defaults.stroke?.contrast,
              )
            : null,
        layout: defaults?.layout != null
            ? LayoutConfig(
                grid: defaults!.layout?.grid,
                margin: defaults.layout?.margin,
              )
            : null,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.prefersEnglish,
    required this.sampleName,
    required this.filters,
    required this.sourceType,
  });

  final bool prefersEnglish;
  final String sampleName;
  final Set<String> filters;
  final DesignSourceType? sourceType;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final shapeChip = filters.contains('official')
        ? (prefersEnglish ? 'Official' : '公的向け')
        : (prefersEnglish ? 'Personal' : '個人利用');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: tokens.colors.primary),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: Text(
                  prefersEnglish ? 'Previewing' : 'プレビュー名',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Chip(
                label: Text(
                  sourceType == DesignSourceType.logo
                      ? (prefersEnglish ? 'Logo' : 'ロゴ')
                      : (prefersEnglish ? 'Text' : '文字入力'),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(sampleName, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: [
              Chip(
                label: Text(shapeChip),
                avatar: const Icon(Icons.tune),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              if (filters.contains('digital'))
                Chip(
                  label: Text(prefersEnglish ? 'Digital-friendly' : 'デジタル重視'),
                  avatar: const Icon(Icons.memory_outlined),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScriptFilters extends StatelessWidget {
  const _ScriptFilters({
    required this.selected,
    required this.prefersEnglish,
    required this.onChanged,
  });

  final ScriptFamily selected;
  final bool prefersEnglish;
  final ValueChanged<ScriptFamily> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SegmentedButton<ScriptFamily>(
      segments: [
        ButtonSegment(
          value: ScriptFamily.kanji,
          label: Text(prefersEnglish ? 'Kanji' : '漢字'),
          icon: const Icon(Icons.g_translate_outlined),
        ),
        ButtonSegment(
          value: ScriptFamily.kana,
          label: Text(prefersEnglish ? 'Kana mix' : 'かな入り'),
          icon: const Icon(Icons.edit_road_outlined),
        ),
        ButtonSegment(
          value: ScriptFamily.roman,
          label: Text(prefersEnglish ? 'Roman' : 'ローマ字'),
          icon: const Icon(Icons.language),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (value) => onChanged(value.first),
      style: ButtonStyle(
        side: WidgetStateProperty.all(
          BorderSide(color: tokens.colors.outline.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

class _ShapeFilters extends StatelessWidget {
  const _ShapeFilters({
    required this.selected,
    required this.prefersEnglish,
    required this.onChanged,
  });

  final SealShape selected;
  final bool prefersEnglish;
  final ValueChanged<SealShape> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Wrap(
      spacing: tokens.spacing.sm,
      runSpacing: tokens.spacing.xs,
      children: [
        FilterChip(
          label: Text(prefersEnglish ? 'Round' : '丸型'),
          selected: selected == SealShape.round,
          onSelected: (_) => onChanged(SealShape.round),
          avatar: const Icon(Icons.radio_button_checked_outlined),
        ),
        FilterChip(
          label: Text(prefersEnglish ? 'Square' : '角型'),
          selected: selected == SealShape.square,
          onSelected: (_) => onChanged(SealShape.square),
          avatar: const Icon(Icons.crop_square_outlined),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.font,
    required this.prefersEnglish,
    required this.sampleName,
    required this.isSelected,
    required this.onSelect,
  });

  final Template template;
  final Font? font;
  final bool prefersEnglish;
  final String sampleName;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final borderColor = isSelected
        ? tokens.colors.primary
        : tokens.colors.outline.withValues(alpha: 0.3);

    return Card(
      elevation: isSelected ? 5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        side: BorderSide(color: borderColor, width: isSelected ? 1.4 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radii.md),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                tokens.colors.surfaceVariant,
                                tokens.colors.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      if (template.previewUrl != null)
                        Positioned.fill(
                          child: Image.network(
                            template.previewUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: EdgeInsets.all(tokens.spacing.sm),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacing.sm,
                              vertical: tokens.spacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.colors.surface.withValues(
                                alpha: 0.78,
                              ),
                              borderRadius: BorderRadius.circular(
                                tokens.radii.sm,
                              ),
                            ),
                            child: Text(
                              sampleName,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: tokens.spacing.sm,
                        right: tokens.spacing.sm,
                        child: FilterChip(
                          label: Text(prefersEnglish ? 'Favorite' : 'お気に入り'),
                          selected: isSelected,
                          onSelected: (_) => onSelect(),
                          avatar: Icon(
                            isSelected ? Icons.favorite : Icons.favorite_border,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                template.description ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: tokens.spacing.sm),
              Wrap(
                spacing: tokens.spacing.xs,
                runSpacing: tokens.spacing.xs,
                children: [
                  Chip(
                    label: Text(
                      template.shape == SealShape.round
                          ? (prefersEnglish ? 'Round' : '丸')
                          : (prefersEnglish ? 'Square' : '角'),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      _writingLabel(template.writing, prefersEnglish),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (font != null)
                    Chip(
                      label: Text(font!.family),
                      avatar: const Icon(Icons.font_download_outlined),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (template.tags.isNotEmpty)
                    ...template.tags
                        .take(2)
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _writingLabel(WritingStyle style, bool prefersEnglish) {
    switch (style) {
      case WritingStyle.tensho:
        return prefersEnglish ? 'Tensho' : '篆書';
      case WritingStyle.reisho:
        return prefersEnglish ? 'Reisho' : '隷書';
      case WritingStyle.kaisho:
        return prefersEnglish ? 'Kaisho' : '楷書';
      case WritingStyle.gyosho:
        return prefersEnglish ? 'Gyosho' : '行書';
      case WritingStyle.koentai:
        return prefersEnglish ? 'Koentai' : '古印体';
      case WritingStyle.custom:
        return prefersEnglish ? 'Custom' : 'カスタム';
    }
  }
}

class _SelectionDetails extends StatelessWidget {
  const _SelectionDetails({
    required this.template,
    required this.font,
    required this.prefersEnglish,
    required this.onContinue,
  });

  final Template? template;
  final Font? font;
  final bool prefersEnglish;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    if (template == null) return const SizedBox.shrink();
    final tpl = template!;
    final defaults = tpl.defaults;
    final double size = defaults?.sizeMm ?? tpl.constraints.sizeMm.min;
    final double strokeWeight =
        defaults?.stroke?.weight ?? tpl.constraints.strokeWeight.min ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefersEnglish ? 'Selected style' : '選択した書体',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tpl.name, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.spacing.xs),
              Text(
                tpl.description ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.72),
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.xs,
                children: [
                  Chip(
                    label: Text(
                      '${prefersEnglish ? 'Size' : 'サイズ'} ${size.toStringAsFixed(1)}mm',
                    ),
                    avatar: const Icon(Icons.straighten),
                  ),
                  Chip(
                    label: Text(
                      '${prefersEnglish ? 'Stroke' : 'ストローク'} ${strokeWeight.toStringAsFixed(2)}',
                    ),
                    avatar: const Icon(Icons.line_weight),
                  ),
                  if (font != null)
                    Chip(
                      label: Text(font!.family),
                      avatar: const Icon(Icons.font_download_outlined),
                    ),
                  Chip(
                    label: Text(
                      tpl.shape == SealShape.round
                          ? (prefersEnglish ? 'Round' : '丸型')
                          : (prefersEnglish ? 'Square' : '角型'),
                    ),
                    avatar: const Icon(Icons.category_outlined),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.md),
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(prefersEnglish ? 'Continue to editor' : 'エディタへ進む'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StyleSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeletonBlock(width: 180, height: 20),
          SizedBox(height: tokens.spacing.sm),
          const AppSkeletonBlock(width: 120),
          SizedBox(height: tokens.spacing.lg),
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.sm),
              itemBuilder: (context, index) => AppSkeletonBlock(
                width: 240,
                height: 260,
                borderRadius: BorderRadius.circular(tokens.radii.lg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleError extends StatelessWidget {
  const _StyleError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: AppEmptyState(
        title: 'Failed to load styles',
        message: error,
        actionLabel: 'Retry',
        onAction: () => context.go(AppRoutePaths.designStyle),
      ),
    );
  }
}

class _StyleSelection {
  const _StyleSelection({
    required this.template,
    required this.shape,
    required this.size,
    required this.style,
  });

  final Template template;
  final SealShape shape;
  final DesignSize size;
  final DesignStyle style;
}
