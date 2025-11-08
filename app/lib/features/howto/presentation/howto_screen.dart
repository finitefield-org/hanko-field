import 'dart:async';

import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';
import 'package:app/features/howto/application/howto_controller.dart';
import 'package:app/features/howto/domain/howto_tutorial.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class HowToScreen extends ConsumerStatefulWidget {
  const HowToScreen({super.key});

  @override
  ConsumerState<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends ConsumerState<HowToScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _tabChangeFromController = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: HowToSegment.values.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    if (_tabChangeFromController) {
      return;
    }
    final segment = HowToSegment.values[_tabController.index];
    ref.read(howToControllerProvider.notifier).selectSegment(segment);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(howToControllerProvider);
    final notifier = ref.read(howToControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    final selectedIndex = asyncState.asData?.value.selectedSegment.index;
    if (selectedIndex != null && _tabController.index != selectedIndex) {
      _tabChangeFromController = true;
      _tabController.animateTo(selectedIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabChangeFromController = false;
      });
    }

    return Scaffold(
      body: asyncState.when(
        data: (state) => _HowToLoadedView(
          state: state,
          tabController: _tabController,
          onRefresh: notifier.refresh,
        ),
        loading: () => const _HowToLoadingView(),
        error: (_, __) =>
            _HowToErrorView(onRetry: notifier.refresh, l10n: l10n),
      ),
    );
  }
}

class _HowToLoadedView extends ConsumerWidget {
  const _HowToLoadedView({
    required this.state,
    required this.tabController,
    required this.onRefresh,
  });

  final HowToState state;
  final TabController tabController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(howToControllerProvider.notifier);
    final appState = ref.read(appStateProvider.notifier);
    final featured = state.featuredTutorial;

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 80,
      child: NestedScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        headerSliverBuilder: (context, _) {
          return [
            SliverAppBar.large(
              title: Text(l10n.howToScreenTitle),
              pinned: true,
              actions: [
                IconButton(
                  tooltip: l10n.howToRefreshTooltip,
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(state.isRefreshing ? 150 : 132),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceL,
                      ),
                      child: _CompletionSummary(state: state),
                    ),
                    TabBar(
                      controller: tabController,
                      tabs: [
                        Tab(text: l10n.howToVideosTabLabel),
                        Tab(text: l10n.howToGuidesTabLabel),
                      ],
                    ),
                    if (state.isRefreshing)
                      const LinearProgressIndicator(minHeight: 2),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: tabController,
          children: [
            _HowToVideosTab(
              state: state,
              featured: featured,
              onToggleCompletion: notifier.toggleCompletion,
              onMarkCompleted: notifier.markCompleted,
              onOpenGuide: (slug) =>
                  appState.push(GuidesRoute(sectionSegments: [slug])),
            ),
            _HowToGuidesTab(
              guides: state.guides,
              onGuideTap: (entry) =>
                  appState.push(GuidesRoute(sectionSegments: [entry.slug])),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionSummary extends StatelessWidget {
  const _CompletionSummary({required this.state});

  final HowToState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final completed = state.completedTutorialIds.length;
    final total = state.tutorialCount;
    final theme = Theme.of(context);
    final progress = state.completionRatio.clamp(0, 1).toDouble();
    final lastUpdated = state.lastUpdated;
    final formatter = DateFormat.yMMMd().add_Hm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.howToScreenSubtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppTokens.spaceS),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.howToCompletionLabel(completed, total),
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (lastUpdated != null)
              Text(
                formatter.format(lastUpdated),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceS),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress == 0 ? 0.0 : progress),
        ),
      ],
    );
  }
}

class _HowToVideosTab extends StatelessWidget {
  const _HowToVideosTab({
    required this.state,
    required this.onToggleCompletion,
    required this.onMarkCompleted,
    required this.onOpenGuide,
    this.featured,
  });

  final HowToState state;
  final HowToTutorial? featured;
  final Future<void> Function(String tutorialId) onToggleCompletion;
  final Future<void> Function(String tutorialId) onMarkCompleted;
  final void Function(String slug) onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (featured != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceS,
              ),
              child: _FeaturedTutorialCard(
                tutorial: featured!,
                completed: state.completedTutorialIds.contains(featured!.id),
                onToggleCompletion: () => onToggleCompletion(featured!.id),
                onMarkCompleted: () => onMarkCompleted(featured!.id),
                onOpenGuide: onOpenGuide,
              ),
            ),
          ),
        for (final group in state.groups)
          Builder(
            builder: (context) {
              final tutorials = [
                for (final tutorial in group.tutorials)
                  if (featured == null || tutorial.id != featured!.id) tutorial,
              ];
              if (tutorials.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceS,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TopicHeader(group: group),
                    const SizedBox(height: AppTokens.spaceS),
                    for (var i = 0; i < tutorials.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 0 : AppTokens.spaceL,
                        ),
                        child: _HowToVideoCard(
                          tutorial: tutorials[i],
                          completed: state.completedTutorialIds.contains(
                            tutorials[i].id,
                          ),
                          onToggleCompletion: () =>
                              onToggleCompletion(tutorials[i].id),
                          onMarkCompleted: () =>
                              onMarkCompleted(tutorials[i].id),
                          onOpenGuide: onOpenGuide,
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTokens.spaceXL * 2),
        ),
      ],
    );
  }
}

class _HowToGuidesTab extends StatelessWidget {
  const _HowToGuidesTab({required this.guides, required this.onGuideTap});

  final List<GuideListEntry> guides;
  final void Function(GuideListEntry entry) onGuideTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (guides.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            title: l10n.howToGuidesEmptyTitle,
            message: l10n.howToGuidesEmptyMessage,
            icon: const Icon(Icons.article_outlined),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      itemCount: guides.length,
      itemBuilder: (context, index) {
        final guide = guides[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == guides.length - 1 ? 0 : AppTokens.spaceL,
          ),
          child: _GuideListTile(guide: guide, onTap: () => onGuideTap(guide)),
        );
      },
    );
  }
}

class _HowToLoadingView extends StatelessWidget {
  const _HowToLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      children: const [
        AppSkeletonBlock(height: 48, width: 200),
        SizedBox(height: AppTokens.spaceL),
        AppListSkeleton(items: 3),
      ],
    );
  }
}

class _HowToErrorView extends StatelessWidget {
  const _HowToErrorView({required this.onRetry, required this.l10n});

  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: AppEmptyState(
          title: l10n.howToLoadErrorTitle,
          message: l10n.howToLoadErrorMessage,
          icon: const Icon(Icons.live_help_outlined),
          primaryAction: AppButton(
            label: l10n.howToRetryButtonLabel,
            onPressed: onRetry,
          ),
        ),
      ),
    );
  }
}

class _FeaturedTutorialCard extends StatelessWidget {
  const _FeaturedTutorialCard({
    required this.tutorial,
    required this.completed,
    required this.onToggleCompletion,
    required this.onMarkCompleted,
    required this.onOpenGuide,
  });

  final HowToTutorial tutorial;
  final bool completed;
  final VoidCallback onToggleCompletion;
  final VoidCallback onMarkCompleted;
  final void Function(String slug) onOpenGuide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Badge(label: Text(l10n.howToFeaturedLabel)),
              const Spacer(),
              if (completed)
                Chip(
                  label: Text(l10n.howToCompletedLabel),
                  avatar: const Icon(Icons.check_circle, size: 18),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(tutorial.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTokens.spaceXS),
          Text(tutorial.summary),
          const SizedBox(height: AppTokens.spaceM),
          _HowToVideoCard(
            tutorial: tutorial,
            completed: completed,
            onToggleCompletion: onToggleCompletion,
            onMarkCompleted: onMarkCompleted,
            onOpenGuide: onOpenGuide,
          ),
        ],
      ),
    );
  }
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({required this.group});

  final HowToTopicGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTokens.spaceXS),
        Text(group.description, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _HowToVideoCard extends StatefulWidget {
  const _HowToVideoCard({
    required this.tutorial,
    required this.completed,
    required this.onToggleCompletion,
    required this.onMarkCompleted,
    required this.onOpenGuide,
  });

  final HowToTutorial tutorial;
  final bool completed;
  final VoidCallback onToggleCompletion;
  final VoidCallback onMarkCompleted;
  final void Function(String slug) onOpenGuide;

  @override
  State<_HowToVideoCard> createState() => _HowToVideoCardState();
}

class _HowToVideoCardState extends State<_HowToVideoCard> {
  late VideoPlayerController _controller;
  late Future<void> _initializeFuture;
  bool _isMuted = true;
  bool _showCaptions = false;
  bool _reportedCompletion = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _HowToVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tutorial.id != widget.tutorial.id) {
      _controller.removeListener(_handleProgress);
      unawaited(_controller.dispose());
      _initController();
    }
    if (!widget.completed) {
      _reportedCompletion = false;
    }
  }

  void _initController() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.tutorial.videoUrl),
    );
    _initializeFuture = _controller.initialize().then((_) async {
      await _controller.setLooping(false);
      await _controller.setVolume(0);
      if (mounted) {
        setState(() {});
      }
    });
    _controller.addListener(_handleProgress);
  }

  void _handleProgress() {
    final value = _controller.value;
    if (!value.isInitialized || _reportedCompletion) {
      return;
    }
    final duration = value.duration;
    if (duration == Duration.zero) {
      return;
    }
    if (value.position >= duration - const Duration(milliseconds: 400)) {
      _reportedCompletion = true;
      widget.onMarkCompleted();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleProgress);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_controller.value.isInitialized) {
      return;
    }
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleMute() {
    if (!_controller.value.isInitialized) {
      return;
    }
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _toggleCaptions() {
    setState(() {
      _showCaptions = !_showCaptions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final durationLabel = _formatDuration(widget.tutorial.duration);
    final difficultyLabel = _difficultyLabel(widget.tutorial.difficulty, l10n);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<void>(
            future: _initializeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.tutorial.thumbnailUrl != null)
                        Image.network(
                          widget.tutorial.thumbnailUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                );
              }
              final aspect = _controller.value.aspectRatio == 0
                  ? 16 / 9
                  : _controller.value.aspectRatio;
              return Stack(
                children: [
                  GestureDetector(
                    onTap: _togglePlayback,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _VideoControls(
                      controller: _controller,
                      isPlaying: _controller.value.isPlaying,
                      isMuted: _isMuted,
                      showCaptions: _showCaptions,
                      onPlayPause: _togglePlayback,
                      onMuteToggle: _toggleMute,
                      onCaptionToggle: widget.tutorial.caption == null
                          ? null
                          : _toggleCaptions,
                    ),
                  ),
                  if (_showCaptions && widget.tutorial.caption != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 72,
                      child: _CaptionBubble(text: widget.tutorial.caption!),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppTokens.spaceM),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: [
              Chip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(durationLabel),
              ),
              Chip(
                avatar: const Icon(Icons.layers_outlined, size: 18),
                label: Text(difficultyLabel),
              ),
              if (widget.tutorial.badge != null)
                Chip(label: Text(widget.tutorial.badge!)),
            ],
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(widget.tutorial.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTokens.spaceM),
          Text(l10n.howToStepsLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppTokens.spaceXS),
          for (var index = 0; index < widget.tutorial.steps.length; index++)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
              title: Text(widget.tutorial.steps[index].title),
              subtitle: Text(widget.tutorial.steps[index].description),
              trailing: widget.tutorial.steps[index].timestamp == null
                  ? null
                  : Text(
                      _formatDuration(widget.tutorial.steps[index].timestamp!),
                    ),
            ),
          const SizedBox(height: AppTokens.spaceS),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onToggleCompletion,
                  icon: Icon(
                    widget.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  label: Text(
                    widget.completed
                        ? l10n.howToCompletedLabel
                        : l10n.howToMarkComplete,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceS),
              if (widget.tutorial.relatedGuideSlug != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      widget.onOpenGuide(widget.tutorial.relatedGuideSlug!),
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l10n.howToOpenGuideLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return '${duration.inSeconds}s';
  }

  String _difficultyLabel(
    HowToDifficultyLevel difficulty,
    AppLocalizations l10n,
  ) {
    return switch (difficulty) {
      HowToDifficultyLevel.beginner => l10n.howToDifficultyBeginner,
      HowToDifficultyLevel.intermediate => l10n.howToDifficultyIntermediate,
      HowToDifficultyLevel.advanced => l10n.howToDifficultyAdvanced,
    };
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    required this.isPlaying,
    required this.isMuted,
    required this.showCaptions,
    required this.onPlayPause,
    required this.onMuteToggle,
    this.onCaptionToggle,
  });

  final VideoPlayerController controller;
  final bool isPlaying;
  final bool isMuted;
  final bool showCaptions;
  final VoidCallback onPlayPause;
  final VoidCallback onMuteToggle;
  final VoidCallback? onCaptionToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: Colors.black.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
              color: Colors.white,
              tooltip: isMuted
                  ? l10n.howToUnmuteTooltip
                  : l10n.howToMuteTooltip,
              onPressed: onMuteToggle,
            ),
            if (onCaptionToggle != null)
              IconButton(
                icon: Icon(
                  showCaptions
                      ? Icons.closed_caption
                      : Icons.closed_caption_off,
                ),
                color: Colors.white,
                tooltip: showCaptions
                    ? l10n.howToHideCaptionsTooltip
                    : l10n.howToShowCaptionsTooltip,
                onPressed: onCaptionToggle,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: scheme.primary,
                  bufferedColor: scheme.onPrimary.withValues(alpha: 0.4),
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onPlayPause,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              tooltip: isPlaying
                  ? l10n.howToPauseTooltip
                  : l10n.howToPlayTooltip,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionBubble extends StatelessWidget {
  const _CaptionBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _GuideListTile extends StatelessWidget {
  const _GuideListTile({required this.guide, required this.onTap});

  final GuideListEntry guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (guide.heroImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(guide.heroImageUrl!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: AppTokens.spaceS),
          Text(guide.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.spaceXS),
          Text(guide.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            children: [
              if (guide.readingTimeMinutes != null)
                Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text('${guide.readingTimeMinutes} min'),
                ),
              if (guide.featured)
                Chip(
                  avatar: const Icon(Icons.bookmark, size: 18),
                  label: Text(AppLocalizations.of(context).howToFeaturedLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
