import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';

class GuideListRequest {
  GuideListRequest({required this.localeTag, required this.persona});

  final String localeTag;
  final UserPersona persona;

  GuideListRequest copyWith({String? localeTag, UserPersona? persona}) {
    return GuideListRequest(
      localeTag: localeTag ?? this.localeTag,
      persona: persona ?? this.persona,
    );
  }
}

class GuidesRepositoryResult {
  const GuidesRepositoryResult({
    required this.guides,
    required this.recommended,
    required this.localeTag,
    required this.persona,
    required this.fetchedAt,
    required this.fromCache,
  });

  final List<GuideListEntry> guides;
  final List<GuideListEntry> recommended;
  final String localeTag;
  final UserPersona persona;
  final DateTime fetchedAt;
  final bool fromCache;
}

abstract class GuidesRepository {
  Future<GuidesRepositoryResult> fetchGuides(GuideListRequest request);
}
