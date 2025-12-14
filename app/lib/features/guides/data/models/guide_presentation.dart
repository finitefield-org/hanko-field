// ignore_for_file: public_member_api_docs

import 'package:app/features/content/data/models/content_models.dart';

String guideTopicLabel(GuideCategory category, {required bool prefersEnglish}) {
  return switch (category) {
    GuideCategory.culture => prefersEnglish ? 'Culture' : '文化',
    GuideCategory.howto => prefersEnglish ? 'How-to' : '使い方',
    GuideCategory.policy => prefersEnglish ? 'Policy' : '規約',
    GuideCategory.faq => 'FAQ',
    GuideCategory.news => prefersEnglish ? 'News' : 'お知らせ',
    GuideCategory.other => prefersEnglish ? 'Other' : 'その他',
  };
}

GuideTranslation guideTranslationForLang(Guide guide, String lang) {
  final normalized = lang.trim().toLowerCase();
  return guide.translations[normalized] ??
      guide.translations[normalized.split('-').first] ??
      guide.translations.values.first;
}

String guideReadingTimeLabel(Guide guide, {required bool prefersEnglish}) {
  final minutes = guide.readingTimeMinutes;
  if (minutes == null || minutes <= 0) {
    return prefersEnglish ? 'Quick read' : 'すぐ読める';
  }
  return '$minutes min';
}
