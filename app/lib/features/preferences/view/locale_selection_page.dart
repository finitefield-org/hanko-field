// ignore_for_file: public_member_api_docs

import 'dart:ui';

import 'package:app/core/routing/routes.dart';
import 'package:app/features/preferences/view_model/locale_selection_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LocaleSelectionPage extends ConsumerStatefulWidget {
  const LocaleSelectionPage({super.key, this.onCompleteRoute});

  final String? onCompleteRoute;

  @override
  ConsumerState<LocaleSelectionPage> createState() =>
      _LocaleSelectionPageState();
}

class _LocaleSelectionPageState extends ConsumerState<LocaleSelectionPage> {
  Locale? _selected;
  bool _userChanged = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewState = ref.watch(localeSelectionViewModel);
    final saveState = ref.watch(localeSelectionViewModel.saveMut);
    final deviceState = ref.watch(localeSelectionViewModel.useDeviceMut);
    final Locale providerSelected =
        viewState.valueOrNull?.selected ?? ref.watch(appLocaleProvider);
    if (!_userChanged || _selected == null) {
      _selected = providerSelected;
    }
    final Locale selected = _selected ?? providerSelected;
    final isSaving =
        saveState is PendingMutationState ||
        deviceState is PendingMutationState;
    final options =
        viewState.valueOrNull?.options ?? localeOptionsFor(selected);
    final deviceLocale =
        viewState.valueOrNull?.deviceLocale ??
        PlatformDispatcher.instance.locale;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.localeTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.onboardingBack,
          onPressed: isSaving ? null : () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => _saveSelection(),
            child: Text(l10n.localeSave),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.localeSubtitle, style: theme.textTheme.titleMedium),
              SizedBox(height: tokens.spacing.sm),
              Text(
                l10n.localeDescription(deviceLocale.toLanguageTag()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: tokens.spacing.sm),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return _LocaleTile(
                      option: option,
                      selected: selected,
                      isBusy: isSaving,
                      onChanged: (value) {
                        if (value == null || isSaving) return;
                        setState(() {
                          _selected = value;
                          _userChanged = true;
                        });
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              FilledButton.icon(
                onPressed: isSaving ? null : () => _saveSelection(),
                icon: isSaving
                    ? SizedBox(
                        width: tokens.spacing.md,
                        height: tokens.spacing.md,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                            colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.localeContinue),
              ),
              TextButton.icon(
                onPressed: isSaving ? null : () => _useDeviceLocale(),
                icon: const Icon(Icons.phone_iphone),
                label: Text(l10n.localeUseDevice),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSelection() async {
    final Locale selected = _selected ?? ref.container.read(appLocaleProvider);
    try {
      await ref.invoke(localeSelectionViewModel.save(selected));
      if (!mounted) return;
      final target = widget.onCompleteRoute ?? AppRoutePaths.persona;
      context.go(target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _useDeviceLocale() async {
    try {
      await ref.invoke(localeSelectionViewModel.useDeviceLocale());
      if (!mounted) return;
      final target = widget.onCompleteRoute ?? AppRoutePaths.persona;
      context.go(target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({
    required this.option,
    required this.selected,
    required this.isBusy,
    required this.onChanged,
  });

  final LocaleOption option;
  final Locale selected;
  final bool isBusy;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = option.locale == selected;

    return InkWell(
      onTap: isBusy ? null : () => onChanged(option.locale),
      borderRadius: BorderRadius.circular(tokens.radii.lg),
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.04)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(tokens.radii.lg),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ignore: deprecated_member_use
                Radio<Locale>(
                  value: option.locale,
                  // ignore: deprecated_member_use
                  groupValue: selected,
                  // ignore: deprecated_member_use
                  onChanged: isBusy ? null : onChanged,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        option.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(tokens.spacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(tokens.radii.md),
              ),
              child: Text(
                option.sample,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
