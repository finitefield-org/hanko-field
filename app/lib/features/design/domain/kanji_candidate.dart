class KanjiCandidatesRequest {
  const KanjiCandidatesRequest({
    required this.realName,
    this.reasonLanguage = 'en',
    this.gender = KanjiCandidateGender.unspecified,
    this.kanjiStyle = KanjiNameStyle.japanese,
    this.count = 5,
  });

  final String realName;
  final String reasonLanguage;
  final KanjiCandidateGender gender;
  final KanjiNameStyle kanjiStyle;
  final int count;
}

class KanjiCandidatesResult {
  const KanjiCandidatesResult({
    required this.realName,
    required this.reasonLanguage,
    required this.gender,
    required this.kanjiStyle,
    required this.candidates,
  });

  final String realName;
  final String reasonLanguage;
  final KanjiCandidateGender gender;
  final KanjiNameStyle kanjiStyle;
  final List<KanjiCandidate> candidates;
}

class KanjiCandidate {
  const KanjiCandidate({
    required this.kanji,
    required this.reading,
    required this.reason,
    this.meaning,
    this.impression = const [],
    this.characterCount,
    this.strokeComplexity,
    this.engravingSuitability,
  });

  final String kanji;
  final String reading;
  final String reason;
  final String? meaning;
  final List<String> impression;
  final int? characterCount;
  final String? strokeComplexity;
  final String? engravingSuitability;
}

enum KanjiCandidateGender {
  unspecified,
  male,
  female;

  String get apiValue => name;

  static KanjiCandidateGender fromApiValue(String value) {
    return switch (value) {
      'male' => KanjiCandidateGender.male,
      'female' => KanjiCandidateGender.female,
      _ => KanjiCandidateGender.unspecified,
    };
  }
}

enum KanjiNameStyle {
  japanese,
  chinese,
  taiwanese;

  String get apiValue => name;

  static KanjiNameStyle fromApiValue(String value) {
    return switch (value) {
      'chinese' => KanjiNameStyle.chinese,
      'taiwanese' => KanjiNameStyle.taiwanese,
      _ => KanjiNameStyle.japanese,
    };
  }
}
