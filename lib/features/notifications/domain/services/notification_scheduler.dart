import 'package:timezone/timezone.dart' as tz;

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/notification_permission_service.dart';
import '../../../../core/notifications/notification_timezone_service.dart';
import '../entities/notification_schedule.dart';
import '../repositories/notification_repository.dart';
import 'smart_notification_engine.dart';

enum NotificationReconciliationReason {
  appStarted,
  appResumed,
  timezoneChanged,
  preferencesChanged,
  cycleDataChanged,
  conceptionDataChanged,
  taskChanged,
  mealPlanChanged,
  workoutPlanChanged,
  journalChanged,
  scheduleVersionChanged,
  manualRefresh,
}

class NotificationReconciliationResult {
  final NotificationReconciliationReason reason;
  final int desiredCount;
  final int scheduledCount;
  final int cancelledCount;
  final int unchangedCount;
  final bool permissionGranted;
  final String timezone;

  const NotificationReconciliationResult({
    required this.reason,
    required this.desiredCount,
    required this.scheduledCount,
    required this.cancelledCount,
    required this.unchangedCount,
    required this.permissionGranted,
    required this.timezone,
  });
}

class NotificationScheduler {
  NotificationScheduler({
    required this.repository,
    required this.engine,
    required this.localService,
    required this.permissionService,
    required this.timezoneService,
  });

  final NotificationRepository repository;
  final SmartNotificationEngine engine;
  final QuevaaLocalNotificationService localService;
  final QuevaaNotificationPermissionService permissionService;
  final QuevaaNotificationTimezoneService timezoneService;

  Future<NotificationReconciliationResult>? _activeReconciliation;

  Future<NotificationReconciliationResult> reconcileNotifications(
    NotificationReconciliationReason reason, {
    NotificationSourceSnapshot snapshot = const NotificationSourceSnapshot(),
  }) {
    final active = _activeReconciliation;
    if (active != null) return active;
    final operation = _reconcile(reason, snapshot: snapshot);
    _activeReconciliation = operation;
    operation.whenComplete(() => _activeReconciliation = null);
    return operation;
  }

  Future<NotificationReconciliationResult> _reconcile(
    NotificationReconciliationReason reason, {
    required NotificationSourceSnapshot snapshot,
  }) async {
    final preferences = await repository.loadPreferences();
    final timezoneName = await timezoneService.initializeTimezone();
    final permission = await permissionService.status();
    if (!preferences.enabled ||
        permission == QuevaaNotificationPermissionStatus.denied) {
      final persisted = await repository.loadScheduleFingerprints();
      if (persisted.isNotEmpty) {
        await localService.cancelAll();
        await repository.markSchedulesCancelled(persisted.keys);
      }
      return NotificationReconciliationResult(
        reason: reason,
        desiredCount: 0,
        scheduledCount: 0,
        cancelledCount: persisted.length,
        unchangedCount: 0,
        permissionGranted: false,
        timezone: timezoneName,
      );
    }

    final now = timezoneService.localLocation.currentTime;
    final desired = engine.buildDesiredSchedules(
      preferences: preferences,
      snapshot: snapshot,
      location: timezoneService.localLocation,
      now: now,
    );
    final desiredById = {for (final schedule in desired) schedule.id: schedule};
    final persisted = await repository.loadScheduleFingerprints();
    final pendingNative = await localService.pending();
    final pendingNativeIds = pendingNative.map((request) => request.id).toSet();

    final obsoleteIds = persisted.keys
        .where(
          (id) =>
              !desiredById.containsKey(id) || !pendingNativeIds.contains(id),
        )
        .toSet();
    final toSchedule = <QuevaaNotificationSchedule>[];
    var unchanged = 0;
    for (final schedule in desired) {
      if (persisted[schedule.id] == schedule.fingerprint &&
          pendingNativeIds.contains(schedule.id)) {
        unchanged++;
      } else {
        toSchedule.add(schedule);
      }
    }

    for (final id in obsoleteIds) {
      await localService.cancel(id);
    }
    for (final schedule in toSchedule) {
      await localService.schedule(schedule);
    }
    await repository.markSchedulesCancelled(obsoleteIds);
    await repository.upsertScheduleStates(desired);
    await repository.persistReconciliation(DateTime.now(), timezoneName);

    return NotificationReconciliationResult(
      reason: reason,
      desiredCount: desired.length,
      scheduledCount: toSchedule.length,
      cancelledCount: obsoleteIds.length,
      unchangedCount: unchanged,
      permissionGranted:
          permission == QuevaaNotificationPermissionStatus.granted,
      timezone: timezoneName,
    );
  }
}

extension on tz.Location {
  tz.TZDateTime get currentTime => tz.TZDateTime.now(this);
}
