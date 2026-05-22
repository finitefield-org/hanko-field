import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/money.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/order_draft.dart';

class OrderFlowEntryScreen extends StatelessWidget {
  const OrderFlowEntryScreen({
    super.key,
    this.draft,
    this.onBack,
    this.onChooseSeal,
    this.onChooseStone,
    this.onContinueToShipping,
  });

  final OrderDraft? draft;
  final VoidCallback? onBack;
  final VoidCallback? onChooseSeal;
  final VoidCallback? onChooseStone;
  final VoidCallback? onContinueToShipping;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orderDraft = draft ?? OrderDraft.empty();

    if (!orderDraft.hasSealSelection && !orderDraft.hasStoneSelection) {
      return _OrderScreenFrame(
        title: l10n.order,
        onBack: onBack,
        children: [
          HankoStateView.empty(
            title: l10n.noActiveDraft,
            message: l10n.noActiveDraftMessage,
            actionLabel: l10n.orderChooseSealAction,
            onAction: onChooseSeal,
          ),
          const SizedBox(height: HankoSpacing.md),
          _SecondaryOrderAction(
            label: l10n.orderChooseStoneAction,
            icon: Icons.diamond_outlined,
            onPressed: onChooseStone,
          ),
        ],
      );
    }

    if (!orderDraft.hasSealSelection) {
      return _MissingSealScreen(
        draft: orderDraft,
        onBack: onBack,
        onChooseSeal: onChooseSeal,
      );
    }

    if (!orderDraft.hasStoneSelection) {
      return _MissingStoneScreen(
        draft: orderDraft,
        onBack: onBack,
        onChooseStone: onChooseStone,
      );
    }

    return OrderCombinationReviewScreen(
      draft: orderDraft,
      onBack: onBack,
      onChangeSeal: onChooseSeal,
      onChangeStone: onChooseStone,
      onContinueToShipping: onContinueToShipping,
    );
  }
}

class _MissingSealScreen extends StatelessWidget {
  const _MissingSealScreen({
    required this.draft,
    required this.onBack,
    required this.onChooseSeal,
  });

  final OrderDraft draft;
  final VoidCallback? onBack;
  final VoidCallback? onChooseSeal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stone = draft.stoneSelection;

    return _OrderScreenFrame(
      title: l10n.orderReviewTitle,
      onBack: onBack,
      children: [
        if (stone != null) ...[
          _StoneSummaryCard(selection: stone),
          const SizedBox(height: HankoSpacing.md),
        ],
        _MissingSelectionCard(
          icon: Icons.draw_outlined,
          title: l10n.orderMissingSealTitle,
          message: l10n.orderMissingSealMessage,
          actionLabel: l10n.orderChooseSealAction,
          onAction: onChooseSeal,
        ),
        const SizedBox(height: HankoSpacing.md),
        _OrderNotice(message: l10n.orderMissingSealNotice),
        const SizedBox(height: HankoSpacing.md),
        HankoPrimaryButton(
          label: l10n.orderChooseSealAction,
          icon: Icons.arrow_forward,
          onPressed: onChooseSeal,
          height: 58,
        ),
      ],
    );
  }
}

class _MissingStoneScreen extends StatelessWidget {
  const _MissingStoneScreen({
    required this.draft,
    required this.onBack,
    required this.onChooseStone,
  });

  final OrderDraft draft;
  final VoidCallback? onBack;
  final VoidCallback? onChooseStone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seal = draft.sealSelection;

    return _OrderScreenFrame(
      title: l10n.orderReviewTitle,
      onBack: onBack,
      children: [
        if (seal != null) ...[
          _SealSummaryCard(selection: seal),
          const SizedBox(height: HankoSpacing.md),
        ],
        _MissingSelectionCard(
          icon: Icons.diamond_outlined,
          title: l10n.orderMissingStoneTitle,
          message: l10n.orderMissingStoneMessage,
          actionLabel: l10n.orderChooseStoneAction,
          onAction: onChooseStone,
        ),
        const SizedBox(height: HankoSpacing.md),
        _OrderNotice(message: l10n.orderCustomMadeNotice),
        const SizedBox(height: HankoSpacing.md),
        HankoPrimaryButton(
          label: l10n.orderChooseStoneAction,
          icon: Icons.arrow_forward,
          onPressed: onChooseStone,
          height: 58,
        ),
      ],
    );
  }
}

class OrderCombinationReviewScreen extends StatelessWidget {
  const OrderCombinationReviewScreen({
    super.key,
    required this.draft,
    this.onBack,
    this.onChangeSeal,
    this.onChangeStone,
    this.onContinueToShipping,
  });

  final OrderDraft draft;
  final VoidCallback? onBack;
  final VoidCallback? onChangeSeal;
  final VoidCallback? onChangeStone;
  final VoidCallback? onContinueToShipping;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seal = draft.sealSelection;
    final stone = draft.stoneSelection;

    if (seal == null || stone == null) {
      return OrderFlowEntryScreen(draft: draft, onBack: onBack);
    }

    final pricing = _OrderPricingSummary.fromDraft(draft);

    return _OrderScreenFrame(
      title: l10n.orderReviewTitle,
      onBack: onBack,
      children: [
        Text(l10n.orderReviewMessage, style: HankoTextStyles.body),
        const SizedBox(height: HankoSpacing.md),
        _SealSummaryCard(
          selection: seal,
          actionLabel: l10n.orderChangeSealAction,
          onAction: onChangeSeal,
        ),
        const SizedBox(height: HankoSpacing.md),
        _StoneSummaryCard(
          selection: stone,
          actionLabel: l10n.orderChangeStoneAction,
          onAction: onChangeStone,
        ),
        const SizedBox(height: HankoSpacing.md),
        _OrderPricingCard(summary: pricing),
        const SizedBox(height: HankoSpacing.md),
        _OrderNotice(message: l10n.orderCustomMadeNotice),
        const SizedBox(height: HankoSpacing.md),
        HankoPrimaryButton(
          label: l10n.continueToShipping,
          icon: Icons.arrow_forward,
          onPressed: onContinueToShipping,
          height: 58,
        ),
      ],
    );
  }
}

class CheckoutInputScreen extends StatefulWidget {
  const CheckoutInputScreen({
    super.key,
    this.input = const OrderDraftInput.empty(),
    this.onBack,
    this.onSave,
  });

  final OrderDraftInput input;
  final VoidCallback? onBack;
  final Future<void> Function(OrderDraftInput input)? onSave;

  @override
  State<CheckoutInputScreen> createState() => _CheckoutInputScreenState();
}

class _CheckoutInputScreenState extends State<CheckoutInputScreen> {
  static const _defaultCountryCode = 'JP';
  static const _knownCountryCodes = ['JP', 'US', 'CA', 'GB', 'AU', 'SG'];

  final _validationSummaryKey = GlobalKey();
  final _fieldKeys = {
    for (final field in _CheckoutInputField.values) field: GlobalKey(),
  };
  late final TextEditingController _emailController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _orderNoteController;
  late String _countryCode;
  var _validationErrors = const <_CheckoutValidationError>[];
  var _isSaving = false;
  var _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _postalCodeController = TextEditingController();
    _stateController = TextEditingController();
    _cityController = TextEditingController();
    _addressLine1Controller = TextEditingController();
    _addressLine2Controller = TextEditingController();
    _orderNoteController = TextEditingController();
    _applyInput(widget.input);
  }

  @override
  void didUpdateWidget(covariant CheckoutInputScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input != widget.input) {
      _applyInput(widget.input);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _orderNoteController.dispose();
    super.dispose();
  }

  void _applyInput(OrderDraftInput input) {
    _emailController.text = input.contact.email;
    _fullNameController.text = input.shipping.recipientName;
    _phoneController.text = input.shipping.phone;
    _postalCodeController.text = input.shipping.postalCode;
    _stateController.text = input.shipping.state;
    _cityController.text = input.shipping.city;
    _addressLine1Controller.text = input.shipping.addressLine1;
    _addressLine2Controller.text = input.shipping.addressLine2;
    _orderNoteController.text = input.orderNote;
    _countryCode = _normalizedCountryCode(input.shipping.countryCode);
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    final locale = Localizations.localeOf(context).languageCode;
    final input = _inputFromControllers(locale: locale);
    final errors = _validateInput(context, input);
    if (errors.isNotEmpty) {
      setState(() {
        _validationErrors = errors;
        _hasSaved = false;
      });
      _scrollToValidationSummary();
      return;
    }

    setState(() {
      _validationErrors = const [];
      _isSaving = true;
      _hasSaved = false;
    });
    try {
      await widget.onSave?.call(input);
      if (!mounted) {
        return;
      }
      setState(() => _hasSaved = true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  OrderDraftInput _inputFromControllers({required String locale}) {
    return widget.input.copyWith(
      contact: OrderDraftContactInput(
        email: _emailController.text.trim(),
        preferredLocale: locale,
      ),
      shipping: OrderDraftShippingInput(
        countryCode: _countryCode.trim().toUpperCase(),
        recipientName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        state: _stateController.text.trim(),
        city: _cityController.text.trim(),
        addressLine1: _addressLine1Controller.text.trim(),
        addressLine2: _addressLine2Controller.text.trim(),
      ),
      orderNote: _orderNoteController.text.trim(),
    );
  }

  void _scrollToValidationSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final summaryContext = _validationSummaryKey.currentContext;
      if (summaryContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        summaryContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _scrollToField(_CheckoutInputField field) {
    final fieldContext = _fieldKeys[field]?.currentContext;
    if (fieldContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  String? _errorTextFor(_CheckoutInputField field) {
    for (final error in _validationErrors) {
      if (error.field == field) {
        return error.message;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final countryCodes = _countryCodesForSelection(_countryCode);

    return _OrderScreenFrame(
      title: l10n.checkoutInputTitle,
      onBack: widget.onBack,
      children: [
        Text(l10n.checkoutInputMessage, style: HankoTextStyles.body),
        const SizedBox(height: HankoSpacing.md),
        if (_validationErrors.isNotEmpty) ...[
          _CheckoutValidationSummary(
            key: _validationSummaryKey,
            errors: _validationErrors,
            onSelectField: _scrollToField,
          ),
          const SizedBox(height: HankoSpacing.md),
        ],
        _CheckoutSectionCard(
          icon: Icons.alternate_email,
          title: l10n.checkoutContactTitle,
          children: [
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.email],
              child: HankoTextField(
                key: const Key('checkout-email-field'),
                label: l10n.email,
                hintText: l10n.emailHint,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                errorText: _errorTextFor(_CheckoutInputField.email),
              ),
            ),
            const SizedBox(height: HankoSpacing.md),
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.fullName],
              child: HankoTextField(
                key: const Key('checkout-full-name-field'),
                label: l10n.checkoutFullNameLabel,
                hintText: l10n.checkoutFullNameHint,
                controller: _fullNameController,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                errorText: _errorTextFor(_CheckoutInputField.fullName),
              ),
            ),
            const SizedBox(height: HankoSpacing.md),
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.phone],
              child: HankoTextField(
                key: const Key('checkout-phone-field'),
                label: l10n.checkoutPhoneLabel,
                hintText: l10n.checkoutPhoneHint,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                errorText: _errorTextFor(_CheckoutInputField.phone),
              ),
            ),
          ],
        ),
        const SizedBox(height: HankoSpacing.md),
        _CheckoutSectionCard(
          icon: Icons.local_shipping_outlined,
          title: l10n.checkoutShippingTitle,
          children: [
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.country],
              child: DropdownButtonFormField<String>(
                key: const Key('checkout-country-field'),
                initialValue: _countryCode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.checkoutCountryLabel,
                  errorText: _errorTextFor(_CheckoutInputField.country),
                ),
                items: [
                  for (final code in countryCodes)
                    DropdownMenuItem(
                      value: code,
                      child: Text(_countryMenuLabel(code)),
                    ),
                ],
                onChanged: (countryCode) {
                  if (countryCode == null) {
                    return;
                  }
                  setState(() => _countryCode = countryCode);
                },
              ),
            ),
            const SizedBox(height: HankoSpacing.md),
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.postalCode],
              child: HankoTextField(
                key: const Key('checkout-postal-code-field'),
                label: l10n.checkoutPostalCodeLabel,
                hintText: l10n.checkoutPostalCodeHint,
                controller: _postalCodeController,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                errorText: _errorTextFor(_CheckoutInputField.postalCode),
              ),
            ),
            const SizedBox(height: HankoSpacing.md),
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.addressLine1],
              child: HankoTextField(
                key: const Key('checkout-address-line1-field'),
                label: l10n.checkoutAddressLine1Label,
                hintText: l10n.checkoutAddressLine1Hint,
                controller: _addressLine1Controller,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                errorText: _errorTextFor(_CheckoutInputField.addressLine1),
              ),
            ),
            const SizedBox(height: HankoSpacing.md),
            HankoTextField(
              key: const Key('checkout-address-line2-field'),
              label: l10n.checkoutAddressLine2Label,
              hintText: l10n.checkoutAddressLine2Hint,
              controller: _addressLine2Controller,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: HankoSpacing.md),
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.city],
              child: HankoTextField(
                key: const Key('checkout-city-field'),
                label: l10n.checkoutCityLabel,
                hintText: l10n.checkoutCityHint,
                controller: _cityController,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                errorText: _errorTextFor(_CheckoutInputField.city),
              ),
            ),
            const SizedBox(height: HankoSpacing.md),
            _CheckoutFieldAnchor(
              fieldKey: _fieldKeys[_CheckoutInputField.state],
              child: HankoTextField(
                key: const Key('checkout-state-field'),
                label: l10n.checkoutStateLabel,
                hintText: l10n.checkoutStateHint,
                controller: _stateController,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                errorText: _errorTextFor(_CheckoutInputField.state),
              ),
            ),
          ],
        ),
        const SizedBox(height: HankoSpacing.md),
        _CheckoutSectionCard(
          icon: Icons.notes_outlined,
          title: l10n.checkoutOrderNoteTitle,
          children: [
            TextFormField(
              key: const Key('checkout-order-note-field'),
              controller: _orderNoteController,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.checkoutOrderNoteLabel,
                hintText: l10n.checkoutOrderNoteHint,
              ),
            ),
          ],
        ),
        if (_hasSaved) ...[
          const SizedBox(height: HankoSpacing.md),
          _OrderNotice(message: l10n.checkoutInputSavedMessage),
        ],
        const SizedBox(height: HankoSpacing.md),
        HankoPrimaryButton(
          label: _isSaving
              ? l10n.checkoutInputSavingAction
              : l10n.checkoutInputSaveAction,
          icon: Icons.save_outlined,
          onPressed: _isSaving ? null : _save,
          height: 58,
        ),
      ],
    );
  }
}

enum _CheckoutInputField {
  email,
  fullName,
  phone,
  country,
  postalCode,
  addressLine1,
  city,
  state,
}

class _CheckoutValidationError {
  const _CheckoutValidationError({
    required this.field,
    required this.label,
    required this.message,
  });

  final _CheckoutInputField field;
  final String label;
  final String message;
}

class _CheckoutValidationSummary extends StatelessWidget {
  const _CheckoutValidationSummary({
    super.key,
    required this.errors,
    required this.onSelectField,
  });

  final List<_CheckoutValidationError> errors;
  final ValueChanged<_CheckoutInputField> onSelectField;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: HankoColors.error),
              const SizedBox(width: HankoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.checkoutValidationTitle,
                      style: HankoTextStyles.cardTitle.copyWith(
                        color: HankoColors.error,
                      ),
                    ),
                    const SizedBox(height: HankoSpacing.xs),
                    Text(
                      l10n.checkoutValidationMessage,
                      style: HankoTextStyles.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HankoSpacing.md),
          for (final error in errors) ...[
            TextButton(
              onPressed: () => onSelectField(error.field),
              style: TextButton.styleFrom(
                foregroundColor: HankoColors.error,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.arrow_downward, size: 18),
                  ),
                  const SizedBox(width: HankoSpacing.sm),
                  Expanded(
                    child: Text(
                      '${error.label}: ${error.message}',
                      style: HankoTextStyles.body.copyWith(
                        color: HankoColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (error != errors.last)
              const Divider(color: HankoColors.surfaceBorder, height: 1),
          ],
        ],
      ),
    );
  }
}

class _CheckoutFieldAnchor extends StatelessWidget {
  const _CheckoutFieldAnchor({required this.fieldKey, required this.child});

  final Key? fieldKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: fieldKey, child: child);
  }
}

class _CheckoutSectionCard extends StatelessWidget {
  const _CheckoutSectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: HankoColors.gold, size: 22),
              const SizedBox(width: HankoSpacing.sm),
              Expanded(child: Text(title, style: HankoTextStyles.sectionTitle)),
            ],
          ),
          const SizedBox(height: HankoSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _OrderScreenFrame extends StatelessWidget {
  const _OrderScreenFrame({
    required this.title,
    required this.children,
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HankoColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, HankoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OrderHeader(title: title, onBack: onBack),
              const SizedBox(height: HankoSpacing.md),
              const _OrderTitleDivider(),
              const SizedBox(height: HankoSpacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: context.l10n.back,
                onPressed: onBack,
                color: HankoColors.gold,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: HankoTextStyles.pageTitle.copyWith(
                  color: HankoColors.ink,
                  fontSize: 31,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTitleDivider extends StatelessWidget {
  const _OrderTitleDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: HankoColors.gold, thickness: 0.8)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: HankoSpacing.md),
          child: Icon(
            Icons.diamond_outlined,
            color: HankoColors.gold,
            size: 18,
          ),
        ),
        Expanded(child: Divider(color: HankoColors.gold, thickness: 0.8)),
      ],
    );
  }
}

class _MissingSelectionCard extends StatelessWidget {
  const _MissingSelectionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = _MissingPreview(icon: icon);
          final detail = _MissingSelectionDetails(
            title: title,
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          );
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: preview),
                const SizedBox(height: HankoSpacing.md),
                detail,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              preview,
              const SizedBox(width: HankoSpacing.lg),
              Expanded(child: detail),
            ],
          );
        },
      ),
    );
  }
}

class _MissingPreview extends StatelessWidget {
  const _MissingPreview({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 132,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HankoColors.surface,
          border: Border.all(color: HankoColors.surfaceBorder, width: 1.2),
          borderRadius: BorderRadius.circular(HankoRadii.sm),
        ),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HankoColors.medallion,
              borderRadius: BorderRadius.circular(HankoRadii.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(HankoSpacing.md),
              child: Icon(icon, color: HankoColors.gold, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingSelectionDetails extends StatelessWidget {
  const _MissingSelectionDetails({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: HankoTextStyles.sectionTitle),
        const SizedBox(height: HankoSpacing.md),
        const _OrderTitleDivider(),
        const SizedBox(height: HankoSpacing.md),
        Text(message, style: HankoTextStyles.body),
        const SizedBox(height: HankoSpacing.md),
        _SecondaryOrderAction(
          label: actionLabel,
          icon: Icons.arrow_forward,
          onPressed: onAction,
        ),
      ],
    );
  }
}

class _SecondaryOrderAction extends StatelessWidget {
  const _SecondaryOrderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: HankoColors.gold,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: HankoColors.gold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: HankoTextStyles.label.copyWith(color: HankoColors.gold),
      ),
    );
  }
}

class _SealSummaryCard extends StatelessWidget {
  const _SealSummaryCard({
    required this.selection,
    this.actionLabel,
    this.onAction,
  });

  final OrderDraftSealSelection selection;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = _OrderSealPreview(selection: selection);
          final detail = _SealSummaryDetails(
            selection: selection,
            actionLabel: actionLabel,
            onAction: onAction,
          );
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: preview),
                const SizedBox(height: HankoSpacing.md),
                detail,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              preview,
              const SizedBox(width: HankoSpacing.lg),
              Expanded(child: detail),
            ],
          );
        },
      ),
    );
  }
}

class _SealSummaryDetails extends StatelessWidget {
  const _SealSummaryDetails({
    required this.selection,
    required this.actionLabel,
    required this.onAction,
  });

  final OrderDraftSealSelection selection;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderDetailLine(
          label: l10n.kanjiLabel,
          value: selection.selectedKanji,
        ),
        _OrderDetailLine(
          label: l10n.sealStyleNameLabel,
          value: _sealStyleLabel(l10n, selection.style),
        ),
        _OrderDetailLine(
          label: l10n.sealShapeLabel,
          value: _sealShapeLabel(l10n, selection.shape),
          hasDivider: false,
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: HankoSpacing.md),
          _SecondaryOrderAction(
            label: actionLabel!,
            icon: Icons.arrow_forward,
            onPressed: onAction,
          ),
        ],
      ],
    );
  }
}

class _OrderSealPreview extends StatelessWidget {
  const _OrderSealPreview({required this.selection});

  final OrderDraftSealSelection selection;

  @override
  Widget build(BuildContext context) {
    final localPath = selection.localImagePath.trim();
    final localFile = localPath.isEmpty ? null : File(localPath);
    final previewUrl = selection.previewImageDownloadUrl.trim();
    final fallback = _SealPreviewFallback(text: selection.selectedKanji);

    final Widget preview;
    if (localFile != null && localFile.existsSync()) {
      preview = Image.file(
        localFile,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (previewUrl.isNotEmpty) {
      preview = Image.network(
        previewUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return fallback;
        },
      );
    } else {
      preview = fallback;
    }

    return SizedBox.square(
      dimension: 132,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HankoRadii.sm),
        child: preview,
      ),
    );
  }
}

class _SealPreviewFallback extends StatelessWidget {
  const _SealPreviewFallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HankoColors.medallion,
        border: Border.all(color: HankoColors.red, width: 2.4),
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HankoTextStyles.heroTitle.copyWith(
            color: HankoColors.red,
            fontSize: 38,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

class _StoneSummaryCard extends StatelessWidget {
  const _StoneSummaryCard({
    required this.selection,
    this.actionLabel,
    this.onAction,
  });

  final OrderDraftStoneSelection selection;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _OrderStonePreview(selection: selection),
          const SizedBox(width: HankoSpacing.lg),
          Expanded(
            child: _StoneSummaryDetails(
              selection: selection,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStonePreview extends StatelessWidget {
  const _OrderStonePreview({required this.selection});

  final OrderDraftStoneSelection selection;

  @override
  Widget build(BuildContext context) {
    final fallback = const _StonePreviewFallback();
    final photoUrl = selection.primaryPhotoUrl.trim();
    final Widget preview = photoUrl.isEmpty
        ? fallback
        : Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return fallback;
            },
          );

    return SizedBox(
      width: 118,
      height: 112,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HankoRadii.sm),
        child: preview,
      ),
    );
  }
}

class _StonePreviewFallback extends StatelessWidget {
  const _StonePreviewFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: HankoColors.medallion),
      child: Center(
        child: Icon(Icons.diamond_outlined, color: HankoColors.gold, size: 42),
      ),
    );
  }
}

class _StoneSummaryDetails extends StatelessWidget {
  const _StoneSummaryDetails({
    required this.selection,
    required this.actionLabel,
    required this.onAction,
  });

  final OrderDraftStoneSelection selection;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          selection.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HankoTextStyles.cardTitle,
        ),
        const SizedBox(height: HankoSpacing.sm),
        Text(
          _stoneSubtitle(selection),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HankoTextStyles.body,
        ),
        const SizedBox(height: HankoSpacing.md),
        Text(_formatMoney(selection.price), style: HankoTextStyles.label),
        const SizedBox(height: HankoSpacing.md),
        _StatusPill(
          label: selection.isOrderable
              ? l10n.stoneAvailable
              : l10n.stoneUnavailable,
          available: selection.isOrderable,
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: HankoSpacing.md),
          _SecondaryOrderAction(
            label: actionLabel!,
            icon: Icons.arrow_forward,
            onPressed: onAction,
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.available});

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? const Color(0xFF5F8F57) : HankoColors.error;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(HankoRadii.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 8),
              Text(label, style: HankoTextStyles.label.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailLine extends StatelessWidget {
  const _OrderDetailLine({
    required this.label,
    required this.value,
    this.hasDivider = true,
  });

  final String label;
  final String value;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: HankoTextStyles.compactBody),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HankoTextStyles.cardTitle,
        ),
        if (hasDivider) ...[
          const SizedBox(height: HankoSpacing.md),
          const Divider(color: HankoColors.surfaceBorder, height: 1),
          const SizedBox(height: HankoSpacing.md),
        ],
      ],
    );
  }
}

class _OrderPricingCard extends StatelessWidget {
  const _OrderPricingCard({required this.summary});

  final _OrderPricingSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          _PricingRow(
            label: l10n.orderItemPriceLabel,
            value: _formatMoney(summary.itemPrice),
          ),
          const Divider(color: HankoColors.surfaceBorder, height: 28),
          _PricingRow(
            label: l10n.orderShippingFeeLabel,
            value: _formatMoney(summary.shippingFee),
          ),
          const SizedBox(height: HankoSpacing.sm),
          Text(l10n.orderShippingEstimateNote, style: HankoTextStyles.body),
          const SizedBox(height: HankoSpacing.md),
          const _OrderTitleDivider(),
          const SizedBox(height: HankoSpacing.md),
          _PricingRow(
            label: l10n.orderTotalLabel,
            value: _formatMoney(summary.total),
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final valueStyle = isTotal
        ? HankoTextStyles.sectionTitle.copyWith(color: HankoColors.gold)
        : HankoTextStyles.cardTitle;
    final labelStyle = isTotal
        ? HankoTextStyles.cardTitle.copyWith(color: HankoColors.gold)
        : HankoTextStyles.body.copyWith(color: HankoColors.ink);

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: HankoSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class _OrderNotice extends StatelessWidget {
  const _OrderNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: HankoColors.gold),
          const SizedBox(width: HankoSpacing.md),
          Expanded(child: Text(message, style: HankoTextStyles.body)),
        ],
      ),
    );
  }
}

class _OrderPricingSummary {
  const _OrderPricingSummary({
    required this.itemPrice,
    required this.shippingFee,
    required this.total,
  });

  factory _OrderPricingSummary.fromDraft(OrderDraft draft) {
    final itemPrice =
        draft.stoneSelection?.price ?? const Money(amount: 0, currency: 'JPY');
    final shippingFee = Money(
      amount: _estimatedShippingAmount(
        currency: itemPrice.currency,
        countryCode: draft.input.shipping.countryCode,
      ),
      currency: itemPrice.currency,
    );
    return _OrderPricingSummary(
      itemPrice: itemPrice,
      shippingFee: shippingFee,
      total: Money(
        amount: itemPrice.amount + shippingFee.amount,
        currency: itemPrice.currency,
      ),
    );
  }

  final Money itemPrice;
  final Money shippingFee;
  final Money total;
}

int _estimatedShippingAmount({
  required String currency,
  required String countryCode,
}) {
  final normalizedCountry = countryCode.trim().toUpperCase();
  final normalizedCurrency = currency.trim().toUpperCase();
  if (normalizedCurrency != 'JPY' && normalizedCurrency != 'USD') {
    return 0;
  }

  return switch (normalizedCountry) {
    'US' => 1800,
    'CA' => 1900,
    'GB' => 2000,
    'AU' => 2100,
    'SG' => 1300,
    _ => 600,
  };
}

List<_CheckoutValidationError> _validateInput(
  BuildContext context,
  OrderDraftInput input,
) {
  final l10n = context.l10n;
  final errors = <_CheckoutValidationError>[];
  final email = input.contact.email.trim();
  final phone = input.shipping.phone.trim();

  void addError({
    required _CheckoutInputField field,
    required String label,
    required String message,
  }) {
    errors.add(
      _CheckoutValidationError(field: field, label: label, message: message),
    );
  }

  if (!_isValidEmail(email)) {
    addError(
      field: _CheckoutInputField.email,
      label: l10n.email,
      message: l10n.checkoutEmailInvalidMessage,
    );
  }
  if (input.shipping.recipientName.trim().isEmpty) {
    addError(
      field: _CheckoutInputField.fullName,
      label: l10n.checkoutFullNameLabel,
      message: l10n.checkoutFullNameRequiredMessage,
    );
  }
  if (!_isValidPhone(phone)) {
    addError(
      field: _CheckoutInputField.phone,
      label: l10n.checkoutPhoneLabel,
      message: l10n.checkoutPhoneInvalidMessage,
    );
  }
  if (input.shipping.countryCode.trim().isEmpty) {
    addError(
      field: _CheckoutInputField.country,
      label: l10n.checkoutCountryLabel,
      message: l10n.checkoutCountryRequiredMessage,
    );
  }
  if (input.shipping.postalCode.trim().isEmpty) {
    addError(
      field: _CheckoutInputField.postalCode,
      label: l10n.checkoutPostalCodeLabel,
      message: l10n.checkoutPostalCodeRequiredMessage,
    );
  }
  if (input.shipping.addressLine1.trim().isEmpty) {
    addError(
      field: _CheckoutInputField.addressLine1,
      label: l10n.checkoutAddressLine1Label,
      message: l10n.checkoutAddressLine1RequiredMessage,
    );
  }
  if (input.shipping.city.trim().isEmpty) {
    addError(
      field: _CheckoutInputField.city,
      label: l10n.checkoutCityLabel,
      message: l10n.checkoutCityRequiredMessage,
    );
  }
  if (input.shipping.state.trim().isEmpty) {
    addError(
      field: _CheckoutInputField.state,
      label: l10n.checkoutStateLabel,
      message: l10n.checkoutStateRequiredMessage,
    );
  }

  return errors;
}

bool _isValidEmail(String value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
}

bool _isValidPhone(String value) {
  final digitCount = RegExp(r'\d').allMatches(value).length;
  final hasOnlyPhoneCharacters = RegExp(r'^[0-9+()\-\s.]+$').hasMatch(value);
  return digitCount >= 6 && hasOnlyPhoneCharacters;
}

String _normalizedCountryCode(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized.isEmpty
      ? _CheckoutInputScreenState._defaultCountryCode
      : normalized;
}

List<String> _countryCodesForSelection(String selectedCountryCode) {
  if (_CheckoutInputScreenState._knownCountryCodes.contains(
    selectedCountryCode,
  )) {
    return _CheckoutInputScreenState._knownCountryCodes;
  }
  return [selectedCountryCode, ..._CheckoutInputScreenState._knownCountryCodes];
}

String _countryMenuLabel(String code) {
  return switch (code) {
    'JP' => 'JP - Japan',
    'US' => 'US - United States',
    'CA' => 'CA - Canada',
    'GB' => 'GB - United Kingdom',
    'AU' => 'AU - Australia',
    'SG' => 'SG - Singapore',
    _ => code,
  };
}

String _stoneSubtitle(OrderDraftStoneSelection selection) {
  final material = selection.materialLabel.trim().isNotEmpty
      ? selection.materialLabel.trim()
      : _labelFromToken(selection.materialKey);
  final size = selection.sizeLabel.trim();
  if (size.isEmpty) {
    return material;
  }
  return '$material / $size';
}

String _sealShapeLabel(HankoLocalizations l10n, String value) {
  return switch (value.trim().toLowerCase()) {
    'square' => l10n.sealShapeSquare,
    'round' => l10n.sealShapeRound,
    _ => _labelFromToken(value),
  };
}

String _sealStyleLabel(HankoLocalizations l10n, String value) {
  return switch (value.trim().toLowerCase()) {
    'traditional' => l10n.sealStyleTraditional,
    'elegant' => l10n.sealStyleElegant,
    'soft' => l10n.sealStyleSoft,
    'bold' => l10n.sealStyleBold,
    _ => _labelFromToken(value),
  };
}

String _formatMoney(Money money) {
  final display = money.display?.trim();
  if (display != null && display.isNotEmpty) {
    return display;
  }
  final formattedAmount = _formatWholeNumber(money.amount);
  return switch (money.currency.toUpperCase()) {
    'JPY' => '¥$formattedAmount',
    'USD' => '\$$formattedAmount',
    _ => '${money.currency.toUpperCase()} $formattedAmount',
  };
}

String _formatWholeNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer(sign);
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _labelFromToken(String token) {
  final words = token
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return token;
  }
  return words
      .map((word) {
        if (word.length == 1) {
          return word.toUpperCase();
        }
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}
