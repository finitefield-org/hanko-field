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

  /// Hero title for the library tab
  ///
  /// In en, this message translates to:
  /// **'My Hanko Library'**
  String get libraryListTitle;

  /// Subtitle explaining the library tab
  ///
  /// In en, this message translates to:
  /// **'Browse saved designs, filter by persona, and export assets anytime.'**
  String get libraryListSubtitle;

  /// Placeholder for the library search bar
  ///
  /// In en, this message translates to:
  /// **'Search designs, IDs, or notes'**
  String get librarySearchPlaceholder;

  /// No description provided for @librarySortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get librarySortRecent;

  /// No description provided for @librarySortAiScore.
  ///
  /// In en, this message translates to:
  /// **'AI score'**
  String get librarySortAiScore;

  /// No description provided for @librarySortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get librarySortName;

  /// No description provided for @libraryViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get libraryViewGrid;

  /// No description provided for @libraryViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get libraryViewList;

  /// No description provided for @libraryFilterStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get libraryFilterStatusLabel;

  /// No description provided for @libraryFilterPersonaLabel.
  ///
  /// In en, this message translates to:
  /// **'Persona'**
  String get libraryFilterPersonaLabel;

  /// No description provided for @libraryFilterDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get libraryFilterDateLabel;

  /// No description provided for @libraryFilterAiLabel.
  ///
  /// In en, this message translates to:
  /// **'AI score'**
  String get libraryFilterAiLabel;

  /// No description provided for @libraryFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filters apply instantly while keeping results available offline.'**
  String get libraryFilterHint;

  /// No description provided for @libraryStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryStatusAll;

  /// No description provided for @libraryPersonaAll.
  ///
  /// In en, this message translates to:
  /// **'All personas'**
  String get libraryPersonaAll;

  /// No description provided for @libraryPersonaJapanese.
  ///
  /// In en, this message translates to:
  /// **'Domestic'**
  String get libraryPersonaJapanese;

  /// No description provided for @libraryPersonaForeigner.
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get libraryPersonaForeigner;

  /// No description provided for @libraryDateLast7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get libraryDateLast7Days;

  /// No description provided for @libraryDateLast30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get libraryDateLast30Days;

  /// No description provided for @libraryDateLast90Days.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get libraryDateLast90Days;

  /// No description provided for @libraryDateAnytime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get libraryDateAnytime;

  /// No description provided for @libraryAiAll.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get libraryAiAll;

  /// No description provided for @libraryAiHigh.
  ///
  /// In en, this message translates to:
  /// **'80+'**
  String get libraryAiHigh;

  /// No description provided for @libraryAiMedium.
  ///
  /// In en, this message translates to:
  /// **'60+'**
  String get libraryAiMedium;

  /// No description provided for @libraryAiLow.
  ///
  /// In en, this message translates to:
  /// **'40+'**
  String get libraryAiLow;

  /// No description provided for @libraryAiScoreUnknown.
  ///
  /// In en, this message translates to:
  /// **'AI score —'**
  String get libraryAiScoreUnknown;

  /// Label describing the AI score with a rounded integer
  ///
  /// In en, this message translates to:
  /// **'AI score {score}'**
  String libraryAiScoreValue(int score);

  /// Label for item-level updated timestamp
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String libraryUpdatedOn(Object date);

  /// Chip showing when the library list last refreshed
  ///
  /// In en, this message translates to:
  /// **'Refreshed {date}'**
  String libraryUpdatedAt(Object date);

  /// No description provided for @libraryUpdatedNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get libraryUpdatedNever;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved seals yet'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your first design or import a file to populate the library.'**
  String get libraryEmptyMessage;

  /// No description provided for @libraryEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Start a new design'**
  String get libraryEmptyCta;

  /// No description provided for @libraryActionPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get libraryActionPreview;

  /// No description provided for @libraryActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get libraryActionShare;

  /// No description provided for @libraryActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get libraryActionEdit;

  /// No description provided for @libraryActionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get libraryActionExport;

  /// No description provided for @libraryActionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get libraryActionDuplicate;

  /// No description provided for @libraryActionReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get libraryActionReorder;

  /// Title for the duplicate design flow
  ///
  /// In en, this message translates to:
  /// **'Duplicate design'**
  String get libraryDuplicateTitle;

  /// Subtitle shown when duplicating a known design
  ///
  /// In en, this message translates to:
  /// **'Make a copy of {name} and jump back into the editor.'**
  String libraryDuplicateSubtitle(Object name);

  /// Fallback subtitle when the source design is not loaded yet
  ///
  /// In en, this message translates to:
  /// **'Make a copy and continue editing.'**
  String get libraryDuplicateSubtitleFallback;

  /// Label for the duplicate name text field
  ///
  /// In en, this message translates to:
  /// **'New design name'**
  String get libraryDuplicateNameLabel;

  /// Hint text for the duplicate name input
  ///
  /// In en, this message translates to:
  /// **'e.g. Yamada Co. round v2'**
  String get libraryDuplicateNameHint;

  /// Validation error for the name field
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the duplicate.'**
  String get libraryDuplicateNameError;

  /// Label for the tags field
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get libraryDuplicateTagsLabel;

  /// Hint text explaining how to enter tags
  ///
  /// In en, this message translates to:
  /// **'personal, ai-ready, round'**
  String get libraryDuplicateTagsHint;

  /// Label above assist chips for suggested tags
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get libraryDuplicateSuggestionsLabel;

  /// Switch label for copying history
  ///
  /// In en, this message translates to:
  /// **'Copy history'**
  String get libraryDuplicateCopyHistory;

  /// Description for the copy history switch
  ///
  /// In en, this message translates to:
  /// **'Include comments, usage events, and AI reports.'**
  String get libraryDuplicateCopyHistoryDescription;

  /// Switch label for copying assets
  ///
  /// In en, this message translates to:
  /// **'Copy assets'**
  String get libraryDuplicateCopyAssets;

  /// Description for the copy assets switch
  ///
  /// In en, this message translates to:
  /// **'Reuse exported files and editor adjustments.'**
  String get libraryDuplicateCopyAssetsDescription;

  /// Primary button label for the duplicate flow
  ///
  /// In en, this message translates to:
  /// **'Duplicate and edit'**
  String get libraryDuplicateSubmit;

  /// Cancel button label for the duplicate flow
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get libraryDuplicateCancel;

  /// No description provided for @libraryDetailTabDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get libraryDetailTabDetails;

  /// No description provided for @libraryDetailTabActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get libraryDetailTabActivity;

  /// No description provided for @libraryDetailTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get libraryDetailTabFiles;

  /// No description provided for @libraryDetailQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get libraryDetailQuickActions;

  /// No description provided for @libraryDetailMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Design metadata'**
  String get libraryDetailMetadataTitle;

  /// No description provided for @libraryDetailAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI review'**
  String get libraryDetailAiTitle;

  /// No description provided for @libraryDetailVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get libraryDetailVersionTitle;

  /// No description provided for @libraryDetailUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage history'**
  String get libraryDetailUsageTitle;

  /// No description provided for @libraryDetailFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get libraryDetailFilesTitle;

  /// No description provided for @libraryDetailMetadataId.
  ///
  /// In en, this message translates to:
  /// **'Design ID'**
  String get libraryDetailMetadataId;

  /// No description provided for @libraryDetailMetadataStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get libraryDetailMetadataStatus;

  /// No description provided for @libraryDetailMetadataPersona.
  ///
  /// In en, this message translates to:
  /// **'Persona'**
  String get libraryDetailMetadataPersona;

  /// No description provided for @libraryDetailMetadataShape.
  ///
  /// In en, this message translates to:
  /// **'Shape · Size'**
  String get libraryDetailMetadataShape;

  /// No description provided for @libraryDetailMetadataWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing style'**
  String get libraryDetailMetadataWriting;

  /// No description provided for @libraryDetailMetadataUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get libraryDetailMetadataUpdated;

  /// No description provided for @libraryDetailMetadataCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get libraryDetailMetadataCreated;

  /// No description provided for @libraryDetailRegistrable.
  ///
  /// In en, this message translates to:
  /// **'Registrable'**
  String get libraryDetailRegistrable;

  /// No description provided for @libraryDetailNotRegistrable.
  ///
  /// In en, this message translates to:
  /// **'Needs tweaks'**
  String get libraryDetailNotRegistrable;

  /// No description provided for @libraryDetailAiScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'AI score'**
  String get libraryDetailAiScoreLabel;

  /// No description provided for @libraryDetailAiDiagnosticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get libraryDetailAiDiagnosticsLabel;

  /// No description provided for @libraryDetailAiDiagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No diagnostics available yet.'**
  String get libraryDetailAiDiagnosticsEmpty;

  /// Label for the current version number
  ///
  /// In en, this message translates to:
  /// **'Current version v{version}'**
  String libraryDetailVersionCurrent(int version);

  /// Summary of how many versions exist
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# total version} other {# total versions}}'**
  String libraryDetailVersionCount(int count);

  /// No description provided for @libraryDetailViewVersionsCta.
  ///
  /// In en, this message translates to:
  /// **'View version history'**
  String get libraryDetailViewVersionsCta;

  /// No description provided for @libraryDetailUsageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recorded usage yet.'**
  String get libraryDetailUsageEmpty;

  /// No description provided for @libraryDetailUsageCreated.
  ///
  /// In en, this message translates to:
  /// **'Created in library'**
  String get libraryDetailUsageCreated;

  /// Timeline entry when a version update happens
  ///
  /// In en, this message translates to:
  /// **'Updated to v{version}'**
  String libraryDetailUsageUpdated(int version);

  /// No description provided for @libraryDetailUsageOrdered.
  ///
  /// In en, this message translates to:
  /// **'Used in an order'**
  String get libraryDetailUsageOrdered;

  /// Timeline entry describing the AI score
  ///
  /// In en, this message translates to:
  /// **'AI review scored {score}'**
  String libraryDetailUsageAiCheck(Object score);

  /// Timeline entry indicating an archived version
  ///
  /// In en, this message translates to:
  /// **'Archived version v{version}'**
  String libraryDetailUsageVersionArchived(int version);

  /// No description provided for @libraryDetailFilesVector.
  ///
  /// In en, this message translates to:
  /// **'Vector (.svg)'**
  String get libraryDetailFilesVector;

  /// No description provided for @libraryDetailFilesPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview PNG'**
  String get libraryDetailFilesPreview;

  /// No description provided for @libraryDetailFilesStampMock.
  ///
  /// In en, this message translates to:
  /// **'Stamp mock'**
  String get libraryDetailFilesStampMock;

  /// No description provided for @libraryDetailFilesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File not generated yet.'**
  String get libraryDetailFilesUnavailable;

  /// Email subject when sharing a design
  ///
  /// In en, this message translates to:
  /// **'Hanko design {id}'**
  String libraryDetailShareSubject(Object id);

  /// Body content when sharing a design
  ///
  /// In en, this message translates to:
  /// **'Check \"{name}\" from my Hanko Field library (ID: {id}).'**
  String libraryDetailShareBody(Object name, Object id);

  /// Snackbar message after duplicating a design
  ///
  /// In en, this message translates to:
  /// **'Duplicated as {id}'**
  String libraryDetailDuplicateSuccess(Object id);

  /// No description provided for @libraryDetailDuplicateFailure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t duplicate. Try again later.'**
  String get libraryDetailDuplicateFailure;

  /// No description provided for @libraryDetailActionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get libraryDetailActionInProgress;

  /// No description provided for @libraryDetailErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Design unavailable'**
  String get libraryDetailErrorTitle;

  /// No description provided for @libraryDetailRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry loading'**
  String get libraryDetailRetry;

  /// No description provided for @libraryDetailShapeRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get libraryDetailShapeRound;

  /// No description provided for @libraryDetailShapeSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get libraryDetailShapeSquare;

  /// No description provided for @libraryDetailWritingTensho.
  ///
  /// In en, this message translates to:
  /// **'Tensho'**
  String get libraryDetailWritingTensho;

  /// No description provided for @libraryDetailWritingReisho.
  ///
  /// In en, this message translates to:
  /// **'Reisho'**
  String get libraryDetailWritingReisho;

  /// No description provided for @libraryDetailWritingKaisho.
  ///
  /// In en, this message translates to:
  /// **'Kaisho'**
  String get libraryDetailWritingKaisho;

  /// No description provided for @libraryDetailWritingGyosho.
  ///
  /// In en, this message translates to:
  /// **'Gyosho'**
  String get libraryDetailWritingGyosho;

  /// No description provided for @libraryDetailWritingKoentai.
  ///
  /// In en, this message translates to:
  /// **'Koentai'**
  String get libraryDetailWritingKoentai;

  /// No description provided for @libraryDetailWritingCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get libraryDetailWritingCustom;

  /// Title for the library digital export screen
  ///
  /// In en, this message translates to:
  /// **'Digital export'**
  String get libraryExportTitle;

  /// Tooltip for the history icon in the library export screen
  ///
  /// In en, this message translates to:
  /// **'View previous exports'**
  String get libraryExportHistoryTooltip;

  /// Sheet title listing past exports
  ///
  /// In en, this message translates to:
  /// **'Export history'**
  String get libraryExportHistoryTitle;

  /// Primary CTA to generate a digital export link
  ///
  /// In en, this message translates to:
  /// **'Generate link'**
  String get libraryExportGenerateCta;

  /// Secondary CTA to revoke all digital export links
  ///
  /// In en, this message translates to:
  /// **'Revoke all links'**
  String get libraryExportRevokeCta;

  /// Snackbar shown when a link is generated
  ///
  /// In en, this message translates to:
  /// **'Link ready to share'**
  String get libraryExportLinkReadySnack;

  /// Snackbar shown when links were revoked
  ///
  /// In en, this message translates to:
  /// **'All links revoked'**
  String get libraryExportRevokedSnack;

  /// Subject when sharing the digital export link
  ///
  /// In en, this message translates to:
  /// **'Digital export for {id}'**
  String libraryExportShareSubject(String id);

  /// Snackbar shown after copying the link
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get libraryExportCopySnack;

  /// Label for the format segmented buttons
  ///
  /// In en, this message translates to:
  /// **'File format'**
  String get libraryExportFormatLabel;

  /// PNG format label
  ///
  /// In en, this message translates to:
  /// **'PNG'**
  String get libraryExportFormatPng;

  /// SVG format label
  ///
  /// In en, this message translates to:
  /// **'SVG'**
  String get libraryExportFormatSvg;

  /// PDF format label
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get libraryExportFormatPdf;

  /// Assist chip describing PNG usage
  ///
  /// In en, this message translates to:
  /// **'Great for chat previews'**
  String get libraryExportFormatPngUseMessaging;

  /// Assist chip describing PNG transparency benefit
  ///
  /// In en, this message translates to:
  /// **'Supports transparency'**
  String get libraryExportFormatPngUseTransparent;

  /// Assist chip describing SVG vector benefit
  ///
  /// In en, this message translates to:
  /// **'Keeps vectors editable'**
  String get libraryExportFormatSvgUseVector;

  /// Assist chip describing SVG CNC benefit
  ///
  /// In en, this message translates to:
  /// **'Laser/CNC friendly'**
  String get libraryExportFormatSvgUseCnc;

  /// Assist chip describing PDF print usage
  ///
  /// In en, this message translates to:
  /// **'Print-ready layout'**
  String get libraryExportFormatPdfUsePrint;

  /// Assist chip describing PDF archive usage
  ///
  /// In en, this message translates to:
  /// **'Archive quality'**
  String get libraryExportFormatPdfUseArchive;

  /// Label for the scale selection
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get libraryExportScaleLabel;

  /// Helper text for the scale selection
  ///
  /// In en, this message translates to:
  /// **'Choose how large the exported file should be.'**
  String get libraryExportScaleSubtitle;

  /// Label for a scale option chip
  ///
  /// In en, this message translates to:
  /// **'{factor}×'**
  String libraryExportScaleChip(int factor);

  /// Switch label for watermark option
  ///
  /// In en, this message translates to:
  /// **'Apply watermark'**
  String get libraryExportWatermarkLabel;

  /// Helper text for watermark toggle
  ///
  /// In en, this message translates to:
  /// **'Adds a subtle diagonal watermark to previews.'**
  String get libraryExportWatermarkDescription;

  /// Switch label for expiry option
  ///
  /// In en, this message translates to:
  /// **'Link expires'**
  String get libraryExportExpiryLabel;

  /// Helper text when expiry is enabled
  ///
  /// In en, this message translates to:
  /// **'Automatically disables downloads after {days} days.'**
  String libraryExportExpiryDescription(int days);

  /// Helper text when expiry is disabled
  ///
  /// In en, this message translates to:
  /// **'Does not expire'**
  String get libraryExportExpiryDisabled;

  /// Label for the expiry dropdown
  ///
  /// In en, this message translates to:
  /// **'Expiry duration'**
  String get libraryExportExpiryPicker;

  /// Label for each expiry option
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String libraryExportExpiryDays(int days);

  /// Switch label for download permissions
  ///
  /// In en, this message translates to:
  /// **'Allow original downloads'**
  String get libraryExportDownloadsLabel;

  /// Title for the library share links management screen
  ///
  /// In en, this message translates to:
  /// **'Share links'**
  String get libraryShareLinksTitle;

  /// Header label for active share links
  ///
  /// In en, this message translates to:
  /// **'Active links'**
  String get libraryShareLinksSectionActive;

  /// Title for the empty state when no share links exist
  ///
  /// In en, this message translates to:
  /// **'No share links yet'**
  String get libraryShareLinksEmptyTitle;

  /// Subtitle explaining why no share links are listed
  ///
  /// In en, this message translates to:
  /// **'Issue a link so teammates can view mockups and download files.'**
  String get libraryShareLinksEmptySubtitle;

  /// Primary CTA to create a share link
  ///
  /// In en, this message translates to:
  /// **'New share link'**
  String get libraryShareLinksCreateCta;

  /// Tooltip for the create link icon button
  ///
  /// In en, this message translates to:
  /// **'Create share link'**
  String get libraryShareLinksCreateTooltip;

  /// Title for the history card
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get libraryShareLinksHistoryTitle;

  /// Summary describing expired/revoked links
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No expired links yet} one {# link expired or was revoked} other {# links expired or were revoked}}'**
  String libraryShareLinksHistorySummary(int count);

  /// Button label to open the history sheet
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get libraryShareLinksHistoryAction;

  /// Message shown when there is no history
  ///
  /// In en, this message translates to:
  /// **'Expired links will appear here.'**
  String get libraryShareLinksHistoryEmpty;

  /// Button label to copy the share link
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get libraryShareLinksCopyAction;

  /// Button label to trigger the share sheet
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get libraryShareLinksShareAction;

  /// Button label to extend link expiry
  ///
  /// In en, this message translates to:
  /// **'Extend expiry'**
  String get libraryShareLinksExtendAction;

  /// Title for the extend expiry sheet
  ///
  /// In en, this message translates to:
  /// **'Extend expiry'**
  String get libraryShareLinksExtendSheetTitle;

  /// Label for extend expiry options
  ///
  /// In en, this message translates to:
  /// **'Add {days} {days, plural, one {day} other {days}}'**
  String libraryShareLinksExtendOptionDays(int days);

  /// Tooltip for the revoke icon button
  ///
  /// In en, this message translates to:
  /// **'Revoke link'**
  String get libraryShareLinksRevokeTooltip;

  /// Label describing when the link expires
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String libraryShareLinksExpiryLabel(Object date);

  /// Subtitle for expired links
  ///
  /// In en, this message translates to:
  /// **'Expired on {date}'**
  String libraryShareLinksExpiredOn(Object date);

  /// Subtitle for revoked links
  ///
  /// In en, this message translates to:
  /// **'Revoked on {date}'**
  String libraryShareLinksRevokedOn(Object date);

  /// Label shown when a link does not expire
  ///
  /// In en, this message translates to:
  /// **'No expiry'**
  String get libraryShareLinksExpiryNever;

  /// Describes how many times a link was opened
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No visits yet} one {# visit} other {# visits}}'**
  String libraryShareLinksVisitsLabel(int count);

  /// Indicates the maximum allowed visits
  ///
  /// In en, this message translates to:
  /// **'Up to {limit} visits'**
  String libraryShareLinksUsageCap(int limit);

  /// Describes when the link was last accessed
  ///
  /// In en, this message translates to:
  /// **'Last opened {timestamp}'**
  String libraryShareLinksLastOpened(Object timestamp);

  /// Snackbar shown after creating a link
  ///
  /// In en, this message translates to:
  /// **'Share link issued.'**
  String get libraryShareLinksCreatedSnack;

  /// Snackbar shown after extending a link
  ///
  /// In en, this message translates to:
  /// **'Expiry extended.'**
  String get libraryShareLinksExtendSnack;

  /// Snackbar shown after revoking a link
  ///
  /// In en, this message translates to:
  /// **'Link revoked.'**
  String get libraryShareLinksRevokeSnack;

  /// Generic error message for share link actions
  ///
  /// In en, this message translates to:
  /// **'Unable to update share links. Try again.'**
  String get libraryShareLinksErrorGeneric;

  /// Subject used when sharing a link
  ///
  /// In en, this message translates to:
  /// **'Share link for {id}'**
  String libraryShareLinksShareSubject(String id);

  /// Title for the bottom sheet listing expired links
  ///
  /// In en, this message translates to:
  /// **'Expired links'**
  String get libraryShareLinksHistorySheetTitle;

  /// Helper text for download permissions
  ///
  /// In en, this message translates to:
  /// **'Let recipients download the full-resolution file.'**
  String get libraryExportDownloadsDescription;

  /// Section title for the generated link
  ///
  /// In en, this message translates to:
  /// **'Shareable link'**
  String get libraryExportLinkTitle;

  /// Empty state title when no link exists
  ///
  /// In en, this message translates to:
  /// **'No link yet'**
  String get libraryExportLinkEmptyTitle;

  /// Empty state message when no link exists
  ///
  /// In en, this message translates to:
  /// **'Generate a link to share digital files securely.'**
  String get libraryExportLinkEmptyMessage;

  /// Button label to share the link
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get libraryExportShareLink;

  /// Button label to copy the link
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get libraryExportCopyLink;

  /// Label showing expiry date
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String libraryExportExpiresOn(String date);

  /// Meta description combining format and scale
  ///
  /// In en, this message translates to:
  /// **'{format} · {scale}'**
  String libraryExportLinkMeta(String format, String scale);

  /// No description provided for @libraryLoadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your library. Check your connection and try again.'**
  String get libraryLoadError;

  /// No description provided for @libraryErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Library unavailable'**
  String get libraryErrorTitle;

  /// No description provided for @libraryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get libraryRetry;

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

  /// Filter label showing all orders
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ordersStatusAll;

  /// Label above the status chips on the orders list
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get ordersFilterStatusLabel;

  /// Filter label for orders that are being processed or produced
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get ordersStatusInProgress;

  /// Filter label for shipped orders
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get ordersStatusShipped;

  /// Filter label for delivered orders
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get ordersStatusDelivered;

  /// Filter label for canceled orders
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get ordersStatusCanceled;

  /// Label above the time range chips on the orders list
  ///
  /// In en, this message translates to:
  /// **'Time range'**
  String get ordersFilterTimeLabel;

  /// Filter label for the past 30 days
  ///
  /// In en, this message translates to:
  /// **'Past 30 days'**
  String get ordersTimeRange30Days;

  /// Filter label for the past 90 days
  ///
  /// In en, this message translates to:
  /// **'Past 90 days'**
  String get ordersTimeRange90Days;

  /// Filter label for the past six months
  ///
  /// In en, this message translates to:
  /// **'Past 6 months'**
  String get ordersTimeRange6Months;

  /// Filter label for the past year
  ///
  /// In en, this message translates to:
  /// **'Past year'**
  String get ordersTimeRangeYear;

  /// Filter label for showing all orders regardless of time
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get ordersTimeRangeAll;

  /// Label that shows when the orders list was last refreshed
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String ordersLastUpdatedText(Object timestamp);

  /// Title for empty orders list state
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get ordersListEmptyTitle;

  /// Description for empty orders list state
  ///
  /// In en, this message translates to:
  /// **'When you place an order, it will appear here along with its status and tracking.'**
  String get ordersListEmptyMessage;

  /// Title for error state on orders list
  ///
  /// In en, this message translates to:
  /// **'Orders can’t be loaded'**
  String get ordersListErrorTitle;

  /// Description shown when orders list fails to load
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get ordersListErrorMessage;

  /// Primary action label for retrying orders fetch
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ordersListRetryLabel;

  /// Snack bar message when pull-to-refresh fails
  ///
  /// In en, this message translates to:
  /// **'Couldn’t refresh orders.'**
  String get ordersListRefreshError;

  /// Fallback name when order item name is missing
  ///
  /// In en, this message translates to:
  /// **'Custom order'**
  String get ordersUnknownItem;

  /// Timeline label for the ordered stage
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get ordersTimelineOrdered;

  /// Timeline label for production stage
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get ordersTimelineProduction;

  /// Timeline label for shipping stage
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get ordersTimelineShipping;

  /// Timeline label for delivered stage
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get ordersTimelineDelivered;

  /// Timeline label shown for canceled orders
  ///
  /// In en, this message translates to:
  /// **'Order canceled'**
  String get ordersTimelineCanceled;

  /// Status label for pending payment
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get orderStatusPendingPayment;

  /// Status label for paid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get orderStatusPaid;

  /// Status label for in production
  ///
  /// In en, this message translates to:
  /// **'In production'**
  String get orderStatusInProduction;

  /// Status label for ready to ship
  ///
  /// In en, this message translates to:
  /// **'Ready to ship'**
  String get orderStatusReadyToShip;

  /// Status label for shipped
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get orderStatusShipped;

  /// Status label for delivered
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatusDelivered;

  /// Status label for canceled orders
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get orderStatusCanceled;

  /// Tab label for the order summary view
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get orderDetailsTabSummary;

  /// Tab label for the order timeline view
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get orderDetailsTabTimeline;

  /// Tab label for the order files view
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get orderDetailsTabFiles;

  /// Title shown in the order details app bar
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber}'**
  String orderDetailsAppBarTitle(String orderNumber);

  /// Action label for reordering the same items
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get orderDetailsActionReorder;

  /// Title for the reorder screen app bar
  ///
  /// In en, this message translates to:
  /// **'Reorder {orderNumber}'**
  String orderReorderAppBarTitle(String orderNumber);

  /// Subtitle showing when the original order was placed
  ///
  /// In en, this message translates to:
  /// **'Placed on {date}'**
  String orderReorderAppBarSubtitle(String date);

  /// Error message shown when the reorder preview fails to load
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load the reorder preview.'**
  String get orderReorderLoadError;

  /// Label for retry button on the reorder error state
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get orderReorderRetryLabel;

  /// Banner message explaining unavailable reorder items
  ///
  /// In en, this message translates to:
  /// **'Some items are no longer available and were left unchecked.'**
  String get orderReorderBannerUnavailable;

  /// Banner message explaining pricing adjustments on reorder
  ///
  /// In en, this message translates to:
  /// **'Pricing has been updated since your original order.'**
  String get orderReorderBannerPriceChanges;

  /// Message shown when an order has no eligible lines to reorder
  ///
  /// In en, this message translates to:
  /// **'No line items are available for reorder.'**
  String get orderReorderNoItemsAvailable;

  /// Summary of how many reorder items are selected
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} items selected'**
  String orderReorderSelectionSummary(int selected, int total);

  /// Label for selecting all reorderable items
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get orderReorderSelectAll;

  /// Label for clearing all selected reorder items
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get orderReorderSelectNone;

  /// Primary button label to rebuild cart and continue to checkout
  ///
  /// In en, this message translates to:
  /// **'Move to checkout'**
  String get orderReorderPrimaryCta;

  /// Secondary action to cancel the reorder flow
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get orderReorderCancelCta;

  /// Displays quantity for a reorder line
  ///
  /// In en, this message translates to:
  /// **'Qty {count}'**
  String orderReorderQuantity(int count);

  /// Label showing the SKU for a reorder line
  ///
  /// In en, this message translates to:
  /// **'SKU: {sku}'**
  String orderReorderSkuLabel(String sku);

  /// Label describing a price change for the reorder line
  ///
  /// In en, this message translates to:
  /// **'New price {newPrice} (was {oldPrice})'**
  String orderReorderPriceChangeLabel(String newPrice, String oldPrice);

  /// Badge text indicating a reorder line is low stock but available
  ///
  /// In en, this message translates to:
  /// **'Limited stock — ships a bit slower'**
  String get orderReorderAvailabilityLowStock;

  /// Badge text indicating a reorder line cannot be reordered
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get orderReorderAvailabilityUnavailable;

  /// Snack bar message summarising how many items were added to the cart
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# item added to cart} other {# items added to cart}}'**
  String orderReorderResultAdded(int count);

  /// Snack bar message summarising how many items could not be reordered
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# item unavailable} other {# items unavailable}}'**
  String orderReorderResultSkipped(int count);

  /// Snack bar note indicating pricing adjustments were applied
  ///
  /// In en, this message translates to:
  /// **'Latest pricing applied.'**
  String get orderReorderResultPriceAdjusted;

  /// Error message when reorder submission fails
  ///
  /// In en, this message translates to:
  /// **'We couldn’t rebuild the cart. Try again.'**
  String get orderReorderSubmitError;

  /// Action label for sharing the order summary
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get orderDetailsActionShare;

  /// Heading for the order items section
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get orderDetailsItemsSectionTitle;

  /// Displays the number of line items in the order
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# item} other {# items}}'**
  String orderDetailsItemsSectionCount(int count);

  /// Heading for the payment breakdown section
  ///
  /// In en, this message translates to:
  /// **'Payment summary'**
  String get orderDetailsTotalsSectionTitle;

  /// Label indicating when the order details were last refreshed
  ///
  /// In en, this message translates to:
  /// **'Synced {timestamp}'**
  String orderDetailsLastUpdated(String timestamp);

  /// Heading for the addresses section
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get orderDetailsAddressesSectionTitle;

  /// Heading for the order contact information section
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get orderDetailsContactSectionTitle;

  /// Heading for the design snapshot gallery
  ///
  /// In en, this message translates to:
  /// **'Design snapshots'**
  String get orderDetailsDesignSectionTitle;

  /// Error message shown when order details fail to load
  ///
  /// In en, this message translates to:
  /// **'Order details can’t be loaded'**
  String get orderDetailsLoadErrorMessage;

  /// Label for retrying to load order details
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get orderDetailsRetryLabel;

  /// Title shown on the timeline tab placeholder
  ///
  /// In en, this message translates to:
  /// **'Production timeline'**
  String get orderDetailsTimelineTabTitle;

  /// Placeholder copy for the timeline tab while content is unavailable
  ///
  /// In en, this message translates to:
  /// **'We’ll surface production, QC, and shipping updates here.'**
  String get orderDetailsTimelinePlaceholder;

  /// Error message shown when production timeline fails to load
  ///
  /// In en, this message translates to:
  /// **'Production updates can’t be loaded'**
  String get orderDetailsTimelineLoadErrorMessage;

  /// Tooltip label for refreshing order details and timeline
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get orderDetailsActionRefresh;

  /// Empty state message when no production events are available
  ///
  /// In en, this message translates to:
  /// **'No production checkpoints yet.'**
  String get orderDetailsProductionTimelineEmpty;

  /// Heading for the production timeline stage list
  ///
  /// In en, this message translates to:
  /// **'Stage history'**
  String get orderDetailsProductionTimelineStageListTitle;

  /// Heading for the production overview card
  ///
  /// In en, this message translates to:
  /// **'Production overview'**
  String get orderDetailsProductionOverviewTitle;

  /// Label describing the estimated production completion
  ///
  /// In en, this message translates to:
  /// **'Estimated completion'**
  String get orderDetailsProductionEstimatedCompletionLabel;

  /// Value shown when estimated completion is unavailable
  ///
  /// In en, this message translates to:
  /// **'Pending schedule'**
  String get orderDetailsProductionEstimatedCompletionUnknown;

  /// Label describing the current production stage
  ///
  /// In en, this message translates to:
  /// **'Current stage'**
  String get orderDetailsProductionCurrentStageLabel;

  /// Message shown when production is on schedule
  ///
  /// In en, this message translates to:
  /// **'On schedule'**
  String get orderDetailsProductionOnSchedule;

  /// Message shown when production is delayed
  ///
  /// In en, this message translates to:
  /// **'Running {duration} late'**
  String orderDetailsProductionDelay(String duration);

  /// Label for the production queue reference
  ///
  /// In en, this message translates to:
  /// **'Queue: {queue}'**
  String orderDetailsProductionQueue(String queue);

  /// Label for the production station
  ///
  /// In en, this message translates to:
  /// **'Station: {station}'**
  String orderDetailsProductionStation(String station);

  /// Label for the production operator
  ///
  /// In en, this message translates to:
  /// **'Operator: {operator}'**
  String orderDetailsProductionOperator(String operator);

  /// Value displayed when production metadata is missing
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get orderDetailsProductionValueUnknown;

  /// Assist chip label when a stage is on track
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get orderDetailsProductionHealthOnTrack;

  /// Assist chip label when a stage needs attention
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get orderDetailsProductionHealthAttention;

  /// Assist chip label when a stage is delayed
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get orderDetailsProductionHealthDelayed;

  /// Fallback label when the production stage is unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown stage'**
  String get orderDetailsProductionStageUnknown;

  /// Label for the queued production event
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get orderDetailsProductionStageQueued;

  /// Label for the engraving production event
  ///
  /// In en, this message translates to:
  /// **'Engraving'**
  String get orderDetailsProductionStageEngraving;

  /// Label for the polishing production event
  ///
  /// In en, this message translates to:
  /// **'Polishing'**
  String get orderDetailsProductionStagePolishing;

  /// Label for the QC production event
  ///
  /// In en, this message translates to:
  /// **'Quality control'**
  String get orderDetailsProductionStageQc;

  /// Label for the packed production event
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get orderDetailsProductionStagePacked;

  /// Label for the on hold production event
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get orderDetailsProductionStageOnHold;

  /// Label for the rework production event
  ///
  /// In en, this message translates to:
  /// **'Rework'**
  String get orderDetailsProductionStageRework;

  /// Label for the canceled production event
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get orderDetailsProductionStageCanceled;

  /// Compact representation of duration hours
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String orderDetailsProductionDurationHours(int hours);

  /// Compact representation of duration minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String orderDetailsProductionDurationMinutes(int minutes);

  /// Label describing how long a stage took
  ///
  /// In en, this message translates to:
  /// **'Elapsed {duration}'**
  String orderDetailsProductionStageDuration(String duration);

  /// Label describing how long the current stage has been active
  ///
  /// In en, this message translates to:
  /// **'Active for {duration}'**
  String orderDetailsProductionStageActive(String duration);

  /// Label describing QC result for a stage
  ///
  /// In en, this message translates to:
  /// **'QC result: {result}'**
  String orderDetailsProductionQcResult(String result);

  /// Label listing QC defects
  ///
  /// In en, this message translates to:
  /// **'Defects: {defects}'**
  String orderDetailsProductionQcDefects(String defects);

  /// Label showing production notes
  ///
  /// In en, this message translates to:
  /// **'Notes: {notes}'**
  String orderDetailsProductionNotes(String notes);

  /// Title shown on the files tab placeholder
  ///
  /// In en, this message translates to:
  /// **'Files & documents'**
  String get orderDetailsFilesTabTitle;

  /// Placeholder copy for the files tab while content is unavailable
  ///
  /// In en, this message translates to:
  /// **'Invoices, certificates, and shared files will appear here.'**
  String get orderDetailsFilesPlaceholder;

  /// Snack bar message shown when reorder succeeds
  ///
  /// In en, this message translates to:
  /// **'Reorder for {orderNumber} has been placed.'**
  String orderDetailsReorderSuccess(String orderNumber);

  /// Snack bar message shown when reorder fails
  ///
  /// In en, this message translates to:
  /// **'We couldn’t start the reorder.'**
  String get orderDetailsReorderError;

  /// Snack bar message shown when invoice request succeeds
  ///
  /// In en, this message translates to:
  /// **'Invoice request for {orderNumber} submitted.'**
  String orderDetailsInvoiceSuccess(String orderNumber);

  /// Snack bar message shown when invoice request fails
  ///
  /// In en, this message translates to:
  /// **'Invoice could not be requested.'**
  String get orderDetailsInvoiceError;

  /// Snack bar message shown when contacting support
  ///
  /// In en, this message translates to:
  /// **'Support will reach out shortly. You can also chat from the Help tab.'**
  String get orderDetailsSupportMessage;

  /// Email subject when sharing an order
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber} summary'**
  String orderDetailsShareSubject(String orderNumber);

  /// Body text when sharing an order summary
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber} total: {total}.\\nCheck the Hanko Field app for details.'**
  String orderDetailsShareBody(String orderNumber, String total);

  /// Assist chip label for contacting support
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get orderDetailsActionSupport;

  /// Assist chip label for downloading the invoice
  ///
  /// In en, this message translates to:
  /// **'Download invoice'**
  String get orderDetailsActionInvoice;

  /// Title for the invoice screen top app bar
  ///
  /// In en, this message translates to:
  /// **'Invoice · {orderNumber}'**
  String orderInvoiceAppBarTitle(String orderNumber);

  /// Tooltip for the invoice share icon button
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get orderInvoiceShareTooltip;

  /// Error message shown when invoice fetch fails
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load the invoice.'**
  String get orderInvoiceLoadError;

  /// Label for retry button when invoice fails to load
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get orderInvoiceRetryLabel;

  /// Headline shown above the invoice summary
  ///
  /// In en, this message translates to:
  /// **'Invoice for {orderNumber}'**
  String orderInvoiceHeadline(String orderNumber);

  /// Subheadline summarising the invoice total amount
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String orderInvoiceSubHeadline(String amount);

  /// Placeholder label when invoice metadata is missing
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get orderInvoiceValueNotAvailable;

  /// Heading for the invoice details card
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get orderInvoiceDetailsTitle;

  /// Label for the invoice number field
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get orderInvoiceDetailsNumber;

  /// Label for the invoice issued date field
  ///
  /// In en, this message translates to:
  /// **'Issued on'**
  String get orderInvoiceDetailsIssuedOn;

  /// Label for the invoice due date field
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get orderInvoiceDetailsDueDate;

  /// Label for the invoice total field
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get orderInvoiceDetailsTotal;

  /// Heading for the invoice line items card
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get orderInvoiceLineItemsTitle;

  /// Primary action label for downloading the invoice
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get orderInvoiceDownloadAction;

  /// Secondary action label for emailing the invoice
  ///
  /// In en, this message translates to:
  /// **'Send by email'**
  String get orderInvoiceEmailAction;

  /// Placeholder message when email delivery is not available
  ///
  /// In en, this message translates to:
  /// **'Email delivery will be available soon.'**
  String get orderInvoiceEmailPlaceholder;

  /// Banner message shown while invoice is pending generation
  ///
  /// In en, this message translates to:
  /// **'Your invoice is being generated. This can take a few minutes.'**
  String get orderInvoicePendingMessage;

  /// Button label to refresh pending invoice state
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get orderInvoicePendingRefresh;

  /// Assist chip label when taxes are included
  ///
  /// In en, this message translates to:
  /// **'Tax inclusive'**
  String get orderInvoiceTaxStatusInclusive;

  /// Assist chip label when taxes are excluded
  ///
  /// In en, this message translates to:
  /// **'Tax exclusive'**
  String get orderInvoiceTaxStatusExclusive;

  /// Assist chip label when invoice is tax exempt
  ///
  /// In en, this message translates to:
  /// **'Tax exempt'**
  String get orderInvoiceTaxStatusExempt;

  /// Invoice status label - draft
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get orderInvoiceStatusDraft;

  /// Invoice status label - issued
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get orderInvoiceStatusIssued;

  /// Invoice status label - sent
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get orderInvoiceStatusSent;

  /// Invoice status label - paid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get orderInvoiceStatusPaid;

  /// Invoice status label - voided
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get orderInvoiceStatusVoided;

  /// Label shown below the invoice preview thumbnail
  ///
  /// In en, this message translates to:
  /// **'PDF preview'**
  String get orderInvoicePreviewLabel;

  /// Message shown while waiting for the PDF to be ready
  ///
  /// In en, this message translates to:
  /// **'Generating invoice PDF…'**
  String get orderInvoicePreviewPending;

  /// Hint displayed below the pending preview message
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh or check again shortly.'**
  String get orderInvoicePreviewPendingHint;

  /// Button label to open the PDF preview
  ///
  /// In en, this message translates to:
  /// **'Open preview'**
  String get orderInvoicePreviewOpen;

  /// Error message shown when launching the preview fails
  ///
  /// In en, this message translates to:
  /// **'Could not open the PDF.'**
  String get orderInvoicePreviewError;

  /// Snack bar message shown when invoice download succeeds
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String orderInvoiceDownloadSuccess(String path);

  /// Snack bar message shown when invoice download fails
  ///
  /// In en, this message translates to:
  /// **'Download failed.'**
  String get orderInvoiceDownloadError;

  /// Subject used when sharing the invoice PDF
  ///
  /// In en, this message translates to:
  /// **'Invoice {invoiceNumber}'**
  String orderInvoiceShareSubject(String invoiceNumber);

  /// Body text used when sharing the invoice PDF
  ///
  /// In en, this message translates to:
  /// **'Here’s the invoice {invoiceNumber} from Hanko Field.'**
  String orderInvoiceShareBody(String invoiceNumber);

  /// Snack bar message shown when invoice sharing fails
  ///
  /// In en, this message translates to:
  /// **'We couldn’t share the invoice.'**
  String get orderInvoiceShareError;

  /// Title shown on the invoice error state
  ///
  /// In en, this message translates to:
  /// **'Invoice unavailable'**
  String get orderInvoiceErrorTitle;

  /// Headline for the support banner
  ///
  /// In en, this message translates to:
  /// **'Need help with this order?'**
  String get orderDetailsSupportBannerTitle;

  /// Body copy for the support banner
  ///
  /// In en, this message translates to:
  /// **'Production is taking longer than expected. Let us know if you need priority handling.'**
  String get orderDetailsSupportBannerMessage;

  /// Heading shown at the top of the order overview
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber}'**
  String orderDetailsHeadline(String orderNumber);

  /// Heading for the recent status timeline chips
  ///
  /// In en, this message translates to:
  /// **'Latest status'**
  String get orderDetailsProgressTitle;

  /// Label for the subtotal line in the totals card
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get orderDetailsSubtotalLabel;

  /// Label for the discount line in the totals card
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get orderDetailsDiscountLabel;

  /// Label for the shipping line in the totals card
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get orderDetailsShippingLabel;

  /// Label for the fees line in the totals card
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get orderDetailsFeesLabel;

  /// Label for the tax line in the totals card
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get orderDetailsTaxLabel;

  /// Label for the grand total line in the totals card
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get orderDetailsTotalLabel;

  /// Label that shows the quantity for a line item
  ///
  /// In en, this message translates to:
  /// **'Qty {quantity}'**
  String orderDetailsQuantityLabel(int quantity);

  /// Label displaying the SKU for a line item
  ///
  /// In en, this message translates to:
  /// **'SKU {sku}'**
  String orderDetailsSkuLabel(String sku);

  /// Heading for the shipping address card
  ///
  /// In en, this message translates to:
  /// **'Shipping address'**
  String get orderDetailsShippingAddressLabel;

  /// Heading for the billing address card
  ///
  /// In en, this message translates to:
  /// **'Billing address'**
  String get orderDetailsBillingAddressLabel;

  /// Label shown when an address is missing
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get orderDetailsAddressUnavailable;

  /// Label displaying a phone number in the addresses section
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String orderDetailsPhoneLabel(String phone);

  /// Label displaying an email address in the contact card
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String orderDetailsEmailLabel(String email);

  /// Timeline chip label when payment is complete
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get orderDetailsTimelinePaid;

  /// Timeline chip label when the order is pending
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get orderDetailsTimelinePending;

  /// Relative timestamp when the update was moments ago
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get orderDetailsUpdatedJustNow;

  /// Relative timestamp shown in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one {# minute ago} other {# minutes ago}}'**
  String orderDetailsUpdatedMinutes(int minutes);

  /// Relative timestamp shown in hours
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, one {# hour ago} other {# hours ago}}'**
  String orderDetailsUpdatedHours(int hours);

  /// Timestamp label when showing a specific date
  ///
  /// In en, this message translates to:
  /// **'on {date}'**
  String orderDetailsUpdatedOn(String date);

  /// Heading for the shipment tracking preview section on the order summary tab
  ///
  /// In en, this message translates to:
  /// **'Shipment tracking'**
  String get orderDetailsTrackingSectionTitle;

  /// Title displayed at the top of the shipment tracking preview card
  ///
  /// In en, this message translates to:
  /// **'Current shipment'**
  String get orderDetailsTrackingCardTitle;

  /// Message shown when shipment tracking data isn’t available yet
  ///
  /// In en, this message translates to:
  /// **'Tracking activates once your order ships. Current order status: {status}'**
  String orderDetailsTrackingCardPending(String status);

  /// Summary line in the tracking preview card showing the shipment status
  ///
  /// In en, this message translates to:
  /// **'Current status: {status}'**
  String orderDetailsTrackingCardStatus(String status);

  /// Line describing the most recent shipment event in the preview card
  ///
  /// In en, this message translates to:
  /// **'Latest update: {event} · {timestamp}'**
  String orderDetailsTrackingCardLatest(String event, String timestamp);

  /// Label for the latest shipment location in the preview card
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String orderDetailsTrackingCardLocation(String location);

  /// Button label to open the full shipment tracking screen
  ///
  /// In en, this message translates to:
  /// **'View tracking'**
  String get orderDetailsTrackingActionLabel;

  /// Error message shown when the tracking preview fails to load
  ///
  /// In en, this message translates to:
  /// **'Tracking could not be loaded.'**
  String get orderDetailsTrackingCardError;

  /// App bar title for the shipment tracking screen
  ///
  /// In en, this message translates to:
  /// **'Tracking · {orderNumber}'**
  String orderTrackingAppBarTitle(String orderNumber);

  /// Tooltip for the map icon on the tracking screen
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get orderTrackingActionViewMap;

  /// Error message when tracking data fails to load
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load tracking details.'**
  String get orderTrackingLoadError;

  /// Title for the empty state when no tracking data is available
  ///
  /// In en, this message translates to:
  /// **'Tracking not available yet'**
  String get orderTrackingUnavailableTitle;

  /// Body message for the empty tracking state
  ///
  /// In en, this message translates to:
  /// **'We’ll show tracking updates here once the carrier shares them.'**
  String get orderTrackingUnavailableMessage;

  /// Primary action label for contacting support from the tracking screen
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get orderTrackingContactSupport;

  /// Snack bar message shown when support contact is triggered
  ///
  /// In en, this message translates to:
  /// **'Support will reach out soon.'**
  String get orderTrackingSupportPending;

  /// Heading above the tracking event timeline
  ///
  /// In en, this message translates to:
  /// **'Tracking updates ({count})'**
  String orderTrackingTimelineTitle(int count);

  /// Snack bar message shown when contacting the carrier
  ///
  /// In en, this message translates to:
  /// **'We’ll connect you with {carrier} shortly.'**
  String orderTrackingContactCarrierPending(String carrier);

  /// Snack bar message confirming the tracking number was copied
  ///
  /// In en, this message translates to:
  /// **'Tracking ID {trackingId} copied.'**
  String orderTrackingCopied(String trackingId);

  /// Snack bar shown when map integration is not yet available but location is known
  ///
  /// In en, this message translates to:
  /// **'Map preview for {location} is coming soon.'**
  String orderTrackingMapPlaceholder(String location);

  /// Snack bar shown when map integration is not yet available and no location is provided
  ///
  /// In en, this message translates to:
  /// **'Map preview is coming soon.'**
  String get orderTrackingMapPlaceholderGeneric;

  /// Label above the shipment selector dropdown
  ///
  /// In en, this message translates to:
  /// **'Select shipment'**
  String get orderTrackingShipmentSelectorLabel;

  /// Label for each shipment option in the dropdown
  ///
  /// In en, this message translates to:
  /// **'Shipment {index} · {carrier}'**
  String orderTrackingShipmentSelectorOption(int index, String carrier);

  /// Label for the last updated timestamp in the tracking screen
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String orderTrackingUpdatedAt(String timestamp);

  /// Label showing the latest known location for the shipment
  ///
  /// In en, this message translates to:
  /// **'Latest location: {location}'**
  String orderTrackingLatestLocation(String location);

  /// Label displaying the estimated delivery date
  ///
  /// In en, this message translates to:
  /// **'Estimated delivery: {date}'**
  String orderTrackingEta(String date);

  /// Label showing the shipment tracking number
  ///
  /// In en, this message translates to:
  /// **'Tracking ID: {trackingId}'**
  String orderTrackingTrackingIdLabel(String trackingId);

  /// Button label to initiate contacting the shipping carrier
  ///
  /// In en, this message translates to:
  /// **'Contact carrier'**
  String get orderTrackingContactCarrierButton;

  /// Button label to copy the tracking number
  ///
  /// In en, this message translates to:
  /// **'Copy tracking ID'**
  String get orderTrackingCopyTrackingIdButton;

  /// Title shown when the shipment has no events in the timeline
  ///
  /// In en, this message translates to:
  /// **'No tracking events yet'**
  String get orderTrackingNoEventsTitle;

  /// Message shown when there are no tracking events
  ///
  /// In en, this message translates to:
  /// **'Check back soon for the first carrier update.'**
  String get orderTrackingNoEventsMessage;

  /// Heading for the order summary card on the tracking screen
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber}'**
  String orderTrackingOrderSummaryTitle(String orderNumber);

  /// Text showing the current order status in the tracking summary
  ///
  /// In en, this message translates to:
  /// **'Order status: {status}'**
  String orderTrackingOrderStatus(String status);

  /// Carrier label for Japan Post
  ///
  /// In en, this message translates to:
  /// **'Japan Post'**
  String get orderTrackingCarrierJapanPost;

  /// Carrier label for Yamato Transport
  ///
  /// In en, this message translates to:
  /// **'Yamato Transport'**
  String get orderTrackingCarrierYamato;

  /// Carrier label for Sagawa Express
  ///
  /// In en, this message translates to:
  /// **'Sagawa Express'**
  String get orderTrackingCarrierSagawa;

  /// Carrier label for DHL
  ///
  /// In en, this message translates to:
  /// **'DHL Express'**
  String get orderTrackingCarrierDhl;

  /// Carrier label for UPS
  ///
  /// In en, this message translates to:
  /// **'UPS'**
  String get orderTrackingCarrierUps;

  /// Carrier label for FedEx
  ///
  /// In en, this message translates to:
  /// **'FedEx'**
  String get orderTrackingCarrierFedex;

  /// Fallback carrier label
  ///
  /// In en, this message translates to:
  /// **'Other carrier'**
  String get orderTrackingCarrierOther;

  /// Shipment status label when the label is created
  ///
  /// In en, this message translates to:
  /// **'Label created'**
  String get orderTrackingStatusLabelCreated;

  /// Shipment status label for in-transit state
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get orderTrackingStatusInTransit;

  /// Shipment status label when out for delivery
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get orderTrackingStatusOutForDelivery;

  /// Shipment status label for delivered state
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderTrackingStatusDelivered;

  /// Shipment status label for exception
  ///
  /// In en, this message translates to:
  /// **'Exception'**
  String get orderTrackingStatusException;

  /// Shipment status label for canceled shipments
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get orderTrackingStatusCancelled;

  /// Event label when the shipping label is created
  ///
  /// In en, this message translates to:
  /// **'Label created'**
  String get orderTrackingEventLabelCreated;

  /// Event label for carrier pickup
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get orderTrackingEventPickedUp;

  /// Event label for in-transit updates
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get orderTrackingEventInTransit;

  /// Event label for arriving at a hub or facility
  ///
  /// In en, this message translates to:
  /// **'Arrived at facility'**
  String get orderTrackingEventArrivedHub;

  /// Event label for customs clearance updates
  ///
  /// In en, this message translates to:
  /// **'Customs clearance'**
  String get orderTrackingEventCustomsClearance;

  /// Event label for out-for-delivery updates
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get orderTrackingEventOutForDelivery;

  /// Event label for delivery confirmation
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderTrackingEventDelivered;

  /// Event label for exception events
  ///
  /// In en, this message translates to:
  /// **'Exception'**
  String get orderTrackingEventException;

  /// Event label when the shipment is being returned
  ///
  /// In en, this message translates to:
  /// **'Returned to sender'**
  String get orderTrackingEventReturnToSender;

  /// Title for the guides list screen
  ///
  /// In en, this message translates to:
  /// **'Guides & Cultural Notes'**
  String get guidesListTitle;

  /// Tooltip for the refresh icon on the guides screen
  ///
  /// In en, this message translates to:
  /// **'Refresh guides'**
  String get guidesRefreshTooltip;

  /// Placeholder text for the guides search bar
  ///
  /// In en, this message translates to:
  /// **'Search guides, topics, or tags'**
  String get guidesSearchHint;

  /// Tooltip for the clear search icon
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get guidesClearSearchTooltip;

  /// Label for the persona filter chips
  ///
  /// In en, this message translates to:
  /// **'Persona'**
  String get guidesFilterPersonaLabel;

  /// Label for the locale filter chips
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get guidesFilterLocaleLabel;

  /// Label for the topic filter chips
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get guidesFilterTopicLabel;

  /// Label for the chip that clears the topic filter
  ///
  /// In en, this message translates to:
  /// **'All topics'**
  String get guidesTopicAllLabel;

  /// Label showing when guides were last updated
  ///
  /// In en, this message translates to:
  /// **'Synced {timestamp}'**
  String guidesLastUpdatedLabel(String timestamp);

  /// Badge shown when data comes from cache
  ///
  /// In en, this message translates to:
  /// **'Offline copy'**
  String get guidesCachedBadge;

  /// Heading for the recommended guides section
  ///
  /// In en, this message translates to:
  /// **'Recommended for {persona}'**
  String guidesRecommendedTitle(String persona);

  /// Chip text shown on cards that are recommended
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get guidesRecommendedChip;

  /// Title for the empty state when no guides match filters
  ///
  /// In en, this message translates to:
  /// **'No guides yet'**
  String get guidesEmptyTitle;

  /// Description for the guides empty state
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or search to discover more cultural notes.'**
  String get guidesEmptyMessage;

  /// Button label to clear guide filters
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get guidesClearFiltersButton;

  /// Title for the guides error state
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load guides'**
  String get guidesLoadErrorTitle;

  /// Body text for the guides error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while fetching guides. Please try again.'**
  String get guidesLoadError;

  /// Retry button label for guides error state
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get guidesRetryButtonLabel;

  /// Label showing estimated reading time for a guide
  ///
  /// In en, this message translates to:
  /// **'{minutes} min read'**
  String guidesReadingTimeLabel(int minutes);

  /// Button label for opening a guide
  ///
  /// In en, this message translates to:
  /// **'Read guide'**
  String get guidesReadButton;

  /// Label for the Japanese persona filter
  ///
  /// In en, this message translates to:
  /// **'Domestic'**
  String get guidesPersonaJapaneseLabel;

  /// Label for the international persona filter
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get guidesPersonaInternationalLabel;

  /// Label for the Japanese locale filter chip
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get guidesLocaleJapaneseLabel;

  /// Label for the English locale filter chip
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get guidesLocaleEnglishLabel;

  /// Label for the culture guide category
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get guidesCategoryCulture;

  /// Label for the how-to guide category
  ///
  /// In en, this message translates to:
  /// **'How-to'**
  String get guidesCategoryHowTo;

  /// Label for the policy guide category
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get guidesCategoryPolicy;

  /// Label for the FAQ guide category
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get guidesCategoryFaq;

  /// Label for the news guide category
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get guidesCategoryNews;

  /// Label for the other guide category
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get guidesCategoryOther;

  /// Label for the share button on the guide detail screen
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get guideDetailShareButtonLabel;

  /// Label for the button that opens the guide in a browser
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get guideDetailOpenInBrowser;

  /// Banner text shown when viewing cached guide content
  ///
  /// In en, this message translates to:
  /// **'Showing offline copy from {timestamp}'**
  String guideDetailCachedBanner(String timestamp);

  /// Label that displays when the guide was last updated
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String guideDetailUpdatedLabel(String timestamp);

  /// Label above the list of sources for a guide
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get guideDetailSourcesLabel;

  /// Heading for related guide recommendations
  ///
  /// In en, this message translates to:
  /// **'Related guides'**
  String get guideDetailRelatedTitle;

  /// Title shown when the guide detail fails to load
  ///
  /// In en, this message translates to:
  /// **'Guide unavailable'**
  String get guideDetailErrorTitle;

  /// Body text for the guide detail error state
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load this guide. Check your connection and try again.'**
  String get guideDetailErrorMessage;

  /// Tooltip when the user can bookmark/save the guide
  ///
  /// In en, this message translates to:
  /// **'Save guide'**
  String get guideDetailBookmarkTooltipSave;

  /// Tooltip when the guide is already bookmarked
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get guideDetailBookmarkTooltipRemove;

  /// Snack bar message when bookmarking succeeds
  ///
  /// In en, this message translates to:
  /// **'Saved for offline reading.'**
  String get guideDetailBookmarkSavedMessage;

  /// Snack bar message when removing bookmark succeeds
  ///
  /// In en, this message translates to:
  /// **'Removed from saved guides.'**
  String get guideDetailBookmarkRemovedMessage;

  /// Message shared when the user taps Share on a guide
  ///
  /// In en, this message translates to:
  /// **'Take a look at \"{title}\" from Hanko Field: {url}'**
  String guideDetailShareMessage(String title, String url);

  /// Snack bar message shown when launching a guide link fails
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the link. Please try again later.'**
  String get guideDetailLinkOpenError;

  /// Placeholder text for the dictionary search bar.
  ///
  /// In en, this message translates to:
  /// **'Search by meaning, reading, or radical'**
  String get kanjiDictionarySearchHint;

  /// Tooltip text for the clear search icon.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get kanjiDictionaryClearSearch;

  /// Tooltip text for the refresh icon.
  ///
  /// In en, this message translates to:
  /// **'Reload results'**
  String get kanjiDictionaryRefresh;

  /// Tooltip for toggling back to all results from favorites.
  ///
  /// In en, this message translates to:
  /// **'Show all results'**
  String get kanjiDictionaryShowAllTooltip;

  /// Tooltip for enabling the favorites-only view.
  ///
  /// In en, this message translates to:
  /// **'Show favorites only'**
  String get kanjiDictionaryShowFavoritesTooltip;

  /// Section title for recent search queries.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get kanjiDictionaryHistorySection;

  /// Section title for recently viewed entries.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed kanji'**
  String get kanjiDictionaryRecentlyViewed;

  /// Heading for the filter chips.
  ///
  /// In en, this message translates to:
  /// **'Refine results'**
  String get kanjiDictionaryFiltersTitle;

  /// Label for grade filters.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get kanjiDictionaryGradeFilterLabel;

  /// Label for stroke count filters.
  ///
  /// In en, this message translates to:
  /// **'Stroke count'**
  String get kanjiDictionaryStrokeFilterLabel;

  /// Label for radical filters.
  ///
  /// In en, this message translates to:
  /// **'Radical'**
  String get kanjiDictionaryRadicalFilterLabel;

  /// Title for the featured kanji carousel.
  ///
  /// In en, this message translates to:
  /// **'Featured kanji'**
  String get kanjiDictionaryFeaturedTitle;

  /// Empty state title when favorites-only view has no entries.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get kanjiDictionaryEmptyFavoritesTitle;

  /// Empty state body when favorites-only view has no entries.
  ///
  /// In en, this message translates to:
  /// **'Bookmark kanji to quickly reference them here.'**
  String get kanjiDictionaryEmptyFavoritesMessage;

  /// Empty state title when a search returns no matches.
  ///
  /// In en, this message translates to:
  /// **'No kanji found'**
  String get kanjiDictionaryEmptyResultsTitle;

  /// Empty state body when a search returns no matches.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting filters or searching with a different keyword.'**
  String get kanjiDictionaryEmptyResultsMessage;

  /// Button label to open the kanji detail sheet.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get kanjiDictionaryViewDetails;

  /// Label showing the number of strokes for a kanji.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# stroke} other {# strokes}}'**
  String kanjiDictionaryStrokeCount(int count);

  /// Heading before the usage examples list.
  ///
  /// In en, this message translates to:
  /// **'Usage examples'**
  String get kanjiDictionaryUsageExamples;

  /// Heading before the stroke order hints.
  ///
  /// In en, this message translates to:
  /// **'Stroke order tips'**
  String get kanjiDictionaryStrokeOrder;

  /// Button label to insert the kanji into the design flow.
  ///
  /// In en, this message translates to:
  /// **'Insert into design'**
  String get kanjiDictionaryInsertAction;

  /// Disabled button label when no design draft is active.
  ///
  /// In en, this message translates to:
  /// **'Start a design to insert kanji'**
  String get kanjiDictionaryInsertDisabled;

  /// Card title promoting the dictionary from the guides list.
  ///
  /// In en, this message translates to:
  /// **'Kanji dictionary'**
  String get kanjiDictionaryPromoTitle;

  /// Card description promoting the dictionary.
  ///
  /// In en, this message translates to:
  /// **'Browse real kanji meanings, readings, and stories to inspire your seal design.'**
  String get kanjiDictionaryPromoDescription;

  /// CTA button label on the promo card.
  ///
  /// In en, this message translates to:
  /// **'Open dictionary'**
  String get kanjiDictionaryPromoCta;
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
