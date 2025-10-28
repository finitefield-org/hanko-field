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
}
