import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/order_lookup_models.dart';

class OrderLookupEntryScreen extends StatefulWidget {
  const OrderLookupEntryScreen({
    super.key,
    this.initialOrderNo,
    this.initialEmail,
    this.onLookup,
    this.onBack,
  });

  final String? initialOrderNo;
  final String? initialEmail;
  final ValueChanged<OrderLookupRequest>? onLookup;
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
    _orderNoController.addListener(_handleInputChanged);
    _emailController.addListener(_handleInputChanged);
  }

  @override
  void didUpdateWidget(covariant OrderLookupEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOrderNo != oldWidget.initialOrderNo &&
        widget.initialOrderNo != null) {
      _orderNoController.text = widget.initialOrderNo!.trim();
    }
    if (widget.initialEmail != oldWidget.initialEmail &&
        widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!.trim();
    }
  }

  @override
  void dispose() {
    _orderNoController.removeListener(_handleInputChanged);
    _emailController.removeListener(_handleInputChanged);
    _orderNoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _canLookup {
    return widget.onLookup != null &&
        _orderNoController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty;
  }

  void _handleInputChanged() {
    setState(() {});
  }

  void _submitLookup() {
    if (!_canLookup) {
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onLookup!(
      OrderLookupRequest(
        orderNo: _orderNoController.text.trim(),
        email: _emailController.text.trim(),
      ),
    );
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
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              HankoTextField(
                label: l10n.email,
                hintText: l10n.emailHint,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _submitLookup(),
              ),
              const SizedBox(height: 24),
              HankoPrimaryButton(
                label: l10n.lookupOrder,
                icon: Icons.search,
                onPressed: _canLookup ? _submitLookup : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
