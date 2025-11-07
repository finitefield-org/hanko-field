import 'package:flutter/foundation.dart';

@immutable
class KanjiCandidate {
  const KanjiCandidate({
    required this.id,
    required this.character,
    required this.meanings,
    required this.readings,
    required this.popularityScore,
    required this.strokeCount,
    required this.radicalCategory,
    required this.gradeLevel,
    this.story,
    this.alternateForms = const [],
    this.usageExamples = const [],
    this.strokeOrderHints = const [],
  });

  final String id;
  final String character;
  final List<String> meanings;
  final List<String> readings;
  final int popularityScore;
  final int strokeCount;
  final KanjiRadicalCategory radicalCategory;
  final KanjiGradeLevel gradeLevel;
  final String? story;
  final List<String> alternateForms;
  final List<String> usageExamples;
  final List<String> strokeOrderHints;

  bool get isFrequentlyUsed => popularityScore >= 4;

  Map<String, Object?> toSerializableMap() {
    return {
      'id': id,
      'character': character,
      'meanings': meanings,
      'readings': readings,
      'popularity': popularityScore,
      'strokes': strokeCount,
      'radical': radicalCategory.name,
      'gradeLevel': gradeLevel.name,
      'story': story,
      'alternateForms': alternateForms,
      'usageExamples': usageExamples,
      'strokeOrderHints': strokeOrderHints,
    };
  }

  factory KanjiCandidate.fromSerializableMap(Map<String, dynamic> json) {
    return KanjiCandidate(
      id: json['id'] as String,
      character: json['character'] as String,
      meanings: (json['meanings'] as List<dynamic>)
          .map((value) => value as String)
          .toList(growable: false),
      readings: (json['readings'] as List<dynamic>)
          .map((value) => value as String)
          .toList(growable: false),
      popularityScore: json['popularity'] as int,
      strokeCount: json['strokes'] as int,
      radicalCategory: KanjiRadicalCategory.values.byName(
        json['radical'] as String,
      ),
      gradeLevel: json['gradeLevel'] == null
          ? KanjiGradeLevel.custom
          : KanjiGradeLevel.values.byName(json['gradeLevel'] as String),
      story: json['story'] as String?,
      alternateForms: (json['alternateForms'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList(growable: false),
      usageExamples: (json['usageExamples'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList(growable: false),
      strokeOrderHints: (json['strokeOrderHints'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList(growable: false),
    );
  }
}

enum KanjiGradeLevel {
  grade1('Grade 1'),
  grade2('Grade 2'),
  grade3('Grade 3'),
  grade4('Grade 4'),
  grade5('Grade 5'),
  grade6('Grade 6'),
  jinmeiyo('Jinmeiyō'),
  custom('Custom');

  const KanjiGradeLevel(this.label);

  final String label;

  String get analyticsId => switch (this) {
    KanjiGradeLevel.grade1 => 'grade_1',
    KanjiGradeLevel.grade2 => 'grade_2',
    KanjiGradeLevel.grade3 => 'grade_3',
    KanjiGradeLevel.grade4 => 'grade_4',
    KanjiGradeLevel.grade5 => 'grade_5',
    KanjiGradeLevel.grade6 => 'grade_6',
    KanjiGradeLevel.jinmeiyo => 'grade_jinmeiyo',
    KanjiGradeLevel.custom => 'grade_custom',
  };
}

enum KanjiStrokeBucket {
  upToFive(1, 5, '1-5'),
  sixToTen(6, 10, '6-10'),
  elevenToFifteen(11, 15, '11-15'),
  sixteenPlus(16, null, '16+');

  const KanjiStrokeBucket(this.min, this.max, this.label);

  final int min;
  final int? max;
  final String label;

  bool matches(int strokeCount) {
    if (strokeCount < min) {
      return false;
    }
    if (max == null) {
      return true;
    }
    return strokeCount <= max!;
  }

  String get analyticsId => switch (this) {
    KanjiStrokeBucket.upToFive => 'strokes_1_5',
    KanjiStrokeBucket.sixToTen => 'strokes_6_10',
    KanjiStrokeBucket.elevenToFifteen => 'strokes_11_15',
    KanjiStrokeBucket.sixteenPlus => 'strokes_16_plus',
  };
}

enum KanjiRadicalCategory {
  person('person', '亻'),
  water('water', '氵'),
  wood('wood', '木'),
  hand('hand', '扌'),
  heart('heart', '忄'),
  speech('speech', '言'),
  fire('fire', '火');

  const KanjiRadicalCategory(this.analyticsId, this.radicalGlyph);

  final String analyticsId;
  final String radicalGlyph;

  String get displayLabel => switch (this) {
    KanjiRadicalCategory.person => 'Person',
    KanjiRadicalCategory.water => 'Water',
    KanjiRadicalCategory.wood => 'Wood',
    KanjiRadicalCategory.hand => 'Hand',
    KanjiRadicalCategory.heart => 'Heart',
    KanjiRadicalCategory.speech => 'Speech',
    KanjiRadicalCategory.fire => 'Fire',
  };
}

class KanjiCandidateResponse {
  KanjiCandidateResponse({
    required List<KanjiCandidate> candidates,
    required this.generatedAt,
    this.query,
    Set<KanjiStrokeBucket> appliedStrokeFilters = const <KanjiStrokeBucket>{},
    Set<KanjiRadicalCategory> appliedRadicalFilters =
        const <KanjiRadicalCategory>{},
  }) : candidates = List.unmodifiable(candidates),
       appliedStrokeFilters = Set.unmodifiable(appliedStrokeFilters),
       appliedRadicalFilters = Set.unmodifiable(appliedRadicalFilters);

  final List<KanjiCandidate> candidates;
  final DateTime generatedAt;
  final String? query;
  final Set<KanjiStrokeBucket> appliedStrokeFilters;
  final Set<KanjiRadicalCategory> appliedRadicalFilters;

  Map<String, Object?> toSerializableMap() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'query': query,
      'strokeFilters':
          appliedStrokeFilters.map((bucket) => bucket.name).toList()..sort(),
      'radicalFilters':
          appliedRadicalFilters.map((radical) => radical.name).toList()..sort(),
      'candidates': candidates
          .map((candidate) => candidate.toSerializableMap())
          .toList(growable: false),
    };
  }

  factory KanjiCandidateResponse.fromSerializableMap(
    Map<String, dynamic> json,
  ) {
    return KanjiCandidateResponse(
      candidates: (json['candidates'] as List<dynamic>)
          .map(
            (item) => KanjiCandidate.fromSerializableMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      query: json['query'] as String?,
      appliedStrokeFilters:
          (json['strokeFilters'] as List<dynamic>? ?? const [])
              .map((name) => KanjiStrokeBucket.values.byName(name as String))
              .toSet(),
      appliedRadicalFilters:
          (json['radicalFilters'] as List<dynamic>? ?? const [])
              .map((name) => KanjiRadicalCategory.values.byName(name as String))
              .toSet(),
    );
  }
}
