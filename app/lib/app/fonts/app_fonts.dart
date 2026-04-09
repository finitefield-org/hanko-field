import 'package:flutter/material.dart';

class AppFonts {
  const AppFonts._();

  static TextStyle notoSerifJp({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: 'Noto Serif JP',
      fontFamilyFallback: const ['Noto Serif', 'serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      shadows: shadows,
    );
  }

  static TextStyle manrope({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle getFont(String fontFamily, {required TextStyle textStyle}) {
    return textStyle.copyWith(fontFamily: _resolveSealFontFamily(fontFamily));
  }

  static String _resolveSealFontFamily(String fontFamily) {
    final normalized = _normalizeFontFamily(fontFamily);
    return switch (normalized) {
      'noto serif jp' => 'Noto Serif JP',
      'noto serif' => 'Noto Serif',
      'kosugi maru' => 'sans-serif',
      'potta one' => 'sans-serif',
      'kiwi maru' => 'serif',
      'wdxl lubrifont jp n' => 'sans-serif',
      'manrope' => 'Manrope',
      _ => 'serif',
    };
  }

  static String _normalizeFontFamily(String fontFamily) {
    return fontFamily
        .split(',')
        .first
        .replaceAll("'", '')
        .replaceAll('"', '')
        .trim()
        .toLowerCase();
  }
}
