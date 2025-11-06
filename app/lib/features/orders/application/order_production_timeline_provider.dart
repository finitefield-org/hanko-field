import 'dart:async';

import 'package:app/core/domain/entities/order.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _pollingInterval = Duration(seconds: 30);
const _pipelineBuffer = Duration(hours: 6);

const Map<ProductionEventType, Duration> _stageTargetDurations = {
  ProductionEventType.queued: Duration(hours: 6),
  ProductionEventType.engraving: Duration(hours: 4),
  ProductionEventType.polishing: Duration(hours: 2),
  ProductionEventType.qc: Duration(hours: 3),
  ProductionEventType.rework: Duration(hours: 6),
  ProductionEventType.onHold: Duration(hours: 8),
  ProductionEventType.packed: Duration(hours: 2),
  ProductionEventType.canceled: Duration.zero,
};

enum ProductionStageHealth { onTrack, attention, delayed }

class ProductionTimelineStage {
  const ProductionTimelineStage({
    required this.event,
    required this.health,
    this.actualDuration,
    this.expectedDuration,
    this.timeSinceStageStart,
  });

  final ProductionEvent event;
  final ProductionStageHealth health;
  final Duration? actualDuration;
  final Duration? expectedDuration;
  final Duration? timeSinceStageStart;
}

class ProductionTimelineState {
  const ProductionTimelineState({
    required this.stages,
    required this.overallHealth,
    required this.estimatedCompletion,
    required this.delay,
  });

  final List<ProductionTimelineStage> stages;
  final ProductionStageHealth overallHealth;
  final DateTime? estimatedCompletion;
  final Duration? delay;

  ProductionTimelineStage? get currentStage {
    if (stages.isEmpty) {
      return null;
    }
    return stages.last;
  }
}

final orderProductionTimelineProvider = StreamProvider.autoDispose
    .family<ProductionTimelineState, String>((ref, orderId) {
      final repository = ref.watch(orderRepositoryProvider);
      final controller = StreamController<ProductionTimelineState>();
      Timer? timer;
      var isDisposed = false;

      Future<void> emit() async {
        if (isDisposed) {
          return;
        }
        try {
          final events = await repository.fetchProductionEvents(orderId);
          if (isDisposed) {
            return;
          }
          final state = _buildTimelineState(events, DateTime.now());
          if (!controller.isClosed) {
            controller.add(state);
          }
        } catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      }

      ref.onDispose(() {
        isDisposed = true;
        timer?.cancel();
        controller.close();
      });

      emit();

      timer = Timer.periodic(_pollingInterval, (_) {
        if (!isDisposed) {
          emit();
        }
      });

      return controller.stream;
    });

ProductionTimelineState _buildTimelineState(
  List<ProductionEvent> events,
  DateTime now,
) {
  if (events.isEmpty) {
    return const ProductionTimelineState(
      stages: <ProductionTimelineStage>[],
      overallHealth: ProductionStageHealth.onTrack,
      estimatedCompletion: null,
      delay: null,
    );
  }

  final sorted = List<ProductionEvent>.from(events)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final stages = <ProductionTimelineStage>[];
  Duration expectedElapsed = Duration.zero;
  Duration actualElapsed = Duration.zero;

  for (var index = 0; index < sorted.length; index++) {
    final event = sorted[index];
    final nextEvent = index + 1 < sorted.length ? sorted[index + 1] : null;
    final isCurrent = index == sorted.length - 1;
    final expectedDuration = _stageTargetDurations[event.type];

    Duration? actualDuration;
    if (event.durationSec != null) {
      actualDuration = Duration(seconds: event.durationSec!);
    } else if (nextEvent != null) {
      final diff = nextEvent.createdAt.difference(event.createdAt);
      if (diff.isNegative) {
        actualDuration = Duration.zero;
      } else {
        actualDuration = diff;
      }
    }

    final dwellDuration = isCurrent ? now.difference(event.createdAt) : null;
    final health = _resolveStageHealth(
      event: event,
      expectedDuration: expectedDuration,
      actualDuration: actualDuration,
      dwellDuration: dwellDuration,
      isCurrentStage: isCurrent,
    );

    stages.add(
      ProductionTimelineStage(
        event: event,
        health: health,
        actualDuration: actualDuration,
        expectedDuration: expectedDuration,
        timeSinceStageStart: dwellDuration,
      ),
    );

    if (expectedDuration != null) {
      expectedElapsed += expectedDuration;
    }
    if (actualDuration != null) {
      actualElapsed += actualDuration;
    }
  }

  final firstEventAt = sorted.first.createdAt;
  final estimatedCompletion = firstEventAt.add(
    expectedElapsed + _pipelineBuffer,
  );
  final currentStage = sorted.last;
  final dwell = now.difference(currentStage.createdAt);
  final effectiveActual = actualElapsed + dwell;
  final delay = effectiveActual - expectedElapsed;
  final normalizedDelay = delay > Duration.zero ? delay : Duration.zero;

  final overallHealth = stages.fold<ProductionStageHealth>(
    ProductionStageHealth.onTrack,
    (previous, stage) =>
        stage.health.index > previous.index ? stage.health : previous,
  );

  return ProductionTimelineState(
    stages: stages,
    overallHealth: overallHealth,
    estimatedCompletion: estimatedCompletion,
    delay: normalizedDelay == Duration.zero ? null : normalizedDelay,
  );
}

ProductionStageHealth _resolveStageHealth({
  required ProductionEvent event,
  required Duration? expectedDuration,
  required Duration? actualDuration,
  required Duration? dwellDuration,
  required bool isCurrentStage,
}) {
  if (event.type == ProductionEventType.canceled) {
    return ProductionStageHealth.delayed;
  }
  if (event.type == ProductionEventType.onHold ||
      event.type == ProductionEventType.rework) {
    return ProductionStageHealth.attention;
  }

  final qcResult = event.qcResult?.toLowerCase();
  if (qcResult == 'fail') {
    return ProductionStageHealth.delayed;
  }
  if (qcResult == 'needs_rework' || event.qcDefects.isNotEmpty) {
    return ProductionStageHealth.attention;
  }

  if (expectedDuration == null) {
    return ProductionStageHealth.onTrack;
  }

  ProductionStageHealth health = ProductionStageHealth.onTrack;

  if (actualDuration != null) {
    if (actualDuration > _scaled(expectedDuration, 1.35)) {
      health = ProductionStageHealth.delayed;
    } else if (actualDuration > _scaled(expectedDuration, 1.15)) {
      health = ProductionStageHealth.attention;
    }
  }

  if (isCurrentStage && dwellDuration != null) {
    if (dwellDuration > _scaled(expectedDuration, 1.5)) {
      health = ProductionStageHealth.delayed;
    } else if (dwellDuration > _scaled(expectedDuration, 1.2)) {
      health = ProductionStageHealth.attention;
    }
  }

  return health;
}

Duration _scaled(Duration duration, double factor) {
  return Duration(milliseconds: (duration.inMilliseconds * factor).round());
}
