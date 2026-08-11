import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../cycle/application/cycle_workspace_provider.dart';
import '../../cycle/domain/models/current_cycle_snapshot.dart';
import '../../cycle/domain/models/cycle_engine_output.dart';
import '../../dashboard/domain/readiness_calculator.dart';
import '../../nutrition/data/nigerian_recipe_database.dart';
import '../../productivity/application/plan_workspace_provider.dart';
import '../../workouts/data/workout_catalog.dart';
import '../../workouts/domain/entities/workout_entity.dart';
import '../../workouts/domain/workout_recommendation_engine.dart';

final onboardingPreferencesProvider = StreamProvider<OnboardingPreference?>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.onboardingPreferences)..limit(1)).watchSingleOrNull();
});

final todaysDailyLogProvider = StreamProvider<DailyLog?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = ref.watch(localTodayProvider);
  return (db.select(db.dailyLogs)
        ..where((tbl) => tbl.deletedAt.isNull() & tbl.date.equals(today))
        ..limit(1))
      .watchSingleOrNull();
});

final recentDailyLogsProvider = StreamProvider<List<DailyLog>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = ref.watch(localTodayProvider);
  final start = today.subtract(const Duration(days: 90));
  return (db.select(db.dailyLogs)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.date.isBiggerOrEqualValue(start) &
              tbl.date.isSmallerOrEqualValue(today),
        )
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
      .watch();
});

final mealAlternativeOffsetsProvider = StateProvider<Map<String, int>>(
  (ref) => const {},
);

final savedMealIdsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.savedMeals)..where((tbl) => tbl.deletedAt.isNull()))
      .watch()
      .map((rows) => rows.map((row) => row.mealId).toSet());
});

final recentlyPreparedMealIdsProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = ref.watch(localTodayProvider);
  final start = today.subtract(const Duration(days: 2));
  return (db.select(db.mealPreparationEntries)..where(
        (tbl) =>
            tbl.deletedAt.isNull() &
            tbl.date.isBiggerOrEqualValue(start) &
            tbl.date.isSmallerOrEqualValue(today),
      ))
      .watch()
      .map((rows) => rows.map((row) => row.mealId).toSet());
});

final pantryIngredientNamesProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.pantryItems)..where((tbl) => tbl.deletedAt.isNull()))
      .watch()
      .map((rows) => rows.map((row) => row.name).toList(growable: false));
});

final dailyQuevaaPlanProvider = Provider<DailyQuevaaPlan>((ref) {
  final date = ref.watch(localTodayProvider);
  final cycleOutput = ref.watch(currentCycleOutputProvider);
  final cycleSnapshot = ref.watch(currentCycleSnapshotProvider);
  final prefs = ref.watch(onboardingPreferencesProvider).valueOrNull;
  final todayLog = ref.watch(todaysDailyLogProvider).valueOrNull;
  final recentLogs = ref.watch(recentDailyLogsProvider).valueOrNull ?? const [];
  final savedMealIds = ref.watch(savedMealIdsProvider).valueOrNull ?? const {};
  final recentlyPreparedMealIds =
      ref.watch(recentlyPreparedMealIdsProvider).valueOrNull ?? const {};
  final pantryItems =
      ref.watch(pantryIngredientNamesProvider).valueOrNull ?? const [];
  final alternativeOffsets = ref.watch(mealAlternativeOffsetsProvider);
  final todayTasks = ref.watch(rankedTodayTasksProvider);

  final energy = todayLog?.energyLevel;
  final pain = todayLog?.painLevel;
  final sleep = todayLog?.sleepHours;
  final symptoms = _decodeSymptoms(todayLog);

  final readiness = ReadinessCalculator.calculate(
    selfReportedEnergy: energy,
    sleepHours: sleep,
    painLevel: pain,
    mood: todayLog?.mood,
    stressLevel: todayLog?.stressLevel,
    symptoms: symptoms,
    estimatedPhase: cycleOutput.estimatedPhase,
    currentCycleDay: cycleSnapshot.cycleDay ?? cycleOutput.currentCycleDay,
    isPeriodActive: cycleSnapshot.isPeriodActive,
    loggedHistoryCount: recentLogs.length,
    historyProfile: _historyProfile(
      logs: recentLogs,
      today: date,
      currentCycleDay: cycleSnapshot.cycleDay ?? cycleOutput.currentCycleDay,
    ),
  );

  final phaseKey = NigerianRecipeDatabase.phaseKeyForCyclePhase(
    cycleOutput.estimatedPhase,
  );
  final meals = NigerianRecipeDatabase.recommendDailyMeals(
    date: date,
    cyclePhase: cycleOutput.estimatedPhase,
    dietaryPattern: prefs?.dietaryPattern,
    preferredRegion: prefs?.regionPreference,
    prepTimePreference: prefs?.prepTimePreference,
    excludedAllergens: _allergensFromPreference(prefs?.dietaryPattern),
    pantryItems: pantryItems,
    recentlyPreparedMealIds: recentlyPreparedMealIds,
    savedMealIds: savedMealIds,
    alternativeOffsets: alternativeOffsets,
  );
  final workout = _selectWorkout(
    date: date,
    phaseKey: phaseKey,
    energy: energy ?? _historicalAverageInt(recentLogs, 3),
    pain:
        pain ??
        _historicalAverageInt(recentLogs, 0, selector: (log) => log.painLevel),
    sleep: sleep ?? _historicalAverageSleep(recentLogs, 7.5),
    lowImpactOnly: prefs?.lowImpactOnly ?? false,
  );

  return DailyQuevaaPlan(
    date: date,
    cycleOutput: cycleOutput,
    cycleSnapshot: cycleSnapshot,
    todayLog: todayLog,
    readiness: readiness,
    meals: meals,
    workout: workout,
    productivityRecommendation: _productivityRecommendation(
      readiness,
      cycleOutput,
      recentLogs.length,
      todayTasks,
    ),
    topFocusTask: _topFocusTask(todayTasks),
    topFocusReason: _topFocusReason(readiness, _topFocusTask(todayTasks)),
    wellnessFocus: _wellnessFocus(readiness),
    wellnessReason: _wellnessReason(cycleOutput, todayLog, recentLogs.length),
    hydrationTarget: (todayLog?.waterGlasses ?? 0) >= 8
        ? todayLog!.waterGlasses
        : 8,
    journalPrompt: _journalPrompt(readiness, cycleOutput),
    symptoms: symptoms,
  );
});

class DailyQuevaaPlan {
  final DateTime date;
  final CycleEngineOutput cycleOutput;
  final CurrentCycleSnapshot cycleSnapshot;
  final DailyLog? todayLog;
  final DailyReadinessResult readiness;
  final Map<String, NigerianRecipe> meals;
  final WorkoutEntity workout;
  final String productivityRecommendation;
  final Task? topFocusTask;
  final String topFocusReason;
  final String wellnessFocus;
  final String wellnessReason;
  final int hydrationTarget;
  final String journalPrompt;
  final List<String> symptoms;

  const DailyQuevaaPlan({
    required this.date,
    required this.cycleOutput,
    required this.cycleSnapshot,
    required this.todayLog,
    required this.readiness,
    required this.meals,
    required this.workout,
    required this.productivityRecommendation,
    required this.topFocusTask,
    required this.topFocusReason,
    required this.wellnessFocus,
    required this.wellnessReason,
    required this.hydrationTarget,
    required this.journalPrompt,
    required this.symptoms,
  });

  NigerianRecipe get featuredMeal =>
      meals['Lunch'] ?? meals['Dinner'] ?? meals.values.first;

  NigerianRecipe mealForOffset(int offset) {
    final values = meals.values.toList(growable: false);
    return values[offset % values.length];
  }
}

WorkoutEntity _selectWorkout({
  required DateTime date,
  required String phaseKey,
  required int energy,
  required int pain,
  required double sleep,
  required bool lowImpactOnly,
}) {
  final phaseAware = bundledWorkoutCatalog.where((workout) {
    final target = workout.targetPhase.toLowerCase();
    return target == 'all' || target == phaseKey;
  }).toList();
  final candidates =
      WorkoutRecommendationEngine.recommendWorkouts(
        availableWorkouts: phaseAware.isEmpty
            ? bundledWorkoutCatalog
            : phaseAware,
        userEnergyLevel: energy,
        userPainLevel: pain,
        sleepHours: sleep,
      ).where((workout) {
        return !lowImpactOnly || workout.intensity != 'High';
      }).toList();
  final pool = candidates.isEmpty ? bundledWorkoutCatalog : candidates;
  return pool[_stableIndex(date, '$phaseKey-workout-$energy-$pain', pool)];
}

String _productivityRecommendation(
  DailyReadinessResult readiness,
  CycleEngineOutput cycle,
  int historyCount,
  List<Task> todayTasks,
) {
  final pending = todayTasks
      .where((task) => !task.isCompleted && task.status != 'Completed')
      .toList();
  if (pending.isEmpty) {
    return 'Choose one meaningful task for today, then Quevaa can rank it against your check-in.';
  }
  switch (readiness.score) {
    case ReadinessScore.restore:
      return 'Quevaa is prioritising lighter, necessary work because today calls for more recovery room.';
    case ReadinessScore.gentle:
      return 'Quevaa is favouring shorter, useful tasks so the plan stays flexible.';
    case ReadinessScore.steady:
      return 'Quevaa is choosing a core priority that fits a steady, manageable pace.';
    case ReadinessScore.focused:
      return 'Quevaa is placing deeper work near the top while your current signals support it.';
    case ReadinessScore.strong:
      return 'Quevaa is surfacing demanding work because today’s capacity looks stronger.';
  }
}

String _wellnessFocus(DailyReadinessResult readiness) {
  return switch (readiness.score) {
    ReadinessScore.restore => 'Gentle care',
    ReadinessScore.gentle => 'Steady support',
    ReadinessScore.steady => 'Steady rhythm',
    ReadinessScore.focused => 'Focused support',
    ReadinessScore.strong => 'Strong capacity',
  };
}

String _wellnessReason(
  CycleEngineOutput cycle,
  DailyLog? todayLog,
  int historyCount,
) {
  final phaseText = _phasePhrase(cycle.estimatedPhase);
  if (todayLog != null) {
    return 'Based on today’s energy, pain, sleep, and $phaseText.';
  }
  if (historyCount >= 7) {
    return 'Based on recent Quevaa logs and your $phaseText.';
  }
  return 'Conservative guidance while Quevaa learns your local patterns.';
}

String _phasePhrase(String estimatedPhase) {
  final phase = estimatedPhase.toLowerCase();
  if (phase.contains('unavailable')) return 'limited cycle data';
  if (phase.contains('phase')) return 'estimated $phase';
  return 'estimated $phase phase';
}

String _journalPrompt(DailyReadinessResult readiness, CycleEngineOutput cycle) {
  if (readiness.score == ReadinessScore.restore) {
    return 'What would make today feel softer and more manageable?';
  }
  return 'What helped your energy feel steady during this ${cycle.estimatedPhase.toLowerCase()} day?';
}

Task? _topFocusTask(List<Task> tasks) {
  for (final task in tasks) {
    if (!task.isCompleted && task.status != 'Completed') return task;
  }
  return null;
}

String _topFocusReason(DailyReadinessResult readiness, Task? task) {
  if (task == null) {
    return 'Add a task to let Quevaa connect your readiness to a practical next step.';
  }
  return 'This ${task.estimatedDurationMinutes}-minute ${task.recommendedEnergy.toLowerCase()}-energy task fits today’s ${readiness.label.toLowerCase()} pace.';
}

ReadinessHistoryProfile _historyProfile({
  required List<DailyLog> logs,
  required DateTime today,
  required int? currentCycleDay,
}) {
  if (currentCycleDay == null || logs.isEmpty) {
    return const ReadinessHistoryProfile(matchingCycleLogs: 0);
  }
  final matching = logs.where((log) {
    final daysAgo = today.difference(normalizeDate(log.date)).inDays;
    if (daysAgo <= 0) return false;
    final approximateCycleDay = ((currentCycleDay - daysAgo - 1) % 28) + 1;
    return (approximateCycleDay - currentCycleDay).abs() <= 2;
  }).toList();
  return ReadinessHistoryProfile(
    matchingCycleLogs: matching.length,
    typicalEnergy: _averageOrNull(
      matching.map((log) => log.energyLevel.toDouble()),
    ),
    typicalPain: _averageOrNull(
      matching.map((log) => log.painLevel.toDouble()),
    ),
    typicalSleep: _averageOrNull(
      matching.map((log) => log.sleepHours).whereType<double>(),
    ),
  );
}

double? _averageOrNull(Iterable<double> values) {
  final list = values.where((value) => value > 0).toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

int _historicalAverageInt(
  List<DailyLog> logs,
  int fallback, {
  int Function(DailyLog log)? selector,
}) {
  final values = logs
      .map((log) => selector?.call(log) ?? log.energyLevel)
      .where((value) => value > 0);
  if (values.isEmpty) return fallback;
  return (values.reduce((a, b) => a + b) / values.length).round().clamp(1, 5);
}

double _historicalAverageSleep(List<DailyLog> logs, double fallback) {
  final values = logs
      .map((log) => log.sleepHours)
      .whereType<double>()
      .where((value) => value > 0)
      .toList();
  if (values.isEmpty) return fallback;
  return values.reduce((a, b) => a + b) / values.length;
}

List<String> _decodeSymptoms(DailyLog? log) {
  if (log == null) return const [];
  try {
    final decoded = jsonDecode(log.customSymptomsJson);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList(growable: false);
    }
  } catch (_) {
    return const [];
  }
  return const [];
}

int _stableIndex(DateTime date, String key, List<Object> values) {
  final seed = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  final hash = Object.hash(seed, key).abs();
  return hash % values.length;
}

List<String> _allergensFromPreference(String? dietaryPattern) {
  final lower = dietaryPattern?.toLowerCase() ?? '';
  return [
    if (lower.contains('no dairy') || lower.contains('dairy-free')) 'dairy',
    if (lower.contains('no egg') || lower.contains('egg-free')) 'egg',
    if (lower.contains('no fish') || lower.contains('fish-free')) 'fish',
    if (lower.contains('groundnut') || lower.contains('peanut')) 'peanut',
  ];
}
