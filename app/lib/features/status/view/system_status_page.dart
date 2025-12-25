// ignore_for_file: public_member_api_docs

import 'package:app/features/status/data/models/status_models.dart';
import 'package:app/features/status/view_model/system_status_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SystemStatusPage extends ConsumerWidget {
  const SystemStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;

    final state = ref.watch(systemStatusViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.invoke(systemStatusViewModel.refresh()),
        edgeOffset: tokens.spacing.lg,
        displacement: tokens.spacing.xl,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              pinned: true,
              backgroundColor: tokens.colors.surface,
              leading: IconButton(
                tooltip: prefersEnglish ? 'Back' : '戻る',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(prefersEnglish ? 'Status' : 'ステータス'),
              actions: [
                IconButton(
                  tooltip: prefersEnglish ? 'Refresh status' : '更新',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invoke(systemStatusViewModel.refresh()),
                ),
                SizedBox(width: tokens.spacing.sm),
              ],
            ),
            ...switch (state) {
              AsyncLoading() => [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.lg,
                    tokens.spacing.md,
                    tokens.spacing.lg,
                    tokens.spacing.xl,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: AppListSkeleton(items: 3, itemHeight: 140),
                  ),
                ),
              ],
              AsyncError(:final error) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    title: prefersEnglish
                        ? 'Unable to load status'
                        : 'ステータスを読み込めませんでした',
                    message: error.toString(),
                    icon: Icons.cloud_off_outlined,
                    actionLabel: prefersEnglish ? 'Retry' : '再試行',
                    onAction: () => ref.invoke(systemStatusViewModel.refresh()),
                  ),
                ),
              ],
              AsyncData(:final value) => _buildContent(
                context: context,
                ref: ref,
                state: value,
                prefersEnglish: prefersEnglish,
              ),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent({
    required BuildContext context,
    required WidgetRef ref,
    required SystemStatusState state,
    required bool prefersEnglish,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final snapshot = state.snapshot;

    final activeIncidents = snapshot.incidents
        .where((i) => i.isActive)
        .toList();
    final serviceIncidents = activeIncidents
        .where((i) => i.service == state.selectedService)
        .toList();

    final history = snapshot.uptimeHistory[state.selectedService] ?? [];

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.md,
          tokens.spacing.lg,
          tokens.spacing.sm,
        ),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBanner(
                prefersEnglish: prefersEnglish,
                service: state.selectedService,
                incidents: serviceIncidents,
                hasOtherIncidents:
                    serviceIncidents.length != activeIncidents.length &&
                    activeIncidents.isNotEmpty,
                updatedAt: snapshot.updatedAt,
              ),
              SizedBox(height: tokens.spacing.md),
              SegmentedButton<StatusService>(
                segments: [
                  ButtonSegment(
                    value: StatusService.api,
                    label: Text(
                      StatusService.api.label(prefersEnglish: prefersEnglish),
                    ),
                    icon: const Icon(Icons.settings_ethernet_rounded),
                  ),
                  ButtonSegment(
                    value: StatusService.app,
                    label: Text(
                      StatusService.app.label(prefersEnglish: prefersEnglish),
                    ),
                    icon: const Icon(Icons.phone_iphone_rounded),
                  ),
                  ButtonSegment(
                    value: StatusService.admin,
                    label: Text(
                      StatusService.admin.label(prefersEnglish: prefersEnglish),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                ],
                selected: {state.selectedService},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    ref.invoke(systemStatusViewModel.setService(value.first)),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
              Text(
                prefersEnglish ? 'Current incidents' : '現在の障害',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              if (serviceIncidents.isEmpty)
                AppCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: tokens.colors.success,
                      ),
                      SizedBox(width: tokens.spacing.md),
                      Expanded(
                        child: Text(
                          prefersEnglish
                              ? 'No active incidents for this service.'
                              : 'このサービスに現在の障害はありません。',
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (final incident in serviceIncidents) ...[
                      _IncidentCard(
                        incident: incident,
                        prefersEnglish: prefersEnglish,
                      ),
                      SizedBox(height: tokens.spacing.sm),
                    ],
                  ],
                ),
              SizedBox(height: tokens.spacing.lg),
              Text(
                prefersEnglish ? 'Historical uptime' : '稼働率の履歴',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              ...history.map(
                (week) => Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                  child: _UptimeWeekCard(
                    week: week,
                    prefersEnglish: prefersEnglish,
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
              _SubscriptionCard(
                prefersEnglish: prefersEnglish,
                onSubscribe: () =>
                    _showSubscriptionSnack(context, prefersEnglish),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(padding: EdgeInsets.only(bottom: tokens.spacing.xxl)),
    ];
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.prefersEnglish,
    required this.service,
    required this.incidents,
    required this.hasOtherIncidents,
    required this.updatedAt,
  });

  final bool prefersEnglish;
  final StatusService service;
  final List<StatusIncident> incidents;
  final bool hasOtherIncidents;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final severity = _highestSeverity(incidents);
    final bannerColor = _bannerColor(severity, tokens);
    final icon = _bannerIcon(severity);

    final headline = incidents.isEmpty
        ? (prefersEnglish
              ? '${service.label(prefersEnglish: true)} operational'
              : '${service.label(prefersEnglish: false)} は正常稼働中')
        : switch (severity) {
            StatusIncidentSeverity.critical =>
              prefersEnglish ? 'Major outage' : '重大な障害',
            StatusIncidentSeverity.major =>
              prefersEnglish ? 'Service disruption' : 'サービス障害',
            StatusIncidentSeverity.minor =>
              prefersEnglish ? 'Minor disruption' : '軽微な影響',
            StatusIncidentSeverity.maintenance =>
              prefersEnglish ? 'Scheduled maintenance' : '計画メンテナンス',
            null => prefersEnglish ? 'Operational' : '正常稼働',
          };

    final subtitle = incidents.isEmpty
        ? (hasOtherIncidents
              ? (prefersEnglish
                    ? 'Other services have active incidents.'
                    : '他のサービスで障害が発生しています。')
              : (prefersEnglish
                    ? 'No incidents reported in the last 24 hours.'
                    : '過去24時間に障害は報告されていません。'))
        : (prefersEnglish
              ? '${incidents.length} active incident${incidents.length == 1 ? '' : 's'}.'
              : '現在 ${incidents.length} 件の障害があります。');

    return AppCard(
      backgroundColor: bannerColor.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: bannerColor),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Updated ${_formatDateTime(updatedAt)}'
                      : '${_formatDateTime(updatedAt)} 更新',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.6),
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

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.prefersEnglish});

  final StatusIncident incident;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final severityColors = _severityColors(incident.severity, tokens);
    final stageColors = _stageColors(incident.stage, tokens);

    return Card(
      elevation: 1.5,
      shadowColor: tokens.colors.outline.withValues(alpha: 0.2),
      color: tokens.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
        side: BorderSide(color: tokens.colors.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  color: severityColors.foreground,
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Text(
                    incident.title.resolve(prefersEnglish),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              incident.summary.resolve(prefersEnglish),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.xs,
              children: [
                InputChip(
                  label: Text(
                    incident.severity.label(prefersEnglish: prefersEnglish),
                  ),
                  backgroundColor: severityColors.background,
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: severityColors.foreground,
                  ),
                  side: BorderSide(color: severityColors.foreground),
                ),
                InputChip(
                  label: Text(
                    incident.stage.label(prefersEnglish: prefersEnglish),
                  ),
                  backgroundColor: stageColors.background,
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: stageColors.foreground,
                  ),
                  side: BorderSide(color: stageColors.foreground),
                ),
                InputChip(
                  label: Text(
                    incident.service.label(prefersEnglish: prefersEnglish),
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              prefersEnglish
                  ? 'Started ${_formatDateTime(incident.startedAt)} · Updated ${_formatDateTime(incident.updatedAt)}'
                  : '${_formatDateTime(incident.startedAt)} 開始・${_formatDateTime(incident.updatedAt)} 更新',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UptimeWeekCard extends StatelessWidget {
  const _UptimeWeekCard({required this.week, required this.prefersEnglish});

  final StatusUptimeWeek week;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final days = week.days;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatWeekRange(week.weekStart, prefersEnglish, days),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: tokens.spacing.sm),
          for (var i = 0; i < days.length; i++) ...[
            _UptimeDayRow(day: days[i], prefersEnglish: prefersEnglish),
            if (i != days.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
                child: Divider(
                  color: tokens.colors.outline.withValues(alpha: 0.3),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _UptimeDayRow extends StatelessWidget {
  const _UptimeDayRow({required this.day, required this.prefersEnglish});

  final StatusUptimeDay day;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final label = _formatMonthDay(day.date);
    final uptime = '${day.uptimePercent.toStringAsFixed(2)}%';
    final indicator = _uptimeIndicator(day, tokens);

    return Row(
      children: [
        Expanded(child: Text(label)),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: indicator, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.sm),
        Text(
          uptime,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: indicator),
        ),
        SizedBox(width: tokens.spacing.sm),
        Text(
          prefersEnglish
              ? '${day.incidentCount} incident${day.incidentCount == 1 ? '' : 's'}'
              : '${day.incidentCount} 件',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.prefersEnglish,
    required this.onSubscribe,
  });

  final bool prefersEnglish;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Get updates' : '更新通知を受け取る',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            prefersEnglish
                ? 'Subscribe to real-time updates for incidents and maintenance.'
                : '障害やメンテナンスの最新情報を受け取れます。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          AppButton(
            label: prefersEnglish ? 'Notify me' : '通知を有効にする',
            leading: const Icon(Icons.notifications_active_outlined),
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: onSubscribe,
          ),
        ],
      ),
    );
  }
}

void _showSubscriptionSnack(BuildContext context, bool prefersEnglish) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        prefersEnglish
            ? 'Subscription settings are coming soon.'
            : '通知設定は近日追加予定です。',
      ),
    ),
  );
}

StatusIncidentSeverity? _highestSeverity(List<StatusIncident> incidents) {
  if (incidents.isEmpty) return null;
  if (incidents.any((i) => i.severity == StatusIncidentSeverity.critical)) {
    return StatusIncidentSeverity.critical;
  }
  if (incidents.any((i) => i.severity == StatusIncidentSeverity.major)) {
    return StatusIncidentSeverity.major;
  }
  if (incidents.any((i) => i.severity == StatusIncidentSeverity.minor)) {
    return StatusIncidentSeverity.minor;
  }
  return StatusIncidentSeverity.maintenance;
}

Color _bannerColor(StatusIncidentSeverity? severity, DesignTokens tokens) {
  return switch (severity) {
    StatusIncidentSeverity.critical => tokens.colors.error,
    StatusIncidentSeverity.major => tokens.colors.warning,
    StatusIncidentSeverity.minor => tokens.colors.warning,
    StatusIncidentSeverity.maintenance => tokens.colors.secondary,
    null => tokens.colors.success,
  };
}

IconData _bannerIcon(StatusIncidentSeverity? severity) {
  return switch (severity) {
    StatusIncidentSeverity.critical => Icons.error_outline,
    StatusIncidentSeverity.major => Icons.warning_amber_rounded,
    StatusIncidentSeverity.minor => Icons.info_outline,
    StatusIncidentSeverity.maintenance => Icons.schedule_outlined,
    null => Icons.check_circle_outline,
  };
}

({Color background, Color foreground}) _severityColors(
  StatusIncidentSeverity severity,
  DesignTokens tokens,
) {
  final base = switch (severity) {
    StatusIncidentSeverity.critical => tokens.colors.error,
    StatusIncidentSeverity.major => tokens.colors.warning,
    StatusIncidentSeverity.minor => tokens.colors.secondary,
    StatusIncidentSeverity.maintenance => tokens.colors.secondary,
  };
  return (background: base.withValues(alpha: 0.12), foreground: base);
}

({Color background, Color foreground}) _stageColors(
  StatusIncidentStage stage,
  DesignTokens tokens,
) {
  final base = switch (stage) {
    StatusIncidentStage.investigating => tokens.colors.warning,
    StatusIncidentStage.identified => tokens.colors.secondary,
    StatusIncidentStage.monitoring => tokens.colors.primary,
    StatusIncidentStage.resolved => tokens.colors.success,
  };
  return (background: base.withValues(alpha: 0.12), foreground: base);
}

Color _uptimeIndicator(StatusUptimeDay day, DesignTokens tokens) {
  if (day.incidentCount > 0 || day.uptimePercent < 99.9) {
    return tokens.colors.warning;
  }
  if (day.uptimePercent < 99.99) {
    return tokens.colors.secondary;
  }
  return tokens.colors.success;
}

String _formatDateTime(DateTime dateTime) {
  final y = dateTime.year.toString().padLeft(4, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final d = dateTime.day.toString().padLeft(2, '0');
  final hh = dateTime.hour.toString().padLeft(2, '0');
  final mm = dateTime.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String _formatMonthDay(DateTime date) {
  final m = date.month.toString();
  final d = date.day.toString().padLeft(2, '0');
  return '$m/$d';
}

String _formatWeekRange(
  DateTime weekStart,
  bool prefersEnglish,
  List<StatusUptimeDay> days,
) {
  final start = _formatMonthDay(weekStart);
  final end = _formatMonthDay(days.last.date);
  return prefersEnglish ? '$start - $end' : '$start 〜 $end';
}
