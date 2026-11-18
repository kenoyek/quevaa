import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/database_provider.dart';
import '../../core/notifications/notification_timezone_service.dart';
import '../../features/notifications/application/notification_preferences_provider.dart';
import '../../features/notifications/application/notification_snapshot_provider.dart';
import '../../features/notifications/domain/services/notification_scheduler.dart';

final appStartupProvider =
    FutureProvider.family<void, NotificationReconciliationReason>((
      ref,
      reason,
    ) async {
      final scheduler = ref.read(notificationSchedulerProvider);
      final database = ref.read(appDatabaseProvider);
      await quevaaNotificationTimezoneService.initializeTimezone();
      final snapshot = await buildNotificationSourceSnapshotFromDatabase(
        database,
      );
      await scheduler.reconcileNotifications(reason, snapshot: snapshot);
    });
