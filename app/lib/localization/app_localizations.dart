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
      'profileTitle': 'Profile',
      'profileAvatarUpdateTooltip': 'Update profile photo',
      'profileAvatarUpdateTitle': 'Update profile photo',
      'profileAvatarUpdateBody':
          'Photo updates are coming soon. For now, you can still change your persona and manage settings here.',
      'profileAvatarUpdateOk': 'OK',
      'profileLoadFailedTitle': 'Could not load profile',
      'profileLoadFailedMessage':
          'Something went wrong while loading your profile. Please try again.',
      'profileRetry': 'Retry',
      'profileStatusSignedOut': 'Signed out',
      'profileStatusGuest': 'Guest',
      'profileStatusMember': 'Signed in',
      'profileFallbackGuestName': 'Guest',
      'profileFallbackProfileName': 'Profile',
      'profilePersonaTitle': 'Persona',
      'profilePersonaSubtitle': 'Switch guidance and recommendations.',
      'profilePersonaJapanese': 'Japan',
      'profilePersonaForeigner': 'Global',
      'profileQuickLinksTitle': 'Quick links',
      'profileQuickOrdersTitle': 'Orders',
      'profileQuickOrdersSubtitle': 'View order history',
      'profileQuickLibraryTitle': 'My seals',
      'profileQuickLibrarySubtitle': 'Saved designs',
      'profileSettingsTitle': 'Settings',
      'profileAddressesTitle': 'Addresses',
      'profileAddressesSubtitle': 'Manage shipping destinations',
      'profilePaymentsTitle': 'Payments',
      'profilePaymentsSubtitle': 'Manage saved payment methods',
      'profileNotificationsTitle': 'Notifications',
      'profileNotificationsSubtitle': 'Update notification preferences',
      'profileNotificationsHeader':
          'Choose how you want to hear from Hanko Field.',
      'profileNotificationsPushHeader': 'Push notifications',
      'profileNotificationsEmailHeader': 'Email notifications',
      'profileNotificationsDigestHeader': 'Digest frequency',
      'profileNotificationsDigestHelper':
          'How often should we send summary emails?',
      'profileNotificationsDigestDaily': 'Daily',
      'profileNotificationsDigestWeekly': 'Weekly',
      'profileNotificationsDigestMonthly': 'Monthly',
      'profileNotificationsSave': 'Save preferences',
      'profileNotificationsReset': 'Reset',
      'profileNotificationsSaved': 'Notification preferences saved.',
      'profileNotificationsSaveFailed': 'Could not save preferences.',
      'profileNotificationsLoadFailedTitle':
          'Could not load notification settings',
      'profileNotificationsCategoryOrdersTitle': 'Order updates',
      'profileNotificationsCategoryOrdersBody':
          'Shipping, production, and delivery status.',
      'profileNotificationsCategoryDesignsTitle': 'Design activity',
      'profileNotificationsCategoryDesignsBody':
          'AI suggestions, edits, and approvals.',
      'profileNotificationsCategoryPromosTitle': 'Promotions',
      'profileNotificationsCategoryPromosBody':
          'New drops, seasonal releases, and offers.',
      'profileNotificationsCategoryGuidesTitle': 'Guides & tips',
      'profileNotificationsCategoryGuidesBody':
          'How-to content and cultural insights.',
      'profileLocaleTitle': 'Language & currency',
      'profileLocaleSubtitle': 'Change language and region',
      'profileLegalTitle': 'Legal',
      'profileLegalSubtitle': 'Terms, privacy, and disclosures',
      'profileSupportTitle': 'Support',
      'profileSupportSubtitle': 'FAQ and contact options',
      'profileGuidesTitle': 'Guides',
      'profileGuidesSubtitle': 'Culture and how-to guides',
      'profileHowtoTitle': 'How to',
      'profileHowtoSubtitle': 'Tutorials and videos',
      'profileLinkedAccountsTitle': 'Linked accounts',
      'profileLinkedAccountsSubtitle': 'Connect Apple and Google',
      'profileExportTitle': 'Export data',
      'profileExportSubtitle': 'Download your account data',
      'profileDeleteTitle': 'Delete account',
      'profileDeleteSubtitle': 'Permanently delete your account',
      'profileSignInCta': 'Sign in',
      'profileAccountSecurityTitle': 'Account security',
      'profileAccountSecuritySubtitle': 'Passwords, 2FA, and linked providers',
      'profileAccountSecurityBody':
          'Security settings will appear here in a future update.',
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
      'profileTitle': 'プロフィール',
      'profileAvatarUpdateTooltip': 'プロフィール写真を変更',
      'profileAvatarUpdateTitle': 'プロフィール写真の変更',
      'profileAvatarUpdateBody': 'プロフィール写真の更新は準備中です。現在はペルソナ切替と各種設定の確認ができます。',
      'profileAvatarUpdateOk': 'OK',
      'profileLoadFailedTitle': 'プロフィールを読み込めませんでした',
      'profileLoadFailedMessage': 'プロフィールの読み込みに失敗しました。再度お試しください。',
      'profileRetry': '再試行',
      'profileStatusSignedOut': '未ログイン',
      'profileStatusGuest': 'ゲスト',
      'profileStatusMember': 'ログイン済み',
      'profileFallbackGuestName': 'ゲスト',
      'profileFallbackProfileName': 'プロフィール',
      'profilePersonaTitle': 'ペルソナ',
      'profilePersonaSubtitle': 'ガイドやおすすめ表示を切り替えます。',
      'profilePersonaJapanese': '日本向け',
      'profilePersonaForeigner': '海外向け',
      'profileQuickLinksTitle': 'クイックリンク',
      'profileQuickOrdersTitle': '注文',
      'profileQuickOrdersSubtitle': '注文履歴を確認',
      'profileQuickLibraryTitle': 'マイ印鑑',
      'profileQuickLibrarySubtitle': '保存したデザイン',
      'profileSettingsTitle': '設定',
      'profileAddressesTitle': '住所帳',
      'profileAddressesSubtitle': '配送先を管理',
      'profilePaymentsTitle': '支払い方法',
      'profilePaymentsSubtitle': '支払い手段を管理',
      'profileNotificationsTitle': '通知設定',
      'profileNotificationsSubtitle': '通知の受け取りを設定',
      'profileNotificationsHeader': 'ハンコフィールドからの通知方法を選択します。',
      'profileNotificationsPushHeader': 'プッシュ通知',
      'profileNotificationsEmailHeader': 'メール通知',
      'profileNotificationsDigestHeader': 'まとめ通知の頻度',
      'profileNotificationsDigestHelper': 'メールの配信頻度を選択してください。',
      'profileNotificationsDigestDaily': '毎日',
      'profileNotificationsDigestWeekly': '毎週',
      'profileNotificationsDigestMonthly': '毎月',
      'profileNotificationsSave': '設定を保存',
      'profileNotificationsReset': 'リセット',
      'profileNotificationsSaved': '通知設定を保存しました。',
      'profileNotificationsSaveFailed': '通知設定を保存できませんでした。',
      'profileNotificationsLoadFailedTitle': '通知設定を読み込めません',
      'profileNotificationsCategoryOrdersTitle': '注文状況',
      'profileNotificationsCategoryOrdersBody': '発送、製作、配達のステータス更新。',
      'profileNotificationsCategoryDesignsTitle': 'デザインの進捗',
      'profileNotificationsCategoryDesignsBody': 'AI提案や修正、承認の通知。',
      'profileNotificationsCategoryPromosTitle': 'キャンペーン',
      'profileNotificationsCategoryPromosBody': '新作や季節限定、特別オファー。',
      'profileNotificationsCategoryGuidesTitle': 'ガイドとヒント',
      'profileNotificationsCategoryGuidesBody': '使い方コンテンツや文化的なヒント。',
      'profileLocaleTitle': '言語と通貨',
      'profileLocaleSubtitle': '表示言語と地域設定',
      'profileLegalTitle': '規約・法務',
      'profileLegalSubtitle': '利用規約やプライバシー',
      'profileSupportTitle': 'サポート',
      'profileSupportSubtitle': 'FAQ・問い合わせ',
      'profileGuidesTitle': 'ガイド',
      'profileGuidesSubtitle': '文化と使い方の案内',
      'profileHowtoTitle': '使い方',
      'profileHowtoSubtitle': 'チュートリアルと動画',
      'profileLinkedAccountsTitle': '連携アカウント',
      'profileLinkedAccountsSubtitle': 'Apple/Google 連携',
      'profileExportTitle': 'データ出力',
      'profileExportSubtitle': 'アカウントデータをDL',
      'profileDeleteTitle': 'アカウント削除',
      'profileDeleteSubtitle': '削除手続きを進める',
      'profileSignInCta': 'ログインする',
      'profileAccountSecurityTitle': 'アカウント保護',
      'profileAccountSecuritySubtitle': 'パスワードや2FA、連携の管理',
      'profileAccountSecurityBody': 'セキュリティ設定は今後追加予定です。',
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
  String get profileTitle => _string('profileTitle');
  String get profileAvatarUpdateTooltip =>
      _string('profileAvatarUpdateTooltip');
  String get profileAvatarUpdateTitle => _string('profileAvatarUpdateTitle');
  String get profileAvatarUpdateBody => _string('profileAvatarUpdateBody');
  String get profileAvatarUpdateOk => _string('profileAvatarUpdateOk');
  String get profileLoadFailedTitle => _string('profileLoadFailedTitle');
  String get profileLoadFailedMessage => _string('profileLoadFailedMessage');
  String get profileRetry => _string('profileRetry');
  String get profileStatusSignedOut => _string('profileStatusSignedOut');
  String get profileStatusGuest => _string('profileStatusGuest');
  String get profileStatusMember => _string('profileStatusMember');
  String get profileFallbackGuestName => _string('profileFallbackGuestName');
  String get profileFallbackProfileName =>
      _string('profileFallbackProfileName');
  String get profilePersonaTitle => _string('profilePersonaTitle');
  String get profilePersonaSubtitle => _string('profilePersonaSubtitle');
  String get profilePersonaJapanese => _string('profilePersonaJapanese');
  String get profilePersonaForeigner => _string('profilePersonaForeigner');
  String get profileQuickLinksTitle => _string('profileQuickLinksTitle');
  String get profileQuickOrdersTitle => _string('profileQuickOrdersTitle');
  String get profileQuickOrdersSubtitle =>
      _string('profileQuickOrdersSubtitle');
  String get profileQuickLibraryTitle => _string('profileQuickLibraryTitle');
  String get profileQuickLibrarySubtitle =>
      _string('profileQuickLibrarySubtitle');
  String get profileSettingsTitle => _string('profileSettingsTitle');
  String get profileAddressesTitle => _string('profileAddressesTitle');
  String get profileAddressesSubtitle => _string('profileAddressesSubtitle');
  String get profilePaymentsTitle => _string('profilePaymentsTitle');
  String get profilePaymentsSubtitle => _string('profilePaymentsSubtitle');
  String get profileNotificationsTitle => _string('profileNotificationsTitle');
  String get profileNotificationsSubtitle =>
      _string('profileNotificationsSubtitle');
  String get profileNotificationsHeader =>
      _string('profileNotificationsHeader');
  String get profileNotificationsPushHeader =>
      _string('profileNotificationsPushHeader');
  String get profileNotificationsEmailHeader =>
      _string('profileNotificationsEmailHeader');
  String get profileNotificationsDigestHeader =>
      _string('profileNotificationsDigestHeader');
  String get profileNotificationsDigestHelper =>
      _string('profileNotificationsDigestHelper');
  String get profileNotificationsDigestDaily =>
      _string('profileNotificationsDigestDaily');
  String get profileNotificationsDigestWeekly =>
      _string('profileNotificationsDigestWeekly');
  String get profileNotificationsDigestMonthly =>
      _string('profileNotificationsDigestMonthly');
  String get profileNotificationsSave => _string('profileNotificationsSave');
  String get profileNotificationsReset => _string('profileNotificationsReset');
  String get profileNotificationsSaved => _string('profileNotificationsSaved');
  String get profileNotificationsSaveFailed =>
      _string('profileNotificationsSaveFailed');
  String get profileNotificationsLoadFailedTitle =>
      _string('profileNotificationsLoadFailedTitle');
  String get profileNotificationsCategoryOrdersTitle =>
      _string('profileNotificationsCategoryOrdersTitle');
  String get profileNotificationsCategoryOrdersBody =>
      _string('profileNotificationsCategoryOrdersBody');
  String get profileNotificationsCategoryDesignsTitle =>
      _string('profileNotificationsCategoryDesignsTitle');
  String get profileNotificationsCategoryDesignsBody =>
      _string('profileNotificationsCategoryDesignsBody');
  String get profileNotificationsCategoryPromosTitle =>
      _string('profileNotificationsCategoryPromosTitle');
  String get profileNotificationsCategoryPromosBody =>
      _string('profileNotificationsCategoryPromosBody');
  String get profileNotificationsCategoryGuidesTitle =>
      _string('profileNotificationsCategoryGuidesTitle');
  String get profileNotificationsCategoryGuidesBody =>
      _string('profileNotificationsCategoryGuidesBody');
  String get profileLocaleTitle => _string('profileLocaleTitle');
  String get profileLocaleSubtitle => _string('profileLocaleSubtitle');
  String get profileLegalTitle => _string('profileLegalTitle');
  String get profileLegalSubtitle => _string('profileLegalSubtitle');
  String get profileSupportTitle => _string('profileSupportTitle');
  String get profileSupportSubtitle => _string('profileSupportSubtitle');
  String get profileGuidesTitle => _string('profileGuidesTitle');
  String get profileGuidesSubtitle => _string('profileGuidesSubtitle');
  String get profileHowtoTitle => _string('profileHowtoTitle');
  String get profileHowtoSubtitle => _string('profileHowtoSubtitle');
  String get profileLinkedAccountsTitle =>
      _string('profileLinkedAccountsTitle');
  String get profileLinkedAccountsSubtitle =>
      _string('profileLinkedAccountsSubtitle');
  String get profileExportTitle => _string('profileExportTitle');
  String get profileExportSubtitle => _string('profileExportSubtitle');
  String get profileDeleteTitle => _string('profileDeleteTitle');
  String get profileDeleteSubtitle => _string('profileDeleteSubtitle');
  String get profileSignInCta => _string('profileSignInCta');
  String get profileAccountSecurityTitle =>
      _string('profileAccountSecurityTitle');
  String get profileAccountSecuritySubtitle =>
      _string('profileAccountSecuritySubtitle');
  String get profileAccountSecurityBody =>
      _string('profileAccountSecurityBody');

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
