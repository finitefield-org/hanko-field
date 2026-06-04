# STONE SIGNATURE

STONE SIGNATURE の Flutter アプリです。

リリースビルドでは、API 経由で本番 Firestore と本番 Stripe を使います。
必要に応じて `HANKO_API_BASE_URL` で API の URL を上書きできます。

## ローカル API 接続

デザイン画面の漢字提案、印影生成、石一覧、注文作成は API へ接続します。
シミュレータで確認する前にリポジトリ直下で API を起動してください。

```bash
make docker-up ENV=dev
make docker-api ENV=dev
```

Flutter アプリの既定の接続先は次の通りです。

- iOS Simulator: `http://127.0.0.1:3050`
- Android Emulator: `http://10.0.2.2:3050`

別の API に接続する場合:

```bash
flutter run --dart-define=HANKO_API_BASE_URL=https://your-api.example.com
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
