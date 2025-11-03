import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Hanko Field'**
  String get appTitle;

  /// Title for the sample counter screen
  ///
  /// In en, this message translates to:
  /// **'Sample Counter'**
  String get counterScreenTitle;

  /// Button label to increment count
  ///
  /// In en, this message translates to:
  /// **'Increment'**
  String get increment;

  /// Displays the current counter value
  ///
  /// In en, this message translates to:
  /// **'Count: {value}'**
  String countLabel(int value);

  /// Title shown on the onboarding tutorial app bar
  ///
  /// In en, this message translates to:
  /// **'Welcome to Hanko Field'**
  String get onboardingAppBarTitle;

  /// CTA to skip the onboarding tutorial
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// CTA to go back to the previous onboarding slide
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// CTA to move to the next onboarding slide
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// CTA when finishing the onboarding tutorial
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// Label describing current step out of total steps
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String onboardingProgressLabel(int current, int total);

  /// Title for the first onboarding slide about creating designs
  ///
  /// In en, this message translates to:
  /// **'Craft your personal seal'**
  String get onboardingSlideCraftTitle;

  /// Body copy describing the creation tools available in the app
  ///
  /// In en, this message translates to:
  /// **'Create beautiful hanko impressions with guided tools and templates tailored to your needs.'**
  String get onboardingSlideCraftBody;

  /// Title for the second onboarding slide about support and guides
  ///
  /// In en, this message translates to:
  /// **'Expert support at every step'**
  String get onboardingSlideSupportTitle;

  /// Body copy describing assistance and order tracking
  ///
  /// In en, this message translates to:
  /// **'Track orders, access guides, and chat with us whenever you need help.'**
  String get onboardingSlideSupportBody;

  /// Title for the third onboarding slide about trust and security
  ///
  /// In en, this message translates to:
  /// **'Secure and ready for business'**
  String get onboardingSlideTrustTitle;

  /// Body copy describing security and reliability benefits
  ///
  /// In en, this message translates to:
  /// **'Your data stays protected while you manage signatures, deliveries, and records with confidence.'**
  String get onboardingSlideTrustBody;

  /// Title for the home tab app bar
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeAppBarTitle;

  /// Heading for the featured carousel on the home screen
  ///
  /// In en, this message translates to:
  /// **'Featured campaigns'**
  String get homeFeaturedSectionTitle;

  /// Default subtitle shown under the featured section heading
  ///
  /// In en, this message translates to:
  /// **'Curated highlights picked for your workspace.'**
  String get homeFeaturedSectionSubtitleDefault;

  /// Subtitle when personalising the featured section
  ///
  /// In en, this message translates to:
  /// **'Recommended for {persona}'**
  String homeFeaturedSectionSubtitle(String persona);

  /// Message shown when there are no featured items
  ///
  /// In en, this message translates to:
  /// **'No featured items available right now.'**
  String get homeFeaturedEmptyMessage;

  /// Generic load error message used across sections
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this section.'**
  String get homeLoadErrorMessage;

  /// Label for retry buttons on the home screen
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetryButtonLabel;

  /// Heading for the recent designs section
  ///
  /// In en, this message translates to:
  /// **'Recent designs'**
  String get homeRecentDesignsTitle;

  /// Subtitle explaining the recent designs section
  ///
  /// In en, this message translates to:
  /// **'Resume where you left off or review recent exports.'**
  String get homeRecentDesignsSubtitle;

  /// Headline for the empty state when no designs are available
  ///
  /// In en, this message translates to:
  /// **'No recent designs yet'**
  String get homeRecentDesignsEmptyTitle;

  /// Body text for the empty recent designs area
  ///
  /// In en, this message translates to:
  /// **'Start a new seal design to see your drafts and history here.'**
  String get homeRecentDesignsEmptyMessage;

  /// Primary CTA for creating a new design from the empty state
  ///
  /// In en, this message translates to:
  /// **'Start a design'**
  String get homeRecentDesignsEmptyCta;

  /// Heading for the recommended templates carousel
  ///
  /// In en, this message translates to:
  /// **'Recommended templates'**
  String get homeTemplateRecommendationsTitle;

  /// Subtitle describing the recommended templates section
  ///
  /// In en, this message translates to:
  /// **'Tailored layouts and writing styles based on your preferences.'**
  String get homeTemplateRecommendationsSubtitle;

  /// Message when template recommendations are unavailable
  ///
  /// In en, this message translates to:
  /// **'No template recommendations at the moment.'**
  String get homeTemplateRecommendationsEmpty;

  /// Design status badge for draft
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get homeDesignStatusDraft;

  /// Design status badge for ready designs
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get homeDesignStatusReady;

  /// Design status badge for ordered designs
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get homeDesignStatusOrdered;

  /// Design status badge for locked designs
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get homeDesignStatusLocked;

  /// Label describing when a design was last updated
  ///
  /// In en, this message translates to:
  /// **'Updated on {date}'**
  String homeUpdatedOn(String date);

  /// Label for the Tensho writing style chip
  ///
  /// In en, this message translates to:
  /// **'Tensho'**
  String get homeWritingStyleTensho;

  /// Label for the Reisho writing style chip
  ///
  /// In en, this message translates to:
  /// **'Reisho'**
  String get homeWritingStyleReisho;

  /// Label for the Kaisho writing style chip
  ///
  /// In en, this message translates to:
  /// **'Kaisho'**
  String get homeWritingStyleKaisho;

  /// Label for the Gyosho writing style chip
  ///
  /// In en, this message translates to:
  /// **'Gyosho'**
  String get homeWritingStyleGyosho;

  /// Label for the Koentai writing style chip
  ///
  /// In en, this message translates to:
  /// **'Koentai'**
  String get homeWritingStyleKoentai;

  /// Label for custom writing style chip
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get homeWritingStyleCustom;

  /// Label for round shape chip
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get homeShapeRound;

  /// Label for square shape chip
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get homeShapeSquare;

  /// Title for the design type selection screen
  ///
  /// In en, this message translates to:
  /// **'Start a new seal'**
  String get designNewTitle;

  /// Subtitle explaining the available creation modes
  ///
  /// In en, this message translates to:
  /// **'Choose how you\'d like to create your seal design.'**
  String get designNewSubtitle;

  /// Tooltip for the help icon on the design creation entry screen
  ///
  /// In en, this message translates to:
  /// **'Help for design creation'**
  String get designNewHelpTooltip;

  /// Label for the primary action button advancing the creation flow
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get designNewContinueLabel;

  /// Quick filter chip label for personal seal use cases
  ///
  /// In en, this message translates to:
  /// **'Personal seal'**
  String get designNewFilterPersonal;

  /// Quick filter chip label for business use cases
  ///
  /// In en, this message translates to:
  /// **'Business use'**
  String get designNewFilterBusiness;

  /// Quick filter chip label for gift or ceremonial use cases
  ///
  /// In en, this message translates to:
  /// **'Gift / ceremonial'**
  String get designNewFilterGift;

  /// Card title for the typed input creation mode
  ///
  /// In en, this message translates to:
  /// **'Type your name'**
  String get designNewOptionTypedTitle;

  /// Description for the typed input creation mode card
  ///
  /// In en, this message translates to:
  /// **'Enter kanji or romaji and preview layouts instantly.'**
  String get designNewOptionTypedDescription;

  /// Card title for the upload creation mode
  ///
  /// In en, this message translates to:
  /// **'Upload artwork'**
  String get designNewOptionUploadTitle;

  /// Description for the upload creation mode card
  ///
  /// In en, this message translates to:
  /// **'Import an existing seal image to refine or trace.'**
  String get designNewOptionUploadDescription;

  /// Card title for the logo engraving mode
  ///
  /// In en, this message translates to:
  /// **'Engrave a logo'**
  String get designNewOptionLogoTitle;

  /// Description for the logo engraving mode card
  ///
  /// In en, this message translates to:
  /// **'Provide brand marks or vector files for engraving guidance.'**
  String get designNewOptionLogoDescription;

  /// Section title for the feature highlight list
  ///
  /// In en, this message translates to:
  /// **'What you get in each mode'**
  String get designNewHighlightsTitle;

  /// Feature highlight title for AI support
  ///
  /// In en, this message translates to:
  /// **'AI assistance'**
  String get designNewHighlightsAiTitle;

  /// Feature highlight body text describing AI support
  ///
  /// In en, this message translates to:
  /// **'Receive smart suggestions for layouts, naming, and visual balance.'**
  String get designNewHighlightsAiBody;

  /// Title for the AI suggestions page in the design flow
  ///
  /// In en, this message translates to:
  /// **'AI suggestions'**
  String get designAiSuggestionsTitle;

  /// Tooltip for the queue badge icon in the AI suggestions page
  ///
  /// In en, this message translates to:
  /// **'Queued proposals'**
  String get designAiSuggestionsQueueTooltip;

  /// Snackbar message shown when an AI request is successfully queued
  ///
  /// In en, this message translates to:
  /// **'AI job queued. We\'ll add new proposals shortly.'**
  String get designAiSuggestionsRequestQueued;

  /// Snackbar message shown when the user hits the rate limit for AI requests
  ///
  /// In en, this message translates to:
  /// **'Please wait {seconds} seconds before requesting again.'**
  String designAiSuggestionsRequestRateLimited(int seconds);

  /// Generic error message for AI suggestion operations
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update suggestions. Please try again.'**
  String get designAiSuggestionsGenericError;

  /// Label for the segmented button showing ready suggestions
  ///
  /// In en, this message translates to:
  /// **'Ready ({count})'**
  String designAiSuggestionsSegmentReady(int count);

  /// Label for the segmented button showing queued suggestions
  ///
  /// In en, this message translates to:
  /// **'Queued ({count})'**
  String designAiSuggestionsSegmentQueued(int count);

  /// Label for the segmented button showing applied suggestions
  ///
  /// In en, this message translates to:
  /// **'Applied ({count})'**
  String designAiSuggestionsSegmentApplied(int count);

  /// Headline for the AI helper card at the top of the suggestions page
  ///
  /// In en, this message translates to:
  /// **'Need a fresh take?'**
  String get designAiSuggestionsHelperTitle;

  /// Supporting copy under the helper headline on the AI page
  ///
  /// In en, this message translates to:
  /// **'Queue a proposal and we\'ll compare it with your current design, highlighting balance and spacing tweaks.'**
  String get designAiSuggestionsHelperSubtitle;

  /// Primary CTA to request new AI suggestions
  ///
  /// In en, this message translates to:
  /// **'Request new proposals'**
  String get designAiSuggestionsRequestCta;

  /// Hint text displayed while the user is rate limited from requesting AI suggestions
  ///
  /// In en, this message translates to:
  /// **'Next request available in {seconds}s'**
  String designAiSuggestionsRateLimitCountdown(int seconds);

  /// Title shown when there are no ready AI suggestions
  ///
  /// In en, this message translates to:
  /// **'No proposals yet'**
  String get designAiSuggestionsEmptyReadyTitle;

  /// Body copy shown when there are no ready suggestions
  ///
  /// In en, this message translates to:
  /// **'Ask the AI for layout ideas to compare against your baseline design.'**
  String get designAiSuggestionsEmptyReadyBody;

  /// Title shown when there are no queued AI suggestions
  ///
  /// In en, this message translates to:
  /// **'Queue is clear'**
  String get designAiSuggestionsEmptyQueuedTitle;

  /// Body copy shown when the queued list is empty
  ///
  /// In en, this message translates to:
  /// **'Request more proposals when you\'re ready. We\'ll process them in the background.'**
  String get designAiSuggestionsEmptyQueuedBody;

  /// Title shown when the user hasn't applied any AI suggestions
  ///
  /// In en, this message translates to:
  /// **'No applied proposals'**
  String get designAiSuggestionsEmptyAppliedTitle;

  /// Body copy for the empty state of applied suggestions
  ///
  /// In en, this message translates to:
  /// **'Accepted proposals will show here so you can revisit the history of changes.'**
  String get designAiSuggestionsEmptyAppliedBody;

  /// Snackbar message shown when an AI suggestion is accepted
  ///
  /// In en, this message translates to:
  /// **'Applied \"{title}\" to your design.'**
  String designAiSuggestionsAcceptSuccess(String title);

  /// Snackbar message shown when an AI suggestion is rejected
  ///
  /// In en, this message translates to:
  /// **'Dismissed \"{title}\".'**
  String designAiSuggestionsRejectSuccess(String title);

  /// Label for the accept button on an AI suggestion card
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get designAiSuggestionsAccept;

  /// Label for the reject button on an AI suggestion card
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get designAiSuggestionsReject;

  /// Badge text shown on cards that were already applied
  ///
  /// In en, this message translates to:
  /// **'Applied to your draft'**
  String get designAiSuggestionsAppliedLabel;

  /// Badge text shown on queued suggestion cards
  ///
  /// In en, this message translates to:
  /// **'Waiting for processing'**
  String get designAiSuggestionsQueuedLabel;

  /// Label showing the AI confidence/quality score
  ///
  /// In en, this message translates to:
  /// **'Score {percent}%'**
  String designAiSuggestionsScoreLabel(int percent);

  /// Hint text shown next to the comparison slider
  ///
  /// In en, this message translates to:
  /// **'Drag to compare'**
  String get designAiSuggestionsComparisonHint;

  /// Feature highlight title for templates
  ///
  /// In en, this message translates to:
  /// **'Templates & fonts'**
  String get designNewHighlightsTemplateTitle;

  /// Feature highlight body text for templates
  ///
  /// In en, this message translates to:
  /// **'Browse curated scripts and templates tuned for Japanese seals.'**
  String get designNewHighlightsTemplateBody;

  /// Feature highlight title for cloud syncing
  ///
  /// In en, this message translates to:
  /// **'Cloud workspace'**
  String get designNewHighlightsCloudTitle;

  /// Feature highlight body text for cloud syncing
  ///
  /// In en, this message translates to:
  /// **'Keep uploads synced securely so you can resume on any device.'**
  String get designNewHighlightsCloudBody;

  /// Snackbar message shown when storage permission is missing
  ///
  /// In en, this message translates to:
  /// **'Storage access is required to continue with this mode.'**
  String get designNewPermissionDenied;

  /// Title for the name input screen
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get designInputTitle;

  /// Subtitle explaining the purpose of the name input screen
  ///
  /// In en, this message translates to:
  /// **'Provide the surname and given name that will appear on your seal. We\'ll preview it as you type.'**
  String get designInputSubtitle;

  /// Title for the preview card showing entered name
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get designInputPreviewTitle;

  /// Caption that explains the preview behaviour
  ///
  /// In en, this message translates to:
  /// **'Preview updates with your selected style later in the flow.'**
  String get designInputPreviewCaption;

  /// Placeholder text when no name has been entered yet
  ///
  /// In en, this message translates to:
  /// **'Sample Name'**
  String get designInputPlaceholderPrimary;

  /// Section header for the primary name fields
  ///
  /// In en, this message translates to:
  /// **'Name (kanji or romaji)'**
  String get designInputSectionPrimary;

  /// Section header for pronunciation fields
  ///
  /// In en, this message translates to:
  /// **'Reading / pronunciation'**
  String get designInputSectionReading;

  /// Label for the surname text field
  ///
  /// In en, this message translates to:
  /// **'Surname'**
  String get designInputSurnameLabel;

  /// Label for the given name text field
  ///
  /// In en, this message translates to:
  /// **'Given name'**
  String get designInputGivenNameLabel;

  /// Helper text guiding surname input
  ///
  /// In en, this message translates to:
  /// **'Full-width characters, up to 6 letters.'**
  String get designInputSurnameHelper;

  /// Helper text guiding given name input
  ///
  /// In en, this message translates to:
  /// **'Full-width characters, up to 6 letters.'**
  String get designInputGivenNameHelper;

  /// Label for the surname reading text field
  ///
  /// In en, this message translates to:
  /// **'Surname reading'**
  String get designInputSurnameReadingLabel;

  /// Label for the given name reading text field
  ///
  /// In en, this message translates to:
  /// **'Given name reading'**
  String get designInputGivenNameReadingLabel;

  /// Helper text for pronunciation fields
  ///
  /// In en, this message translates to:
  /// **'Use Hiragana or Katakana. Required when designing a Japanese seal.'**
  String get designInputReadingHelper;

  /// Primary action label to proceed from the name input screen
  ///
  /// In en, this message translates to:
  /// **'Choose style'**
  String get designInputContinue;

  /// Title for the style selection screen
  ///
  /// In en, this message translates to:
  /// **'Choose style & template'**
  String get designStyleTitle;

  /// Subtitle explaining the style selection screen
  ///
  /// In en, this message translates to:
  /// **'Select the script family, seal shape, and template that best matches your persona. You can fine-tune details later in the editor.'**
  String get designStyleSubtitle;

  /// Tooltip for the help button on the style selection screen
  ///
  /// In en, this message translates to:
  /// **'Typography tips'**
  String get designStyleHelpTooltip;

  /// Segmented button label for kanji script
  ///
  /// In en, this message translates to:
  /// **'Kanji'**
  String get designStyleScriptKanji;

  /// Segmented button label for kana script
  ///
  /// In en, this message translates to:
  /// **'Kana'**
  String get designStyleScriptKana;

  /// Segmented button label for roman script
  ///
  /// In en, this message translates to:
  /// **'Roman'**
  String get designStyleScriptRoman;

  /// Filter chip label for round seal shape
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get designStyleShapeRound;

  /// Filter chip label for square seal shape
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get designStyleShapeSquare;

  /// Primary action after selecting a style
  ///
  /// In en, this message translates to:
  /// **'Open editor'**
  String get designStyleContinue;

  /// Assist chip label to add the template to favourites
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get designStyleFavoritesAdd;

  /// Assist chip label shown when template is already a favourite
  ///
  /// In en, this message translates to:
  /// **'Favourited'**
  String get designStyleFavoritesRemove;

  /// Empty state title when there are no templates to show
  ///
  /// In en, this message translates to:
  /// **'No templates available'**
  String get designStyleEmptyTitle;

  /// Empty state body text on the style selection screen
  ///
  /// In en, this message translates to:
  /// **'Adjust your filters or refresh to load templates that match your persona and available fonts.'**
  String get designStyleEmptyBody;

  /// Retry button label in the style selection empty state
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get designStyleRetry;

  /// Heading for the selected template details card
  ///
  /// In en, this message translates to:
  /// **'Selected template'**
  String get designStyleSelectedHeading;

  /// Title for the design editor screen
  ///
  /// In en, this message translates to:
  /// **'Design editor'**
  String get designEditorTitle;

  /// Fallback text shown on the canvas when no name is available
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get designEditorFallbackText;

  /// Label for the bottom extended FAB on the design editor screen
  ///
  /// In en, this message translates to:
  /// **'Preview & export'**
  String get designEditorPrimaryCta;

  /// Tooltip for the undo icon button
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get designEditorUndoTooltip;

  /// Tooltip for the redo icon button
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get designEditorRedoTooltip;

  /// Tooltip for the registrability check shortcut
  ///
  /// In en, this message translates to:
  /// **'Check registrability'**
  String get designEditorRegistrabilityTooltip;

  /// Tooltip for the overflow menu on the design editor app bar
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get designEditorMoreActionsTooltip;

  /// Tooltip for the version history shortcut in the design editor
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get designEditorVersionHistoryTooltip;

  /// Menu item label to reset the editor values back to the template defaults
  ///
  /// In en, this message translates to:
  /// **'Reset to template defaults'**
  String get designEditorResetMenu;

  /// Snackbar message shown after resetting the editor
  ///
  /// In en, this message translates to:
  /// **'Restored template defaults.'**
  String get designEditorResetSnackbar;

  /// Navigation rail label for the selection tool
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get designEditorToolSelect;

  /// Navigation rail label for the text tool
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get designEditorToolText;

  /// Navigation rail label for the layout tool
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get designEditorToolLayout;

  /// Navigation rail label for the export shortcuts
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get designEditorToolExport;

  /// Heading for the canvas preview section
  ///
  /// In en, this message translates to:
  /// **'Live canvas'**
  String get designEditorCanvasTitle;

  /// Subtitle shown when the template has no title
  ///
  /// In en, this message translates to:
  /// **'Untitled template'**
  String get designEditorCanvasUntitled;

  /// Status label shown while autosave is running
  ///
  /// In en, this message translates to:
  /// **'Autosaving…'**
  String get designEditorAutosaveInProgress;

  /// Status label when nothing has been saved yet
  ///
  /// In en, this message translates to:
  /// **'Adjustments save automatically.'**
  String get designEditorAutosaveIdle;

  /// Status label showing when the last autosave happened
  ///
  /// In en, this message translates to:
  /// **'Saved at {time}'**
  String designEditorAutosaveCompleted(String time);

  /// Heading for the property sheet
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get designEditorPropertiesHeading;

  /// App bar title for the registrability check screen
  ///
  /// In en, this message translates to:
  /// **'Registrability check'**
  String get designRegistrabilityTitle;

  /// Tooltip for refresh icon on the registrability screen
  ///
  /// In en, this message translates to:
  /// **'Run check again'**
  String get designRegistrabilityRefreshTooltip;

  /// Placeholder title when the design is not ready for checks
  ///
  /// In en, this message translates to:
  /// **'Finish the design setup'**
  String get designRegistrabilityIncompleteTitle;

  /// Placeholder body when registrability cannot run yet
  ///
  /// In en, this message translates to:
  /// **'Select a template and enter the name to check registrability.'**
  String get designRegistrabilityIncompleteBody;

  /// Card title shown before the first registrability run
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get designRegistrabilityNoResultTitle;

  /// Card body prompting the user to run the check
  ///
  /// In en, this message translates to:
  /// **'Run the registrability check to see conflicts and guidance.'**
  String get designRegistrabilityNoResultBody;

  /// Button label to trigger registrability evaluation
  ///
  /// In en, this message translates to:
  /// **'Run check'**
  String get designRegistrabilityRunCheck;

  /// Banner copy when the stored check is outdated
  ///
  /// In en, this message translates to:
  /// **'The design changed since the last check. Run it again to refresh.'**
  String get designRegistrabilityOutdatedBanner;

  /// Title when displaying cached registrability data
  ///
  /// In en, this message translates to:
  /// **'Showing cached result'**
  String get designRegistrabilityOfflineTitle;

  /// Body text explaining cached fallback usage
  ///
  /// In en, this message translates to:
  /// **'We reused the last successful check while offline.'**
  String get designRegistrabilityOfflineBody;

  /// Status headline when no issues were found
  ///
  /// In en, this message translates to:
  /// **'Ready to register'**
  String get designRegistrabilityStatusSafe;

  /// Status headline when warnings were found
  ///
  /// In en, this message translates to:
  /// **'Review before submitting'**
  String get designRegistrabilityStatusCaution;

  /// Status headline when registration is not allowed
  ///
  /// In en, this message translates to:
  /// **'Registration blocked'**
  String get designRegistrabilityStatusBlocked;

  /// Label describing when the registrability check was performed
  ///
  /// In en, this message translates to:
  /// **'Checked at {timestamp}'**
  String designRegistrabilityCheckedAt(String timestamp);

  /// Label when cached result is stale
  ///
  /// In en, this message translates to:
  /// **'Cached result may be outdated.'**
  String get designRegistrabilityCacheStale;

  /// Label when cached result is fresh
  ///
  /// In en, this message translates to:
  /// **'Latest result is cached for offline use.'**
  String get designRegistrabilityCacheFresh;

  /// Snackbar message shown when the registrability request fails to start
  ///
  /// In en, this message translates to:
  /// **'Could not start the check. Please try again.'**
  String get designRegistrabilityRunFailed;

  /// Hint text under the summary card when outdated
  ///
  /// In en, this message translates to:
  /// **'Run the check again to reflect recent adjustments.'**
  String get designRegistrabilityOutdatedHint;

  /// Chip label showing registrability score
  ///
  /// In en, this message translates to:
  /// **'Score {value}'**
  String designRegistrabilityScore(String value);

  /// Heading for the diagnostics list
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get designRegistrabilityDiagnosticsTitle;

  /// Assist chip label for safe diagnostic
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get designRegistrabilityBadgeSafe;

  /// Assist chip label for similar diagnostic
  ///
  /// In en, this message translates to:
  /// **'Similar'**
  String get designRegistrabilityBadgeSimilar;

  /// Assist chip label for conflict diagnostic
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get designRegistrabilityBadgeConflict;

  /// Assist chip label for informational diagnostic
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get designRegistrabilityBadgeInfo;

  /// Title for conflict banner
  ///
  /// In en, this message translates to:
  /// **'Conflicts detected'**
  String get designRegistrabilityConflictTitle;

  /// Default message under the conflict banner
  ///
  /// In en, this message translates to:
  /// **'Resolve the conflicts below before submitting.'**
  String get designRegistrabilityConflictBody;

  /// Label for the stroke weight slider control
  ///
  /// In en, this message translates to:
  /// **'Stroke weight'**
  String get designEditorStrokeLabel;

  /// Slider value label for stroke width
  ///
  /// In en, this message translates to:
  /// **'{weight} pt'**
  String designEditorStrokeValue(String weight);

  /// Label for the margin slider control
  ///
  /// In en, this message translates to:
  /// **'Margins'**
  String get designEditorMarginLabel;

  /// Slider value label for margin amount
  ///
  /// In en, this message translates to:
  /// **'{value} px'**
  String designEditorMarginValue(String value);

  /// Label for the rotation slider control
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get designEditorRotationLabel;

  /// Slider value label for rotation
  ///
  /// In en, this message translates to:
  /// **'{value} deg'**
  String designEditorRotationValue(String value);

  /// Label for the grid toggle segmented button
  ///
  /// In en, this message translates to:
  /// **'Grid overlay'**
  String get designEditorGridLabel;

  /// Grid option label for none
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get designEditorGridNone;

  /// Grid option label for square grids
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get designEditorGridSquare;

  /// Grid option label for radial guides
  ///
  /// In en, this message translates to:
  /// **'Radial'**
  String get designEditorGridRadial;

  /// Label for the alignment segmented button
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get designEditorAlignmentLabel;

  /// Alignment option label for center
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get designEditorAlignCenter;

  /// Alignment option label for top
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get designEditorAlignTop;

  /// Alignment option label for bottom
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get designEditorAlignBottom;

  /// Alignment option label for left
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get designEditorAlignLeft;

  /// Alignment option label for right
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get designEditorAlignRight;

  /// Placeholder snackbar message for the preview/export action
  ///
  /// In en, this message translates to:
  /// **'Preview will open soon.'**
  String get designEditorPreviewPlaceholder;

  /// Title for the design preview screen
  ///
  /// In en, this message translates to:
  /// **'Preview & Share'**
  String get designPreviewTitle;

  /// Tooltip for the share icon in the preview screen app bar
  ///
  /// In en, this message translates to:
  /// **'Share preview'**
  String get designPreviewShareTooltip;

  /// Tooltip for the edit/back icon in the preview screen app bar
  ///
  /// In en, this message translates to:
  /// **'Back to editor'**
  String get designPreviewEditTooltip;

  /// Fallback message when preview screen is opened without required state
  ///
  /// In en, this message translates to:
  /// **'Choose a template and enter text before viewing the preview.'**
  String get designPreviewMissingSelection;

  /// Primary CTA label for sharing/exporting the design from preview screen
  ///
  /// In en, this message translates to:
  /// **'Share or export'**
  String get designPreviewExportCta;

  /// Secondary CTA label returning to the editor from preview screen
  ///
  /// In en, this message translates to:
  /// **'Reopen editor'**
  String get designPreviewBackToEditor;

  /// Label describing the actual size measurement of the stamp
  ///
  /// In en, this message translates to:
  /// **'Actual size · {sizeMm} mm · {sizeInch} in'**
  String designPreviewActualSizeLabel(String sizeMm, String sizeInch);

  /// Hint text explaining how to view the design at actual size
  ///
  /// In en, this message translates to:
  /// **'Hold your device upright to inspect the stamp at 1:1 scale. Pinch to zoom for details.'**
  String get designPreviewActualSizeHint;

  /// Label for background selection controls
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get designPreviewBackgroundLabel;

  /// Segmented button label for paper background
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get designPreviewBackgroundPaper;

  /// Segmented button label for wood background
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get designPreviewBackgroundWood;

  /// Segmented button label for transparent background
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get designPreviewBackgroundTransparent;

  /// Label for lighting preset chips
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get designPreviewLightingLabel;

  /// Lighting preset for no additional lighting
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get designPreviewLightingNone;

  /// Lighting preset for a soft diffused light
  ///
  /// In en, this message translates to:
  /// **'Soft light'**
  String get designPreviewLightingSoft;

  /// Lighting preset for a studio-style highlight
  ///
  /// In en, this message translates to:
  /// **'Studio glow'**
  String get designPreviewLightingStudio;

  /// Toggle label for showing measurement overlay
  ///
  /// In en, this message translates to:
  /// **'Display measurement overlay'**
  String get designPreviewMeasurementToggle;

  /// Helper text describing the measurement overlay
  ///
  /// In en, this message translates to:
  /// **'Shows horizontal and vertical guides with millimeter and inch values.'**
  String get designPreviewMeasurementHint;

  /// Title for the bottom sheet with share options
  ///
  /// In en, this message translates to:
  /// **'Share design'**
  String get designPreviewShareSheetTitle;

  /// Subtitle for the share options sheet
  ///
  /// In en, this message translates to:
  /// **'Send a quick preview to collaborators or save it for reference.'**
  String get designPreviewShareSheetSubtitle;

  /// Share option to save the design locally
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get designPreviewShareOptionSave;

  /// Subtitle describing the save-to-device share option
  ///
  /// In en, this message translates to:
  /// **'Export a high-resolution PNG to your gallery.'**
  String get designPreviewShareOptionSaveSubtitle;

  /// Share option for messaging apps
  ///
  /// In en, this message translates to:
  /// **'Send via messages'**
  String get designPreviewShareOptionMessage;

  /// Subtitle for the messaging share option
  ///
  /// In en, this message translates to:
  /// **'Share a lightweight preview through chat apps.'**
  String get designPreviewShareOptionMessageSubtitle;

  /// Share option to copy a link
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get designPreviewShareOptionLink;

  /// Subtitle for the copy-link share option
  ///
  /// In en, this message translates to:
  /// **'Generate a shareable link when available.'**
  String get designPreviewShareOptionLinkSubtitle;

  /// Button label to dismiss the share sheet
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get designPreviewShareCancel;

  /// Title for the share screen
  ///
  /// In en, this message translates to:
  /// **'Share mockups'**
  String get designShareTitle;

  /// Subtitle shown on the share screen explaining its purpose
  ///
  /// In en, this message translates to:
  /// **'Craft social-ready previews with watermarks, captions, and hashtags.'**
  String get designShareSubtitle;

  /// Tooltip for the close button in the share screen app bar
  ///
  /// In en, this message translates to:
  /// **'Close share screen'**
  String get designShareCloseTooltip;

  /// Tooltip for the copy link button in the share screen app bar
  ///
  /// In en, this message translates to:
  /// **'Copy public link'**
  String get designShareCopyLinkTooltip;

  /// Message shown when the share screen is opened without a valid design selection
  ///
  /// In en, this message translates to:
  /// **'Select a template and enter content before generating share assets.'**
  String get designShareMissingSelection;

  /// Text used for the watermark overlay
  ///
  /// In en, this message translates to:
  /// **'Hanko Field'**
  String get designShareWatermarkLabel;

  /// Title for the toggle that controls the watermark overlay
  ///
  /// In en, this message translates to:
  /// **'Apply Hanko Field watermark'**
  String get designShareWatermarkToggleTitle;

  /// Subtitle describing the watermark toggle
  ///
  /// In en, this message translates to:
  /// **'Adds a subtle diagonal watermark for early previews.'**
  String get designShareWatermarkToggleSubtitle;

  /// Title for the toggle that controls whether hashtags are included
  ///
  /// In en, this message translates to:
  /// **'Append hashtags'**
  String get designShareHashtagToggleTitle;

  /// Subtitle for the hashtag toggle
  ///
  /// In en, this message translates to:
  /// **'Include recommended hashtags when sharing.'**
  String get designShareHashtagToggleSubtitle;

  /// Label above the share caption text field
  ///
  /// In en, this message translates to:
  /// **'Share caption'**
  String get designShareCaptionLabel;

  /// Hint text inside the caption text field
  ///
  /// In en, this message translates to:
  /// **'Write a short caption or use a suggestion below.'**
  String get designShareCaptionHint;

  /// Heading for suggested caption chips
  ///
  /// In en, this message translates to:
  /// **'Quick copy'**
  String get designShareSuggestionsLabel;

  /// Label for the celebration caption suggestion
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get designShareSuggestionCelebrationLabel;

  /// Label for the craft caption suggestion
  ///
  /// In en, this message translates to:
  /// **'Craft story'**
  String get designShareSuggestionCraftLabel;

  /// Label for the launch caption suggestion
  ///
  /// In en, this message translates to:
  /// **'Launch hype'**
  String get designShareSuggestionLaunchLabel;

  /// Caption copy for the celebration preset
  ///
  /// In en, this message translates to:
  /// **'Celebrating the new seal for {name}.'**
  String designShareSuggestionCelebrationText(String name);

  /// Caption copy for the craft preset
  ///
  /// In en, this message translates to:
  /// **'Hand-finished {style} impression prepared for {name}.'**
  String designShareSuggestionCraftText(String style, String name);

  /// Fallback craft caption when no style name is available
  ///
  /// In en, this message translates to:
  /// **'Hand-finished seal impression prepared for {name}.'**
  String designShareSuggestionCraftTextAlt(String name);

  /// Caption copy for the launch preset
  ///
  /// In en, this message translates to:
  /// **'Getting {name}\'s brand ready for launch with this seal.'**
  String designShareSuggestionLaunchText(String name);

  /// Heading above the hashtag chips
  ///
  /// In en, this message translates to:
  /// **'Hashtags'**
  String get designShareHashtagsLabel;

  /// Heading for the assist chips that switch platforms
  ///
  /// In en, this message translates to:
  /// **'Quick targets'**
  String get designShareQuickTargetsLabel;

  /// Label for the Instagram assist chip
  ///
  /// In en, this message translates to:
  /// **'Instagram feed'**
  String get designShareAssistInstagram;

  /// Label for the X assist chip
  ///
  /// In en, this message translates to:
  /// **'X post'**
  String get designShareAssistX;

  /// Label for the LinkedIn assist chip
  ///
  /// In en, this message translates to:
  /// **'LinkedIn update'**
  String get designShareAssistLinkedIn;

  /// Label for the button that launches the native share sheet
  ///
  /// In en, this message translates to:
  /// **'Open share sheet'**
  String get designShareShareButton;

  /// Subject provided to the share sheet
  ///
  /// In en, this message translates to:
  /// **'Share {platform} mockup'**
  String designShareShareSubject(String platform);

  /// Snackbar message when share succeeds
  ///
  /// In en, this message translates to:
  /// **'Share sheet opened.'**
  String get designShareShareSuccess;

  /// Snackbar message when share fails
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t prepare the mockup. Try again.'**
  String get designShareShareError;

  /// Snackbar message after copying the share link
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard.'**
  String get designShareCopySuccess;

  /// Fallback caption used when the custom caption is empty
  ///
  /// In en, this message translates to:
  /// **'Showcasing {name}\'s seal on {platform}.'**
  String designShareDefaultCaption(String name, String platform);

  /// Readable name for Instagram
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get designSharePlatformInstagram;

  /// Readable name for X/Twitter
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get designSharePlatformX;

  /// Readable name for LinkedIn
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get designSharePlatformLinkedIn;

  /// Label for the sunset background
  ///
  /// In en, this message translates to:
  /// **'Sunset glow'**
  String get designShareBackgroundSunsetGlow;

  /// Label for the light neutral background
  ///
  /// In en, this message translates to:
  /// **'Morning mist'**
  String get designShareBackgroundMorningMist;

  /// Label for the dark neon background
  ///
  /// In en, this message translates to:
  /// **'Neo noir'**
  String get designShareBackgroundNeoNoir;

  /// Label for the midnight gradient background
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get designShareBackgroundMidnight;

  /// Label for the cyan gradient background
  ///
  /// In en, this message translates to:
  /// **'Cyan grid'**
  String get designShareBackgroundCyanGrid;

  /// Label for the graphite gradient background
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get designShareBackgroundGraphite;

  /// Label for the neutral studio background
  ///
  /// In en, this message translates to:
  /// **'Studio light'**
  String get designShareBackgroundStudio;

  /// Label for the navy background
  ///
  /// In en, this message translates to:
  /// **'Navy slate'**
  String get designShareBackgroundNavySlate;

  /// Label for the aqua background
  ///
  /// In en, this message translates to:
  /// **'Aqua focus'**
  String get designShareBackgroundAquaFocus;

  /// Message showing the last successful share timestamp
  ///
  /// In en, this message translates to:
  /// **'Last shared on {date} at {time}'**
  String designShareLastShared(String date, String time);

  /// Title for the design version history screen
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get designVersionHistoryTitle;

  /// Tooltip for showing all tracked fields in the diff view
  ///
  /// In en, this message translates to:
  /// **'Show all fields'**
  String get designVersionHistoryShowAllTooltip;

  /// Tooltip for showing only the fields that changed in the diff view
  ///
  /// In en, this message translates to:
  /// **'Highlight changes only'**
  String get designVersionHistoryShowChangesTooltip;

  /// Empty state message when no design versions are available
  ///
  /// In en, this message translates to:
  /// **'No previous versions yet. Restore points appear after you save updates.'**
  String get designVersionHistoryEmptyState;

  /// Snackbar message shown after restoring a version
  ///
  /// In en, this message translates to:
  /// **'Version v{version} restored.'**
  String designVersionHistoryRestoredSnack(int version);

  /// Snackbar message shown after duplicating a version
  ///
  /// In en, this message translates to:
  /// **'Duplicated as {designId}.'**
  String designVersionHistoryDuplicatedSnack(String designId);

  /// Heading for the version timeline card
  ///
  /// In en, this message translates to:
  /// **'History timeline'**
  String get designVersionHistoryTimelineTitle;

  /// Subtitle describing how to use the version timeline
  ///
  /// In en, this message translates to:
  /// **'Select a version to compare and restore.'**
  String get designVersionHistoryTimelineSubtitle;

  /// Tooltip for reloading the version history list
  ///
  /// In en, this message translates to:
  /// **'Refresh versions'**
  String get designVersionHistoryRefreshTooltip;

  /// Assist chip label for the current version
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get designVersionHistoryStatusCurrent;

  /// Assist chip label for archived versions
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get designVersionHistoryStatusArchived;

  /// Header label shown on the current version preview card
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get designVersionHistoryCurrentLabel;

  /// Header label shown on the selected version preview card
  ///
  /// In en, this message translates to:
  /// **'Selected v{version}'**
  String designVersionHistorySelectedLabel(int version);

  /// Heading for the diff comparison card
  ///
  /// In en, this message translates to:
  /// **'Diff overview'**
  String get designVersionHistoryDiffTitle;

  /// Subtitle shown when highlighting changed fields
  ///
  /// In en, this message translates to:
  /// **'Showing changed fields only.'**
  String get designVersionHistoryDiffHighlightSubtitle;

  /// Subtitle shown when displaying all diff fields
  ///
  /// In en, this message translates to:
  /// **'Showing all tracked fields.'**
  String get designVersionHistoryDiffAllSubtitle;

  /// Message shown when there are no diff changes
  ///
  /// In en, this message translates to:
  /// **'No differences detected for the selected version.'**
  String get designVersionHistoryDiffNoChanges;

  /// Message shown when diff data cannot be produced
  ///
  /// In en, this message translates to:
  /// **'Comparison data is unavailable.'**
  String get designVersionHistoryDiffNotAvailable;

  /// Label describing the current value in the diff entry
  ///
  /// In en, this message translates to:
  /// **'Current: {value}'**
  String designVersionHistoryDiffCurrent(String value);

  /// Label describing the selected version value in the diff entry
  ///
  /// In en, this message translates to:
  /// **'Selected: {value}'**
  String designVersionHistoryDiffSelected(String value);

  /// Button label for duplicating a version
  ///
  /// In en, this message translates to:
  /// **'Duplicate version'**
  String get designVersionHistoryDuplicateCta;

  /// Button label for restoring a version
  ///
  /// In en, this message translates to:
  /// **'Restore version'**
  String get designVersionHistoryRestoreCta;

  /// Title for the design export screen
  ///
  /// In en, this message translates to:
  /// **'Digital export'**
  String get designExportTitle;

  /// Tooltip for the export history icon
  ///
  /// In en, this message translates to:
  /// **'View previous exports'**
  String get designExportHistoryTooltip;

  /// Label above the export preview artboard
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get designExportPreviewLabel;

  /// Label for the export format selector
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get designExportFormatLabel;

  /// PNG format option label
  ///
  /// In en, this message translates to:
  /// **'PNG'**
  String get designExportFormatPng;

  /// SVG format option label
  ///
  /// In en, this message translates to:
  /// **'SVG'**
  String get designExportFormatSvg;

  /// PDF format option label
  ///
  /// In en, this message translates to:
  /// **'PDF (coming soon)'**
  String get designExportFormatPdf;

  /// Toggle label for transparent background option
  ///
  /// In en, this message translates to:
  /// **'Transparent background'**
  String get designExportOptionTransparent;

  /// Helper text for transparent background option
  ///
  /// In en, this message translates to:
  /// **'Removes the artboard fill so only the stamp shape is opaque.'**
  String get designExportOptionTransparentSubtitle;

  /// Toggle label for adding bleed spacing
  ///
  /// In en, this message translates to:
  /// **'Include bleed margin'**
  String get designExportOptionBleed;

  /// Helper text for bleed option
  ///
  /// In en, this message translates to:
  /// **'Adds a safety margin around the imprint for print layouts.'**
  String get designExportOptionBleedSubtitle;

  /// Toggle label for metadata option
  ///
  /// In en, this message translates to:
  /// **'Embed metadata'**
  String get designExportOptionMetadata;

  /// Helper text for metadata option
  ///
  /// In en, this message translates to:
  /// **'Saves creation details alongside the exported file.'**
  String get designExportOptionMetadataSubtitle;

  /// Label for the export action button
  ///
  /// In en, this message translates to:
  /// **'Export file'**
  String get designExportExportButton;

  /// Label for the share action button
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get designExportShareButton;

  /// Message shown when storage access is denied
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to continue.'**
  String get designExportPermissionDenied;

  /// Snackbar message when export succeeds
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String designExportExportSuccess(String path);

  /// Snackbar indicating metadata file location
  ///
  /// In en, this message translates to:
  /// **'Metadata saved as {path}'**
  String designExportMetadataSaved(String path);

  /// Generic error shown when export fails
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get designExportGenericError;

  /// Error shown when user selects PDF
  ///
  /// In en, this message translates to:
  /// **'PDF export is not available yet.'**
  String get designExportPdfUnavailable;

  /// Error shown when share action fails
  ///
  /// In en, this message translates to:
  /// **'Unable to share right now.'**
  String get designExportShareError;

  /// Subject used for share intents
  ///
  /// In en, this message translates to:
  /// **'Hanko design preview'**
  String get designExportShareSubject;

  /// Body text used for share intents
  ///
  /// In en, this message translates to:
  /// **'Here is the latest hanko design export.'**
  String get designExportShareBody;

  /// Title for the destination picker sheet
  ///
  /// In en, this message translates to:
  /// **'Save to'**
  String get designExportDestinationTitle;

  /// Destination option for downloads
  ///
  /// In en, this message translates to:
  /// **'Downloads folder'**
  String get designExportDestinationDownloads;

  /// Destination option for app-managed storage
  ///
  /// In en, this message translates to:
  /// **'App documents'**
  String get designExportDestinationAppStorage;

  /// Title for export history sheet
  ///
  /// In en, this message translates to:
  /// **'Recent export'**
  String get designExportHistoryTitle;

  /// Subtitle showing format and timestamp in history
  ///
  /// In en, this message translates to:
  /// **'{format} • {timestamp}'**
  String designExportHistorySubtitle(String format, String timestamp);

  /// Message shown when export history is empty
  ///
  /// In en, this message translates to:
  /// **'No exports yet.'**
  String get designExportHistoryEmpty;

  /// Header for suggestion chips sourced from the profile
  ///
  /// In en, this message translates to:
  /// **'Quick fill'**
  String get designInputSuggestionHeader;

  /// Label for profile-based name suggestion
  ///
  /// In en, this message translates to:
  /// **'Use profile name'**
  String get designInputSuggestionProfile;

  /// Label for identity-based name suggestion
  ///
  /// In en, this message translates to:
  /// **'Use account name'**
  String get designInputSuggestionIdentity;

  /// Fallback label when no specific suggestion label applies
  ///
  /// In en, this message translates to:
  /// **'Suggested name'**
  String get designInputSuggestionFallback;

  /// Title for the kanji mapping helper card
  ///
  /// In en, this message translates to:
  /// **'Need kanji ideas?'**
  String get designInputKanjiMappingTitle;

  /// Description for the kanji mapping helper card
  ///
  /// In en, this message translates to:
  /// **'Find culturally appropriate kanji variants and meanings for foreign names.'**
  String get designInputKanjiMappingDescription;

  /// Call-to-action for the kanji mapping helper card
  ///
  /// In en, this message translates to:
  /// **'Open mapper'**
  String get designInputKanjiMappingCta;

  /// Label showing the currently selected kanji mapping on the input screen
  ///
  /// In en, this message translates to:
  /// **'Selected kanji: {value}'**
  String designInputKanjiMappingSelectionLabel(String value);

  /// Validation error shown when surname field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter your surname.'**
  String get designInputErrorEmptySurname;

  /// Validation error shown when given name field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter your given name.'**
  String get designInputErrorEmptyGiven;

  /// Validation error when half-width characters are used in kanji fields
  ///
  /// In en, this message translates to:
  /// **'Use full-width characters for your seal.'**
  String get designInputErrorInvalidKanji;

  /// Validation error when kanji input exceeds limit
  ///
  /// In en, this message translates to:
  /// **'Keep the name within 6 full-width characters.'**
  String get designInputErrorTooLongKanji;

  /// Validation error when latin input exceeds limit
  ///
  /// In en, this message translates to:
  /// **'Keep the name within 20 characters.'**
  String get designInputErrorTooLongLatin;

  /// Validation error when kana field contains invalid characters
  ///
  /// In en, this message translates to:
  /// **'Use Hiragana, Katakana, or prolonged sound marks.'**
  String get designInputErrorInvalidKana;

  /// Validation error when kana input exceeds limit
  ///
  /// In en, this message translates to:
  /// **'Keep the reading within 20 characters.'**
  String get designInputErrorTooLongKana;

  /// Validation error when required reading field is blank
  ///
  /// In en, this message translates to:
  /// **'Enter the reading in Hiragana or Katakana.'**
  String get designInputErrorEmptyKana;

  /// Snackbar message shown when validation fails on submit
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields.'**
  String get designInputValidationFailed;

  /// App bar title for kanji mapping screen
  ///
  /// In en, this message translates to:
  /// **'Kanji mapper'**
  String get designKanjiMappingTitle;

  /// Button label that confirms kanji selection
  ///
  /// In en, this message translates to:
  /// **'Use selection'**
  String get designKanjiMappingConfirm;

  /// Hint text inside the kanji mapper search bar
  ///
  /// In en, this message translates to:
  /// **'Search by meaning, sound, or radical'**
  String get designKanjiMappingSearchHint;

  /// Tooltip for refresh button in kanji mapper search bar
  ///
  /// In en, this message translates to:
  /// **'Refresh suggestions'**
  String get designKanjiMappingRefreshTooltip;

  /// Heading for compare chip section
  ///
  /// In en, this message translates to:
  /// **'Compare list'**
  String get designKanjiMappingCompareHeader;

  /// Label for chip that adds candidate to comparison list
  ///
  /// In en, this message translates to:
  /// **'Add to compare'**
  String get designKanjiMappingCompareToggleLabel;

  /// Label when candidate is already in comparison list
  ///
  /// In en, this message translates to:
  /// **'In compare list'**
  String get designKanjiMappingCompareSelectedLabel;

  /// Chip label describing stroke count for a candidate
  ///
  /// In en, this message translates to:
  /// **'{count} strokes'**
  String designKanjiMappingStrokeCountLabel(int count);

  /// Tooltip when bookmarking a kanji candidate
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get designKanjiMappingBookmarkAdd;

  /// Tooltip when removing a bookmarked candidate
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get designKanjiMappingBookmarkRemove;

  /// Tooltip when selecting a kanji candidate
  ///
  /// In en, this message translates to:
  /// **'Select this candidate'**
  String get designKanjiMappingSelectTooltip;

  /// Heading for manual kanji entry card
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get designKanjiMappingManualTitle;

  /// Description for manual kanji entry
  ///
  /// In en, this message translates to:
  /// **'Already have characters in mind? Enter them directly.'**
  String get designKanjiMappingManualDescription;

  /// Label for manual kanji entry field
  ///
  /// In en, this message translates to:
  /// **'Kanji characters'**
  String get designKanjiMappingManualKanjiLabel;

  /// Helper text for manual kanji field
  ///
  /// In en, this message translates to:
  /// **'Use up to 4 characters. Full-width recommended.'**
  String get designKanjiMappingManualKanjiHelper;

  /// Label for manual meaning/notes field
  ///
  /// In en, this message translates to:
  /// **'Meaning or notes (optional)'**
  String get designKanjiMappingManualMeaningLabel;

  /// Helper text for manual meaning field
  ///
  /// In en, this message translates to:
  /// **'Visible only to you for reference.'**
  String get designKanjiMappingManualMeaningHelper;

  /// Title shown when kanji search has no results
  ///
  /// In en, this message translates to:
  /// **'No candidates match yet'**
  String get designKanjiMappingEmptyResultsTitle;

  /// Subtitle when kanji search returns no results
  ///
  /// In en, this message translates to:
  /// **'Adjust filters or try a different meaning to explore more kanji.'**
  String get designKanjiMappingEmptyResultsDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
