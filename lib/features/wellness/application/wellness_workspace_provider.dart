import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../cycle/application/cycle_workspace_provider.dart';
import '../../notifications/application/notification_preferences_provider.dart';
import '../../notifications/domain/services/notification_scheduler.dart';
import '../../nutrition/data/nigerian_recipe_database.dart';
import '../../workouts/domain/entities/workout_entity.dart';
import '../../workouts/domain/workout_recommendation_engine.dart';

final wellnessSectionProvider = StateProvider<String>((ref) => 'For You');

final todaysWellnessLogProvider = StreamProvider<DailyLog?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = normalizeDate(DateTime.now());
  return (db.select(db.dailyLogs)
        ..where((tbl) => tbl.deletedAt.isNull() & tbl.date.equals(today))
        ..limit(1))
      .watchSingleOrNull();
});

final mealPlanStreamProvider = StreamProvider<List<MealPlan>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = normalizeDate(DateTime.now());
  final end = today.add(const Duration(days: 7));
  return (db.select(db.mealPlans)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.date.isBiggerOrEqualValue(today) &
              tbl.date.isSmallerThanValue(end),
        )
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
      .watch();
});

final pantryStreamProvider = StreamProvider<List<PantryItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.pantryItems)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
      .watch();
});

final shoppingStreamProvider = StreamProvider<List<ShoppingItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.shoppingItems)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([
          (tbl) => OrderingTerm.asc(tbl.isPurchased),
          (tbl) => OrderingTerm.asc(tbl.itemName),
        ]))
      .watch();
});

final workoutSessionStreamProvider = StreamProvider<List<WorkoutSession>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.workoutSessions)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.completedAt)]))
      .watch();
});

final journalStreamProvider = StreamProvider<List<JournalEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.journalEntries)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
      .watch();
});

final journalEntryCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .select(db.journalEntries)
      .watch()
      .map(
        (entries) => entries.where((entry) => entry.deletedAt == null).length,
      );
});

final wellnessRecommendationProvider = Provider<WellnessRecommendation>((ref) {
  final log = ref.watch(todaysWellnessLogProvider).valueOrNull;
  final cycle = ref.watch(currentCycleOutputProvider);
  final recipes = NigerianRecipeDatabase.getForPhase(cycle.estimatedPhase);
  final meal = recipes.isEmpty
      ? NigerianRecipeDatabase.recipes.first
      : recipes.first;
  final workouts = WorkoutRecommendationEngine.recommendWorkouts(
    availableWorkouts: bundledWorkoutCatalog,
    userEnergyLevel: log?.energyLevel ?? 3,
    userPainLevel: log?.painLevel ?? 0,
    sleepHours: log?.sleepHours ?? 7,
  );
  final workout = workouts.isEmpty
      ? bundledWorkoutCatalog.first
      : workouts.first;
  final lowEnergy = (log?.energyLevel ?? 3) <= 2 || (log?.painLevel ?? 0) >= 3;
  return WellnessRecommendation(
    focus: lowEnergy ? 'Gentle balance' : 'Steady nourishment',
    reason: lowEnergy
        ? 'Based on lower energy or higher pain logged today.'
        : 'Based on today’s log and your estimated ${cycle.estimatedPhase.toLowerCase()} phase.',
    meal: meal,
    workout: workout,
    hydrationTarget: log?.waterGlasses == null || log!.waterGlasses < 8
        ? 8
        : log.waterGlasses,
    journalPrompt: lowEnergy
        ? 'What would make today feel softer and more manageable?'
        : 'What helped your energy feel steady today?',
  );
});

final wellnessWorkspaceControllerProvider =
    NotifierProvider<WellnessWorkspaceController, bool>(
      WellnessWorkspaceController.new,
    );

class WellnessRecommendation {
  final String focus;
  final String reason;
  final NigerianRecipe meal;
  final WorkoutEntity workout;
  final int hydrationTarget;
  final String journalPrompt;

  const WellnessRecommendation({
    required this.focus,
    required this.reason,
    required this.meal,
    required this.workout,
    required this.hydrationTarget,
    required this.journalPrompt,
  });
}

class WellnessWorkspaceController extends Notifier<bool> {
  @override
  bool build() => false;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> logWater(int glasses) async {
    final today = normalizeDate(DateTime.now());
    final now = DateTime.now();
    final existing =
        await (_db.select(_db.dailyLogs)
              ..where((tbl) => tbl.deletedAt.isNull() & tbl.date.equals(today))
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.dailyLogs)
          .insert(
            DailyLogsCompanion.insert(
              uuid: localUuid('log'),
              createdAt: now,
              updatedAt: now,
              date: today,
              waterGlasses: Value(glasses),
            ),
          );
    } else {
      await (_db.update(
        _db.dailyLogs,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        DailyLogsCompanion(waterGlasses: Value(glasses), updatedAt: Value(now)),
      );
    }
    await _db
        .into(_db.hydrationEntries)
        .insert(
          HydrationEntriesCompanion.insert(
            uuid: localUuid('water'),
            createdAt: now,
            updatedAt: now,
            date: today,
            glassesDrank: Value(glasses),
          ),
        );
    // Reconcile notifications after logging water
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.mealPlanChanged, // Closest match or wellness
    );
  }

  Future<void> planMeal(DateTime date, NigerianRecipe recipe) async {
    final now = DateTime.now();
    await _db
        .into(_db.mealPlans)
        .insert(
          MealPlansCompanion.insert(
            uuid: localUuid('meal-plan'),
            createdAt: now,
            updatedAt: now,
            date: normalizeDate(date),
            mealId: recipe.title.hashCode.abs(),
            mealType: recipe.mealType,
          ),
        );
  }

  Future<void> markMealPrepared(NigerianRecipe recipe) async {
    final now = DateTime.now();
    await _db
        .into(_db.mealLogs)
        .insert(
          MealLogsCompanion.insert(
            uuid: localUuid('meal-log'),
            createdAt: now,
            updatedAt: now,
            loggedAt: now,
            mealTitle: recipe.title,
            notes: const Value('Prepared from Wellness workspace'),
          ),
        );
  }

  Future<void> addRecipeToShoppingList(NigerianRecipe recipe) async {
    final now = DateTime.now();
    for (final item in _ingredientsForRecipe(recipe)) {
      await _db
          .into(_db.shoppingItems)
          .insert(
            ShoppingItemsCompanion.insert(
              uuid: localUuid('shopping'),
              createdAt: now,
              updatedAt: now,
              itemName: item,
              category: const Value('Meal plan'),
              sourceMealTitle: Value(recipe.title),
            ),
          );
    }
  }

  Future<void> addPantryItem({
    required String name,
    double quantity = 1,
    String unit = 'item',
    bool lowStock = false,
  }) async {
    if (name.trim().isEmpty) return;
    final now = DateTime.now();
    await _db
        .into(_db.pantryItems)
        .insert(
          PantryItemsCompanion.insert(
            uuid: localUuid('pantry'),
            createdAt: now,
            updatedAt: now,
            name: name.trim(),
            quantity: quantity,
            unit: unit,
            lowStock: Value(lowStock),
          ),
        );
  }

  Future<void> toggleShoppingItem(ShoppingItem item) async {
    await (_db.update(
      _db.shoppingItems,
    )..where((tbl) => tbl.id.equals(item.id))).write(
      ShoppingItemsCompanion(
        isPurchased: Value(!item.isPurchased),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> completeWorkout(
    WorkoutEntity workout, {
    int exertion = 5,
  }) async {
    final now = DateTime.now();
    await _db
        .into(_db.workoutPlans)
        .insertOnConflictUpdate(
          WorkoutPlansCompanion.insert(
            id: Value(workout.id.hashCode.abs()),
            uuid: 'workout-${workout.id}',
            createdAt: now,
            updatedAt: now,
            title: workout.title,
            category: workout.category,
            targetPhase: workout.targetPhase,
            durationMinutes: workout.durationMinutes,
            intensity: workout.intensity,
          ),
        );
    await _db
        .into(_db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            uuid: localUuid('workout-session'),
            createdAt: now,
            updatedAt: now,
            workoutPlanId: workout.id.hashCode.abs(),
            completedAt: now,
            perceivedExertion: exertion,
          ),
        );
    // Reconcile notifications after completing a workout
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.workoutPlanChanged,
    );
  }

  Future<void> markRestDay() async {
    final now = DateTime.now();
    await _db
        .into(_db.workoutPlans)
        .insertOnConflictUpdate(
          WorkoutPlansCompanion.insert(
            id: const Value(0),
            uuid: 'workout-rest-day',
            createdAt: now,
            updatedAt: now,
            title: 'Rest day',
            category: 'Recovery Sessions',
            targetPhase: 'All',
            durationMinutes: 0,
            intensity: 'Gentle',
          ),
        );
    await _db
        .into(_db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            uuid: localUuid('rest-day'),
            createdAt: now,
            updatedAt: now,
            workoutPlanId: 0,
            completedAt: now,
            perceivedExertion: 1,
          ),
        );
    // Reconcile notifications after marking a rest day
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.workoutPlanChanged,
    );
  }

  Future<void> saveJournalEntry({
    int? id,
    required String title,
    required String content,
    String? mood,
    List<String>? tags,
  }) async {
    final now = DateTime.now();
    final tagsStr = jsonEncode(tags ?? ['reflection']);
    if (id == null) {
      await _db.into(_db.journalEntries).insert(
            JournalEntriesCompanion.insert(
              uuid: localUuid('journal'),
              createdAt: now,
              updatedAt: now,
              title: Value(
                title.trim().isEmpty ? 'Private Reflection' : title.trim(),
              ),
              encryptedContent: content.trim(),
              mood: Value(mood ?? 'Calm'),
              tagsJson: Value(tagsStr),
            ),
          );
    } else {
      await (_db.update(_db.journalEntries)..where((tbl) => tbl.id.equals(id)))
          .write(
        JournalEntriesCompanion(
          title: Value(
            title.trim().isEmpty ? 'Private Reflection' : title.trim(),
          ),
          encryptedContent: Value(content.trim()),
          mood: Value(mood ?? 'Calm'),
          tagsJson: Value(tagsStr),
          updatedAt: Value(now),
        ),
      );
    }
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.journalChanged,
    );
  }

  Future<void> deleteJournalEntry(int id) async {
    final now = DateTime.now();
    await (_db.update(_db.journalEntries)..where((tbl) => tbl.id.equals(id)))
        .write(JournalEntriesCompanion(deletedAt: Value(now)));
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.journalChanged,
    );
  }

  Future<void> addJournalPrompt(String prompt) async {
    await saveJournalEntry(
      title: 'Daily Reflection Prompt',
      content: prompt,
      mood: 'Reflective',
      tags: ['prompt', 'reflection'],
    );
  }
}

List<String> _ingredientsForRecipe(NigerianRecipe recipe) {
  final lower = recipe.description.toLowerCase();
  final items = <String>{};
  for (final candidate in [
    'ugu',
    'plantain',
    'fish',
    'yam',
    'okra',
    'beans',
    'sweet potato',
    'egusi',
    'spinach',
    'ginger',
    'zobo',
  ]) {
    if (lower.contains(candidate) ||
        recipe.title.toLowerCase().contains(candidate)) {
      items.add(candidate);
    }
  }
  return items.isEmpty ? [recipe.title] : items.toList();
}

const bundledWorkoutCatalog = [
  WorkoutEntity(
    id: 'gentle-mobility-15',
    title: 'Gentle Mobility Reset',
    category: 'Gentle Mobility',
    durationMinutes: 15,
    intensity: 'Gentle',
    warmup: [
      ExerciseItem(
        name: 'Breathing reset',
        durationOrReps: '2 min',
        modification: 'Sit or lie down with one hand on your belly.',
      ),
    ],
    mainExercises: [
      ExerciseItem(
        name: 'Cat-cow',
        durationOrReps: '8 reps',
        modification: 'Use a chair if floor work is uncomfortable.',
      ),
      ExerciseItem(
        name: 'Hip circles',
        durationOrReps: '45 sec each way',
        modification: 'Reduce range if the lower back feels tender.',
      ),
    ],
    cooldown: [
      ExerciseItem(
        name: 'Child pose breathing',
        durationOrReps: '2 min',
        modification: 'Place a pillow under your torso.',
      ),
    ],
  ),
  WorkoutEntity(
    id: 'walk-strength-25',
    title: 'Walk and Strength Blend',
    category: 'Walking',
    durationMinutes: 25,
    intensity: 'Moderate',
    warmup: [
      ExerciseItem(
        name: 'Easy walk',
        durationOrReps: '5 min',
        modification: 'Keep conversation pace.',
      ),
    ],
    mainExercises: [
      ExerciseItem(
        name: 'Brisk walk intervals',
        durationOrReps: '10 min',
        modification: 'Shorten intervals if energy dips.',
      ),
      ExerciseItem(
        name: 'Wall push-up',
        durationOrReps: '2 x 8',
        modification: 'Step closer to the wall.',
      ),
    ],
    cooldown: [
      ExerciseItem(
        name: 'Slow walk and calf stretch',
        durationOrReps: '5 min',
        modification: 'Hold a support for balance.',
      ),
    ],
  ),
  WorkoutEntity(
    id: 'strength-30',
    title: 'Mat Strength Flow',
    category: 'Bodyweight Strength',
    durationMinutes: 30,
    intensity: 'High',
    warmup: [
      ExerciseItem(
        name: 'Dynamic warm-up',
        durationOrReps: '5 min',
        modification: 'Keep all moves low impact.',
      ),
    ],
    mainExercises: [
      ExerciseItem(
        name: 'Squat to chair',
        durationOrReps: '3 x 10',
        modification: 'Sit fully between reps.',
      ),
      ExerciseItem(
        name: 'Glute bridge',
        durationOrReps: '3 x 12',
        modification: 'Reduce range if cramping.',
      ),
    ],
    cooldown: [
      ExerciseItem(
        name: 'Full-body stretch',
        durationOrReps: '5 min',
        modification: 'Skip any position that feels sharp.',
      ),
    ],
  ),
];
