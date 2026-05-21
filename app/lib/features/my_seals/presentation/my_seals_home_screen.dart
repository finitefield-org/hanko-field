import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/widgets/core_widgets.dart';

class MySealsHomeScreen extends StatelessWidget {
  const MySealsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.mySeals,
      children: [
        HankoStateView.empty(
          title: l10n.noSavedSeals,
          message: l10n.noSavedSealsMessage,
          actionLabel: l10n.startDesigning,
        ),
      ],
    );
  }
}
