// ignore_for_file: public_member_api_docs, deprecated_member_use

import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/features/profile/view_model/profile_addresses_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/forms/app_text_field.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileAddressesPage extends ConsumerStatefulWidget {
  const ProfileAddressesPage({super.key});

  @override
  ConsumerState<ProfileAddressesPage> createState() =>
      _ProfileAddressesPageState();
}

class _ProfileAddressesPageState extends ConsumerState<ProfileAddressesPage> {
  bool _dismissedMismatchBanner = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(profileAddressesViewModel);
    final flow = ref.watch(checkoutFlowProvider);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Text(prefersEnglish ? 'Addresses' : '住所帳'),
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
            state: state,
            flow: flow,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required bool prefersEnglish,
    required AsyncValue<ProfileAddressesState> state,
    required CheckoutFlowState flow,
  }) {
    final tokens = DesignTokensTheme.of(context);

    if (state is AsyncLoading<ProfileAddressesState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 3, itemHeight: 96),
      );
    }

    if (state is AsyncError<ProfileAddressesState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load addresses' : '住所を読み込めません',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () =>
              ref.refreshValue(profileAddressesViewModel, keepPrevious: false),
        ),
      );
    }

    final data =
        state.valueOrNull ?? const ProfileAddressesState(addresses: []);
    if (data.addresses.isEmpty) {
      return AppEmptyState(
        title: prefersEnglish ? 'No addresses yet' : '住所がありません',
        message: prefersEnglish
            ? 'Add a shipping destination to speed up checkout.'
            : '配送先を登録すると、チェックアウトがスムーズになります。',
        icon: Icons.home_work_outlined,
        actionLabel: prefersEnglish ? 'Add address' : '住所を追加',
        onAction: () => _openForm(makeDefault: true),
      );
    }

    final defaultId = data.defaultAddress?.id;
    final shippingId = flow.addressId;
    final mismatchDefaultId =
        shippingId != null && defaultId != null && shippingId != defaultId
        ? defaultId
        : null;

    return Column(
      children: [
        if (mismatchDefaultId != null && !_dismissedMismatchBanner)
          MaterialBanner(
            content: Text(
              prefersEnglish
                  ? 'Shipping is using a non-default address.'
                  : '配送先が既定の住所と異なります。',
            ),
            leading: const Icon(Icons.sync_problem_outlined),
            actions: [
              TextButton(
                onPressed: () => _syncShipping(mismatchDefaultId),
                child: Text(prefersEnglish ? 'Sync to default' : '既定に同期'),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _dismissedMismatchBanner = true),
                child: Text(prefersEnglish ? 'Keep' : 'このまま'),
              ),
            ],
          ),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.refreshValue(profileAddressesViewModel, keepPrevious: true),
            edgeOffset: tokens.spacing.sm,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: data.addresses.length,
              separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
              itemBuilder: (context, index) {
                final address = data.addresses[index];
                return _AddressListItem(
                  address: address,
                  groupValue: defaultId,
                  prefersEnglish: prefersEnglish,
                  onSelect: address.id == null || address.id == defaultId
                      ? null
                      : () => ref.invoke(
                          profileAddressesViewModel.setDefault(address.id!),
                        ),
                  onEdit: () => _openForm(editing: address),
                  onDelete: address.id == null
                      ? null
                      : () => _confirmDelete(address),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _syncShipping(String defaultId) async {
    final addresses = ref.container
        .read(profileAddressesViewModel)
        .valueOrNull
        ?.addresses;
    final defaultAddress = addresses?.firstWhereOrNull(
      (item) => item.id == defaultId,
    );
    if (defaultAddress == null) return;

    await ref.invoke(
      checkoutFlowProvider.setAddress(
        addressId: defaultAddress.id,
        isInternational: defaultAddress.country.toUpperCase() != 'JP',
      ),
    );
    if (!mounted) return;
    setState(() => _dismissedMismatchBanner = true);
  }

  Future<void> _confirmDelete(UserAddress address) async {
    final gates = ref.container.read(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final id = address.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prefersEnglish ? 'Delete address?' : '住所を削除しますか？'),
        content: Text(
          prefersEnglish ? 'This cannot be undone.' : 'この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(prefersEnglish ? 'Cancel' : 'キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(prefersEnglish ? 'Delete' : '削除'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await ref.invoke(profileAddressesViewModel.deleteAddress(id));
  }

  Future<void> _openForm({
    UserAddress? editing,
    bool makeDefault = false,
  }) async {
    final gates = ref.container.read(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final existing =
        ref.container.read(profileAddressesViewModel).valueOrNull?.addresses ??
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

class _AddressListItem extends StatelessWidget {
  const _AddressListItem({
    required this.address,
    required this.groupValue,
    required this.prefersEnglish,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final UserAddress address;
  final String? groupValue;
  final bool prefersEnglish;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.sm,
      ),
      onTap: onSelect,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.xs),
            child: const Icon(Icons.place_outlined),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.label ??
                      (prefersEnglish ? 'Shipping address' : '配送先'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(address.recipient),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  _formatAddress(address),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<String?>(
                value: address.id,
                groupValue: groupValue,
                onChanged: onSelect == null ? null : (_) => onSelect!(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: prefersEnglish ? 'Edit' : '編集',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: prefersEnglish ? 'Delete' : '削除',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
    final saveState = ref.watch(profileAddressesViewModel.saveAddressMut);
    final isSaving = saveState is PendingMutationState;

    final title = _draft.id == null
        ? (prefersEnglish ? 'Add address' : '住所を追加')
        : (prefersEnglish ? 'Edit address' : '住所を編集');

    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: tokens.spacing.xxl * 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              onSelectionChanged: isSaving
                  ? null
                  : (value) {
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
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(recipient: value)),
            ),
            SizedBox(height: tokens.spacing.md),
            AppTextField(
              label: prefersEnglish ? 'Company (optional)' : '会社名（任意）',
              controller: _companyController,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(company: value)),
            ),
            SizedBox(height: tokens.spacing.lg),
            AppTextField(
              label: prefersEnglish ? 'Postal code' : '郵便番号',
              controller: _postalController,
              keyboardType: TextInputType.number,
              errorText: _errors['postalCode'],
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(postalCode: value)),
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
              label: prefersEnglish ? 'Phone (optional)' : '電話番号（任意）',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              errorText: _errors['phone'],
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(phone: value)),
            ),
            SizedBox(height: tokens.spacing.md),
            SwitchListTile.adaptive(
              value: _draft.isDefault,
              onChanged: isSaving
                  ? null
                  : (value) => setState(
                      () => _draft = _draft.copyWith(isDefault: value),
                    ),
              title: Text(prefersEnglish ? 'Use as default' : '既定の住所にする'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(prefersEnglish ? 'Cancel' : 'キャンセル'),
        ),
        TextButton(
          onPressed: isSaving ? null : _submit,
          child: Text(prefersEnglish ? 'Save' : '保存'),
        ),
      ],
    );
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
      profileAddressesViewModel.saveAddress(updated),
    );
    if (!result.validation.isValid) {
      setState(() => _errors = result.validation.fieldErrors);
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
