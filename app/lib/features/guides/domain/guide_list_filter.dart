import 'dart:ui';

import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/domain/entities/user.dart';

class GuideListFilter {
  const GuideListFilter({
    required this.persona,
    required this.locale,
    this.topic,
  });

  final UserPersona persona;
  final Locale locale;
  final GuideCategory? topic;

  static const Object _topicSentinel = Object();

  GuideListFilter copyWith({
    UserPersona? persona,
    Locale? locale,
    Object? topic = _topicSentinel,
  }) {
    return GuideListFilter(
      persona: persona ?? this.persona,
      locale: locale ?? this.locale,
      topic: identical(topic, _topicSentinel)
          ? this.topic
          : topic as GuideCategory?,
    );
  }
}
