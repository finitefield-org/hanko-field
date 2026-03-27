import 'package:flutter/material.dart';

class HfPalette {
  static const bgMain = Color(0xFFF8F2E8);
  static const bgPanel = Color(0xFFFFFAF2);
  static const ink = Color(0xFF1D1B19);
  static const muted = Color(0xFF6A645D);
  static const line = Color(0xFFDBCFBF);
  static const accent = Color(0xFFB6362B);
  static const accentSoft = Color(0xFFF2DBD8);
  static const accent2 = Color(0xFF0F6B63);
  static const card = Colors.white;
}

ThemeData buildHfTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: HfPalette.bgMain,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: HfPalette.accent,
          brightness: Brightness.light,
        ).copyWith(
          surface: HfPalette.bgPanel,
          primary: HfPalette.accent,
          secondary: HfPalette.accent2,
          onSurface: HfPalette.ink,
          onPrimary: Colors.white,
        ),
    textTheme: base.textTheme.apply(
      bodyColor: HfPalette.ink,
      displayColor: HfPalette.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCFC5B7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCFC5B7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: HfPalette.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8F2219), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8F2219), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFF8F2219)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HfPalette.line),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
  );
}
