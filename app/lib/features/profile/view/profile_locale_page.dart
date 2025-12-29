// ignore_for_file: public_member_api_docs

import 'package:app/features/preferences/view_model/locale_selection_view_model.dart';
import 'package:app/features/profile/view_model/profile_locale_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_currency_provider.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum _CurrencyChoice { auto, jpy, usd }

class ProfileLocalePage extends ConsumerStatefulWidget {
  const ProfileLocalePage({super.key});

  @override
  ConsumerState<ProfileLocalePage> createState() => _ProfileLocalePageState();
}

class _ProfileLocalePageState extends ConsumerState<ProfileLocalePage> {
  Locale? _selectedLocale;
  String? _currencyOverride;
  bool _localeTouched = false;
  bool _currencyTouched = false;
  bool _isDirty = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(profileLocaleViewModel);
    final saveState = ref.watch(profileLocaleViewModel.saveMut);
    final useDeviceState = ref.watch(profileLocaleViewModel.useDeviceMut);
    final isBusy =
        saveState is PendingMutationState ||
        useDeviceState is PendingMutationState;
    final loaded = state.valueOrNull;

    if (loaded != null) {
      if (!_localeTouched || _selectedLocale == null) {
        _selectedLocale = loaded.selectedLocale;
      }
      if (!_currencyTouched) {
        _currencyOverride = loaded.currencyOverride;
      }
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Text(l10n.profileLocaleTitle),
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
            theme: theme,
            tokens: tokens,
            l10n: l10n,
            state: state,
            isBusy: isBusy,
            isSaving: saveState is PendingMutationState,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ThemeData theme,
    required DesignTokens tokens,
    required AppLocalizations l10n,
    required AsyncValue<ProfileLocaleState> state,
    required bool isBusy,
    required bool isSaving,
  }) {
    if (state is AsyncLoading<ProfileLocaleState> &&
        state.valueOrNull == null) {
      return const AppListSkeleton(items: 3, itemHeight: 96);
    }

    if (state is AsyncError<ProfileLocaleState> && state.valueOrNull == null) {
      return AppEmptyState(
        title: l10n.profileLoadFailedTitle,
        message: state.error.toString(),
        icon: Icons.language_outlined,
        actionLabel: l10n.profileRetry,
        onAction: () => ref.invalidate(profileLocaleViewModel),
      );
    }

    final Locale currentLocale =
        _selectedLocale ?? ref.container.read(appLocaleProvider);
    final loaded = state.valueOrNull;
    final deviceLocale =
        loaded?.deviceLocale ?? Localizations.localeOf(context);
    final options = loaded?.localeOptions ?? localeOptionsFor(currentLocale);
    final currencyOverride = _currencyTouched
        ? _currencyOverride
        : loaded?.currencyOverride;
    final currencyChoice = _currencyChoiceFromOverride(currencyOverride);
    final resolvedCurrency =
        loaded?.resolvedCurrency ??
        resolveCurrency(currencyOverride, currentLocale);
    final canSave = _isDirty && !isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Text(
                l10n.profileLocaleLanguageHeader,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                l10n.profileLocaleLanguageHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(
                l10n.localeDescription(deviceLocale.toLanguageTag()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              for (final option in options) ...[
                _LocaleOptionTile(
                  option: option,
                  selected: currentLocale,
                  isBusy: isBusy,
                  onChanged: (value) {
                    if (value == null || isBusy) return;
                    setState(() {
                      _selectedLocale = value;
                      _localeTouched = true;
                      _refreshDirty();
                    });
                  },
                ),
                if (option != options.last) SizedBox(height: tokens.spacing.sm),
              ],
              SizedBox(height: tokens.spacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: isBusy ? null : _useDeviceLocale,
                  icon: const Icon(Icons.phone_iphone),
                  label: Text(l10n.profileLocaleUseDevice),
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
              Text(
                l10n.profileLocaleCurrencyHeader,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                l10n.profileLocaleCurrencyHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              AppCard(
                padding: EdgeInsets.all(tokens.spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<_CurrencyChoice>(
                      segments: [
                        ButtonSegment(
                          value: _CurrencyChoice.auto,
                          label: Text(l10n.profileLocaleCurrencyAuto),
                        ),
                        ButtonSegment(
                          value: _CurrencyChoice.jpy,
                          label: Text(l10n.profileLocaleCurrencyJpy),
                        ),
                        ButtonSegment(
                          value: _CurrencyChoice.usd,
                          label: Text(l10n.profileLocaleCurrencyUsd),
                        ),
                      ],
                      selected: {currencyChoice},
                      onSelectionChanged: isBusy
                          ? null
                          : (selection) {
                              if (selection.isEmpty) return;
                              final choice = selection.first;
                              setState(() {
                                _currencyOverride = _currencyOverrideFromChoice(
                                  choice,
                                );
                                _currencyTouched = true;
                                _refreshDirty();
                              });
                            },
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Text(
                      l10n.profileLocaleCurrencyAutoHint(resolvedCurrency),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave ? _savePreferences : null,
            child: isSaving
                ? SizedBox(
                    width: tokens.spacing.md,
                    height: tokens.spacing.md,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(l10n.profileLocaleSave),
          ),
        ),
      ],
    );
  }

  _CurrencyChoice _currencyChoiceFromOverride(String? override) {
    final normalized = normalizeCurrency(override);
    return switch (normalized) {
      'JPY' => _CurrencyChoice.jpy,
      'USD' => _CurrencyChoice.usd,
      _ => _CurrencyChoice.auto,
    };
  }

  String? _currencyOverrideFromChoice(_CurrencyChoice choice) {
    return switch (choice) {
      _CurrencyChoice.auto => null,
      _CurrencyChoice.jpy => 'JPY',
      _CurrencyChoice.usd => 'USD',
    };
  }

  void _refreshDirty() {
    final loaded = ref.container.read(profileLocaleViewModel).valueOrNull;
    if (loaded == null) {
      _isDirty = true;
      return;
    }
    final locale = _selectedLocale ?? loaded.selectedLocale;
    final currency = _currencyTouched
        ? _currencyOverride
        : loaded.currencyOverride;
    _isDirty =
        locale != loaded.selectedLocale || currency != loaded.currencyOverride;
  }

  Future<void> _useDeviceLocale() async {
    try {
      await ref.invoke(profileLocaleViewModel.useDeviceLocale());
      if (!mounted) return;
      setState(() {
        _selectedLocale = null;
        _localeTouched = false;
        _refreshDirty();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _savePreferences() async {
    final l10n = AppLocalizations.of(context);
    final Locale locale =
        _selectedLocale ?? ref.container.read(appLocaleProvider);
    final currencyOverride = _currencyOverride;
    try {
      await ref.invoke(
        profileLocaleViewModel.save(
          ProfileLocaleDraft(
            locale: locale,
            currencyOverride: currencyOverride,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _isDirty = false;
        _localeTouched = false;
        _currencyTouched = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileLocaleSaved)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileLocaleSaveFailed)));
    }
  }
}

class _LocaleOptionTile extends StatelessWidget {
  const _LocaleOptionTile({
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
    return AppListTile(
      leading: Radio<Locale>(
        value: option.locale,
        // ignore: deprecated_member_use
        groupValue: selected,
        // ignore: deprecated_member_use
        onChanged: isBusy ? null : onChanged,
      ),
      title: Text(option.title),
      subtitle: Text(option.subtitle),
      trailing: option.locale == selected
          ? const Icon(Icons.check_circle)
          : const Icon(Icons.radio_button_unchecked),
      onTap: isBusy ? null : () => onChanged(option.locale),
    );
  }
}
