// ignore_for_file: public_member_api_docs

import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:miniriverpod/miniriverpod.dart';

class HankoFieldApp extends ConsumerWidget {
  const HankoFieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(appFlavorProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeBundle = ref.watch(themeBundleProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: flavor.displayLabel,
      theme: themeBundle.light,
      darkTheme: themeBundle.dark,
      themeMode: themeMode,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: AppLocalizations.resolveLocale,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final tokens = ref.watch(themeBundleProvider).tokensFor(brightness);
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.welcomeHeadline, style: tokens.typography.headline),
            SizedBox(height: tokens.spacing.md),
            Text(strings.welcomeBody, style: tokens.typography.body),
            SizedBox(height: tokens.spacing.xl),
            Wrap(
              spacing: tokens.spacing.md,
              runSpacing: tokens.spacing.sm,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: Text(strings.primaryAction),
                ),
                FilledButton.tonal(
                  onPressed: () {},
                  child: Text(strings.secondaryAction),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.xl),
            Wrap(
              spacing: tokens.spacing.sm,
              children: [
                Chip(
                  label: Text(
                    'Spacing ${tokens.spacing.md.toStringAsFixed(0)}',
                  ),
                ),
                Chip(
                  label: Text('Radius ${tokens.radii.md.toStringAsFixed(0)}'),
                ),
                Chip(
                  label: Text('Fast ${tokens.durations.fast.inMilliseconds}ms'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
