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
  String get splashPreparing => _strings.splashPreparing;
  String get onboardingTitle => _strings.onboardingTitle;
  String get onboardingHeroTitle => _strings.onboardingHeroTitle;
  String get onboardingTagline => _strings.onboardingTagline;
  String get onboardingKanjiTitle => _strings.onboardingKanjiTitle;
  String get onboardingKanjiMessage => _strings.onboardingKanjiMessage;
  String get onboardingAiTitle => _strings.onboardingAiTitle;
  String get onboardingAiMessage => _strings.onboardingAiMessage;
  String get onboardingStoneTitle => _strings.onboardingStoneTitle;
  String get onboardingStoneMessage => _strings.onboardingStoneMessage;
  String get onboardingStorageTitle => _strings.onboardingStorageTitle;
  String get onboardingStorageMessage => _strings.onboardingStorageMessage;
  String get onboardingGetStarted => _strings.onboardingGetStarted;
  String get onboardingSaving => _strings.onboardingSaving;
  String get onboardingSkip => _strings.onboardingSkip;
  String get onboardingSaveError => _strings.onboardingSaveError;
  String get design => _strings.design;
  String get mySeals => _strings.mySeals;
  String get stones => _strings.stones;
  String get settings => _strings.settings;
  String get createCustomSeal => _strings.createCustomSeal;
  String get customSealDescription => _strings.customSealDescription;
  String get startDesigning => _strings.startDesigning;
  String get designNameTitle => _strings.designNameTitle;
  String get designNameIntro => _strings.designNameIntro;
  String get designNameLabel => _strings.designNameLabel;
  String get designNameHint => _strings.designNameHint;
  String get designNameHelp => _strings.designNameHelp;
  String get designGenderLabel => _strings.designGenderLabel;
  String get designGenderUnspecified => _strings.designGenderUnspecified;
  String get designGenderMale => _strings.designGenderMale;
  String get designGenderFemale => _strings.designGenderFemale;
  String get designKanjiStyleLabel => _strings.designKanjiStyleLabel;
  String get designKanjiStyleJapanese => _strings.designKanjiStyleJapanese;
  String get designKanjiStyleChinese => _strings.designKanjiStyleChinese;
  String get designKanjiStyleTaiwanese => _strings.designKanjiStyleTaiwanese;
  String get suggestKanji => _strings.suggestKanji;
  String get designKanjiTipTitle => _strings.designKanjiTipTitle;
  String get designKanjiTipMessage => _strings.designKanjiTipMessage;
  String get designCandidateReadyTitle => _strings.designCandidateReadyTitle;
  String get designCandidateReadyMessage =>
      _strings.designCandidateReadyMessage;
  String get designRequestDetails => _strings.designRequestDetails;
  String get editName => _strings.editName;
  String get designLoadingTitle => _strings.designLoadingTitle;
  String get designLoadingMessage => _strings.designLoadingMessage;
  String get designLoadingDetail => _strings.designLoadingDetail;
  String get designInvalidNameSummary => _strings.designInvalidNameSummary;
  String get designInvalidNameMessage => _strings.designInvalidNameMessage;
  String get designSuggestionErrorTitle => _strings.designSuggestionErrorTitle;
  String get designSuggestionErrorMessage =>
      _strings.designSuggestionErrorMessage;
  String get designNoKanjiTitle => _strings.designNoKanjiTitle;
  String get designNoKanjiMessage => _strings.designNoKanjiMessage;
  String get designNoKanjiRuleCharacters =>
      _strings.designNoKanjiRuleCharacters;
  String get designNoKanjiRuleCommon => _strings.designNoKanjiRuleCommon;
  String get designNoKanjiRuleEngraving => _strings.designNoKanjiRuleEngraving;
  String get designErrorTip => _strings.designErrorTip;
  String get designNoKanjiTip => _strings.designNoKanjiTip;
  String get tryAgain => _strings.tryAgain;
  String get back => _strings.back;
  String get kanjiSuggestionsTitle => _strings.kanjiSuggestionsTitle;
  String get kanjiSuggestionsMessage => _strings.kanjiSuggestionsMessage;
  String get kanjiReadingLabel => _strings.kanjiReadingLabel;
  String get kanjiMeaningLabel => _strings.kanjiMeaningLabel;
  String get kanjiImpressionLabel => _strings.kanjiImpressionLabel;
  String get kanjiReasonLabel => _strings.kanjiReasonLabel;
  String get kanjiCharacterCountLabel => _strings.kanjiCharacterCountLabel;
  String get kanjiStrokeComplexityLabel => _strings.kanjiStrokeComplexityLabel;
  String get kanjiEngravingSuitabilityLabel =>
      _strings.kanjiEngravingSuitabilityLabel;
  String get selectKanji => _strings.selectKanji;
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
  String get howItWorks => _strings.howItWorks;
  String get faq => _strings.faq;
  String get privacy => _strings.privacy;
  String get terms => _strings.terms;
  String get contact => _strings.contact;
  String get version => _strings.version;
  String get settingsLanguageTitle => _strings.settingsLanguageTitle;
  String get settingsLanguageMessage => _strings.settingsLanguageMessage;
  String get settingsLanguageEnglish => _strings.settingsLanguageEnglish;
  String get settingsLanguageJapanese => _strings.settingsLanguageJapanese;
  String get settingsFaqIntro => _strings.settingsFaqIntro;
  String get settingsVersionTitle => _strings.settingsVersionTitle;
  String settingsVersionMessage(String version) {
    return _strings.settingsVersionMessageTemplate.replaceAll(
      '{version}',
      version,
    );
  }
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
    required this.splashPreparing,
    required this.onboardingTitle,
    required this.onboardingHeroTitle,
    required this.onboardingTagline,
    required this.onboardingKanjiTitle,
    required this.onboardingKanjiMessage,
    required this.onboardingAiTitle,
    required this.onboardingAiMessage,
    required this.onboardingStoneTitle,
    required this.onboardingStoneMessage,
    required this.onboardingStorageTitle,
    required this.onboardingStorageMessage,
    required this.onboardingGetStarted,
    required this.onboardingSaving,
    required this.onboardingSkip,
    required this.onboardingSaveError,
    required this.design,
    required this.mySeals,
    required this.stones,
    required this.settings,
    required this.createCustomSeal,
    required this.customSealDescription,
    required this.startDesigning,
    required this.designNameTitle,
    required this.designNameIntro,
    required this.designNameLabel,
    required this.designNameHint,
    required this.designNameHelp,
    required this.designGenderLabel,
    required this.designGenderUnspecified,
    required this.designGenderMale,
    required this.designGenderFemale,
    required this.designKanjiStyleLabel,
    required this.designKanjiStyleJapanese,
    required this.designKanjiStyleChinese,
    required this.designKanjiStyleTaiwanese,
    required this.suggestKanji,
    required this.designKanjiTipTitle,
    required this.designKanjiTipMessage,
    required this.designCandidateReadyTitle,
    required this.designCandidateReadyMessage,
    required this.designRequestDetails,
    required this.editName,
    required this.designLoadingTitle,
    required this.designLoadingMessage,
    required this.designLoadingDetail,
    required this.designInvalidNameSummary,
    required this.designInvalidNameMessage,
    required this.designSuggestionErrorTitle,
    required this.designSuggestionErrorMessage,
    required this.designNoKanjiTitle,
    required this.designNoKanjiMessage,
    required this.designNoKanjiRuleCharacters,
    required this.designNoKanjiRuleCommon,
    required this.designNoKanjiRuleEngraving,
    required this.designErrorTip,
    required this.designNoKanjiTip,
    required this.tryAgain,
    required this.back,
    required this.kanjiSuggestionsTitle,
    required this.kanjiSuggestionsMessage,
    required this.kanjiReadingLabel,
    required this.kanjiMeaningLabel,
    required this.kanjiImpressionLabel,
    required this.kanjiReasonLabel,
    required this.kanjiCharacterCountLabel,
    required this.kanjiStrokeComplexityLabel,
    required this.kanjiEngravingSuitabilityLabel,
    required this.selectKanji,
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
    required this.howItWorks,
    required this.faq,
    required this.privacy,
    required this.terms,
    required this.contact,
    required this.version,
    required this.settingsLanguageTitle,
    required this.settingsLanguageMessage,
    required this.settingsLanguageEnglish,
    required this.settingsLanguageJapanese,
    required this.settingsFaqIntro,
    required this.settingsVersionTitle,
    required this.settingsVersionMessageTemplate,
  });

  final String appTitle;
  final String splashPreparing;
  final String onboardingTitle;
  final String onboardingHeroTitle;
  final String onboardingTagline;
  final String onboardingKanjiTitle;
  final String onboardingKanjiMessage;
  final String onboardingAiTitle;
  final String onboardingAiMessage;
  final String onboardingStoneTitle;
  final String onboardingStoneMessage;
  final String onboardingStorageTitle;
  final String onboardingStorageMessage;
  final String onboardingGetStarted;
  final String onboardingSaving;
  final String onboardingSkip;
  final String onboardingSaveError;
  final String design;
  final String mySeals;
  final String stones;
  final String settings;
  final String createCustomSeal;
  final String customSealDescription;
  final String startDesigning;
  final String designNameTitle;
  final String designNameIntro;
  final String designNameLabel;
  final String designNameHint;
  final String designNameHelp;
  final String designGenderLabel;
  final String designGenderUnspecified;
  final String designGenderMale;
  final String designGenderFemale;
  final String designKanjiStyleLabel;
  final String designKanjiStyleJapanese;
  final String designKanjiStyleChinese;
  final String designKanjiStyleTaiwanese;
  final String suggestKanji;
  final String designKanjiTipTitle;
  final String designKanjiTipMessage;
  final String designCandidateReadyTitle;
  final String designCandidateReadyMessage;
  final String designRequestDetails;
  final String editName;
  final String designLoadingTitle;
  final String designLoadingMessage;
  final String designLoadingDetail;
  final String designInvalidNameSummary;
  final String designInvalidNameMessage;
  final String designSuggestionErrorTitle;
  final String designSuggestionErrorMessage;
  final String designNoKanjiTitle;
  final String designNoKanjiMessage;
  final String designNoKanjiRuleCharacters;
  final String designNoKanjiRuleCommon;
  final String designNoKanjiRuleEngraving;
  final String designErrorTip;
  final String designNoKanjiTip;
  final String tryAgain;
  final String back;
  final String kanjiSuggestionsTitle;
  final String kanjiSuggestionsMessage;
  final String kanjiReadingLabel;
  final String kanjiMeaningLabel;
  final String kanjiImpressionLabel;
  final String kanjiReasonLabel;
  final String kanjiCharacterCountLabel;
  final String kanjiStrokeComplexityLabel;
  final String kanjiEngravingSuitabilityLabel;
  final String selectKanji;
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
  final String howItWorks;
  final String faq;
  final String privacy;
  final String terms;
  final String contact;
  final String version;
  final String settingsLanguageTitle;
  final String settingsLanguageMessage;
  final String settingsLanguageEnglish;
  final String settingsLanguageJapanese;
  final String settingsFaqIntro;
  final String settingsVersionTitle;
  final String settingsVersionMessageTemplate;
}

const _localizedValues = {
  'en': HankoLocalizations._(
    Locale('en'),
    _HankoStrings(
      appTitle: 'STONE SIGNATURE',
      splashPreparing: 'Preparing your design experience.',
      onboardingTitle: 'Welcome',
      onboardingHeroTitle: 'Create your\nseal in minutes',
      onboardingTagline: 'Personalized. Timeless.\nUniquely yours.',
      onboardingKanjiTitle: 'Choose kanji from your name',
      onboardingKanjiMessage: 'We suggest meaningful kanji based on your name.',
      onboardingAiTitle: 'Generate a seal design with AI',
      onboardingAiMessage:
          'Our AI creates beautiful, balanced seal designs just for you.',
      onboardingStoneTitle: 'Select a gemstone and order',
      onboardingStoneMessage:
          'Pick your favorite gemstone and we will craft your seal with care.',
      onboardingStorageTitle: 'Saved on this device',
      onboardingStorageMessage:
          'Saved seal designs and preview images stay on this device. Payment details and checkout secrets are never saved locally.',
      onboardingGetStarted: 'Get Started',
      onboardingSaving: 'Saving...',
      onboardingSkip: 'Skip',
      onboardingSaveError:
          'Could not save onboarding status. Please try again.',
      design: 'Design',
      mySeals: 'My Seals',
      stones: 'Stones',
      settings: 'Settings',
      createCustomSeal: 'Create your\ncustom seal',
      customSealDescription:
          'Turn your name into a\npersonalized gemstone seal.',
      startDesigning: 'Start Designing',
      designNameTitle: 'Enter Your Name',
      designNameIntro:
          "We'll suggest engraving-friendly kanji for your personal seal.",
      designNameLabel: 'Your name',
      designNameHint: 'Michael Smith',
      designNameHelp: '1-2 kanji will be suggested for a small personal seal.',
      designGenderLabel: 'Gender preference',
      designGenderUnspecified: 'No preference',
      designGenderMale: 'Masculine',
      designGenderFemale: 'Feminine',
      designKanjiStyleLabel: 'Kanji style',
      designKanjiStyleJapanese: 'Japanese style',
      designKanjiStyleChinese: 'Chinese style',
      designKanjiStyleTaiwanese: 'Taiwanese style',
      suggestKanji: 'Suggest Kanji',
      designKanjiTipTitle: 'Simple kanji work best for gemstone engraving.',
      designKanjiTipMessage:
          'Clear, balanced characters create the most beautiful and timeless results.',
      designCandidateReadyTitle: 'Ready to Suggest Kanji',
      designCandidateReadyMessage:
          'Candidate generation can now use this name and preference set.',
      designRequestDetails: 'Request details',
      editName: 'Edit Name',
      designLoadingTitle: 'Finding Kanji',
      designLoadingMessage: 'Creating engraving-friendly kanji suggestions...',
      designLoadingDetail:
          'We are considering sound, meaning, and simplicity for seal engraving.',
      designInvalidNameSummary: 'Enter your name to continue.',
      designInvalidNameMessage:
          'Please enter a valid first name or short name.',
      designSuggestionErrorTitle: "We couldn't suggest kanji",
      designSuggestionErrorMessage:
          'Something went wrong while generating kanji suggestions for your name. Please try again.',
      designNoKanjiTitle: "We couldn't find a suitable kanji",
      designNoKanjiMessage:
          'Your name did not return any kanji suggestions that fit our engraving rules.',
      designNoKanjiRuleCharacters: '1-2 characters only',
      designNoKanjiRuleCommon: 'Simple, common kanji',
      designNoKanjiRuleEngraving: 'Suitable for seal engraving',
      designErrorTip: 'Use a simple first name or short name.',
      designNoKanjiTip: 'Try a shorter name or nickname.',
      tryAgain: 'Try Again',
      back: 'Back',
      kanjiSuggestionsTitle: 'Kanji Suggestions',
      kanjiSuggestionsMessage: 'Choose the kanji that best fits your seal.',
      kanjiReadingLabel: 'Reading',
      kanjiMeaningLabel: 'Meaning',
      kanjiImpressionLabel: 'Impression',
      kanjiReasonLabel: 'Reason',
      kanjiCharacterCountLabel: 'Characters',
      kanjiStrokeComplexityLabel: 'Stroke complexity',
      kanjiEngravingSuitabilityLabel: 'Engraving suitability',
      selectKanji: 'Select Kanji',
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
      howItWorks: 'How It Works',
      faq: 'FAQ',
      privacy: 'Privacy',
      terms: 'Terms',
      contact: 'Contact',
      version: 'Version',
      settingsLanguageTitle: 'App language',
      settingsLanguageMessage:
          'Language destinations are available now. Locale switching will be connected after settings persistence is finalized.',
      settingsLanguageEnglish: 'English',
      settingsLanguageJapanese: 'Japanese',
      settingsFaqIntro:
          'Find answers to common questions about kanji selection, production, delivery, and order lookup.',
      settingsVersionTitle: 'Installed app version',
      settingsVersionMessageTemplate: 'Version {version}',
    ),
  ),
  'ja': HankoLocalizations._(
    Locale('ja'),
    _HankoStrings(
      appTitle: 'STONE SIGNATURE',
      splashPreparing: 'デザイン体験を準備しています。',
      onboardingTitle: 'ようこそ',
      onboardingHeroTitle: '数分で\n印影を作成',
      onboardingTagline: 'あなたらしく。時を超えて。\n唯一無二の印鑑へ。',
      onboardingKanjiTitle: '名前から漢字を選ぶ',
      onboardingKanjiMessage: '名前に合わせて意味のある漢字候補を提案します。',
      onboardingAiTitle: 'AIで印影を生成',
      onboardingAiMessage: '美しく整った印影デザインをAIが作成します。',
      onboardingStoneTitle: '天然石を選んで注文',
      onboardingStoneMessage: 'お気に入りの天然石を選び、職人が丁寧に制作します。',
      onboardingStorageTitle: 'この端末に保存されます',
      onboardingStorageMessage:
          '保存済み印影とプレビュー画像はこの端末に保存されます。カード情報やCheckoutの秘密情報は端末に保存しません。',
      onboardingGetStarted: 'はじめる',
      onboardingSaving: '保存中...',
      onboardingSkip: 'スキップ',
      onboardingSaveError: '初回案内の完了状態を保存できませんでした。もう一度お試しください。',
      design: 'デザイン',
      mySeals: 'マイ印影',
      stones: '石',
      settings: '設定',
      createCustomSeal: 'あなた専用の\n印影を作成',
      customSealDescription: '名前から、あなただけの\n天然石印鑑を作ります。',
      startDesigning: '作成をはじめる',
      designNameTitle: '名前を入力',
      designNameIntro: '印鑑に合う彫刻しやすい漢字を提案します。',
      designNameLabel: 'お名前',
      designNameHint: '山田 太郎',
      designNameHelp: '小さな印鑑に合う1-2文字の漢字を提案します。',
      designGenderLabel: '性別の希望',
      designGenderUnspecified: '指定なし',
      designGenderMale: '男性的',
      designGenderFemale: '女性的',
      designKanjiStyleLabel: '漢字スタイル',
      designKanjiStyleJapanese: '日本スタイル',
      designKanjiStyleChinese: '中国スタイル',
      designKanjiStyleTaiwanese: '台湾スタイル',
      suggestKanji: '漢字を提案',
      designKanjiTipTitle: '天然石の彫刻にはシンプルな漢字が適しています。',
      designKanjiTipMessage: '明快で整った文字が、美しく長く愛せる印影になります。',
      designCandidateReadyTitle: '漢字候補の準備ができました',
      designCandidateReadyMessage: 'この名前と希望条件で漢字候補生成へ進めます。',
      designRequestDetails: '入力内容',
      editName: '名前を修正',
      designLoadingTitle: '漢字を検索中',
      designLoadingMessage: '彫刻しやすい漢字候補を作成しています...',
      designLoadingDetail: '音、意味、字形の簡潔さを確認しています。',
      designInvalidNameSummary: '名前を入力してください。',
      designInvalidNameMessage: '短いお名前またはニックネームを入力してください。',
      designSuggestionErrorTitle: '漢字候補を提案できませんでした',
      designSuggestionErrorMessage: '漢字候補の生成中に問題が発生しました。もう一度お試しください。',
      designNoKanjiTitle: '条件に合う漢字が見つかりませんでした',
      designNoKanjiMessage: '入力された名前では、彫刻条件に合う漢字候補を出せませんでした。',
      designNoKanjiRuleCharacters: '1-2文字のみ',
      designNoKanjiRuleCommon: 'シンプルで一般的な漢字',
      designNoKanjiRuleEngraving: '印鑑の彫刻に適している',
      designErrorTip: '短い名またはニックネームをお試しください。',
      designNoKanjiTip: 'より短い名前やニックネームをお試しください。',
      tryAgain: 'もう一度試す',
      back: '戻る',
      kanjiSuggestionsTitle: '漢字候補',
      kanjiSuggestionsMessage: '印鑑に使う漢字を選んでください。',
      kanjiReadingLabel: '読み',
      kanjiMeaningLabel: '意味',
      kanjiImpressionLabel: '印象',
      kanjiReasonLabel: '理由',
      kanjiCharacterCountLabel: '文字数',
      kanjiStrokeComplexityLabel: '画数の複雑さ',
      kanjiEngravingSuitabilityLabel: '彫刻適性',
      selectKanji: '漢字を選択',
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
      howItWorks: '使い方',
      faq: 'FAQ',
      privacy: 'プライバシー',
      terms: '利用規約',
      contact: 'お問い合わせ',
      version: 'バージョン',
      settingsLanguageTitle: 'アプリの言語',
      settingsLanguageMessage: '言語の遷移先を用意しています。ロケール切り替えは設定保存の確定後に接続します。',
      settingsLanguageEnglish: '英語',
      settingsLanguageJapanese: '日本語',
      settingsFaqIntro: '漢字選択、製作、配送、注文照会についてのよくある質問です。',
      settingsVersionTitle: 'インストール済みアプリのバージョン',
      settingsVersionMessageTemplate: 'バージョン {version}',
    ),
  ),
};
