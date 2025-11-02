import 'package:app/core/storage/cache_policy.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/design_creation/application/registrability_check_controller.dart';
import 'package:app/features/design_creation/application/registrability_check_state.dart';
import 'package:app/features/design_creation/data/registrability_check_repository.dart';
import 'package:app/features/design_creation/domain/registrability_check.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DesignRegistrabilityCheckPage extends ConsumerStatefulWidget {
  const DesignRegistrabilityCheckPage({super.key});

  @override
  ConsumerState<DesignRegistrabilityCheckPage> createState() =>
      _DesignRegistrabilityCheckPageState();
}

class _DesignRegistrabilityCheckPageState
    extends ConsumerState<DesignRegistrabilityCheckPage> {
  bool _suppressErrorSnack = false;

  @override
  void initState() {
    super.initState();
    ref.listen<RegistrabilityCheckState>(
      registrabilityCheckControllerProvider,
      (previous, next) {
        final message = next.errorMessage;
        if (message != null &&
            message != previous?.errorMessage &&
            mounted &&
            !_suppressErrorSnack) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          ref.read(registrabilityCheckControllerProvider.notifier).clearError();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(registrabilityCheckControllerProvider);
    final result = state.result;
    final isLoading = state.isLoading && !state.hasResult;
    final canRun = state.canRunCheck;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designRegistrabilityTitle),
        actions: [
          IconButton(
            tooltip: l10n.designRegistrabilityRefreshTooltip,
            icon: state.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: canRun ? () => _triggerRefresh(l10n) : null,
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : !canRun && !state.hasResult
            ? _IncompleteDesignPlaceholder(l10n: l10n)
            : RefreshIndicator(
                onRefresh: () => _triggerRefresh(l10n),
                displacement: 56,
                child: ListView(
                  padding: const EdgeInsets.all(AppTokens.spaceL),
                  children: [
                    if (state.isOutdated)
                      _RecheckBanner(
                        l10n: l10n,
                        onRecheck: () => _triggerRefresh(l10n),
                      ),
                    if (state.isOfflineFallback) _OfflineNotice(l10n: l10n),
                    if (result != null) ...[
                      _SummaryCard(
                        result: result,
                        l10n: l10n,
                        isOutdated: state.isOutdated,
                        cacheState: state.cacheState,
                        theme: theme,
                      ),
                      const SizedBox(height: AppTokens.spaceL),
                      if (result.verdict == RegistrabilityVerdict.blocked)
                        _ConflictBanner(l10n: l10n, guidance: result.guidance),
                      if (result.details.isNotEmpty) ...[
                        _DiagnosticsHeader(l10n: l10n),
                        const SizedBox(height: AppTokens.spaceS),
                        for (final detail in result.details)
                          _DiagnosticTile(detail: detail, l10n: l10n),
                      ],
                    ] else
                      _NoResultPlaceholder(
                        l10n: l10n,
                        onRun: () => _triggerRefresh(l10n),
                      ),
                    const SizedBox(height: AppTokens.spaceXXL),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _triggerRefresh(AppLocalizations l10n) async {
    final controller = ref.read(registrabilityCheckControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    _suppressErrorSnack = true;
    try {
      await controller.refresh();
    } on RegistrabilityCheckException catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
      controller.clearError();
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.designRegistrabilityRunFailed)),
        );
      controller.clearError();
    } finally {
      _suppressErrorSnack = false;
    }
  }
}

class _IncompleteDesignPlaceholder extends StatelessWidget {
  const _IncompleteDesignPlaceholder({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.draw_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              l10n.designRegistrabilityIncompleteTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              l10n.designRegistrabilityIncompleteBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultPlaceholder extends StatelessWidget {
  const _NoResultPlaceholder({required this.l10n, required this.onRun});

  final AppLocalizations l10n;
  final Future<void> Function() onRun;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.designRegistrabilityNoResultTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              l10n.designRegistrabilityNoResultBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton.icon(
              icon: const Icon(Icons.verified_outlined),
              onPressed: () {
                onRun();
              },
              label: Text(l10n.designRegistrabilityRunCheck),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecheckBanner extends StatelessWidget {
  const _RecheckBanner({required this.l10n, required this.onRecheck});

  final AppLocalizations l10n;
  final Future<void> Function() onRecheck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
      child: MaterialBanner(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        leading: const Icon(Icons.update),
        content: Text(l10n.designRegistrabilityOutdatedBanner),
        actions: [
          TextButton(
            onPressed: () {
              onRecheck();
            },
            child: Text(l10n.designRegistrabilityRunCheck),
          ),
        ],
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceM),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(l10n.designRegistrabilityOfflineTitle),
        subtitle: Text(l10n.designRegistrabilityOfflineBody),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.result,
    required this.l10n,
    required this.isOutdated,
    required this.cacheState,
    required this.theme,
  });

  final RegistrabilityCheckResult result;
  final AppLocalizations l10n;
  final bool isOutdated;
  final CacheState? cacheState;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentVerdict(result.verdict, theme, l10n);
    final timestamp = DateFormat.yMMMd().add_Hm().format(result.checkedAt);
    final cacheLabel = cacheState == CacheState.stale
        ? l10n.designRegistrabilityCacheStale
        : cacheState == CacheState.fresh
        ? l10n.designRegistrabilityCacheFresh
        : null;

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: presentation.backgroundColor,
                  foregroundColor: presentation.iconColor,
                  child: Icon(presentation.icon),
                ),
                const SizedBox(width: AppTokens.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        presentation.title,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTokens.spaceXS),
                      Text(
                        l10n.designRegistrabilityCheckedAt(timestamp),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (cacheLabel != null)
                        Text(cacheLabel, style: theme.textTheme.bodySmall),
                      if (isOutdated)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTokens.spaceS),
                          child: Text(
                            l10n.designRegistrabilityOutdatedHint,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (result.score != null)
                  Chip(
                    label: Text(
                      l10n.designRegistrabilityScore(
                        result.score!.toStringAsFixed(0),
                      ),
                    ),
                    avatar: const Icon(Icons.speed),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceM),
            Text(result.summary, style: theme.textTheme.bodyLarge),
            if (result.guidance != null) ...[
              const SizedBox(height: AppTokens.spaceS),
              Text(result.guidance!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  _VerdictPresentation _presentVerdict(
    RegistrabilityVerdict verdict,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    switch (verdict) {
      case RegistrabilityVerdict.safe:
        return _VerdictPresentation(
          title: l10n.designRegistrabilityStatusSafe,
          icon: Icons.verified_outlined,
          backgroundColor: theme.colorScheme.primaryContainer,
          iconColor: theme.colorScheme.onPrimaryContainer,
        );
      case RegistrabilityVerdict.caution:
        return _VerdictPresentation(
          title: l10n.designRegistrabilityStatusCaution,
          icon: Icons.warning_amber_outlined,
          backgroundColor: theme.colorScheme.tertiaryContainer,
          iconColor: theme.colorScheme.onTertiaryContainer,
        );
      case RegistrabilityVerdict.blocked:
        return _VerdictPresentation(
          title: l10n.designRegistrabilityStatusBlocked,
          icon: Icons.block,
          backgroundColor: theme.colorScheme.errorContainer,
          iconColor: theme.colorScheme.onErrorContainer,
        );
    }
  }
}

class _DiagnosticsHeader extends StatelessWidget {
  const _DiagnosticsHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Text(
      l10n.designRegistrabilityDiagnosticsTitle,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({required this.detail, required this.l10n});

  final RegistrabilityCheckDetail detail;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final chip = _buildChip(detail.badge, l10n, Theme.of(context));
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceS),
      child: ListTile(
        title: Text(detail.title),
        subtitle: Text(detail.description),
        trailing: chip,
      ),
    );
  }

  Widget _buildChip(
    RegistrabilityBadgeType badge,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    switch (badge) {
      case RegistrabilityBadgeType.safe:
        return Chip(
          avatar: Icon(Icons.check_circle, color: theme.colorScheme.primary),
          label: Text(l10n.designRegistrabilityBadgeSafe),
        );
      case RegistrabilityBadgeType.similar:
        return Chip(
          avatar: Icon(Icons.compare_arrows, color: theme.colorScheme.tertiary),
          label: Text(l10n.designRegistrabilityBadgeSimilar),
        );
      case RegistrabilityBadgeType.conflict:
        return Chip(
          avatar: Icon(Icons.error_outline, color: theme.colorScheme.error),
          label: Text(l10n.designRegistrabilityBadgeConflict),
        );
      case RegistrabilityBadgeType.info:
        return Chip(
          avatar: Icon(Icons.info_outline, color: theme.colorScheme.secondary),
          label: Text(l10n.designRegistrabilityBadgeInfo),
        );
    }
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.l10n, this.guidance});

  final AppLocalizations l10n;
  final String? guidance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceM),
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_outlined,
          color: theme.colorScheme.onErrorContainer,
        ),
        title: Text(
          l10n.designRegistrabilityConflictTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        subtitle: Text(
          guidance ?? l10n.designRegistrabilityConflictBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _VerdictPresentation {
  const _VerdictPresentation({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
}
