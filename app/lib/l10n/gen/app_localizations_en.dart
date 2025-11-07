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
  String get libraryListTitle => 'My Hanko Library';

  @override
  String get libraryListSubtitle =>
      'Browse saved designs, filter by persona, and export assets anytime.';

  @override
  String get librarySearchPlaceholder => 'Search designs, IDs, or notes';

  @override
  String get librarySortRecent => 'Recent';

  @override
  String get librarySortAiScore => 'AI score';

  @override
  String get librarySortName => 'Name';

  @override
  String get libraryViewGrid => 'Grid';

  @override
  String get libraryViewList => 'List';

  @override
  String get libraryFilterStatusLabel => 'Status';

  @override
  String get libraryFilterPersonaLabel => 'Persona';

  @override
  String get libraryFilterDateLabel => 'Updated';

  @override
  String get libraryFilterAiLabel => 'AI score';

  @override
  String get libraryFilterHint =>
      'Filters apply instantly while keeping results available offline.';

  @override
  String get libraryStatusAll => 'All';

  @override
  String get libraryPersonaAll => 'All personas';

  @override
  String get libraryPersonaJapanese => 'Domestic';

  @override
  String get libraryPersonaForeigner => 'International';

  @override
  String get libraryDateLast7Days => '7 days';

  @override
  String get libraryDateLast30Days => '30 days';

  @override
  String get libraryDateLast90Days => '90 days';

  @override
  String get libraryDateAnytime => 'Any time';

  @override
  String get libraryAiAll => 'Any';

  @override
  String get libraryAiHigh => '80+';

  @override
  String get libraryAiMedium => '60+';

  @override
  String get libraryAiLow => '40+';

  @override
  String get libraryAiScoreUnknown => 'AI score —';

  @override
  String libraryAiScoreValue(int score) {
    return 'AI score $score';
  }

  @override
  String libraryUpdatedOn(Object date) {
    return 'Updated $date';
  }

  @override
  String libraryUpdatedAt(Object date) {
    return 'Refreshed $date';
  }

  @override
  String get libraryUpdatedNever => 'Not synced yet';

  @override
  String get libraryEmptyTitle => 'No saved seals yet';

  @override
  String get libraryEmptyMessage =>
      'Create your first design or import a file to populate the library.';

  @override
  String get libraryEmptyCta => 'Start a new design';

  @override
  String get libraryActionPreview => 'Preview';

  @override
  String get libraryActionShare => 'Share';

  @override
  String get libraryActionEdit => 'Edit';

  @override
  String get libraryActionExport => 'Export';

  @override
  String get libraryActionDuplicate => 'Duplicate';

  @override
  String get libraryActionReorder => 'Reorder';

  @override
  String get libraryDuplicateTitle => 'Duplicate design';

  @override
  String libraryDuplicateSubtitle(Object name) {
    return 'Make a copy of $name and jump back into the editor.';
  }

  @override
  String get libraryDuplicateSubtitleFallback =>
      'Make a copy and continue editing.';

  @override
  String get libraryDuplicateNameLabel => 'New design name';

  @override
  String get libraryDuplicateNameHint => 'e.g. Yamada Co. round v2';

  @override
  String get libraryDuplicateNameError => 'Enter a name for the duplicate.';

  @override
  String get libraryDuplicateTagsLabel => 'Tags';

  @override
  String get libraryDuplicateTagsHint => 'personal, ai-ready, round';

  @override
  String get libraryDuplicateSuggestionsLabel => 'Suggestions';

  @override
  String get libraryDuplicateCopyHistory => 'Copy history';

  @override
  String get libraryDuplicateCopyHistoryDescription =>
      'Include comments, usage events, and AI reports.';

  @override
  String get libraryDuplicateCopyAssets => 'Copy assets';

  @override
  String get libraryDuplicateCopyAssetsDescription =>
      'Reuse exported files and editor adjustments.';

  @override
  String get libraryDuplicateSubmit => 'Duplicate and edit';

  @override
  String get libraryDuplicateCancel => 'Cancel';

  @override
  String get libraryDetailTabDetails => 'Details';

  @override
  String get libraryDetailTabActivity => 'Activity';

  @override
  String get libraryDetailTabFiles => 'Files';

  @override
  String get libraryDetailQuickActions => 'Quick actions';

  @override
  String get libraryDetailMetadataTitle => 'Design metadata';

  @override
  String get libraryDetailAiTitle => 'AI review';

  @override
  String get libraryDetailVersionTitle => 'Versions';

  @override
  String get libraryDetailUsageTitle => 'Usage history';

  @override
  String get libraryDetailFilesTitle => 'Files';

  @override
  String get libraryDetailMetadataId => 'Design ID';

  @override
  String get libraryDetailMetadataStatus => 'Status';

  @override
  String get libraryDetailMetadataPersona => 'Persona';

  @override
  String get libraryDetailMetadataShape => 'Shape · Size';

  @override
  String get libraryDetailMetadataWriting => 'Writing style';

  @override
  String get libraryDetailMetadataUpdated => 'Last updated';

  @override
  String get libraryDetailMetadataCreated => 'Created';

  @override
  String get libraryDetailRegistrable => 'Registrable';

  @override
  String get libraryDetailNotRegistrable => 'Needs tweaks';

  @override
  String get libraryDetailAiScoreLabel => 'AI score';

  @override
  String get libraryDetailAiDiagnosticsLabel => 'Diagnostics';

  @override
  String get libraryDetailAiDiagnosticsEmpty => 'No diagnostics available yet.';

  @override
  String libraryDetailVersionCurrent(int version) {
    return 'Current version v$version';
  }

  @override
  String libraryDetailVersionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# total versions',
      one: '# total version',
    );
    return '$_temp0';
  }

  @override
  String get libraryDetailViewVersionsCta => 'View version history';

  @override
  String get libraryDetailUsageEmpty => 'No recorded usage yet.';

  @override
  String get libraryDetailUsageCreated => 'Created in library';

  @override
  String libraryDetailUsageUpdated(int version) {
    return 'Updated to v$version';
  }

  @override
  String get libraryDetailUsageOrdered => 'Used in an order';

  @override
  String libraryDetailUsageAiCheck(Object score) {
    return 'AI review scored $score';
  }

  @override
  String libraryDetailUsageVersionArchived(int version) {
    return 'Archived version v$version';
  }

  @override
  String get libraryDetailFilesVector => 'Vector (.svg)';

  @override
  String get libraryDetailFilesPreview => 'Preview PNG';

  @override
  String get libraryDetailFilesStampMock => 'Stamp mock';

  @override
  String get libraryDetailFilesUnavailable => 'File not generated yet.';

  @override
  String libraryDetailShareSubject(Object id) {
    return 'Hanko design $id';
  }

  @override
  String libraryDetailShareBody(Object name, Object id) {
    return 'Check \"$name\" from my Hanko Field library (ID: $id).';
  }

  @override
  String libraryDetailDuplicateSuccess(Object id) {
    return 'Duplicated as $id';
  }

  @override
  String get libraryDetailDuplicateFailure =>
      'Couldn\'t duplicate. Try again later.';

  @override
  String get libraryDetailActionInProgress => 'Processing...';

  @override
  String get libraryDetailErrorTitle => 'Design unavailable';

  @override
  String get libraryDetailRetry => 'Retry loading';

  @override
  String get libraryDetailShapeRound => 'Round';

  @override
  String get libraryDetailShapeSquare => 'Square';

  @override
  String get libraryDetailWritingTensho => 'Tensho';

  @override
  String get libraryDetailWritingReisho => 'Reisho';

  @override
  String get libraryDetailWritingKaisho => 'Kaisho';

  @override
  String get libraryDetailWritingGyosho => 'Gyosho';

  @override
  String get libraryDetailWritingKoentai => 'Koentai';

  @override
  String get libraryDetailWritingCustom => 'Custom';

  @override
  String get libraryExportTitle => 'Digital export';

  @override
  String get libraryExportHistoryTooltip => 'View previous exports';

  @override
  String get libraryExportHistoryTitle => 'Export history';

  @override
  String get libraryExportGenerateCta => 'Generate link';

  @override
  String get libraryExportRevokeCta => 'Revoke all links';

  @override
  String get libraryExportLinkReadySnack => 'Link ready to share';

  @override
  String get libraryExportRevokedSnack => 'All links revoked';

  @override
  String libraryExportShareSubject(String id) {
    return 'Digital export for $id';
  }

  @override
  String get libraryExportCopySnack => 'Link copied';

  @override
  String get libraryExportFormatLabel => 'File format';

  @override
  String get libraryExportFormatPng => 'PNG';

  @override
  String get libraryExportFormatSvg => 'SVG';

  @override
  String get libraryExportFormatPdf => 'PDF';

  @override
  String get libraryExportFormatPngUseMessaging => 'Great for chat previews';

  @override
  String get libraryExportFormatPngUseTransparent => 'Supports transparency';

  @override
  String get libraryExportFormatSvgUseVector => 'Keeps vectors editable';

  @override
  String get libraryExportFormatSvgUseCnc => 'Laser/CNC friendly';

  @override
  String get libraryExportFormatPdfUsePrint => 'Print-ready layout';

  @override
  String get libraryExportFormatPdfUseArchive => 'Archive quality';

  @override
  String get libraryExportScaleLabel => 'Scale';

  @override
  String get libraryExportScaleSubtitle =>
      'Choose how large the exported file should be.';

  @override
  String libraryExportScaleChip(int factor) {
    return '$factor×';
  }

  @override
  String get libraryExportWatermarkLabel => 'Apply watermark';

  @override
  String get libraryExportWatermarkDescription =>
      'Adds a subtle diagonal watermark to previews.';

  @override
  String get libraryExportExpiryLabel => 'Link expires';

  @override
  String libraryExportExpiryDescription(int days) {
    return 'Automatically disables downloads after $days days.';
  }

  @override
  String get libraryExportExpiryDisabled => 'Does not expire';

  @override
  String get libraryExportExpiryPicker => 'Expiry duration';

  @override
  String libraryExportExpiryDays(int days) {
    return '$days days';
  }

  @override
  String get libraryExportDownloadsLabel => 'Allow original downloads';

  @override
  String get libraryExportDownloadsDescription =>
      'Let recipients download the full-resolution file.';

  @override
  String get libraryExportLinkTitle => 'Shareable link';

  @override
  String get libraryExportLinkEmptyTitle => 'No link yet';

  @override
  String get libraryExportLinkEmptyMessage =>
      'Generate a link to share digital files securely.';

  @override
  String get libraryExportShareLink => 'Share link';

  @override
  String get libraryExportCopyLink => 'Copy link';

  @override
  String libraryExportExpiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String libraryExportLinkMeta(String format, String scale) {
    return '$format · $scale';
  }

  @override
  String get libraryLoadError =>
      'We couldn\'t load your library. Check your connection and try again.';

  @override
  String get libraryErrorTitle => 'Library unavailable';

  @override
  String get libraryRetry => 'Retry';

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
  String get designAiSuggestionsTitle => 'AI suggestions';

  @override
  String get designAiSuggestionsQueueTooltip => 'Queued proposals';

  @override
  String get designAiSuggestionsRequestQueued =>
      'AI job queued. We\'ll add new proposals shortly.';

  @override
  String designAiSuggestionsRequestRateLimited(int seconds) {
    return 'Please wait $seconds seconds before requesting again.';
  }

  @override
  String get designAiSuggestionsGenericError =>
      'We couldn\'t update suggestions. Please try again.';

  @override
  String designAiSuggestionsSegmentReady(int count) {
    return 'Ready ($count)';
  }

  @override
  String designAiSuggestionsSegmentQueued(int count) {
    return 'Queued ($count)';
  }

  @override
  String designAiSuggestionsSegmentApplied(int count) {
    return 'Applied ($count)';
  }

  @override
  String get designAiSuggestionsHelperTitle => 'Need a fresh take?';

  @override
  String get designAiSuggestionsHelperSubtitle =>
      'Queue a proposal and we\'ll compare it with your current design, highlighting balance and spacing tweaks.';

  @override
  String get designAiSuggestionsRequestCta => 'Request new proposals';

  @override
  String designAiSuggestionsRateLimitCountdown(int seconds) {
    return 'Next request available in ${seconds}s';
  }

  @override
  String get designAiSuggestionsEmptyReadyTitle => 'No proposals yet';

  @override
  String get designAiSuggestionsEmptyReadyBody =>
      'Ask the AI for layout ideas to compare against your baseline design.';

  @override
  String get designAiSuggestionsEmptyQueuedTitle => 'Queue is clear';

  @override
  String get designAiSuggestionsEmptyQueuedBody =>
      'Request more proposals when you\'re ready. We\'ll process them in the background.';

  @override
  String get designAiSuggestionsEmptyAppliedTitle => 'No applied proposals';

  @override
  String get designAiSuggestionsEmptyAppliedBody =>
      'Accepted proposals will show here so you can revisit the history of changes.';

  @override
  String designAiSuggestionsAcceptSuccess(String title) {
    return 'Applied \"$title\" to your design.';
  }

  @override
  String designAiSuggestionsRejectSuccess(String title) {
    return 'Dismissed \"$title\".';
  }

  @override
  String get designAiSuggestionsAccept => 'Accept';

  @override
  String get designAiSuggestionsReject => 'Reject';

  @override
  String get designAiSuggestionsAppliedLabel => 'Applied to your draft';

  @override
  String get designAiSuggestionsQueuedLabel => 'Waiting for processing';

  @override
  String designAiSuggestionsScoreLabel(int percent) {
    return 'Score $percent%';
  }

  @override
  String get designAiSuggestionsComparisonHint => 'Drag to compare';

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
  String get designEditorTitle => 'Design editor';

  @override
  String get designEditorFallbackText => 'Sample';

  @override
  String get designEditorPrimaryCta => 'Preview & export';

  @override
  String get designEditorUndoTooltip => 'Undo';

  @override
  String get designEditorRedoTooltip => 'Redo';

  @override
  String get designEditorRegistrabilityTooltip => 'Check registrability';

  @override
  String get designEditorMoreActionsTooltip => 'More actions';

  @override
  String get designEditorVersionHistoryTooltip => 'Version history';

  @override
  String get designEditorResetMenu => 'Reset to template defaults';

  @override
  String get designEditorResetSnackbar => 'Restored template defaults.';

  @override
  String get designEditorToolSelect => 'Select';

  @override
  String get designEditorToolText => 'Text';

  @override
  String get designEditorToolLayout => 'Layout';

  @override
  String get designEditorToolExport => 'Export';

  @override
  String get designEditorCanvasTitle => 'Live canvas';

  @override
  String get designEditorCanvasUntitled => 'Untitled template';

  @override
  String get designEditorAutosaveInProgress => 'Autosaving…';

  @override
  String get designEditorAutosaveIdle => 'Adjustments save automatically.';

  @override
  String designEditorAutosaveCompleted(String time) {
    return 'Saved at $time';
  }

  @override
  String get designEditorPropertiesHeading => 'Properties';

  @override
  String get designRegistrabilityTitle => 'Registrability check';

  @override
  String get designRegistrabilityRefreshTooltip => 'Run check again';

  @override
  String get designRegistrabilityIncompleteTitle => 'Finish the design setup';

  @override
  String get designRegistrabilityIncompleteBody =>
      'Select a template and enter the name to check registrability.';

  @override
  String get designRegistrabilityNoResultTitle => 'No results yet';

  @override
  String get designRegistrabilityNoResultBody =>
      'Run the registrability check to see conflicts and guidance.';

  @override
  String get designRegistrabilityRunCheck => 'Run check';

  @override
  String get designRegistrabilityOutdatedBanner =>
      'The design changed since the last check. Run it again to refresh.';

  @override
  String get designRegistrabilityOfflineTitle => 'Showing cached result';

  @override
  String get designRegistrabilityOfflineBody =>
      'We reused the last successful check while offline.';

  @override
  String get designRegistrabilityStatusSafe => 'Ready to register';

  @override
  String get designRegistrabilityStatusCaution => 'Review before submitting';

  @override
  String get designRegistrabilityStatusBlocked => 'Registration blocked';

  @override
  String designRegistrabilityCheckedAt(String timestamp) {
    return 'Checked at $timestamp';
  }

  @override
  String get designRegistrabilityCacheStale => 'Cached result may be outdated.';

  @override
  String get designRegistrabilityCacheFresh =>
      'Latest result is cached for offline use.';

  @override
  String get designRegistrabilityRunFailed =>
      'Could not start the check. Please try again.';

  @override
  String get designRegistrabilityOutdatedHint =>
      'Run the check again to reflect recent adjustments.';

  @override
  String designRegistrabilityScore(String value) {
    return 'Score $value';
  }

  @override
  String get designRegistrabilityDiagnosticsTitle => 'Diagnostics';

  @override
  String get designRegistrabilityBadgeSafe => 'Safe';

  @override
  String get designRegistrabilityBadgeSimilar => 'Similar';

  @override
  String get designRegistrabilityBadgeConflict => 'Conflict';

  @override
  String get designRegistrabilityBadgeInfo => 'Notice';

  @override
  String get designRegistrabilityConflictTitle => 'Conflicts detected';

  @override
  String get designRegistrabilityConflictBody =>
      'Resolve the conflicts below before submitting.';

  @override
  String get designEditorStrokeLabel => 'Stroke weight';

  @override
  String designEditorStrokeValue(String weight) {
    return '$weight pt';
  }

  @override
  String get designEditorMarginLabel => 'Margins';

  @override
  String designEditorMarginValue(String value) {
    return '$value px';
  }

  @override
  String get designEditorRotationLabel => 'Rotation';

  @override
  String designEditorRotationValue(String value) {
    return '$value deg';
  }

  @override
  String get designEditorGridLabel => 'Grid overlay';

  @override
  String get designEditorGridNone => 'None';

  @override
  String get designEditorGridSquare => 'Square';

  @override
  String get designEditorGridRadial => 'Radial';

  @override
  String get designEditorAlignmentLabel => 'Alignment';

  @override
  String get designEditorAlignCenter => 'Center';

  @override
  String get designEditorAlignTop => 'Top';

  @override
  String get designEditorAlignBottom => 'Bottom';

  @override
  String get designEditorAlignLeft => 'Left';

  @override
  String get designEditorAlignRight => 'Right';

  @override
  String get designEditorPreviewPlaceholder => 'Preview will open soon.';

  @override
  String get designPreviewTitle => 'Preview & Share';

  @override
  String get designPreviewShareTooltip => 'Share preview';

  @override
  String get designPreviewEditTooltip => 'Back to editor';

  @override
  String get designPreviewMissingSelection =>
      'Choose a template and enter text before viewing the preview.';

  @override
  String get designPreviewExportCta => 'Share or export';

  @override
  String get designPreviewBackToEditor => 'Reopen editor';

  @override
  String designPreviewActualSizeLabel(String sizeMm, String sizeInch) {
    return 'Actual size · $sizeMm mm · $sizeInch in';
  }

  @override
  String get designPreviewActualSizeHint =>
      'Hold your device upright to inspect the stamp at 1:1 scale. Pinch to zoom for details.';

  @override
  String get designPreviewBackgroundLabel => 'Background';

  @override
  String get designPreviewBackgroundPaper => 'Paper';

  @override
  String get designPreviewBackgroundWood => 'Wood';

  @override
  String get designPreviewBackgroundTransparent => 'Transparent';

  @override
  String get designPreviewLightingLabel => 'Lighting';

  @override
  String get designPreviewLightingNone => 'None';

  @override
  String get designPreviewLightingSoft => 'Soft light';

  @override
  String get designPreviewLightingStudio => 'Studio glow';

  @override
  String get designPreviewMeasurementToggle => 'Display measurement overlay';

  @override
  String get designPreviewMeasurementHint =>
      'Shows horizontal and vertical guides with millimeter and inch values.';

  @override
  String get designPreviewShareSheetTitle => 'Share design';

  @override
  String get designPreviewShareSheetSubtitle =>
      'Send a quick preview to collaborators or save it for reference.';

  @override
  String get designPreviewShareOptionSave => 'Save to device';

  @override
  String get designPreviewShareOptionSaveSubtitle =>
      'Export a high-resolution PNG to your gallery.';

  @override
  String get designPreviewShareOptionMessage => 'Send via messages';

  @override
  String get designPreviewShareOptionMessageSubtitle =>
      'Share a lightweight preview through chat apps.';

  @override
  String get designPreviewShareOptionLink => 'Copy link';

  @override
  String get designPreviewShareOptionLinkSubtitle =>
      'Generate a shareable link when available.';

  @override
  String get designPreviewShareCancel => 'Cancel';

  @override
  String get designShareTitle => 'Share mockups';

  @override
  String get designShareSubtitle =>
      'Craft social-ready previews with watermarks, captions, and hashtags.';

  @override
  String get designShareCloseTooltip => 'Close share screen';

  @override
  String get designShareCopyLinkTooltip => 'Copy public link';

  @override
  String get designShareMissingSelection =>
      'Select a template and enter content before generating share assets.';

  @override
  String get designShareWatermarkLabel => 'Hanko Field';

  @override
  String get designShareWatermarkToggleTitle => 'Apply Hanko Field watermark';

  @override
  String get designShareWatermarkToggleSubtitle =>
      'Adds a subtle diagonal watermark for early previews.';

  @override
  String get designShareHashtagToggleTitle => 'Append hashtags';

  @override
  String get designShareHashtagToggleSubtitle =>
      'Include recommended hashtags when sharing.';

  @override
  String get designShareCaptionLabel => 'Share caption';

  @override
  String get designShareCaptionHint =>
      'Write a short caption or use a suggestion below.';

  @override
  String get designShareSuggestionsLabel => 'Quick copy';

  @override
  String get designShareSuggestionCelebrationLabel => 'Announcement';

  @override
  String get designShareSuggestionCraftLabel => 'Craft story';

  @override
  String get designShareSuggestionLaunchLabel => 'Launch hype';

  @override
  String designShareSuggestionCelebrationText(String name) {
    return 'Celebrating the new seal for $name.';
  }

  @override
  String designShareSuggestionCraftText(String style, String name) {
    return 'Hand-finished $style impression prepared for $name.';
  }

  @override
  String designShareSuggestionCraftTextAlt(String name) {
    return 'Hand-finished seal impression prepared for $name.';
  }

  @override
  String designShareSuggestionLaunchText(String name) {
    return 'Getting $name\'s brand ready for launch with this seal.';
  }

  @override
  String get designShareHashtagsLabel => 'Hashtags';

  @override
  String get designShareQuickTargetsLabel => 'Quick targets';

  @override
  String get designShareAssistInstagram => 'Instagram feed';

  @override
  String get designShareAssistX => 'X post';

  @override
  String get designShareAssistLinkedIn => 'LinkedIn update';

  @override
  String get designShareShareButton => 'Open share sheet';

  @override
  String designShareShareSubject(String platform) {
    return 'Share $platform mockup';
  }

  @override
  String get designShareShareSuccess => 'Share sheet opened.';

  @override
  String get designShareShareError =>
      'We couldn\'t prepare the mockup. Try again.';

  @override
  String get designShareCopySuccess => 'Link copied to clipboard.';

  @override
  String designShareDefaultCaption(String name, String platform) {
    return 'Showcasing $name\'s seal on $platform.';
  }

  @override
  String get designSharePlatformInstagram => 'Instagram';

  @override
  String get designSharePlatformX => 'X';

  @override
  String get designSharePlatformLinkedIn => 'LinkedIn';

  @override
  String get designShareBackgroundSunsetGlow => 'Sunset glow';

  @override
  String get designShareBackgroundMorningMist => 'Morning mist';

  @override
  String get designShareBackgroundNeoNoir => 'Neo noir';

  @override
  String get designShareBackgroundMidnight => 'Midnight';

  @override
  String get designShareBackgroundCyanGrid => 'Cyan grid';

  @override
  String get designShareBackgroundGraphite => 'Graphite';

  @override
  String get designShareBackgroundStudio => 'Studio light';

  @override
  String get designShareBackgroundNavySlate => 'Navy slate';

  @override
  String get designShareBackgroundAquaFocus => 'Aqua focus';

  @override
  String designShareLastShared(String date, String time) {
    return 'Last shared on $date at $time';
  }

  @override
  String get designVersionHistoryTitle => 'Version history';

  @override
  String get designVersionHistoryShowAllTooltip => 'Show all fields';

  @override
  String get designVersionHistoryShowChangesTooltip => 'Highlight changes only';

  @override
  String get designVersionHistoryEmptyState =>
      'No previous versions yet. Restore points appear after you save updates.';

  @override
  String designVersionHistoryRestoredSnack(int version) {
    return 'Version v$version restored.';
  }

  @override
  String designVersionHistoryDuplicatedSnack(String designId) {
    return 'Duplicated as $designId.';
  }

  @override
  String get designVersionHistoryTimelineTitle => 'History timeline';

  @override
  String get designVersionHistoryTimelineSubtitle =>
      'Select a version to compare and restore.';

  @override
  String get designVersionHistoryRefreshTooltip => 'Refresh versions';

  @override
  String get designVersionHistoryStatusCurrent => 'Current';

  @override
  String get designVersionHistoryStatusArchived => 'Archived';

  @override
  String get designVersionHistoryCurrentLabel => 'Current version';

  @override
  String designVersionHistorySelectedLabel(int version) {
    return 'Selected v$version';
  }

  @override
  String get designVersionHistoryDiffTitle => 'Diff overview';

  @override
  String get designVersionHistoryDiffHighlightSubtitle =>
      'Showing changed fields only.';

  @override
  String get designVersionHistoryDiffAllSubtitle =>
      'Showing all tracked fields.';

  @override
  String get designVersionHistoryDiffNoChanges =>
      'No differences detected for the selected version.';

  @override
  String get designVersionHistoryDiffNotAvailable =>
      'Comparison data is unavailable.';

  @override
  String designVersionHistoryDiffCurrent(String value) {
    return 'Current: $value';
  }

  @override
  String designVersionHistoryDiffSelected(String value) {
    return 'Selected: $value';
  }

  @override
  String get designVersionHistoryDuplicateCta => 'Duplicate version';

  @override
  String get designVersionHistoryRestoreCta => 'Restore version';

  @override
  String get designExportTitle => 'Digital export';

  @override
  String get designExportHistoryTooltip => 'View previous exports';

  @override
  String get designExportPreviewLabel => 'Preview';

  @override
  String get designExportFormatLabel => 'Format';

  @override
  String get designExportFormatPng => 'PNG';

  @override
  String get designExportFormatSvg => 'SVG';

  @override
  String get designExportFormatPdf => 'PDF (coming soon)';

  @override
  String get designExportOptionTransparent => 'Transparent background';

  @override
  String get designExportOptionTransparentSubtitle =>
      'Removes the artboard fill so only the stamp shape is opaque.';

  @override
  String get designExportOptionBleed => 'Include bleed margin';

  @override
  String get designExportOptionBleedSubtitle =>
      'Adds a safety margin around the imprint for print layouts.';

  @override
  String get designExportOptionMetadata => 'Embed metadata';

  @override
  String get designExportOptionMetadataSubtitle =>
      'Saves creation details alongside the exported file.';

  @override
  String get designExportExportButton => 'Export file';

  @override
  String get designExportShareButton => 'Share…';

  @override
  String get designExportPermissionDenied =>
      'Storage permission is required to continue.';

  @override
  String designExportExportSuccess(String path) {
    return 'Exported to $path';
  }

  @override
  String designExportMetadataSaved(String path) {
    return 'Metadata saved as $path';
  }

  @override
  String get designExportGenericError => 'Export failed. Please try again.';

  @override
  String get designExportPdfUnavailable => 'PDF export is not available yet.';

  @override
  String get designExportShareError => 'Unable to share right now.';

  @override
  String get designExportShareSubject => 'Hanko design preview';

  @override
  String get designExportShareBody => 'Here is the latest hanko design export.';

  @override
  String get designExportDestinationTitle => 'Save to';

  @override
  String get designExportDestinationDownloads => 'Downloads folder';

  @override
  String get designExportDestinationAppStorage => 'App documents';

  @override
  String get designExportHistoryTitle => 'Recent export';

  @override
  String designExportHistorySubtitle(String format, String timestamp) {
    return '$format • $timestamp';
  }

  @override
  String get designExportHistoryEmpty => 'No exports yet.';

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

  @override
  String get ordersStatusAll => 'All';

  @override
  String get ordersFilterStatusLabel => 'Filter by status';

  @override
  String get ordersStatusInProgress => 'In progress';

  @override
  String get ordersStatusShipped => 'Shipped';

  @override
  String get ordersStatusDelivered => 'Delivered';

  @override
  String get ordersStatusCanceled => 'Canceled';

  @override
  String get ordersFilterTimeLabel => 'Time range';

  @override
  String get ordersTimeRange30Days => 'Past 30 days';

  @override
  String get ordersTimeRange90Days => 'Past 90 days';

  @override
  String get ordersTimeRange6Months => 'Past 6 months';

  @override
  String get ordersTimeRangeYear => 'Past year';

  @override
  String get ordersTimeRangeAll => 'All time';

  @override
  String ordersLastUpdatedText(Object timestamp) {
    return 'Updated $timestamp';
  }

  @override
  String get ordersListEmptyTitle => 'No orders yet';

  @override
  String get ordersListEmptyMessage =>
      'When you place an order, it will appear here along with its status and tracking.';

  @override
  String get ordersListErrorTitle => 'Orders can’t be loaded';

  @override
  String get ordersListErrorMessage =>
      'Please check your connection and try again.';

  @override
  String get ordersListRetryLabel => 'Retry';

  @override
  String get ordersListRefreshError => 'Couldn’t refresh orders.';

  @override
  String get ordersUnknownItem => 'Custom order';

  @override
  String get ordersTimelineOrdered => 'Ordered';

  @override
  String get ordersTimelineProduction => 'Production';

  @override
  String get ordersTimelineShipping => 'Shipping';

  @override
  String get ordersTimelineDelivered => 'Delivered';

  @override
  String get ordersTimelineCanceled => 'Order canceled';

  @override
  String get orderStatusPendingPayment => 'Awaiting payment';

  @override
  String get orderStatusPaid => 'Paid';

  @override
  String get orderStatusInProduction => 'In production';

  @override
  String get orderStatusReadyToShip => 'Ready to ship';

  @override
  String get orderStatusShipped => 'Shipped';

  @override
  String get orderStatusDelivered => 'Delivered';

  @override
  String get orderStatusCanceled => 'Canceled';

  @override
  String get orderDetailsTabSummary => 'Summary';

  @override
  String get orderDetailsTabTimeline => 'Timeline';

  @override
  String get orderDetailsTabFiles => 'Files';

  @override
  String orderDetailsAppBarTitle(String orderNumber) {
    return 'Order $orderNumber';
  }

  @override
  String get orderDetailsActionReorder => 'Reorder';

  @override
  String orderReorderAppBarTitle(String orderNumber) {
    return 'Reorder $orderNumber';
  }

  @override
  String orderReorderAppBarSubtitle(String date) {
    return 'Placed on $date';
  }

  @override
  String get orderReorderLoadError => 'We couldn’t load the reorder preview.';

  @override
  String get orderReorderRetryLabel => 'Retry';

  @override
  String get orderReorderBannerUnavailable =>
      'Some items are no longer available and were left unchecked.';

  @override
  String get orderReorderBannerPriceChanges =>
      'Pricing has been updated since your original order.';

  @override
  String get orderReorderNoItemsAvailable =>
      'No line items are available for reorder.';

  @override
  String orderReorderSelectionSummary(int selected, int total) {
    return '$selected of $total items selected';
  }

  @override
  String get orderReorderSelectAll => 'Select all';

  @override
  String get orderReorderSelectNone => 'Clear';

  @override
  String get orderReorderPrimaryCta => 'Move to checkout';

  @override
  String get orderReorderCancelCta => 'Cancel';

  @override
  String orderReorderQuantity(int count) {
    return 'Qty $count';
  }

  @override
  String orderReorderSkuLabel(String sku) {
    return 'SKU: $sku';
  }

  @override
  String orderReorderPriceChangeLabel(String newPrice, String oldPrice) {
    return 'New price $newPrice (was $oldPrice)';
  }

  @override
  String get orderReorderAvailabilityLowStock =>
      'Limited stock — ships a bit slower';

  @override
  String get orderReorderAvailabilityUnavailable => 'Unavailable';

  @override
  String orderReorderResultAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# items added to cart',
      one: '# item added to cart',
    );
    return '$_temp0';
  }

  @override
  String orderReorderResultSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# items unavailable',
      one: '# item unavailable',
    );
    return '$_temp0';
  }

  @override
  String get orderReorderResultPriceAdjusted => 'Latest pricing applied.';

  @override
  String get orderReorderSubmitError =>
      'We couldn’t rebuild the cart. Try again.';

  @override
  String get orderDetailsActionShare => 'Share';

  @override
  String get orderDetailsItemsSectionTitle => 'Items';

  @override
  String orderDetailsItemsSectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# items',
      one: '# item',
    );
    return '$_temp0';
  }

  @override
  String get orderDetailsTotalsSectionTitle => 'Payment summary';

  @override
  String orderDetailsLastUpdated(String timestamp) {
    return 'Synced $timestamp';
  }

  @override
  String get orderDetailsAddressesSectionTitle => 'Addresses';

  @override
  String get orderDetailsContactSectionTitle => 'Contact';

  @override
  String get orderDetailsDesignSectionTitle => 'Design snapshots';

  @override
  String get orderDetailsLoadErrorMessage => 'Order details can’t be loaded';

  @override
  String get orderDetailsRetryLabel => 'Retry';

  @override
  String get orderDetailsTimelineTabTitle => 'Production timeline';

  @override
  String get orderDetailsTimelinePlaceholder =>
      'We’ll surface production, QC, and shipping updates here.';

  @override
  String get orderDetailsTimelineLoadErrorMessage =>
      'Production updates can’t be loaded';

  @override
  String get orderDetailsActionRefresh => 'Refresh';

  @override
  String get orderDetailsProductionTimelineEmpty =>
      'No production checkpoints yet.';

  @override
  String get orderDetailsProductionTimelineStageListTitle => 'Stage history';

  @override
  String get orderDetailsProductionOverviewTitle => 'Production overview';

  @override
  String get orderDetailsProductionEstimatedCompletionLabel =>
      'Estimated completion';

  @override
  String get orderDetailsProductionEstimatedCompletionUnknown =>
      'Pending schedule';

  @override
  String get orderDetailsProductionCurrentStageLabel => 'Current stage';

  @override
  String get orderDetailsProductionOnSchedule => 'On schedule';

  @override
  String orderDetailsProductionDelay(String duration) {
    return 'Running $duration late';
  }

  @override
  String orderDetailsProductionQueue(String queue) {
    return 'Queue: $queue';
  }

  @override
  String orderDetailsProductionStation(String station) {
    return 'Station: $station';
  }

  @override
  String orderDetailsProductionOperator(String operator) {
    return 'Operator: $operator';
  }

  @override
  String get orderDetailsProductionValueUnknown => 'Not assigned';

  @override
  String get orderDetailsProductionHealthOnTrack => 'On track';

  @override
  String get orderDetailsProductionHealthAttention => 'Attention';

  @override
  String get orderDetailsProductionHealthDelayed => 'Delayed';

  @override
  String get orderDetailsProductionStageUnknown => 'Unknown stage';

  @override
  String get orderDetailsProductionStageQueued => 'Queued';

  @override
  String get orderDetailsProductionStageEngraving => 'Engraving';

  @override
  String get orderDetailsProductionStagePolishing => 'Polishing';

  @override
  String get orderDetailsProductionStageQc => 'Quality control';

  @override
  String get orderDetailsProductionStagePacked => 'Packed';

  @override
  String get orderDetailsProductionStageOnHold => 'On hold';

  @override
  String get orderDetailsProductionStageRework => 'Rework';

  @override
  String get orderDetailsProductionStageCanceled => 'Canceled';

  @override
  String orderDetailsProductionDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String orderDetailsProductionDurationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String orderDetailsProductionStageDuration(String duration) {
    return 'Elapsed $duration';
  }

  @override
  String orderDetailsProductionStageActive(String duration) {
    return 'Active for $duration';
  }

  @override
  String orderDetailsProductionQcResult(String result) {
    return 'QC result: $result';
  }

  @override
  String orderDetailsProductionQcDefects(String defects) {
    return 'Defects: $defects';
  }

  @override
  String orderDetailsProductionNotes(String notes) {
    return 'Notes: $notes';
  }

  @override
  String get orderDetailsFilesTabTitle => 'Files & documents';

  @override
  String get orderDetailsFilesPlaceholder =>
      'Invoices, certificates, and shared files will appear here.';

  @override
  String orderDetailsReorderSuccess(String orderNumber) {
    return 'Reorder for $orderNumber has been placed.';
  }

  @override
  String get orderDetailsReorderError => 'We couldn’t start the reorder.';

  @override
  String orderDetailsInvoiceSuccess(String orderNumber) {
    return 'Invoice request for $orderNumber submitted.';
  }

  @override
  String get orderDetailsInvoiceError => 'Invoice could not be requested.';

  @override
  String get orderDetailsSupportMessage =>
      'Support will reach out shortly. You can also chat from the Help tab.';

  @override
  String orderDetailsShareSubject(String orderNumber) {
    return 'Order $orderNumber summary';
  }

  @override
  String orderDetailsShareBody(String orderNumber, String total) {
    return 'Order $orderNumber total: $total.\\nCheck the Hanko Field app for details.';
  }

  @override
  String get orderDetailsActionSupport => 'Contact support';

  @override
  String get orderDetailsActionInvoice => 'Download invoice';

  @override
  String orderInvoiceAppBarTitle(String orderNumber) {
    return 'Invoice · $orderNumber';
  }

  @override
  String get orderInvoiceShareTooltip => 'Share PDF';

  @override
  String get orderInvoiceLoadError => 'We couldn’t load the invoice.';

  @override
  String get orderInvoiceRetryLabel => 'Try again';

  @override
  String orderInvoiceHeadline(String orderNumber) {
    return 'Invoice for $orderNumber';
  }

  @override
  String orderInvoiceSubHeadline(String amount) {
    return 'Total $amount';
  }

  @override
  String get orderInvoiceValueNotAvailable => 'Not available';

  @override
  String get orderInvoiceDetailsTitle => 'Details';

  @override
  String get orderInvoiceDetailsNumber => 'Invoice number';

  @override
  String get orderInvoiceDetailsIssuedOn => 'Issued on';

  @override
  String get orderInvoiceDetailsDueDate => 'Due date';

  @override
  String get orderInvoiceDetailsTotal => 'Amount due';

  @override
  String get orderInvoiceLineItemsTitle => 'Line items';

  @override
  String get orderInvoiceDownloadAction => 'Download PDF';

  @override
  String get orderInvoiceEmailAction => 'Send by email';

  @override
  String get orderInvoiceEmailPlaceholder =>
      'Email delivery will be available soon.';

  @override
  String get orderInvoicePendingMessage =>
      'Your invoice is being generated. This can take a few minutes.';

  @override
  String get orderInvoicePendingRefresh => 'Refresh status';

  @override
  String get orderInvoiceTaxStatusInclusive => 'Tax inclusive';

  @override
  String get orderInvoiceTaxStatusExclusive => 'Tax exclusive';

  @override
  String get orderInvoiceTaxStatusExempt => 'Tax exempt';

  @override
  String get orderInvoiceStatusDraft => 'Draft';

  @override
  String get orderInvoiceStatusIssued => 'Issued';

  @override
  String get orderInvoiceStatusSent => 'Sent';

  @override
  String get orderInvoiceStatusPaid => 'Paid';

  @override
  String get orderInvoiceStatusVoided => 'Voided';

  @override
  String get orderInvoicePreviewLabel => 'PDF preview';

  @override
  String get orderInvoicePreviewPending => 'Generating invoice PDF…';

  @override
  String get orderInvoicePreviewPendingHint =>
      'Pull to refresh or check again shortly.';

  @override
  String get orderInvoicePreviewOpen => 'Open preview';

  @override
  String get orderInvoicePreviewError => 'Could not open the PDF.';

  @override
  String orderInvoiceDownloadSuccess(String path) {
    return 'Saved to $path';
  }

  @override
  String get orderInvoiceDownloadError => 'Download failed.';

  @override
  String orderInvoiceShareSubject(String invoiceNumber) {
    return 'Invoice $invoiceNumber';
  }

  @override
  String orderInvoiceShareBody(String invoiceNumber) {
    return 'Here’s the invoice $invoiceNumber from Hanko Field.';
  }

  @override
  String get orderInvoiceShareError => 'We couldn’t share the invoice.';

  @override
  String get orderInvoiceErrorTitle => 'Invoice unavailable';

  @override
  String get orderDetailsSupportBannerTitle => 'Need help with this order?';

  @override
  String get orderDetailsSupportBannerMessage =>
      'Production is taking longer than expected. Let us know if you need priority handling.';

  @override
  String orderDetailsHeadline(String orderNumber) {
    return 'Order $orderNumber';
  }

  @override
  String get orderDetailsProgressTitle => 'Latest status';

  @override
  String get orderDetailsSubtotalLabel => 'Subtotal';

  @override
  String get orderDetailsDiscountLabel => 'Discounts';

  @override
  String get orderDetailsShippingLabel => 'Shipping';

  @override
  String get orderDetailsFeesLabel => 'Fees';

  @override
  String get orderDetailsTaxLabel => 'Tax';

  @override
  String get orderDetailsTotalLabel => 'Total';

  @override
  String orderDetailsQuantityLabel(int quantity) {
    return 'Qty $quantity';
  }

  @override
  String orderDetailsSkuLabel(String sku) {
    return 'SKU $sku';
  }

  @override
  String get orderDetailsShippingAddressLabel => 'Shipping address';

  @override
  String get orderDetailsBillingAddressLabel => 'Billing address';

  @override
  String get orderDetailsAddressUnavailable => 'Not provided';

  @override
  String orderDetailsPhoneLabel(String phone) {
    return 'Phone: $phone';
  }

  @override
  String orderDetailsEmailLabel(String email) {
    return 'Email: $email';
  }

  @override
  String get orderDetailsTimelinePaid => 'Payment confirmed';

  @override
  String get orderDetailsTimelinePending => 'Processing';

  @override
  String get orderDetailsUpdatedJustNow => 'just now';

  @override
  String orderDetailsUpdatedMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '# minutes ago',
      one: '# minute ago',
    );
    return '$_temp0';
  }

  @override
  String orderDetailsUpdatedHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '# hours ago',
      one: '# hour ago',
    );
    return '$_temp0';
  }

  @override
  String orderDetailsUpdatedOn(String date) {
    return 'on $date';
  }

  @override
  String get orderDetailsTrackingSectionTitle => 'Shipment tracking';

  @override
  String get orderDetailsTrackingCardTitle => 'Current shipment';

  @override
  String orderDetailsTrackingCardPending(String status) {
    return 'Tracking activates once your order ships. Current order status: $status';
  }

  @override
  String orderDetailsTrackingCardStatus(String status) {
    return 'Current status: $status';
  }

  @override
  String orderDetailsTrackingCardLatest(String event, String timestamp) {
    return 'Latest update: $event · $timestamp';
  }

  @override
  String orderDetailsTrackingCardLocation(String location) {
    return 'Location: $location';
  }

  @override
  String get orderDetailsTrackingActionLabel => 'View tracking';

  @override
  String get orderDetailsTrackingCardError => 'Tracking could not be loaded.';

  @override
  String orderTrackingAppBarTitle(String orderNumber) {
    return 'Tracking · $orderNumber';
  }

  @override
  String get orderTrackingActionViewMap => 'View on map';

  @override
  String get orderTrackingLoadError => 'We couldn’t load tracking details.';

  @override
  String get orderTrackingUnavailableTitle => 'Tracking not available yet';

  @override
  String get orderTrackingUnavailableMessage =>
      'We’ll show tracking updates here once the carrier shares them.';

  @override
  String get orderTrackingContactSupport => 'Contact support';

  @override
  String get orderTrackingSupportPending => 'Support will reach out soon.';

  @override
  String orderTrackingTimelineTitle(int count) {
    return 'Tracking updates ($count)';
  }

  @override
  String orderTrackingContactCarrierPending(String carrier) {
    return 'We’ll connect you with $carrier shortly.';
  }

  @override
  String orderTrackingCopied(String trackingId) {
    return 'Tracking ID $trackingId copied.';
  }

  @override
  String orderTrackingMapPlaceholder(String location) {
    return 'Map preview for $location is coming soon.';
  }

  @override
  String get orderTrackingMapPlaceholderGeneric =>
      'Map preview is coming soon.';

  @override
  String get orderTrackingShipmentSelectorLabel => 'Select shipment';

  @override
  String orderTrackingShipmentSelectorOption(int index, String carrier) {
    return 'Shipment $index · $carrier';
  }

  @override
  String orderTrackingUpdatedAt(String timestamp) {
    return 'Updated $timestamp';
  }

  @override
  String orderTrackingLatestLocation(String location) {
    return 'Latest location: $location';
  }

  @override
  String orderTrackingEta(String date) {
    return 'Estimated delivery: $date';
  }

  @override
  String orderTrackingTrackingIdLabel(String trackingId) {
    return 'Tracking ID: $trackingId';
  }

  @override
  String get orderTrackingContactCarrierButton => 'Contact carrier';

  @override
  String get orderTrackingCopyTrackingIdButton => 'Copy tracking ID';

  @override
  String get orderTrackingNoEventsTitle => 'No tracking events yet';

  @override
  String get orderTrackingNoEventsMessage =>
      'Check back soon for the first carrier update.';

  @override
  String orderTrackingOrderSummaryTitle(String orderNumber) {
    return 'Order $orderNumber';
  }

  @override
  String orderTrackingOrderStatus(String status) {
    return 'Order status: $status';
  }

  @override
  String get orderTrackingCarrierJapanPost => 'Japan Post';

  @override
  String get orderTrackingCarrierYamato => 'Yamato Transport';

  @override
  String get orderTrackingCarrierSagawa => 'Sagawa Express';

  @override
  String get orderTrackingCarrierDhl => 'DHL Express';

  @override
  String get orderTrackingCarrierUps => 'UPS';

  @override
  String get orderTrackingCarrierFedex => 'FedEx';

  @override
  String get orderTrackingCarrierOther => 'Other carrier';

  @override
  String get orderTrackingStatusLabelCreated => 'Label created';

  @override
  String get orderTrackingStatusInTransit => 'In transit';

  @override
  String get orderTrackingStatusOutForDelivery => 'Out for delivery';

  @override
  String get orderTrackingStatusDelivered => 'Delivered';

  @override
  String get orderTrackingStatusException => 'Exception';

  @override
  String get orderTrackingStatusCancelled => 'Canceled';

  @override
  String get orderTrackingEventLabelCreated => 'Label created';

  @override
  String get orderTrackingEventPickedUp => 'Picked up';

  @override
  String get orderTrackingEventInTransit => 'In transit';

  @override
  String get orderTrackingEventArrivedHub => 'Arrived at facility';

  @override
  String get orderTrackingEventCustomsClearance => 'Customs clearance';

  @override
  String get orderTrackingEventOutForDelivery => 'Out for delivery';

  @override
  String get orderTrackingEventDelivered => 'Delivered';

  @override
  String get orderTrackingEventException => 'Exception';

  @override
  String get orderTrackingEventReturnToSender => 'Returned to sender';
}
