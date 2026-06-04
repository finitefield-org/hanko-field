import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../domain/stone_listing.dart';

Future<bool> confirmStoneSelection(
  BuildContext context,
  StoneListing listing,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: HankoColors.surface,
        title: Text(
          l10n.selectStoneConfirmationTitle,
          style: HankoTextStyles.cardTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(listing.title, style: HankoTextStyles.label),
            const SizedBox(height: HankoSpacing.sm),
            Text(
              l10n.selectStoneConfirmationMessage,
              style: HankoTextStyles.body,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('stone-selection-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.selectStoneConfirm),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
