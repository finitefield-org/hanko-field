// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/feedback/app_message_helpers.dart';
import 'package:app/core/feedback/app_message_provider.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_ai_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignAiPage extends ConsumerStatefulWidget {
  const DesignAiPage({super.key});

  @override
  ConsumerState<DesignAiPage> createState() => _DesignAiPageState();
}

class _DesignAiPageState extends ConsumerState<DesignAiPage> {
  int? _lastFeedbackId;
  late final ProviderSubscription<AsyncValue<AiSuggestionsState>>
  _feedbackCancel;

  @override
  void initState() {
    super.initState();
    _feedbackCancel = ref.container.listen<AsyncValue<AiSuggestionsState>>(
      designAiViewModel,
      (_, next) {
        if (next case AsyncData(:final value)) {
          _handleFeedback(value);
        }
      },
    );
  }

  @override
  void dispose() {
    _feedbackCancel.close();
    super.dispose();
  }

  Future<void> _refresh() => ref.invoke(designAiViewModel.poll());

  Future<void> _request(AiSuggestionMethod method) =>
      ref.invoke(designAiViewModel.requestSuggestions(method));

  Future<void> _accept(AiSuggestion suggestion) => ref.invoke(
    designAiViewModel.acceptSuggestion(suggestion.id ?? suggestion.jobRef),
  );

  Future<void> _reject(AiSuggestion suggestion) => ref.invoke(
    designAiViewModel.rejectSuggestion(suggestion.id ?? suggestion.jobRef),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(designAiViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _AiAppBar(
        queueLength: state.valueOrNull?.queueLength ?? 0,
        isPolling: state.valueOrNull?.isPolling ?? false,
        prefersEnglish: prefersEnglish,
        onRefresh: _refresh,
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _refresh,
          edgeOffset: tokens.spacing.md,
          displacement: tokens.spacing.xl,
          child: _buildBody(
            context: context,
            state: state,
            prefersEnglish: prefersEnglish,
            tokens: tokens,
          ),
        ),
      ),
    );
  }

  void _handleFeedback(AiSuggestionsState state) {
    final feedback = state.feedbackMessage;
    if (feedback == null) return;
    if (state.feedbackId == _lastFeedbackId) return;
    _lastFeedbackId = state.feedbackId;
    emitMessageFromText(ref.container.read(appMessageSinkProvider), feedback);
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncValue<AiSuggestionsState> state,
    required bool prefersEnglish,
    required DesignTokens tokens,
  }) {
    final loading = state is AsyncLoading<AiSuggestionsState>;
    final data = state.valueOrNull;

    if (loading && data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.all(tokens.spacing.lg),
        children: const [
          AppSkeletonBlock(height: 120),
          SizedBox(height: 12),
          AppListSkeleton(items: 4, itemHeight: 180),
        ],
      );
    }

    if (state is AsyncError<AiSuggestionsState> && data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(tokens.spacing.xl),
            child: AppEmptyState(
              title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
              message: state.error.toString(),
              icon: Icons.error_outline,
              actionLabel: prefersEnglish ? 'Retry' : '再試行',
              onAction: _refresh,
            ),
          ),
        ],
      );
    }

    final ready =
        data?.suggestions
            .where((s) => s.status == AiSuggestionStatus.proposed)
            .toList() ??
        const <AiSuggestion>[];
    final applied =
        data?.suggestions
            .where(
              (s) =>
                  s.status == AiSuggestionStatus.applied ||
                  s.status == AiSuggestionStatus.rejected,
            )
            .toList() ??
        const <AiSuggestion>[];
    final queue = data?.queue ?? const <AiQueueItem>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      children: [
        _RequestCard(
          prefersEnglish: prefersEnglish,
          isRequesting: data?.isRequesting ?? false,
          queueLength: data?.queueLength ?? 0,
          rateLimitedUntil: data?.rateLimitedUntil,
          onRequest: () => _request(AiSuggestionMethod.balance),
          onAlternative: () => _request(AiSuggestionMethod.registrabilityCheck),
        ),
        SizedBox(height: tokens.spacing.lg),
        _StatusPills(prefersEnglish: prefersEnglish, state: data),
        SizedBox(height: tokens.spacing.sm),
        _FilterBar(
          selected: data?.filter ?? AiSuggestionFilter.ready,
          prefersEnglish: prefersEnglish,
          onSelected: (filter) =>
              ref.invoke(designAiViewModel.setFilter(filter)),
        ),
        SizedBox(height: tokens.spacing.md),
        Builder(
          builder: (context) {
            final filter = data?.filter ?? AiSuggestionFilter.ready;
            if (filter == AiSuggestionFilter.queued) {
              if (queue.isEmpty) {
                return _EmptyContent(
                  title: prefersEnglish ? 'No queued jobs' : 'キューは空です',
                  message: prefersEnglish
                      ? 'Start a new AI job to see it here.'
                      : 'AIジョブをリクエストするとここに表示されます。',
                  onAction: () => _request(AiSuggestionMethod.balance),
                  prefersEnglish: prefersEnglish,
                );
              }
              return Column(
                children: queue
                    .map(
                      (job) => Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacing.md),
                        child: _QueueCard(
                          prefersEnglish: prefersEnglish,
                          job: job,
                          tokens: tokens,
                        ),
                      ),
                    )
                    .toList(),
              );
            }

            if (filter == AiSuggestionFilter.applied) {
              if (applied.isEmpty) {
                return _EmptyContent(
                  title: prefersEnglish
                      ? 'Nothing applied yet'
                      : '適用済みの提案はありません',
                  message: prefersEnglish
                      ? 'Accept a proposal to see the history.'
                      : '提案を適用すると履歴に残ります。',
                  onAction: () => _request(AiSuggestionMethod.balance),
                  prefersEnglish: prefersEnglish,
                );
              }
              return Column(
                children: applied
                    .map(
                      (suggestion) => Padding(
                        padding: EdgeInsets.only(bottom: tokens.spacing.md),
                        child: _SuggestionCard(
                          suggestion: suggestion,
                          prefersEnglish: prefersEnglish,
                          tokens: tokens,
                          onAccept: _accept,
                          onReject: _reject,
                        ),
                      ),
                    )
                    .toList(),
              );
            }

            if (ready.isEmpty) {
              return _EmptyContent(
                title: prefersEnglish ? 'No proposals ready' : '準備できた提案はありません',
                message: prefersEnglish
                    ? 'AI will drop proposals here once the job completes.'
                    : 'ジョブ完了後、ここに提案が届きます。',
                onAction: () => _request(AiSuggestionMethod.balance),
                prefersEnglish: prefersEnglish,
              );
            }

            return Column(
              children: ready
                  .map(
                    (suggestion) => Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.md),
                      child: _SuggestionCard(
                        suggestion: suggestion,
                        prefersEnglish: prefersEnglish,
                        tokens: tokens,
                        onAccept: _accept,
                        onReject: _reject,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _AiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AiAppBar({
    required this.queueLength,
    required this.isPolling,
    required this.prefersEnglish,
    required this.onRefresh,
  });

  final int queueLength;
  final bool isPolling;
  final bool prefersEnglish;
  final Future<void> Function() onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final badgeColor = tokens.colors.primary;
    final label = prefersEnglish ? 'AI proposals' : 'AI提案';

    return AppBar(
      centerTitle: true,
      title: Text(label),
      leading: const BackButton(),
      actions: [
        Badge.count(
          count: queueLength,
          isLabelVisible: queueLength > 0,
          backgroundColor: badgeColor,
          textColor: tokens.colors.onPrimary,
          offset: const Offset(4, -4),
          child: IconButton(
            tooltip: prefersEnglish ? 'Refresh' : '更新',
            icon: isPolling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2.2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => unawaited(onRefresh()),
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.prefersEnglish,
    required this.isRequesting,
    required this.queueLength,
    required this.onRequest,
    required this.onAlternative,
    this.rateLimitedUntil,
  });

  final bool prefersEnglish;
  final bool isRequesting;
  final int queueLength;
  final Future<void> Function() onRequest;
  final Future<void> Function() onAlternative;
  final DateTime? rateLimitedUntil;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final now = DateTime.now();
    final isRateLimited =
        rateLimitedUntil != null && now.isBefore(rateLimitedUntil!);
    final waitSeconds = isRateLimited
        ? rateLimitedUntil!.difference(now).inSeconds.clamp(1, 99)
        : null;

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: tokens.colors.primary),
              SizedBox(width: tokens.spacing.sm),
              Text(
                prefersEnglish ? 'AI refinement queue' : 'AI仕上げのキュー',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Chip(
                label: Text(
                  prefersEnglish
                      ? 'Queue: $queueLength'
                      : 'キュー: $queueLength 件',
                ),
                avatar: Icon(
                  Icons.hourglass_bottom,
                  size: 18,
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish
                ? 'Send your current draft to AI to get 2-3 proposals with diff notes.'
                : '現在のドラフトをAIに送り、2〜3件の提案と差分メモを受け取ります。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (isRateLimited) ...[
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                Icon(Icons.timer_outlined, color: tokens.colors.secondary),
                SizedBox(width: tokens.spacing.xs),
                Expanded(
                  child: Text(
                    prefersEnglish
                        ? 'Please wait $waitSeconds s before the next run.'
                        : '次の実行まで $waitSeconds 秒 お待ちください。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: tokens.spacing.md),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: [
              FilledButton.icon(
                onPressed: isRequesting || isRateLimited
                    ? null
                    : () => unawaited(onRequest()),
                icon: isRequesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.bolt),
                label: Text(prefersEnglish ? 'Generate proposals' : '提案を生成'),
              ),
              OutlinedButton.icon(
                onPressed: isRequesting || isRateLimited
                    ? null
                    : () => unawaited(onAlternative()),
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  prefersEnglish ? 'Run registrability check' : '実印向けチェック',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.prefersEnglish, required this.state});

  final bool prefersEnglish;
  final AiSuggestionsState? state;

  @override
  Widget build(BuildContext context) {
    if (state == null) return const SizedBox.shrink();
    final tokens = DesignTokensTheme.of(context);
    final now = DateTime.now();
    final updated = state!.lastUpdatedAt;

    String label() {
      if (updated == null) return prefersEnglish ? 'Pending' : '待機中';
      final minutes = now.difference(updated).inMinutes;
      if (minutes == 0) {
        return prefersEnglish ? 'Updated just now' : 'たった今更新';
      }
      return prefersEnglish ? 'Updated $minutes m ago' : '$minutes分前に更新';
    }

    return Wrap(
      spacing: tokens.spacing.sm,
      runSpacing: tokens.spacing.xs,
      children: [
        InputChip(
          label: Text(label()),
          avatar: Icon(
            Icons.schedule,
            size: 18,
            color: tokens.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if ((state?.queueLength ?? 0) > 0)
          InputChip(
            label: Text(prefersEnglish ? 'Queue running' : 'キュー処理中'),
            avatar: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(tokens.colors.primary),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.prefersEnglish,
    required this.onSelected,
  });

  final AiSuggestionFilter selected;
  final bool prefersEnglish;
  final void Function(AiSuggestionFilter) onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SegmentedButton<AiSuggestionFilter>(
      segments: [
        ButtonSegment(
          value: AiSuggestionFilter.queued,
          icon: const Icon(Icons.hourglass_bottom),
          label: Text(prefersEnglish ? 'Queued' : 'キュー'),
        ),
        ButtonSegment(
          value: AiSuggestionFilter.ready,
          icon: const Icon(Icons.visibility),
          label: Text(prefersEnglish ? 'Ready' : '比較'),
        ),
        ButtonSegment(
          value: AiSuggestionFilter.applied,
          icon: const Icon(Icons.task_alt),
          label: Text(prefersEnglish ? 'Applied' : '適用済み'),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.sm,
          ),
        ),
      ),
      onSelectionChanged: (values) => onSelected(values.first),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.prefersEnglish,
    required this.job,
    required this.tokens,
  });

  final bool prefersEnglish;
  final AiQueueItem job;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final etaSeconds = job.eta.inSeconds.clamp(0, 99);
    final label = prefersEnglish ? 'Waiting to finalize' : '確定待ち';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(tokens.colors.primary),
              ),
            ),
            SizedBox(width: tokens.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prefersEnglish ? 'Queue job' : 'キュー中ジョブ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    '$label • ${_methodLabel(job.method, prefersEnglish)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    prefersEnglish ? 'ETA ~$etaSeconds s' : '完了まで約$etaSeconds秒',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.prefersEnglish,
    required this.tokens,
    required this.onAccept,
    required this.onReject,
  });

  final AiSuggestion suggestion;
  final bool prefersEnglish;
  final DesignTokens tokens;
  final Future<void> Function(AiSuggestion) onAccept;
  final Future<void> Function(AiSuggestion) onReject;

  bool get _actionable => suggestion.status == AiSuggestionStatus.proposed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final basePreview =
        suggestion.preview.diffUrl ?? suggestion.preview.previewUrl;
    final statusLabel = _statusText(prefersEnglish);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusChip(
                  label: statusLabel,
                  status: suggestion.status,
                  tokens: tokens,
                ),
                SizedBox(width: tokens.spacing.sm),
                Chip(
                  avatar: const Icon(Icons.explore, size: 18),
                  label: Text(
                    _methodLabel(
                      suggestion.method ?? AiSuggestionMethod.balance,
                      prefersEnglish,
                    ),
                  ),
                ),
                const Spacer(),
                Text(_scoreLabel(prefersEnglish), style: textTheme.titleSmall),
              ],
            ),
            SizedBox(height: tokens.spacing.md),
            _PreviewCompare(
              beforeUrl: basePreview,
              afterUrl: suggestion.preview.previewUrl,
            ),
            SizedBox(height: tokens.spacing.sm),
            Wrap(
              spacing: tokens.spacing.xs,
              runSpacing: tokens.spacing.xs,
              children: suggestion.tags
                  .take(6)
                  .map((tag) => InputChip(label: Text(tag)))
                  .toList(),
            ),
            SizedBox(height: tokens.spacing.sm),
            ..._diffBullets(textTheme),
            SizedBox(height: tokens.spacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _actionable
                        ? () => unawaited(onAccept(suggestion))
                        : null,
                    icon: const Icon(Icons.check_circle),
                    label: Text(prefersEnglish ? 'Accept & apply' : '適用する'),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionable
                        ? () => unawaited(onReject(suggestion))
                        : null,
                    icon: const Icon(Icons.close),
                    label: Text(prefersEnglish ? 'Reject' : '却下する'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _scoreLabel(bool prefersEnglish) {
    final pct = (suggestion.score * 100).round();
    return prefersEnglish ? 'Score $pct%' : 'スコア $pct%';
  }

  List<Widget> _diffBullets(TextTheme textTheme) {
    final bulletStyle = textTheme.bodyMedium!.copyWith(
      color: tokens.colors.onSurface.withValues(alpha: 0.7),
    );
    final deltas = <String>[];

    final absolute = suggestion.delta?.absolute ?? const <String, Object?>{};
    final margin = absolute['margin'];
    if (margin != null) {
      deltas.add(
        prefersEnglish
            ? 'Expanded margin $margin mm for clarity'
            : '余白を$margin mm広げ可読性を向上',
      );
    }
    final rotation = absolute['rotation'];
    if (rotation != null) {
      deltas.add(
        prefersEnglish ? 'Adjusted rotation $rotation°' : '傾きを$rotation°調整',
      );
    }
    if (suggestion.registrability == true) {
      deltas.add(
        prefersEnglish ? 'Registrability check passed' : '公的手続き向けの要件を満たしています',
      );
    }
    if (deltas.isEmpty) {
      deltas.add(
        prefersEnglish
            ? 'Balanced strokes and improved legibility.'
            : '線のバランスと可読性を改善しました。',
      );
    }

    return deltas
        .map(
          (msg) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: bulletStyle),
                Expanded(child: Text(msg, style: bulletStyle)),
              ],
            ),
          ),
        )
        .toList();
  }

  String _statusText(bool prefersEnglish) {
    return switch (suggestion.status) {
      AiSuggestionStatus.proposed =>
        prefersEnglish ? 'Ready to review' : 'レビュー待ち',
      AiSuggestionStatus.applied => prefersEnglish ? 'Applied' : '適用済み',
      AiSuggestionStatus.accepted => prefersEnglish ? 'Accepted' : '承認済み',
      AiSuggestionStatus.rejected => prefersEnglish ? 'Rejected' : '却下済み',
      AiSuggestionStatus.expired => prefersEnglish ? 'Expired' : '期限切れ',
    };
  }
}

class _PreviewCompare extends StatefulWidget {
  const _PreviewCompare({required this.beforeUrl, required this.afterUrl});

  final String beforeUrl;
  final String afterUrl;

  @override
  State<_PreviewCompare> createState() => _PreviewCompareState();
}

class _PreviewCompareState extends State<_PreviewCompare> {
  double _fraction = 0.55;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * _fraction;
              return ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.md),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PreviewImage(url: widget.beforeUrl),
                    ClipRect(
                      clipper: _HalfClipper(width: width),
                      child: _PreviewImage(url: widget.afterUrl),
                    ),
                    Positioned(
                      left: width - 8,
                      top: 0,
                      bottom: 0,
                      child: _Handle(color: tokens.colors.primary),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Slider(
          value: _fraction,
          onChanged: (value) => setState(() => _fraction = value),
        ),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported),
      ),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  const _HalfClipper({required this.width});

  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_HalfClipper oldClipper) => oldClipper.width != width;
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Center(child: Icon(Icons.drag_indicator, color: color)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.status,
    required this.tokens,
  });

  final String label;
  final AiSuggestionStatus status;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AiSuggestionStatus.proposed => tokens.colors.surfaceVariant,
      AiSuggestionStatus.applied ||
      AiSuggestionStatus.accepted => Color.alphaBlend(
        tokens.colors.primary.withValues(alpha: 0.12),
        tokens.colors.surfaceVariant,
      ),
      AiSuggestionStatus.rejected => Color.alphaBlend(
        tokens.colors.error.withValues(alpha: 0.12),
        tokens.colors.surfaceVariant,
      ),
      AiSuggestionStatus.expired => tokens.colors.surfaceVariant.withValues(
        alpha: 0.8,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({
    required this.title,
    required this.message,
    required this.onAction,
    required this.prefersEnglish,
  });

  final String title;
  final String message;
  final Future<void> Function() onAction;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.spacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: tokens.spacing.sm),
          TextButton.icon(
            onPressed: () => unawaited(onAction()),
            icon: const Icon(Icons.auto_fix_high),
            label: Text(prefersEnglish ? 'Request AI' : 'AIに依頼する'),
          ),
        ],
      ),
    );
  }
}

String _methodLabel(AiSuggestionMethod method, bool prefersEnglish) {
  return switch (method) {
    AiSuggestionMethod.balance => prefersEnglish ? 'Balance' : 'バランス補正',
    AiSuggestionMethod.generateCandidates =>
      prefersEnglish ? 'Generate' : '候補生成',
    AiSuggestionMethod.vectorizeUpload =>
      prefersEnglish ? 'Vectorize' : 'ベクター化',
    AiSuggestionMethod.registrabilityCheck =>
      prefersEnglish ? 'Registrability' : '実印チェック',
    AiSuggestionMethod.custom => prefersEnglish ? 'Custom' : 'カスタム',
  };
}
