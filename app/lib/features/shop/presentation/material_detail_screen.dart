import 'package:app/features/shop/application/material_detail_provider.dart';
import 'package:app/features/shop/domain/material_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class MaterialDetailScreen extends ConsumerStatefulWidget {
  const MaterialDetailScreen({required this.materialId, super.key});

  final String materialId;

  @override
  ConsumerState<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends ConsumerState<MaterialDetailScreen> {
  late final PageController _pageController;
  bool _isFavorite = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(materialDetailProvider(widget.materialId));
    return detailAsync.when(
      data: (detail) => _MaterialDetailLoadedView(
        detail: detail,
        pageController: _pageController,
        currentPage: _currentPage,
        isFavorite: _isFavorite,
        onToggleFavorite: _toggleFavorite,
        onPageChanged: _handlePageChanged,
        onViewCompatible: () => _showCompatibleProducts(detail),
      ),
      loading: () => const _MaterialDetailLoadingView(),
      error: (error, stack) => _MaterialDetailErrorView(
        onRetry: () => ref.refresh(materialDetailProvider(widget.materialId)),
      ),
    );
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _showCompatibleProducts(MaterialDetail detail) async {
    if (detail.compatibleProductIds.isEmpty) {
      return;
    }
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('対応製品一覧', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  'この素材と組み合わせられる製品です。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: detail.compatibleProductIds.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final productId = detail.compatibleProductIds[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text('製品 $productId'),
                        subtitle: const Text('対応製品詳細は今後追加予定です。'),
                        onTap: () {
                          Navigator.of(context).pop();
                          scaffoldMessenger.hideCurrentSnackBar();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('製品 $productId の詳細へ遷移（未実装）'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MaterialDetailLoadedView extends StatelessWidget {
  const _MaterialDetailLoadedView({
    required this.detail,
    required this.pageController,
    required this.currentPage,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onPageChanged,
    required this.onViewCompatible,
  });

  final MaterialDetail detail;
  final PageController pageController;
  final int currentPage;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onViewCompatible;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(detail.material.name),
            actions: [
              IconButton(
                tooltip: isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: onToggleFavorite,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detail.highlights
                        .map(
                          (highlight) => Chip(
                            avatar: const Icon(Icons.check_circle_outline),
                            label: Text(highlight),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  _MaterialMediaCarousel(
                    detail: detail,
                    pageController: pageController,
                    currentPage: currentPage,
                    onPageChanged: onPageChanged,
                  ),
                  const SizedBox(height: 24),
                  _MaterialSpecsSection(detail: detail),
                  const SizedBox(height: 24),
                  if (detail.compatibleProductIds.isNotEmpty)
                    _CompatibleProductsCard(
                      detail: detail,
                      onViewCompatible: onViewCompatible,
                    ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _MaterialDetailActionBar(detail: detail),
    );
  }
}

class _MaterialDetailActionBar extends StatelessWidget {
  const _MaterialDetailActionBar({required this.detail});

  final MaterialDetail detail;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('注文を開始'),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('${detail.material.name} をカートに追加（未実装）'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.share_outlined),
              label: const Text('共有する'),
              onPressed: () {
                Share.share(
                  'Check out ${detail.material.name} from Hanko Field.',
                  subject: 'Material: ${detail.material.name}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialMediaCarousel extends StatelessWidget {
  const _MaterialMediaCarousel({
    required this.detail,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
  });

  final MaterialDetail detail;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final mediaItems = detail.media;
    if (mediaItems.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Text(
          'メディアがまだ追加されていません。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: pageController,
            itemCount: mediaItems.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final media = mediaItems[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 4,
                  shadowColor: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: _MaterialMediaContent(media: media),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            mediaItems.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: currentPage == index ? 20 : 8,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        if (mediaItems[currentPage].caption != null) ...[
          const SizedBox(height: 12),
          Text(
            mediaItems[currentPage].caption!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _MaterialMediaContent extends StatelessWidget {
  const _MaterialMediaContent({required this.media});

  final MaterialMedia media;

  @override
  Widget build(BuildContext context) {
    return switch (media.type) {
      MaterialMediaType.image => _ZoomableImage(url: media.url),
      MaterialMediaType.video => _CarouselVideoPlayer(
        url: media.url,
        previewUrl: media.previewImageUrl,
      ),
    };
  }
}

class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Ink.image(image: NetworkImage(url), fit: BoxFit.cover),
    );
  }
}

class _CarouselVideoPlayer extends StatefulWidget {
  const _CarouselVideoPlayer({required this.url, this.previewUrl});

  final String url;
  final String? previewUrl;

  @override
  State<_CarouselVideoPlayer> createState() => _CarouselVideoPlayerState();
}

class _CarouselVideoPlayerState extends State<_CarouselVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialiseFuture;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialiseFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialiseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.previewUrl != null)
                Ink.image(
                  image: NetworkImage(widget.previewUrl!),
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }

        final aspect = _controller.value.aspectRatio == 0
            ? 16 / 9
            : _controller.value.aspectRatio;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                  setState(() {});
                },
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _controller.setVolume(_isMuted ? 0 : 1);
                      });
                    },
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Theme.of(context).colorScheme.primary,
                        bufferedColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: () {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MaterialSpecsSection extends StatelessWidget {
  const _MaterialSpecsSection({required this.detail});

  final MaterialDetail detail;

  @override
  Widget build(BuildContext context) {
    final specs = detail.specs;
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            _AvailabilityTile(availability: detail.availability),
            const Divider(height: 1),
            ...List.generate(specs.length, (index) {
              final spec = specs[index];
              final isLast = index == specs.length - 1;
              return Column(
                children: [
                  _SpecTile(spec: spec),
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityTile extends StatelessWidget {
  const _AvailabilityTile({required this.availability});

  final MaterialAvailability availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(availability.statusLabel, style: theme.textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availability.estimatedLeadTime != null)
            Text(
              availability.estimatedLeadTime!,
              style: theme.textTheme.bodyMedium,
            ),
          if (availability.inventoryNote != null) ...[
            const SizedBox(height: 4),
            Text(availability.inventoryNote!, style: theme.textTheme.bodySmall),
          ],
          if (availability.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availability.tags
                  .map((tag) => _AssistChip(label: tag))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.spec});

  final MaterialSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForKind(spec.kind);
    return ListTile(
      leading: Icon(icon),
      title: Text(spec.label, style: theme.textTheme.bodyLarge),
      subtitle: spec.detail != null ? Text(spec.detail!) : null,
      trailing: _AssistChip(label: spec.value),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  IconData _iconForKind(MaterialSpecKind kind) {
    return switch (kind) {
      MaterialSpecKind.hardness => Icons.fitness_center_outlined,
      MaterialSpecKind.texture => Icons.texture,
      MaterialSpecKind.finish => Icons.layers_outlined,
      MaterialSpecKind.origin => Icons.public,
      MaterialSpecKind.density => Icons.line_weight,
      MaterialSpecKind.color => Icons.palette_outlined,
      MaterialSpecKind.sustainability => Icons.eco_outlined,
      MaterialSpecKind.maintenance => Icons.build_outlined,
      MaterialSpecKind.bestFor => Icons.star_outline,
    };
  }
}

class _CompatibleProductsCard extends StatelessWidget {
  const _CompatibleProductsCard({
    required this.detail,
    required this.onViewCompatible,
  });

  final MaterialDetail detail;
  final VoidCallback onViewCompatible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('対応する製品', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detail.compatibleProductIds
                  .map(
                    (productId) => Chip(
                      label: Text(productId),
                      avatar: const Icon(Icons.inventory_outlined, size: 18),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onViewCompatible,
                icon: const Icon(Icons.arrow_outward),
                label: Text('互換製品を表示 (${detail.compatibleProductIds.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistChip extends StatelessWidget {
  const _AssistChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () {},
      visualDensity: VisualDensity.compact,
      pressElevation: 0,
    );
  }
}

class _MaterialDetailLoadingView extends StatelessWidget {
  const _MaterialDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _MaterialDetailErrorView extends StatelessWidget {
  const _MaterialDetailErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('素材の読み込みに失敗しました。'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('再試行')),
            ],
          ),
        ),
      ),
    );
  }
}
