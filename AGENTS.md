# hanko-field
このレポジトリは、Hanko Field のフロントエンド、バックエンド、管理画面を管理するためのものです。

全体の設計は `doc/design.md` を参照してください。

## フォルダ構成

```
/
├── app/ # Flutterアプリ
├── api/ # Rust API
├── admin/ # 管理画面 (Rust)
├── web/ # ウェブ (Rust)
├── doc/ # ドキュメント
```

## 管理画面(admin)
- Rust
- htmx
- ironframe (Tailwind CSS v4.1 clone crate in Rust)
- テンプレートエンジンは `askama` crate を使用すること。
- **ポリシー**: 管理画面ではポーリングやストリーミング（SSE / WebSocket 等）を実装しないこと。

## バックエンド(api)
- Rust
- Cloud Run
- Firestore
- Firebase Auth
- Firebase Storage

## ウェブ(web)
- Rust
- htmx
- ironframe (Tailwind CSS v4.1 clone crate in Rust)
- Firebase 連携は `firebase-sdk-rust` crate（`/Users/kazuyoshitoshiya/Documents/GitHub/firebase-sdk-rust`）を使用すること。
- テンプレートエンジンは `askama` crate を使用すること。
- **ポリシー**: ユーザ向けウェブ画面ではポーリングやストリーミング（SSE / WebSocket 等）を実装しないこと。

## アプリ(app)
- Flutter
- MVVM + feature-first architecture
- miniriverpod
- declarative_nav
  - Do NOT use any other navigation library such as go_router.

## タスクについて
- タスクが終了したらチェックを入れること。
