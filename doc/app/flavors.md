# Flutter flavors, icons, and splash setup (dev/stg/prod)
Targets: Flutter app with three flavors and branded launch assets.

## Flavor definitions
- Flavors: `dev`, `stg`, `prod`.
- Package IDs:
  - Android `applicationId`: `com.hanko.field.dev`, `com.hanko.field.stg`, `com.hanko.field`.
  - iOS bundle IDs: `com.hanko.field.dev`, `com.hanko.field.stg`, `com.hanko.field`.
- App display names: `Hanko Field Dev`, `Hanko Field Stg`, `Hanko Field`.
- Deep link schemes (align with navigation doc): `hanko-dev`, `hanko-stg`, `hanko`.

## Entry points
Create separate entry files that set a flavor flag/env and call the shared bootstrap.
```
lib/main.dart          # defaults to prod
lib/main_dev.dart      # sets flavor=dev
lib/main_stg.dart      # sets flavor=stg
lib/bootstrap.dart     # runApp, ProviderScope overrides per flavor
```

Example snippet:
```dart
import 'bootstrap.dart';

void main() {
  bootstrap(flavor: Flavor.prod);
}
```

## Android configuration
- `android/app/build.gradle`:
  - Define `productFlavors` with `applicationIdSuffix` for dev/stg, and `resValue` for app name.
  - Set `manifestPlaceholders` for intent-filter scheme per flavor.
  - Use `buildConfigField` for API base URL, feature flag endpoints, and flavor string.
- `AndroidManifest.xml`:
  - Intent filters for deep links use `${appAuthScheme}` placeholder.
  - Add `android:exported` on activities (Flutter 3 requirement).
- Keystores: debug uses default; release per flavor stored in CI secrets.

## iOS configuration
- Create schemes/targets per flavor or use xcconfigs:
  - `Runner-dev`, `Runner-stg`, `Runner` (prod).
  - Bundle ID per flavor; set `PRODUCT_BUNDLE_IDENTIFIER`.
  - Add URL Type for deep link scheme (`hanko-dev`, `hanko-stg`, `hanko`).
  - Set `APP_DISPLAY_NAME` via `Info.plist` or build settings.
- Use `Configurations` (`Debug-Dev`, `Debug-Stg`, `Release-Prod`) and map to schemes.

## Icons and splash
- Add to `pubspec.yaml`:
  ```yaml
  dev_dependencies:
    flutter_launcher_icons: ^0.14.1
    flutter_native_splash: ^2.4.1

  flutter_icons:
    android: true
    ios: true
    image_path: assets/branding/icon.png
    adaptive_icon_background: "#FFFFFF"
    adaptive_icon_foreground: assets/branding/icon-foreground.png

  flutter_native_splash:
    color: "#FFFFFF"
    image: assets/branding/splash.png
    android_12:
      image: assets/branding/splash-android12.png
      icon_background_color: "#FFFFFF"
    web: false
  ```
- Run generators per flavor after assets exist:
  - `flutter pub run flutter_launcher_icons -f pubspec.yaml`
  - `flutter pub run flutter_native_splash:create`
- Provide flavor-specific icons if needed by running generator with alternate config files (e.g., `pubspec_dev.yaml`).

## Build/run commands
- `flutter run --flavor dev -t lib/main_dev.dart`
- `flutter run --flavor stg -t lib/main_stg.dart`
- `flutter run --flavor prod -t lib/main.dart`
- Android bundle: `flutter build appbundle --flavor prod -t lib/main.dart`
- iOS: `flutter build ipa --flavor prod -t lib/main.dart`

## CI notes
- Cache `flutter pub get`; run `flutter analyze`/`flutter test` once (no flavor-specific tests unless needed).
- Build matrix per flavor for release artifacts; inject env via `--dart-define` or flavor-specific config files.
- Ensure signing keys/Profiles provided via CI secrets for prod; dev/stg can use ad-hoc.

## To-do after assets arrive
- Add actual branding files under `assets/branding/`.
- Wire firebase/google-services per flavor (separate `google-services.json`/`GoogleService-Info.plist`).
- Verify deep link intent filters/URL Types with QA for all schemes.
