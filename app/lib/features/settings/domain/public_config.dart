class PublicConfig {
  const PublicConfig({
    required this.supportedLocales,
    required this.defaultLocale,
    required this.defaultCurrency,
    required this.currencyByLocale,
  });

  final List<String> supportedLocales;
  final String defaultLocale;
  final String defaultCurrency;
  final Map<String, String> currencyByLocale;

  String currencyForLocale(String locale) {
    return currencyByLocale[locale] ?? defaultCurrency;
  }
}
