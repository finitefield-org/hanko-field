import 'dart:ui';

import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/preferences/pref_keys.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 地域ごとの体験モード
enum ExperienceRegion { japanDomestic, international }

@immutable
class ExperienceGate {
  const ExperienceGate({
    required this.locale,
    required this.systemLocale,
    required this.localeSource,
    required this.persona,
    required this.region,
    required this.currencyCode,
    required this.currencySymbol,
    required this.creationStages,
    required this.creationSubtitle,
    required this.shopSubtitle,
    required this.ordersSubtitle,
    required this.librarySubtitle,
    required this.profileSubtitle,
  });

  final Locale locale;
  final Locale systemLocale;
  final AppLocaleSource localeSource;
  final UserPersona persona;
  final ExperienceRegion region;
  final String currencyCode;
  final String currencySymbol;
  final List<List<String>> creationStages;
  final String creationSubtitle;
  final String shopSubtitle;
  final String ordersSubtitle;
  final String librarySubtitle;
  final String profileSubtitle;

  bool get isDomestic => region == ExperienceRegion.japanDomestic;
  bool get isInternational => region == ExperienceRegion.international;
  bool get showKanjiAssist => persona == UserPersona.foreigner;
  bool get showComplianceChecklist => persona == UserPersona.japanese;

  String get personaLabel => switch (persona) {
    UserPersona.foreigner => '海外のお客様',
    UserPersona.japanese => '日本のお客様',
  };

  String get regionLabel => isDomestic ? '国内フロー' : '国際フロー (Intl)';
}

class ExperienceGateNotifier extends AsyncNotifier<ExperienceGate> {
  @override
  Future<ExperienceGate> build() async {
    final localeState = await ref.watch(appLocaleProvider.future);
    final sessionState = await ref.watch(userSessionProvider.future);
    final prefs = await ref.watch(sharedPreferencesProvider.future);

    final persona = _resolvePersona(sessionState, prefs);
    final region = _resolveRegion(localeState.locale);
    final (currencyCode, currencySymbol) = _resolveCurrency(region);

    final creationStages = persona == UserPersona.foreigner
        ? const [
            ['new'],
            ['input'],
            ['input', 'kanji-map'],
            ['style'],
            ['editor'],
            ['preview'],
          ]
        : const [
            ['new'],
            ['input'],
            ['style'],
            ['editor'],
            ['check'],
            ['preview'],
          ];

    final creationSubtitle = persona == UserPersona.foreigner
        ? '英語 UI で漢字マッピングと文化ガイドを優先表示'
        : '実印・銀行印チェックと国内書式ガイドを含む構成';
    final shopSubtitle = region == ExperienceRegion.japanDomestic
        ? '国内素材と円建て価格を優先表示'
        : '国際配送と多通貨オプションを案内';
    final ordersSubtitle = region == ExperienceRegion.japanDomestic
        ? '国内配送と印鑑登録ステータスを追跡'
        : '国際配送と通関イベントを追跡';
    final librarySubtitle = persona == UserPersona.foreigner
        ? '漢字変換履歴と文化ノートを保存'
        : '印鑑登録可否とデザイン差分を管理';
    final profileSubtitle = persona == UserPersona.foreigner
        ? '言語・通貨・配送先を国際モードで調整'
        : '住所帳や通知、銀行印設定を管理';

    return ExperienceGate(
      locale: localeState.locale,
      systemLocale: localeState.systemLocale,
      localeSource: localeState.source,
      persona: persona,
      region: region,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      creationStages: creationStages,
      creationSubtitle: creationSubtitle,
      shopSubtitle: shopSubtitle,
      ordersSubtitle: ordersSubtitle,
      librarySubtitle: librarySubtitle,
      profileSubtitle: profileSubtitle,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  UserPersona _resolvePersona(
    UserSessionState session,
    SharedPreferences prefs,
  ) {
    if (session.status == UserSessionStatus.authenticated &&
        session.profile != null) {
      return session.profile!.persona;
    }
    final stored = prefs.getString(prefKeyUserPersonaSelection);
    if (stored != null) {
      return UserPersona.values.firstWhere(
        (value) => value.name == stored,
        orElse: () => UserPersona.japanese,
      );
    }
    return UserPersona.japanese;
  }

  ExperienceRegion _resolveRegion(Locale locale) {
    final countryCode = locale.countryCode?.toUpperCase();
    if (countryCode == 'JP') {
      return ExperienceRegion.japanDomestic;
    }
    return ExperienceRegion.international;
  }

  (String, String) _resolveCurrency(ExperienceRegion region) {
    if (region == ExperienceRegion.japanDomestic) {
      return ('JPY', '¥');
    }
    return ('USD', r'$');
  }
}

final experienceGateProvider =
    AsyncNotifierProvider<ExperienceGateNotifier, ExperienceGate>(
      ExperienceGateNotifier.new,
    );
