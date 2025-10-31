import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/design_editor_controller.dart';
import 'package:app/features/design_creation/application/design_editor_state.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/features/design_creation/presentation/widgets/design_canvas_preview.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _EditorMenuAction { reset }

class DesignEditorPage extends ConsumerStatefulWidget {
  const DesignEditorPage({super.key});

  @override
  ConsumerState<DesignEditorPage> createState() => _DesignEditorPageState();
}

class _DesignEditorPageState extends ConsumerState<DesignEditorPage> {
  int _selectedToolIndex = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editorState = ref.watch(designEditorControllerProvider);
    final editorNotifier = ref.read(designEditorControllerProvider.notifier);
    final creationState = ref.watch(designCreationControllerProvider);
    final designText =
        creationState.pendingInput?.kanji?.value ??
        creationState.pendingInput?.rawName ??
        creationState.nameDraft?.combined ??
        l10n.designEditorFallbackText;
    final shape = creationState.selectedShape ?? DesignShape.round;

    return Scaffold(
      appBar: _buildAppBar(context, l10n, editorState, editorNotifier),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final content = Padding(
              padding: const EdgeInsets.only(
                top: AppTokens.spaceL,
                left: AppTokens.spaceL,
                right: AppTokens.spaceL,
              ),
              child: isWide
                  ? _WideEditorLayout(
                      selectedToolIndex: _selectedToolIndex,
                      onToolSelected: _handleToolSelection,
                      editorState: editorState,
                      editorNotifier: editorNotifier,
                      designText: designText,
                      shape: shape,
                      creationState: creationState,
                      l10n: l10n,
                    )
                  : _CompactEditorLayout(
                      selectedToolIndex: _selectedToolIndex,
                      onToolSelected: _handleToolSelection,
                      editorState: editorState,
                      editorNotifier: editorNotifier,
                      designText: designText,
                      shape: shape,
                      creationState: creationState,
                      l10n: l10n,
                      maxHeight: constraints.maxHeight,
                    ),
            );
            return content;
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
        child: FloatingActionButton.extended(
          icon: const Icon(Icons.visibility_outlined),
          label: Text(l10n.designEditorPrimaryCta),
          onPressed: () => _handlePreview(context, l10n),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    DesignEditorState state,
    DesignEditorController notifier,
  ) {
    return AppBar(
      title: Text(l10n.designEditorTitle),
      actions: [
        IconButton(
          tooltip: l10n.designEditorUndoTooltip,
          icon: const Icon(Icons.undo),
          onPressed: state.canUndo ? notifier.undo : null,
        ),
        IconButton(
          tooltip: l10n.designEditorRedoTooltip,
          icon: const Icon(Icons.redo),
          onPressed: state.canRedo ? notifier.redo : null,
        ),
        PopupMenuButton<_EditorMenuAction>(
          tooltip: l10n.designEditorMoreActionsTooltip,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _EditorMenuAction.reset,
              child: Text(l10n.designEditorResetMenu),
            ),
          ],
          onSelected: (action) {
            if (action == _EditorMenuAction.reset) {
              notifier.resetToBaseline();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.designEditorResetSnackbar)),
              );
            }
          },
        ),
      ],
    );
  }

  void _handleToolSelection(int index) {
    setState(() {
      _selectedToolIndex = index;
    });
  }

  void _handlePreview(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.designEditorPreviewPlaceholder)),
      );
  }
}

class _WideEditorLayout extends StatelessWidget {
  const _WideEditorLayout({
    required this.selectedToolIndex,
    required this.onToolSelected,
    required this.editorState,
    required this.editorNotifier,
    required this.designText,
    required this.shape,
    required this.creationState,
    required this.l10n,
  });

  final int selectedToolIndex;
  final ValueChanged<int> onToolSelected;
  final DesignEditorState editorState;
  final DesignEditorController editorNotifier;
  final String designText;
  final DesignShape shape;
  final DesignCreationState creationState;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToolRail(
          selectedIndex: selectedToolIndex,
          onSelected: onToolSelected,
          l10n: l10n,
          extended: true,
        ),
        const SizedBox(width: AppTokens.spaceL),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _CanvasSection(
                  editorState: editorState,
                  designText: designText,
                  shape: shape,
                  templateTitle: creationState.selectedTemplateTitle,
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: AppTokens.spaceL),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: _PropertySheet(
                  state: editorState,
                  notifier: editorNotifier,
                  l10n: l10n,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactEditorLayout extends StatelessWidget {
  const _CompactEditorLayout({
    required this.selectedToolIndex,
    required this.onToolSelected,
    required this.editorState,
    required this.editorNotifier,
    required this.designText,
    required this.shape,
    required this.creationState,
    required this.l10n,
    required this.maxHeight,
  });

  final int selectedToolIndex;
  final ValueChanged<int> onToolSelected;
  final DesignEditorState editorState;
  final DesignEditorController editorNotifier;
  final String designText;
  final DesignShape shape;
  final DesignCreationState creationState;
  final AppLocalizations l10n;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToolRail(
          selectedIndex: selectedToolIndex,
          onSelected: onToolSelected,
          l10n: l10n,
          extended: false,
        ),
        const SizedBox(width: AppTokens.spaceL),
        Expanded(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              children: [
                Expanded(
                  child: _CanvasSection(
                    editorState: editorState,
                    designText: designText,
                    shape: shape,
                    templateTitle: creationState.selectedTemplateTitle,
                    l10n: l10n,
                    compact: true,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceL),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: AppTokens.spaceXL),
                    child: _PropertySheet(
                      state: editorState,
                      notifier: editorNotifier,
                      l10n: l10n,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.l10n,
    required this.extended,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AppLocalizations l10n;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: extended,
      labelType: extended
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.none,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceM),
        child: Icon(
          Icons.construction_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.select_all_outlined),
          selectedIcon: const Icon(Icons.select_all),
          label: Text(l10n.designEditorToolSelect),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.title_outlined),
          selectedIcon: const Icon(Icons.title),
          label: Text(l10n.designEditorToolText),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.tune_outlined),
          selectedIcon: const Icon(Icons.tune),
          label: Text(l10n.designEditorToolLayout),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.ios_share_outlined),
          selectedIcon: const Icon(Icons.ios_share),
          label: Text(l10n.designEditorToolExport),
        ),
      ],
    );
  }
}

class _CanvasSection extends StatelessWidget {
  const _CanvasSection({
    required this.editorState,
    required this.designText,
    required this.shape,
    required this.templateTitle,
    required this.l10n,
    this.compact = false,
  });

  final DesignEditorState editorState;
  final String designText;
  final DesignShape shape;
  final String? templateTitle;
  final AppLocalizations l10n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = templateTitle?.isNotEmpty == true
        ? templateTitle!
        : l10n.designEditorCanvasUntitled;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? AppTokens.spaceL : AppTokens.spaceXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.designEditorCanvasTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppTokens.spaceL),
            Expanded(
              child: DesignCanvasPreview(
                config: editorState.config,
                shape: shape,
                primaryText: designText,
              ),
            ),
            const SizedBox(height: AppTokens.spaceL),
            _AutosaveIndicator(state: editorState, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _AutosaveIndicator extends StatelessWidget {
  const _AutosaveIndicator({required this.state, required this.l10n});

  final DesignEditorState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = state.isAutosaving
        ? l10n.designEditorAutosaveInProgress
        : state.lastSavedAt == null
        ? l10n.designEditorAutosaveIdle
        : l10n.designEditorAutosaveCompleted(
            TimeOfDay.fromDateTime(state.lastSavedAt!).format(context),
          );
    return Row(
      children: [
        if (state.isAutosaving)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 18),
        const SizedBox(width: AppTokens.spaceS),
        Text(statusText, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _PropertySheet extends StatelessWidget {
  const _PropertySheet({
    required this.state,
    required this.notifier,
    required this.l10n,
  });

  final DesignEditorState state;
  final DesignEditorController notifier;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.designEditorPropertiesHeading,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceL),
            _AlignmentControl(state: state, notifier: notifier, l10n: l10n),
            const SizedBox(height: AppTokens.spaceL),
            _SliderControl(
              label: l10n.designEditorStrokeLabel,
              valueLabel: l10n.designEditorStrokeValue(
                state.config.strokeWidth.toStringAsFixed(1),
              ),
              value: state.config.strokeWidth,
              min: 1,
              max: 10,
              divisions: 18,
              onChanged: notifier.updateStrokeWidth,
            ),
            const SizedBox(height: AppTokens.spaceL),
            _SliderControl(
              label: l10n.designEditorMarginLabel,
              valueLabel: l10n.designEditorMarginValue(
                state.config.margin.toStringAsFixed(1),
              ),
              value: state.config.margin,
              min: 0,
              max: 20,
              divisions: 20,
              onChanged: notifier.updateMargin,
            ),
            const SizedBox(height: AppTokens.spaceL),
            _SliderControl(
              label: l10n.designEditorRotationLabel,
              valueLabel: l10n.designEditorRotationValue(
                state.config.rotation.toStringAsFixed(0),
              ),
              value: state.config.rotation,
              min: 0,
              max: 360,
              divisions: 36,
              onChanged: notifier.updateRotation,
            ),
            const SizedBox(height: AppTokens.spaceL),
            Text(l10n.designEditorGridLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppTokens.spaceS),
            SegmentedButton<DesignGridType>(
              segments: [
                ButtonSegment(
                  value: DesignGridType.none,
                  label: Text(l10n.designEditorGridNone),
                  icon: const Icon(Icons.grid_off),
                ),
                ButtonSegment(
                  value: DesignGridType.square,
                  label: Text(l10n.designEditorGridSquare),
                  icon: const Icon(Icons.grid_view),
                ),
                ButtonSegment(
                  value: DesignGridType.radial,
                  label: Text(l10n.designEditorGridRadial),
                  icon: const Icon(Icons.blur_circular),
                ),
              ],
              selected: {state.config.grid},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  notifier.setGrid(selection.first);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AlignmentControl extends StatelessWidget {
  const _AlignmentControl({
    required this.state,
    required this.notifier,
    required this.l10n,
  });

  final DesignEditorState state;
  final DesignEditorController notifier;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.designEditorAlignmentLabel,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppTokens.spaceS),
        SegmentedButton<DesignCanvasAlignment>(
          segments: [
            ButtonSegment(
              value: DesignCanvasAlignment.center,
              icon: const Icon(Icons.radio_button_checked),
              label: Text(l10n.designEditorAlignCenter),
            ),
            ButtonSegment(
              value: DesignCanvasAlignment.top,
              icon: const Icon(Icons.north),
              label: Text(l10n.designEditorAlignTop),
            ),
            ButtonSegment(
              value: DesignCanvasAlignment.bottom,
              icon: const Icon(Icons.south),
              label: Text(l10n.designEditorAlignBottom),
            ),
            ButtonSegment(
              value: DesignCanvasAlignment.left,
              icon: const Icon(Icons.west),
              label: Text(l10n.designEditorAlignLeft),
            ),
            ButtonSegment(
              value: DesignCanvasAlignment.right,
              icon: const Icon(Icons.east),
              label: Text(l10n.designEditorAlignRight),
            ),
          ],
          selected: {state.config.alignment},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              notifier.updateAlignment(selection.first);
            }
          },
        ),
      ],
    );
  }
}

class _SliderControl extends StatelessWidget {
  const _SliderControl({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            Text(valueLabel, style: theme.textTheme.bodySmall),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
