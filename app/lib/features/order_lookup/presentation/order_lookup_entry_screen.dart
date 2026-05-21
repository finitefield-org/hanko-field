import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/widgets/core_widgets.dart';

class OrderLookupEntryScreen extends StatelessWidget {
  const OrderLookupEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.orderLookup,
      children: [
        HankoSurfaceCard(
          padding: const EdgeInsets.all(24),
          radius: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HankoTextField(label: l10n.orderNo, hintText: l10n.orderNoHint),
              const SizedBox(height: 16),
              HankoTextField(
                label: l10n.email,
                hintText: l10n.emailHint,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              HankoPrimaryButton(label: l10n.lookupOrder, onPressed: null),
            ],
          ),
        ),
      ],
    );
  }
}
