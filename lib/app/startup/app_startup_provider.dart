import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notifications/domain/services/notification_scheduler.dart';
import '../../features/notifications/application/notification_preferences_provider.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  // Trigger notification reconciliation
  await ref
      .read(notificationSchedulerProvider)
      .reconcileNotifications(NotificationReconciliationReason.appStarted);
});
