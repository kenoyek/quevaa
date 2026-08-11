import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../core/notifications/notification_permission_service.dart';
import '../../../core/notifications/notification_system_settings.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/enums/notification_privacy_mode.dart';
import '../domain/services/notification_scheduler.dart';
import 'notification_preferences_provider.dart';
import 'notification_snapshot_provider.dart';
import 'pending_notifications_provider.dart';

class NotificationController extends StateNotifier<AsyncValue<void>> {
  NotificationController(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> requestAndEnable() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final permissionService = ref.read(notificationPermissionServiceProvider);
      await permissionService.requestPermission();
      final status = await permissionService.status();
      final permission = status == QuevaaNotificationPermissionStatus.granted;
      final repository = ref.read(notificationRepositoryProvider);
      final preferences = await repository.loadPreferences();
      await repository.savePreferences(
        preferences.copyWith(
          enabled: permission,
          permissionInvitationSeen: true,
          permissionPreviouslyDeclined: !permission,
        ),
      );
      if (permission) {
        await ref
            .read(notificationSchedulerProvider)
            .reconcileNotifications(
              NotificationReconciliationReason.preferencesChanged,
              snapshot: ref.read(notificationSourceSnapshotProvider),
            );
      }
      ref.invalidate(notificationPreferencesProvider);
      ref.invalidate(notificationPermissionStatusProvider);
      ref.invalidate(pendingNotificationsProvider);
    });
  }

  Future<void> dismissPermissionInvitation() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(notificationRepositoryProvider);
      final preferences = await repository.loadPreferences();
      await repository.savePreferences(
        preferences.copyWith(permissionInvitationSeen: true),
      );
      ref.invalidate(notificationPreferencesProvider);
      ref.invalidate(notificationPermissionStatusProvider);
    });
  }

  Future<void> savePreferences(
    QuevaaNotificationPreferences preferences,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(preferences);
      await ref
          .read(notificationSchedulerProvider)
          .reconcileNotifications(
            NotificationReconciliationReason.preferencesChanged,
            snapshot: ref.read(notificationSourceSnapshotProvider),
          );
      ref.invalidate(notificationPreferencesProvider);
      ref.invalidate(notificationPermissionStatusProvider);
      ref.invalidate(pendingNotificationsProvider);
    });
  }

  Future<void> updatePrivacyMode(QuevaaNotificationPrivacyMode mode) async {
    final preferences = await ref
        .read(notificationRepositoryProvider)
        .loadPreferences();
    await savePreferences(preferences.copyWith(privacyMode: mode));
  }

  Future<void> toggleCategory(String category, bool enabled) async {
    final preferences = await ref
        .read(notificationRepositoryProvider)
        .loadPreferences();
    await savePreferences(
      preferences.copyWith(
        categoryEnabled: {...preferences.categoryEnabled, category: enabled},
      ),
    );
  }

  Future<void> updateQuietHours({
    required int startMinutes,
    required int endMinutes,
  }) async {
    final preferences = await ref
        .read(notificationRepositoryProvider)
        .loadPreferences();
    await savePreferences(
      preferences.copyWith(
        quietStartMinutes: startMinutes,
        quietEndMinutes: endMinutes,
      ),
    );
  }

  Future<void> sendTestNotification() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final permissionService = ref.read(notificationPermissionServiceProvider);
      await permissionService.requestPermission();
      final status = await permissionService.status();
      final permission = status == QuevaaNotificationPermissionStatus.granted;
      if (!permission) {
        throw StateError('Notification permission is disabled.');
      }
      await QuevaaLocalNotificationService.instance.scheduleTestNotification();
      ref.invalidate(pendingNotificationsProvider);
    });
  }

  Future<void> openSystemNotificationSettings() async {
    await QuevaaNotificationSystemSettings.openNotificationSettings();
  }

  Future<void> cancelAll() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await QuevaaLocalNotificationService.instance.cancelAll();
      ref.invalidate(pendingNotificationsProvider);
    });
  }
}

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, AsyncValue<void>>(
      NotificationController.new,
    );
