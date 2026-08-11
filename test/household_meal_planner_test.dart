import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/providers/database_provider.dart';
import 'package:quevaa/features/cycle/application/cycle_workspace_provider.dart';
import 'package:quevaa/features/notifications/application/notification_preferences_provider.dart';
import 'package:quevaa/features/notifications/domain/services/notification_scheduler.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';
import 'package:quevaa/features/nutrition/data/nigerian_recipe_database.dart';
import 'package:quevaa/features/recommendations/application/daily_quevaa_plan_provider.dart';
import 'package:quevaa/features/wellness/application/wellness_workspace_provider.dart';
import 'package:quevaa/features/wellness/domain/household_meal_planner.dart';

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(NotificationReconciliationReason.mealPlanChanged);
    registerFallbackValue(const NotificationSourceSnapshot());
  });

  group('Household meal planning engine', () {
    test(
      'subtracts pantry quantities and safely aggregates compatible units',
      () {
        const planner = HouseholdMealPlanner();
        final riceMeal = _recipe(
          id: 'rice-a',
          title: 'Family Rice',
          ingredients: const [
            MealIngredient(
              name: 'Rice',
              quantity: 2000,
              unit: 'g',
              category: 'Grains & Staples',
            ),
          ],
        );
        final bigRiceMeal = _recipe(
          id: 'rice-b',
          title: 'Big Family Rice',
          ingredients: const [
            MealIngredient(
              name: 'Rice',
              quantity: 7,
              unit: 'kg',
              category: 'Grains & Staples',
            ),
          ],
        );

        final covered = planner.generateShoppingList(
          plannedMeals: [
            PlannedMealSlot(
              date: DateTime(2026, 8, 10),
              mealType: 'Dinner',
              recipe: riceMeal,
              servings: 4,
            ),
          ],
          pantry: const [
            PantryInventoryItem(
              ingredientId: 'rice',
              displayName: 'Rice',
              quantity: 5,
              unit: 'kg',
            ),
          ],
        );
        expect(covered.where((item) => item.ingredientId == 'rice'), isEmpty);

        final missing = planner.generateShoppingList(
          plannedMeals: [
            PlannedMealSlot(
              date: DateTime(2026, 8, 10),
              mealType: 'Dinner',
              recipe: bigRiceMeal,
              servings: 4,
            ),
          ],
          pantry: const [
            PantryInventoryItem(
              ingredientId: 'rice',
              displayName: 'Rice',
              quantity: 5,
              unit: 'kg',
            ),
          ],
        );
        expect(missing.single.ingredientId, 'rice');
        expect(missing.single.quantity, 2);
        expect(missing.single.unit, 'kg');
      },
    );

    test('aggregates duplicate onions after pantry subtraction', () {
      const planner = HouseholdMealPlanner();
      final recipes = [
        _recipe(
          id: 'a',
          title: 'A',
          ingredients: const [
            MealIngredient(name: 'Onions', quantity: 2, unit: 'pieces'),
          ],
        ),
        _recipe(
          id: 'b',
          title: 'B',
          ingredients: const [
            MealIngredient(name: 'Red onion', quantity: 3, unit: 'pieces'),
          ],
        ),
        _recipe(
          id: 'c',
          title: 'C',
          ingredients: const [
            MealIngredient(name: 'Onion', quantity: 1, unit: 'pieces'),
          ],
        ),
      ];

      final shopping = planner.generateShoppingList(
        plannedMeals: [
          for (final recipe in recipes)
            PlannedMealSlot(
              date: DateTime(2026, 8, 10),
              mealType: 'Dinner',
              recipe: recipe,
              servings: 4,
            ),
        ],
        pantry: const [
          PantryInventoryItem(
            ingredientId: 'onion',
            displayName: 'Onion',
            quantity: 2,
            unit: 'pieces',
          ),
        ],
      );

      expect(shopping.single.ingredientId, 'onion');
      expect(shopping.single.quantity, 4);
    });

    test('generates allergen-safe weekly family plan with serving scaling', () {
      const planner = HouseholdMealPlanner();
      final week = planner.generateWeek(
        weekStart: DateTime(2026, 8, 10),
        household: const HouseholdProfileModel(
          adults: 2,
          children: 2,
          defaultServings: 4,
          allergens: ['peanut'],
          weekdayPrepLimitMinutes: 45,
        ),
        members: const [
          FamilyMemberModel(
            id: 'child-1',
            name: 'Child',
            ageGroup: FamilyAgeGroup.child,
            allergens: ['peanut'],
          ),
        ],
        pantry: const [
          PantryInventoryItem(
            ingredientId: 'rice',
            displayName: 'Rice',
            quantity: 5,
            unit: 'kg',
          ),
          PantryInventoryItem(
            ingredientId: 'tomato',
            displayName: 'Tomato',
            quantity: 8,
            unit: 'pieces',
          ),
        ],
        cyclePhase: 'Menstrual',
      );

      expect(week.slots, isNotEmpty);
      expect(week.slots.every((slot) => slot.servings == 4), isTrue);
      expect(
        week.slots.expand((slot) => slot.recipe.allergenTags),
        isNot(contains('peanut')),
      );
      expect(
        week.slots
            .where((slot) => slot.mealType == 'Dinner')
            .map((slot) => slot.recipe.id)
            .toSet()
            .length,
        greaterThan(1),
      );
    });

    test(
      'monthly plan separates shelf-stable staples from weekly fresh windows',
      () {
        const planner = HouseholdMealPlanner();
        final month = planner.generateMonth(
          month: DateTime(2026, 8),
          household: const HouseholdProfileModel(defaultServings: 4),
          members: const [],
          pantry: const [],
        );

        expect(month.weeks, hasLength(5));
        expect(month.plannedMeals, greaterThan(50));
        expect(
          month.weeklyFreshWindows.values.expand((items) => items),
          isNotEmpty,
        );
        expect(
          month.monthlyStaples.every(
            (item) =>
                item.category != 'Produce' && item.category != 'Meat/Fish',
          ),
          isTrue,
        );
      },
    );
  });

  group('Household planner persistence', () {
    late AppDatabase db;
    late ProviderContainer container;
    late MockNotificationScheduler scheduler;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      scheduler = MockNotificationScheduler();
      when(
        () => scheduler.reconcileNotifications(
          any(),
          snapshot: any(named: 'snapshot'),
        ),
      ).thenAnswer(
        (_) async => const NotificationReconciliationResult(
          reason: NotificationReconciliationReason.mealPlanChanged,
          desiredCount: 0,
          scheduledCount: 0,
          cancelledCount: 0,
          unchangedCount: 0,
          permissionGranted: true,
          timezone: 'UTC',
        ),
      );
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          localTodayProvider.overrideWithValue(DateTime(2026, 8, 10)),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'schema v8 tables exist and pantry quantities merge across restart',
      () async {
        expect(db.schemaVersion, 8);
        final controller = container.read(
          wellnessWorkspaceControllerProvider.notifier,
        );

        await controller.addPantryItem(name: 'Rice', quantity: 5, unit: 'kg');
        container.dispose();
        container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            localTodayProvider.overrideWithValue(DateTime(2026, 8, 10)),
            notificationSchedulerProvider.overrideWithValue(scheduler),
          ],
        );

        final rice = (await db.select(db.pantryItems).get()).single;
        expect(rice.ingredientId, 'rice');
        expect(rice.quantity, 5);

        await container
            .read(wellnessWorkspaceControllerProvider.notifier)
            .adjustPantryItem(rice, -2);
        await container
            .read(wellnessWorkspaceControllerProvider.notifier)
            .addPantryItem(name: 'Rice', quantity: 1, unit: 'kg');
        final rows = await db.select(db.pantryItems).get();
        expect(rows, hasLength(1));
        expect(rows.single.quantity, 4);
      },
    );

    test(
      'generated week persists and can create pantry-subtracted shopping',
      () async {
        final controller = container.read(
          wellnessWorkspaceControllerProvider.notifier,
        );
        await controller.saveHouseholdProfile(
          adults: 2,
          children: 2,
          defaultServings: 4,
          allergens: ['peanut'],
        );
        await controller.addPantryItem(name: 'Rice', quantity: 5, unit: 'kg');
        await container.read(householdProfileStreamProvider.future);
        await controller.applyGeneratedWeek();
        await controller.generateShoppingListFromWeek(DateTime(2026, 8, 10));

        final plans = await db.select(db.mealPlans).get();
        final shopping = await db.select(db.shoppingItems).get();
        expect(plans.length, 21);
        expect(plans.every((plan) => plan.recipeId.isNotEmpty), isTrue);
        expect(plans.every((plan) => plan.servings == 4), isTrue);
        expect(shopping, isNotEmpty);
        expect(shopping.every((item) => item.ingredientId.isNotEmpty), isTrue);
      },
    );

    test(
      'shopping trip and prepared meal can update pantry idempotently',
      () async {
        final controller = container.read(
          wellnessWorkspaceControllerProvider.notifier,
        );
        await controller.addPantryItem(name: 'Rice', quantity: 5, unit: 'kg');
        await controller.addPantryItem(
          name: 'Tomatoes',
          quantity: 4,
          unit: 'pieces',
        );
        final recipe = _recipe(
          id: 'prepared-rice',
          title: 'Prepared Rice',
          ingredients: const [
            MealIngredient(
              name: 'Rice',
              quantity: 2,
              unit: 'kg',
              category: 'Grains & Staples',
            ),
            MealIngredient(
              name: 'Tomatoes',
              quantity: 2,
              unit: 'pieces',
              category: 'Produce',
            ),
          ],
        );

        await controller.markMealPrepared(
          recipe,
          servings: 4,
          updatePantry: true,
        );
        await controller.markMealPrepared(
          recipe,
          servings: 4,
          updatePantry: false,
        );
        final prepared = await db.select(db.mealPreparationEntries).get();
        expect(prepared, hasLength(1));
        final pantryAfterPrep = await db.select(db.pantryItems).get();
        expect(
          pantryAfterPrep
              .firstWhere((item) => item.ingredientId == 'rice')
              .quantity,
          3,
        );

        await controller.addRecipeToShoppingList(recipe);
        final shoppingBefore = await db.select(db.shoppingItems).get();
        for (final item in shoppingBefore) {
          await controller.toggleShoppingItem(item);
        }
        await controller.finishShoppingTrip();
        final shoppingAfter = await (db.select(
          db.shoppingItems,
        )..where((tbl) => tbl.deletedAt.isNull())).get();
        expect(shoppingAfter, isEmpty);
        expect(
          (await db.select(db.pantryItems).get())
              .firstWhere((item) => item.ingredientId == 'tomato')
              .quantity,
          greaterThanOrEqualTo(2),
        );
      },
    );

    test(
      'DailyQuevaaPlan uses scheduled family meal before auto recommendation',
      () async {
        final planned = NigerianRecipeDatabase.recipes.firstWhere(
          (recipe) => recipe.mealType == 'Dinner',
        );
        final now = DateTime(2026, 8, 10);
        await db
            .into(db.mealPlans)
            .insert(
              MealPlansCompanion.insert(
                uuid: 'planned-dinner',
                createdAt: now,
                updatedAt: now,
                date: now,
                mealId: planned.title.hashCode.abs(),
                recipeId: Value(planned.id),
                recipeTitle: Value(planned.title),
                mealType: 'Dinner',
                servings: const Value(4),
              ),
            );

        await container.read(plannedMealsForTodayProvider.future);
        final daily = container.read(dailyQuevaaPlanProvider);
        expect(daily.meals['Dinner']?.id, planned.id);
      },
    );
  });
}

NigerianRecipe _recipe({
  required String id,
  required String title,
  required List<MealIngredient> ingredients,
}) {
  return NigerianRecipe(
    id: id,
    title: title,
    mealType: 'Dinner',
    targetPhase: 'all',
    description: 'Family planning fixture.',
    keyNutrients: 'Fixture nutrients',
    region: 'Test',
    prepMinutes: 10,
    cookMinutes: 20,
    servings: 4,
    ingredients: ingredients,
    instructions: const [
      RecipeStep(
        stepNumber: 1,
        title: 'Prep',
        instruction: 'Prep.',
        estimatedMinutes: 10,
      ),
      RecipeStep(
        stepNumber: 2,
        title: 'Cook',
        instruction: 'Cook.',
        estimatedMinutes: 20,
      ),
    ],
    nutritionTags: const ['family'],
    cyclePhaseTags: const ['all'],
    dietaryTags: const ['Vegetarian'],
    allergenTags: const [],
    proteinSources: const [],
    healthyFatSources: const [],
    ironRich: false,
    highFibre: false,
    complexCarbohydrate: true,
    substitutions: const [],
    servingSuggestions: const [],
  );
}
