import 'dart:async';

import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';

import '../features/common/common.dart';
import '../features/design/design.dart';
import '../features/my_seals/my_seals.dart';
import '../features/order/order.dart';
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
    this.listStoneListings = listStoneListingsWithDefaultApi,
    this.getStoneListingDetail = getStoneListingDetailWithDefaultApi,
    this.localSealDesignRepository,
    this.localOrderDraftRepository,
  });

  final Locale? locale;
  final HasSeenOnboardingResolver hasSeenOnboardingResolver;
  final OnboardingCompletionWriter markOnboardingSeen;
  final Duration splashMinimumDuration;
  final KanjiCandidatesGenerator generateKanjiCandidates;
  final SealDesignsGenerator generateSealDesigns;
  final StoneListingsLoader listStoneListings;
  final StoneListingDetailLoader getStoneListingDetail;
  final LocalSealDesignRepository? localSealDesignRepository;
  final LocalOrderDraftRepository? localOrderDraftRepository;

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
        listStoneListings: listStoneListings,
        getStoneListingDetail: getStoneListingDetail,
        localSealDesignRepository: localSealDesignRepository,
        localOrderDraftRepository: localOrderDraftRepository,
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
    required this.listStoneListings,
    required this.getStoneListingDetail,
    required this.localSealDesignRepository,
    required this.localOrderDraftRepository,
  });

  final HasSeenOnboardingResolver hasSeenOnboardingResolver;
  final OnboardingCompletionWriter markOnboardingSeen;
  final Duration splashMinimumDuration;
  final KanjiCandidatesGenerator generateKanjiCandidates;
  final SealDesignsGenerator generateSealDesigns;
  final StoneListingsLoader listStoneListings;
  final StoneListingDetailLoader getStoneListingDetail;
  final LocalSealDesignRepository? localSealDesignRepository;
  final LocalOrderDraftRepository? localOrderDraftRepository;

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
        listStoneListings: widget.listStoneListings,
        getStoneListingDetail: widget.getStoneListingDetail,
        localSealDesignRepository: widget.localSealDesignRepository,
        localOrderDraftRepository: widget.localOrderDraftRepository,
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
    this.listStoneListings = listStoneListingsWithDefaultApi,
    this.getStoneListingDetail = getStoneListingDetailWithDefaultApi,
    this.localSealDesignRepository,
    this.localOrderDraftRepository,
  });

  final KanjiCandidatesGenerator generateKanjiCandidates;
  final SealDesignsGenerator generateSealDesigns;
  final StoneListingsLoader listStoneListings;
  final StoneListingDetailLoader getStoneListingDetail;
  final LocalSealDesignRepository? localSealDesignRepository;
  final LocalOrderDraftRepository? localOrderDraftRepository;

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

class _StoneImageGallerySelection {
  const _StoneImageGallerySelection({
    required this.listing,
    required this.initialPhotoIndex,
  });

  final StoneListing listing;
  final int initialPhotoIndex;
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
  static const _orderReviewPage = PageEntry(
    key: 'CMB-001-order-combination-review',
    name: '/order/review',
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
  static const _mySealsDetailPageKey = 'MYS-003-seal-detail';
  static const _stoneDetailPageKey = 'STN-007-stone-detail';
  static const _stoneImageGalleryPageKey = 'STN-008-stone-image-gallery';

  late final LocalSealDesignRepository _localSealDesignRepository;
  late final LocalOrderDraftRepository _localOrderDraftRepository;
  var _localSealDesigns = const <LocalSealDesign>[];
  var _localSealDesignsLoaded = false;
  Object? _localSealDesignsLoadError;
  var _orderDraft = OrderDraft.empty();
  var _orderDraftHasLocalChanges = false;
  StoneListingsResult? _stoneListingsResult;
  var _stoneListingsLoaded = false;
  var _stoneListingsLoading = false;
  Object? _stoneListingsLoadError;
  String? _stoneListingsLocale;
  final _savingLocalSealKeys = <String>{};
  final _deletingLocalSealIds = <String>{};
  HankoAppTab? _requestedTab;
  var _pages = const <PageEntry>[_shellPage];

  @override
  void initState() {
    super.initState();
    _localSealDesignRepository =
        widget.localSealDesignRepository ?? InMemoryLocalSealDesignRepository();
    _localOrderDraftRepository =
        widget.localOrderDraftRepository ?? InMemoryLocalOrderDraftRepository();
    unawaited(_loadLocalSealDesigns());
    unawaited(_loadOrderDraft());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_stoneListingsLocale == locale) {
      return;
    }
    _stoneListingsLocale = locale;
    unawaited(_loadStoneListings(locale: locale));
  }

  @override
  Widget build(BuildContext context) {
    return DeclarativePagesNavigator(
      pages: _pages,
      buildPage: (context, page) {
        if (page.key == _orderReviewPage.key) {
          return _buildOrderReviewPage();
        }
        if (page.key == _settingsPage.key) {
          return _buildSettingsPage();
        }
        return _buildShellPage(context);
      },
      onPopTop: _closeTopPage,
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
            selectedTab: _requestedTab,
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
          child: SettingsScreen(onClose: _closeTopPage),
        ),
      ),
    );
  }

  Widget _buildOrderReviewPage() {
    return Scaffold(
      backgroundColor: HankoColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 432),
          child: OrderFlowEntryScreen(
            draft: _orderDraft,
            onBack: _closeTopPage,
            onChooseSeal: () => _showTabFromOrder(HankoAppTab.mySeals),
            onChooseStone: () => _showTabFromOrder(HankoAppTab.stones),
          ),
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
      HankoAppTab.mySeals => _buildMySealsPage(page, stack),
      HankoAppTab.stones => _buildStonesPage(page, stack),
    };
  }

  Widget _buildStonesPage(PageEntry page, HankoTabStackController stack) {
    final pageData = page.data;
    if (page.key == _stoneDetailPageKey && pageData is StoneListing) {
      return StoneDetailScreen(
        listing: pageData,
        locale: _stoneListingsLocale ?? _stoneListingsResult?.locale,
        loadStoneListing: widget.getStoneListingDetail,
        onOpenImageGallery: (listing, initialPhotoIndex) => stack.push(
          _stoneImageGalleryPage(
            listing: listing,
            initialPhotoIndex: initialPhotoIndex,
          ),
        ),
        isSelectedForOrder:
            _orderDraft.stoneSelection?.listingId == pageData.id,
        onSelectStone: _chooseStoneForOrder,
        onBack: stack.pop,
      );
    }
    if (page.key == _stoneImageGalleryPageKey &&
        pageData is _StoneImageGallerySelection) {
      return StoneImageGalleryScreen(
        listing: pageData.listing,
        initialPhotoIndex: pageData.initialPhotoIndex,
        onBack: stack.pop,
      );
    }

    return StonesHomeScreen(
      result: _stoneListingsResult,
      isLoading: !_stoneListingsLoaded || _stoneListingsLoading,
      loadError: _stoneListingsLoadError,
      onRetry: _retryStoneListings,
      onOpenStoneDetail: (listing) => stack.push(_stoneDetailPage(listing)),
      selectedStoneId: _orderDraft.stoneSelection?.listingId,
      onSelectStone: _chooseStoneForOrder,
    );
  }

  Widget _buildMySealsPage(PageEntry page, HankoTabStackController stack) {
    final pageData = page.data;
    if (page.key == _mySealsDetailPageKey && pageData is LocalSealDesign) {
      return SealDetailScreen(
        design: pageData,
        isSelectedForOrder:
            _orderDraft.sealSelection?.localSealDesignId == pageData.id,
        onChooseForOrder: _chooseLocalSealForOrder,
        onDelete: (design) => _deleteLocalSealDesign(design, stack),
        onBack: stack.pop,
      );
    }

    return MySealsHomeScreen(
      designs: _localSealDesigns,
      isLoading: !_localSealDesignsLoaded,
      loadError: _localSealDesignsLoadError,
      onStartDesigning: () => stack.selectTab(HankoAppTab.design),
      onExploreStones: () => stack.selectTab(HankoAppTab.stones),
      onChooseSeal: (design) => stack.push(_mySealsDetailPage(design)),
    );
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

  Future<void> _loadOrderDraft() async {
    try {
      final draft = await _localOrderDraftRepository.loadOrderDraft();
      if (!mounted) {
        return;
      }
      if (_orderDraftHasLocalChanges) {
        return;
      }
      setState(() => _orderDraft = draft);
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (_orderDraftHasLocalChanges) {
        return;
      }
      setState(() => _orderDraft = OrderDraft.empty());
    }
  }

  Future<void> _loadStoneListings({required String locale}) async {
    if (_stoneListingsLoading) {
      return;
    }
    setState(() {
      _stoneListingsLoading = true;
      _stoneListingsLoadError = null;
    });
    try {
      final result = await widget.listStoneListings(
        StoneListingsQuery(locale: locale, status: 'published'),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _stoneListingsResult = result;
        _stoneListingsLoaded = true;
        _stoneListingsLoading = false;
        _stoneListingsLoadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stoneListingsLoaded = true;
        _stoneListingsLoading = false;
        _stoneListingsLoadError = error;
      });
    }
  }

  void _retryStoneListings() {
    final locale =
        _stoneListingsLocale ?? Localizations.localeOf(context).languageCode;
    unawaited(_loadStoneListings(locale: locale));
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

  void _chooseLocalSealForOrder(LocalSealDesign design) {
    final nextDraft = _orderDraft.withSealSelection(
      _orderDraftSealSelectionFromLocalSealDesign(design),
    );
    unawaited(_applyOrderDraft(nextDraft));
    _openOrderReview();
  }

  void _chooseStoneForOrder(StoneListing listing) {
    if (!listing.isOrderable) {
      return;
    }
    final nextDraft = _orderDraft.withStoneSelection(
      _orderDraftStoneSelectionFromStoneListing(listing),
    );
    unawaited(_applyOrderDraft(nextDraft));
    _openOrderReview();
  }

  Future<void> _applyOrderDraft(OrderDraft draft) async {
    final nextDraft = OrderDraft(
      sealSelection: draft.sealSelection,
      stoneSelection: draft.stoneSelection,
      input: draft.input,
    );
    if (mounted) {
      setState(() {
        _orderDraft = nextDraft;
        _orderDraftHasLocalChanges = true;
      });
    }
    try {
      await _localOrderDraftRepository.saveOrderDraft(nextDraft);
    } catch (_) {
      // Keep the in-memory draft so tab-to-tab flow remains usable.
    }
  }

  Future<void> _deleteLocalSealDesign(
    LocalSealDesign design,
    HankoTabStackController stack,
  ) async {
    if (_deletingLocalSealIds.contains(design.id)) {
      return;
    }
    _deletingLocalSealIds.add(design.id);
    try {
      await _localSealDesignRepository.deleteLocalSealDesign(design.id);
    } catch (error) {
      if (!mounted) {
        _deletingLocalSealIds.remove(design.id);
        return;
      }
      setState(() {
        _localSealDesignsLoaded = true;
        _localSealDesignsLoadError = error;
      });
      _deletingLocalSealIds.remove(design.id);
      return;
    }
    _deletingLocalSealIds.remove(design.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _localSealDesigns = List.unmodifiable(
        _localSealDesigns.where((savedDesign) => savedDesign.id != design.id),
      );
      _localSealDesignsLoaded = true;
      _localSealDesignsLoadError = null;
    });
    if (_orderDraft.sealSelection?.localSealDesignId == design.id) {
      unawaited(_applyOrderDraft(_orderDraft.withoutSealSelection()));
    }
    stack.pop();
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

  PageEntry _mySealsDetailPage(LocalSealDesign design) {
    return PageEntry(
      key: _mySealsDetailPageKey,
      name: '/my-seals/detail',
      data: design,
    );
  }

  PageEntry _stoneDetailPage(StoneListing listing) {
    return PageEntry(
      key: _stoneDetailPageKey,
      name: '/stones/detail',
      data: listing,
    );
  }

  PageEntry _stoneImageGalleryPage({
    required StoneListing listing,
    required int initialPhotoIndex,
  }) {
    return PageEntry(
      key: _stoneImageGalleryPageKey,
      name: '/stones/detail/gallery',
      data: _StoneImageGallerySelection(
        listing: listing,
        initialPhotoIndex: initialPhotoIndex,
      ),
    );
  }

  void _openSettings() {
    if (_pages.last.key == _settingsPage.key) {
      return;
    }
    setState(() => _pages = const [_shellPage, _settingsPage]);
  }

  void _openOrderReview() {
    if (_pages.last.key == _orderReviewPage.key) {
      return;
    }
    setState(() => _pages = const [_shellPage, _orderReviewPage]);
  }

  void _showTabFromOrder(HankoAppTab tab) {
    setState(() {
      _requestedTab = tab;
      _pages = const [_shellPage];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedTab != tab) {
        return;
      }
      setState(() => _requestedTab = null);
    });
  }

  void _closeTopPage() {
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

OrderDraftSealSelection _orderDraftSealSelectionFromLocalSealDesign(
  LocalSealDesign design,
) {
  return OrderDraftSealSelection(
    localSealDesignId: design.id,
    selectedKanji: design.selectedKanji,
    reading: design.reading,
    shape: design.shape,
    style: design.style,
    strokeWeight: design.strokeWeight,
    balance: design.balance,
    aiGenerationId: design.aiGenerationId,
    aiVariantId: design.aiVariantId,
    previewImageStoragePath: design.previewImageStoragePath,
    previewImageDownloadUrl: design.previewImageDownloadUrl,
    localImagePath: design.localImagePath,
  );
}

OrderDraftStoneSelection _orderDraftStoneSelectionFromStoneListing(
  StoneListing listing,
) {
  return OrderDraftStoneSelection(
    listingId: listing.id,
    code: listing.code,
    materialKey: listing.materialKey,
    materialLabel: listing.materialLabel,
    sizeLabel: listing.sizeLabel,
    title: listing.title,
    price: listing.price,
    status: listing.status,
    isOrderable: listing.isOrderable,
    primaryPhotoUrl: _primaryStonePhotoUrl(listing.photos),
  );
}

String _primaryStonePhotoUrl(List<StoneListingPhoto> photos) {
  if (photos.isEmpty) {
    return '';
  }
  for (final photo in photos) {
    if (photo.isPrimary) {
      return photo.assetUrl;
    }
  }
  final sorted = [...photos]
    ..sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);
      return order == 0 ? left.assetId.compareTo(right.assetId) : order;
    });
  return sorted.first.assetUrl;
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
