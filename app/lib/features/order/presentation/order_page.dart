import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/fonts/app_fonts.dart';
import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/theme/hf_theme.dart';
import '../../../app/widgets/app_site_chrome.dart';
import '../data/order_draft_storage.dart';
import '../domain/order_models.dart';
import 'order_view_model.dart';

class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBackToTop,
    required this.onOpenAbout,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
    required this.onOpenPaymentSuccess,
    required this.onOpenPaymentFailure,
    required this.showConfirmationLinks,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBackToTop;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;
  final void Function(String? sessionId, String? orderId) onOpenPaymentSuccess;
  final ValueChanged<String?> onOpenPaymentFailure;
  final bool showConfirmationLinks;

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  late final TextEditingController _sealLine1Controller;
  late final TextEditingController _sealLine2Controller;
  late final ScrollController _pageScrollController;
  bool _syncingSealControllers = false;
  bool _initializedFromState = false;
  bool _bootstrapped = false;
  bool _showSavedSealComparison = false;
  final Set<String> _selectedSavedSealDesignIds = <String>{};
  ProviderSubscription<OrderScreenState>? _orderStateSubscription;
  String _lastAutoOpenedCheckoutToken = '';

  @override
  void initState() {
    super.initState();
    _sealLine1Controller = TextEditingController();
    _sealLine2Controller = TextEditingController();
    _pageScrollController = ScrollController();

    _sealLine1Controller.addListener(() {
      if (_syncingSealControllers) {
        return;
      }
      ref.invoke(orderViewModel.updateSealLine1(_sealLine1Controller.text));
    });
    _sealLine2Controller.addListener(() {
      if (_syncingSealControllers) {
        return;
      }
      ref.invoke(orderViewModel.updateSealLine2(_sealLine2Controller.text));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final draftStorage = ref.read(orderDraftStorageProvider);

    _orderStateSubscription ??= ref.listenManual<OrderScreenState>(
      orderViewModel,
      (previous, next) {
        final previousDraft = previous == null ? '' : _draftJson(previous);
        final nextDraft = _draftJson(next);
        if (previousDraft != nextDraft) {
          unawaited(draftStorage.save(_draftFromState(next)));
        }

        final validSavedDesignIds = next.savedSealDesigns
            .map((design) => design.id)
            .toSet();
        final selectedCountBefore = _selectedSavedSealDesignIds.length;
        _selectedSavedSealDesignIds.removeWhere(
          (id) => !validSavedDesignIds.contains(id),
        );
        final comparisonWasVisible = _showSavedSealComparison;
        if (_showSavedSealComparison &&
            _selectedSavedSealDesignIds.length < 2) {
          _showSavedSealComparison = false;
        }
        if (mounted &&
            (selectedCountBefore != _selectedSavedSealDesignIds.length ||
                comparisonWasVisible != _showSavedSealComparison)) {
          setState(() {});
        }

        final nextResult = next.purchaseResult;
        if (nextResult == null) {
          return;
        }

        final checkoutUrl = nextResult.checkoutUrl.trim();
        if (checkoutUrl.isEmpty) {
          return;
        }

        final previousToken = _checkoutToken(previous?.purchaseResult);
        final nextToken = _checkoutToken(nextResult);
        if (nextToken.isEmpty || nextToken == previousToken) {
          return;
        }
        if (nextToken == _lastAutoOpenedCheckoutToken) {
          return;
        }

        _lastAutoOpenedCheckoutToken = nextToken;
        unawaited(_openCheckoutUrl(checkoutUrl));
      },
    );

    if (!_bootstrapped) {
      _bootstrapped = true;
      ref.invoke(orderViewModel.initialize());
    }

    if (_initializedFromState) {
      return;
    }

    final state = ref.read(orderViewModel);
    _syncingSealControllers = true;
    _sealLine1Controller.text = state.sealLine1;
    _sealLine2Controller.text = state.sealLine2;
    _syncingSealControllers = false;
    _initializedFromState = true;
  }

  @override
  void dispose() {
    _orderStateSubscription?.close();
    _pageScrollController.dispose();
    _sealLine1Controller.dispose();
    _sealLine2Controller.dispose();
    super.dispose();
  }

  void _syncSealControllers(OrderScreenState state) {
    if (_sealLine1Controller.text == state.sealLine1 &&
        _sealLine2Controller.text == state.sealLine2) {
      return;
    }

    _syncingSealControllers = true;
    if (_sealLine1Controller.text != state.sealLine1) {
      _sealLine1Controller.value = TextEditingValue(
        text: state.sealLine1,
        selection: TextSelection.collapsed(offset: state.sealLine1.length),
      );
    }
    if (_sealLine2Controller.text != state.sealLine2) {
      _sealLine2Controller.value = TextEditingValue(
        text: state.sealLine2,
        selection: TextSelection.collapsed(offset: state.sealLine2.length),
      );
    }
    _syncingSealControllers = false;
  }

  Future<void> _openCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedUiText(
              widget.locale.code,
              ja: 'Checkout URL が不正です。',
              en: 'The checkout URL is invalid.',
            ),
          ),
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedUiText(
              widget.locale.code,
              ja: 'Checkout URL を開けませんでした。',
              en: 'Could not open the checkout URL.',
            ),
          ),
        ),
      );
    }
  }

  String _checkoutToken(PurchaseResultData? result) {
    if (result == null) {
      return '';
    }

    final sessionId = result.checkoutSessionId.trim();
    if (sessionId.isNotEmpty) {
      return sessionId;
    }

    return result.checkoutUrl.trim();
  }

  OrderDraftData _draftFromState(OrderScreenState state) {
    return OrderDraftData(
      stepValue: state.step.value,
      sealLine1: state.sealLine1,
      sealLine2: state.sealLine2,
      kanjiStyleCode: state.kanjiStyle.code,
      selectedFontKey: state.selectedFontKey,
      shapeCode: state.shape.code,
      selectedStoneListingKey: state.selectedStoneListingKey,
      selectedColorFamily: state.selectedColorFamily,
      selectedPatternPrimary: state.selectedPatternPrimary,
      selectedCountryCode: state.selectedCountryCode,
      realName: state.realName,
      candidateGenderCode: state.candidateGender.code,
      recipientName: state.recipientName,
      email: state.email,
      phone: state.phone,
      postalCode: state.postalCode,
      stateName: state.stateName,
      city: state.city,
      addressLine1: state.addressLine1,
      addressLine2: state.addressLine2,
      termsAgreed: state.termsAgreed,
    );
  }

  String _draftJson(OrderScreenState state) {
    return jsonEncode(_draftFromState(state).toJson());
  }

  void _scrollPageToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageScrollController.hasClients) {
        return;
      }
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _toggleSavedSealDesignSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedSavedSealDesignIds.add(id);
      } else {
        _selectedSavedSealDesignIds.remove(id);
      }
    });
  }

  void _clearSavedSealDesignSelection() {
    setState(() {
      _selectedSavedSealDesignIds.clear();
      _showSavedSealComparison = false;
    });
  }

  void _openSavedSealComparison() {
    if (_selectedSavedSealDesignIds.length < 2) {
      return;
    }
    setState(() {
      _showSavedSealComparison = true;
    });
    _scrollPageToTop();
  }

  void _closeSavedSealComparison() {
    setState(() {
      _showSavedSealComparison = false;
    });
    _scrollPageToTop();
  }

  void _applySavedSealDesign(String id) {
    ref.invoke(orderViewModel.applySavedSealDesign(id));
    setState(() {
      _showSavedSealComparison = false;
    });
    _scrollPageToTop();
  }

  void _continueWithSavedSealDesign(String id) {
    ref.invoke(orderViewModel.continueWithSavedSealDesign(id));
    setState(() {
      _showSavedSealComparison = false;
    });
    _scrollPageToTop();
  }

  void _setSavedSealDesignFavorite(String id, bool isFavorite) {
    ref.invoke(orderViewModel.setSavedSealDesignFavorite(id, isFavorite));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderViewModel);
    _syncSealControllers(state);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6),
      body: SafeArea(
        child: Column(
          children: [
            AppSiteHeader(
              locale: widget.locale,
              onSelectLocale: widget.onSelectLocale,
              onBrandTap: widget.onBackToTop,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _pageScrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1152),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DesignLead(locale: state.locale),
                              const SizedBox(height: 48),
                              _buildMainPanel(state),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 56),
                    AppSiteFooter(
                      locale: widget.locale,
                      onOpenAbout: widget.onOpenAbout,
                      onOpenLegalNotice: widget.onOpenLegalNotice,
                      onOpenTerms: widget.onOpenTerms,
                      onBrandTap: widget.onBackToTop,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel(OrderScreenState state) {
    final designState = state.hasCatalog
        ? state
        : state.copyWith(step: OrderStep.design);

    if (_showSavedSealComparison) {
      return _SavedSealComparisonScreen(
        locale: designState.locale,
        state: designState,
        selectedIds: _selectedSavedSealDesignIds,
        onBack: _closeSavedSealComparison,
        onClearSelection: _clearSavedSealDesignSelection,
        onApply: _applySavedSealDesign,
        onContinue: _continueWithSavedSealDesign,
        onToggleFavorite: _setSavedSealDesignFavorite,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTrack(step: designState.step, locale: designState.locale),
        const SizedBox(height: 24),
        if (state.isLoadingCatalog && !state.hasCatalog)
          _CatalogLoadingPanel(locale: state.locale)
        else if (!state.hasCatalog)
          _CatalogErrorPanel(
            locale: state.locale,
            message: state.catalogError.isEmpty
                ? localizedUiText(
                    state.locale,
                    ja: 'カタログを取得できませんでした。',
                    en: 'Could not load the catalog.',
                  )
                : state.catalogError,
            onRetry: () => ref.invoke(orderViewModel.initialize()),
          )
        else if (state.catalogError.isNotEmpty)
          _CatalogInlineError(message: state.catalogError),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildStepPanel(designState),
        ),
      ],
    );
  }

  Widget _buildStepPanel(OrderScreenState state) {
    return switch (state.step) {
      OrderStep.design => _DesignStep(
        key: const ValueKey('design_step'),
        locale: state.locale,
        state: state,
        sealLine1Controller: _sealLine1Controller,
        sealLine2Controller: _sealLine2Controller,
        onToggleWritingMode: () =>
            ref.invoke(orderViewModel.toggleWritingMode()),
        onStyleChanged: (style) =>
            ref.invoke(orderViewModel.selectKanjiStyle(style)),
        onSelectFont: (fontKey) =>
            ref.invoke(orderViewModel.selectFont(fontKey)),
        onSelectShape: (shape) => ref.invoke(orderViewModel.selectShape(shape)),
        onRealNameChanged: (value) =>
            ref.invoke(orderViewModel.updateRealName(value)),
        onGenderChanged: (gender) =>
            ref.invoke(orderViewModel.selectCandidateGender(gender)),
        onGenerateSuggestions: () =>
            ref.invoke(orderViewModel.generateSuggestions()),
        onSelectSuggestion: (index) =>
            ref.invoke(orderViewModel.selectSuggestion(index)),
        onSaveCurrentSealDesign: () =>
            ref.invoke(orderViewModel.saveCurrentSealDesign()),
        onApplySavedSealDesign: _applySavedSealDesign,
        onContinueWithSavedSealDesign: _continueWithSavedSealDesign,
        selectedSavedSealDesignIds: _selectedSavedSealDesignIds,
        onToggleSavedSealDesignSelection: _toggleSavedSealDesignSelection,
        onClearSavedSealDesignSelection: _clearSavedSealDesignSelection,
        onCompareSavedSealDesigns: _openSavedSealComparison,
        onToggleSavedSealDesignFavorite: _setSavedSealDesignFavorite,
        onDeleteSavedSealDesign: (id) =>
            ref.invoke(orderViewModel.deleteSavedSealDesign(id)),
        onNext: () => ref.invoke(orderViewModel.nextStep()),
      ),
      OrderStep.listing => _StoneListingStep(
        key: const ValueKey('listing_step'),
        locale: state.locale,
        state: state,
        onSelectColorFilter: (value) =>
            ref.invoke(orderViewModel.selectColorFilter(value)),
        onSelectPatternFilter: (value) =>
            ref.invoke(orderViewModel.selectPatternFilter(value)),
        onClearMaterialFilters: () =>
            ref.invoke(orderViewModel.clearMaterialFilters()),
        onSelectStoneListing: (key) =>
            ref.invoke(orderViewModel.selectStoneListing(key)),
        onPrev: () => ref.invoke(orderViewModel.prevStep()),
        onNext: () => ref.invoke(orderViewModel.nextStep()),
      ),
      OrderStep.purchase => _PurchaseStep(
        key: const ValueKey('purchase_step'),
        locale: state.locale,
        state: state,
        onPrev: () => ref.invoke(orderViewModel.prevStep()),
        onCountryChanged: (code) =>
            ref.invoke(orderViewModel.selectCountry(code)),
        onRecipientNameChanged: (value) =>
            ref.invoke(orderViewModel.updateRecipientName(value)),
        onEmailChanged: (value) =>
            ref.invoke(orderViewModel.updateEmail(value)),
        onPhoneChanged: (value) =>
            ref.invoke(orderViewModel.updatePhone(value)),
        onPostalCodeChanged: (value) =>
            ref.invoke(orderViewModel.updatePostalCode(value)),
        onStateChanged: (value) =>
            ref.invoke(orderViewModel.updateStateName(value)),
        onCityChanged: (value) => ref.invoke(orderViewModel.updateCity(value)),
        onAddress1Changed: (value) =>
            ref.invoke(orderViewModel.updateAddressLine1(value)),
        onAddress2Changed: (value) =>
            ref.invoke(orderViewModel.updateAddressLine2(value)),
        onTermsChanged: (checked) =>
            ref.invoke(orderViewModel.setTermsAgreed(checked)),
        onSubmit: () => ref.invoke(orderViewModel.submitPurchase()),
        onOpenTerms: widget.onOpenTerms,
        onOpenPaymentSuccess: widget.onOpenPaymentSuccess,
        onOpenPaymentFailure: widget.onOpenPaymentFailure,
        showConfirmationLinks: widget.showConfirmationLinks,
      ),
    };
  }
}

class _CatalogLoadingPanel extends StatelessWidget {
  const _CatalogLoadingPanel({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HfPalette.line),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              localizedUiText(
                locale,
                ja: 'カタログを読み込み中です。印影テキストとプレビューは先に編集できます。',
                en: 'Loading catalog. You can start editing the seal text and preview now.',
              ),
              style: const TextStyle(fontSize: 13, color: HfPalette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogErrorPanel extends StatelessWidget {
  const _CatalogErrorPanel({
    required this.locale,
    required this.message,
    required this.onRetry,
  });

  final String locale;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1D1CE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: Color(0xFF8F2219)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF8F2219),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(
                    localizedUiText(locale, ja: '再読み込み', en: 'Retry'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogInlineError extends StatelessWidget {
  const _CatalogInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1D1CE)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF8F2219), fontSize: 13),
      ),
    );
  }
}

class _DesignLead extends StatelessWidget {
  const _DesignLead({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final tagline = localizedUiText(
      locale,
      ja: 'あなただけの宝石印鑑をデザイン。',
      en: 'A gemstone seal made just for you.',
    );
    final intro = localizedUiText(
      locale,
      ja: '印影、出品個体、お届け先を順に選んで、そのまま購入まで進めます。',
      en: 'Choose the seal text, listing, and shipping details, then continue to checkout.',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 640;
        final titleSize = isCompact ? 34.0 : 46.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tagline,
              style: AppFonts.notoSerifJp(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: 0.02,
                color: HfPalette.ink,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: Text(
                intro,
                style: AppFonts.manrope(
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.w400,
                  height: 1.8,
                  color: HfPalette.muted,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepTrack extends StatelessWidget {
  const _StepTrack({required this.step, required this.locale});

  final OrderStep step;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final steps = OrderStep.values;
        final isCompact = constraints.maxWidth < 720;

        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: HfPalette.line),
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < steps.length; index++) ...[
                        _StepTrackItem(
                          step: steps[index],
                          activeStep: step,
                          locale: locale,
                          isCompact: true,
                          isLast: index == steps.length - 1,
                        ),
                        if (index != steps.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: HfPalette.line,
                          ),
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < steps.length; index++)
                        Expanded(
                          child: _StepTrackItem(
                            step: steps[index],
                            activeStep: step,
                            locale: locale,
                            isCompact: false,
                            isLast: index == steps.length - 1,
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

class _StepTrackItem extends StatelessWidget {
  const _StepTrackItem({
    required this.step,
    required this.activeStep,
    required this.locale,
    required this.isCompact,
    required this.isLast,
  });

  final OrderStep step;
  final OrderStep activeStep;
  final String locale;
  final bool isCompact;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDone = activeStep.value > step.value;
    final isCurrent = step == activeStep;
    final markerBorderColor = isDone || isCurrent
        ? HfPalette.accent
        : HfPalette.line;
    final markerFillColor = isDone ? HfPalette.accent : Colors.white;
    final markerTextColor = isDone
        ? Colors.white
        : isCurrent
        ? HfPalette.accent
        : HfPalette.muted;
    final labelColor = isDone
        ? HfPalette.ink
        : isCurrent
        ? HfPalette.accent
        : HfPalette.muted;
    final titleLabel = switch (step) {
      OrderStep.design => localizedUiText(locale, ja: 'デザイン', en: 'Design'),
      OrderStep.listing => localizedUiText(locale, ja: '出品個体', en: 'Listing'),
      OrderStep.purchase => localizedUiText(locale, ja: '購入', en: 'Purchase'),
    };
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: markerFillColor,
              border: Border.all(color: markerBorderColor, width: 2),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 20, color: Colors.white)
                  : Text(
                      step.value.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: markerTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              titleLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );

    if (isCompact) {
      return content;
    }

    return Stack(
      children: [
        content,
        if (!isLast)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 20,
                  child: CustomPaint(
                    painter: _StepArrowSeparatorPainter(HfPalette.line),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StepArrowSeparatorPainter extends CustomPainter {
  const _StepArrowSeparatorPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StepArrowSeparatorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DesignStep extends StatelessWidget {
  const _DesignStep({
    super.key,
    required this.locale,
    required this.state,
    required this.sealLine1Controller,
    required this.sealLine2Controller,
    required this.onToggleWritingMode,
    required this.onStyleChanged,
    required this.onSelectFont,
    required this.onSelectShape,
    required this.onRealNameChanged,
    required this.onGenderChanged,
    required this.onGenerateSuggestions,
    required this.onSelectSuggestion,
    required this.onSaveCurrentSealDesign,
    required this.onApplySavedSealDesign,
    required this.onContinueWithSavedSealDesign,
    required this.selectedSavedSealDesignIds,
    required this.onToggleSavedSealDesignSelection,
    required this.onClearSavedSealDesignSelection,
    required this.onCompareSavedSealDesigns,
    required this.onToggleSavedSealDesignFavorite,
    required this.onDeleteSavedSealDesign,
    required this.onNext,
  });

  final String locale;
  final OrderScreenState state;
  final TextEditingController sealLine1Controller;
  final TextEditingController sealLine2Controller;
  final VoidCallback onToggleWritingMode;
  final ValueChanged<KanjiStyle> onStyleChanged;
  final ValueChanged<String> onSelectFont;
  final ValueChanged<SealShape> onSelectShape;
  final ValueChanged<String> onRealNameChanged;
  final ValueChanged<CandidateGender> onGenderChanged;
  final VoidCallback onGenerateSuggestions;
  final ValueChanged<int> onSelectSuggestion;
  final VoidCallback onSaveCurrentSealDesign;
  final ValueChanged<String> onApplySavedSealDesign;
  final ValueChanged<String> onContinueWithSavedSealDesign;
  final Set<String> selectedSavedSealDesignIds;
  final void Function(String id, bool selected)
  onToggleSavedSealDesignSelection;
  final VoidCallback onClearSavedSealDesignSelection;
  final VoidCallback onCompareSavedSealDesigns;
  final void Function(String id, bool isFavorite)
  onToggleSavedSealDesignFavorite;
  final ValueChanged<String> onDeleteSavedSealDesign;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 920;
        final controls = _buildControls();
        final preview = _buildPreview(onSelectShape: onSelectShape);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (twoColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 14, child: controls),
                  const SizedBox(width: 16),
                  Expanded(flex: 10, child: preview),
                ],
              )
            else ...[
              controls,
              const SizedBox(height: 14),
              preview,
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onNext,
                child: Text(
                  isEnglishLocale(locale) ? 'Next: Listing' : '出品個体選びへ進む',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    final sealTitle = localizedUiText(
      locale,
      ja: 'お名前（印影テキスト）',
      en: 'Name for the seal text',
    );
    final toggleWritingModeLabel = localizedUiText(
      locale,
      ja: '縦横変換',
      en: 'Swap layout',
    );
    final line1Label = localizedUiText(locale, ja: '1行目', en: 'Line 1');
    final line2Label = localizedUiText(locale, ja: '2行目', en: 'Line 2');
    final sealLimitHint = localizedUiText(
      locale,
      ja: '1行目と2行目の合計2文字まで',
      en: 'Use up to 2 characters total across the two lines.',
    );
    final fontStyleLabel = localizedUiText(
      locale,
      ja: 'フォントスタイル',
      en: 'Font style',
    );
    final styleHint = localizedUiText(
      locale,
      ja: '選んだスタイルに合わせてフォントが表示されます。',
      en: 'Fonts are filtered to the selected style.',
    );
    final hasSealTextError = state.sealTextError.isNotEmpty;

    InputDecoration sealLineDecoration(String hintText) {
      return InputDecoration(
        counterText: '',
        hintText: hintText,
        errorText: hasSealTextError ? ' ' : null,
        errorStyle: const TextStyle(fontSize: 0, height: 0),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sealTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                OutlinedButton(
                  onPressed: onToggleWritingMode,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: HfPalette.line),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(toggleWritingModeLabel),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line1Label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: sealLine1Controller,
                        maxLength: 2,
                        decoration: sealLineDecoration(line1Label),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line2Label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: sealLine2Controller,
                        maxLength: 2,
                        decoration: sealLineDecoration(line2Label),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sealLimitHint,
              style: TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
            if (hasSealTextError) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8F2219).withValues(alpha: 0.22),
                  ),
                  color: const Color(0xFFFBF2F0),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Color(0xFF8F2219),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.sealTextError,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Color(0xFF8F2219),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              fontStyleLabel,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            _KanjiStyleSelectField(
              locale: locale,
              value: state.kanjiStyle,
              onChanged: onStyleChanged,
            ),
            const SizedBox(height: 6),
            Text(
              styleHint,
              style: TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
            const SizedBox(height: 12),
            _buildSuggestionPanel(),
            const SizedBox(height: 12),
            _SavedSealDesignsPanel(
              locale: locale,
              state: state,
              onSave: onSaveCurrentSealDesign,
              onApply: onApplySavedSealDesign,
              onContinue: onContinueWithSavedSealDesign,
              selectedIds: selectedSavedSealDesignIds,
              onToggleSelection: onToggleSavedSealDesignSelection,
              onClearSelection: onClearSavedSealDesignSelection,
              onCompareSelected: onCompareSavedSealDesigns,
              onToggleFavorite: onToggleSavedSealDesignFavorite,
              onDelete: onDeleteSavedSealDesign,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview({required ValueChanged<SealShape> onSelectShape}) {
    final line1 = state.sealLine1.isEmpty ? '印' : state.sealLine1;
    final line2 = state.sealLine2;
    final hasLine2 = line2.isNotEmpty;
    final isSingleChar = !hasLine2 && line1.characters.length == 1;
    final isSingleLine = !hasLine2 && line1.characters.length > 1;
    final isRound = state.shape == SealShape.round;

    const rem = 16.0;
    var line1Size = 8.8 * rem;
    var line2Size = 5.6 * rem;
    if (hasLine2) {
      line1Size = isRound ? 6.2 * rem : 6.8 * rem;
      line2Size = isRound ? 6.2 * rem : 6.8 * rem;
    } else if (isSingleLine) {
      line1Size = isRound ? 8.8 * rem : 9.4 * rem;
    } else if (isSingleChar) {
      line1Size = isRound ? 10.8 * rem : 12.5 * rem;
    }

    final previewPadding = isSingleChar
        ? const EdgeInsets.fromLTRB(4, 2, 4, 8)
        : const EdgeInsets.all(6);
    final previewScale = isSingleChar ? (isRound ? 1.14 : 1.18) : 1.1;
    final lineGap = hasLine2
        ? isRound
              ? 0.06 * rem
              : 0.08 * rem
        : 0.15 * rem;
    final previewTitle = localizedUiText(locale, ja: 'プレビュー', en: 'Preview');
    final shapeOptionsLabel = localizedUiText(locale, ja: '形状', en: 'Shape');
    final fontOptionsLabel = localizedUiText(
      locale,
      ja: 'フォント一覧',
      en: 'Font list',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              previewTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 260,
                height: 260,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  shape: state.shape == SealShape.round
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: state.shape == SealShape.square
                      ? BorderRadius.circular(16)
                      : null,
                  border: Border.all(color: HfPalette.accent, width: 4),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFCECE9)],
                  ),
                ),
                child: Padding(
                  padding: previewPadding,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _SealPreviewTextPainter(
                          line1: line1,
                          line2: hasLine2 ? line2 : '',
                          line1Style: _stampFontStyle(
                            family: state.selectedFont.family,
                            size: line1Size * previewScale,
                            height: 1,
                          ),
                          line2Style: _stampFontStyle(
                            family: state.selectedFont.family,
                            size: line2Size * previewScale,
                            height: 1,
                          ),
                          lineGap: lineGap * previewScale,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      ExcludeSemantics(
                        child: Opacity(
                          opacity: 0,
                          child: Text(hasLine2 ? '$line1\n$line2' : line1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.shape.localizedPreviewLabel(locale)} / ${state.selectedFont.label}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: HfPalette.muted),
            ),
            const SizedBox(height: 14),
            Text(
              shapeOptionsLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.availableShapes
                  .map((shape) {
                    return ChoiceChip(
                      label: Text(shape.localizedLabel(locale)),
                      selected: state.shape == shape,
                      onSelected: (_) => onSelectShape(shape),
                      showCheckmark: true,
                      checkmarkColor: HfPalette.accent,
                      selectedColor: HfPalette.accentSoft,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: state.shape == shape
                            ? HfPalette.accent
                            : HfPalette.line,
                        width: state.shape == shape ? 1.4 : 1,
                      ),
                      labelStyle: TextStyle(
                        color: state.shape == shape
                            ? HfPalette.accent
                            : HfPalette.ink,
                        fontWeight: state.shape == shape
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFD8CCBC), height: 1),
            const SizedBox(height: 12),
            Text(
              fontOptionsLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 420 ? 2 : 3;
                const spacing = 8.0;
                final chipWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: state.visibleFonts
                      .map((font) {
                        final selected = font.key == state.selectedFont.key;
                        final previewText = state.sealLine1.isEmpty
                            ? '印'
                            : state.sealLine2.isNotEmpty
                            ? '${state.sealLine1}\n${state.sealLine2}'
                            : state.sealLine1;
                        return SizedBox(
                          width: chipWidth,
                          child: GestureDetector(
                            onTap: () => onSelectFont(font.key),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? HfPalette.accent
                                      : HfPalette.line,
                                  width: selected ? 1.6 : 1,
                                ),
                                color: selected
                                    ? const Color(0xFFFFF7F5)
                                    : Colors.white,
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: HfPalette.accent.withValues(
                                            alpha: 0.10,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    height: 46,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFECE3D6),
                                      ),
                                      color: const Color(0xFFFFFBF5),
                                    ),
                                    child: Text(
                                      previewText,
                                      textAlign: TextAlign.center,
                                      style: _stampFontStyle(
                                        family: font.family,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    font.label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: selected
                                          ? HfPalette.accent
                                          : HfPalette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCEB79F)),
                color: const Color(0xFFFFFBF5),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: localizedUiText(locale, ja: '補足: ', en: 'Note: '),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HfPalette.ink,
                      ),
                    ),
                    TextSpan(
                      text: localizedUiText(
                        locale,
                        ja: '宝石個体は丸印・角印のどちらでも選べます。',
                        en: 'The gemstone listings can be used with either shape.',
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: HfPalette.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionPanel() {
    final title = localizedUiText(
      locale,
      ja: '漢字名提案',
      en: 'Kanji name suggestions',
    );
    final description = localizedUiText(
      locale,
      ja: '本名と性別を入力して、今選んでいるフォントスタイルに合う候補を生成できます。',
      en: 'Enter a name and gender preference to generate suggestions that match the selected font style.',
    );
    final nameLabel = localizedUiText(locale, ja: '本名', en: 'Name');
    final nameHint = localizedUiText(
      locale,
      ja: '例: 山田 太郎',
      en: 'e.g. Michael Smith',
    );
    final genderLabel = localizedUiText(
      locale,
      ja: '性別',
      en: 'Gender preference',
    );
    final generateLabel = localizedUiText(
      locale,
      ja: '候補を生成',
      en: 'Generate suggestions',
    );
    final generatingLabel = localizedUiText(
      locale,
      ja: '生成中...',
      en: 'Generating suggestions...',
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFCEB79F),
          style: BorderStyle.solid,
        ),
        color: const Color(0xFFFFFBF5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: HfPalette.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nameLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: state.realName,
            onChanged: onRealNameChanged,
            decoration: InputDecoration(hintText: nameHint),
          ),
          const SizedBox(height: 10),
          Text(
            genderLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _GenderSelectField(
            locale: locale,
            value: state.candidateGender,
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: state.isGeneratingSuggestions
                ? null
                : onGenerateSuggestions,
            child: Text(
              state.isGeneratingSuggestions ? generatingLabel : generateLabel,
            ),
          ),
          const SizedBox(height: 10),
          _SuggestionBox(state: state, onSelectSuggestion: onSelectSuggestion),
        ],
      ),
    );
  }
}

class _GenderSelectField extends StatelessWidget {
  const _GenderSelectField({
    required this.locale,
    required this.value,
    required this.onChanged,
  });

  final String locale;
  final CandidateGender value;
  final ValueChanged<CandidateGender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: HfPalette.bgPanel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HfPalette.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.localizedLabel(locale),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HfPalette.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: HfPalette.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final isEnglish = isEnglishLocale(locale);
    final title = isEnglish ? 'Gender preference' : '性別';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: HfPalette.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.notoSerifJp(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: HfPalette.ink,
                  ),
                ),
                const SizedBox(height: 12),
                ...CandidateGender.values.map((gender) {
                  final selected = gender == value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (!selected) {
                          onChanged(gender);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? HfPalette.accentSoft.withValues(alpha: 0.45)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? HfPalette.accent : HfPalette.line,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                gender.localizedLabel(locale),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: selected
                                      ? HfPalette.accent
                                      : HfPalette.ink,
                                ),
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: selected
                                  ? HfPalette.accent
                                  : HfPalette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomSheetSelectOption<T> {
  const _BottomSheetSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _BottomSheetSelectField<T> extends StatelessWidget {
  const _BottomSheetSelectField({
    required this.title,
    required this.selectedValue,
    required this.selectedLabel,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T selectedValue;
  final String selectedLabel;
  final List<_BottomSheetSelectOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: HfPalette.bgPanel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HfPalette.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HfPalette.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: HfPalette.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: HfPalette.bgPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.notoSerifJp(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: HfPalette.ink,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((option) {
                  final selected = option.value == selectedValue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (!selected) {
                          onChanged(option.value);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? HfPalette.accentSoft.withValues(alpha: 0.45)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? HfPalette.accent : HfPalette.line,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: selected
                                      ? HfPalette.accent
                                      : HfPalette.ink,
                                ),
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: selected
                                  ? HfPalette.accent
                                  : HfPalette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountrySelectField extends StatelessWidget {
  const _CountrySelectField({
    required this.locale,
    required this.value,
    required this.selectedLabel,
    required this.options,
    required this.onChanged,
  });

  final String locale;
  final String value;
  final String selectedLabel;
  final List<_BottomSheetSelectOption<String>> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = isEnglishLocale(locale) ? 'Country' : '国';
    return _BottomSheetSelectField<String>(
      title: title,
      selectedValue: value,
      selectedLabel: selectedLabel,
      options: options,
      onChanged: onChanged,
    );
  }
}

class _KanjiStyleSelectField extends StatelessWidget {
  const _KanjiStyleSelectField({
    required this.locale,
    required this.value,
    required this.onChanged,
  });

  final String locale;
  final KanjiStyle value;
  final ValueChanged<KanjiStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final isEnglish = isEnglishLocale(locale);
    final title = isEnglish ? 'Font style' : 'フォントスタイル';
    return _BottomSheetSelectField<KanjiStyle>(
      title: title,
      selectedValue: value,
      selectedLabel: value.localizedLabel(locale),
      options: KanjiStyle.values
          .map(
            (style) => _BottomSheetSelectOption<KanjiStyle>(
              value: style,
              label: style.localizedLabel(locale),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

class _SuggestionBox extends StatelessWidget {
  const _SuggestionBox({required this.state, required this.onSelectSuggestion});

  final OrderScreenState state;
  final ValueChanged<int> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    if (state.isGeneratingSuggestions) {
      return Text(
        localizedUiText(
          state.locale,
          ja: '候補を生成しています...',
          en: 'Generating suggestions...',
        ),
        style: const TextStyle(fontSize: 13, color: HfPalette.muted),
      );
    }

    if (state.suggestions.isEmpty) {
      final hasName = state.realName.trim().isNotEmpty;
      final message = state.suggestionsError.isNotEmpty
          ? state.suggestionsError
          : hasName
          ? localizedUiText(
              state.locale,
              ja: '候補を生成してください。',
              en: 'Generate suggestions.',
            )
          : localizedUiText(
              state.locale,
              ja: 'お名前を入力してください。',
              en: 'Enter your name.',
            );
      final color = state.suggestionsError.isNotEmpty
          ? const Color(0xFF8F2219)
          : HfPalette.muted;
      return Text(message, style: TextStyle(fontSize: 13, color: color));
    }

    final selected = state.selectedSuggestion;
    final readingText = selected == null
        ? localizedUiText(state.locale, ja: '読み方', en: 'Reading')
        : state.kanjiStyle.isChineseStyle
        ? localizedUiText(
            state.locale,
            ja: '読み方(拼音): ${normalizePinyinWithoutTone(selected.reading)}',
            en: 'Reading (Pinyin): ${normalizePinyinWithoutTone(selected.reading)}',
          )
        : localizedUiText(
            state.locale,
            ja: '読み方(ローマ字): ${selected.reading.toLowerCase()}',
            en: 'Reading (Romaji): ${selected.reading.toLowerCase()}',
          );

    final reasonText =
        selected?.reason ??
        localizedUiText(state.locale, ja: '提案理由', en: 'Reason');
    final suggestionsHeading = localizedUiText(
      state.locale,
      ja: '${state.realName.trim()} さんへの候補',
      en: 'Suggestions for ${state.realName.trim()}',
    );
    final tapHint = localizedUiText(
      state.locale,
      ja: '候補をタップすると印影テキストに反映されます。',
      en: 'Tap a suggestion to apply it to the seal text.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(suggestionsHeading, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(state.suggestions.length, (index) {
            final suggestion = state.suggestions[index];
            final selectedChip = state.selectedSuggestionIndex == index;
            return ChoiceChip(
              label: Text(
                suggestion.kanji,
                style: _stampFontStyle(
                  family: state.selectedFont.family,
                  size: 18,
                  color: selectedChip ? HfPalette.accent : HfPalette.accent2,
                ),
              ),
              selected: selectedChip,
              backgroundColor: HfPalette.accent2.withValues(alpha: 0.08),
              side: BorderSide(
                color: selectedChip
                    ? HfPalette.accent.withValues(alpha: 0.45)
                    : HfPalette.accent2.withValues(alpha: 0.35),
              ),
              selectedColor: HfPalette.accent.withValues(alpha: 0.10),
              onSelected: (_) => onSelectSuggestion(index),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          readingText,
          style: const TextStyle(fontSize: 12, color: HfPalette.muted),
        ),
        const SizedBox(height: 4),
        Text(
          reasonText,
          style: const TextStyle(fontSize: 12, color: HfPalette.muted),
        ),
        const SizedBox(height: 6),
        Text(tapHint, style: TextStyle(fontSize: 12, color: HfPalette.muted)),
      ],
    );
  }
}

class _SavedSealDesignsPanel extends StatelessWidget {
  const _SavedSealDesignsPanel({
    required this.locale,
    required this.state,
    required this.onSave,
    required this.onApply,
    required this.onContinue,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onClearSelection,
    required this.onCompareSelected,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final String locale;
  final OrderScreenState state;
  final VoidCallback onSave;
  final ValueChanged<String> onApply;
  final ValueChanged<String> onContinue;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onToggleSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onCompareSelected;
  final void Function(String id, bool isFavorite) onToggleFavorite;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final title = localizedUiText(
      locale,
      ja: '保存済み印影案',
      en: 'Saved seal ideas',
    );
    final saveLabel = localizedUiText(
      locale,
      ja: '現在の印影を保存',
      en: 'Save current',
    );
    final compareLabel = localizedUiText(
      locale,
      ja: '選択した案を比較',
      en: 'Compare selected',
    );
    final clearLabel = localizedUiText(locale, ja: '選択解除', en: 'Clear');
    final emptyText = localizedUiText(
      locale,
      ja: '保存した印影案はここに表示されます。',
      en: 'Saved seal ideas will appear here.',
    );
    final localStorageNotice = localizedUiText(
      locale,
      ja: '保存済み印影案は、この端末内にのみ保存されます。アプリ削除・別端末・機種変更では引き継がれません。',
      en: 'Saved only on this device. It is not transferred if you delete the app, use another device, or change phones.',
    );
    final hasError = state.savedSealDesignsError.isNotEmpty;
    final statusText = hasError
        ? state.savedSealDesignsError
        : state.savedSealDesignsMessage;
    final selectedCount = state.savedSealDesigns
        .where((design) => selectedIds.contains(design.id))
        .length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCEB79F)),
        color: const Color(0xFFFFFBF5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: Text(saveLabel),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: HfPalette.line),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: selectedCount >= 2 ? onCompareSelected : null,
                      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      label: Text(compareLabel),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            localStorageNotice,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: HfPalette.muted,
            ),
          ),
          if (selectedCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  localizedUiText(
                    locale,
                    ja: '$selectedCount件を比較対象に選択中',
                    en: '$selectedCount selected for comparison',
                  ),
                  style: const TextStyle(fontSize: 12, color: HfPalette.muted),
                ),
                TextButton(
                  onPressed: onClearSelection,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(clearLabel),
                ),
              ],
            ),
          ],
          if (statusText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SavedSealDesignStatus(message: statusText, isError: hasError),
          ],
          const SizedBox(height: 10),
          if (state.savedSealDesigns.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(fontSize: 13, color: HfPalette.muted),
            )
          else
            Column(
              children: state.savedSealDesigns
                  .map(
                    (design) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SavedSealDesignTile(
                        locale: locale,
                        state: state,
                        design: design,
                        selected: selectedIds.contains(design.id),
                        onSelectedChanged: (selected) =>
                            onToggleSelection(design.id, selected),
                        onApply: () => onApply(design.id),
                        onContinue: () => onContinue(design.id),
                        onToggleFavorite: (isFavorite) =>
                            onToggleFavorite(design.id, isFavorite),
                        onDelete: () => onDelete(design.id),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _SavedSealDesignStatus extends StatelessWidget {
  const _SavedSealDesignStatus({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFF8F2219) : const Color(0xFF0A564F);
    final background = isError
        ? const Color(0xFFFBF2F0)
        : HfPalette.accent2.withValues(alpha: 0.08);
    final border = isError
        ? const Color(0xFFF1D1CE)
        : HfPalette.accent2.withValues(alpha: 0.24);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        color: background,
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12.5, height: 1.35, color: color),
      ),
    );
  }
}

class _SavedSealDesignTile extends StatelessWidget {
  const _SavedSealDesignTile({
    required this.locale,
    required this.state,
    required this.design,
    required this.selected,
    required this.onSelectedChanged,
    required this.onApply,
    required this.onContinue,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final String locale;
  final OrderScreenState state;
  final SavedSealDesignData design;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onApply;
  final VoidCallback onContinue;
  final ValueChanged<bool> onToggleFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final shape = SealShape.fromCode(design.shapeCode);
    final fontLabel = _fontLabelForSavedDesign(state, design);
    final reading = design.reading.trim();
    final meaning = design.meaning.trim();
    final savedAt = _formatSavedSealDesignDate(design.updatedAtMillis);
    final applyLabel = localizedUiText(locale, ja: '編集を再開', en: 'Edit again');
    final continueLabel = localizedUiText(
      locale,
      ja: '注文へ進む',
      en: 'Continue order',
    );
    final deleteLabel = localizedUiText(locale, ja: '削除', en: 'Delete');
    final selectLabel = localizedUiText(
      locale,
      ja: '比較対象に選択',
      en: 'Select for comparison',
    );
    final favoriteLabel = localizedUiText(
      locale,
      ja: design.isFavorite ? 'お気に入りを解除' : 'お気に入りに追加',
      en: design.isFavorite ? 'Remove favorite' : 'Add favorite',
    );
    final readingLabel = localizedUiText(locale, ja: '読み方', en: 'Reading');
    final meaningLabel = localizedUiText(locale, ja: '提案理由', en: 'Reason');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HfPalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: selectLabel,
            child: Checkbox(
              value: selected,
              onChanged: (value) => onSelectedChanged(value ?? false),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          _SavedSealPreview(state: state, design: design),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  design.sealDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HfPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${shape.localizedLabel(locale)} / $fontLabel / $savedAt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: HfPalette.muted),
                ),
                if (reading.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '$readingLabel: $reading',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HfPalette.muted,
                    ),
                  ),
                ],
                if (meaning.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '$meaningLabel: $meaning',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: HfPalette.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: onApply,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: Text(applyLabel),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 17),
                      label: Text(continueLabel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HfPalette.accent,
                        side: const BorderSide(color: HfPalette.accent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: favoriteLabel,
                child: IconButton(
                  onPressed: () => onToggleFavorite(!design.isFavorite),
                  icon: Icon(
                    design.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                  color: design.isFavorite
                      ? const Color(0xFFB87912)
                      : HfPalette.muted,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Tooltip(
                message: deleteLabel,
                child: IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: HfPalette.muted,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedSealComparisonScreen extends StatelessWidget {
  const _SavedSealComparisonScreen({
    required this.locale,
    required this.state,
    required this.selectedIds,
    required this.onBack,
    required this.onClearSelection,
    required this.onApply,
    required this.onContinue,
    required this.onToggleFavorite,
  });

  final String locale;
  final OrderScreenState state;
  final Set<String> selectedIds;
  final VoidCallback onBack;
  final VoidCallback onClearSelection;
  final ValueChanged<String> onApply;
  final ValueChanged<String> onContinue;
  final void Function(String id, bool isFavorite) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final designs = state.savedSealDesigns
        .where((design) => selectedIds.contains(design.id))
        .toList(growable: false);
    final title = localizedUiText(
      locale,
      ja: '印影案を比較',
      en: 'Compare seal ideas',
    );
    final subtitle = localizedUiText(
      locale,
      ja: '選択した保存済み印影案の文字・書体・形状・読み方/意味・お気に入り状態を見比べられます。',
      en: 'Review the saved seal text, font, shape, reading, meaning, and favorite state side by side.',
    );
    final backLabel = localizedUiText(locale, ja: '保存済み案に戻る', en: 'Back');
    final clearLabel = localizedUiText(locale, ja: '選択を解除', en: 'Clear');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: HfPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: HfPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(backLabel),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: HfPalette.line),
                    ),
                  ),
                  TextButton(
                    onPressed: onClearSelection,
                    child: Text(clearLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (designs.length < 2)
          _SavedSealDesignStatus(
            message: localizedUiText(
              locale,
              ja: '比較する印影案を2件以上選択してください。',
              en: 'Select at least two seal ideas to compare.',
            ),
            isError: true,
          )
        else
          _SavedSealComparisonTable(
            locale: locale,
            state: state,
            designs: designs,
            onApply: onApply,
            onContinue: onContinue,
            onToggleFavorite: onToggleFavorite,
          ),
      ],
    );
  }
}

class _SavedSealComparisonTable extends StatelessWidget {
  const _SavedSealComparisonTable({
    required this.locale,
    required this.state,
    required this.designs,
    required this.onApply,
    required this.onContinue,
    required this.onToggleFavorite,
  });

  final String locale;
  final OrderScreenState state;
  final List<SavedSealDesignData> designs;
  final ValueChanged<String> onApply;
  final ValueChanged<String> onContinue;
  final void Function(String id, bool isFavorite) onToggleFavorite;

  static const _labelWidth = 150.0;
  static const _minColumnWidth = 238.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedColumnWidth = designs.isEmpty
            ? _minColumnWidth
            : (constraints.maxWidth - _labelWidth) / designs.length;
        final columnWidth = expandedColumnWidth > _minColumnWidth
            ? expandedColumnWidth
            : _minColumnWidth;
        final tableWidth = _labelWidth + columnWidth * designs.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SizedBox(
              width: tableWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HfPalette.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _headerRow(columnWidth: columnWidth),
                      _comparisonRow(
                        label: localizedUiText(
                          locale,
                          ja: '印面テキスト',
                          en: 'Seal text',
                        ),
                        values: designs
                            .map((design) {
                              return _ComparisonText(
                                primary: design.sealDisplay,
                                emphasize: true,
                              );
                            })
                            .toList(growable: false),
                        columnWidth: columnWidth,
                      ),
                      _comparisonRow(
                        label: localizedUiText(locale, ja: '書体', en: 'Font'),
                        values: designs
                            .map((design) {
                              return _ComparisonText(
                                primary: _fontLabelForSavedDesign(
                                  state,
                                  design,
                                ),
                                secondary: KanjiStyle.fromCode(
                                  design.kanjiStyleCode,
                                ).localizedLabel(locale),
                              );
                            })
                            .toList(growable: false),
                        columnWidth: columnWidth,
                      ),
                      _comparisonRow(
                        label: localizedUiText(locale, ja: '形状', en: 'Shape'),
                        values: designs
                            .map((design) {
                              return _ComparisonText(
                                primary: SealShape.fromCode(
                                  design.shapeCode,
                                ).localizedLabel(locale),
                              );
                            })
                            .toList(growable: false),
                        columnWidth: columnWidth,
                      ),
                      _comparisonRow(
                        label: localizedUiText(
                          locale,
                          ja: '読み方 / 意味',
                          en: 'Reading / meaning',
                        ),
                        values: designs
                            .map((design) {
                              final reading = design.reading.trim();
                              final meaning = design.meaning.trim();
                              final fallback = localizedUiText(
                                locale,
                                ja: '保存された読み方・意味はありません。',
                                en: 'No reading or reason saved.',
                              );
                              return _ComparisonText(
                                primary: reading.isEmpty ? fallback : reading,
                                secondary: meaning,
                              );
                            })
                            .toList(growable: false),
                        columnWidth: columnWidth,
                        minHeight: 96,
                      ),
                      _comparisonRow(
                        label: localizedUiText(
                          locale,
                          ja: 'お気に入り',
                          en: 'Favorite',
                        ),
                        values: designs
                            .map((design) {
                              return _FavoriteComparisonCell(
                                locale: locale,
                                design: design,
                                onToggle: () => onToggleFavorite(
                                  design.id,
                                  !design.isFavorite,
                                ),
                              );
                            })
                            .toList(growable: false),
                        columnWidth: columnWidth,
                      ),
                      _comparisonRow(
                        label: localizedUiText(locale, ja: '操作', en: 'Actions'),
                        values: designs
                            .map((design) {
                              return _ComparisonActions(
                                locale: locale,
                                onApply: () => onApply(design.id),
                                onContinue: () => onContinue(design.id),
                              );
                            })
                            .toList(growable: false),
                        columnWidth: columnWidth,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerRow({required double columnWidth}) {
    return _comparisonRowShell(
      columnWidth: columnWidth,
      minHeight: 118,
      isFirstRow: true,
      isHeader: true,
      label: Text(
        localizedUiText(locale, ja: '比較項目', en: 'Compare'),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: HfPalette.ink,
        ),
      ),
      values: designs
          .map((design) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SavedSealPreview(state: state, design: design),
                const SizedBox(height: 8),
                Text(
                  _formatSavedSealDesignDate(design.updatedAtMillis),
                  style: const TextStyle(fontSize: 12, color: HfPalette.muted),
                ),
              ],
            );
          })
          .toList(growable: false),
    );
  }

  Widget _comparisonRow({
    required String label,
    required List<Widget> values,
    required double columnWidth,
    double minHeight = 78,
  }) {
    return _comparisonRowShell(
      columnWidth: columnWidth,
      minHeight: minHeight,
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: HfPalette.ink,
        ),
      ),
      values: values,
    );
  }

  Widget _comparisonRowShell({
    required Widget label,
    required List<Widget> values,
    required double columnWidth,
    required double minHeight,
    bool isFirstRow = false,
    bool isHeader = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _comparisonCell(
            label,
            width: _labelWidth,
            minHeight: minHeight,
            isFirstRow: isFirstRow,
            isLastColumn: values.isEmpty,
            isHeader: isHeader,
          ),
          for (var index = 0; index < values.length; index++)
            _comparisonCell(
              values[index],
              width: columnWidth,
              minHeight: minHeight,
              isFirstRow: isFirstRow,
              isLastColumn: index == values.length - 1,
              isHeader: isHeader,
            ),
        ],
      ),
    );
  }

  Widget _comparisonCell(
    Widget child, {
    required double width,
    required double minHeight,
    required bool isFirstRow,
    required bool isLastColumn,
    required bool isHeader,
  }) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          top: isFirstRow
              ? BorderSide.none
              : const BorderSide(color: HfPalette.line),
          right: isLastColumn
              ? BorderSide.none
              : const BorderSide(color: HfPalette.line),
        ),
        color: isHeader ? const Color(0xFFFFFBF5) : Colors.white,
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _ComparisonText extends StatelessWidget {
  const _ComparisonText({
    required this.primary,
    this.secondary = '',
    this.emphasize = false,
  });

  final String primary;
  final String secondary;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          primary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: emphasize ? 16 : 13,
            height: 1.35,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: HfPalette.ink,
          ),
        ),
        if (secondary.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            secondary.trim(),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: HfPalette.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _FavoriteComparisonCell extends StatelessWidget {
  const _FavoriteComparisonCell({
    required this.locale,
    required this.design,
    required this.onToggle,
  });

  final String locale;
  final SavedSealDesignData design;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = localizedUiText(
      locale,
      ja: design.isFavorite ? 'お気に入り' : '未設定',
      en: design.isFavorite ? 'Favorite' : 'Not favorite',
    );
    final tooltip = localizedUiText(
      locale,
      ja: design.isFavorite ? 'お気に入りを解除' : 'お気に入りに追加',
      en: design.isFavorite ? 'Remove favorite' : 'Add favorite',
    );

    return Row(
      children: [
        Icon(
          design.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          size: 20,
          color: design.isFavorite ? const Color(0xFFB87912) : HfPalette.muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HfPalette.ink,
            ),
          ),
        ),
        Tooltip(
          message: tooltip,
          child: IconButton(
            onPressed: onToggle,
            icon: const Icon(Icons.swap_horiz_rounded),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

class _ComparisonActions extends StatelessWidget {
  const _ComparisonActions({
    required this.locale,
    required this.onApply,
    required this.onContinue,
  });

  final String locale;
  final VoidCallback onApply;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final applyLabel = localizedUiText(locale, ja: '編集', en: 'Edit');
    final continueLabel = localizedUiText(locale, ja: '注文へ', en: 'Order');

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        TextButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: Text(applyLabel),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 34),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.shopping_bag_outlined, size: 17),
          label: Text(continueLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: HfPalette.accent,
            side: const BorderSide(color: HfPalette.accent),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 34),
          ),
        ),
      ],
    );
  }
}

class _SavedSealPreview extends StatelessWidget {
  const _SavedSealPreview({required this.state, required this.design});

  final OrderScreenState state;
  final SavedSealDesignData design;

  @override
  Widget build(BuildContext context) {
    final shape = SealShape.fromCode(design.shapeCode);
    final line1 = design.sealLine1.isEmpty ? '印' : design.sealLine1;
    final line2 = design.sealLine2;
    final family = _fontFamilyForSavedDesign(state, design);

    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        shape: shape == SealShape.round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape == SealShape.square
            ? BorderRadius.circular(10)
            : null,
        border: Border.all(color: HfPalette.accent, width: 2),
        color: const Color(0xFFFFF7F5),
      ),
      child: CustomPaint(
        painter: _SealPreviewTextPainter(
          line1: line1,
          line2: line2,
          line1Style: _stampFontStyle(
            family: family,
            size: line2.isEmpty ? 31 : 24,
          ),
          line2Style: _stampFontStyle(family: family, size: 24),
          lineGap: 1,
        ),
      ),
    );
  }
}

class _SealPreviewTextPainter extends CustomPainter {
  const _SealPreviewTextPainter({
    required this.line1,
    required this.line2,
    required this.line1Style,
    required this.line2Style,
    required this.lineGap,
  });

  final String line1;
  final String line2;
  final TextStyle line1Style;
  final TextStyle line2Style;
  final double lineGap;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = <_MeasuredSealLine>[
      _measureLine(line1, line1Style),
      if (line2.trim().isNotEmpty) _measureLine(line2, line2Style),
    ];
    if (lines.isEmpty) {
      return;
    }

    final blockWidth = lines.fold<double>(
      0,
      (maxWidth, line) =>
          line.bounds.width > maxWidth ? line.bounds.width : maxWidth,
    );
    final blockHeight =
        lines.fold<double>(0, (height, line) => height + line.bounds.height) +
        lineGap * (lines.length - 1);

    var y = (size.height - blockHeight) / 2;
    for (final line in lines) {
      final x =
          (size.width - blockWidth) / 2 +
          (blockWidth - line.bounds.width) / 2 -
          line.bounds.left;
      line.painter.paint(canvas, Offset(x, y - line.bounds.top));
      y += line.bounds.height + lineGap;
    }
  }

  _MeasuredSealLine _measureLine(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
      boxHeightStyle: ui.BoxHeightStyle.tight,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );

    Rect bounds;
    if (boxes.isEmpty) {
      bounds = Offset.zero & painter.size;
    } else {
      bounds = boxes.first.toRect();
      for (final box in boxes.skip(1)) {
        bounds = bounds.expandToInclude(box.toRect());
      }
    }

    return _MeasuredSealLine(painter: painter, bounds: bounds);
  }

  @override
  bool shouldRepaint(covariant _SealPreviewTextPainter oldDelegate) {
    return line1 != oldDelegate.line1 ||
        line2 != oldDelegate.line2 ||
        line1Style != oldDelegate.line1Style ||
        line2Style != oldDelegate.line2Style ||
        lineGap != oldDelegate.lineGap;
  }
}

class _MeasuredSealLine {
  const _MeasuredSealLine({required this.painter, required this.bounds});

  final TextPainter painter;
  final Rect bounds;
}

class _StoneListingStep extends StatelessWidget {
  const _StoneListingStep({
    super.key,
    required this.locale,
    required this.state,
    required this.onSelectColorFilter,
    required this.onSelectPatternFilter,
    required this.onClearMaterialFilters,
    required this.onSelectStoneListing,
    required this.onPrev,
    required this.onNext,
  });

  final String locale;
  final OrderScreenState state;
  final ValueChanged<String> onSelectColorFilter;
  final ValueChanged<String> onSelectPatternFilter;
  final VoidCallback onClearMaterialFilters;
  final ValueChanged<String> onSelectStoneListing;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final title = isEnglishLocale(locale) ? 'Choose listing' : '出品個体を選ぶ';
    final subtitle = isEnglishLocale(locale)
        ? 'Compare texture, weight, use, and price to pick your listing. The gemstone listings can be used with either shape.'
        : '質感・重さ・用途と価格を見ながら出品個体を決めます。宝石個体は丸印・角印のどちらでも選べます。';
    final backLabel = isEnglishLocale(locale) ? 'Back' : '戻る';
    final nextLabel = isEnglishLocale(locale) ? 'Next: Purchase' : '購入へ進む';

    String shapeLabelForCode(String code) {
      return switch (code.trim().toLowerCase()) {
        'square' => localizedUiText(locale, ja: '角印', en: 'Square seal'),
        'round' => localizedUiText(locale, ja: '丸印', en: 'Round seal'),
        _ => code,
      };
    }

    List<Widget> shapeChips(StoneListingOption listing) {
      final shapeCode = listing.stoneShape.trim();
      if (shapeCode.isEmpty) {
        return const [];
      }

      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFFFDF9F4),
            border: Border.all(color: HfPalette.line),
          ),
          child: Text(
            shapeLabelForCode(shapeCode),
            style: const TextStyle(fontSize: 11.5, color: HfPalette.muted),
          ),
        ),
      ];
    }

    Widget buildFilterChip({
      required String label,
      required bool selected,
      required VoidCallback onSelected,
    }) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        selectedColor: HfPalette.accentSoft,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? HfPalette.accent : HfPalette.line,
          width: selected ? 1.4 : 1,
        ),
        labelStyle: TextStyle(
          color: selected ? HfPalette.accent : HfPalette.ink,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    Widget buildFilterGroup({
      required String label,
      required String selectedValue,
      required List<MaterialFilterOption> options,
      required ValueChanged<String> onSelected,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildFilterChip(
                label: localizedUiText(locale, ja: 'すべて', en: 'All'),
                selected: selectedValue.isEmpty,
                onSelected: () => onSelected(''),
              ),
              ...options.map((option) {
                return buildFilterChip(
                  label: option.label,
                  selected: selectedValue == option.value,
                  onSelected: () => onSelected(option.value),
                );
              }),
            ],
          ),
        ],
      );
    }

    Widget buildFilterPanel() {
      final visibleCount = state.visibleStoneListings.length;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HfPalette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    localizedUiText(locale, ja: '絞り込み', en: 'Filters'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClearMaterialFilters,
                  child: Text(
                    localizedUiText(locale, ja: 'すべて解除', en: 'Clear all'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${localizedUiText(locale, ja: '選択中の形状', en: 'Selected shape')} ',
                  ),
                  TextSpan(
                    text: state.shape.localizedLabel(locale),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12.5, color: HfPalette.muted),
            ),
            const SizedBox(height: 12),
            buildFilterGroup(
              label: localizedUiText(locale, ja: '色', en: 'Color'),
              selectedValue: state.selectedColorFamily,
              options: state.catalog.materialFilters.colorOptions,
              onSelected: onSelectColorFilter,
            ),
            const SizedBox(height: 12),
            buildFilterGroup(
              label: localizedUiText(locale, ja: '模様', en: 'Pattern'),
              selectedValue: state.selectedPatternPrimary,
              options: state.catalog.materialFilters.patternOptions,
              onSelected: onSelectPatternFilter,
            ),
            const SizedBox(height: 12),
            Text(
              localizedUiText(
                locale,
                ja: '$visibleCount件の出品個体が表示されています。',
                en: '$visibleCount listings are shown.',
              ),
              style: const TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
            if (visibleCount == 0) ...[
              const SizedBox(height: 8),
              Text(
                localizedUiText(
                  locale,
                  ja: '条件に一致する出品個体がありません。フィルタを解除してください。',
                  en: 'No listings match the current filters. Clear one or more filters.',
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF8F2219),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildListingCard(
      StoneListingOption listing,
      bool selected,
      bool compact,
    ) {
      final titleText = listing.title.isNotEmpty
          ? listing.title
          : listing.listingCode;

      return GestureDetector(
        onTap: () => onSelectStoneListing(listing.key),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? HfPalette.accent : HfPalette.line,
              width: selected ? 1.4 : 1,
            ),
            color: Colors.white,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: HfPalette.accent.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.all(compact ? 14 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: listing.hasPhoto
                    ? Image.network(
                        listing.photoUrl,
                        height: compact ? 152 : 132,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: compact ? 152 : 132,
                          color: HfPalette.bgMain,
                        ),
                      )
                    : Container(
                        height: compact ? 152 : 132,
                        color: HfPalette.bgMain,
                      ),
              ),
              SizedBox(height: compact ? 12 : 10),
              Text(
                titleText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 16 : 15,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: shapeChips(listing)),
              if (listing.description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  listing.description,
                  style: TextStyle(
                    fontSize: compact ? 13.5 : 13,
                    height: 1.4,
                    color: HfPalette.muted,
                  ),
                ),
              ],
              if (listing.story.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  listing.story,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 12,
                    height: 1.45,
                    color: HfPalette.muted,
                  ),
                ),
              ],
              if (listing.colorTagLabels.isNotEmpty ||
                  listing.patternTagLabels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      [...listing.colorTagLabels, ...listing.patternTagLabels]
                          .map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: HfPalette.accent2.withValues(
                                  alpha: 0.08,
                                ),
                                border: Border.all(
                                  color: HfPalette.accent2.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: HfPalette.muted,
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                formatMoney(listing.price, state.effectiveCurrency),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 16 : 15,
                  color: HfPalette.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: HfPalette.muted)),
        const SizedBox(height: 16),
        buildFilterPanel(),
        if (state.visibleStoneListings.isNotEmpty) ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 980
                  ? 3
                  : constraints.maxWidth > 620
                  ? 2
                  : 1;
              final compact = constraints.maxWidth < 560;
              final spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: state.visibleStoneListings
                    .map((listing) {
                      final selected =
                          listing.key == state.selectedStoneListingOrNull?.key;
                      return SizedBox(
                        width: itemWidth,
                        child: buildListingCard(listing, selected, compact),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(onPressed: onPrev, child: Text(backLabel)),
            const SizedBox(width: 8),
            FilledButton(onPressed: onNext, child: Text(nextLabel)),
          ],
        ),
      ],
    );
  }
}

class _PurchaseStep extends StatelessWidget {
  const _PurchaseStep({
    super.key,
    required this.locale,
    required this.state,
    required this.onPrev,
    required this.onCountryChanged,
    required this.onRecipientNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onPostalCodeChanged,
    required this.onStateChanged,
    required this.onCityChanged,
    required this.onAddress1Changed,
    required this.onAddress2Changed,
    required this.onTermsChanged,
    required this.onSubmit,
    required this.onOpenTerms,
    required this.onOpenPaymentSuccess,
    required this.onOpenPaymentFailure,
    required this.showConfirmationLinks,
  });

  final String locale;
  final OrderScreenState state;
  final VoidCallback onPrev;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onRecipientNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onPostalCodeChanged;
  final ValueChanged<String> onStateChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onAddress1Changed;
  final ValueChanged<String> onAddress2Changed;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onSubmit;
  final VoidCallback onOpenTerms;
  final void Function(String? sessionId, String? orderId) onOpenPaymentSuccess;
  final ValueChanged<String?> onOpenPaymentFailure;
  final bool showConfirmationLinks;

  @override
  Widget build(BuildContext context) {
    final title = isEnglishLocale(locale) ? 'Purchase' : '購入';
    final subtitle = isEnglishLocale(locale)
        ? 'Review the details, then continue to payment.'
        : '内容を確認して、支払いへ進みます。';
    final backLabel = isEnglishLocale(locale) ? 'Back' : '戻る';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: HfPalette.muted)),
        const SizedBox(height: 16),
        _buildPersonalInfoCard(),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 12),
        _buildPaymentCard(context),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onPrev, child: Text(backLabel)),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    final sectionTitle = localizedUiText(
      locale,
      ja: 'お届け先情報',
      en: 'Shipping details',
    );
    final recipientNameLabel = localizedUiText(
      locale,
      ja: 'お届け先氏名',
      en: 'Recipient name',
    );
    final recipientNameExample = localizedUiText(
      locale,
      ja: '例: 山田 太郎',
      en: 'e.g. Michael Smith',
    );
    final emailLabel = localizedUiText(
      locale,
      ja: 'メールアドレス',
      en: 'Email address',
    );
    final emailExample = localizedUiText(
      locale,
      ja: 'you@example.com',
      en: 'name@example.com',
    );
    final phoneLabel = localizedUiText(locale, ja: '電話番号', en: 'Phone number');
    final phoneExample = localizedUiText(
      locale,
      ja: '+81 90 1234 5678',
      en: '+1 415 555 0123',
    );
    final countryLabel = localizedUiText(
      locale,
      ja: '国 / Country',
      en: 'Country',
    );
    final postalCodeLabel = localizedUiText(
      locale,
      ja: '郵便番号 / ZIP',
      en: 'Postal code',
    );
    final postalCodeExample = localizedUiText(
      locale,
      ja: '100-0001',
      en: '94103',
    );
    final stateLabel = localizedUiText(
      locale,
      ja: '都道府県 / 州',
      en: 'State / Prefecture',
    );
    final stateExample = localizedUiText(locale, ja: '東京都', en: 'California');
    final cityLabel = localizedUiText(locale, ja: '市区町村 / City', en: 'City');
    final cityExample = localizedUiText(
      locale,
      ja: '千代田区',
      en: 'San Francisco',
    );
    final address1Label = localizedUiText(
      locale,
      ja: '住所1',
      en: 'Address line 1',
    );
    final address1Example = localizedUiText(
      locale,
      ja: '丸の内1-1-1',
      en: '1 Market St',
    );
    final address2Label = localizedUiText(
      locale,
      ja: '住所2（任意）',
      en: 'Address line 2 (optional)',
    );
    final address2Example = localizedUiText(
      locale,
      ja: '建物名・部屋番号など',
      en: 'Apt 12B, building name, etc.',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: recipientNameLabel,
              child: TextFormField(
                initialValue: state.recipientName,
                onChanged: onRecipientNameChanged,
                decoration: InputDecoration(hintText: recipientNameExample),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: emailLabel,
              child: TextFormField(
                initialValue: state.email,
                onChanged: onEmailChanged,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: emailExample),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: phoneLabel,
              child: TextFormField(
                initialValue: state.phone,
                onChanged: onPhoneChanged,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(hintText: phoneExample),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: countryLabel,
              child: _CountrySelectField(
                locale: locale,
                value: state.selectedCountry.code,
                selectedLabel: state.selectedCountry.label,
                options: state.catalog.countries
                    .map(
                      (country) => _BottomSheetSelectOption<String>(
                        value: country.code,
                        label: country.label,
                      ),
                    )
                    .toList(growable: false),
                onChanged: onCountryChanged,
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: postalCodeLabel,
              child: TextFormField(
                initialValue: state.postalCode,
                onChanged: onPostalCodeChanged,
                decoration: InputDecoration(hintText: postalCodeExample),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: stateLabel,
              child: TextFormField(
                initialValue: state.stateName,
                onChanged: onStateChanged,
                decoration: InputDecoration(hintText: stateExample),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: cityLabel,
              child: TextFormField(
                initialValue: state.city,
                onChanged: onCityChanged,
                decoration: InputDecoration(hintText: cityExample),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: address1Label,
              child: TextFormField(
                initialValue: state.addressLine1,
                onChanged: onAddress1Changed,
                decoration: InputDecoration(hintText: address1Example),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: address2Label,
              child: TextFormField(
                initialValue: state.addressLine2,
                onChanged: onAddress2Changed,
                decoration: InputDecoration(hintText: address2Example),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final title = localizedUiText(locale, ja: '注文サマリー', en: 'Order summary');
    final sealTextLabel = localizedUiText(
      locale,
      ja: '印影テキスト',
      en: 'Seal text',
    );
    final shapeLabel = localizedUiText(locale, ja: '形状', en: 'Shape');
    final fontLabel = localizedUiText(locale, ja: 'フォント', en: 'Font');
    final listingLabel = localizedUiText(locale, ja: '出品個体', en: 'Listing');
    final countryLabel = localizedUiText(
      locale,
      ja: '配送先の国',
      en: 'Shipping country',
    );
    final subtotalLabel = localizedUiText(locale, ja: '商品価格', en: 'Item total');
    final shippingLabel = localizedUiText(locale, ja: '送料', en: 'Shipping');
    final totalLabel = localizedUiText(locale, ja: '合計', en: 'Total');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: sealTextLabel, value: state.sealDisplay),
            _SummaryRow(
              label: shapeLabel,
              value: state.shape.localizedLabel(locale),
            ),
            _SummaryRow(label: fontLabel, value: state.selectedFont.label),
            _SummaryRow(
              label: listingLabel,
              value: state.selectedStoneListing.title,
            ),
            _SummaryRow(
              label: countryLabel,
              value: state.selectedCountry.label,
            ),
            _SummaryRow(
              label: subtotalLabel,
              value: formatMoney(state.subtotal, state.effectiveCurrency),
            ),
            _SummaryRow(
              label: shippingLabel,
              value: formatMoney(state.shipping, state.effectiveCurrency),
            ),
            _SummaryRow(
              label: totalLabel,
              value: formatMoney(state.total, state.effectiveCurrency),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    final result = state.purchaseResult;
    final validationGroups = state.purchaseValidationGroups;
    final title = localizedUiText(locale, ja: 'お支払い', en: 'Payment');
    final helperText = localizedUiText(
      locale,
      ja: 'Stripe Checkout に遷移して決済します。',
      en: 'You will be redirected to Stripe Checkout to complete payment.',
    );
    final submitLabel = localizedUiText(locale, ja: '支払う', en: 'Pay now');
    final submittingLabel = localizedUiText(
      locale,
      ja: '送信中...',
      en: 'Submitting...',
    );
    final canSubmitPurchase = state.canSubmitPurchase;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: state.termsAgreed,
                  onChanged: (checked) => onTermsChanged(checked ?? false),
                ),
                Expanded(
                  child: _TermsAgreementText(
                    locale: locale,
                    onOpenTerms: onOpenTerms,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              helperText,
              style: TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
            const SizedBox(height: 10),
            _PurchaseStatusBanner(
              locale: locale,
              state: state,
              validationGroups: validationGroups,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmitPurchase ? onSubmit : null,
                child: state.isSubmittingPurchase
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(submittingLabel),
                        ],
                      )
                    : Text(submitLabel),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _PurchaseResultCard(
                locale: locale,
                result: result,
                onOpenPaymentSuccess: onOpenPaymentSuccess,
                onOpenPaymentFailure: onOpenPaymentFailure,
                showConfirmationLinks: showConfirmationLinks,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TermsAgreementText extends StatefulWidget {
  const _TermsAgreementText({required this.locale, required this.onOpenTerms});

  final String locale;
  final VoidCallback onOpenTerms;

  @override
  State<_TermsAgreementText> createState() => _TermsAgreementTextState();
}

class _TermsAgreementTextState extends State<_TermsAgreementText> {
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = widget.onOpenTerms;
  }

  @override
  void didUpdateWidget(covariant _TermsAgreementText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onOpenTerms != widget.onOpenTerms) {
      _termsRecognizer.onTap = widget.onOpenTerms;
    }
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = isEnglishLocale(widget.locale);
    final linkStyle = const TextStyle(
      color: HfPalette.ink,
      decoration: TextDecoration.underline,
    );

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: isEnglish
            ? [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'terms of service',
                  style: linkStyle,
                  recognizer: _termsRecognizer,
                ),
              ]
            : [
                TextSpan(
                  text: '利用規約',
                  style: linkStyle,
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: 'に同意する'),
              ],
      ),
    );
  }
}

class _PurchaseStatusBanner extends StatelessWidget {
  const _PurchaseStatusBanner({
    required this.locale,
    required this.state,
    required this.validationGroups,
  });

  final String locale;
  final OrderScreenState state;
  final List<PurchaseValidationGroup> validationGroups;

  @override
  Widget build(BuildContext context) {
    final isSubmitting = state.isSubmittingPurchase;
    final hasBlockingIssues = validationGroups.isNotEmpty;
    final hasError =
        state.purchaseError.isNotEmpty && !isSubmitting && !hasBlockingIssues;
    if (state.purchaseResult != null &&
        !isSubmitting &&
        !hasBlockingIssues &&
        !hasError) {
      return const SizedBox.shrink();
    }
    final kind = isSubmitting
        ? _PurchaseStatusKind.submitting
        : hasBlockingIssues
        ? _PurchaseStatusKind.blocked
        : hasError
        ? _PurchaseStatusKind.error
        : _PurchaseStatusKind.ready;

    final title = switch (kind) {
      _PurchaseStatusKind.submitting => localizedUiText(
        locale,
        ja: '送信中',
        en: 'Submitting',
      ),
      _PurchaseStatusKind.blocked => localizedUiText(
        locale,
        ja: '入力が不足しています',
        en: 'Missing details',
      ),
      _PurchaseStatusKind.error => localizedUiText(
        locale,
        ja: '送信エラー',
        en: 'Submission error',
      ),
      _PurchaseStatusKind.ready => localizedUiText(
        locale,
        ja: '送信準備完了',
        en: 'Ready to submit',
      ),
    };
    final message = switch (kind) {
      _PurchaseStatusKind.submitting => localizedUiText(
        locale,
        ja: 'Stripe Checkout への送信を準備しています。',
        en: 'Submitting the order and preparing Stripe Checkout.',
      ),
      _PurchaseStatusKind.blocked => localizedUiText(
        locale,
        ja: '未入力または未確認の項目を確認してください。',
        en: 'Review the missing or unconfirmed details below.',
      ),
      _PurchaseStatusKind.error => state.purchaseError,
      _PurchaseStatusKind.ready => localizedUiText(
        locale,
        ja: '入力が揃いました。支払いへ進めます。',
        en: 'All required details are ready. You can proceed to payment.',
      ),
    };

    final icon = switch (kind) {
      _PurchaseStatusKind.submitting => null,
      _PurchaseStatusKind.blocked => Icons.info_outline,
      _PurchaseStatusKind.error => Icons.error_outline,
      _PurchaseStatusKind.ready => Icons.check_circle_outline,
    };
    final backgroundColor = switch (kind) {
      _PurchaseStatusKind.submitting => HfPalette.accent.withValues(
        alpha: 0.08,
      ),
      _PurchaseStatusKind.blocked => const Color(0xFFFBF2F0),
      _PurchaseStatusKind.error => const Color(0xFFFFF2F1),
      _PurchaseStatusKind.ready => HfPalette.accent2.withValues(alpha: 0.08),
    };
    final borderColor = switch (kind) {
      _PurchaseStatusKind.submitting => HfPalette.accent.withValues(
        alpha: 0.30,
      ),
      _PurchaseStatusKind.blocked => const Color(0xFFF1D1CE),
      _PurchaseStatusKind.error => const Color(0xFFF1D1CE),
      _PurchaseStatusKind.ready => HfPalette.accent2.withValues(alpha: 0.30),
    };
    final contentColor = switch (kind) {
      _PurchaseStatusKind.submitting => HfPalette.accent,
      _PurchaseStatusKind.blocked => const Color(0xFF8F2219),
      _PurchaseStatusKind.error => const Color(0xFF8F2219),
      _PurchaseStatusKind.ready => const Color(0xFF0A564F),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        color: backgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kind == _PurchaseStatusKind.submitting)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: contentColor,
                    ),
                  ),
                )
              else
                Icon(icon, size: 18, color: contentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: contentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: contentColor),
          ),
          if (hasBlockingIssues) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: validationGroups
                  .map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: contentColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: group.items
                                .map(
                                  (item) => _PurchaseStatusChip(
                                    text: item,
                                    color: contentColor,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _PurchaseStatusChip extends StatelessWidget {
  const _PurchaseStatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        color: Colors.white.withValues(alpha: 0.78),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PurchaseResultCard extends StatelessWidget {
  const _PurchaseResultCard({
    required this.locale,
    required this.result,
    required this.onOpenPaymentSuccess,
    required this.onOpenPaymentFailure,
    required this.showConfirmationLinks,
  });

  final String locale;
  final PurchaseResultData result;
  final void Function(String? sessionId, String? orderId) onOpenPaymentSuccess;
  final ValueChanged<String?> onOpenPaymentFailure;
  final bool showConfirmationLinks;

  @override
  Widget build(BuildContext context) {
    final hasLine2 = result.sealLine2.isNotEmpty;
    final hasAddress2 = result.addressLine2.isNotEmpty;
    final title = localizedUiText(
      locale,
      ja: '注文を受け付けました',
      en: 'Order received',
    );
    final sourceLabel = localizedUiText(locale, ja: 'データソース', en: 'Source');
    final orderIdLabel = localizedUiText(locale, ja: '注文ID', en: 'Order ID');
    final checkoutLabel = localizedUiText(
      locale,
      ja: '決済セッションID',
      en: 'Checkout Session ID',
    );
    final listingLabel = localizedUiText(locale, ja: '出品個体', en: 'Listing');
    final sealLabel = localizedUiText(locale, ja: '印影', en: 'Seal');
    final shippingLabel = localizedUiText(locale, ja: '配送先', en: 'Shipping to');
    final addressLabel = localizedUiText(locale, ja: '住所', en: 'Address');
    final subtotalLabel = localizedUiText(locale, ja: '小計', en: 'Subtotal');
    final totalLabel = localizedUiText(locale, ja: '合計', en: 'Total');
    final emailLabel = localizedUiText(
      locale,
      ja: '確認メール送信先',
      en: 'Confirmation email',
    );
    final successButtonLabel = localizedUiText(
      locale,
      ja: '支払い成功画面へ（確認用）',
      en: 'Open payment success page',
    );
    final failureButtonLabel = localizedUiText(
      locale,
      ja: '支払い失敗画面へ（確認用）',
      en: 'Open payment failure page',
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HfPalette.accent2.withValues(alpha: 0.35)),
        color: HfPalette.accent2.withValues(alpha: 0.08),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: HfPalette.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$sourceLabel: ${result.sourceLabel} / $orderIdLabel: ${result.orderId} / $checkoutLabel: ${result.checkoutSessionId}',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          Text(
            '$listingLabel: ${result.listingLabel}',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 6),
          Text(
            '$sealLabel: ${result.sealLine1}${hasLine2 ? ' / ${result.sealLine2}' : ''}',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          Text(
            '$shippingLabel: ${result.countryLabel} / ${result.stripeName} / ${result.stripePhone}',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          Text(
            '$addressLabel: ${result.postalCode} ${result.state} ${result.city} ${result.addressLine1}${hasAddress2 ? ' ${result.addressLine2}' : ''}',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          Text(
            '$subtotalLabel: ${formatMoney(result.subtotal, result.currency)} / ${localizedUiText(locale, ja: '送料', en: 'Shipping')}: ${formatMoney(result.shipping, result.currency)} / $totalLabel: ${formatMoney(result.total, result.currency)}',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          Text(
            '$emailLabel: ${result.email}',
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
          if (showConfirmationLinks) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => onOpenPaymentSuccess(
                    result.checkoutSessionId,
                    result.orderId,
                  ),
                  child: Text(successButtonLabel),
                ),
                OutlinedButton(
                  onPressed: () => onOpenPaymentFailure(result.orderId),
                  child: Text(failureButtonLabel),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _PurchaseStatusKind { submitting, blocked, error, ready }

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: HfPalette.muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

String _fontLabelForSavedDesign(
  OrderScreenState state,
  SavedSealDesignData design,
) {
  for (final font in state.catalog.fonts) {
    if (font.key == design.selectedFontKey) {
      return font.label;
    }
  }
  if (design.fontLabel.trim().isNotEmpty) {
    return design.fontLabel.trim();
  }
  return state.selectedFont.label;
}

String _fontFamilyForSavedDesign(
  OrderScreenState state,
  SavedSealDesignData design,
) {
  for (final font in state.catalog.fonts) {
    if (font.key == design.selectedFontKey) {
      return font.family;
    }
  }
  if (design.fontFamily.trim().isNotEmpty) {
    return design.fontFamily.trim();
  }
  return state.selectedFont.family;
}

String _formatSavedSealDesignDate(int millis) {
  if (millis <= 0) {
    return '';
  }

  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

TextStyle _stampFontStyle({
  required String family,
  required double size,
  Color color = HfPalette.accent,
  double height = 0.9,
}) {
  final base = TextStyle(
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w700,
    height: height,
  );

  final primaryFont = _extractPrimaryFontName(family);
  try {
    return AppFonts.getFont(primaryFont, textStyle: base);
  } catch (_) {
    return base;
  }
}

String _extractPrimaryFontName(String family) {
  final primary = family.split(',').first.trim();
  return primary.replaceAll("'", '').replaceAll('"', '').trim();
}
