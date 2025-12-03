// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/view_model/auth_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authViewModel);
    final state = authState.valueOrNull;
    final pendingLink = state?.pendingLink;
    final appleAvailable = state?.appleAvailable ?? false;

    final appleBusy = ref.watch(authViewModel.appleMut) is PendingMutationState;
    final googleBusy =
        ref.watch(authViewModel.googleMut) is PendingMutationState;
    final emailBusy = ref.watch(authViewModel.emailMut) is PendingMutationState;
    final guestBusy = ref.watch(authViewModel.guestMut) is PendingMutationState;
    final anyBusy = appleBusy || googleBusy || emailBusy || guestBusy;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              automaticallyImplyLeading: false,
              titleSpacing: tokens.spacing.lg,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(tokens.spacing.sm),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(tokens.radii.md),
                        ),
                        child: Icon(
                          Icons.approval_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.sm),
                      Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    l10n.authSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.authHelpTooltip,
                  icon: const Icon(Icons.help_center_outlined),
                  onPressed: anyBusy ? null : () => _showHelpSheet(context),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.lg,
                  vertical: tokens.spacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pendingLink != null)
                      _PendingLinkBanner(
                        linkContext: pendingLink,
                        onDismissed: anyBusy
                            ? null
                            : () =>
                                  ref.invoke(authViewModel.clearPendingLink()),
                      ),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(tokens.spacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.authTitle,
                              style: theme.textTheme.headlineSmall,
                            ),
                            SizedBox(height: tokens.spacing.sm),
                            Text(
                              l10n.authBody,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: tokens.spacing.lg),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    enabled: !anyBusy,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: InputDecoration(
                                      labelText: l10n.authEmailLabel,
                                      helperText: l10n.authEmailHelper,
                                    ),
                                    validator: (value) {
                                      final text = value?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return l10n.authEmailRequired;
                                      }
                                      final isValid = RegExp(
                                        r'.+@.+',
                                      ).hasMatch(text);
                                      if (!isValid) {
                                        return l10n.authEmailInvalid;
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: tokens.spacing.md),
                                  TextFormField(
                                    controller: _passwordController,
                                    enabled: !anyBusy,
                                    obscureText: _obscurePassword,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: l10n.authPasswordLabel,
                                      helperText: l10n.authPasswordHelper,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (value) {
                                      final text = value ?? '';
                                      if (text.length < 8) {
                                        return l10n.authPasswordTooShort;
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: tokens.spacing.md),
                                  FilledButton.icon(
                                    onPressed: anyBusy
                                        ? null
                                        : () => _submitEmail(),
                                    icon: emailBusy
                                        ? _BusyIcon(colorScheme.onSecondary)
                                        : const Icon(Icons.mail_outline),
                                    label: Text(l10n.authEmailCta),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: tokens.spacing.lg),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (appleAvailable)
                                  _ProviderButton(
                                    label: l10n.authAppleButton,
                                    icon: Icons.apple,
                                    onPressed: appleBusy || anyBusy
                                        ? null
                                        : () => _signInWithApple(),
                                    busy: appleBusy,
                                  ),
                                _ProviderButton(
                                  label: l10n.authGoogleButton,
                                  icon: Icons.g_translate,
                                  onPressed: googleBusy || anyBusy
                                      ? null
                                      : () => _signInWithGoogle(),
                                  busy: googleBusy,
                                ),
                              ],
                            ),
                            SizedBox(height: tokens.spacing.md),
                            TextButton.icon(
                              onPressed: guestBusy || anyBusy
                                  ? null
                                  : _continueAsGuest,
                              icon: guestBusy
                                  ? _BusyIcon(colorScheme.primary)
                                  : const Icon(Icons.airline_stops_outlined),
                              label: Text(l10n.authGuestCta),
                            ),
                            SizedBox(height: tokens.spacing.xs),
                            Text(
                              l10n.authGuestNote,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _submitEmail() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    try {
      await ref.invoke(
        authViewModel.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
      if (!mounted) return;
      _goNext();
    } on AuthException catch (e) {
      _showAuthError(e);
    } catch (_) {
      _showGenericError();
    }
  }

  Future<void> _signInWithApple() async {
    try {
      await ref.invoke(authViewModel.signInWithApple());
      if (!mounted) return;
      _goNext();
    } on AuthException catch (e) {
      _showAuthError(e);
    } catch (_) {
      _showGenericError();
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.invoke(authViewModel.signInWithGoogle());
      if (!mounted) return;
      _goNext();
    } on AuthException catch (e) {
      _showAuthError(e);
    } catch (_) {
      _showGenericError();
    }
  }

  Future<void> _continueAsGuest() async {
    try {
      await ref.invoke(authViewModel.continueAsGuest());
      if (!mounted) return;
      _goNext();
    } on AuthException catch (e) {
      _showAuthError(e);
    } catch (_) {
      _showGenericError();
    }
  }

  void _goNext() {
    context.go(AppRoutePaths.home);
  }

  void _showAuthError(AuthException exception) {
    final l10n = AppLocalizations.of(context);
    final providers = _formatProviders(
      l10n,
      exception.linkContext?.existingProviders ?? const <String>[],
    );
    final message = switch (exception.code) {
      AuthErrorCode.cancelled => l10n.authErrorCancelled,
      AuthErrorCode.network => l10n.authErrorNetwork,
      AuthErrorCode.invalidCredential => l10n.authErrorInvalid,
      AuthErrorCode.wrongPassword => l10n.authErrorWrongPassword,
      AuthErrorCode.weakPassword => l10n.authErrorWeakPassword,
      AuthErrorCode.appleUnavailable => l10n.authErrorAppleUnavailable,
      AuthErrorCode.accountExistsWithDifferentCredential => l10n.authErrorLink(
        providers,
      ),
      _ => l10n.authErrorUnknown,
    };

    _showSnackBar(message);
  }

  void _showGenericError() {
    final l10n = AppLocalizations.of(context);
    _showSnackBar(l10n.authErrorUnknown);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showHelpSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.authHelpTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              l10n.authHelpBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.busy,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.sm),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: busy ? _BusyIcon(colorScheme.onSecondaryContainer) : Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _BusyIcon extends StatelessWidget {
  const _BusyIcon(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator.adaptive(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class _PendingLinkBanner extends StatelessWidget {
  const _PendingLinkBanner({required this.linkContext, this.onDismissed});

  final AuthLinkContext linkContext;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final providers = _formatProviders(l10n, linkContext.existingProviders);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(bottom: tokens.spacing.md),
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radii.md),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_rounded, color: colorScheme.primary),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.authLinkingTitle, style: textTheme.titleSmall),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  l10n.authLinkPrompt(providers),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  linkContext.email,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (onDismissed != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismissed,
              tooltip: l10n.onboardingSkip,
            ),
        ],
      ),
    );
  }
}

String _formatProviders(AppLocalizations l10n, List<String> providerIds) {
  if (providerIds.isEmpty) return l10n.authProviderUnknown;

  String friendly(String id) {
    return switch (id) {
      'google.com' => l10n.authProviderGoogle,
      'apple.com' => l10n.authProviderApple,
      'password' => l10n.authProviderEmail,
      _ => l10n.authProviderUnknown,
    };
  }

  final names = providerIds.map(friendly).toSet().toList();
  return names.join(' / ');
}
