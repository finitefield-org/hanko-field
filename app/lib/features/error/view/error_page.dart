// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:share_plus/share_plus.dart';

class ErrorDiagnostics {
  const ErrorDiagnostics({
    required this.path,
    required this.timestamp,
    this.code,
    this.message,
    this.source,
    this.returnTo,
    this.traceId,
  });

  final String path;
  final DateTime timestamp;
  final String? code;
  final String? message;
  final String? source;
  final String? returnTo;
  final String? traceId;

  String formatForExport({required String localeTag, required String persona}) {
    final buffer = StringBuffer()
      ..writeln('Hanko Field diagnostics')
      ..writeln('Timestamp: ${timestamp.toIso8601String()}')
      ..writeln('Path: $path')
      ..writeln('Locale: $localeTag')
      ..writeln('Persona: $persona');

    if (_hasValue(code)) buffer.writeln('Code: $code');
    if (_hasValue(message)) buffer.writeln('Message: $message');
    if (_hasValue(source)) buffer.writeln('Source: $source');
    if (_hasValue(returnTo)) buffer.writeln('ReturnTo: $returnTo');
    if (_hasValue(traceId)) buffer.writeln('TraceId: $traceId');

    return buffer.toString();
  }

  bool _hasValue(String? value) {
    final trimmed = value?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }
}

class ErrorPage extends ConsumerStatefulWidget {
  const ErrorPage({super.key, required this.diagnostics});

  final ErrorDiagnostics diagnostics;

  @override
  ConsumerState<ErrorPage> createState() => _ErrorPageState();
}

class _ErrorPageState extends ConsumerState<ErrorPage> {
  static final Logger _logger = Logger('ErrorPage');

  @override
  void initState() {
    super.initState();
    unawaited(_trackErrorView());
  }

  Future<void> _trackErrorView() async {
    final gates = ref.container.read(appExperienceGatesProvider);
    final diagnostics = widget.diagnostics;
    _logger.warning(
      'Error screen opened: ${diagnostics.code ?? 'unknown'} ${diagnostics.path}',
    );

    await ref.container
        .read(analyticsClientProvider)
        .track(
          ErrorScreenViewedEvent(
            code: _nullableValue(diagnostics.code),
            path: diagnostics.path,
            source: _nullableValue(diagnostics.source),
            locale: gates.localeTag,
            persona: gates.personaKey,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final diagnostics = widget.diagnostics;
    final router = GoRouter.of(context);

    final title = prefersEnglish ? 'Something went wrong' : 'エラーが発生しました';
    final headline = prefersEnglish ? 'We hit a snag' : '問題が発生しました';
    final detail =
        _nullableValue(diagnostics.message) ??
        (prefersEnglish
            ? 'Try again, or contact support if this keeps happening.'
            : '再試行するか、解決しない場合はサポートにお問い合わせください。');
    final codeLabel = prefersEnglish ? 'Error code' : 'エラーコード';
    final supportHeadline = prefersEnglish ? 'Need help?' : 'サポートが必要ですか？';
    final supportMessage = prefersEnglish
        ? 'Share the diagnostics below with our team for faster help.'
        : '下記の診断情報を共有すると対応が早くなります。';
    final retryLabel = prefersEnglish ? 'Retry' : '再試行';
    final homeLabel = prefersEnglish ? 'Go home' : 'ホームへ戻る';
    final reportLabel = prefersEnglish ? 'Contact support' : 'サポートに連絡';
    final exportLabel = prefersEnglish ? 'Export diagnostics' : '診断情報を共有';
    final chipsLabel = prefersEnglish ? 'Quick actions' : 'クイックアクション';
    final diagnosticsLabel = prefersEnglish ? 'Diagnostics' : '診断情報';

    final codeText = _nullableValue(diagnostics.code) ?? 'UNKNOWN';

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(title),
        leading: IconButton(
          tooltip: prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (router.canPop()) {
              router.pop();
            } else {
              router.go(AppRoutePaths.home);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.lg,
            tokens.spacing.lg,
            tokens.spacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(tokens.spacing.md),
                          decoration: BoxDecoration(
                            color: tokens.colors.error.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: tokens.colors.error,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: tokens.spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              SizedBox(height: tokens.spacing.xs),
                              Text(
                                detail,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: tokens.colors.onSurface.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.md),
                    Row(
                      children: [
                        Text(
                          codeLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        SizedBox(width: tokens.spacing.sm),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.sm,
                            vertical: tokens.spacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              tokens.radii.sm,
                            ),
                          ),
                          child: Text(
                            codeText,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
              Text(chipsLabel, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: tokens.spacing.sm),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.refresh_rounded),
                    label: Text(retryLabel),
                    onPressed: _retry,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.support_agent_rounded),
                    label: Text(reportLabel),
                    onPressed: _contactSupport,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.share_outlined),
                    label: Text(exportLabel),
                    onPressed: () => _exportDiagnostics(gates),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.lg),
              Text(
                diagnosticsLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DiagnosticRow(
                      label: prefersEnglish ? 'Timestamp' : '発生時刻',
                      value: _formatTimestamp(context, diagnostics.timestamp),
                    ),
                    _DiagnosticRow(
                      label: prefersEnglish ? 'Route' : 'ルート',
                      value: diagnostics.path,
                    ),
                    _DiagnosticRow(
                      label: prefersEnglish ? 'Locale' : '言語/地域',
                      value: '${gates.localeTag} (${gates.regionCode})',
                    ),
                    _DiagnosticRow(
                      label: prefersEnglish ? 'Persona' : 'ペルソナ',
                      value: gates.personaKey,
                    ),
                    if (_hasValue(diagnostics.source))
                      _DiagnosticRow(
                        label: prefersEnglish ? 'Source' : '発生元',
                        value: diagnostics.source!,
                      ),
                    if (_hasValue(diagnostics.returnTo))
                      _DiagnosticRow(
                        label: prefersEnglish ? 'Return to' : '遷移先',
                        value: diagnostics.returnTo!,
                      ),
                    if (_hasValue(diagnostics.traceId))
                      _DiagnosticRow(
                        label: prefersEnglish ? 'Trace ID' : 'トレースID',
                        value: diagnostics.traceId!,
                      ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supportHeadline,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      supportMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    SizedBox(height: tokens.spacing.md),
                    _SupportLinkTile(
                      icon: Icons.quiz_outlined,
                      title: prefersEnglish ? 'Browse FAQ' : 'FAQを見る',
                      subtitle: prefersEnglish
                          ? 'Troubleshooting guides and answers.'
                          : 'よくある質問と解決策を確認できます。',
                      onTap: () => router.go(AppRoutePaths.supportFaq),
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    _SupportLinkTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: prefersEnglish ? 'Start chat' : 'チャットで相談',
                      subtitle: prefersEnglish
                          ? 'Talk to support in real time.'
                          : 'リアルタイムでサポートに相談できます。',
                      onTap: () => router.go(AppRoutePaths.supportChat),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.xl),
              AppButton(
                label: retryLabel,
                onPressed: _retry,
                expand: true,
                leading: const Icon(Icons.refresh_rounded),
              ),
              SizedBox(height: tokens.spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: homeLabel,
                      onPressed: () => router.go(AppRoutePaths.home),
                      variant: AppButtonVariant.ghost,
                      leading: const Icon(Icons.home_outlined),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.md),
                  TextButton(
                    onPressed: _contactSupport,
                    child: Text(reportLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retry() {
    final router = GoRouter.of(context);
    final returnTo = widget.diagnostics.returnTo;
    if (_hasValue(returnTo)) {
      router.go(returnTo!.trim());
      return;
    }
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go(AppRoutePaths.home);
  }

  void _contactSupport() {
    GoRouter.of(context).go(AppRoutePaths.supportContact);
  }

  Future<void> _exportDiagnostics(AppExperienceGates gates) async {
    final diagnostics = widget.diagnostics;
    final payload = diagnostics.formatForExport(
      localeTag: gates.localeTag,
      persona: gates.personaKey,
    );

    await Share.share(payload);
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatFullDate(local);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '$date $time';
  }

  bool _hasValue(String? value) {
    final trimmed = value?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  String? _nullableValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportLinkTile extends StatelessWidget {
  const _SupportLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tokens.colors.primary),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: tokens.colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
