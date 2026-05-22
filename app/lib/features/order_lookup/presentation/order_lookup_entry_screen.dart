import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/widgets/core_widgets.dart';

class OrderLookupEntryScreen extends StatefulWidget {
  const OrderLookupEntryScreen({
    super.key,
    this.initialOrderNo,
    this.initialEmail,
    this.onBack,
  });

  final String? initialOrderNo;
  final String? initialEmail;
  final VoidCallback? onBack;

  @override
  State<OrderLookupEntryScreen> createState() => _OrderLookupEntryScreenState();
}

class _OrderLookupEntryScreenState extends State<OrderLookupEntryScreen> {
  late final TextEditingController _orderNoController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _orderNoController = TextEditingController(
      text: widget.initialOrderNo?.trim() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.initialEmail?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _orderNoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.orderLookup,
      children: [
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.onBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        HankoSurfaceCard(
          padding: const EdgeInsets.all(24),
          radius: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HankoTextField(
                label: l10n.orderNo,
                hintText: l10n.orderNoHint,
                controller: _orderNoController,
              ),
              const SizedBox(height: 16),
              HankoTextField(
                label: l10n.email,
                hintText: l10n.emailHint,
                controller: _emailController,
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
