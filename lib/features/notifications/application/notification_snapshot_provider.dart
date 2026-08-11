import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/notifications/notification_timezone_service.dart';
import '../../conception/application/conception_settings_provider.dart';
import '../../cycle/application/cycle_workspace_provider.dart';
import '../../cycle/domain/cycle_engine.dart';
import '../../nutrition/data/nigerian_recipe_database.dart';
import '../../workouts/data/workout_catalog.dart';
import '../../workouts/domain/workout_recommendation_engine.dart';
import '../domain/services/smart_notification_engine.dart';

/// Builds a [NotificationSourceSnapshot] from live user data so that
/// the notification scheduler can produce cycle-aware, TTC-aware, and
/// wellness-aware local notifications.
///
/// This provider is the single authoritative bridge between the user's
/// logged health data and the notification engine.
final notificationSourceSnapshotProvider = Provider<NotificationSourceSnapshot>(
  (ref) {
    final cycleSnapshot = ref.watch(currentCycleSnapshotProvider);
    final cycleOutput = ref.watch(currentCycleOutputProvider);
    final isTtcEnabled =
        ref.watch(persistedConceptionModeActiveProvider).valueOrNull ?? false;
    final todayLog = ref.watch(notificationTodayLogProvider).valueOrNull;

    // Convert nullable DateTimes to TZDateTimes for the notification engine.
    final location = quevaaNotificationTimezoneService.localLocation;

    tz.TZDateTime? toTz(DateTime? dt) {
      if (dt == null) return null;
      return tz.TZDateTime(location, dt.year, dt.month, dt.day, 9, 0);
    }

    return NotificationSourceSnapshot(
      // Cycle state flags
      cycleTrackingPaused: !cycleSnapshot.hasEnoughData,
      pregnancyMode: false, // TODO: wire once pregnancy mode exists
      conceptionModeActive: isTtcEnabled,

      // Cycle predictions
      estimatedPeriodStart: toTz(
        cycleSnapshot.primaryPrediction?.estimatedStartDate,
      ),
      fertileWindowStart: toTz(cycleSnapshot.fertileWindowRange?.start),
      fertileWindowEnd: toTz(cycleSnapshot.fertileWindowRange?.end),
      estimatedOvulationDate: toTz(
        cycleSnapshot.ovulationRange?.start.add(const Duration(days: 1)),
      ),
      predictionConfidence: cycleSnapshot.confidence,
      currentCycleDay: cycleSnapshot.cycleDay,
      estimatedPhase: cycleOutput.estimatedPhase,
      todayEnergyLevel: todayLog?.energyLevel,
      todayPainLevel: todayLog?.painLevel,
      todaySleepHours: todayLog?.sleepHours,
      mealSuggestion: _mealSuggestion(cycleOutput.estimatedPhase),
      workoutSuggestion: _workoutSuggestion(todayLog),

      // Logged days — will be populated by TTC repository once persisted
      loggedOvulationTestDays: const {},
      loggedBbtDays: const {},
      loggedPregnancyTestDays: const {},

      // Productivity & wellness — will be expanded in Phase 5/6
      completedTaskIds: const {},
      completedWorkoutIds: const {},
      journaledDays: const {},
      hydrationTargetReached: false,
    );
  },
);

final notificationTodayLogProvider = StreamProvider<DailyLog?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = ref.watch(localTodayProvider);
  return (db.select(db.dailyLogs)
        ..where((tbl) => tbl.deletedAt.isNull() & tbl.date.equals(today))
        ..limit(1))
      .watchSingleOrNull();
});

Future<NotificationSourceSnapshot> buildNotificationSourceSnapshotFromDatabase(
  AppDatabase db, {
  bool? conceptionModeActive,
  DateTime? today,
}) async {
  final effectiveToday = normalizeDate(today ?? DateTime.now());
  final history =
      await (db.select(db.cyclePeriods)
            ..where((tbl) => tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.startDate)]))
          .get();
  final userProfile = await (db.select(
    db.userProfiles,
  )..limit(1)).getSingleOrNull();
  final todayLog =
      await (db.select(db.dailyLogs)
            ..where(
              (tbl) => tbl.deletedAt.isNull() & tbl.date.equals(effectiveToday),
            )
            ..limit(1))
          .getSingleOrNull();
  final conceptionProfile = await (db.select(
    db.conceptionProfiles,
  )..limit(1)).getSingleOrNull();
  final ttcActive =
      conceptionModeActive ?? conceptionProfile?.status == 'tryingToConceive';

  final output = CycleEngine.calculate(
    periodHistory: [
      for (final period in history)
        CyclePeriodRecord(startDate: period.startDate, endDate: period.endDate),
    ],
    targetDate: effectiveToday,
    userConfiguredAverageCycleLength: userProfile?.averageCycleLength ?? 28,
    userConfiguredPeriodLength: userProfile?.averagePeriodLength ?? 5,
  );
  final snapshot = output.toSnapshot(effectiveToday, isTtcEnabled: ttcActive);
  final location = quevaaNotificationTimezoneService.localLocation;

  tz.TZDateTime? toTz(DateTime? dt) {
    if (dt == null) return null;
    return tz.TZDateTime(location, dt.year, dt.month, dt.day, 9);
  }

  return NotificationSourceSnapshot(
    cycleTrackingPaused: !snapshot.hasEnoughData,
    pregnancyMode: false,
    conceptionModeActive: ttcActive,
    estimatedPeriodStart: toTz(snapshot.primaryPrediction?.estimatedStartDate),
    fertileWindowStart: toTz(snapshot.fertileWindowRange?.start),
    fertileWindowEnd: toTz(snapshot.fertileWindowRange?.end),
    estimatedOvulationDate: toTz(
      snapshot.ovulationRange?.start.add(const Duration(days: 1)),
    ),
    predictionConfidence: snapshot.confidence,
    currentCycleDay: snapshot.cycleDay,
    estimatedPhase: output.estimatedPhase,
    todayEnergyLevel: todayLog?.energyLevel,
    todayPainLevel: todayLog?.painLevel,
    todaySleepHours: todayLog?.sleepHours,
    mealSuggestion: _mealSuggestion(output.estimatedPhase),
    workoutSuggestion: _workoutSuggestion(todayLog),
    hydrationTargetReached: (todayLog?.waterGlasses ?? 0) >= 8,
  );
}

String _mealSuggestion(String phase) {
  final meals = NigerianRecipeDatabase.getForPhase(phase);
  return (meals.isEmpty ? NigerianRecipeDatabase.recipes : meals).first.title;
}

String _workoutSuggestion(DailyLog? log) {
  final workouts = WorkoutRecommendationEngine.recommendWorkouts(
    availableWorkouts: bundledWorkoutCatalog,
    userEnergyLevel: log?.energyLevel ?? 3,
    userPainLevel: log?.painLevel ?? 0,
    sleepHours: log?.sleepHours ?? 7.5,
  );
  return (workouts.isEmpty ? bundledWorkoutCatalog : workouts).first.title;
}
