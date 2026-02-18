# ハンコフィールド

ハンコフィールドは、アプリでユーザが自分の印鑑をデザインし、注文できるサービスです。

- アプリフレームワーク: Flutter
- ウェブ: Cloud Run (Rust)
- 管理画面: Cloud Run (Rust)
- データベース: Firestore
- API: Cloud Run (Rust)
- ストレージ: Firebase Storage
- 認証: Firebase Auth
- 支払い: Stripe
- 管理画面/ウェブ: ポーリングやストリーミング（SSE / WebSocket 等）を実装しない
- 対応言語: 日本語（`ja`）/ 英語（`en`）を初期対応し、追加可能な多言語設計にする

## 関連ドキュメント
- Firebase Firestore 設計（本番向け・多言語対応）: `doc/firebase-firestore-design.md`

## タスク
- [x] 管理画面（`admin`）の初期モック実装を追加
- [x] 管理画面（`admin`）で `mock` / `dev` / `prod` のデータソース切替を追加
- [x] `api` / `admin` / `web` の実装言語を Rust に統一
- [x] 管理画面（`admin`）を注文管理・材質マスタ・材質マスタ編集のページに分割
