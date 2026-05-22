import 'dart:async';

import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';

import '../features/common/common.dart';
import '../features/design/design.dart';
import '../features/my_seals/my_seals.dart';
import '../features/settings/settings.dart';
import '../features/stones/stones.dart';
import 'localization/app_localization.dart';
import 'navigation/app_navigation_shell.dart';
import 'theme/app_theme.dart';

class HankoApp extends StatelessWidget {
  const HankoApp({
    super.key,
    this.locale,
    this.hasSeenOnboardingResolver = _defaultHasSeenOnboardingResolver,
    this.markOnboardingSeen = _defaultMarkOnboardingSeen,
    this.splashMinimumDuration = const Duration(milliseconds: 700),
    this.generateKanjiCandidates = generateKanjiCandidatesWithDefaultApi,
    this.generateSealDesigns = generateSealDesignsWithDefaultApi,
    this.localSealDesignRepository,
  });

  final Locale? locale;
  final HasSeenOnboardingResolver hasSeenOnboardingResolver;
  final OnboardingCompletionWriter markOnboardingSeen;
  final Duration splashMinimumDuration;
  final KanjiCandidatesGenerator generateKanjiCandidates;
  final SealDesignsGenerator generateSealDesigns;
  final LocalSealDesignRepository? localSealDesignRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: HankoLocalizations.supportedLocales,
      localizationsDelegates: HankoLocalizations.localizationsDelegates,
      theme: HankoTheme.light(),
      home: _AppLaunchGate(
        hasSeenOnboardingResolver: hasSeenOnboardingResolver,
        markOnboardingSeen: markOnboardingSeen,
        splashMinimumDuration: splashMinimumDuration,
        generateKanjiCandidates: generateKanjiCandidates,
        generateSealDesigns: generateSealDesigns,
        localSealDesignRepository: localSealDesignRepository,
      ),
    );
  }
}

Future<bool> _defaultHasSeenOnboardingResolver() async {
  return const AppLaunchStore().hasSeenOnboarding();
}

Future<void> _defaultMarkOnboardingSeen() {
  return const AppLaunchStore().setHasSeenOnboarding(true);
}

enum _AppLaunchStage { splash, onboarding, shell }

class _AppLaunchGate extends StatefulWidget {
  const _AppLaunchGate({
    required this.hasSeenOnboardingResolver,
    required this.markOnboardingSeen,
    required this.splashMinimumDuration,
    required this.generateKanjiCandidates,
    required this.generateSealDesigns,
    required this.localSealDesignRepository,
  });

  final HasSeenOnboardingResolver hasSeenOnboardingResolver;
  final OnboardingCompletionWriter markOnboardingSeen;
  final Duration splashMinimumDuration;
  final KanjiCandidatesGenerator generateKanjiCandidates;
  final SealDesignsGenerator generateSealDesigns;
  final LocalSealDesignRepository? localSealDesignRepository;

  @override
  State<_AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<_AppLaunchGate> {
  var _stage = _AppLaunchStage.splash;

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _AppLaunchStage.splash => SplashScreen(
        hasSeenOnboardingResolver: widget.hasSeenOnboardingResolver,
        minimumDisplayDuration: widget.splashMinimumDuration,
        onLaunchResolved: _showLaunchDestination,
      ),
      _AppLaunchStage.onboarding => OnboardingScreen(
        onComplete: _completeOnboarding,
      ),
      _AppLaunchStage.shell => BottomNavigationShell(
        generateKanjiCandidates: widget.generateKanjiCandidates,
        generateSealDesigns: widget.generateSealDesigns,
        localSealDesignRepository: widget.localSealDesignRepository,
      ),
    };
  }

  Future<void> _completeOnboarding() async {
    await widget.markOnboardingSeen();
    if (!mounted) {
      return;
    }
    setState(() => _stage = _AppLaunchStage.shell);
  }

  void _showLaunchDestination(AppLaunchDestination destination) {
    setState(() {
      _stage = switch (destination) {
        AppLaunchDestination.onboarding => _AppLaunchStage.onboarding,
        AppLaunchDestination.shell => _AppLaunchStage.shell,
      };
    });
  }
}

class BottomNavigationShell extends StatefulWidget {
  const BottomNavigationShell({
    super.key,
    this.generateKanjiCandidates = generateKanjiCandidatesWithDefaultApi,
    this.generateSealDesigns = generateSealDesignsWithDefaultApi,
    this.localSealDesignRepository,
  });

  final KanjiCandidatesGenerator generateKanjiCandidates;
  final SealDesignsGenerator generateSealDesigns;
  final LocalSealDesignRepository? localSealDesignRepository;

  @override
  State<BottomNavigationShell> createState() => _BottomNavigationShellState();
}

class _KanjiSuggestionFailure {
  const _KanjiSuggestionFailure({required this.request});

  final KanjiCandidatesRequest request;
}

class _KanjiCandidateSelection {
  const _KanjiCandidateSelection({
    required this.result,
    required this.candidate,
  });

  final KanjiCandidatesResult result;
  final KanjiCandidate candidate;
}

class _SealGenerationFailure {
  const _SealGenerationFailure({required this.request});

  final SealGenerationRequest request;
}

class _SealPreviewSelection {
  const _SealPreviewSelection({required this.result, required this.variant});

  final SealGenerationResult result;
  final SealDesignVariant variant;
}

class _BottomNavigationShellState extends State<BottomNavigationShell> {
  static const _shellPage = PageEntry(
    key: 'COM-003-bottom-navigation-shell',
    name: '/shell',
  );
  static const _settingsPage = PageEntry(
    key: 'COM-004-settings',
    name: '/settings',
  );
  static const _navigationTabs = [
    HankoTabDefinition(
      tab: HankoAppTab.design,
      rootKey: 'COM-003-design-root',
      rootName: '/design',
    ),
    HankoTabDefinition(
      tab: HankoAppTab.mySeals,
      rootKey: 'COM-003-my-seals-root',
      rootName: '/my-seals',
    ),
    HankoTabDefinition(
      tab: HankoAppTab.stones,
      rootKey: 'COM-003-stones-root',
      rootName: '/stones',
    ),
  ];
  static const _designNameInputPage = PageEntry(
    key: 'DES-002-name-input',
    name: '/design/name',
  );
  static const _designKanjiLoadingPageKey = 'DES-003-kanji-suggestion-loading';
  static const _designKanjiSuggestionsPageKey = 'DES-004-kanji-suggestions';
  static const _designKanjiCandidateDetailPageKey =
      'DES-005-kanji-candidate-detail';
  static const _designSealStyleSelectionPageKey =
      'DES-006-seal-style-selection';
  static const _designSealGenerationLoadingPageKey =
      'DES-007-seal-generation-loading';
  static const _designSealVariantSelectionPageKey =
      'DES-008-seal-variant-selection';
  static const _designSealPreviewDetailPageKey = 'DES-009-seal-preview-detail';
  static const _designSealSaveConfirmationPageKey =
      'DES-010-seal-save-confirmation';
  static const _designKanjiErrorPageKey = 'DES-011-kanji-suggestion-error';
  static const _designSealGenerationErrorPageKey =
      'DES-012-seal-generation-error';
  static const _designUnsupportedKanjiPageKey =
      'DES-014-unsupported-kanji-result';
  static const _designSealGenerationLimitPageKey =
      'DES-015-seal-generation-limit';

  late final LocalSealDesignRepository _localSealDesignRepository;
  var _localSealDesigns = const <LocalSealDesign>[];
  var _localSealDesignsLoaded = false;
  Object? _localSealDesignsLoadError;
  final _savingLocalSealKeys = <String>{};
  var _pages = const <PageEntry>[_shellPage];

  @override
  void initState() {
    super.initState();
    _localSealDesignRepository =
        widget.localSealDesignRepository ?? InMemoryLocalSealDesignRepository();
    unawaited(_loadLocalSealDesigns());
  }

  @override
  Widget build(BuildContext context) {
    return DeclarativePagesNavigator(
      pages: _pages,
      buildPage: (context, page) {
        if (page.key == _settingsPage.key) {
          return _buildSettingsPage();
        }
        return _buildShellPage(context);
      },
      onPopTop: _closeSettings,
    );
  }

  Widget _buildShellPage(BuildContext context) {
    final l10n = context.l10n;
    final tabItems = [
      _TabItem(l10n.design, _TabIcon.design),
      _TabItem(l10n.mySeals, _TabIcon.mySeals),
      _TabItem(l10n.stones, _TabIcon.stones),
    ];

    return Scaffold(
      backgroundColor: HankoColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 432),
          child: HankoTabNavigationShell(
            tabs: _navigationTabs,
            buildPage: _buildTabPage,
            buildBottomNavigation: (context, selectedIndex, onSelected) {
              return _BottomTabs(
                selectedIndex: selectedIndex,
                tabs: tabItems,
                onSelected: onSelected,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPage() {
    return Scaffold(
      backgroundColor: HankoColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 432),
          child: SettingsScreen(onClose: _closeSettings),
        ),
      ),
    );
  }

  Widget _buildTabPage(
    BuildContext context,
    HankoAppTab tab,
    PageEntry page,
    HankoTabStackController stack,
  ) {
    return switch (tab) {
      HankoAppTab.design => _buildDesignPage(page, stack),
      HankoAppTab.mySeals => MySealsHomeScreen(
        designs: _localSealDesigns,
        isLoading: !_localSealDesignsLoaded,
        loadError: _localSealDesignsLoadError,
        onStartDesigning: () => stack.selectTab(HankoAppTab.design),
        onExploreStones: () => stack.selectTab(HankoAppTab.stones),
      ),
      HankoAppTab.stones => const StonesHomeScreen(),
    };
  }

  Widget _buildDesignPage(PageEntry page, HankoTabStackController stack) {
    final pageData = page.data;
    if (page.key == _designNameInputPage.key) {
      return NameInputScreen(
        onBack: stack.pop,
        onSubmit: (request) {
          stack.push(_kanjiLoadingPage(request));
        },
      );
    }

    if (page.key == _designKanjiLoadingPageKey &&
        pageData is KanjiCandidatesRequest) {
      return KanjiSuggestionLoadingScreen(
        request: pageData,
        generateCandidates: widget.generateKanjiCandidates,
        onLoaded: (result) {
          if (result.candidates.isEmpty) {
            stack.replaceTop(_unsupportedKanjiPage(pageData));
            return;
          }
          stack.replaceTop(_kanjiSuggestionsPage(result));
        },
        onError: (error) {
          stack.replaceTop(_kanjiSuggestionErrorPage(pageData));
        },
        onBack: stack.pop,
      );
    }

    if (page.key == _designKanjiSuggestionsPageKey &&
        pageData is KanjiCandidatesResult) {
      return KanjiSuggestionsScreen(
        result: pageData,
        onOpenCandidate: (candidate) {
          stack.push(_kanjiCandidateDetailPage(pageData, candidate));
        },
        onBack: stack.pop,
      );
    }

    if (page.key == _designKanjiCandidateDetailPageKey &&
        pageData is _KanjiCandidateSelection) {
      return KanjiCandidateDetailScreen(
        candidate: pageData.candidate,
        onSelected: (candidate) {
          stack.push(_sealStyleSelectionPage(pageData));
        },
        onBack: stack.pop,
      );
    }

    if (page.key == _designSealStyleSelectionPageKey &&
        pageData is _KanjiCandidateSelection) {
      return SealStyleSelectionScreen(
        candidate: pageData.candidate,
        onBack: stack.pop,
        onGenerate: (selection) {
          stack.push(
            _sealGenerationLoadingPage(
              SealGenerationRequest(
                inputName: pageData.result.realName,
                candidate: pageData.candidate,
                style: selection,
              ),
            ),
          );
        },
      );
    }

    if (page.key == _designSealGenerationLoadingPageKey &&
        pageData is SealGenerationRequest) {
      return SealGenerationLoadingScreen(
        request: pageData,
        generateSealDesigns: widget.generateSealDesigns,
        onGenerated: (result) {
          stack.replaceTop(_sealVariantSelectionPage(result));
        },
        onError: (error) {
          if (pageData.hasReachedLimit) {
            stack.replaceTop(_sealGenerationLimitPage(pageData));
            return;
          }
          stack.replaceTop(_sealGenerationErrorPage(pageData));
        },
        onBack: stack.pop,
      );
    }

    if (page.key == _designSealVariantSelectionPageKey &&
        pageData is SealGenerationResult) {
      return SealVariantSelectionScreen(
        result: pageData,
        onSelected: (variant) {
          stack.push(_sealPreviewDetailPage(pageData, variant));
        },
        onBack: stack.pop,
      );
    }

    if (page.key == _designSealPreviewDetailPageKey &&
        pageData is _SealPreviewSelection) {
      return SealPreviewDetailScreen(
        result: pageData.result,
        variant: pageData.variant,
        onSave: () {
          unawaited(
            _saveLocalSealDesign(
              result: pageData.result,
              variant: pageData.variant,
              stack: stack,
            ),
          );
        },
        onChooseStone: () => stack.selectTab(HankoAppTab.stones),
        onBack: stack.pop,
      );
    }

    if (page.key == _designSealSaveConfirmationPageKey &&
        pageData is _SealPreviewSelection) {
      return SealSaveConfirmationScreen(
        result: pageData.result,
        variant: pageData.variant,
        onOpenMySeals: () => stack.selectTab(HankoAppTab.mySeals),
        onChooseStone: () => stack.selectTab(HankoAppTab.stones),
        onCreateAnother: stack.popToRoot,
        onBack: stack.pop,
      );
    }

    if (page.key == _designKanjiErrorPageKey &&
        pageData is _KanjiSuggestionFailure) {
      return KanjiSuggestionErrorScreen(
        request: pageData.request,
        onRetry: () => stack.replaceTop(_kanjiLoadingPage(pageData.request)),
        onBack: stack.pop,
      );
    }

    if (page.key == _designSealGenerationErrorPageKey &&
        pageData is _SealGenerationFailure) {
      return SealGenerationErrorScreen(
        request: pageData.request,
        onRetry: () {
          stack.replaceTop(
            _sealGenerationLoadingPage(pageData.request.nextAttempt()),
          );
        },
        onBack: stack.pop,
      );
    }

    if (page.key == _designUnsupportedKanjiPageKey &&
        pageData is KanjiCandidatesRequest) {
      return UnsupportedKanjiResultScreen(
        request: pageData,
        onRetry: () => stack.replaceTop(_kanjiLoadingPage(pageData)),
        onEditName: stack.pop,
        onBack: stack.pop,
      );
    }

    if (page.key == _designSealGenerationLimitPageKey &&
        pageData is SealGenerationRequest) {
      return SealGenerationLimitScreen(
        request: pageData,
        onAdjustStyle: stack.pop,
        onBack: stack.pop,
      );
    }

    return DesignHomeScreen(
      onOpenSettings: _openSettings,
      onStartDesign: () => stack.push(_designNameInputPage),
    );
  }

  Future<void> _loadLocalSealDesigns() async {
    try {
      final designs = await _localSealDesignRepository.listLocalSealDesigns();
      if (!mounted) {
        return;
      }
      setState(() {
        _localSealDesigns = List.unmodifiable(designs);
        _localSealDesignsLoaded = true;
        _localSealDesignsLoadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _localSealDesignsLoaded = true;
        _localSealDesignsLoadError = error;
      });
    }
  }

  Future<void> _saveLocalSealDesign({
    required SealGenerationResult result,
    required SealDesignVariant variant,
    required HankoTabStackController stack,
  }) async {
    final saveKey = '${result.requestId}:${variant.id}';
    if (_savingLocalSealKeys.contains(saveKey)) {
      return;
    }
    _savingLocalSealKeys.add(saveKey);
    final design = _localSealDesignFromSelection(result, variant);
    try {
      await _localSealDesignRepository.saveLocalSealDesign(design);
    } catch (error) {
      if (!mounted) {
        _savingLocalSealKeys.remove(saveKey);
        return;
      }
      setState(() {
        _localSealDesignsLoaded = true;
        _localSealDesignsLoadError = error;
      });
      _savingLocalSealKeys.remove(saveKey);
      return;
    }
    _savingLocalSealKeys.remove(saveKey);
    if (!mounted) {
      return;
    }

    setState(() {
      final remaining = _localSealDesigns
          .where((savedDesign) => savedDesign.id != design.id)
          .toList(growable: false);
      _localSealDesigns = List.unmodifiable([design, ...remaining]);
      _localSealDesignsLoaded = true;
      _localSealDesignsLoadError = null;
    });
    stack.push(_sealSaveConfirmationPage(result, variant));
  }

  PageEntry _kanjiLoadingPage(KanjiCandidatesRequest request) {
    return PageEntry(
      key: _designKanjiLoadingPageKey,
      name: '/design/kanji/loading',
      data: request,
    );
  }

  PageEntry _kanjiSuggestionsPage(KanjiCandidatesResult result) {
    return PageEntry(
      key: _designKanjiSuggestionsPageKey,
      name: '/design/kanji/suggestions',
      data: result,
    );
  }

  PageEntry _kanjiCandidateDetailPage(
    KanjiCandidatesResult result,
    KanjiCandidate candidate,
  ) {
    return PageEntry(
      key: _designKanjiCandidateDetailPageKey,
      name: '/design/kanji/candidate',
      data: _KanjiCandidateSelection(result: result, candidate: candidate),
    );
  }

  PageEntry _sealStyleSelectionPage(_KanjiCandidateSelection selection) {
    return PageEntry(
      key: _designSealStyleSelectionPageKey,
      name: '/design/seal/style',
      data: selection,
    );
  }

  PageEntry _sealGenerationLoadingPage(SealGenerationRequest request) {
    return PageEntry(
      key: _designSealGenerationLoadingPageKey,
      name: '/design/seal/generating',
      data: request,
    );
  }

  PageEntry _sealVariantSelectionPage(SealGenerationResult result) {
    return PageEntry(
      key: _designSealVariantSelectionPageKey,
      name: '/design/seal/variants',
      data: result,
    );
  }

  PageEntry _sealPreviewDetailPage(
    SealGenerationResult result,
    SealDesignVariant variant,
  ) {
    return PageEntry(
      key: _designSealPreviewDetailPageKey,
      name: '/design/seal/preview',
      data: _SealPreviewSelection(result: result, variant: variant),
    );
  }

  PageEntry _sealSaveConfirmationPage(
    SealGenerationResult result,
    SealDesignVariant variant,
  ) {
    return PageEntry(
      key: _designSealSaveConfirmationPageKey,
      name: '/design/seal/saved',
      data: _SealPreviewSelection(result: result, variant: variant),
    );
  }

  PageEntry _kanjiSuggestionErrorPage(KanjiCandidatesRequest request) {
    return PageEntry(
      key: _designKanjiErrorPageKey,
      name: '/design/kanji/error',
      data: _KanjiSuggestionFailure(request: request),
    );
  }

  PageEntry _sealGenerationErrorPage(SealGenerationRequest request) {
    return PageEntry(
      key: _designSealGenerationErrorPageKey,
      name: '/design/seal/error',
      data: _SealGenerationFailure(request: request),
    );
  }

  PageEntry _unsupportedKanjiPage(KanjiCandidatesRequest request) {
    return PageEntry(
      key: _designUnsupportedKanjiPageKey,
      name: '/design/kanji/empty',
      data: request,
    );
  }

  PageEntry _sealGenerationLimitPage(SealGenerationRequest request) {
    return PageEntry(
      key: _designSealGenerationLimitPageKey,
      name: '/design/seal/limit',
      data: request,
    );
  }

  void _openSettings() {
    if (_pages.last.key == _settingsPage.key) {
      return;
    }
    setState(() => _pages = const [_shellPage, _settingsPage]);
  }

  void _closeSettings() {
    if (_pages.length <= 1) {
      return;
    }
    setState(() => _pages = const [_shellPage]);
  }
}

LocalSealDesign _localSealDesignFromSelection(
  SealGenerationResult result,
  SealDesignVariant variant,
) {
  final now = DateTime.now();
  final candidate = result.request.candidate;
  final style = result.request.style;

  return LocalSealDesign(
    id: _localSealDesignId(result.requestId, variant.id, now),
    inputName: result.request.inputName,
    selectedKanji: candidate.kanji,
    reading: candidate.reading,
    meaning: candidate.meaning,
    impression: candidate.impression,
    characterCount: candidate.characterCount ?? candidate.kanji.runes.length,
    strokeComplexity: candidate.strokeComplexity,
    engravingSuitability: candidate.engravingSuitability,
    shape: style.shape.apiValue,
    style: style.style.apiValue,
    strokeWeight: style.strokeWeight.apiValue,
    balance: style.balance.apiValue,
    aiGenerationId: result.requestId,
    aiVariantId: variant.id,
    previewImageStoragePath: variant.storagePath,
    previewImageDownloadUrl: variant.downloadUrl,
    localImagePath: '',
    isFavorite: false,
    createdAt: now,
    updatedAt: now,
  );
}

String _localSealDesignId(String requestId, String variantId, DateTime now) {
  final rawId = 'local_${requestId}_${variantId}_${now.microsecondsSinceEpoch}';
  return rawId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.selectedIndex,
    required this.tabs,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: HankoColors.background,
              border: Border(
                top: BorderSide(color: HankoColors.navBorder, width: 0.7),
              ),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  left: tabWidth * selectedIndex + (tabWidth / 2) - 25,
                  width: 50,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: HankoColors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var index = 0; index < tabs.length; index++)
                      Expanded(
                        child: _BottomTabButton(
                          item: tabs[index],
                          isSelected: selectedIndex == index,
                          onTap: () => onSelected(index),
                        ),
                      ),
                  ],
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(child: _HomeIndicator()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _TabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? HankoColors.red : HankoColors.ink;
    return InkResponse(
      onTap: onTap,
      containedInkWell: true,
      highlightShape: BoxShape.rectangle,
      child: Padding(
        padding: const EdgeInsets.only(top: 21, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size.square(31),
              painter: _TabIconPainter(item.icon, color),
            ),
            const SizedBox(height: 7),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _TabIconPainter extends CustomPainter {
  const _TabIconPainter(this.icon, this.color);

  final _TabIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (icon) {
      case _TabIcon.design:
        final stem = Path()
          ..moveTo(size.width * 0.61, size.height * 0.04)
          ..lineTo(size.width * 0.32, size.height * 0.61);
        canvas.drawPath(stem, paint);
        final brush = Path()
          ..moveTo(size.width * 0.65, size.height * 0.03)
          ..quadraticBezierTo(
            size.width * 0.79,
            size.height * 0.16,
            size.width * 0.68,
            size.height * 0.30,
          )
          ..lineTo(size.width * 0.42, size.height * 0.66)
          ..quadraticBezierTo(
            size.width * 0.33,
            size.height * 0.59,
            size.width * 0.31,
            size.height * 0.54,
          )
          ..lineTo(size.width * 0.56, size.height * 0.20)
          ..quadraticBezierTo(
            size.width * 0.59,
            size.height * 0.10,
            size.width * 0.65,
            size.height * 0.03,
          );
        canvas.drawPath(brush, paint);
        final plate = Path()
          ..moveTo(size.width * 0.18, size.height * 0.61)
          ..quadraticBezierTo(
            size.width * 0.34,
            size.height * 0.80,
            size.width * 0.17,
            size.height * 0.84,
          )
          ..quadraticBezierTo(
            size.width * 0.42,
            size.height * 1.02,
            size.width * 0.72,
            size.height * 0.76,
          );
        canvas.drawPath(plate, paint);
        canvas.drawOval(
          Rect.fromLTWH(
            size.width * 0.03,
            size.height * 0.69,
            size.width * 0.65,
            size.height * 0.25,
          ),
          paint,
        );
        break;
      case _TabIcon.mySeals:
        final shield = Path()
          ..moveTo(size.width * 0.50, size.height * 0.07)
          ..lineTo(size.width * 0.84, size.height * 0.20)
          ..lineTo(size.width * 0.79, size.height * 0.61)
          ..quadraticBezierTo(
            size.width * 0.74,
            size.height * 0.80,
            size.width * 0.50,
            size.height * 0.93,
          )
          ..quadraticBezierTo(
            size.width * 0.26,
            size.height * 0.80,
            size.width * 0.21,
            size.height * 0.61,
          )
          ..lineTo(size.width * 0.16, size.height * 0.20)
          ..close();
        canvas.drawPath(shield, paint);
        canvas.drawCircle(
          Offset(size.width * 0.50, size.height * 0.51),
          size.width * 0.045,
          fillPaint,
        );
        final sparkle = Path()
          ..moveTo(size.width * 0.50, size.height * 0.34)
          ..lineTo(size.width * 0.54, size.height * 0.47)
          ..lineTo(size.width * 0.67, size.height * 0.51)
          ..lineTo(size.width * 0.54, size.height * 0.55)
          ..lineTo(size.width * 0.50, size.height * 0.68)
          ..lineTo(size.width * 0.46, size.height * 0.55)
          ..lineTo(size.width * 0.33, size.height * 0.51)
          ..lineTo(size.width * 0.46, size.height * 0.47)
          ..close();
        canvas.drawPath(sparkle, fillPaint);
        break;
      case _TabIcon.stones:
        final path = Path()
          ..moveTo(size.width * 0.50, size.height * 0.94)
          ..lineTo(size.width * 0.09, size.height * 0.35)
          ..lineTo(size.width * 0.27, size.height * 0.12)
          ..lineTo(size.width * 0.73, size.height * 0.12)
          ..lineTo(size.width * 0.91, size.height * 0.35)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(size.width * 0.09, size.height * 0.35),
          Offset(size.width * 0.91, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.27, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.94),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.73, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.94),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.40, size.height * 0.12),
          Offset(size.width * 0.31, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.60, size.height * 0.12),
          Offset(size.width * 0.69, size.height * 0.35),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TabIconPainter oldDelegate) {
    return oldDelegate.icon != icon || oldDelegate.color != color;
  }
}

class _TabItem {
  const _TabItem(this.label, this.icon);

  final String label;
  final _TabIcon icon;
}

enum _TabIcon { design, mySeals, stones }
