// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Application localization without ARB for type safety.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('ja')];

  static const supportedLanguageCodes = <String>{'en', 'ja'};

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'appTitle': 'Hanko Field',
      'welcomeHeadline': 'Craft your seal, your way',
      'welcomeBody':
          'Localization, theming, and tokens are ready to power every screen.',
      'primaryAction': 'Get started',
      'secondaryAction': 'Browse designs',
      'onboardingTitle': 'Welcome tour',
      'onboardingSkip': 'Skip',
      'onboardingNext': 'Next',
      'onboardingBack': 'Back',
      'onboardingFinish': 'Start setup',
      'onboardingRetry': 'Try again',
      'onboardingErrorTitle': 'Could not load onboarding',
      'onboardingStepCount': 'Step {current} of {total}',
      'onboardingSlideCreateTitle': 'Design without guesswork',
      'onboardingSlideCreateBody':
          'Preview scripts, spacing, and layout with guided templates built for hanko.',
      'onboardingSlideCreateTagline': 'Create',
      'onboardingSlideMaterialsTitle': 'Pick the right materials',
      'onboardingSlideMaterialsBody':
          'Compare woods, stones, and metals with availability and recommendations.',
      'onboardingSlideMaterialsTagline': 'Shop',
      'onboardingSlideSupportTitle': 'Guided all the way',
      'onboardingSlideSupportBody':
          'Save progress, resume on web, and reach support if you get stuck.',
      'onboardingSlideSupportTagline': 'Assist',
    },
    'ja': {
      'appTitle': 'ハンコフィールド',
      'welcomeHeadline': 'あなたらしい印鑑をつくる',
      'welcomeBody': 'ローカライズ、テーマ、デザイントークンの準備ができました。',
      'primaryAction': 'はじめる',
      'secondaryAction': 'デザインを見る',
      'onboardingTitle': 'チュートリアル',
      'onboardingSkip': 'スキップ',
      'onboardingNext': '次へ',
      'onboardingBack': '戻る',
      'onboardingFinish': '設定を進める',
      'onboardingRetry': '再読み込み',
      'onboardingErrorTitle': 'チュートリアルを読み込めませんでした',
      'onboardingStepCount': '{total} ステップ中 {current} ステップ目',
      'onboardingSlideCreateTitle': '迷わずつくれるデザイン',
      'onboardingSlideCreateBody': '書体・バランスをプレビューしながら、印鑑に合うテンプレを提案します。',
      'onboardingSlideCreateTagline': '作成',
      'onboardingSlideMaterialsTitle': '素材選びもかんたん',
      'onboardingSlideMaterialsBody': '木・石・金属の特徴や在庫状況を比較し、おすすめを提示します。',
      'onboardingSlideMaterialsTagline': 'ショップ',
      'onboardingSlideSupportTitle': 'サポート付きで安心',
      'onboardingSlideSupportBody': '途中保存やWebとの連携ができ、困ったらすぐに相談できます。',
      'onboardingSlideSupportTagline': 'サポート',
    },
  };

  static AppLocalizations of(BuildContext context) {
    final localizations = maybeOf(context);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static Locale resolveLocale(Locale? locale, Iterable<Locale> supported) {
    if (locale == null) {
      return supported.first;
    }

    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
    return supported.first;
  }

  String get appTitle => _string('appTitle');
  String get welcomeHeadline => _string('welcomeHeadline');
  String get welcomeBody => _string('welcomeBody');
  String get primaryAction => _string('primaryAction');
  String get secondaryAction => _string('secondaryAction');
  String get onboardingTitle => _string('onboardingTitle');
  String get onboardingSkip => _string('onboardingSkip');
  String get onboardingNext => _string('onboardingNext');
  String get onboardingBack => _string('onboardingBack');
  String get onboardingFinish => _string('onboardingFinish');
  String get onboardingRetry => _string('onboardingRetry');
  String get onboardingErrorTitle => _string('onboardingErrorTitle');
  String get onboardingSlideCreateTitle =>
      _string('onboardingSlideCreateTitle');
  String get onboardingSlideCreateBody => _string('onboardingSlideCreateBody');
  String get onboardingSlideCreateTagline =>
      _string('onboardingSlideCreateTagline');
  String get onboardingSlideMaterialsTitle =>
      _string('onboardingSlideMaterialsTitle');
  String get onboardingSlideMaterialsBody =>
      _string('onboardingSlideMaterialsBody');
  String get onboardingSlideMaterialsTagline =>
      _string('onboardingSlideMaterialsTagline');
  String get onboardingSlideSupportTitle =>
      _string('onboardingSlideSupportTitle');
  String get onboardingSlideSupportBody =>
      _string('onboardingSlideSupportBody');
  String get onboardingSlideSupportTagline =>
      _string('onboardingSlideSupportTagline');

  String onboardingStepCount(int current, int total) {
    final template = _string('onboardingStepCount');
    return template
        .replaceAll('{current}', '$current')
        .replaceAll('{total}', '$total');
  }

  String _string(String key) {
    final language = _resolveLanguageCode(locale);
    final table = _localizedValues[language] ?? _localizedValues['en']!;
    return table[key] ?? _localizedValues['en']![key]!;
  }

  String _resolveLanguageCode(Locale locale) {
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      return locale.languageCode;
    }
    return 'en';
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
