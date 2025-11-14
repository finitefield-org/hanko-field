import 'package:app/features/onboarding/application/locale_selection_controller.dart';
import 'package:app/shared/locale/locale_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleSelectionScreen extends ConsumerWidget {
  const LocaleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(localeSelectionControllerProvider);
    return asyncState.when(
      data: (state) => _LocaleSelectionView(state: state),
      loading: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => Scaffold(
        body: SafeArea(
          child: Center(child: Text('言語設定の読み込みに失敗しました。\n${error.toString()}')),
        ),
      ),
    );
  }
}

class _LocaleSelectionView extends ConsumerStatefulWidget {
  const _LocaleSelectionView({required this.state});

  final LocaleSelectionState state;

  @override
  ConsumerState<_LocaleSelectionView> createState() =>
      _LocaleSelectionViewState();
}

class _LocaleSelectionViewState extends ConsumerState<_LocaleSelectionView> {
  bool _showSavingIndicator = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(localeSelectionControllerProvider.notifier);
    final state =
        ref.watch(localeSelectionControllerProvider).asData?.value ??
        widget.state;
    final theme = Theme.of(context);

    Future<void> handleSave({bool force = false}) async {
      if (_showSavingIndicator) {
        return;
      }
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _showSavingIndicator = true);
      try {
        await controller.saveSelection(force: force);
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
          setState(() => _showSavingIndicator = false);
        }
      }
    }

    Future<void> handleUseSystem() async {
      if (_showSavingIndicator) {
        return;
      }
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _showSavingIndicator = true);
      try {
        await controller.saveUsingSystemLocale();
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
          setState(() => _showSavingIndicator = false);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('言語と地域'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          TextButton(
            onPressed: _showSavingIndicator
                ? null
                : () => handleSave(force: true),
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
                '表示言語と地域を選んでください。価格やガイドの内容が選択した言語に最適化されます。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemBuilder: (context, index) {
                  final option = state.availableLocales[index];
                  return _LocaleOptionTile(
                    option: option,
                    selectedTag: state.selectedLocale.toLanguageTag(),
                    onTap: () => controller.selectLocale(option.locale),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: state.availableLocales.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: _showSavingIndicator ? null : handleUseSystem,
                    child: const Text('デバイスの言語を使う'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _showSavingIndicator
                        ? null
                        : () => handleSave(force: true),
                    child: _showSavingIndicator
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('続行'),
                  ),
                ],
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

class _LocaleOptionTile extends StatelessWidget {
  const _LocaleOptionTile({
    required this.option,
    required this.selectedTag,
    required this.onTap,
  });

  final LocaleOption option;
  final String selectedTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = option.languageTag == selectedTag;
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.sampleHeadline,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.sampleBody,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
