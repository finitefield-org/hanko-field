import 'package:flutter/foundation.dart';

/// Content categories surfaced on the /howto screen.
enum HowToTopic { onboarding, care, shipping, digital, etiquette }

extension HowToTopicX on HowToTopic {
  String get analyticsId => switch (this) {
    HowToTopic.onboarding => 'onboarding',
    HowToTopic.care => 'care',
    HowToTopic.shipping => 'shipping',
    HowToTopic.digital => 'digital',
    HowToTopic.etiquette => 'etiquette',
  };
}

enum HowToDifficultyLevel { beginner, intermediate, advanced }

@immutable
class HowToStep {
  const HowToStep({
    required this.title,
    required this.description,
    this.timestamp,
  });

  final String title;
  final String description;
  final Duration? timestamp;

  HowToStep copyWith({
    String? title,
    String? description,
    Duration? timestamp,
  }) {
    return HowToStep(
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is HowToStep &&
            other.title == title &&
            other.description == description &&
            other.timestamp == timestamp);
  }

  @override
  int get hashCode => Object.hash(title, description, timestamp);
}

@immutable
class HowToTutorial {
  HowToTutorial({
    required this.id,
    required this.topic,
    required this.title,
    required this.summary,
    required this.videoUrl,
    required this.duration,
    required List<HowToStep> steps,
    this.thumbnailUrl,
    this.caption,
    List<String>? resources,
    this.difficulty = HowToDifficultyLevel.intermediate,
    this.featured = false,
    this.badge,
    this.relatedGuideSlug,
  }) : steps = List.unmodifiable(steps),
       resources = List.unmodifiable(resources ?? const []);

  final String id;
  final HowToTopic topic;
  final String title;
  final String summary;
  final String videoUrl;
  final Duration duration;
  final List<HowToStep> steps;
  final String? thumbnailUrl;
  final String? caption;
  final List<String> resources;
  final HowToDifficultyLevel difficulty;
  final bool featured;
  final String? badge;
  final String? relatedGuideSlug;

  HowToTutorial copyWith({
    String? id,
    HowToTopic? topic,
    String? title,
    String? summary,
    String? videoUrl,
    Duration? duration,
    List<HowToStep>? steps,
    String? thumbnailUrl,
    String? caption,
    List<String>? resources,
    HowToDifficultyLevel? difficulty,
    bool? featured,
    String? badge,
    String? relatedGuideSlug,
  }) {
    return HowToTutorial(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      steps: steps ?? this.steps,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      resources: resources ?? this.resources,
      difficulty: difficulty ?? this.difficulty,
      featured: featured ?? this.featured,
      badge: badge ?? this.badge,
      relatedGuideSlug: relatedGuideSlug ?? this.relatedGuideSlug,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is HowToTutorial &&
            other.id == id &&
            other.topic == topic &&
            other.title == title &&
            other.summary == summary &&
            other.videoUrl == videoUrl &&
            other.duration == duration &&
            listEquals(other.steps, steps) &&
            other.thumbnailUrl == thumbnailUrl &&
            other.caption == caption &&
            listEquals(other.resources, resources) &&
            other.difficulty == difficulty &&
            other.featured == featured &&
            other.badge == badge &&
            other.relatedGuideSlug == relatedGuideSlug);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      topic,
      title,
      summary,
      videoUrl,
      duration,
      Object.hashAll(steps),
      thumbnailUrl,
      caption,
      Object.hashAll(resources),
      difficulty,
      featured,
      badge,
      relatedGuideSlug,
    ]);
  }
}

@immutable
class HowToTopicGroup {
  HowToTopicGroup({
    required this.topic,
    required this.title,
    required this.description,
    required List<HowToTutorial> tutorials,
  }) : tutorials = List.unmodifiable(tutorials);

  final HowToTopic topic;
  final String title;
  final String description;
  final List<HowToTutorial> tutorials;

  HowToTopicGroup copyWith({
    HowToTopic? topic,
    String? title,
    String? description,
    List<HowToTutorial>? tutorials,
  }) {
    return HowToTopicGroup(
      topic: topic ?? this.topic,
      title: title ?? this.title,
      description: description ?? this.description,
      tutorials: tutorials ?? this.tutorials,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is HowToTopicGroup &&
            other.topic == topic &&
            other.title == title &&
            other.description == description &&
            listEquals(other.tutorials, tutorials));
  }

  @override
  int get hashCode =>
      Object.hash(topic, title, description, Object.hashAll(tutorials));
}
