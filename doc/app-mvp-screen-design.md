# Stone Signature App MVP 画面デザイン設計

## 目的

Stone Signature のアプリ版は、天然石印鑑のECをそのままアプリ化するのではなく、ユーザーが自分の personal seal を設計し、保存し、比較し、必要に応じて実物の石印として注文できるネイティブアプリとして設計する。

App Store Review Guideline 4.2 対応として、購入前でも価値がある体験を中心に置く。主価値は「印影を作る」「端末内に保存する」「複数案を比較する」であり、注文はその延長に置く。

## MVP 前提

- アカウント登録はしない。
- ログイン画面は作らない。
- Firebase Auth は使わない。
- 保存済み印影案は端末内ローカル保存のみとする。
- アプリ削除、別端末、機種変更では保存済み印影案は引き継がれない。
- 注文時だけ、メールアドレスと配送先を入力する。
- 決済は Stripe Checkout に遷移する。
- 初回ダウンロード直後のみ Guided Start を表示し、完了またはスキップ後は Design Studio を通常起点とする。
- Guided Start の表示済み状態は端末内ローカルフラグで管理し、アカウントやクラウド同期には依存しない。

## 情報設計

下部タブは3つに絞る。

```text
Design / My Seals / Stones
```

初回ダウンロード直後のユーザーには、下部タブの通常導線へ入る前に Guided Start を表示する。これはブランド説明用の Intro ではなく、名前入力から印影案作成までを短く案内する制作フローとする。

```text
初回起動のみ
  -> Guided Start
      -> Design Studio / My Seals / Stones

2回目以降
  -> Design Studio
```

設定、About、法務系ページは右上の設定アイコン、またはメニューから遷移する。

## アプリ全体の画面設計

アプリ全体は、初回ユーザー向けの Guided Start と、再訪ユーザー向けの通常制作導線に分ける。初回導線はアプリ理解を助けるための一度きりの制作フローであり、通常導線は `Design / My Seals / Stones` の3タブを中心にする。

```text
AppRoot
├─ FirstLaunchGate
│  ├─ Guided Start（初回のみ）
│  └─ Main Tabs
│
├─ Design Tab
│  ├─ Design Studio
│  ├─ Kanji Suggestions Panel
│  ├─ Customize Seal
│  └─ Preview / Save Actions
│
├─ My Seals Tab
│  ├─ Saved Seal List
│  └─ Compare Seals
│
├─ Stones Tab
│  ├─ Stone Listing List
│  ├─ Stone Filters
│  └─ Order Review
│
├─ Payment Result
└─ Settings / Legal
```

### 画面グループ

| グループ | 役割 | 主な画面 | UI 方針 |
| --- | --- | --- | --- |
| 初回制作 | 初めてのユーザーが迷わず1案作る | Guided Start | 通常Flutter UIを基本にし、CustomizeだけGen UI化できる構造にする |
| 制作 | 印影を自由に編集し、保存や石選択へ進む | Design Studio / Kanji Suggestions / Customize Seal / Preview | ライブプレビューを中心に置く |
| 保存・比較 | 購入しないユーザーにも価値を残す | My Seals / Compare Seals | 端末内保存であることを短く明示する |
| 石選択 | 印影に合わせて天然石を選ぶ | Stones | 在庫、価格、形状はAPI由来の確定情報として扱う |
| 注文 | 注文内容、配送、同意、決済へ進む | Order Review / Payment Result | AIやGen UIを関与させず、FlutterとRust APIで厳密に管理する |
| 補助 | ブランド、法務、設定を確認する | Settings / Legal / About | 制作導線を邪魔しない補助導線にする |

### 初回ユーザー導線

初回ダウンロード直後は Guided Start を表示する。これはブランド紹介だけの画面ではなく、名前入力、漢字候補、短いカスタマイズ、保存または石選択まで進める制作体験にする。

```text
Guided Start
  -> 名前入力
  -> Masculine / Feminine / No preference
  -> 漢字候補生成
  -> 漢字候補選択
  -> Customize Seal
  -> Preview / Save / Select Stone
```

Guided Start は完了またはスキップされた時点で表示済みにする。ユーザーが途中で離脱した場合は、次回起動時に途中再開するよりも Design Studio へ入れる方を優先する。初回体験が何度も出ると、再訪時の制作速度を落とすためである。

### 再訪ユーザー導線

2回目以降は Design Studio を起点にする。ユーザーはすぐに印影を編集でき、保存済み印影を呼び出し、必要に応じて石選択へ進む。

```text
Design Studio
  -> Edit seal
  -> Save locally
  -> My Seals
  -> Stones
  -> Order Review
```

### 制作ステップの扱い

`Create Your Seal`、`Select Kanji`、`Customize Seal`、`Preview Seal` は、すべて独立した下部タブにはしない。Guided Start または Design Studio 内の制作ステップとして扱う。

| ステップ | 配置 | 実装方針 |
| --- | --- | --- |
| Start Designing | 初回のみ Guided Start | 入力開始のための短い導入。説明ページ化しない |
| Create Your Seal | Guided Start / Design Studio | 名前、性別印象、印面文字の入力は通常Flutter UI。入力前は5種類程度の既存漢字サンプル印影をグラデーション遷移で見せる |
| Select Kanji | Guided Start / Design Studio | APIから返った候補をFlutter側でカード表示 |
| Customize Seal | Guided Start / Design Studio | Gen UI導入の中心。4個の選択質問（角印/丸印を含む）と短い自由入力を担当 |
| Preview Seal | Design Studio内のプレビュー領域 | FlutterまたはRust APIの決定的描画結果を表示 |
| Select Stone | Stonesタブ | 在庫、価格、素材情報はRust API由来の確定情報を表示 |

### Create Your Seal の印影演出

Create Your Seal では、名前入力前から印影の魅力が伝わるように、画面上部または中央にアニメーション印影を表示する。これはAIが文字を自由生成するものではなく、アプリ側で用意した5種類程度の既存漢字の組み合わせを使う。

```text
sampleSealTexts
  -> ["山田", "雅月", "清風", "悠真", "美咲"] など
  -> 既存文字だけで構成
  -> 角印/丸印プレビュー内でゆっくり切り替える
```

演出方針:

- 5種類程度のサンプル印影を、赤系インクの濃淡や透明度のグラデーションで移り変わらせる。
- 切り替えは急なスライドではなく、クロスフェード、にじみ、インク濃度の変化のように見せる。
- サンプル文字はすべて既存の漢字に限定し、存在しない文字や疑似漢字は使わない。
- ユーザーが名前を入力した、または漢字候補を選択した時点で、サンプルアニメーションから実際の印影プレビューへ切り替える。
- 端末の `reduce motion` 設定が有効な場合は、アニメーションを停止し、静的な代表印影を表示する。
- この演出はCreate Your Sealの導入表現であり、注文データや保存済み印影には使わない。

## 画面一覧

### 0. Guided Start（初回のみ）

#### 役割

初めて利用するユーザーが迷わず最初の印影案を作れるようにする、初回専用のガイド付き制作フロー。単なる紹介ページやブランド説明ページではなく、最初の入力から印影プレビューまでを短く進める。

#### 表示内容

- 名前入力
- 入力前のアニメーション印影プレビュー
  - 5種類程度の既存漢字サンプル
  - 赤系インクのグラデーション遷移
  - 入力後は実際の印影プレビューへ切り替え
- Masculine / Feminine / No preference の選択
- 漢字候補生成の実行状態
- 漢字候補カード
  - 漢字
  - reading
  - 意味または理由
- Customize Seal への導線
- Customize Seal でのカスタマイズ
  - Which words feel most like you?
  - How would you like the characters to look?
  - Which seal shape do you prefer?
  - Which layout do you prefer?
  - What should this seal express?（短い自由入力）
- 完成した印影スタイルの要約
- Preview / Save / Select Stone への導線
- スキップして Design Studio へ進む導線

#### 主な操作

- 名前入力
- 性別印象の選択
- 漢字候補生成
- 漢字候補の選択
- カスタマイズ質問への回答
- 印影案の保存
- Design Studio で編集を続ける
- Stones へ進む

#### 遷移先

- Design Studio
- My Seals
- Stones

#### 状態管理

- `hasSeenGuidedStart` のような端末内ローカルフラグで、初回表示済みかどうかを管理する。
- Guided Start を完了またはスキップした時点で表示済みにする。
- Guided Start で作成した印影案は、Design Studio の現在編集中データへ引き継ぐ。
- 保存した場合は My Seals の保存済み印影案として扱う。
- Stones へ進む場合も、Design Studio と同じ注文下書きデータへ接続する。

#### 注意点

Guided Start は初回ユーザーの理解を助けるための導線であり、毎回表示しない。2回目以降はユーザーがすぐ編集できる Design Studio を起点にする。

### 1. Design Studio

#### 役割

通常起動時のホーム画面。ユーザーが名前や単語を入力し、印影をすぐ確認できる制作画面。購入よりもデザイン体験を先に出す。初回ダウンロード直後は Guided Start を表示し、完了またはスキップ後はこの画面を起点にする。

#### 表示内容

- ブランド名: `STONE SIGNATURE`
- 短いタグライン
  - 日本語: `自分の印をデザインする`
  - 英語: `Design your personal seal`
- 印影ライブプレビュー
- 入力欄
  - 1行目
  - 2行目
- 形状選択
  - 角印
  - 丸印
- 書体選択
- 文字方向
  - 縦書き
  - 横書き
- 現在のデザイン情報
  - 印面テキスト
  - 書体
  - 形状
- 保存ボタン
  - `この印影を保存`
- 石を選ぶボタン
  - `この印影で石を選ぶ`
- My Seals への導線
- 設定メニューへの導線
- APIエラー時の最低限表示
  - カタログ取得に失敗しても、文字入力と印影プレビューは使える状態にする。

#### 主な操作

- 文字入力
- 形状変更
- 書体変更
- 縦横切替
- 印影案の保存
- 保存済み印影案の呼び出し
- 石選択への遷移

#### 遷移先

- My Seals
- Stones
- Settings / Legal

#### 注意点

通常起動時の最初の画面に商品説明を長く置かない。ユーザーがすぐ触れる制作画面にする。

### 2. My Seals

#### 役割

端末内に保存した印影案を管理する画面。購入しないユーザーにも継続的な価値を残す。

#### 表示内容

- 画面タイトル: `My Seals`
- 保存済み印影案の一覧
- 各カードの内容
  - 印影プレビュー
  - 印面テキスト
  - 書体
  - 形状
  - 保存日
  - お気に入り状態
- 空状態
  - まだ保存済み印影案がないこと
  - Design Studio で印影を作れること
- ローカル保存の説明
  - 日本語: `保存済み印影案はこの端末にのみ保存されます。`
  - 英語: `Saved seal designs are stored only on this device.`

#### 主な操作

- 編集再開
- お気に入り切替
- 比較に追加
- 石を選ぶ
- 削除

#### 遷移先

- Design Studio
- Compare Seals
- Stones

#### 注意点

会員登録やクラウド同期を想起させない。端末内保存であることを短く明示する。

### 3. Compare Seals

#### 役割

複数の印影案を比較する画面。アプリならではの価値として、購入前の検討体験を強化する。

#### 表示内容

- 画面タイトル: `Compare`
- 比較対象の印影案 2から4件
- 各案の表示内容
  - 印影プレビュー
  - 印面テキスト
  - 書体
  - 形状
  - 保存日
  - お気に入り状態
- 比較対象が不足している場合の案内
  - 2件以上選ぶ必要があること
- ベスト案を選ぶボタン
- 選んだ案で編集するボタン
- 選んだ案で石を選ぶボタン

#### 主な操作

- 比較対象の確認
- ベスト案の選択
- Design Studio で編集再開
- Stones へ進む

#### 遷移先

- Design Studio
- My Seals
- Stones

#### 注意点

比較画面は商品購入に直結させすぎない。まずは「どの印影がよいか」を判断する画面にする。

### 4. Stones

#### 役割

現在の印影に合う天然石を選ぶ画面。単なる商品一覧ではなく、「この印影をどの石で作るか」を選ぶ画面として見せる。

#### 表示内容

- 画面タイトル: `Stones`
- 現在の印影プレビュー
- 選択中の印影情報
  - 印面テキスト
  - 形状
- 石一覧
- 各石カードの内容
  - 石の写真
  - 素材名
  - 一点物名または listing code
  - 価格
  - 対応形状
  - 色タグ
  - 模様タグ
- フィルタ
  - 色
  - 模様
  - 形状
- カタログ取得エラー表示
- 石未選択時の案内

#### デザイン方針

Stonesタブで開くStoneページは、提供スクリーンショットの構成を取り入れる。縦スクロールの一覧画面として、上部にタイトルと現在ステップ、右上に設定アイコン、続いてフィルタチップ、石カード一覧、下部タブを配置する。

スクリーンショットから取り入れる要素:

- タイトルは `Select Stone`、サブテキストは `Design` とする。
- 右上に設定アイコンを置き、Settings / Legal へ進める。
- フィルタは `Stone color` と `Pattern` を上から並べる。
- フィルタチップは横並びで折り返し、選択中の `All` は淡い赤背景とチェックアイコンで示す。
- 石カードは白背景、薄い枠線、角丸の縦カードにする。
- 石写真はカード上部に大きく表示し、角丸でトリミングする。
- 商品名は濃い赤系の太字で表示する。
- `Square`、色、模様などのタグは小さな丸みのあるチップで表示する。
- サイズ、説明文、ストーリー文を価格の前に表示する。
- 価格は `USD 165.00` のように通貨と金額を赤系で強調する。
- `Select This Stone` はカード幅いっぱいのアウトラインボタンにし、淡い赤背景と赤枠で表示する。
- 下部タブは `Design`、`My Seals`、`Stones` の3つを維持し、Stones選択中は淡いピンクのピル背景で強調する。

スクリーンショットの見た目は採用するが、表示データは必ずRust APIの `/v1/catalog` と `/v1/stone-listings` 由来にする。価格、在庫、対応形状、素材情報はAIやGen UIで生成しない。

#### 主な操作

- 石の絞り込み
- 石の選択
- 注文確認へ進む
- Design Studio に戻って印影を調整する

#### 遷移先

- Order Review
- Design Studio
- My Seals

#### 注意点

現在の印影を画面上部に残し、ユーザーが「印影と石の組み合わせ」を判断できるようにする。

### 5. Order Review

#### 役割

注文前に、印影、石、金額、配送情報、同意内容を確認する画面。

#### 表示内容

- 画面タイトル: `Order Review`
- 印影プレビュー
- 注文内容
  - 印面テキスト
  - 書体
  - 形状
  - 選択した石
  - 価格
  - 送料
  - 合計金額
- 購入者情報
  - メールアドレス
  - 氏名
  - 電話番号
- 配送先
  - 国
  - 郵便番号
  - 都道府県、州、地域
  - 市区町村
  - 住所
  - 建物名、部屋番号
- 同意チェック
  - 利用規約
  - 特商法表記
  - 天然石の個体差
- Stripe Checkout へ進むボタン
- 入力不足、同意未完了、送信中の状態表示

#### 主な操作

- 注文内容確認
- 配送先入力
- 利用規約確認
- Stripe Checkout へ進む

#### 遷移先

- Stripe Checkout
- Stones
- Design Studio
- Terms
- Legal Notice

#### 注意点

この画面ではアカウント作成を求めない。注文に必要な情報だけを入力させる。

### 6. Payment Result

#### 役割

Stripe Checkout 後の成功、失敗を表示する画面。

#### 表示内容

成功時:

- 注文完了メッセージ
- 注文ID
- 選択した印影
- 選択した石
- 確認メールを送ること
- 次の流れ
- 問い合わせ導線

失敗時:

- 決済が完了しなかったこと
- 注文内容は保持されていること
- 再試行ボタン
- Order Review に戻るボタン
- 問い合わせ導線

#### 主な操作

- My Seals に戻る
- Design Studio に戻る
- Order Review に戻って再試行する
- 問い合わせる

#### 遷移先

- My Seals
- Design Studio
- Order Review
- Contact

### 7. Settings / Legal

#### 役割

設定、ブランド説明、法務情報、問い合わせをまとめる補助画面。

#### 表示内容

- 言語切替
  - 日本語
  - English
- About STONE SIGNATURE
- 利用規約
- 特定商取引法に基づく表記
- プライバシーポリシー
- 会社情報
- 問い合わせ
- バージョン情報

#### 主な操作

- 言語変更
- 法務ページ確認
- About確認
- 問い合わせ

#### 遷移先

- About
- Terms
- Legal Notice
- Privacy Policy
- Company Info
- Contact
- Design Studio

## 基本導線

```text
First launch only
  -> Guided Start
      -> Design Studio
      -> Save locally
      -> My Seals
      -> Stones

Design Studio
  -> Save locally
  -> My Seals
  -> Stones
      -> Order Review
          -> Stripe Checkout
              -> Payment Result

My Seals
  -> Design Studio
  -> Compare Seals
  -> Stones

Compare Seals
  -> Design Studio
  -> Stones

Settings / Legal
  -> About
  -> Terms
  -> Legal Notice
  -> Privacy Policy
  -> Company Info
  -> Contact
```

## 画面別の実装責任

| 画面 | Flutterの責務 | Rust APIの責務 | AI/Gen UIの責務 | 保存先 |
| --- | --- | --- | --- | --- |
| Guided Start | 初回フロー、入力、選択、ステップ制御 | 漢字候補生成、必要なカタログ取得 | Customize Sealの質問と要約 | 端末内フラグ、注文下書き |
| Design Studio | ライブプレビュー、印面文字、形状、書体、保存 | カタログ取得、漢字候補生成 | 任意導線としての候補生成補助 | 注文下書き、保存済み印影 |
| Kanji Suggestions | 候補カード表示、選択反映 | `/v1/kanji-candidates` | 候補生成のみ | 注文下書き |
| Customize Seal | Gen UIコンテナ、選択結果と自由入力の検証 | 将来の `/v1/seal-profiles` | 4個の選択質問、短い自由入力、回答要約、印影スタイル条件化 | 注文下書き |
| My Seals | 保存済み印影一覧、編集再開、削除 | なし | なし | 端末内保存 |
| Compare Seals | 2から4件の比較、ベスト案選択 | なし | なし | 端末内保存 |
| Stones | 石一覧、フィルタ、選択 | `/v1/catalog`、`/v1/stone-listings` | 将来の推薦理由生成のみ | 注文下書き |
| Order Review | 配送先、同意、注文確定操作 | `/v1/orders`、Stripe Checkout Session作成 | なし | Firestore、注文下書き |
| Payment Result | 成功/失敗表示、次アクション | Stripe Webhook反映後の注文状態 | なし | Firestore |
| Settings / Legal | 言語切替、About、規約表示 | 必要に応じて公開設定取得 | なし | 端末内設定 |

## Gen UI 導入方針

Gen UIは、印影の好みを聞き出す接客UIとして使う。MVPでは制作・注文・在庫管理の中核には置かず、Customize Seal に限定する。

```text
漢字候補を選択
  -> Customize Seal
      -> Gen UIが質問カードを表示
      -> ユーザーが選択質問と短い自由入力に回答
      -> sealProfileを生成
  -> Preview Seal
```

### Gen UIに任せること

- 質問カードを表示する
- チップ選択UIを表示する
- 短い自由入力フォームを表示する
- 選択回答と自由入力を要約する
- 印影スタイル条件を構造化して返す
- 再調整の選択肢を提案する

### Gen UIに任せないこと

- 名前入力
- 漢字候補の最終表示
- 文字そのものの生成、置換、創作
- 選択済み文字と異なる印影画像の生成
- 素材在庫の判断
- 価格の決定
- カート、注文、決済
- 配送条件の確定
- Firestoreへの直接書き込み

### 質問設計

選択質問は4個に収める。ユーザーに考えさせすぎないことを優先しつつ、角印か丸印かもAIが質問する。最後に短い自由入力フォームを1つ置いて、選択肢だけでは拾えない希望を受け取れるようにする。

| 種別 | 質問 | 選択肢 / 入力 | 保存値 |
| --- | --- | --- | --- |
| 複数選択 | Which words feel most like you? | Calm / Elegant / Bold / Warm / Creative / Mysterious | `calm`、`elegant` など。最大2件 |
| 単一選択 | How would you like the characters to look? | Clear / Balanced / Artistic | `clear`、`balanced`、`artistic` |
| 単一選択 | Which seal shape do you prefer? | Square / Round / Let AI choose | `square`、`round`、`auto` |
| 単一選択 | Which layout do you prefer? | Vertical / Horizontal / Let AI choose | `vertical`、`horizontal`、`auto` |
| 自由入力 | What should this seal express? | 80文字程度までの短文。例: `A calm but confident impression.` | `preferenceNote` |

`shapePreference` が `square` または `round` の場合は、Preview Sealへ進む前に現在の `shape` へ反映する。`auto` の場合は、選択済み文字、レイアウト、石在庫との相性を見て `square` または `round` に解決する。自由入力は必須にしない。空でも次へ進める。

自由入力の扱い:

- 注文情報、住所、配送条件、価格希望は入力させない。
- 入力欄には個人情報を書かないよう短く案内する。
- AIへ渡す場合は印影スタイル生成の補助情報として扱う。
- My Seals の永続保存では、原文ではなく要約タグや `sealProfile.summary` に反映することを優先する。

### Widget Catalog

Gen UIが使ってよい部品は固定する。AIが自由なレイアウトや任意コードを返すのではなく、Flutter側で検証できるJSON DSLとして扱う。

| Widget | 役割 |
| --- | --- |
| `ProgressStepHeader` | 現在の制作ステップを示す |
| `SealQuestionCard` | 質問文と補足を表示する |
| `ChoiceChipGroup` | 単一選択のチップ群 |
| `MultiChoiceChipGroup` | 複数選択のチップ群 |
| `ShortPreferenceInput` | 短い自由入力フォーム |
| `SealStyleSummaryCard` | カスタマイズ回答後のスタイル要約 |
| `SealPreviewCard` | 現在の印影プレビューを表示する |
| `RegenerateOptionCard` | 再調整候補を表示する |
| `PrimaryActionButton` | 次へ進む主要操作 |
| `SecondaryActionButton` | 戻る、スキップなどの補助操作 |

Gen UIから返るUI定義は、必ず `widgetType`、`props`、`actions` を持つ。Flutter側は未知の `widgetType`、未知のaction、許可されていない選択肢を破棄する。

## AI と API の設計

AIは候補生成と要約に限定する。業務ロジック、注文、在庫、価格、決済はRust APIが管理する。

| 役割 | 実装場所 | 出力 |
| --- | --- | --- |
| 漢字候補生成 | Rust API + Gemini | `candidates` |
| Gen UI質問生成 | Flutter内Gen UI基盤、またはRust API | 許可済みWidget DSL |
| 回答から印影スタイルへ変換 | 将来のRust API | `sealProfile` |
| 素材推薦理由生成 | 将来のRust API | 表示用の短い推薦文 |
| 印影プレビュー描画 | Flutter CustomPainter、またはRust API | 決定的なプレビュー画像 |

### 既存API

既存の `/v1/*` を優先し、新しいAI機能も同じ名前空間へ追加する。

| API | 用途 |
| --- | --- |
| `GET /v1/config/public` | 公開設定、ロケール、通貨ポリシー |
| `GET /v1/catalog` | フォント、素材、配送国、公開カタログ |
| `GET /v1/stone-listings` | 一点物石一覧、フィルタ |
| `POST /v1/kanji-candidates` | 名前から漢字候補を生成 |
| `POST /v1/orders` | 注文作成、在庫予約 |
| `POST /v1/payments/stripe/checkout-session` | Stripe Checkout開始 |

### 追加候補API

| API | 用途 | MVPでの扱い |
| --- | --- | --- |
| `POST /v1/seal-profiles` | Customize Sealの回答から印影スタイル条件を生成 | Gen UI導入時に追加 |
| `POST /v1/seal-preview` | API側で印影プレビューを決定的に描画 | Flutter描画で足りない場合に追加 |
| `GET /v1/stone-recommendations` | 選択中の印影に合う石と推薦理由を返す | Stones改善時に追加 |

### AIレスポンス方針

AIの返却値は自由文だけにしない。Flutterで扱いやすいよう、構造化されたJSONにする。

```json
{
  "schemaVersion": 1,
  "summary": "A calm, grounded seal with a balanced vertical layout.",
  "tags": ["grounded", "natural", "calm", "balanced"],
  "shape": "square",
  "layout": "vertical",
  "lineWeight": "medium",
  "stylization": "balanced",
  "fontMood": "traditional",
  "regenerateOptions": [
    "make_more_elegant",
    "make_bolder",
    "try_round_layout"
  ]
}
```

## 状態管理とローカルデータ

状態管理は `miniriverpod` を使い、ナビゲーションは `declarative_nav` を使う。他のナビゲーションライブラリは使わない。

| Provider | 役割 |
| --- | --- |
| `guidedStartProvider` | 初回表示済みフラグ、Guided Startのステップ状態 |
| `sealDesignSessionProvider` | 現在編集中の印影デザイン |
| `kanjiSuggestionsProvider` | 名前から生成された漢字候補 |
| `customizeSealProvider` | カスタマイズ回答、自由入力、sealProfile |
| `sealPreviewProvider` | プレビュー描画に必要な状態 |
| `savedSealDesignsProvider` | 保存済み印影案 |
| `stoneCatalogProvider` | カタログ、素材、一点物石一覧 |
| `stoneSelectionProvider` | 選択中の石とフィルタ状態 |
| `orderDraftProvider` | 注文前の下書き |
| `checkoutProvider` | 注文作成、Checkout開始、送信中状態 |

### SealDesignSession

現在編集中のデザイン状態。注文下書きとして端末内に保存してよいが、My Sealsとして永続保存する内容は個人情報を避ける。

```json
{
  "sessionId": "local_001",
  "sealLine1": "山田",
  "sealLine2": "",
  "selectedKanji": "山田",
  "reading": "Yamada",
  "meaning": "Mountain + Rice Field",
  "kanjiTags": ["steady", "grounded", "natural", "calm"],
  "shape": "square",
  "layout": "vertical",
  "fontKey": "noto_serif_jp",
  "customizeAnswers": {
    "personality": ["calm", "elegant"],
    "characterLook": "balanced",
    "shapePreference": "square",
    "layout": "vertical",
    "preferenceNote": "A calm but confident impression."
  },
  "sealProfile": {
    "summary": "A calm, grounded seal with a balanced vertical layout.",
    "tags": ["grounded", "natural", "calm", "balanced"],
    "lineWeight": "medium",
    "stylization": "balanced"
  },
  "updatedAt": "..."
}
```

### SavedSealDesign

保存済み印影案は、端末内ローカル保存のみとする。名前や配送先などの注文個人情報は保存しない。

```json
{
  "id": "seal_001",
  "sealLine1": "山田",
  "sealLine2": "",
  "reading": "Yamada",
  "meaning": "Mountain + Rice Field",
  "shape": "square",
  "layout": "vertical",
  "fontKey": "noto_serif_jp",
  "kanjiStyle": "japanese",
  "tags": ["grounded", "natural", "calm"],
  "isFavorite": true,
  "createdAt": "...",
  "updatedAt": "..."
}
```

## 印影生成の設計

印影画像は、文字そのものとスタイルを分けて扱う。AIは書体の雰囲気、線の太さ、余白、かすれ、構図、印影らしい崩し方などのスタイルを提案してよい。一方で、印影に入る文字そのものは、ユーザーが選択した既存文字から固定し、AIが別の文字、存在しない文字、疑似文字へ置き換えてはいけない。

```text
ユーザー / Flutter
  -> selectedKanji / sealLine1 / sealLine2 を決める

AI / Gen UI
  -> 好み、タグ、レイアウト条件、書体ムードを決める
  -> 文字そのものは変更しない

Flutter / Rust API
  -> 選択済み文字を検証する
  -> 既存フォント、既存グリフ、または検証済み文字アウトラインを元に印影画像を生成する

Flutter
  -> プレビュー、保存済み印影、注文確認で同じ見た目を表示する
```

この分担により、AIによる表現の幅を残しながら、文字が壊れにくく、再現性があり、注文データや彫刻データへ近づけやすい。

### 文字固定ルール

- 印影に使う文字列の正本は `selectedKanji`、`sealLine1`、`sealLine2` とする。
- AIに渡す場合も、文字列は入力条件として固定し、AIの出力で上書きしない。
- AIは `fontMood`、`lineWeight`、`stylization`、`layout`、`texture`、`margin` などのスタイル値だけを返す。
- 画像生成またはベクター生成を使う場合も、既存文字のグリフ、フォント、アウトライン、または検証済み文字データを元にする。
- 生成後のプレビューは、入力文字列とレンダリング対象文字列が一致していることをAPIまたはFlutter側で検証する。
- 一致しない場合はその画像を破棄し、決定的なフォント描画へフォールバックする。

### 画像生成パイプライン

MVPではFlutterの `CustomPainter` による決定的な描画を基本にする。AIによる書体デザインや画像生成を導入する場合は、以下のように文字固定のレンダリングパイプラインとして扱う。

```text
Customize answers
  -> sealProfile
  -> renderStyle
  -> glyph-locked renderer
  -> previewImage
```

`renderStyle` の例:

```json
{
  "schemaVersion": 1,
  "sourceText": "山田",
  "layout": "vertical",
  "fontMood": "traditional",
  "lineWeight": "medium",
  "stylization": "balanced",
  "texture": "soft_stamp",
  "margin": "normal",
  "cornerTreatment": "slightly_rounded"
}
```

`sourceText` は表示確認用であり、AIの判断で変更してはいけない。Rust APIまたはFlutterは、リクエスト時の `selectedKanji` / `sealLine1` / `sealLine2` と `sourceText` が一致する場合だけレンダリングへ進む。

## デザインシステム

Design Studio、Guided Start、My Seals、Stones、Order Reviewで見た目が分断されないよう、共通コンポーネントとDesign Tokenを固定する。

### Design Token

| Token | 用途 | 値 |
| --- | --- | --- |
| Primary | 主要ボタン、選択状態、印影アクセント | `#A62C2B` |
| Secondary | 本文、見出し、強調テキスト | `#333333` |
| Tertiary | 価格、特別感、素材アクセント | `#C5A059` |
| Neutral | 背景 | `#F7F5F2` |
| Surface | パネル、カード、入力面 | `#FFFFFF` |
| Soft Pink | チップ背景、下部タブ背景 | 既存テーマに合わせて定義 |

### 共通コンポーネント

| Component | 使用画面 |
| --- | --- |
| `SealPreview` | Guided Start、Design Studio、My Seals、Compare、Stones、Order Review |
| `KanjiCard` | Guided Start、Design Studio |
| `StoneCard` | Stones、Order Review |
| `ChoiceChip` | Guided Start、Customize Seal、Filters |
| `PrimaryButton` | 主要CTA |
| `SecondaryButton` | 戻る、スキップ、補助CTA |
| `StepHeader` | Guided Start、Order Review |
| `BottomTabBar` | Design、My Seals、Stones |
| `ScreenHeader` | 各画面 |

## 実装順序

Gen UIに最初から依存しすぎないよう、通常Flutter UIで制作体験を成立させてから、Customize SealだけをGen UI化する。

1. Guided Startのローカル表示済みフラグを追加する。
2. Guided Startを通常Flutter UIで実装し、Design Studioへ状態を引き継ぐ。
3. Design Studio、My Seals、Stonesで `SealPreview` の見た目を揃える。
4. 漢字候補生成をGuided Startにも接続する。
5. Customize Sealの選択質問と短い自由入力を通常Flutter UIで仮実装する。
6. `sealProfile` の構造を固める。
7. Customize SealだけGen UIへ置き換える。
8. 必要に応じて `/v1/seal-profiles` を追加する。
9. 必要に応じて `/v1/seal-preview` を追加する。
10. Stonesに推薦理由を追加する場合は、在庫や価格とは分離して表示文だけAIに生成させる。

## MVP で後回しにするもの

- アカウント登録
- ログイン
- クラウド同期
- 注文履歴
- 専用の Name Ideas 画面
- 専用の Seal Detail 画面
- 専用の Stone Detail 画面
- 高度な紙面モック表示
- ARプレビュー
- SNS共有
- プッシュ通知

## App Store Review 向け説明方針

Stone Signature は、Webサイトの再包装ではなく、ユーザーが自分の personal seal をネイティブUIで設計できるアプリである。購入前でも、印影ライブプレビュー、端末内保存、複数案比較により独立した実用性がある。

初回ダウンロード直後だけ Guided Start を表示し、名前入力、漢字候補選択、短いカスタマイズを通じて最初の印影案を作れるようにする。これはWebコンテンツの紹介ではなく、ネイティブUIで動く制作体験である。

アカウント登録は不要で、保存済み印影案は端末内にのみ保存される。ユーザーは複数の印影案を作成、保存、比較し、気に入った案を天然石の印として注文できる。
