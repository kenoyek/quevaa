import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../application/notification_controller.dart';
import '../application/notification_preferences_provider.dart';
import '../application/pending_notifications_provider.dart';
import '../domain/enums/notification_privacy_mode.dart';
import 'widgets/notification_category_tile.dart';
import 'widgets/notification_permission_card.dart';
import 'widgets/quiet_hours_selector.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);
    final pendingAsync = ref.watch(pendingNotificationsProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      appBar: AppBar(title: const Text('Notifications')),
      body: preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load settings: $error')),
        data: (preferences) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              NotificationPermissionCard(
                enabled: preferences.enabled,
                onEnable: controller.requestAndEnable,
                onDismiss: controller.dismissPermissionInvitation,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy mode',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<QuevaaNotificationPrivacyMode>(
                        segments: QuevaaNotificationPrivacyMode.values
                            .map(
                              (mode) => ButtonSegment(
                                value: mode,
                                label: Text(mode.label),
                              ),
                            )
                            .toList(),
                        selected: {preferences.privacyMode},
                        onSelectionChanged: (selection) =>
                            controller.updatePrivacyMode(selection.first),
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
                        'Quiet hours',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      QuietHoursSelector(
                        startMinutes: preferences.quietStartMinutes,
                        endMinutes: preferences.quietEndMinutes,
                        onStartChanged: (value) => controller.updateQuietHours(
                          startMinutes: value,
                          endMinutes: preferences.quietEndMinutes,
                        ),
                        onEndChanged: (value) => controller.updateQuietHours(
                          startMinutes: preferences.quietStartMinutes,
                          endMinutes: value,
                        ),
                      ),
                      Slider(
                        value: preferences.dailyCap.toDouble(),
                        min: 1,
                        max: 8,
                        divisions: 7,
                        label: '${preferences.dailyCap} per day',
                        onChanged: (value) {
                          controller.savePreferences(
                            preferences.copyWith(dailyCap: value.round()),
                          );
                        },
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
                          value:
                              preferences.categoryEnabled[category.key] ?? true,
                          onChanged: (value) =>
                              controller.toggleCategory(category.key, value),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Notification sound'),
                        value: preferences.soundEnabled,
                        onChanged: (value) => controller.savePreferences(
                          preferences.copyWith(soundEnabled: value),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vibration'),
                        value: preferences.vibrationEnabled,
                        onChanged: (value) => controller.savePreferences(
                          preferences.copyWith(vibrationEnabled: value),
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
                            onPressed: controller.sendTestNotification,
                            icon: const Icon(Icons.notification_add_rounded),
                            label: const Text('Send test notification'),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.cancelAll,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Cancel all reminders'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      pendingAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) =>
                            Text('Pending unavailable: $error'),
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
