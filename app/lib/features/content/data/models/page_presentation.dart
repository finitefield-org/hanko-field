// ignore_for_file: public_member_api_docs

import 'package:app/features/content/data/models/content_models.dart';

PageTranslation pageTranslationForLang(PageContent page, String lang) {
  final normalized = lang.trim().toLowerCase();
  return page.translations[normalized] ??
      page.translations[normalized.split('-').first] ??
      page.translations.values.first;
}
