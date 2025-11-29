# Firebase setup (Auth, Messaging, Remote Config)

Firebase is wired for all flavors via FlutterFire packages. Update the options file and native configs per environment before running on devices.

## Flavor mapping
- Flavors: `dev`, `stg`, `prod`
- Android IDs: `com.hanko.field.dev`, `com.hanko.field.stg`, `com.hanko.field`
- iOS bundle IDs: `com.hanko.field.dev`, `com.hanko.field.stg`, `com.hanko.field`

## Configure projects with FlutterFire
Run the CLI once per flavor and copy the generated options into `app/lib/firebase/firebase_options.dart` (replace the placeholder values).

```bash
# Dev
flutterfire configure \
  --project <firebase-dev-project-id> \
  --ios-bundle-id com.hanko.field.dev \
  --android-package-name com.hanko.field.dev \
  --platforms ios,android \
  --out lib/firebase/firebase_options_dev.dart

# Staging
flutterfire configure \
  --project <firebase-stg-project-id> \
  --ios-bundle-id com.hanko.field.stg \
  --android-package-name com.hanko.field.stg \
  --platforms ios,android \
  --out lib/firebase/firebase_options_stg.dart

# Prod
flutterfire configure \
  --project <firebase-prod-project-id> \
  --ios-bundle-id com.hanko.field \
  --android-package-name com.hanko.field \
  --platforms ios,android \
  --out lib/firebase/firebase_options_prod.dart
```

Copy each platform section from the generated files into `lib/firebase/firebase_options.dart` so that `DefaultFirebaseOptions.currentPlatform(flavor)` returns the right values.

## Native config files
- Android: place `google-services.json` under `android/app/src/dev`, `android/app/src/stg`, and `android/app/src/prod` to match the product flavors.
- iOS: add a scheme/xcconfig per flavor that points to the correct `GoogleService-Info.plist` (e.g., `Runner-dev`, `Runner-stg`, `Runner`). Ensure the plist bundle IDs match the flavor IDs above.
- APNs: upload the APNs key/cert to Firebase for Messaging; keep `UIBackgroundModes: remote-notification` enabled in `ios/Runner/Info.plist`.

## Run commands per flavor
Always pass the dart-define so background messaging uses the right Firebase app:
- Dev: `flutter run --flavor dev -t lib/main_dev.dart --dart-define=APP_FLAVOR=dev`
- Stg: `flutter run --flavor stg -t lib/main_stg.dart --dart-define=APP_FLAVOR=stg`
- Prod: `flutter run --flavor prod -t lib/main.dart --dart-define=APP_FLAVOR=prod`

## Messaging notes
- Background handler: `lib/firebase/messaging.dart` registers `firebaseMessagingBackgroundHandler` for push payloads.
- Permissions: Android manifest includes `POST_NOTIFICATIONS`; iOS uses `UNUserNotificationCenter` delegate in `AppDelegate` and requests permission in Dart.
- Foreground display: `FirebaseMessaging.setForegroundNotificationPresentationOptions` is enabled for iOS/macOS.

## Remote Config defaults
- Defaults live in `lib/firebase/remote_config.dart` (feature toggles + min supported versions).
- Fetch timeout: 10s, minimum interval: 30m. Initialization runs during app bootstrap.

## Auth
- `FirebaseAuth` is initialized off the shared `FirebaseApp` and exposed via `firebaseAuthProvider`. No providers are enabled in Firebase Console by default; enable Apple/Google/Email and set redirect URIs before shipping builds.
