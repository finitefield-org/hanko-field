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
  String get libraryListTitle => 'マイ印鑑ライブラリ';

  @override
  String get libraryListSubtitle => '保存した印影を並べ替え・フィルタして、いつでもエクスポートできます。';

  @override
  String get librarySearchPlaceholder => 'デザイン名・ID・メモを検索';

  @override
  String get librarySortRecent => '最近';

  @override
  String get librarySortAiScore => 'AIスコア';

  @override
  String get librarySortName => '名前';

  @override
  String get libraryViewGrid => 'グリッド';

  @override
  String get libraryViewList => 'リスト';

  @override
  String get libraryFilterStatusLabel => 'ステータス';

  @override
  String get libraryFilterPersonaLabel => 'ペルソナ';

  @override
  String get libraryFilterDateLabel => '更新日';

  @override
  String get libraryFilterAiLabel => 'AIスコア';

  @override
  String get libraryFilterHint => 'フィルタは即時に反映され、結果はオフラインでも保持されます。';

  @override
  String get libraryStatusAll => 'すべて';

  @override
  String get libraryPersonaAll => 'すべて';

  @override
  String get libraryPersonaJapanese => '国内';

  @override
  String get libraryPersonaForeigner => '国際';

  @override
  String get libraryDateLast7Days => '直近7日';

  @override
  String get libraryDateLast30Days => '直近30日';

  @override
  String get libraryDateLast90Days => '直近90日';

  @override
  String get libraryDateAnytime => '期間指定なし';

  @override
  String get libraryAiAll => '制限なし';

  @override
  String get libraryAiHigh => '80以上';

  @override
  String get libraryAiMedium => '60以上';

  @override
  String get libraryAiLow => '40以上';

  @override
  String get libraryAiScoreUnknown => 'AIスコア —';

  @override
  String libraryAiScoreValue(int score) {
    return 'AIスコア $score';
  }

  @override
  String libraryUpdatedOn(Object date) {
    return '最終更新 $date';
  }

  @override
  String libraryUpdatedAt(Object date) {
    return '同期日時 $date';
  }

  @override
  String get libraryUpdatedNever => '同期待ち';

  @override
  String get libraryEmptyTitle => '保存済みの印影がありません';

  @override
  String get libraryEmptyMessage => '新しく作成するか、既存のデザインを取り込んでライブラリを充実させましょう。';

  @override
  String get libraryEmptyCta => 'デザインを作成';

  @override
  String get libraryActionPreview => 'プレビュー';

  @override
  String get libraryActionShare => '共有';

  @override
  String get libraryActionEdit => '編集';

  @override
  String get libraryActionExport => '書き出し';

  @override
  String get libraryActionDuplicate => '複製';

  @override
  String get libraryActionReorder => '再注文';

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
  String get libraryDetailTabDetails => '詳細';

  @override
  String get libraryDetailTabActivity => 'アクティビティ';

  @override
  String get libraryDetailTabFiles => 'ファイル';

  @override
  String get libraryDetailQuickActions => 'クイックアクション';

  @override
  String get libraryDetailMetadataTitle => 'デザイン情報';

  @override
  String get libraryDetailAiTitle => 'AI評価';

  @override
  String get libraryDetailVersionTitle => 'バージョン';

  @override
  String get libraryDetailUsageTitle => '利用履歴';

  @override
  String get libraryDetailFilesTitle => 'ファイル';

  @override
  String get libraryDetailMetadataId => 'デザインID';

  @override
  String get libraryDetailMetadataStatus => 'ステータス';

  @override
  String get libraryDetailMetadataPersona => 'ペルソナ';

  @override
  String get libraryDetailMetadataShape => '形状・サイズ';

  @override
  String get libraryDetailMetadataWriting => '書体';

  @override
  String get libraryDetailMetadataUpdated => '最終更新';

  @override
  String get libraryDetailMetadataCreated => '作成日';

  @override
  String get libraryDetailRegistrable => '登録可能';

  @override
  String get libraryDetailNotRegistrable => '調整が必要';

  @override
  String get libraryDetailAiScoreLabel => 'AIスコア';

  @override
  String get libraryDetailAiDiagnosticsLabel => '診断メモ';

  @override
  String get libraryDetailAiDiagnosticsEmpty => '診断データはまだありません。';

  @override
  String libraryDetailVersionCurrent(int version) {
    return '現在のバージョン v$version';
  }

  @override
  String libraryDetailVersionCount(int count) {
    return '$count件のバージョン';
  }

  @override
  String get libraryDetailViewVersionsCta => 'バージョン履歴を開く';

  @override
  String get libraryDetailUsageEmpty => 'まだ利用履歴がありません。';

  @override
  String get libraryDetailUsageCreated => 'ライブラリに保存';

  @override
  String libraryDetailUsageUpdated(int version) {
    return 'v$version に更新';
  }

  @override
  String get libraryDetailUsageOrdered => '注文で利用';

  @override
  String libraryDetailUsageAiCheck(Object score) {
    return 'AI評価 $score';
  }

  @override
  String libraryDetailUsageVersionArchived(int version) {
    return '保存済みバージョン v$version';
  }

  @override
  String get libraryDetailFilesVector => 'ベクターデータ（.svg）';

  @override
  String get libraryDetailFilesPreview => 'プレビューPNG';

  @override
  String get libraryDetailFilesStampMock => '捺印モック';

  @override
  String get libraryDetailFilesUnavailable => 'まだ生成されていません。';

  @override
  String libraryDetailShareSubject(Object id) {
    return '印影デザイン $id';
  }

  @override
  String libraryDetailShareBody(Object name, Object id) {
    return '\"$name\" の印影デザイン（ID: $id）を共有します。';
  }

  @override
  String libraryDetailDuplicateSuccess(Object id) {
    return '$id として複製しました';
  }

  @override
  String get libraryDetailDuplicateFailure => '複製に失敗しました。もう一度お試しください。';

  @override
  String get libraryDetailActionInProgress => '処理中...';

  @override
  String get libraryDetailErrorTitle => 'デザインを読み込めませんでした';

  @override
  String get libraryDetailRetry => '再読み込み';

  @override
  String get libraryDetailShapeRound => '丸形';

  @override
  String get libraryDetailShapeSquare => '角形';

  @override
  String get libraryDetailWritingTensho => '篆書';

  @override
  String get libraryDetailWritingReisho => '隷書';

  @override
  String get libraryDetailWritingKaisho => '楷書';

  @override
  String get libraryDetailWritingGyosho => '行書';

  @override
  String get libraryDetailWritingKoentai => '古印体';

  @override
  String get libraryDetailWritingCustom => 'カスタム';

  @override
  String get libraryExportTitle => 'デジタル書き出し';

  @override
  String get libraryExportHistoryTooltip => '過去の書き出しを確認';

  @override
  String get libraryExportHistoryTitle => '書き出し履歴';

  @override
  String get libraryExportGenerateCta => 'リンクを作成';

  @override
  String get libraryExportRevokeCta => 'すべてのリンクを無効化';

  @override
  String get libraryExportLinkReadySnack => 'リンクを作成しました';

  @override
  String get libraryExportRevokedSnack => 'リンクを無効化しました';

  @override
  String libraryExportShareSubject(String id) {
    return '$id のデジタル書き出し';
  }

  @override
  String get libraryExportCopySnack => 'リンクをコピーしました';

  @override
  String get libraryExportFormatLabel => 'ファイル形式';

  @override
  String get libraryExportFormatPng => 'PNG';

  @override
  String get libraryExportFormatSvg => 'SVG';

  @override
  String get libraryExportFormatPdf => 'PDF';

  @override
  String get libraryExportFormatPngUseMessaging => 'チャットのプレビューに最適';

  @override
  String get libraryExportFormatPngUseTransparent => '透過背景に対応';

  @override
  String get libraryExportFormatSvgUseVector => 'ベクター編集を保持';

  @override
  String get libraryExportFormatSvgUseCnc => 'レーザー/CNC向け';

  @override
  String get libraryExportFormatPdfUsePrint => '印刷用レイアウト';

  @override
  String get libraryExportFormatPdfUseArchive => 'アーカイブ品質';

  @override
  String get libraryExportScaleLabel => 'スケール';

  @override
  String get libraryExportScaleSubtitle => '書き出すファイルのサイズを選択してください。';

  @override
  String libraryExportScaleChip(int factor) {
    return '$factor×';
  }

  @override
  String get libraryExportWatermarkLabel => '透かしを重ねる';

  @override
  String get libraryExportWatermarkDescription => 'プレビューに斜めの透かしを追加します。';

  @override
  String get libraryExportExpiryLabel => 'リンクの有効期限';

  @override
  String libraryExportExpiryDescription(int days) {
    return '$days日後に自動でダウンロードを停止します。';
  }

  @override
  String get libraryExportExpiryDisabled => '期限なし';

  @override
  String get libraryExportExpiryPicker => '有効期限';

  @override
  String libraryExportExpiryDays(int days) {
    return '$days日';
  }

  @override
  String get libraryExportDownloadsLabel => '元データのダウンロードを許可';

  @override
  String get libraryShareLinksTitle => '共有リンク';

  @override
  String get libraryShareLinksSectionActive => '発行中のリンク';

  @override
  String get libraryShareLinksEmptyTitle => '共有リンクはまだありません';

  @override
  String get libraryShareLinksEmptySubtitle => 'モックアップやファイルを見せるにはリンクを発行してください。';

  @override
  String get libraryShareLinksCreateCta => 'リンクを発行';

  @override
  String get libraryShareLinksCreateTooltip => '共有リンクを作成';

  @override
  String get libraryShareLinksHistoryTitle => '履歴';

  @override
  String libraryShareLinksHistorySummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '期限切れ/取り消し: # 件',
      zero: '期限切れのリンクはありません',
    );
    return '$_temp0';
  }

  @override
  String get libraryShareLinksHistoryAction => '履歴を見る';

  @override
  String get libraryShareLinksHistoryEmpty => '期限切れのリンクがここに表示されます。';

  @override
  String get libraryShareLinksCopyAction => 'リンクをコピー';

  @override
  String get libraryShareLinksShareAction => '共有する';

  @override
  String get libraryShareLinksExtendAction => '期限を延長';

  @override
  String get libraryShareLinksExtendSheetTitle => '有効期限を延長';

  @override
  String libraryShareLinksExtendOptionDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '# 日延長',
      one: '# 日延長',
    );
    return '$_temp0';
  }

  @override
  String get libraryShareLinksRevokeTooltip => 'リンクを取り消す';

  @override
  String libraryShareLinksExpiryLabel(Object date) {
    return '$date に有効期限';
  }

  @override
  String libraryShareLinksExpiredOn(Object date) {
    return '$date に期限切れ';
  }

  @override
  String libraryShareLinksRevokedOn(Object date) {
    return '$date に取り消し';
  }

  @override
  String get libraryShareLinksExpiryNever => '有効期限なし';

  @override
  String libraryShareLinksVisitsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 回のアクセス',
      zero: 'アクセスはまだありません',
    );
    return '$_temp0';
  }

  @override
  String libraryShareLinksUsageCap(int limit) {
    return '最大 $limit 回';
  }

  @override
  String libraryShareLinksLastOpened(Object timestamp) {
    return '最終アクセス $timestamp';
  }

  @override
  String get libraryShareLinksCreatedSnack => '共有リンクを発行しました。';

  @override
  String get libraryShareLinksExtendSnack => '有効期限を延長しました。';

  @override
  String get libraryShareLinksRevokeSnack => 'リンクを取り消しました。';

  @override
  String get libraryShareLinksErrorGeneric => '共有リンクを更新できませんでした。もう一度お試しください。';

  @override
  String libraryShareLinksShareSubject(String id) {
    return '$id の共有リンク';
  }

  @override
  String get libraryShareLinksHistorySheetTitle => '期限切れのリンク';

  @override
  String get libraryExportDownloadsDescription => '受け手がフル解像度のファイルを保存できます。';

  @override
  String get libraryExportLinkTitle => '共有リンク';

  @override
  String get libraryExportLinkEmptyTitle => 'リンクがまだありません';

  @override
  String get libraryExportLinkEmptyMessage => '安全に共有するにはリンクを作成してください。';

  @override
  String get libraryExportShareLink => 'リンクを共有';

  @override
  String get libraryExportCopyLink => 'リンクをコピー';

  @override
  String libraryExportExpiresOn(String date) {
    return '$dateに失効';
  }

  @override
  String libraryExportLinkMeta(String format, String scale) {
    return '$format・$scale';
  }

  @override
  String get libraryLoadError => 'ライブラリを読み込めませんでした。通信環境を確認して再試行してください。';

  @override
  String get libraryErrorTitle => 'ライブラリを表示できません';

  @override
  String get libraryRetry => '再試行';

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
  String get designAiSuggestionsTitle => 'AI提案';

  @override
  String get designAiSuggestionsQueueTooltip => 'キュー中の提案';

  @override
  String get designAiSuggestionsRequestQueued => 'AIジョブを受け付けました。まもなく提案が追加されます。';

  @override
  String designAiSuggestionsRequestRateLimited(int seconds) {
    return '次のリクエストまで $seconds 秒お待ちください。';
  }

  @override
  String get designAiSuggestionsGenericError =>
      '提案を更新できませんでした。時間をおいて再試行してください。';

  @override
  String designAiSuggestionsSegmentReady(int count) {
    return '利用可能 ($count)';
  }

  @override
  String designAiSuggestionsSegmentQueued(int count) {
    return 'キュー中 ($count)';
  }

  @override
  String designAiSuggestionsSegmentApplied(int count) {
    return '適用済み ($count)';
  }

  @override
  String get designAiSuggestionsHelperTitle => '別の案を試しますか？';

  @override
  String get designAiSuggestionsHelperSubtitle =>
      'AIが現在のデザインと比較できるレイアウト提案を生成します。';

  @override
  String get designAiSuggestionsRequestCta => '新しい提案を依頼';

  @override
  String designAiSuggestionsRateLimitCountdown(int seconds) {
    return 'あと $seconds 秒で再度リクエストできます';
  }

  @override
  String get designAiSuggestionsEmptyReadyTitle => '提案がまだありません';

  @override
  String get designAiSuggestionsEmptyReadyBody =>
      'AIに依頼してレイアウト案を取得し、現在の印影と見比べてみましょう。';

  @override
  String get designAiSuggestionsEmptyQueuedTitle => 'キューは空です';

  @override
  String get designAiSuggestionsEmptyQueuedBody =>
      '準備ができたら提案を依頼してください。バックグラウンドで処理されます。';

  @override
  String get designAiSuggestionsEmptyAppliedTitle => '適用した提案はありません';

  @override
  String get designAiSuggestionsEmptyAppliedBody => '受け入れた提案がここに履歴として表示されます。';

  @override
  String designAiSuggestionsAcceptSuccess(String title) {
    return '\"$title\" をデザインに適用しました。';
  }

  @override
  String designAiSuggestionsRejectSuccess(String title) {
    return '\"$title\" を却下しました。';
  }

  @override
  String get designAiSuggestionsAccept => '受け入れる';

  @override
  String get designAiSuggestionsReject => '却下';

  @override
  String get designAiSuggestionsAppliedLabel => 'デザインに適用済み';

  @override
  String get designAiSuggestionsQueuedLabel => '処理待ち';

  @override
  String designAiSuggestionsScoreLabel(int percent) {
    return 'スコア $percent%';
  }

  @override
  String get designAiSuggestionsComparisonHint => '比較スライダー';

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
  String get designInputTitle => 'お名前を入力';

  @override
  String get designInputSubtitle => '印影に刻む姓と名を入力してください。入力内容に合わせてプレビューが更新されます。';

  @override
  String get designInputPreviewTitle => 'ライブプレビュー';

  @override
  String get designInputPreviewCaption => '書体やレイアウトは次のステップで調整できます。';

  @override
  String get designInputPlaceholderPrimary => '山田太郎';

  @override
  String get designInputSectionPrimary => '氏名（漢字またはローマ字）';

  @override
  String get designInputSectionReading => 'よみがな / 発音';

  @override
  String get designInputSurnameLabel => '姓';

  @override
  String get designInputGivenNameLabel => '名';

  @override
  String get designInputSurnameHelper => '全角6文字まで入力できます。';

  @override
  String get designInputGivenNameHelper => '全角6文字まで入力できます。';

  @override
  String get designInputSurnameReadingLabel => '姓（ふりがな）';

  @override
  String get designInputGivenNameReadingLabel => '名（ふりがな）';

  @override
  String get designInputReadingHelper => 'ひらがな・カタカナで入力してください（日本語の印影では必須）。';

  @override
  String get designInputContinue => '書体を選ぶ';

  @override
  String get designStyleTitle => '書体とテンプレートを選択';

  @override
  String get designStyleSubtitle =>
      'ペルソナに合わせて書体ファミリーと印面の形状、テンプレートを選択してください。詳細の調整は後で行えます。';

  @override
  String get designStyleHelpTooltip => '書体のヒント';

  @override
  String get designStyleScriptKanji => '漢字';

  @override
  String get designStyleScriptKana => 'かな';

  @override
  String get designStyleScriptRoman => 'ローマ字';

  @override
  String get designStyleShapeRound => '丸印';

  @override
  String get designStyleShapeSquare => '角印';

  @override
  String get designStyleContinue => 'エディターを開く';

  @override
  String get designStyleFavoritesAdd => 'お気に入りに追加';

  @override
  String get designStyleFavoritesRemove => 'お気に入り済み';

  @override
  String get designStyleEmptyTitle => '表示できるテンプレートがありません';

  @override
  String get designStyleEmptyBody =>
      'フィルターを調整するか再読み込みして、ペルソナや利用可能なフォントに合うテンプレートを取得してください。';

  @override
  String get designStyleRetry => '再試行';

  @override
  String get designStyleSelectedHeading => '選択中のテンプレート';

  @override
  String get designEditorTitle => 'デザインエディター';

  @override
  String get designEditorFallbackText => 'サンプル';

  @override
  String get designEditorPrimaryCta => 'プレビュー・エクスポート';

  @override
  String get designEditorUndoTooltip => '元に戻す';

  @override
  String get designEditorRedoTooltip => 'やり直す';

  @override
  String get designEditorRegistrabilityTooltip => '登録可否チェック';

  @override
  String get designEditorMoreActionsTooltip => 'その他の操作';

  @override
  String get designEditorVersionHistoryTooltip => '版の履歴';

  @override
  String get designEditorResetMenu => 'テンプレート初期値にリセット';

  @override
  String get designEditorResetSnackbar => 'テンプレート初期値にリセットしました。';

  @override
  String get designEditorToolSelect => '選択';

  @override
  String get designEditorToolText => 'テキスト';

  @override
  String get designEditorToolLayout => 'レイアウト';

  @override
  String get designEditorToolExport => '書き出し';

  @override
  String get designEditorCanvasTitle => 'ライブキャンバス';

  @override
  String get designEditorCanvasUntitled => 'テンプレート（名称未設定）';

  @override
  String get designEditorAutosaveInProgress => '自動保存中...';

  @override
  String get designEditorAutosaveIdle => '調整内容は自動的に保存されます。';

  @override
  String designEditorAutosaveCompleted(String time) {
    return '$time に保存しました';
  }

  @override
  String get designEditorPropertiesHeading => 'プロパティ';

  @override
  String get designRegistrabilityTitle => '登録可否チェック';

  @override
  String get designRegistrabilityRefreshTooltip => '再チェック';

  @override
  String get designRegistrabilityIncompleteTitle => 'デザインの設定を完了してください';

  @override
  String get designRegistrabilityIncompleteBody =>
      'テンプレートを選び、名前を入力してから登録可否を確認します。';

  @override
  String get designRegistrabilityNoResultTitle => 'まだチェックしていません';

  @override
  String get designRegistrabilityNoResultBody =>
      '登録可否チェックを実行して、重複や注意点を確認しましょう。';

  @override
  String get designRegistrabilityRunCheck => 'チェックを実行';

  @override
  String get designRegistrabilityOutdatedBanner =>
      '最後のチェック以降にデザインが変更されました。再チェックしてください。';

  @override
  String get designRegistrabilityOfflineTitle => 'キャッシュ結果を表示しています';

  @override
  String get designRegistrabilityOfflineBody =>
      'オフラインのため、最後に成功したチェック結果を表示しています。';

  @override
  String get designRegistrabilityStatusSafe => '登録可能';

  @override
  String get designRegistrabilityStatusCaution => '提出前に確認が必要';

  @override
  String get designRegistrabilityStatusBlocked => '登録不可';

  @override
  String designRegistrabilityCheckedAt(String timestamp) {
    return '$timestamp にチェック';
  }

  @override
  String get designRegistrabilityCacheStale => 'キャッシュ結果が古い可能性があります。';

  @override
  String get designRegistrabilityCacheFresh => '最新の結果をオフライン用に保存しました。';

  @override
  String get designRegistrabilityRunFailed => '登録可否チェックを開始できませんでした。再試行してください。';

  @override
  String get designRegistrabilityOutdatedHint => '最新の調整を反映するには再チェックしてください。';

  @override
  String designRegistrabilityScore(String value) {
    return 'スコア $value';
  }

  @override
  String get designRegistrabilityDiagnosticsTitle => '診断結果';

  @override
  String get designRegistrabilityBadgeSafe => '安全';

  @override
  String get designRegistrabilityBadgeSimilar => '類似';

  @override
  String get designRegistrabilityBadgeConflict => '衝突';

  @override
  String get designRegistrabilityBadgeInfo => '注意';

  @override
  String get designRegistrabilityConflictTitle => '衝突を検出しました';

  @override
  String get designRegistrabilityConflictBody => '提出前に以下の問題を解消してください。';

  @override
  String get designEditorStrokeLabel => '輪郭の太さ';

  @override
  String designEditorStrokeValue(String weight) {
    return '$weight pt';
  }

  @override
  String get designEditorMarginLabel => '余白';

  @override
  String designEditorMarginValue(String value) {
    return '$value px';
  }

  @override
  String get designEditorRotationLabel => '回転';

  @override
  String designEditorRotationValue(String value) {
    return '$value 度';
  }

  @override
  String get designEditorGridLabel => 'グリッド';

  @override
  String get designEditorGridNone => 'なし';

  @override
  String get designEditorGridSquare => '方眼';

  @override
  String get designEditorGridRadial => '放射';

  @override
  String get designEditorAlignmentLabel => '配置';

  @override
  String get designEditorAlignCenter => '中央';

  @override
  String get designEditorAlignTop => '上';

  @override
  String get designEditorAlignBottom => '下';

  @override
  String get designEditorAlignLeft => '左';

  @override
  String get designEditorAlignRight => '右';

  @override
  String get designEditorPreviewPlaceholder => 'プレビュー機能は近日公開予定です。';

  @override
  String get designPreviewTitle => 'プレビューと共有';

  @override
  String get designPreviewShareTooltip => 'プレビューを共有';

  @override
  String get designPreviewEditTooltip => '編集に戻る';

  @override
  String get designPreviewMissingSelection =>
      'テンプレートを選択し、文字を入力してからプレビューを表示してください。';

  @override
  String get designPreviewExportCta => '共有・エクスポート';

  @override
  String get designPreviewBackToEditor => '編集に戻る';

  @override
  String designPreviewActualSizeLabel(String sizeMm, String sizeInch) {
    return '実寸表示・$sizeMm mm・$sizeInch in';
  }

  @override
  String get designPreviewActualSizeHint =>
      '端末を正面に持って実寸（1:1）を確認し、細部はピンチ操作で拡大してください。';

  @override
  String get designPreviewBackgroundLabel => '背景';

  @override
  String get designPreviewBackgroundPaper => '和紙';

  @override
  String get designPreviewBackgroundWood => '木目';

  @override
  String get designPreviewBackgroundTransparent => '透明';

  @override
  String get designPreviewLightingLabel => 'ライティング';

  @override
  String get designPreviewLightingNone => 'なし';

  @override
  String get designPreviewLightingSoft => 'ソフトライト';

  @override
  String get designPreviewLightingStudio => 'スタジオ光';

  @override
  String get designPreviewMeasurementToggle => '寸法ガイドを表示';

  @override
  String get designPreviewMeasurementHint => 'ミリとインチの横・縦ガイドを重ねて表示します。';

  @override
  String get designPreviewShareSheetTitle => 'デザインを共有';

  @override
  String get designPreviewShareSheetSubtitle => 'スタッフや取引先にすぐ見せたり、メモとして保存できます。';

  @override
  String get designPreviewShareOptionSave => 'デバイスに保存';

  @override
  String get designPreviewShareOptionSaveSubtitle => '高解像度PNGとしてギャラリーに書き出します。';

  @override
  String get designPreviewShareOptionMessage => 'メッセージで送信';

  @override
  String get designPreviewShareOptionMessageSubtitle =>
      'チャットアプリで軽量プレビューを共有します。';

  @override
  String get designPreviewShareOptionLink => 'リンクをコピー';

  @override
  String get designPreviewShareOptionLinkSubtitle => '利用可能になったら共有リンクを生成します。';

  @override
  String get designPreviewShareCancel => 'キャンセル';

  @override
  String get designShareTitle => '共有モックアップ';

  @override
  String get designShareSubtitle => '透かしやキャプション、ハッシュタグを設定してSNS向けのプレビューを作成します。';

  @override
  String get designShareCloseTooltip => '共有画面を閉じる';

  @override
  String get designShareCopyLinkTooltip => '公開リンクをコピー';

  @override
  String get designShareMissingSelection => 'テンプレートと名前を選択してから共有アセットを生成してください。';

  @override
  String get designShareWatermarkLabel => 'Hanko Field';

  @override
  String get designShareWatermarkToggleTitle => 'Hanko Fieldの透かしを重ねる';

  @override
  String get designShareWatermarkToggleSubtitle => '試作共有向けに斜めの透かしを薄く追加します。';

  @override
  String get designShareHashtagToggleTitle => 'ハッシュタグを追加';

  @override
  String get designShareHashtagToggleSubtitle => '共有時に推奨ハッシュタグを含めます。';

  @override
  String get designShareCaptionLabel => '共有キャプション';

  @override
  String get designShareCaptionHint => '短い説明文を書くか、下の候補を使用してください。';

  @override
  String get designShareSuggestionsLabel => '定型コピー';

  @override
  String get designShareSuggestionCelebrationLabel => '完成報告';

  @override
  String get designShareSuggestionCraftLabel => '制作ストーリー';

  @override
  String get designShareSuggestionLaunchLabel => 'リリース告知';

  @override
  String designShareSuggestionCelebrationText(String name) {
    return '新しい印影「$name」が完成しました。';
  }

  @override
  String designShareSuggestionCraftText(String style, String name) {
    return '$name様のために$style仕上げで制作しました。';
  }

  @override
  String designShareSuggestionCraftTextAlt(String name) {
    return '丁寧に仕上げた印影を$name様にご用意しました。';
  }

  @override
  String designShareSuggestionLaunchText(String name) {
    return '$name様のブランドローンチに向けて印影を準備しています。';
  }

  @override
  String get designShareHashtagsLabel => 'ハッシュタグ';

  @override
  String get designShareQuickTargetsLabel => 'クイック共有先';

  @override
  String get designShareAssistInstagram => 'Instagramフィード';

  @override
  String get designShareAssistX => 'X投稿';

  @override
  String get designShareAssistLinkedIn => 'LinkedInアップデート';

  @override
  String get designShareShareButton => '共有シートを開く';

  @override
  String designShareShareSubject(String platform) {
    return '$platform向けモックアップを共有';
  }

  @override
  String get designShareShareSuccess => '共有シートを開きました。';

  @override
  String get designShareShareError => 'モックアップの準備に失敗しました。もう一度お試しください。';

  @override
  String get designShareCopySuccess => 'リンクをクリップボードにコピーしました。';

  @override
  String designShareDefaultCaption(String name, String platform) {
    return '$platformで$name様の印影を紹介します。';
  }

  @override
  String get designSharePlatformInstagram => 'Instagram';

  @override
  String get designSharePlatformX => 'X';

  @override
  String get designSharePlatformLinkedIn => 'LinkedIn';

  @override
  String get designShareBackgroundSunsetGlow => 'サンセットグロー';

  @override
  String get designShareBackgroundMorningMist => 'モーニングミスト';

  @override
  String get designShareBackgroundNeoNoir => 'ネオノワール';

  @override
  String get designShareBackgroundMidnight => 'ミッドナイト';

  @override
  String get designShareBackgroundCyanGrid => 'シアングリッド';

  @override
  String get designShareBackgroundGraphite => 'グラファイト';

  @override
  String get designShareBackgroundStudio => 'スタジオライト';

  @override
  String get designShareBackgroundNavySlate => 'ネイビースレート';

  @override
  String get designShareBackgroundAquaFocus => 'アクアフォーカス';

  @override
  String designShareLastShared(String date, String time) {
    return '最終共有: $date $time';
  }

  @override
  String get designVersionHistoryTitle => '版の履歴';

  @override
  String get designVersionHistoryShowAllTooltip => 'すべての項目を表示';

  @override
  String get designVersionHistoryShowChangesTooltip => '変更された項目のみ強調';

  @override
  String get designVersionHistoryEmptyState =>
      'まだ履歴がありません。変更を保存すると復元ポイントが表示されます。';

  @override
  String designVersionHistoryRestoredSnack(int version) {
    return 'バージョン v$version を復元しました。';
  }

  @override
  String designVersionHistoryDuplicatedSnack(String designId) {
    return '$designId として複製しました。';
  }

  @override
  String get designVersionHistoryTimelineTitle => '履歴タイムライン';

  @override
  String get designVersionHistoryTimelineSubtitle => '比較・復元したいバージョンを選択してください。';

  @override
  String get designVersionHistoryRefreshTooltip => '履歴を再読み込み';

  @override
  String get designVersionHistoryStatusCurrent => '現在';

  @override
  String get designVersionHistoryStatusArchived => '保存済み';

  @override
  String get designVersionHistoryCurrentLabel => '現在のバージョン';

  @override
  String designVersionHistorySelectedLabel(int version) {
    return '選択中 v$version';
  }

  @override
  String get designVersionHistoryDiffTitle => '差分ビュー';

  @override
  String get designVersionHistoryDiffHighlightSubtitle => '変更された項目のみ表示しています。';

  @override
  String get designVersionHistoryDiffAllSubtitle => 'トラッキングしているすべての項目を表示しています。';

  @override
  String get designVersionHistoryDiffNoChanges => '選択したバージョンとの違いは見つかりませんでした。';

  @override
  String get designVersionHistoryDiffNotAvailable => '差分を取得できませんでした。';

  @override
  String designVersionHistoryDiffCurrent(String value) {
    return '現在: $value';
  }

  @override
  String designVersionHistoryDiffSelected(String value) {
    return '選択: $value';
  }

  @override
  String get designVersionHistoryDuplicateCta => 'バージョンを複製';

  @override
  String get designVersionHistoryRestoreCta => 'バージョンを復元';

  @override
  String get designExportTitle => 'デジタル書き出し';

  @override
  String get designExportHistoryTooltip => '書き出し履歴を表示';

  @override
  String get designExportPreviewLabel => 'プレビュー';

  @override
  String get designExportFormatLabel => 'フォーマット';

  @override
  String get designExportFormatPng => 'PNG';

  @override
  String get designExportFormatSvg => 'SVG';

  @override
  String get designExportFormatPdf => 'PDF（近日対応）';

  @override
  String get designExportOptionTransparent => '背景を透明にする';

  @override
  String get designExportOptionTransparentSubtitle => '印影以外の背景を透過にします。';

  @override
  String get designExportOptionBleed => '塗り足しを追加';

  @override
  String get designExportOptionBleedSubtitle => '印影の周囲に安全マージンを確保します。';

  @override
  String get designExportOptionMetadata => 'メタデータを埋め込む';

  @override
  String get designExportOptionMetadataSubtitle => '書き出しファイルと一緒に作成情報を保存します。';

  @override
  String get designExportExportButton => '書き出す';

  @override
  String get designExportShareButton => '共有';

  @override
  String get designExportPermissionDenied => 'ストレージへのアクセス許可が必要です。';

  @override
  String designExportExportSuccess(String path) {
    return '$path に書き出しました';
  }

  @override
  String designExportMetadataSaved(String path) {
    return '$path にメタデータを保存しました';
  }

  @override
  String get designExportGenericError => '書き出しに失敗しました。もう一度お試しください。';

  @override
  String get designExportPdfUnavailable => 'PDF書き出しは現在準備中です。';

  @override
  String get designExportShareError => '現在は共有できません。';

  @override
  String get designExportShareSubject => '印鑑デザインのプレビュー';

  @override
  String get designExportShareBody => '最新の印鑑デザインを書き出しました。';

  @override
  String get designExportDestinationTitle => '保存先を選択';

  @override
  String get designExportDestinationDownloads => 'ダウンロードフォルダ';

  @override
  String get designExportDestinationAppStorage => 'アプリ内ドキュメント';

  @override
  String get designExportHistoryTitle => '最近の書き出し';

  @override
  String designExportHistorySubtitle(String format, String timestamp) {
    return '$format・$timestamp';
  }

  @override
  String get designExportHistoryEmpty => 'まだ書き出し履歴はありません。';

  @override
  String get designInputSuggestionHeader => 'プロフィールから補完';

  @override
  String get designInputSuggestionProfile => 'プロフィール名を使用';

  @override
  String get designInputSuggestionIdentity => 'アカウント名を使用';

  @override
  String get designInputSuggestionFallback => '名前を挿入';

  @override
  String get designInputKanjiMappingTitle => '漢字の候補を探していますか？';

  @override
  String get designInputKanjiMappingDescription => '外国人の方向けに、意味付きの漢字候補を検索できます。';

  @override
  String get designInputKanjiMappingCta => '漢字マップを開く';

  @override
  String designInputKanjiMappingSelectionLabel(String value) {
    return '選択中の漢字：$value';
  }

  @override
  String get designInputErrorEmptySurname => '姓を入力してください。';

  @override
  String get designInputErrorEmptyGiven => '名を入力してください。';

  @override
  String get designInputErrorInvalidKanji => '全角の漢字・かなで入力してください。';

  @override
  String get designInputErrorTooLongKanji => '全角6文字以内で入力してください。';

  @override
  String get designInputErrorTooLongLatin => '20文字以内で入力してください。';

  @override
  String get designInputErrorInvalidKana => 'ひらがな・カタカナ・長音符のみ使用できます。';

  @override
  String get designInputErrorTooLongKana => '20文字以内で入力してください。';

  @override
  String get designInputErrorEmptyKana => 'ふりがなを入力してください。';

  @override
  String get designInputValidationFailed => '入力内容を確認してください。';

  @override
  String get designKanjiMappingTitle => '漢字マップ';

  @override
  String get designKanjiMappingConfirm => 'この候補を使う';

  @override
  String get designKanjiMappingSearchHint => '意味・読み・部首で検索';

  @override
  String get designKanjiMappingRefreshTooltip => '候補を更新';

  @override
  String get designKanjiMappingCompareHeader => '比較リスト';

  @override
  String get designKanjiMappingCompareToggleLabel => '比較に追加';

  @override
  String get designKanjiMappingCompareSelectedLabel => '比較リストに追加済み';

  @override
  String designKanjiMappingStrokeCountLabel(int count) {
    return '$count画';
  }

  @override
  String get designKanjiMappingBookmarkAdd => 'ブックマークに追加';

  @override
  String get designKanjiMappingBookmarkRemove => 'ブックマークを解除';

  @override
  String get designKanjiMappingSelectTooltip => 'この候補を選択';

  @override
  String get designKanjiMappingManualTitle => '手動入力';

  @override
  String get designKanjiMappingManualDescription =>
      '使いたい漢字が決まっている場合はこちらから直接入力できます。';

  @override
  String get designKanjiMappingManualKanjiLabel => '漢字';

  @override
  String get designKanjiMappingManualKanjiHelper => '最大4文字まで。全角で入力してください。';

  @override
  String get designKanjiMappingManualMeaningLabel => '意味・メモ（任意）';

  @override
  String get designKanjiMappingManualMeaningHelper => '自分用のメモ。印影には表示されません。';

  @override
  String get designKanjiMappingEmptyResultsTitle => '一致する候補が見つかりません';

  @override
  String get designKanjiMappingEmptyResultsDescription =>
      'フィルターを見直すか、別の意味・読みで検索してみてください。';

  @override
  String get ordersStatusAll => 'すべて';

  @override
  String get ordersFilterStatusLabel => 'ステータスで絞り込み';

  @override
  String get ordersStatusInProgress => '進行中';

  @override
  String get ordersStatusShipped => '発送済み';

  @override
  String get ordersStatusDelivered => '配達完了';

  @override
  String get ordersStatusCanceled => 'キャンセル済み';

  @override
  String get ordersFilterTimeLabel => '期間で絞り込み';

  @override
  String get ordersTimeRange30Days => '過去30日間';

  @override
  String get ordersTimeRange90Days => '過去90日間';

  @override
  String get ordersTimeRange6Months => '過去6か月';

  @override
  String get ordersTimeRangeYear => '過去1年間';

  @override
  String get ordersTimeRangeAll => '全期間';

  @override
  String ordersLastUpdatedText(Object timestamp) {
    return '最終更新: $timestamp';
  }

  @override
  String get ordersListEmptyTitle => 'まだ注文がありません';

  @override
  String get ordersListEmptyMessage => '注文すると、ステータスや追跡情報とともにここに表示されます。';

  @override
  String get ordersListErrorTitle => '注文履歴を読み込めませんでした';

  @override
  String get ordersListErrorMessage => '通信状況を確認してもう一度お試しください。';

  @override
  String get ordersListRetryLabel => '再試行';

  @override
  String get ordersListRefreshError => '注文を更新できませんでした。';

  @override
  String get ordersUnknownItem => 'カスタム注文';

  @override
  String get ordersTimelineOrdered => '注文受付';

  @override
  String get ordersTimelineProduction => '制作';

  @override
  String get ordersTimelineShipping => '発送';

  @override
  String get ordersTimelineDelivered => '配達完了';

  @override
  String get ordersTimelineCanceled => '注文はキャンセルされました';

  @override
  String get orderStatusPendingPayment => '支払い待ち';

  @override
  String get orderStatusPaid => '支払い済み';

  @override
  String get orderStatusInProduction => '制作中';

  @override
  String get orderStatusReadyToShip => '発送準備中';

  @override
  String get orderStatusShipped => '発送済み';

  @override
  String get orderStatusDelivered => '配達完了';

  @override
  String get orderStatusCanceled => 'キャンセル済み';

  @override
  String get orderDetailsTabSummary => '概要';

  @override
  String get orderDetailsTabTimeline => 'タイムライン';

  @override
  String get orderDetailsTabFiles => 'ファイル';

  @override
  String orderDetailsAppBarTitle(String orderNumber) {
    return '注文 $orderNumber';
  }

  @override
  String get orderDetailsActionReorder => '再注文';

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
  String get orderDetailsActionShare => '共有';

  @override
  String get orderDetailsItemsSectionTitle => '商品';

  @override
  String orderDetailsItemsSectionCount(int count) {
    return '$count件';
  }

  @override
  String get orderDetailsTotalsSectionTitle => '支払い内訳';

  @override
  String orderDetailsLastUpdated(String timestamp) {
    return '$timestampに更新';
  }

  @override
  String get orderDetailsAddressesSectionTitle => '住所';

  @override
  String get orderDetailsContactSectionTitle => '連絡先';

  @override
  String get orderDetailsDesignSectionTitle => 'デザインスナップショット';

  @override
  String get orderDetailsLoadErrorMessage => '注文詳細を読み込めませんでした';

  @override
  String get orderDetailsRetryLabel => '再試行';

  @override
  String get orderDetailsTimelineTabTitle => '制作タイムライン';

  @override
  String get orderDetailsTimelinePlaceholder => '制作・検品・配送の更新をここに表示します。';

  @override
  String get orderDetailsTimelineLoadErrorMessage => '生産状況を読み込めませんでした';

  @override
  String get orderDetailsActionRefresh => '更新';

  @override
  String get orderDetailsProductionTimelineEmpty => '生産のチェックポイントはまだありません。';

  @override
  String get orderDetailsProductionTimelineStageListTitle => 'ステージ履歴';

  @override
  String get orderDetailsProductionOverviewTitle => '生産概要';

  @override
  String get orderDetailsProductionEstimatedCompletionLabel => '完了予定';

  @override
  String get orderDetailsProductionEstimatedCompletionUnknown => 'スケジュール調整中';

  @override
  String get orderDetailsProductionCurrentStageLabel => '現在のステージ';

  @override
  String get orderDetailsProductionOnSchedule => '予定どおり';

  @override
  String orderDetailsProductionDelay(String duration) {
    return '約$durationの遅れ';
  }

  @override
  String orderDetailsProductionQueue(String queue) {
    return 'キュー: $queue';
  }

  @override
  String orderDetailsProductionStation(String station) {
    return '作業台: $station';
  }

  @override
  String orderDetailsProductionOperator(String operator) {
    return '担当者: $operator';
  }

  @override
  String get orderDetailsProductionValueUnknown => '未割り当て';

  @override
  String get orderDetailsProductionHealthOnTrack => '順調';

  @override
  String get orderDetailsProductionHealthAttention => '要確認';

  @override
  String get orderDetailsProductionHealthDelayed => '遅延';

  @override
  String get orderDetailsProductionStageUnknown => '不明なステージ';

  @override
  String get orderDetailsProductionStageQueued => '待機中';

  @override
  String get orderDetailsProductionStageEngraving => '彫刻';

  @override
  String get orderDetailsProductionStagePolishing => '研磨';

  @override
  String get orderDetailsProductionStageQc => '検品';

  @override
  String get orderDetailsProductionStagePacked => '梱包';

  @override
  String get orderDetailsProductionStageOnHold => '保留';

  @override
  String get orderDetailsProductionStageRework => '手直し';

  @override
  String get orderDetailsProductionStageCanceled => 'キャンセル';

  @override
  String orderDetailsProductionDurationHours(int hours) {
    return '$hours時間';
  }

  @override
  String orderDetailsProductionDurationMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String orderDetailsProductionStageDuration(String duration) {
    return '$duration経過';
  }

  @override
  String orderDetailsProductionStageActive(String duration) {
    return '経過中: $duration';
  }

  @override
  String orderDetailsProductionQcResult(String result) {
    return '検品結果: $result';
  }

  @override
  String orderDetailsProductionQcDefects(String defects) {
    return '指摘事項: $defects';
  }

  @override
  String orderDetailsProductionNotes(String notes) {
    return 'メモ: $notes';
  }

  @override
  String get orderDetailsFilesTabTitle => 'ファイル・書類';

  @override
  String get orderDetailsFilesPlaceholder => '領収書や証明書などのファイルがここに並びます。';

  @override
  String orderDetailsReorderSuccess(String orderNumber) {
    return '$orderNumber の再注文を受け付けました。';
  }

  @override
  String get orderDetailsReorderError => '再注文を開始できませんでした。';

  @override
  String orderDetailsInvoiceSuccess(String orderNumber) {
    return '$orderNumber の請求書リクエストを送信しました。';
  }

  @override
  String get orderDetailsInvoiceError => '請求書をリクエストできませんでした。';

  @override
  String get orderDetailsSupportMessage => 'サポートがまもなくご連絡します。ヘルプタブからチャットもできます。';

  @override
  String orderDetailsShareSubject(String orderNumber) {
    return '注文 $orderNumber の概要';
  }

  @override
  String orderDetailsShareBody(String orderNumber, String total) {
    return '注文 $orderNumber の合計金額は $total です。\\n詳細は Hanko Field アプリをご確認ください。';
  }

  @override
  String get orderDetailsActionSupport => 'サポートに連絡';

  @override
  String get orderDetailsActionInvoice => '請求書をダウンロード';

  @override
  String orderInvoiceAppBarTitle(String orderNumber) {
    return '請求書 · $orderNumber';
  }

  @override
  String get orderInvoiceShareTooltip => 'PDFを共有';

  @override
  String get orderInvoiceLoadError => '請求書を読み込めませんでした。';

  @override
  String get orderInvoiceRetryLabel => '再試行';

  @override
  String orderInvoiceHeadline(String orderNumber) {
    return '$orderNumber の請求書';
  }

  @override
  String orderInvoiceSubHeadline(String amount) {
    return '合計 $amount';
  }

  @override
  String get orderInvoiceValueNotAvailable => '未設定';

  @override
  String get orderInvoiceDetailsTitle => '詳細';

  @override
  String get orderInvoiceDetailsNumber => '請求書番号';

  @override
  String get orderInvoiceDetailsIssuedOn => '発行日';

  @override
  String get orderInvoiceDetailsDueDate => '支払期日';

  @override
  String get orderInvoiceDetailsTotal => '請求金額';

  @override
  String get orderInvoiceLineItemsTitle => '内訳';

  @override
  String get orderInvoiceDownloadAction => 'PDFをダウンロード';

  @override
  String get orderInvoiceEmailAction => 'メールで送信';

  @override
  String get orderInvoiceEmailPlaceholder => 'メール配信機能は準備中です。';

  @override
  String get orderInvoicePendingMessage => '請求書を生成しています。数分お待ちください。';

  @override
  String get orderInvoicePendingRefresh => '状態を更新';

  @override
  String get orderInvoiceTaxStatusInclusive => '税込';

  @override
  String get orderInvoiceTaxStatusExclusive => '税抜';

  @override
  String get orderInvoiceTaxStatusExempt => '非課税';

  @override
  String get orderInvoiceStatusDraft => '下書き';

  @override
  String get orderInvoiceStatusIssued => '発行済み';

  @override
  String get orderInvoiceStatusSent => '送信済み';

  @override
  String get orderInvoiceStatusPaid => '支払い済み';

  @override
  String get orderInvoiceStatusVoided => '無効';

  @override
  String get orderInvoicePreviewLabel => 'PDFプレビュー';

  @override
  String get orderInvoicePreviewPending => '請求書PDFを作成しています…';

  @override
  String get orderInvoicePreviewPendingHint => '下に引いて更新するか、時間をおいて再度お試しください。';

  @override
  String get orderInvoicePreviewOpen => 'プレビューを開く';

  @override
  String get orderInvoicePreviewError => 'PDFを開けませんでした。';

  @override
  String orderInvoiceDownloadSuccess(String path) {
    return '$path に保存しました';
  }

  @override
  String get orderInvoiceDownloadError => 'ダウンロードに失敗しました。';

  @override
  String orderInvoiceShareSubject(String invoiceNumber) {
    return '請求書 $invoiceNumber';
  }

  @override
  String orderInvoiceShareBody(String invoiceNumber) {
    return 'Hanko Fieldの請求書 $invoiceNumber を共有します。';
  }

  @override
  String get orderInvoiceShareError => '請求書を共有できませんでした。';

  @override
  String get orderInvoiceErrorTitle => '請求書を表示できません';

  @override
  String get orderDetailsSupportBannerTitle => 'この注文でお困りですか？';

  @override
  String get orderDetailsSupportBannerMessage =>
      '現在、制作に通常より時間がかかっています。優先対応が必要な場合はお知らせください。';

  @override
  String orderDetailsHeadline(String orderNumber) {
    return '注文 $orderNumber';
  }

  @override
  String get orderDetailsProgressTitle => '最新状況';

  @override
  String get orderDetailsSubtotalLabel => '小計';

  @override
  String get orderDetailsDiscountLabel => '割引';

  @override
  String get orderDetailsShippingLabel => '送料';

  @override
  String get orderDetailsFeesLabel => '手数料';

  @override
  String get orderDetailsTaxLabel => '税額';

  @override
  String get orderDetailsTotalLabel => '合計';

  @override
  String orderDetailsQuantityLabel(int quantity) {
    return '数量 $quantity';
  }

  @override
  String orderDetailsSkuLabel(String sku) {
    return 'SKU $sku';
  }

  @override
  String get orderDetailsShippingAddressLabel => '配送先住所';

  @override
  String get orderDetailsBillingAddressLabel => '請求先住所';

  @override
  String get orderDetailsAddressUnavailable => '未設定';

  @override
  String orderDetailsPhoneLabel(String phone) {
    return '電話: $phone';
  }

  @override
  String orderDetailsEmailLabel(String email) {
    return 'メール: $email';
  }

  @override
  String get orderDetailsTimelinePaid => '支払い完了';

  @override
  String get orderDetailsTimelinePending => '処理中';

  @override
  String get orderDetailsUpdatedJustNow => 'たった今';

  @override
  String orderDetailsUpdatedMinutes(int minutes) {
    return '$minutes分前';
  }

  @override
  String orderDetailsUpdatedHours(int hours) {
    return '$hours時間前';
  }

  @override
  String orderDetailsUpdatedOn(String date) {
    return '$date 更新';
  }

  @override
  String get orderDetailsTrackingSectionTitle => '配送トラッキング';

  @override
  String get orderDetailsTrackingCardTitle => '現在の配送状況';

  @override
  String orderDetailsTrackingCardPending(String status) {
    return '出荷が完了すると追跡が有効になります。現在の注文ステータス：$status';
  }

  @override
  String orderDetailsTrackingCardStatus(String status) {
    return '配送ステータス：$status';
  }

  @override
  String orderDetailsTrackingCardLatest(String event, String timestamp) {
    return '最新更新：$event · $timestamp';
  }

  @override
  String orderDetailsTrackingCardLocation(String location) {
    return '配送先：$location';
  }

  @override
  String get orderDetailsTrackingActionLabel => '追跡を見る';

  @override
  String get orderDetailsTrackingCardError => '配送情報を読み込めませんでした。';

  @override
  String orderTrackingAppBarTitle(String orderNumber) {
    return '追跡 · $orderNumber';
  }

  @override
  String get orderTrackingActionViewMap => 'マップで表示';

  @override
  String get orderTrackingLoadError => '配送情報を取得できませんでした。';

  @override
  String get orderTrackingUnavailableTitle => 'まだ追跡情報がありません';

  @override
  String get orderTrackingUnavailableMessage => '配送業者から更新が届き次第ここに表示されます。';

  @override
  String get orderTrackingContactSupport => 'サポートに連絡';

  @override
  String get orderTrackingSupportPending => 'サポート担当がまもなく連絡します。';

  @override
  String orderTrackingTimelineTitle(int count) {
    return '追跡履歴（$count件）';
  }

  @override
  String orderTrackingContactCarrierPending(String carrier) {
    return '$carrier へ接続中です。';
  }

  @override
  String orderTrackingCopied(String trackingId) {
    return '追跡番号 $trackingId をコピーしました。';
  }

  @override
  String orderTrackingMapPlaceholder(String location) {
    return '$location のマップ表示は近日対応予定です。';
  }

  @override
  String get orderTrackingMapPlaceholderGeneric => 'マップ表示は近日対応予定です。';

  @override
  String get orderTrackingShipmentSelectorLabel => '配送を選択';

  @override
  String orderTrackingShipmentSelectorOption(int index, String carrier) {
    return '配送 $index · $carrier';
  }

  @override
  String orderTrackingUpdatedAt(String timestamp) {
    return '更新日時：$timestamp';
  }

  @override
  String orderTrackingLatestLocation(String location) {
    return '最新の場所：$location';
  }

  @override
  String orderTrackingEta(String date) {
    return 'お届け予定日：$date';
  }

  @override
  String orderTrackingTrackingIdLabel(String trackingId) {
    return '追跡番号：$trackingId';
  }

  @override
  String get orderTrackingContactCarrierButton => '配送業者に連絡';

  @override
  String get orderTrackingCopyTrackingIdButton => '追跡番号をコピー';

  @override
  String get orderTrackingNoEventsTitle => '追跡イベントはまだありません';

  @override
  String get orderTrackingNoEventsMessage => '最初の更新が届くまで少しお待ちください。';

  @override
  String orderTrackingOrderSummaryTitle(String orderNumber) {
    return '注文 $orderNumber';
  }

  @override
  String orderTrackingOrderStatus(String status) {
    return '注文ステータス：$status';
  }

  @override
  String get orderTrackingCarrierJapanPost => '日本郵便';

  @override
  String get orderTrackingCarrierYamato => 'ヤマト運輸';

  @override
  String get orderTrackingCarrierSagawa => '佐川急便';

  @override
  String get orderTrackingCarrierDhl => 'DHL';

  @override
  String get orderTrackingCarrierUps => 'UPS';

  @override
  String get orderTrackingCarrierFedex => 'FedEx';

  @override
  String get orderTrackingCarrierOther => 'その他の配送業者';

  @override
  String get orderTrackingStatusLabelCreated => '送り状作成済み';

  @override
  String get orderTrackingStatusInTransit => '輸送中';

  @override
  String get orderTrackingStatusOutForDelivery => '配達中';

  @override
  String get orderTrackingStatusDelivered => '配達済み';

  @override
  String get orderTrackingStatusException => '例外発生';

  @override
  String get orderTrackingStatusCancelled => 'キャンセル';

  @override
  String get orderTrackingEventLabelCreated => '送り状を作成';

  @override
  String get orderTrackingEventPickedUp => '集荷完了';

  @override
  String get orderTrackingEventInTransit => '輸送中';

  @override
  String get orderTrackingEventArrivedHub => '拠点に到着';

  @override
  String get orderTrackingEventCustomsClearance => '通関手続き完了';

  @override
  String get orderTrackingEventOutForDelivery => '配達中';

  @override
  String get orderTrackingEventDelivered => '配達完了';

  @override
  String get orderTrackingEventException => '例外発生';

  @override
  String get orderTrackingEventReturnToSender => '差出人に返送';

  @override
  String get guidesListTitle => 'ガイド & 文化コンテンツ';

  @override
  String get guidesRefreshTooltip => 'ガイドを再読み込み';

  @override
  String get guidesSearchHint => 'ガイド・トピック・タグを検索';

  @override
  String get guidesClearSearchTooltip => '検索をクリア';

  @override
  String get guidesFilterPersonaLabel => 'ペルソナ';

  @override
  String get guidesFilterLocaleLabel => '言語';

  @override
  String get guidesFilterTopicLabel => 'トピック';

  @override
  String get guidesTopicAllLabel => 'すべて';

  @override
  String guidesLastUpdatedLabel(String timestamp) {
    return '最終同期 $timestamp';
  }

  @override
  String get guidesCachedBadge => 'オフライン';

  @override
  String guidesRecommendedTitle(String persona) {
    return 'おすすめ ($persona)';
  }

  @override
  String get guidesRecommendedChip => 'おすすめ';

  @override
  String get guidesEmptyTitle => '表示できるガイドがありません';

  @override
  String get guidesEmptyMessage => '検索条件またはフィルターを調整してください。';

  @override
  String get guidesClearFiltersButton => 'フィルターをリセット';

  @override
  String get guidesLoadErrorTitle => 'ガイドを読み込めませんでした';

  @override
  String get guidesLoadError => '通信状況を確認して、もう一度お試しください。';

  @override
  String get guidesRetryButtonLabel => '再試行';

  @override
  String guidesReadingTimeLabel(int minutes) {
    return '$minutes 分で読めます';
  }

  @override
  String get guidesReadButton => 'ガイドを開く';

  @override
  String get guidesPersonaJapaneseLabel => '国内向け';

  @override
  String get guidesPersonaInternationalLabel => '海外向け';

  @override
  String get guidesLocaleJapaneseLabel => '日本語';

  @override
  String get guidesLocaleEnglishLabel => '英語';

  @override
  String get guidesCategoryCulture => '文化';

  @override
  String get guidesCategoryHowTo => 'ハウツー';

  @override
  String get guidesCategoryPolicy => '制度';

  @override
  String get guidesCategoryFaq => 'FAQ';

  @override
  String get guidesCategoryNews => 'アップデート';

  @override
  String get guidesCategoryOther => 'その他';

  @override
  String get howToScreenTitle => 'ハウツーハブ';

  @override
  String get howToScreenSubtitle => '動画と記事の使い方ガイドをまとめて確認できます。';

  @override
  String get howToRefreshTooltip => '最新のチュートリアルを読み込む';

  @override
  String get howToVideosTabLabel => '動画';

  @override
  String get howToGuidesTabLabel => '記事';

  @override
  String howToCompletionLabel(int completed, int total) {
    return '$total 件中 $completed 件完了';
  }

  @override
  String get howToFeaturedLabel => '注目';

  @override
  String get howToCompletedLabel => '完了済み';

  @override
  String get howToGuidesEmptyTitle => '公開中のハウツー記事はありません';

  @override
  String get howToGuidesEmptyMessage => 'まもなく新しいチュートリアルが追加されます。';

  @override
  String get howToLoadErrorTitle => '使い方コンテンツを読み込めませんでした';

  @override
  String get howToLoadErrorMessage => '通信状況を確認してもう一度お試しください。';

  @override
  String get howToRetryButtonLabel => '再試行';

  @override
  String get howToStepsLabel => '手順';

  @override
  String get howToMarkComplete => '完了にする';

  @override
  String get howToOpenGuideLabel => 'ガイドを開く';

  @override
  String get howToEntryCtaLabel => 'ハウツーハブを開く';

  @override
  String get howToDifficultyBeginner => '初級';

  @override
  String get howToDifficultyIntermediate => '中級';

  @override
  String get howToDifficultyAdvanced => '上級';

  @override
  String get howToMuteTooltip => 'ミュート';

  @override
  String get howToUnmuteTooltip => 'ミュート解除';

  @override
  String get howToShowCaptionsTooltip => '字幕を表示';

  @override
  String get howToHideCaptionsTooltip => '字幕を非表示';

  @override
  String get howToPauseTooltip => '一時停止';

  @override
  String get howToPlayTooltip => '再生';

  @override
  String get guideDetailShareButtonLabel => '共有';

  @override
  String get guideDetailOpenInBrowser => 'ブラウザで開く';

  @override
  String guideDetailCachedBanner(String timestamp) {
    return 'オフラインコピー（$timestamp 保存）';
  }

  @override
  String guideDetailUpdatedLabel(String timestamp) {
    return '更新日 $timestamp';
  }

  @override
  String get guideDetailSourcesLabel => '出典';

  @override
  String get guideDetailRelatedTitle => '関連記事';

  @override
  String get guideDetailErrorTitle => 'ガイドを表示できません';

  @override
  String get guideDetailErrorMessage => 'ガイドを読み込めませんでした。通信状況を確認して再度お試しください。';

  @override
  String get guideDetailBookmarkTooltipSave => 'あとで読む';

  @override
  String get guideDetailBookmarkTooltipRemove => '保存を解除';

  @override
  String get guideDetailBookmarkSavedMessage => 'オフライン用に保存しました。';

  @override
  String get guideDetailBookmarkRemovedMessage => '保存済みガイドから削除しました。';

  @override
  String guideDetailShareMessage(String title, String url) {
    return '\"$title\"（Hanko Field）をチェック: $url';
  }

  @override
  String get guideDetailLinkOpenError => 'リンクを開けませんでした。時間をおいて再度お試しください。';

  @override
  String get kanjiDictionarySearchHint => '意味・読み・部首で検索';

  @override
  String get kanjiDictionaryClearSearch => '検索をクリア';

  @override
  String get kanjiDictionaryRefresh => '最新の情報に更新';

  @override
  String get kanjiDictionaryShowAllTooltip => 'すべての結果を表示';

  @override
  String get kanjiDictionaryShowFavoritesTooltip => 'ブックマークのみ表示';

  @override
  String get kanjiDictionaryHistorySection => '最近の検索';

  @override
  String get kanjiDictionaryRecentlyViewed => '最近チェックした漢字';

  @override
  String get kanjiDictionaryFiltersTitle => '条件で絞り込む';

  @override
  String get kanjiDictionaryGradeFilterLabel => '学年';

  @override
  String get kanjiDictionaryStrokeFilterLabel => '画数';

  @override
  String get kanjiDictionaryRadicalFilterLabel => '部首';

  @override
  String get kanjiDictionaryFeaturedTitle => 'おすすめの漢字';

  @override
  String get kanjiDictionaryEmptyFavoritesTitle => 'ブックマークがまだありません';

  @override
  String get kanjiDictionaryEmptyFavoritesMessage =>
      '気に入った漢字にブックマークすると、ここからすぐ参照できます。';

  @override
  String get kanjiDictionaryEmptyResultsTitle => '一致する漢字が見つかりません';

  @override
  String get kanjiDictionaryEmptyResultsMessage =>
      'キーワードやフィルター条件を変えて再度お試しください。';

  @override
  String get kanjiDictionaryViewDetails => '詳細を見る';

  @override
  String kanjiDictionaryStrokeCount(int count) {
    return '$count画';
  }

  @override
  String get kanjiDictionaryUsageExamples => '用例';

  @override
  String get kanjiDictionaryStrokeOrder => '書き順のポイント';

  @override
  String get kanjiDictionaryInsertAction => 'デザインに挿入';

  @override
  String get kanjiDictionaryInsertDisabled => 'デザイン作成を開始すると挿入できます';

  @override
  String get kanjiDictionaryPromoTitle => '漢字辞典';

  @override
  String get kanjiDictionaryPromoDescription =>
      '意味やストーリーを調べて、印影デザインのヒントにしましょう。';

  @override
  String get kanjiDictionaryPromoCta => '漢字辞典を開く';

  @override
  String get profileHomeLoadError => 'プロフィール情報を読み込めませんでした。';

  @override
  String get profileHomeRetryLabel => '再試行';

  @override
  String get profileHomeQuickLinksTitle => 'クイックリンク';

  @override
  String get profileHomeQuickLinkLocaleTitle => '言語と通貨';

  @override
  String get profileHomeQuickLinkLocaleSubtitle => 'アプリの表示言語と通貨を調整';

  @override
  String get profileHomeQuickLinkAddressesTitle => '住所帳';

  @override
  String get profileHomeQuickLinkAddressesSubtitle => '配送先と請求先';

  @override
  String get profileHomeQuickLinkPaymentsTitle => '支払方法';

  @override
  String get profileHomeQuickLinkPaymentsSubtitle => 'カード / ウォレット / 請求書';

  @override
  String get profileHomeQuickLinkNotificationsTitle => '通知設定';

  @override
  String get profileHomeQuickLinkNotificationsSubtitle => 'プッシュ・メール・SMS';

  @override
  String get profileHomeQuickLinkSupportTitle => 'サポート';

  @override
  String get profileHomeQuickLinkSupportSubtitle => 'FAQ / チャット / お問い合わせ';

  @override
  String get profileHomeQuickLinkLegalTitle => '法務ドキュメント';

  @override
  String get profileHomeQuickLinkLegalSubtitle => '利用規約・プライバシー・特商法';

  @override
  String get profileLocaleTitle => '言語と通貨';

  @override
  String profileLocaleLoadError(String details) {
    return '言語・通貨の設定を読み込めませんでした。\n$details';
  }

  @override
  String get profileLocaleHelpTooltip => 'オーバーライドの仕組み';

  @override
  String get profileLocaleHelpTitle => '言語と通貨のオーバーライド';

  @override
  String get profileLocaleHelpBody =>
      '表示言語を切り替えると UI テキストやガイドの内容が個別化されます。通貨オーバーライドは価格やオファーの表示方法のみを変更し、この端末に保存されます。';

  @override
  String get profileLocaleHelpClose => '閉じる';

  @override
  String get profileLocaleLanguageSectionTitle => 'アプリの表示言語';

  @override
  String get profileLocaleLanguageSectionSubtitle =>
      'UI テキストやガイド、推奨フローを切り替えます。';

  @override
  String get profileLocaleCurrencySectionTitle => '通貨設定';

  @override
  String get profileLocaleCurrencySectionSubtitle =>
      '価格やチェックアウト金額の表示通貨を上書きします。';

  @override
  String get profileLocaleCurrencyJpyLabel => 'JPY・日本円';

  @override
  String get profileLocaleCurrencyUsdLabel => 'USD・米ドル';

  @override
  String profileLocaleCurrencyRecommendation(String locale, String currency) {
    return '$localeにおすすめ: $currency';
  }

  @override
  String get profileLocaleUseSystemButton => '端末の言語を使う';

  @override
  String get profileLocaleApplyButton => '変更を適用';

  @override
  String get profileLocaleApplySuccess => '言語と通貨の設定を更新しました。';

  @override
  String get profileLocaleApplyError => '設定を更新できませんでした。もう一度お試しください。';

  @override
  String get profileLegalTitle => '法務ドキュメント';

  @override
  String get profileLegalDownloadTooltip => '最新情報を取得してオフラインに保存';

  @override
  String get profileLegalLoadError => '法務ドキュメントを読み込めませんでした。';

  @override
  String get profileLegalRetryLabel => '再試行';

  @override
  String profileLegalSyncedLabel(String timestamp) {
    return '最終同期 $timestamp';
  }

  @override
  String profileLegalOfflineBanner(String timestamp) {
    return '$timestamp 時点のオフラインコピーを表示しています';
  }

  @override
  String get profileLegalDocumentsSectionTitle => 'ドキュメント一覧';

  @override
  String get profileLegalNoDocumentsLabel => '表示できる法務ドキュメントがありません。';

  @override
  String profileLegalUpdatedLabel(String timestamp) {
    return '$timestamp 更新';
  }

  @override
  String profileLegalVersionChip(String version) {
    return 'バージョン $version';
  }

  @override
  String get profileLegalViewerEmptyState => 'プレビューするドキュメントを選択してください。';

  @override
  String get profileLegalOpenInBrowser => 'ブラウザで開く';

  @override
  String get profileLegalOpenInBrowserUnavailable => 'ブラウザリンクはありません';

  @override
  String get profileLegalOpenExternalError => 'リンクを開けませんでした。後でもう一度お試しください。';

  @override
  String get profileNotificationsTitle => '通知設定';

  @override
  String get profileNotificationsDescription =>
      'カテゴリごとのプッシュ/メール通知と配信タイミングを管理します。';

  @override
  String get profileNotificationsCategoriesTitle => 'チャネル';

  @override
  String get profileNotificationsCategoriesSubtitle =>
      'カテゴリごとにプッシュ通知とメール通知を切り替えます。';

  @override
  String get profileNotificationsChannelPush => 'プッシュ';

  @override
  String get profileNotificationsChannelEmail => 'メール';

  @override
  String get profileNotificationsCategoryOrder => '注文';

  @override
  String get profileNotificationsCategoryOrderDescription =>
      'ステータス変更・発送通知・エクスポート完了など。';

  @override
  String get profileNotificationsCategoryProduction => '制作';

  @override
  String get profileNotificationsCategoryProductionDescription =>
      '工房での進捗、承認依頼、修正リクエスト。';

  @override
  String get profileNotificationsCategoryPromotion => 'キャンペーン';

  @override
  String get profileNotificationsCategoryPromotionDescription =>
      'キャンペーン、クーポン、カートのリマインダー。';

  @override
  String get profileNotificationsCategoryGuide => 'ガイド・学習';

  @override
  String get profileNotificationsCategoryGuideDescription =>
      'チュートリアル、漢字ストーリー、ハウツー記事。';

  @override
  String get profileNotificationsCategorySystem => 'システム通知';

  @override
  String get profileNotificationsCategorySystemDescription =>
      'アプリ状況、セキュリティ通知、連携アカウントの警告。';

  @override
  String get profileNotificationsDigestTitle => 'ダイジェスト・配信スケジュール';

  @override
  String get profileNotificationsDigestSubtitle =>
      '個別通知の代わりに、まとめて受け取る時間を決められます。';

  @override
  String get profileNotificationsFrequencyDaily => '毎日';

  @override
  String get profileNotificationsFrequencyWeekly => '毎週';

  @override
  String get profileNotificationsFrequencyMonthly => '毎月';

  @override
  String get profileNotificationsDigestTimeLabel => '配信時間';

  @override
  String get profileNotificationsDigestWeekdayLabel => '配信曜日';

  @override
  String get profileNotificationsDigestMonthdayLabel => '配信日';

  @override
  String get profileNotificationsQuietHoursTitle => 'サイレント時間';

  @override
  String get profileNotificationsQuietHoursSubtitle =>
      '夜間のプッシュ通知を一時停止し、朝に再開します。';

  @override
  String get profileNotificationsQuietHoursStartLabel => '開始';

  @override
  String get profileNotificationsQuietHoursEndLabel => '終了';

  @override
  String get profileNotificationsSaveButton => '設定を保存';

  @override
  String get profileNotificationsSaveSuccess => '通知設定を保存しました。';

  @override
  String get profileNotificationsSaveError => '通知設定を保存できませんでした。';

  @override
  String profileNotificationsLastSaved(String time) {
    return '最終保存 $time';
  }

  @override
  String get profileNotificationsReset => 'リセット';

  @override
  String get profileAddressesTitle => '住所帳';

  @override
  String get profileAddressesAddTooltip => '住所を追加';

  @override
  String get profileAddressesDeleteConfirmTitle => '住所を削除しますか？';

  @override
  String profileAddressesDeleteConfirmBody(String name) {
    return '$name の住所を削除しますか？';
  }

  @override
  String get profileAddressesDeleteConfirmAction => '削除';

  @override
  String get profileAddressesDeleteConfirmCancel => 'キャンセル';

  @override
  String get profileAddressesLoadError => '住所帳を読み込めません。';

  @override
  String get profileAddressesRetryLabel => '再試行';

  @override
  String get profileAddressesEmptyTitle => '住所が登録されていません';

  @override
  String get profileAddressesEmptyBody => '配送先・請求先の住所を登録すると注文時に再利用できます。';

  @override
  String get profileAddressesEmptyAction => '住所を追加';

  @override
  String get profileAddressesSyncTitle => '配送同期';

  @override
  String get profileAddressesSyncNever => 'まだ同期していません。最新の配送データを取得してください。';

  @override
  String profileAddressesSyncStatus(String timestamp) {
    return '最終同期 $timestamp';
  }

  @override
  String get profileAddressesSyncAction => '今すぐ同期';

  @override
  String profileAddressesPhoneLabel(String value) {
    return '電話番号: $value';
  }

  @override
  String get profileAddressesDefaultLabel => '既定';

  @override
  String get profileAddressesSetDefaultTooltip => '既定に設定';

  @override
  String get profileAddressesEditTooltip => '編集';

  @override
  String get profileAddressesDeleteTooltip => '削除';

  @override
  String get profileHomeAvatarButtonTooltip => 'プロフィール写真を変更';

  @override
  String get profileHomeFallbackDisplayName => 'ゲスト';

  @override
  String get profileHomeHeaderDescription => '本人情報・セキュリティ・通知などの設定をここから管理できます。';

  @override
  String get profileHomeAvatarUpdateMessage => '写真アップロードはまもなく対応予定です。';

  @override
  String get profileHomeMembershipActive => 'アクティブ会員';

  @override
  String get profileHomeMembershipSuspended => '利用一時停止';

  @override
  String get profileHomeMembershipStaff => 'チームアカウント';

  @override
  String get profileHomeMembershipAdmin => '管理者アカウント';

  @override
  String get profileHomePersonaTitle => 'ペルソナモード';

  @override
  String get profileHomePersonaSubtitle =>
      '国内向け/海外向けの案内を切り替えて、文言やチェックリストを最適化します。';

  @override
  String get profileHomePersonaDomestic => '国内向け';

  @override
  String get profileHomePersonaInternational => '海外向け';

  @override
  String get profileHomePersonaUpdateError => 'ペルソナを更新できませんでした。もう一度お試しください。';

  @override
  String get profileLinkedAccountsTitle => '連携アカウント';

  @override
  String get profileLinkedAccountsAddTooltip => 'アカウントを追加';

  @override
  String get profileLinkedAccountsLoadError => '連携アカウントを読み込めませんでした。';

  @override
  String get profileLinkedAccountsRetryLabel => '再試行';

  @override
  String get profileLinkedAccountsSecurityTitle => 'サインインを安全に保つ';

  @override
  String get profileLinkedAccountsSecurityBody =>
      'パスワードを使い回さず、可能であればパスキーを有効にしましょう。';

  @override
  String get profileLinkedAccountsSecurityAction => 'セキュリティガイド';

  @override
  String get profileLinkedAccountsProviderApple => 'Apple';

  @override
  String get profileLinkedAccountsProviderGoogle => 'Google';

  @override
  String get profileLinkedAccountsProviderEmail => 'メール/パスワード';

  @override
  String get profileLinkedAccountsProviderLine => 'LINE';

  @override
  String get profileLinkedAccountsStatusActive => '連携済み';

  @override
  String get profileLinkedAccountsStatusPending => '確認待ち';

  @override
  String get profileLinkedAccountsStatusRevoked => '解除済み';

  @override
  String get profileLinkedAccountsStatusActionRequired => '要対応';

  @override
  String profileLinkedAccountsLinkedAt(String timestamp) {
    return '連携日: $timestamp';
  }

  @override
  String profileLinkedAccountsLastUsed(String timestamp) {
    return '最終利用: $timestamp';
  }

  @override
  String get profileLinkedAccountsAutoSignInLabel => '自動サインイン';

  @override
  String get profileLinkedAccountsAutoSignInDescription =>
      '信頼できる端末ではログイン画面をスキップします。';

  @override
  String get profileLinkedAccountsPendingChangesLabel => '未保存の変更';

  @override
  String get profileLinkedAccountsUnlinkAction => '連携解除';

  @override
  String get profileLinkedAccountsSaveAction => '保存';

  @override
  String get profileLinkedAccountsSaveSuccess => '自動サインイン設定を保存しました。';

  @override
  String get profileLinkedAccountsSaveError => '変更を保存できませんでした。';

  @override
  String get profileLinkedAccountsUnlinkConfirmTitle => 'このアカウントの連携を解除しますか？';

  @override
  String profileLinkedAccountsUnlinkConfirmBody(String provider) {
    return '解除すると、$providerで再度サインインする必要があります。';
  }

  @override
  String get profileLinkedAccountsUnlinkConfirmAction => '連携解除';

  @override
  String get profileLinkedAccountsUnlinkCancel => 'キャンセル';

  @override
  String profileLinkedAccountsUnlinkSuccess(String provider) {
    return '$providerの連携を解除しました。';
  }

  @override
  String get profileLinkedAccountsUnlinkError => '連携を解除できませんでした。';

  @override
  String get profileLinkedAccountsEmptyTitle => 'まだ連携されていません';

  @override
  String get profileLinkedAccountsEmptyBody =>
      'AppleやGoogle、LINEなどのサインイン方法を追加して、安全にアクセスできます。';

  @override
  String get profileLinkedAccountsEmptyAction => '連携を追加';

  @override
  String profileLinkedAccountsLinkSuccess(String provider) {
    return '$providerを追加しました。';
  }

  @override
  String get profileLinkedAccountsLinkError => '連携を開始できませんでした。もう一度お試しください。';

  @override
  String get profileLinkedAccountsAddSheetTitle => '連携するサービスを選択';

  @override
  String get profileLinkedAccountsAddSheetSubtitle => '普段使っているアカウントを追加しましょう。';

  @override
  String get profilePaymentsTitle => 'お支払い方法';

  @override
  String get profilePaymentsAddTooltip => '支払い方法を追加';

  @override
  String get profilePaymentsLimitReachedInternational =>
      '登録できるお支払い方法の上限に達しています。';

  @override
  String get profilePaymentsLimitReachedDomestic => 'これ以上お支払い方法を追加できません。';

  @override
  String get profilePaymentsAddDialogTitle => 'お支払い方法を追加';

  @override
  String get profilePaymentsAddDialogClose => '閉じる';

  @override
  String get profilePaymentsDeleteConfirmTitle => 'お支払い方法を削除しますか？';

  @override
  String profilePaymentsDeleteConfirmBody(String brand, String last4) {
    return '$brand（下4桁 $last4）を削除しますか？';
  }

  @override
  String get profilePaymentsDeleteUnknownBrand => 'この方法';

  @override
  String get profilePaymentsDeleteConfirmAction => '削除';

  @override
  String get profilePaymentsDeleteConfirmCancel => 'キャンセル';

  @override
  String get profilePaymentsDefaultBadge => 'デフォルト';

  @override
  String get profilePaymentsDeleteTooltip => 'この方法を削除';

  @override
  String profilePaymentsTokenLabel(String token) {
    return 'PSPトークン: $token';
  }

  @override
  String get profilePaymentsTokenUnavailable => 'トークン情報が見つかりません';

  @override
  String get profilePaymentsTokenLoading => 'PSPトークンを取得しています…';

  @override
  String get profilePaymentsTokenError => 'PSPトークンを読み取れませんでした。';

  @override
  String get profilePaymentsSecurityTitleIntl => 'カード情報は暗号化されています';

  @override
  String get profilePaymentsSecurityTitleDomestic => 'カード保管のコンプライアンス';

  @override
  String get profilePaymentsSecurityBodyIntl =>
      'PSPトークンのみを保存し、カード番号は保持しません。資格情報の更新とアクセス監査を定期的に実施してください。';

  @override
  String get profilePaymentsSecurityBodyDomestic =>
      '国内PSPでトークン化し、すべての変更を記録しています。財務チームと定期的にレビューしましょう。';

  @override
  String get profilePaymentsSecurityChipTokens => 'PSPトークン';

  @override
  String get profilePaymentsSecurityChipFaq => 'セキュリティFAQ';

  @override
  String get profilePaymentsSecurityChipSupport => 'サポートに連絡';

  @override
  String profilePaymentsSecurityLinkComingSoon(String destination) {
    return 'セキュリティリンク（$destination）はまもなく公開予定です。';
  }

  @override
  String get profilePaymentsEmptyTitle => '保存済みのお支払い方法がありません';

  @override
  String get profilePaymentsEmptyMessage =>
      'カードやウォレット、請求プロファイルを登録するとチェックアウトがスムーズになります。';

  @override
  String get profilePaymentsEmptyCta => 'お支払い方法を追加';

  @override
  String profilePaymentsErrorMessage(String message) {
    return 'お支払い方法を読み込めません（$message）';
  }

  @override
  String get profilePaymentsErrorRetry => '再試行';

  @override
  String get profileSupportTitle => 'サポート';

  @override
  String get profileSupportSearchTooltip => 'サポートを検索';

  @override
  String get profileSupportHelpCenterTitle => 'お困りですか？';

  @override
  String get profileSupportHelpCenterSubtitle => 'FAQ やチャット、コンシェルジュへの連絡はこちら';

  @override
  String profileSupportUpdatedLabel(String timestamp) {
    return '最終更新 $timestamp';
  }

  @override
  String get profileSupportLoadError => 'サポート情報を読み込めませんでした。';

  @override
  String get profileSupportRetryLabel => '再試行';

  @override
  String get profileSupportQuickFaqTitle => 'FAQ・ガイド';

  @override
  String get profileSupportQuickFaqSubtitle => '利用規約 / 配送 / カスタム';

  @override
  String get profileSupportQuickChatTitle => 'ライブチャット';

  @override
  String get profileSupportQuickChatSubtitle => '平均返信 2 分';

  @override
  String get profileSupportQuickCallTitle => 'コンシェルジュ通話';

  @override
  String get profileSupportQuickCallSubtitle => 'フォーム送信や折り返し依頼';

  @override
  String get profileSupportRecentTicketsTitle => '最近のチケット';

  @override
  String get profileSupportRecentTicketsSubtitle => '進行中のサポートの状況を確認できます。';

  @override
  String get profileSupportEmptyTicketsTitle => 'チケットはまだありません';

  @override
  String get profileSupportEmptyTicketsSubtitle => 'カスタム相談があればチケットを作成してください。';

  @override
  String get profileSupportCreateTicketLabel => 'チケットを作成';

  @override
  String get profileSupportCreateTicketSuccess => 'チケットを作成しました。まもなくご連絡します。';

  @override
  String get profileSupportCreateTicketError => 'チケットを作成できませんでした。もう一度お試しください。';

  @override
  String get profileSupportTicketQuickSubject => 'コンシェルジュ相談';

  @override
  String profileSupportTicketSubtitle(String timestamp, String reference) {
    return '更新 $timestamp ・ $reference';
  }

  @override
  String get profileSupportStatusOpen => '対応中';

  @override
  String get profileSupportStatusWaiting => 'お客様からの返信待ち';

  @override
  String get profileSupportStatusResolved => '解決済み';

  @override
  String get profileSupportActionError => 'リンクを開けませんでした。もう一度お試しください。';

  @override
  String get profileSupportSearchPlaceholder => 'FAQ やチケットを検索';

  @override
  String get profileSupportSearchEmpty => '該当する結果がありません';

  @override
  String get profileSupportTicketDetailBody =>
      'チャットとメールで更新をお送りします。追記は会話に返信してください。';

  @override
  String get profileSupportTicketDetailAction => '会話を開く';

  @override
  String profileSupportTicketDetailFollowup(String reference) {
    return '$reference の更新をお送りします。';
  }

  @override
  String get profileHomeQuickLinkExportTitle => 'データエクスポート';

  @override
  String get profileHomeQuickLinkExportSubtitle => '個人データをダウンロード';

  @override
  String get profileExportTitle => 'データエクスポート';

  @override
  String get profileExportLoadError => 'データエクスポート情報を読み込めません。';

  @override
  String get profileExportRetryLabel => '再試行';

  @override
  String get profileExportRequestStarted =>
      'エクスポートの作成を開始しました。準備ができたらメールでお知らせします。';

  @override
  String get profileExportRequestError => 'エクスポートを開始できませんでした。もう一度お試しください。';

  @override
  String profileExportDownloadStarted(String host) {
    return '$host 経由の安全なダウンロードを開始しました。';
  }

  @override
  String get profileExportDownloadError => 'ダウンロードリンクを準備できませんでした。もう一度お試しください。';

  @override
  String get profileExportSummaryTitle => 'データコピーをダウンロード';

  @override
  String get profileExportSummaryDescription =>
      '個人情報・デザイン資産・注文履歴・アクティビティ履歴を暗号化されたアーカイブでまとめて取得します。';

  @override
  String profileExportEstimatedDuration(int minutes) {
    return '平均 $minutes 分で完了します';
  }

  @override
  String get profileExportSecurityNote =>
      'アーカイブは保存時にも暗号化され、ダウンロード時に署名されます。リンクは自動で失効します。';

  @override
  String get profileExportSupportNote => 'GDPR 等の依頼はヘルプ&サポートからお問い合わせください。';

  @override
  String get profileExportStatusNever => '未実行';

  @override
  String get profileExportStatusPreparing => '処理中';

  @override
  String get profileExportStatusReady => '準備完了';

  @override
  String get profileExportStatusExpired => '期限切れ';

  @override
  String get profileExportStatusFailed => '失敗';

  @override
  String get profileExportLatestEmptyTitle => 'エクスポートはまだありません';

  @override
  String get profileExportLatestEmptySubtitle => '含めたいデータを選んでエクスポートを作成してください。';

  @override
  String get profileExportLatestArchiveTitle => '最新のアーカイブ';

  @override
  String profileExportLastRequestedLabel(String timestamp) {
    return 'リクエスト日時: $timestamp';
  }

  @override
  String profileExportArchiveSizeLabel(String size) {
    return 'サイズ $size';
  }

  @override
  String profileExportArchiveExpiresLabel(String timestamp) {
    return '有効期限 $timestamp';
  }

  @override
  String get profileExportDownloadInProgress => '準備中...';

  @override
  String get profileExportDownloadLatest => 'アーカイブをダウンロード';

  @override
  String get profileExportIncludeAssetsTitle => 'クリエイティブ資産';

  @override
  String get profileExportIncludeAssetsSubtitle => 'デザイン書き出し、印影データ、AIプロンプト、SVG';

  @override
  String get profileExportIncludeOrdersTitle => '注文・請求';

  @override
  String get profileExportIncludeOrdersSubtitle => '購入履歴、請求書、配送情報、メモ';

  @override
  String get profileExportIncludeHistoryTitle => '活動履歴';

  @override
  String get profileExportIncludeHistorySubtitle => 'サインイン、ペルソナ変更、連携アプリ、承認履歴';

  @override
  String get profileExportGenerateButton => 'エクスポートを作成';

  @override
  String get profileExportGeneratingLabel => '生成中...';

  @override
  String get profileExportNoSelectionWarning => '少なくとも1つは選択してください。';

  @override
  String get profileExportViewHistory => '過去のエクスポートを見る';

  @override
  String get profileExportHistoryTitle => '過去のアーカイブ';

  @override
  String get profileExportHistoryEmpty => '過去のアーカイブはありません。';

  @override
  String profileExportHistoryRequested(String timestamp) {
    return 'リクエスト日時: $timestamp';
  }

  @override
  String get profileExportHistoryDownload => 'ダウンロード';

  @override
  String get profileExportBundleAssets => '資産';

  @override
  String get profileExportBundleOrders => '注文';

  @override
  String get profileExportBundleHistory => '履歴';
}
