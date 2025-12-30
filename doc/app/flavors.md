# Flutter flavors, icons, and splash setup (dev/prod)
Targets: Flutter app with dev/prod flavors and branded launch assets.

## Flavor definitions
- Flavors: `dev`, `prod`.
- Package IDs:
  - Android `applicationId`: `org.finitefield.hanko` (dev/prod share the same for now; see note below).
  - iOS bundle IDs: `org.finitefield.hanko` (dev/prod share the same for now; see note below).
- App display names: `Hanko Field Dev`, `Hanko Field`.
- Deep link schemes (align with navigation doc): `hanko-dev`, `hanko`.

Note:
- The repo currently has a single checked-in `google-services.json` for Android (`org.finitefield.hanko`).
- If you want side-by-side installs (e.g. `org.finitefield.hanko.dev`), add a separate Firebase Android app for that package and place a matching `google-services.json` under `android/app/src/dev/google-services.json` (and similarly for other flavors).

## Entry points
Use a single entry file and select the flavor via launch arguments.
```
lib/main.dart          # flavor is resolved from args (APP_FLAVOR / --flavor)
lib/bootstrap.dart     # runApp, ProviderScope overrides per flavor
```

Example snippet:
```dart
import 'package:app/bootstrap.dart';
import 'package:app/config/app_flavor.dart';

Future<void> main() => bootstrap(flavor: appFlavorFromEnvironment());
```

## Android configuration
- `android/app/build.gradle`:
  - Define `productFlavors` (dev/prod) and `resValue` for app name.
  - Set `manifestPlaceholders` for intent-filter scheme per flavor.
  - Use `buildConfigField` for API base URL, feature flag endpoints, and flavor string.
- `AndroidManifest.xml`:
  - Intent filters for deep links use `${appAuthScheme}` placeholder.
  - Add `android:exported` on activities (Flutter 3 requirement).
- Keystores: debug uses default; release per flavor stored in CI secrets.

## iOS configuration
- Create schemes/targets per flavor or use xcconfigs:
  - `Runner-dev`, `Runner` (prod).
  - Bundle ID per flavor; set `PRODUCT_BUNDLE_IDENTIFIER`.
  - Add URL Type for deep link scheme (`hanko-dev`, `hanko`).
  - Set `APP_DISPLAY_NAME` via `Info.plist` or build settings.
- Use `Configurations` (`Debug-Dev`, `Release-Prod`) and map to schemes.

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
- `flutter run --flavor dev --dart-define=APP_FLAVOR=dev`
- `flutter run --flavor prod --dart-define=APP_FLAVOR=prod`
- Android bundle: `flutter build appbundle --flavor prod --dart-define=APP_FLAVOR=prod`
- iOS: `flutter build ipa --flavor prod --dart-define=APP_FLAVOR=prod`

## CI notes
- Cache `flutter pub get`; run `flutter analyze`/`flutter test` once (no flavor-specific tests unless needed).
- Build matrix per flavor for release artifacts; inject env via `--dart-define` or flavor-specific config files.
- Ensure signing keys/Profiles provided via CI secrets for prod; dev can use ad-hoc.

## To-do after assets arrive
- Add actual branding files under `assets/branding/`.
- Wire firebase/google-services per flavor (separate `google-services.json`/`GoogleService-Info.plist`).
- Verify deep link intent filters/URL Types with QA for all schemes.
