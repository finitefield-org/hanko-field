// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/view_model/order_production_timeline_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OrderProductionTimelinePage extends ConsumerStatefulWidget {
  const OrderProductionTimelinePage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderProductionTimelinePage> createState() =>
      _OrderProductionTimelinePageState();
}

class _OrderProductionTimelinePageState
    extends ConsumerState<OrderProductionTimelinePage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final vm = OrderProductionTimelineViewModel(orderId: widget.orderId);
      final current = ref.container.read(vm).valueOrNull;
      final status = current?.order.status;
      if (status != OrderStatus.inProduction &&
          status != OrderStatus.readyToShip) {
        return;
      }
      unawaited(ref.invoke(vm.refresh()));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final vm = OrderProductionTimelineViewModel(orderId: widget.orderId);
    final state = ref.watch(vm);
    final refreshState = ref.watch(vm.refreshMut);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.container.read(navigationControllerProvider).pop();
          },
        ),
        title: Text(prefersEnglish ? 'Production' : '制作進捗'),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Refresh' : '更新',
            icon: const Icon(Icons.refresh),
            onPressed: refreshState is PendingMutationState
                ? null
                : () => unawaited(_refresh(vm)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          displacement: tokens.spacing.xl,
          edgeOffset: tokens.spacing.md,
          onRefresh: () => _refresh(vm),
          child: _buildBody(
            context: context,
            state: state,
            tokens: tokens,
            prefersEnglish: prefersEnglish,
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(OrderProductionTimelineViewModel vm) {
    return ref.invoke(vm.refresh());
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncValue<OrderProductionTimelineState> state,
    required DesignTokens tokens,
    required bool prefersEnglish,
  }) {
    final loading = state is AsyncLoading<OrderProductionTimelineState>;
    final error = state is AsyncError<OrderProductionTimelineState>;
    final data = state.valueOrNull;

    if (loading && data == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 6, itemHeight: 88),
      );
    }

    if (error && data == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () => unawaited(
            _refresh(OrderProductionTimelineViewModel(orderId: widget.orderId)),
          ),
        ),
      );
    }

    final current = data;
    if (current == null) {
      return const SizedBox.shrink();
    }

    final order = current.order;
    final events = current.events;
    final eta =
        order.fulfillment?.estimatedShipDate ??
        order.fulfillment?.estimatedDeliveryDate;
    final health = _healthForEta(eta);

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
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _HealthChip(health: health, prefersEnglish: prefersEnglish),
                ],
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(
                prefersEnglish
                    ? 'Status: ${_orderStatusLabel(order.status, prefersEnglish: prefersEnglish)}'
                    : 'ステータス：${_orderStatusLabel(order.status, prefersEnglish: prefersEnglish)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (eta != null) ...[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  prefersEnglish
                      ? 'Estimated completion: ${_formatDateTime(eta)}'
                      : '完了予定：${_formatDateTime(eta)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (health == _SlaHealth.delayed) ...[
                SizedBox(height: tokens.spacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    SizedBox(width: tokens.spacing.sm),
                    Expanded(
                      child: Text(
                        prefersEnglish
                            ? 'This order is past the estimated completion date.'
                            : 'この注文は完了予定日を過ぎています。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        Text(
          prefersEnglish ? 'Timeline' : 'タイムライン',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.sm),
        if (events.isEmpty)
          AppEmptyState(
            title: prefersEnglish ? 'No events yet' : 'まだ履歴がありません',
            message: prefersEnglish
                ? 'Production updates will appear here when available.'
                : '制作状況が更新されると、ここに表示されます。',
            icon: Icons.schedule_outlined,
            actionLabel: prefersEnglish ? 'Refresh' : '更新する',
            onAction: () => unawaited(
              _refresh(
                OrderProductionTimelineViewModel(orderId: widget.orderId),
              ),
            ),
          )
        else
          ..._buildEventList(
            context,
            tokens,
            events,
            prefersEnglish: prefersEnglish,
          ),
      ],
    );
  }

  List<Widget> _buildEventList(
    BuildContext context,
    DesignTokens tokens,
    List<ProductionEvent> events, {
    required bool prefersEnglish,
  }) {
    final widgets = <Widget>[];
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      widgets.add(
        AppListTile(
          leading: _EventIcon(type: event.type),
          title: Text(_eventTitle(event.type, prefersEnglish: prefersEnglish)),
          subtitle: _EventSubtitle(
            event: event,
            prefersEnglish: prefersEnglish,
          ),
          dense: true,
        ),
      );
      if (i != events.length - 1) {
        widgets.add(SizedBox(height: tokens.spacing.sm));
      }
    }
    return widgets;
  }
}

enum _SlaHealth { onTrack, attention, delayed }

_SlaHealth _healthForEta(DateTime? eta) {
  if (eta == null) return _SlaHealth.onTrack;
  final now = DateTime.now();
  if (now.isAfter(eta)) return _SlaHealth.delayed;
  if (eta.difference(now) <= const Duration(hours: 24)) {
    return _SlaHealth.attention;
  }
  return _SlaHealth.onTrack;
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.health, required this.prefersEnglish});

  final _SlaHealth health;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (label, bg, fg, icon) = switch (health) {
      _SlaHealth.onTrack => (
        prefersEnglish ? 'On track' : '順調',
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      _SlaHealth.attention => (
        prefersEnglish ? 'Attention' : '注意',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.info_outline,
      ),
      _SlaHealth.delayed => (
        prefersEnglish ? 'Delayed' : '遅延',
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.warning_amber_outlined,
      ),
    };

    return ActionChip(
      label: Text(label),
      avatar: Icon(icon, size: 18, color: fg),
      backgroundColor: bg,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
      onPressed: () {},
    );
  }
}

class _EventIcon extends StatelessWidget {
  const _EventIcon({required this.type});

  final ProductionEventType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (type) {
      ProductionEventType.queued => Icons.schedule_outlined,
      ProductionEventType.engraving => Icons.auto_fix_high_outlined,
      ProductionEventType.polishing => Icons.cleaning_services_outlined,
      ProductionEventType.qc => Icons.fact_check_outlined,
      ProductionEventType.packed => Icons.inventory_2_outlined,
      ProductionEventType.onHold => Icons.pause_circle_outline,
      ProductionEventType.rework => Icons.build_circle_outlined,
      ProductionEventType.canceled => Icons.cancel_outlined,
    };

    final (bg, fg) = switch (type) {
      ProductionEventType.canceled => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      ProductionEventType.onHold || ProductionEventType.rework => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };

    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

class _EventSubtitle extends StatelessWidget {
  const _EventSubtitle({required this.event, required this.prefersEnglish});

  final ProductionEvent event;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final parts = <Widget>[Text(_formatDateTime(event.createdAt))];

    final station = event.station;
    if (station != null && station.trim().isNotEmpty) {
      parts.add(
        Text(
          prefersEnglish ? 'Station: $station' : '工程：$station',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final note = event.note;
    if (note != null && note.trim().isNotEmpty) {
      parts.add(Text(note, style: Theme.of(context).textTheme.bodySmall));
    }

    final qc = event.qc;
    if (qc != null) {
      final result = qc.result;
      final defects = qc.defects;
      final details = <String>[
        if (result != null && result.trim().isNotEmpty) result.trim(),
        if (defects.isNotEmpty) defects.join(', '),
      ].join(defects.isNotEmpty && result != null ? ' · ' : '');

      if (details.trim().isNotEmpty) {
        parts.add(
          Text(
            prefersEnglish ? 'QC: $details' : '検品：$details',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts) ...[
          part,
          SizedBox(height: tokens.spacing.xs),
        ],
      ],
    );
  }
}

String _eventTitle(ProductionEventType type, {required bool prefersEnglish}) {
  return switch (type) {
    ProductionEventType.queued => prefersEnglish ? 'Queued' : '受付',
    ProductionEventType.engraving => prefersEnglish ? 'Engraving' : '彫刻',
    ProductionEventType.polishing => prefersEnglish ? 'Polishing' : '研磨',
    ProductionEventType.qc => prefersEnglish ? 'Quality check' : '検品',
    ProductionEventType.packed => prefersEnglish ? 'Packed' : '梱包',
    ProductionEventType.onHold => prefersEnglish ? 'On hold' : '保留',
    ProductionEventType.rework => prefersEnglish ? 'Rework' : '再加工',
    ProductionEventType.canceled => prefersEnglish ? 'Canceled' : 'キャンセル',
  };
}

String _orderStatusLabel(OrderStatus status, {required bool prefersEnglish}) {
  return switch (status) {
    OrderStatus.pendingPayment => prefersEnglish ? 'Pending' : '未払い',
    OrderStatus.paid => prefersEnglish ? 'Paid' : '支払い済み',
    OrderStatus.inProduction => prefersEnglish ? 'In production' : '制作中',
    OrderStatus.readyToShip => prefersEnglish ? 'Ready to ship' : '発送準備中',
    OrderStatus.shipped => prefersEnglish ? 'Shipped' : '発送済み',
    OrderStatus.delivered => prefersEnglish ? 'Delivered' : '配達済み',
    OrderStatus.canceled => prefersEnglish ? 'Canceled' : 'キャンセル',
    _ => prefersEnglish ? 'Processing' : '処理中',
  };
}

String _formatDateTime(DateTime dateTime) {
  final y = dateTime.year.toString().padLeft(4, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final d = dateTime.day.toString().padLeft(2, '0');
  final hh = dateTime.hour.toString().padLeft(2, '0');
  final mm = dateTime.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
