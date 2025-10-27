import 'package:app/core/app_state/user_session.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/auth/presentation/auth_screen.dart';
import 'package:app/features/onboarding/application/onboarding_tutorial_controller.dart';
import 'package:app/features/onboarding/presentation/locale_selection_screen.dart';
import 'package:app/features/onboarding/presentation/onboarding_tutorial_screen.dart';
import 'package:app/features/onboarding/presentation/persona_selection_screen.dart';
import 'package:app/features/splash/domain/startup_decision.dart';
import 'package:clock/clock.dart' as clock_package;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppUpdateRequiredScreen extends StatelessWidget {
  const AppUpdateRequiredScreen({
    required this.status,
    required this.onRetry,
    this.onBypass,
    super.key,
  });

  final VersionGateStatus status;
  final VoidCallback onRetry;
  final VoidCallback? onBypass;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description =
        '現在のバージョン (${status.currentVersion.raw}) は最小要件 '
        '(${status.minimumSupportedVersion.raw}) を満たしていません。';
    return _BlockingLayout(
      icon: Icons.system_update_alt_outlined,
      title: '最新バージョンが必要です',
      description: description,
      primaryLabel: 'アップデートを確認',
      primaryAction: () => _showStoreRedirectSnackbar(context),
      secondaryLabel: '再チェック',
      secondaryAction: onRetry,
      tertiaryLabel: onBypass == null ? null : 'デバッグ: スキップ',
      tertiaryAction: onBypass,
      background: colorScheme.surface,
    );
  }

  void _showStoreRedirectSnackbar(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ストア遷移は後続タスクで実装予定です。')));
  }
}

class OnboardingRequiredScreen extends ConsumerStatefulWidget {
  const OnboardingRequiredScreen({
    required this.flags,
    required this.onCompleted,
    super.key,
  });

  final OnboardingFlags flags;
  final VoidCallback onCompleted;

  @override
  ConsumerState<OnboardingRequiredScreen> createState() =>
      _OnboardingRequiredScreenState();
}

class _OnboardingRequiredScreenState
    extends ConsumerState<OnboardingRequiredScreen> {
  late OnboardingFlags _flags = widget.flags;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant OnboardingRequiredScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flags != widget.flags) {
      _flags = widget.flags;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pendingSteps = _flags.stepCompletion.entries
        .where((entry) => entry.value == false)
        .map(
          (entry) => switch (entry.key) {
            OnboardingStep.tutorial => 'チュートリアル',
            OnboardingStep.locale => '言語・地域',
            OnboardingStep.persona => '利用スタイル',
            OnboardingStep.notifications => '通知設定',
          },
        )
        .toList();
    final subtitle = pendingSteps.isEmpty
        ? '初期設定を完了してください。'
        : '未完了のステップ: ${pendingSteps.join('、')}';

    final tutorialDone =
        _flags.stepCompletion[OnboardingStep.tutorial] ?? false;
    final localeDone = _flags.stepCompletion[OnboardingStep.locale] ?? false;
    final personaDone = _flags.stepCompletion[OnboardingStep.persona] ?? false;
    final notificationsDone =
        _flags.stepCompletion[OnboardingStep.notifications] ?? false;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '初回セットアップ',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _OnboardingStepCard(
                icon: Icons.menu_book_outlined,
                title: 'チュートリアル',
                description: 'アプリの流れを3ステップで紹介します。',
                completed: tutorialDone,
                busy: _busy,
                onPressed: tutorialDone ? null : _handleTutorial,
                actionLabel: '開始する',
              ),
              const SizedBox(height: 16),
              _OnboardingStepCard(
                icon: Icons.language_outlined,
                title: '言語と地域',
                description: '価格・ガイド・表記を選んだ言語に最適化します。',
                completed: localeDone,
                busy: _busy,
                onPressed: localeDone ? null : _handleLocale,
                actionLabel: '言語を選ぶ',
              ),
              const SizedBox(height: 16),
              _OnboardingStepCard(
                icon: Icons.person_outline,
                title: '利用スタイル',
                description: '日本のお客様/海外のお客様向けに導線を切り替えます。',
                completed: personaDone,
                busy: _busy,
                onPressed: personaDone ? null : _handlePersona,
                actionLabel: 'スタイルを選ぶ',
              ),
              const SizedBox(height: 16),
              _OnboardingStepCard(
                icon: Icons.notifications_active_outlined,
                title: '通知設定',
                description: '最新情報や出荷状況のお知らせを受け取れます。（後で変更可能）',
                completed: notificationsDone,
                busy: _busy,
                onPressed: notificationsDone ? null : _handleNotifications,
                secondaryAction: true,
                actionLabel: '後で設定',
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _handleCompleteForDebug,
                child: const Text('デバッグ: 全ステップ完了にする'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTutorial() async {
    setState(() => _busy = true);
    ref.invalidate(onboardingTutorialControllerProvider);
    final result = await Navigator.of(context).push<OnboardingTutorialOutcome>(
      MaterialPageRoute(builder: (_) => const OnboardingTutorialScreen()),
    );
    if (result != null && mounted) {
      await _refreshFlags();
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _handleLocale() async {
    setState(() => _busy = true);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LocaleSelectionScreen()),
    );
    if (result == true && mounted) {
      await _refreshFlags();
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _handlePersona() async {
    setState(() => _busy = true);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PersonaSelectionScreen()),
    );
    if (result == true && mounted) {
      await _refreshFlags();
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _handleNotifications() async {
    setState(() => _busy = true);
    final dataSource = await ref.read(onboardingLocalDataSourceProvider.future);
    await dataSource.updateStep(OnboardingStep.notifications);
    if (mounted) {
      await _refreshFlags();
      setState(() => _busy = false);
    }
  }

  Future<void> _handleCompleteForDebug() async {
    setState(() => _busy = true);
    final dataSource = await ref.read(onboardingLocalDataSourceProvider.future);
    final completed = OnboardingFlags(
      steps: {for (final step in OnboardingStep.values) step: true},
      updatedAt: clock_package.clock.now(),
    );
    await dataSource.replace(completed);
    if (mounted) {
      await _refreshFlags();
      setState(() => _busy = false);
    }
  }

  Future<void> _refreshFlags() async {
    final dataSource = await ref.read(onboardingLocalDataSourceProvider.future);
    final latest = await dataSource.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _flags = latest;
    });
    widget.onCompleted();
  }
}

class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.completed,
    required this.busy,
    this.onPressed,
    this.secondaryAction = false,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool completed;
  final bool busy;
  final VoidCallback? onPressed;
  final bool secondaryAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: completed ? 3 : 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (completed)
                  Chip(
                    label: const Text('完了'),
                    avatar: const Icon(Icons.check, size: 16),
                    labelStyle: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: colorScheme.primaryContainer,
                    elevation: 0,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (!completed)
              Align(
                alignment: Alignment.centerRight,
                child: secondaryAction
                    ? OutlinedButton(
                        onPressed: busy ? null : onPressed,
                        child: Text(actionLabel ?? '後で設定'),
                      )
                    : FilledButton(
                        onPressed: busy ? null : onPressed,
                        child: Text(actionLabel ?? '進む'),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class AuthRequiredScreen extends ConsumerWidget {
  const AuthRequiredScreen({required this.onRetry, this.onBypass, super.key});

  final VoidCallback onRetry;
  final VoidCallback? onBypass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<UserSessionState>>(userSessionProvider, (
      previous,
      next,
    ) {
      if (next.hasValue &&
          next.value?.status == UserSessionStatus.authenticated) {
        onRetry();
      }
    });

    return AuthScreen(onStatusRefresh: onRetry, onBypass: onBypass);
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _BlockingLayout(
      icon: Icons.error_outline,
      title: '初期化に失敗しました',
      description: error.toString(),
      primaryLabel: '再試行',
      primaryAction: onRetry,
    );
  }
}

class _BlockingLayout extends StatelessWidget {
  const _BlockingLayout({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.primaryAction,
    this.secondaryLabel,
    this.secondaryAction,
    this.tertiaryLabel,
    this.tertiaryAction,
    this.background,
  });

  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback primaryAction;
  final String? secondaryLabel;
  final VoidCallback? secondaryAction;
  final String? tertiaryLabel;
  final VoidCallback? tertiaryAction;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: background ?? colorScheme.surfaceContainer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 64, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: primaryAction, child: Text(primaryLabel)),
              if (secondaryLabel != null && secondaryAction != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: secondaryAction,
                  child: Text(secondaryLabel!),
                ),
              ],
              if (tertiaryLabel != null && tertiaryAction != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: tertiaryAction,
                  child: Text(tertiaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
