import 'package:flutter/material.dart';

/// Supported social platforms for mocked share previews.
enum DesignSharePlatform { instagram, x, linkedin }

/// Copy presets rendered as quick suggestions on the share screen.
enum DesignShareCopyPreset { celebration, craft, launch }

@immutable
class DesignShareBackgroundVariant {
  const DesignShareBackgroundVariant({
    required this.id,
    required this.labelKey,
    required this.gradientColors,
    required this.onBackground,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.surfaceColor,
    this.surfaceBorderRadius = 28,
    this.surfaceShadowColor,
    this.surfaceElevation = 6,
    this.chipColor,
  });

  /// Identifier for persistence and analytics.
  final String id;

  /// Localization key for display name.
  final String labelKey;

  /// Gradient stops for background decoration.
  final List<Color> gradientColors;

  /// Gradient begin alignment.
  final Alignment begin;

  /// Gradient end alignment.
  final Alignment end;

  /// Preferred foreground color for text and watermark.
  final Color onBackground;

  /// Optional container color for the design preview.
  final Color? surfaceColor;

  /// Corner radius for preview surface.
  final double surfaceBorderRadius;

  /// Optional custom shadow tint.
  final Color? surfaceShadowColor;

  /// Elevation level for preview surface.
  final double surfaceElevation;

  /// Accent color for platform chip.
  final Color? chipColor;
}

@immutable
class DesignShareTemplate {
  const DesignShareTemplate({
    required this.id,
    required this.platform,
    required this.aspectRatio,
    required this.accentColor,
    required this.backgrounds,
    required this.defaultHashtags,
    required this.copyPresets,
  });

  /// Unique template identifier.
  final String id;

  /// Social platform associated with the mockup.
  final DesignSharePlatform platform;

  /// Aspect ratio (width / height).
  final double aspectRatio;

  /// Accent color used for platform chip and highlights.
  final Color accentColor;

  /// Background variants available for the template.
  final List<DesignShareBackgroundVariant> backgrounds;

  /// Default hashtags suggested for the platform.
  final List<String> defaultHashtags;

  /// Copy presets exposed as quick suggestions.
  final List<DesignShareCopyPreset> copyPresets;
}

const List<DesignShareTemplate> kDesignShareTemplates = [
  DesignShareTemplate(
    id: 'instagram-square',
    platform: DesignSharePlatform.instagram,
    aspectRatio: 1,
    accentColor: Color(0xFFF97316),
    backgrounds: [
      DesignShareBackgroundVariant(
        id: 'sunset-glow',
        labelKey: 'designShareBackgroundSunsetGlow',
        gradientColors: [
          Color(0xFFFDE68A),
          Color(0xFFFB7185),
          Color(0xFFA855F7),
        ],
        onBackground: Colors.white,
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        surfaceColor: Color(0xFFFFFBFE),
        surfaceShadowColor: Color(0x33FFFFFF),
        chipColor: Color(0xFFFFA85C),
      ),
      DesignShareBackgroundVariant(
        id: 'morning-mist',
        labelKey: 'designShareBackgroundMorningMist',
        gradientColors: [Color(0xFFF3F4F6), Color(0xFFE0E7FF)],
        onBackground: Color(0xFF1F2937),
        surfaceColor: Color(0xFFFFFFFF),
        surfaceShadowColor: Color(0x1A1F2937),
        chipColor: Color(0xFF60A5FA),
      ),
      DesignShareBackgroundVariant(
        id: 'neo-noir',
        labelKey: 'designShareBackgroundNeoNoir',
        gradientColors: [Color(0xFF1F2937), Color(0xFF111827)],
        onBackground: Color(0xFFF9FAFB),
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        surfaceColor: Color(0xFF111827),
        surfaceShadowColor: Color(0x66111827),
        chipColor: Color(0xFF60A5FA),
      ),
    ],
    defaultHashtags: ['#印鑑デザイン', '#HankoField', '#JapaneseCraft'],
    copyPresets: [
      DesignShareCopyPreset.celebration,
      DesignShareCopyPreset.craft,
      DesignShareCopyPreset.launch,
    ],
  ),
  DesignShareTemplate(
    id: 'x-landscape',
    platform: DesignSharePlatform.x,
    aspectRatio: 16 / 9,
    accentColor: Color(0xFF1D4ED8),
    backgrounds: [
      DesignShareBackgroundVariant(
        id: 'midnight',
        labelKey: 'designShareBackgroundMidnight',
        gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        onBackground: Color(0xFFE2E8F0),
        surfaceColor: Color(0xFF020617),
        surfaceShadowColor: Color(0x33020617),
        chipColor: Color(0xFF1D4ED8),
      ),
      DesignShareBackgroundVariant(
        id: 'cyan-grid',
        labelKey: 'designShareBackgroundCyanGrid',
        gradientColors: [Color(0xFF0EA5E9), Color(0xFF312E81)],
        onBackground: Colors.white,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        surfaceColor: Color(0xFF0B1120),
        surfaceShadowColor: Color(0x660B1120),
        chipColor: Color(0xFF38BDF8),
      ),
      DesignShareBackgroundVariant(
        id: 'graphite',
        labelKey: 'designShareBackgroundGraphite',
        gradientColors: [Color(0xFF111827), Color(0xFF374151)],
        onBackground: Color(0xFFFDFFFC),
        surfaceColor: Color(0xFF1F2933),
        surfaceShadowColor: Color(0x33111827),
        chipColor: Color(0xFF64748B),
      ),
    ],
    defaultHashtags: ['#HankoField', '#SmallBusiness', '#Branding'],
    copyPresets: [DesignShareCopyPreset.launch, DesignShareCopyPreset.craft],
  ),
  DesignShareTemplate(
    id: 'linkedin-portrait',
    platform: DesignSharePlatform.linkedin,
    aspectRatio: 4 / 5,
    accentColor: Color(0xFF2563EB),
    backgrounds: [
      DesignShareBackgroundVariant(
        id: 'studio',
        labelKey: 'designShareBackgroundStudio',
        gradientColors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        onBackground: Color(0xFF0F172A),
        surfaceColor: Color(0xFFFFFFFF),
        surfaceShadowColor: Color(0x1A0F172A),
        chipColor: Color(0xFF2563EB),
      ),
      DesignShareBackgroundVariant(
        id: 'navy-slate',
        labelKey: 'designShareBackgroundNavySlate',
        gradientColors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
        onBackground: Color(0xFFF8FAFC),
        surfaceColor: Color(0xFF172554),
        surfaceShadowColor: Color(0x33172554),
        chipColor: Color(0xFF60A5FA),
      ),
      DesignShareBackgroundVariant(
        id: 'aqua-focus',
        labelKey: 'designShareBackgroundAquaFocus',
        gradientColors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
        onBackground: Color(0xFF0F172A),
        surfaceColor: Color(0xFFEFF6FF),
        surfaceShadowColor: Color(0x330F172A),
        chipColor: Color(0xFF2563EB),
      ),
    ],
    defaultHashtags: ['#BrandIdentity', '#Craftsmanship', '#TeamUpdate'],
    copyPresets: [DesignShareCopyPreset.craft, DesignShareCopyPreset.launch],
  ),
];

extension DesignShareTemplatesX on Iterable<DesignShareTemplate> {
  DesignShareTemplate? maybeById(String id) {
    for (final template in this) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  }

  DesignShareTemplate byId(String id) {
    final template = maybeById(id);
    if (template == null) {
      throw ArgumentError.value(id, 'id', 'Unknown share template id');
    }
    return template;
  }
}
