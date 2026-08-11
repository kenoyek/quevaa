import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/notifications/notification_destination_resolver.dart';
import 'package:quevaa/core/notifications/notification_constants.dart';
import 'package:quevaa/core/notifications/notification_id.dart';
import 'package:quevaa/core/notifications/notification_payload.dart';
import 'package:quevaa/core/notifications/notification_permission_service.dart';
import 'package:quevaa/features/notifications/application/notification_controller.dart';
import 'package:quevaa/features/notifications/application/notification_preferences_provider.dart';
import 'package:quevaa/features/notifications/application/notification_snapshot_provider.dart';
import 'package:quevaa/features/notifications/data/notification_repository_impl.dart';
import 'package:quevaa/features/notifications/domain/entities/notification_preferences.dart';
import 'package:quevaa/features/notifications/domain/entities/notification_schedule.dart';
import 'package:quevaa/features/notifications/domain/entities/quevaa_notification.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_priority.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_privacy_mode.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_type.dart';
import 'package:quevaa/features/notifications/domain/repositories/notification_repository.dart';
import 'package:quevaa/features/notifications/domain/services/notification_scheduler.dart';
import 'package:quevaa/features/notifications/domain/services/notification_policy_engine.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockNotificationPermissionService extends Mock
    implements QuevaaNotificationPermissionService {}

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

void main() {
  late tz.Location lagos;

  setUpAll(() {
    tz_data.initializeTimeZones();
    lagos = tz.getLocation('Africa/Lagos');
    tz.setLocalLocation(lagos);
    registerFallbackValue(QuevaaNotificationPreferences.defaults());
    registerFallbackValue(NotificationReconciliationReason.preferencesChanged);
    registerFallbackValue(const NotificationSourceSnapshot());
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
    test(
      'rejects empty source snapshots instead of scheduling stale defaults',
      () {
        final preferences = QuevaaNotificationPreferences.defaults().copyWith(
          enabled: true,
        );

        expect(
          () => const SmartNotificationEngine().buildDesiredSchedules(
            preferences: preferences,
            snapshot: const NotificationSourceSnapshot(),
            location: lagos,
            now: tz.TZDateTime(lagos, 2026, 8, 16, 8),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

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

    test('schedules one daily meal notification for the stable meal plan', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
        dailyCap: 20,
        privacyMode: QuevaaNotificationPrivacyMode.explicit,
      );
      final schedules = const SmartNotificationEngine().buildDesiredSchedules(
        preferences: preferences,
        snapshot: const NotificationSourceSnapshot(
          estimatedPhase: 'Follicular',
          mealSuggestion: 'Rice and Beans with Tomato Stew',
          workoutSuggestion: 'Gentle Walk',
          todayEnergyLevel: 4,
          todayPainLevel: 0,
          todaySleepHours: 8,
        ),
        location: lagos,
        now: tz.TZDateTime(lagos, 2026, 8, 16, 8),
      );
      final mealSchedules = schedules
          .where((item) => item.notification.type.categoryKey == 'meals')
          .toList();

      expect(mealSchedules, hasLength(1));
      expect(
        mealSchedules.single.notification.title,
        "Today's Quevaa meal ideas are ready.",
      );
      expect(
        mealSchedules.single.notification.route,
        '/wellness?section=Meals',
      );
    });
  });

  group('Notification preference controller', () {
    test('keeps Quevaa reminders on when Android blocks permission', () async {
      final repository = MockNotificationRepository();
      final permissionService = MockNotificationPermissionService();
      final scheduler = MockNotificationScheduler();
      when(
        repository.loadPreferences,
      ).thenAnswer((_) async => QuevaaNotificationPreferences.defaults());
      when(() => repository.savePreferences(any())).thenAnswer((_) async {});
      when(permissionService.requestPermission).thenAnswer((_) async => false);
      when(
        permissionService.status,
      ).thenAnswer((_) async => QuevaaNotificationPermissionStatus.denied);
      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
          notificationPermissionServiceProvider.overrideWithValue(
            permissionService,
          ),
          notificationSchedulerProvider.overrideWithValue(scheduler),
          notificationSourceSnapshotProvider.overrideWithValue(
            const NotificationSourceSnapshot(
              estimatedPhase: 'Follicular',
              mealSuggestion: 'Rice and Beans',
              workoutSuggestion: 'Walk',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(notificationControllerProvider.notifier)
          .requestAndEnable();

      final saved =
          verify(() => repository.savePreferences(captureAny())).captured.single
              as QuevaaNotificationPreferences;
      expect(saved.enabled, isTrue);
      expect(saved.permissionPreviouslyDeclined, isTrue);
      verifyNever(
        () => scheduler.reconcileNotifications(
          any(),
          snapshot: any(named: 'snapshot'),
        ),
      );
    });
  });

  group('Notification payload', () {
    test(
      'rejects malformed payloads and resolves unsupported routes safely',
      () {
        expect(QuevaaNotificationPayload.tryParse('not-json'), isNull);
        final parsed = QuevaaNotificationPayload.tryParse(
          '{"version":1,"type":"hydration","route":"https://example.com"}',
        );
        expect(parsed?.route, QuevaaNotificationType.hydration.defaultRoute);
      },
    );

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

    test('allows meal notification payloads to open the Meals tab', () {
      final payload = QuevaaNotificationPayload.forSchedule(
        type: QuevaaNotificationType.breakfast,
        route: QuevaaNotificationType.breakfast.defaultRoute,
        entityId: 'meal-breakfast-2026-08-14',
      ).encode();

      final parsed = QuevaaNotificationPayload.tryParse(payload);

      expect(parsed?.route, '/wellness?section=Meals');
      expect(parsed?.type, QuevaaNotificationType.breakfast);
    });

    test('resolves core notification destinations safely', () {
      expect(
        NotificationDestinationResolver.resolve(
          type: QuevaaNotificationType.periodExpected,
          route: '/cycle',
        ),
        '/cycle',
      );
      expect(
        NotificationDestinationResolver.resolve(
          type: QuevaaNotificationType.breakfast,
          route: '/wellness?section=Meals',
        ),
        '/wellness?section=Meals',
      );
      expect(
        NotificationDestinationResolver.resolve(
          type: QuevaaNotificationType.workout,
          route: '/wellness',
        ),
        '/wellness',
      );
      expect(
        NotificationDestinationResolver.resolve(
          type: QuevaaNotificationType.productivityGuidance,
          route: '/plan',
        ),
        '/plan',
      );
      expect(
        NotificationDestinationResolver.resolve(
          type: QuevaaNotificationType.ovulationTest,
          route: '/conception/log',
        ),
        '/conception/log',
      );
      expect(
        NotificationDestinationResolver.resolve(
          type: QuevaaNotificationType.hydration,
          route: '/not-a-route',
        ),
        '/wellness?section=Meals',
      );
    });
  });

  group('Notification inbox repository', () {
    late AppDatabase database;
    late NotificationRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = NotificationRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('reports zero unread for an empty inbox', () async {
      expect(await repository.unreadCount(), 0);
      expect(await repository.watchUnreadCount().first, 0);
    });

    test('reports one unread and marks the item read', () async {
      final schedule = _schedule(
        lagos,
        QuevaaNotificationType.hydration,
        DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await repository.upsertInboxEntries([schedule]);

      expect(await repository.unreadCount(), 1);

      await repository.markInboxEntryRead(schedule.id);
      final items = await repository.watchInbox().first;

      expect(await repository.unreadCount(), 0);
      expect(items.single.readAt, isNotNull);
    });

    test('reports twelve unread and supports mark all read', () async {
      final schedules = [
        for (var i = 0; i < 12; i++)
          _schedule(
            lagos,
            QuevaaNotificationType.hydration,
            DateTime.now().subtract(Duration(minutes: i + 1)),
            idSuffix: 'count-$i',
          ),
      ];

      await repository.upsertInboxEntries(schedules);

      expect(await repository.unreadCount(), 12);

      await repository.markAllInboxRead();

      expect(await repository.unreadCount(), 0);
    });

    test('supports badge cap inputs over ninety-nine unread', () async {
      final schedules = [
        for (var i = 0; i < 105; i++)
          _schedule(
            lagos,
            QuevaaNotificationType.hydration,
            DateTime.now().subtract(Duration(minutes: i + 1)),
            idSuffix: 'bulk-$i',
          ),
      ];

      await repository.upsertInboxEntries(schedules);

      expect(await repository.unreadCount(), 105);
    });

    test('deduplicates the same logical inbox notification', () async {
      final schedule = _schedule(
        lagos,
        QuevaaNotificationType.productivityGuidance,
        DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await repository.upsertInboxEntries([schedule]);
      await repository.upsertInboxEntries([schedule]);

      expect(await repository.unreadCount(), 1);
      expect((await repository.watchInbox().first).length, 1);
    });

    test('persists explicit and discreet privacy mode changes', () async {
      final explicit = QuevaaNotificationPreferences.defaults().copyWith(
        privacyMode: QuevaaNotificationPrivacyMode.explicit,
      );
      await repository.savePreferences(explicit);
      expect(
        (await repository.loadPreferences()).privacyMode,
        QuevaaNotificationPrivacyMode.explicit,
      );

      await repository.savePreferences(
        explicit.copyWith(privacyMode: QuevaaNotificationPrivacyMode.discreet),
      );
      expect(
        (await repository.loadPreferences()).privacyMode,
        QuevaaNotificationPrivacyMode.discreet,
      );

      await repository.savePreferences(
        explicit.copyWith(privacyMode: QuevaaNotificationPrivacyMode.explicit),
      );
      expect(
        (await repository.loadPreferences()).privacyMode,
        QuevaaNotificationPrivacyMode.explicit,
      );
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
