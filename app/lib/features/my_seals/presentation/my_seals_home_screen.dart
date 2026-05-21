import 'package:flutter/material.dart';

import '../../../core/widgets/core_widgets.dart';

class MySealsHomeScreen extends StatelessWidget {
  const MySealsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HankoFeaturePage(
      title: 'My Seals',
      children: [
        HankoStateView.empty(
          title: 'No saved seals',
          message: 'Saved seal designs will appear here after you create one.',
          actionLabel: 'Start Designing',
        ),
      ],
    );
  }
}
