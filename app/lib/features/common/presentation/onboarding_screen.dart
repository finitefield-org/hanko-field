import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/widgets/core_widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.onboardingTitle,
      children: [
        HankoStateView.empty(
          title: l10n.onboardingIntroTitle,
          message: l10n.onboardingIntroMessage,
          actionLabel: l10n.startDesigning,
          onAction: onComplete,
        ),
      ],
    );
  }
}
