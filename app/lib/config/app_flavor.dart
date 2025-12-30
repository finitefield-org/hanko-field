// ignore_for_file: public_member_api_docs

const _flavorKey = 'APP_FLAVOR';
const _flutterAppFlavorKey = 'FLUTTER_APP_FLAVOR';

enum AppFlavor { dev, prod }

AppFlavor appFlavorFromEnvironment() {
  // Prefer an explicit, app-owned define.
  const explicit = String.fromEnvironment(_flavorKey, defaultValue: '');
  if (explicit.isNotEmpty) {
    return _parseFlavor(explicit);
  }

  // Flutter sets this automatically when you pass `--flavor <name>`.
  // This allows:
  //   flutter run --flavor dev
  // without having to also pass `--dart-define=APP_FLAVOR=dev` or `-t`.
  const flutterFlavor = String.fromEnvironment(
    _flutterAppFlavorKey,
    defaultValue: '',
  );
  if (flutterFlavor.isNotEmpty) {
    return _parseFlavor(flutterFlavor);
  }

  return AppFlavor.prod;
}

AppFlavor _parseFlavor(String value) {
  switch (value.toLowerCase()) {
    case 'dev':
      return AppFlavor.dev;
    case 'prod':
    case 'production':
    default:
      return AppFlavor.prod;
  }
}

extension AppFlavorX on AppFlavor {
  String get name {
    switch (this) {
      case AppFlavor.dev:
        return 'dev';
      case AppFlavor.prod:
        return 'prod';
    }
  }

  String get displayLabel {
    switch (this) {
      case AppFlavor.dev:
        return 'Hanko Field Dev';
      case AppFlavor.prod:
        return 'Hanko Field';
    }
  }

  String get firebaseAppName => 'hanko-field';

  String get firestoreDatabaseId {
    switch (this) {
      case AppFlavor.dev:
        return '(default)';
      case AppFlavor.prod:
        return 'prod';
    }
  }
}
