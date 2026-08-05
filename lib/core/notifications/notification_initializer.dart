import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'local_notification_service.dart';
import 'notification_timezone_service.dart';

class QuevaaNotificationInitializer {
  const QuevaaNotificationInitializer._();

  static Future<void> initialize({
    required void Function(NotificationResponse response) onTap,
  }) async {
    await quevaaNotificationTimezoneService.initializeTimezone();
    await QuevaaLocalNotificationService.instance.initialize(onTap: onTap);
  }
}
