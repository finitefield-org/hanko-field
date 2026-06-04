import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';

typedef HasSeenOnboardingResolver = Future<bool> Function();

enum AppLaunchDestination { onboarding, shell }

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.hasSeenOnboardingResolver,
    required this.onLaunchResolved,
    this.minimumDisplayDuration = const Duration(milliseconds: 700),
  });

  final HasSeenOnboardingResolver hasSeenOnboardingResolver;
  final ValueChanged<AppLaunchDestination> onLaunchResolved;
  final Duration minimumDisplayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolveLaunch();
  }

  Future<void> _resolveLaunch() async {
    final hasSeenFuture = widget.hasSeenOnboardingResolver();
    final minimumDelay = Future<void>.delayed(widget.minimumDisplayDuration);
    bool hasSeenOnboarding;
    try {
      hasSeenOnboarding = await hasSeenFuture;
    } catch (_) {
      hasSeenOnboarding = false;
    }
    await minimumDelay;

    if (!mounted) {
      return;
    }

    widget.onLaunchResolved(
      hasSeenOnboarding
          ? AppLaunchDestination.shell
          : AppLaunchDestination.onboarding,
    );
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
            colors: [Color(0xFFF5EEE7), Color(0xFFFFFCF8), Color(0xFFF3EADF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 432),
              child: Column(
                children: [
                  const Spacer(flex: 26),
                  const _SplashLogo(),
                  const SizedBox(height: 38),
                  const _SplashBrandTitle(),
                  const SizedBox(height: 24),
                  const _SplashDivider(),
                  const Spacer(flex: 19),
                  const SizedBox.square(
                    dimension: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.2,
                      color: HankoColors.gold,
                      backgroundColor: Color(0x47B8894B),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.splashPreparing,
                    textAlign: TextAlign.center,
                    style: HankoTextStyles.body.copyWith(
                      color: HankoColors.ink,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const Spacer(flex: 19),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x2639160E),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Image.asset(
        'assets/site-logo.png',
        width: 146,
        height: 146,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _SplashBrandTitle extends StatelessWidget {
  const _SplashBrandTitle();

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stone', style: _brandTextStyle),
          SizedBox(width: 13),
          Text(
            'Signature',
            style: TextStyle(
              color: HankoColors.red,
              fontFamily: HankoFonts.serif,
              fontSize: 42,
              fontWeight: FontWeight.w500,
              height: 0.95,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

const _brandTextStyle = TextStyle(
  color: HankoColors.ink,
  fontFamily: HankoFonts.serif,
  fontSize: 42,
  fontWeight: FontWeight.w500,
  height: 0.95,
  letterSpacing: 0,
);

class _SplashDivider extends StatelessWidget {
  const _SplashDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 74, height: 1, color: HankoColors.gold),
        const SizedBox(width: 17),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              border: Border.all(color: HankoColors.gold, width: 2),
              color: const Color(0x85FFFFFF),
            ),
          ),
        ),
        const SizedBox(width: 17),
        Container(width: 74, height: 1, color: HankoColors.gold),
      ],
    );
  }
}
