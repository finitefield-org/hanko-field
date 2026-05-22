import '../../../core/api/core_api.dart';
import '../domain/kanji_candidate.dart';

typedef KanjiCandidatesGenerator =
    Future<KanjiCandidatesResult> Function(KanjiCandidatesRequest request);

const defaultHankoApiBaseUrl = String.fromEnvironment(
  'HANKO_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3050',
);

final _defaultKanjiCandidatesRepository = KanjiCandidatesRepository(
  HankoApiClient(baseUri: Uri.parse(defaultHankoApiBaseUrl)),
);

Future<KanjiCandidatesResult> generateKanjiCandidatesWithDefaultApi(
  KanjiCandidatesRequest request,
) {
  return _defaultKanjiCandidatesRepository.generateCandidates(request);
}

class KanjiCandidatesRepository {
  const KanjiCandidatesRepository(this._apiClient);

  final HankoApiClient _apiClient;

  Future<KanjiCandidatesResult> generateCandidates(
    KanjiCandidatesRequest request,
  ) async {
    final json = await _apiClient.postJson(
      '/v1/kanji-candidates',
      KanjiCandidatesRequestDto.fromDomain(request).toJson(),
    );
    return KanjiCandidatesResponseDto.fromJson(json).toDomain();
  }
}

class KanjiCandidatesRequestDto {
  const KanjiCandidatesRequestDto({
    required this.realName,
    required this.reasonLanguage,
    required this.gender,
    required this.kanjiStyle,
    required this.count,
  });

  factory KanjiCandidatesRequestDto.fromDomain(KanjiCandidatesRequest request) {
    return KanjiCandidatesRequestDto(
      realName: request.realName,
      reasonLanguage: request.reasonLanguage,
      gender: request.gender.apiValue,
      kanjiStyle: request.kanjiStyle.apiValue,
      count: request.count,
    );
  }

  final String realName;
  final String reasonLanguage;
  final String gender;
  final String kanjiStyle;
  final int count;

  JsonMap toJson() {
    return {
      'real_name': realName,
      'reason_language': reasonLanguage,
      'gender': gender,
      'kanji_style': kanjiStyle,
      'count': count,
    };
  }
}

class KanjiCandidatesResponseDto {
  const KanjiCandidatesResponseDto({
    required this.realName,
    required this.reasonLanguage,
    required this.gender,
    required this.kanjiStyle,
    required this.candidates,
  });

  factory KanjiCandidatesResponseDto.fromJson(JsonMap json) {
    return KanjiCandidatesResponseDto(
      realName: readString(json, 'real_name'),
      reasonLanguage: readString(json, 'reason_language'),
      gender: readString(json, 'gender', defaultValue: 'unspecified'),
      kanjiStyle: readString(json, 'kanji_style', defaultValue: 'japanese'),
      candidates: readJsonList(json, 'candidates')
          .map(
            (value) =>
                KanjiCandidateDto.fromJson(asJsonMap(value, 'kanji candidate')),
          )
          .toList(growable: false),
    );
  }

  final String realName;
  final String reasonLanguage;
  final String gender;
  final String kanjiStyle;
  final List<KanjiCandidateDto> candidates;

  KanjiCandidatesResult toDomain() {
    return KanjiCandidatesResult(
      realName: realName,
      reasonLanguage: reasonLanguage,
      gender: KanjiCandidateGender.fromApiValue(gender),
      kanjiStyle: KanjiNameStyle.fromApiValue(kanjiStyle),
      candidates: candidates
          .map((candidate) => candidate.toDomain())
          .toList(growable: false),
    );
  }
}

class KanjiCandidateDto {
  const KanjiCandidateDto({
    required this.kanji,
    required this.reading,
    required this.reason,
    this.meaning,
    this.impression = const [],
    this.characterCount,
    this.strokeComplexity,
    this.engravingSuitability,
  });

  factory KanjiCandidateDto.fromJson(JsonMap json) {
    return KanjiCandidateDto(
      kanji: readString(json, 'kanji'),
      reading: readString(json, 'reading'),
      reason: readString(json, 'reason'),
      meaning: readOptionalString(json, 'meaning'),
      impression: readStringList(json, 'impression'),
      characterCount: json['character_count'] == null
          ? null
          : readInt(json, 'character_count'),
      strokeComplexity: readOptionalString(json, 'stroke_complexity'),
      engravingSuitability: readOptionalString(json, 'engraving_suitability'),
    );
  }

  final String kanji;
  final String reading;
  final String reason;
  final String? meaning;
  final List<String> impression;
  final int? characterCount;
  final String? strokeComplexity;
  final String? engravingSuitability;

  KanjiCandidate toDomain() {
    return KanjiCandidate(
      kanji: kanji,
      reading: reading,
      reason: reason,
      meaning: meaning,
      impression: impression,
      characterCount: characterCount,
      strokeComplexity: strokeComplexity,
      engravingSuitability: engravingSuitability,
    );
  }
}
