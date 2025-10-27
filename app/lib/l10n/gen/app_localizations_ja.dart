// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ハンコフィールド';

  @override
  String get counterScreenTitle => 'サンプルカウンター';

  @override
  String get increment => 'インクリメント';

  @override
  String countLabel(int value) {
    return 'カウント: $value';
  }

  @override
  String get onboardingAppBarTitle => 'ようこそ Hanko Field へ';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingBack => '戻る';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingGetStarted => 'はじめる';

  @override
  String onboardingProgressLabel(int current, int total) {
    return 'ステップ $current/$total';
  }

  @override
  String get onboardingSlideCraftTitle => 'あなただけの印影を作成';

  @override
  String get onboardingSlideCraftBody => 'テンプレートとガイドで、用途に合った美しい印影を簡単にデザインできます。';

  @override
  String get onboardingSlideSupportTitle => 'いつでもサポート';

  @override
  String get onboardingSlideSupportBody =>
      '注文状況の確認やガイドの閲覧、困ったときのチャットもアプリからすぐに利用できます。';

  @override
  String get onboardingSlideTrustTitle => '安心のセキュリティ';

  @override
  String get onboardingSlideTrustBody => 'データを安全に保ちながら、署名・配送・履歴管理を安心して進められます。';
}
