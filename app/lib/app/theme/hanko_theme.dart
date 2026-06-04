import 'package:flutter/material.dart';

abstract final class HankoTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: HankoColors.background,
      fontFamily: HankoFonts.sans,
      colorScheme: ColorScheme.fromSeed(
        seedColor: HankoColors.red,
        surface: HankoColors.background,
        primary: HankoColors.red,
        secondary: HankoColors.gold,
        error: HankoColors.error,
      ),
      textTheme: const TextTheme(
        headlineLarge: HankoTextStyles.pageTitle,
        headlineMedium: HankoTextStyles.sectionTitle,
        titleMedium: HankoTextStyles.cardTitle,
        bodyMedium: HankoTextStyles.body,
        labelLarge: HankoTextStyles.label,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HankoColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HankoSpacing.md,
          vertical: HankoSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
          borderSide: const BorderSide(color: HankoColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
          borderSide: const BorderSide(color: HankoColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
          borderSide: const BorderSide(color: HankoColors.gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
          borderSide: const BorderSide(color: HankoColors.error),
        ),
        labelStyle: HankoTextStyles.label,
        hintStyle: HankoTextStyles.body,
      ),
    );
  }
}

abstract final class HankoColors {
  static const background = Color(0xFFFBF8F3);
  static const surface = Color(0xFFFEFCF9);
  static const surfaceBorder = Color(0xFFEDE3D7);
  static const navBorder = Color(0xFFE8DED3);
  static const medallion = Color(0xFFF1EAE2);
  static const red = Color(0xFF9D1F22);
  static const gold = Color(0xFFB47B2C);
  static const ink = Color(0xFF202629);
  static const body = Color(0xFF64686B);
  static const error = Color(0xFFB3261E);
}

abstract final class HankoFonts {
  static const sans = 'Manrope';
  static const serif = 'Noto Serif';
}

abstract final class HankoTextStyles {
  static const pageTitle = TextStyle(
    color: HankoColors.red,
    fontFamily: HankoFonts.serif,
    fontSize: 38,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );

  static const heroTitle = TextStyle(
    color: HankoColors.ink,
    fontFamily: HankoFonts.serif,
    fontSize: 36,
    fontWeight: FontWeight.w500,
    height: 1.12,
    letterSpacing: 0,
  );

  static const sectionTitle = TextStyle(
    color: HankoColors.ink,
    fontFamily: HankoFonts.serif,
    fontSize: 25,
    fontWeight: FontWeight.w500,
    height: 1.12,
    letterSpacing: 0,
  );

  static const cardTitle = TextStyle(
    color: HankoColors.ink,
    fontFamily: HankoFonts.serif,
    fontSize: 21.5,
    fontWeight: FontWeight.w500,
    height: 1.05,
    letterSpacing: 0,
  );

  static const buttonLabel = TextStyle(
    fontFamily: HankoFonts.serif,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );

  static const body = TextStyle(
    color: HankoColors.body,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    height: 1.65,
    letterSpacing: 0,
  );

  static const compactBody = TextStyle(
    color: HankoColors.body,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.62,
    letterSpacing: 0,
  );

  static const label = TextStyle(
    color: HankoColors.ink,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0,
  );
}

abstract final class HankoSpacing {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class HankoRadii {
  static const sm = 8.0;
  static const md = 15.0;
  static const lg = 17.0;
}
