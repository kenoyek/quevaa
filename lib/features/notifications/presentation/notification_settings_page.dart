import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/notifications/notification_permission_service.dart';
import '../application/notification_controller.dart';
import '../application/notification_preferences_provider.dart';
import '../application/pending_notifications_provider.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/enums/notification_privacy_mode.dart';
import 'widgets/notification_category_tile.dart';
import 'widgets/notification_permission_card.dart';
import 'widgets/quiet_hours_selector.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  QuevaaNotificationPreferences? _draft;
  String? _lastLoadedSignature;
  Future<void> _saveQueue = Future.value();
  var _saveSerial = 0;
  var _savingDraft = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final permissionStatusAsync = ref.watch(
      notificationPermissionStatusProvider,
    );
    final pendingAsync = ref.watch(pendingNotificationsProvider);
    final controllerState = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/me');
            }
          },
        ),
        title: const Text('Notification preferences'),
      ),
      body: preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.terracottaPrimary,
                ),
                const SizedBox(height: 12),
                const Text(
                  "We couldn't load notification preferences.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(notificationPreferencesProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (preferences) {
          final draft = _syncDraft(preferences);
          final permissionStatus = permissionStatusAsync.valueOrNull;
          final permissionGranted =
              permissionStatus == QuevaaNotificationPermissionStatus.granted;
          final permissionKnownDenied =
              permissionStatus == QuevaaNotificationPermissionStatus.denied;
          final notificationsEnabled = draft.enabled && permissionGranted;
          final permissionBlocked =
              permissionKnownDenied &&
              (draft.enabled ||
                  draft.permissionInvitationSeen ||
                  draft.permissionPreviouslyDeclined);
          final controllerBusy = controllerState.isLoading && !_savingDraft;
          final toolsBusy = controllerState.isLoading || _savingDraft;
          final previewMode =
              draft.privacyMode == QuevaaNotificationPrivacyMode.hidden
              ? QuevaaNotificationPrivacyMode.discreet
              : draft.privacyMode;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              NotificationPermissionCard(
                enabled: notificationsEnabled,
                permissionBlocked: permissionBlocked,
                permissionPreviouslyDeclined:
                    draft.permissionPreviouslyDeclined,
                onEnable: controller.requestAndEnable,
                onDismiss: controller.dismissPermissionInvitation,
                onOpenSettings: controller.openSystemNotificationSettings,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification previews',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose how much detail Quevaa shows outside the app.',
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<QuevaaNotificationPrivacyMode>(
                        segments: const [
                          ButtonSegment(
                            value: QuevaaNotificationPrivacyMode.explicit,
                            label: Text('Detailed'),
                            icon: Icon(Icons.article_outlined),
                          ),
                          ButtonSegment(
                            value: QuevaaNotificationPrivacyMode.discreet,
                            label: Text('Discreet'),
                            icon: Icon(Icons.visibility_off_outlined),
                          ),
                        ],
                        selected: {previewMode},
                        onSelectionChanged: controllerBusy
                            ? null
                            : (selection) {
                                _updateDraft(
                                  draft.copyWith(privacyMode: selection.first),
                                  persist: true,
                                );
                              },
                      ),
                      const SizedBox(height: 14),
                      _PrivacyPreview(mode: previewMode),
                      if (_savingDraft) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiet hours',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      QuietHoursSelector(
                        startMinutes: draft.quietStartMinutes,
                        endMinutes: draft.quietEndMinutes,
                        onStartChanged: !notificationsEnabled
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(quietStartMinutes: value),
                              ),
                        onStartChangeEnd: !notificationsEnabled
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(quietStartMinutes: value),
                                persist: true,
                              ),
                        onEndChanged: !notificationsEnabled
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(quietEndMinutes: value),
                              ),
                        onEndChangeEnd: !notificationsEnabled
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(quietEndMinutes: value),
                                persist: true,
                              ),
                      ),
                      Slider(
                        value: draft.dailyCap.toDouble(),
                        min: 1,
                        max: 8,
                        divisions: 7,
                        label: '${draft.dailyCap} per day',
                        onChanged: !notificationsEnabled
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(dailyCap: value.round()),
                              ),
                        onChangeEnd: !notificationsEnabled
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(dailyCap: value.round()),
                                persist: true,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      for (final category in _categories)
                        NotificationCategoryTile(
                          icon: category.icon,
                          title: category.title,
                          subtitle: category.subtitle,
                          value: draft.categoryEnabled[category.key] ?? true,
                          onChanged: !notificationsEnabled || controllerBusy
                              ? null
                              : (value) => _updateDraft(
                                  draft.copyWith(
                                    categoryEnabled: {
                                      ...draft.categoryEnabled,
                                      category.key: value,
                                    },
                                  ),
                                  persist: true,
                                ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Notification sound'),
                        value: draft.soundEnabled,
                        onChanged: !notificationsEnabled || controllerBusy
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(soundEnabled: value),
                                persist: true,
                              ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vibration'),
                        value: draft.vibrationEnabled,
                        onChanged: !notificationsEnabled || controllerBusy
                            ? null
                            : (value) => _updateDraft(
                                draft.copyWith(vibrationEnabled: value),
                                persist: true,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tools',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: toolsBusy
                                ? null
                                : controller.sendTestNotification,
                            icon: const Icon(Icons.notification_add_rounded),
                            label: const Text('Send test notification'),
                          ),
                          OutlinedButton.icon(
                            onPressed: toolsBusy ? null : controller.cancelAll,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Cancel all reminders'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      pendingAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) =>
                            const Text('Pending reminders are unavailable.'),
                        data: (pending) =>
                            Text('${pending.length} native pending reminders'),
                      ),
                    ],
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: pendingAsync.maybeWhen(
                      data: (pending) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug pending reminders',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final item in pending)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('ID ${item.id}'),
                              subtitle: Text(item.payload ?? 'No payload'),
                            ),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  QuevaaNotificationPreferences _syncDraft(
    QuevaaNotificationPreferences preferences,
  ) {
    final signature = _preferencesSignature(preferences);
    final shouldResetDraft =
        _draft == null || (!_savingDraft && _lastLoadedSignature != signature);
    if (shouldResetDraft) {
      _draft = preferences;
      _lastLoadedSignature = signature;
    }
    return _draft!;
  }

  void _updateDraft(
    QuevaaNotificationPreferences preferences, {
    bool persist = false,
  }) {
    setState(() => _draft = preferences);
    if (persist) _queueSave(preferences);
  }

  void _queueSave(QuevaaNotificationPreferences preferences) {
    final serial = ++_saveSerial;
    setState(() => _savingDraft = true);
    _saveQueue = _saveQueue.catchError((_) {}).then((_) {
      if (!mounted) return Future<void>.value();
      return ref
          .read(notificationControllerProvider.notifier)
          .savePreferences(preferences);
    });
    _saveQueue.whenComplete(() {
      if (!mounted || serial != _saveSerial) return;
      setState(() => _savingDraft = false);
      ref.invalidate(notificationPreferencesProvider);
      ref.invalidate(pendingNotificationsProvider);
    });
  }

  String _preferencesSignature(QuevaaNotificationPreferences preferences) {
    return [
      preferences.enabled,
      preferences.permissionInvitationSeen,
      preferences.permissionPreviouslyDeclined,
      preferences.privacyMode.name,
      preferences.quietStartMinutes,
      preferences.quietEndMinutes,
      preferences.dailyCap,
      preferences.soundEnabled,
      preferences.vibrationEnabled,
      preferences.lastKnownTimezone,
      preferences.lastReconciliationAt?.millisecondsSinceEpoch,
      preferences.scheduleVersion,
      preferences.categoryEnabled,
      preferences.categoryTimes,
    ].join('|');
  }
}

class _PrivacyPreview extends StatelessWidget {
  const _PrivacyPreview({required this.mode});

  final QuevaaNotificationPrivacyMode mode;

  @override
  Widget build(BuildContext context) {
    final detailed = mode == QuevaaNotificationPrivacyMode.explicit;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            detailed
                ? 'Your period may start tomorrow.'
                : 'You have a Quevaa update.',
          ),
        ],
      ),
    );
  }
}

class _CategoryInfo {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;

  const _CategoryInfo({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

const _categories = [
  _CategoryInfo(
    key: 'cycle',
    icon: Icons.calendar_month_rounded,
    title: 'Cycle reminders',
    subtitle: 'Period ranges and daily check-ins',
  ),
  _CategoryInfo(
    key: 'conception',
    icon: Icons.eco_rounded,
    title: 'Trying to conceive',
    subtitle: 'Fertility observations and private TTC prompts',
  ),
  _CategoryInfo(
    key: 'medication',
    icon: Icons.medication_rounded,
    title: 'Supplements and medication',
    subtitle: 'User-selected supplement and medication reminders',
  ),
  _CategoryInfo(
    key: 'tasks',
    icon: Icons.task_alt_rounded,
    title: 'Tasks and productivity',
    subtitle: 'Task due, routines and focus sessions',
  ),
  _CategoryInfo(
    key: 'meals',
    icon: Icons.restaurant_rounded,
    title: 'Meal reminders',
    subtitle: 'Nigerian meal suggestions',
  ),
  _CategoryInfo(
    key: 'hydration',
    icon: Icons.water_drop_outlined,
    title: 'Hydration',
    subtitle: 'Two or three gentle reminders per day',
  ),
  _CategoryInfo(
    key: 'workouts',
    icon: Icons.fitness_center_rounded,
    title: 'Workouts',
    subtitle: 'Planned movement reminders',
  ),
  _CategoryInfo(
    key: 'journal',
    icon: Icons.edit_note_rounded,
    title: 'Journal',
    subtitle: 'Gentle reflection prompts',
  ),
  _CategoryInfo(
    key: 'weeklyReview',
    icon: Icons.insights_rounded,
    title: 'Weekly review',
    subtitle: 'Planning and pattern summaries',
  ),
];
