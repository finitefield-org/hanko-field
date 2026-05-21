import 'package:flutter/material.dart';

class OrderFlowEntryScreen extends StatelessWidget {
  const OrderFlowEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeatureEntryScaffold(
      title: 'Order',
      routeName: '/order',
      description: 'Draft, combination, checkout, and payment return screens.',
    );
  }
}

class _FeatureEntryScaffold extends StatelessWidget {
  const _FeatureEntryScaffold({
    required this.title,
    required this.routeName,
    required this.description,
  });

  final String title;
  final String routeName;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(routeName, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 16),
            Text(description),
          ],
        ),
      ),
    );
  }
}
