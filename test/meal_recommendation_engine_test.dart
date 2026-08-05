import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/nutrition/domain/entities/recipe_entity.dart';
import 'package:quevaa/features/nutrition/domain/meal_recommendation_engine.dart';

void main() {
  group('Phase 8: Meal Recommendation Engine Unit Tests', () {
    final sampleRecipes = [
      const RecipeEntity(
        id: '1',
        name: 'Groundnut Soup & Semo',
        region: 'Hausa/Northern',
        mealType: 'Dinner',
        ingredients: ['Peanuts', 'Beef', 'Palm Oil'],
        ingredientQuantities: {'Peanuts': '2 cups', 'Beef': '500g'},
        keyNutrients: 'Protein & Healthy Fats',
        allergens: ['Peanuts'],
      ),
      const RecipeEntity(
        id: '2',
        name: 'Ugu & Unripe Plantain Porridge',
        region: 'Igbo',
        mealType: 'Lunch',
        ingredients: ['Ugu Leaves', 'Unripe Plantain', 'Dry Fish'],
        ingredientQuantities: {
          'Ugu Leaves': '1 bunch',
          'Unripe Plantain': '3 fingers',
        },
        keyNutrients: 'Iron & Magnesium',
        allergens: ['Fish'],
      ),
    ];

    test(
      'Hard Allergen Exclusion: Excludes peanut meals when user has peanut allergy',
      () {
        final safeMeals = MealRecommendationEngine.recommend(
          allRecipes: sampleRecipes,
          userAllergens: ['Peanuts'],
        );

        expect(safeMeals.length, 1);
        expect(safeMeals.first.name, 'Ugu & Unripe Plantain Porridge');
      },
    );

    test(
      'Smart Shopping List: Combines duplicate ingredients across planned meals',
      () {
        final shoppingList = MealRecommendationEngine.generateSmartShoppingList(
          [
            const RecipeEntity(
              id: '1',
              name: 'Meal A',
              region: 'Yoruba',
              mealType: 'Lunch',
              ingredients: ['Ugu Leaves'],
              ingredientQuantities: {'Ugu Leaves': '1 bunch'},
              keyNutrients: 'Iron',
            ),
            const RecipeEntity(
              id: '2',
              name: 'Meal B',
              region: 'Igbo',
              mealType: 'Dinner',
              ingredients: ['Ugu Leaves'],
              ingredientQuantities: {'Ugu Leaves': '2 bunches'},
              keyNutrients: 'Iron',
            ),
          ],
        );

        expect(shoppingList.containsKey('Ugu leaves'), true);
        expect(shoppingList['Ugu leaves'], '1 bunch + 2 bunches');
      },
    );
  });
}
