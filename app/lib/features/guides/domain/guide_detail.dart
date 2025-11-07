import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

enum GuideBodyFormat { markdown, html }

@immutable
class GuideDetail {
  GuideDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.body,
    required this.bodyFormat,
    required this.category,
    required this.locale,
    this.heroImageUrl,
    this.readingTimeMinutes,
    this.author,
    List<String>? sources,
    List<String>? tags,
    Set<UserPersona>? personaTargets,
    this.publishAt,
    this.updatedAt,
    this.version,
    this.shareUrl,
    this.featured = false,
  }) : sources = List.unmodifiable(sources ?? const []),
       tags = List.unmodifiable(tags ?? const []),
       personaTargets = Set.unmodifiable(personaTargets ?? const {});

  final String id;
  final String slug;
  final String title;
  final String summary;
  final String body;
  final GuideBodyFormat bodyFormat;
  final GuideCategory category;
  final String locale;
  final String? heroImageUrl;
  final int? readingTimeMinutes;
  final GuideAuthor? author;
  final List<String> sources;
  final List<String> tags;
  final Set<UserPersona> personaTargets;
  final DateTime? publishAt;
  final DateTime? updatedAt;
  final String? version;
  final String? shareUrl;
  final bool featured;
}
