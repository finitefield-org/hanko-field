// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:app/ui/overlays/app_modal.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileSupportPage extends ConsumerWidget {
  const ProfileSupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final navigation = context.navigation;

    final options = _supportOptions(
      context,
      prefersEnglish: prefersEnglish,
      onNavigate: navigation.push,
    );

    final tickets = _supportTickets(prefersEnglish);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: const BackButton(),
            title: Text(l10n.profileSupportTitle),
            actions: [
              IconButton(
                tooltip: prefersEnglish ? 'Search support' : 'サポートを検索',
                icon: const Icon(Icons.search),
                onPressed: () =>
                    unawaited(_showSearchModal(context, prefersEnglish)),
              ),
              SizedBox(width: tokens.spacing.sm),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.sm,
              tokens.spacing.lg,
              tokens.spacing.xxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                Text(
                  prefersEnglish
                      ? 'Find the fastest way to get help.'
                      : '一番早いサポート方法を選べます。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: tokens.spacing.lg),
                Text(
                  prefersEnglish ? 'Support channels' : 'サポート窓口',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.md),
                _SupportOptionGrid(options: options),
                SizedBox(height: tokens.spacing.xl),
                Text(
                  prefersEnglish ? 'Recent tickets' : '最近のチケット',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.md),
                ...tickets.map(
                  (ticket) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                    child: AppListTile(
                      dense: true,
                      leading: Icon(
                        ticket.icon,
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                      title: Text(ticket.title),
                      subtitle: Text(ticket.subtitle),
                      trailing: _SupportChip(
                        label: ticket.statusLabel,
                        tone: ticket.statusTone,
                      ),
                      onTap: () => unawaited(
                        _showTicketModal(context, ticket, prefersEnglish),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.lg),
                AppButton(
                  label: prefersEnglish ? 'Create ticket' : 'チケットを作成',
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  leading: const Icon(Icons.add_circle_outline),
                  onPressed: () =>
                      navigation.push(AppRoutePaths.supportContact),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

List<_SupportOption> _supportOptions(
  BuildContext context, {
  required bool prefersEnglish,
  required void Function(String route) onNavigate,
}) {
  return [
    _SupportOption(
      title: 'FAQ',
      description: prefersEnglish ? 'Search top questions' : 'よくある質問を検索',
      icon: Icons.quiz_outlined,
      availabilityLabel: prefersEnglish ? 'Updated daily' : '毎日更新',
      availabilityTone: _SupportChipTone.neutral,
      onTap: () => onNavigate(AppRoutePaths.supportFaq),
    ),
    _SupportOption(
      title: prefersEnglish ? 'Chat' : 'チャット',
      description: prefersEnglish ? 'Connect to an agent' : '担当者に接続',
      icon: Icons.chat_bubble_outline,
      availabilityLabel: prefersEnglish ? 'Online now' : 'オンライン',
      availabilityTone: _SupportChipTone.positive,
      onTap: () => onNavigate(AppRoutePaths.supportChat),
    ),
    _SupportOption(
      title: prefersEnglish ? 'Contact' : '問い合わせ',
      description: prefersEnglish ? 'Forms and callbacks' : 'フォームと折返し',
      icon: Icons.support_agent_outlined,
      availabilityLabel: prefersEnglish ? '9:00-18:00' : '9:00-18:00',
      availabilityTone: _SupportChipTone.warning,
      onTap: () => onNavigate(AppRoutePaths.supportContact),
    ),
  ];
}

List<_SupportTicket> _supportTickets(bool prefersEnglish) {
  return [
    _SupportTicket(
      title: prefersEnglish ? 'Order receipt update' : '領収書の修正',
      subtitle: prefersEnglish
          ? 'Ticket #8421 · Updated 2h ago'
          : 'チケット #8421 · 2時間前に更新',
      statusLabel: prefersEnglish ? 'In review' : '確認中',
      statusTone: _SupportChipTone.info,
      icon: Icons.receipt_long_outlined,
    ),
    _SupportTicket(
      title: prefersEnglish ? 'Shipping address change' : '配送先の変更',
      subtitle: prefersEnglish
          ? 'Ticket #8388 · Updated yesterday'
          : 'チケット #8388 · 昨日更新',
      statusLabel: prefersEnglish ? 'Waiting on you' : '対応待ち',
      statusTone: _SupportChipTone.warning,
      icon: Icons.local_shipping_outlined,
    ),
    _SupportTicket(
      title: prefersEnglish ? 'Design approval' : 'デザイン確認',
      subtitle: prefersEnglish
          ? 'Ticket #8325 · Resolved'
          : 'チケット #8325 · 解決済み',
      statusLabel: prefersEnglish ? 'Resolved' : '解決済み',
      statusTone: _SupportChipTone.positive,
      icon: Icons.check_circle_outline,
    ),
  ];
}

class _SupportOptionGrid extends StatelessWidget {
  const _SupportOptionGrid({required this.options});

  final List<_SupportOption> options;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 680 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: tokens.spacing.md,
            mainAxisSpacing: tokens.spacing.md,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            return _SupportOptionCard(option: option);
          },
        );
      },
    );
  }
}

class _SupportOptionCard extends StatelessWidget {
  const _SupportOptionCard({required this.option});

  final _SupportOption option;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(tokens.radii.md);

    return Card(
      elevation: 1.4,
      shadowColor: tokens.colors.outline.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: radius),
      color: tokens.colors.surface,
      child: InkWell(
        borderRadius: radius,
        onTap: option.onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(tokens.radii.sm),
                ),
                child: Icon(option.icon, color: tokens.colors.onSurface),
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(option.title, style: theme.textTheme.titleMedium),
              SizedBox(height: tokens.spacing.xs),
              Text(
                option.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              _SupportChip(
                label: option.availabilityLabel,
                tone: option.availabilityTone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportChip extends StatelessWidget {
  const _SupportChip({required this.label, required this.tone});

  final String label;
  final _SupportChipTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final style = _SupportChipStyle.from(tokens, tone);

    return Chip(
      label: Text(label),
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: style.foreground),
      backgroundColor: style.background,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
    );
  }
}

class _SupportOption {
  _SupportOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.availabilityLabel,
    required this.availabilityTone,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final String availabilityLabel;
  final _SupportChipTone availabilityTone;
  final VoidCallback? onTap;
}

class _SupportTicket {
  _SupportTicket({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusTone,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final _SupportChipTone statusTone;
  final IconData icon;
}

enum _SupportChipTone { neutral, positive, warning, info }

class _SupportChipStyle {
  const _SupportChipStyle({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  factory _SupportChipStyle.from(DesignTokens tokens, _SupportChipTone tone) {
    switch (tone) {
      case _SupportChipTone.positive:
        return _SupportChipStyle(
          background: tokens.colors.success.withValues(alpha: 0.14),
          foreground: tokens.colors.success,
        );
      case _SupportChipTone.warning:
        return _SupportChipStyle(
          background: tokens.colors.warning.withValues(alpha: 0.16),
          foreground: tokens.colors.warning,
        );
      case _SupportChipTone.info:
        return _SupportChipStyle(
          background: tokens.colors.secondary.withValues(alpha: 0.16),
          foreground: tokens.colors.secondary,
        );
      case _SupportChipTone.neutral:
        return _SupportChipStyle(
          background: tokens.colors.surfaceVariant,
          foreground: tokens.colors.onSurface,
        );
    }
  }
}

Future<void> _showSearchModal(BuildContext context, bool prefersEnglish) {
  return showAppModal<void>(
    context: context,
    title: prefersEnglish ? 'Search support' : 'サポートを検索',
    body: Text(
      prefersEnglish
          ? 'Support search is coming soon. For now, browse the FAQ or start a chat.'
          : 'サポート検索は準備中です。FAQの確認やチャットをご利用ください。',
    ),
    primaryAction: prefersEnglish ? 'Got it' : 'OK',
  );
}

Future<void> _showTicketModal(
  BuildContext context,
  _SupportTicket ticket,
  bool prefersEnglish,
) {
  final navigation = context.navigation;
  return showAppModal<void>(
    context: context,
    title: ticket.title,
    body: Text(
      prefersEnglish
          ? 'Ticket details are coming soon. For now, you can continue in the contact form.'
          : 'チケット詳細は準備中です。問い合わせフォームから続けられます。',
    ),
    primaryAction: prefersEnglish ? 'Contact support' : '問い合わせる',
    secondaryAction: prefersEnglish ? 'Close' : '閉じる',
    onPrimaryPressed: () {
      Navigator.of(context).pop();
      navigation.push(AppRoutePaths.supportContact);
    },
  );
}
