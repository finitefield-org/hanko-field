import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/howto/domain/howto_tutorial.dart';

class HowToContentRequest {
  const HowToContentRequest({required this.localeTag, required this.persona});

  final String localeTag;
  final UserPersona persona;

  HowToContentRequest copyWith({String? localeTag, UserPersona? persona}) {
    return HowToContentRequest(
      localeTag: localeTag ?? this.localeTag,
      persona: persona ?? this.persona,
    );
  }
}

class HowToContentResult {
  const HowToContentResult({
    required this.groups,
    required this.localeTag,
    required this.persona,
    required this.fetchedAt,
    required this.fromCache,
  });

  final List<HowToTopicGroup> groups;
  final String localeTag;
  final UserPersona persona;
  final DateTime fetchedAt;
  final bool fromCache;

  HowToTutorial? get featuredTutorial {
    for (final group in groups) {
      for (final tutorial in group.tutorials) {
        if (tutorial.featured) {
          return tutorial;
        }
      }
    }
    if (groups.isEmpty || groups.first.tutorials.isEmpty) {
      return null;
    }
    return groups.first.tutorials.first;
  }
}

abstract class HowToRepository {
  Future<HowToContentResult> fetchContent(HowToContentRequest request);
}
