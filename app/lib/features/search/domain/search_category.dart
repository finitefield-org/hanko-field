import 'package:flutter/material.dart';

/// Available global search domains.
enum SearchCategory { templates, materials, articles, faq }

extension SearchCategoryX on SearchCategory {
  String get label {
    switch (this) {
      case SearchCategory.templates:
        return 'テンプレート';
      case SearchCategory.materials:
        return '素材';
      case SearchCategory.articles:
        return '記事';
      case SearchCategory.faq:
        return 'FAQ';
    }
  }

  IconData get icon {
    switch (this) {
      case SearchCategory.templates:
        return Icons.design_services_outlined;
      case SearchCategory.materials:
        return Icons.inventory_2_outlined;
      case SearchCategory.articles:
        return Icons.menu_book_outlined;
      case SearchCategory.faq:
        return Icons.help_outline;
    }
  }

  String get analyticsName {
    switch (this) {
      case SearchCategory.templates:
        return 'templates';
      case SearchCategory.materials:
        return 'materials';
      case SearchCategory.articles:
        return 'articles';
      case SearchCategory.faq:
        return 'faq';
    }
  }
}
