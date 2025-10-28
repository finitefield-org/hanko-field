import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:flutter/foundation.dart';

enum HomeSectionType { featured, recents, templates }

extension HomeSectionTypeX on HomeSectionType {
  String get analyticsId => switch (this) {
    HomeSectionType.featured => 'featured',
    HomeSectionType.recents => 'recents',
    HomeSectionType.templates => 'templates',
  };
}

@immutable
class HomeContentDestination {
  const HomeContentDestination({required this.route, this.overrideTab});

  final IndependentRoute route;
  final AppTab? overrideTab;
}

@immutable
class HomeFeaturedItem {
  const HomeFeaturedItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.ctaLabel,
    required this.destination,
    this.badgeLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaLabel;
  final String? badgeLabel;
  final HomeContentDestination destination;
}

@immutable
class HomeRecentDesign {
  const HomeRecentDesign({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.status,
    this.thumbnailUrl,
    this.sourceType,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final DesignStatus status;
  final String? thumbnailUrl;
  final DesignSourceType? sourceType;
}

@immutable
class HomeTemplateRecommendation {
  const HomeTemplateRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.shape,
    required this.writingStyle,
    required this.destination,
    this.previewUrl,
    this.highlightLabel,
  });

  final String id;
  final String title;
  final String description;
  final DesignShape shape;
  final DesignWritingStyle writingStyle;
  final String? previewUrl;
  final String? highlightLabel;
  final HomeContentDestination destination;
}

@immutable
class HomeUsageInsights {
  const HomeUsageInsights({
    required this.recentDesignCount,
    required this.recommendedTemplateInteractionCount,
    this.lastDesignInteractionAt,
    this.lastEngagedSection,
  });

  final int recentDesignCount;
  final int recommendedTemplateInteractionCount;
  final DateTime? lastDesignInteractionAt;
  final HomeSectionType? lastEngagedSection;
}

@immutable
class HomeContentContext {
  const HomeContentContext({required this.experience, required this.usage});

  final ExperienceGate experience;
  final HomeUsageInsights usage;
}

List<HomeSectionType> computeHomeSectionOrder({
  required ExperienceGate experience,
  required HomeUsageInsights usage,
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final sections = <HomeSectionType>[
    HomeSectionType.featured,
    HomeSectionType.recents,
    HomeSectionType.templates,
  ];

  void moveToFront(HomeSectionType section) {
    if (sections.remove(section)) {
      sections.insert(0, section);
    }
  }

  void moveToEnd(HomeSectionType section) {
    if (sections.remove(section)) {
      sections.add(section);
    }
  }

  if (usage.lastEngagedSection != null) {
    moveToFront(usage.lastEngagedSection!);
  }

  final recentsAreFresh =
      usage.lastDesignInteractionAt != null &&
      timestamp.difference(usage.lastDesignInteractionAt!).inDays <= 7;

  if (experience.persona == UserPersona.foreigner) {
    moveToFront(HomeSectionType.templates);
  } else if (usage.recentDesignCount > 0 && recentsAreFresh) {
    moveToFront(HomeSectionType.recents);
  }

  if (usage.recentDesignCount == 0) {
    moveToEnd(HomeSectionType.recents);
  }

  if (experience.isInternational &&
      usage.recommendedTemplateInteractionCount < 1) {
    moveToFront(HomeSectionType.templates);
  }

  return List.unmodifiable(sections);
}
