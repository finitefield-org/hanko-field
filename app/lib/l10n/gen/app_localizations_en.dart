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
}
