import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notification_service.dart';

final pendingNotificationsProvider =
    FutureProvider<List<PendingNotificationRequest>>((ref) {
      return QuevaaLocalNotificationService.instance.pending();
    });
