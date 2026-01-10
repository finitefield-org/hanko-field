// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/onboarding/view_model/onboarding_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendStepViewed(0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final viewState = ref.watch(onboardingViewModel);
    final completeState = ref.watch(onboardingViewModel.completeMut);
    final skipState = ref.watch(onboardingViewModel.skipMut);
    final isCompleting = completeState is PendingMutationState;
    final isSkipping = skipState is PendingMutationState;
    final isBusy = isCompleting || isSkipping;

    Widget body;
    if (viewState is AsyncLoading<OnboardingState>) {
      body = const _OnboardingLoader();
    } else if (viewState case AsyncError(:final error)) {
      body = _OnboardingError(
        message: error.toString(),
        onRetry: () => ref.invalidate(onboardingViewModel),
      );
    } else {
      final slides = _slides(l10n, colorScheme);
      final totalSteps = slides.length;
      final progress = (_currentPage + 1) / totalSteps;

      body = PopScope(
        canPop: _currentPage == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBack();
        },
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            children: [
              _ProgressHeader(
                label: l10n.onboardingStepCount(_currentPage + 1, totalSteps),
                progress: progress,
              ),
              SizedBox(height: tokens.spacing.md),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalSteps,
                  physics: isBusy
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _sendStepViewed(index);
                  },
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return _OnboardingCard(slide: slide);
                  },
                ),
              ),
              SizedBox(height: tokens.spacing.md),
              _ProgressBar(progress: progress),
              SizedBox(height: tokens.spacing.lg),
              _ActionBar(
                l10n: l10n,
                tokens: tokens,
                isBusy: isBusy,
                isFirst: _currentPage == 0,
                isLast: _currentPage == totalSteps - 1,
                onBack: _handleBack,
                onNext: () => _handleNext(totalSteps),
                onSkip: () =>
                    _finishFlow(skipped: true, totalSteps: totalSteps),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingTitle),
        leading: IconButton(
          icon: Icon(_currentPage == 0 ? Icons.close : Icons.arrow_back),
          onPressed: isBusy ? null : _handleBack,
          tooltip: l10n.onboardingBack,
        ),
        actions: [
          TextButton(
            onPressed: isBusy
                ? null
                : () {
                    final slides = _slides(l10n, colorScheme);
                    _finishFlow(skipped: true, totalSteps: slides.length);
                  },
            child: Text(l10n.onboardingSkip),
          ),
        ],
      ),
      body: body,
    );
  }

  void _sendStepViewed(int index) {
    final totalSteps = _slides(
      AppLocalizations.of(context),
      Theme.of(context).colorScheme,
    ).length;
    ref.invoke(
      onboardingViewModel.markStep(step: index + 1, totalSteps: totalSteps),
    );
  }

  void _handleBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _handleNext(int totalSteps) {
    final isLast = _currentPage >= totalSteps - 1;
    if (isLast) {
      _finishFlow(skipped: false, totalSteps: totalSteps);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishFlow({
    required bool skipped,
    required int totalSteps,
  }) async {
    final step = _currentPage + 1;
    final action = skipped
        ? onboardingViewModel.skip(step: step, totalSteps: totalSteps)
        : onboardingViewModel.complete(step: step, totalSteps: totalSteps);

    try {
      await ref.invoke(action);
      if (!mounted) return;
      await context.go(AppRoutePaths.locale);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.label, required this.progress});

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.md,
            vertical: tokens.spacing.xs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(tokens.radii.lg),
          ),
          child: Text(
            '${(progress * 100).round()}%',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.md),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: progress,
        backgroundColor: colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
      child: Material(
        elevation: 12,
        shadowColor: slide.accent.withValues(alpha: 0.25),
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SlideBadge(label: slide.tagline, accent: slide.accent),
              SizedBox(height: tokens.spacing.lg),
              _SlideIllustration(slide: slide),
              SizedBox(height: tokens.spacing.lg),
              Text(slide.title, style: theme.textTheme.headlineSmall),
              SizedBox(height: tokens.spacing.sm),
              Text(
                slide.body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideIllustration extends StatelessWidget {
  const _SlideIllustration({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = slide.accent;
    final gradient = LinearGradient(
      colors: [accent.withValues(alpha: 0.14), accent.withValues(alpha: 0.34)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return SizedBox(
      height: 190,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(tokens.radii.lg),
            ),
          ),
          PositionedDirectional(
            start: -20,
            top: -10,
            child: _Halo(accent: accent.withValues(alpha: 0.3)),
          ),
          PositionedDirectional(
            end: -16,
            bottom: -12,
            child: _Halo(accent: accent.withValues(alpha: 0.2)),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Icon(
                  slide.icon,
                  size: 96,
                  color: colorScheme.onPrimary.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: tokens.spacing.lg,
            bottom: tokens.spacing.lg,
            child: Text(
              slide.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 9,
      child: Container(
        width: 160,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(42),
          color: accent,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 36,
              spreadRadius: 8,
              offset: const Offset(0, 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideBadge extends StatelessWidget {
  const _SlideBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radii.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.l10n,
    required this.tokens,
    required this.isBusy,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final AppLocalizations l10n;
  final DesignTokens tokens;
  final bool isBusy;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy ? null : (isFirst ? onSkip : onBack),
                style: buttonStyle,
                child: Text(
                  isFirst ? l10n.onboardingSkip : l10n.onboardingBack,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.md),
            Expanded(
              child: FilledButton.tonal(
                onPressed: isBusy ? null : onNext,
                style: buttonStyle,
                child: Text(
                  isLast ? l10n.onboardingFinish : l10n.onboardingNext,
                ),
              ),
            ),
          ],
        ),
        if (isBusy) ...[
          SizedBox(height: tokens.spacing.sm),
          Center(
            child: SizedBox(
              width: tokens.spacing.lg,
              height: tokens.spacing.lg,
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ],
      ],
    );
  }
}

class _OnboardingLoader extends StatelessWidget {
  const _OnboardingLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}

class _OnboardingError extends StatelessWidget {
  const _OnboardingError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).onboardingErrorTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).onboardingRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.body,
    required this.tagline,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String body;
  final String tagline;
  final IconData icon;
  final Color accent;
}

List<_OnboardingSlide> _slides(AppLocalizations l10n, ColorScheme colorScheme) {
  return [
    _OnboardingSlide(
      title: l10n.onboardingSlideCreateTitle,
      body: l10n.onboardingSlideCreateBody,
      tagline: l10n.onboardingSlideCreateTagline,
      icon: Icons.gesture_rounded,
      accent: colorScheme.primary,
    ),
    _OnboardingSlide(
      title: l10n.onboardingSlideMaterialsTitle,
      body: l10n.onboardingSlideMaterialsBody,
      tagline: l10n.onboardingSlideMaterialsTagline,
      icon: Icons.widgets_outlined,
      accent: colorScheme.secondary,
    ),
    _OnboardingSlide(
      title: l10n.onboardingSlideSupportTitle,
      body: l10n.onboardingSlideSupportBody,
      tagline: l10n.onboardingSlideSupportTagline,
      icon: Icons.support_agent,
      accent: colorScheme.tertiary,
    ),
  ];
}
