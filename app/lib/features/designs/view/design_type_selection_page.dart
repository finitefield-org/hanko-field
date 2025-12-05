// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignTypeSelectionPage extends ConsumerWidget {
  const DesignTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final state = ref.watch(designCreationViewModel);
    final permissionState = ref.watch(designCreationViewModel.ensureStorageMut);
    final isCheckingPermission = permissionState is PendingMutationState;
    final prefersEnglish = gates.prefersEnglish;

    final selectedType =
        state.valueOrNull?.selectedType ?? DesignSourceType.typed;
    final activeFilters =
        state.valueOrNull?.activeFilters ?? const <String>{'personal'};
    final requiresStorage = _requiresStorage(selectedType);

    final options = _designOptions(prefersEnglish, gates);
    final filters = _quickFilters(prefersEnglish, gates);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppTopBar(
        title: prefersEnglish ? 'Choose creation mode' : '作成タイプを選択',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: prefersEnglish ? 'Flow tips' : '作成フローのヒントを表示します',
            onPressed: () => unawaited(
              _showFlowHelp(context: context, prefersEnglish: prefersEnglish),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FloatingActionButton.extended(
            heroTag: 'design-new-primary',
            onPressed: state.valueOrNull != null && !isCheckingPermission
                ? () => _handleContinue(
                    context: context,
                    ref: ref,
                    prefersEnglish: prefersEnglish,
                  )
                : null,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCheckingPermission) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        tokens.colors.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.sm),
                ] else
                  Icon(_iconForCta(selectedType)),
                Text(
                  prefersEnglish
                      ? _ctaLabelEnglish(selectedType)
                      : _ctaLabel(selectedType),
                ),
              ],
            ),
            backgroundColor: tokens.colors.primary,
            foregroundColor: tokens.colors.onPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncLoading<DesignCreationState>() => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const _DesignNewSkeleton(),
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
          _ => _DesignNewContent(
            options: options,
            filters: filters,
            selectedType: selectedType,
            activeFilters: activeFilters,
            prefersEnglish: prefersEnglish,
            requiresStorage: requiresStorage,
          ),
        },
      ),
    );
  }

  Future<void> _handleContinue({
    required BuildContext context,
    required WidgetRef ref,
    required bool prefersEnglish,
  }) async {
    final state = ref.watch(designCreationViewModel).valueOrNull;
    if (state == null) return;

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final requiresStorage = _requiresStorage(state.selectedType);
    if (requiresStorage) {
      final granted = await ref.invoke(
        designCreationViewModel.ensureStorageAccess(),
      );
      if (granted != true) {
        _showPermissionSnack(messenger, prefersEnglish);
        return;
      }
    }

    final analytics = ref.watch(analyticsClientProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    unawaited(
      analytics.track(
        DesignCreationModeSelectedEvent(
          mode: state.selectedType.toJson(),
          filters: state.activeFilters.toList()..sort(),
          persona: gates.personaKey,
          locale: gates.localeTag,
          entryPoint: 'design_new',
        ),
      ),
    );

    final target = _targetRoute(state.selectedType);
    final filters = state.activeFilters.isEmpty
        ? ''
        : '&filters=${state.activeFilters.join(',')}';
    router.go('$target?mode=${state.selectedType.toJson()}$filters');
  }
}

class _DesignNewContent extends ConsumerWidget {
  const _DesignNewContent({
    required this.options,
    required this.filters,
    required this.selectedType,
    required this.activeFilters,
    required this.prefersEnglish,
    required this.requiresStorage,
  });

  final List<_DesignOption> options;
  final List<_QuickFilterOption> filters;
  final DesignSourceType selectedType;
  final Set<String> activeFilters;
  final bool prefersEnglish;
  final bool requiresStorage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

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
                Text(
                  prefersEnglish ? 'Start a new seal' : '新しい印影を作成',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Pick how you want to start: type text, upload a reference, or engrave a logo.'
                      : '文字入力・画像アップロード・ロゴ刻印から始められます。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spacing.md),
                Wrap(
                  spacing: tokens.spacing.sm,
                  runSpacing: tokens.spacing.sm,
                  children: filters
                      .map(
                        (filter) => FilterChip(
                          selected: activeFilters.contains(filter.id),
                          label: Text(filter.label),
                          avatar: Icon(
                            filter.icon,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          onSelected: (_) => ref.invoke(
                            designCreationViewModel.toggleFilter(filter.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
            child: _OptionGrid(
              options: options,
              selectedType: selectedType,
              onSelected: (type) =>
                  ref.invoke(designCreationViewModel.selectType(type)),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.lg,
              tokens.spacing.lg,
              tokens.spacing.xxl * 2,
            ),
            child: Column(
              children: [
                _HighlightCard(
                  icon: Icons.sd_storage_rounded,
                  title: prefersEnglish
                      ? 'Uploads need storage access'
                      : 'アップロードにはストレージ権限が必要です',
                  body: prefersEnglish
                      ? 'We check your permission before opening camera roll or files.'
                      : 'ファイル/写真へのアクセス前に権限を確認します。',
                  tone: requiresStorage
                      ? tokens.colors.primary
                      : tokens.colors.onSurface.withValues(alpha: 0.6),
                ),
                SizedBox(height: tokens.spacing.md),
                _HighlightCard(
                  icon: Icons.auto_awesome_rounded,
                  title: prefersEnglish
                      ? 'Assisted by AI and templates'
                      : 'AI補正とテンプレート提案付き',
                  body: prefersEnglish
                      ? 'We prefill stroke weight, spacing, and suggest styles based on your filters.'
                      : 'フィルターに応じて太さ・余白・書体を自動提案します。',
                  tone: tokens.colors.secondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.options,
    required this.selectedType,
    required this.onSelected,
  });

  final List<_DesignOption> options;
  final DesignSourceType selectedType;
  final ValueChanged<DesignSourceType> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = tokens.spacing.md;
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: options
              .map(
                (option) => SizedBox(
                  width: itemWidth,
                  child: _DesignOptionCard(
                    option: option,
                    selected: option.type == selectedType,
                    onSelected: () => onSelected(option.type),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DesignOptionCard extends StatelessWidget {
  const _DesignOptionCard({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final _DesignOption option;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = selected
        ? tokens.colors.primary
        : colorScheme.outline;

    return Material(
      elevation: selected ? 4 : 1,
      color: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        side: BorderSide(
          color: selected
              ? tokens.colors.primary
              : tokens.colors.outline.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tokens.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(tokens.radii.md),
                    ),
                    child: Icon(option.icon, color: highlightColor),
                  ),
                  SizedBox(width: tokens.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: tokens.spacing.xs),
                        Text(
                          option.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.colors.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (option.badge != null) ...[
                    SizedBox(width: tokens.spacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacing.sm,
                        vertical: tokens.spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(tokens.radii.sm),
                      ),
                      child: Text(
                        option.badge!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: tokens.spacing.md),
              Container(
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tokens.radii.md),
                  gradient: LinearGradient(
                    colors: [
                      tokens.colors.surfaceVariant,
                      tokens.colors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: tokens.spacing.md,
                      bottom: tokens.spacing.sm,
                      child: Icon(
                        Icons.auto_fix_high_rounded,
                        color: tokens.colors.onSurface.withValues(alpha: 0.08),
                        size: 48,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(tokens.spacing.md),
                      child: Text(
                        option.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: option.highlights
                    .map(
                      (text) =>
                          _HighlightPill(text: text, color: highlightColor),
                    )
                    .toList(),
              ),
              if (option.needsStorage) ...[
                SizedBox(height: tokens.spacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.sd_storage_rounded,
                      size: 18,
                      color: tokens.colors.warning,
                    ),
                    SizedBox(width: tokens.spacing.xs),
                    Text(
                      option.storageLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  const _HighlightPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(tokens.radii.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: color),
          SizedBox(width: tokens.spacing.xs),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      backgroundColor: tone.withValues(alpha: 0.06),
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignNewSkeleton extends StatelessWidget {
  const _DesignNewSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSkeletonBlock(
          width: 200,
          height: 22,
          borderRadius: BorderRadius.circular(tokens.radii.sm),
        ),
        SizedBox(height: tokens.spacing.sm),
        AppSkeletonBlock(
          width: 280,
          height: 14,
          borderRadius: BorderRadius.circular(tokens.radii.sm),
        ),
        SizedBox(height: tokens.spacing.lg),
        const AppSkeletonBlock(height: 32),
        SizedBox(height: tokens.spacing.sm),
        const AppSkeletonBlock(height: 32),
        SizedBox(height: tokens.spacing.lg),
        const AppListSkeleton(items: 3, itemHeight: 180),
      ],
    );
  }
}

Future<void> _showFlowHelp({
  required BuildContext context,
  required bool prefersEnglish,
}) {
  final tokens = DesignTokensTheme.of(context);

  return showAppModal<void>(
    context: context,
    title: prefersEnglish ? 'Which path should I choose?' : 'どの作成方法を選ぶか',
    primaryAction: prefersEnglish ? 'Open guides' : 'ガイドを見る',
    onPrimaryPressed: () {
      Navigator.of(context).maybePop();
      GoRouter.of(context).go(AppRoutePaths.guides);
    },
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefersEnglish
              ? 'Text entry is best when you know the exact name. Upload when you already have a stamp photo. Logo is for corporate marks or signatures.'
              : '氏名入力なら文字作成、既存印影の写真があるならアップロード、'
                    'ロゴやサインを刻印する場合はロゴ刻印を選んでください。',
        ),
        SizedBox(height: tokens.spacing.md),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: const [
            _HelpPill(label: 'Text', value: '名前入力'),
            _HelpPill(label: 'Upload', value: '写真/ファイル'),
            _HelpPill(label: 'Logo', value: 'サイン/社印'),
          ],
        ),
      ],
    ),
  );
}

void _showPermissionSnack(
  ScaffoldMessengerState messenger,
  bool prefersEnglish,
) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        prefersEnglish
            ? 'Storage access is needed to continue.'
            : '続行にはストレージ権限が必要です。',
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

String _targetRoute(DesignSourceType type) {
  return switch (type) {
    DesignSourceType.typed => AppRoutePaths.designInput,
    DesignSourceType.uploaded => AppRoutePaths.designEditor,
    DesignSourceType.logo => AppRoutePaths.designStyle,
  };
}

bool _requiresStorage(DesignSourceType type) {
  return switch (type) {
    DesignSourceType.typed => false,
    DesignSourceType.uploaded => true,
    DesignSourceType.logo => true,
  };
}

IconData _iconForCta(DesignSourceType type) {
  return switch (type) {
    DesignSourceType.typed => Icons.edit,
    DesignSourceType.uploaded => Icons.file_upload_outlined,
    DesignSourceType.logo => Icons.apartment_rounded,
  };
}

String _ctaLabel(DesignSourceType type) {
  return switch (type) {
    DesignSourceType.typed => '文字入力に進む',
    DesignSourceType.uploaded => '画像を選ぶ',
    DesignSourceType.logo => 'ロゴ刻印を選ぶ',
  };
}

String _ctaLabelEnglish(DesignSourceType type) {
  return switch (type) {
    DesignSourceType.typed => 'Start with text',
    DesignSourceType.uploaded => 'Upload an image',
    DesignSourceType.logo => 'Engrave a logo',
  };
}

List<_DesignOption> _designOptions(
  bool prefersEnglish,
  AppExperienceGates gates,
) {
  final intl = gates.emphasizeInternationalFlows;

  return [
    _DesignOption(
      type: DesignSourceType.typed,
      title: prefersEnglish ? 'Type text' : '文字を入力して作る',
      subtitle: prefersEnglish
          ? 'Best for names or short phrases.'
          : '氏名や刻みたい文字を入力して開始。',
      body: prefersEnglish
          ? 'We prefill recommended script, size, and spacing based on your filters.'
          : 'フィルターに基づき書体・サイズ・余白を自動提案します。',
      badge: prefersEnglish ? 'Recommended' : 'おすすめ',
      icon: Icons.edit_note_rounded,
      needsStorage: false,
      highlights: [
        prefersEnglish ? 'Kanji suggestions available' : '漢字マッピング候補',
        prefersEnglish ? 'Style presets ready' : '書体プリセット付き',
        prefersEnglish ? 'Analytics-safe drafts' : '下書きを自動保存',
      ],
      storageLabel: '',
    ),
    _DesignOption(
      type: DesignSourceType.uploaded,
      title: prefersEnglish ? 'Upload image' : '画像をアップロード',
      subtitle: prefersEnglish
          ? 'Use a scan or photo of an existing seal.'
          : '既存の印影写真やスキャンを取り込み。',
      body: prefersEnglish
          ? 'We align, clean edges, and let you adjust stroke weight quickly.'
          : '縁取りを整え、太さや余白をすぐ調整できます。',
      icon: Icons.cloud_upload_rounded,
      needsStorage: true,
      highlights: [
        prefersEnglish ? 'Accepts photos/PDF' : '写真・PDF対応',
        prefersEnglish ? 'Auto clean-up' : 'ノイズ自動除去',
        prefersEnglish ? 'Keeps original layer' : '元画像を残して編集',
      ],
      storageLabel: prefersEnglish
          ? 'Needs photo/file access'
          : '写真/ファイル権限が必要です',
    ),
    _DesignOption(
      type: DesignSourceType.logo,
      title: prefersEnglish ? 'Engrave a logo' : 'ロゴ・サインを刻印',
      subtitle: prefersEnglish
          ? 'Import vector marks or signatures.'
          : 'ロゴやサインを取り込み刻印用に整形。',
      body: prefersEnglish
          ? 'Great for corporate seals or personal marks. We keep curves crisp.'
          : '社判・角印・サイン刻印に。曲線を滑らかに保ちます。',
      icon: Icons.apartment_rounded,
      needsStorage: true,
      highlights: [
        prefersEnglish ? 'SVG/PNG friendly' : 'SVG/PNG対応',
        prefersEnglish ? 'Grid & margin helpers' : 'ガイド線と余白ガイド付き',
        intl ? 'EN/JA layout hints' : '日英レイアウトヒント',
      ],
      storageLabel: prefersEnglish ? 'Needs file access' : 'ファイル権限が必要です',
    ),
  ];
}

List<_QuickFilterOption> _quickFilters(
  bool prefersEnglish,
  AppExperienceGates gates,
) {
  return [
    _QuickFilterOption(
      id: 'personal',
      label: prefersEnglish ? 'Personal use' : '日常使い',
      icon: Icons.person_outline,
    ),
    _QuickFilterOption(
      id: 'official',
      label: prefersEnglish ? 'Official / bank' : '実印・銀行印',
      icon: Icons.verified_user_outlined,
    ),
    _QuickFilterOption(
      id: 'business',
      label: prefersEnglish ? 'Business / corner seal' : '会社・角印',
      icon: Icons.business_center_outlined,
    ),
    _QuickFilterOption(
      id: 'digital',
      label: prefersEnglish ? 'Digital use' : 'デジタル署名',
      icon: Icons.devices_other_rounded,
    ),
  ];
}

class _DesignOption {
  const _DesignOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    required this.needsStorage,
    required this.highlights,
    required this.storageLabel,
    this.badge,
  });

  final DesignSourceType type;
  final String title;
  final String subtitle;
  final String body;
  final String? badge;
  final IconData icon;
  final bool needsStorage;
  final List<String> highlights;
  final String storageLabel;
}

class _QuickFilterOption {
  const _QuickFilterOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class _HelpPill extends StatelessWidget {
  const _HelpPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          SizedBox(width: tokens.spacing.xs),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
