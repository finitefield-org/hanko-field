// ignore_for_file: public_member_api_docs

import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';

class TabPlaceholderPage extends StatelessWidget {
  const TabPlaceholderPage({
    super.key,
    required this.title,
    required this.routePath,
    this.detail,
    this.showBack = false,
  });

  final String title;
  final String routePath;
  final String? detail;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBack ? const BackButton() : null,
      ),
      body: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(routePath, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: tokens.spacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail ?? 'Screen coming soon',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    'Path: $routePath',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: tokens.colors.onSurface,
                    ),
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
