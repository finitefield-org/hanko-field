// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/checkout/view_model/checkout_address_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
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
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(checkoutAddressViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: const BackButton(),
        title: Text(prefersEnglish ? 'Shipping address' : '配送先'),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Add address' : '住所を追加',
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
            prefersEnglish: prefersEnglish,
            gates: gates,
            state: state,
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(
        context: context,
        prefersEnglish: prefersEnglish,
        state: state,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required bool prefersEnglish,
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
          title: prefersEnglish ? 'Could not load addresses' : '住所を読み込めません',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
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
          _PersonaHint(prefersEnglish: prefersEnglish, gates: gates),
          SizedBox(height: tokens.spacing.lg),
          Expanded(
            child: AppEmptyState(
              title: prefersEnglish ? 'Add your first address' : '住所を追加してください',
              message: prefersEnglish
                  ? 'Save a shipping address to continue checkout.'
                  : '配送先を登録すると、次のステップに進めます。',
              icon: Icons.home_work_outlined,
              actionLabel: prefersEnglish ? 'Add address' : '住所を追加',
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
        _PersonaHint(prefersEnglish: prefersEnglish, gates: gates),
        SizedBox(height: tokens.spacing.sm),
        Text(
          prefersEnglish
              ? 'Choose where to ship your order.'
              : '配送先を選択し、必要に応じて編集してください。',
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
                  prefersEnglish: prefersEnglish,
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
          label: prefersEnglish ? 'Add another address' : '住所を追加',
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
    required bool prefersEnglish,
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
        label: prefersEnglish ? 'Continue to shipping' : '配送方法へ進む',
        expand: true,
        isLoading: isSaving,
        onPressed: selected == null || isSaving
            ? null
            : () => _confirmAndNext(prefersEnglish),
      ),
    );
  }

  Future<void> _confirmAndNext(bool prefersEnglish) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await ref.invoke(
      checkoutAddressViewModel.confirmSelection(),
    );
    if (result == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish ? 'Select an address to continue' : '配送先を選択してください',
          ),
        ),
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
    final prefersEnglish = gates.prefersEnglish;
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
      builder: (context) =>
          _AddressFormDialog(initial: initial, prefersEnglish: prefersEnglish),
    );

    if (!mounted || result == null || !result.isSuccess) return;

    final messenger = ScaffoldMessenger.of(context);
    final message = prefersEnglish
        ? (result.created ? 'Address added' : 'Address updated')
        : (result.created ? '住所を追加しました' : '住所を更新しました');
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.selected,
    required this.selectedId,
    required this.prefersEnglish,
    required this.onSelect,
    required this.onEdit,
  });

  final UserAddress address;
  final bool selected;
  final String? selectedId;
  final bool prefersEnglish;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <String>[
      if (selected) prefersEnglish ? 'Shipping' : '配送先',
      if (address.isDefault) prefersEnglish ? 'Default' : '既定',
      if (address.isDefault) prefersEnglish ? 'Billing' : '請求先',
      if (address.country.toUpperCase() != 'JP')
        (prefersEnglish ? 'International' : '海外配送'),
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
                        address.label ??
                            (prefersEnglish ? 'Shipping address' : '配送先'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: onEdit,
                      child: Text(prefersEnglish ? 'Edit' : '編集'),
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
                  _formatAddress(address, prefersEnglish),
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
  const _PersonaHint({required this.prefersEnglish, required this.gates});

  final bool prefersEnglish;
  final AppExperienceGates gates;

  @override
  Widget build(BuildContext context) {
    final message = prefersEnglish
        ? (gates.isJapanRegion
              ? 'Use postal lookup for Japanese addresses; include building name.'
              : 'For international shipping, enter romanized names and a phone with country code.')
        : (gates.isJapanRegion
              ? '郵便番号から住所を補完できます。建物名・部屋番号まで入力してください。'
              : '海外配送の場合はローマ字表記と国番号付き電話を入力してください。');

    return AppValidationMessage(
      message: message,
      state: AppValidationState.info,
    );
  }
}

class _AddressFormDialog extends ConsumerStatefulWidget {
  const _AddressFormDialog({
    required this.initial,
    required this.prefersEnglish,
  });

  final AddressFormInput initial;
  final bool prefersEnglish;

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
    final prefersEnglish = widget.prefersEnglish;
    final saveState = ref.watch(checkoutAddressViewModel.saveAddressMut);
    final lookupState = ref.watch(checkoutAddressViewModel.postalLookupMut);
    final isSaving = saveState is PendingMutationState;
    final isLookingUp = lookupState is PendingMutationState;

    final title = _draft.id == null
        ? (prefersEnglish ? 'Add address' : '住所を追加')
        : (prefersEnglish ? 'Edit address' : '住所を編集');

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: prefersEnglish ? 'Close' : '閉じる',
            onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          ),
          title: Text(title),
          actions: [
            TextButton(
              onPressed: isSaving ? null : _submit,
              child: Text(prefersEnglish ? 'Save' : '保存'),
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
                  prefersEnglish: prefersEnglish,
                  gates: ref.container.read(appExperienceGatesProvider),
                ),
                SizedBox(height: tokens.spacing.md),
                SegmentedButton<AddressFormLayout>(
                  segments: [
                    ButtonSegment(
                      value: AddressFormLayout.domestic,
                      label: Text(prefersEnglish ? 'Domestic (JP)' : '国内'),
                      icon: const Icon(Icons.flag),
                    ),
                    ButtonSegment(
                      value: AddressFormLayout.international,
                      label: Text(prefersEnglish ? 'International' : '海外'),
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
                  label: prefersEnglish ? 'Label (optional)' : 'ラベル（任意）',
                  controller: _labelController,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(label: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Recipient' : '受取人',
                  controller: _recipientController,
                  errorText: _errors['recipient'],
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(recipient: value),
                  ),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Company (optional)' : '会社名（任意）',
                  controller: _companyController,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(company: value)),
                ),
                SizedBox(height: tokens.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: prefersEnglish ? 'Postal code' : '郵便番号',
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
                      label: Text(prefersEnglish ? 'Lookup' : '住所補完'),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Prefecture/State' : '都道府県・州',
                  controller: _stateController,
                  errorText: _errors['state'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(state: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'City/Ward' : '市区町村',
                  controller: _cityController,
                  errorText: _errors['city'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(city: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Address line 1' : '番地・町名',
                  controller: _line1Controller,
                  errorText: _errors['line1'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(line1: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish
                      ? 'Address line 2 (optional)'
                      : '建物名・部屋番号（任意）',
                  controller: _line2Controller,
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(line2: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Country/Region' : '国・地域',
                  controller: _countryController,
                  enabled: _draft.layout == AddressFormLayout.international,
                  errorText: _errors['country'],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(country: value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish
                      ? 'Phone (with country code)'
                      : '電話番号（国番号付き推奨）',
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
                  title: Text(prefersEnglish ? 'Use as default' : '既定の住所にする'),
                  subtitle: Text(
                    prefersEnglish
                        ? 'Default address is pre-selected in checkout.'
                        : '既定の住所はチェックアウトで自動選択されます。',
                  ),
                ),
                SizedBox(height: tokens.spacing.xl),
                AppButton(
                  label: prefersEnglish ? 'Save address' : '保存する',
                  expand: true,
                  isLoading: isSaving,
                  onPressed: isSaving ? null : _submit,
                  leading: const Icon(Icons.check),
                ),
                if (_errors.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.md),
                  AppValidationMessage(
                    message: prefersEnglish
                        ? 'Please correct the highlighted fields.'
                        : 'エラーを修正してください。',
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

String _formatAddress(UserAddress address, bool prefersEnglish) {
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
