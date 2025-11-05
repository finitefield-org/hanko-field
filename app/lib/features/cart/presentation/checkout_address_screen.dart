import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_text_field.dart';
import 'package:app/features/cart/application/checkout_address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutAddressScreen extends ConsumerStatefulWidget {
  const CheckoutAddressScreen({super.key});

  @override
  ConsumerState<CheckoutAddressScreen> createState() =>
      _CheckoutAddressScreenState();
}

class _CheckoutAddressScreenState extends ConsumerState<CheckoutAddressScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    ref.listen<AsyncValue<CheckoutAddressState>>(
      checkoutAddressControllerProvider,
      (previous, next) {
        final prevData = previous?.value;
        final nextData = next.value;
        if (!mounted || nextData == null) {
          return;
        }
        final controller = ref.read(checkoutAddressControllerProvider.notifier);
        final messenger = ScaffoldMessenger.of(context);

        final feedback = nextData.feedbackMessage;
        if (feedback != null && feedback != prevData?.feedbackMessage) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(feedback)));
          controller.clearMessages();
          return;
        }
        final error = nextData.errorMessage;
        if (error != null && error != prevData?.errorMessage) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          controller.clearMessages();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  CheckoutAddressController get _controller =>
      ref.read(checkoutAddressControllerProvider.notifier);

  Future<void> _openForm({
    UserAddress? initialAddress,
    required ExperienceGate? experience,
  }) async {
    await showDialog<UserAddress?>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: _CheckoutAddressForm(
          initialAddress: initialAddress,
          experience: experience,
        ),
      ),
    );
  }

  Future<bool> _confirmDeletion(
    UserAddress address,
    ExperienceGate? experience,
  ) async {
    final isIntl = experience?.isInternational ?? false;
    final title = isIntl ? 'Delete address?' : '住所を削除しますか？';
    final body = isIntl
        ? 'This address will be removed from your checkout address book.'
        : 'この住所を削除するとチェックアウトで利用できなくなります。';
    final deleteLabel = isIntl ? 'Delete' : '削除';
    final cancelLabel = isIntl ? 'Cancel' : 'キャンセル';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(deleteLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleConfirm(
    CheckoutAddressState state,
    ExperienceGate? experience,
  ) async {
    if (state.selectedAddressId == null) {
      final message = experience?.isInternational ?? false
          ? 'Select an address before continuing.'
          : '確定する住所を選択してください。';
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final experienceAsync = ref.watch(experienceGateProvider);
    final experience = experienceAsync.value;
    final asyncState = ref.watch(checkoutAddressControllerProvider);
    final controller = _controller;

    final isIntl = experience?.isInternational ?? false;
    final title = isIntl ? 'Shipping address' : '配送先住所';
    final addTooltip = isIntl ? 'Add address' : '住所を追加';

    void openAddAddress() => _openForm(experience: experience);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: addTooltip,
            onPressed: asyncState.isLoading ? null : openAddAddress,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _LoadingView(),
          error: (error, stackTrace) => _ErrorView(
            message: error.toString(),
            onRetry: controller.refresh,
            experience: experience,
          ),
          data: (state) => RefreshIndicator(
            onRefresh: controller.refresh,
            child: _AddressListSection(
              state: state,
              experience: experience,
              scrollController: _scrollController,
              onAdd: openAddAddress,
              onSelect: controller.selectAddress,
              onEdit: (address) =>
                  _openForm(initialAddress: address, experience: experience),
              onDelete: (address) async {
                final approved = await _confirmDeletion(address, experience);
                if (!approved) {
                  return;
                }
                await controller.deleteAddress(address.id);
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: asyncState.maybeWhen(
        data: (state) {
          void confirmSelection() => _handleConfirm(state, experience);
          return _CheckoutAddressFooter(
            state: state,
            experience: experience,
            onConfirm: confirmSelection,
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.experience,
  });

  final String message;
  final VoidCallback onRetry;
  final ExperienceGate? experience;

  @override
  Widget build(BuildContext context) {
    final isIntl = experience?.isInternational ?? false;
    final retryLabel = isIntl ? 'Retry' : '再試行';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: AppTokens.spaceM),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

class _AddressListSection extends StatelessWidget {
  const _AddressListSection({
    required this.state,
    required this.experience,
    required this.scrollController,
    required this.onAdd,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final CheckoutAddressState state;
  final ExperienceGate? experience;
  final ScrollController scrollController;
  final VoidCallback onAdd;
  final ValueChanged<String> onSelect;
  final ValueChanged<UserAddress> onEdit;
  final ValueChanged<UserAddress> onDelete;

  @override
  Widget build(BuildContext context) {
    if (!state.hasAddresses) {
      return _EmptyAddressState(experience: experience, onAdd: onAdd);
    }

    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceL,
        AppTokens.spaceL,
        AppTokens.spaceL,
        AppTokens.spaceXXL,
      ),
      itemBuilder: (context, index) {
        final address = state.addresses[index];
        final isDeleting = state.deletingAddressIds.contains(address.id);
        final isSaving =
            state.isSaving &&
            state.savingAddressId != null &&
            state.savingAddressId == address.id;
        return _AddressCard(
          address: address,
          experience: experience,
          selectedAddressId: state.selectedAddressId,
          isDeleting: isDeleting,
          isSaving: isSaving,
          onSelect: () => onSelect(address.id),
          onEdit: () => onEdit(address),
          onDelete: () => onDelete(address),
        );
      },
      separatorBuilder: (context, _) =>
          const SizedBox(height: AppTokens.spaceM),
      itemCount: state.addresses.length,
    );
  }
}

class _EmptyAddressState extends StatelessWidget {
  const _EmptyAddressState({required this.experience, required this.onAdd});

  final ExperienceGate? experience;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIntl = experience?.isInternational ?? false;
    final headline = isIntl ? 'No addresses yet' : '住所が登録されていません';
    final body = isIntl
        ? 'Add a shipping address to continue checkout.'
        : 'チェックアウトを進めるには配送先住所を追加してください。';
    final addLabel = isIntl ? 'Add address' : '住所を追加';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTokens.spaceXL),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppTokens.spaceL),
            Text(headline, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.spaceS),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceXL),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.experience,
    required this.selectedAddressId,
    required this.isDeleting,
    required this.isSaving,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final UserAddress address;
  final ExperienceGate? experience;
  final String? selectedAddressId;
  final bool isDeleting;
  final bool isSaving;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  bool get _isDomestic => address.country.toUpperCase() == 'JP';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = selectedAddressId == address.id;
    final cardColor = address.isDefault
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surface;
    final selectionBorder = isSelected
        ? Border.all(color: colorScheme.primary, width: 1.6)
        : Border.all(color: colorScheme.outlineVariant, width: 0.8);
    final textTheme = theme.textTheme;
    final postalPrefix = _isDomestic ? '〒' : '';
    final formattedLines = _formatAddressLines(address, experience);
    final chips = _buildChips(experience, address, isSelected: isSelected);
    final isBusy = isDeleting || isSaving;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onSelect,
        borderRadius: AppTokens.radiusL,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: AppTokens.radiusL,
            border: selectionBorder,
          ),
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, color: colorScheme.primary),
                  const SizedBox(width: AppTokens.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address.recipient, style: textTheme.titleMedium),
                        if (address.company != null &&
                            address.company!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTokens.spaceXS,
                            ),
                            child: Text(
                              address.company!,
                              style: textTheme.labelMedium,
                            ),
                          ),
                        const SizedBox(height: AppTokens.spaceS),
                        Text(
                          [
                            if (address.postalCode.isNotEmpty)
                              '$postalPrefix${address.postalCode}',
                            ...formattedLines,
                          ].join('\n'),
                          style: textTheme.bodyMedium,
                        ),
                        if (address.phone != null &&
                            address.phone!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTokens.spaceS,
                            ),
                            child: Text(
                              (experience?.isInternational ?? false)
                                  ? 'Phone: ${address.phone}'
                                  : '電話番号: ${address.phone}',
                              style: textTheme.bodySmall,
                            ),
                          ),
                        if (chips.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTokens.spaceS,
                            ),
                            child: Wrap(
                              spacing: AppTokens.spaceS,
                              runSpacing: AppTokens.spaceS,
                              children: chips,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceS),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        tooltip: experience?.isInternational ?? false
                            ? 'Use this address'
                            : 'この住所を使う',
                        onPressed: isBusy ? null : onSelect,
                      ),
                      const SizedBox(height: AppTokens.spaceXS),
                      _AddressOverflowMenu(
                        experience: experience,
                        onEdit: onEdit,
                        onDelete: isBusy ? null : onDelete,
                        isDeleting: isDeleting,
                      ),
                    ],
                  ),
                ],
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.only(top: AppTokens.spaceS),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChips(
    ExperienceGate? experience,
    UserAddress address, {
    required bool isSelected,
  }) {
    final isIntl = experience?.isInternational ?? false;
    final chips = <Widget>[];
    if (address.isDefault) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.flag_outlined, size: 16),
          label: Text(isIntl ? 'Default' : '既定'),
        ),
      );
    }
    final label = address.label?.trim();
    if (label != null && label.isNotEmpty) {
      final lower = label.toLowerCase();
      final billing = lower.contains('bill');
      final labelText = billing ? (isIntl ? 'Billing' : '請求先') : label;
      chips.add(
        Chip(
          avatar: Icon(
            billing ? Icons.receipt_long_outlined : Icons.label_outline,
            size: 16,
          ),
          label: Text(labelText),
        ),
      );
    }
    if (_isDomestic && (experience?.showKanjiAssist ?? false)) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.translate_outlined, size: 16),
          label: Text(isSelected ? '選択中' : '漢字形式'),
        ),
      );
    }
    return chips;
  }

  List<String> _formatAddressLines(
    UserAddress address,
    ExperienceGate? experience,
  ) {
    final lines = <String>[];
    final state = address.state?.trim();
    final city = address.city.trim();
    final line1 = address.line1.trim();
    final line2 = address.line2?.trim();
    final postal = address.postalCode.trim();
    if (_isDomestic) {
      if (state != null && state.isNotEmpty) {
        lines.add(state + city);
      } else {
        lines.add(city);
      }
      lines.add(line1);
      if (line2 != null && line2.isNotEmpty) {
        lines.add(line2);
      }
    } else {
      lines.add(line1);
      if (line2 != null && line2.isNotEmpty) {
        lines.add(line2);
      }
      final locality = state == null || state.isEmpty ? city : '$city, $state';
      lines.add(locality);
      if (postal.isNotEmpty) {
        lines.add(postal);
      }
      lines.add(address.country.toUpperCase());
    }
    return lines;
  }
}

class _AddressOverflowMenu extends StatelessWidget {
  const _AddressOverflowMenu({
    required this.experience,
    required this.onEdit,
    required this.onDelete,
    required this.isDeleting,
  });

  final ExperienceGate? experience;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final isIntl = experience?.isInternational ?? false;
    final editLabel = isIntl ? 'Edit' : '編集';
    final deleteLabel = isIntl ? 'Delete' : '削除';
    return PopupMenuButton<_AddressMenuAction>(
      tooltip: isIntl ? 'Actions' : '操作',
      onSelected: (action) {
        switch (action) {
          case _AddressMenuAction.edit:
            onEdit();
          case _AddressMenuAction.delete:
            if (onDelete != null) {
              onDelete!();
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: _AddressMenuAction.edit, child: Text(editLabel)),
        PopupMenuItem(
          value: _AddressMenuAction.delete,
          enabled: onDelete != null && !isDeleting,
          child: Text(deleteLabel),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}

enum _AddressMenuAction { edit, delete }

class _CheckoutAddressFooter extends StatelessWidget {
  const _CheckoutAddressFooter({
    required this.state,
    required this.experience,
    required this.onConfirm,
  });

  final CheckoutAddressState state;
  final ExperienceGate? experience;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isIntl = experience?.isInternational ?? false;
    final confirmLabel = isIntl ? 'Confirm shipping address' : '配送先住所を確定';
    final disabled =
        state.selectedAddressId == null ||
        state.deletingAddressIds.isNotEmpty ||
        state.isSaving;

    return SafeArea(
      minimum: const EdgeInsets.all(AppTokens.spaceL),
      child: FilledButton(
        onPressed: disabled ? null : onConfirm,
        child: Text(confirmLabel),
      ),
    );
  }
}

enum AddressFormMode { domestic, international }

class _CheckoutAddressForm extends ConsumerStatefulWidget {
  const _CheckoutAddressForm({
    required this.initialAddress,
    required this.experience,
  });

  final UserAddress? initialAddress;
  final ExperienceGate? experience;

  @override
  ConsumerState<_CheckoutAddressForm> createState() =>
      _CheckoutAddressFormState();
}

class _CheckoutAddressFormState extends ConsumerState<_CheckoutAddressForm> {
  late final TextEditingController _labelController;
  late final TextEditingController _recipientController;
  late final TextEditingController _companyController;
  late final TextEditingController _postalController;
  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _countryController;
  late final TextEditingController _phoneController;
  late AddressFormMode _mode;
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  CheckoutAddressController get _controller =>
      ref.read(checkoutAddressControllerProvider.notifier);

  ExperienceGate? get _experience => widget.experience;

  bool get _isEditing => widget.initialAddress != null;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _recipientController = TextEditingController();
    _companyController = TextEditingController();
    _postalController = TextEditingController();
    _stateController = TextEditingController();
    _cityController = TextEditingController();
    _line1Controller = TextEditingController();
    _line2Controller = TextEditingController();
    _countryController = TextEditingController();
    _phoneController = TextEditingController();

    final initial = widget.initialAddress;
    if (initial != null) {
      _mode = initial.country.toUpperCase() == 'JP'
          ? AddressFormMode.domestic
          : AddressFormMode.international;
      _labelController.text = initial.label ?? '';
      _recipientController.text = initial.recipient;
      _companyController.text = initial.company ?? '';
      _postalController.text = initial.postalCode;
      _stateController.text = initial.state ?? '';
      _cityController.text = initial.city;
      _line1Controller.text = initial.line1;
      _line2Controller.text = initial.line2 ?? '';
      _countryController.text = initial.country;
      _phoneController.text = initial.phone ?? '';
    } else {
      _mode = (widget.experience?.isDomestic ?? true)
          ? AddressFormMode.domestic
          : AddressFormMode.international;
      _countryController.text = _mode == AddressFormMode.domestic ? 'JP' : '';
    }
  }

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
    final isIntl = _experience?.isInternational ?? false;
    final appBarTitle = _isEditing
        ? (isIntl ? 'Edit address' : '住所を編集')
        : (isIntl ? 'Add address' : '住所を追加');
    final saveLabel = isIntl ? 'Save' : '保存';

    final segments = <ButtonSegment<AddressFormMode>>[
      ButtonSegment(
        value: AddressFormMode.domestic,
        label: Text(isIntl ? 'Japan' : '国内'),
        icon: const Icon(Icons.home_work_outlined),
      ),
      ButtonSegment(
        value: AddressFormMode.international,
        label: Text(isIntl ? 'International' : '海外'),
        icon: const Icon(Icons.flight_takeoff_outlined),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(appBarTitle),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _handleSubmit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(saveLabel),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            children: [
              SegmentedButton<AddressFormMode>(
                segments: segments,
                selected: {_mode},
                onSelectionChanged: (value) {
                  if (value.isEmpty) {
                    return;
                  }
                  final next = value.first;
                  if (next == _mode) {
                    return;
                  }
                  setState(() {
                    _mode = next;
                    if (_mode == AddressFormMode.domestic) {
                      _countryController.text = 'JP';
                    }
                  });
                },
              ),
              const SizedBox(height: AppTokens.spaceL),
              _FormInstructions(experience: _experience, mode: _mode),
              const SizedBox(height: AppTokens.spaceL),
              AppTextField(
                controller: _labelController,
                label: isIntl ? 'Label (optional)' : 'ラベル（任意）',
                hint: isIntl ? 'Home, Office, Billing…' : '自宅、オフィス、請求先など',
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _recipientController,
                label: isIntl ? 'Recipient' : '氏名',
                required: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isIntl
                        ? 'Recipient name is required.'
                        : '氏名を入力してください。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _companyController,
                label: isIntl ? 'Company (optional)' : '会社名（任意）',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTokens.spaceL),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _postalController,
                      label: isIntl ? 'Postal code' : '郵便番号',
                      required: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      validator: _validatePostal,
                    ),
                  ),
                  if (_mode == AddressFormMode.domestic) ...[
                    const SizedBox(width: AppTokens.spaceS),
                    TextButton.icon(
                      onPressed: _submitting ? null : _lookupPostalCode,
                      icon: const Icon(Icons.search),
                      label: Text(isIntl ? 'Lookup' : '住所検索'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _stateController,
                label: _mode == AddressFormMode.domestic
                    ? (isIntl ? 'Prefecture' : '都道府県')
                    : (isIntl ? 'State / Region (optional)' : '州・地域（任意）'),
                required: _mode == AddressFormMode.domestic,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (_mode == AddressFormMode.domestic &&
                      (value == null || value.trim().isEmpty)) {
                    return isIntl
                        ? 'Prefecture is required.'
                        : '都道府県を入力してください。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _cityController,
                label: _mode == AddressFormMode.domestic
                    ? (isIntl ? 'City / Ward' : '市区町村')
                    : (isIntl ? 'City' : '市区町村'),
                required: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isIntl ? 'City is required.' : '市区町村を入力してください。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _line1Controller,
                label: isIntl ? 'Address line 1' : '番地・町名',
                required: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isIntl
                        ? 'Address line is required.'
                        : '住所（番地まで）を入力してください。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _line2Controller,
                label: isIntl ? 'Address line 2 (optional)' : '建物名・部屋番号（任意）',
                textInputAction: TextInputAction.next,
              ),
              if (_mode == AddressFormMode.international) ...[
                const SizedBox(height: AppTokens.spaceM),
                AppTextField(
                  controller: _countryController,
                  label: isIntl ? 'Country' : '国',
                  required: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isIntl ? 'Country is required.' : '国名を入力してください。';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _phoneController,
                label: isIntl ? 'Phone number (optional)' : '電話番号（任意）',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
                  if (digits.length < 5) {
                    return isIntl
                        ? 'Enter a valid phone number.'
                        : '有効な電話番号を入力してください。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.spaceXXL),
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePostal(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _experience?.isInternational ?? false
          ? 'Postal code is required.'
          : '郵便番号を入力してください。';
    }
    if (_mode == AddressFormMode.domestic) {
      final normalized = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalized.length != 7) {
        return _experience?.isInternational ?? false
            ? 'Enter 7 digits for Japanese postal code.'
            : '郵便番号は7桁で入力してください。';
      }
    }
    return null;
  }

  Future<void> _lookupPostalCode() async {
    final postal = _postalController.text;
    if (postal.trim().isEmpty) {
      return;
    }
    setState(() => _submitting = true);
    final result = await _controller.lookupPostalCode(postal);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    final isIntl = _experience?.isInternational ?? false;
    final messenger = ScaffoldMessenger.of(context);
    if (result == null) {
      final message = isIntl
          ? 'No match found for this postal code.'
          : '郵便番号に該当する住所が見つかりませんでした。';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    _stateController.text = result.prefecture;
    _cityController.text = result.city;
    if (_line1Controller.text.trim().isEmpty) {
      _line1Controller.text = result.town;
    }
    final message = isIntl ? 'Address fields populated.' : '住所を補完しました。';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  CheckoutAddressDraft _buildDraft() {
    final country = _mode == AddressFormMode.domestic
        ? 'JP'
        : _countryController.text;
    return CheckoutAddressDraft(
      original: widget.initialAddress,
      label: _labelController.text,
      recipient: _recipientController.text,
      company: _companyController.text,
      line1: _line1Controller.text,
      line2: _line2Controller.text,
      city: _cityController.text,
      state: _stateController.text,
      postalCode: _postalController.text,
      country: country,
      phone: _phoneController.text,
      selectAfterSave: _isEditing ? null : true,
    );
  }

  Future<void> _handleSubmit() async {
    if (_submitting) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _submitting = true);
    final draft = _buildDraft();
    final saved = await _controller.saveAddress(draft);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (saved != null) {
      Navigator.of(context).pop(saved);
    }
  }
}

class _FormInstructions extends StatelessWidget {
  const _FormInstructions({required this.experience, required this.mode});

  final ExperienceGate? experience;
  final AddressFormMode mode;

  @override
  Widget build(BuildContext context) {
    final isIntl = experience?.isInternational ?? false;
    final showKanjiAssist = experience?.showKanjiAssist ?? false;
    String message;
    if (mode == AddressFormMode.domestic) {
      message = isIntl
          ? 'Postal code lookup fills prefecture/city automatically. Please use full-width characters if you prefer.'
          : '郵便番号検索で都道府県・市区町村を自動補完できます。番地は漢字で入力してください。';
    } else if (showKanjiAssist) {
      message = isIntl
          ? 'Use Latin characters for international shipping labels so customs officers can read them easily.'
          : '海外配送ではローマ字表記が推奨されます。正しいスペルで入力してください。';
    } else {
      message = isIntl
          ? 'International addresses should include state, postal code, and country.'
          : '海外住所では州・国名を忘れずに入力してください。';
    }
    return AppValidationMessage(
      message: message,
      state: AppValidationState.info,
    );
  }
}
