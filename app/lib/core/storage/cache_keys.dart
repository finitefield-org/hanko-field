// ignore_for_file: public_member_api_docs

class LocalCacheKey {
  const LocalCacheKey(this.value, {this.tags = const []});

  final String value;
  final List<String> tags;
}

class LocalCacheKeys {
  const LocalCacheKeys._();

  static LocalCacheKey designsList({String persona = 'default'}) {
    return LocalCacheKey('designs/list/$persona', tags: ['designs', persona]);
  }

  static LocalCacheKey designDetail(String designId) {
    return LocalCacheKey(
      'designs/$designId',
      tags: ['designs', 'design:$designId'],
    );
  }

  static const cart = LocalCacheKey('cart/current', tags: ['cart']);

  static LocalCacheKey guides({String locale = 'default'}) {
    return LocalCacheKey('guides/$locale', tags: ['guides', locale]);
  }

  static LocalCacheKey notifications({String userId = 'current'}) {
    return LocalCacheKey(
      'notifications/$userId',
      tags: ['notifications', userId],
    );
  }

  static const onboarding = LocalCacheKey(
    'onboarding/state',
    tags: ['onboarding'],
  );
}
