// ignore_for_file: public_member_api_docs

import 'package:app/features/notifications/data/notification_preferences.dart';
import 'package:app/features/profile/view_model/profile_notifications_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileNotificationsPage extends ConsumerStatefulWidget {
  const ProfileNotificationsPage({super.key});

  @override
  ConsumerState<ProfileNotificationsPage> createState() =>
      _ProfileNotificationsPageState();
}

class _ProfileNotificationsPageState
    extends ConsumerState<ProfileNotificationsPage> {
  NotificationPreferences? _draft;
  bool _isDirty = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(profileNotificationsViewModel);
    final saveState = ref.watch(profileNotificationsViewModel.saveMut);
    final isBusy = saveState is PendingMutationState;
    final loaded = state.valueOrNull;

    if (loaded != null && (!_isDirty || _draft == null)) {
      _draft = loaded;
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Text(l10n.profileNotificationsTitle),
        actions: [
          TextButton(
            onPressed: isBusy || _draft == null ? null : _resetToDefaults,
            child: Text(l10n.profileNotificationsReset),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          child: _buildBody(
            context: context,
            theme: theme,
            tokens: tokens,
            l10n: l10n,
            state: state,
            isBusy: isBusy,
            isSaving: saveState is PendingMutationState,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ThemeData theme,
    required DesignTokens tokens,
    required AppLocalizations l10n,
    required AsyncValue<NotificationPreferences> state,
    required bool isBusy,
    required bool isSaving,
  }) {
    if (state is AsyncLoading<NotificationPreferences> &&
        state.valueOrNull == null) {
      return const AppListSkeleton(items: 4, itemHeight: 80);
    }

    if (state is AsyncError<NotificationPreferences> &&
        state.valueOrNull == null) {
      return AppEmptyState(
        title: l10n.profileNotificationsLoadFailedTitle,
        message: state.error.toString(),
        icon: Icons.notifications_off_outlined,
        actionLabel: l10n.profileRetry,
        onAction: () => ref.invalidate(profileNotificationsViewModel),
      );
    }

    final prefs = _draft ?? NotificationPreferences.defaults;
    final canSave = _isDirty && !isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              Text(
                l10n.profileNotificationsHeader,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
              Text(
                l10n.profileNotificationsPushHeader,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              _CategoryList(
                categories: notificationCategories,
                l10n: l10n,
                tokens: tokens,
                enabledFor: prefs.isPushEnabled,
                onToggle: isBusy ? null : _togglePush,
              ),
              SizedBox(height: tokens.spacing.lg),
              Text(
                l10n.profileNotificationsEmailHeader,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              _CategoryList(
                categories: notificationCategories,
                l10n: l10n,
                tokens: tokens,
                enabledFor: prefs.isEmailEnabled,
                onToggle: isBusy ? null : _toggleEmail,
              ),
              SizedBox(height: tokens.spacing.lg),
              Text(
                l10n.profileNotificationsDigestHeader,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              AppCard(
                padding: EdgeInsets.all(tokens.spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<NotificationDigestFrequency>(
                      segments: [
                        ButtonSegment(
                          value: NotificationDigestFrequency.daily,
                          label: Text(l10n.profileNotificationsDigestDaily),
                        ),
                        ButtonSegment(
                          value: NotificationDigestFrequency.weekly,
                          label: Text(l10n.profileNotificationsDigestWeekly),
                        ),
                        ButtonSegment(
                          value: NotificationDigestFrequency.monthly,
                          label: Text(l10n.profileNotificationsDigestMonthly),
                        ),
                      ],
                      selected: {prefs.digestFrequency},
                      onSelectionChanged: isBusy
                          ? null
                          : (selection) {
                              if (selection.isEmpty) return;
                              _updateDigest(selection.first);
                            },
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Text(
                      l10n.profileNotificationsDigestHelper,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.lg),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: canSave ? _savePreferences : null,
            child: isSaving
                ? SizedBox(
                    width: tokens.spacing.md,
                    height: tokens.spacing.md,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  )
                : Text(l10n.profileNotificationsSave),
          ),
        ),
      ],
    );
  }

  void _togglePush(NotificationCategory category, bool enabled) {
    final current = _draft ?? NotificationPreferences.defaults;
    final next = current.updatePush(category, enabled);
    _updateDraft(next);
  }

  void _toggleEmail(NotificationCategory category, bool enabled) {
    final current = _draft ?? NotificationPreferences.defaults;
    final next = current.updateEmail(category, enabled);
    _updateDraft(next);
  }

  void _updateDigest(NotificationDigestFrequency frequency) {
    final current = _draft ?? NotificationPreferences.defaults;
    final next = current.updateDigest(frequency);
    _updateDraft(next);
  }

  void _updateDraft(NotificationPreferences next) {
    final loaded = ref.container
        .read(profileNotificationsViewModel)
        .valueOrNull;
    setState(() {
      _draft = next;
      _isDirty = loaded == null ? true : !next.isEquivalentTo(loaded);
    });
  }

  void _resetToDefaults() {
    _updateDraft(NotificationPreferences.defaults);
  }

  Future<void> _savePreferences() async {
    final l10n = AppLocalizations.of(context);
    final prefs = _draft;
    if (prefs == null) return;
    try {
      await ref.invoke(profileNotificationsViewModel.save(prefs));
      if (!mounted) return;
      setState(() => _isDirty = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileNotificationsSaved)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileNotificationsSaveFailed)),
      );
    }
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.l10n,
    required this.tokens,
    required this.enabledFor,
    required this.onToggle,
  });

  final List<NotificationCategory> categories;
  final AppLocalizations l10n;
  final DesignTokens tokens;
  final bool Function(NotificationCategory) enabledFor;
  final void Function(NotificationCategory, bool)? onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final category in categories) ...[
          _NotificationToggleTile(
            category: category,
            l10n: l10n,
            enabled: enabledFor(category),
            onChanged: onToggle == null
                ? null
                : (value) => onToggle!(category, value),
          ),
          if (category != categories.last) SizedBox(height: tokens.spacing.sm),
        ],
      ],
    );
  }
}

class _NotificationToggleTile extends StatelessWidget {
  const _NotificationToggleTile({
    required this.category,
    required this.l10n,
    required this.enabled,
    required this.onChanged,
  });

  final NotificationCategory category;
  final AppLocalizations l10n;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: Text(_categoryTitle(l10n, category)),
      subtitle: Text(_categorySubtitle(l10n, category)),
      trailing: Switch.adaptive(value: enabled, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!enabled),
    );
  }

  String _categoryTitle(AppLocalizations l10n, NotificationCategory category) {
    switch (category) {
      case NotificationCategory.orderUpdates:
        return l10n.profileNotificationsCategoryOrdersTitle;
      case NotificationCategory.designUpdates:
        return l10n.profileNotificationsCategoryDesignsTitle;
      case NotificationCategory.promotions:
        return l10n.profileNotificationsCategoryPromosTitle;
      case NotificationCategory.guides:
        return l10n.profileNotificationsCategoryGuidesTitle;
    }
  }

  String _categorySubtitle(
    AppLocalizations l10n,
    NotificationCategory category,
  ) {
    switch (category) {
      case NotificationCategory.orderUpdates:
        return l10n.profileNotificationsCategoryOrdersBody;
      case NotificationCategory.designUpdates:
        return l10n.profileNotificationsCategoryDesignsBody;
      case NotificationCategory.promotions:
        return l10n.profileNotificationsCategoryPromosBody;
      case NotificationCategory.guides:
        return l10n.profileNotificationsCategoryGuidesBody;
    }
  }
}
