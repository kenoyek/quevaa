import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class NotificationPermissionCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onEnable;

  const NotificationPermissionCard({
    super.key,
    required this.enabled,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            const Text(
              'Quevaa can remind you about cycle check-ins, planned tasks, meals, workouts and private wellness routines. Your reminders are scheduled on this device. No internet connection is required.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton(onPressed: () {}, child: const Text('Not now')),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: enabled ? null : onEnable,
                  child: Text(enabled ? 'Enabled' : 'Enable reminders'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
