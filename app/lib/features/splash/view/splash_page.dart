// ignore_for_file: public_member_api_docs

import 'package:app/features/splash/view_model/splash_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(splashViewModel);
    final retryState = ref.watch(splashViewModel.retryMut);
    final isRetrying = retryState is PendingMutationState;
    final result = state.valueOrNull;
    final isError = state is AsyncError<SplashResult>;
    final isLoading = state is AsyncLoading<SplashResult>;
    final isComplete = result != null;

    if (isComplete && !_navigated) {
      _scheduleNavigation(result);
    }

    final showLoader = isLoading || isComplete || isRetrying;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BrandLockup(tokens: tokens, colorScheme: colorScheme),
                SizedBox(height: tokens.spacing.xl),
                if (showLoader) ...[
                  SizedBox(
                    width: tokens.spacing.xl,
                    height: tokens.spacing.xl,
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.md),
                  Text(
                    l10n.splashLoading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ] else if (isError) ...[
                  Text(
                    l10n.splashFailedTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    l10n.splashFailedMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: tokens.spacing.lg),
                  ElevatedButton.icon(
                    onPressed: isRetrying
                        ? null
                        : () => ref.invoke(splashViewModel.retry()),
                    icon: isRetrying
                        ? SizedBox(
                            width: tokens.spacing.md,
                            height: tokens.spacing.md,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(l10n.commonRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleNavigation(SplashResult result) {
    if (_navigated) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(result.targetRoute);
    });
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.tokens, required this.colorScheme});

  final DesignTokens tokens;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final displayStyle = Theme.of(context).textTheme.displaySmall;
    final iconSize = (displayStyle?.fontSize ?? 48) + 8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(tokens.spacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(tokens.radii.lg),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome,
            size: iconSize,
            color: colorScheme.primary,
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        Text(AppLocalizations.of(context).appTitle, style: displayStyle),
      ],
    );
  }
}
