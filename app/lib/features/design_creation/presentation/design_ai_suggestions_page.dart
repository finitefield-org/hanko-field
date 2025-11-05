import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/design_creation/application/design_ai_suggestions_controller.dart';
import 'package:app/features/design_creation/application/design_ai_suggestions_state.dart';
import 'package:app/features/design_creation/domain/ai_suggestion.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesignAiSuggestionsPage extends ConsumerStatefulWidget {
  const DesignAiSuggestionsPage({super.key});

  @override
  ConsumerState<DesignAiSuggestionsPage> createState() =>
      _DesignAiSuggestionsPageState();
}

class _DesignAiSuggestionsPageState
    extends ConsumerState<DesignAiSuggestionsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(designAiSuggestionsControllerProvider);
    final controller = ref.read(designAiSuggestionsControllerProvider.notifier);
    final rateLimitRemaining = state.rateLimitRemaining(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.designAiSuggestionsTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.spaceS),
            child: Badge.count(
              count: state.queuedCount,
              isLabelVisible: state.queuedCount > 0,
              alignment: AlignmentDirectional.topEnd,
              child: IconButton(
                tooltip: l10n.designAiSuggestionsQueueTooltip,
                icon: const Icon(Icons.history_outlined),
                onPressed: state.queuedCount > 0
                    ? () =>
                          controller.setFilter(DesignAiSuggestionFilter.queued)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.manualRefresh,
          displacement: 56,
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _RequestHeader(
                isLoading: state.isRequesting,
                onRequest: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await controller.requestSuggestions();
                  if (!mounted) return;
                  switch (result.status) {
                    case DesignAiActionStatus.success:
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.designAiSuggestionsRequestQueued,
                            ),
                          ),
                        );
                    case DesignAiActionStatus.rateLimited:
                      final remaining =
                          result.retryAfter ?? const Duration(seconds: 10);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.designAiSuggestionsRequestRateLimited(
                                remaining.inSeconds,
                              ),
                            ),
                          ),
                        );
                    case DesignAiActionStatus.failure:
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              result.message ??
                                  l10n.designAiSuggestionsGenericError,
                            ),
                          ),
                        );
                  }
                },
                isDisabled: rateLimitRemaining != null,
                rateLimitRemaining: rateLimitRemaining,
                state: state,
              ),
              const SizedBox(height: AppTokens.spaceL),
              _StateBanner(message: state.errorMessage),
              if (state.errorMessage != null)
                const SizedBox(height: AppTokens.spaceL),
              SegmentedButton<DesignAiSuggestionFilter>(
                segments: [
                  ButtonSegment<DesignAiSuggestionFilter>(
                    value: DesignAiSuggestionFilter.ready,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: Text(
                      l10n.designAiSuggestionsSegmentReady(state.readyCount),
                    ),
                  ),
                  ButtonSegment<DesignAiSuggestionFilter>(
                    value: DesignAiSuggestionFilter.queued,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      l10n.designAiSuggestionsSegmentQueued(state.queuedCount),
                    ),
                  ),
                  ButtonSegment<DesignAiSuggestionFilter>(
                    value: DesignAiSuggestionFilter.applied,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: Text(
                      l10n.designAiSuggestionsSegmentApplied(
                        state.appliedCount,
                      ),
                    ),
                  ),
                ],
                selected: {state.filter},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    controller.setFilter(selection.first);
                  }
                },
              ),
              const SizedBox(height: AppTokens.spaceL),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTokens.spaceXL),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.visibleSuggestions.isEmpty)
                _EmptyPlaceholder(
                  filter: state.filter,
                  l10n: l10n,
                  onRequest: state.filter == DesignAiSuggestionFilter.ready
                      ? () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final result = await controller.requestSuggestions();
                          if (!mounted) return;
                          if (result.status == DesignAiActionStatus.success) {
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.designAiSuggestionsRequestQueued,
                                  ),
                                ),
                              );
                          }
                        }
                      : null,
                )
              else ...[
                for (final suggestion in state.visibleSuggestions)
                  _SuggestionCard(
                    suggestion: suggestion,
                    l10n: l10n,
                    isBusy: state.pendingActionIds.contains(suggestion.id),
                    onAccept: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await controller.acceptSuggestion(
                        suggestion.id,
                      );
                      if (!mounted) return;
                      _showActionFeedback(
                        messenger,
                        l10n: l10n,
                        result: result,
                        successMessage: l10n.designAiSuggestionsAcceptSuccess(
                          suggestion.title,
                        ),
                      );
                    },
                    onReject:
                        suggestion.status == DesignAiSuggestionStatus.ready
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final result = await controller.rejectSuggestion(
                              suggestion.id,
                            );
                            if (!mounted) return;
                            _showActionFeedback(
                              messenger,
                              l10n: l10n,
                              result: result,
                              successMessage: l10n
                                  .designAiSuggestionsRejectSuccess(
                                    suggestion.title,
                                  ),
                            );
                          }
                        : null,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showActionFeedback(
    ScaffoldMessengerState messenger, {
    required AppLocalizations l10n,
    required DesignAiActionResult result,
    required String successMessage,
  }) {
    messenger.hideCurrentSnackBar();
    switch (result.status) {
      case DesignAiActionStatus.success:
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      case DesignAiActionStatus.rateLimited:
        final remaining = result.retryAfter ?? const Duration(seconds: 10);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.designAiSuggestionsRequestRateLimited(remaining.inSeconds),
            ),
          ),
        );
      case DesignAiActionStatus.failure:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? l10n.designAiSuggestionsGenericError,
            ),
          ),
        );
    }
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({
    required this.isLoading,
    required this.onRequest,
    required this.isDisabled,
    required this.rateLimitRemaining,
    required this.state,
  });

  final bool isLoading;
  final VoidCallback onRequest;
  final bool isDisabled;
  final Duration? rateLimitRemaining;
  final DesignAiSuggestionsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final remainingLabel = rateLimitRemaining == null
        ? null
        : l10n.designAiSuggestionsRateLimitCountdown(
            rateLimitRemaining!.inSeconds,
          );
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.designAiSuggestionsHelperTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.designAiSuggestionsHelperSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTokens.spaceM),
          FilledButton.icon(
            onPressed: isDisabled || isLoading ? null : onRequest,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            label: Text(l10n.designAiSuggestionsRequestCta),
          ),
          if (remainingLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceS),
              child: Text(
                remainingLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.tertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _StateBanner extends StatelessWidget {
  const _StateBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppTokens.radiusM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({
    required this.filter,
    required this.l10n,
    this.onRequest,
  });

  final DesignAiSuggestionFilter filter;
  final AppLocalizations l10n;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (filter) {
      DesignAiSuggestionFilter.ready => (
        l10n.designAiSuggestionsEmptyReadyTitle,
        l10n.designAiSuggestionsEmptyReadyBody,
      ),
      DesignAiSuggestionFilter.queued => (
        l10n.designAiSuggestionsEmptyQueuedTitle,
        l10n.designAiSuggestionsEmptyQueuedBody,
      ),
      DesignAiSuggestionFilter.applied => (
        l10n.designAiSuggestionsEmptyAppliedTitle,
        l10n.designAiSuggestionsEmptyAppliedBody,
      ),
    };
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.spaceXL,
        horizontal: AppTokens.spaceL,
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_fix_high_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: AppTokens.spaceM),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRequest != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceL),
              child: FilledButton(
                onPressed: onRequest,
                child: Text(l10n.designAiSuggestionsRequestCta),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.l10n,
    required this.isBusy,
    required this.onAccept,
    this.onReject,
  });

  final DesignAiSuggestion suggestion;
  final AppLocalizations l10n;
  final bool isBusy;
  final Future<void> Function() onAccept;
  final Future<void> Function()? onReject;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;
    final scheme = Theme.of(context).colorScheme;
    final scoreLabel = widget.l10n.designAiSuggestionsScoreLabel(
      (suggestion.score * 100).round(),
    );

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceS),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceS,
                  vertical: AppTokens.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: AppTokens.radiusS,
                ),
                child: Text(
                  scoreLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            suggestion.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTokens.spaceM),
          if (suggestion.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
              child: Wrap(
                spacing: AppTokens.spaceS,
                runSpacing: AppTokens.spaceS / 2,
                children: [
                  for (final tag in suggestion.tags) Chip(label: Text(tag)),
                ],
              ),
            ),
          _PreviewComparison(
            split: _split,
            onChanged: (value) => setState(() => _split = value),
            baselineUrl: suggestion.baselinePreviewUrl,
            proposedUrl: suggestion.proposedPreviewUrl,
            l10n: widget.l10n,
          ),
          const SizedBox(height: AppTokens.spaceM),
          switch (suggestion.status) {
            DesignAiSuggestionStatus.ready => _ActionRow(
              isBusy: widget.isBusy,
              onAccept: widget.onAccept,
              onReject: widget.onReject,
              l10n: widget.l10n,
            ),
            DesignAiSuggestionStatus.applied => _AppliedLabel(
              l10n: widget.l10n,
            ),
            DesignAiSuggestionStatus.queued => _QueuedLabel(l10n: widget.l10n),
            DesignAiSuggestionStatus.rejected => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
    required this.l10n,
  });

  final bool isBusy;
  final Future<void> Function() onAccept;
  final Future<void> Function()? onReject;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy ? null : onAccept,
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(l10n.designAiSuggestionsAccept),
          ),
        ),
        const SizedBox(width: AppTokens.spaceM),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isBusy || onReject == null ? null : onReject,
            icon: const Icon(Icons.close),
            label: Text(l10n.designAiSuggestionsReject),
          ),
        ),
      ],
    );
  }
}

class _AppliedLabel extends StatelessWidget {
  const _AppliedLabel({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppTokens.radiusM,
      ),
      padding: const EdgeInsets.all(AppTokens.spaceS),
      child: Row(
        children: [
          Icon(Icons.task_alt, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppTokens.spaceS),
          Text(
            l10n.designAiSuggestionsAppliedLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedLabel extends StatelessWidget {
  const _QueuedLabel({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppTokens.radiusM,
      ),
      padding: const EdgeInsets.all(AppTokens.spaceS),
      child: Row(
        children: [
          Icon(Icons.schedule, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppTokens.spaceS),
          Text(
            l10n.designAiSuggestionsQueuedLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PreviewComparison extends StatelessWidget {
  const _PreviewComparison({
    required this.split,
    required this.onChanged,
    required this.baselineUrl,
    required this.proposedUrl,
    required this.l10n,
  });

  final double split;
  final ValueChanged<double> onChanged;
  final String baselineUrl;
  final String proposedUrl;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final clampedSplit = split.clamp(0.0, 1.0);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: AppTokens.radiusM,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final handleX = clampedSplit * width;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(child: _PreviewImage(url: baselineUrl)),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: math.max(clampedSplit, 0.001),
                            child: _PreviewImage(url: proposedUrl),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: handleX.clamp(0, width - 1),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: const Color(0xE6FFFFFF),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(value: clampedSplit, onChanged: onChanged),
            ),
            Padding(
              padding: const EdgeInsets.only(left: AppTokens.spaceS),
              child: Text(
                l10n.designAiSuggestionsComparisonHint,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined),
        );
      },
    );
  }
}
