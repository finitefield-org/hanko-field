// ignore_for_file: public_member_api_docs

const _flavorKey = 'APP_FLAVOR';

enum AppFlavor { dev, prod }

AppFlavor appFlavorFromEnvironment() {
  const value = String.fromEnvironment(_flavorKey, defaultValue: 'prod');
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
