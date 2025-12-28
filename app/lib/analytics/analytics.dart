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

  ref.listen(privacyPreferencesProvider, (_, next) {
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

class HomeSectionItemTappedEvent extends AppAnalyticsEvent {
  const HomeSectionItemTappedEvent({
    required this.section,
    required this.itemId,
    this.position,
    this.persona,
    this.locale,
    this.reason,
  });

  final String section;
  final String itemId;
  final int? position;
  final String? persona;
  final String? locale;
  final String? reason;

  @override
  String get name => 'home_section_item_tapped';

  @override
  Map<String, Object?> toParameters() {
    return {
      'section': section,
      'item_id': itemId,
      'position': position,
      'persona': persona,
      'locale': locale,
      'reason': reason,
    };
  }
}

class HomeRefreshedEvent extends AppAnalyticsEvent {
  const HomeRefreshedEvent({this.persona, this.locale, this.sections});

  final String? persona;
  final String? locale;
  final List<String>? sections;

  @override
  String get name => 'home_refreshed';

  @override
  Map<String, Object?> toParameters() {
    return {
      'persona': persona,
      'locale': locale,
      'sections': sections == null || sections!.isEmpty
          ? null
          : sections!.join(','),
    };
  }
}

class DesignCreationModeSelectedEvent extends AppAnalyticsEvent {
  const DesignCreationModeSelectedEvent({
    required this.mode,
    this.filters,
    this.persona,
    this.locale,
    this.entryPoint,
  });

  final String mode;
  final List<String>? filters;
  final String? persona;
  final String? locale;
  final String? entryPoint;

  @override
  String get name => 'design_creation_mode_selected';

  @override
  Map<String, Object?> toParameters() {
    return {
      'mode': mode,
      'filters': filters == null || filters!.isEmpty
          ? null
          : filters!.join(','),
      'persona': persona,
      'locale': locale,
      'entry_point': entryPoint,
    };
  }
}

class KanjiMappingSelectedEvent extends AppAnalyticsEvent {
  const KanjiMappingSelectedEvent({
    required this.candidateId,
    required this.glyph,
    required this.query,
    this.persona,
    this.locale,
    this.bookmarked = false,
    this.fromCache = false,
  });

  final String candidateId;
  final String glyph;
  final String query;
  final String? persona;
  final String? locale;
  final bool bookmarked;
  final bool fromCache;

  @override
  String get name => 'kanji_mapping_selected';

  @override
  Map<String, Object?> toParameters() {
    return {
      'candidate_id': candidateId,
      'glyph': glyph,
      'query': query,
      'persona': persona,
      'locale': locale,
      'bookmarked': bookmarked,
      'from_cache': fromCache,
    };
  }
}

class DesignVersionRolledBackEvent extends AppAnalyticsEvent {
  const DesignVersionRolledBackEvent({
    required this.designId,
    required this.toVersion,
    required this.fromVersion,
    this.reason,
  });

  final String designId;
  final int toVersion;
  final int fromVersion;
  final String? reason;

  @override
  String get name => 'design_version_rolled_back';

  @override
  Map<String, Object?> toParameters() {
    return {
      'design_id': designId,
      'to_version': toVersion,
      'from_version': fromVersion,
      'reason': reason,
    };
  }
}

class ShopCategoryTappedEvent extends AppAnalyticsEvent {
  const ShopCategoryTappedEvent({
    required this.categoryId,
    this.position,
    this.persona,
    this.locale,
  });

  final String categoryId;
  final int? position;
  final String? persona;
  final String? locale;

  ShopCategoryTappedEvent copyWith({
    String? categoryId,
    int? position,
    String? persona,
    String? locale,
  }) {
    return ShopCategoryTappedEvent(
      categoryId: categoryId ?? this.categoryId,
      position: position ?? this.position,
      persona: persona ?? this.persona,
      locale: locale ?? this.locale,
    );
  }

  @override
  String get name => 'shop_category_tapped';

  @override
  Map<String, Object?> toParameters() {
    return {
      'category_id': categoryId,
      'position': position,
      'persona': persona,
      'locale': locale,
    };
  }
}

class ShopPromotionTappedEvent extends AppAnalyticsEvent {
  const ShopPromotionTappedEvent({
    required this.promotionId,
    this.code,
    this.position,
    this.persona,
    this.locale,
    this.entryPoint,
  });

  final String promotionId;
  final String? code;
  final int? position;
  final String? persona;
  final String? locale;
  final String? entryPoint;

  ShopPromotionTappedEvent copyWith({
    String? promotionId,
    String? code,
    int? position,
    String? persona,
    String? locale,
    String? entryPoint,
  }) {
    return ShopPromotionTappedEvent(
      promotionId: promotionId ?? this.promotionId,
      code: code ?? this.code,
      position: position ?? this.position,
      persona: persona ?? this.persona,
      locale: locale ?? this.locale,
      entryPoint: entryPoint ?? this.entryPoint,
    );
  }

  @override
  String get name => 'shop_promotion_tapped';

  @override
  Map<String, Object?> toParameters() {
    return {
      'promotion_id': promotionId,
      'code': code,
      'position': position,
      'persona': persona,
      'locale': locale,
      'entry_point': entryPoint,
    };
  }
}

class ShopMaterialTappedEvent extends AppAnalyticsEvent {
  const ShopMaterialTappedEvent({
    required this.materialId,
    this.materialType,
    this.position,
    this.persona,
    this.locale,
  });

  final String materialId;
  final String? materialType;
  final int? position;
  final String? persona;
  final String? locale;

  ShopMaterialTappedEvent copyWith({
    String? materialId,
    String? materialType,
    int? position,
    String? persona,
    String? locale,
  }) {
    return ShopMaterialTappedEvent(
      materialId: materialId ?? this.materialId,
      materialType: materialType ?? this.materialType,
      position: position ?? this.position,
      persona: persona ?? this.persona,
      locale: locale ?? this.locale,
    );
  }

  @override
  String get name => 'shop_material_tapped';

  @override
  Map<String, Object?> toParameters() {
    return {
      'material_id': materialId,
      'material_type': materialType,
      'position': position,
      'persona': persona,
      'locale': locale,
    };
  }
}

class ShopGuideTappedEvent extends AppAnalyticsEvent {
  const ShopGuideTappedEvent({
    required this.guideId,
    this.persona,
    this.locale,
  });

  final String guideId;
  final String? persona;
  final String? locale;

  ShopGuideTappedEvent copyWith({
    String? guideId,
    String? persona,
    String? locale,
  }) {
    return ShopGuideTappedEvent(
      guideId: guideId ?? this.guideId,
      persona: persona ?? this.persona,
      locale: locale ?? this.locale,
    );
  }

  @override
  String get name => 'shop_guide_tapped';

  @override
  Map<String, Object?> toParameters() {
    return {'guide_id': guideId, 'persona': persona, 'locale': locale};
  }
}

class HowtoTutorialOpenedEvent extends AppAnalyticsEvent {
  const HowtoTutorialOpenedEvent({
    required this.tutorialId,
    required this.format,
    this.topic,
    this.position,
  });

  final String tutorialId;
  final String format;
  final String? topic;
  final int? position;

  @override
  String get name => 'howto_tutorial_opened';

  @override
  Map<String, Object?> toParameters() {
    return {
      'tutorial_id': tutorialId,
      'format': format,
      'topic': topic,
      'position': position,
    };
  }
}

class HowtoTutorialProgressEvent extends AppAnalyticsEvent {
  const HowtoTutorialProgressEvent({
    required this.tutorialId,
    required this.format,
    required this.progress,
  });

  final String tutorialId;
  final String format;
  final String progress;

  @override
  String get name => 'howto_tutorial_progress';

  @override
  Map<String, Object?> toParameters() {
    return {'tutorial_id': tutorialId, 'format': format, 'progress': progress};
  }
}

class ChangelogViewedEvent extends AppAnalyticsEvent {
  const ChangelogViewedEvent({this.latestVersion, this.releaseCount});

  final String? latestVersion;
  final int? releaseCount;

  @override
  String get name => 'changelog_viewed';

  @override
  Map<String, Object?> toParameters() {
    return {'latest_version': latestVersion, 'release_count': releaseCount};
  }
}

class ChangelogFilterChangedEvent extends AppAnalyticsEvent {
  const ChangelogFilterChangedEvent({required this.filter});

  final String filter;

  @override
  String get name => 'changelog_filter_changed';

  @override
  Map<String, Object?> toParameters() => {'filter': filter};
}

class ChangelogReleaseExpandedEvent extends AppAnalyticsEvent {
  const ChangelogReleaseExpandedEvent({
    required this.version,
    required this.expanded,
  });

  final String version;
  final bool expanded;

  @override
  String get name => 'changelog_release_expanded';

  @override
  Map<String, Object?> toParameters() {
    return {'version': version, 'expanded': expanded};
  }
}

class ChangelogLearnMoreTappedEvent extends AppAnalyticsEvent {
  const ChangelogLearnMoreTappedEvent({required this.version});

  final String version;

  @override
  String get name => 'changelog_learn_more_tapped';

  @override
  Map<String, Object?> toParameters() => {'version': version};
}

class NotificationOpenedEvent extends AppAnalyticsEvent {
  const NotificationOpenedEvent({
    required this.notificationId,
    required this.route,
    required this.source,
  });

  final String notificationId;
  final String route;
  final String source;

  @override
  String get name => 'notification_opened';

  @override
  Map<String, Object?> toParameters() {
    return {
      'notification_id': notificationId,
      'route': route,
      'source': source,
    };
  }
}

class ErrorScreenViewedEvent extends AppAnalyticsEvent {
  const ErrorScreenViewedEvent({
    required this.path,
    this.code,
    this.source,
    this.locale,
    this.persona,
  });

  final String path;
  final String? code;
  final String? source;
  final String? locale;
  final String? persona;

  @override
  String get name => 'error_screen_viewed';

  @override
  Map<String, Object?> toParameters() {
    return {
      'path': path,
      'code': code,
      'source': source,
      'locale': locale,
      'persona': persona,
    };
  }
}

class DesignCreationStartedEvent extends AppAnalyticsEvent {
  const DesignCreationStartedEvent({this.locale, this.persona});

  final String? locale;
  final String? persona;

  @override
  String get name => 'design_creation_started';

  @override
  Map<String, Object?> toParameters() {
    return {'locale': locale, 'persona': persona};
  }
}

class DesignInputSavedEvent extends AppAnalyticsEvent {
  const DesignInputSavedEvent({
    required this.sourceType,
    required this.nameLength,
    required this.hasKanji,
    this.locale,
    this.persona,
  });

  final String sourceType;
  final int nameLength;
  final bool hasKanji;
  final String? locale;
  final String? persona;

  @override
  String get name => 'design_input_saved';

  @override
  Map<String, Object?> toParameters() {
    return {
      'source_type': sourceType,
      'name_length': nameLength,
      'has_kanji': hasKanji,
      'locale': locale,
      'persona': persona,
    };
  }
}

class DesignStyleSelectedEvent extends AppAnalyticsEvent {
  const DesignStyleSelectedEvent({
    required this.shape,
    required this.sizeMm,
    required this.writingStyle,
    this.templateRef,
    this.locale,
    this.persona,
  });

  final String shape;
  final double sizeMm;
  final String writingStyle;
  final String? templateRef;
  final String? locale;
  final String? persona;

  @override
  String get name => 'design_style_selected';

  @override
  Map<String, Object?> toParameters() {
    return {
      'shape': shape,
      'size_mm': sizeMm,
      'writing_style': writingStyle,
      'template_ref': templateRef,
      'locale': locale,
      'persona': persona,
    };
  }
}

class DesignEditorStartedEvent extends AppAnalyticsEvent {
  const DesignEditorStartedEvent({
    required this.layout,
    required this.shape,
    required this.sizeMm,
    required this.writingStyle,
    this.templateRef,
    this.locale,
    this.persona,
  });

  final String layout;
  final String shape;
  final double sizeMm;
  final String writingStyle;
  final String? templateRef;
  final String? locale;
  final String? persona;

  @override
  String get name => 'design_editor_started';

  @override
  Map<String, Object?> toParameters() {
    return {
      'layout': layout,
      'shape': shape,
      'size_mm': sizeMm,
      'writing_style': writingStyle,
      'template_ref': templateRef,
      'locale': locale,
      'persona': persona,
    };
  }
}

class DesignExportCompletedEvent extends AppAnalyticsEvent {
  const DesignExportCompletedEvent({
    required this.format,
    required this.destination,
    required this.fileSizeMb,
    required this.includeBleed,
    required this.includeMetadata,
    required this.transparentBackground,
    required this.watermarkOnShare,
    this.locale,
    this.persona,
  });

  final String format;
  final String destination;
  final double fileSizeMb;
  final bool includeBleed;
  final bool includeMetadata;
  final bool transparentBackground;
  final bool watermarkOnShare;
  final String? locale;
  final String? persona;

  @override
  String get name => 'design_export_completed';

  @override
  Map<String, Object?> toParameters() {
    return {
      'format': format,
      'destination': destination,
      'file_size_mb': fileSizeMb,
      'include_bleed': includeBleed,
      'include_metadata': includeMetadata,
      'transparent_background': transparentBackground,
      'watermark_on_share': watermarkOnShare,
      'locale': locale,
      'persona': persona,
    };
  }
}

class DesignExportSharedEvent extends AppAnalyticsEvent {
  const DesignExportSharedEvent({
    required this.format,
    required this.target,
    required this.includeMetadata,
    required this.watermarked,
    this.locale,
    this.persona,
  });

  final String format;
  final String target;
  final bool includeMetadata;
  final bool watermarked;
  final String? locale;
  final String? persona;

  @override
  String get name => 'design_export_shared';

  @override
  Map<String, Object?> toParameters() {
    return {
      'format': format,
      'target': target,
      'include_metadata': includeMetadata,
      'watermarked': watermarked,
      'locale': locale,
      'persona': persona,
    };
  }
}

class DesignShareOpenedEvent extends AppAnalyticsEvent {
  const DesignShareOpenedEvent({
    required this.background,
    required this.watermarkEnabled,
    required this.includeHashtags,
    this.locale,
    this.persona,
  });

  final String background;
  final bool watermarkEnabled;
  final bool includeHashtags;
  final String? locale;
  final String? persona;

  @override
  String get name => 'design_share_opened';

  @override
  Map<String, Object?> toParameters() {
    return {
      'background': background,
      'watermark_enabled': watermarkEnabled,
      'include_hashtags': includeHashtags,
      'locale': locale,
      'persona': persona,
    };
  }
}

class DesignShareBackgroundSelectedEvent extends AppAnalyticsEvent {
  const DesignShareBackgroundSelectedEvent({required this.background});

  final String background;

  @override
  String get name => 'design_share_background_selected';

  @override
  Map<String, Object?> toParameters() => {'background': background};
}

class DesignShareWatermarkToggledEvent extends AppAnalyticsEvent {
  const DesignShareWatermarkToggledEvent({required this.enabled});

  final bool enabled;

  @override
  String get name => 'design_share_watermark_toggled';

  @override
  Map<String, Object?> toParameters() => {'enabled': enabled};
}

class DesignShareHashtagsToggledEvent extends AppAnalyticsEvent {
  const DesignShareHashtagsToggledEvent({required this.enabled});

  final bool enabled;

  @override
  String get name => 'design_share_hashtags_toggled';

  @override
  Map<String, Object?> toParameters() => {'enabled': enabled};
}

class DesignShareRegeneratedEvent extends AppAnalyticsEvent {
  const DesignShareRegeneratedEvent({
    required this.background,
    required this.watermarkEnabled,
    required this.includeHashtags,
  });

  final String background;
  final bool watermarkEnabled;
  final bool includeHashtags;

  @override
  String get name => 'design_share_regenerated';

  @override
  Map<String, Object?> toParameters() {
    return {
      'background': background,
      'watermark_enabled': watermarkEnabled,
      'include_hashtags': includeHashtags,
    };
  }
}

class DesignShareSubmittedEvent extends AppAnalyticsEvent {
  const DesignShareSubmittedEvent({
    required this.target,
    required this.success,
    required this.background,
    required this.watermarkEnabled,
    required this.includeHashtags,
  });

  final String target;
  final bool success;
  final String background;
  final bool watermarkEnabled;
  final bool includeHashtags;

  @override
  String get name => 'design_share_submitted';

  @override
  Map<String, Object?> toParameters() {
    return {
      'target': target,
      'success': success,
      'background': background,
      'watermark_enabled': watermarkEnabled,
      'include_hashtags': includeHashtags,
    };
  }
}

class CheckoutStartedEvent extends AppAnalyticsEvent {
  const CheckoutStartedEvent({
    required this.itemCount,
    required this.subtotalAmount,
    required this.currency,
    required this.hasPromo,
    required this.isInternational,
  });

  final int itemCount;
  final int subtotalAmount;
  final String currency;
  final bool hasPromo;
  final bool isInternational;

  @override
  String get name => 'checkout_started';

  @override
  Map<String, Object?> toParameters() {
    return {
      'item_count': itemCount,
      'subtotal_amount': subtotalAmount,
      'currency': currency,
      'has_promo': hasPromo,
      'is_international': isInternational,
    };
  }
}

class CheckoutAddressSavedEvent extends AppAnalyticsEvent {
  const CheckoutAddressSavedEvent({
    required this.isNew,
    required this.isDefault,
    required this.country,
    required this.isInternational,
  });

  final bool isNew;
  final bool isDefault;
  final String country;
  final bool isInternational;

  @override
  String get name => 'checkout_address_saved';

  @override
  Map<String, Object?> toParameters() {
    return {
      'is_new': isNew,
      'is_default': isDefault,
      'country': country,
      'is_international': isInternational,
    };
  }
}

class CheckoutAddressConfirmedEvent extends AppAnalyticsEvent {
  const CheckoutAddressConfirmedEvent({
    required this.country,
    required this.isInternational,
    required this.addressCount,
  });

  final String country;
  final bool isInternational;
  final int addressCount;

  @override
  String get name => 'checkout_address_confirmed';

  @override
  Map<String, Object?> toParameters() {
    return {
      'country': country,
      'is_international': isInternational,
      'address_count': addressCount,
    };
  }
}

class CheckoutShippingSelectedEvent extends AppAnalyticsEvent {
  const CheckoutShippingSelectedEvent({
    required this.shippingMethodId,
    required this.carrier,
    required this.costAmount,
    required this.currency,
    required this.etaMinDays,
    required this.etaMaxDays,
    required this.isExpress,
    required this.isInternational,
    required this.focus,
    required this.hasPromo,
  });

  final String shippingMethodId;
  final String carrier;
  final int costAmount;
  final String currency;
  final int etaMinDays;
  final int etaMaxDays;
  final bool isExpress;
  final bool isInternational;
  final String focus;
  final bool hasPromo;

  @override
  String get name => 'checkout_shipping_selected';

  @override
  Map<String, Object?> toParameters() {
    return {
      'shipping_method_id': shippingMethodId,
      'carrier': carrier,
      'cost_amount': costAmount,
      'currency': currency,
      'eta_min_days': etaMinDays,
      'eta_max_days': etaMaxDays,
      'is_express': isExpress,
      'is_international': isInternational,
      'focus': focus,
      'has_promo': hasPromo,
    };
  }
}

class CheckoutPaymentSelectedEvent extends AppAnalyticsEvent {
  const CheckoutPaymentSelectedEvent({
    required this.provider,
    required this.methodType,
    required this.isDefault,
    required this.isNew,
  });

  final String provider;
  final String methodType;
  final bool isDefault;
  final bool isNew;

  @override
  String get name => 'checkout_payment_selected';

  @override
  Map<String, Object?> toParameters() {
    return {
      'provider': provider,
      'method_type': methodType,
      'is_default': isDefault,
      'is_new': isNew,
    };
  }
}

class CheckoutOrderPlacedEvent extends AppAnalyticsEvent {
  const CheckoutOrderPlacedEvent({
    required this.success,
    required this.totalAmount,
    required this.currency,
    required this.itemCount,
    required this.isInternational,
    required this.hasPromo,
    required this.shippingMethodId,
    required this.paymentMethodType,
  });

  final bool success;
  final int totalAmount;
  final String currency;
  final int itemCount;
  final bool isInternational;
  final bool hasPromo;
  final String shippingMethodId;
  final String paymentMethodType;

  @override
  String get name => 'checkout_order_placed';

  @override
  Map<String, Object?> toParameters() {
    return {
      'success': success,
      'total_amount': totalAmount,
      'currency': currency,
      'item_count': itemCount,
      'is_international': isInternational,
      'has_promo': hasPromo,
      'shipping_method_id': shippingMethodId,
      'payment_method_type': paymentMethodType,
    };
  }
}

class CheckoutCompleteViewedEvent extends AppAnalyticsEvent {
  const CheckoutCompleteViewedEvent({
    required this.totalAmount,
    required this.currency,
    required this.itemCount,
    required this.notificationStatus,
  });

  final int totalAmount;
  final String currency;
  final int itemCount;
  final String notificationStatus;

  @override
  String get name => 'checkout_complete_viewed';

  @override
  Map<String, Object?> toParameters() {
    return {
      'total_amount': totalAmount,
      'currency': currency,
      'item_count': itemCount,
      'notification_status': notificationStatus,
    };
  }
}
