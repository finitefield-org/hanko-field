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

  @override
  String get homeAppBarTitle => 'ホーム';

  @override
  String get homeFeaturedSectionTitle => '注目のキャンペーン';

  @override
  String get homeFeaturedSectionSubtitleDefault => 'あなたのワークスペース向けに厳選したおすすめです。';

  @override
  String homeFeaturedSectionSubtitle(String persona) {
    return '$persona 向けのおすすめ';
  }

  @override
  String get homeFeaturedEmptyMessage => '現在表示できる注目コンテンツがありません。';

  @override
  String get homeLoadErrorMessage => 'このセクションを読み込めませんでした。';

  @override
  String get homeRetryButtonLabel => '再読み込み';

  @override
  String get homeRecentDesignsTitle => '最近のデザイン';

  @override
  String get homeRecentDesignsSubtitle => '作業の続きや書き出した印影をすぐに確認できます。';

  @override
  String get homeRecentDesignsEmptyTitle => 'まだ最近のデザインがありません';

  @override
  String get homeRecentDesignsEmptyMessage => '新しい印影を作成すると、ここに下書きや履歴が表示されます。';

  @override
  String get homeRecentDesignsEmptyCta => 'デザインをはじめる';

  @override
  String get homeTemplateRecommendationsTitle => 'おすすめテンプレート';

  @override
  String get homeTemplateRecommendationsSubtitle => 'ペルソナや利用状況に合わせたレイアウトと書体です。';

  @override
  String get homeTemplateRecommendationsEmpty => '現在おすすめできるテンプレートはありません。';

  @override
  String get homeDesignStatusDraft => '下書き';

  @override
  String get homeDesignStatusReady => '準備完了';

  @override
  String get homeDesignStatusOrdered => '注文済み';

  @override
  String get homeDesignStatusLocked => 'ロック済み';

  @override
  String homeUpdatedOn(String date) {
    return '$date に更新';
  }

  @override
  String get homeWritingStyleTensho => '篆書体';

  @override
  String get homeWritingStyleReisho => '隷書体';

  @override
  String get homeWritingStyleKaisho => '楷書体';

  @override
  String get homeWritingStyleGyosho => '行書体';

  @override
  String get homeWritingStyleKoentai => '古印体';

  @override
  String get homeWritingStyleCustom => 'カスタム';

  @override
  String get homeShapeRound => '丸形';

  @override
  String get homeShapeSquare => '角形';
}
