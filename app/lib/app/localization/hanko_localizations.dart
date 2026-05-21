import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class HankoLocalizations {
  const HankoLocalizations._(this.locale, this._strings);

  final Locale locale;
  final _HankoStrings _strings;

  static const supportedLocales = [Locale('en'), Locale('ja')];

  static const delegate = _HankoLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static HankoLocalizations of(BuildContext context) {
    return Localizations.of<HankoLocalizations>(context, HankoLocalizations) ??
        forLocale(const Locale('en'));
  }

  static HankoLocalizations forLocale(Locale locale) {
    return _localizedValues[locale.languageCode] ?? _localizedValues['en']!;
  }

  String get appTitle => _strings.appTitle;
  String get design => _strings.design;
  String get mySeals => _strings.mySeals;
  String get stones => _strings.stones;
  String get settings => _strings.settings;
  String get createCustomSeal => _strings.createCustomSeal;
  String get customSealDescription => _strings.customSealDescription;
  String get startDesigning => _strings.startDesigning;
  String get savedSeals => _strings.savedSeals;
  String get savedSealsDescription => _strings.savedSealsDescription;
  String get browseStones => _strings.browseStones;
  String get browseStonesDescription => _strings.browseStonesDescription;
  String get noSavedSeals => _strings.noSavedSeals;
  String get noSavedSealsMessage => _strings.noSavedSealsMessage;
  String get noStonesLoaded => _strings.noStonesLoaded;
  String get noStonesLoadedMessage => _strings.noStonesLoadedMessage;
  String get order => _strings.order;
  String get noActiveDraft => _strings.noActiveDraft;
  String get noActiveDraftMessage => _strings.noActiveDraftMessage;
  String get reviewSelection => _strings.reviewSelection;
  String get orderLookup => _strings.orderLookup;
  String get orderNo => _strings.orderNo;
  String get orderNoHint => _strings.orderNoHint;
  String get email => _strings.email;
  String get emailHint => _strings.emailHint;
  String get lookupOrder => _strings.lookupOrder;
  String get language => _strings.language;
  String get about => _strings.about;
  String get faq => _strings.faq;
  String get privacy => _strings.privacy;
  String get terms => _strings.terms;
  String get contact => _strings.contact;
  String get version => _strings.version;
}

extension HankoLocalizationsBuildContext on BuildContext {
  HankoLocalizations get l10n => HankoLocalizations.of(this);
}

class _HankoLocalizationsDelegate
    extends LocalizationsDelegate<HankoLocalizations> {
  const _HankoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return _localizedValues.containsKey(locale.languageCode);
  }

  @override
  Future<HankoLocalizations> load(Locale locale) {
    return SynchronousFuture(HankoLocalizations.forLocale(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<HankoLocalizations> old) {
    return false;
  }
}

class _HankoStrings {
  const _HankoStrings({
    required this.appTitle,
    required this.design,
    required this.mySeals,
    required this.stones,
    required this.settings,
    required this.createCustomSeal,
    required this.customSealDescription,
    required this.startDesigning,
    required this.savedSeals,
    required this.savedSealsDescription,
    required this.browseStones,
    required this.browseStonesDescription,
    required this.noSavedSeals,
    required this.noSavedSealsMessage,
    required this.noStonesLoaded,
    required this.noStonesLoadedMessage,
    required this.order,
    required this.noActiveDraft,
    required this.noActiveDraftMessage,
    required this.reviewSelection,
    required this.orderLookup,
    required this.orderNo,
    required this.orderNoHint,
    required this.email,
    required this.emailHint,
    required this.lookupOrder,
    required this.language,
    required this.about,
    required this.faq,
    required this.privacy,
    required this.terms,
    required this.contact,
    required this.version,
  });

  final String appTitle;
  final String design;
  final String mySeals;
  final String stones;
  final String settings;
  final String createCustomSeal;
  final String customSealDescription;
  final String startDesigning;
  final String savedSeals;
  final String savedSealsDescription;
  final String browseStones;
  final String browseStonesDescription;
  final String noSavedSeals;
  final String noSavedSealsMessage;
  final String noStonesLoaded;
  final String noStonesLoadedMessage;
  final String order;
  final String noActiveDraft;
  final String noActiveDraftMessage;
  final String reviewSelection;
  final String orderLookup;
  final String orderNo;
  final String orderNoHint;
  final String email;
  final String emailHint;
  final String lookupOrder;
  final String language;
  final String about;
  final String faq;
  final String privacy;
  final String terms;
  final String contact;
  final String version;
}

const _localizedValues = {
  'en': HankoLocalizations._(
    Locale('en'),
    _HankoStrings(
      appTitle: 'STONE SIGNATURE',
      design: 'Design',
      mySeals: 'My Seals',
      stones: 'Stones',
      settings: 'Settings',
      createCustomSeal: 'Create your\ncustom seal',
      customSealDescription:
          'Turn your name into a\npersonalized gemstone seal.',
      startDesigning: 'Start Designing',
      savedSeals: 'Saved Seals',
      savedSealsDescription: 'View and manage your\nsaved seal designs.',
      browseStones: 'Browse Stones',
      browseStonesDescription: 'Explore our collection of\nnatural gemstones.',
      noSavedSeals: 'No saved seals',
      noSavedSealsMessage:
          'Saved seal designs will appear here after you create one.',
      noStonesLoaded: 'No stones loaded',
      noStonesLoadedMessage:
          'Available one-of-a-kind stones will be shown here.',
      order: 'Order',
      noActiveDraft: 'No active draft',
      noActiveDraftMessage: 'Choose a saved seal and a stone before checkout.',
      reviewSelection: 'Review Selection',
      orderLookup: 'Order Lookup',
      orderNo: 'Order No',
      orderNoHint: 'HF-0001',
      email: 'Email',
      emailHint: 'name@example.com',
      lookupOrder: 'Lookup Order',
      language: 'Language',
      about: 'About',
      faq: 'FAQ',
      privacy: 'Privacy',
      terms: 'Terms',
      contact: 'Contact',
      version: 'Version',
    ),
  ),
  'ja': HankoLocalizations._(
    Locale('ja'),
    _HankoStrings(
      appTitle: 'STONE SIGNATURE',
      design: 'デザイン',
      mySeals: 'マイ印影',
      stones: '石',
      settings: '設定',
      createCustomSeal: 'あなた専用の\n印影を作成',
      customSealDescription: '名前から、あなただけの\n天然石印鑑を作ります。',
      startDesigning: '作成をはじめる',
      savedSeals: '保存済み印影',
      savedSealsDescription: '保存した印影デザインを\n確認・管理できます。',
      browseStones: '石を探す',
      browseStonesDescription: '天然石コレクションを\nご覧ください。',
      noSavedSeals: '保存済み印影はありません',
      noSavedSealsMessage: '作成した印影デザインがここに表示されます。',
      noStonesLoaded: '石を読み込んでいません',
      noStonesLoadedMessage: '販売中の一点物の石がここに表示されます。',
      order: '注文',
      noActiveDraft: '進行中の下書きはありません',
      noActiveDraftMessage: '注文前に保存済み印影と石を選択してください。',
      reviewSelection: '選択内容を確認',
      orderLookup: '注文照会',
      orderNo: '注文番号',
      orderNoHint: 'HF-0001',
      email: 'メールアドレス',
      emailHint: 'name@example.com',
      lookupOrder: '注文を照会',
      language: '言語',
      about: 'このアプリについて',
      faq: 'FAQ',
      privacy: 'プライバシー',
      terms: '利用規約',
      contact: 'お問い合わせ',
      version: 'バージョン',
    ),
  ),
};
