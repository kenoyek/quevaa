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
import '../domain/household_meal_planner.dart' as household;

final wellnessSectionProvider = StateProvider<String>((ref) => 'For You');
final mealsSectionProvider = StateProvider<String>((ref) => 'Today');
final plannerModeProvider = StateProvider<String>((ref) => 'Week');
final plannerWeekStartProvider = StateProvider<DateTime>((ref) {
  final today = normalizeDate(DateTime.now());
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
});

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

final householdProfileStreamProvider =
    StreamProvider<household.HouseholdProfileModel>((ref) async* {
      final db = ref.watch(appDatabaseProvider);
      final stream =
          (db.select(db.householdProfiles)
                ..where((tbl) => tbl.deletedAt.isNull())
                ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
                ..limit(1))
              .watchSingleOrNull();
      await for (final row in stream) {
        if (row == null) {
          yield const household.HouseholdProfileModel();
        } else {
          yield household.HouseholdProfileModel(
            householdName: row.householdName ?? '',
            adults: row.adultCount,
            children: row.childCount,
            defaultServings: row.defaultServings,
            dietaryPreferences: _decodeStringList(row.dietaryPreferencesJson),
            allergens: _decodeStringList(row.allergensJson),
            dislikedIngredients: _decodeStringList(row.dislikedIngredientsJson),
            weekdayPrepLimitMinutes: row.weekdayPrepLimitMinutes,
            weekendPrepLimitMinutes: row.weekendPrepLimitMinutes,
            avoidRepeatDinnerDays: row.avoidRepeatDinnerDays,
            weeklyBudget: row.weeklyBudget,
            monthlyBudget: row.monthlyBudget,
          );
        }
      }
    });

final familyMembersStreamProvider =
    StreamProvider<List<household.FamilyMemberModel>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return (db.select(db.familyMembers)
            ..where((tbl) => tbl.deletedAt.isNull() & tbl.active.equals(true))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => household.FamilyMemberModel(
                    id: row.uuid,
                    name: row.name,
                    ageGroup: _ageGroup(row.ageGroup),
                    dietaryPreferences: _decodeStringList(
                      row.dietaryPreferencesJson,
                    ),
                    allergens: _decodeStringList(row.allergensJson),
                    dislikedIngredients: _decodeStringList(
                      row.dislikedIngredientsJson,
                    ),
                    notes: row.notes ?? '',
                    active: row.active,
                  ),
                )
                .toList(growable: false),
          );
    });

final pantryInventoryProvider =
    StreamProvider<List<household.PantryInventoryItem>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return (db.select(db.pantryItems)
            ..where((tbl) => tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => household.PantryInventoryItem(
                    ingredientId: row.ingredientId.isEmpty
                        ? household.IngredientNormalizer.ingredientId(row.name)
                        : row.ingredientId,
                    displayName: row.name,
                    quantity: row.quantity,
                    unit: row.unit,
                    category: row.category,
                    expiryDate: row.expiryDate,
                    minimumStockLevel: row.minimumStockLevel,
                    storageLocation: row.storageLocation,
                    opened: row.opened,
                  ),
                )
                .toList(growable: false),
          );
    });

final weeklyFamilyMealPlanProvider = Provider<household.WeeklyPlanSummary>((
  ref,
) {
  final profile =
      ref.watch(householdProfileStreamProvider).valueOrNull ??
      const household.HouseholdProfileModel();
  final members = ref.watch(familyMembersStreamProvider).valueOrNull ?? [];
  final pantry = ref.watch(pantryInventoryProvider).valueOrNull ?? [];
  final savedIds =
      ref
          .watch(savedMealsStreamProvider)
          .valueOrNull
          ?.map((row) => row.mealId)
          .toSet() ??
      const <String>{};
  final preparedIds =
      ref
          .watch(mealPreparationHistoryProvider)
          .valueOrNull
          ?.map((row) => row.mealId)
          .toSet() ??
      const <String>{};
  final cycle = ref.watch(currentCycleSnapshotProvider);
  return const household.HouseholdMealPlanner().generateWeek(
    weekStart: ref.watch(plannerWeekStartProvider),
    household: profile,
    members: members,
    pantry: pantry,
    cyclePhase: cycle.phase.label,
    savedMealIds: savedIds,
    recentlyPreparedMealIds: preparedIds,
  );
});

final monthlyFamilyMealPlanProvider = Provider<household.MonthlyPlanSummary>((
  ref,
) {
  final profile =
      ref.watch(householdProfileStreamProvider).valueOrNull ??
      const household.HouseholdProfileModel();
  final members = ref.watch(familyMembersStreamProvider).valueOrNull ?? [];
  final pantry = ref.watch(pantryInventoryProvider).valueOrNull ?? [];
  final savedIds =
      ref
          .watch(savedMealsStreamProvider)
          .valueOrNull
          ?.map((row) => row.mealId)
          .toSet() ??
      const <String>{};
  final preparedIds =
      ref
          .watch(mealPreparationHistoryProvider)
          .valueOrNull
          ?.map((row) => row.mealId)
          .toSet() ??
      const <String>{};
  final cycle = ref.watch(currentCycleSnapshotProvider);
  return const household.HouseholdMealPlanner().generateMonth(
    month: ref.watch(plannerWeekStartProvider),
    household: profile,
    members: members,
    pantry: pantry,
    cyclePhase: cycle.phase.label,
    savedMealIds: savedIds,
    recentlyPreparedMealIds: preparedIds,
  );
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
    final profile =
        ref.read(householdProfileStreamProvider).valueOrNull ??
        const household.HouseholdProfileModel();
    await _db
        .into(_db.mealPlans)
        .insert(
          MealPlansCompanion.insert(
            uuid: localUuid('meal-plan'),
            createdAt: now,
            updatedAt: now,
            date: normalizeDate(date),
            mealId: recipe.title.hashCode.abs(),
            recipeId: Value(recipe.id),
            recipeTitle: Value(recipe.title),
            mealType: recipe.mealType,
            servings: Value(profile.effectiveServings),
          ),
        );
  }

  Future<void> saveHouseholdProfile({
    String householdName = '',
    int adults = 1,
    int children = 0,
    int? defaultServings,
    List<String> dietaryPreferences = const [],
    List<String> allergens = const [],
    List<String> dislikedIngredients = const [],
    int weekdayPrepLimitMinutes = 45,
    int weekendPrepLimitMinutes = 90,
    int avoidRepeatDinnerDays = 4,
    double? weeklyBudget,
    double? monthlyBudget,
  }) async {
    final now = DateTime.now();
    final existing =
        await (_db.select(_db.householdProfiles)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    final companion = HouseholdProfilesCompanion(
      householdName: Value(householdName.trim().isEmpty ? null : householdName),
      adultCount: Value(adults.clamp(0, 20)),
      childCount: Value(children.clamp(0, 20)),
      defaultServings: Value(
        (defaultServings ?? (adults + children).clamp(1, 20)).clamp(1, 30),
      ),
      dietaryPreferencesJson: Value(_encodeStringList(dietaryPreferences)),
      allergensJson: Value(_encodeStringList(allergens)),
      dislikedIngredientsJson: Value(_encodeStringList(dislikedIngredients)),
      weekdayPrepLimitMinutes: Value(weekdayPrepLimitMinutes.clamp(10, 240)),
      weekendPrepLimitMinutes: Value(weekendPrepLimitMinutes.clamp(10, 360)),
      avoidRepeatDinnerDays: Value(avoidRepeatDinnerDays.clamp(0, 14)),
      weeklyBudget: Value(weeklyBudget),
      monthlyBudget: Value(monthlyBudget),
      updatedAt: Value(now),
    );
    if (existing == null) {
      await _db
          .into(_db.householdProfiles)
          .insert(
            companion.copyWith(
              uuid: Value(localUuid('household')),
              createdAt: Value(now),
            ),
          );
    } else {
      await (_db.update(
        _db.householdProfiles,
      )..where((tbl) => tbl.id.equals(existing.id))).write(companion);
    }
  }

  Future<void> addFamilyMember({
    required String name,
    String ageGroup = 'Adult',
    List<String> dietaryPreferences = const [],
    List<String> allergens = const [],
    List<String> dislikedIngredients = const [],
    String? notes,
  }) async {
    if (name.trim().isEmpty) return;
    final now = DateTime.now();
    await _db
        .into(_db.familyMembers)
        .insert(
          FamilyMembersCompanion.insert(
            uuid: localUuid('family-member'),
            createdAt: now,
            updatedAt: now,
            name: name.trim(),
            ageGroup: Value(ageGroup),
            dietaryPreferencesJson: Value(
              _encodeStringList(dietaryPreferences),
            ),
            allergensJson: Value(_encodeStringList(allergens)),
            dislikedIngredientsJson: Value(
              _encodeStringList(dislikedIngredients),
            ),
            notes: Value(notes),
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
    bool updatePantry = false,
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
    await (_db.update(_db.mealPlans)..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.date.equals(today) &
              tbl.recipeId.equals(recipe.id) &
              tbl.mealType.equals(recipe.mealType),
        ))
        .write(
          MealPlansCompanion(
            status: const Value('prepared'),
            updatedAt: Value(now),
          ),
        );
    if (updatePantry) {
      await _subtractRecipeFromPantry(
        recipe,
        servings: servings ?? recipe.servings,
      );
    }
    await _reconcileNotifications(
      NotificationReconciliationReason.mealPlanChanged,
    );
  }

  Future<void> addRecipeToShoppingList(
    NigerianRecipe recipe, {
    int? servings,
    String sourceType = 'recipe',
  }) async {
    final pantry = await _pantrySnapshot();
    final requirements = const household.HouseholdMealPlanner()
        .generateShoppingList(
          plannedMeals: [
            household.PlannedMealSlot(
              date: ref.read(localTodayProvider),
              mealType: recipe.mealType,
              recipe: recipe,
              servings: servings ?? recipe.servings,
            ),
          ],
          pantry: pantry,
          sourceType: sourceType,
        );
    await _upsertShoppingRequirements(requirements, recipe.title);
  }

  Future<void> generateShoppingListFromWeek(DateTime weekStart) async {
    final start = normalizeDate(weekStart);
    final end = start.add(const Duration(days: 7));
    final rows =
        await (_db.select(_db.mealPlans)..where(
              (tbl) =>
                  tbl.deletedAt.isNull() &
                  tbl.date.isBiggerOrEqualValue(start) &
                  tbl.date.isSmallerThanValue(end),
            ))
            .get();
    final slots = <household.PlannedMealSlot>[];
    for (final row in rows) {
      final recipe = _recipeForMealPlan(row);
      if (recipe == null) continue;
      slots.add(
        household.PlannedMealSlot(
          date: row.date,
          mealType: row.mealType,
          recipe: recipe,
          servings: row.servings,
          status: row.status,
        ),
      );
    }
    final requirements = const household.HouseholdMealPlanner()
        .generateShoppingList(
          plannedMeals: slots,
          pantry: await _pantrySnapshot(),
        );
    await _upsertShoppingRequirements(requirements, 'Weekly meal plan');
  }

  Future<void> applyGeneratedWeek() async {
    final summary = ref.read(weeklyFamilyMealPlanProvider);
    final now = DateTime.now();
    await _db.transaction(() async {
      for (final slot in summary.slots) {
        final existing =
            await (_db.select(_db.mealPlans)
                  ..where(
                    (tbl) =>
                        tbl.deletedAt.isNull() &
                        tbl.date.equals(normalizeDate(slot.date)) &
                        tbl.mealType.equals(slot.mealType),
                  )
                  ..limit(1))
                .getSingleOrNull();
        final companion = MealPlansCompanion(
          date: Value(normalizeDate(slot.date)),
          mealId: Value(slot.recipe.title.hashCode.abs()),
          recipeId: Value(slot.recipe.id),
          recipeTitle: Value(slot.recipe.title),
          mealType: Value(slot.mealType),
          servings: Value(slot.servings),
          selectedMemberIdsJson: Value(
            _encodeStringList(slot.selectedMemberIds),
          ),
          notes: Value(slot.notes.isEmpty ? null : slot.notes),
          status: Value(slot.status),
          updatedAt: Value(now),
        );
        if (existing == null) {
          await _db
              .into(_db.mealPlans)
              .insert(
                companion.copyWith(
                  uuid: Value(localUuid('meal-plan')),
                  createdAt: Value(now),
                ),
              );
        } else {
          await (_db.update(
            _db.mealPlans,
          )..where((tbl) => tbl.id.equals(existing.id))).write(companion);
        }
      }
    });
    await _reconcileNotifications(
      NotificationReconciliationReason.mealPlanChanged,
    );
  }

  Future<void> finishShoppingTrip({bool addPurchasedToPantry = true}) async {
    final now = DateTime.now();
    final purchased =
        await (_db.select(_db.shoppingItems)..where(
              (tbl) => tbl.deletedAt.isNull() & tbl.isPurchased.equals(true),
            ))
            .get();
    await _db.transaction(() async {
      if (addPurchasedToPantry) {
        for (final item in purchased) {
          await _mergePantryItem(
            name: item.itemName,
            ingredientId: item.ingredientId,
            quantity:
                item.requiredQuantity ?? _parseQuantity(item.quantity) ?? 1,
            unit: item.unit ?? 'pieces',
            category: item.category,
            purchaseDate: now,
          );
        }
      }
      for (final item in purchased) {
        await (_db.update(
          _db.shoppingItems,
        )..where((tbl) => tbl.id.equals(item.id))).write(
          ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<void> _upsertShoppingRequirements(
    List<household.ShoppingRequirement> requirements,
    String sourceMealTitle,
  ) async {
    final now = DateTime.now();
    for (final item in requirements) {
      final existing =
          await (_db.select(_db.shoppingItems)
                ..where(
                  (tbl) =>
                      tbl.deletedAt.isNull() &
                      tbl.isPurchased.equals(false) &
                      tbl.ingredientId.equals(item.ingredientId) &
                      tbl.unit.equals(item.unit),
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
                ingredientId: Value(item.ingredientId),
                itemName: item.displayName,
                quantity: Value(item.quantityLabel),
                requiredQuantity: Value(item.quantity),
                unit: Value(item.unit),
                category: Value(item.category),
                sourceMealTitle: Value(sourceMealTitle),
                sourceType: Value(item.sourceType),
                sourceIdsJson: Value(_encodeStringList(item.sourceRecipeIds)),
              ),
            );
      } else {
        final nextQuantity =
            (existing.requiredQuantity ??
                _parseQuantity(existing.quantity) ??
                0) +
            item.quantity;
        await (_db.update(
          _db.shoppingItems,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          ShoppingItemsCompanion(
            quantity: Value(_formatQuantity(nextQuantity)),
            requiredQuantity: Value(nextQuantity),
            sourceMealTitle: Value(
              existing.sourceMealTitle == null ||
                      existing.sourceMealTitle == sourceMealTitle
                  ? sourceMealTitle
                  : '${existing.sourceMealTitle}, $sourceMealTitle',
            ),
            sourceType: Value(item.sourceType),
            updatedAt: Value(now),
          ),
        );
      }
    }
  }

  Future<List<household.PantryInventoryItem>> _pantrySnapshot() async {
    final rows = await (_db.select(
      _db.pantryItems,
    )..where((tbl) => tbl.deletedAt.isNull())).get();
    return rows
        .map(
          (row) => household.PantryInventoryItem(
            ingredientId: row.ingredientId.isEmpty
                ? household.IngredientNormalizer.ingredientId(row.name)
                : row.ingredientId,
            displayName: row.name,
            quantity: row.quantity,
            unit: row.unit,
            category: row.category,
            expiryDate: row.expiryDate,
            minimumStockLevel: row.minimumStockLevel,
            storageLocation: row.storageLocation,
            opened: row.opened,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _mergePantryItem({
    required String name,
    required String ingredientId,
    required double quantity,
    required String unit,
    bool lowStock = false,
    String category = 'General',
    DateTime? expiryDate,
    DateTime? purchaseDate,
    double? minimumStockLevel,
    String storageLocation = 'Pantry',
    bool opened = false,
    String? notes,
  }) async {
    final now = DateTime.now();
    final normalizedId = ingredientId.isEmpty
        ? household.IngredientNormalizer.ingredientId(name)
        : ingredientId;
    final normalizedUnit = household.IngredientNormalizer.canonicalUnit(unit);
    final existing =
        await (_db.select(_db.pantryItems)
              ..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.ingredientId.equals(normalizedId) &
                    tbl.unit.equals(normalizedUnit),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.pantryItems)
          .insert(
            PantryItemsCompanion.insert(
              uuid: localUuid('pantry'),
              createdAt: now,
              updatedAt: now,
              ingredientId: Value(normalizedId),
              name: household.IngredientNormalizer.displayName(name),
              quantity: quantity,
              unit: normalizedUnit,
              category: Value(category),
              lowStock: Value(
                minimumStockLevel == null
                    ? lowStock
                    : quantity < minimumStockLevel,
              ),
              expiryDate: Value(expiryDate),
              purchaseDate: Value(purchaseDate),
              minimumStockLevel: Value(minimumStockLevel),
              storageLocation: Value(storageLocation),
              opened: Value(opened),
              notes: Value(notes),
            ),
          );
    } else {
      final nextQuantity = existing.quantity + quantity;
      await (_db.update(
        _db.pantryItems,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        PantryItemsCompanion(
          name: Value(existing.name),
          quantity: Value(nextQuantity),
          category: Value(category),
          lowStock: Value(
            minimumStockLevel == null
                ? lowStock
                : nextQuantity < minimumStockLevel,
          ),
          expiryDate: Value(expiryDate ?? existing.expiryDate),
          purchaseDate: Value(purchaseDate ?? existing.purchaseDate),
          minimumStockLevel: Value(
            minimumStockLevel ?? existing.minimumStockLevel,
          ),
          storageLocation: Value(storageLocation),
          opened: Value(opened || existing.opened),
          notes: Value(notes ?? existing.notes),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> _subtractRecipeFromPantry(
    NigerianRecipe recipe, {
    required int servings,
  }) async {
    final scale = servings / recipe.servings;
    for (final ingredient in recipe.ingredients) {
      final id = household.IngredientNormalizer.ingredientId(ingredient.name);
      final unit = household.IngredientNormalizer.canonicalUnit(
        ingredient.unit,
      );
      final required = household.IngredientNormalizer.convert(
        ingredient.quantity * scale,
        ingredient.unit,
        unit,
      );
      final existing =
          await (_db.select(_db.pantryItems)
                ..where(
                  (tbl) =>
                      tbl.deletedAt.isNull() &
                      tbl.ingredientId.equals(id) &
                      tbl.unit.equals(unit),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing == null) continue;
      final next = (existing.quantity - required).clamp(0, 999999).toDouble();
      await (_db.update(
        _db.pantryItems,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        PantryItemsCompanion(
          quantity: Value(next),
          lowStock: Value(
            existing.minimumStockLevel == null
                ? existing.lowStock
                : next < existing.minimumStockLevel!,
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  NigerianRecipe? _recipeForMealPlan(MealPlan row) {
    if (row.recipeId.isNotEmpty) {
      return NigerianRecipeDatabase.recipes
          .where((recipe) => recipe.id == row.recipeId)
          .firstOrNull;
    }
    return NigerianRecipeDatabase.recipes
        .where((recipe) => recipe.title.hashCode.abs() == row.mealId)
        .firstOrNull;
  }

  Future<void> addPantryItem({
    required String name,
    double quantity = 1,
    String unit = 'item',
    bool lowStock = false,
    String? category,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    double? minimumStockLevel,
    String storageLocation = 'Pantry',
    bool opened = false,
    String? notes,
  }) async {
    if (name.trim().isEmpty) return;
    await _mergePantryItem(
      name: name,
      ingredientId: household.IngredientNormalizer.ingredientId(name),
      quantity: quantity,
      unit: unit,
      lowStock: lowStock,
      category: category ?? 'General',
      expiryDate: expiryDate,
      purchaseDate: purchaseDate,
      minimumStockLevel: minimumStockLevel,
      storageLocation: storageLocation,
      opened: opened,
      notes: notes,
    );
  }

  Future<void> adjustPantryItem(PantryItem item, double delta) async {
    final next = (item.quantity + delta).clamp(0, 999999).toDouble();
    await (_db.update(
      _db.pantryItems,
    )..where((tbl) => tbl.id.equals(item.id))).write(
      PantryItemsCompanion(
        quantity: Value(next),
        lowStock: Value(
          item.minimumStockLevel == null
              ? item.lowStock
              : next < item.minimumStockLevel!,
        ),
        updatedAt: Value(DateTime.now()),
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

List<String> _decodeStringList(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

String _encodeStringList(List<String> values) {
  return jsonEncode(
    values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(),
  );
}

household.FamilyAgeGroup _ageGroup(String value) {
  return switch (value.toLowerCase()) {
    'teen' => household.FamilyAgeGroup.teen,
    'child' => household.FamilyAgeGroup.child,
    _ => household.FamilyAgeGroup.adult,
  };
}
