// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/view_model/order_production_timeline_view_model.dart';
import 'package:app/localization/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final vm = OrderProductionTimelineViewModel(orderId: widget.orderId);
    final state = ref.watch(vm);
    final refreshState = ref.watch(vm.refreshMut);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.container.read(navigationControllerProvider).pop();
          },
        ),
        title: Text(l10n.orderProductionTitle),
        actions: [
          IconButton(
            tooltip: l10n.orderProductionRefreshTooltip,
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
            l10n: l10n,
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
    required AppLocalizations l10n,
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
          title: l10n.commonLoadFailed,
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: l10n.commonRetry,
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
                  _HealthChip(health: health, l10n: l10n),
                ],
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(
                l10n.orderProductionStatusLabel(
                  _orderStatusLabel(order.status, l10n: l10n),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (eta != null) ...[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  l10n.orderProductionEtaLabel(_formatDateTime(eta)),
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
                        l10n.orderProductionDelayedMessage,
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
          l10n.orderProductionTimelineTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.sm),
        if (events.isEmpty)
          AppEmptyState(
            title: l10n.orderProductionNoEventsTitle,
            message: l10n.orderProductionNoEventsMessage,
            icon: Icons.schedule_outlined,
            actionLabel: l10n.orderProductionNoEventsAction,
            onAction: () => unawaited(
              _refresh(
                OrderProductionTimelineViewModel(orderId: widget.orderId),
              ),
            ),
          )
        else
          ..._buildEventList(context, tokens, events, l10n: l10n),
      ],
    );
  }

  List<Widget> _buildEventList(
    BuildContext context,
    DesignTokens tokens,
    List<ProductionEvent> events, {
    required AppLocalizations l10n,
  }) {
    final widgets = <Widget>[];
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      widgets.add(
        AppListTile(
          leading: _EventIcon(type: event.type),
          title: Text(_eventTitle(event.type, l10n: l10n)),
          subtitle: _EventSubtitle(event: event, l10n: l10n),
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
  const _HealthChip({required this.health, required this.l10n});

  final _SlaHealth health;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (label, bg, fg, icon) = switch (health) {
      _SlaHealth.onTrack => (
        l10n.orderProductionHealthOnTrack,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      _SlaHealth.attention => (
        l10n.orderProductionHealthAttention,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.info_outline,
      ),
      _SlaHealth.delayed => (
        l10n.orderProductionHealthDelayed,
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
  const _EventSubtitle({required this.event, required this.l10n});

  final ProductionEvent event;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final parts = <Widget>[Text(_formatDateTime(event.createdAt))];

    final station = event.station;
    if (station != null && station.trim().isNotEmpty) {
      parts.add(
        Text(
          l10n.orderProductionEventStation(station),
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
            l10n.orderProductionEventQc(details),
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

String _eventTitle(ProductionEventType type, {required AppLocalizations l10n}) {
  return switch (type) {
    ProductionEventType.queued => l10n.orderProductionEventQueued,
    ProductionEventType.engraving => l10n.orderProductionEventEngraving,
    ProductionEventType.polishing => l10n.orderProductionEventPolishing,
    ProductionEventType.qc => l10n.orderProductionEventQualityCheck,
    ProductionEventType.packed => l10n.orderProductionEventPacked,
    ProductionEventType.onHold => l10n.orderProductionEventOnHold,
    ProductionEventType.rework => l10n.orderProductionEventRework,
    ProductionEventType.canceled => l10n.orderProductionEventCanceled,
  };
}

String _orderStatusLabel(OrderStatus status, {required AppLocalizations l10n}) {
  return switch (status) {
    OrderStatus.pendingPayment => l10n.orderDetailStatusPending,
    OrderStatus.paid => l10n.orderDetailStatusPaid,
    OrderStatus.inProduction => l10n.orderDetailStatusInProduction,
    OrderStatus.readyToShip => l10n.orderDetailStatusReadyToShip,
    OrderStatus.shipped => l10n.orderDetailStatusShipped,
    OrderStatus.delivered => l10n.orderDetailStatusDelivered,
    OrderStatus.canceled => l10n.orderDetailStatusCanceled,
    _ => l10n.orderDetailStatusProcessing,
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
