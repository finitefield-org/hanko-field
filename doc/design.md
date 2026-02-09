# ハンコフィールド

ハンコフィールドは、アプリでユーザが自分の印鑑をデザインし、注文できるサービスです。

- アプリフレームワーク: Flutter
- ウェブ: Cloud Run (Go)
- 管理画面: Cloud Run (Go)
- データベース: Firestore
- API: Cloud Run (Go)
- ストレージ: Firebase Storage
- 認証: Firebase Auth
- 支払い: Stripe
- 管理画面/ウェブ: ポーリングやストリーミング（SSE / WebSocket 等）を実装しない
- 対応言語: 日本語（`ja`）/ 英語（`en`）を初期対応し、追加可能な多言語設計にする

## 関連ドキュメント
- Firebase Firestore 設計（本番向け・多言語対応）: `doc/firebase-firestore-design.md`
