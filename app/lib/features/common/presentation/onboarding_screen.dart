import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';

typedef OnboardingCompletionWriter = Future<void> Function();

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final OnboardingCompletionWriter onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  var _isCompleting = false;
  String? _errorMessage;

  Future<void> _complete() async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
      _errorMessage = null;
    });

    try {
      await widget.onComplete();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCompleting = false;
        _errorMessage = context.l10n.onboardingSaveError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: HankoColors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 432),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 400;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 24 : 31,
                      28,
                      compact ? 24 : 31,
                      HankoSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _OnboardingBrand(),
                        SizedBox(height: compact ? 42 : 58),
                        _OnboardingHero(compact: compact),
                        SizedBox(height: compact ? 36 : 50),
                        _OnboardingStepList(compact: compact),
                        const SizedBox(height: HankoSpacing.lg),
                        const _LocalStorageNotice(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: HankoSpacing.md),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: HankoTextStyles.compactBody.copyWith(
                              color: HankoColors.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: HankoSpacing.lg),
                        HankoPrimaryButton(
                          label: _isCompleting
                              ? l10n.onboardingSaving
                              : l10n.onboardingGetStarted,
                          onPressed: _isCompleting ? null : _complete,
                        ),
                        const SizedBox(height: HankoSpacing.sm),
                        TextButton(
                          onPressed: _isCompleting ? null : _complete,
                          child: Text(l10n.onboardingSkip),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingBrand extends StatelessWidget {
  const _OnboardingBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomPaint(size: const Size(34, 40), painter: _BrandDiamondPainter()),
        const SizedBox(width: HankoSpacing.sm),
        const Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Stone Signature',
              maxLines: 1,
              style: TextStyle(
                color: HankoColors.red,
                fontFamily: HankoFonts.serif,
                fontSize: 31,
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: compact ? 285 : 316,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -68 : -84,
            top: compact ? -8 : -24,
            child: Transform.rotate(
              angle: -0.72,
              child: const _OnboardingStamp(),
            ),
          ),
          Positioned(
            left: 0,
            top: compact ? 44 : 58,
            width: compact ? 262 : 300,
            child: Text(
              l10n.onboardingHeroTitle,
              style: HankoTextStyles.heroTitle.copyWith(
                fontSize: compact ? 45 : 52,
                height: 1.05,
              ),
            ),
          ),
          const Positioned(left: 0, top: 185, child: _Ornament()),
          Positioned(
            left: 0,
            top: 225,
            child: Text(l10n.onboardingTagline, style: HankoTextStyles.body),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStamp extends StatelessWidget {
  const _OnboardingStamp();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      height: 278,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 78,
              height: 174,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(39),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5B2A15), Color(0xFFB56934)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            child: Container(
              width: 112,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD7A35C), Color(0xFFF6D8A0)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2A57200E),
                    blurRadius: 18,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 154,
              height: 154,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.24, -0.32),
                  colors: [
                    Color(0xFFC6332B),
                    Color(0xFF8B1618),
                    Color(0xFF3A0808),
                  ],
                  stops: [0.0, 0.63, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40B8894B),
                    blurRadius: 0,
                    spreadRadius: 9,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 106,
                  height: 106,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xD6D7A35C)),
                  ),
                  child: const Center(
                    child: Text(
                      '永',
                      style: TextStyle(
                        color: Color(0xFFF6D68F),
                        fontFamily: HankoFonts.serif,
                        fontSize: 52,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepList extends StatelessWidget {
  const _OnboardingStepList({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      _StepData(
        icon: const Text(
          '永',
          style: TextStyle(
            color: HankoColors.red,
            fontFamily: HankoFonts.serif,
            fontSize: 38,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        title: l10n.onboardingKanjiTitle,
        message: l10n.onboardingKanjiMessage,
      ),
      _StepData(
        icon: const Icon(
          Icons.auto_awesome_outlined,
          color: HankoColors.red,
          size: 42,
        ),
        title: l10n.onboardingAiTitle,
        message: l10n.onboardingAiMessage,
      ),
      _StepData(
        icon: const Icon(
          Icons.diamond_outlined,
          color: HankoColors.red,
          size: 43,
        ),
        title: l10n.onboardingStoneTitle,
        message: l10n.onboardingStoneMessage,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          _OnboardingStep(data: steps[index], compact: compact),
          if (index != steps.length - 1)
            SizedBox(height: compact ? HankoSpacing.lg : HankoSpacing.xl),
        ],
      ],
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({required this.data, required this.compact});

  final _StepData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 58 : 70,
          height: compact ? 58 : 70,
          decoration: const BoxDecoration(
            color: HankoColors.medallion,
            shape: BoxShape.circle,
          ),
          child: Center(child: data.icon),
        ),
        const SizedBox(width: HankoSpacing.lg),
        Container(width: 1, height: compact ? 62 : 68, color: HankoColors.gold),
        const SizedBox(width: HankoSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.title, style: HankoTextStyles.cardTitle),
              const SizedBox(height: HankoSpacing.sm),
              Text(data.message, style: HankoTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocalStorageNotice extends StatelessWidget {
  const _LocalStorageNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HankoSurfaceCard(
      padding: const EdgeInsets.all(HankoSpacing.md),
      radius: HankoRadii.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: HankoColors.gold, size: 24),
          const SizedBox(width: HankoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.onboardingStorageTitle, style: HankoTextStyles.label),
                const SizedBox(height: HankoSpacing.xs),
                Text(
                  l10n.onboardingStorageMessage,
                  style: HankoTextStyles.compactBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 76, height: 1, color: HankoColors.gold),
        const SizedBox(width: HankoSpacing.md),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              border: Border.all(color: HankoColors.gold, width: 2),
            ),
          ),
        ),
        const SizedBox(width: HankoSpacing.md),
        Container(width: 76, height: 1, color: HankoColors.gold),
      ],
    );
  }
}

class _BrandDiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HankoColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final top = Offset(size.width / 2, 0);
    final leftMid = Offset(0, size.height * 0.48);
    final rightMid = Offset(size.width, size.height * 0.48);
    final bottom = Offset(size.width / 2, size.height);
    final center = Offset(size.width / 2, size.height * 0.48);

    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(leftMid.dx, leftMid.dy)
        ..lineTo(center.dx, center.dy)
        ..lineTo(top.dx, top.dy)
        ..moveTo(top.dx, top.dy)
        ..lineTo(rightMid.dx, rightMid.dy)
        ..lineTo(center.dx, center.dy)
        ..moveTo(leftMid.dx, leftMid.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(rightMid.dx, rightMid.dy)
        ..moveTo(top.dx, top.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..moveTo(leftMid.dx, leftMid.dy)
        ..lineTo(rightMid.dx, rightMid.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _StepData {
  const _StepData({
    required this.icon,
    required this.title,
    required this.message,
  });

  final Widget icon;
  final String title;
  final String message;
}
