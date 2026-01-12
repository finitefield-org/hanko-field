# hanko-field
このレポジトリは、Hanko Field のフロントエンド、バックエンド、管理画面を管理するためのものです。

全体の設計は `doc/design.md` を参照してください。

## フォルダ構成

```
/
├── app/ # Flutterアプリ
├── api/ # Go API
├── admin/ # 管理画面 (Go)
├── web/ # ウェブ (Go)
├── doc/ # ドキュメント
├── doc/db/db_design.md # データベース設計
├── doc/db/schema/*.md # データスキーマ
├── doc/api/api_design.md # API設計
├── doc/api/tasks/*.md # APIタスク
├── doc/app/app_design.md # アプリ設計
├── doc/app/tasks/*.md # アプリタスク
├── doc/web/web_design.md # ウェブ設計
├── doc/admin/admin_design.md # 管理画面設計
├── doc/admin/tasks/*.md # 管理画面タスク
├── doc/web/web_design.md # ウェブ設計
├── doc/web/tasks/*.md # ウェブタスク
├── doc/customer_journey/persona.md # ペルソナ
├── doc/customer_journey/customer_journey_map.md # カスタマージャーニーマップ
```

## 管理画面(admin)
- Go
- htmx
- Tailwind CSS

## バックエンド(api)
- Go
- Cloud Run
- Firestore
- Firebase Auth
- Firebase Storage

## ウェブ(web)
- Go
- htmx
- Tailwind CSS

## アプリ(app)
- Flutter
  - doc/app/app_design.md を参照してください。
  - doc/app/navigation.md を参照してください。
- MVVM + feature-first architecture
  - doc/app/architecture.md を参照してください。
- miniriverpod
  - 使い方については、../../miniriverpod/miniriverpod/README.md を参照してください。
  - doc/app/miniriverpod-guidelines.md も参照してください。

## タスクについて
- タスクが終了したらチェックを入れること。


## 編集不可項目
- miniriverpod自体を変更してはいけません。
- declarative_nav 自体を変更してはいけません。
