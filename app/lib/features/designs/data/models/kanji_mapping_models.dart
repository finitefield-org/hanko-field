// ignore_for_file: public_member_api_docs

import 'package:collection/collection.dart';

class KanjiCandidate {
  const KanjiCandidate({
    required this.id,
    required this.glyph,
    required this.meaning,
    required this.pronunciation,
    required this.popularity,
    required this.strokeCount,
    required this.radical,
    this.keywords = const <String>[],
  });

  final String id;
  final String glyph;
  final String meaning;
  final String pronunciation;
  final double popularity;
  final int strokeCount;
  final String radical;
  final List<String> keywords;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'glyph': glyph,
      'meaning': meaning,
      'pronunciation': pronunciation,
      'popularity': popularity,
      'strokeCount': strokeCount,
      'radical': radical,
      'keywords': keywords,
    };
  }

  factory KanjiCandidate.fromJson(Map<String, Object?> json) {
    return KanjiCandidate(
      id: json['id'] as String,
      glyph: json['glyph'] as String,
      meaning: json['meaning'] as String,
      pronunciation: json['pronunciation'] as String,
      popularity: (json['popularity'] as num).toDouble(),
      strokeCount: (json['strokeCount'] as num).toInt(),
      radical: json['radical'] as String,
      keywords:
          (json['keywords'] as List?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }

  KanjiCandidate copyWith({
    String? id,
    String? glyph,
    String? meaning,
    String? pronunciation,
    double? popularity,
    int? strokeCount,
    String? radical,
    List<String>? keywords,
  }) {
    return KanjiCandidate(
      id: id ?? this.id,
      glyph: glyph ?? this.glyph,
      meaning: meaning ?? this.meaning,
      pronunciation: pronunciation ?? this.pronunciation,
      popularity: popularity ?? this.popularity,
      strokeCount: strokeCount ?? this.strokeCount,
      radical: radical ?? this.radical,
      keywords: keywords ?? this.keywords,
    );
  }

  @override
  bool operator ==(Object other) {
    final listEq = const ListEquality<String>();
    return identical(this, other) ||
        (other is KanjiCandidate &&
            other.id == id &&
            other.glyph == glyph &&
            other.meaning == meaning &&
            other.pronunciation == pronunciation &&
            other.popularity == popularity &&
            other.strokeCount == strokeCount &&
            other.radical == radical &&
            listEq.equals(other.keywords, keywords));
  }

  @override
  int get hashCode {
    final listEq = const ListEquality<String>();
    return Object.hash(
      id,
      glyph,
      meaning,
      pronunciation,
      popularity,
      strokeCount,
      radical,
      listEq.hash(keywords),
    );
  }
}

class KanjiFilter {
  const KanjiFilter({this.grade, this.strokeBucket, this.radical});

  final int? grade;
  final String? strokeBucket;
  final String? radical;

  static const Object _unset = Object();

  String get cacheKey {
    final gradeKey = grade?.toString() ?? 'any';
    final stroke = strokeBucket ?? 'any';
    final rad = radical ?? 'any';
    return 'grade:$gradeKey|stroke:$stroke|radical:$rad';
  }

  KanjiFilter copyWith({
    Object? grade = _unset,
    Object? strokeBucket = _unset,
    Object? radical = _unset,
  }) {
    return KanjiFilter(
      grade: grade == _unset ? this.grade : grade as int?,
      strokeBucket: strokeBucket == _unset
          ? this.strokeBucket
          : strokeBucket as String?,
      radical: radical == _unset ? this.radical : radical as String?,
    );
  }
}

class KanjiSuggestionResult {
  const KanjiSuggestionResult({
    required this.candidates,
    this.fromCache = false,
    this.cachedAt,
  });

  final List<KanjiCandidate> candidates;
  final bool fromCache;
  final DateTime? cachedAt;
}
