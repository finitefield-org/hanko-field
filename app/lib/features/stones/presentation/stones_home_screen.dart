import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/widgets/core_widgets.dart';

class StonesHomeScreen extends StatelessWidget {
  const StonesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.stones,
      children: [
        HankoStateView.empty(
          title: l10n.noStonesLoaded,
          message: l10n.noStonesLoadedMessage,
        ),
      ],
    );
  }
}
