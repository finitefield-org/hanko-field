import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/onboarding/application/persona_selection_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonaSelectionScreen extends ConsumerWidget {
  const PersonaSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(personaSelectionControllerProvider);
    return asyncState.when(
      data: (state) => _PersonaSelectionView(state: state),
      loading: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('利用スタイルの読み込みに失敗しました。\n${error.toString()}'),
          ),
        ),
      ),
    );
  }
}

class _PersonaSelectionView extends ConsumerStatefulWidget {
  const _PersonaSelectionView({required this.state});

  final PersonaSelectionState state;

  @override
  ConsumerState<_PersonaSelectionView> createState() =>
      _PersonaSelectionViewState();
}

class _PersonaSelectionViewState extends ConsumerState<_PersonaSelectionView> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(personaSelectionControllerProvider.notifier);
    final state =
        ref.watch(personaSelectionControllerProvider).asData?.value ??
        widget.state;
    final theme = Theme.of(context);
    final selectedOption = state.availablePersonas.firstWhere(
      (option) => option.persona == state.selectedPersona,
    );

    Future<void> handleSave() async {
      if (_saving) {
        return;
      }
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _saving = true);
      try {
        await controller.saveSelection(force: true);
        if (!mounted) {
          return;
        }
        navigator.pop(true);
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showError(messenger, error);
      } finally {
        if (mounted) {
          setState(() => _saving = false);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('利用スタイル'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : handleSave,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'あなたに合わせた初期設定を選びましょう。作成フローやチェックリストが選択したスタイルに合わせて変わります。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final option in state.availablePersonas)
                    _PersonaChip(
                      option: option,
                      selected: option.persona == state.selectedPersona,
                      onSelected: () =>
                          controller.selectPersona(option.persona),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _PersonaHighlightCard(
                  key: ValueKey<UserPersona>(selectedOption.persona),
                  option: selectedOption,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _saving ? null : handleSave,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('続行'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(ScaffoldMessengerState messenger, Object error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _PersonaChip extends StatelessWidget {
  const _PersonaChip({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final PersonaOption option;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarIcon = option.persona == UserPersona.japanese
        ? Icons.flag
        : Icons.language_outlined;
    return ChoiceChip(
      avatar: Icon(avatarIcon),
      label: Text(option.label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primaryContainer,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
    );
  }
}

class _PersonaHighlightCard extends StatelessWidget {
  const _PersonaHighlightCard({required this.option, super.key});

  final PersonaOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.caption,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.highlight,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
