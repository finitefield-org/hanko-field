import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

/// High-level script buckets used for segmented filtering on the style screen.
enum StyleScriptFamily { kanji, kana, roman }

extension StyleScriptFamilyX on StyleScriptFamily {
  String get analyticsId => switch (this) {
    StyleScriptFamily.kanji => 'kanji',
    StyleScriptFamily.kana => 'kana',
    StyleScriptFamily.roman => 'roman',
  };
}

/// Metadata describing a template option presented in the style selector.
@immutable
class StyleTemplate {
  const StyleTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.scriptFamily,
    required this.shape,
    required this.writingStyle,
    required this.previewUrl,
    this.fontRefs = const {},
    this.tags = const [],
    this.recommendedPersona,
    this.templateRef,
  });

  /// Stable identifier referencing the catalog template entry.
  final String id;

  final String title;
  final String description;
  final StyleScriptFamily scriptFamily;
  final DesignShape shape;
  final DesignWritingStyle writingStyle;
  final String previewUrl;

  /// Catalog font identifiers that pair nicely with this template.
  final Set<String> fontRefs;

  /// Optional descriptive tags (e.g. "Popular", "Gift").
  final List<String> tags;

  /// Persona this template is tuned for. `null` means applicable to all.
  final UserPersona? recommendedPersona;

  /// Reference passed downstream to editor for fetching template data.
  final String? templateRef;

  bool matchesPersona(UserPersona persona) {
    return recommendedPersona == null || recommendedPersona == persona;
  }

  bool matchesFonts(Set<String> availableFonts) {
    if (fontRefs.isEmpty || availableFonts.isEmpty) {
      return true;
    }
    return availableFonts.intersection(fontRefs).isNotEmpty;
  }

  bool matchesShapes(Set<DesignShape> activeShapes) {
    if (activeShapes.isEmpty) {
      return true;
    }
    return activeShapes.contains(shape);
  }

  StyleTemplate copyWith({
    String? id,
    String? title,
    String? description,
    StyleScriptFamily? scriptFamily,
    DesignShape? shape,
    DesignWritingStyle? writingStyle,
    String? previewUrl,
    Set<String>? fontRefs,
    List<String>? tags,
    UserPersona? recommendedPersona,
    bool clearRecommendedPersona = false,
    String? templateRef,
  }) {
    return StyleTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scriptFamily: scriptFamily ?? this.scriptFamily,
      shape: shape ?? this.shape,
      writingStyle: writingStyle ?? this.writingStyle,
      previewUrl: previewUrl ?? this.previewUrl,
      fontRefs: fontRefs ?? this.fontRefs,
      tags: tags ?? this.tags,
      recommendedPersona: clearRecommendedPersona
          ? null
          : recommendedPersona ?? this.recommendedPersona,
      templateRef: templateRef ?? this.templateRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is StyleTemplate &&
            other.id == id &&
            other.title == title &&
            other.description == description &&
            other.scriptFamily == scriptFamily &&
            other.shape == shape &&
            other.writingStyle == writingStyle &&
            other.previewUrl == previewUrl &&
            setEquals(other.fontRefs, fontRefs) &&
            listEquals(other.tags, tags) &&
            other.recommendedPersona == recommendedPersona &&
            other.templateRef == templateRef);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      title,
      description,
      scriptFamily,
      shape,
      writingStyle,
      previewUrl,
      Object.hashAll(fontRefs),
      Object.hashAll(tags),
      recommendedPersona,
      templateRef,
    ]);
  }
}
