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
import 'package:quevaa/features/wellness/application/wellness_workspace_provider.dart';

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(NotificationReconciliationReason.manualRefresh);
    registerFallbackValue(const NotificationSourceSnapshot());
  });

  group('Meals catalogue quality', () {
    test('bundled Nigerian recipe catalogue is complete and structured', () {
      final recipes = NigerianRecipeDatabase.recipes;
      expect(recipes.length, greaterThanOrEqualTo(60));
      expect(
        recipes.where((recipe) => recipe.mealType == 'Breakfast').length,
        greaterThanOrEqualTo(15),
      );
      expect(
        recipes.where((recipe) => recipe.mealType == 'Lunch').length,
        greaterThanOrEqualTo(20),
      );
      expect(
        recipes.where((recipe) => recipe.mealType == 'Dinner').length,
        greaterThanOrEqualTo(20),
      );
      expect(
        recipes.where((recipe) => recipe.mealType == 'Snack').length,
        greaterThanOrEqualTo(10),
      );

      final ids = <String>{};
      for (final recipe in recipes) {
        expect(ids.add(recipe.id), isTrue, reason: recipe.id);
        expect(recipe.title.trim(), isNotEmpty);
        expect([
          'Breakfast',
          'Lunch',
          'Dinner',
          'Snack',
        ], contains(recipe.mealType));
        expect(recipe.servings, greaterThan(0));
        expect(recipe.ingredients.length, greaterThanOrEqualTo(2));
        expect(recipe.instructions.length, greaterThanOrEqualTo(2));
        expect(recipe.totalMinutes, recipe.prepMinutes + recipe.cookMinutes);
        expect(recipe.cyclePhaseTags, isNotEmpty);
        expect(recipe.nutritionTags, isNotEmpty);
        for (final allergen in recipe.allergenTags) {
          expect(
            ['peanut', 'fish', 'egg', 'dairy', 'shellfish'],
            contains(allergen),
            reason: '${recipe.title}: $allergen',
          );
        }
      }
    });

    test('recipe copy avoids unsupported health claims', () {
      final joined = NigerianRecipeDatabase.recipes
          .map(
            (recipe) =>
                '${recipe.title} ${recipe.description} ${recipe.instructions.map((step) => step.instruction).join(' ')}',
          )
          .join(' ')
          .toLowerCase();
      for (final claim in const [
        'boosts fertility',
        'balances hormones',
        'prevents pms',
        'cures cramps',
        'fixes anaemia',
        'detoxes',
        'guarantees conception',
      ]) {
        expect(joined, isNot(contains(claim)));
      }
    });
  });

  group('Meals recommendation engine', () {
    test('respects cycle, dietary, allergen, and prep-time filters', () {
      for (final phase in const [
        'Menstrual',
        'Follicular',
        'Estimated Ovulatory Window',
        'Luteal',
      ]) {
        final meals = NigerianRecipeDatabase.recommendDailyMeals(
          date: DateTime(2026, 8, 14),
          cyclePhase: phase,
          dietaryPattern: 'Vegetarian, No groundnuts/peanuts, No fish',
          prepTimePreference: '30 minutes or less',
          excludedAllergens: const ['peanut', 'fish'],
        );
        expect(
          meals.keys,
          containsAll(['Breakfast', 'Lunch', 'Dinner', 'Snack']),
        );
        for (final entry in meals.entries) {
          final recipe = entry.value;
          expect(recipe.mealType, entry.key);
          expect(recipe.isVegetarian, isTrue);
          expect(recipe.allergenTags, isNot(contains('peanut')));
          expect(recipe.allergenTags, isNot(contains('fish')));
          expect(recipe.totalMinutes, lessThanOrEqualTo(45));
        }
      }
    });

    test('is stable for the same day and rotates across a week', () {
      final base = DateTime(2026, 8, 14);
      final first = NigerianRecipeDatabase.recommendDailyMeals(
        date: base,
        cyclePhase: 'Follicular',
      );
      final second = NigerianRecipeDatabase.recommendDailyMeals(
        date: base,
        cyclePhase: 'Follicular',
      );
      expect(
        second.map((key, value) => MapEntry(key, value.id)),
        first.map((key, value) => MapEntry(key, value.id)),
      );

      final signatures = <String>{};
      for (var i = 0; i < 7; i++) {
        final meals = NigerianRecipeDatabase.recommendDailyMeals(
          date: base.add(Duration(days: i)),
          cyclePhase: 'Follicular',
        );
        signatures.add(meals.values.map((recipe) => recipe.id).join('|'));
      }
      expect(signatures.length, greaterThan(1));
    });

    test('show another chooses the next valid ranked meal', () {
      final first = NigerianRecipeDatabase.recommend(
        MealRecommendationInput(
          date: DateTime(2026, 8, 14),
          cyclePhase: 'Luteal',
          mealType: 'Lunch',
        ),
      );
      final another = NigerianRecipeDatabase.recommend(
        MealRecommendationInput(
          date: DateTime(2026, 8, 14),
          cyclePhase: 'Luteal',
          mealType: 'Lunch',
          alternativeOffset: 1,
        ),
      );
      expect(another.id, isNot(first.id));
      expect(another.mealType, 'Lunch');
      if (first.dishFamily == 'moi_moi') {
        expect(another.dishFamily, isNot('moi_moi'));
      }
    });

    test(
      'same-day meals avoid repeating dish families where alternatives exist',
      () {
        final meals = NigerianRecipeDatabase.recommendDailyMeals(
          date: DateTime(2026, 8, 14),
          cyclePhase: 'Menstrual',
        );
        final families = meals.values
            .map((recipe) => recipe.dishFamily)
            .toList();

        expect(families.toSet().length, families.length);
        expect(
          families.where((family) => family == 'moi_moi').length,
          lessThanOrEqualTo(1),
        );
      },
    );

    test(
      'fourteen day unrestricted recommendations show real family variety',
      () {
        final metrics = _mealDiversityMetrics(
          start: DateTime(2026, 8, 8),
          days: 14,
          cyclePhase: 'Menstrual',
        );

        expect(metrics.uniqueRecipes, greaterThanOrEqualTo(28));
        expect(metrics.uniqueFamilies, greaterThanOrEqualTo(12));
        expect(metrics.moiMoiCount, lessThanOrEqualTo(6));
        expect(metrics.maxSameFamilyStreak, lessThanOrEqualTo(1));
      },
    );

    test('vegetarian recommendations stay diverse and allergen-safe', () {
      final metrics = _mealDiversityMetrics(
        start: DateTime(2026, 8, 8),
        days: 14,
        cyclePhase: 'Luteal',
        dietaryPattern: 'Vegetarian',
      );

      expect(metrics.uniqueRecipes, greaterThanOrEqualTo(20));
      expect(metrics.uniqueFamilies, greaterThanOrEqualTo(10));
      expect(metrics.moiMoiCount, lessThanOrEqualTo(8));
      expect(metrics.maxSameFamilyStreak, lessThanOrEqualTo(1));
      expect(metrics.recipes.every((recipe) => recipe.isVegetarian), isTrue);
    });

    test('recently prepared Moi Moi penalizes the whole dish family', () {
      final recentMoiMoi = NigerianRecipeDatabase.recipes.firstWhere(
        (recipe) => recipe.dishFamily == 'moi_moi',
      );
      final lunch = NigerianRecipeDatabase.recommend(
        MealRecommendationInput(
          date: DateTime(2026, 8, 14),
          cyclePhase: 'Menstrual',
          mealType: 'Lunch',
          recentlyPreparedMealIds: {recentMoiMoi.id},
          recentDishFamilies: {'moi_moi'},
        ),
      );

      expect(lunch.dishFamily, isNot('moi_moi'));
    });

    test('pantry match does not override dish-family diversity', () {
      final meals = NigerianRecipeDatabase.recommendDailyMeals(
        date: DateTime(2026, 8, 14),
        cyclePhase: 'Menstrual',
        pantryItems: const ['moi moi', 'beans', 'rice', 'tomatoes'],
      );
      final families = meals.values.map((recipe) => recipe.dishFamily).toList();

      expect(
        families.where((family) => family == 'moi_moi').length,
        lessThanOrEqualTo(1),
      );
      expect(families.toSet().length, greaterThanOrEqualTo(3));
    });
  });

  group('Meals persistence', () {
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
          localTodayProvider.overrideWithValue(DateTime(2026, 8, 14)),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'save persists across provider restart and unsave removes it',
      () async {
        final recipe = NigerianRecipeDatabase.recipes.first;
        final controller = container.read(
          wellnessWorkspaceControllerProvider.notifier,
        );

        await controller.toggleSavedMeal(recipe);
        expect(await db.select(db.savedMeals).get(), hasLength(1));

        container.dispose();
        container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            localTodayProvider.overrideWithValue(DateTime(2026, 8, 14)),
            notificationSchedulerProvider.overrideWithValue(scheduler),
          ],
        );
        final saved = await container.read(savedMealsStreamProvider.future);
        expect(saved.single.mealId, recipe.id);

        await container
            .read(wellnessWorkspaceControllerProvider.notifier)
            .toggleSavedMeal(recipe);
        final active = await (db.select(
          db.savedMeals,
        )..where((tbl) => tbl.deletedAt.isNull())).get();
        expect(active, isEmpty);
      },
    );

    test('prepared entries are date-specific and idempotent', () async {
      final recipe = NigerianRecipeDatabase.recipes.firstWhere(
        (item) => item.mealType == 'Lunch',
      );
      final controller = container.read(
        wellnessWorkspaceControllerProvider.notifier,
      );

      await controller.markMealPrepared(recipe);
      await controller.markMealPrepared(recipe);
      final todayEntries = await db.select(db.mealPreparationEntries).get();
      expect(todayEntries, hasLength(1));
      expect(todayEntries.single.mealId, recipe.id);

      container.dispose();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          localTodayProvider.overrideWithValue(DateTime(2026, 8, 15)),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      await container
          .read(wellnessWorkspaceControllerProvider.notifier)
          .markMealPrepared(recipe);
      expect(await db.select(db.mealPreparationEntries).get(), hasLength(2));
    });

    test(
      'shopping list receives and combines structured ingredients',
      () async {
        final recipes = NigerianRecipeDatabase.recipes
            .where(
              (recipe) =>
                  recipe.ingredients.any((item) => item.name == 'onion'),
            )
            .take(2)
            .toList();
        final controller = container.read(
          wellnessWorkspaceControllerProvider.notifier,
        );

        await controller.addRecipeToShoppingList(recipes.first);
        await controller.addRecipeToShoppingList(recipes.last);

        final onions = await (db.select(
          db.shoppingItems,
        )..where((tbl) => tbl.ingredientId.equals('onion'))).get();
        expect(onions, hasLength(1));
        expect(onions.single.requiredQuantity, greaterThan(1));
      },
    );
  });
}

class _MealDiversityMetrics {
  final List<NigerianRecipe> recipes;
  final int uniqueRecipes;
  final int uniqueFamilies;
  final int moiMoiCount;
  final int maxSameFamilyStreak;

  const _MealDiversityMetrics({
    required this.recipes,
    required this.uniqueRecipes,
    required this.uniqueFamilies,
    required this.moiMoiCount,
    required this.maxSameFamilyStreak,
  });
}

_MealDiversityMetrics _mealDiversityMetrics({
  required DateTime start,
  required int days,
  required String cyclePhase,
  String? dietaryPattern,
}) {
  final all = <NigerianRecipe>[];
  String? previousFamily;
  var currentStreak = 0;
  var maxStreak = 0;
  for (var day = 0; day < days; day++) {
    final recent = all.reversed.take(12).map((recipe) => recipe.id).toSet();
    final meals = NigerianRecipeDatabase.recommendDailyMeals(
      date: start.add(Duration(days: day)),
      cyclePhase: cyclePhase,
      dietaryPattern: dietaryPattern,
      prepTimePreference: '45 minutes or less',
      recentlyPreparedMealIds: recent,
    );
    for (final recipe in meals.values) {
      all.add(recipe);
      if (recipe.dishFamily == previousFamily) {
        currentStreak++;
      } else {
        currentStreak = 1;
        previousFamily = recipe.dishFamily;
      }
      if (currentStreak > maxStreak) maxStreak = currentStreak;
    }
  }
  return _MealDiversityMetrics(
    recipes: all,
    uniqueRecipes: all.map((recipe) => recipe.id).toSet().length,
    uniqueFamilies: all.map((recipe) => recipe.dishFamily).toSet().length,
    moiMoiCount: all.where((recipe) => recipe.dishFamily == 'moi_moi').length,
    maxSameFamilyStreak: maxStreak,
  );
}
