import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
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

class OnboardingRequiredScreen extends ConsumerWidget {
  const OnboardingRequiredScreen({
    required this.flags,
    required this.onCompleted,
    super.key,
  });

  final OnboardingFlags flags;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSteps = flags.stepCompletion.entries
        .where((entry) => entry.value == false)
        .map((entry) => entry.key.name)
        .join(', ');
    final subtitle = pendingSteps.isEmpty
        ? '初期設定を完了してください。'
        : '未完了のステップ: $pendingSteps';
    return _BlockingLayout(
      icon: Icons.auto_stories_outlined,
      title: '初回セットアップ',
      description: subtitle,
      primaryLabel: 'チュートリアルを開始',
      primaryAction: () => _showComingSoon(context),
      secondaryLabel: 'デバッグ: 完了にする',
      secondaryAction: () async {
        await _markAllCompleted(ref);
        onCompleted();
      },
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('オンボーディング画面は後続タスクで実装されます。')));
  }

  Future<void> _markAllCompleted(WidgetRef ref) async {
    final dataSource = await ref.read(onboardingLocalDataSourceProvider.future);
    final completed = OnboardingFlags(
      steps: {for (final step in OnboardingStep.values) step: true},
      updatedAt: clock_package.clock.now(),
    );
    await dataSource.replace(completed);
  }
}

class AuthRequiredScreen extends StatelessWidget {
  const AuthRequiredScreen({required this.onRetry, this.onBypass, super.key});

  final VoidCallback onRetry;
  final VoidCallback? onBypass;

  @override
  Widget build(BuildContext context) {
    return _BlockingLayout(
      icon: Icons.login,
      title: 'サインインが必要です',
      description: 'Apple/Google/Email 認証フローは後続タスクで追加されます。',
      primaryLabel: 'ログインに進む',
      primaryAction: () => _showPlaceholder(context),
      secondaryLabel: 'ステータス再取得',
      secondaryAction: onRetry,
      tertiaryLabel: onBypass == null ? null : 'デバッグ: スキップ',
      tertiaryAction: onBypass,
    );
  }

  void _showPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('認証フローは Task 021 で実装予定です。')));
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
