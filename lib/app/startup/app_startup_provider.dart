import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/database_provider.dart';
import '../../features/notifications/application/notification_preferences_provider.dart';
import '../../features/notifications/application/notification_snapshot_provider.dart';
import '../../features/notifications/domain/services/notification_scheduler.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  final snapshot = await buildNotificationSourceSnapshotFromDatabase(
    ref.read(appDatabaseProvider),
  );
  await ref
      .read(notificationSchedulerProvider)
      .reconcileNotifications(
        NotificationReconciliationReason.appStarted,
        snapshot: snapshot,
      );
});
