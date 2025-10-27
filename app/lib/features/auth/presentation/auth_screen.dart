import 'dart:async';

import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/features/auth/application/auth_controller.dart';
import 'package:app/features/auth/application/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.onStatusRefresh,
    this.onBypass,
    this.nextPath,
  });

  final VoidCallback? onStatusRefresh;
  final VoidCallback? onBypass;
  final String? nextPath;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _passwordFocusNode;

  @override
  void initState() {
    super.initState();
    final initialState = ref.read(authControllerProvider);
    _emailController = TextEditingController(text: initialState.email);
    _passwordController = TextEditingController(text: initialState.password);
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    if (_emailController.text != authState.email) {
      _emailController.value = _emailController.value.copyWith(
        text: authState.email,
        selection: TextSelection.collapsed(offset: authState.email.length),
        composing: TextRange.empty,
      );
    }
    if (_passwordController.text != authState.password) {
      _passwordController.value = _passwordController.value.copyWith(
        text: authState.password,
        selection: TextSelection.collapsed(offset: authState.password.length),
        composing: TextRange.empty,
      );
    }

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final message = next.errorMessage;
      final previousMessage = previous?.errorMessage;
      if (!mounted || message == null || message.isEmpty) {
        return;
      }
      if (message == previousMessage) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(label: '閉じる', onPressed: () {}),
          ),
        );
      controller.clearError();
    });

    void unfocus() => FocusScope.of(context).unfocus();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        toolbarHeight: 88,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hanko Field',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'アカウントにサインイン',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.nextPath != null) ...[
              const SizedBox(height: 6),
              Chip(
                avatar: const Icon(Icons.arrow_forward),
                label: Text('完了後に ${widget.nextPath} へ移動します'),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'ヘルプ',
            onPressed: () => showHelpOverlay(context, contextLabel: 'サインイン'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'お気に入りの印影や注文履歴を同期するにはサインインしてください。',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _ProviderButton(
                    label: 'Apple で続行',
                    icon: Icons.apple,
                    onPressed: () {
                      unfocus();
                      unawaited(controller.signInWithApple());
                    },
                    busy: authState.activeAction == AuthAction.apple,
                    enabled: !authState.isProcessing,
                  ),
                  const SizedBox(height: 12),
                  _ProviderButton(
                    label: 'Google で続行',
                    icon: Icons.g_mobiledata,
                    onPressed: () {
                      unfocus();
                      unawaited(controller.signInWithGoogle());
                    },
                    busy: authState.activeAction == AuthAction.google,
                    enabled: !authState.isProcessing,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.alternate_email),
                    label: Text(
                      authState.emailFormExpanded
                          ? 'メールサインインを閉じる'
                          : 'メールアドレスでサインイン',
                    ),
                    onPressed: () {
                      unfocus();
                      controller.toggleEmailForm();
                    },
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _EmailSignInForm(
                        emailController: _emailController,
                        passwordController: _passwordController,
                        passwordFocusNode: _passwordFocusNode,
                        state: authState,
                        onEmailChanged: controller.updateEmail,
                        onPasswordChanged: controller.updatePassword,
                        onSubmit: () {
                          unfocus();
                          unawaited(controller.signInWithEmail());
                        },
                        onTogglePasswordVisibility:
                            controller.togglePasswordVisibility,
                      ),
                    ),
                    crossFadeState: authState.emailFormExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    icon: const Icon(Icons.person_outline),
                    label: const Text('ゲストとして続行'),
                    onPressed: authState.isProcessing
                        ? null
                        : () {
                            unfocus();
                            unawaited(controller.continueAsGuest());
                          },
                  ),
                  const SizedBox(height: 24),
                  if (widget.onStatusRefresh != null || widget.onBypass != null)
                    const Divider(),
                  if (widget.onStatusRefresh != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('サインイン状態を再チェック'),
                      onPressed: authState.isProcessing
                          ? null
                          : () {
                              unfocus();
                              widget.onStatusRefresh?.call();
                            },
                    ),
                  ],
                  if (widget.onBypass != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: authState.isProcessing
                          ? null
                          : widget.onBypass,
                      child: const Text('デバッグ: スキップ'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailSignInForm extends StatelessWidget {
  const _EmailSignInForm({
    required this.emailController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.state,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
    required this.onTogglePasswordVisibility,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final AuthState state;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePasswordVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: emailController,
            autofillHints: const [AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: onEmailChanged,
            onSubmitted: (_) => passwordFocusNode.requestFocus(),
            decoration: InputDecoration(
              labelText: 'メールアドレス',
              prefixIcon: const Icon(Icons.mail_outline),
              helperText:
                  state.emailDirty && state.emailValidationMessage == null
                  ? '例: user@example.com'
                  : null,
              errorText: state.emailValidationMessage,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            autofillHints: const [AutofillHints.password],
            obscureText: !state.isPasswordVisible,
            focusNode: passwordFocusNode,
            textInputAction: TextInputAction.done,
            onChanged: onPasswordChanged,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'パスワード',
              prefixIcon: const Icon(Icons.lock_outline),
              helperText:
                  state.passwordDirty && state.passwordValidationMessage == null
                  ? '8文字以上'
                  : null,
              errorText: state.passwordValidationMessage,
              suffixIcon: IconButton(
                tooltip: state.isPasswordVisible ? 'パスワードを隠す' : 'パスワードを表示',
                icon: Icon(
                  state.isPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: onTogglePasswordVisibility,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isProcessing ? null : onSubmit,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.activeAction == AuthAction.email) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(Icons.login),
                  const SizedBox(width: 12),
                ],
                const Text('メールアドレスで続行'),
              ],
            ),
          ),
        ],
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
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilledButton.tonal(
      onPressed: enabled ? onPressed : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (busy) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
