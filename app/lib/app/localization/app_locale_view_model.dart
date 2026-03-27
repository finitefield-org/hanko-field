import 'package:miniriverpod/miniriverpod.dart';

import '../../features/order/domain/order_models.dart';
import '../config/app_runtime_config.dart';

enum AppLocale {
  ja,
  en;

  String get code {
    return switch (this) {
      AppLocale.ja => 'ja',
      AppLocale.en => 'en',
    };
  }

  String get displayLabel {
    return switch (this) {
      AppLocale.ja => '日本語',
      AppLocale.en => 'English',
    };
  }

  static AppLocale fromCode(String code) {
    return normalizeUiLocale(code) == 'en' ? AppLocale.en : AppLocale.ja;
  }
}

class AppLocaleViewModel extends Provider<AppLocale> {
  AppLocaleViewModel() : super.args(null);

  @override
  AppLocale build(Ref ref) {
    final runtime = ref.watch(appRuntimeConfigProvider);
    return AppLocale.fromCode(runtime.preferredLocale);
  }

  late final selectLocaleMut = mutation<void>(#selectLocale);

  Call<void, AppLocale> selectLocale(AppLocale locale) {
    return mutate(selectLocaleMut, (ref) async {
      final current = ref.watch(this);
      if (current == locale) {
        return;
      }
      ref.state = locale;
    });
  }
}

final appLocaleViewModel = AppLocaleViewModel();

String privacyPolicyUrlForLocaleCode(String code) {
  final locale = normalizeUiLocale(code);
  if (locale == 'ja') {
    return 'https://finitefield.org/privacy/';
  }
  return 'https://finitefield.org/$locale/privacy/';
}

String privacyPolicyUrlForLocale(AppLocale locale) {
  return privacyPolicyUrlForLocaleCode(locale.code);
}

String inquiryUrlForLocaleCode(String code) {
  final locale = normalizeUiLocale(code);
  if (locale == 'ja') {
    return 'https://finitefield.org/inquiry/';
  }
  return 'https://finitefield.org/$locale/inquiry/';
}

String inquiryUrlForLocale(AppLocale locale) {
  return inquiryUrlForLocaleCode(locale.code);
}

String commercialTransactionsUrlForLocaleCode(String code) {
  final locale = normalizeUiLocale(code);
  return 'https://finitefield.org/commercial-transactions?lang=$locale';
}

String commercialTransactionsUrlForLocale(AppLocale locale) {
  return commercialTransactionsUrlForLocaleCode(locale.code);
}
