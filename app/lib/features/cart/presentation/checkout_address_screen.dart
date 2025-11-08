import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_address_controller.dart';
import 'package:app/features/cart/presentation/address_form_dialog.dart';
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
        child: AddressFormDialog(
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
