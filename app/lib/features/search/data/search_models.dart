// ignore_for_file: public_member_api_docs

import 'package:app/features/catalog/data/models/catalog_models.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:flutter/material.dart' show IconData, Icons;

enum SearchSegment { templates, materials, articles, faq }

extension SearchSegmentX on SearchSegment {
  String label({required bool prefersEnglish}) {
    switch (this) {
      case SearchSegment.templates:
        return prefersEnglish ? 'Templates' : 'テンプレート';
      case SearchSegment.materials:
        return prefersEnglish ? 'Materials' : '素材';
      case SearchSegment.articles:
        return prefersEnglish ? 'Articles' : '記事';
      case SearchSegment.faq:
        return prefersEnglish ? 'FAQ' : 'FAQ';
    }
  }

  IconData icon() {
    switch (this) {
      case SearchSegment.templates:
        return Icons.widgets_outlined;
      case SearchSegment.materials:
        return Icons.layers_outlined;
      case SearchSegment.articles:
        return Icons.menu_book_outlined;
      case SearchSegment.faq:
        return Icons.live_help_outlined;
    }
  }
}

class SearchSuggestion {
  const SearchSuggestion({required this.label, this.context, this.segment});

  final String label;
  final String? context;
  final SearchSegment? segment;
}

class TemplateSearchHit {
  const TemplateSearchHit({required this.template, required this.reason});

  final Template template;
  final String reason;
}

class MaterialSearchHit {
  const MaterialSearchHit({
    required this.material,
    required this.summary,
    this.badge,
  });

  final Material material;
  final String summary;
  final String? badge;
}

class ArticleSearchHit {
  const ArticleSearchHit({
    required this.guide,
    required this.summary,
    required this.category,
  });

  final Guide guide;
  final String summary;
  final GuideCategory category;
}

class FaqSearchHit {
  const FaqSearchHit({
    required this.guide,
    required this.question,
    required this.answer,
  });

  final Guide guide;
  final String question;
  final String answer;
}
