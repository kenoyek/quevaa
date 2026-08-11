import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/models/prediction_confidence.dart';
import 'package:quevaa/core/providers/database_provider.dart';
import 'package:quevaa/core/providers/user_profile_provider.dart';
import 'package:quevaa/features/cycle/application/cycle_workspace_provider.dart';
import 'package:quevaa/features/cycle/domain/cycle_engine.dart';
import 'package:quevaa/features/cycle/domain/models/cycle_calendar_phase.dart';
import 'package:quevaa/features/cycle/domain/models/cycle_engine_output.dart';
import 'package:quevaa/features/dashboard/domain/readiness_calculator.dart';
import 'package:quevaa/features/notifications/domain/entities/notification_preferences.dart';
import 'package:quevaa/features/notifications/domain/entities/notification_schedule.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_privacy_mode.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_type.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';
import 'package:quevaa/features/nutrition/data/nigerian_recipe_database.dart';
import 'package:quevaa/features/recommendations/application/daily_quevaa_plan_provider.dart';
import 'package:quevaa/features/workouts/domain/workout_recommendation_engine.dart';
import 'package:quevaa/features/workouts/data/workout_catalog.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late tz.Location lagos;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    tz_data.initializeTimeZones();
    lagos = tz.getLocation('Africa/Lagos');
    tz.setLocalLocation(lagos);
  });

  group('Release-grade canonical Aug 8 cycle state', () {
    test('calendar phases match the canonical 28 day / 4 day scenario', () {
      final output = _canonicalOutput(DateTime(2026, 8, 12));
      final expected = <DateTime, CycleCalendarPhase>{
        DateTime(2026, 8, 8): CycleCalendarPhase.menstrual,
        DateTime(2026, 8, 11): CycleCalendarPhase.menstrual,
        DateTime(2026, 8, 12): CycleCalendarPhase.follicular,
        DateTime(2026, 8, 17): CycleCalendarPhase.fertileWindow,
        DateTime(2026, 8, 22): CycleCalendarPhase.estimatedOvulation,
        DateTime(2026, 8, 23): CycleCalendarPhase.estimatedOvulation,
        DateTime(2026, 9, 4): CycleCalendarPhase.luteal,
        DateTime(2026, 9, 5): CycleCalendarPhase.menstrual,
      };

      for (final entry in expected.entries) {
        expect(
          output.getCalendarPhase(entry.key, history: _canonicalHistory),
          entry.value,
          reason: entry.key.toIso8601String(),
        );
      }
      expect(output.estimatedPeriodStartMin, DateTime(2026, 9, 5));
      expect(output.estimatedPeriodStartMax, DateTime(2026, 9, 8));
      expect(output.fertileWindowStart, DateTime(2026, 8, 17));
      expect(output.fertileWindowEnd, DateTime(2026, 8, 23));
      expect(output.estimatedOvulationStart, DateTime(2026, 8, 21));
      expect(output.estimatedOvulationEnd, DateTime(2026, 8, 23));
    });

    test('phase-specific daily plan is deterministic for a day', () async {
      final aug12 = await _planFor(DateTime(2026, 8, 12));
      final aug12Again = await _planFor(DateTime(2026, 8, 12));
      final aug22 = await _planFor(DateTime(2026, 8, 22));
      final sep4 = await _planFor(DateTime(2026, 9, 4));

      expect(aug12.cycleOutput.estimatedPhase, 'Follicular');
      expect(aug22.cycleOutput.estimatedPhase, 'Estimated Ovulatory Window');
      expect(sep4.cycleOutput.estimatedPhase, isNot('Menstrual'));
      expect(aug12.featuredMeal.title, aug12Again.featuredMeal.title);
      expect(aug12.workout.id, aug12Again.workout.id);
      expect(aug12.meals.values.every(_vegetarianSafe), isTrue);
      expect(aug22.featuredMeal.targetPhase, 'Ovulation');
      expect(sep4.featuredMeal.targetPhase, 'Luteal');
    });
  });

  group('Release-grade recommendations', () {
    test('readiness responds to energy, sleep, and pain over phase alone', () {
      final low = ReadinessCalculator.calculate(
        selfReportedEnergy: 1,
        sleepHours: 5,
        painLevel: 4,
        estimatedPhase: 'Follicular',
      );
      final high = ReadinessCalculator.calculate(
        selfReportedEnergy: 5,
        sleepHours: 8,
        painLevel: 0,
        estimatedPhase: 'Luteal',
      );

      expect(low.score, ReadinessScore.restore);
      expect(high.score, anyOf(ReadinessScore.focused, ReadinessScore.strong));
    });

    test('movement changes for high-readiness and low-readiness days', () {
      final high = WorkoutRecommendationEngine.recommendWorkouts(
        availableWorkouts: bundledWorkoutCatalog,
        userEnergyLevel: 5,
        userPainLevel: 0,
        sleepHours: 8,
      );
      final low = WorkoutRecommendationEngine.recommendWorkouts(
        availableWorkouts: bundledWorkoutCatalog,
        userEnergyLevel: 1,
        userPainLevel: 4,
        sleepHours: 5,
      );

      expect(high.any((workout) => workout.intensity != 'Gentle'), isTrue);
      expect(low.every((workout) => workout.intensity == 'Gentle'), isTrue);
    });
  });

  group('Release-grade notifications', () {
    test(
      'canonical notification schedule covers period, fertility, and productivity',
      () {
        final preferences = QuevaaNotificationPreferences.defaults().copyWith(
          enabled: true,
          dailyCap: 20,
          privacyMode: QuevaaNotificationPrivacyMode.explicit,
        );
        final schedules = const SmartNotificationEngine().buildDesiredSchedules(
          preferences: preferences,
          snapshot: _canonicalNotificationSnapshot(lagos),
          location: lagos,
          now: tz.TZDateTime(lagos, 2026, 8, 16, 8),
        );

        expect(
          _byType(
            schedules,
            QuevaaNotificationType.periodExpected,
            'minus3',
          ).notification.scheduledAt,
          tz.TZDateTime(lagos, 2026, 9, 2, 9),
        );
        expect(
          _byType(
            schedules,
            QuevaaNotificationType.periodExpected,
            'minus1',
          ).notification.scheduledAt,
          tz.TZDateTime(lagos, 2026, 9, 4, 9),
        );
        expect(
          _byType(
            schedules,
            QuevaaNotificationType.periodToday,
            'period-2026-9',
          ).notification.scheduledAt,
          tz.TZDateTime(lagos, 2026, 9, 5, 9),
        );
        expect(
          _byType(
            schedules,
            QuevaaNotificationType.fertileWindowApproaching,
            'fertile-2026-8',
          ).notification.scheduledAt,
          tz.TZDateTime(lagos, 2026, 8, 16, 10),
        );
        expect(
          _byType(
            schedules,
            QuevaaNotificationType.highFertilityCheckIn,
            'ovulation-2026-8-22',
          ).notification.scheduledAt,
          tz.TZDateTime(lagos, 2026, 8, 21, 10),
        );
        expect(
          _byType(
            schedules,
            QuevaaNotificationType.productivityGuidance,
            'productivity-2026-08-17',
          ).notification.route,
          '/plan',
        );
      },
    );

    test('early period rescheduling removes obsolete prior period IDs', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
        dailyCap: 20,
        privacyMode: QuevaaNotificationPrivacyMode.explicit,
      );
      final before = const SmartNotificationEngine().buildDesiredSchedules(
        preferences: preferences,
        snapshot: _canonicalNotificationSnapshot(lagos),
        location: lagos,
        now: tz.TZDateTime(lagos, 2026, 9, 2, 8),
      );
      final after = const SmartNotificationEngine().buildDesiredSchedules(
        preferences: preferences,
        snapshot: NotificationSourceSnapshot(
          estimatedPeriodStart: tz.TZDateTime(lagos, 2026, 10, 1, 9),
          predictionConfidence: PredictionConfidence.low,
        ),
        location: lagos,
        now: tz.TZDateTime(lagos, 2026, 9, 2, 8),
      );

      final beforeIds = before.map((item) => item.notification.localRecordId);
      final afterIds = after.map((item) => item.notification.localRecordId);
      expect(beforeIds, contains('period-2026-9'));
      expect(afterIds, isNot(contains('period-2026-9')));
      expect(afterIds, contains('period-2026-10'));
    });

    test('productivity guidance copy changes for high and low readiness', () {
      final preferences = QuevaaNotificationPreferences.defaults().copyWith(
        enabled: true,
        dailyCap: 20,
        privacyMode: QuevaaNotificationPrivacyMode.explicit,
      );
      final low = const SmartNotificationEngine().buildDesiredSchedules(
        preferences: preferences,
        snapshot: const NotificationSourceSnapshot(
          todayEnergyLevel: 1,
          todayPainLevel: 4,
          todaySleepHours: 5,
          estimatedPhase: 'Follicular',
        ),
        location: lagos,
        now: tz.TZDateTime(lagos, 2026, 8, 16, 8),
      );
      final high = const SmartNotificationEngine().buildDesiredSchedules(
        preferences: preferences,
        snapshot: const NotificationSourceSnapshot(
          todayEnergyLevel: 5,
          todayPainLevel: 0,
          todaySleepHours: 8,
          estimatedPhase: 'Luteal',
        ),
        location: lagos,
        now: tz.TZDateTime(lagos, 2026, 8, 16, 8),
      );

      final lowProductivity = _onlyType(
        low,
        QuevaaNotificationType.productivityGuidance,
      ).notification;
      final highProductivity = _onlyType(
        high,
        QuevaaNotificationType.productivityGuidance,
      ).notification;
      expect(lowProductivity.title, contains('lighter'));
      expect(highProductivity.title, contains('focus'));
      expect(lowProductivity.body, isNot(highProductivity.body));
    });
  });
}

final _canonicalHistory = [
  CyclePeriodRecord(
    startDate: DateTime(2026, 8, 8),
    endDate: DateTime(2026, 8, 11),
  ),
];

CycleEngineOutput _canonicalOutput(DateTime targetDate) {
  return CycleEngine.calculate(
    periodHistory: _canonicalHistory,
    targetDate: targetDate,
    userConfiguredAverageCycleLength: 28,
    userConfiguredPeriodLength: 4,
  );
}

NotificationSourceSnapshot _canonicalNotificationSnapshot(
  tz.Location location,
) {
  return NotificationSourceSnapshot(
    conceptionModeActive: true,
    estimatedPeriodStart: tz.TZDateTime(location, 2026, 9, 5, 9),
    fertileWindowStart: tz.TZDateTime(location, 2026, 8, 17, 9),
    fertileWindowEnd: tz.TZDateTime(location, 2026, 8, 23, 9),
    estimatedOvulationDate: tz.TZDateTime(location, 2026, 8, 22, 9),
    predictionConfidence: PredictionConfidence.low,
    todayEnergyLevel: 3,
    todayPainLevel: 1,
    todaySleepHours: 7.5,
    estimatedPhase: 'Follicular',
    mealSuggestion: 'Warm Ogi',
    workoutSuggestion: 'Walk and Strength Blend',
  );
}

Future<DailyQuevaaPlan> _planFor(DateTime date) async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      localTodayProvider.overrideWithValue(date),
    ],
  );
  try {
    await _seedCanonicalProfile(db);
    await container.read(periodHistoryProvider.future);
    await container.read(userProfileProvider.future);
    await container.read(onboardingPreferencesProvider.future);
    await container.read(todaysDailyLogProvider.future);
    await container.read(recentDailyLogsProvider.future);
    return container.read(dailyQuevaaPlanProvider);
  } finally {
    container.dispose();
    await db.close();
  }
}

Future<void> _seedCanonicalProfile(AppDatabase db) async {
  final now = DateTime(2026, 8, 1);
  await db
      .into(db.userProfiles)
      .insert(
        UserProfilesCompanion.insert(
          uuid: 'release-user',
          createdAt: now,
          updatedAt: now,
          averageCycleLength: const Value(28),
          averagePeriodLength: const Value(4),
          lastPeriodStartDate: Value(DateTime(2026, 8, 8)),
          primaryGoal: const Value('Track my cycle'),
        ),
      );
  await db
      .into(db.cyclePeriods)
      .insert(
        CyclePeriodsCompanion.insert(
          uuid: 'release-period-2026-08-08',
          createdAt: now,
          updatedAt: now,
          startDate: DateTime(2026, 8, 8),
          endDate: Value(DateTime(2026, 8, 11)),
          flowIntensity: const Value(3),
          isOngoing: const Value(false),
        ),
      );
  await db
      .into(db.onboardingPreferences)
      .insert(
        OnboardingPreferencesCompanion.insert(
          uuid: 'release-onboarding',
          createdAt: now,
          updatedAt: now,
          dietaryPattern: const Value('Vegetarian'),
          workoutLocation: const Value('Home'),
          lowImpactOnly: const Value(true),
        ),
      );
}

bool _vegetarianSafe(NigerianRecipe recipe) {
  final text = '${recipe.title} ${recipe.description}'.toLowerCase();
  return ![
    'fish',
    'catfish',
    'snail',
    'seafood',
    'prawn',
    'crab',
    'stockfish',
    'mackerel',
  ].any(text.contains);
}

QuevaaNotificationSchedule _byType(
  List<QuevaaNotificationSchedule> schedules,
  QuevaaNotificationType type,
  String localRecordIdFragment,
) {
  return schedules.singleWhere(
    (item) =>
        item.notification.type == type &&
        (item.notification.localRecordId ?? '').contains(localRecordIdFragment),
  );
}

QuevaaNotificationSchedule _onlyType(
  List<QuevaaNotificationSchedule> schedules,
  QuevaaNotificationType type,
) {
  return schedules.singleWhere((item) => item.notification.type == type);
}
