import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/design_creation/domain/style_template.dart';

/// Temporary repository that simulates fetching templates/font availability.
class StyleTemplateRepository {
  StyleTemplateRepository();

  final Set<String> _favoriteTemplateIds = <String>{};

  Future<List<StyleTemplate>> fetchTemplates({
    required UserPersona persona,
    required Set<String> availableFontRefs,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return _templates
        .where((template) {
          if (!template.matchesPersona(persona)) {
            return false;
          }
          return template.matchesFonts(availableFontRefs);
        })
        .toList(growable: false);
  }

  Future<Set<String>> fetchAvailableFontRefs(UserPersona persona) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return switch (persona) {
      UserPersona.japanese => {
        'jp_tensho_classic',
        'jp_kana_flow',
        'jp_reisho_fine',
      },
      UserPersona.foreigner => {'latin_serif_round', 'latin_sans_square'},
    };
  }

  Future<void> prefetchTemplateAssets(String templateId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  Future<Set<String>> loadFavoriteTemplateIds() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return Set<String>.from(_favoriteTemplateIds);
  }

  Future<void> saveFavoriteTemplateIds(Set<String> favorites) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _favoriteTemplateIds
      ..clear()
      ..addAll(favorites);
  }
}

const List<StyleTemplate> _templates = [
  StyleTemplate(
    id: 'tpl-kanji-origin-round',
    title: 'Tensho Origin Round',
    description:
        'Formal round seal layout with signature Tensho strokes and balance.',
    scriptFamily: StyleScriptFamily.kanji,
    shape: DesignShape.round,
    writingStyle: DesignWritingStyle.tensho,
    previewUrl:
        'https://images.unsplash.com/photo-1503602642458-232111445657?w=640',
    fontRefs: {'jp_tensho_classic'},
    tags: ['Popular', 'Recommended'],
    recommendedPersona: UserPersona.japanese,
    templateRef: 'tpl_tensho_origin_round',
  ),
  StyleTemplate(
    id: 'tpl-kanji-modern-square',
    title: 'Reisho Modern Square',
    description:
        'Slightly condensed square seal optimised for professional documents.',
    scriptFamily: StyleScriptFamily.kanji,
    shape: DesignShape.square,
    writingStyle: DesignWritingStyle.reisho,
    previewUrl:
        'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=640',
    fontRefs: {'jp_reisho_fine'},
    tags: ['Business'],
    recommendedPersona: UserPersona.japanese,
    templateRef: 'tpl_reisho_modern_square',
  ),
  StyleTemplate(
    id: 'tpl-kanji-flow-round',
    title: 'Gyosho Flow Round',
    description:
        'Expressive round layout with sweeping Gyosho strokes for gifts.',
    scriptFamily: StyleScriptFamily.kanji,
    shape: DesignShape.round,
    writingStyle: DesignWritingStyle.gyosho,
    previewUrl:
        'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=640',
    fontRefs: {'jp_kana_flow'},
    tags: ['Gift'],
    recommendedPersona: UserPersona.japanese,
    templateRef: 'tpl_gyosho_flow_round',
  ),
  StyleTemplate(
    id: 'tpl-kana-soft-round',
    title: 'Kana Soft Round',
    description:
        'Rounded layout with gentle kana strokes suited for casual seals.',
    scriptFamily: StyleScriptFamily.kana,
    shape: DesignShape.round,
    writingStyle: DesignWritingStyle.kaisho,
    previewUrl:
        'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=640',
    fontRefs: {'jp_kana_flow'},
    tags: ['Casual'],
    recommendedPersona: UserPersona.japanese,
    templateRef: 'tpl_kana_soft_round',
  ),
  StyleTemplate(
    id: 'tpl-kana-block-square',
    title: 'Kana Block Square',
    description:
        'Square template balancing kana characters with generous margins.',
    scriptFamily: StyleScriptFamily.kana,
    shape: DesignShape.square,
    writingStyle: DesignWritingStyle.kaisho,
    previewUrl:
        'https://images.unsplash.com/photo-1448932223592-d1fc686e76ea?w=640',
    fontRefs: {'jp_reisho_fine'},
    tags: ['Neat'],
    recommendedPersona: UserPersona.japanese,
    templateRef: 'tpl_kana_block_square',
  ),
  StyleTemplate(
    id: 'tpl-roman-serif-round',
    title: 'Roman Serif Round',
    description:
        'Roman letter template with serif contrast and classic round outline.',
    scriptFamily: StyleScriptFamily.roman,
    shape: DesignShape.round,
    writingStyle: DesignWritingStyle.custom,
    previewUrl:
        'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=640',
    fontRefs: {'latin_serif_round'},
    tags: ['Easy start'],
    recommendedPersona: UserPersona.foreigner,
    templateRef: 'tpl_roman_serif_round',
  ),
  StyleTemplate(
    id: 'tpl-roman-bold-square',
    title: 'Roman Bold Square',
    description:
        'Bold sans-serif lettering in a square frame for modern impressions.',
    scriptFamily: StyleScriptFamily.roman,
    shape: DesignShape.square,
    writingStyle: DesignWritingStyle.custom,
    previewUrl:
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=640',
    fontRefs: {'latin_sans_square'},
    tags: ['Modern'],
    recommendedPersona: UserPersona.foreigner,
    templateRef: 'tpl_roman_bold_square',
  ),
];
