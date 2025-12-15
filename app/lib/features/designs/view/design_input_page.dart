// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignInputPage extends ConsumerStatefulWidget {
  const DesignInputPage({super.key, this.sourceType});

  final DesignSourceType? sourceType;

  @override
  ConsumerState<DesignInputPage> createState() => _DesignInputPageState();
}

class _DesignInputPageState extends ConsumerState<DesignInputPage> {
  late final TextEditingController _surnameKanjiCtrl;
  late final TextEditingController _givenKanjiCtrl;
  late final TextEditingController _surnameKanaCtrl;
  late final TextEditingController _givenKanaCtrl;

  @override
  void initState() {
    super.initState();
    final draft =
        ref.container.read(designCreationViewModel).valueOrNull?.nameDraft ??
        const NameInputDraft();
    _surnameKanjiCtrl = TextEditingController(text: draft.surnameKanji);
    _givenKanjiCtrl = TextEditingController(text: draft.givenKanji);
    _surnameKanaCtrl = TextEditingController(text: draft.surnameKana);
    _givenKanaCtrl = TextEditingController(text: draft.givenKana);

    if (widget.sourceType != null) {
      scheduleMicrotask(
        () =>
            ref.invoke(designCreationViewModel.selectType(widget.sourceType!)),
      );
    }
  }

  @override
  void dispose() {
    _surnameKanjiCtrl.dispose();
    _givenKanjiCtrl.dispose();
    _surnameKanaCtrl.dispose();
    _givenKanaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(designCreationViewModel);
    final saveState = ref.watch(designCreationViewModel.saveInputMut);
    final isSaving = saveState is PendingMutationState;
    final draft = state.valueOrNull?.nameDraft ?? const NameInputDraft();
    _syncControllers(draft);
    final validation = validateNameDraft(draft, gates);
    final previewStyle = state.valueOrNull?.previewStyle ?? WritingStyle.tensho;
    final session = ref.watch(userSessionProvider).valueOrNull;
    final profileSuggestion = _profileSuggestion(session?.profile, draft);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppTopBar(
        title: prefersEnglish ? 'Enter name' : '名前の入力',
        showBack: true,
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Open kanji helper' : '漢字候補を開く',
            icon: const Icon(Icons.maps_ugc_outlined),
            onPressed: () => _openKanjiMap(context),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncLoading<DesignCreationState>() => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const AppListSkeleton(items: 3, itemHeight: 140),
          ),
          AsyncError(:final error) when state.valueOrNull == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: AppEmptyState(
              title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
              message: error.toString(),
              actionLabel: prefersEnglish ? 'Retry' : '再試行',
              onAction: () => ref.invalidate(designCreationViewModel),
            ),
          ),
          _ => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.lg,
              tokens.spacing.lg,
              tokens.spacing.xxl * 2,
            ),
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prefersEnglish
                          ? 'Use your official spelling for engraving. We validate scripts and show a live preview.'
                          : '刻印に使う氏名を入力してください。全角チェックとプレビューで仕上がりを確認できます。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    SizedBox(height: tokens.spacing.lg),
                    _NameFieldsCard(
                      surnameController: _surnameKanjiCtrl,
                      givenController: _givenKanjiCtrl,
                      surnameKanaController: _surnameKanaCtrl,
                      givenKanaController: _givenKanaCtrl,
                      currentDraft: draft,
                      validation: validation,
                      prefersEnglish: prefersEnglish,
                      onChanged: _handleFieldChanged,
                      onOpenDictionary: (field, value) =>
                          _openKanjiDictionary(field, value),
                      onApplySuggestion: (next) => ref.invoke(
                        designCreationViewModel.applyNameSuggestion(next),
                      ),
                      surnameTemplates: _surnameTemplates(prefersEnglish),
                      givenTemplates: _givenTemplates(prefersEnglish),
                      profileSuggestion: profileSuggestion,
                    ),
                    SizedBox(height: tokens.spacing.lg),
                    _KanjiMappingCard(
                      prefersEnglish: prefersEnglish,
                      onOpen: () => _openKanjiMap(context),
                      showAssist: gates.enableKanjiAssist,
                      mapping: draft.kanjiMapping,
                    ),
                    SizedBox(height: tokens.spacing.lg),
                    _PreviewCard(
                      draft: draft,
                      validation: validation,
                      prefersEnglish: prefersEnglish,
                      style: previewStyle,
                      onStyleChanged: (style) => ref.invoke(
                        designCreationViewModel.setPreviewStyle(style),
                      ),
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.all(tokens.spacing.lg),
        child: FilledButton.icon(
          onPressed: validation.isValid && !isSaving
              ? () => _saveAndContinue()
              : null,
          icon: isSaving
              ? SizedBox(
                  width: tokens.spacing.md,
                  height: tokens.spacing.md,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(tokens.colors.onPrimary),
                  ),
                )
              : const Icon(Icons.arrow_forward_rounded),
          label: Text(prefersEnglish ? 'Continue to styles' : '書体選択に進む'),
        ),
      ),
    );
  }

  void _syncControllers(NameInputDraft draft) {
    _syncController(_surnameKanjiCtrl, draft.surnameKanji);
    _syncController(_givenKanjiCtrl, draft.givenKanji);
    _syncController(_surnameKanaCtrl, draft.surnameKana);
    _syncController(_givenKanaCtrl, draft.givenKana);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _handleFieldChanged(NameField field, String value) {
    ref.invoke(designCreationViewModel.updateNameField(field, value));
  }

  Future<void> _saveAndContinue() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.container.read(designCreationViewModel).valueOrNull;
    if (state == null) return;

    try {
      final input = await ref.invoke(designCreationViewModel.saveNameInput());
      final filters = state.activeFilters;
      final filterQuery = filters.isEmpty
          ? ''
          : '&filters=${filters.join(',')}';
      router.go(
        '${AppRoutePaths.designStyle}?mode=${input.sourceType.toJson()}$filterQuery',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openKanjiMap(BuildContext context) {
    context.push(AppRoutePaths.designKanjiMap);
  }

  void _openKanjiDictionary(NameField field, String query) {
    final qp = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'insertField': field.name,
      'returnTo': AppRoutePaths.designInput,
    };
    final uri = Uri(path: AppRoutePaths.kanjiDictionary, queryParameters: qp);
    context.push(uri.toString());
  }
}

class _NameFieldsCard extends StatelessWidget {
  const _NameFieldsCard({
    required this.surnameController,
    required this.givenController,
    required this.surnameKanaController,
    required this.givenKanaController,
    required this.currentDraft,
    required this.validation,
    required this.prefersEnglish,
    required this.onChanged,
    required this.onOpenDictionary,
    required this.onApplySuggestion,
    required this.surnameTemplates,
    required this.givenTemplates,
    this.profileSuggestion,
  });

  final TextEditingController surnameController;
  final TextEditingController givenController;
  final TextEditingController surnameKanaController;
  final TextEditingController givenKanaController;
  final NameInputDraft currentDraft;
  final NameValidationResult validation;
  final bool prefersEnglish;
  final void Function(NameField, String) onChanged;
  final void Function(NameField field, String currentValue) onOpenDictionary;
  final ValueChanged<NameInputDraft> onApplySuggestion;
  final List<_NameTemplate> surnameTemplates;
  final List<_NameTemplate> givenTemplates;
  final NameInputDraft? profileSuggestion;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final labelStyle = Theme.of(context).textTheme.titleSmall;
    final helperColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.75);
    final suggestion = profileSuggestion;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Name (kanji/latin)' : '漢字/英字',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          ResponsiveLayout(
            compact: (_) => Column(
              children: [
                AppTextField(
                  label: prefersEnglish ? 'Surname' : '姓',
                  controller: surnameController,
                  hintText: prefersEnglish ? 'e.g., 山田 / Smith' : '例: 山田',
                  errorText: validation.surnameError,
                  suffix: IconButton(
                    tooltip: prefersEnglish ? 'Kanji dictionary' : '漢字辞典',
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: () => onOpenDictionary(
                      NameField.surnameKanji,
                      surnameController.text,
                    ),
                  ),
                  onChanged: (value) =>
                      onChanged(NameField.surnameKanji, value),
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Given name' : '名',
                  controller: givenController,
                  hintText: prefersEnglish ? 'e.g., 太郎 / Ken' : '例: 太郎',
                  errorText: validation.givenError,
                  suffix: IconButton(
                    tooltip: prefersEnglish ? 'Kanji dictionary' : '漢字辞典',
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: () => onOpenDictionary(
                      NameField.givenKanji,
                      givenController.text,
                    ),
                  ),
                  onChanged: (value) => onChanged(NameField.givenKanji, value),
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            medium: (_) => Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: prefersEnglish ? 'Surname' : '姓',
                    controller: surnameController,
                    hintText: prefersEnglish ? 'e.g., 山田 / Smith' : '例: 山田',
                    errorText: validation.surnameError,
                    suffix: IconButton(
                      tooltip: prefersEnglish ? 'Kanji dictionary' : '漢字辞典',
                      icon: const Icon(Icons.menu_book_outlined),
                      onPressed: () => onOpenDictionary(
                        NameField.surnameKanji,
                        surnameController.text,
                      ),
                    ),
                    onChanged: (value) =>
                        onChanged(NameField.surnameKanji, value),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: AppTextField(
                    label: prefersEnglish ? 'Given name' : '名',
                    controller: givenController,
                    hintText: prefersEnglish ? 'e.g., 太郎 / Ken' : '例: 太郎',
                    errorText: validation.givenError,
                    suffix: IconButton(
                      tooltip: prefersEnglish ? 'Kanji dictionary' : '漢字辞典',
                      icon: const Icon(Icons.menu_book_outlined),
                      onPressed: () => onOpenDictionary(
                        NameField.givenKanji,
                        givenController.text,
                      ),
                    ),
                    onChanged: (value) =>
                        onChanged(NameField.givenKanji, value),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Text(
            prefersEnglish
                ? 'Kana (full-width) for engraving accuracy'
                : 'フリガナ (全角)',
            style: labelStyle,
          ),
          SizedBox(height: tokens.spacing.xs),
          ResponsiveLayout(
            compact: (_) => Column(
              children: [
                AppTextField(
                  label: prefersEnglish ? 'Surname kana' : 'セイ',
                  controller: surnameKanaController,
                  hintText: prefersEnglish ? 'ヤマダ' : 'ヤマダ',
                  errorText: validation.surnameKanaError,
                  onChanged: (value) => onChanged(NameField.surnameKana, value),
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Given kana' : 'メイ',
                  controller: givenKanaController,
                  hintText: prefersEnglish ? 'タロウ' : 'タロウ',
                  errorText: validation.givenKanaError,
                  onChanged: (value) => onChanged(NameField.givenKana, value),
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            medium: (_) => Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: prefersEnglish ? 'Surname kana' : 'セイ',
                    controller: surnameKanaController,
                    hintText: prefersEnglish ? 'ヤマダ' : 'ヤマダ',
                    errorText: validation.surnameKanaError,
                    onChanged: (value) =>
                        onChanged(NameField.surnameKana, value),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: AppTextField(
                    label: prefersEnglish ? 'Given kana' : 'メイ',
                    controller: givenKanaController,
                    hintText: prefersEnglish ? 'タロウ' : 'タロウ',
                    errorText: validation.givenKanaError,
                    onChanged: (value) => onChanged(NameField.givenKana, value),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish
                ? 'Use full-width characters to avoid engraving errors.'
                : '全角入力が必要です。半角が含まれると仕上がりに影響します。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: helperColor),
          ),
          SizedBox(height: tokens.spacing.md),
          if (suggestion != null) ...[
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.xs,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.person),
                  label: Text(
                    prefersEnglish
                        ? 'Use profile: ${suggestion.fullName(prefersEnglish: true)}'
                        : 'プロフィール: ${suggestion.fullName(prefersEnglish: false)}',
                  ),
                  onPressed: () => onApplySuggestion(suggestion),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
          ],
          _TemplateChips(
            label: prefersEnglish ? 'Common surnames' : '姓の候補',
            templates: surnameTemplates,
            onSelect: (template) {
              final next = _applyTemplate(
                template,
                current: currentDraft,
                isSurname: true,
              );
              onApplySuggestion(next);
            },
          ),
          SizedBox(height: tokens.spacing.sm),
          _TemplateChips(
            label: prefersEnglish ? 'Given name presets' : '名の候補',
            templates: givenTemplates,
            onSelect: (template) {
              final next = _applyTemplate(
                template,
                current: currentDraft,
                isSurname: false,
              );
              onApplySuggestion(next);
            },
          ),
          if (validation.scriptWarning != null) ...[
            SizedBox(height: tokens.spacing.md),
            AppValidationMessage(
              message: validation.scriptWarning!,
              state: AppValidationState.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateChips extends StatelessWidget {
  const _TemplateChips({
    required this.label,
    required this.templates,
    required this.onSelect,
  });

  final String label;
  final List<_NameTemplate> templates;
  final ValueChanged<_NameTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    final tokens = DesignTokensTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.xs),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: templates
              .map(
                (template) => ActionChip(
                  label: Text(template.label),
                  onPressed: () => onSelect(template),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _KanjiMappingCard extends StatelessWidget {
  const _KanjiMappingCard({
    required this.prefersEnglish,
    required this.onOpen,
    required this.showAssist,
    this.mapping,
  });

  final bool prefersEnglish;
  final VoidCallback onOpen;
  final bool showAssist;
  final KanjiMapping? mapping;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.md,
      ),
      onTap: onOpen,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: tokens.colors.primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.psychology_alt_outlined,
              color: tokens.colors.primary,
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefersEnglish ? 'Need kanji ideas?' : '漢字マッピングを提案',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  prefersEnglish
                      ? 'Open the kanji helper to browse meanings and pick candidates.'
                      : '意味や由来から候補を確認し、そのまま入力に反映できます。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                if (mapping != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    prefersEnglish
                        ? 'Selected: ${mapping!.value ?? mapping!.mappingRef ?? ''}'
                        : '選択中: ${mapping!.value ?? mapping!.mappingRef ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (showAssist) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    prefersEnglish
                        ? 'Recommended for international users.'
                        : '海外ユーザー向けのガイドを優先表示します。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: tokens.colors.onSurface),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.draft,
    required this.validation,
    required this.prefersEnglish,
    required this.style,
    required this.onStyleChanged,
    required this.colorScheme,
  });

  final NameInputDraft draft;
  final NameValidationResult validation;
  final bool prefersEnglish;
  final WritingStyle style;
  final ValueChanged<WritingStyle> onStyleChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final previewText = draft.fullName(prefersEnglish: prefersEnglish);
    final kana = draft.fullKana();
    final fallback = prefersEnglish ? 'Preview' : 'プレビュー';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prefersEnglish ? 'Preview' : 'プレビュー',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      prefersEnglish
                          ? 'Live preview updates with your input and style.'
                          : '入力内容と書体を反映してリアルタイムで確認できます。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: tokens.spacing.xs,
                children: _writingStyleOptions(prefersEnglish).map((option) {
                  final selected = option.style == style;
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: selected,
                    onSelected: (_) => onStyleChanged(option.style),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.08),
                  colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(tokens.radii.md),
              border: Border.all(
                color: tokens.colors.outline.withValues(alpha: 0.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              previewText.isEmpty ? fallback : previewText,
              textAlign: TextAlign.center,
              style: _previewStyle(context, style),
            ),
          ),
          if (kana.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.sm),
            Text(
              '${prefersEnglish ? 'Kana' : 'フリガナ'}: $kana',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!validation.isValid) ...[
            SizedBox(height: tokens.spacing.sm),
            AppValidationMessage(
              message: prefersEnglish
                  ? 'Complete required fields to enable preview export.'
                  : '必須項目の入力を完了すると次に進めます。',
              state: AppValidationState.error,
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle _previewStyle(BuildContext context, WritingStyle style) {
  final base = Theme.of(context).textTheme.headlineMedium!;
  switch (style) {
    case WritingStyle.tensho:
      return base.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700);
    case WritingStyle.reisho:
      return base.copyWith(letterSpacing: 4, fontStyle: FontStyle.italic);
    case WritingStyle.kaisho:
      return base.copyWith(letterSpacing: 2, fontWeight: FontWeight.w600);
    case WritingStyle.gyosho:
      return base.copyWith(
        letterSpacing: 3,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
      );
    case WritingStyle.koentai:
      return base.copyWith(
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
        height: 1.1,
      );
    case WritingStyle.custom:
      return base.copyWith(letterSpacing: 2);
  }
}

List<_WritingStyleOption> _writingStyleOptions(bool prefersEnglish) {
  return [
    _WritingStyleOption(
      style: WritingStyle.tensho,
      label: prefersEnglish ? 'Tensho' : '篆書',
    ),
    _WritingStyleOption(
      style: WritingStyle.kaisho,
      label: prefersEnglish ? 'Kaisho' : '楷書',
    ),
    _WritingStyleOption(
      style: WritingStyle.gyosho,
      label: prefersEnglish ? 'Gyosho' : '行書',
    ),
  ];
}

class _WritingStyleOption {
  const _WritingStyleOption({required this.style, required this.label});

  final WritingStyle style;
  final String label;
}

class _NameTemplate {
  const _NameTemplate({required this.label, this.kana});

  final String label;
  final String? kana;
}

List<_NameTemplate> _surnameTemplates(bool prefersEnglish) {
  if (prefersEnglish) {
    return const [
      _NameTemplate(label: 'Yamada', kana: 'ヤマダ'),
      _NameTemplate(label: 'Sato', kana: 'サトウ'),
      _NameTemplate(label: 'Suzuki', kana: 'スズキ'),
    ];
  }
  return const [
    _NameTemplate(label: '山田', kana: 'ヤマダ'),
    _NameTemplate(label: '佐藤', kana: 'サトウ'),
    _NameTemplate(label: '鈴木', kana: 'スズキ'),
  ];
}

List<_NameTemplate> _givenTemplates(bool prefersEnglish) {
  if (prefersEnglish) {
    return const [
      _NameTemplate(label: 'Taro', kana: 'タロウ'),
      _NameTemplate(label: 'Ken', kana: 'ケン'),
      _NameTemplate(label: 'Mika', kana: 'ミカ'),
    ];
  }
  return const [
    _NameTemplate(label: '太郎', kana: 'タロウ'),
    _NameTemplate(label: '健', kana: 'ケン'),
    _NameTemplate(label: '美香', kana: 'ミカ'),
  ];
}

NameInputDraft _applyTemplate(
  _NameTemplate template, {
  required NameInputDraft current,
  required bool isSurname,
}) {
  final kanaValue = template.kana ?? '';
  if (isSurname) {
    return current.copyWith(
      surnameKanji: template.label,
      surnameKana: kanaValue.isEmpty ? current.surnameKana : kanaValue,
      clearKanjiMapping: true,
    );
  }

  return current.copyWith(
    givenKanji: template.label,
    givenKana: kanaValue.isEmpty ? current.givenKana : kanaValue,
    clearKanjiMapping: true,
  );
}

NameInputDraft? _profileSuggestion(
  UserProfile? profile,
  NameInputDraft current,
) {
  final display = profile?.displayName?.trim();
  if (display == null || display.isEmpty) return null;

  final parts = display.split(RegExp(r'\s+'));
  final surname = parts.isNotEmpty ? parts.first : '';
  final given = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  if (surname.isEmpty && given.isEmpty) return null;

  return NameInputDraft(
    surnameKanji: surname,
    givenKanji: given,
    surnameKana: current.surnameKana,
    givenKana: current.givenKana,
    kanjiMapping: current.kanjiMapping,
  );
}
