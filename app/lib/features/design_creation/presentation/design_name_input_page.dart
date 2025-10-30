import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_text_field.dart';
import 'package:app/features/design_creation/application/design_name_input_controller.dart';
import 'package:app/features/design_creation/application/design_name_input_state.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesignNameInputPage extends ConsumerStatefulWidget {
  const DesignNameInputPage({super.key});

  @override
  ConsumerState<DesignNameInputPage> createState() =>
      _DesignNameInputPageState();
}

class _DesignNameInputPageState extends ConsumerState<DesignNameInputPage> {
  late final TextEditingController _surnameController;
  late final TextEditingController _givenNameController;
  late final TextEditingController _surnameReadingController;
  late final TextEditingController _givenNameReadingController;

  @override
  void initState() {
    super.initState();
    _surnameController = TextEditingController();
    _givenNameController = TextEditingController();
    _surnameReadingController = TextEditingController();
    _givenNameReadingController = TextEditingController();

    ref.listen<DesignNameInputState>(
      designNameInputControllerProvider,
      (_, next) => _applyState(next),
    );
    _applyState(ref.read(designNameInputControllerProvider));
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _givenNameController.dispose();
    _surnameReadingController.dispose();
    _givenNameReadingController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(designNameInputControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleSuggestions = state.suggestions
        .where((suggestion) => !suggestion.isEmpty)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.designInputTitle)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            children: [
              Text(l10n.designInputSubtitle, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppTokens.spaceL),
              if (visibleSuggestions.isNotEmpty)
                _SuggestionSection(
                  suggestions: visibleSuggestions,
                  onApply: (suggestion) => ref
                      .read(designNameInputControllerProvider.notifier)
                      .applySuggestion(suggestion),
                ),
              if (visibleSuggestions.isNotEmpty)
                const SizedBox(height: AppTokens.spaceL),
              _PreviewCard(
                title: l10n.designInputPreviewTitle,
                primaryText: state.previewPrimary,
                reading: state.previewReading,
                colorScheme: colorScheme,
                persona: state.persona,
                l10n: l10n,
              ),
              const SizedBox(height: AppTokens.spaceXL),
              Text(
                l10n.designInputSectionPrimary,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _surnameController,
                label: l10n.designInputSurnameLabel,
                helper: l10n.designInputSurnameHelper,
                textInputAction: TextInputAction.next,
                onChanged: ref
                    .read(designNameInputControllerProvider.notifier)
                    .updateSurname,
                validationMessage: _primaryErrorMessage(
                  context,
                  state.surnameError,
                  isSurname: true,
                  persona: state.persona,
                ),
                validationState: state.surnameError == null
                    ? null
                    : AppValidationState.error,
                required: true,
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _givenNameController,
                label: l10n.designInputGivenNameLabel,
                helper: l10n.designInputGivenNameHelper,
                textInputAction: state.requiresKana
                    ? TextInputAction.next
                    : TextInputAction.done,
                onChanged: ref
                    .read(designNameInputControllerProvider.notifier)
                    .updateGivenName,
                validationMessage: _primaryErrorMessage(
                  context,
                  state.givenNameError,
                  isSurname: false,
                  persona: state.persona,
                ),
                validationState: state.givenNameError == null
                    ? null
                    : AppValidationState.error,
                required: true,
              ),
              const SizedBox(height: AppTokens.spaceXL),
              Text(
                l10n.designInputSectionReading,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _surnameReadingController,
                label: l10n.designInputSurnameReadingLabel,
                helper: l10n.designInputReadingHelper,
                textInputAction: TextInputAction.next,
                onChanged: ref
                    .read(designNameInputControllerProvider.notifier)
                    .updateSurnameReading,
                validationMessage: _readingErrorMessage(
                  context,
                  state.surnameReadingError,
                ),
                validationState: state.surnameReadingError == null
                    ? null
                    : AppValidationState.error,
                required: state.requiresKana,
              ),
              const SizedBox(height: AppTokens.spaceM),
              AppTextField(
                controller: _givenNameReadingController,
                label: l10n.designInputGivenNameReadingLabel,
                helper: l10n.designInputReadingHelper,
                textInputAction: TextInputAction.done,
                onChanged: ref
                    .read(designNameInputControllerProvider.notifier)
                    .updateGivenNameReading,
                validationMessage: _readingErrorMessage(
                  context,
                  state.givenNameReadingError,
                ),
                validationState: state.givenNameReadingError == null
                    ? null
                    : AppValidationState.error,
                required: state.requiresKana,
              ),
              const SizedBox(height: AppTokens.spaceXL),
              _KanjiMappingCard(
                onOpen: () => ref
                    .read(designNameInputControllerProvider.notifier)
                    .openKanjiMapper(),
                l10n: l10n,
                colorScheme: colorScheme,
                selectedMapping: state.selectedKanjiMapping,
              ),
              const SizedBox(height: AppTokens.spaceXXL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceM,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: FilledButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.designInputContinue),
          onPressed: state.canSubmit ? () => _handleSubmit(context) : null,
        ),
      ),
    );
  }

  Future<void> _handleSubmit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = ref.read(appStateProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final success = await ref
        .read(designNameInputControllerProvider.notifier)
        .submit();
    if (!mounted) {
      return;
    }
    if (success) {
      router.push(CreationStageRoute(const ['style']));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designInputValidationFailed)),
      );
    }
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _applyState(DesignNameInputState state) {
    _syncController(_surnameController, state.surname);
    _syncController(_givenNameController, state.givenName);
    _syncController(_surnameReadingController, state.surnameReading);
    _syncController(_givenNameReadingController, state.givenNameReading);
  }

  String? _primaryErrorMessage(
    BuildContext context,
    DesignNameFieldError? error, {
    required bool isSurname,
    required UserPersona persona,
  }) {
    if (error == null) {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    switch (error) {
      case DesignNameFieldError.empty:
        return isSurname
            ? l10n.designInputErrorEmptySurname
            : l10n.designInputErrorEmptyGiven;
      case DesignNameFieldError.invalidScript:
        return l10n.designInputErrorInvalidKanji;
      case DesignNameFieldError.tooLong:
        return persona == UserPersona.japanese
            ? l10n.designInputErrorTooLongKanji
            : l10n.designInputErrorTooLongLatin;
    }
  }

  String? _readingErrorMessage(
    BuildContext context,
    DesignNameFieldError? error,
  ) {
    if (error == null) {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    switch (error) {
      case DesignNameFieldError.empty:
        return l10n.designInputErrorEmptyKana;
      case DesignNameFieldError.invalidScript:
        return l10n.designInputErrorInvalidKana;
      case DesignNameFieldError.tooLong:
        return l10n.designInputErrorTooLongKana;
    }
  }
}

class _SuggestionSection extends StatelessWidget {
  const _SuggestionSection({required this.suggestions, required this.onApply});

  final List<DesignNameSuggestion> suggestions;
  final ValueChanged<DesignNameSuggestion> onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.designInputSuggestionHeader,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final suggestion in suggestions)
              ActionChip(
                avatar: const Icon(Icons.person),
                label: Text(_resolveSuggestionLabel(l10n, suggestion.labelKey)),
                onPressed: () => onApply(suggestion),
              ),
          ],
        ),
      ],
    );
  }

  String _resolveSuggestionLabel(AppLocalizations l10n, String labelKey) {
    switch (labelKey) {
      case 'profile':
        return l10n.designInputSuggestionProfile;
      case 'identity':
        return l10n.designInputSuggestionIdentity;
    }
    return l10n.designInputSuggestionFallback;
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.primaryText,
    required this.reading,
    required this.colorScheme,
    required this.persona,
    required this.l10n,
  });

  final String title;
  final String primaryText;
  final String reading;
  final ColorScheme colorScheme;
  final UserPersona persona;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppTokens.elevations[1],
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTokens.spaceS),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: AppTokens.radiusM,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXL,
                vertical: AppTokens.spaceXL,
              ),
              child: Column(
                children: [
                  Text(
                    primaryText.isEmpty
                        ? l10n.designInputPlaceholderPrimary
                        : primaryText,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: persona == UserPersona.japanese
                          ? AppTokens.designPreviewLetterSpacingKanji
                          : AppTokens.designPreviewLetterSpacingLatin,
                    ),
                  ),
                  if (reading.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceS),
                      child: Text(
                        reading,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              l10n.designInputPreviewCaption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanjiMappingCard extends StatelessWidget {
  const _KanjiMappingCard({
    required this.onOpen,
    required this.l10n,
    required this.colorScheme,
    this.selectedMapping,
  });

  final VoidCallback onOpen;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;
  final DesignKanjiMapping? selectedMapping;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTokens.radiusL,
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Row(
        children: [
          Icon(Icons.translate, color: colorScheme.primary),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.designInputKanjiMappingTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  l10n.designInputKanjiMappingDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (selectedMapping != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceS),
                    child: Text(
                      l10n.designInputKanjiMappingSelectionLabel(
                        selectedMapping!.value,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          OutlinedButton(
            onPressed: onOpen,
            child: Text(l10n.designInputKanjiMappingCta),
          ),
        ],
      ),
    );
  }
}
