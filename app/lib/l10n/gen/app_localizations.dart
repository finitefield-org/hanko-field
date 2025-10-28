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
