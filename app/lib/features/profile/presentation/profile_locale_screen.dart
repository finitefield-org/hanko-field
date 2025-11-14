import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/profile/application/profile_locale_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/shared/locale/locale_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileLocaleScreen extends ConsumerWidget {
  const ProfileLocaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(profileLocaleControllerProvider);
    final l10n = AppLocalizations.of(context);

    return asyncState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.profileLocaleTitle)),
        body: Center(
          child: Text(l10n.profileLocaleLoadError(error.toString())),
        ),
      ),
      data: (state) => _ProfileLocaleContent(state: state),
    );
  }
}

class _ProfileLocaleContent extends ConsumerWidget {
  const _ProfileLocaleContent({required this.state});

  final ProfileLocaleState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(profileLocaleControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    Future<void> handleApply() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await controller.saveChanges();
        if (!context.mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileLocaleApplySuccess)),
        );
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileLocaleApplyError)),
        );
      }
    }

    Future<void> handleUseSystem() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await controller.saveUsingSystemLocale();
        if (!context.mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileLocaleApplySuccess)),
        );
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileLocaleApplyError)),
        );
      }
    }

    void showHelpSheet() {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileLocaleHelpTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceS),
              Text(
                l10n.profileLocaleHelpBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTokens.spaceL),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.profileLocaleHelpClose),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedLocaleOption = state.availableLocales.firstWhere(
      (option) => option.languageTag == state.selectedLocaleTag,
      orElse: () => state.availableLocales.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileLocaleTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileLocaleHelpTooltip,
            icon: const Icon(Icons.help_outline),
            onPressed: showHelpSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceM,
                ),
                children: [
                  Text(
                    l10n.profileLocaleLanguageSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    l10n.profileLocaleLanguageSectionSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceM),
                  for (final option in state.availableLocales)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
                      child: _LocaleOptionTile(
                        option: option,
                        selected: option.languageTag == state.selectedLocaleTag,
                        disabled: state.isSaving,
                        onTap: () => controller.selectLocale(option.locale),
                      ),
                    ),
                  const SizedBox(height: AppTokens.spaceL),
                  Text(
                    l10n.profileLocaleCurrencySectionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    l10n.profileLocaleCurrencySectionSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceM),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final code in state.availableCurrencies)
                        ButtonSegment<String>(
                          value: code,
                          label: Text(_currencyLabel(l10n, code)),
                        ),
                    ],
                    selected: {state.selectedCurrencyCode},
                    onSelectionChanged: state.isSaving
                        ? null
                        : (selection) =>
                              controller.selectCurrency(selection.first),
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  Text(
                    l10n.profileLocaleCurrencyRecommendation(
                      selectedLocaleOption.title,
                      _currencyLabel(
                        l10n,
                        state.recommendedCurrencyForSelection,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceM,
                AppTokens.spaceL,
                AppTokens.spaceL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: state.isSaving ? null : handleUseSystem,
                    child: Text(l10n.profileLocaleUseSystemButton),
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  FilledButton(
                    onPressed: state.isSaving || !state.hasChanges
                        ? null
                        : handleApply,
                    child: state.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.profileLocaleApplyButton),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocaleOptionTile extends StatelessWidget {
  const _LocaleOptionTile({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final LocaleOption option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: selected ? AppCardVariant.filled : AppCardVariant.outlined,
      onTap: disabled ? null : onTap,
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTokens.spaceS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  option.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceM),
                Text(
                  option.sampleHeadline,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  option.sampleBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _currencyLabel(AppLocalizations l10n, String code) {
  switch (code.toUpperCase()) {
    case 'JPY':
      return l10n.profileLocaleCurrencyJpyLabel;
    case 'USD':
    default:
      return l10n.profileLocaleCurrencyUsdLabel;
  }
}
