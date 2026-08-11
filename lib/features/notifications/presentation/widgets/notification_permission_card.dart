import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class NotificationPermissionCard extends StatelessWidget {
  final bool enabled;
  final bool permissionBlocked;
  final bool permissionPreviouslyDeclined;
  final VoidCallback onEnable;
  final VoidCallback onDismiss;
  final VoidCallback onOpenSettings;

  const NotificationPermissionCard({
    super.key,
    required this.enabled,
    required this.permissionBlocked,
    required this.permissionPreviouslyDeclined,
    required this.onEnable,
    required this.onDismiss,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (enabled) {
      return const SizedBox.shrink();
    }

    final blocked = permissionBlocked || permissionPreviouslyDeclined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.terracottaPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stay gently prepared',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              blocked
                  ? 'Notifications are currently blocked for Quevaa on this device. Open Android notification settings, allow notifications, then return here to enable reminders.'
                  : 'Quevaa can remind you about cycle check-ins, planned tasks, meals, workouts and private wellness routines. Your reminders are scheduled on this device. No internet connection is required.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: blocked
                  ? [
                      FilledButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Open settings'),
                      ),
                      OutlinedButton(
                        onPressed: onEnable,
                        child: const Text('Try again'),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: onDismiss,
                        child: const Text('Not now'),
                      ),
                      FilledButton(
                        onPressed: onEnable,
                        child: const Text('Enable reminders'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
