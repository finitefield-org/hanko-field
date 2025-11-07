import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

/// Lightweight guide summary used for list surfaces.
@immutable
class GuideListEntry {
  GuideListEntry({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.category,
    required this.locale,
    this.heroImageUrl,
    this.readingTimeMinutes,
    List<String>? tags,
    Set<UserPersona>? personaTargets,
    this.featured = false,
  }) : tags = List.unmodifiable(tags ?? const []),
       personaTargets = Set.unmodifiable(personaTargets ?? const {});

  final String id;
  final String slug;
  final String title;
  final String summary;
  final GuideCategory category;
  final String locale;
  final String? heroImageUrl;
  final int? readingTimeMinutes;
  final List<String> tags;
  final Set<UserPersona> personaTargets;
  final bool featured;

  bool supportsPersona(UserPersona persona) {
    return personaTargets.isEmpty || personaTargets.contains(persona);
  }

  bool matchesCategory(GuideCategory? topic) {
    if (topic == null) {
      return true;
    }
    return category == topic;
  }

  bool matchesSearch(String query) {
    if (query.isEmpty) {
      return true;
    }
    final needle = query.toLowerCase();
    return title.toLowerCase().contains(needle) ||
        summary.toLowerCase().contains(needle) ||
        tags.any((tag) => tag.toLowerCase().contains(needle));
  }

  GuideListEntry copyWith({
    String? id,
    String? slug,
    String? title,
    String? summary,
    GuideCategory? category,
    String? locale,
    String? heroImageUrl,
    int? readingTimeMinutes,
    List<String>? tags,
    Set<UserPersona>? personaTargets,
    bool? featured,
  }) {
    return GuideListEntry(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      locale: locale ?? this.locale,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      readingTimeMinutes: readingTimeMinutes ?? this.readingTimeMinutes,
      tags: tags ?? this.tags,
      personaTargets: personaTargets ?? this.personaTargets,
      featured: featured ?? this.featured,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is GuideListEntry &&
            other.id == id &&
            other.slug == slug &&
            other.title == title &&
            other.summary == summary &&
            other.category == category &&
            other.locale == locale &&
            other.heroImageUrl == heroImageUrl &&
            other.readingTimeMinutes == readingTimeMinutes &&
            listEquals(other.tags, tags) &&
            setEquals(other.personaTargets, personaTargets) &&
            other.featured == featured);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      slug,
      title,
      summary,
      category,
      locale,
      heroImageUrl,
      readingTimeMinutes,
      Object.hashAll(tags),
      Object.hashAll(personaTargets),
      featured,
    ]);
  }
}
