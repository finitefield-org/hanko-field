import 'package:flutter/material.dart';

import '../../../core/widgets/core_widgets.dart';

class OrderFlowEntryScreen extends StatelessWidget {
  const OrderFlowEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HankoFeaturePage(
      title: 'Order',
      children: [
        HankoStateView.empty(
          title: 'No active draft',
          message: 'Choose a saved seal and a stone before checkout.',
          actionLabel: 'Review Selection',
        ),
      ],
    );
  }
}
