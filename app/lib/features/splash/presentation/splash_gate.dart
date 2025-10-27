import 'package:app/features/splash/application/splash_controller.dart';
import 'package:app/features/splash/domain/startup_decision.dart';
import 'package:app/features/splash/presentation/splash_screen.dart';
import 'package:app/features/splash/presentation/startup_blocking_screens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate>
    with WidgetsBindingObserver {
  bool _shellUnlocked = false;
  bool _authBypassed = false;
  bool _updateBypassed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(splashControllerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(splashControllerProvider);
    return startup.when(
      data: (decision) => _buildDecision(context, decision),
      loading: () => _shellUnlocked ? widget.child : const SplashScreen(),
      error: (error, stack) => StartupErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(splashControllerProvider),
      ),
    );
  }

  Widget _buildDecision(BuildContext context, SplashRouteState decision) {
    switch (decision.destination) {
      case SplashDestination.appUpdate:
        if (_updateBypassed) {
          _markShellUnlocked(true);
          return widget.child;
        }
        _markShellUnlocked(false);
        return AppUpdateRequiredScreen(
          status: decision.versionStatus,
          onRetry: () => ref.invalidate(splashControllerProvider),
          onBypass: kDebugMode ? _handleUpdateBypass : null,
        );
      case SplashDestination.onboarding:
        _markShellUnlocked(false);
        return OnboardingRequiredScreen(
          flags: decision.onboardingFlags,
          onCompleted: () => ref.invalidate(splashControllerProvider),
        );
      case SplashDestination.auth:
        if (_authBypassed) {
          _markShellUnlocked(true);
          return widget.child;
        }
        _markShellUnlocked(false);
        return AuthRequiredScreen(
          onRetry: () => ref.invalidate(splashControllerProvider),
          onBypass: kDebugMode ? _handleAuthBypass : null,
        );
      case SplashDestination.home:
        _markShellUnlocked(true);
        return widget.child;
    }
  }

  void _markShellUnlocked(bool unlocked) {
    if (_shellUnlocked == unlocked) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _shellUnlocked = unlocked;
      });
    });
  }

  void _handleAuthBypass() {
    setState(() {
      _authBypassed = true;
    });
  }

  void _handleUpdateBypass() {
    setState(() {
      _updateBypassed = true;
    });
  }
}
