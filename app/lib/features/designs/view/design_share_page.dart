// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message_helpers.dart';
import 'package:app/core/feedback/app_message_provider.dart';
import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/view_model/design_share_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignSharePage extends ConsumerStatefulWidget {
  const DesignSharePage({super.key});

  @override
  ConsumerState<DesignSharePage> createState() => _DesignSharePageState();
}

class _DesignSharePageState extends ConsumerState<DesignSharePage> {
  final TextEditingController _overlayController = TextEditingController();
  int? _lastFeedbackId;
  late final void Function() _feedbackCancel;

  @override
  void initState() {
    super.initState();
    _feedbackCancel = ref.container.listen<AsyncValue<DesignShareState>>(
      designShareViewModel,
      (next) {
        if (next case AsyncData(:final value)) {
          _handleFeedback(value);
        }
      },
    );
  }

  @override
  void dispose() {
    _feedbackCancel();
    _overlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final share = ref.watch(designShareViewModel);
    final data = share.valueOrNull;

    if (data != null && _overlayController.text != data.overlayText) {
      _overlayController.value = TextEditingValue(
        text: data.overlayText,
        selection: TextSelection.collapsed(offset: data.overlayText.length),
      );
    }

    Widget body;
    switch (share) {
      case AsyncLoading() when data == null:
        body = const _ShareSkeleton();
      case AsyncError(:final error) when data == null:
        body = _ShareError(
          prefersEnglish: prefersEnglish,
          error: error,
          onRetry: () => ref.invalidate(designShareViewModel),
        );
      default:
        body = _ShareBody(
          state: data!,
          prefersEnglish: prefersEnglish,
          overlayController: _overlayController,
          onBackgroundChanged: (background) =>
              ref.invoke(designShareViewModel.selectBackground(background)),
          onToggleWatermark: (enabled) =>
              ref.invoke(designShareViewModel.toggleWatermark(enabled)),
          onToggleHashtags: (enabled) =>
              ref.invoke(designShareViewModel.toggleHashtags(enabled)),
          onOverlayChanged: (value) =>
              ref.invoke(designShareViewModel.updateOverlay(value)),
          onRegenerate: () => ref.invoke(designShareViewModel.regenerate()),
          onShare: (target) =>
              ref.invoke(designShareViewModel.share(target: target)),
          onCopyLink: () => _copyToClipboard(
            data.shareLink,
            prefersEnglish ? 'Share link copied' : '共有リンクをコピーしました',
          ),
          onCopyCaption: () => _copyToClipboard(
            data.shareCopy,
            prefersEnglish ? 'Share copy copied' : 'キャプションをコピーしました',
          ),
        );
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _ShareAppBar(
        prefersEnglish: prefersEnglish,
        onCopyLink: data == null
            ? null
            : () => _copyToClipboard(
                data.shareLink,
                prefersEnglish ? 'Share link copied' : '共有リンクをコピーしました',
              ),
        onClose: () => _close(context),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: data == null
          ? null
          : _ShareFooter(
              prefersEnglish: prefersEnglish,
              onNavigate: (tab) => GoRouter.of(context).go(tab.location),
            ),
    );
  }

  void _handleFeedback(DesignShareState state) {
    final feedback = state.feedbackMessage;
    if (feedback == null) return;
    if (state.feedbackId == _lastFeedbackId) return;
    _lastFeedbackId = state.feedbackId;
    emitMessageFromText(ref.container.read(appMessageSinkProvider), feedback);
  }

  void _close(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go(AppRoutePaths.designPreview);
  }

  Future<void> _copyToClipboard(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShareAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShareAppBar({
    required this.prefersEnglish,
    this.onCopyLink,
    required this.onClose,
  });

  final bool prefersEnglish;
  final VoidCallback? onCopyLink;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: prefersEnglish ? 'Close' : '閉じる',
        onPressed: onClose,
      ),
      titleSpacing: tokens.spacing.md,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prefersEnglish ? 'Share design' : 'デザインを共有'),
          Text(
            prefersEnglish
                ? 'Mocked social posts with watermark'
                : 'ウォーターマーク付きのソーシャルモック',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: prefersEnglish ? 'Copy link' : 'リンクをコピー',
          onPressed: onCopyLink,
          icon: const Icon(Icons.link_rounded),
        ),
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _ShareBody extends StatelessWidget {
  const _ShareBody({
    required this.state,
    required this.prefersEnglish,
    required this.overlayController,
    required this.onBackgroundChanged,
    required this.onToggleWatermark,
    required this.onToggleHashtags,
    required this.onOverlayChanged,
    required this.onRegenerate,
    required this.onShare,
    required this.onCopyCaption,
    required this.onCopyLink,
  });

  final DesignShareState state;
  final bool prefersEnglish;
  final TextEditingController overlayController;
  final ValueChanged<ShareBackground> onBackgroundChanged;
  final ValueChanged<bool> onToggleWatermark;
  final ValueChanged<bool> onToggleHashtags;
  final ValueChanged<String> onOverlayChanged;
  final VoidCallback onRegenerate;
  final ValueChanged<String> onShare;
  final VoidCallback onCopyCaption;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final subtitle = state.design.templateName == null
        ? null
        : '${prefersEnglish ? 'Template' : 'テンプレート'}: ${state.design.templateName}';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      children: [
        _ShareHeader(
          prefersEnglish: prefersEnglish,
          design: state.design,
          subtitle: subtitle,
          onRegenerate: onRegenerate,
          isGenerating: state.isGenerating,
          lastGeneratedAt: state.lastGeneratedAt,
        ),
        SizedBox(height: tokens.spacing.lg),
        _MockDeck(
          prefersEnglish: prefersEnglish,
          previews: state.previews,
          watermarkEnabled: state.watermarkEnabled,
          includeHashtags: state.includeHashtags,
        ),
        SizedBox(height: tokens.spacing.lg),
        _ShareControls(
          prefersEnglish: prefersEnglish,
          state: state,
          overlayController: overlayController,
          onBackgroundChanged: onBackgroundChanged,
          onToggleWatermark: onToggleWatermark,
          onToggleHashtags: onToggleHashtags,
          onOverlayChanged: onOverlayChanged,
        ),
        SizedBox(height: tokens.spacing.lg),
        _ShareCopyCard(
          prefersEnglish: prefersEnglish,
          shareCopy: state.shareCopy,
          shareLink: state.shareLink,
          onCopyCaption: onCopyCaption,
          onCopyLink: onCopyLink,
        ),
        SizedBox(height: tokens.spacing.lg),
        _ShareActions(
          prefersEnglish: prefersEnglish,
          isSharing: state.isSharing,
          onShare: onShare,
        ),
      ],
    );
  }
}

class _ShareHeader extends StatelessWidget {
  const _ShareHeader({
    required this.prefersEnglish,
    required this.design,
    required this.onRegenerate,
    required this.isGenerating,
    required this.lastGeneratedAt,
    this.subtitle,
  });

  final bool prefersEnglish;
  final ShareableDesign design;
  final VoidCallback onRegenerate;
  final bool isGenerating;
  final DateTime? lastGeneratedAt;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final sizeLabel = '${design.sizeMm.toStringAsFixed(0)}mm';
    final writing = _writingLabel(design.writingStyle, prefersEnglish);
    final shape = design.shape == SealShape.square
        ? (prefersEnglish ? 'Square' : '角印')
        : (prefersEnglish ? 'Round' : '丸印');
    final timestamp = lastGeneratedAt == null
        ? ''
        : (prefersEnglish
              ? 'Updated ${lastGeneratedAt!.hour.toString().padLeft(2, '0')}:${lastGeneratedAt!.minute.toString().padLeft(2, '0')}'
              : '${lastGeneratedAt!.hour.toString().padLeft(2, '0')}:${lastGeneratedAt!.minute.toString().padLeft(2, '0')} に更新');

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
                      design.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.colors.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: tokens.spacing.xs),
                    Wrap(
                      spacing: tokens.spacing.xs,
                      runSpacing: tokens.spacing.xs,
                      children: [
                        _InfoPill(
                          label: writing,
                          icon: Icons.font_download_outlined,
                        ),
                        _InfoPill(label: sizeLabel, icon: Icons.straighten),
                        _InfoPill(label: shape, icon: Icons.blur_circular),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: isGenerating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.autorenew),
                label: Text(prefersEnglish ? 'Refresh' : '再生成'),
                onPressed: isGenerating ? null : onRegenerate,
              ),
            ],
          ),
          if (timestamp.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              timestamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MockDeck extends StatelessWidget {
  const _MockDeck({
    required this.prefersEnglish,
    required this.previews,
    required this.watermarkEnabled,
    required this.includeHashtags,
  });

  final bool prefersEnglish;
  final List<SocialMock> previews;
  final bool watermarkEnabled;
  final bool includeHashtags;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              prefersEnglish ? 'Preview deck' : 'プレビュー',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                _Tag(
                  label: watermarkEnabled
                      ? (prefersEnglish ? 'Watermark on' : '透かし ON')
                      : (prefersEnglish ? 'Watermark off' : '透かし OFF'),
                  icon: Icons.verified_user_outlined,
                ),
                SizedBox(width: tokens.spacing.xs),
                _Tag(
                  label: includeHashtags
                      ? (prefersEnglish ? 'Hashtags' : 'ハッシュタグあり')
                      : (prefersEnglish ? 'No hashtags' : 'ハッシュタグなし'),
                  icon: Icons.tag,
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.sm),
        SizedBox(
          height: 320,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final mock = previews[index];
              return _MockPreviewCard(
                mock: mock,
                prefersEnglish: prefersEnglish,
              );
            },
            separatorBuilder: (context, _) =>
                SizedBox(width: tokens.spacing.md),
            itemCount: previews.length,
          ),
        ),
      ],
    );
  }
}

class _MockPreviewCard extends StatelessWidget {
  const _MockPreviewCard({required this.mock, required this.prefersEnglish});

  final SocialMock mock;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final accent = _platformAccent(mock.platform);
    final gradient = _backgroundGradient(mock.background, tokens);

    return SizedBox(
      width: 280,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.lg),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: mock.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radii.lg),
                  child: Stack(
                    children: [
                      Container(decoration: BoxDecoration(gradient: gradient)),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(alpha: 0.12),
                                accent.withValues(alpha: 0.04),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _Tag(
                          label: mock.platform.label(prefersEnglish),
                          icon: _platformIcon(mock.platform),
                          color: accent,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(tokens.spacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  mock.overlayText.isEmpty
                                      ? (prefersEnglish
                                            ? 'Awaiting overlay'
                                            : 'テキスト未入力')
                                      : mock.overlayText,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: tokens.colors.onPrimary
                                            .withValues(alpha: 0.92),
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                ),
                              ),
                            ),
                            if (mock.hashtags.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  mock.hashtags.join(' '),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: tokens.colors.onPrimary
                                            .withValues(alpha: 0.8),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (mock.watermarked)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Transform.rotate(
                            angle: -0.24,
                            child: Text(
                              'Hanko Field',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: tokens.colors.onPrimary.withValues(
                                      alpha: 0.3,
                                    ),
                                    letterSpacing: 1.8,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.xs,
                runSpacing: tokens.spacing.xs,
                children: [
                  _Tag(label: mock.sizeLabel, icon: Icons.aspect_ratio),
                  _Tag(
                    label: '${(mock.impressionScore * 100).round()}% reach',
                    icon: Icons.auto_graph_rounded,
                  ),
                  _Tag(label: mock.callout, icon: Icons.palette_outlined),
                ],
              ),
              SizedBox(height: tokens.spacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.md),
                child: LinearProgressIndicator(
                  value: mock.impressionScore.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: accent,
                  backgroundColor: tokens.colors.surfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareControls extends StatelessWidget {
  const _ShareControls({
    required this.prefersEnglish,
    required this.state,
    required this.overlayController,
    required this.onBackgroundChanged,
    required this.onToggleWatermark,
    required this.onToggleHashtags,
    required this.onOverlayChanged,
  });

  final bool prefersEnglish;
  final DesignShareState state;
  final TextEditingController overlayController;
  final ValueChanged<ShareBackground> onBackgroundChanged;
  final ValueChanged<bool> onToggleWatermark;
  final ValueChanged<bool> onToggleHashtags;
  final ValueChanged<String> onOverlayChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Templates' : 'テンプレート',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: ShareBackground.values.map((background) {
              final selected = background == state.background;
              return ChoiceChip(
                label: Text(background.label(prefersEnglish)),
                selected: selected,
                avatar: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _backgroundGradient(background, tokens),
                  ),
                ),
                onSelected: (_) => onBackgroundChanged(background),
              );
            }).toList(),
          ),
          SizedBox(height: tokens.spacing.md),
          SwitchListTile.adaptive(
            value: state.watermarkEnabled,
            onChanged: onToggleWatermark,
            title: Text(prefersEnglish ? 'Apply watermark' : 'ウォーターマークを適用'),
            subtitle: Text(
              prefersEnglish
                  ? 'Light overlay for social exports'
                  : 'ソーシャル用に軽い透かしを追加',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile.adaptive(
            value: state.includeHashtags,
            onChanged: onToggleHashtags,
            title: Text(prefersEnglish ? 'Include hashtags' : 'ハッシュタグを含める'),
            subtitle: Text(
              prefersEnglish
                  ? 'Preset copy uses #HankoField + context tags'
                  : 'プリセットコピーに #HankoField などを含めます',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          SizedBox(height: tokens.spacing.sm),
          AppTextField(
            label: prefersEnglish ? 'Overlay text' : 'オーバーレイテキスト',
            controller: overlayController,
            hintText: prefersEnglish
                ? 'Add a caption for mocked posts'
                : 'モック投稿用のキャプションを入力',
            prefix: const Icon(Icons.edit_note_outlined),
            onChanged: onOverlayChanged,
            helperText: prefersEnglish
                ? 'Shown on all mocked social posts'
                : '全モック投稿のオーバーレイとして表示',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _ShareCopyCard extends StatelessWidget {
  const _ShareCopyCard({
    required this.prefersEnglish,
    required this.shareCopy,
    required this.shareLink,
    required this.onCopyCaption,
    required this.onCopyLink,
  });

  final bool prefersEnglish;
  final String shareCopy;
  final String shareLink;
  final VoidCallback onCopyCaption;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                prefersEnglish ? 'Share copy' : '共有用コピー',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: tokens.spacing.xs,
                children: [
                  IconButton(
                    icon: const Icon(Icons.link_rounded),
                    tooltip: prefersEnglish ? 'Copy link' : 'リンクをコピー',
                    onPressed: onCopyLink,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_all_outlined),
                    tooltip: prefersEnglish ? 'Copy text' : 'テキストをコピー',
                    onPressed: onCopyCaption,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: tokens.colors.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(tokens.radii.md),
            ),
            padding: EdgeInsets.all(tokens.spacing.md),
            child: SelectableText(
              shareCopy,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            shareLink,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActions extends StatelessWidget {
  const _ShareActions({
    required this.prefersEnglish,
    required this.isSharing,
    required this.onShare,
  });

  final bool prefersEnglish;
  final bool isSharing;
  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final targets = [
      _ShareTarget(
        label: prefersEnglish ? 'Instagram feed' : 'インスタフィード',
        icon: Icons.photo_library_outlined,
        target: 'Instagram',
      ),
      _ShareTarget(
        label: prefersEnglish ? 'LINE chat' : 'LINE トーク',
        icon: Icons.chat_bubble_outline_rounded,
        target: 'LINE',
      ),
      _ShareTarget(
        label: prefersEnglish ? 'Messages/DM' : 'メッセージ・DM',
        icon: Icons.send_rounded,
        target: 'DM',
      ),
      _ShareTarget(
        label: prefersEnglish ? 'Save watermarked' : '透かし付きで保存',
        icon: Icons.verified,
        target: 'Watermarked export',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefersEnglish ? 'Share options' : '共有オプション',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: targets
              .map(
                (target) => ActionChip(
                  avatar: Icon(target.icon),
                  label: Text(target.label),
                  onPressed: isSharing ? null : () => onShare(target.target),
                ),
              )
              .toList(),
        ),
        SizedBox(height: tokens.spacing.md),
        FilledButton.tonalIcon(
          icon: isSharing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.colors.onPrimary,
                  ),
                )
              : const Icon(Icons.ios_share_rounded),
          label: Text(prefersEnglish ? 'Open share sheet' : '共有シートを開く'),
          onPressed: isSharing ? null : () => onShare('Share sheet'),
        ),
      ],
    );
  }
}

class _ShareFooter extends StatelessWidget {
  const _ShareFooter({required this.prefersEnglish, required this.onNavigate});

  final bool prefersEnglish;
  final ValueChanged<AppTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.lg,
              vertical: tokens.spacing.sm,
            ),
            child: Text(
              prefersEnglish
                  ? 'Return to tabs when you are done sharing.'
                  : '共有後は下のタブバーから移動できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) => onNavigate(AppTab.values[index]),
            destinations: AppTab.values
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ShareSkeleton extends StatelessWidget {
  const _ShareSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: [
        const AppSkeletonBlock(height: 120),
        SizedBox(height: tokens.spacing.md),
        const AppListSkeleton(items: 1, itemHeight: 280),
        SizedBox(height: tokens.spacing.md),
        const AppSkeletonBlock(height: 180),
        SizedBox(height: tokens.spacing.md),
        const AppSkeletonBlock(height: 160),
      ],
    );
  }
}

class _ShareError extends StatelessWidget {
  const _ShareError({
    required this.prefersEnglish,
    required this.error,
    required this.onRetry,
  });

  final bool prefersEnglish;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: AppEmptyState(
        title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
        message: error.toString(),
        icon: Icons.error_outline,
        actionLabel: prefersEnglish ? 'Retry' : '再試行',
        onAction: onRetry,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final background =
        color?.withValues(alpha: 0.12) ?? tokens.colors.surfaceVariant;
    final foreground = color ?? tokens.colors.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          SizedBox(width: tokens.spacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

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
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: tokens.spacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ShareTarget {
  const _ShareTarget({
    required this.label,
    required this.icon,
    required this.target,
  });

  final String label;
  final IconData icon;
  final String target;
}

String _writingLabel(WritingStyle style, bool prefersEnglish) {
  return switch (style) {
    WritingStyle.tensho => prefersEnglish ? 'Tensho' : '篆書',
    WritingStyle.reisho => prefersEnglish ? 'Reisho' : '隷書',
    WritingStyle.kaisho => prefersEnglish ? 'Kaisho' : '楷書',
    WritingStyle.gyosho => prefersEnglish ? 'Gyosho' : '行書',
    WritingStyle.koentai => prefersEnglish ? 'Koentai' : '古印体',
    WritingStyle.custom => prefersEnglish ? 'Custom' : 'カスタム',
  };
}

IconData _platformIcon(SocialPlatform platform) {
  return switch (platform) {
    SocialPlatform.instagram => Icons.camera_alt_outlined,
    SocialPlatform.x => Icons.alternate_email,
    SocialPlatform.line => Icons.chat_bubble_outline_rounded,
    SocialPlatform.linkedin => Icons.business_center_outlined,
  };
}

Color _platformAccent(SocialPlatform platform) {
  switch (platform) {
    case SocialPlatform.instagram:
      return const Color(0xFFE1306C);
    case SocialPlatform.x:
      return const Color(0xFF0F1419);
    case SocialPlatform.line:
      return const Color(0xFF06C755);
    case SocialPlatform.linkedin:
      return const Color(0xFF0A66C2);
  }
}

Gradient _backgroundGradient(ShareBackground background, DesignTokens tokens) {
  return switch (background) {
    ShareBackground.linen => LinearGradient(
      colors: [const Color(0xFFF7F1E6), tokens.colors.surfaceVariant],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    ShareBackground.studio => const LinearGradient(
      colors: [Color(0xFF1F2026), Color(0xFF2D3038)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    ShareBackground.midnight => const LinearGradient(
      colors: [Color(0xFF1A1026), Color(0xFF0C1A2A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  };
}
