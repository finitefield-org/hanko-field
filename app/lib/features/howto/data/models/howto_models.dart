// ignore_for_file: public_member_api_docs

class HowtoVideo {
  const HowtoVideo({
    required this.id,
    required this.titleJa,
    required this.titleEn,
    required this.summaryJa,
    required this.summaryEn,
    required this.youtubeUrl,
    required this.durationLabel,
    this.topicJa,
    this.topicEn,
    this.isFeatured = false,
  });

  final String id;
  final String titleJa;
  final String titleEn;
  final String summaryJa;
  final String summaryEn;
  final String youtubeUrl;
  final String durationLabel;
  final String? topicJa;
  final String? topicEn;
  final bool isFeatured;

  String title({required bool prefersEnglish}) =>
      prefersEnglish ? titleEn : titleJa;

  String summary({required bool prefersEnglish}) =>
      prefersEnglish ? summaryEn : summaryJa;

  String topic({required bool prefersEnglish}) {
    final fallback = prefersEnglish ? 'Tutorials' : 'チュートリアル';
    final value = prefersEnglish ? topicEn : topicJa;
    return (value == null || value.trim().isEmpty) ? fallback : value.trim();
  }
}
