import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/entities/notification_schedule.dart';
import '../domain/repositories/notification_repository.dart';
import 'notification_preference_store.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._database)
    : _store = NotificationPreferenceStore(_database);

  final AppDatabase _database;
  final NotificationPreferenceStore _store;

  @override
  Future<QuevaaNotificationPreferences> loadPreferences() => _store.load();

  @override
  Future<void> savePreferences(QuevaaNotificationPreferences preferences) {
    return _store.save(preferences);
  }

  @override
  Future<Map<int, String>> loadScheduleFingerprints() async {
    final rows = await _database
        .select(_database.notificationScheduleStates)
        .get();
    return {
      for (final row in rows)
        if (row.isPending) row.notificationId: row.fingerprint,
    };
  }

  @override
  Future<void> upsertScheduleStates(
    List<QuevaaNotificationSchedule> schedules,
  ) async {
    await _database.batch((batch) {
      for (final schedule in schedules) {
        final notification = schedule.notification;
        batch.insert(
          _database.notificationScheduleStates,
          NotificationScheduleStatesCompanion.insert(
            uuid: 'notification-${notification.id}',
            createdAt: notification.createdAt,
            updatedAt: DateTime.now(),
            notificationId: notification.id,
            notificationType: notification.type.name,
            scheduledAt: notification.scheduledAt,
            timezoneName: schedule.timezoneName,
            route: notification.route,
            priority: notification.priority.name,
            fingerprint: schedule.fingerprint,
          ).copyWith(
            localRecordId: Value(notification.localRecordId),
            isPending: const Value(true),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<void> markSchedulesCancelled(Iterable<int> ids) async {
    for (final id in ids) {
      await (_database.update(
        _database.notificationScheduleStates,
      )..where((table) => table.notificationId.equals(id))).write(
        NotificationScheduleStatesCompanion(
          updatedAt: Value(DateTime.now()),
          isPending: const Value(false),
        ),
      );
    }
  }

  @override
  Future<void> persistReconciliation(
    DateTime reconciledAt,
    String timezone,
  ) async {
    final preferences = await loadPreferences();
    await savePreferences(
      preferences.copyWith(
        lastKnownTimezone: timezone,
        lastReconciliationAt: reconciledAt,
      ),
    );
  }
}
