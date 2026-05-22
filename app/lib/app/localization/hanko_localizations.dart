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
  String get kanjiCandidateDetailTitle => _strings.kanjiCandidateDetailTitle;
  String get kanjiCandidateDetailMessage =>
      _strings.kanjiCandidateDetailMessage;
  String get kanjiReadingLabel => _strings.kanjiReadingLabel;
  String get kanjiMeaningLabel => _strings.kanjiMeaningLabel;
  String get kanjiImpressionLabel => _strings.kanjiImpressionLabel;
  String get kanjiReasonLabel => _strings.kanjiReasonLabel;
  String get kanjiCharacterCountLabel => _strings.kanjiCharacterCountLabel;
  String get kanjiStrokeComplexityLabel => _strings.kanjiStrokeComplexityLabel;
  String get kanjiEngravingSuitabilityLabel =>
      _strings.kanjiEngravingSuitabilityLabel;
  String get selectKanji => _strings.selectKanji;
  String get kanjiSelectedTitle => _strings.kanjiSelectedTitle;
  String get kanjiSelectedMessage => _strings.kanjiSelectedMessage;
  String get sealStyleTitle => _strings.sealStyleTitle;
  String get sealStyleMessage => _strings.sealStyleMessage;
  String get sealStyleSelectedKanjiLabel =>
      _strings.sealStyleSelectedKanjiLabel;
  String get sealShapeLabel => _strings.sealShapeLabel;
  String get sealShapeSquare => _strings.sealShapeSquare;
  String get sealShapeRound => _strings.sealShapeRound;
  String get sealStyleNameLabel => _strings.sealStyleNameLabel;
  String get sealStyleTraditional => _strings.sealStyleTraditional;
  String get sealStyleElegant => _strings.sealStyleElegant;
  String get sealStyleSoft => _strings.sealStyleSoft;
  String get sealStyleBold => _strings.sealStyleBold;
  String get sealStrokeWeightLabel => _strings.sealStrokeWeightLabel;
  String get sealStrokeStandard => _strings.sealStrokeStandard;
  String get sealStrokeBold => _strings.sealStrokeBold;
  String get sealBalanceLabel => _strings.sealBalanceLabel;
  String get sealBalanceAiry => _strings.sealBalanceAiry;
  String get sealBalanceBalanced => _strings.sealBalanceBalanced;
  String get sealBalanceDense => _strings.sealBalanceDense;
  String get sealStyleSummaryTitle => _strings.sealStyleSummaryTitle;
  String get confirmStyle => _strings.confirmStyle;
  String get sealStyleConfirmedTitle => _strings.sealStyleConfirmedTitle;
  String get sealStyleConfirmedMessage => _strings.sealStyleConfirmedMessage;
  String get generateSeal => _strings.generateSeal;
  String get sealGenerationLoadingTitle => _strings.sealGenerationLoadingTitle;
  String get sealGenerationLoadingMessage =>
      _strings.sealGenerationLoadingMessage;
  String get sealGenerationLoadingDetail =>
      _strings.sealGenerationLoadingDetail;
  String get sealGenerationErrorTitle => _strings.sealGenerationErrorTitle;
  String get sealGenerationErrorMessage => _strings.sealGenerationErrorMessage;
  String get sealGenerationLimitTitle => _strings.sealGenerationLimitTitle;
  String get sealGenerationLimitMessage => _strings.sealGenerationLimitMessage;
  String get sealGenerationAttemptLabel => _strings.sealGenerationAttemptLabel;
  String get sealGenerationStyleDetails => _strings.sealGenerationStyleDetails;
  String get sealGenerationErrorTip => _strings.sealGenerationErrorTip;
  String get sealGenerationLimitTip => _strings.sealGenerationLimitTip;
  String get adjustStyle => _strings.adjustStyle;
  String get sealVariantSelectionTitle => _strings.sealVariantSelectionTitle;
  String get sealVariantSelectionMessage =>
      _strings.sealVariantSelectionMessage;
  String get sealVariantSelectionDetail => _strings.sealVariantSelectionDetail;
  String get sealVariantSelectedBadge => _strings.sealVariantSelectedBadge;
  String get sealVariantSelectedTitle => _strings.sealVariantSelectedTitle;
  String get sealVariantSelectedMessage => _strings.sealVariantSelectedMessage;
  String get sealPreviewTitle => _strings.sealPreviewTitle;
  String get sealPreviewMessage => _strings.sealPreviewMessage;
  String get sealPreviewRulesNote => _strings.sealPreviewRulesNote;
  String get sealPreviewVariantLabel => _strings.sealPreviewVariantLabel;
  String get sealPreviewStorageLabel => _strings.sealPreviewStorageLabel;
  String get saveSeal => _strings.saveSeal;
  String get chooseStone => _strings.chooseStone;
  String get sealSavedTitle => _strings.sealSavedTitle;
  String get sealSavedHeading => _strings.sealSavedHeading;
  String get sealSavedMessage => _strings.sealSavedMessage;
  String get goToMySeals => _strings.goToMySeals;
  String get createAnotherSeal => _strings.createAnotherSeal;
  String get savedSeals => _strings.savedSeals;
  String get savedSealsDescription => _strings.savedSealsDescription;
  String get savedOnThisDevice => _strings.savedOnThisDevice;
  String get savedSealsLoadingTitle => _strings.savedSealsLoadingTitle;
  String get savedSealsLoadingMessage => _strings.savedSealsLoadingMessage;
  String get savedSealsLoadErrorTitle => _strings.savedSealsLoadErrorTitle;
  String get savedSealsLoadErrorMessage => _strings.savedSealsLoadErrorMessage;
  String get chooseSavedSeal => _strings.chooseSavedSeal;
  String get viewSealDetails => _strings.viewSealDetails;
  String get sealDetailTitle => _strings.sealDetailTitle;
  String get kanjiLabel => _strings.kanjiLabel;
  String get createdAtLabel => _strings.createdAtLabel;
  String get compareSavedSeals => _strings.compareSavedSeals;
  String get compareSavedSealsTitle => _strings.compareSavedSealsTitle;
  String get compareSavedSealsMessage => _strings.compareSavedSealsMessage;
  String get editSavedSeal => _strings.editSavedSeal;
  String get editSavedSealTitle => _strings.editSavedSealTitle;
  String get editSavedSealMessage => _strings.editSavedSealMessage;
  String get chooseSealForOrder => _strings.chooseSealForOrder;
  String get sealSelectedForOrderTitle => _strings.sealSelectedForOrderTitle;
  String get sealSelectedForOrderMessage =>
      _strings.sealSelectedForOrderMessage;
  String get sealSelectedForOrderAction => _strings.sealSelectedForOrderAction;
  String get deleteSavedSeal => _strings.deleteSavedSeal;
  String get deleteSealTitle => _strings.deleteSealTitle;
  String get deleteSealMessage => _strings.deleteSealMessage;
  String get deleteSealConfirm => _strings.deleteSealConfirm;
  String get cancel => _strings.cancel;
  String get close => _strings.close;
  String get browseStones => _strings.browseStones;
  String get browseStonesDescription => _strings.browseStonesDescription;
  String get noSavedSeals => _strings.noSavedSeals;
  String get noSavedSealsMessage => _strings.noSavedSealsMessage;
  String get stonesLoadingTitle => _strings.stonesLoadingTitle;
  String get stonesLoadingMessage => _strings.stonesLoadingMessage;
  String get stonesLoadErrorTitle => _strings.stonesLoadErrorTitle;
  String get stonesLoadErrorMessage => _strings.stonesLoadErrorMessage;
  String get noStonesLoaded => _strings.noStonesLoaded;
  String get noStonesLoadedMessage => _strings.noStonesLoadedMessage;
  String get stoneFiltersTitle => _strings.stoneFiltersTitle;
  String get stoneFilterAll => _strings.stoneFilterAll;
  String get stoneFilterMaterial => _strings.stoneFilterMaterial;
  String get stoneFilterColor => _strings.stoneFilterColor;
  String get stoneFilterPattern => _strings.stoneFilterPattern;
  String get stoneFilterAvailability => _strings.stoneFilterAvailability;
  String get stoneFilterReset => _strings.stoneFilterReset;
  String get noStonesMatchFilters => _strings.noStonesMatchFilters;
  String get noStonesMatchFiltersMessage =>
      _strings.noStonesMatchFiltersMessage;
  String get stoneSortTitle => _strings.stoneSortTitle;
  String get stoneSortAction => _strings.stoneSortAction;
  String get stoneSortRecommended => _strings.stoneSortRecommended;
  String get stoneSortNewest => _strings.stoneSortNewest;
  String get stoneSortPriceLowToHigh => _strings.stoneSortPriceLowToHigh;
  String get stoneSortPriceHighToLow => _strings.stoneSortPriceHighToLow;
  String get selectStone => _strings.selectStone;
  String get stoneAvailable => _strings.stoneAvailable;
  String get stoneUnavailable => _strings.stoneUnavailable;
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
    required this.kanjiCandidateDetailTitle,
    required this.kanjiCandidateDetailMessage,
    required this.kanjiReadingLabel,
    required this.kanjiMeaningLabel,
    required this.kanjiImpressionLabel,
    required this.kanjiReasonLabel,
    required this.kanjiCharacterCountLabel,
    required this.kanjiStrokeComplexityLabel,
    required this.kanjiEngravingSuitabilityLabel,
    required this.selectKanji,
    required this.kanjiSelectedTitle,
    required this.kanjiSelectedMessage,
    required this.sealStyleTitle,
    required this.sealStyleMessage,
    required this.sealStyleSelectedKanjiLabel,
    required this.sealShapeLabel,
    required this.sealShapeSquare,
    required this.sealShapeRound,
    required this.sealStyleNameLabel,
    required this.sealStyleTraditional,
    required this.sealStyleElegant,
    required this.sealStyleSoft,
    required this.sealStyleBold,
    required this.sealStrokeWeightLabel,
    required this.sealStrokeStandard,
    required this.sealStrokeBold,
    required this.sealBalanceLabel,
    required this.sealBalanceAiry,
    required this.sealBalanceBalanced,
    required this.sealBalanceDense,
    required this.sealStyleSummaryTitle,
    required this.confirmStyle,
    required this.sealStyleConfirmedTitle,
    required this.sealStyleConfirmedMessage,
    required this.generateSeal,
    required this.sealGenerationLoadingTitle,
    required this.sealGenerationLoadingMessage,
    required this.sealGenerationLoadingDetail,
    required this.sealGenerationErrorTitle,
    required this.sealGenerationErrorMessage,
    required this.sealGenerationLimitTitle,
    required this.sealGenerationLimitMessage,
    required this.sealGenerationAttemptLabel,
    required this.sealGenerationStyleDetails,
    required this.sealGenerationErrorTip,
    required this.sealGenerationLimitTip,
    required this.adjustStyle,
    required this.sealVariantSelectionTitle,
    required this.sealVariantSelectionMessage,
    required this.sealVariantSelectionDetail,
    required this.sealVariantSelectedBadge,
    required this.sealVariantSelectedTitle,
    required this.sealVariantSelectedMessage,
    required this.sealPreviewTitle,
    required this.sealPreviewMessage,
    required this.sealPreviewRulesNote,
    required this.sealPreviewVariantLabel,
    required this.sealPreviewStorageLabel,
    required this.saveSeal,
    required this.chooseStone,
    required this.sealSavedTitle,
    required this.sealSavedHeading,
    required this.sealSavedMessage,
    required this.goToMySeals,
    required this.createAnotherSeal,
    required this.savedSeals,
    required this.savedSealsDescription,
    required this.savedOnThisDevice,
    required this.savedSealsLoadingTitle,
    required this.savedSealsLoadingMessage,
    required this.savedSealsLoadErrorTitle,
    required this.savedSealsLoadErrorMessage,
    required this.chooseSavedSeal,
    required this.viewSealDetails,
    required this.sealDetailTitle,
    required this.kanjiLabel,
    required this.createdAtLabel,
    required this.compareSavedSeals,
    required this.compareSavedSealsTitle,
    required this.compareSavedSealsMessage,
    required this.editSavedSeal,
    required this.editSavedSealTitle,
    required this.editSavedSealMessage,
    required this.chooseSealForOrder,
    required this.sealSelectedForOrderTitle,
    required this.sealSelectedForOrderMessage,
    required this.sealSelectedForOrderAction,
    required this.deleteSavedSeal,
    required this.deleteSealTitle,
    required this.deleteSealMessage,
    required this.deleteSealConfirm,
    required this.cancel,
    required this.close,
    required this.browseStones,
    required this.browseStonesDescription,
    required this.noSavedSeals,
    required this.noSavedSealsMessage,
    required this.stonesLoadingTitle,
    required this.stonesLoadingMessage,
    required this.stonesLoadErrorTitle,
    required this.stonesLoadErrorMessage,
    required this.noStonesLoaded,
    required this.noStonesLoadedMessage,
    required this.stoneFiltersTitle,
    required this.stoneFilterAll,
    required this.stoneFilterMaterial,
    required this.stoneFilterColor,
    required this.stoneFilterPattern,
    required this.stoneFilterAvailability,
    required this.stoneFilterReset,
    required this.noStonesMatchFilters,
    required this.noStonesMatchFiltersMessage,
    required this.stoneSortTitle,
    required this.stoneSortAction,
    required this.stoneSortRecommended,
    required this.stoneSortNewest,
    required this.stoneSortPriceLowToHigh,
    required this.stoneSortPriceHighToLow,
    required this.selectStone,
    required this.stoneAvailable,
    required this.stoneUnavailable,
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
  final String kanjiCandidateDetailTitle;
  final String kanjiCandidateDetailMessage;
  final String kanjiReadingLabel;
  final String kanjiMeaningLabel;
  final String kanjiImpressionLabel;
  final String kanjiReasonLabel;
  final String kanjiCharacterCountLabel;
  final String kanjiStrokeComplexityLabel;
  final String kanjiEngravingSuitabilityLabel;
  final String selectKanji;
  final String kanjiSelectedTitle;
  final String kanjiSelectedMessage;
  final String sealStyleTitle;
  final String sealStyleMessage;
  final String sealStyleSelectedKanjiLabel;
  final String sealShapeLabel;
  final String sealShapeSquare;
  final String sealShapeRound;
  final String sealStyleNameLabel;
  final String sealStyleTraditional;
  final String sealStyleElegant;
  final String sealStyleSoft;
  final String sealStyleBold;
  final String sealStrokeWeightLabel;
  final String sealStrokeStandard;
  final String sealStrokeBold;
  final String sealBalanceLabel;
  final String sealBalanceAiry;
  final String sealBalanceBalanced;
  final String sealBalanceDense;
  final String sealStyleSummaryTitle;
  final String confirmStyle;
  final String sealStyleConfirmedTitle;
  final String sealStyleConfirmedMessage;
  final String generateSeal;
  final String sealGenerationLoadingTitle;
  final String sealGenerationLoadingMessage;
  final String sealGenerationLoadingDetail;
  final String sealGenerationErrorTitle;
  final String sealGenerationErrorMessage;
  final String sealGenerationLimitTitle;
  final String sealGenerationLimitMessage;
  final String sealGenerationAttemptLabel;
  final String sealGenerationStyleDetails;
  final String sealGenerationErrorTip;
  final String sealGenerationLimitTip;
  final String adjustStyle;
  final String sealVariantSelectionTitle;
  final String sealVariantSelectionMessage;
  final String sealVariantSelectionDetail;
  final String sealVariantSelectedBadge;
  final String sealVariantSelectedTitle;
  final String sealVariantSelectedMessage;
  final String sealPreviewTitle;
  final String sealPreviewMessage;
  final String sealPreviewRulesNote;
  final String sealPreviewVariantLabel;
  final String sealPreviewStorageLabel;
  final String saveSeal;
  final String chooseStone;
  final String sealSavedTitle;
  final String sealSavedHeading;
  final String sealSavedMessage;
  final String goToMySeals;
  final String createAnotherSeal;
  final String savedSeals;
  final String savedSealsDescription;
  final String savedOnThisDevice;
  final String savedSealsLoadingTitle;
  final String savedSealsLoadingMessage;
  final String savedSealsLoadErrorTitle;
  final String savedSealsLoadErrorMessage;
  final String chooseSavedSeal;
  final String viewSealDetails;
  final String sealDetailTitle;
  final String kanjiLabel;
  final String createdAtLabel;
  final String compareSavedSeals;
  final String compareSavedSealsTitle;
  final String compareSavedSealsMessage;
  final String editSavedSeal;
  final String editSavedSealTitle;
  final String editSavedSealMessage;
  final String chooseSealForOrder;
  final String sealSelectedForOrderTitle;
  final String sealSelectedForOrderMessage;
  final String sealSelectedForOrderAction;
  final String deleteSavedSeal;
  final String deleteSealTitle;
  final String deleteSealMessage;
  final String deleteSealConfirm;
  final String cancel;
  final String close;
  final String browseStones;
  final String browseStonesDescription;
  final String noSavedSeals;
  final String noSavedSealsMessage;
  final String stonesLoadingTitle;
  final String stonesLoadingMessage;
  final String stonesLoadErrorTitle;
  final String stonesLoadErrorMessage;
  final String noStonesLoaded;
  final String noStonesLoadedMessage;
  final String stoneFiltersTitle;
  final String stoneFilterAll;
  final String stoneFilterMaterial;
  final String stoneFilterColor;
  final String stoneFilterPattern;
  final String stoneFilterAvailability;
  final String stoneFilterReset;
  final String noStonesMatchFilters;
  final String noStonesMatchFiltersMessage;
  final String stoneSortTitle;
  final String stoneSortAction;
  final String stoneSortRecommended;
  final String stoneSortNewest;
  final String stoneSortPriceLowToHigh;
  final String stoneSortPriceHighToLow;
  final String selectStone;
  final String stoneAvailable;
  final String stoneUnavailable;
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
      kanjiCandidateDetailTitle: 'Kanji Detail',
      kanjiCandidateDetailMessage:
          'Review the meaning and engraving fit before choosing this kanji.',
      kanjiReadingLabel: 'Reading',
      kanjiMeaningLabel: 'Meaning',
      kanjiImpressionLabel: 'Impression',
      kanjiReasonLabel: 'Reason',
      kanjiCharacterCountLabel: 'Characters',
      kanjiStrokeComplexityLabel: 'Stroke complexity',
      kanjiEngravingSuitabilityLabel: 'Engraving suitability',
      selectKanji: 'Select Kanji',
      kanjiSelectedTitle: 'Kanji selected',
      kanjiSelectedMessage: 'This kanji is ready for seal style selection.',
      sealStyleTitle: 'Seal Style',
      sealStyleMessage: 'Choose a fixed style set for AI seal generation.',
      sealStyleSelectedKanjiLabel: 'Selected kanji',
      sealShapeLabel: 'Shape',
      sealShapeSquare: 'Square',
      sealShapeRound: 'Round',
      sealStyleNameLabel: 'Style',
      sealStyleTraditional: 'Traditional',
      sealStyleElegant: 'Elegant',
      sealStyleSoft: 'Soft',
      sealStyleBold: 'Bold',
      sealStrokeWeightLabel: 'Stroke Weight',
      sealStrokeStandard: 'Standard',
      sealStrokeBold: 'Bold',
      sealBalanceLabel: 'Balance',
      sealBalanceAiry: 'Airy',
      sealBalanceBalanced: 'Balanced',
      sealBalanceDense: 'Dense',
      sealStyleSummaryTitle: 'Current style',
      confirmStyle: 'Confirm Style',
      sealStyleConfirmedTitle: 'Style selected',
      sealStyleConfirmedMessage:
          'These style choices are ready for AI seal generation.',
      generateSeal: 'Generate Seal',
      sealGenerationLoadingTitle: 'Generating Seal',
      sealGenerationLoadingMessage:
          'Creating three AI seal design directions...',
      sealGenerationLoadingDetail:
          'We are checking the kanji, style, and engraving safety before saving previews.',
      sealGenerationErrorTitle: "We couldn't generate seal designs",
      sealGenerationErrorMessage:
          'Something went wrong while creating AI seal previews. Please try again.',
      sealGenerationLimitTitle: 'Generation limit reached',
      sealGenerationLimitMessage:
          'You have used all generation attempts for this style set. Adjust the style before trying again.',
      sealGenerationAttemptLabel: 'Attempts',
      sealGenerationStyleDetails: 'Generation details',
      sealGenerationErrorTip:
          'Try again once. If it still fails, adjust the style or choose a simpler kanji.',
      sealGenerationLimitTip:
          'Choose a different balance, stroke weight, or kanji to start a fresh generation.',
      adjustStyle: 'Adjust Style',
      sealVariantSelectionTitle: 'Seal Options',
      sealVariantSelectionMessage: 'Choose one AI seal design.',
      sealVariantSelectionDetail:
          'Each option is saved with a stable Storage path for later preview and ordering.',
      sealVariantSelectedBadge: 'Selected',
      sealVariantSelectedTitle: 'Seal design selected',
      sealVariantSelectedMessage:
          'This AI seal design is ready for preview and saving.',
      sealPreviewTitle: 'Seal Preview',
      sealPreviewMessage: 'Review your selected seal design before saving.',
      sealPreviewRulesNote: 'Created within engraving-friendly design rules.',
      sealPreviewVariantLabel: 'AI Variant',
      sealPreviewStorageLabel: 'Storage path',
      saveSeal: 'Save Seal',
      chooseStone: 'Choose a Stone',
      sealSavedTitle: 'Seal Saved',
      sealSavedHeading: 'Seal saved to My Seals',
      sealSavedMessage:
          'Your custom seal design is ready for comparison and ordering.',
      goToMySeals: 'Go to My Seals',
      createAnotherSeal: 'Create Another Seal',
      savedSeals: 'Saved Seals',
      savedSealsDescription: 'View and manage your\nsaved seal designs.',
      savedOnThisDevice: 'Saved on this device',
      savedSealsLoadingTitle: 'Loading saved seals',
      savedSealsLoadingMessage: 'Checking seal designs saved on this device.',
      savedSealsLoadErrorTitle: "Couldn't load saved seals",
      savedSealsLoadErrorMessage:
          'Open My Seals again, or create a new seal design.',
      chooseSavedSeal: 'Choose',
      viewSealDetails: 'View Details',
      sealDetailTitle: 'Seal Detail',
      kanjiLabel: 'Kanji',
      createdAtLabel: 'Created',
      compareSavedSeals: 'Compare Seals',
      compareSavedSealsTitle: 'Compare saved seals',
      compareSavedSealsMessage:
          'Open each saved seal to review its preview, kanji, and style details. Side-by-side comparison will be added later.',
      editSavedSeal: 'Edit / Regenerate',
      editSavedSealTitle: 'Create a new version from Design',
      editSavedSealMessage:
          'Saved seals stay unchanged. To try different kanji or style choices, start a new design and save it.',
      chooseSealForOrder: 'Choose for Order',
      sealSelectedForOrderTitle: 'Selected for order',
      sealSelectedForOrderMessage: 'This seal is now saved in the order draft.',
      sealSelectedForOrderAction: 'Selected for Order',
      deleteSavedSeal: 'Delete Seal',
      deleteSealTitle: 'Delete saved seal?',
      deleteSealMessage:
          'This removes the seal design from this device. This action cannot be undone.',
      deleteSealConfirm: 'Delete',
      cancel: 'Cancel',
      close: 'Close',
      browseStones: 'Browse Stones',
      browseStonesDescription: 'Explore our collection of\nnatural gemstones.',
      noSavedSeals: 'No saved seals',
      noSavedSealsMessage:
          'Saved seal designs will appear here after you create one.',
      stonesLoadingTitle: 'Loading stones',
      stonesLoadingMessage: 'Checking available one-of-a-kind seal stones.',
      stonesLoadErrorTitle: "Couldn't load stones",
      stonesLoadErrorMessage:
          'Try again to refresh the available stone listings.',
      noStonesLoaded: 'No stones loaded',
      noStonesLoadedMessage:
          'Available one-of-a-kind stones will be shown here.',
      stoneFiltersTitle: 'Filters',
      stoneFilterAll: 'All',
      stoneFilterMaterial: 'Material',
      stoneFilterColor: 'Color',
      stoneFilterPattern: 'Pattern',
      stoneFilterAvailability: 'Availability',
      stoneFilterReset: 'Reset',
      noStonesMatchFilters: 'No stones match filters',
      noStonesMatchFiltersMessage:
          'Clear or change filters to browse other stones.',
      stoneSortTitle: 'Sort',
      stoneSortAction: 'Sort',
      stoneSortRecommended: 'Recommended',
      stoneSortNewest: 'Newest',
      stoneSortPriceLowToHigh: 'Price: Low to High',
      stoneSortPriceHighToLow: 'Price: High to Low',
      selectStone: 'Select Stone',
      stoneAvailable: 'Available',
      stoneUnavailable: 'Unavailable',
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
      kanjiCandidateDetailTitle: '漢字の詳細',
      kanjiCandidateDetailMessage: '意味と彫刻適性を確認して、この漢字を選択します。',
      kanjiReadingLabel: '読み',
      kanjiMeaningLabel: '意味',
      kanjiImpressionLabel: '印象',
      kanjiReasonLabel: '理由',
      kanjiCharacterCountLabel: '文字数',
      kanjiStrokeComplexityLabel: '画数の複雑さ',
      kanjiEngravingSuitabilityLabel: '彫刻適性',
      selectKanji: '漢字を選択',
      kanjiSelectedTitle: '漢字を選択しました',
      kanjiSelectedMessage: 'この漢字で印影スタイル選択へ進めます。',
      sealStyleTitle: '印影スタイル',
      sealStyleMessage: 'AI印影生成に使う固定スタイルを選択してください。',
      sealStyleSelectedKanjiLabel: '選択中の漢字',
      sealShapeLabel: '形',
      sealShapeSquare: '角印',
      sealShapeRound: '丸印',
      sealStyleNameLabel: '雰囲気',
      sealStyleTraditional: '伝統的',
      sealStyleElegant: '上品',
      sealStyleSoft: 'やわらかい',
      sealStyleBold: '力強い',
      sealStrokeWeightLabel: '線の太さ',
      sealStrokeStandard: '標準',
      sealStrokeBold: '太め',
      sealBalanceLabel: '余白感',
      sealBalanceAiry: '余白多め',
      sealBalanceBalanced: '標準',
      sealBalanceDense: '密度高め',
      sealStyleSummaryTitle: '現在のスタイル',
      confirmStyle: 'スタイルを確定',
      sealStyleConfirmedTitle: 'スタイルを選択しました',
      sealStyleConfirmedMessage: 'このスタイルでAI印影生成へ進めます。',
      generateSeal: '印影を生成',
      sealGenerationLoadingTitle: '印影を生成中',
      sealGenerationLoadingMessage: 'AI印影候補を3件作成しています...',
      sealGenerationLoadingDetail: '漢字、スタイル、彫刻しやすさを確認しながらプレビューを保存しています。',
      sealGenerationErrorTitle: '印影を生成できませんでした',
      sealGenerationErrorMessage: 'AI印影候補の作成中に問題が発生しました。もう一度お試しください。',
      sealGenerationLimitTitle: '再生成の上限に達しました',
      sealGenerationLimitMessage:
          'このスタイルで利用できる生成回数を使い切りました。スタイルを調整してから再度お試しください。',
      sealGenerationAttemptLabel: '生成回数',
      sealGenerationStyleDetails: '生成内容',
      sealGenerationErrorTip: '一度再試行し、続けて失敗する場合はスタイルや漢字をよりシンプルにしてください。',
      sealGenerationLimitTip: '余白感、線の太さ、または漢字を変えると新しく生成できます。',
      adjustStyle: 'スタイルを調整',
      sealVariantSelectionTitle: '印影候補',
      sealVariantSelectionMessage: 'AI印影候補から1件を選択してください。',
      sealVariantSelectionDetail: '各候補は、プレビューと注文に使えるStorageパスと一緒に保存されています。',
      sealVariantSelectedBadge: '選択中',
      sealVariantSelectedTitle: '印影を選択しました',
      sealVariantSelectedMessage: 'このAI印影をプレビュー確認と保存に進められます。',
      sealPreviewTitle: '印影プレビュー',
      sealPreviewMessage: '保存前に選択した印影デザインを確認してください。',
      sealPreviewRulesNote: '彫刻しやすいデザインルール内で作成されています。',
      sealPreviewVariantLabel: 'AI候補',
      sealPreviewStorageLabel: 'Storageパス',
      saveSeal: '印影を保存',
      chooseStone: '石を選ぶ',
      sealSavedTitle: '保存完了',
      sealSavedHeading: '印影を保存しました',
      sealSavedMessage: '保存した印影は比較や注文に使えます。',
      goToMySeals: 'マイ印影へ',
      createAnotherSeal: '別の印影を作成',
      savedSeals: '保存済み印影',
      savedSealsDescription: '保存した印影デザインを\n確認・管理できます。',
      savedOnThisDevice: 'この端末に保存',
      savedSealsLoadingTitle: '保存済み印影を読み込み中',
      savedSealsLoadingMessage: 'この端末に保存された印影を確認しています。',
      savedSealsLoadErrorTitle: '保存済み印影を読み込めません',
      savedSealsLoadErrorMessage: 'マイ印影を開き直すか、新しい印影を作成してください。',
      chooseSavedSeal: '選択',
      viewSealDetails: '詳細を見る',
      sealDetailTitle: '印影詳細',
      kanjiLabel: '漢字',
      createdAtLabel: '作成日',
      compareSavedSeals: '印影を比較',
      compareSavedSealsTitle: '保存済み印影の比較',
      compareSavedSealsMessage:
          '今は各印影の詳細を開いて、プレビュー、漢字、スタイルを確認してください。横並び比較は後続で追加します。',
      editSavedSeal: '編集 / 再生成',
      editSavedSealTitle: 'Designから新しい案を作成',
      editSavedSealMessage:
          '保存済み印影はそのまま残ります。漢字やスタイルを変える場合は、Designから新しい印影を作成して保存してください。',
      chooseSealForOrder: '注文に使う',
      sealSelectedForOrderTitle: '注文用に選択済み',
      sealSelectedForOrderMessage: 'この印影を注文下書きに反映しました。',
      sealSelectedForOrderAction: '選択済み',
      deleteSavedSeal: '印影を削除',
      deleteSealTitle: '保存済み印影を削除しますか？',
      deleteSealMessage: 'この端末から印影デザインを削除します。この操作は元に戻せません。',
      deleteSealConfirm: '削除',
      cancel: 'キャンセル',
      close: '閉じる',
      browseStones: '石を探す',
      browseStonesDescription: '天然石コレクションを\nご覧ください。',
      noSavedSeals: '保存済み印影はありません',
      noSavedSealsMessage: '作成した印影デザインがここに表示されます。',
      stonesLoadingTitle: '石を読み込み中',
      stonesLoadingMessage: '販売中の一点物の石を確認しています。',
      stonesLoadErrorTitle: '石を読み込めません',
      stonesLoadErrorMessage: '販売中の石一覧を再読み込みしてください。',
      noStonesLoaded: '石を読み込んでいません',
      noStonesLoadedMessage: '販売中の一点物の石がここに表示されます。',
      stoneFiltersTitle: '絞り込み',
      stoneFilterAll: 'すべて',
      stoneFilterMaterial: '素材',
      stoneFilterColor: '色',
      stoneFilterPattern: '模様',
      stoneFilterAvailability: '在庫',
      stoneFilterReset: 'リセット',
      noStonesMatchFilters: '条件に合う石がありません',
      noStonesMatchFiltersMessage: '絞り込み条件を変更するか解除してください。',
      stoneSortTitle: '並び替え',
      stoneSortAction: '並び替え',
      stoneSortRecommended: 'おすすめ順',
      stoneSortNewest: '新着順',
      stoneSortPriceLowToHigh: '価格が安い順',
      stoneSortPriceHighToLow: '価格が高い順',
      selectStone: '石を選択',
      stoneAvailable: '販売中',
      stoneUnavailable: '選択不可',
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
