// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/checkout/view_model/checkout_address_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/forms/app_text_field.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class CheckoutAddressPage extends ConsumerStatefulWidget {
  const CheckoutAddressPage({super.key});

  @override
  ConsumerState<CheckoutAddressPage> createState() =>
      _CheckoutAddressPageState();
}

class _CheckoutAddressPageState extends ConsumerState<CheckoutAddressPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final state = ref.watch(checkoutAddressViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: const BackButton(),
        title: Text(l10n.checkoutAddressTitle),
        actions: [
          IconButton(
            tooltip: l10n.checkoutAddressAddTooltip,
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          child: _buildBody(
            context: context,
            l10n: l10n,
            gates: gates,
            state: state,
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(
        context: context,
        l10n: l10n,
        state: state,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AppLocalizations l10n,
    required AppExperienceGates gates,
    required AsyncValue<CheckoutAddressState> state,
  }) {
    final tokens = DesignTokensTheme.of(context);

    if (state is AsyncLoading<CheckoutAddressState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 3, itemHeight: 120),
      );
    }

    if (state is AsyncError<CheckoutAddressState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: l10n.checkoutAddressLoadFailedTitle,
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: l10n.commonRetry,
          onAction: () =>
              ref.refreshValue(checkoutAddressViewModel, keepPrevious: false),
        ),
      );
    }

    final data = state.valueOrNull ?? const CheckoutAddressState(addresses: []);
    if (data.addresses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PersonaHint(l10n: l10n, gates: gates),
          SizedBox(height: tokens.spacing.lg),
          Expanded(
            child: AppEmptyState(
              title: l10n.checkoutAddressEmptyTitle,
              message: l10n.checkoutAddressEmptyMessage,
              icon: Icons.home_work_outlined,
              actionLabel: l10n.checkoutAddressAddAction,
              onAction: () => _openForm(makeDefault: true),
            ),
          ),
        ],
      );
    }

    final selectedId = data.selectedAddressId ?? data.selectedAddress?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PersonaHint(l10n: l10n, gates: gates),
        SizedBox(height: tokens.spacing.sm),
        Text(
          l10n.checkoutAddressChooseHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.refreshValue(checkoutAddressViewModel, keepPrevious: true),
            edgeOffset: tokens.spacing.sm,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: data.addresses.length,
              separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
              itemBuilder: (context, index) {
                final address = data.addresses[index];
                final isSelected =
                    selectedId != null && address.id == selectedId;
                return _AddressTile(
                  address: address,
                  selected: isSelected,
                  selectedId: selectedId,
                  l10n: l10n,
                  onSelect: () => ref.invoke(
                    checkoutAddressViewModel.selectAddress(address.id),
                  ),
                  onEdit: () => _openForm(editing: address),
                );
              },
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        AppButton(
          label: l10n.checkoutAddressAddAnother,
          variant: AppButtonVariant.ghost,
          leading: const Icon(Icons.add),
          expand: true,
          onPressed: () => _openForm(),
        ),
      ],
    );
  }

  Widget _buildFooter({
    required BuildContext context,
    required AppLocalizations l10n,
    required AsyncValue<CheckoutAddressState> state,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final confirmState = ref.watch(
      checkoutAddressViewModel.confirmSelectionMut,
    );
    final isSaving = confirmState is PendingMutationState;
    final selected = state.valueOrNull?.selectedAddress;

    return SafeArea(
      minimum: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.sm,
        tokens.spacing.lg,
        tokens.spacing.md,
      ),
      child: AppButton(
        label: l10n.checkoutAddressContinueShipping,
        expand: true,
        isLoading: isSaving,
        onPressed: selected == null || isSaving
            ? null
            : () => _confirmAndNext(l10n),
      ),
    );
  }

  Future<void> _confirmAndNext(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await ref.invoke(
      checkoutAddressViewModel.confirmSelection(),
    );
    if (result == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.checkoutAddressSelectRequired)),
      );
      return;
    }
    if (!mounted) return;
    router.go(AppRoutePaths.checkoutShipping);
  }

  Future<void> _openForm({
    UserAddress? editing,
    bool makeDefault = false,
  }) async {
    final gates = ref.container.read(appExperienceGatesProvider);
    final l10n = AppLocalizations.of(context);
    final existing =
        ref.container.read(checkoutAddressViewModel).valueOrNull?.addresses ??
        const [];
    final defaultLayout = gates.isJapanRegion
        ? AddressFormLayout.domestic
        : AddressFormLayout.international;
    final initial = editing == null
        ? AddressFormInput(
            label: '',
            recipient: '',
            company: '',
            line1: '',
            line2: '',
            city: '',
            state: '',
            postalCode: '',
            country: defaultLayout == AddressFormLayout.domestic ? 'JP' : '',
            phone: '',
            isDefault: makeDefault || existing.isEmpty,
            layout: defaultLayout,
          )
        : AddressFormInput(
            id: editing.id,
            label: editing.label ?? '',
            recipient: editing.recipient,
            company: editing.company ?? '',
            line1: editing.line1,
            line2: editing.line2 ?? '',
            city: editing.city,
            state: editing.state ?? '',
            postalCode: editing.postalCode,
            country: editing.country,
            phone: editing.phone ?? '',
            isDefault: editing.isDefault,
            layout: editing.country.toUpperCase() == 'JP'
                ? AddressFormLayout.domestic
                : AddressFormLayout.international,
          );

    final result = await showDialog<AddressSaveResult>(
      context: context,
      builder: (context) => _AddressFormDialog(initial: initial),
    );

    if (!mounted || result == null || !result.isSuccess) return;

    final messenger = ScaffoldMessenger.of(context);
    final message = result.created
        ? l10n.checkoutAddressSavedCreated
        : l10n.checkoutAddressSavedUpdated;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.selected,
    required this.selectedId,
    required this.l10n,
    required this.onSelect,
    required this.onEdit,
  });

  final UserAddress address;
  final bool selected;
  final String? selectedId;
  final AppLocalizations l10n;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <String>[
      if (selected) l10n.checkoutAddressChipShipping,
      if (address.isDefault) l10n.checkoutAddressChipDefault,
      if (address.isDefault) l10n.checkoutAddressChipBilling,
      if (address.country.toUpperCase() != 'JP')
        l10n.checkoutAddressChipInternational,
    ];

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      backgroundColor: selected
          ? colorScheme.primary.withValues(alpha: 0.04)
          : tokens.colors.surface,
      onTap: onSelect,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: tokens.spacing.md),
            child: Icon(
              Icons.place_outlined,
              color: selected ? colorScheme.primary : tokens.colors.onSurface,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        address.label ?? l10n.checkoutAddressLabelFallback,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: onEdit,
                      child: Text(l10n.checkoutAddressEditAction),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  address.recipient,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  _formatAddress(address),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                if (address.phone != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    address.phone!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.sm),
                Wrap(
                  spacing: tokens.spacing.xs,
                  runSpacing: tokens.spacing.xs,
                  children: chips
                      .map(
                        (chip) => InputChip(
                          label: Text(chip),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.check, size: 16),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: tokens.spacing.sm),
            // Radio groupValue/onChanged are deprecated in Flutter 3.32; keeping for now until RadioGroup is adopted.
            // ignore: deprecated_member_use
            child: Radio<String>(
              value: address.id ?? '',
              // ignore: deprecated_member_use
              groupValue: selectedId ?? '',
              // ignore: deprecated_member_use
              onChanged: (_) => onSelect(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaHint extends StatelessWidget {
  const _PersonaHint({required this.l10n, required this.gates});

  final AppLocalizations l10n;
  final AppExperienceGates gates;

  @override
  Widget build(BuildContext context) {
    final message = gates.isJapanRegion
        ? l10n.checkoutAddressPersonaDomesticHint
        : l10n.checkoutAddressPersonaInternationalHint;

    return AppValidationMessage(
      message: message,
      state: AppValidationState.info,
    );
  }
}

class _AddressFormDialog extends ConsumerStatefulWidget {
  const _AddressFormDialog({required this.initial});

  final AddressFormInput initial;

  @override
  ConsumerState<_AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<_AddressFormDialog> {
  late AddressFormInput _draft = widget.initial;
  Map<String, String> _errors = const {};

  late final TextEditingController _labelController = TextEditingController(
    text: widget.initial.label,
  );
  late final TextEditingController _recipientController = TextEditingController(
    text: widget.initial.recipient,
  );
  late final TextEditingController _companyController = TextEditingController(
    text: widget.initial.company,
  );
  late final TextEditingController _postalController = TextEditingController(
    text: widget.initial.postalCode,
  );
  late final TextEditingController _stateController = TextEditingController(
    text: widget.initial.state,
  );
  late final TextEditingController _cityController = TextEditingController(
    text: widget.initial.city,
  );
  late final TextEditingController _line1Controller = TextEditingController(
    text: widget.initial.line1,
  );
  late final TextEditingController _line2Controller = TextEditingController(
    text: widget.initial.line2,
  );
  late final TextEditingController _countryController = TextEditingController(
    text: widget.initial.country,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.initial.phone,
  );

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _companyController.dispose();
    _postalController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final saveState = ref.watch(checkoutAddressViewModel.saveAddressMut);
    final lookupState = ref.watch(checkoutAddressViewModel.postalLookupMut);
    final isSaving = saveState is PendingMutationState;
    final isLookingUp = lookupState is PendingMutationState;

    final title = _draft.id == null
        ? l10n.checkoutAddressFormAddTitle
        : l10n.checkoutAddressFormEditTitle;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
            onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          ),
          title: Text(title),
          actions: [
            TextButton(
              onPressed: isSaving ? null : _submit,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PersonaHint(
                  l10n: l10n,
                  gates: ref.container.read(appExperienceGatesProvider),
                ),
                SizedBox(height: tokens.spacing.md),
                SegmentedButton<AddressFormLayout>(
                  segments: [
                    ButtonSegment(
                      value: AddressFormLayout.domestic,
                      label: Text(l10n.checkoutAddressFormDomesticLabel),
                      icon: const Icon(Icons.flag),
                    ),
                    ButtonSegment(
                      value: AddressFormLayout.international,
                      label: Text(l10n.checkoutAddressFormInternationalLabel),
                      icon: const Icon(Icons.public),
                    ),
                  ],
                  selected: {_draft.layout},
                  onSelectionChanged: (value) {
                    final layout = value.first;
                    setState(() {
                      _draft = _draft.copyWith(
                        layout: layout,
                        country: layout == AddressFormLayout.domestic
                            ? 'JP'
                            : _draft.country,
                      );
                      _countryController.text =
                          layout == AddressFormLayout.domestic
                          ? 'JP'
                          : _countryController.text;
                    });
                  },
                ),
                SizedBox(height: tokens.spacing.lg),
                AppTextField(
                  label: l10n.checkoutAddressFormLabelOptional,
                  controller: _labelController,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(label: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormRecipient,
                  controller: _recipientController,
                  errorText: _errors['recipient'],
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(recipient: value),
                  ),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormCompanyOptional,
                  controller: _companyController,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(company: value)),
                ),
                SizedBox(height: tokens.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: l10n.checkoutAddressFormPostalCode,
                        controller: _postalController,
                        keyboardType: TextInputType.number,
                        errorText: _errors['postalCode'],
                        onChanged: (value) => setState(
                          () => _draft = _draft.copyWith(postalCode: value),
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.sm),
                    TextButton.icon(
                      onPressed:
                          _draft.layout == AddressFormLayout.domestic &&
                              !isLookingUp
                          ? _lookupPostal
                          : null,
                      icon: isLookingUp
                          ? SizedBox(
                              width: tokens.spacing.md,
                              height: tokens.spacing.md,
                              child: const CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(l10n.checkoutAddressFormLookup),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormState,
                  controller: _stateController,
                  errorText: _errors['state'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(state: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormCity,
                  controller: _cityController,
                  errorText: _errors['city'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(city: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormLine1,
                  controller: _line1Controller,
                  errorText: _errors['line1'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(line1: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormLine2Optional,
                  controller: _line2Controller,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(line2: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormCountry,
                  controller: _countryController,
                  enabled: _draft.layout == AddressFormLayout.international,
                  errorText: _errors['country'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(country: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: l10n.checkoutAddressFormPhone,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  errorText: _errors['phone'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(phone: value)),
                ),
                SizedBox(height: tokens.spacing.lg),
                SwitchListTile.adaptive(
                  value: _draft.isDefault,
                  onChanged: isSaving
                      ? null
                      : (value) => setState(
                          () => _draft = _draft.copyWith(isDefault: value),
                        ),
                  title: Text(l10n.checkoutAddressFormDefaultTitle),
                  subtitle: Text(l10n.checkoutAddressFormDefaultSubtitle),
                ),
                SizedBox(height: tokens.spacing.xl),
                AppButton(
                  label: l10n.checkoutAddressFormSave,
                  expand: true,
                  isLoading: isSaving,
                  onPressed: isSaving ? null : _submit,
                  leading: const Icon(Icons.check),
                ),
                if (_errors.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.md),
                  AppValidationMessage(
                    message: l10n.checkoutAddressFormFixErrors,
                    state: AppValidationState.error,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _lookupPostal() async {
    final result = await ref.invoke(
      checkoutAddressViewModel.lookupPostalCode(_postalController.text),
    );
    if (result == null) return;

    setState(() {
      _stateController.text = result.state;
      _cityController.text = result.city;
      _line1Controller.text = result.line1Hint ?? _line1Controller.text;
      _draft = _draft.copyWith(
        state: _stateController.text,
        city: _cityController.text,
        line1: _line1Controller.text,
      );
    });
  }

  Future<void> _submit() async {
    final updated = _draft.copyWith(
      label: _labelController.text,
      recipient: _recipientController.text,
      company: _companyController.text,
      postalCode: _postalController.text,
      state: _stateController.text,
      city: _cityController.text,
      line1: _line1Controller.text,
      line2: _line2Controller.text,
      country: _countryController.text,
      phone: _phoneController.text,
    );
    setState(() {
      _draft = updated;
      _errors = const {};
    });

    final result = await ref.invoke(
      checkoutAddressViewModel.saveAddress(updated),
    );
    if (!result.validation.isValid) {
      setState(() {
        _errors = result.validation.fieldErrors;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
}

String _formatAddress(UserAddress address) {
  if (address.country.toUpperCase() == 'JP') {
    return '〒${address.postalCode} ${address.state ?? ''}${address.city} ${address.line1} ${address.line2 ?? ''}';
  }
  final parts = [
    address.line1,
    if (address.line2 != null) address.line2!,
    address.city,
    if (address.state != null) address.state!,
    address.postalCode,
    address.country,
  ];
  return parts.where((part) => part.isNotEmpty).join(', ');
}
