// ignore_for_file: public_member_api_docs, unnecessary_import

import 'dart:async';
import 'dart:math' as math;

import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/monitoring/performance_monitoring.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignEditorPage extends ConsumerStatefulWidget {
  const DesignEditorPage({super.key});

  @override
  ConsumerState<DesignEditorPage> createState() => _DesignEditorPageState();
}

class _DesignEditorPageState extends ConsumerState<DesignEditorPage> {
  int _selectedTool = 1;
  late final Stopwatch _renderStopwatch;
  PerformanceTraceHandle? _renderTrace;
  bool _renderTraceRecorded = false;

  @override
  void initState() {
    super.initState();
    _renderStopwatch = Stopwatch()..start();
    _renderTrace = ref
        .read(performanceMonitorProvider)
        .startTrace(
          'design_editor_render',
          attributes: const {'screen': 'design_editor'},
        );
  }

  @override
  void dispose() {
    _stopRenderTrace(status: 'disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final editor = ref.watch(designEditorViewModel);

    if (!_renderTraceRecorded && editor.valueOrNull != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _renderTraceRecorded) return;
        _stopRenderTrace();
      });
    }
    if (!_renderTraceRecorded &&
        editor is AsyncError<DesignEditorState> &&
        editor.valueOrNull == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _renderTraceRecorded) return;
        _stopRenderTrace(status: 'error');
      });
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _EditorAppBar(
        state: editor.valueOrNull,
        prefersEnglish: prefersEnglish,
        onUndo: () => ref.invoke(designEditorViewModel.undo()),
        onRedo: () => ref.invoke(designEditorViewModel.redo()),
        onReset: () => ref.invoke(designEditorViewModel.reset()),
        onOpenSettings: (state) => _openPropertySheet(context, state),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: editor.valueOrNull == null
          ? null
          : _PreviewFab(
              prefersEnglish: prefersEnglish,
              onPressed: () =>
                  GoRouter.of(context).go(AppRoutePaths.designPreview),
            ),
      body: SafeArea(
        bottom: false,
        child: switch (editor) {
          AsyncLoading<DesignEditorState>() => const _EditorSkeleton(),
          AsyncError(:final error) when editor.valueOrNull == null =>
            _EditorError(
              prefersEnglish: prefersEnglish,
              message: error.toString(),
              onRetry: () => ref.invalidate(designEditorViewModel),
            ),
          _ => LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final railPadding = tokens.spacing.md;
              final canvasPadding = EdgeInsets.symmetric(
                horizontal: tokens.spacing.lg,
                vertical: tokens.spacing.lg,
              );
              final state = editor.valueOrNull!;

              return Column(
                children: [
                  _AutoSaveBanner(state: state, prefersEnglish: prefersEnglish),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: railPadding),
                          child: _ToolRail(
                            prefersEnglish: prefersEnglish,
                            selectedIndex: _selectedTool,
                            onSelected: (index) {
                              setState(() => _selectedTool = index);
                              if (!isWide && index == 2) {
                                _openPropertySheet(context, state);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: canvasPadding,
                            physics: const BouncingScrollPhysics(),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1280,
                                ),
                                child: _CanvasAndDetails(
                                  state: state,
                                  prefersEnglish: prefersEnglish,
                                  onOpenSettings: !isWide
                                      ? () => _openPropertySheet(context, state)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isWide)
                          _PropertySheet(
                            state: state,
                            prefersEnglish: prefersEnglish,
                            width: 360,
                            onLayoutChanged: (layout) => ref.invoke(
                              designEditorViewModel.setLayout(layout),
                            ),
                            onStrokeChanged: (value) => ref.invoke(
                              designEditorViewModel.setStroke(value),
                            ),
                            onMarginChanged: (value) => ref.invoke(
                              designEditorViewModel.setMargin(value),
                            ),
                            onRotationChanged: (value) => ref.invoke(
                              designEditorViewModel.setRotation(value),
                            ),
                            onToggleGrid: (enabled) => ref.invoke(
                              designEditorViewModel.toggleGrid(enabled),
                            ),
                            onGridSpacingChanged: (value) => ref.invoke(
                              designEditorViewModel.setGridSpacing(value),
                            ),
                            onToggleGuides: (enabled) => ref.invoke(
                              designEditorViewModel.toggleGuides(enabled),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        },
      ),
    );
  }

  void _stopRenderTrace({String? status}) {
    if (_renderTraceRecorded) return;
    _renderTraceRecorded = true;
    _renderStopwatch.stop();
    final attributes = <String, String>{};
    if (status != null && status.isNotEmpty) {
      attributes['status'] = status;
    }
    unawaited(
      _renderTrace?.stop(
        metrics: {'render_ms': _renderStopwatch.elapsedMilliseconds},
        attributes: attributes.isEmpty ? null : attributes,
      ),
    );
  }

  Future<void> _openPropertySheet(
    BuildContext context,
    DesignEditorState? state,
  ) async {
    final tokens = DesignTokensTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radii.lg),
        ),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, sheetRef) {
            final sheetState =
                sheetRef.watch(designEditorViewModel).valueOrNull ?? state;
            if (sheetState == null) return const SizedBox.shrink();
            final prefersEnglish = sheetRef
                .watch(appExperienceGatesProvider)
                .prefersEnglish;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.lg,
                tokens.spacing.md,
                tokens.spacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + tokens.spacing.lg,
              ),
              child: _PropertySheet(
                state: sheetState,
                prefersEnglish: prefersEnglish,
                width: double.infinity,
                dense: true,
                onLayoutChanged: (layout) =>
                    sheetRef.invoke(designEditorViewModel.setLayout(layout)),
                onStrokeChanged: (value) =>
                    sheetRef.invoke(designEditorViewModel.setStroke(value)),
                onMarginChanged: (value) =>
                    sheetRef.invoke(designEditorViewModel.setMargin(value)),
                onRotationChanged: (value) =>
                    sheetRef.invoke(designEditorViewModel.setRotation(value)),
                onToggleGrid: (enabled) =>
                    sheetRef.invoke(designEditorViewModel.toggleGrid(enabled)),
                onGridSpacingChanged: (value) => sheetRef.invoke(
                  designEditorViewModel.setGridSpacing(value),
                ),
                onToggleGuides: (enabled) => sheetRef.invoke(
                  designEditorViewModel.toggleGuides(enabled),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditorAppBar({
    required this.state,
    required this.prefersEnglish,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onOpenSettings,
  });

  final DesignEditorState? state;
  final bool prefersEnglish;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final void Function(DesignEditorState?) onOpenSettings;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final subtitle = state?.templateName != null
        ? (prefersEnglish
              ? 'Template • ${state!.templateName}'
              : 'テンプレート • ${state!.templateName}')
        : (prefersEnglish ? 'Draft layout' : 'ドラフトレイアウト');
    final savedLabel = state?.lastSavedAt != null
        ? (prefersEnglish ? 'Saved' : '保存済み')
        : (prefersEnglish ? 'Not saved yet' : '未保存');

    return AppBar(
      toolbarHeight: 72,
      elevation: 0,
      backgroundColor: tokens.colors.surface,
      leading: const BackButton(),
      titleSpacing: tokens.spacing.md,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Design editor' : 'デザインエディタ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '$subtitle • $savedLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: prefersEnglish ? 'Undo' : '元に戻す',
          onPressed: state?.canUndo == true ? onUndo : null,
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          tooltip: prefersEnglish ? 'Redo' : 'やり直し',
          onPressed: state?.canRedo == true ? onRedo : null,
          icon: const Icon(Icons.redo_rounded),
        ),
        IconButton(
          tooltip: prefersEnglish ? 'Canvas settings' : 'キャンバス設定',
          onPressed: state != null ? () => onOpenSettings(state) : null,
          icon: const Icon(Icons.tune_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: prefersEnglish ? 'More' : 'その他',
          onSelected: (value) {
            if (value == 'reset') onReset();
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem<String>(
                value: 'reset',
                child: Text(prefersEnglish ? 'Reset to template' : 'テンプレートに戻す'),
              ),
            ];
          },
        ),
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({
    required this.prefersEnglish,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool prefersEnglish;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    final destinations = [
      _DestinationData(
        icon: Icons.pan_tool_alt_outlined,
        label: prefersEnglish ? 'Select' : '選択',
      ),
      _DestinationData(
        icon: Icons.edit_note_rounded,
        label: prefersEnglish ? 'Text' : 'テキスト',
      ),
      _DestinationData(
        icon: Icons.grid_view_rounded,
        label: prefersEnglish ? 'Layout' : 'レイアウト',
      ),
      _DestinationData(
        icon: Icons.outbox_outlined,
        label: prefersEnglish ? 'Export' : '出力',
      ),
    ];

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: !isCompact,
      labelType: isCompact
          ? NavigationRailLabelType.selected
          : NavigationRailLabelType.none,
      backgroundColor: tokens.colors.surface,
      destinations: destinations
          .map(
            (destination) => NavigationRailDestination(
              icon: Icon(destination.icon),
              label: Text(destination.label),
            ),
          )
          .toList(),
    );
  }
}

class _DestinationData {
  const _DestinationData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _CanvasAndDetails extends StatelessWidget {
  const _CanvasAndDetails({
    required this.state,
    required this.prefersEnglish,
    this.onOpenSettings,
  });

  final DesignEditorState state;
  final bool prefersEnglish;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final ink = tokens.colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(
              avatar: Icon(
                state.shape == SealShape.round
                    ? Icons.circle_outlined
                    : Icons.crop_square_rounded,
              ),
              label: Text('${state.sizeMm.toStringAsFixed(0)}mm'),
            ),
            SizedBox(width: tokens.spacing.sm),
            Chip(
              avatar: const Icon(Icons.text_fields_rounded),
              label: Text(switch (state.writingStyle) {
                WritingStyle.tensho => prefersEnglish ? 'Tensho' : '篆書',
                WritingStyle.reisho => prefersEnglish ? 'Reisho' : '隷書',
                WritingStyle.kaisho => prefersEnglish ? 'Kaisho' : '楷書',
                WritingStyle.gyosho => prefersEnglish ? 'Gyosho' : '行書',
                WritingStyle.koentai => prefersEnglish ? 'Koentai' : '古印体',
                WritingStyle.custom => prefersEnglish ? 'Custom' : 'カスタム',
              }),
            ),
            const Spacer(),
            if (onOpenSettings != null)
              TextButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.tune_rounded),
                label: Text(prefersEnglish ? 'Adjust' : '調整'),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.md),
        AppCard(
          padding: EdgeInsets.all(tokens.spacing.lg),
          backgroundColor: tokens.colors.surfaceVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CanvasHeader(state: state, prefersEnglish: prefersEnglish),
              SizedBox(height: tokens.spacing.md),
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _DesignCanvasPainter(
                    state: state,
                    ink: ink,
                    tokens: tokens,
                    prefersEnglish: prefersEnglish,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              _CanvasFootnote(state: state, prefersEnglish: prefersEnglish),
            ],
          ),
        ),
      ],
    );
  }
}

class _CanvasHeader extends StatelessWidget {
  const _CanvasHeader({required this.state, required this.prefersEnglish});

  final DesignEditorState state;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final marginLabel = prefersEnglish ? 'Margins' : '余白';
    final strokeLabel = prefersEnglish ? 'Stroke' : '線の太さ';
    final layoutLabel = switch (state.layout) {
      DesignCanvasLayout.balanced => prefersEnglish ? 'Balanced' : '均等配置',
      DesignCanvasLayout.vertical => prefersEnglish ? 'Vertical' : '縦書き配置',
      DesignCanvasLayout.grid => prefersEnglish ? 'Grid' : '格子',
      DesignCanvasLayout.arc => prefersEnglish ? 'Arc' : '円弧配置',
    };

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefersEnglish ? 'Live preview' : 'ライブプレビュー',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(
              prefersEnglish ? 'Layout: $layoutLabel' : '配置: $layoutLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        const Spacer(),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          alignment: WrapAlignment.end,
          children: [
            _BadgePill(
              label: '$strokeLabel ${state.strokeWeight.toStringAsFixed(1)}pt',
              icon: Icons.stacked_line_chart_rounded,
            ),
            _BadgePill(
              label: '$marginLabel ${state.margin.toStringAsFixed(0)}px',
              icon: Icons.space_bar_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        border: Border.all(
          color: tokens.colors.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          SizedBox(width: tokens.spacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CanvasFootnote extends StatelessWidget {
  const _CanvasFootnote({required this.state, required this.prefersEnglish});

  final DesignEditorState state;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final rotationLabel = '${state.rotation.toStringAsFixed(1)}°';
    final gridLabel = state.showGrid
        ? '${state.gridSpacing.toStringAsFixed(0)}px grid'
        : (prefersEnglish ? 'Grid hidden' : 'グリッド非表示');

    return Row(
      children: [
        Icon(
          Icons.rotate_90_degrees_ccw_rounded,
          size: 18,
          color: tokens.colors.onSurface.withValues(alpha: 0.7),
        ),
        SizedBox(width: tokens.spacing.xs),
        Text(
          prefersEnglish ? 'Rotation $rotationLabel' : '回転 $rotationLabel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Icon(
          Icons.grid_3x3_rounded,
          size: 18,
          color: tokens.colors.onSurface.withValues(alpha: 0.7),
        ),
        SizedBox(width: tokens.spacing.xs),
        Text(
          gridLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _AutoSaveBanner extends StatelessWidget {
  const _AutoSaveBanner({required this.state, required this.prefersEnglish});

  final DesignEditorState state;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final statusText = state.isSaving
        ? (prefersEnglish ? 'Saving...' : '保存中...')
        : state.lastSavedAt != null
        ? (prefersEnglish ? 'Saved just now' : '保存しました')
        : (prefersEnglish ? 'Auto-save ready' : '自動保存待機中');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: state.isSaving ? 48 : 40,
      width: double.infinity,
      color: state.isSaving
          ? tokens.colors.primary.withValues(alpha: 0.08)
          : tokens.colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.sm,
      ),
      child: Row(
        children: [
          if (state.isSaving)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(tokens.colors.primary),
              ),
            )
          else
            Icon(Icons.check_circle_rounded, color: tokens.colors.primary),
          SizedBox(width: tokens.spacing.sm),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const Spacer(),
          Text(
            state.hasPendingChanges
                ? (prefersEnglish ? 'Pending changes' : '未保存の変更あり')
                : (prefersEnglish ? 'All synced' : '同期済み'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertySheet extends StatelessWidget {
  const _PropertySheet({
    required this.state,
    required this.prefersEnglish,
    required this.onLayoutChanged,
    required this.onStrokeChanged,
    required this.onMarginChanged,
    required this.onRotationChanged,
    required this.onToggleGrid,
    required this.onGridSpacingChanged,
    required this.onToggleGuides,
    this.width,
    this.dense = false,
  });

  final DesignEditorState state;
  final bool prefersEnglish;
  final ValueChanged<DesignCanvasLayout> onLayoutChanged;
  final ValueChanged<double> onStrokeChanged;
  final ValueChanged<double> onMarginChanged;
  final ValueChanged<double> onRotationChanged;
  final ValueChanged<bool> onToggleGrid;
  final ValueChanged<double> onGridSpacingChanged;
  final ValueChanged<bool> onToggleGuides;
  final double? width;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final headerStyle = Theme.of(context).textTheme.titleMedium;
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: tokens.colors.onSurface.withValues(alpha: 0.8),
    );

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        border: Border(
          left: BorderSide(color: tokens.colors.outline.withValues(alpha: 0.2)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        dense ? tokens.spacing.sm : tokens.spacing.xl,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prefersEnglish ? 'Properties' : 'プロパティ', style: headerStyle),
            SizedBox(height: tokens.spacing.md),
            Text(
              prefersEnglish ? 'Layout alignment' : '配置の方向',
              style: labelStyle,
            ),
            SizedBox(height: tokens.spacing.sm),
            SegmentedButton<DesignCanvasLayout>(
              segments: [
                ButtonSegment(
                  value: DesignCanvasLayout.balanced,
                  icon: const Icon(Icons.blur_circular_rounded),
                  label: Text(prefersEnglish ? 'Balanced' : '均等'),
                ),
                ButtonSegment(
                  value: DesignCanvasLayout.vertical,
                  icon: const Icon(Icons.view_stream_rounded),
                  label: Text(prefersEnglish ? 'Vertical' : '縦'),
                ),
                ButtonSegment(
                  value: DesignCanvasLayout.grid,
                  icon: const Icon(Icons.grid_4x4_rounded),
                  label: Text(prefersEnglish ? 'Grid' : '格子'),
                ),
                ButtonSegment(
                  value: DesignCanvasLayout.arc,
                  icon: const Icon(Icons.rotate_left_rounded),
                  label: Text(prefersEnglish ? 'Arc' : '円弧'),
                ),
              ],
              selected: {state.layout},
              onSelectionChanged: (selection) {
                final value = selection.isNotEmpty
                    ? selection.first
                    : state.layout;
                onLayoutChanged(value);
              },
            ),
            SizedBox(height: tokens.spacing.lg),
            Text(prefersEnglish ? 'Stroke weight' : '線の太さ', style: labelStyle),
            Slider(
              value: state.strokeWeight,
              min: 1,
              max: 6,
              divisions: 10,
              label: '${state.strokeWeight.toStringAsFixed(1)} pt',
              onChanged: onStrokeChanged,
            ),
            SizedBox(height: tokens.spacing.md),
            Text(prefersEnglish ? 'Margins' : '余白', style: labelStyle),
            Slider(
              value: state.margin,
              min: 4,
              max: 28,
              divisions: 12,
              label: '${state.margin.toStringAsFixed(0)} px',
              onChanged: onMarginChanged,
            ),
            SizedBox(height: tokens.spacing.md),
            Text(prefersEnglish ? 'Rotation' : '回転', style: labelStyle),
            Slider(
              value: state.rotation,
              min: -22,
              max: 22,
              divisions: 22,
              label: '${state.rotation.toStringAsFixed(1)}°',
              onChanged: onRotationChanged,
            ),
            SizedBox(height: tokens.spacing.md),
            SwitchListTile(
              value: state.showGrid,
              contentPadding: EdgeInsets.zero,
              title: Text(prefersEnglish ? 'Grid overlay' : 'グリッドを表示'),
              subtitle: Text(
                prefersEnglish
                    ? 'Helps align strokes and margins'
                    : '線と余白の揃えに便利です',
              ),
              onChanged: onToggleGrid,
            ),
            if (state.showGrid) ...[
              Slider(
                value: state.gridSpacing,
                min: 4,
                max: 32,
                divisions: 14,
                label: '${state.gridSpacing.toStringAsFixed(0)} px',
                onChanged: onGridSpacingChanged,
              ),
            ],
            SwitchListTile(
              value: state.guidesEnabled,
              contentPadding: EdgeInsets.zero,
              title: Text(prefersEnglish ? 'Guide rings' : 'ガイドライン'),
              subtitle: Text(
                prefersEnglish
                    ? 'Shows margin and center guides'
                    : '余白と中心のガイドを表示',
              ),
              onChanged: onToggleGuides,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignCanvasPainter extends CustomPainter {
  _DesignCanvasPainter({
    required this.state,
    required this.ink,
    required this.tokens,
    required this.prefersEnglish,
  });

  final DesignEditorState state;
  final Color ink;
  final DesignTokens tokens;
  final bool prefersEnglish;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = tokens.colors.surface
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(tokens.radii.md),
      ),
      bgPaint,
    );

    final inset = state.margin + 8;
    final area = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final center = area.center;

    if (state.showGrid) {
      _drawGrid(canvas, size, spacing: state.gridSpacing);
    }
    if (state.guidesEnabled) {
      _drawGuides(canvas, center, area);
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(state.rotation * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    _drawShape(canvas, center, area);
    _drawName(canvas, center, area);

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size, {required double spacing}) {
    final gridPaint = Paint()
      ..color = tokens.colors.outline.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawGuides(Canvas canvas, Offset center, Rect area) {
    final guidePaint = Paint()
      ..color = tokens.colors.primary.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, area.top),
      Offset(center.dx, area.bottom),
      guidePaint,
    );
    canvas.drawLine(
      Offset(area.left, center.dy),
      Offset(area.right, center.dy),
      guidePaint,
    );
    final radius = math.min(area.width, area.height) / 2;
    canvas.drawCircle(
      center,
      radius,
      guidePaint..color = guidePaint.color.withValues(alpha: 0.18),
    );
  }

  void _drawShape(Canvas canvas, Offset center, Rect area) {
    final radius = math.min(area.width, area.height) / 2;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.strokeWeight
      ..strokeJoin = StrokeJoin.round;

    switch (state.shape) {
      case SealShape.round:
        canvas.drawCircle(center, radius, stroke);
      case SealShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: area.shortestSide,
              height: area.shortestSide,
            ),
            Radius.circular(tokens.radii.sm),
          ),
          stroke,
        );
    }
  }

  void _drawName(Canvas canvas, Offset center, Rect area) {
    final characters = state.displayName.characters.toList();
    final inkPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;
    final textStyle = TextStyle(
      color: inkPaint.color,
      fontWeight: _weightForStyle(state.writingStyle),
      letterSpacing: state.layout == DesignCanvasLayout.grid ? 1 : 0,
      fontSize: area.shortestSide * 0.12,
      height: state.layout == DesignCanvasLayout.vertical ? 1.15 : 1.0,
    );

    switch (state.layout) {
      case DesignCanvasLayout.balanced:
        _drawCentered(canvas, center, area, textStyle, characters.join(''));
      case DesignCanvasLayout.vertical:
        _drawVertical(canvas, center, area, textStyle, characters);
      case DesignCanvasLayout.grid:
        _drawGridLayout(canvas, center, area, textStyle, characters);
      case DesignCanvasLayout.arc:
        _drawArc(canvas, center, area, textStyle, characters);
    }
  }

  void _drawCentered(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    String text,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: area.width * 0.75);
    final offset = Offset(
      center.dx - painter.width / 2,
      center.dy - painter.height / 2,
    );
    painter.paint(canvas, offset);
  }

  void _drawVertical(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    List<String> chars,
  ) {
    final spacing = area.height / (chars.length + 1);
    for (int i = 0; i < chars.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx - painter.width / 2,
        area.top + spacing * (i + 0.8),
      );
      painter.paint(canvas, offset);
    }
  }

  void _drawGridLayout(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    List<String> chars,
  ) {
    final columns = 2;
    final rows = (chars.length / columns).ceil();
    final cellWidth = area.width / columns;
    final cellHeight = area.height / rows;
    for (int i = 0; i < chars.length; i++) {
      final col = i % columns;
      final row = (i / columns).floor();
      final painter = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cellWidth);
      final dx = area.left + cellWidth * col + (cellWidth - painter.width) / 2;
      final dy =
          area.top + cellHeight * row + (cellHeight - painter.height) / 2;
      painter.paint(canvas, Offset(dx, dy));
    }
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    Rect area,
    TextStyle style,
    List<String> chars,
  ) {
    final radius = math.min(area.width, area.height) / 2.4;
    final sweep = math.pi * 1.3;
    final startAngle = -sweep / 2;
    for (int i = 0; i < chars.length; i++) {
      final angle = startAngle + sweep * (i / math.max(chars.length - 1, 1));
      final offset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle + math.pi / 2);
      final painter = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  FontWeight _weightForStyle(WritingStyle style) {
    return switch (style) {
      WritingStyle.tensho => FontWeight.w600,
      WritingStyle.reisho => FontWeight.w500,
      WritingStyle.kaisho => FontWeight.w700,
      WritingStyle.gyosho => FontWeight.w500,
      WritingStyle.koentai => FontWeight.w800,
      WritingStyle.custom => FontWeight.w600,
    };
  }

  @override
  bool shouldRepaint(covariant _DesignCanvasPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.ink != ink ||
        oldDelegate.prefersEnglish != prefersEnglish;
  }
}

class _PreviewFab extends StatelessWidget {
  const _PreviewFab({required this.prefersEnglish, required this.onPressed});

  final bool prefersEnglish;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        icon: const Icon(Icons.visibility_rounded),
        label: Text(prefersEnglish ? 'Preview / Export' : 'プレビュー・出力へ'),
      ),
    );
  }
}

class _EditorSkeleton extends StatelessWidget {
  const _EditorSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: const AppListSkeleton(items: 2, itemHeight: 260),
    );
  }
}

class _EditorError extends StatelessWidget {
  const _EditorError({
    required this.prefersEnglish,
    required this.message,
    required this.onRetry,
  });

  final bool prefersEnglish;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: AppEmptyState(
        title: prefersEnglish ? 'Could not load editor' : 'エディタを読み込めません',
        message: message,
        actionLabel: prefersEnglish ? 'Retry' : '再試行',
        onAction: onRetry,
      ),
    );
  }
}
