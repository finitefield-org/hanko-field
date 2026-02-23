import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/theme/hf_theme.dart';
import '../../../app/widgets/app_settings_button.dart';
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
  final ValueChanged<String?> onOpenPaymentSuccess;
  final VoidCallback onOpenPaymentFailure;

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

    _orderStateSubscription ??= ref.listenManual<OrderScreenState>(
      orderViewModel,
      (previous, next) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checkout URL が不正です。')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checkout URL を開けませんでした。')));
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
      return const _CatalogLoadingPanel();
    }

    if (!state.hasCatalog) {
      return _CatalogErrorPanel(
        message: state.catalogError.isEmpty
            ? 'カタログを取得できませんでした。'
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
          child: _buildStepPanel(state),
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
      ),
    };
  }
}

class _CatalogLoadingPanel extends StatelessWidget {
  const _CatalogLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
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
            Text('カタログを読み込み中です...'),
          ],
        ),
      ),
    );
  }
}

class _CatalogErrorPanel extends StatelessWidget {
  const _CatalogErrorPanel({required this.message, required this.onRetry});

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
            OutlinedButton(onPressed: onRetry, child: const Text('再読み込み')),
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: borderColor),
                    color: backgroundColor,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
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
        final controls = _buildControls(context);
        final preview = _buildPreview(context);

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
          ],
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'お名前（印影テキスト）',
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
                  child: const Text('縦横変換'),
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
                      const Text(
                        '1行目',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: sealLine1Controller,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '1行目',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2行目',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: sealLine2Controller,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '2行目',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '1行目と2行目の合計2文字まで',
              style: TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
            const SizedBox(height: 4),
            Text(
              state.sealTextError,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8F2219)),
            ),
            const SizedBox(height: 10),
            const Text(
              'フォントスタイル',
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
            const Text(
              '漢字名提案は選択したスタイルに合わせて生成されます。',
              style: TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
            const SizedBox(height: 14),
            Container(
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
                  const Text(
                    '漢字名提案',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '本名',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: state.realName,
                    onChanged: onRealNameChanged,
                    decoration: const InputDecoration(
                      hintText: '例: Michael Smith',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '性別',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<CandidateGender>(
                    key: ValueKey(
                      'candidate_gender_${state.candidateGender.code}',
                    ),
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
                      state.isGeneratingSuggestions ? '生成中...' : '候補を生成',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SuggestionBox(
                    state: state,
                    onSelectSuggestion: onSelectSuggestion,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final line1 = state.sealLine1.isEmpty ? '印' : state.sealLine1;
    final line2 = state.sealLine2;
    final hasLine2 = line2.isNotEmpty;
    final isSingleChar = !hasLine2 && line1.characters.length == 1;
    final isSingleLine = !hasLine2 && line1.characters.length > 1;

    var line1Size = 72.0;
    var line2Size = 54.0;
    if (hasLine2) {
      line1Size = state.shape == SealShape.round ? 46 : 50;
      line2Size = state.shape == SealShape.round ? 46 : 50;
    } else if (isSingleLine) {
      line1Size = state.shape == SealShape.round ? 56 : 60;
    } else if (isSingleChar) {
      line1Size = state.shape == SealShape.round ? 68 : 74;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('プレビュー', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 260,
                height: 260,
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
            const SizedBox(height: 8),
            Text(
              '${state.shape.localizedPreviewLabel(locale)} / ${state.selectedFont.label}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: HfPalette.muted),
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFD8CCBC), height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.visibleFonts
                  .map((font) {
                    final selected = font.key == state.selectedFont.key;
                    final previewText = state.sealLine1.isEmpty
                        ? '印'
                        : state.sealLine2.isNotEmpty
                        ? '${state.sealLine1}\n${state.sealLine2}'
                        : state.sealLine1;
                    return GestureDetector(
                      onTap: () => onSelectFont(font.key),
                      child: Container(
                        width: 86,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? HfPalette.accent : HfPalette.line,
                            width: selected ? 1.4 : 1,
                          ),
                          color: selected
                              ? const Color(0xFFFFF7F5)
                              : Colors.white,
                        ),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFECE3D6)),
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
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: SealShape.values
                  .map((shape) {
                    return ChoiceChip(
                      label: Text(shape.localizedLabel(locale)),
                      selected: state.shape == shape,
                      onSelected: (_) => onSelectShape(shape),
                    );
                  })
                  .toList(growable: false),
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
      return const Text(
        '候補を生成しています...',
        style: TextStyle(fontSize: 13, color: HfPalette.muted),
      );
    }

    if (state.suggestions.isEmpty) {
      final message = state.suggestionsError.isEmpty
          ? '本名を入力して候補を生成してください。'
          : state.suggestionsError;
      final color = state.suggestionsError.isEmpty
          ? HfPalette.muted
          : const Color(0xFF8F2219);
      return Text(message, style: TextStyle(fontSize: 13, color: color));
    }

    final selected = state.selectedSuggestion;
    final readingText = selected == null
        ? '読み方'
        : state.kanjiStyle.isChineseStyle
        ? '読み方(拼音): ${normalizePinyinWithoutTone(selected.reading)}'
        : '読み方(ローマ字): ${selected.reading.toLowerCase()}';

    final reasonText = selected?.reason ?? '提案理由';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${state.realName.trim()} さんへの候補',
          style: const TextStyle(fontSize: 13),
        ),
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
        const Text(
          '候補をタップすると印影テキストに反映されます。',
          style: TextStyle(fontSize: 12, color: HfPalette.muted),
        ),
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
        ? 'Compare feel and price to pick your material.'
        : '使用感と価格を見ながら材質を決めます。';
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
            final spacing = 12.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

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
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: material.hasPhoto
                                  ? Image.network(
                                      material.photoUrl,
                                      height: 130,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 130,
                                        color: HfPalette.bgMain,
                                      ),
                                    )
                                  : Container(
                                      height: 130,
                                      color: HfPalette.bgMain,
                                    ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              material.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              material.shapeLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: HfPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              material.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: HfPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatMoney(
                                material.price,
                                state.effectiveCurrency,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
  final ValueChanged<String?> onOpenPaymentSuccess;
  final VoidCallback onOpenPaymentFailure;

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
        _buildPaymentCard(),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onPrev, child: Text(backLabel)),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'お届け先情報',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'お届け先氏名',
              child: TextFormField(
                initialValue: state.recipientName,
                onChanged: onRecipientNameChanged,
                decoration: const InputDecoration(hintText: '例: 山田 太郎'),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: 'メールアドレス',
              child: TextFormField(
                initialValue: state.email,
                onChanged: onEmailChanged,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'you@example.com'),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: '電話番号',
              child: TextFormField(
                initialValue: state.phone,
                onChanged: onPhoneChanged,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '+81 90 1234 5678'),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: '国 / Country',
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
              label: '郵便番号 / ZIP',
              child: TextFormField(
                initialValue: state.postalCode,
                onChanged: onPostalCodeChanged,
                decoration: const InputDecoration(hintText: '100-0001'),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: '都道府県 / 州',
              child: TextFormField(
                initialValue: state.stateName,
                onChanged: onStateChanged,
                decoration: const InputDecoration(hintText: '東京都'),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: '市区町村 / City',
              child: TextFormField(
                initialValue: state.city,
                onChanged: onCityChanged,
                decoration: const InputDecoration(hintText: '千代田区'),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: '住所1',
              child: TextFormField(
                initialValue: state.addressLine1,
                onChanged: onAddress1Changed,
                decoration: const InputDecoration(hintText: '丸の内1-1-1'),
              ),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: '住所2（任意）',
              child: TextFormField(
                initialValue: state.addressLine2,
                onChanged: onAddress2Changed,
                decoration: const InputDecoration(hintText: '建物名・部屋番号など'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '注文サマリー',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: '印影テキスト', value: state.sealDisplay),
            _SummaryRow(label: '形状', value: state.shape.localizedLabel(locale)),
            _SummaryRow(label: 'フォント', value: state.selectedFont.label),
            _SummaryRow(label: '材質', value: state.selectedMaterial.label),
            _SummaryRow(label: '配送先の国', value: state.selectedCountry.label),
            _SummaryRow(
              label: '商品価格',
              value: formatMoney(state.subtotal, state.effectiveCurrency),
            ),
            _SummaryRow(
              label: '送料',
              value: formatMoney(state.shipping, state.effectiveCurrency),
            ),
            _SummaryRow(
              label: '合計',
              value: formatMoney(state.total, state.effectiveCurrency),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    final result = state.purchaseResult;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'お支払い',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: state.termsAgreed,
                  onChanged: (checked) => onTermsChanged(checked ?? false),
                ),
                const Expanded(child: Text('利用規約に同意する')),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '注文作成後、Stripe Checkout に遷移します。',
              style: TextStyle(fontSize: 12, color: HfPalette.muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isSubmittingPurchase ? null : onSubmit,
                child: Text(state.isSubmittingPurchase ? '処理中...' : '支払いへ進む'),
              ),
            ),
            if (state.purchaseError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                state.purchaseError,
                style: const TextStyle(color: Color(0xFF8F2219), fontSize: 13),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 12),
              _PurchaseResultCard(
                result: result,
                onOpenPaymentSuccess: onOpenPaymentSuccess,
                onOpenPaymentFailure: onOpenPaymentFailure,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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

class _PurchaseResultCard extends StatelessWidget {
  const _PurchaseResultCard({
    required this.result,
    required this.onOpenPaymentSuccess,
    required this.onOpenPaymentFailure,
  });

  final PurchaseResultData result;
  final ValueChanged<String?> onOpenPaymentSuccess;
  final VoidCallback onOpenPaymentFailure;

  @override
  Widget build(BuildContext context) {
    final hasLine2 = result.sealLine2.isNotEmpty;
    final hasAddress2 = result.addressLine2.isNotEmpty;

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
          const Text(
            '注文を受け付けました',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: HfPalette.accent2,
            ),
          ),
          const SizedBox(height: 6),
          Text('データソース: ${result.sourceLabel}'),
          Text('注文ID: ${result.orderId}'),
          Text('Checkout Session ID: ${result.checkoutSessionId}'),
          Text(
            '印影: ${result.sealLine1}${hasLine2 ? ' / ${result.sealLine2}' : ''}',
          ),
          Text(
            '${result.shapeLabel} / ${result.materialLabel} / ${result.fontLabel}',
          ),
          Text(
            '配送先: ${result.countryLabel} / ${result.stripeName} / ${result.stripePhone}',
          ),
          Text(
            '住所: ${result.postalCode} ${result.state} ${result.city} '
            '${result.addressLine1}${hasAddress2 ? ' ${result.addressLine2}' : ''}',
          ),
          Text(
            '小計: ${formatMoney(result.subtotal, result.currency)} / '
            '送料: ${formatMoney(result.shipping, result.currency)} / '
            '合計: ${formatMoney(result.total, result.currency)}',
          ),
          Text('確認メール送信先: ${result.email}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => onOpenPaymentSuccess(result.checkoutSessionId),
                child: const Text('支払い成功画面へ（確認用）'),
              ),
              OutlinedButton(
                onPressed: onOpenPaymentFailure,
                child: const Text('支払い失敗画面へ（確認用）'),
              ),
            ],
          ),
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
    fontWeight: FontWeight.w500,
    height: 1,
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
