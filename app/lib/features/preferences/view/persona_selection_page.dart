// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/preferences/view_model/persona_selection_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_persona_provider.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class PersonaSelectionPage extends ConsumerStatefulWidget {
  const PersonaSelectionPage({super.key, this.onCompleteRoute});

  final String? onCompleteRoute;

  @override
  ConsumerState<PersonaSelectionPage> createState() =>
      _PersonaSelectionPageState();
}

class _PersonaSelectionPageState extends ConsumerState<PersonaSelectionPage> {
  UserPersona? _selected;
  bool _userChanged = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewState = ref.watch(personaSelectionViewModel);
    final saveState = ref.watch(personaSelectionViewModel.saveMut);
    final UserPersona providerSelected =
        viewState.valueOrNull?.selected ?? ref.watch(appPersonaProvider);
    if (!_userChanged || _selected == null) {
      _selected = providerSelected;
    }
    final UserPersona selected = _selected ?? providerSelected;
    final isSaving = saveState is PendingMutationState;
    final options = viewState.valueOrNull?.options ?? personaOptions();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.personaTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.onboardingBack,
          onPressed: isSaving ? null : () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => _saveSelection(),
            child: Text(l10n.personaSave),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.personaSubtitle, style: theme.textTheme.titleMedium),
              SizedBox(height: tokens.spacing.sm),
              Text(
                l10n.personaDescription,
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
                    return _PersonaCard(
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
                    : const Icon(Icons.check_circle),
                label: Text(l10n.personaContinue),
              ),
              TextButton.icon(
                onPressed: isSaving ? null : () => _saveSelection(),
                icon: const Icon(Icons.done_all),
                label: Text(l10n.personaUseSelected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSelection() async {
    final UserPersona selected =
        _selected ?? ref.container.read(appPersonaProvider);
    try {
      final isAuthed =
          ref.container
              .read(personaSelectionViewModel)
              .valueOrNull
              ?.isAuthenticated ??
          ref.container
                  .read(userSessionProvider)
                  .valueOrNull
                  ?.isAuthenticated ==
              true;
      await ref.invoke(personaSelectionViewModel.save(selected));
      if (!mounted) return;
      final target =
          widget.onCompleteRoute ??
          (isAuthed ? AppRoutePaths.home : AppRoutePaths.auth);
      context.go(target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.option,
    required this.selected,
    required this.isBusy,
    required this.onChanged,
  });

  final PersonaOption option;
  final UserPersona selected;
  final bool isBusy;
  final ValueChanged<UserPersona?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = option.persona == selected;

    return InkWell(
      onTap: isBusy ? null : () => onChanged(option.persona),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ignore: deprecated_member_use
                Radio<UserPersona>(
                  value: option.persona,
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
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.sm,
              children: option.assists
                  .map(
                    (assist) => ActionChip(
                      onPressed: isBusy
                          ? null
                          : () => onChanged(option.persona),
                      label: Text(assist),
                      avatar: Icon(
                        Icons.tune,
                        size: tokens.spacing.md,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
