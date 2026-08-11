import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../cycle/application/cycle_workspace_provider.dart';
import '../../cycle/domain/models/estimated_cycle_phase.dart';
import '../../notifications/application/notification_preferences_provider.dart';
import '../../notifications/application/notification_snapshot_provider.dart';
import '../../notifications/domain/services/notification_scheduler.dart';
import '../../nutrition/data/nigerian_recipe_database.dart';
import '../../recommendations/application/daily_quevaa_plan_provider.dart';
import '../../workouts/domain/entities/workout_entity.dart';
import '../../../core/security/secure_storage_service.dart';

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

final savedMealsStreamProvider = StreamProvider<List<SavedMeal>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.savedMeals)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.savedAt)]))
      .watch();
});

final mealPreparationHistoryProvider =
    StreamProvider<List<MealPreparationEntry>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return (db.select(db.mealPreparationEntries)
            ..where((tbl) => tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.preparedAt)]))
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

final journalStreamProvider = StreamProvider<List<JournalEntry>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final secureStorage = SecureStorageService();
  final stream =
      (db.select(db.journalEntries)
            ..where((tbl) => tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
          .watch();

  await for (final entries in stream) {
    final decrypted = <JournalEntry>[];
    for (final entry in entries) {
      if (SecureStorageService.isEncrypted(entry.encryptedContent)) {
        try {
          final plainText = await secureStorage.decryptJournalContent(
            entry.encryptedContent,
          );
          decrypted.add(entry.copyWith(encryptedContent: plainText));
        } catch (_) {
          decrypted.add(entry);
        }
      } else {
        decrypted.add(entry);
      }
    }
    yield decrypted;
  }
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
  final plan = ref.watch(dailyQuevaaPlanProvider);
  return WellnessRecommendation(
    focus: plan.wellnessFocus,
    reason: plan.wellnessReason,
    meal: plan.featuredMeal,
    workout: plan.workout,
    hydrationTarget: plan.hydrationTarget,
    journalPrompt: plan.journalPrompt,
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
    await _reconcileNotifications(
      NotificationReconciliationReason.mealPlanChanged,
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

  Future<void> toggleSavedMeal(NigerianRecipe recipe) async {
    final now = DateTime.now();
    final existing =
        await (_db.select(_db.savedMeals)
              ..where(
                (tbl) => tbl.deletedAt.isNull() & tbl.mealId.equals(recipe.id),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.savedMeals)
          .insert(
            SavedMealsCompanion.insert(
              uuid: localUuid('saved-meal'),
              createdAt: now,
              updatedAt: now,
              mealId: recipe.id,
              savedAt: now,
            ),
          );
    } else {
      await (_db.update(
        _db.savedMeals,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        SavedMealsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    }
  }

  Future<void> markMealPrepared(
    NigerianRecipe recipe, {
    int? servings,
    String? notes,
  }) async {
    final now = DateTime.now();
    final today = ref.read(localTodayProvider);
    final cycle = ref.read(currentCycleSnapshotProvider);
    final existing =
        await (_db.select(_db.mealPreparationEntries)
              ..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.mealId.equals(recipe.id) &
                    tbl.date.equals(today) &
                    tbl.mealType.equals(recipe.mealType),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.mealPreparationEntries)
          .insert(
            MealPreparationEntriesCompanion.insert(
              uuid: localUuid('meal-prepared'),
              createdAt: now,
              updatedAt: now,
              mealId: recipe.id,
              preparedAt: now,
              date: today,
              mealType: recipe.mealType,
              servings: Value(servings ?? recipe.servings),
              cycleDay: Value(cycle.cycleDay),
              cyclePhase: Value(cycle.phase.label),
              notes: Value(notes),
            ),
          );
    } else {
      await (_db.update(
        _db.mealPreparationEntries,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        MealPreparationEntriesCompanion(
          preparedAt: Value(now),
          servings: Value(servings ?? existing.servings),
          notes: Value(notes ?? existing.notes),
          updatedAt: Value(now),
        ),
      );
    }
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
    await _reconcileNotifications(
      NotificationReconciliationReason.mealPlanChanged,
    );
  }

  Future<void> addRecipeToShoppingList(NigerianRecipe recipe) async {
    final now = DateTime.now();
    for (final ingredient in recipe.ingredients) {
      final existing =
          await (_db.select(_db.shoppingItems)
                ..where(
                  (tbl) =>
                      tbl.deletedAt.isNull() &
                      tbl.isPurchased.equals(false) &
                      tbl.itemName.lower().equals(
                        ingredient.name.toLowerCase(),
                      ) &
                      tbl.unit.equals(ingredient.unit),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.shoppingItems)
            .insert(
              ShoppingItemsCompanion.insert(
                uuid: localUuid('shopping'),
                createdAt: now,
                updatedAt: now,
                itemName: ingredient.name,
                quantity: Value(_formatQuantity(ingredient.quantity)),
                unit: Value(ingredient.unit),
                category: Value(ingredient.category),
                sourceMealTitle: Value(recipe.title),
              ),
            );
      } else {
        final nextQuantity =
            (_parseQuantity(existing.quantity) ?? 0) + ingredient.quantity;
        await (_db.update(
          _db.shoppingItems,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          ShoppingItemsCompanion(
            quantity: Value(_formatQuantity(nextQuantity)),
            sourceMealTitle: Value(
              existing.sourceMealTitle == null ||
                      existing.sourceMealTitle == recipe.title
                  ? recipe.title
                  : '${existing.sourceMealTitle}, ${recipe.title}',
            ),
            updatedAt: Value(now),
          ),
        );
      }
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

  Future<void> removeShoppingItem(ShoppingItem item) async {
    final now = DateTime.now();
    await (_db.update(
      _db.shoppingItems,
    )..where((tbl) => tbl.id.equals(item.id))).write(
      ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> clearCompletedShoppingItems() async {
    final now = DateTime.now();
    await (_db.update(
      _db.shoppingItems,
    )..where((tbl) => tbl.isPurchased.equals(true))).write(
      ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  void showAnotherMeal(String mealType) {
    final notifier = ref.read(mealAlternativeOffsetsProvider.notifier);
    final current = notifier.state;
    notifier.state = {...current, mealType: (current[mealType] ?? 0) + 1};
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
    await _reconcileNotifications(
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
    await _reconcileNotifications(
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
    final secureStorage = SecureStorageService();
    final encryptedContent = await secureStorage.encryptJournalContent(
      content.trim(),
    );

    if (id == null) {
      await _db
          .into(_db.journalEntries)
          .insert(
            JournalEntriesCompanion.insert(
              uuid: localUuid('journal'),
              createdAt: now,
              updatedAt: now,
              title: Value(
                title.trim().isEmpty ? 'Private Reflection' : title.trim(),
              ),
              encryptedContent: encryptedContent,
              mood: Value(mood ?? 'Calm'),
              tagsJson: Value(tagsStr),
            ),
          );
    } else {
      await (_db.update(
        _db.journalEntries,
      )..where((tbl) => tbl.id.equals(id))).write(
        JournalEntriesCompanion(
          title: Value(
            title.trim().isEmpty ? 'Private Reflection' : title.trim(),
          ),
          encryptedContent: Value(encryptedContent),
          mood: Value(mood ?? 'Calm'),
          tagsJson: Value(tagsStr),
          updatedAt: Value(now),
        ),
      );
    }
    await _reconcileNotifications(
      NotificationReconciliationReason.journalChanged,
    );
  }

  Future<void> deleteJournalEntry(int id) async {
    final now = DateTime.now();
    await (_db.update(_db.journalEntries)..where((tbl) => tbl.id.equals(id)))
        .write(JournalEntriesCompanion(deletedAt: Value(now)));
    await _reconcileNotifications(
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

  Future<void> _reconcileNotifications(
    NotificationReconciliationReason reason,
  ) async {
    final snapshot = await buildNotificationSourceSnapshotFromDatabase(
      _db,
      today: ref.read(localTodayProvider),
    );
    await ref
        .read(notificationSchedulerProvider)
        .reconcileNotifications(reason, snapshot: snapshot);
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}

double? _parseQuantity(String? value) {
  if (value == null) return null;
  return double.tryParse(value);
}
