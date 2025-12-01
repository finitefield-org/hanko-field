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
      'localeTitle': 'Choose language & region',
      'localeSave': 'Save',
      'localeSubtitle': 'Set your preferred language',
      'localeDescription': 'Device locale: {device}',
      'localeContinue': 'Save and continue',
      'localeUseDevice': 'Use device locale',
      'personaTitle': 'Choose your persona',
      'personaSave': 'Save',
      'personaSubtitle': 'Tailor guidance to your needs',
      'personaDescription':
          'Pick the journey that best matches how you will use Hanko Field.',
      'personaContinue': 'Continue',
      'personaUseSelected': 'Save persona',
      'authTitle': 'Sign in or continue',
      'authSubtitle': 'Choose how you\'d like to continue',
      'authBody':
          'Sign in to sync designs and orders, or continue as a guest with limited features.',
      'authEmailLabel': 'Email',
      'authEmailHelper': 'Used for receipts and account recovery.',
      'authEmailRequired': 'Email is required.',
      'authEmailInvalid': 'Enter a valid email address.',
      'authPasswordLabel': 'Password',
      'authPasswordHelper': 'At least 8 characters.',
      'authPasswordTooShort': 'Password is too short.',
      'authEmailCta': 'Continue with email',
      'authAppleButton': 'Continue with Apple',
      'authGoogleButton': 'Continue with Google',
      'authGuestCta': 'Continue as guest',
      'authGuestNote':
          'Guest mode lets you browse with limited saving and checkout.',
      'authHelpTooltip': 'Need help?',
      'authHelpTitle': 'About signing in',
      'authHelpBody':
          'Use your account to keep designs and orders in sync. You can link Apple or Google later from settings.',
      'authErrorCancelled': 'Sign-in was cancelled.',
      'authErrorNetwork': 'Network unavailable. Please check your connection.',
      'authErrorInvalid': 'Credentials are invalid or expired. Try again.',
      'authErrorWrongPassword': 'Email or password is incorrect.',
      'authErrorWeakPassword': 'Password is too weak; try 8+ characters.',
      'authErrorAppleUnavailable':
          'Apple Sign-In is not available on this device.',
      'authErrorLink':
          'This email is already linked with {providers}. Sign in with that option to connect.',
      'authErrorUnknown': 'Could not sign in. Please try again.',
      'authLinkingTitle': 'Link your account',
      'authLinkPrompt':
          'Sign in with {providers} to link and keep your data together.',
      'authProviderUnknown': 'your account',
      'authProviderGoogle': 'Google',
      'authProviderApple': 'Apple',
      'authProviderEmail': 'Email',
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
      'localeTitle': '言語・地域の設定',
      'localeSave': '保存',
      'localeSubtitle': '表示言語を選択してください',
      'localeDescription': '端末の言語設定: {device}',
      'localeContinue': '保存して進む',
      'localeUseDevice': '端末の設定を使う',
      'personaTitle': 'ペルソナを選択',
      'personaSave': '保存',
      'personaSubtitle': 'あなたに合わせた案内に切り替えます',
      'personaDescription': '利用シーンに近いスタイルを選ぶと、最適なガイドを表示します。',
      'personaContinue': '次へ進む',
      'personaUseSelected': 'この設定で進む',
      'authTitle': 'ログインまたは続行',
      'authSubtitle': '利用方法を選んでください',
      'authBody': 'デザインの保存や注文にはログインが必要です。ゲストでも閲覧できます。',
      'authEmailLabel': 'メールアドレス',
      'authEmailHelper': '領収書やアカウント復旧に使用します。',
      'authEmailRequired': 'メールアドレスを入力してください。',
      'authEmailInvalid': '有効なメールアドレスを入力してください。',
      'authPasswordLabel': 'パスワード',
      'authPasswordHelper': '8文字以上で入力してください。',
      'authPasswordTooShort': 'パスワードが短すぎます。',
      'authEmailCta': 'メールで続ける',
      'authAppleButton': 'Appleで続ける',
      'authGoogleButton': 'Googleで続ける',
      'authGuestCta': 'ゲストとして続行',
      'authGuestNote': 'ゲストは閲覧のみ、保存や購入は制限されます。',
      'authHelpTooltip': 'ヘルプ',
      'authHelpTitle': 'サインインについて',
      'authHelpBody': 'アカウントでデザインや注文を安全に同期します。後から設定でApple/Googleを連携できます。',
      'authErrorCancelled': 'サインインをキャンセルしました。',
      'authErrorNetwork': 'ネットワークに接続できません。',
      'authErrorInvalid': '認証情報が無効です。もう一度お試しください。',
      'authErrorWrongPassword': 'メールアドレスまたはパスワードが正しくありません。',
      'authErrorWeakPassword': 'パスワードが弱すぎます（8文字以上推奨）。',
      'authErrorAppleUnavailable': 'この端末ではAppleでのサインインは利用できません。',
      'authErrorLink': '{providers}ですでに登録済みです。その方法でサインインして連携してください。',
      'authErrorUnknown': 'サインインできませんでした。再度お試しください。',
      'authLinkingTitle': 'アカウントを連携',
      'authLinkPrompt': '{providers}でサインインするとアカウントをまとめられます。',
      'authProviderUnknown': '既存の方法',
      'authProviderGoogle': 'Google',
      'authProviderApple': 'Apple',
      'authProviderEmail': 'メール',
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
  String get localeTitle => _string('localeTitle');
  String get localeSave => _string('localeSave');
  String get localeSubtitle => _string('localeSubtitle');
  String get localeContinue => _string('localeContinue');
  String get localeUseDevice => _string('localeUseDevice');
  String get personaTitle => _string('personaTitle');
  String get personaSave => _string('personaSave');
  String get personaSubtitle => _string('personaSubtitle');
  String get personaDescription => _string('personaDescription');
  String get personaContinue => _string('personaContinue');
  String get personaUseSelected => _string('personaUseSelected');
  String get authTitle => _string('authTitle');
  String get authSubtitle => _string('authSubtitle');
  String get authBody => _string('authBody');
  String get authEmailLabel => _string('authEmailLabel');
  String get authEmailHelper => _string('authEmailHelper');
  String get authEmailRequired => _string('authEmailRequired');
  String get authEmailInvalid => _string('authEmailInvalid');
  String get authPasswordLabel => _string('authPasswordLabel');
  String get authPasswordHelper => _string('authPasswordHelper');
  String get authPasswordTooShort => _string('authPasswordTooShort');
  String get authEmailCta => _string('authEmailCta');
  String get authAppleButton => _string('authAppleButton');
  String get authGoogleButton => _string('authGoogleButton');
  String get authGuestCta => _string('authGuestCta');
  String get authGuestNote => _string('authGuestNote');
  String get authHelpTooltip => _string('authHelpTooltip');
  String get authHelpTitle => _string('authHelpTitle');
  String get authHelpBody => _string('authHelpBody');
  String get authErrorCancelled => _string('authErrorCancelled');
  String get authErrorNetwork => _string('authErrorNetwork');
  String get authErrorInvalid => _string('authErrorInvalid');
  String get authErrorWrongPassword => _string('authErrorWrongPassword');
  String get authErrorWeakPassword => _string('authErrorWeakPassword');
  String get authErrorAppleUnavailable => _string('authErrorAppleUnavailable');
  String get authErrorUnknown => _string('authErrorUnknown');
  String get authLinkingTitle => _string('authLinkingTitle');
  String get authProviderUnknown => _string('authProviderUnknown');
  String get authProviderGoogle => _string('authProviderGoogle');
  String get authProviderApple => _string('authProviderApple');
  String get authProviderEmail => _string('authProviderEmail');

  String onboardingStepCount(int current, int total) {
    final template = _string('onboardingStepCount');
    return template
        .replaceAll('{current}', '$current')
        .replaceAll('{total}', '$total');
  }

  String authErrorLink(String providers) {
    final template = _string('authErrorLink');
    return template.replaceAll('{providers}', providers);
  }

  String authLinkPrompt(String providers) {
    final template = _string('authLinkPrompt');
    return template.replaceAll('{providers}', providers);
  }

  String localeDescription(String deviceTag) {
    final template = _string('localeDescription');
    return template.replaceAll('{device}', deviceTag);
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
