import 'package:app/core/theme/tokens.dart';
import 'package:app/features/library/application/library_entry_detail_provider.dart';
import 'package:app/features/library/application/library_versions_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/shared/version_history/design_version_history_state.dart';
import 'package:app/shared/version_history/widgets/design_version_history_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryDesignVersionsPage extends ConsumerStatefulWidget {
  const LibraryDesignVersionsPage({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<LibraryDesignVersionsPage> createState() =>
      _LibraryDesignVersionsPageState();
}

class _LibraryDesignVersionsPageState
    extends ConsumerState<LibraryDesignVersionsPage> {
  bool _highlightChanges = true;
  ProviderSubscription<DesignVersionHistoryState>? _subscription;

  @override
  void initState() {
    super.initState();
    final provider = libraryDesignVersionsControllerProvider(widget.designId);
    _subscription = ref.listenManual<DesignVersionHistoryState>(provider, (
      previous,
      next,
    ) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.restoredVersion != null &&
          next.restoredVersion != previous?.restoredVersion) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).designVersionHistoryRestoredSnack(next.restoredVersion!),
            ),
          ),
        );
      }
      if (next.duplicatedDesignId != null &&
          next.duplicatedDesignId != previous?.duplicatedDesignId) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).designVersionHistoryDuplicatedSnack(next.duplicatedDesignId!),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = libraryDesignVersionsControllerProvider(widget.designId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final diffEntries = controller.diffEntries();
    final filteredDiffs = _highlightChanges
        ? diffEntries.where((entry) => entry.changed).toList()
        : diffEntries;
    final designName = ref
        .watch(libraryDesignProvider(widget.designId))
        .maybeWhen(
          data: (design) => design.input?.rawName ?? design.id,
          orElse: () => l10n.designVersionHistoryTitle,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(designName),
        actions: [
          IconButton(
            tooltip: _highlightChanges
                ? l10n.designVersionHistoryShowAllTooltip
                : l10n.designVersionHistoryShowChangesTooltip,
            icon: Icon(
              _highlightChanges
                  ? Icons.highlight_alt
                  : Icons.compare_arrows_outlined,
            ),
            onPressed: diffEntries.isEmpty
                ? null
                : () {
                    setState(() {
                      _highlightChanges = !_highlightChanges;
                    });
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            if (state.isLoading && state.versions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.versions.isEmpty) {
              return DesignVersionHistoryEmptyState(
                message: l10n.designVersionHistoryEmptyState,
                onRetry: controller.refresh,
                l10n: l10n,
              );
            }
            final timeline = DesignVersionTimeline(
              versions: state.versions,
              selectedIndex: state.selectedIndex,
              onSelected: controller.selectVersion,
              onRefresh: controller.refresh,
              isRefreshing: state.isLoading,
              l10n: l10n,
            );
            final diffPanel = DesignVersionDiffViewer(
              current: state.currentVersion!,
              selected: state.selectedVersion!,
              diffEntries: filteredDiffs,
              showEmptyDiffMessage:
                  filteredDiffs.isEmpty && diffEntries.isNotEmpty,
              highlightChanges: _highlightChanges,
              onRestore: controller.rollbackSelectedVersion,
              onDuplicate: controller.duplicateSelectedVersion,
              restoring: state.isRollbackInProgress,
              duplicating: state.isDuplicateInProgress,
              l10n: l10n,
            );
            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(AppTokens.spaceL),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: timeline),
                    const SizedBox(width: AppTokens.spaceL),
                    Expanded(flex: 4, child: diffPanel),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  timeline,
                  const SizedBox(height: AppTokens.spaceL),
                  diffPanel,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
