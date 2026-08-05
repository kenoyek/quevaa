import 'package:timezone/timezone.dart' as tz;

import '../../../../core/notifications/notification_constants.dart';
import '../entities/notification_preferences.dart';
import '../entities/notification_schedule.dart';
import '../entities/quevaa_notification.dart';
import '../enums/notification_priority.dart';
import '../enums/notification_privacy_mode.dart';
import '../enums/notification_type.dart';

class NotificationPolicyEngine {
  const NotificationPolicyEngine();

  List<QuevaaNotificationSchedule> applyPolicies({
    required List<QuevaaNotificationSchedule> desired,
    required QuevaaNotificationPreferences preferences,
    required tz.TZDateTime now,
  }) {
    if (!preferences.enabled) return const [];

    final privacyApplied = desired
        .where((schedule) => _categoryEnabled(schedule, preferences))
        .map(
          (schedule) => QuevaaNotificationSchedule(
            timezoneName: schedule.timezoneName,
            notification: _withPrivacy(schedule.notification, preferences),
          ),
        )
        .map(
          (schedule) => _adjustForQuietHours(
            schedule: schedule,
            preferences: preferences,
          ),
        )
        .where((schedule) => _withinRollingWindow(schedule, now))
        .toList();

    final deduped = _deduplicate(privacyApplied);
    final cappedByDay = _applyDailyCap(deduped, preferences);
    return _applyGlobalLimit(cappedByDay);
  }

  QuevaaNotificationSchedule adjustForQuietHoursForTest({
    required QuevaaNotificationSchedule schedule,
    required QuevaaNotificationPreferences preferences,
  }) {
    return _adjustForQuietHours(schedule: schedule, preferences: preferences);
  }

  static bool _categoryEnabled(
    QuevaaNotificationSchedule schedule,
    QuevaaNotificationPreferences preferences,
  ) {
    final key = schedule.notification.type.categoryKey;
    return preferences.categoryEnabled[key] ?? true;
  }

  static bool _withinRollingWindow(
    QuevaaNotificationSchedule schedule,
    tz.TZDateTime now,
  ) {
    final end = now.add(
      const Duration(days: QuevaaNotificationConstants.rollingHorizonDays),
    );
    return schedule.notification.scheduledAt.isAfter(now) &&
        schedule.notification.scheduledAt.isBefore(end);
  }

  static QuevaaNotification _withPrivacy(
    QuevaaNotification notification,
    QuevaaNotificationPreferences preferences,
  ) {
    switch (preferences.privacyMode) {
      case QuevaaNotificationPrivacyMode.explicit:
        return notification;
      case QuevaaNotificationPrivacyMode.discreet:
        return QuevaaNotification(
          id: notification.id,
          type: notification.type,
          scheduledAt: notification.scheduledAt,
          title: notification.privacySafeTitle,
          body: notification.privacySafeBody,
          privacySafeTitle: notification.privacySafeTitle,
          privacySafeBody: notification.privacySafeBody,
          hiddenTitle: notification.hiddenTitle,
          hiddenBody: notification.hiddenBody,
          route: notification.route,
          localRecordId: notification.localRecordId,
          priority: notification.priority,
          source: notification.source,
          createdAt: notification.createdAt,
          updatedAt: notification.updatedAt,
          scheduleVersion: notification.scheduleVersion,
        );
      case QuevaaNotificationPrivacyMode.hidden:
        return QuevaaNotification(
          id: notification.id,
          type: notification.type,
          scheduledAt: notification.scheduledAt,
          title: notification.hiddenTitle,
          body: notification.hiddenBody,
          privacySafeTitle: notification.privacySafeTitle,
          privacySafeBody: notification.privacySafeBody,
          hiddenTitle: notification.hiddenTitle,
          hiddenBody: notification.hiddenBody,
          route: notification.route,
          localRecordId: notification.localRecordId,
          priority: notification.priority,
          source: notification.source,
          createdAt: notification.createdAt,
          updatedAt: notification.updatedAt,
          scheduleVersion: notification.scheduleVersion,
        );
    }
  }

  static QuevaaNotificationSchedule _adjustForQuietHours({
    required QuevaaNotificationSchedule schedule,
    required QuevaaNotificationPreferences preferences,
  }) {
    final notification = schedule.notification;
    if (notification.priority == QuevaaNotificationPriority.userCreated) {
      return schedule;
    }
    if (notification.priority == QuevaaNotificationPriority.high &&
        notification.type.categoryKey == 'medication') {
      return schedule;
    }
    final minutes =
        notification.scheduledAt.hour * 60 + notification.scheduledAt.minute;
    if (!_insideQuietHours(
      minutes: minutes,
      start: preferences.quietStartMinutes,
      end: preferences.quietEndMinutes,
    )) {
      return schedule;
    }

    var adjusted = tz.TZDateTime(
      notification.scheduledAt.location,
      notification.scheduledAt.year,
      notification.scheduledAt.month,
      notification.scheduledAt.day,
      preferences.quietEndMinutes ~/ 60,
      preferences.quietEndMinutes % 60,
    );
    if (!adjusted.isAfter(notification.scheduledAt)) {
      adjusted = adjusted.add(const Duration(days: 1));
    }

    return QuevaaNotificationSchedule(
      timezoneName: schedule.timezoneName,
      notification: QuevaaNotification(
        id: notification.id,
        type: notification.type,
        scheduledAt: adjusted,
        title: notification.title,
        body: notification.body,
        privacySafeTitle: notification.privacySafeTitle,
        privacySafeBody: notification.privacySafeBody,
        hiddenTitle: notification.hiddenTitle,
        hiddenBody: notification.hiddenBody,
        route: notification.route,
        localRecordId: notification.localRecordId,
        priority: notification.priority,
        source: notification.source,
        createdAt: notification.createdAt,
        updatedAt: DateTime.now(),
        scheduleVersion: notification.scheduleVersion,
      ),
    );
  }

  static bool _insideQuietHours({
    required int minutes,
    required int start,
    required int end,
  }) {
    if (start == end) return false;
    if (start < end) return minutes >= start && minutes < end;
    return minutes >= start || minutes < end;
  }

  static List<QuevaaNotificationSchedule> _deduplicate(
    List<QuevaaNotificationSchedule> schedules,
  ) {
    final byLogicalEvent = <String, QuevaaNotificationSchedule>{};
    for (final schedule in schedules) {
      final notification = schedule.notification;
      final key = [
        notification.type.name,
        notification.localRecordId ?? 'global',
        notification.scheduledAt.year,
        notification.scheduledAt.month,
        notification.scheduledAt.day,
      ].join('|');
      final existing = byLogicalEvent[key];
      if (existing == null ||
          _sortValue(schedule).compareTo(_sortValue(existing)) < 0) {
        byLogicalEvent[key] = schedule;
      }
    }
    final ids = <int>{};
    return byLogicalEvent.values
        .where((schedule) => ids.add(schedule.id))
        .toList();
  }

  static List<QuevaaNotificationSchedule> _applyDailyCap(
    List<QuevaaNotificationSchedule> schedules,
    QuevaaNotificationPreferences preferences,
  ) {
    final sorted = [...schedules]..sort(_compareSchedules);
    final ordinaryCountByDay = <String, int>{};
    final kept = <QuevaaNotificationSchedule>[];
    for (final schedule in sorted) {
      if (_exemptFromDailyCap(schedule.notification)) {
        kept.add(schedule);
        continue;
      }
      final dayKey = _dayKey(schedule.notification.scheduledAt);
      final count = ordinaryCountByDay[dayKey] ?? 0;
      if (count < preferences.dailyCap) {
        ordinaryCountByDay[dayKey] = count + 1;
        kept.add(schedule);
      }
    }
    return kept;
  }

  static List<QuevaaNotificationSchedule> _applyGlobalLimit(
    List<QuevaaNotificationSchedule> schedules,
  ) {
    final sorted = [...schedules]..sort(_compareSchedules);
    return sorted
        .take(QuevaaNotificationConstants.maxPendingNotifications)
        .toList();
  }

  static bool _exemptFromDailyCap(QuevaaNotification notification) {
    return notification.priority == QuevaaNotificationPriority.userCreated ||
        notification.type.categoryKey == 'medication' ||
        notification.type.categoryKey == 'tasks';
  }

  static int _compareSchedules(
    QuevaaNotificationSchedule a,
    QuevaaNotificationSchedule b,
  ) {
    final priority = a.notification.priority.rank.compareTo(
      b.notification.priority.rank,
    );
    if (priority != 0) return priority;
    return a.notification.scheduledAt.compareTo(b.notification.scheduledAt);
  }

  static String _sortValue(QuevaaNotificationSchedule schedule) {
    return '${schedule.notification.priority.rank}|'
        '${schedule.notification.scheduledAt.toIso8601String()}';
  }

  static String _dayKey(tz.TZDateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}
