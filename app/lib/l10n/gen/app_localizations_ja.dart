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
}
