// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/firebase/firebase_providers.dart';
import 'package:app/privacy/privacy_preferences.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final firebasePerformanceProvider = Provider<FirebasePerformance>((ref) {
  final app = ref.watch(firebaseAppProvider);
  return FirebasePerformance.instanceFor(app: app);
});

final performanceMonitorProvider = Provider<PerformanceMonitor>((ref) {
  final performance = ref.watch(firebasePerformanceProvider);
  final logger = Logger('PerformanceMonitor');
  return PerformanceMonitor(ref, performance, logger);
});

final performanceMonitoringInitializerProvider = AsyncProvider<void>((
  ref,
) async {
  final performance = ref.watch(firebasePerformanceProvider);
  final preferences = await ref.watch(privacyPreferencesProvider.future);

  await performance.setPerformanceCollectionEnabled(
    preferences.analyticsAllowed,
  );

  ref.listen(privacyPreferencesProvider, (_, next) {
    if (next case AsyncData<PrivacyPreferences>(:final value)) {
      unawaited(
        performance
            .setPerformanceCollectionEnabled(value.analyticsAllowed)
            .catchError((Object error, StackTrace stack) {
              Logger('PerformanceMonitor').warning(
                'Failed to update performance collection state: $error',
                error,
                stack,
              );
            }),
      );
    }
  });
});

final performanceRouteObserverProvider = Provider<PerformanceRouteObserver>((
  ref,
) {
  final monitor = ref.watch(performanceMonitorProvider);
  return PerformanceRouteObserver(monitor);
});

class PerformanceMonitor {
  PerformanceMonitor(this._ref, this._performance, this._logger);

  final Ref _ref;
  final FirebasePerformance _performance;
  final Logger _logger;

  PerformanceTraceHandle startTrace(
    String name, {
    Map<String, String>? attributes,
  }) {
    if (!_allowSending) return PerformanceTraceHandle.disabled();

    final trace = _performance.newTrace(_sanitizeTraceName(name));
    _applyAttributes(trace, attributes);
    unawaited(
      trace.start().catchError((Object error, StackTrace stack) {
        _logger.fine(
          'Failed to start performance trace $name: $error',
          error,
          stack,
        );
      }),
    );
    return PerformanceTraceHandle(trace, _logger);
  }

  PerformanceTraceHandle startScreenLoadTrace(String screenName) {
    final traceName = 'screen_load_${_sanitizeToken(screenName)}';
    return startTrace(traceName, attributes: {'screen': screenName});
  }

  Future<HttpMetric?> startHttpMetric({
    required Uri uri,
    required String method,
    int? requestPayloadSize,
  }) async {
    if (!_allowSending) return null;

    final metric = _performance.newHttpMetric(
      uri.toString(),
      _mapHttpMethod(method),
    );
    if (requestPayloadSize != null && requestPayloadSize > 0) {
      metric.requestPayloadSize = requestPayloadSize;
    }

    try {
      await metric.start();
      return metric;
    } catch (e, stack) {
      _logger.fine(
        'Failed to start HTTP metric for $method $uri: $e',
        e,
        stack,
      );
      return null;
    }
  }

  Future<void> stopHttpMetric(
    HttpMetric? metric, {
    int? responseCode,
    int? responsePayloadSize,
    String? responseContentType,
  }) async {
    if (metric == null) return;
    if (responseCode != null) {
      metric.httpResponseCode = responseCode;
    }
    if (responsePayloadSize != null && responsePayloadSize >= 0) {
      metric.responsePayloadSize = responsePayloadSize;
    }
    if (responseContentType != null && responseContentType.isNotEmpty) {
      metric.responseContentType = responseContentType;
    }
    try {
      await metric.stop();
    } catch (e, stack) {
      _logger.fine('Failed to stop HTTP metric: $e', e, stack);
    }
  }

  bool get _allowSending =>
      _ref.watch(privacyPreferencesProvider).valueOrNull?.analyticsAllowed ??
      false;

  void _applyAttributes(Trace trace, Map<String, String>? attributes) {
    if (attributes == null || attributes.isEmpty) return;
    attributes.forEach((key, value) {
      if (value.isNotEmpty) {
        trace.putAttribute(key, value);
      }
    });
  }

  String _sanitizeTraceName(String name) {
    final sanitized = _sanitizeToken(name);
    if (sanitized.isEmpty) return 'trace';
    if (sanitized.length <= _maxTraceNameLength) return sanitized;
    return sanitized.substring(0, _maxTraceNameLength);
  }

  String _sanitizeToken(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'unknown';
    final normalized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return normalized.toLowerCase();
  }

  HttpMethod _mapHttpMethod(String method) {
    return switch (method.toUpperCase()) {
      'POST' => HttpMethod.Post,
      'PUT' => HttpMethod.Put,
      'DELETE' => HttpMethod.Delete,
      'PATCH' => HttpMethod.Patch,
      'HEAD' => HttpMethod.Head,
      'OPTIONS' => HttpMethod.Options,
      'TRACE' => HttpMethod.Trace,
      'CONNECT' => HttpMethod.Connect,
      _ => HttpMethod.Get,
    };
  }
}

class PerformanceTraceHandle {
  PerformanceTraceHandle(this._trace, this._logger);

  final Trace? _trace;
  final Logger _logger;
  bool _stopped = false;

  static PerformanceTraceHandle disabled() =>
      PerformanceTraceHandle(null, Logger('PerformanceTrace'));

  Future<void> stop({
    Map<String, int>? metrics,
    Map<String, String>? attributes,
  }) async {
    final trace = _trace;
    if (trace == null || _stopped) return;
    _stopped = true;
    if (attributes != null && attributes.isNotEmpty) {
      attributes.forEach((key, value) {
        if (value.isNotEmpty) {
          trace.putAttribute(key, value);
        }
      });
    }
    if (metrics != null && metrics.isNotEmpty) {
      metrics.forEach((key, value) {
        trace.setMetric(key, value);
      });
    }
    try {
      await trace.stop();
    } catch (e, stack) {
      _logger.fine('Failed to stop performance trace: $e', e, stack);
    }
  }
}

class PerformanceRouteObserver extends NavigatorObserver {
  PerformanceRouteObserver(this._monitor);

  final PerformanceMonitor _monitor;
  final Map<Route<dynamic>, _ScreenLoadTrace> _activeTraces = {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _startTrace(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      _activeTraces.remove(oldRoute);
    }
    if (newRoute != null) {
      _startTrace(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _activeTraces.remove(route);
    super.didRemove(route, previousRoute);
  }

  void _startTrace(Route<dynamic> route) {
    final screenName = _resolveScreenName(route);
    if (screenName == null || screenName.isEmpty) return;

    final trace = _monitor.startScreenLoadTrace(screenName);
    final stopwatch = Stopwatch()..start();
    _activeTraces[route] = _ScreenLoadTrace(trace, stopwatch);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      final entry = _activeTraces.remove(route);
      if (entry == null) return;
      entry.stopwatch.stop();
      unawaited(
        entry.trace.stop(
          metrics: {'first_frame_ms': entry.stopwatch.elapsedMilliseconds},
        ),
      );
    });
  }

  String? _resolveScreenName(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.trim().isNotEmpty) return name;
    final args = route.settings.arguments;
    if (args is String && args.trim().isNotEmpty) return args;
    final shortName = route.runtimeType.toString();
    return shortName.isEmpty ? null : shortName;
  }
}

class _ScreenLoadTrace {
  _ScreenLoadTrace(this.trace, this.stopwatch);

  final PerformanceTraceHandle trace;
  final Stopwatch stopwatch;
}

const _maxTraceNameLength = 100;
