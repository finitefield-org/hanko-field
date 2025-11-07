import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/features/library/application/library_entry_detail_provider.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class LibraryEntryScreen extends ConsumerStatefulWidget {
  const LibraryEntryScreen({required this.designId, this.subPage, super.key});

  final String designId;
  final String? subPage;

  @override
  ConsumerState<LibraryEntryScreen> createState() => _LibraryEntryScreenState();
}

class _LibraryEntryScreenState extends ConsumerState<LibraryEntryScreen> {
  late final int _initialTab;
  bool _isExporting = false;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _initialTab = _resolveInitialTab(widget.subPage);
  }

  int _resolveInitialTab(String? section) {
    switch (section) {
      case 'activity':
        return 1;
      case 'files':
        return 2;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(libraryDesignDetailProvider(widget.designId));
    final tabs = [
      Tab(text: l10n.libraryDetailTabDetails),
      Tab(text: l10n.libraryDetailTabActivity),
      Tab(text: l10n.libraryDetailTabFiles),
    ];

    return detailAsync.when(
      data: (detail) {
        return DefaultTabController(
          length: tabs.length,
          initialIndex: _initialTab,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar.medium(
                    pinned: true,
                    title: Text(detail.displayName),
                    actions: [
                      IconButton(
                        tooltip: l10n.libraryActionEdit,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _handleEdit(detail, l10n),
                      ),
                      IconButton(
                        tooltip: l10n.libraryActionExport,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        onPressed: _isExporting
                            ? null
                            : () => _handleExport(detail, l10n),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.spaceL,
                        AppTokens.spaceS,
                        AppTokens.spaceL,
                        AppTokens.spaceM,
                      ),
                      child: _DesignHeroCard(
                        detail: detail,
                        l10n: l10n,
                        onShare: () => _handleShare(detail, l10n),
                        onDuplicate: () => _handleDuplicate(detail),
                        onReorder: _isReordering
                            ? null
                            : () => _handleReorder(detail, l10n),
                        reordering: _isReordering,
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _LibraryEntryTabBarDelegate(TabBar(tabs: tabs)),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _DetailsTab(
                    detail: detail,
                    onViewVersions: () {
                      ref
                          .read(appStateProvider.notifier)
                          .push(
                            LibraryEntryRoute(
                              designId: detail.design.id,
                              trailing: const ['versions'],
                            ),
                          );
                    },
                  ),
                  _ActivityTab(detail: detail),
                  _FilesTab(
                    detail: detail,
                    onExport: () => _handleExport(detail, l10n),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const _LibraryEntryLoadingView(),
      error: (error, stack) => _LibraryEntryErrorView(
        message: l10n.libraryDetailErrorTitle,
        onRetry: () {
          ref.invalidate(libraryDesignDetailProvider(widget.designId));
        },
        retryLabel: l10n.libraryDetailRetry,
      ),
    );
  }

  void _handleEdit(LibraryDesignDetail detail, AppLocalizations l10n) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.libraryActionEdit)));
  }

  Future<void> _handleExport(
    LibraryDesignDetail detail,
    AppLocalizations l10n,
  ) async {
    if (_isExporting) {
      return;
    }
    setState(() {
      _isExporting = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }
    setState(() {
      _isExporting = false;
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.libraryActionExport)));
  }

  void _handleDuplicate(LibraryDesignDetail detail) {
    ref
        .read(appStateProvider.notifier)
        .push(
          LibraryEntryRoute(
            designId: detail.design.id,
            trailing: const ['duplicate'],
          ),
        );
  }

  Future<void> _handleShare(
    LibraryDesignDetail detail,
    AppLocalizations l10n,
  ) async {
    final name = detail.displayName;
    await Share.share(
      l10n.libraryDetailShareBody(name, detail.design.id),
      subject: l10n.libraryDetailShareSubject(detail.design.id),
    );
  }

  Future<void> _handleReorder(
    LibraryDesignDetail detail,
    AppLocalizations l10n,
  ) async {
    if (_isReordering) {
      return;
    }
    setState(() {
      _isReordering = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      return;
    }
    setState(() {
      _isReordering = false;
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.libraryActionReorder)));
  }
}

class _LibraryEntryLoadingView extends StatelessWidget {
  const _LibraryEntryLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _LibraryEntryErrorView extends StatelessWidget {
  const _LibraryEntryErrorView({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AppEmptyState(
          title: message,
          primaryAction: AppButton(
            label: retryLabel,
            onPressed: onRetry,
            variant: AppButtonVariant.primary,
          ),
        ),
      ),
    );
  }
}

class _LibraryEntryTabBarDelegate extends SliverPersistentHeaderDelegate {
  _LibraryEntryTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _LibraryEntryTabBarDelegate oldDelegate) {
    return false;
  }
}

class _DesignHeroCard extends StatelessWidget {
  const _DesignHeroCard({
    required this.detail,
    required this.l10n,
    required this.onShare,
    required this.onDuplicate,
    required this.onReorder,
    required this.reordering,
  });

  final LibraryDesignDetail detail;
  final AppLocalizations l10n;
  final VoidCallback onShare;
  final VoidCallback? onDuplicate;
  final VoidCallback? onReorder;
  final bool reordering;

  @override
  Widget build(BuildContext context) {
    final design = detail.design;
    final imageUrl =
        design.assets?.stampMockUrl ?? design.assets?.previewPngUrl;
    final score = detail.aiScore;
    final scheme = Theme.of(context).colorScheme;
    final registrable = detail.isRegistrable;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PreviewImage(imageUrl: imageUrl),
              const SizedBox(width: AppTokens.spaceL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTokens.spaceS),
                    Wrap(
                      spacing: AppTokens.spaceS,
                      runSpacing: AppTokens.spaceS,
                      children: [
                        _InfoChip(
                          icon: Icons.flag,
                          label: _statusLabel(design.status, l10n),
                        ),
                        if (design.persona != null)
                          _InfoChip(
                            icon: Icons.person,
                            label: _personaLabel(design.persona!, l10n),
                          ),
                        _InfoChip(
                          icon: Icons.crop_square,
                          label: _shapeLabel(design.shape, design.size, l10n),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.spaceL),
                    Row(
                      children: [
                        _AiScoreGauge(score: score),
                        const SizedBox(width: AppTokens.spaceL),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.libraryDetailAiScoreLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                score == null
                                    ? l10n.libraryAiScoreUnknown
                                    : l10n.libraryAiScoreValue(score.round()),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppTokens.spaceS),
                              Chip(
                                avatar: Icon(
                                  registrable
                                      ? Icons.verified_outlined
                                      : Icons.warning_amber_outlined,
                                ),
                                label: Text(
                                  registrable
                                      ? l10n.libraryDetailRegistrable
                                      : l10n.libraryDetailNotRegistrable,
                                ),
                                backgroundColor: registrable
                                    ? scheme.primaryContainer
                                    : scheme.errorContainer,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            l10n.libraryDetailQuickActions,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: [
              ActionChip(
                onPressed: onShare,
                avatar: const Icon(Icons.ios_share_rounded),
                label: Text(l10n.libraryActionShare),
              ),
              ActionChip(
                onPressed: onDuplicate,
                avatar: const Icon(Icons.copy_all_outlined),
                label: Text(l10n.libraryActionDuplicate),
              ),
              ActionChip(
                onPressed: onReorder,
                avatar: const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  reordering
                      ? l10n.libraryDetailActionInProgress
                      : l10n.libraryActionReorder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.detail, required this.onViewVersions});

  final LibraryDesignDetail detail;
  final VoidCallback onViewVersions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final design = detail.design;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceXL,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SectionTitle(label: l10n.libraryDetailMetadataTitle),
              const SizedBox(height: AppTokens.spaceS),
              AppCard(
                variant: AppCardVariant.outlined,
                child: Column(
                  children: [
                    _MetadataRow(
                      label: l10n.libraryDetailMetadataId,
                      value: design.id,
                    ),
                    _MetadataRow(
                      label: l10n.libraryDetailMetadataStatus,
                      value: _statusLabel(design.status, l10n),
                    ),
                    _MetadataRow(
                      label: l10n.libraryDetailMetadataPersona,
                      value: _personaLabel(design.persona, l10n),
                    ),
                    _MetadataRow(
                      label: l10n.libraryDetailMetadataShape,
                      value: _shapeLabel(design.shape, design.size, l10n),
                    ),
                    _MetadataRow(
                      label: l10n.libraryDetailMetadataWriting,
                      value: _writingLabel(design.style.writing, l10n),
                    ),
                    _MetadataRow(
                      label: l10n.libraryDetailMetadataUpdated,
                      value: _formatDateTime(context, design.updatedAt),
                    ),
                    _MetadataRow(
                      label: l10n.libraryDetailMetadataCreated,
                      value: _formatDateTime(context, design.createdAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.spaceL),
              _SectionTitle(label: l10n.libraryDetailAiTitle),
              const SizedBox(height: AppTokens.spaceS),
              AppCard(
                variant: AppCardVariant.outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.libraryDetailAiDiagnosticsLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceS),
                    Builder(
                      builder: (context) {
                        final diagnostics = design.ai?.diagnostics;
                        if (diagnostics != null && diagnostics.isNotEmpty) {
                          return Wrap(
                            spacing: AppTokens.spaceS,
                            runSpacing: AppTokens.spaceS,
                            children: diagnostics
                                .map(
                                  (diagnostic) => Chip(label: Text(diagnostic)),
                                )
                                .toList(),
                          );
                        }
                        return Text(
                          l10n.libraryDetailAiDiagnosticsEmpty,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.spaceL),
              _SectionTitle(label: l10n.libraryDetailVersionTitle),
              const SizedBox(height: AppTokens.spaceS),
              AppCard(
                variant: AppCardVariant.outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.libraryDetailVersionCurrent(design.version),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceS),
                    Text(
                      l10n.libraryDetailVersionCount(detail.versions.length),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceS),
                    ...detail.versions
                        .take(3)
                        .map(
                          (version) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              child: Text('v${version.version}'),
                            ),
                            title: Text(
                              _formatDateTime(context, version.updatedAt),
                            ),
                            subtitle: Text(_statusLabel(version.status, l10n)),
                          ),
                        ),
                    const SizedBox(height: AppTokens.spaceS),
                    AppButton(
                      label: l10n.libraryDetailViewVersionsCta,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: onViewVersions,
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.detail});

  final LibraryDesignDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = detail.usageHistory;
    if (events.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: AppEmptyState(
                title: l10n.libraryDetailUsageEmpty,
                icon: const Icon(Icons.history_toggle_off),
              ),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceXL,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final event = events[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == events.length - 1 ? 0 : AppTokens.spaceM,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTokens.radiusM,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(_usageIcon(event.type)),
                  ),
                  title: Text(_usageTitle(event, l10n)),
                  subtitle: Text(_formatDateTime(context, event.timestamp)),
                ),
              );
            }, childCount: events.length),
          ),
        ),
      ],
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.detail, required this.onExport});

  final LibraryDesignDetail detail;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final assets = detail.design.assets;
    final entries = [
      _FileEntry(
        icon: Icons.texture,
        label: l10n.libraryDetailFilesVector,
        available: assets?.vectorSvg != null,
      ),
      _FileEntry(
        icon: Icons.image_outlined,
        label: l10n.libraryDetailFilesPreview,
        available: assets?.previewPngUrl != null,
      ),
      _FileEntry(
        icon: Icons.print_outlined,
        label: l10n.libraryDetailFilesStampMock,
        available: assets?.stampMockUrl != null,
      ),
    ];
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceXL,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final entry = entries[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == entries.length - 1 ? 0 : AppTokens.spaceM,
                ),
                child: AppListTile(
                  title: entry.label,
                  subtitle: entry.available
                      ? l10n.libraryActionExport
                      : l10n.libraryDetailFilesUnavailable,
                  leading: Icon(entry.icon),
                  trailing: entry.available
                      ? const Icon(Icons.download_outlined)
                      : const Icon(Icons.lock_clock),
                  onTap: entry.available ? onExport : null,
                ),
              );
            }, childCount: entries.length),
          ),
        ),
      ],
    );
  }
}

class _FileEntry {
  const _FileEntry({
    required this.icon,
    required this.label,
    required this.available,
  });

  final IconData icon;
  final String label;
  final bool available;
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTokens.radiusM,
      ),
      child: const Icon(Icons.image_outlined, size: 48),
    );
    if (imageUrl == null || imageUrl!.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: AppTokens.radiusM,
      child: Image.network(
        imageUrl!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

class _AiScoreGauge extends StatelessWidget {
  const _AiScoreGauge({this.score});

  final double? score;

  @override
  Widget build(BuildContext context) {
    final normalized = (score ?? 0).clamp(0, 100) / 100;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score == null ? null : normalized,
            strokeWidth: 6,
          ),
          Text(
            score == null ? '--' : score!.toStringAsFixed(0),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceS),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

String _statusLabel(DesignStatus status, AppLocalizations l10n) {
  return switch (status) {
    DesignStatus.draft => l10n.homeDesignStatusDraft,
    DesignStatus.ready => l10n.homeDesignStatusReady,
    DesignStatus.ordered => l10n.homeDesignStatusOrdered,
    DesignStatus.locked => l10n.homeDesignStatusLocked,
  };
}

String _personaLabel(UserPersona? persona, AppLocalizations l10n) {
  return switch (persona) {
    UserPersona.japanese => l10n.libraryPersonaJapanese,
    UserPersona.foreigner => l10n.libraryPersonaForeigner,
    null => l10n.libraryPersonaAll,
  };
}

String _shapeLabel(DesignShape shape, DesignSize size, AppLocalizations l10n) {
  final shapeLabel = switch (shape) {
    DesignShape.round => l10n.libraryDetailShapeRound,
    DesignShape.square => l10n.libraryDetailShapeSquare,
  };
  final mm = size.mm.toStringAsFixed(size.mm % 1 == 0 ? 0 : 1);
  return '$shapeLabel · ${mm}mm';
}

String _writingLabel(DesignWritingStyle writing, AppLocalizations l10n) {
  return switch (writing) {
    DesignWritingStyle.tensho => l10n.libraryDetailWritingTensho,
    DesignWritingStyle.reisho => l10n.libraryDetailWritingReisho,
    DesignWritingStyle.kaisho => l10n.libraryDetailWritingKaisho,
    DesignWritingStyle.gyosho => l10n.libraryDetailWritingGyosho,
    DesignWritingStyle.koentai => l10n.libraryDetailWritingKoentai,
    DesignWritingStyle.custom => l10n.libraryDetailWritingCustom,
  };
}

String _formatDateTime(BuildContext context, DateTime timestamp) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final formatter = DateFormat.yMMMd(locale).add_Hm();
  return formatter.format(timestamp.toLocal());
}

IconData _usageIcon(LibraryUsageEventType type) {
  return switch (type) {
    LibraryUsageEventType.created => Icons.star_border,
    LibraryUsageEventType.updated => Icons.edit_note,
    LibraryUsageEventType.ordered => Icons.shopping_bag_outlined,
    LibraryUsageEventType.aiCheck => Icons.auto_awesome,
    LibraryUsageEventType.version => Icons.history,
  };
}

String _usageTitle(LibraryUsageEvent event, AppLocalizations l10n) {
  return switch (event.type) {
    LibraryUsageEventType.created => l10n.libraryDetailUsageCreated,
    LibraryUsageEventType.updated => l10n.libraryDetailUsageUpdated(
      event.version ?? 0,
    ),
    LibraryUsageEventType.ordered => l10n.libraryDetailUsageOrdered,
    LibraryUsageEventType.aiCheck => l10n.libraryDetailUsageAiCheck(
      (event.score ?? 0).toStringAsFixed(0),
    ),
    LibraryUsageEventType.version => l10n.libraryDetailUsageVersionArchived(
      event.version ?? 0,
    ),
  };
}
