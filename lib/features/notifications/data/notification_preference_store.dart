import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/enums/notification_privacy_mode.dart';

class NotificationPreferenceStore {
  NotificationPreferenceStore(this._database);

  final AppDatabase _database;

  Future<QuevaaNotificationPreferences> load() async {
    final row = await (_database.select(
      _database.notificationPreferenceRows,
    )..limit(1)).getSingleOrNull();
    if (row == null) return QuevaaNotificationPreferences.defaults();

    return QuevaaNotificationPreferences(
      enabled: row.enabled,
      permissionInvitationSeen: row.permissionInvitationSeen,
      permissionPreviouslyDeclined: row.permissionPreviouslyDeclined,
      privacyMode: QuevaaNotificationPrivacyMode.values.firstWhere(
        (mode) => mode.name == row.privacyMode,
        orElse: () => QuevaaNotificationPrivacyMode.discreet,
      ),
      quietStartMinutes: row.quietStartMinutes,
      quietEndMinutes: row.quietEndMinutes,
      dailyCap: row.dailyCap,
      soundEnabled: row.soundEnabled,
      vibrationEnabled: row.vibrationEnabled,
      lastKnownTimezone: row.lastKnownTimezone,
      lastReconciliationAt: row.lastReconciliationAt,
      scheduleVersion: row.notificationScheduleVersion,
      categoryEnabled: _decodeBoolMap(row.categoryEnabledJson),
      categoryTimes: _decodeIntMap(row.categoryTimesJson),
    );
  }

  Future<void> save(QuevaaNotificationPreferences preferences) async {
    final existing = await (_database.select(
      _database.notificationPreferenceRows,
    )..limit(1)).getSingleOrNull();
    final companion =
        NotificationPreferenceRowsCompanion.insert(
          uuid: existing?.uuid ?? 'notification-preferences',
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ).copyWith(
          enabled: Value(preferences.enabled),
          permissionInvitationSeen: Value(preferences.permissionInvitationSeen),
          permissionPreviouslyDeclined: Value(
            preferences.permissionPreviouslyDeclined,
          ),
          privacyMode: Value(preferences.privacyMode.name),
          quietStartMinutes: Value(preferences.quietStartMinutes),
          quietEndMinutes: Value(preferences.quietEndMinutes),
          dailyCap: Value(preferences.dailyCap),
          soundEnabled: Value(preferences.soundEnabled),
          vibrationEnabled: Value(preferences.vibrationEnabled),
          lastKnownTimezone: Value(preferences.lastKnownTimezone),
          lastReconciliationAt: Value(preferences.lastReconciliationAt),
          notificationScheduleVersion: Value(preferences.scheduleVersion),
          categoryEnabledJson: Value(jsonEncode(preferences.categoryEnabled)),
          categoryTimesJson: Value(jsonEncode(preferences.categoryTimes)),
        );

    if (existing == null) {
      await _database
          .into(_database.notificationPreferenceRows)
          .insert(companion);
    } else {
      await (_database.update(
        _database.notificationPreferenceRows,
      )..where((table) => table.id.equals(existing.id))).write(companion);
    }
  }

  static Map<String, bool> _decodeBoolMap(String raw) {
    final defaults = QuevaaNotificationPreferences.defaults().categoryEnabled;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return defaults;
      return {
        ...defaults,
        for (final entry in decoded.entries)
          if (entry.value is bool) entry.key: entry.value as bool,
      };
    } catch (_) {
      return defaults;
    }
  }

  static Map<String, int> _decodeIntMap(String raw) {
    final defaults = QuevaaNotificationPreferences.defaults().categoryTimes;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return defaults;
      return {
        ...defaults,
        for (final entry in decoded.entries)
          if (entry.value is int) entry.key: entry.value as int,
      };
    } catch (_) {
      return defaults;
    }
  }
}
