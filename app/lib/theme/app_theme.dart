// ignore_for_file: public_member_api_docs, deprecated_member_use

import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ThemeBundle {
  ThemeBundle({
    required this.light,
    required this.dark,
    required this.lightTokens,
    required this.darkTokens,
  });

  final ThemeData light;
  final ThemeData dark;
  final DesignTokens lightTokens;
  final DesignTokens darkTokens;

  DesignTokens tokensFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkTokens : lightTokens;
  }
}

class AppTheme {
  static ThemeData fromTokens(DesignTokens tokens, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.colors.primary,
      onPrimary: tokens.colors.onPrimary,
      secondary: tokens.colors.secondary,
      onSecondary: tokens.colors.onSecondary,
      surface: tokens.colors.surface,
      onSurface: tokens.colors.onSurface,
      surfaceVariant: tokens.colors.surfaceVariant,
      background: tokens.colors.background,
      onBackground: tokens.colors.onBackground,
      error: tokens.colors.error,
      onError: tokens.colors.onError,
      outline: tokens.colors.outline,
    );

    final textTheme = tokens.typography.toTextTheme();

    final outlineAlphaCard = (tokens.colors.outline.alpha / 255) * 0.35;
    final outlineAlphaDivider = (tokens.colors.outline.alpha / 255) * 0.5;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: tokens.colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.colors.surface,
        foregroundColor: tokens.colors.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: tokens.colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.md),
          side: BorderSide(
            color: tokens.colors.outline.withValues(alpha: outlineAlphaCard),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.colors.primary,
          foregroundColor: tokens.colors.onPrimary,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.lg,
            vertical: tokens.spacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.colors.secondary,
          foregroundColor: tokens.colors.onSecondary,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.lg,
            vertical: tokens.spacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.colors.surfaceVariant,
        labelStyle: textTheme.labelMedium!.copyWith(
          color: tokens.colors.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.sm),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.sm,
          vertical: tokens.spacing.xs,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.colors.outline.withValues(alpha: outlineAlphaDivider),
        thickness: 1,
        space: tokens.spacing.md,
      ),
    );
  }
}

final themeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final themeBundleProvider = Provider<ThemeBundle>((ref) {
  final lightTokens = DesignTokens.light();
  final darkTokens = DesignTokens.dark();

  return ThemeBundle(
    light: AppTheme.fromTokens(lightTokens, Brightness.light),
    dark: AppTheme.fromTokens(darkTokens, Brightness.dark),
    lightTokens: lightTokens,
    darkTokens: darkTokens,
  );
});

final lightDesignTokensProvider = Provider<DesignTokens>(
  (ref) => ref.watch(themeBundleProvider).lightTokens,
);

final darkDesignTokensProvider = Provider<DesignTokens>(
  (ref) => ref.watch(themeBundleProvider).darkTokens,
);
