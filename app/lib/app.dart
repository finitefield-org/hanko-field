// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
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
    final analytics = ref.watch(analyticsClientProvider);
    final tokens = DesignTokensTheme.of(context);
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: ResponsivePadding(
        child: ListView(
          children: [
            Text(strings.welcomeHeadline, style: tokens.typography.headline),
            SizedBox(height: tokens.spacing.sm),
            Text(strings.welcomeBody, style: tokens.typography.body),
            SizedBox(height: tokens.spacing.xl),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reusable widgets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: tokens.spacing.md),
                  const AppTextField(
                    label: 'Email',
                    hintText: 'name@example.com',
                    prefix: Icon(Icons.mail_outline),
                  ),
                  SizedBox(height: tokens.spacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: strings.primaryAction,
                          onPressed: () {
                            unawaited(
                              analytics.track(
                                PrimaryActionTappedEvent(
                                  label: strings.primaryAction,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: tokens.spacing.sm),
                      Expanded(
                        child: AppButton(
                          label: strings.secondaryAction,
                          variant: AppButtonVariant.secondary,
                          trailing: const Icon(Icons.arrow_forward),
                          onPressed: () {
                            unawaited(
                              analytics.track(
                                SecondaryActionTappedEvent(
                                  label: strings.secondaryAction,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
            AppListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: tokens.colors.surfaceVariant,
                child: Icon(
                  Icons.stacked_bar_chart,
                  color: tokens.colors.primary,
                ),
              ),
              title: const Text('Sample list tile'),
              subtitle: const Text(
                'Cards and tiles share padding and borders.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            SizedBox(height: tokens.spacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('States', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: tokens.spacing.sm),
                  const AppListSkeleton(),
                  SizedBox(height: tokens.spacing.md),
                  AppEmptyState(
                    title: 'No items yet',
                    message: 'Pull to refresh or adjust filters to load data.',
                    actionLabel: 'Reload',
                    onAction: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
