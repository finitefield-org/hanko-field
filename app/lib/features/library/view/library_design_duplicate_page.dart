// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/features/library/view_model/library_design_duplicate_view_model.dart';
import 'package:app/features/library/view_model/library_list_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LibraryDesignDuplicatePage extends ConsumerStatefulWidget {
  const LibraryDesignDuplicatePage({super.key, required this.designId});

  final String designId;

  @override
  ConsumerState<LibraryDesignDuplicatePage> createState() =>
      _LibraryDesignDuplicatePageState();
}

class _LibraryDesignDuplicatePageState
    extends ConsumerState<LibraryDesignDuplicatePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tagsCtrl;
  late final FocusNode _tagsFocus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _tagsCtrl = TextEditingController();
    _tagsFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagsCtrl.dispose();
    _tagsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final viewModel = LibraryDesignDuplicateViewModel(
      designId: widget.designId,
    );
    final state = ref.watch(viewModel);

    final title = prefersEnglish ? 'Duplicate' : '複製';

    final formState = state.valueOrNull;
    if (formState != null) {
      final tagsText = formState.tags.join(', ');
      if (_nameCtrl.text != formState.name || _tagsCtrl.text != tagsText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_nameCtrl.text != formState.name) {
            _nameCtrl.value = _nameCtrl.value.copyWith(
              text: formState.name,
              selection: TextSelection.collapsed(offset: formState.name.length),
              composing: TextRange.empty,
            );
          }
          if (!_tagsFocus.hasFocus && _tagsCtrl.text != tagsText) {
            _tagsCtrl.value = _tagsCtrl.value.copyWith(
              text: tagsText,
              selection: TextSelection.collapsed(offset: tagsText.length),
              composing: TextRange.empty,
            );
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        title: switch (state) {
          AsyncData(:final value) => _AppBarTitle(
            title: title,
            subtitle: _sourceLabel(
              value.source,
              prefersEnglish: prefersEnglish,
            ),
          ),
          _ => Text(title),
        },
      ),
      body: switch (state) {
        AsyncLoading<LibraryDesignDuplicateState>() => Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const CircularProgressIndicator.adaptive(),
          ),
        ),
        AsyncError(:final error) when state.valueOrNull == null => _ErrorBody(
          message: error.toString(),
          prefersEnglish: prefersEnglish,
          onRetry: () => ref.invalidate(viewModel),
        ),
        _ => _FormBody(
          state: state.valueOrNull!,
          prefersEnglish: prefersEnglish,
          nameController: _nameCtrl,
          tagsController: _tagsCtrl,
          tagsFocus: _tagsFocus,
          onNameChanged: (value) => ref.invoke(viewModel.setName(value)),
          onTagsChanged: (value) =>
              ref.invoke(viewModel.setTags(_parseTags(value))),
          onRemoveTag: (tag) => ref.invoke(
            viewModel.setTags(
              state.valueOrNull!.tags.where((value) => value != tag),
            ),
          ),
          onSuggestion: (tag) =>
              ref.invoke(viewModel.setTags({...state.valueOrNull!.tags, tag})),
          onToggleCopyHistory: (enabled) =>
              ref.invoke(viewModel.toggleCopyHistory(enabled)),
          onToggleCopyAssets: (enabled) =>
              ref.invoke(viewModel.toggleCopyAssets(enabled)),
          onSubmit: () => _submit(viewModel),
          onCancel: () => context.pop(),
        ),
      },
    );
  }

  Future<void> _submit(LibraryDesignDuplicateViewModel viewModel) async {
    final navigation = context.navigation;
    final messenger = ScaffoldMessenger.of(context);
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;

    try {
      final duplicated = await ref.invoke(viewModel.submit());
      unawaited(ref.invoke(libraryListViewModel.refresh()));

      if (!await _hydrateCreationFromDesign(duplicated)) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(prefersEnglish ? 'Duplicated' : '複製しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await navigation.go(AppRoutePaths.designEditor);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _hydrateCreationFromDesign(Design design) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;

    try {
      await ref.container.read(designCreationViewModel.future);
      await ref.invoke(designCreationViewModel.hydrateFromDesign(design));
      ref.invalidate(designEditorViewModel);
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish
                ? 'Failed to prepare editor: $e'
                : '編集の準備に失敗しました: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        SizedBox(height: tokens.spacing.xs),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: tokens.colors.onSurface.withAlpha(178),
          ),
        ),
      ],
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.state,
    required this.prefersEnglish,
    required this.nameController,
    required this.tagsController,
    required this.tagsFocus,
    required this.onNameChanged,
    required this.onTagsChanged,
    required this.onRemoveTag,
    required this.onSuggestion,
    required this.onToggleCopyHistory,
    required this.onToggleCopyAssets,
    required this.onSubmit,
    required this.onCancel,
  });

  final LibraryDesignDuplicateState state;
  final bool prefersEnglish;
  final TextEditingController nameController;
  final TextEditingController tagsController;
  final FocusNode tagsFocus;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onRemoveTag;
  final ValueChanged<String> onSuggestion;
  final ValueChanged<bool> onToggleCopyHistory;
  final ValueChanged<bool> onToggleCopyAssets;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.xl,
        ),
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: prefersEnglish ? 'New name' : '新しい名前',
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: onNameChanged,
          ),
          SizedBox(height: tokens.spacing.lg),
          TextField(
            controller: tagsController,
            focusNode: tagsFocus,
            decoration: InputDecoration(
              labelText: prefersEnglish ? 'Tags' : 'タグ',
              helperText: prefersEnglish
                  ? 'Comma-separated (e.g., family, square)'
                  : 'カンマ区切り（例: family, square）',
              border: const OutlineInputBorder(),
            ),
            onChanged: onTagsChanged,
          ),
          if (state.tags.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.md),
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.sm,
              children: [
                for (final tag in state.tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: state.isSubmitting
                        ? null
                        : () => onRemoveTag(tag),
                  ),
              ],
            ),
          ],
          if (state.suggestions.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.md),
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.sm,
              children: [
                for (final tag in state.suggestions)
                  ActionChip(
                    label: Text(tag),
                    onPressed: state.isSubmitting
                        ? null
                        : () => onSuggestion(tag),
                  ),
              ],
            ),
          ],
          SizedBox(height: tokens.spacing.xl),
          Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: state.copyHistory,
                    onChanged: state.isSubmitting
                        ? null
                        : (v) => onToggleCopyHistory(v),
                    title: Text(prefersEnglish ? 'Copy history' : '履歴を含める'),
                  ),
                  SwitchListTile.adaptive(
                    value: state.copyAssets,
                    onChanged: state.isSubmitting
                        ? null
                        : (v) => onToggleCopyAssets(v),
                    title: Text(prefersEnglish ? 'Copy assets' : 'アセットを含める'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.xl),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: state.isSubmitting ? null : onSubmit,
                  child: state.isSubmitting
                      ? SizedBox(
                          width: tokens.spacing.md,
                          height: tokens.spacing.md,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(
                              tokens.colors.onPrimary,
                            ),
                          ),
                        )
                      : Text(prefersEnglish ? 'Duplicate' : '複製する'),
                ),
              ),
              SizedBox(width: tokens.spacing.md),
              TextButton(
                onPressed: state.isSubmitting ? null : onCancel,
                child: Text(prefersEnglish ? 'Cancel' : 'キャンセル'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.prefersEnglish,
    required this.onRetry,
  });

  final String message;
  final bool prefersEnglish;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prefersEnglish ? 'Failed to load design' : 'デザインの読み込みに失敗しました',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.md),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(prefersEnglish ? 'Retry' : '再試行'),
            ),
          ],
        ),
      ),
    );
  }
}

String _sourceLabel(Design design, {required bool prefersEnglish}) {
  final name = design.input?.rawName.trim();
  final resolved = (name == null || name.isEmpty)
      ? (prefersEnglish ? 'Untitled' : '無題')
      : name;
  return prefersEnglish ? 'From: $resolved' : '元: $resolved';
}

Set<String> _parseTags(String raw) {
  return raw
      .split(RegExp(r'[,\n ]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .map((value) => value.startsWith('#') ? value.substring(1) : value)
      .toSet();
}
