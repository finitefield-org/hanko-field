import 'dart:async';

import 'package:app/core/theme/tokens.dart';
import 'package:app/features/profile/application/profile_support_controller.dart';
import 'package:app/features/profile/domain/support_center.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSupportScreen extends ConsumerWidget {
  const ProfileSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(profileSupportControllerProvider);
    final controller = ref.read(profileSupportControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileSupportError(
          message: l10n.profileSupportLoadError,
          actionLabel: l10n.profileSupportRetryLabel,
          onRetry: controller.reload,
        ),
        data: (state) => _ProfileSupportBody(
          state: state,
          controller: controller,
          l10n: l10n,
        ),
      ),
    );
  }
}

class _ProfileSupportBody extends StatelessWidget {
  const _ProfileSupportBody({
    required this.state,
    required this.controller,
    required this.l10n,
  });

  final ProfileSupportState state;
  final ProfileSupportController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.reload,
      edgeOffset: AppTokens.spaceL,
      displacement: AppTokens.spaceXL,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.profileSupportTitle),
            centerTitle: true,
            pinned: true,
            actions: [
              IconButton(
                tooltip: l10n.profileSupportSearchTooltip,
                onPressed: () => _handleSearch(context),
                icon: const Icon(Icons.search),
              ),
            ],
            bottom: state.isRefreshing
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceS,
              AppTokens.spaceL,
              AppTokens.spaceS,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  l10n.profileSupportHelpCenterTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  l10n.profileSupportHelpCenterSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.lastUpdated != null) ...[
                  const SizedBox(height: AppTokens.spaceS),
                  Text(
                    l10n.profileSupportUpdatedLabel(
                      _formatTimestamp(state.lastUpdated!, l10n),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppTokens.spaceL,
                mainAxisSpacing: AppTokens.spaceL,
                childAspectRatio: 1.25,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final action = state.quickActions[index];
                return _SupportQuickActionCard(
                  action: action,
                  l10n: l10n,
                  onTap: () => _handleQuickAction(context, action),
                );
              }, childCount: state.quickActions.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceXL,
              AppTokens.spaceL,
              AppTokens.spaceS,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  l10n.profileSupportRecentTicketsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS / 2),
                Text(
                  l10n.profileSupportRecentTicketsSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
          ),
          if (state.hasTickets)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ticket = state.tickets[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == state.tickets.length - 1
                          ? 0
                          : AppTokens.spaceM,
                    ),
                    child: _SupportTicketTile(
                      ticket: ticket,
                      l10n: l10n,
                      onTap: () => _showTicketDetails(context, ticket),
                    ),
                  );
                }, childCount: state.tickets.length),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceM,
                  AppTokens.spaceL,
                  AppTokens.spaceXL,
                ),
                child: _SupportEmptyState(l10n: l10n),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceXXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.isCreatingTicket)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppTokens.spaceS),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  FilledButton.tonal(
                    onPressed: state.isCreatingTicket
                        ? null
                        : () => _handleCreateTicket(context),
                    child: Text(l10n.profileSupportCreateTicketLabel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuickAction(
    BuildContext context,
    SupportQuickAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(
        action.target,
        mode: action.target.scheme == 'https'
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
      if (!context.mounted) {
        return;
      }
      if (!launched) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.profileSupportActionError)),
          );
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.profileSupportActionError)));
    }
  }

  Future<void> _handleCreateTicket(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.createTicket(l10n.profileSupportTicketQuickSubject);
      if (!context.mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.profileSupportCreateTicketSuccess)),
        );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.profileSupportCreateTicketError)),
        );
    }
  }

  Future<void> _handleSearch(BuildContext context) async {
    final result = await showSearch<_SupportSearchResult?>(
      context: context,
      delegate: _SupportSearchDelegate(
        l10n: l10n,
        actions: state.quickActions,
        tickets: state.tickets,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (result == null) {
      return;
    }
    if (result.action != null) {
      await _handleQuickAction(context, result.action!);
      return;
    }
    final ticket = result.ticket;
    if (ticket != null && context.mounted) {
      await _showTicketDetails(context, ticket);
    }
  }

  Future<void> _showTicketDetails(
    BuildContext context,
    SupportTicket ticket,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceXXL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_channelIcon(ticket.channel), color: scheme.primary),
                  const SizedBox(width: AppTokens.spaceS),
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceS),
              Text(
                l10n.profileSupportTicketSubtitle(
                  _formatTimestamp(ticket.updatedAt, l10n),
                  ticket.reference,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.spaceM),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(_statusLabel(ticket.status, l10n)),
                  backgroundColor: _statusColor(ticket.status, scheme),
                ),
              ),
              const SizedBox(height: AppTokens.spaceM),
              Text(
                l10n.profileSupportTicketDetailBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTokens.spaceL),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.profileSupportTicketDetailFollowup(
                            ticket.reference,
                          ),
                        ),
                      ),
                    );
                },
                child: Text(l10n.profileSupportTicketDetailAction),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupportQuickActionCard extends StatelessWidget {
  const _SupportQuickActionCard({
    required this.action,
    required this.l10n,
    required this.onTap,
  });

  final SupportQuickAction action;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _actionTitle(action.kind, l10n);
    final subtitle = _actionSubtitle(action.kind, l10n);
    final icon = _actionIcon(action.kind);

    return Card(
      elevation: 3,
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: InkWell(
        borderRadius: AppTokens.radiusL,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: AppTokens.spaceM),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppTokens.spaceS),
              Expanded(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceS),
              ActionChip(
                avatar: Icon(
                  Icons.schedule,
                  size: 18,
                  color: _availabilityTextColor(
                    action.availabilityStatus,
                    scheme,
                  ),
                ),
                label: Text(action.availabilityLabel),
                backgroundColor: _availabilityColor(
                  action.availabilityStatus,
                  scheme,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportTicketTile extends StatelessWidget {
  const _SupportTicketTile({
    required this.ticket,
    required this.l10n,
    required this.onTap,
  });

  final SupportTicket ticket;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            _channelIcon(ticket.channel),
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(ticket.subject),
        subtitle: Text(
          l10n.profileSupportTicketSubtitle(
            _formatTimestamp(ticket.updatedAt, l10n),
            ticket.reference,
          ),
        ),
        trailing: Chip(
          label: Text(_statusLabel(ticket.status, l10n)),
          backgroundColor: _statusColor(ticket.status, scheme),
          labelStyle: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      decoration: BoxDecoration(
        borderRadius: AppTokens.radiusL,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileSupportEmptyTicketsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.profileSupportEmptyTicketsSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ProfileSupportError extends StatelessWidget {
  const _ProfileSupportError({
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String message;
  final String actionLabel;
  final FutureOr<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceM),
              FilledButton(onPressed: onRetry, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportSearchDelegate extends SearchDelegate<_SupportSearchResult?> {
  _SupportSearchDelegate({
    required this.l10n,
    required this.actions,
    required this.tickets,
  }) : _results = [
         ...actions.map(_SupportSearchResult.fromAction),
         ...tickets.map(_SupportSearchResult.fromTicket),
       ];

  final AppLocalizations l10n;
  final List<SupportQuickAction> actions;
  final List<SupportTicket> tickets;
  final List<_SupportSearchResult> _results;

  @override
  String? get searchFieldLabel => l10n.profileSupportSearchPlaceholder;

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) {
      return null;
    }
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final lowerQuery = query.trim().toLowerCase();
    final filtered = lowerQuery.isEmpty
        ? _results
        : _results.where((entry) => entry.matches(lowerQuery, l10n)).toList();

    if (filtered.isEmpty) {
      return Center(child: Text(l10n.profileSupportSearchEmpty));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = filtered[index];
        final icon = result.action != null
            ? _actionIcon(result.action!.kind)
            : _channelIcon(result.ticket!.channel);
        final title = result.action != null
            ? _actionTitle(result.action!.kind, l10n)
            : result.ticket!.subject;
        final subtitle = result.action != null
            ? _actionSubtitle(result.action!.kind, l10n)
            : l10n.profileSupportTicketSubtitle(
                _formatTimestamp(result.ticket!.updatedAt, l10n),
                result.ticket!.reference,
              );
        return ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: () => close(context, result),
        );
      },
    );
  }
}

class _SupportSearchResult {
  const _SupportSearchResult._({this.action, this.ticket});

  factory _SupportSearchResult.fromAction(SupportQuickAction action) =>
      _SupportSearchResult._(action: action);

  factory _SupportSearchResult.fromTicket(SupportTicket ticket) =>
      _SupportSearchResult._(ticket: ticket);

  final SupportQuickAction? action;
  final SupportTicket? ticket;

  bool matches(String query, AppLocalizations l10n) {
    final buffer = StringBuffer();
    if (action != null) {
      buffer
        ..write(_actionTitle(action!.kind, l10n))
        ..write(' ')
        ..write(_actionSubtitle(action!.kind, l10n))
        ..write(' ')
        ..write(action!.availabilityLabel);
    } else if (ticket != null) {
      buffer
        ..write(ticket!.subject)
        ..write(' ')
        ..write(ticket!.reference);
    }
    return buffer.toString().toLowerCase().contains(query);
  }
}

String _actionTitle(SupportQuickActionKind kind, AppLocalizations l10n) {
  return switch (kind) {
    SupportQuickActionKind.faq => l10n.profileSupportQuickFaqTitle,
    SupportQuickActionKind.chat => l10n.profileSupportQuickChatTitle,
    SupportQuickActionKind.call => l10n.profileSupportQuickCallTitle,
  };
}

String _actionSubtitle(SupportQuickActionKind kind, AppLocalizations l10n) {
  return switch (kind) {
    SupportQuickActionKind.faq => l10n.profileSupportQuickFaqSubtitle,
    SupportQuickActionKind.chat => l10n.profileSupportQuickChatSubtitle,
    SupportQuickActionKind.call => l10n.profileSupportQuickCallSubtitle,
  };
}

IconData _actionIcon(SupportQuickActionKind kind) {
  return switch (kind) {
    SupportQuickActionKind.faq => Icons.menu_book_outlined,
    SupportQuickActionKind.chat => Icons.chat_bubble_outline,
    SupportQuickActionKind.call => Icons.support_agent,
  };
}

IconData _channelIcon(SupportChannel channel) {
  return switch (channel) {
    SupportChannel.portal => Icons.folder_shared_outlined,
    SupportChannel.chat => Icons.chat_bubble_outline,
    SupportChannel.phone => Icons.call_outlined,
    SupportChannel.email => Icons.email_outlined,
  };
}

String _statusLabel(SupportTicketStatus status, AppLocalizations l10n) {
  return switch (status) {
    SupportTicketStatus.open => l10n.profileSupportStatusOpen,
    SupportTicketStatus.waitingCustomer => l10n.profileSupportStatusWaiting,
    SupportTicketStatus.resolved => l10n.profileSupportStatusResolved,
  };
}

Color _statusColor(SupportTicketStatus status, ColorScheme scheme) {
  return switch (status) {
    SupportTicketStatus.open => scheme.secondaryContainer,
    SupportTicketStatus.waitingCustomer => scheme.tertiaryContainer,
    SupportTicketStatus.resolved => scheme.surfaceContainerHighest,
  };
}

Color _availabilityColor(SupportAvailabilityStatus status, ColorScheme scheme) {
  return switch (status) {
    SupportAvailabilityStatus.online => scheme.secondaryContainer,
    SupportAvailabilityStatus.limited => scheme.tertiaryContainer,
    SupportAvailabilityStatus.offline => scheme.surfaceContainerHighest,
  };
}

Color _availabilityTextColor(
  SupportAvailabilityStatus status,
  ColorScheme scheme,
) {
  return switch (status) {
    SupportAvailabilityStatus.online => scheme.onSecondaryContainer,
    SupportAvailabilityStatus.limited => scheme.onTertiaryContainer,
    SupportAvailabilityStatus.offline => scheme.onSurfaceVariant,
  };
}

String _formatTimestamp(DateTime timestamp, AppLocalizations l10n) {
  final formatter = DateFormat.yMMMd(l10n.localeName).add_Hm();
  return formatter.format(timestamp);
}
