import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_text_field.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/library/application/library_duplicate_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryDuplicatePage extends ConsumerStatefulWidget {
  const LibraryDuplicatePage({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<LibraryDuplicatePage> createState() =>
      _LibraryDuplicatePageState();
}

class _LibraryDuplicatePageState extends ConsumerState<LibraryDuplicatePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _tagsController;
  late final ProviderSubscription<LibraryDuplicateState> _subscription;
  final _formKey = GlobalKey<FormState>();

  LibraryDuplicateController get _controller =>
      ref.read(libraryDuplicateControllerProvider(widget.designId).notifier);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _tagsController = TextEditingController();
    _subscription = ref.listenManual<LibraryDuplicateState>(
      libraryDuplicateControllerProvider(widget.designId),
      (previous, next) {
        if (next.newName != _nameController.text) {
          _nameController.value = TextEditingValue(
            text: next.newName,
            selection: TextSelection.collapsed(offset: next.newName.length),
          );
        }
        if (next.tagsInput != _tagsController.text) {
          _tagsController.value = TextEditingValue(
            text: next.tagsInput,
            selection: TextSelection.collapsed(offset: next.tagsInput.length),
          );
        }
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          _showSnack(next.errorMessage!);
          _controller.clearFeedback();
        }
        if (next.duplicatedDesign != null &&
            next.duplicatedDesign != previous?.duplicatedDesign) {
          _handleDuplicateSuccess(next);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _subscription.close();
    _nameController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = libraryDuplicateControllerProvider(widget.designId);
    final state = ref.watch(provider);
    final design = state.sourceDesign;
    final subtitle = design == null
        ? l10n.libraryDuplicateSubtitleFallback
        : l10n.libraryDuplicateSubtitle(design.input?.rawName ?? design.id);
    final suggestions = _buildSuggestions(design);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.libraryDuplicateTitle),
            if (design != null)
              Text(
                design.input?.rawName ?? design.id,
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _controller.refresh,
          child: state.isLoading && design == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _nameController,
                          label: l10n.libraryDuplicateNameLabel,
                          hint: l10n.libraryDuplicateNameHint,
                          required: true,
                          onChanged: _controller.updateName,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.libraryDuplicateNameError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _tagsController,
                          label: l10n.libraryDuplicateTagsLabel,
                          hint: l10n.libraryDuplicateTagsHint,
                          onChanged: _controller.updateTagsInput,
                          maxLines: 2,
                        ),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            l10n.libraryDuplicateSuggestionsLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final suggestion in suggestions)
                                ActionChip(
                                  label: Text(suggestion),
                                  onPressed: () =>
                                      _controller.applySuggestedTag(suggestion),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                title: Text(l10n.libraryDuplicateCopyHistory),
                                subtitle: Text(
                                  l10n.libraryDuplicateCopyHistoryDescription,
                                ),
                                value: state.copyHistory,
                                onChanged: _controller.toggleCopyHistory,
                              ),
                              const Divider(height: 1),
                              SwitchListTile.adaptive(
                                title: Text(l10n.libraryDuplicateCopyAssets),
                                subtitle: Text(
                                  l10n.libraryDuplicateCopyAssetsDescription,
                                ),
                                value: state.copyAssets,
                                onChanged: _controller.toggleCopyAssets,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: l10n.libraryDuplicateSubmit,
                          onPressed: state.isSubmitting ? null : _submit,
                          loading: state.isSubmitting,
                          fullWidth: true,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: state.isSubmitting
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: Text(l10n.libraryDuplicateCancel),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final currentState = ref.read(
      libraryDuplicateControllerProvider(widget.designId),
    );
    if (!_formKey.currentState!.validate() || currentState.isSubmitting) {
      return;
    }
    await _controller.submit();
  }

  Future<void> _handleDuplicateSuccess(LibraryDuplicateState state) async {
    final duplicate = state.duplicatedDesign;
    if (duplicate == null || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    _showSnack(l10n.libraryDetailDuplicateSuccess(duplicate.id));
    ref
        .read(designCreationControllerProvider.notifier)
        .hydrateFromDesign(duplicate, overrideName: state.newName.trim());
    final router = ref.read(appStateProvider.notifier);
    router.selectTab(AppTab.creation);
    router.push(CreationStageRoute(const ['editor']));
    if (mounted) {
      await Navigator.of(context).maybePop();
    }
    _controller.clearFeedback();
  }

  List<String> _buildSuggestions(Design? design) {
    if (design == null) {
      return const [];
    }
    final suggestions = <String>{
      design.style.writing.name,
      design.status.name,
      if (design.shape == DesignShape.round) 'round' else 'square',
    };
    final persona = design.persona;
    if (persona != null) {
      suggestions.add(persona.name);
    }
    final score = design.ai?.qualityScore;
    if (score != null) {
      suggestions.add('ai-${score.round()}');
    }
    return suggestions.toList();
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
