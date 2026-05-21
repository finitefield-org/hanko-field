import 'package:flutter/material.dart';

import '../../../core/widgets/core_widgets.dart';

class OrderLookupEntryScreen extends StatelessWidget {
  const OrderLookupEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HankoFeaturePage(
      title: 'Order Lookup',
      children: [
        HankoSurfaceCard(
          padding: EdgeInsets.all(24),
          radius: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HankoTextField(label: 'Order No', hintText: 'HF-0001'),
              SizedBox(height: 16),
              HankoTextField(
                label: 'Email',
                hintText: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 24),
              HankoPrimaryButton(label: 'Lookup Order', onPressed: null),
            ],
          ),
        ),
      ],
    );
  }
}
