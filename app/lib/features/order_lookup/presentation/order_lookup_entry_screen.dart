import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../core/api/core_api.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/order_lookup_models.dart';

enum _OrderLookupStep { input, loading, notFound, error }

class OrderLookupEntryScreen extends StatefulWidget {
  const OrderLookupEntryScreen({
    super.key,
    this.initialOrderNo,
    this.initialEmail,
    this.onLookup,
    this.lookupOrder,
    this.onLookupResult,
    this.onBack,
  });

  final String? initialOrderNo;
  final String? initialEmail;
  final ValueChanged<OrderLookupRequest>? onLookup;
  final OrderLookupFetcher? lookupOrder;
  final ValueChanged<OrderStatus>? onLookupResult;
  final VoidCallback? onBack;

  @override
  State<OrderLookupEntryScreen> createState() => _OrderLookupEntryScreenState();
}

class _OrderLookupEntryScreenState extends State<OrderLookupEntryScreen> {
  late final TextEditingController _orderNoController;
  late final TextEditingController _emailController;
  var _step = _OrderLookupStep.input;
  var _lookupRequestId = 0;
  OrderLookupRequest? _lastRequest;

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
    _orderNoController.removeListener(_handleInputChanged);
    _emailController.removeListener(_handleInputChanged);
    var didChangeInitialInput = false;
    if (widget.initialOrderNo != oldWidget.initialOrderNo &&
        widget.initialOrderNo != null) {
      _orderNoController.text = widget.initialOrderNo!.trim();
      didChangeInitialInput = true;
    }
    if (widget.initialEmail != oldWidget.initialEmail &&
        widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!.trim();
      didChangeInitialInput = true;
    }
    if (didChangeInitialInput) {
      _lookupRequestId++;
      _step = _OrderLookupStep.input;
    }
    _orderNoController.addListener(_handleInputChanged);
    _emailController.addListener(_handleInputChanged);
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
    return _step != _OrderLookupStep.loading &&
        (widget.onLookup != null || widget.lookupOrder != null) &&
        _orderNoController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty;
  }

  bool get _isLoading => _step == _OrderLookupStep.loading;

  void _handleInputChanged() {
    if (_step != _OrderLookupStep.input) {
      _step = _OrderLookupStep.input;
    }
    setState(() {});
  }

  Future<void> _submitLookup() async {
    if (!_canLookup) {
      return;
    }
    FocusScope.of(context).unfocus();
    final request = OrderLookupRequest(
      orderNo: _orderNoController.text.trim(),
      email: _emailController.text.trim(),
    );
    _lastRequest = request;
    widget.onLookup?.call(request);

    final lookupOrder = widget.lookupOrder;
    if (lookupOrder == null) {
      return;
    }

    final requestId = ++_lookupRequestId;
    setState(() => _step = _OrderLookupStep.loading);
    try {
      final result = await lookupOrder(request);
      if (!mounted || requestId != _lookupRequestId) {
        return;
      }
      widget.onLookupResult?.call(result);
      if (!mounted || requestId != _lookupRequestId) {
        return;
      }
      setState(() => _step = _OrderLookupStep.input);
    } on HankoApiException catch (error) {
      if (!mounted || requestId != _lookupRequestId) {
        return;
      }
      setState(() {
        _step = _isLookupNotFoundError(error)
            ? _OrderLookupStep.notFound
            : _OrderLookupStep.error;
      });
    } catch (_) {
      if (!mounted || requestId != _lookupRequestId) {
        return;
      }
      setState(() => _step = _OrderLookupStep.error);
    }
  }

  void _retryLookup() {
    final request = _lastRequest;
    if (request == null || _isLoading) {
      return;
    }
    _orderNoController.text = request.orderNo;
    _emailController.text = request.email;
    _submitLookup();
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
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              HankoTextField(
                label: l10n.email,
                hintText: l10n.emailHint,
                controller: _emailController,
                enabled: !_isLoading,
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
        if (_step != _OrderLookupStep.input) ...[
          const SizedBox(height: 16),
          _OrderLookupStateCard(step: _step, onRetry: _retryLookup),
        ],
      ],
    );
  }
}

bool _isLookupNotFoundError(HankoApiException error) {
  return switch (error.code.trim().toLowerCase()) {
    'order_not_found' || 'not_found' || 'validation_error' => true,
    _ => error.statusCode == 404,
  };
}

class _OrderLookupStateCard extends StatelessWidget {
  const _OrderLookupStateCard({required this.step, required this.onRetry});

  final _OrderLookupStep step;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (step) {
      _OrderLookupStep.loading => HankoStateView.loading(
        title: l10n.orderLookupLoadingTitle,
        message: l10n.orderLookupLoadingMessage,
      ),
      _OrderLookupStep.notFound => HankoStateView.empty(
        title: l10n.orderLookupNotFoundTitle,
        message: l10n.orderLookupNotFoundMessage,
        actionLabel: l10n.tryAgain,
        onAction: onRetry,
      ),
      _OrderLookupStep.error => HankoStateView.error(
        title: l10n.orderLookupErrorTitle,
        message: l10n.orderLookupErrorMessage,
        actionLabel: l10n.tryAgain,
        onAction: onRetry,
      ),
      _OrderLookupStep.input => const SizedBox.shrink(),
    };
  }
}
