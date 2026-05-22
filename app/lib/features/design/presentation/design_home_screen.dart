import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';
import '../data/kanji_candidates_repository.dart';
import '../domain/kanji_candidate.dart';

class DesignHomeScreen extends StatelessWidget {
  const DesignHomeScreen({super.key, this.onOpenSettings, this.onStartDesign});

  final VoidCallback? onOpenSettings;
  final VoidCallback? onStartDesign;

  @override
  Widget build(BuildContext context) {
    return DesignStartScreen(
      onOpenSettings: onOpenSettings,
      onStartDesign: onStartDesign,
    );
  }
}

class DesignStartScreen extends StatelessWidget {
  const DesignStartScreen({super.key, this.onOpenSettings, this.onStartDesign});

  final VoidCallback? onOpenSettings;
  final VoidCallback? onStartDesign;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width < 410 ? 14.0 : 16.0;
        final cardGap = width < 410 ? 12.0 : 14.0;
        final heroHeight = width < 410 ? 372.0 : 386.0;
        final featureCardHeight = width < 410 ? 252.0 : 260.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                48,
                horizontalPadding,
                31,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DesignHeader(onOpenSettings: onOpenSettings),
                  const SizedBox(height: 17),
                  _HeroDesignCard(
                    height: heroHeight,
                    onStartDesign: onStartDesign,
                  ),
                  const SizedBox(height: 23),
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          title: l10n.savedSeals,
                          body: l10n.savedSealsDescription,
                          assetPath: 'assets/design/com003_saved_seal.png',
                          icon: _FeatureIcon.saved,
                          imageTop: 31,
                          imageRight: -2,
                          imageWidth: 108,
                          height: featureCardHeight,
                        ),
                      ),
                      SizedBox(width: cardGap),
                      Expanded(
                        child: _FeatureCard(
                          title: l10n.browseStones,
                          body: l10n.browseStonesDescription,
                          assetPath: 'assets/design/com003_gemstones.png',
                          icon: _FeatureIcon.diamond,
                          imageTop: 26,
                          imageRight: 0,
                          imageWidth: 123,
                          height: featureCardHeight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NameInputScreen extends StatefulWidget {
  const NameInputScreen({
    super.key,
    required this.onBack,
    required this.onSubmit,
  });

  final VoidCallback onBack;
  final ValueChanged<KanjiCandidatesRequest> onSubmit;

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final _nameController = TextEditingController();

  var _gender = KanjiCandidateGender.unspecified;
  var _kanjiStyle = KanjiNameStyle.japanese;
  var _showNameError = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    super.dispose();
  }

  bool get _isNameValid {
    final realName = _nameController.text.trim();
    return realName.isNotEmpty && realName.length <= 80;
  }

  void _handleNameChanged() {
    setState(() {});
  }

  void _submit() {
    final realName = _nameController.text.trim();
    if (!_isNameValid) {
      setState(() => _showNameError = true);
      return;
    }

    widget.onSubmit(
      KanjiCandidatesRequest(
        realName: realName,
        reasonLanguage: _reasonLanguageFor(context),
        gender: _gender,
        kanjiStyle: _kanjiStyle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DesignStepScaffold(
      title: l10n.designNameTitle,
      onBack: widget.onBack,
      children: [
        HankoSurfaceCard(
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SealMedallion()),
              const SizedBox(height: 22),
              const Center(child: _DividerMark()),
              const SizedBox(height: 26),
              Text(
                l10n.designNameIntro,
                textAlign: TextAlign.center,
                style: HankoTextStyles.sectionTitle,
              ),
              if (_showNameError && !_isNameValid) ...[
                const SizedBox(height: 18),
                _InlineAlert(message: l10n.designInvalidNameSummary),
              ],
              const SizedBox(height: 26),
              HankoTextField(
                label: l10n.designNameLabel,
                hintText: l10n.designNameHint,
                controller: _nameController,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                errorText: _showNameError && !_isNameValid
                    ? l10n.designInvalidNameMessage
                    : null,
              ),
              const SizedBox(height: 10),
              Text(l10n.designNameHelp, style: HankoTextStyles.compactBody),
              const SizedBox(height: 20),
              DropdownButtonFormField<KanjiCandidateGender>(
                initialValue: _gender,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.designGenderLabel),
                items: [
                  for (final gender in KanjiCandidateGender.values)
                    DropdownMenuItem(
                      value: gender,
                      child: Text(_genderLabel(l10n, gender)),
                    ),
                ],
                onChanged: (gender) {
                  if (gender == null) {
                    return;
                  }
                  setState(() => _gender = gender);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<KanjiNameStyle>(
                initialValue: _kanjiStyle,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.designKanjiStyleLabel,
                ),
                items: [
                  for (final style in KanjiNameStyle.values)
                    DropdownMenuItem(
                      value: style,
                      child: Text(_kanjiStyleLabel(l10n, style)),
                    ),
                ],
                onChanged: (style) {
                  if (style == null) {
                    return;
                  }
                  setState(() => _kanjiStyle = style);
                },
              ),
              const SizedBox(height: 24),
              HankoPrimaryButton(label: l10n.suggestKanji, onPressed: _submit),
            ],
          ),
        ),
        const SizedBox(height: 22),
        HankoSurfaceCard(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _TipBadge(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.designKanjiTipTitle,
                      style: HankoTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.designKanjiTipMessage,
                      style: HankoTextStyles.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class KanjiSuggestionLoadingScreen extends StatefulWidget {
  const KanjiSuggestionLoadingScreen({
    super.key,
    required this.request,
    required this.generateCandidates,
    required this.onLoaded,
    required this.onError,
    required this.onBack,
  });

  final KanjiCandidatesRequest request;
  final KanjiCandidatesGenerator generateCandidates;
  final ValueChanged<KanjiCandidatesResult> onLoaded;
  final ValueChanged<Object> onError;
  final VoidCallback onBack;

  @override
  State<KanjiSuggestionLoadingScreen> createState() =>
      _KanjiSuggestionLoadingScreenState();
}

class _KanjiSuggestionLoadingScreenState
    extends State<KanjiSuggestionLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    try {
      final result = await widget.generateCandidates(widget.request);
      if (!mounted) {
        return;
      }
      widget.onLoaded(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      widget.onError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DesignStepScaffold(
      title: l10n.designLoadingTitle,
      onBack: widget.onBack,
      children: [
        HankoSurfaceCard(
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SealMedallion(icon: Icons.search)),
              const SizedBox(height: 24),
              const Center(child: _DividerMark()),
              const SizedBox(height: 26),
              Text(
                l10n.designLoadingMessage,
                textAlign: TextAlign.center,
                style: HankoTextStyles.sectionTitle,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.designLoadingDetail,
                textAlign: TextAlign.center,
                style: HankoTextStyles.body,
              ),
              const SizedBox(height: 26),
              const Center(
                child: SizedBox.square(
                  dimension: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: HankoColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _RequestSummaryCard(request: widget.request),
            ],
          ),
        ),
      ],
    );
  }
}

class KanjiSuggestionsScreen extends StatelessWidget {
  const KanjiSuggestionsScreen({
    super.key,
    required this.result,
    required this.onBack,
  });

  final KanjiCandidatesResult result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DesignStepScaffold(
      title: l10n.kanjiSuggestionsTitle,
      onBack: onBack,
      children: [
        HankoSurfaceCard(
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SealMedallion(icon: Icons.auto_awesome)),
              const SizedBox(height: 22),
              const Center(child: _DividerMark()),
              const SizedBox(height: 26),
              Text(
                l10n.kanjiSuggestionsMessage,
                textAlign: TextAlign.center,
                style: HankoTextStyles.sectionTitle,
              ),
              const SizedBox(height: 24),
              for (final candidate in result.candidates) ...[
                _KanjiCandidateCard(candidate: candidate),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class KanjiSuggestionErrorScreen extends StatelessWidget {
  const KanjiSuggestionErrorScreen({
    super.key,
    required this.onRetry,
    required this.onBack,
    this.request,
  });

  final KanjiCandidatesRequest? request;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DesignStepScaffold(
      title: l10n.design,
      onBack: onBack,
      children: [
        _DesignStateCard(
          icon: Icons.error_outline,
          title: l10n.designSuggestionErrorTitle,
          message: l10n.designSuggestionErrorMessage,
          primaryLabel: l10n.tryAgain,
          onPrimary: onRetry,
          secondaryLabel: l10n.back,
          onSecondary: onBack,
          child: request == null
              ? null
              : _RequestSummaryCard(request: request!),
        ),
        const SizedBox(height: 22),
        _StateTipCard(message: l10n.designErrorTip),
      ],
    );
  }
}

class _KanjiCandidateCard extends StatelessWidget {
  const _KanjiCandidateCard({required this.candidate});

  final KanjiCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reason = candidate.reason.trim();
    final meaning = candidate.meaning?.trim();
    final strokeComplexity = candidate.strokeComplexity?.trim();
    final engravingSuitability = candidate.engravingSuitability?.trim();
    final impressions = candidate.impression
        .map((impression) => impression.trim())
        .where((impression) => impression.isNotEmpty)
        .toList(growable: false);
    final metrics = <({String label, String value})>[
      if (candidate.characterCount != null)
        (
          label: l10n.kanjiCharacterCountLabel,
          value: candidate.characterCount.toString(),
        ),
      if (strokeComplexity != null && strokeComplexity.isNotEmpty)
        (
          label: l10n.kanjiStrokeComplexityLabel,
          value: _candidateMetricLabel(context, strokeComplexity),
        ),
      if (engravingSuitability != null && engravingSuitability.isNotEmpty)
        (
          label: l10n.kanjiEngravingSuitabilityLabel,
          value: _candidateMetricLabel(context, engravingSuitability),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HankoColors.background.withValues(alpha: 0.56),
        border: Border.all(color: HankoColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: HankoColors.medallion,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 74,
                    child: Center(
                      child: Text(
                        candidate.kanji,
                        textAlign: TextAlign.center,
                        style: HankoTextStyles.sectionTitle.copyWith(
                          color: HankoColors.red,
                          fontSize: candidate.kanji.length <= 1 ? 36 : 28,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.kanjiReadingLabel,
                        style: HankoTextStyles.compactBody,
                      ),
                      const SizedBox(height: 4),
                      Text(candidate.reading, style: HankoTextStyles.cardTitle),
                      if (meaning != null && meaning.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _CandidateDetailLine(
                          label: l10n.kanjiMeaningLabel,
                          value: meaning,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (impressions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.kanjiImpressionLabel, style: HankoTextStyles.label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final impression in impressions)
                    _CandidatePill(label: impression),
                ],
              ),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CandidateDetailBlock(
                label: l10n.kanjiReasonLabel,
                value: reason,
              ),
            ],
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CandidateMetrics(metrics: metrics),
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateDetailLine extends StatelessWidget {
  const _CandidateDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: HankoTextStyles.label.copyWith(color: HankoColors.gold),
        ),
        Expanded(child: Text(value, style: HankoTextStyles.compactBody)),
      ],
    );
  }
}

class _CandidateDetailBlock extends StatelessWidget {
  const _CandidateDetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HankoTextStyles.label),
        const SizedBox(height: 8),
        Text(value, style: HankoTextStyles.compactBody),
      ],
    );
  }
}

class _CandidatePill extends StatelessWidget {
  const _CandidatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HankoColors.medallion,
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: HankoTextStyles.compactBody.copyWith(color: HankoColors.ink),
        ),
      ),
    );
  }
}

class _CandidateMetrics extends StatelessWidget {
  const _CandidateMetrics({required this.metrics});

  final List<({String label, String value})> metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: HankoColors.surfaceBorder, height: 1),
        const SizedBox(height: 10),
        for (final metric in metrics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(metric.label, style: HankoTextStyles.compactBody),
                ),
                const SizedBox(width: 12),
                Text(metric.value, style: HankoTextStyles.label),
              ],
            ),
          ),
      ],
    );
  }
}

class UnsupportedKanjiResultScreen extends StatelessWidget {
  const UnsupportedKanjiResultScreen({
    super.key,
    required this.request,
    required this.onRetry,
    required this.onEditName,
    required this.onBack,
  });

  final KanjiCandidatesRequest request;
  final VoidCallback onRetry;
  final VoidCallback onEditName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DesignStepScaffold(
      title: l10n.design,
      onBack: onBack,
      children: [
        _DesignStateCard(
          icon: Icons.search_off,
          title: l10n.designNoKanjiTitle,
          message: l10n.designNoKanjiMessage,
          primaryLabel: l10n.editName,
          onPrimary: onEditName,
          secondaryLabel: l10n.tryAgain,
          onSecondary: onRetry,
          child: _KanjiRulesList(),
        ),
        const SizedBox(height: 22),
        _StateTipCard(message: l10n.designNoKanjiTip),
      ],
    );
  }
}

class _DesignStateCard extends StatelessWidget {
  const _DesignStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.child,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _SealMedallion(icon: icon)),
          const SizedBox(height: 24),
          const Center(child: _DividerMark()),
          const SizedBox(height: 26),
          Text(
            title,
            textAlign: TextAlign.center,
            style: HankoTextStyles.sectionTitle,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: HankoTextStyles.body,
          ),
          if (child != null) ...[const SizedBox(height: 24), child!],
          const SizedBox(height: 24),
          HankoPrimaryButton(label: primaryLabel, onPressed: onPrimary),
          const SizedBox(height: 12),
          _SecondaryActionButton(label: secondaryLabel, onPressed: onSecondary),
        ],
      ),
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.request});

  final KanjiCandidatesRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HankoColors.background.withValues(alpha: 0.56),
        border: Border.all(color: HankoColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.designRequestDetails, style: HankoTextStyles.label),
                const SizedBox(height: 12),
                _RequestSummaryRow(
                  label: l10n.designNameLabel,
                  value: request.realName,
                ),
                _RequestSummaryRow(
                  label: l10n.designGenderLabel,
                  value: _genderLabel(l10n, request.gender),
                ),
                _RequestSummaryRow(
                  label: l10n.designKanjiStyleLabel,
                  value: _kanjiStyleLabel(l10n, request.kanjiStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KanjiRulesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = [
      (icon: Icons.looks_two_outlined, label: l10n.designNoKanjiRuleCharacters),
      (icon: Icons.auto_awesome, label: l10n.designNoKanjiRuleCommon),
      (
        icon: Icons.verified_user_outlined,
        label: l10n.designNoKanjiRuleEngraving,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HankoColors.background.withValues(alpha: 0.56),
        border: Border.all(color: HankoColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      child: Column(
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _SmallBadge(icon: rule.icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(rule.label, style: HankoTextStyles.body),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineAlert extends StatelessWidget {
  const _InlineAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F6),
        border: Border.all(color: HankoColors.error),
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: HankoColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: HankoTextStyles.label.copyWith(color: HankoColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateTipCard extends StatelessWidget {
  const _StateTipCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tipPrefix = context.l10n.locale.languageCode == 'ja'
        ? 'ヒント: '
        : 'Tip: ';

    return HankoSurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          const _SmallBadge(icon: Icons.tips_and_updates_outlined),
          const SizedBox(width: 16),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: tipPrefix,
                    style: HankoTextStyles.label.copyWith(
                      color: HankoColors.gold,
                    ),
                  ),
                  TextSpan(text: message),
                ],
              ),
              style: HankoTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HankoColors.medallion,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(icon, color: HankoColors.gold, size: 24),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: HankoColors.gold,
          side: const BorderSide(color: HankoColors.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HankoRadii.sm),
          ),
        ),
        child: Text(label, style: HankoTextStyles.buttonLabel),
      ),
    );
  }
}

class _RequestSummaryRow extends StatelessWidget {
  const _RequestSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: HankoTextStyles.compactBody),
          ),
          Expanded(child: Text(value, style: HankoTextStyles.label)),
        ],
      ),
    );
  }
}

class _DesignStepScaffold extends StatelessWidget {
  const _DesignStepScaffold({
    required this.title,
    required this.onBack,
    required this.children,
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width < 410 ? 14.0 : 16.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                48,
                horizontalPadding,
                31,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          onPressed: onBack,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          icon: const Icon(Icons.arrow_back_ios_new),
                          color: HankoColors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: HankoTextStyles.pageTitle.copyWith(
                              fontSize: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                  const SizedBox(height: 30),
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SealMedallion extends StatelessWidget {
  const _SealMedallion({this.icon = Icons.auto_awesome});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HankoColors.red,
        shape: BoxShape.circle,
        border: Border.all(color: HankoColors.gold, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26961B1D),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 92,
        child: Icon(icon, color: Colors.white, size: 42),
      ),
    );
  }
}

class _TipBadge extends StatelessWidget {
  const _TipBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: HankoColors.medallion,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 76,
        child: Icon(Icons.auto_awesome, color: HankoColors.gold, size: 34),
      ),
    );
  }
}

String _reasonLanguageFor(BuildContext context) {
  final languageCode = context.l10n.locale.languageCode;
  return languageCode == 'ja' ? 'ja' : 'en';
}

String _genderLabel(HankoLocalizations l10n, KanjiCandidateGender gender) {
  return switch (gender) {
    KanjiCandidateGender.unspecified => l10n.designGenderUnspecified,
    KanjiCandidateGender.male => l10n.designGenderMale,
    KanjiCandidateGender.female => l10n.designGenderFemale,
  };
}

String _kanjiStyleLabel(HankoLocalizations l10n, KanjiNameStyle style) {
  return switch (style) {
    KanjiNameStyle.japanese => l10n.designKanjiStyleJapanese,
    KanjiNameStyle.chinese => l10n.designKanjiStyleChinese,
    KanjiNameStyle.taiwanese => l10n.designKanjiStyleTaiwanese,
  };
}

String _candidateMetricLabel(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
  final isJapanese = context.l10n.locale.languageCode == 'ja';
  return switch (normalized) {
    'high' => isJapanese ? '高い' : 'High',
    'medium' => isJapanese ? '中' : 'Medium',
    'low' => isJapanese ? '低い' : 'Low',
    'simple' => isJapanese ? 'シンプル' : 'Simple',
    'complex' => isJapanese ? '複雑' : 'Complex',
    _ => normalized.isEmpty ? value : normalized,
  };
}

class _DesignHeader extends StatelessWidget {
  const _DesignHeader({required this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(l10n.design, style: HankoTextStyles.pageTitle)),
        IconButton(
          onPressed: onOpenSettings ?? () {},
          tooltip: l10n.settings,
          icon: const Icon(Icons.settings_outlined),
          color: HankoColors.gold,
          iconSize: 34,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      ],
    );
  }
}

class _HeroDesignCard extends StatelessWidget {
  const _HeroDesignCard({required this.height, required this.onStartDesign});

  final double height;
  final VoidCallback? onStartDesign;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoSurfaceCard(
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 28,
            right: -4,
            width: 198,
            child: _FadedAssetImage(
              assetPath: 'assets/design/com003_hero_seal.png',
            ),
          ),
          Positioned(
            left: 26,
            top: 67,
            width: 246,
            child: Text(
              l10n.createCustomSeal,
              softWrap: false,
              style: HankoTextStyles.heroTitle,
            ),
          ),
          const Positioned(left: 26, top: 174, child: _DividerMark()),
          Positioned(
            left: 27,
            top: 205,
            width: 215,
            child: Text(
              l10n.customSealDescription,
              style: HankoTextStyles.body,
            ),
          ),
          Positioned(
            left: 26,
            top: 282,
            width: 172,
            height: 52,
            child: HankoPrimaryButton(
              label: l10n.startDesigning,
              onPressed: onStartDesign,
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerMark extends StatelessWidget {
  const _DividerMark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GoldLine(),
        SizedBox(width: 10),
        _OutlinedDiamond(size: 10),
        SizedBox(width: 10),
        _GoldLine(),
      ],
    );
  }
}

class _GoldLine extends StatelessWidget {
  const _GoldLine();

  @override
  Widget build(BuildContext context) {
    return Container(width: 58, height: 1, color: HankoColors.gold);
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.body,
    required this.assetPath,
    required this.icon,
    required this.imageTop,
    required this.imageRight,
    required this.imageWidth,
    required this.height,
  });

  final String title;
  final String body;
  final String assetPath;
  final _FeatureIcon icon;
  final double imageTop;
  final double imageRight;
  final double imageWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      height: height,
      radius: HankoRadii.md,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: imageTop,
            right: imageRight,
            width: imageWidth,
            child: _FadedAssetImage(assetPath: assetPath),
          ),
          Positioned(
            left: 28,
            top: 29,
            width: 64,
            height: 64,
            child: _IconMedallion(icon: icon),
          ),
          Positioned(
            left: 20,
            right: 13,
            top: 141,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HankoTextStyles.cardTitle,
            ),
          ),
          Positioned(
            left: 20,
            right: 17,
            top: 177,
            child: Text(body, style: HankoTextStyles.compactBody),
          ),
          const Positioned(
            right: 24,
            bottom: 25,
            child: Icon(Icons.chevron_right, size: 31, color: HankoColors.gold),
          ),
        ],
      ),
    );
  }
}

class _FadedAssetImage extends StatelessWidget {
  const _FadedAssetImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0, 0.16, 1],
          colors: const [Colors.transparent, Colors.white, Colors.white],
        ).createShader(bounds);
      },
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class _IconMedallion extends StatelessWidget {
  const _IconMedallion({required this.icon});

  final _FeatureIcon icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HankoColors.medallion,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CustomPaint(
          size: const Size.square(34),
          painter: _FeatureIconPainter(icon),
        ),
      ),
    );
  }
}

class _OutlinedDiamond extends StatelessWidget {
  const _OutlinedDiamond({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.7853981634,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: HankoColors.gold, width: 1.5),
        ),
      ),
    );
  }
}

class _FeatureIconPainter extends CustomPainter {
  const _FeatureIconPainter(this.icon);

  final _FeatureIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HankoColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case _FeatureIcon.saved:
        final book = RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.13, size.height * 0.13, 22, 26),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(book, paint);
        canvas.drawLine(
          Offset(size.width * 0.26, size.height * 0.33),
          Offset(size.width * 0.13, size.height * 0.33),
          paint,
        );
        final bookmark = Path()
          ..moveTo(size.width * 0.70, size.height * 0.48)
          ..lineTo(size.width * 0.89, size.height * 0.48)
          ..lineTo(size.width * 0.89, size.height * 0.90)
          ..lineTo(size.width * 0.79, size.height * 0.82)
          ..lineTo(size.width * 0.70, size.height * 0.90)
          ..close();
        canvas.drawPath(bookmark, paint);
        break;
      case _FeatureIcon.diamond:
        final path = Path()
          ..moveTo(size.width * 0.50, size.height * 0.91)
          ..lineTo(size.width * 0.08, size.height * 0.35)
          ..lineTo(size.width * 0.25, size.height * 0.12)
          ..lineTo(size.width * 0.75, size.height * 0.12)
          ..lineTo(size.width * 0.92, size.height * 0.35)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(size.width * 0.08, size.height * 0.35),
          Offset(size.width * 0.92, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.25, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.91),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.75, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.91),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.39, size.height * 0.12),
          Offset(size.width * 0.30, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.61, size.height * 0.12),
          Offset(size.width * 0.70, size.height * 0.35),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FeatureIconPainter oldDelegate) {
    return oldDelegate.icon != icon;
  }
}

enum _FeatureIcon { saved, diamond }
