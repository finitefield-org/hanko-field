// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/privacy/privacy_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  final app = ref.watch(firebaseAppProvider);
  return FirebaseAnalytics.instanceFor(app: app);
});

final analyticsClientProvider = Provider<AnalyticsClient>((ref) {
  final analytics = ref.watch(firebaseAnalyticsProvider);
  final logger = Logger('Analytics');
  return AnalyticsClient(ref, analytics, logger);
});

final analyticsInitializerProvider = AsyncProvider<void>((ref) async {
  final analytics = ref.watch(firebaseAnalyticsProvider);
  final preferences = await ref.watch(privacyPreferencesProvider.future);
  final flavor = ref.watch(appFlavorProvider);

  await analytics.setAnalyticsCollectionEnabled(preferences.analyticsAllowed);
  await analytics.setUserProperty(name: 'environment', value: flavor.name);

  ref.listen(privacyPreferencesProvider, (next) {
    if (next case AsyncData<PrivacyPreferences>(:final value)) {
      unawaited(
        analytics
            .setAnalyticsCollectionEnabled(value.analyticsAllowed)
            .catchError((Object error, StackTrace stack) {
              Logger('Analytics').warning(
                'Failed to update analytics collection: $error',
                error,
                stack,
              );
            }),
      );
    }
  });
});

class AnalyticsClient {
  AnalyticsClient(this._ref, this._analytics, this._logger);

  final Ref _ref;
  final FirebaseAnalytics _analytics;
  final Logger _logger;

  Future<void> track(AppAnalyticsEvent event) async {
    final consents = _ref.watch(privacyPreferencesProvider).valueOrNull;
    if (consents == null || !consents.analyticsAllowed) {
      _logger.fine(
        'Analytics suppressed (consent not granted) for ${event.name}',
      );
      return;
    }

    try {
      final parameters = event.validatedParameters();
      await _analytics.logEvent(
        name: event.name,
        parameters: parameters.isEmpty ? null : parameters,
      );
    } on ArgumentError catch (e, stack) {
      _logger.warning('Dropped analytics event ${event.name}: $e', e, stack);
    } catch (e, stack) {
      _logger.severe('Failed to log analytics event ${event.name}', e, stack);
    }
  }
}

sealed class AppAnalyticsEvent {
  const AppAnalyticsEvent();

  String get name;

  Map<String, Object?> toParameters();

  Map<String, Object> validatedParameters() {
    final raw = toParameters();
    final sanitized = <String, Object>{};

    raw.forEach((key, value) {
      if (value == null) return;
      if (_isSupportedValue(value)) {
        sanitized[key] = switch (value) {
          final String v => _truncate(v),
          _ => value,
        };
      } else {
        throw ArgumentError.value(
          value,
          key,
          'Unsupported analytics parameter type',
        );
      }
    });

    return sanitized;
  }

  bool _isSupportedValue(Object value) {
    return value is num || value is String || value is bool;
  }

  String _truncate(String value, {int maxLength = 100}) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'String parameter is empty');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'String parameter is empty');
    }
    return trimmed.substring(0, min(trimmed.length, maxLength));
  }
}

class AppOpenedEvent extends AppAnalyticsEvent {
  const AppOpenedEvent({
    required this.entryPoint,
    this.locale,
    this.region,
    this.persona,
  });

  final String entryPoint;
  final String? locale;
  final String? region;
  final String? persona;

  @override
  String get name => 'app_opened';

  @override
  Map<String, Object?> toParameters() {
    return {
      'entry_point': entryPoint,
      'locale': locale,
      'region': region,
      'persona': persona,
    };
  }
}

class PrimaryActionTappedEvent extends AppAnalyticsEvent {
  const PrimaryActionTappedEvent({required this.label});

  final String label;

  @override
  String get name => 'primary_action_tapped';

  @override
  Map<String, Object?> toParameters() => {'label': label};
}

class SecondaryActionTappedEvent extends AppAnalyticsEvent {
  const SecondaryActionTappedEvent({required this.label});

  final String label;

  @override
  String get name => 'secondary_action_tapped';

  @override
  Map<String, Object?> toParameters() => {'label': label};
}

class OnboardingStepViewedEvent extends AppAnalyticsEvent {
  const OnboardingStepViewedEvent({
    required this.step,
    required this.totalSteps,
  });

  final int step;
  final int totalSteps;

  @override
  String get name => 'onboarding_step_viewed';

  @override
  Map<String, Object?> toParameters() => {
    'step': step,
    'total_steps': totalSteps,
  };
}

class OnboardingCompletedEvent extends AppAnalyticsEvent {
  const OnboardingCompletedEvent({required this.totalSteps});

  final int totalSteps;

  @override
  String get name => 'onboarding_completed';

  @override
  Map<String, Object?> toParameters() => {'total_steps': totalSteps};
}

class OnboardingSkippedEvent extends AppAnalyticsEvent {
  const OnboardingSkippedEvent({
    required this.totalSteps,
    required this.skippedAtStep,
  });

  final int totalSteps;
  final int skippedAtStep;

  @override
  String get name => 'onboarding_skipped';

  @override
  Map<String, Object?> toParameters() => {
    'total_steps': totalSteps,
    'skipped_at_step': skippedAtStep,
  };
}
