import 'entities/recipe_entity.dart';

class MealRecommendationEngine {
  /// Filters recipes by hard allergen exclusions, dietary preferences, and regional priority.
  static List<RecipeEntity> recommend({
    required List<RecipeEntity> allRecipes,
    required List<String> userAllergens,
    List<String> userDislikedFoods = const [],
    String? preferredRegion,
    String? dietaryPattern,
  }) {
    return allRecipes.where((recipe) {
      // 1. HARD ALLERGEN EXCLUSION: If any ingredient or allergen matches, exclude completely
      for (final allergen in userAllergens) {
        final lowerAllergen = allergen.toLowerCase();
        if (recipe.allergens.any(
          (a) => a.toLowerCase().contains(lowerAllergen),
        )) {
          return false;
        }
        if (recipe.ingredients.any(
          (ing) => ing.toLowerCase().contains(lowerAllergen),
        )) {
          return false;
        }
      }

      // 2. Disliked foods exclusion
      for (final disliked in userDislikedFoods) {
        final lowerDisliked = disliked.toLowerCase();
        if (recipe.ingredients.any(
          (ing) => ing.toLowerCase().contains(lowerDisliked),
        )) {
          return false;
        }
      }

      // 3. Dietary pattern matching (e.g. Vegetarian)
      if (dietaryPattern != null &&
          dietaryPattern.toLowerCase().contains('vegetarian')) {
        if (!recipe.dietaryTags.any((t) => t.toLowerCase() == 'vegetarian')) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Aggregates and merges duplicate ingredients across a list of planned meals into a smart shopping list.
  static Map<String, String> generateSmartShoppingList(
    List<RecipeEntity> plannedRecipes,
  ) {
    final Map<String, List<String>> aggregated = {};

    for (final recipe in plannedRecipes) {
      recipe.ingredientQuantities.forEach((ingredient, quantity) {
        final key = ingredient.trim().toLowerCase();
        if (!aggregated.containsKey(key)) {
          aggregated[key] = [];
        }
        aggregated[key]!.add(quantity);
      });
    }

    final Map<String, String> smartList = {};
    aggregated.forEach((ingredient, quantities) {
      // Capitalize first letter
      final formattedName =
          ingredient[0].toUpperCase() + ingredient.substring(1);
      smartList[formattedName] = quantities.join(' + ');
    });

    return smartList;
  }

  /// "Cook with what I have" ingredient matcher.
  static List<RecipeEntity> cookWithAvailableIngredients({
    required List<RecipeEntity> recipes,
    required List<String> availablePantryItems,
  }) {
    final List<String> lowerAvailable = availablePantryItems
        .map((i) => i.toLowerCase())
        .toList();

    final List<RecipeEntity> matches = List.from(recipes);
    matches.sort((a, b) {
      final aCount = a.ingredients
          .where((i) => lowerAvailable.contains(i.toLowerCase()))
          .length;
      final bCount = b.ingredients
          .where((i) => lowerAvailable.contains(i.toLowerCase()))
          .length;
      return bCount.compareTo(aCount);
    });

    return matches;
  }
}
