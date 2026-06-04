import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';

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
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFDF9), Color(0xFFF8F2EA), Color(0xFFFFFAF4)],
            stops: [0, 0.52, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 432),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 400;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: compact ? 10 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _OnboardingBrand(compact: compact),
                            _OnboardingHero(compact: compact),
                            _OnboardingStepList(compact: compact),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: HankoSpacing.md),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 30 : 38.5,
                                ),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: HankoTextStyles.compactBody.copyWith(
                                    color: HankoColors.error,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: compact ? 18 : 36),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 30 : 38.5,
                              ),
                              child: _OnboardingPrimaryButton(
                                label: _isCompleting
                                    ? l10n.onboardingSaving
                                    : l10n.onboardingGetStarted,
                                onPressed: _isCompleting ? null : _complete,
                              ),
                            ),
                            SizedBox(height: compact ? 6 : 10),
                            TextButton(
                              onPressed: _isCompleting ? null : _complete,
                              style: TextButton.styleFrom(
                                foregroundColor: HankoColors.red,
                                disabledForegroundColor: HankoColors.body,
                                textStyle: HankoTextStyles.label.copyWith(
                                  fontSize: compact ? 14 : 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text(l10n.onboardingSkip),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingBrand extends StatelessWidget {
  const _OnboardingBrand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 22 : 24, 19, 24, 0),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(38, 38),
            painter: _BrandDiamondPainter(),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Transform.scale(
              scaleX: 0.86,
              alignment: Alignment.centerLeft,
              child: const Text(
                'Stone Signature',
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: Color(0xFF8D1018),
                  fontFamily: HankoFonts.serif,
                  fontSize: 27,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
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
      height: compact ? 292 : 300,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -26 : -34,
            top: compact ? -18 : -26,
            child: _OnboardingStampPhoto(
              width: compact ? 164 : 176.5,
              height: compact ? 325 : 350,
            ),
          ),
          Positioned(
            left: compact ? 30 : 33,
            top: compact ? 92 : 100,
            width: compact ? 360 : 390,
            child: Transform.scale(
              scaleX: 0.68,
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.onboardingHeroTitle,
                style: HankoTextStyles.heroTitle.copyWith(
                  fontSize: compact ? 46 : 50,
                  height: 1.01,
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 30 : 33,
            top: compact ? 218 : 224,
            child: const _Ornament(),
          ),
          Positioned(
            left: compact ? 30 : 33,
            top: compact ? 252 : 260,
            child: Text(l10n.onboardingTagline, style: HankoTextStyles.body),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStampPhoto extends StatelessWidget {
  const _OnboardingStampPhoto({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/design/com003_hero_seal.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.black, Colors.black],
          stops: [0, 0.16, 1],
        ).createShader(bounds);
      },
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0, 0.87, 1],
          ).createShader(bounds);
        },
        child: image,
      ),
    );
  }
}

class _OnboardingPrimaryButton extends StatelessWidget {
  const _OnboardingPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 60.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFFA31118), Color(0xFF951017)],
                )
              : const LinearGradient(
                  colors: [
                    HankoColors.surfaceBorder,
                    HankoColors.surfaceBorder,
                  ],
                ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x21790A10),
                    blurRadius: 34,
                    offset: Offset(0, 18),
                  ),
                ]
              : const [],
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: enabled ? Colors.white : HankoColors.body,
            disabledForegroundColor: HankoColors.body,
            padding: const EdgeInsets.symmetric(horizontal: 21),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  style: HankoTextStyles.buttonLabel.copyWith(fontSize: 22),
                ),
                const Positioned(
                  right: 0,
                  child: Icon(Icons.arrow_forward, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KanjiSealIcon extends StatelessWidget {
  const _KanjiSealIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _KanjiSealIconPainter(),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            '永',
            style: TextStyle(
              color: HankoColors.red,
              fontFamily: HankoFonts.serif,
              fontSize: size * 0.56,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _KanjiSealIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HankoColors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.42,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _SparkleStepIcon extends StatelessWidget {
  const _SparkleStepIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SparkleIconPainter());
  }
}

class _SparkleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HankoColors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    Path sparkle(double cx, double cy, double radius) {
      return Path()
        ..moveTo(cx, cy - radius)
        ..cubicTo(
          cx + radius * 0.24,
          cy - radius * 0.32,
          cx + radius * 0.32,
          cy - radius * 0.24,
          cx + radius,
          cy,
        )
        ..cubicTo(
          cx + radius * 0.32,
          cy + radius * 0.24,
          cx + radius * 0.24,
          cy + radius * 0.32,
          cx,
          cy + radius,
        )
        ..cubicTo(
          cx - radius * 0.24,
          cy + radius * 0.32,
          cx - radius * 0.32,
          cy + radius * 0.24,
          cx - radius,
          cy,
        )
        ..cubicTo(
          cx - radius * 0.32,
          cy - radius * 0.24,
          cx - radius * 0.24,
          cy - radius * 0.32,
          cx,
          cy - radius,
        );
    }

    canvas.drawPath(
      sparkle(size.width * 0.47, size.height * 0.47, size.width * 0.34),
      paint,
    );
    canvas.drawPath(
      sparkle(size.width * 0.78, size.height * 0.22, size.width * 0.12),
      paint,
    );
    canvas.drawPath(
      sparkle(size.width * 0.2, size.height * 0.75, size.width * 0.1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _GemstoneStepIcon extends StatelessWidget {
  const _GemstoneStepIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GemstoneIconPainter(),
    );
  }
}

class _GemstoneIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HankoColors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final topY = h * 0.28;
    final midY = h * 0.44;
    final bottomY = h * 0.82;
    final left = w * 0.17;
    final right = w * 0.83;
    final center = w * 0.5;
    final shoulder = w * 0.28;
    final upper = w * 0.72;

    canvas.drawPath(
      Path()
        ..moveTo(left, midY)
        ..lineTo(shoulder, topY)
        ..lineTo(upper, topY)
        ..lineTo(right, midY)
        ..lineTo(center, bottomY)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left, midY)
        ..lineTo(right, midY)
        ..moveTo(shoulder, topY)
        ..lineTo(center, bottomY)
        ..moveTo(upper, topY)
        ..lineTo(center, bottomY)
        ..moveTo(shoulder, topY)
        ..lineTo(center, midY)
        ..lineTo(upper, topY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _OnboardingStepList extends StatelessWidget {
  const _OnboardingStepList({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final iconSize = compact ? 38.0 : 45.0;
    final steps = [
      _StepData(
        icon: _KanjiSealIcon(size: iconSize),
        title: l10n.onboardingKanjiTitle,
        message: l10n.onboardingKanjiMessage,
      ),
      _StepData(
        icon: _SparkleStepIcon(size: iconSize),
        title: l10n.onboardingAiTitle,
        message: l10n.onboardingAiMessage,
      ),
      _StepData(
        icon: _GemstoneStepIcon(size: iconSize),
        title: l10n.onboardingStoneTitle,
        message: l10n.onboardingStoneMessage,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 30 : 46,
        compact ? 38 : 48,
        compact ? 26 : 38,
        0,
      ),
      child: Column(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            _OnboardingStep(data: steps[index], compact: compact),
            if (index != steps.length - 1) SizedBox(height: compact ? 22 : 30),
          ],
        ],
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({required this.data, required this.compact});

  final _StepData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = HankoTextStyles.cardTitle.copyWith(
      fontSize: compact ? 19.5 : 21,
      height: 1.06,
    );
    final bodyStyle = HankoTextStyles.body.copyWith(
      fontSize: compact ? 13.5 : 14,
      height: 1.62,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 56 : 70,
          height: compact ? 56 : 70,
          decoration: const BoxDecoration(
            color: Color(0xD1EDE4D8),
            shape: BoxShape.circle,
          ),
          child: Center(child: data.icon),
        ),
        SizedBox(width: compact ? 14 : 20),
        Container(width: 1, height: compact ? 62 : 67, color: HankoColors.gold),
        SizedBox(width: compact ? 14 : 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(data.title, maxLines: 1, style: titleStyle),
                ),
              ),
              const SizedBox(height: 12),
              Text(data.message, style: bodyStyle),
            ],
          ),
        ),
      ],
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
