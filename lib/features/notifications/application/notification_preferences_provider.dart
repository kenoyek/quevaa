import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../core/notifications/notification_permission_service.dart';
import '../../../core/notifications/notification_timezone_service.dart';
import '../../../core/providers/database_provider.dart';
import '../data/notification_repository_impl.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/services/notification_scheduler.dart';
import '../domain/services/smart_notification_engine.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(appDatabaseProvider));
});

final notificationPermissionServiceProvider =
    Provider<QuevaaNotificationPermissionService>((ref) {
      return QuevaaNotificationPermissionService(
        QuevaaLocalNotificationService.instance.plugin,
      );
    });

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(
    repository: ref.watch(notificationRepositoryProvider),
    engine: const SmartNotificationEngine(),
    localService: QuevaaLocalNotificationService.instance,
    permissionService: ref.watch(notificationPermissionServiceProvider),
    timezoneService: quevaaNotificationTimezoneService,
  );
});

final notificationPreferencesProvider =
    FutureProvider<QuevaaNotificationPreferences>((ref) {
      return ref.watch(notificationRepositoryProvider).loadPreferences();
    });
