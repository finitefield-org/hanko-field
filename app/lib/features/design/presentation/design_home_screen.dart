import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';
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

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  void _handleNameChanged() {
    setState(() {});
  }

  void _submit() {
    final realName = _nameController.text.trim();
    if (realName.isEmpty) {
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
              const SizedBox(height: 26),
              HankoTextField(
                label: l10n.designNameLabel,
                hintText: l10n.designNameHint,
                controller: _nameController,
                keyboardType: TextInputType.name,
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
              HankoPrimaryButton(
                label: l10n.suggestKanji,
                onPressed: _canSubmit ? _submit : null,
              ),
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

class KanjiCandidateGenerationReadyScreen extends StatelessWidget {
  const KanjiCandidateGenerationReadyScreen({
    super.key,
    required this.request,
    required this.onBack,
    required this.onEdit,
  });

  final KanjiCandidatesRequest request;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DesignStepScaffold(
      title: l10n.designCandidateReadyTitle,
      onBack: onBack,
      children: [
        HankoSurfaceCard(
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SealMedallion(icon: Icons.task_alt)),
              const SizedBox(height: 24),
              Text(
                l10n.designCandidateReadyMessage,
                textAlign: TextAlign.center,
                style: HankoTextStyles.sectionTitle,
              ),
              const SizedBox(height: 26),
              Text(l10n.designRequestDetails, style: HankoTextStyles.label),
              const SizedBox(height: 14),
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
              const SizedBox(height: 24),
              HankoPrimaryButton(
                label: l10n.editName,
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ],
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
