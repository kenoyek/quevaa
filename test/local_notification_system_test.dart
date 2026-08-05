import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/notifications/notification_constants.dart';
import 'package:quevaa/core/notifications/notification_id.dart';
import 'package:quevaa/core/notifications/notification_payload.dart';
import 'package:quevaa/features/notifications/domain/entities/notification_preferences.dart';
import 'package:quevaa/features/notifications/domain/entities/notification_schedule.dart';
import 'package:quevaa/features/notifications/domain/entities/quevaa_notification.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_priority.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_privacy_mode.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_type.dart';
import 'package:quevaa/features/notifications/domain/services/notification_policy_engine.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location lagos;

  setUpAll(() {
    tz_data.initializeTimeZones();
    lagos = tz.getLocation('Africa/Lagos');
    tz.setLocalLocation(lagos);
  });

  group('Stable notification IDs', () {
    test('same logical notification gets the same deterministic ID', () {
      final occurrence = DateTime(2026, 8, 18, 8, 30);
      final first = QuevaaNotificationId.generate(
        type: QuevaaNotificationType.basalBodyTemperature,
        entityId: 'bbt-2026-08-18',
        occurrence: occurrence,
      );
      final second = QuevaaNotificationId.generate(
        type: QuevaaNotificationType.basalBodyTemperature,
        entityId: 'bbt-2026-08-18',
        occurrence: occurrence,
      );

      expect(first, second);
      expect(first, inInclusiveRange(1, 0x7fffffff));
    });

    test('resists collisions across common logical reminders', () {
      final ids = <int>{};
      for (final type in QuevaaNotificationType.values) {
        for (var day = 1; day <= 20; day++) {
          ids.add(
            QuevaaNotificationId.generate(
              type: type,
              entityId: '${type.name}-$day',
              occurrence: DateTime(2026, 8, day, 9),
            ),
          );
        }
      }

      expect(ids.length, QuevaaNotificationType.values.length * 20);
    });
  });

  group('Notification policy engine', () {
    test('moves ordinary reminders out of quiet hours crossing midnight', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
        quietStartMinutes: 21 * 60,
        quietEndMinutes: 8 * 60,
      );
      final original = _schedule(
        lagos,
        QuevaaNotificationType.hydration,
        DateTime(2026, 8, 18, 22),
      );

      final adjusted = const NotificationPolicyEngine()
          .adjustForQuietHoursForTest(
            schedule: original,
            preferences: preferences,
          );

      expect(adjusted.notification.scheduledAt.hour, 8);
      expect(adjusted.notification.scheduledAt.day, 19);
    });

    test('preserves user-created medication times inside quiet hours', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
      );
      final original = _schedule(
        lagos,
        QuevaaNotificationType.medication,
        DateTime(2026, 8, 18, 22),
        priority: QuevaaNotificationPriority.userCreated,
      );

      final adjusted = const NotificationPolicyEngine()
          .adjustForQuietHoursForTest(
            schedule: original,
            preferences: preferences,
          );

      expect(adjusted.notification.scheduledAt.hour, 22);
    });

    test('applies daily cap and maximum 48 rolling schedules', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
        dailyCap: 2,
      );
      final now = tz.TZDateTime(lagos, 2026, 8, 1, 8);
      final schedules = [
        for (var i = 0; i < 70; i++)
          _schedule(
            lagos,
            QuevaaNotificationType.hydration,
            DateTime(2026, 8, 1 + (i ~/ 4), 9 + (i % 4)),
            idSuffix: '$i',
          ),
      ];

      final result = const NotificationPolicyEngine().applyPolicies(
        desired: schedules,
        preferences: preferences,
        now: now,
      );

      expect(
        result.length,
        lessThanOrEqualTo(QuevaaNotificationConstants.maxPendingNotifications),
      );
      expect(
        result.where((item) => item.notification.scheduledAt.day == 1).length,
        2,
      );
    });

    test('applies hidden privacy mode without leaking content', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
        privacyMode: QuevaaNotificationPrivacyMode.hidden,
      );
      final now = tz.TZDateTime(lagos, 2026, 8, 1, 8);

      final result = const NotificationPolicyEngine().applyPolicies(
        desired: [
          _schedule(
            lagos,
            QuevaaNotificationType.pregnancyTest,
            DateTime(2026, 8, 2, 9),
          ),
        ],
        preferences: preferences,
        now: now,
      );

      expect(result.single.notification.title, 'Quevaa');
      expect(
        result.single.notification.body,
        'Open the app to view your update.',
      );
    });
  });

  group('Smart notification engine', () {
    test('generates TTC reminders only in conception mode', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
      );
      final now = tz.TZDateTime(lagos, 2026, 8, 1, 8);
      const engine = SmartNotificationEngine();

      final paused = engine.buildDesiredSchedules(
        preferences: preferences,
        snapshot: NotificationSourceSnapshot(
          conceptionModeActive: false,
          fertileWindowStart: tz.TZDateTime(lagos, 2026, 8, 10),
          fertileWindowEnd: tz.TZDateTime(lagos, 2026, 8, 15),
        ),
        location: lagos,
        now: now,
      );
      final active = engine.buildDesiredSchedules(
        preferences: preferences,
        snapshot: NotificationSourceSnapshot(
          conceptionModeActive: true,
          fertileWindowStart: tz.TZDateTime(lagos, 2026, 8, 10),
          fertileWindowEnd: tz.TZDateTime(lagos, 2026, 8, 15),
        ),
        location: lagos,
        now: now,
      );

      expect(
        paused.any(
          (item) =>
              item.notification.type == QuevaaNotificationType.ovulationTest,
        ),
        isFalse,
      );
      expect(
        active.any(
          (item) =>
              item.notification.type == QuevaaNotificationType.ovulationTest,
        ),
        isTrue,
      );
    });

    test('suppresses BBT and ovulation-test reminders after daily entries', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
      );
      final now = tz.TZDateTime(lagos, 2026, 8, 1, 8);

      final suppressed = const SmartNotificationEngine().buildDesiredSchedules(
        preferences: preferences,
        snapshot: NotificationSourceSnapshot(
          conceptionModeActive: true,
          fertileWindowStart: tz.TZDateTime(lagos, 2026, 8, 10),
          fertileWindowEnd: tz.TZDateTime(lagos, 2026, 8, 10),
          loggedBbtDays: {'2026-08-10'},
          loggedOvulationTestDays: {'2026-08-10'},
        ),
        location: lagos,
        now: now,
      );

      expect(
        suppressed.any(
          (item) =>
              item.notification.type ==
                  QuevaaNotificationType.basalBodyTemperature ||
              item.notification.type == QuevaaNotificationType.ovulationTest,
        ),
        isFalse,
      );
    });
  });

  group('Notification payload', () {
    test('rejects malformed payloads and unsupported routes', () {
      expect(QuevaaNotificationPayload.tryParse('not-json'), isNull);
      expect(
        QuevaaNotificationPayload.tryParse(
          '{"version":1,"type":"hydration","route":"https://example.com"}',
        ),
        isNull,
      );
    });

    test('parses valid privacy-safe typed payload', () {
      final payload = QuevaaNotificationPayload.forSchedule(
        type: QuevaaNotificationType.hydration,
        route: '/wellness',
        entityId: 'hydration-am',
      ).encode();

      final parsed = QuevaaNotificationPayload.tryParse(payload);

      expect(parsed?.type, QuevaaNotificationType.hydration);
      expect(parsed?.route, '/wellness');
      expect(parsed?.entityId, 'hydration-am');
    });
  });
}

QuevaaNotificationSchedule _schedule(
  tz.Location location,
  QuevaaNotificationType type,
  DateTime date, {
  QuevaaNotificationPriority priority = QuevaaNotificationPriority.low,
  String idSuffix = '',
}) {
  final scheduledAt = tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute,
  );
  final id = QuevaaNotificationId.generate(
    type: type,
    entityId: '${type.name}$idSuffix',
    occurrence: scheduledAt,
  );
  return QuevaaNotificationSchedule(
    timezoneName: location.name,
    notification: QuevaaNotification(
      id: id,
      type: type,
      scheduledAt: scheduledAt,
      title: 'Explicit private content',
      body: 'Sensitive body text',
      privacySafeTitle: 'Your Quevaa update is ready.',
      privacySafeBody: 'Open Quevaa to continue.',
      route: type.defaultRoute,
      localRecordId: '${type.name}$idSuffix',
      priority: priority,
      source: QuevaaNotificationConstants.debugSource,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      scheduleVersion: QuevaaNotificationConstants.scheduleVersion,
    ),
  );
}
