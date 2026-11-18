import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/notification_permission_service.dart';
import '../../application/notification_controller.dart';
import '../../application/notification_preferences_provider.dart';
import 'notification_permission_card.dart';

class NotificationPermissionInvitation extends ConsumerWidget {
  const NotificationPermissionInvitation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!QuevaaLocalNotificationService.instance.isSupported) {
      return const SizedBox.shrink();
    }
    final preferences = ref.watch(notificationPreferencesProvider).valueOrNull;
    if (preferences == null) return const SizedBox.shrink();

    final permission = ref
        .watch(notificationPermissionStatusProvider)
        .valueOrNull;
    final blocked =
        preferences.enabled &&
        permission == QuevaaNotificationPermissionStatus.denied;
    final needsInvitation =
        !preferences.enabled && !preferences.permissionInvitationSeen;
    if (!needsInvitation && !blocked) return const SizedBox.shrink();

    final controller = ref.read(notificationControllerProvider.notifier);
    final busy = ref.watch(notificationControllerProvider).isLoading;
    ref.listen(notificationControllerProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quevaa could not finish setting up reminders. Open Notification preferences to retry.',
            ),
          ),
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NotificationPermissionCard(
        enabled: false,
        permissionBlocked: blocked,
        permissionPreviouslyDeclined: false,
        onEnable: busy ? null : controller.requestAndEnable,
        onDismiss: busy ? null : controller.dismissPermissionInvitation,
        onOpenSettings: controller.openSystemNotificationSettings,
      ),
    );
  }
}
