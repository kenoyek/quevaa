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

  Future<void> _reconciliationQueue = Future.value();

  Future<NotificationReconciliationResult> reconcileNotifications(
    NotificationReconciliationReason reason, {
    NotificationSourceSnapshot snapshot = const NotificationSourceSnapshot(),
  }) {
    final operation = _reconciliationQueue.then(
      (_) => _reconcile(reason, snapshot: snapshot),
    );
    _reconciliationQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
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
        permission != QuevaaNotificationPermissionStatus.granted) {
      final persisted = await repository.loadScheduleFingerprints();
      final pending = await localService.pending();
      for (final request in pending) {
        if (request.id ==
                QuevaaLocalNotificationService.scheduledTestNotificationId &&
            permission == QuevaaNotificationPermissionStatus.granted) {
          continue;
        }
        await localService.cancel(request.id);
      }
      await repository.markSchedulesCancelled(persisted.keys);
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

    final persisted = await repository.loadScheduleFingerprints();
    final pendingNative = await localService.pending();
    final pendingNativeIds = pendingNative
        .map((request) => request.id)
        .where(
          (id) =>
              id != QuevaaLocalNotificationService.scheduledTestNotificationId,
        )
        .toSet();
    final location = timezoneService.localLocation;
    final desired = engine.buildDesiredSchedules(
      preferences: preferences,
      snapshot: snapshot,
      location: location,
      now: location.currentTime,
      // Android may still have an inexact alarm queued after its target time.
      retainPending: (schedule) =>
          pendingNativeIds.contains(schedule.id) &&
          persisted[schedule.id] == schedule.fingerprint,
    );
    final desiredIds = desired.map((schedule) => schedule.id).toSet();
    final obsoleteIds = persisted.keys.toSet().difference(desiredIds);
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

    for (final id in pendingNativeIds.difference(desiredIds)) {
      await localService.cancel(id);
    }
    for (final schedule in toSchedule) {
      await localService.schedule(schedule);
    }
    await repository.markSchedulesCancelled(obsoleteIds);
    await repository.upsertScheduleStates(desired);
    await repository.upsertInboxEntries(desired);
    await repository.persistReconciliation(DateTime.now(), timezoneName);

    return NotificationReconciliationResult(
      reason: reason,
      desiredCount: desired.length,
      scheduledCount: toSchedule.length,
      cancelledCount: obsoleteIds.length,
      unchangedCount: unchanged,
      permissionGranted: true,
      timezone: timezoneName,
    );
  }
}

extension on tz.Location {
  tz.TZDateTime get currentTime => tz.TZDateTime.now(this);
}
