import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_payload.dart';
import '../domain/entities/app_notification.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/entities/notification_schedule.dart';
import '../domain/enums/notification_priority.dart';
import '../domain/enums/notification_type.dart';
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
  Future<void> upsertInboxEntries(
    List<QuevaaNotificationSchedule> schedules,
  ) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      for (final schedule in schedules) {
        final notification = schedule.notification;
        final existing =
            await (_database.select(_database.notificationInboxEntries)
                  ..where(
                    (table) => table.notificationId.equals(notification.id),
                  )
                  ..limit(1))
                .getSingleOrNull();
        final payload = QuevaaNotificationPayload.forSchedule(
          notificationId: notification.id,
          type: notification.type,
          route: notification.route,
          entityId: notification.localRecordId,
        ).encode();
        final companion =
            NotificationInboxEntriesCompanion.insert(
              uuid: existing?.uuid ?? 'notification-inbox-${notification.id}',
              createdAt: existing?.createdAt ?? notification.createdAt,
              updatedAt: now,
              notificationId: notification.id,
              category: notification.type.categoryKey,
              title: notification.title,
              explicitBody: notification.body,
              discreetBody: notification.privacySafeBody,
              scheduledFor: notification.scheduledAt,
              deepLink: notification.route,
              priority: notification.priority.name,
            ).copyWith(
              deliveredAt: Value(existing?.deliveredAt),
              readAt: Value(existing?.readAt),
              payload: Value(payload),
              deletedAt: const Value(null),
            );
        await _database
            .into(_database.notificationInboxEntries)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Stream<List<AppNotification>> watchInbox({int limit = 80}) {
    final now = DateTime.now();
    final query = _database.select(_database.notificationInboxEntries)
      ..where(
        (table) =>
            table.deletedAt.isNull() &
            (table.deliveredAt.isNotNull() |
                table.scheduledFor.isSmallerOrEqualValue(now)),
      )
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.scheduledFor,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_mapInboxRow).toList());
  }

  @override
  Stream<int> watchUnreadCount() {
    final now = DateTime.now();
    final count = _database.notificationInboxEntries.id.count();
    final query = _database.selectOnly(_database.notificationInboxEntries)
      ..addColumns([count])
      ..where(
        _database.notificationInboxEntries.deletedAt.isNull() &
            _database.notificationInboxEntries.readAt.isNull() &
            (_database.notificationInboxEntries.deliveredAt.isNotNull() |
                _database.notificationInboxEntries.scheduledFor
                    .isSmallerOrEqualValue(now)),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  @override
  Future<int> unreadCount() async {
    final now = DateTime.now();
    final count = _database.notificationInboxEntries.id.count();
    final query = _database.selectOnly(_database.notificationInboxEntries)
      ..addColumns([count])
      ..where(
        _database.notificationInboxEntries.deletedAt.isNull() &
            _database.notificationInboxEntries.readAt.isNull() &
            (_database.notificationInboxEntries.deliveredAt.isNotNull() |
                _database.notificationInboxEntries.scheduledFor
                    .isSmallerOrEqualValue(now)),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<void> markInboxEntryRead(int notificationId) async {
    final now = DateTime.now();
    await (_database.update(
      _database.notificationInboxEntries,
    )..where((table) => table.notificationId.equals(notificationId))).write(
      NotificationInboxEntriesCompanion(
        updatedAt: Value(now),
        deliveredAt: Value(now),
        readAt: Value(now),
      ),
    );
  }

  @override
  Future<void> markAllInboxRead() async {
    final now = DateTime.now();
    await (_database.update(_database.notificationInboxEntries)..where(
          (table) =>
              table.deletedAt.isNull() &
              table.readAt.isNull() &
              (table.deliveredAt.isNotNull() |
                  table.scheduledFor.isSmallerOrEqualValue(now)),
        ))
        .write(
          NotificationInboxEntriesCompanion(
            updatedAt: Value(now),
            readAt: Value(now),
          ),
        );
  }

  @override
  Future<void> markSchedulesCancelled(Iterable<int> ids) async {
    final now = DateTime.now();
    for (final id in ids) {
      await (_database.update(
        _database.notificationScheduleStates,
      )..where((table) => table.notificationId.equals(id))).write(
        NotificationScheduleStatesCompanion(
          updatedAt: Value(now),
          isPending: const Value(false),
        ),
      );
      await (_database.update(
        _database.notificationInboxEntries,
      )..where((table) => table.notificationId.equals(id))).write(
        NotificationInboxEntriesCompanion(
          updatedAt: Value(now),
          deletedAt: Value(now),
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

  static AppNotification _mapInboxRow(NotificationInboxEntry row) {
    final priority = QuevaaNotificationPriority.values.firstWhere(
      (candidate) => candidate.name == row.priority,
      orElse: () => QuevaaNotificationPriority.normal,
    );
    return AppNotification(
      id: row.notificationId,
      category: row.category,
      title: row.title,
      explicitBody: row.explicitBody,
      discreetBody: row.discreetBody,
      createdAt: row.createdAt,
      scheduledFor: row.scheduledFor,
      deliveredAt: row.deliveredAt,
      readAt: row.readAt,
      deepLink: row.deepLink,
      payload: row.payload,
      priority: priority,
    );
  }
}
