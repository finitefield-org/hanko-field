import 'package:app/core/theme/tokens.dart';
import 'package:app/features/notifications/domain/app_notification.dart';
import 'package:app/features/profile/application/profile_notifications_controller.dart';
import 'package:app/features/profile/domain/notification_preferences.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProfileNotificationsScreen extends ConsumerStatefulWidget {
  const ProfileNotificationsScreen({super.key});

  @override
  ConsumerState<ProfileNotificationsScreen> createState() =>
      _ProfileNotificationsScreenState();
}

class _ProfileNotificationsScreenState
    extends ConsumerState<ProfileNotificationsScreen> {
  ProfileNotificationsController get _controller =>
      ref.read(profileNotificationsControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(profileNotificationsControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.profileNotificationsTitle),
        actions: [
          asyncState.maybeWhen(
            data: (state) => TextButton(
              onPressed: state.hasChanges && !state.isSaving
                  ? _controller.resetDraft
                  : null,
              child: Text(l10n.profileNotificationsReset),
            ),
            orElse: () => TextButton(
              onPressed: null,
              child: Text(l10n.profileNotificationsReset),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ProfileNotificationsError(
            message: error.toString(),
            onRetry: _controller.reload,
          ),
          data: (state) => RefreshIndicator(
            onRefresh: _controller.reload,
            edgeOffset: AppTokens.spaceL,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (state.isSaving)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceM,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _IntroText(l10n: l10n),
                      const SizedBox(height: AppTokens.spaceM),
                      _ChannelPreferencesCard(
                        state: state,
                        l10n: l10n,
                        onToggle: _handleChannelToggle,
                      ),
                      const SizedBox(height: AppTokens.spaceM),
                      _DigestScheduleCard(
                        state: state,
                        l10n: l10n,
                        onFrequencyChanged: _controller.setDigestFrequency,
                        onPickTime: _handleDigestTimePicker,
                        onPickWeekday: _handleDigestWeekdayPicker,
                        onPickMonthDay: _handleDigestMonthdayPicker,
                      ),
                      const SizedBox(height: AppTokens.spaceM),
                      _QuietHoursCard(
                        state: state,
                        l10n: l10n,
                        onToggle: _controller.setQuietHoursEnabled,
                        onPickStart: _handleQuietStartPicker,
                        onPickEnd: _handleQuietEndPicker,
                      ),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceL,
                    AppTokens.spaceS,
                    AppTokens.spaceL,
                    AppTokens.spaceXL,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _SaveFooter(
                      state: state,
                      l10n: l10n,
                      onSave: () => _handleSave(state, l10n),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleChannelToggle(
    NotificationCategory category,
    NotificationChannelType channel,
    bool enabled,
  ) {
    _controller.updateChannel(
      category: category,
      channel: channel,
      enabled: enabled,
    );
  }

  Future<void> _handleDigestTimePicker(
    NotificationDigestSchedule schedule,
  ) async {
    final initial = TimeOfDay(hour: schedule.hour, minute: schedule.minute);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (!mounted || picked == null) {
      return;
    }
    _controller.setDigestTime(hour: picked.hour, minute: picked.minute);
  }

  void _handleDigestWeekdayPicker(int weekday) {
    _controller.setDigestWeekday(weekday);
  }

  void _handleDigestMonthdayPicker(int day) {
    _controller.setDigestDayOfMonth(day);
  }

  Future<void> _handleQuietStartPicker(
    NotificationQuietHours quietHours,
  ) async {
    final time = _timeFromMinutes(quietHours.startMinutes);
    final picked = await showTimePicker(context: context, initialTime: time);
    if (!mounted || picked == null) {
      return;
    }
    _controller.setQuietHoursStart(_minutesFromTime(picked));
  }

  Future<void> _handleQuietEndPicker(NotificationQuietHours quietHours) async {
    final time = _timeFromMinutes(quietHours.endMinutes);
    final picked = await showTimePicker(context: context, initialTime: time);
    if (!mounted || picked == null) {
      return;
    }
    _controller.setQuietHoursEnd(_minutesFromTime(picked));
  }

  Future<void> _handleSave(
    ProfileNotificationsState state,
    AppLocalizations l10n,
  ) async {
    if (!state.hasChanges || state.isSaving) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.saveChanges();
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.profileNotificationsSaveSuccess)),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileNotificationsSaveError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }
}

class _IntroText extends StatelessWidget {
  const _IntroText({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Text(l10n.profileNotificationsDescription, style: textStyle);
  }
}

class _ChannelPreferencesCard extends StatelessWidget {
  const _ChannelPreferencesCard({
    required this.state,
    required this.l10n,
    required this.onToggle,
  });

  final ProfileNotificationsState state;
  final AppLocalizations l10n;
  final void Function(
    NotificationCategory category,
    NotificationChannelType channel,
    bool enabled,
  )
  onToggle;

  @override
  Widget build(BuildContext context) {
    final disabled = state.isSaving;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileNotificationsCategoriesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              l10n.profileNotificationsCategoriesSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.spaceL),
            for (final preference in state.draft.categories) ...[
              _CategoryTile(
                preference: preference,
                l10n: l10n,
                disabled: disabled,
                onToggle: onToggle,
              ),
              if (preference != state.draft.categories.last)
                const Divider(height: AppTokens.spaceL * 1.5),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.preference,
    required this.l10n,
    required this.disabled,
    required this.onToggle,
  });

  final NotificationCategoryPreference preference;
  final AppLocalizations l10n;
  final bool disabled;
  final void Function(
    NotificationCategory category,
    NotificationChannelType channel,
    bool enabled,
  )
  onToggle;

  @override
  Widget build(BuildContext context) {
    final metadata = _categoryMetadata(preference.category, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(metadata.icon),
          title: Text(metadata.title),
          subtitle: Text(metadata.subtitle),
        ),
        const SizedBox(height: AppTokens.spaceXS),
        SwitchListTile(
          title: Text(l10n.profileNotificationsChannelPush),
          contentPadding: EdgeInsets.zero,
          value: preference.pushEnabled,
          onChanged: disabled
              ? null
              : (value) => onToggle(
                  preference.category,
                  NotificationChannelType.push,
                  value,
                ),
          dense: true,
        ),
        SwitchListTile(
          title: Text(l10n.profileNotificationsChannelEmail),
          contentPadding: EdgeInsets.zero,
          value: preference.emailEnabled,
          onChanged: disabled
              ? null
              : (value) => onToggle(
                  preference.category,
                  NotificationChannelType.email,
                  value,
                ),
          dense: true,
        ),
      ],
    );
  }
}

class _DigestScheduleCard extends StatelessWidget {
  const _DigestScheduleCard({
    required this.state,
    required this.l10n,
    required this.onFrequencyChanged,
    required this.onPickTime,
    required this.onPickWeekday,
    required this.onPickMonthDay,
  });

  final ProfileNotificationsState state;
  final AppLocalizations l10n;
  final void Function(NotificationDigestFrequency frequency) onFrequencyChanged;
  final Future<void> Function(NotificationDigestSchedule schedule) onPickTime;
  final void Function(int weekday) onPickWeekday;
  final void Function(int dayOfMonth) onPickMonthDay;

  @override
  Widget build(BuildContext context) {
    final schedule = state.draft.digestSchedule;
    final disabled = state.isSaving;
    final selection = <NotificationDigestFrequency>{schedule.frequency};
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileNotificationsDigestTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              l10n.profileNotificationsDigestSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.spaceM),
            SegmentedButton<NotificationDigestFrequency>(
              segments: [
                ButtonSegment(
                  value: NotificationDigestFrequency.daily,
                  label: Text(l10n.profileNotificationsFrequencyDaily),
                ),
                ButtonSegment(
                  value: NotificationDigestFrequency.weekly,
                  label: Text(l10n.profileNotificationsFrequencyWeekly),
                ),
                ButtonSegment(
                  value: NotificationDigestFrequency.monthly,
                  label: Text(l10n.profileNotificationsFrequencyMonthly),
                ),
              ],
              selected: selection,
              onSelectionChanged: disabled
                  ? null
                  : (value) => onFrequencyChanged(value.first),
            ),
            const SizedBox(height: AppTokens.spaceM),
            _SelectionTile(
              label: l10n.profileNotificationsDigestTimeLabel,
              value: _formatTime(context, schedule.hour, schedule.minute),
              onTap: disabled ? null : () => onPickTime(schedule),
            ),
            if (schedule.frequency == NotificationDigestFrequency.weekly)
              _DropdownTile(
                label: l10n.profileNotificationsDigestWeekdayLabel,
                value: schedule.weekday,
                items: _weekdayItems(context),
                onChanged: disabled
                    ? null
                    : (value) {
                        if (value != null) {
                          onPickWeekday(value);
                        }
                      },
              ),
            if (schedule.frequency == NotificationDigestFrequency.monthly)
              _DropdownTile(
                label: l10n.profileNotificationsDigestMonthdayLabel,
                value: schedule.dayOfMonth,
                items: _monthdayItems(context),
                onChanged: disabled
                    ? null
                    : (value) {
                        if (value != null) {
                          onPickMonthDay(value);
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }
}

class _QuietHoursCard extends StatelessWidget {
  const _QuietHoursCard({
    required this.state,
    required this.l10n,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final ProfileNotificationsState state;
  final AppLocalizations l10n;
  final void Function(bool enabled) onToggle;
  final Future<void> Function(NotificationQuietHours quietHours) onPickStart;
  final Future<void> Function(NotificationQuietHours quietHours) onPickEnd;

  @override
  Widget build(BuildContext context) {
    final quietHours = state.draft.quietHours;
    final disabled = state.isSaving;
    final effectiveDisabled = disabled || !quietHours.enabled;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.profileNotificationsQuietHoursTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(l10n.profileNotificationsQuietHoursSubtitle),
              value: quietHours.enabled,
              onChanged: disabled ? null : onToggle,
            ),
            const SizedBox(height: AppTokens.spaceS),
            _SelectionTile(
              label: l10n.profileNotificationsQuietHoursStartLabel,
              value: _formatTimeFromMinutes(context, quietHours.startMinutes),
              onTap: effectiveDisabled ? null : () => onPickStart(quietHours),
            ),
            _SelectionTile(
              label: l10n.profileNotificationsQuietHoursEndLabel,
              value: _formatTimeFromMinutes(context, quietHours.endMinutes),
              onTap: effectiveDisabled ? null : () => onPickEnd(quietHours),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<DropdownMenuItem<int>> items;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        onChanged: onChanged,
        items: items,
      ),
    );
  }
}

class _SaveFooter extends StatelessWidget {
  const _SaveFooter({
    required this.state,
    required this.l10n,
    required this.onSave,
  });

  final ProfileNotificationsState state;
  final AppLocalizations l10n;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final lastSaved = state.lastSavedAt;
    final helperText = lastSaved == null
        ? null
        : l10n.profileNotificationsLastSaved(
            _formatFullTimestamp(context, lastSaved),
          );
    final canSave = state.hasChanges && !state.isSaving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
            child: Text(
              helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        FilledButton.tonal(
          onPressed: canSave ? onSave : null,
          child: state.isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.profileNotificationsSaveButton),
        ),
      ],
    );
  }
}

class _ProfileNotificationsError extends StatelessWidget {
  const _ProfileNotificationsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.profileHomeRetryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryMetadata {
  const _CategoryMetadata({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

_CategoryMetadata _categoryMetadata(
  NotificationCategory category,
  AppLocalizations l10n,
) {
  switch (category) {
    case NotificationCategory.order:
      return _CategoryMetadata(
        icon: Icons.inventory_2_outlined,
        title: l10n.profileNotificationsCategoryOrder,
        subtitle: l10n.profileNotificationsCategoryOrderDescription,
      );
    case NotificationCategory.production:
      return _CategoryMetadata(
        icon: Icons.precision_manufacturing_outlined,
        title: l10n.profileNotificationsCategoryProduction,
        subtitle: l10n.profileNotificationsCategoryProductionDescription,
      );
    case NotificationCategory.promotion:
      return _CategoryMetadata(
        icon: Icons.discount_outlined,
        title: l10n.profileNotificationsCategoryPromotion,
        subtitle: l10n.profileNotificationsCategoryPromotionDescription,
      );
    case NotificationCategory.guide:
      return _CategoryMetadata(
        icon: Icons.menu_book_outlined,
        title: l10n.profileNotificationsCategoryGuide,
        subtitle: l10n.profileNotificationsCategoryGuideDescription,
      );
    case NotificationCategory.system:
      return _CategoryMetadata(
        icon: Icons.notifications_active_outlined,
        title: l10n.profileNotificationsCategorySystem,
        subtitle: l10n.profileNotificationsCategorySystemDescription,
      );
  }
}

TimeOfDay _timeFromMinutes(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return TimeOfDay(hour: hour, minute: minute);
}

int _minutesFromTime(TimeOfDay time) => time.hour * 60 + time.minute;

String _formatTime(BuildContext context, int hour, int minute) {
  final materialLocalizations = MaterialLocalizations.of(context);
  return materialLocalizations.formatTimeOfDay(
    TimeOfDay(hour: hour, minute: minute),
  );
}

String _formatTimeFromMinutes(BuildContext context, int minutes) {
  final time = _timeFromMinutes(minutes);
  return MaterialLocalizations.of(context).formatTimeOfDay(time);
}

List<DropdownMenuItem<int>> _weekdayItems(BuildContext context) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return [
    for (int weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      DropdownMenuItem(
        value: weekday,
        child: Text(
          DateFormat.EEEE(locale).format(_referenceDateForWeekday(weekday)),
        ),
      ),
  ];
}

List<DropdownMenuItem<int>> _monthdayItems(BuildContext context) {
  return [
    for (int day = 1; day <= 28; day++)
      DropdownMenuItem(value: day, child: Text(day.toString())),
  ];
}

DateTime _referenceDateForWeekday(int weekday) {
  final delta = weekday - DateTime.monday;
  return DateTime(2024, 1, 1 + delta);
}

String _formatFullTimestamp(BuildContext context, DateTime timestamp) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final dateFormatter = DateFormat.yMMMd(locale);
  final timeFormatter = DateFormat.jm(locale);
  return '${dateFormatter.format(timestamp)} ${timeFormatter.format(timestamp)}';
}
