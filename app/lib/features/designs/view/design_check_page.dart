// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message_helpers.dart';
import 'package:app/core/feedback/app_message_provider.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/registrability_models.dart';
import 'package:app/features/designs/view_model/design_check_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignCheckPage extends ConsumerStatefulWidget {
  const DesignCheckPage({super.key});

  @override
  ConsumerState<DesignCheckPage> createState() => _DesignCheckPageState();
}

class _DesignCheckPageState extends ConsumerState<DesignCheckPage> {
  int? _lastFeedbackId;
  late final ProviderSubscription<AsyncValue<RegistrabilityCheckState>>
  _feedbackCancel;

  @override
  void initState() {
    super.initState();
    _feedbackCancel = ref.container
        .listen<AsyncValue<RegistrabilityCheckState>>(
          registrabilityCheckViewModel,
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

  Future<void> _refresh() => ref.invoke(registrabilityCheckViewModel.refresh());

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(registrabilityCheckViewModel);
    final data = state.valueOrNull;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _CheckAppBar(
        prefersEnglish: prefersEnglish,
        isRefreshing: data?.isRefreshing ?? false,
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

  void _handleFeedback(RegistrabilityCheckState state) {
    final feedback = state.feedbackMessage;
    if (feedback == null) return;
    if (state.feedbackId == _lastFeedbackId) return;
    _lastFeedbackId = state.feedbackId;
    emitMessageFromText(ref.container.read(appMessageSinkProvider), feedback);
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncValue<RegistrabilityCheckState> state,
    required bool prefersEnglish,
    required DesignTokens tokens,
  }) {
    final data = state.valueOrNull;
    final loading = state is AsyncLoading<RegistrabilityCheckState>;

    if (loading && data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.all(tokens.spacing.lg),
        children: const [
          AppSkeletonBlock(height: 140),
          SizedBox(height: 12),
          AppListSkeleton(items: 4, itemHeight: 92),
        ],
      );
    }

    if (state is AsyncError<RegistrabilityCheckState> && data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.all(tokens.spacing.xl),
        children: [
          AppEmptyState(
            title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
            message: state.error.toString(),
            icon: Icons.error_outline,
            actionLabel: prefersEnglish ? 'Retry' : '再試行',
            onAction: _refresh,
          ),
        ],
      );
    }

    if (data == null) {
      return const SizedBox.shrink();
    }

    final report = data.report;
    final bannerMessage = report.hasCritical
        ? (prefersEnglish
              ? 'Conflicts detected. Adjust your design before submitting.'
              : '衝突が検知されています。提出前にデザインを調整してください。')
        : null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xxl,
      ),
      children: [
        if (bannerMessage != null) ...[
          _ConflictBanner(
            message: bannerMessage,
            prefersEnglish: prefersEnglish,
            onEdit: () => GoRouter.of(context).go(AppRoutePaths.designEditor),
          ),
          SizedBox(height: tokens.spacing.md),
        ],
        _SummaryCard(
          report: report,
          prefersEnglish: prefersEnglish,
          usingCache: data.usingCache || report.fromCache,
          onRefresh: _refresh,
          onEdit: () => GoRouter.of(context).go(AppRoutePaths.designEditor),
        ),
        SizedBox(height: tokens.spacing.lg),
        _DetailList(report: report, prefersEnglish: prefersEnglish),
        SizedBox(height: tokens.spacing.lg),
        _GuidanceCard(
          guidance: report.guidance,
          prefersEnglish: prefersEnglish,
        ),
      ],
    );
  }
}

class _CheckAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CheckAppBar({
    required this.prefersEnglish,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final bool prefersEnglish;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final title = prefersEnglish ? 'Registrability check' : '実印チェック';

    return AppBar(
      leading: const BackButton(),
      title: Text(title),
      actions: [
        IconButton(
          tooltip: prefersEnglish ? 'Re-run check' : '再チェック',
          icon: isRefreshing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.colors.onSurface,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          onPressed: isRefreshing ? null : onRefresh,
        ),
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.report,
    required this.prefersEnglish,
    required this.usingCache,
    required this.onRefresh,
    required this.onEdit,
  });

  final RegistrabilityReport report;
  final bool prefersEnglish;
  final bool usingCache;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final color = _colorForVerdict(tokens, report.verdict);
    final label = _labelForVerdict(prefersEnglish, report.verdict);
    final subtitle = StringBuffer()
      ..write(report.summary)
      ..write(
        prefersEnglish
            ? ' • Checked ${_formatTimestamp(report.checkedAt)}'
            : ' • チェック日時: ${_formatTimestamp(report.checkedAt)}',
      );

    final chips = <Widget>[
      Chip(
        avatar: Icon(_iconForVerdict(report.verdict), size: 18, color: color),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: color.withValues(alpha: 0.12),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: 0.6)),
        ),
      ),
      if (usingCache)
        Chip(
          avatar: const Icon(Icons.cloud_off, size: 18),
          label: Text(prefersEnglish ? 'Offline result' : 'キャッシュ表示'),
        ),
      if (report.isStale)
        Chip(
          avatar: const Icon(Icons.schedule, size: 18),
          label: Text(prefersEnglish ? 'Stale' : '期限切れ'),
        ),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VerdictPill(color: color),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        subtitle.toString(),
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: tokens.colors.onSurface.withValues(
                            alpha: 0.76,
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.spacing.md),
                      Wrap(
                        spacing: tokens.spacing.sm,
                        runSpacing: tokens.spacing.xs,
                        children: chips,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.md),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                  label: Text(prefersEnglish ? 'Re-run check' : '再チェック'),
                ),
                SizedBox(width: tokens.spacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  label: Text(prefersEnglish ? 'Open editor' : '編集に戻る'),
                ),
                const Spacer(),
                if (report.referenceId != null)
                  Text(
                    report.referenceId!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailList extends StatelessWidget {
  const _DetailList({required this.report, required this.prefersEnglish});

  final RegistrabilityReport report;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.sm),
          child: Text(
            prefersEnglish ? 'Checks' : 'チェック項目',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...report.findings.map(
          (finding) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: AppListTile(
              dense: true,
              leading: Icon(
                _iconForSeverity(finding.severity),
                color: _colorForBadge(tokens, finding.badge),
              ),
              title: Text(finding.title),
              subtitle: Text(finding.detail),
              trailing: Chip(
                label: Text(_labelForBadge(prefersEnglish, finding.badge)),
                backgroundColor: _colorForBadge(
                  tokens,
                  finding.badge,
                ).withValues(alpha: 0.12),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: _colorForBadge(
                      tokens,
                      finding.badge,
                    ).withValues(alpha: 0.4),
                  ),
                ),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _colorForBadge(tokens, finding.badge),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.guidance, required this.prefersEnglish});

  final List<String> guidance;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Guidance' : '調整のヒント',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          ...guidance.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.xs),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: tokens.colors.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.xs),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({
    required this.message,
    required this.prefersEnglish,
    required this.onEdit,
  });

  final String message;
  final bool prefersEnglish;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return MaterialBanner(
      content: Text(message),
      leading: Icon(Icons.warning_amber_rounded, color: tokens.colors.error),
      backgroundColor: tokens.colors.surfaceVariant,
      padding: EdgeInsets.all(tokens.spacing.md),
      actions: [
        TextButton(
          onPressed: onEdit,
          child: Text(prefersEnglish ? 'Adjust' : '調整する'),
        ),
      ],
    );
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Icon(Icons.verified, color: color),
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  return '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}

String _labelForVerdict(bool prefersEnglish, RegistrabilityVerdict verdict) {
  if (prefersEnglish) {
    switch (verdict) {
      case RegistrabilityVerdict.ok:
        return 'OK';
      case RegistrabilityVerdict.warning:
        return 'Warning';
      case RegistrabilityVerdict.fail:
        return 'Fail';
    }
  }

  switch (verdict) {
    case RegistrabilityVerdict.ok:
      return '適合';
    case RegistrabilityVerdict.warning:
      return '注意';
    case RegistrabilityVerdict.fail:
      return '要対応';
  }
}

String _labelForBadge(bool prefersEnglish, RegistrabilityBadge badge) {
  if (prefersEnglish) {
    switch (badge) {
      case RegistrabilityBadge.safe:
        return 'Safe';
      case RegistrabilityBadge.similar:
        return 'Similar';
      case RegistrabilityBadge.conflict:
        return 'Conflict';
    }
  }

  switch (badge) {
    case RegistrabilityBadge.safe:
      return '安全';
    case RegistrabilityBadge.similar:
      return '類似';
    case RegistrabilityBadge.conflict:
      return '衝突';
  }
}

Color _colorForVerdict(DesignTokens tokens, RegistrabilityVerdict verdict) {
  switch (verdict) {
    case RegistrabilityVerdict.ok:
      return tokens.colors.success;
    case RegistrabilityVerdict.warning:
      return tokens.colors.warning;
    case RegistrabilityVerdict.fail:
      return tokens.colors.error;
  }
}

Color _colorForBadge(DesignTokens tokens, RegistrabilityBadge badge) {
  switch (badge) {
    case RegistrabilityBadge.safe:
      return tokens.colors.success;
    case RegistrabilityBadge.similar:
      return tokens.colors.warning;
    case RegistrabilityBadge.conflict:
      return tokens.colors.error;
  }
}

IconData _iconForVerdict(RegistrabilityVerdict verdict) {
  switch (verdict) {
    case RegistrabilityVerdict.ok:
      return Icons.verified_user;
    case RegistrabilityVerdict.warning:
      return Icons.warning_amber_outlined;
    case RegistrabilityVerdict.fail:
      return Icons.block;
  }
}

IconData _iconForSeverity(RegistrabilitySeverity severity) {
  switch (severity) {
    case RegistrabilitySeverity.info:
      return Icons.check_circle_outline;
    case RegistrabilitySeverity.caution:
      return Icons.error_outline;
    case RegistrabilitySeverity.critical:
      return Icons.block;
  }
}
