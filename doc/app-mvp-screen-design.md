# Stone Signature App MVP 画面設計

## 目的

Stone Signature のアプリ版は、ユーザーが自分の名前から漢字候補を選び、AI印影候補を生成し、保存・比較し、販売中の宝石材と組み合わせて注文できるネイティブアプリとして設計する。

購入前でも「印影を作る」「端末内に保存する」「複数案を比較する」体験を成立させ、注文はその延長に置く。

## MVP 前提

- アカウント登録はしない。
- ログイン画面は作らない。
- Firebase Auth は使わない。
- MVPでは Gen UI は使わない。印影条件の選択は固定のFlutter UIで実装する。
- 保存済み印影案は端末内ローカル保存のみとする。
- アプリ削除、別端末、機種変更では保存済み印影案は引き継がれない。
- 注文時だけ、メールアドレス、氏名、配送先、電話番号を入力する。
- 決済は Stripe Checkout に遷移する。
- 注文確定はアプリの戻りURLではなく、Stripe Webhook の反映結果を正とする。
- AIは漢字候補生成と印影候補生成に使うが、注文、在庫、価格、決済判断には使わない。
- 印影に使う漢字は1から2文字までとし、難字、旧字体、細線、過度な装飾、読めない字形は避ける。
- 既存のFirestoreコレクション構成は維持する。ただし、app注文でadmin確認が必要なAI印影画像、AI Variant ID、選択スタイル詳細、顧客確認チェック記録は `orders.seal.*` と `orders.customer_confirmation.*` に追加保存する。
- 管理画面は既存adminを使い、新しい別管理画面は作らない。
- 下部タブは `Design` / `My Seals` / `Stones` の3つにする。

## 画面コード体系

画面コードは、実装・テスト・設計レビューで同じ画面を参照するための固定IDとする。

| Prefix | 領域 |
| --- | --- |
| `COM` | 初回・共通系 |
| `DES` | Designタブ系 |
| `MYS` | My Sealsタブ系 |
| `STN` | Stonesタブ系 |
| `CMB` | 印影 + 宝石材 組み合わせ系 |
| `CHK` | Checkout / Stripe Checkout系 |
| `LKP` | Order Lookup系 |
| `NTC` | 通知・メール案内系 |
| `ERR` | エラー・共通状態画面 |

状態表示として実装してよいものも、仕様上は画面コードを付与する。Flutter実装では同一Screen内の `loading` / `empty` / `error` / `success` state としてまとめてよい。

### 固定IDの運用ルール

画面コードは、Flutter実装、Widget test、スクリーンショット、レビュー資料で同じ対象を指す正本IDとして扱う。

- FlutterのScreen/Shell/State名は、この文書の画面構造に記載した実装名を使う。
- `declarative_nav` の `PageEntry.key`、ログ、analytics/debug label、保存済みスクリーンショット名には、対象の画面コードを先頭に含める。
- Widget testの `testWidgets` 名は、対象画面コードから始める。例: `COM-003 bottom navigation shell switches tabs`。
- スクリーンショットは `doc/screens/{CODE}.png`、HTML確認用モックは `doc/screens/html/{CODE}.html` を正規ファイル名にする。
- State / Section / Bottom Sheet として実装する画面コードも、親Screenのテスト内で該当コードを明示して検証する。
- 同じ画面コードを別の意味で再利用しない。画面統合を行う場合も、この文書にあるコードと状態名の対応は残す。

## 画面構造

```text
AppRoot
├─ COM-001 SplashScreen
├─ COM-002 OnboardingScreen
├─ COM-003 BottomNavigationShell
│  ├─ DesignTab
│  │  ├─ DES-001 DesignStartScreen
│  │  ├─ DES-002 NameInputScreen
│  │  ├─ DES-003 KanjiSuggestionLoadingScreen
│  │  ├─ DES-004 KanjiSuggestionsScreen
│  │  ├─ DES-005 KanjiCandidateDetailScreen
│  │  ├─ DES-006 SealStyleSelectionScreen
│  │  ├─ DES-007 AISealGenerationLoadingScreen
│  │  ├─ DES-008 SealVariantSelectionScreen
│  │  ├─ DES-009 SealPreviewDetailScreen
│  │  └─ DES-010 SaveSealConfirmationScreen
│  │
│  ├─ MySealsTab
│  │  ├─ MYS-001 MySealsListScreen
│  │  ├─ MYS-002 MySealsEmptyScreen
│  │  ├─ MYS-003 SealDetailScreen
│  │  ├─ MYS-004 EditSavedSealScreen
│  │  ├─ MYS-005 SealCompareSelectionScreen
│  │  ├─ MYS-006 SealComparisonScreen
│  │  ├─ MYS-007 DeleteSealConfirmationScreen
│  │  └─ MYS-008 ChooseSealForOrderState
│  │
│  └─ StonesTab
│     ├─ STN-001 StonesListScreen
│     ├─ STN-002 StonesEmptyScreen
│     ├─ STN-003 StonesLoadingScreen
│     ├─ STN-004 StonesErrorScreen
│     ├─ STN-005 StoneFilterSheet
│     ├─ STN-006 StoneSortSheet
│     ├─ STN-007 StoneDetailScreen
│     ├─ STN-008 StoneImageGalleryScreen
│     ├─ STN-009 SelectStoneConfirmationState
│     └─ STN-010 SoldOutStoneState
│
├─ OrderStack
│  ├─ CMB-001 SealStoneConfirmationScreen
│  ├─ CMB-002 MissingSealState
│  ├─ CMB-003 MissingStoneState
│  ├─ CMB-004 ChangeSealScreen
│  ├─ CMB-005 ChangeStoneScreen
│  ├─ CHK-001 CheckoutInformationScreen
│  ├─ CHK-002 ShippingAddressFormSection
│  ├─ CHK-003 ContactInformationFormSection
│  ├─ CHK-004 OrderNoteSection
│  ├─ CHK-005 CheckoutValidationErrorState
│  ├─ CHK-006 OrderConfirmationScreen
│  ├─ CHK-007 CustomMadeAgreementSection
│  ├─ CHK-008 CreatingCheckoutSessionScreen
│  ├─ CHK-009 StripeCheckoutTransitionScreen
│  ├─ CHK-010 StripeCheckoutExternal
│  ├─ CHK-011 PaymentSuccessHandlingScreen
│  ├─ CHK-012 PaymentCancelledScreen
│  ├─ CHK-013 PaymentFailedScreen
│  ├─ CHK-014 PaymentPendingScreen
│  └─ CHK-015 OrderCompleteScreen
│
├─ OrderLookupStack
│  ├─ LKP-001 OrderLookupInputScreen
│  ├─ LKP-002 OrderLookupLoadingScreen
│  ├─ LKP-003 OrderLookupResultScreen
│  ├─ LKP-004 OrderLookupNotFoundScreen
│  ├─ LKP-005 OrderLookupErrorScreen
│  └─ LKP-006 TrackingDetailScreen
│
├─ SettingsStack
│  ├─ COM-004 SettingsScreen
│  ├─ COM-005 AboutScreen
│  ├─ COM-006 HowItWorksScreen
│  ├─ COM-007 FAQScreen
│  ├─ COM-008 ContactScreen
│  ├─ COM-009 PrivacyPolicyScreen
│  └─ COM-010 TermsOfServiceScreen
│
└─ CommonStateScreens
   ├─ NTC-001 EmailSentNotice
   ├─ NTC-002 OrderConfirmationEmailGuide
   ├─ NTC-003 ContactSupportPrompt
   ├─ ERR-001 NetworkErrorScreen
   ├─ ERR-002 ServerErrorScreen
   ├─ ERR-003 MaintenanceScreen
   ├─ ERR-004 AppUpdateRequiredScreen
   ├─ ERR-005 PermissionStorageErrorScreen
   ├─ ERR-006 DeepLinkErrorScreen
   └─ ERR-007 GenericErrorScreen
```

## 画面一覧

PNG/HTML列は `doc/screens` 配下の画面確認用ファイルへのリンクである。未作成のファイルは `-` とする。

### 1. 初回・共通系

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `COM-001` | Splash画面 | アプリ起動時の初期表示 | Screen | [PNG](screens/COM-001.png) | [HTML](screens/html/COM-001.html) |
| `COM-002` | Onboarding画面 | アプリの価値と使い方を簡単に説明 | Screen | [PNG](screens/COM-002.png) | [HTML](screens/html/COM-002.html) |
| `COM-003` | Bottom Navigation Shell | `Design` / `My Seals` / `Stones` の3タブを切り替える共通土台 | Shell | [PNG](screens/COM-003.png) | - |
| `COM-004` | Settings画面 | 言語、アプリ情報、規約、問い合わせなどへの導線 | Screen | [PNG](screens/COM-004.png) | [HTML](screens/html/COM-004.html) |
| `COM-005` | About画面 | Stone Signatureの説明 | Screen | [PNG](screens/COM-005.png) | [HTML](screens/html/COM-005.html) |
| `COM-006` | How It Works画面 | 注文・制作・発送までの流れを説明 | Screen | [PNG](screens/COM-006.png) | [HTML](screens/html/COM-006.html) |
| `COM-007` | FAQ画面 | よくある質問 | Screen | [PNG](screens/COM-007.png) | [HTML](screens/html/COM-007.html) |
| `COM-008` | Contact画面 | 問い合わせ導線 | Screen | [PNG](screens/COM-008.png) | [HTML](screens/html/COM-008.html) |
| `COM-009` | Privacy Policy画面 | プライバシーポリシー表示 | Screen | [PNG](screens/COM-009.png) | [HTML](screens/html/COM-009.html) |
| `COM-010` | Terms of Service画面 | 利用規約表示 | Screen | [PNG](screens/COM-010.png) | [HTML](screens/html/COM-010.html) |

### 2. Designタブ系

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `DES-001` | Design Start画面 | 名前入力の入口 | Screen | [PNG](screens/DES-001.png) | - |
| `DES-002` | Name Input画面 | ユーザーが名前を入力 | Screen | [PNG](screens/DES-002.png) | - |
| `DES-003` | Kanji Suggestion Loading画面 | 漢字候補生成中の表示 | State | [PNG](screens/DES-003.png) | - |
| `DES-004` | Kanji Suggestions画面 | AIが生成した漢字候補を表示 | Screen | [PNG](screens/DES-004.png) | - |
| `DES-005` | Kanji Candidate Detail画面 | 漢字候補の意味・印象・理由を詳しく表示 | Screen | [PNG](screens/DES-005.png) | - |
| `DES-006` | Seal Style Selection画面 | 形・雰囲気・太さ・余白感を選択 | Screen | [PNG](screens/DES-006.png) | - |
| `DES-007` | AI Seal Generation Loading画面 | 印影候補生成中の表示 | State | [PNG](screens/DES-007.png) | - |
| `DES-008` | Seal Variant Selection画面 | AIが生成した3つの印影候補を表示 | Screen | [PNG](screens/DES-008.png) | - |
| `DES-009` | Seal Preview Detail画面 | 選択した印影を大きく確認 | Screen | [PNG](screens/DES-009.png) | - |
| `DES-010` | Save Seal Confirmation画面 | 印影保存完了、次の行動を選ぶ | Screen | [PNG](screens/DES-010.png) | - |
| `DES-011` | Kanji Suggestion Error画面 | 漢字候補生成に失敗した場合 | State | [PNG](screens/DES-011.png) | [HTML](screens/html/DES-011.html) |
| `DES-012` | Seal Generation Error画面 | 印影生成に失敗した場合 | State | [PNG](screens/DES-012.png) | [HTML](screens/html/DES-012.html) |
| `DES-013` | Invalid Name Input画面 / 状態 | 名前が未入力・不正な場合 | State | [PNG](screens/DES-013.png) | [HTML](screens/html/DES-013.html) |
| `DES-014` | Unsupported Kanji Result画面 / 状態 | 条件に合う漢字候補が出せなかった場合 | State | [PNG](screens/DES-014.png) | [HTML](screens/html/DES-014.html) |
| `DES-015` | Generation Limit Reached画面 / 状態 | 再生成回数上限に達した場合 | State | [PNG](screens/DES-015.png) | [HTML](screens/html/DES-015.html) |

### 3. My Sealsタブ系

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `MYS-001` | My Seals List画面 | 保存済み印影一覧を表示 | Screen | [PNG](screens/MYS-001.png) | [HTML](screens/html/MYS-001.html) |
| `MYS-002` | My Seals Empty画面 | 保存済み印影がない状態 | State | [PNG](screens/MYS-002.png) | [HTML](screens/html/MYS-002.html) |
| `MYS-003` | Seal Detail画面 | 保存済み印影の詳細を確認 | Screen | [PNG](screens/MYS-003.png) | [HTML](screens/html/MYS-003.html) |
| `MYS-004` | Edit Saved Seal画面 | 保存済み印影の条件を編集・再生成 | Screen | [PNG](screens/MYS-004.png) | [HTML](screens/html/MYS-004.html) |
| `MYS-005` | Seal Compare Selection画面 | 比較する印影を2から4件選択 | Screen | [PNG](screens/MYS-005.png) | [HTML](screens/html/MYS-005.html) |
| `MYS-006` | Seal Comparison画面 | 保存済み印影を並べて比較 | Screen | [PNG](screens/MYS-006.png) | [HTML](screens/html/MYS-006.html) |
| `MYS-007` | Delete Seal Confirmation画面 | 保存済み印影の削除確認 | Dialog / Screen | [PNG](screens/MYS-007.png) | [HTML](screens/html/MYS-007.html) |
| `MYS-008` | Choose Seal for Order画面 / 状態 | 注文に使う印影として選択 | State | [PNG](screens/MYS-008.png) | [HTML](screens/html/MYS-008.html) |

### 4. Stonesタブ系

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `STN-001` | Stones List画面 | 販売中の宝石材一覧を表示 | Screen | [PNG](screens/STN-001.png) | [HTML](screens/html/STN-001.html) |
| `STN-002` | Stones Empty画面 | 条件に合う宝石材がない状態 | State | [PNG](screens/STN-002.png) | [HTML](screens/html/STN-002.html) |
| `STN-003` | Stones Loading画面 | 宝石材一覧取得中 | State | [PNG](screens/STN-003.png) | [HTML](screens/html/STN-003.html) |
| `STN-004` | Stones Error画面 | 宝石材一覧取得失敗 | State | [PNG](screens/STN-004.png) | [HTML](screens/html/STN-004.html) |
| `STN-005` | Stone Filter画面 / Bottom Sheet | Material / Color / Pattern / Availabilityで絞り込み | Bottom Sheet | [PNG](screens/STN-005.png) | [HTML](screens/html/STN-005.html) |
| `STN-006` | Stone Sort画面 / Bottom Sheet | 価格や新着順で並び替え | Bottom Sheet | [PNG](screens/STN-006.png) | [HTML](screens/html/STN-006.html) |
| `STN-007` | Stone Detail画面 | 宝石材の詳細を表示 | Screen | [PNG](screens/STN-007.png) | [HTML](screens/html/STN-007.html) |
| `STN-008` | Stone Image Gallery画面 | 宝石材画像を拡大表示 | Screen | [PNG](screens/STN-008.png) | [HTML](screens/html/STN-008.html) |
| `STN-009` | Select Stone Confirmation画面 / 状態 | この宝石材を選択する確認 | State | [PNG](screens/STN-009.png) | [HTML](screens/html/STN-009.html) |
| `STN-010` | Sold Out Stone画面 / 状態 | 売り切れ宝石材の表示 | State | [PNG](screens/STN-010.png) | [HTML](screens/html/STN-010.html) |

### 5. 印影 + 宝石材 組み合わせ系

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `CMB-001` | Seal + Stone Confirmation画面 | 選択した印影と宝石材の組み合わせを確認 | Screen | [PNG](screens/CMB-001.png) | [HTML](screens/html/CMB-001.html) |
| `CMB-002` | Missing Seal画面 / 状態 | 宝石材は選んだが印影が未選択 | State | [PNG](screens/CMB-002.png) | [HTML](screens/html/CMB-002.html) |
| `CMB-003` | Missing Stone画面 / 状態 | 印影は選んだが宝石材が未選択 | State | [PNG](screens/CMB-003.png) | [HTML](screens/html/CMB-003.html) |
| `CMB-004` | Change Seal画面 | 注文に使う印影を変更 | Screen | [PNG](screens/CMB-004.png) | [HTML](screens/html/CMB-004.html) |
| `CMB-005` | Change Stone画面 | 注文に使う宝石材を変更 | Screen | [PNG](screens/CMB-005.png) | [HTML](screens/html/CMB-005.html) |

### 6. Checkout / Stripe Checkout系

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `CHK-001` | Checkout Information画面 | メール・氏名・住所・電話番号を入力 | Screen | [PNG](screens/CHK-001.png) | [HTML](screens/html/CHK-001.html) |
| `CHK-002` | Shipping Address Form画面 / セクション | 配送先入力 | Section | [PNG](screens/CHK-002.png) | [HTML](screens/html/CHK-002.html) |
| `CHK-003` | Contact Information Form画面 / セクション | メール・氏名・電話番号入力 | Section | [PNG](screens/CHK-003.png) | [HTML](screens/html/CHK-003.html) |
| `CHK-004` | Order Note画面 / セクション | 任意の注文メモ入力 | Section | [PNG](screens/CHK-004.png) | [HTML](screens/html/CHK-004.html) |
| `CHK-005` | Checkout Validation Error画面 / 状態 | 入力不備の表示 | State | [PNG](screens/CHK-005.png) | [HTML](screens/html/CHK-005.html) |
| `CHK-006` | Order Confirmation画面 | Stripe Checkoutへ進む前の最終確認 | Screen | [PNG](screens/CHK-006.png) | [HTML](screens/html/CHK-006.html) |
| `CHK-007` | Custom-made Agreement画面 / セクション | オーダーメイド確認チェック | Section | [PNG](screens/CHK-007.png) | [HTML](screens/html/CHK-007.html) |
| `CHK-008` | Creating Checkout Session画面 | Stripe Checkout Session作成中 | State | [PNG](screens/CHK-008.png) | [HTML](screens/html/CHK-008.html) |
| `CHK-009` | Stripe Checkout Transition画面 | Stripe Checkoutへ遷移する直前の表示 | Screen | [PNG](screens/CHK-009.png) | [HTML](screens/html/CHK-009.html) |
| `CHK-010` | Stripe Checkout画面 | Stripe側の外部決済画面 | External | [PNG](screens/CHK-010.png) | [HTML](screens/html/CHK-010.html) |
| `CHK-011` | Payment Success Handling画面 | Stripeから戻った後、決済成功確認中 | Screen | [PNG](screens/CHK-011.png) | [HTML](screens/html/CHK-011.html) |
| `CHK-012` | Payment Cancelled画面 | Stripe Checkoutでキャンセルされた場合 | Screen | [PNG](screens/CHK-012.png) | [HTML](screens/html/CHK-012.html) |
| `CHK-013` | Payment Failed画面 | 決済失敗時の表示 | Screen | [PNG](screens/CHK-013.png) | [HTML](screens/html/CHK-013.html) |
| `CHK-014` | Payment Pending画面 | Webhook反映待ち・確認中 | Screen | [PNG](screens/CHK-014.png) | [HTML](screens/html/CHK-014.html) |
| `CHK-015` | Order Complete画面 | 注文完了表示 | Screen | [PNG](screens/CHK-015.png) | [HTML](screens/html/CHK-015.html) |

`CHK-010` はアプリ内で作る画面ではなく、Stripeが提供する外部決済画面である。アプリ側では遷移前、戻り後、キャンセル時、確認中の画面を用意する。

### 7. Order Lookup系

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `LKP-001` | Order Lookup Input画面 | 注文番号とメールアドレスを入力 | Screen | [PNG](screens/LKP-001.png) | [HTML](screens/html/LKP-001.html) |
| `LKP-002` | Order Lookup Loading画面 | 注文情報取得中 | State | [PNG](screens/LKP-002.png) | [HTML](screens/html/LKP-002.html) |
| `LKP-003` | Order Lookup Result画面 | 注文内容・決済状態・制作状態・発送状態を表示 | Screen | [PNG](screens/LKP-003.png) | [HTML](screens/html/LKP-003.html) |
| `LKP-004` | Order Lookup Not Found画面 | 注文が見つからない場合 | State | [PNG](screens/LKP-004.png) | [HTML](screens/html/LKP-004.html) |
| `LKP-005` | Order Lookup Error画面 | 通信エラーなどの場合 | State | [PNG](screens/LKP-005.png) | [HTML](screens/html/LKP-005.html) |
| `LKP-006` | Tracking Detail画面 | 追跡番号・配送情報を表示 | Screen | [PNG](screens/LKP-006.png) | [HTML](screens/html/LKP-006.html) |

### 8. 通知・メール案内系

| Code | 画面 / 状態 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `NTC-001` | Email Sent Notice | 注文確認メール送信済みの案内 | State | [PNG](screens/NTC-001.png) | [HTML](screens/html/NTC-001.html) |
| `NTC-002` | Order Confirmation Email Guide | 注文メールが届かない場合の案内 | State | [PNG](screens/NTC-002.png) | [HTML](screens/html/NTC-002.html) |
| `NTC-003` | Contact Support Prompt | 困ったときの問い合わせ導線 | State | [PNG](screens/NTC-003.png) | [HTML](screens/html/NTC-003.html) |

### 9. エラー・共通状態画面

| Code | 画面 | 目的 | 実装単位 | PNG | HTML |
| --- | --- | --- | --- | --- | --- |
| `ERR-001` | Network Error画面 | 通信エラー | Screen / State | [PNG](screens/ERR-001.png) | [HTML](screens/html/ERR-001.html) |
| `ERR-002` | Server Error画面 | サーバー側エラー | Screen / State | [PNG](screens/ERR-002.png) | [HTML](screens/html/ERR-002.html) |
| `ERR-003` | Maintenance画面 | メンテナンス中 | Screen | [PNG](screens/ERR-003.png) | [HTML](screens/html/ERR-003.html) |
| `ERR-004` | App Update Required画面 | 強制アップデートが必要な場合 | Screen | [PNG](screens/ERR-004.png) | [HTML](screens/html/ERR-004.html) |
| `ERR-005` | Permission / Storage Error画面 | 印影画像保存に失敗した場合 | Screen / State | [PNG](screens/ERR-005.png) | [HTML](screens/html/ERR-005.html) |
| `ERR-006` | Deep Link Error画面 | Stripe Checkout戻りURL処理に失敗した場合 | Screen | [PNG](screens/ERR-006.png) | [HTML](screens/html/ERR-006.html) |
| `ERR-007` | Generic Error画面 | 想定外エラー | Screen / State | [PNG](screens/ERR-007.png) | [HTML](screens/html/ERR-007.html) |

## 実装上の推奨画面構成

すべてを完全に独立Screenにする必要はない。MVPでは以下のまとまりで実装する。

### Bottom Navigation配下

```text
COM-003 BottomNavigationShell
├─ DesignTab
├─ MySealsTab
└─ StonesTab
```

### Design Stack

```text
DES-001 DesignStartScreen
DES-004 KanjiSuggestionsScreen
DES-006 SealStyleSelectionScreen
DES-007 SealGenerationScreen
DES-008 SealVariantSelectionScreen
DES-009 SealPreviewDetailScreen
DES-010 SaveSealConfirmationScreen
```

`DES-002`、`DES-003`、`DES-011`、`DES-012`、`DES-013`、`DES-014`、`DES-015` は、Design Stack内の状態またはサブステップとして実装してよい。

### My Seals Stack

```text
MYS-001 MySealsListScreen
MYS-003 SealDetailScreen
MYS-006 SealComparisonScreen
MYS-004 EditSavedSealScreen
```

`MYS-002`、`MYS-005`、`MYS-007`、`MYS-008` は、一覧・詳細画面内の状態、選択モード、確認ダイアログとして実装してよい。

### Stones Stack

```text
STN-001 StonesListScreen
STN-007 StoneDetailScreen
STN-008 StoneImageGalleryScreen
STN-005 StoneFilterSheet
```

`STN-002`、`STN-003`、`STN-004`、`STN-006`、`STN-009`、`STN-010` は、Stones List / Stone Detail 内の状態またはBottom Sheetとして実装してよい。

### Order Stack

```text
CMB-001 SealStoneConfirmationScreen
CHK-001 CheckoutInformationScreen
CHK-006 OrderConfirmationScreen
CHK-008 CreatingCheckoutSessionScreen
CHK-009 StripeCheckoutTransitionScreen
CHK-011 PaymentResultScreen
CHK-015 OrderCompleteScreen
```

`CHK-011 PaymentResultScreen` は、`CHK-011`、`CHK-012`、`CHK-013`、`CHK-014` の状態をまとめる親画面として実装してよい。

### Order Lookup Stack

```text
LKP-001 OrderLookupInputScreen
LKP-003 OrderLookupResultScreen
LKP-006 TrackingDetailScreen
```

`LKP-002`、`LKP-004`、`LKP-005` は Order Lookup Stack 内の状態として扱う。

### Settings Stack

```text
COM-004 SettingsScreen
COM-005 AboutScreen
COM-006 HowItWorksScreen
COM-007 FAQScreen
COM-008 ContactScreen
COM-009 PrivacyPolicyScreen
COM-010 TermsOfServiceScreen
```

## MVPで必須の画面

最小限に絞る場合、MVPで必須にする画面コードは以下。

```text
COM-001 SplashScreen
COM-002 OnboardingScreen
COM-003 BottomNavigationShell

DES-001 DesignStartScreen
DES-004 KanjiSuggestionsScreen
DES-006 SealStyleSelectionScreen
DES-008 SealVariantSelectionScreen
DES-009 SealPreviewDetailScreen

MYS-001 MySealsListScreen
MYS-003 SealDetailScreen

STN-001 StonesListScreen
STN-007 StoneDetailScreen

CMB-001 SealStoneConfirmationScreen
CHK-001 CheckoutInformationScreen
CHK-006 OrderConfirmationScreen
CHK-008 CreatingCheckoutSessionScreen
CHK-011 PaymentSuccessHandlingScreen
CHK-012 PaymentCancelledScreen
CHK-015 OrderCompleteScreen

LKP-001 OrderLookupInputScreen
LKP-003 OrderLookupResultScreen

COM-004 SettingsScreen
COM-005 AboutScreen
COM-007 FAQScreen
COM-009 PrivacyPolicyScreen
COM-010 TermsOfServiceScreen

ERR-001 NetworkErrorScreen
ERR-007 GenericErrorScreen
```

### MVP必須画面の固定ID対応

MVP必須画面は、以下の対応で実装・テスト・スクリーンショットをそろえる。

| Code | Flutter実装名 | PageEntry / route key prefix | Widget test名 prefix | Screenshot |
| --- | --- | --- | --- | --- |
| `COM-001` | `SplashScreen` | `COM-001` | `COM-001` | `doc/screens/COM-001.png` |
| `COM-002` | `OnboardingScreen` | `COM-002` | `COM-002` | `doc/screens/COM-002.png` |
| `COM-003` | `BottomNavigationShell` | `COM-003` | `COM-003` | `doc/screens/COM-003.png` |
| `DES-001` | `DesignStartScreen` | `DES-001` | `DES-001` | `doc/screens/DES-001.png` |
| `DES-004` | `KanjiSuggestionsScreen` | `DES-004` | `DES-004` | `doc/screens/DES-004.png` |
| `DES-006` | `SealStyleSelectionScreen` | `DES-006` | `DES-006` | `doc/screens/DES-006.png` |
| `DES-008` | `SealVariantSelectionScreen` | `DES-008` | `DES-008` | `doc/screens/DES-008.png` |
| `DES-009` | `SealPreviewDetailScreen` | `DES-009` | `DES-009` | `doc/screens/DES-009.png` |
| `MYS-001` | `MySealsListScreen` | `MYS-001` | `MYS-001` | `doc/screens/MYS-001.png` |
| `MYS-003` | `SealDetailScreen` | `MYS-003` | `MYS-003` | `doc/screens/MYS-003.png` |
| `STN-001` | `StonesListScreen` | `STN-001` | `STN-001` | `doc/screens/STN-001.png` |
| `STN-007` | `StoneDetailScreen` | `STN-007` | `STN-007` | `doc/screens/STN-007.png` |
| `CMB-001` | `SealStoneConfirmationScreen` | `CMB-001` | `CMB-001` | `doc/screens/CMB-001.png` |
| `CHK-001` | `CheckoutInformationScreen` | `CHK-001` | `CHK-001` | `doc/screens/CHK-001.png` |
| `CHK-006` | `OrderConfirmationScreen` | `CHK-006` | `CHK-006` | `doc/screens/CHK-006.png` |
| `CHK-008` | `CreatingCheckoutSessionScreen` | `CHK-008` | `CHK-008` | `doc/screens/CHK-008.png` |
| `CHK-011` | `PaymentSuccessHandlingScreen` | `CHK-011` | `CHK-011` | `doc/screens/CHK-011.png` |
| `CHK-012` | `PaymentCancelledScreen` | `CHK-012` | `CHK-012` | `doc/screens/CHK-012.png` |
| `CHK-015` | `OrderCompleteScreen` | `CHK-015` | `CHK-015` | `doc/screens/CHK-015.png` |
| `LKP-001` | `OrderLookupInputScreen` | `LKP-001` | `LKP-001` | `doc/screens/LKP-001.png` |
| `LKP-003` | `OrderLookupResultScreen` | `LKP-003` | `LKP-003` | `doc/screens/LKP-003.png` |
| `COM-004` | `SettingsScreen` | `COM-004` | `COM-004` | `doc/screens/COM-004.png` |
| `COM-005` | `AboutScreen` | `COM-005` | `COM-005` | `doc/screens/COM-005.png` |
| `COM-007` | `FAQScreen` | `COM-007` | `COM-007` | `doc/screens/COM-007.png` |
| `COM-009` | `PrivacyPolicyScreen` | `COM-009` | `COM-009` | `doc/screens/COM-009.png` |
| `COM-010` | `TermsOfServiceScreen` | `COM-010` | `COM-010` | `doc/screens/COM-010.png` |
| `ERR-001` | `NetworkErrorScreen` | `ERR-001` | `ERR-001` | `doc/screens/ERR-001.png` |
| `ERR-007` | `GenericErrorScreen` | `ERR-007` | `ERR-007` | `doc/screens/ERR-007.png` |

## MVPでは後回しでもよい画面

以下は最初のMVPでは後回しでもよい。

```text
DES-005 KanjiCandidateDetailScreen
MYS-005 SealCompareSelectionScreen
MYS-006 SealComparisonScreen
MYS-004 EditSavedSealScreen
STN-006 StoneSortSheet
STN-008 StoneImageGalleryScreen
CMB-004 ChangeSealScreen
CMB-005 ChangeStoneScreen
LKP-006 TrackingDetailScreen
COM-006 HowItWorksScreen
COM-008 ContactScreen
ERR-003 MaintenanceScreen
ERR-004 AppUpdateRequiredScreen
```

## 画面数の目安

状態画面を除くMVPの実画面数は、25から30画面程度を目安にする。状態表示・エラー表示込みでは35から45画面程度になる。

ただし、`Loading`、`Empty`、`Error`、`Success` は別Screenではなく、同じScreen内の状態として扱う。

## 画面別の実装責任

| 画面コード | 画面群 | Flutterの責務 | Rust APIの責務 | AIの責務 | 保存先 |
| --- | --- | --- | --- | --- | --- |
| `DES-*` | Design | 名前入力、候補表示、スタイル選択、印影候補選択、保存 | 漢字候補生成、印影候補生成、Storage保存 | 漢字候補生成、印影候補生成 | 注文下書き、端末内保存 |
| `MYS-*` | My Seals | 保存済み印影一覧、詳細、比較、削除、注文用選択 | なし | なし | 端末内保存 |
| `STN-*` | Stones | 石一覧、詳細、画像表示、フィルタ、選択 | `/v1/catalog`、`/v1/stone-listings` | なし | 注文下書き |
| `CMB-*` | Seal + Stone | 印影と宝石材の組み合わせ確認、変更導線 | 価格・在庫再確認のための入力受け取り | なし | 注文下書き |
| `CHK-*` | Checkout | 連絡先・配送先・同意・Stripe遷移・戻り後表示 | `/v1/orders`、Stripe Checkout Session作成、Webhook反映後の状態取得 | なし | Firestore、注文下書き |
| `LKP-*` | Order Lookup | 注文検索入力、注文状態表示、追跡表示 | 注文検索・注文状態取得 | なし | Firestore |
| `COM-*` | 共通 | 初回表示、設定、法務、FAQ、問い合わせ導線 | 必要に応じて公開設定取得 | なし | 端末内設定 |

## 印影スタイル選択方針

`DES-006 Seal Style Selection画面` では、Gen UIを使わず、固定の選択UIで以下を選ぶ。

| 項目 | 選択肢 | 注文保存先 |
| --- | --- | --- |
| Shape | `square` / `round` | `orders.seal.shape` |
| Style | `traditional` / `elegant` / `soft` / `bold` | `orders.seal.style.name` |
| Stroke Weight | `standard` / `bold` | `orders.seal.style.stroke_weight` |
| Balance | `airy` / `balanced` / `dense` | `orders.seal.style.balance` |

初期値は `square`、`elegant`、`standard`、`balanced` とする。`fine` はMVPでは出さない。細線は彫刻で潰れやすく、AI生成結果と実物との差が大きくなりやすいためである。

固定UIが扱わないこと:

- 名前入力の置き換え
- 漢字候補の勝手な変更
- 選択済み文字と異なる印影画像の採用
- 在庫、価格、配送条件、注文、決済の判断
- Firestoreへの直接書き込み

## AI と API の設計

AIは漢字候補生成と印影候補生成に使う。業務ロジック、注文、在庫、価格、決済はRust APIが管理する。

| 役割 | 実装場所 | 出力 |
| --- | --- | --- |
| 漢字候補生成 | Rust API + Gemini | `candidates` |
| 印影候補生成 | Rust API + 画像生成AI | `request_id`、`variants` |
| 印影画像保存 | Rust API + Firebase Storage | `storage_path`、必要に応じて `download_url` |
| 注文スナップショット保存 | Rust API | `orders.seal.*`、`orders.customer_confirmation.*` |

### 既存API

| API | 用途 |
| --- | --- |
| `GET /v1/config/public` | 公開設定、ロケール、通貨ポリシー |
| `GET /v1/catalog` | フォント、素材、配送国、公開カタログ |
| `GET /v1/stone-listings` | 一点物石一覧、フィルタ |
| `POST /v1/kanji-candidates` | 名前から漢字候補を生成 |
| `POST /v1/seal-designs/generate` | 選択済み漢字とスタイル条件からAI印影候補を3件生成し、Storageへ保存 |
| `POST /v1/orders` | 注文作成、在庫予約、AI印影と顧客確認記録の保存 |
| `POST /v1/payments/stripe/checkout-session` | Stripe Checkout開始 |

### 印影候補生成レスポンス例

AI事業者の一時URLを注文の正本にしない。Rust APIがFirebase Storageへ保存した `storagePath` を返す。

```json
{
  "requestId": "seal_request_001",
  "variants": [
    {
      "id": "seal_variant_001",
      "storagePath": "seal_designs/seal_request_001/seal_variant_001.png",
      "downloadUrl": "https://firebasestorage.googleapis.com/...",
      "label": "Elegant and balanced",
      "width": 1024,
      "height": 1024
    }
  ]
}
```

## 注文スナップショット

`CHK-006 Order Confirmation画面` でユーザーが確認した印影情報は、`CHK-008 Creating Checkout Session画面` へ進む前に `/v1/orders` へ送信し、Firestore の `orders` に保存する。adminで制作確認に使うため、AI印影画像、AI Variant ID、選択スタイル、顧客確認チェックを残す。

```json
{
  "seal": {
    "line1": "美",
    "line2": "空",
    "shape": "square",
    "font_key": "noto_serif_jp",
    "font_label": "Noto Serif JP",
    "font_version": 1,
    "ai_generation_id": "seal_request_001",
    "ai_variant_id": "seal_variant_001",
    "preview_image": {
      "storage_path": "seal_designs/seal_request_001/seal_variant_001.png",
      "download_url": "https://firebasestorage.googleapis.com/...",
      "width": 1024,
      "height": 1024
    },
    "style": {
      "name": "elegant",
      "stroke_weight": "standard",
      "balance": "balanced",
      "prompt_summary": "Elegant, standard stroke, balanced spacing."
    }
  },
  "customer_confirmation": {
    "kanji_and_design": true,
    "custom_made_policy": true,
    "confirmed_at": "2026-05-21T11:00:00+09:00",
    "confirmed_seal_text": "美空"
  }
}
```

`preview_image.download_url` は表示補助であり、正本は `preview_image.storage_path` とする。期限付きURLしか取得できない場合はFirestoreへ保存せず、admin表示時にAPIで再生成する。

## 状態管理とローカルデータ

状態管理は `miniriverpod` を使い、ナビゲーションは `declarative_nav` を使う。他のナビゲーションライブラリは使わない。

| Provider | 役割 |
| --- | --- |
| `appLaunchProvider` | `COM-001` / `COM-002` / `COM-003` の初期表示制御 |
| `appNavigationProvider` | 画面コードベースのタブ・スタック状態 |
| `sealDesignSessionProvider` | `DES-*` の現在編集中の印影デザイン |
| `kanjiSuggestionsProvider` | `DES-004` の漢字候補状態 |
| `sealGenerationProvider` | `DES-007` / `DES-008` の印影生成状態 |
| `savedSealDesignsProvider` | `MYS-*` の保存済み印影案 |
| `stoneCatalogProvider` | `STN-*` の宝石材一覧・フィルタ状態 |
| `orderDraftProvider` | `CMB-*` / `CHK-*` の注文下書き |
| `checkoutProvider` | `CHK-*` の注文作成、Checkout開始、決済結果確認 |
| `orderLookupProvider` | `LKP-*` の注文検索状態 |

## App Store Review 向け説明方針

Stone Signature は、Webサイトの再包装ではなく、ユーザーが自分の personal seal をネイティブUIで設計できるアプリである。購入前でも、印影生成、端末内保存、複数案比較により独立した実用性がある。

アカウント登録は不要で、保存済み印影案は端末内にのみ保存される。ユーザーは複数の印影案を作成、保存、比較し、気に入った案を天然石の印として注文できる。
