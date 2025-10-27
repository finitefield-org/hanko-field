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
}
