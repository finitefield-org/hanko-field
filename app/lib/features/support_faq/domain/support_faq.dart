import 'package:flutter/foundation.dart';

enum FaqCategoryIcon { sparkles, shipping, billing, account, ai, status }

@immutable
class FaqCategory {
  const FaqCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.highlight,
  });

  final String id;
  final String title;
  final String description;
  final FaqCategoryIcon icon;
  final String? highlight;
}

@immutable
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.categoryId,
    required this.question,
    required this.answer,
    required this.tags,
    required this.updatedAt,
    required this.helpfulCount,
    required this.notHelpfulCount,
    this.relatedLink,
  });

  final String id;
  final String categoryId;
  final String question;
  final String answer;
  final List<String> tags;
  final DateTime updatedAt;
  final int helpfulCount;
  final int notHelpfulCount;
  final Uri? relatedLink;

  FaqEntry copyWith({
    String? id,
    String? categoryId,
    String? question,
    String? answer,
    List<String>? tags,
    DateTime? updatedAt,
    int? helpfulCount,
    int? notHelpfulCount,
    Uri? relatedLink,
  }) {
    return FaqEntry(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      tags: tags ?? List<String>.from(this.tags),
      updatedAt: updatedAt ?? this.updatedAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      notHelpfulCount: notHelpfulCount ?? this.notHelpfulCount,
      relatedLink: relatedLink ?? this.relatedLink,
    );
  }
}

@immutable
class FaqContentResult {
  const FaqContentResult({
    required this.categories,
    required this.entries,
    required this.suggestions,
    required this.fetchedAt,
    required this.localeTag,
    required this.fromCache,
  });

  final List<FaqCategory> categories;
  final List<FaqEntry> entries;
  final List<String> suggestions;
  final DateTime fetchedAt;
  final String localeTag;
  final bool fromCache;
}

enum FaqFeedbackChoice { helpful, unhelpful }
