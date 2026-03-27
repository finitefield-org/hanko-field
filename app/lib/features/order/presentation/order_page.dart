import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config/app_runtime_config.dart';
import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/theme/hf_theme.dart';
import '../../../app/widgets/app_settings_button.dart';
import '../data/order_draft_storage.dart';
import '../domain/order_models.dart';
import 'order_view_model.dart';

class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onOpenPaymentSuccess,
    required this.onOpenPaymentFailure,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final void Function(String? sessionId, String? orderId) onOpenPaymentSuccess;
  final ValueChanged<String?> onOpenPaymentFailure;

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  late final TextEditingController _sealLine1Controller;
  late final TextEditingController _sealLine2Controller;
  bool _syncingSealControllers = false;
  bool _initializedFromState = false;
  bool _bootstrapped = false;
  ProviderSubscription<OrderScreenState>? _orderStateSubscription;
  String _lastAutoOpenedCheckoutToken = '';

  @override
  void initState() {
    super.initState();
    _sealLine1Controller = TextEditingController();
    _sealLine2Controller = TextEditingController();

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
      selectedMaterialKey: state.selectedMaterialKey,
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderViewModel);
    _syncSealControllers(state);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              left: -110,
              top: -90,
              child: _BackgroundShape(angle: 0.42),
            ),
            const Positioned(
              right: -120,
              bottom: -110,
              child: _BackgroundShape(angle: 0.34),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroHeader(
                        locale: widget.locale,
                        onSelectLocale: widget.onSelectLocale,
                      ),
                      const SizedBox(height: 18),
                      Card(
                        color: HfPalette.bgPanel,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _buildMainPanel(state),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel(OrderScreenState state) {
    if (state.isLoadingCatalog && !state.hasCatalog) {
      return _CatalogLoadingPanel(locale: state.locale);
    }

    if (!state.hasCatalog) {
      return _CatalogErrorPanel(
        locale: state.locale,
        message: state.catalogError.isEmpty
            ? localizedUiText(
                state.locale,
                ja: 'カタログを取得できませんでした。',
                en: 'Could not load the catalog.',
              )
            : state.catalogError,
        onRetry: () => ref.invoke(orderViewModel.initialize()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTrack(step: state.step, locale: state.locale),
        const SizedBox(height: 20),
        if (state.catalogError.isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1D1CE)),
            ),
            child: Text(
              state.catalogError,
              style: const TextStyle(color: Color(0xFF8F2219), fontSize: 13),
            ),
          ),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildStepPanel(
            state,
            showConfirmationLinks: ref
                .watch(appRuntimeConfigProvider)
                .showConfirmationLinks,
          ),
        ),
      ],
    );
  }

  Widget _buildStepPanel(
    OrderScreenState state, {
    required bool showConfirmationLinks,
  }) {
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
        onNext: () => ref.invoke(orderViewModel.nextStep()),
      ),
      OrderStep.material => _MaterialStep(
        key: const ValueKey('material_step'),
        locale: state.locale,
        state: state,
        onSelectMaterial: (key) =>
            ref.invoke(orderViewModel.selectMaterial(key)),
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
        onOpenPaymentSuccess: widget.onOpenPaymentSuccess,
        onOpenPaymentFailure: widget.onOpenPaymentFailure,
        showConfirmationLinks: showConfirmationLinks,
      ),
    };
  }
}

class _CatalogLoadingPanel extends StatelessWidget {
  const _CatalogLoadingPanel({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(height: 12),
            Text(
              localizedUiText(
                locale,
                ja: 'カタログを読み込み中です...',
                en: 'Loading catalog...',
              ),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8F2219)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(localizedUiText(locale, ja: '再読み込み', en: 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.locale, required this.onSelectLocale});

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stone Signature',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: HfPalette.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Hand-carved Stone Seals',
                style: TextStyle(fontSize: 16, color: HfPalette.muted),
              ),
            ],
          ),
        ),
        AppSettingsButton(
          selectedLocale: locale,
          onSelectLocale: onSelectLocale,
        ),
      ],
    );
  }
}

class _BackgroundShape extends StatelessWidget {
  const _BackgroundShape({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 340,
        height: 340,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: HfPalette.accent.withValues(alpha: 0.15),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _StepTrack extends StatelessWidget {
  const _StepTrack({required this.step, required this.locale});

  final OrderStep step;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final labels = <OrderStep, String>{
      OrderStep.design: isEnglishLocale(locale) ? '1. Design' : '1. デザイン',
      OrderStep.material: isEnglishLocale(locale) ? '2. Material' : '2. 材質',
      OrderStep.purchase: isEnglishLocale(locale) ? '3. Purchase' : '3. 購入',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Row(
          children: labels.entries
              .map((entry) {
                final isActive = step == entry.key;
                final isDone = step.value > entry.key.value;

                final borderColor = isActive
                    ? HfPalette.accent
                    : isDone
                    ? HfPalette.accent2.withValues(alpha: 0.35)
                    : HfPalette.line;
                final backgroundColor = isActive
                    ? HfPalette.accent
                    : isDone
                    ? HfPalette.accent2.withValues(alpha: 0.08)
                    : Colors.white;
                final textColor = isActive
                    ? Colors.white
                    : isDone
                    ? HfPalette.accent2
                    : HfPalette.muted;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 9 : 11,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor),
                        color: backgroundColor,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            entry.value,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: textColor,
                              fontSize: compact ? 12 : 14,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
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
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 920;
        final controls = _buildControls();
        final preview = _buildPreview();

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
                  isEnglishLocale(locale) ? 'Next: Material' : '材質選びへ進む',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildOptionalSuggestionSection(),
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
            DropdownButtonFormField<KanjiStyle>(
              key: ValueKey('kanji_style_${state.kanjiStyle.code}'),
              initialValue: state.kanjiStyle,
              items: KanjiStyle.values
                  .map(
                    (style) => DropdownMenuItem(
                      value: style,
                      child: Text(style.localizedLabel(locale)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (style) {
                if (style != null) {
                  onStyleChanged(style);
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
              styleHint,
              style: TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionalSuggestionSection() {
    final suggestionsTitle = localizedUiText(
      locale,
      ja: '漢字名提案',
      en: 'Kanji name suggestions',
    );
    final optionalBadge = localizedUiText(locale, ja: '任意', en: 'Optional');
    final suggestionsHint = localizedUiText(
      locale,
      ja: '必要なときだけ開いて、現在のスタイルに合う候補を生成できます。',
      en: 'Open this only if you want suggestions that match the selected style.',
    );
    final realNameLabel = localizedUiText(locale, ja: '本名', en: 'Name');
    final realNameExample = localizedUiText(
      locale,
      ja: '例: 山田 太郎',
      en: 'e.g. Michael Smith',
    );
    final genderLabel = localizedUiText(locale, ja: '性別', en: 'Gender');
    final generatingLabel = localizedUiText(
      locale,
      ja: '生成中...',
      en: 'Generating...',
    );
    final generateLabel = localizedUiText(
      locale,
      ja: '候補を生成',
      en: 'Generate suggestions',
    );

    return Card(
      child: ExpansionTile(
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                suggestionsTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: HfPalette.line),
                color: HfPalette.bgPanel,
              ),
              child: Text(
                optionalBadge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: HfPalette.muted,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            suggestionsHint,
            style: const TextStyle(fontSize: 12, color: HfPalette.muted),
          ),
        ),
        children: [
          Text(
            realNameLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: state.realName,
            onChanged: onRealNameChanged,
            decoration: InputDecoration(hintText: realNameExample),
          ),
          const SizedBox(height: 10),
          Text(
            genderLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<CandidateGender>(
            key: ValueKey('candidate_gender_${state.candidateGender.code}'),
            initialValue: state.candidateGender,
            items: CandidateGender.values
                .map(
                  (gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender.localizedLabel(locale)),
                  ),
                )
                .toList(growable: false),
            onChanged: (gender) {
              if (gender != null) {
                onGenderChanged(gender);
              }
            },
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

  Widget _buildPreview() {
    final line1 = state.sealLine1.isEmpty ? '印' : state.sealLine1;
    final line2 = state.sealLine2;
    final hasLine2 = line2.isNotEmpty;
    final isSingleChar = !hasLine2 && line1.characters.length == 1;
    final isSingleLine = !hasLine2 && line1.characters.length > 1;

    var line1Size = 140.0;
    var line2Size = 106.0;
    if (hasLine2) {
      line1Size = state.shape == SealShape.round ? 86 : 100;
      line2Size = state.shape == SealShape.round ? 86 : 100;
    } else if (isSingleLine) {
      line1Size = state.shape == SealShape.round ? 114 : 132;
    } else if (isSingleChar) {
      line1Size = state.shape == SealShape.round ? 154 : 168;
    }

    final previewPadding = isSingleChar ? 0.0 : 5.0;
    final previewScale = isSingleChar ? 1.14 : 1.08;
    final previewShiftY = hasLine2
        ? -2.0
        : isSingleChar
        ? -12.0
        : 0.0;
    final previewTitle = localizedUiText(locale, ja: 'プレビュー', en: 'Preview');
    final fontOptionsLabel = localizedUiText(
      locale,
      ja: 'フォント一覧',
      en: 'Font list',
    );
    final shapeLabel = localizedUiText(locale, ja: '形状', en: 'Shape');

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
                      ? BorderRadius.circular(18)
                      : null,
                  border: Border.all(color: HfPalette.accent, width: 4),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFCECE9)],
                  ),
                ),
                child: Padding(
                  padding: isSingleChar
                      ? const EdgeInsets.fromLTRB(4, 2, 4, 8)
                      : EdgeInsets.all(previewPadding),
                  child: Transform.translate(
                    offset: Offset(0, previewShiftY),
                    child: Transform.scale(
                      scale: previewScale,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            line1,
                            style: _stampFontStyle(
                              family: state.selectedFont.family,
                              size: line1Size,
                            ),
                          ),
                          if (hasLine2) const SizedBox(height: 2),
                          if (hasLine2)
                            Text(
                              line2,
                              style: _stampFontStyle(
                                family: state.selectedFont.family,
                                size: line2Size,
                              ),
                            ),
                        ],
                      ),
                    ),
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
            Text(
              shapeLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SealShape.values
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
                        ja: '形状を変えると、対応する材質へ自動で切り替わることがあります。',
                        en: 'Changing the shape may automatically switch the material to a compatible option.',
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
      final message = state.suggestionsError.isEmpty
          ? localizedUiText(
              state.locale,
              ja: '本名を入力して候補を生成してください。',
              en: 'Enter your name to generate suggestions.',
            )
          : state.suggestionsError;
      final color = state.suggestionsError.isEmpty
          ? HfPalette.muted
          : const Color(0xFF8F2219);
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

class _MaterialStep extends StatelessWidget {
  const _MaterialStep({
    super.key,
    required this.locale,
    required this.state,
    required this.onSelectMaterial,
    required this.onPrev,
    required this.onNext,
  });

  final String locale;
  final OrderScreenState state;
  final ValueChanged<String> onSelectMaterial;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final title = isEnglishLocale(locale) ? 'Choose Material' : '材質を選ぶ';
    final subtitle = isEnglishLocale(locale)
        ? 'Compare texture, weight, use, and price to pick your material. If you change the shape, the material may switch to a compatible option automatically.'
        : '質感・重さ・用途と価格を見ながら材質を決めます。形状を変えた場合は、対応する材質へ自動で切り替わることがあります。';
    final backLabel = isEnglishLocale(locale) ? 'Back' : '戻る';
    final nextLabel = isEnglishLocale(locale) ? 'Next: Purchase' : '購入へ進む';

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

            Widget buildComparisonSection(List<_MaterialComparisonFact> facts) {
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: facts
                      .asMap()
                      .entries
                      .map((entry) {
                        final fact = entry.value;
                        final isLast = entry.key == facts.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: HfPalette.line),
                              color: const Color(0xFFFDF9F4),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    fact.label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: HfPalette.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    fact.value,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: HfPalette.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              }

              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: facts
                    .map((fact) => _ComparisonBadge(fact: fact))
                    .toList(growable: false),
              );
            }

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: state.visibleMaterials
                  .map((material) {
                    final selected = material.key == state.selectedMaterial.key;
                    return GestureDetector(
                      onTap: () => onSelectMaterial(material.key),
                      child: Container(
                        width: itemWidth,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? HfPalette.accent : HfPalette.line,
                            width: selected ? 1.4 : 1,
                          ),
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.all(compact ? 14 : 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: material.hasPhoto
                                  ? Image.network(
                                      material.photoUrl,
                                      height: compact ? 152 : 130,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: compact ? 152 : 130,
                                        color: HfPalette.bgMain,
                                      ),
                                    )
                                  : Container(
                                      height: compact ? 152 : 130,
                                      color: HfPalette.bgMain,
                                    ),
                            ),
                            SizedBox(height: compact ? 12 : 10),
                            Text(
                              material.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: compact ? 16 : 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              material.shapeLabel,
                              style: TextStyle(
                                fontSize: compact ? 13.5 : 13,
                                color: HfPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              material.description,
                              style: TextStyle(
                                fontSize: compact ? 13.5 : 13,
                                height: 1.4,
                                color: HfPalette.muted,
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 8),
                            Text(
                              isEnglishLocale(locale) ? 'Comparison' : '比較ポイント',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: HfPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            buildComparisonSection(
                              _materialComparisonFacts(material, locale),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatMoney(
                                material.price,
                                state.effectiveCurrency,
                              ),
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
                  })
                  .toList(growable: false),
            );
          },
        ),
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
  final void Function(String? sessionId, String? orderId) onOpenPaymentSuccess;
  final ValueChanged<String?> onOpenPaymentFailure;
  final bool showConfirmationLinks;

  @override
  Widget build(BuildContext context) {
    final title = isEnglishLocale(locale) ? 'Purchase' : '購入';
    final subtitle = isEnglishLocale(locale)
        ? 'Review details, then proceed to Stripe Checkout.'
        : '内容を確認して、Stripe Checkout へ進みます。';
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
              child: DropdownButtonFormField<String>(
                key: ValueKey('country_${state.selectedCountry.code}'),
                initialValue: state.selectedCountry.code,
                items: state.catalog.countries
                    .map(
                      (country) => DropdownMenuItem(
                        value: country.code,
                        child: Text('${country.label} (${country.code})'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (code) {
                  if (code != null) {
                    onCountryChanged(code);
                  }
                },
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
    final materialLabel = localizedUiText(locale, ja: '材質', en: 'Material');
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
              label: materialLabel,
              value: state.selectedMaterial.label,
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
    final termsLabel = localizedUiText(
      locale,
      ja: '利用規約に同意する',
      en: 'I agree to the terms of service',
    );
    final helperText = localizedUiText(
      locale,
      ja: '注文作成後、Stripe Checkout に遷移します。',
      en: 'After the order is created, you will be redirected to Stripe Checkout.',
    );
    final submitLabel = localizedUiText(
      locale,
      ja: '支払いへ進む',
      en: 'Proceed to payment',
    );
    final submittingLabel = localizedUiText(
      locale,
      ja: '処理中...',
      en: 'Processing...',
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
                Expanded(child: Text(termsLabel)),
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

@immutable
class _MaterialComparisonFact {
  const _MaterialComparisonFact({required this.label, required this.value});

  final String label;
  final String value;
}

class _ComparisonBadge extends StatelessWidget {
  const _ComparisonBadge({required this.fact});

  final _MaterialComparisonFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HfPalette.line),
        color: const Color(0xFFFDF9F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fact.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: HfPalette.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fact.value,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: HfPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

List<_MaterialComparisonFact> _materialComparisonFacts(
  MaterialOption material,
  String locale,
) {
  final english = isEnglishLocale(locale);

  return switch (material.key) {
    'boxwood' => [
      _MaterialComparisonFact(
        label: english ? 'Texture' : '質感',
        value: english ? 'Dry wood grain' : 'さらりとした木目',
      ),
      _MaterialComparisonFact(
        label: english ? 'Weight' : '重さ',
        value: english ? 'Light and easy to handle' : '軽めで扱いやすい',
      ),
      _MaterialComparisonFact(
        label: english ? 'Use' : '用途',
        value: english ? 'Everyday square seals' : '日常使いの角印向き',
      ),
    ],
    'black_buffalo' => [
      _MaterialComparisonFact(
        label: english ? 'Texture' : '質感',
        value: english ? 'Smooth and slightly glossy' : 'しっとりした艶感',
      ),
      _MaterialComparisonFact(
        label: english ? 'Weight' : '重さ',
        value: english ? 'Medium weight with stability' : '中量で安定感がある',
      ),
      _MaterialComparisonFact(
        label: english ? 'Use' : '用途',
        value: english ? 'A safe choice for round seals' : '丸印の定番として選びやすい',
      ),
    ],
    'titanium' => [
      _MaterialComparisonFact(
        label: english ? 'Texture' : '質感',
        value: english ? 'Crisp metallic finish' : '金属らしいシャープな質感',
      ),
      _MaterialComparisonFact(
        label: english ? 'Weight' : '重さ',
        value: english ? 'Heavy and dense' : '重めで高密度',
      ),
      _MaterialComparisonFact(
        label: english ? 'Use' : '用途',
        value: english ? 'Long-term durable use' : '長期使用や耐久性重視に向く',
      ),
    ],
    _ => [
      _MaterialComparisonFact(
        label: english ? 'Texture' : '質感',
        value: english ? 'Balanced texture' : '標準的な質感',
      ),
      _MaterialComparisonFact(
        label: english ? 'Weight' : '重さ',
        value: english ? 'Medium weight' : '中程度の重さ',
      ),
      _MaterialComparisonFact(
        label: english ? 'Use' : '用途',
        value: english ? 'General-purpose use' : '汎用的',
      ),
    ],
  };
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: HfPalette.accent2,
            ),
          ),
          const SizedBox(height: 6),
          Text('$sourceLabel: ${result.sourceLabel}'),
          Text('$orderIdLabel: ${result.orderId}'),
          Text('$checkoutLabel: ${result.checkoutSessionId}'),
          Text(
            '$sealLabel: ${result.sealLine1}${hasLine2 ? ' / ${result.sealLine2}' : ''}',
          ),
          Text(
            '${result.shapeLabel} / ${result.materialLabel} / ${result.fontLabel}',
          ),
          Text(
            '$shippingLabel: ${result.countryLabel} / ${result.stripeName} / ${result.stripePhone}',
          ),
          Text(
            '$addressLabel: ${result.postalCode} ${result.state} ${result.city} '
            '${result.addressLine1}${hasAddress2 ? ' ${result.addressLine2}' : ''}',
          ),
          Text(
            '$subtotalLabel: ${formatMoney(result.subtotal, result.currency)} / '
            '${localizedUiText(locale, ja: '送料', en: 'Shipping')}: ${formatMoney(result.shipping, result.currency)} / '
            '$totalLabel: ${formatMoney(result.total, result.currency)}',
          ),
          Text('$emailLabel: ${result.email}'),
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

TextStyle _stampFontStyle({
  required String family,
  required double size,
  Color color = HfPalette.accent,
}) {
  final base = TextStyle(
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w700,
    height: 0.9,
  );

  final primaryFont = _extractPrimaryFontName(family);
  try {
    return GoogleFonts.getFont(primaryFont, textStyle: base);
  } catch (_) {
    return base;
  }
}

String _extractPrimaryFontName(String family) {
  final primary = family.split(',').first.trim();
  return primary.replaceAll("'", '').replaceAll('"', '').trim();
}
