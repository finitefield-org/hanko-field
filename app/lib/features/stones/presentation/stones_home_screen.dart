import 'package:flutter/material.dart';

import '../../../core/widgets/core_widgets.dart';

class StonesHomeScreen extends StatelessWidget {
  const StonesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HankoFeaturePage(
      title: 'Stones',
      children: [
        HankoStateView.empty(
          title: 'No stones loaded',
          message: 'Available one-of-a-kind stones will be shown here.',
        ),
      ],
    );
  }
}
