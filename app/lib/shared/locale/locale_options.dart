import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class LocaleOption {
  const LocaleOption({
    required this.locale,
    required this.title,
    required this.subtitle,
    required this.sampleHeadline,
    required this.sampleBody,
  });

  final Locale locale;
  final String title;
  final String subtitle;
  final String sampleHeadline;
  final String sampleBody;

  String get languageTag => locale.toLanguageTag();
}

const List<LocaleOption> kSupportedLocaleOptions = [
  LocaleOption(
    locale: Locale('ja', 'JP'),
    title: '日本語 (日本)',
    subtitle: '和文ガイド・円建て価格・国内配送を優先表示',
    sampleHeadline: 'こんにちは！',
    sampleBody: '日本語 UI で印鑑作りのステップを丁寧に案内します。',
  ),
  LocaleOption(
    locale: Locale('en', 'US'),
    title: 'English (Global)',
    subtitle: 'English guidance, romanization tips, USD-equivalent pricing',
    sampleHeadline: 'Welcome!',
    sampleBody: 'We’ll guide you through crafting your personal hanko.',
  ),
];
