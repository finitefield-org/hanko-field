import 'dart:math' as math;

import 'package:app/features/onboarding/application/onboarding_tutorial_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OnboardingTutorialOutcome { completed, skipped }

class OnboardingTutorialScreen extends ConsumerStatefulWidget {
  const OnboardingTutorialScreen({super.key});

  @override
  ConsumerState<OnboardingTutorialScreen> createState() =>
      _OnboardingTutorialScreenState();
}

class _OnboardingTutorialScreenState
    extends ConsumerState<OnboardingTutorialScreen> {
  late final PageController _pageController;
  late List<_OnboardingSlide> _slides;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final localizations = AppLocalizations.of(context);
    _slides = [
      _OnboardingSlide(
        icon: Icons.auto_graph_rounded,
        title: localizations.onboardingSlideCraftTitle,
        description: localizations.onboardingSlideCraftBody,
      ),
      _OnboardingSlide(
        icon: Icons.handshake_outlined,
        title: localizations.onboardingSlideSupportTitle,
        description: localizations.onboardingSlideSupportBody,
      ),
      _OnboardingSlide(
        icon: Icons.security_outlined,
        title: localizations.onboardingSlideTrustTitle,
        description: localizations.onboardingSlideTrustBody,
      ),
    ];
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(onboardingTutorialControllerProvider.notifier)
          .setCurrentPage(0, totalSteps: _slides.length, force: true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(onboardingTutorialControllerProvider);
    final controller = ref.read(onboardingTutorialControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);
    final totalSteps = _slides.length;
    final isLastPage = state.currentPage >= totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        title: Text(localizations.onboardingAppBarTitle),
        leading: IconButton(
          onPressed: state.isSaving
              ? null
              : () {
                  if (_pageController.hasClients &&
                      _pageController.page != null &&
                      _pageController.page! > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: state.isSaving || isLastPage
                ? null
                : () {
                    _handleFinish(
                      controller,
                      totalSteps: totalSteps,
                      skipped: true,
                    );
                  },
            child: Text(localizations.onboardingSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: state.isSaving
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (index) =>
                      controller.setCurrentPage(index, totalSteps: totalSteps),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return _OnboardingSlideCard(slide: _slides[index]);
                  },
                ),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: math.max(0.0, (state.currentPage + 1) / totalSteps),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.isSaving
                          ? null
                          : state.currentPage == 0
                          ? () {
                              _handleFinish(
                                controller,
                                totalSteps: totalSteps,
                                skipped: true,
                              );
                            }
                          : () {
                              if (_pageController.hasClients) {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                      child: Text(
                        state.currentPage == 0
                            ? localizations.onboardingSkip
                            : localizations.onboardingBack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: state.isSaving
                          ? null
                          : () {
                              if (isLastPage) {
                                _handleFinish(
                                  controller,
                                  totalSteps: totalSteps,
                                  skipped: false,
                                );
                              } else if (_pageController.hasClients) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                      child: Text(
                        isLastPage
                            ? localizations.onboardingGetStarted
                            : localizations.onboardingNext,
                      ),
                    ),
                  ),
                ],
              ),
              if (state.isSaving) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 8),
              Text(
                localizations.onboardingProgressLabel(
                  state.currentPage + 1,
                  totalSteps,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFinish(
    OnboardingTutorialController controller, {
    required int totalSteps,
    required bool skipped,
  }) async {
    try {
      await controller.completeTutorial(
        totalSteps: totalSteps,
        skipped: skipped,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        skipped
            ? OnboardingTutorialOutcome.skipped
            : OnboardingTutorialOutcome.completed,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _OnboardingSlideCard extends StatelessWidget {
  const _OnboardingSlideCard({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  slide.icon,
                  size: 64,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                slide.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                slide.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
