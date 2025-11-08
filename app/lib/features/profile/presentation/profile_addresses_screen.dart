import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_address_controller.dart';
import 'package:app/features/cart/presentation/address_form_dialog.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProfileAddressesScreen extends ConsumerStatefulWidget {
  const ProfileAddressesScreen({super.key});

  @override
  ConsumerState<ProfileAddressesScreen> createState() =>
      _ProfileAddressesScreenState();
}

class _ProfileAddressesScreenState
    extends ConsumerState<ProfileAddressesScreen> {
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
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceM,
          vertical: AppTokens.spaceL,
        ),
        child: AddressFormDialog(
          initialAddress: initialAddress,
          experience: experience,
          presentation: AddressFormPresentation.dialog,
        ),
      ),
    );
  }

  Future<bool> _confirmDeletion(
    UserAddress address,
    ExperienceGate? experience,
    AppLocalizations l10n,
  ) async {
    final title = l10n.profileAddressesDeleteConfirmTitle;
    final body = l10n.profileAddressesDeleteConfirmBody(address.recipient);
    final deleteLabel = l10n.profileAddressesDeleteConfirmAction;
    final cancelLabel = l10n.profileAddressesDeleteConfirmCancel;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final experienceAsync = ref.watch(experienceGateProvider);
    final experience = experienceAsync.value;
    final asyncState = ref.watch(checkoutAddressControllerProvider);
    final controller = _controller;

    void openAddAddress() => _openForm(experience: experience);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileAddressesTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileAddressesAddTooltip,
            onPressed: asyncState.isLoading ? null : openAddAddress,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _ProfileAddressesLoading(),
          error: (error, stackTrace) => _ProfileAddressesError(
            message: error.toString(),
            onRetry: controller.refresh,
            l10n: l10n,
          ),
          data: (state) => RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.spaceL,
                      AppTokens.spaceL,
                      AppTokens.spaceL,
                      AppTokens.spaceS,
                    ),
                    child: _ShippingSyncBanner(
                      state: state,
                      l10n: l10n,
                      onSync: controller.refresh,
                    ),
                  ),
                ),
                if (state.hasAddresses)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.spaceL,
                      AppTokens.spaceM,
                      AppTokens.spaceL,
                      AppTokens.spaceXL,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final address = state.addresses[index];
                        final isDeleting = state.deletingAddressIds.contains(
                          address.id,
                        );
                        final isSaving =
                            state.isSaving &&
                            state.savingAddressId == address.id;
                        final defaultId = _defaultAddressId(state.addresses);
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppTokens.spaceM,
                          ),
                          child: _ProfileAddressTile(
                            address: address,
                            experience: experience,
                            isDefault: defaultId == address.id,
                            defaultAddressId: defaultId,
                            isBusy: isDeleting || isSaving,
                            l10n: l10n,
                            onSetDefault: () =>
                                controller.setDefaultAddress(address.id),
                            onEdit: () => _openForm(
                              initialAddress: address,
                              experience: experience,
                            ),
                            onDelete: () async {
                              final approved = await _confirmDeletion(
                                address,
                                experience,
                                l10n,
                              );
                              if (!approved) {
                                return;
                              }
                              await controller.deleteAddress(address.id);
                            },
                          ),
                        );
                      }, childCount: state.addresses.length),
                    ),
                  )
                else
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ProfileAddressesEmptyState(
                      l10n: l10n,
                      onAdd: openAddAddress,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _defaultAddressId(Iterable<UserAddress> addresses) {
    for (final address in addresses) {
      if (address.isDefault) {
        return address.id;
      }
    }
    return null;
  }
}

class _ProfileAddressesLoading extends StatelessWidget {
  const _ProfileAddressesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ProfileAddressesError extends StatelessWidget {
  const _ProfileAddressesError({
    required this.message,
    required this.onRetry,
    required this.l10n,
  });

  final String message;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              l10n.profileAddressesLoadError,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceL),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.profileAddressesRetryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAddressesEmptyState extends StatelessWidget {
  const _ProfileAddressesEmptyState({required this.l10n, required this.onAdd});

  final AppLocalizations l10n;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined, size: 64, color: theme.primaryColor),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            l10n.profileAddressesEmptyTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(l10n.profileAddressesEmptyBody, textAlign: TextAlign.center),
          const SizedBox(height: AppTokens.spaceL),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.profileAddressesEmptyAction),
          ),
        ],
      ),
    );
  }
}

class _ShippingSyncBanner extends StatelessWidget {
  const _ShippingSyncBanner({
    required this.state,
    required this.l10n,
    required this.onSync,
  });

  final CheckoutAddressState state;
  final AppLocalizations l10n;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timestamp = state.lastSyncedAt;
    final statusText = timestamp == null
        ? l10n.profileAddressesSyncNever
        : l10n.profileAddressesSyncStatus(
            _formatSyncTimestamp(context, timestamp),
          );

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.sync_alt),
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileAddressesSyncTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.spaceM),
            TextButton.icon(
              onPressed: state.isRefreshing ? null : onSync,
              icon: state.isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(l10n.profileAddressesSyncAction),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSyncTimestamp(BuildContext context, DateTime timestamp) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat.yMMMd(locale).add_Hm();
    return formatter.format(timestamp);
  }
}

class _ProfileAddressTile extends StatelessWidget {
  const _ProfileAddressTile({
    required this.address,
    required this.experience,
    required this.isDefault,
    required this.defaultAddressId,
    required this.isBusy,
    required this.l10n,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  final UserAddress address;
  final ExperienceGate? experience;
  final bool isDefault;
  final String? defaultAddressId;
  final bool isBusy;
  final AppLocalizations l10n;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  bool get _isDomestic => address.country.toUpperCase() == 'JP';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formattedLines = _formatAddressLines(address, experience);
    final postalPrefix = _isDomestic ? '〒' : '';
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, color: scheme.primary),
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
                            style: textTheme.bodySmall,
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
                          padding: const EdgeInsets.only(top: AppTokens.spaceS),
                          child: Text(
                            l10n.profileAddressesPhoneLabel(address.phone!),
                            style: textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: AppTokens.spaceS),
                      Wrap(
                        spacing: AppTokens.spaceS,
                        runSpacing: AppTokens.spaceS,
                        children: _buildChips(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.spaceS),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: isDefault
                          ? l10n.profileAddressesDefaultLabel
                          : l10n.profileAddressesSetDefaultTooltip,
                      child:
                          // ignore: deprecated_member_use
                          Radio<String>(
                            value: address.id,
                            // ignore: deprecated_member_use
                            groupValue: defaultAddressId,
                            // ignore: deprecated_member_use
                            onChanged: isDefault || isBusy
                                ? null
                                : (_) => onSetDefault(),
                          ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.profileAddressesEditTooltip,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: isBusy ? null : onEdit,
                        ),
                        IconButton(
                          tooltip: l10n.profileAddressesDeleteTooltip,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: isBusy ? null : onDelete,
                        ),
                      ],
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
    );
  }

  List<Widget> _buildChips(BuildContext context) {
    final chips = <Widget>[];
    if (isDefault) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.flag_outlined, size: 16),
          label: Text(l10n.profileAddressesDefaultLabel),
        ),
      );
    }
    final label = address.label?.trim();
    if (label != null && label.isNotEmpty) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.label_outline, size: 16),
          label: Text(label),
        ),
      );
    }
    if (_isDomestic && (experience?.showKanjiAssist ?? false)) {
      chips.add(
        const Chip(
          avatar: Icon(Icons.translate_outlined, size: 16),
          label: Text('漢字形式'),
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
