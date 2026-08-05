import '../../features/notifications/domain/enums/notification_privacy_mode.dart';
import 'local_notification_service.dart';
import 'notification_initializer.dart';
import 'notification_permission_service.dart';

typedef NotificationPrivacyMode = QuevaaNotificationPrivacyMode;

class NotificationService {
  final QuevaaLocalNotificationService _local =
      QuevaaLocalNotificationService.instance;

  Future<void> initialize() async {
    await QuevaaNotificationInitializer.initialize(onTap: (_) {});
  }

  Future<bool> requestPermission() {
    return QuevaaNotificationPermissionService(
      _local.plugin,
    ).requestPermission();
  }

  static Map<String, String> formatNotificationContent({
    required String explicitTitle,
    required String explicitBody,
    required NotificationPrivacyMode mode,
  }) {
    switch (mode) {
      case NotificationPrivacyMode.explicit:
        return {'title': explicitTitle, 'body': explicitBody};
      case NotificationPrivacyMode.discreet:
        return {
          'title': 'Quevaa Update',
          'body': 'Your daily Quevaa check-in is ready.',
        };
      case NotificationPrivacyMode.hidden:
        return {'title': 'Quevaa', 'body': 'Open the app to view your update.'};
    }
  }
}
