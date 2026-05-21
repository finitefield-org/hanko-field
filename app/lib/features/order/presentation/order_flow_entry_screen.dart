import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/widgets/core_widgets.dart';

class OrderFlowEntryScreen extends StatelessWidget {
  const OrderFlowEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.order,
      children: [
        HankoStateView.empty(
          title: l10n.noActiveDraft,
          message: l10n.noActiveDraftMessage,
          actionLabel: l10n.reviewSelection,
        ),
      ],
    );
  }
}
