// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

class ColorTokens {
  const ColorTokens({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.background,
    required this.onBackground,
    required this.outline,
    required this.success,
    required this.warning,
    required this.error,
    required this.onError,
  });

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color background;
  final Color onBackground;
  final Color outline;
  final Color success;
  final Color warning;
  final Color error;
  final Color onError;
}

class SpacingTokens {
  const SpacingTokens({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
}

class RadiusTokens {
  const RadiusTokens({required this.sm, required this.md, required this.lg});

  final double sm;
  final double md;
  final double lg;
}

class DurationTokens {
  const DurationTokens({
    required this.fast,
    required this.regular,
    required this.slow,
  });

  final Duration fast;
  final Duration regular;
  final Duration slow;
}

class TypographyTokens {
  const TypographyTokens({
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.label,
  });

  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;

  TextTheme toTextTheme() {
    return TextTheme(
      displayLarge: display.copyWith(fontSize: 52, fontWeight: FontWeight.w600),
      displayMedium: display.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: display.copyWith(fontSize: 38, fontWeight: FontWeight.w600),
      headlineLarge: headline.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: headline.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: headline.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: title.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: title.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleSmall: title.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      bodyMedium: body.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      bodySmall: body.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      labelLarge: label.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: label.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
      labelSmall: label.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
    );
  }
}

class DesignTokens {
  const DesignTokens({
    required this.colors,
    required this.spacing,
    required this.radii,
    required this.durations,
    required this.typography,
  });

  final ColorTokens colors;
  final SpacingTokens spacing;
  final RadiusTokens radii;
  final DurationTokens durations;
  final TypographyTokens typography;

  factory DesignTokens.light() {
    return const DesignTokens(
      colors: ColorTokens(
        primary: Color(0xFFB22A2A),
        onPrimary: Colors.white,
        secondary: Color(0xFF5B342F),
        onSecondary: Colors.white,
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF1F1512),
        surfaceVariant: Color(0xFFF2E7E3),
        background: Color(0xFFFDF8F3),
        onBackground: Color(0xFF1F1512),
        outline: Color(0xFFCBB8B2),
        success: Color(0xFF1B8F5A),
        warning: Color(0xFFB35B00),
        error: Color(0xFFC62828),
        onError: Colors.white,
      ),
      spacing: SpacingTokens(xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32),
      radii: RadiusTokens(sm: 6, md: 12, lg: 18),
      durations: DurationTokens(
        fast: Duration(milliseconds: 120),
        regular: Duration(milliseconds: 200),
        slow: Duration(milliseconds: 320),
      ),
      typography: TypographyTokens(
        display: TextStyle(height: 1.08, letterSpacing: -0.6),
        headline: TextStyle(height: 1.12, letterSpacing: -0.4),
        title: TextStyle(height: 1.16, letterSpacing: -0.2),
        body: TextStyle(
          height: 1.3,
          letterSpacing: 0,
          color: Color(0xFF3E2723),
        ),
        label: TextStyle(height: 1.2, letterSpacing: 0.2),
      ),
    );
  }

  factory DesignTokens.dark() {
    return const DesignTokens(
      colors: ColorTokens(
        primary: Color(0xFFE2695D),
        onPrimary: Color(0xFF2A0B07),
        secondary: Color(0xFFD8B08F),
        onSecondary: Color(0xFF2A0B07),
        surface: Color(0xFF1A0F0C),
        onSurface: Color(0xFFF5E9E4),
        surfaceVariant: Color(0xFF241511),
        background: Color(0xFF0F0705),
        onBackground: Color(0xFFF1E4DC),
        outline: Color(0xFF5E4036),
        success: Color(0xFF5AC78B),
        warning: Color(0xFFE8A23C),
        error: Color(0xFFE57373),
        onError: Color(0xFF2A0B07),
      ),
      spacing: SpacingTokens(xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32),
      radii: RadiusTokens(sm: 6, md: 12, lg: 18),
      durations: DurationTokens(
        fast: Duration(milliseconds: 120),
        regular: Duration(milliseconds: 200),
        slow: Duration(milliseconds: 320),
      ),
      typography: TypographyTokens(
        display: TextStyle(height: 1.08, letterSpacing: -0.6),
        headline: TextStyle(height: 1.12, letterSpacing: -0.4),
        title: TextStyle(height: 1.16, letterSpacing: -0.2),
        body: TextStyle(height: 1.3, letterSpacing: 0),
        label: TextStyle(height: 1.2, letterSpacing: 0.2),
      ),
    );
  }
}

class DesignTokensTheme extends ThemeExtension<DesignTokensTheme> {
  const DesignTokensTheme({required this.tokens});

  final DesignTokens tokens;

  static DesignTokens of(BuildContext context) {
    final extension = Theme.of(context).extension<DesignTokensTheme>();
    assert(extension != null, 'DesignTokensTheme is not found in ThemeData');
    return extension!.tokens;
  }

  @override
  DesignTokensTheme copyWith({DesignTokens? tokens}) {
    return DesignTokensTheme(tokens: tokens ?? this.tokens);
  }

  @override
  ThemeExtension<DesignTokensTheme> lerp(
    covariant ThemeExtension<DesignTokensTheme>? other,
    double t,
  ) {
    if (other is! DesignTokensTheme) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}
