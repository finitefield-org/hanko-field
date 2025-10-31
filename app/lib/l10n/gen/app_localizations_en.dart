// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hanko Field';

  @override
  String get counterScreenTitle => 'Sample Counter';

  @override
  String get increment => 'Increment';

  @override
  String countLabel(int value) {
    return 'Count: $value';
  }

  @override
  String get onboardingAppBarTitle => 'Welcome to Hanko Field';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String onboardingProgressLabel(int current, int total) {
    return '$current of $total';
  }

  @override
  String get onboardingSlideCraftTitle => 'Craft your personal seal';

  @override
  String get onboardingSlideCraftBody =>
      'Create beautiful hanko impressions with guided tools and templates tailored to your needs.';

  @override
  String get onboardingSlideSupportTitle => 'Expert support at every step';

  @override
  String get onboardingSlideSupportBody =>
      'Track orders, access guides, and chat with us whenever you need help.';

  @override
  String get onboardingSlideTrustTitle => 'Secure and ready for business';

  @override
  String get onboardingSlideTrustBody =>
      'Your data stays protected while you manage signatures, deliveries, and records with confidence.';

  @override
  String get homeAppBarTitle => 'Home';

  @override
  String get homeFeaturedSectionTitle => 'Featured campaigns';

  @override
  String get homeFeaturedSectionSubtitleDefault =>
      'Curated highlights picked for your workspace.';

  @override
  String homeFeaturedSectionSubtitle(String persona) {
    return 'Recommended for $persona';
  }

  @override
  String get homeFeaturedEmptyMessage =>
      'No featured items available right now.';

  @override
  String get homeLoadErrorMessage => 'We couldn\'t load this section.';

  @override
  String get homeRetryButtonLabel => 'Retry';

  @override
  String get homeRecentDesignsTitle => 'Recent designs';

  @override
  String get homeRecentDesignsSubtitle =>
      'Resume where you left off or review recent exports.';

  @override
  String get homeRecentDesignsEmptyTitle => 'No recent designs yet';

  @override
  String get homeRecentDesignsEmptyMessage =>
      'Start a new seal design to see your drafts and history here.';

  @override
  String get homeRecentDesignsEmptyCta => 'Start a design';

  @override
  String get homeTemplateRecommendationsTitle => 'Recommended templates';

  @override
  String get homeTemplateRecommendationsSubtitle =>
      'Tailored layouts and writing styles based on your preferences.';

  @override
  String get homeTemplateRecommendationsEmpty =>
      'No template recommendations at the moment.';

  @override
  String get homeDesignStatusDraft => 'Draft';

  @override
  String get homeDesignStatusReady => 'Ready';

  @override
  String get homeDesignStatusOrdered => 'Ordered';

  @override
  String get homeDesignStatusLocked => 'Locked';

  @override
  String homeUpdatedOn(String date) {
    return 'Updated on $date';
  }

  @override
  String get homeWritingStyleTensho => 'Tensho';

  @override
  String get homeWritingStyleReisho => 'Reisho';

  @override
  String get homeWritingStyleKaisho => 'Kaisho';

  @override
  String get homeWritingStyleGyosho => 'Gyosho';

  @override
  String get homeWritingStyleKoentai => 'Koentai';

  @override
  String get homeWritingStyleCustom => 'Custom';

  @override
  String get homeShapeRound => 'Round';

  @override
  String get homeShapeSquare => 'Square';

  @override
  String get designNewTitle => 'Start a new seal';

  @override
  String get designNewSubtitle =>
      'Choose how you\'d like to create your seal design.';

  @override
  String get designNewHelpTooltip => 'Help for design creation';

  @override
  String get designNewContinueLabel => 'Continue';

  @override
  String get designNewFilterPersonal => 'Personal seal';

  @override
  String get designNewFilterBusiness => 'Business use';

  @override
  String get designNewFilterGift => 'Gift / ceremonial';

  @override
  String get designNewOptionTypedTitle => 'Type your name';

  @override
  String get designNewOptionTypedDescription =>
      'Enter kanji or romaji and preview layouts instantly.';

  @override
  String get designNewOptionUploadTitle => 'Upload artwork';

  @override
  String get designNewOptionUploadDescription =>
      'Import an existing seal image to refine or trace.';

  @override
  String get designNewOptionLogoTitle => 'Engrave a logo';

  @override
  String get designNewOptionLogoDescription =>
      'Provide brand marks or vector files for engraving guidance.';

  @override
  String get designNewHighlightsTitle => 'What you get in each mode';

  @override
  String get designNewHighlightsAiTitle => 'AI assistance';

  @override
  String get designNewHighlightsAiBody =>
      'Receive smart suggestions for layouts, naming, and visual balance.';

  @override
  String get designNewHighlightsTemplateTitle => 'Templates & fonts';

  @override
  String get designNewHighlightsTemplateBody =>
      'Browse curated scripts and templates tuned for Japanese seals.';

  @override
  String get designNewHighlightsCloudTitle => 'Cloud workspace';

  @override
  String get designNewHighlightsCloudBody =>
      'Keep uploads synced securely so you can resume on any device.';

  @override
  String get designNewPermissionDenied =>
      'Storage access is required to continue with this mode.';

  @override
  String get designInputTitle => 'Enter your name';

  @override
  String get designInputSubtitle =>
      'Provide the surname and given name that will appear on your seal. We\'ll preview it as you type.';

  @override
  String get designInputPreviewTitle => 'Live preview';

  @override
  String get designInputPreviewCaption =>
      'Preview updates with your selected style later in the flow.';

  @override
  String get designInputPlaceholderPrimary => 'Sample Name';

  @override
  String get designInputSectionPrimary => 'Name (kanji or romaji)';

  @override
  String get designInputSectionReading => 'Reading / pronunciation';

  @override
  String get designInputSurnameLabel => 'Surname';

  @override
  String get designInputGivenNameLabel => 'Given name';

  @override
  String get designInputSurnameHelper =>
      'Full-width characters, up to 6 letters.';

  @override
  String get designInputGivenNameHelper =>
      'Full-width characters, up to 6 letters.';

  @override
  String get designInputSurnameReadingLabel => 'Surname reading';

  @override
  String get designInputGivenNameReadingLabel => 'Given name reading';

  @override
  String get designInputReadingHelper =>
      'Use Hiragana or Katakana. Required when designing a Japanese seal.';

  @override
  String get designInputContinue => 'Choose style';

  @override
  String get designStyleTitle => 'Choose style & template';

  @override
  String get designStyleSubtitle =>
      'Select the script family, seal shape, and template that best matches your persona. You can fine-tune details later in the editor.';

  @override
  String get designStyleHelpTooltip => 'Typography tips';

  @override
  String get designStyleScriptKanji => 'Kanji';

  @override
  String get designStyleScriptKana => 'Kana';

  @override
  String get designStyleScriptRoman => 'Roman';

  @override
  String get designStyleShapeRound => 'Round';

  @override
  String get designStyleShapeSquare => 'Square';

  @override
  String get designStyleContinue => 'Open editor';

  @override
  String get designStyleFavoritesAdd => 'Add to favourites';

  @override
  String get designStyleFavoritesRemove => 'Favourited';

  @override
  String get designStyleEmptyTitle => 'No templates available';

  @override
  String get designStyleEmptyBody =>
      'Adjust your filters or refresh to load templates that match your persona and available fonts.';

  @override
  String get designStyleRetry => 'Retry';

  @override
  String get designStyleSelectedHeading => 'Selected template';

  @override
  String get designInputSuggestionHeader => 'Quick fill';

  @override
  String get designInputSuggestionProfile => 'Use profile name';

  @override
  String get designInputSuggestionIdentity => 'Use account name';

  @override
  String get designInputSuggestionFallback => 'Suggested name';

  @override
  String get designInputKanjiMappingTitle => 'Need kanji ideas?';

  @override
  String get designInputKanjiMappingDescription =>
      'Find culturally appropriate kanji variants and meanings for foreign names.';

  @override
  String get designInputKanjiMappingCta => 'Open mapper';

  @override
  String designInputKanjiMappingSelectionLabel(String value) {
    return 'Selected kanji: $value';
  }

  @override
  String get designInputErrorEmptySurname => 'Enter your surname.';

  @override
  String get designInputErrorEmptyGiven => 'Enter your given name.';

  @override
  String get designInputErrorInvalidKanji =>
      'Use full-width characters for your seal.';

  @override
  String get designInputErrorTooLongKanji =>
      'Keep the name within 6 full-width characters.';

  @override
  String get designInputErrorTooLongLatin =>
      'Keep the name within 20 characters.';

  @override
  String get designInputErrorInvalidKana =>
      'Use Hiragana, Katakana, or prolonged sound marks.';

  @override
  String get designInputErrorTooLongKana =>
      'Keep the reading within 20 characters.';

  @override
  String get designInputErrorEmptyKana =>
      'Enter the reading in Hiragana or Katakana.';

  @override
  String get designInputValidationFailed => 'Check the highlighted fields.';

  @override
  String get designKanjiMappingTitle => 'Kanji mapper';

  @override
  String get designKanjiMappingConfirm => 'Use selection';

  @override
  String get designKanjiMappingSearchHint =>
      'Search by meaning, sound, or radical';

  @override
  String get designKanjiMappingRefreshTooltip => 'Refresh suggestions';

  @override
  String get designKanjiMappingCompareHeader => 'Compare list';

  @override
  String get designKanjiMappingCompareToggleLabel => 'Add to compare';

  @override
  String get designKanjiMappingCompareSelectedLabel => 'In compare list';

  @override
  String designKanjiMappingStrokeCountLabel(int count) {
    return '$count strokes';
  }

  @override
  String get designKanjiMappingBookmarkAdd => 'Bookmark';

  @override
  String get designKanjiMappingBookmarkRemove => 'Remove bookmark';

  @override
  String get designKanjiMappingSelectTooltip => 'Select this candidate';

  @override
  String get designKanjiMappingManualTitle => 'Manual entry';

  @override
  String get designKanjiMappingManualDescription =>
      'Already have characters in mind? Enter them directly.';

  @override
  String get designKanjiMappingManualKanjiLabel => 'Kanji characters';

  @override
  String get designKanjiMappingManualKanjiHelper =>
      'Use up to 4 characters. Full-width recommended.';

  @override
  String get designKanjiMappingManualMeaningLabel =>
      'Meaning or notes (optional)';

  @override
  String get designKanjiMappingManualMeaningHelper =>
      'Visible only to you for reference.';

  @override
  String get designKanjiMappingEmptyResultsTitle => 'No candidates match yet';

  @override
  String get designKanjiMappingEmptyResultsDescription =>
      'Adjust filters or try a different meaning to explore more kanji.';
}
