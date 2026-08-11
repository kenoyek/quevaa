class MealIngredient {
  final String name;
  final double quantity;
  final String unit;
  final bool optional;
  final String preparation;
  final String category;

  const MealIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.optional = false,
    this.preparation = '',
    this.category = 'General',
  });

  MealIngredient scaled(double factor) {
    return MealIngredient(
      name: name,
      quantity: quantity * factor,
      unit: unit,
      optional: optional,
      preparation: preparation,
      category: category,
    );
  }

  String format({double scale = 1}) {
    final scaledQuantity = quantity * scale;
    final quantityText = scaledQuantity == scaledQuantity.roundToDouble()
        ? scaledQuantity.round().toString()
        : scaledQuantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final prep = preparation.isEmpty ? '' : ', $preparation';
    final optionalText = optional ? ', optional' : '';
    return '$quantityText $unit $name$prep$optionalText'.trim();
  }
}

class RecipeStep {
  final int stepNumber;
  final String title;
  final String instruction;
  final int estimatedMinutes;

  const RecipeStep({
    required this.stepNumber,
    required this.title,
    required this.instruction,
    required this.estimatedMinutes,
  });
}

class NigerianRecipe {
  final String id;
  final String title;
  final String mealType;
  final String targetPhase;
  final String description;
  final String keyNutrients;
  final String region;
  final int prepMinutes;
  final int cookMinutes;
  final int servings;
  final String cuisine;
  final String difficulty;
  final String budgetLevel;
  final String imageAsset;
  final List<MealIngredient> ingredients;
  final List<RecipeStep> instructions;
  final List<String> nutritionTags;
  final List<String> cyclePhaseTags;
  final List<String> dietaryTags;
  final List<String> allergenTags;
  final List<String> proteinSources;
  final List<String> healthyFatSources;
  final bool ironRich;
  final bool highFibre;
  final bool complexCarbohydrate;
  final List<String> substitutions;
  final List<String> servingSuggestions;

  const NigerianRecipe({
    required this.id,
    required this.title,
    required this.mealType,
    required this.targetPhase,
    required this.description,
    required this.keyNutrients,
    required this.region,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.servings,
    required this.ingredients,
    required this.instructions,
    required this.nutritionTags,
    required this.cyclePhaseTags,
    required this.dietaryTags,
    required this.allergenTags,
    required this.proteinSources,
    required this.healthyFatSources,
    required this.ironRich,
    required this.highFibre,
    required this.complexCarbohydrate,
    required this.substitutions,
    required this.servingSuggestions,
    this.cuisine = 'Nigerian',
    this.difficulty = 'Easy',
    this.budgetLevel = 'Moderate',
    this.imageAsset = '',
  });

  int get totalMinutes => prepMinutes + cookMinutes;
  bool get isVegetarian => dietaryTags.contains('Vegetarian');
  bool get hasHealthyFat => healthyFatSources.isNotEmpty;
  String get dishFamily => NigerianRecipeDatabase.dishFamilyFor(this);
  String get dominantStaple => NigerianRecipeDatabase.dominantStapleFor(this);

  String whySuggested(String phase, {String? prepPreference}) {
    final phaseCopy = NigerianRecipeDatabase.phaseLabelForCyclePhase(phase);
    final nutrients = nutritionTags.take(3).join(', ').toLowerCase();
    final time = prepPreference == null || prepPreference.trim().isEmpty
        ? ''
        : ' It also fits your $prepPreference preparation preference when possible.';
    return 'Quevaa ranked this meal because it fits your $phaseCopy context, adds ${dishFamily.replaceAll('_', ' ')} variety, contains $nutrients, and matches your food preferences.$time';
  }
}

class MealRecommendationInput {
  final DateTime date;
  final String cyclePhase;
  final String mealType;
  final String? dietaryPattern;
  final String? preferredRegion;
  final String? prepTimePreference;
  final List<String> excludedAllergens;
  final List<String> dislikedFoods;
  final List<String> pantryItems;
  final Set<String> recentlyPreparedMealIds;
  final Set<String> savedMealIds;
  final Set<String> selectedDishFamilies;
  final Set<String> recentDishFamilies;
  final Set<String> selectedStaples;
  final Set<String> recentStaples;
  final int alternativeOffset;

  const MealRecommendationInput({
    required this.date,
    required this.cyclePhase,
    required this.mealType,
    this.dietaryPattern,
    this.preferredRegion,
    this.prepTimePreference,
    this.excludedAllergens = const [],
    this.dislikedFoods = const [],
    this.pantryItems = const [],
    this.recentlyPreparedMealIds = const {},
    this.savedMealIds = const {},
    this.selectedDishFamilies = const {},
    this.recentDishFamilies = const {},
    this.selectedStaples = const {},
    this.recentStaples = const {},
    this.alternativeOffset = 0,
  });
}

class NigerianRecipeDatabase {
  static final List<NigerianRecipe> recipes = List.unmodifiable(
    _buildRecipes(),
  );

  static List<NigerianRecipe> getForPhase(String phase) {
    final normalizedPhase = phaseKeyForCyclePhase(phase);
    return recipes
        .where((r) => r.cyclePhaseTags.contains(normalizedPhase))
        .toList();
  }

  static NigerianRecipe recommend(MealRecommendationInput input) {
    final ranked = rankedRecommendations(input);
    if (ranked.isEmpty) {
      final fallback = recipes
          .where((recipe) => recipe.mealType == input.mealType)
          .toList(growable: false);
      return (fallback.isEmpty ? recipes : fallback).first;
    }
    final familyDistinct = <NigerianRecipe>[];
    final seenFamilies = <String>{};
    for (final recipe in ranked) {
      if (seenFamilies.add(recipe.dishFamily)) {
        familyDistinct.add(recipe);
      }
    }
    final pool = familyDistinct.length > input.alternativeOffset
        ? familyDistinct
        : ranked;
    return pool[input.alternativeOffset % pool.length];
  }

  static List<NigerianRecipe> rankedRecommendations(
    MealRecommendationInput input,
  ) {
    final phaseKey = phaseKeyForCyclePhase(input.cyclePhase);
    final maxPrepMinutes = prepMinutesForPreference(input.prepTimePreference);
    final exclusions = {
      ...input.excludedAllergens.map(_normalizeToken),
      ..._allergensFromDiet(input.dietaryPattern),
    };
    final dislikes = input.dislikedFoods.map(_normalizeToken).toSet();
    final pantry = input.pantryItems.map(_normalizeToken).toSet();

    var scored = <({NigerianRecipe recipe, int score})>[];
    for (final recipe in recipes) {
      if (recipe.mealType != input.mealType) continue;
      if (!_matchesDiet(recipe, input.dietaryPattern)) continue;
      if (_hasExcludedAllergen(recipe, exclusions)) continue;
      if (_containsDislikedFood(recipe, dislikes)) continue;

      var score = 40;
      score -= _familyOverrepresentationPenalty(recipe);
      if (recipe.cyclePhaseTags.contains(phaseKey)) score += 14;
      if (recipe.cyclePhaseTags.contains('all')) score += 8;
      if (_regionScore(recipe, input.preferredRegion) > 0) score += 12;
      if (maxPrepMinutes == null || recipe.totalMinutes <= maxPrepMinutes) {
        score += 14;
      } else {
        score -= ((recipe.totalMinutes - maxPrepMinutes) / 5).round();
      }
      final pantryMatches = recipe.ingredients
          .where(
            (ingredient) => pantry.contains(_normalizeToken(ingredient.name)),
          )
          .length;
      score += pantryMatches.clamp(0, 3) * 3;
      if (input.savedMealIds.contains(recipe.id)) score += 8;
      if (input.recentlyPreparedMealIds.contains(recipe.id)) score -= 80;
      if (input.selectedDishFamilies.contains(recipe.dishFamily)) score -= 95;
      if (input.recentDishFamilies.contains(recipe.dishFamily)) score -= 55;
      final staple = recipe.dominantStaple;
      if (staple.isNotEmpty && input.selectedStaples.contains(staple)) {
        score -= 28;
      }
      if (staple.isNotEmpty && input.recentStaples.contains(staple)) {
        score -= 12;
      }
      score += _stableTiebreak(input.date, recipe.id);
      scored.add((recipe: recipe, score: score));
    }
    if (maxPrepMinutes != null) {
      final timeFit = scored
          .where((entry) => entry.recipe.totalMinutes <= maxPrepMinutes + 15)
          .toList(growable: false);
      if (timeFit.isNotEmpty) scored = timeFit;
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.recipe.title.compareTo(b.recipe.title);
    });
    return scored.map((entry) => entry.recipe).toList(growable: false);
  }

  static Map<String, NigerianRecipe> recommendDailyMeals({
    required DateTime date,
    required String cyclePhase,
    String? dietaryPattern,
    String? preferredRegion,
    String? prepTimePreference,
    List<String> excludedAllergens = const [],
    List<String> pantryItems = const [],
    Set<String> recentlyPreparedMealIds = const {},
    Set<String> savedMealIds = const {},
    Map<String, int> alternativeOffsets = const {},
  }) {
    final selectedFamilies = <String>{};
    final selectedStaples = <String>{};
    final recentFamilies = {
      for (final id in recentlyPreparedMealIds)
        if (recipeById(id) case final recipe?) recipe.dishFamily,
    };
    final recentStaples = {
      for (final id in recentlyPreparedMealIds)
        if (recipeById(id) case final recipe?)
          if (recipe.dominantStaple.isNotEmpty) recipe.dominantStaple,
    };
    final meals = <String, NigerianRecipe>{};
    for (final mealType in const ['Breakfast', 'Lunch', 'Dinner', 'Snack']) {
      final recipe = recommend(
        MealRecommendationInput(
          date: date,
          cyclePhase: cyclePhase,
          mealType: mealType,
          dietaryPattern: dietaryPattern,
          preferredRegion: preferredRegion,
          prepTimePreference: prepTimePreference,
          excludedAllergens: excludedAllergens,
          pantryItems: pantryItems,
          recentlyPreparedMealIds: recentlyPreparedMealIds,
          savedMealIds: savedMealIds,
          selectedDishFamilies: selectedFamilies,
          recentDishFamilies: recentFamilies,
          selectedStaples: selectedStaples,
          recentStaples: recentStaples,
          alternativeOffset: alternativeOffsets[mealType] ?? 0,
        ),
      );
      meals[mealType] = recipe;
      selectedFamilies.add(recipe.dishFamily);
      if (recipe.dominantStaple.isNotEmpty) {
        selectedStaples.add(recipe.dominantStaple);
      }
    }
    return meals;
  }

  static NigerianRecipe? recipeById(String id) {
    for (final recipe in recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  static String dishFamilyFor(NigerianRecipe recipe) {
    final tokens = [
      recipe.id,
      recipe.title,
      ...recipe.ingredients.map((item) => item.name),
    ].join(' ').toLowerCase();
    if (tokens.contains('moi moi') || tokens.contains('moi-moi')) {
      return 'moi_moi';
    }
    if (tokens.contains('jollof')) return 'jollof';
    if (tokens.contains('fried rice')) return 'fried_rice';
    if (tokens.contains('ofada')) return 'ofada_rice';
    if (tokens.contains('native rice')) return 'native_rice';
    if (tokens.contains('rice and beans')) return 'rice_beans';
    if (tokens.contains('rice')) return 'rice';
    if (tokens.contains('beans')) return 'beans';
    if (tokens.contains('yam')) return 'yam';
    if (tokens.contains('plantain')) return 'plantain';
    if (tokens.contains('sweet potato') || tokens.contains('potato')) {
      return 'potato';
    }
    if (tokens.contains('spaghetti') || tokens.contains('pasta')) {
      return 'pasta';
    }
    if (tokens.contains('oat')) return 'oats';
    if (tokens.contains('pap') || tokens.contains('akamu')) return 'pap';
    if (tokens.contains('egg') || tokens.contains('omelette')) return 'eggs';
    if (tokens.contains('okra')) return 'okra_soup';
    if (tokens.contains('egusi')) return 'egusi_soup';
    if (tokens.contains('ogbono')) return 'ogbono_soup';
    if (tokens.contains('pepper soup')) return 'pepper_soup';
    if (tokens.contains('soup')) return 'soups';
    if (tokens.contains('salad')) return 'salad';
    if (tokens.contains('fruit')) return 'fruit';
    if (tokens.contains('groundnut')) return 'groundnuts';
    return _normalizeToken(
      recipe.title,
    ).replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  static String dominantStapleFor(NigerianRecipe recipe) {
    final ingredientText = recipe.ingredients
        .map((item) => item.name.toLowerCase())
        .join(' ');
    for (final staple in const [
      'rice',
      'beans',
      'yam',
      'plantain',
      'sweet potato',
      'spaghetti',
      'oats',
      'millet pap',
      'corn pap',
      'akamu',
      'bread',
      'corn',
    ]) {
      if (ingredientText.contains(staple)) {
        if (staple.contains('pap') || staple == 'akamu') return 'pap';
        if (staple == 'spaghetti') return 'pasta';
        return staple.replaceAll(' ', '_');
      }
    }
    return '';
  }

  static int _familyOverrepresentationPenalty(NigerianRecipe recipe) {
    final count = recipes
        .where(
          (candidate) =>
              candidate.mealType == recipe.mealType &&
              candidate.dishFamily == recipe.dishFamily,
        )
        .length;
    return count <= 1 ? 0 : (count - 1) * 8;
  }

  static String phaseKeyForCyclePhase(String phase) {
    final normalized = phase.toLowerCase();
    if (normalized.contains('menstrual') ||
        normalized.contains('bleeding') ||
        normalized.contains('period')) {
      return 'menstrual';
    }
    if (normalized.contains('ovulation') ||
        normalized.contains('ovulatory') ||
        normalized.contains('fertile')) {
      return 'ovulation';
    }
    if (normalized.contains('luteal')) return 'luteal';
    if (normalized.contains('follicular')) return 'follicular';
    return 'all';
  }

  static String phaseLabelForCyclePhase(String phase) {
    return switch (phaseKeyForCyclePhase(phase)) {
      'menstrual' => 'menstrual phase',
      'follicular' => 'follicular phase',
      'ovulation' => 'estimated ovulatory window',
      'luteal' => 'luteal phase',
      _ => 'current cycle',
    };
  }

  static int? prepMinutesForPreference(String? value) {
    final lower = value?.toLowerCase() ?? '';
    if (lower.contains('15')) return 15;
    if (lower.contains('30')) return 30;
    if (lower.contains('45')) return 45;
    if (lower.contains('60')) return 60;
    return null;
  }
}

List<NigerianRecipe> _buildRecipes() {
  final seeds = <_RecipeSeed>[
    const _RecipeSeed(
      'nigerian-oatmeal-banana-groundnuts',
      'Nigerian Oatmeal with Banana and Groundnuts',
      'Breakfast',
      'menstrual',
      'Contemporary',
      ['oats', 'banana', 'groundnuts'],
      ['peanut'],
      ['whole grain', 'fruit', 'healthy fat'],
      5,
      10,
      true,
    ),
    const _RecipeSeed(
      'millet-pap-moi-moi',
      'Millet Pap with Moi Moi',
      'Breakfast',
      'menstrual',
      'Northern',
      ['millet pap', 'moi moi', 'ginger'],
      [],
      ['complex carbohydrate', 'plant protein'],
      5,
      15,
      true,
    ),
    const _RecipeSeed(
      'akamu-with-egg',
      'Akamu with Egg',
      'Breakfast',
      'follicular',
      'Pan-Nigerian',
      ['akamu', 'eggs', 'tomatoes'],
      ['egg'],
      ['protein', 'whole food carbohydrate'],
      8,
      12,
      false,
    ),
    const _RecipeSeed(
      'akamu-with-akara',
      'Akamu with Akara',
      'Breakfast',
      'follicular',
      'Yoruba',
      ['akamu', 'beans', 'pepper'],
      [],
      ['plant protein', 'fibre'],
      15,
      25,
      true,
    ),
    const _RecipeSeed(
      'boiled-yam-egg-sauce',
      'Boiled Yam and Egg Sauce',
      'Breakfast',
      'follicular',
      'Pan-Nigerian',
      ['yam', 'eggs', 'tomatoes'],
      ['egg'],
      ['protein', 'complex carbohydrate'],
      10,
      20,
      false,
    ),
    const _RecipeSeed(
      'sweet-potato-vegetable-omelette',
      'Sweet Potato and Vegetable Omelette',
      'Breakfast',
      'luteal',
      'Contemporary',
      ['sweet potato', 'eggs', 'spinach'],
      ['egg'],
      ['protein', 'vegetables', 'complex carbohydrate'],
      10,
      18,
      false,
    ),
    const _RecipeSeed(
      'bread-vegetable-egg-sauce',
      'Bread and Vegetable Egg Sauce',
      'Breakfast',
      'follicular',
      'Pan-Nigerian',
      ['bread', 'eggs', 'ugu'],
      ['egg'],
      ['protein', 'vegetables'],
      8,
      12,
      false,
    ),
    const _RecipeSeed(
      'moi-moi-with-fruit',
      'Moi Moi with Fruit',
      'Breakfast',
      'ovulation',
      'Pan-Nigerian',
      ['moi moi', 'pawpaw', 'banana'],
      [],
      ['plant protein', 'fruit'],
      5,
      5,
      true,
    ),
    const _RecipeSeed(
      'plantain-scrambled-egg',
      'Plantain and Scrambled Egg',
      'Breakfast',
      'luteal',
      'Pan-Nigerian',
      ['plantain', 'eggs', 'onion'],
      ['egg'],
      ['protein', 'complex carbohydrate'],
      8,
      18,
      false,
    ),
    const _RecipeSeed(
      'beans-ripe-plantain-breakfast',
      'Beans and Ripe Plantain',
      'Breakfast',
      'menstrual',
      'Pan-Nigerian',
      ['beans', 'plantain', 'palm oil'],
      [],
      ['plant protein', 'fibre', 'complex carbohydrate'],
      10,
      35,
      true,
    ),
    const _RecipeSeed(
      'boiled-plantain-egg-sauce',
      'Boiled Plantain and Egg Sauce',
      'Breakfast',
      'luteal',
      'Pan-Nigerian',
      ['plantain', 'eggs', 'tomatoes'],
      ['egg'],
      ['protein', 'fibre'],
      8,
      20,
      false,
    ),
    const _RecipeSeed(
      'yoghurt-fruit-groundnut-bowl',
      'Yoghurt, Fruit and Groundnut Bowl',
      'Breakfast',
      'ovulation',
      'Contemporary',
      ['yoghurt', 'banana', 'groundnuts'],
      ['dairy', 'peanut'],
      ['fruit', 'protein', 'healthy fat'],
      10,
      0,
      false,
    ),
    const _RecipeSeed(
      'oat-groundnut-breakfast-bowl',
      'Oat and Groundnut Breakfast Bowl',
      'Breakfast',
      'luteal',
      'Contemporary',
      ['oats', 'groundnuts', 'dates'],
      ['peanut'],
      ['whole grain', 'healthy fat'],
      5,
      8,
      true,
    ),
    const _RecipeSeed(
      'sweet-potato-sardine-egg-sauce',
      'Sweet Potato and Sardine Egg Sauce',
      'Breakfast',
      'ovulation',
      'Pan-Nigerian',
      ['sweet potato', 'sardines', 'eggs'],
      ['fish', 'egg'],
      ['protein', 'omega-3', 'complex carbohydrate'],
      8,
      18,
      false,
    ),
    const _RecipeSeed(
      'avocado-egg-toast',
      'Avocado Egg Toast',
      'Breakfast',
      'follicular',
      'Contemporary',
      ['bread', 'avocado', 'eggs'],
      ['egg'],
      ['healthy fat', 'protein'],
      8,
      8,
      false,
    ),
    const _RecipeSeed(
      'corn-porridge-moi-moi',
      'Corn Porridge with Moi Moi',
      'Breakfast',
      'menstrual',
      'Pan-Nigerian',
      ['corn pap', 'moi moi', 'ginger'],
      [],
      ['plant protein', 'complex carbohydrate'],
      5,
      10,
      true,
    ),
    const _RecipeSeed(
      'jollof-rice-grilled-chicken',
      'Jollof Rice with Grilled Chicken',
      'Lunch',
      'follicular',
      'Pan-Nigerian',
      ['rice', 'chicken', 'tomatoes', 'red bell pepper'],
      [],
      ['protein', 'vegetables'],
      20,
      45,
      false,
    ),
    const _RecipeSeed(
      'jollof-rice-grilled-fish',
      'Jollof Rice with Grilled Fish',
      'Dinner',
      'ovulation',
      'Pan-Nigerian',
      ['rice', 'fish', 'tomatoes', 'red bell pepper'],
      ['fish'],
      ['protein', 'vegetables'],
      20,
      40,
      false,
    ),
    const _RecipeSeed(
      'nigerian-fried-rice-chicken',
      'Nigerian Fried Rice with Chicken',
      'Lunch',
      'follicular',
      'Pan-Nigerian',
      ['rice', 'chicken', 'carrots', 'green beans'],
      [],
      ['protein', 'vegetables'],
      20,
      35,
      false,
    ),
    const _RecipeSeed(
      'rice-beans-tomato-stew',
      'Rice and Beans with Tomato Stew',
      'Lunch',
      'menstrual',
      'Pan-Nigerian',
      ['rice', 'beans', 'tomatoes'],
      [],
      ['plant protein', 'fibre', 'complex carbohydrate'],
      15,
      45,
      true,
    ),
    const _RecipeSeed(
      'ofada-rice-vegetable-sauce',
      'Ofada Rice with Vegetable-Rich Sauce',
      'Lunch',
      'follicular',
      'Yoruba',
      ['ofada rice', 'eggs', 'green pepper'],
      ['egg'],
      ['protein', 'vegetables'],
      15,
      35,
      false,
    ),
    const _RecipeSeed(
      'beans-porridge',
      'Beans Porridge',
      'Lunch',
      'menstrual',
      'Pan-Nigerian',
      ['beans', 'palm oil', 'crayfish'],
      ['shellfish'],
      ['plant protein', 'fibre'],
      15,
      45,
      false,
    ),
    const _RecipeSeed(
      'beans-ripe-plantain-lunch',
      'Beans and Ripe Plantain Bowl',
      'Lunch',
      'luteal',
      'Pan-Nigerian',
      ['beans', 'plantain', 'ugu'],
      [],
      ['plant protein', 'fibre', 'vegetables'],
      15,
      40,
      true,
    ),
    const _RecipeSeed(
      'unripe-plantain-porridge',
      'Unripe Plantain Porridge',
      'Dinner',
      'menstrual',
      'South-South',
      ['unripe plantain', 'ugu', 'dry fish'],
      ['fish'],
      ['iron-rich vegetables', 'complex carbohydrate'],
      15,
      35,
      false,
    ),
    const _RecipeSeed(
      'yam-porridge',
      'Yam Porridge',
      'Lunch',
      'luteal',
      'Pan-Nigerian',
      ['yam', 'tomatoes', 'ugu'],
      [],
      ['complex carbohydrate', 'vegetables'],
      15,
      30,
      true,
    ),
    const _RecipeSeed(
      'boiled-yam-garden-egg-sauce',
      'Boiled Yam with Garden Egg Sauce',
      'Lunch',
      'ovulation',
      'Pan-Nigerian',
      ['yam', 'garden egg', 'tomatoes'],
      [],
      ['vegetables', 'complex carbohydrate'],
      15,
      25,
      true,
    ),
    const _RecipeSeed(
      'boiled-yam-egg-sauce-lunch',
      'Boiled Yam with Egg Sauce',
      'Lunch',
      'follicular',
      'Pan-Nigerian',
      ['yam', 'eggs', 'tomatoes'],
      ['egg'],
      ['protein', 'complex carbohydrate'],
      10,
      25,
      false,
    ),
    const _RecipeSeed(
      'sweet-potato-vegetable-sauce',
      'Sweet Potato with Vegetable Sauce',
      'Dinner',
      'luteal',
      'Pan-Nigerian',
      ['sweet potato', 'spinach', 'tomatoes'],
      [],
      ['fibre', 'complex carbohydrate', 'vegetables'],
      12,
      25,
      true,
    ),
    const _RecipeSeed(
      'moi-moi-salad',
      'Moi Moi with Salad',
      'Lunch',
      'ovulation',
      'Pan-Nigerian',
      ['moi moi', 'cabbage', 'carrots'],
      [],
      ['plant protein', 'vegetables'],
      10,
      5,
      true,
    ),
    const _RecipeSeed(
      'moi-moi-rice',
      'Moi Moi with Rice',
      'Dinner',
      'menstrual',
      'Pan-Nigerian',
      ['moi moi', 'rice', 'tomatoes'],
      [],
      ['plant protein', 'complex carbohydrate'],
      10,
      25,
      true,
    ),
    const _RecipeSeed(
      'efo-riro-rice',
      'Efo Riro with Rice',
      'Dinner',
      'menstrual',
      'Yoruba',
      ['efo leaves', 'rice', 'fish'],
      ['fish'],
      ['leafy vegetables', 'protein'],
      20,
      35,
      false,
    ),
    const _RecipeSeed(
      'edikang-ikong-style-soup',
      'Edikang Ikong-Style Vegetable Soup',
      'Dinner',
      'luteal',
      'South-South',
      ['ugu', 'waterleaf', 'fish'],
      ['fish'],
      ['leafy vegetables', 'protein'],
      20,
      40,
      false,
    ),
    const _RecipeSeed(
      'okra-soup',
      'Okra Soup',
      'Dinner',
      'ovulation',
      'Pan-Nigerian',
      ['okra', 'spinach', 'fish'],
      ['fish'],
      ['vegetables', 'protein'],
      15,
      25,
      false,
    ),
    const _RecipeSeed(
      'vegetarian-okra-soup',
      'Vegetarian Okra and Spinach Soup',
      'Dinner',
      'ovulation',
      'Pan-Nigerian',
      ['okra', 'spinach', 'mushrooms'],
      [],
      ['vegetables', 'fibre'],
      15,
      25,
      true,
    ),
    const _RecipeSeed(
      'ogbono-soup',
      'Ogbono Soup',
      'Dinner',
      'luteal',
      'Igbo',
      ['ogbono', 'spinach', 'fish'],
      ['fish'],
      ['healthy fat', 'vegetables'],
      15,
      30,
      false,
    ),
    const _RecipeSeed(
      'egusi-soup',
      'Egusi Soup with Spinach',
      'Dinner',
      'luteal',
      'Pan-Nigerian',
      ['egusi', 'spinach', 'stockfish'],
      ['fish'],
      ['healthy fat', 'leafy vegetables'],
      20,
      35,
      false,
    ),
    const _RecipeSeed(
      'mushroom-egusi',
      'Mushroom Egusi with Spinach',
      'Dinner',
      'luteal',
      'Pan-Nigerian',
      ['egusi', 'mushrooms', 'spinach'],
      [],
      ['healthy fat', 'plant protein'],
      20,
      35,
      true,
    ),
    const _RecipeSeed(
      'afang-style-soup',
      'Afang-Style Soup',
      'Dinner',
      'luteal',
      'South-South',
      ['afang leaves', 'waterleaf', 'fish'],
      ['fish'],
      ['leafy vegetables', 'protein'],
      20,
      40,
      false,
    ),
    const _RecipeSeed(
      'oha-soup',
      'Oha Soup',
      'Dinner',
      'follicular',
      'Igbo',
      ['oha leaves', 'cocoyam', 'fish'],
      ['fish'],
      ['vegetables', 'complex carbohydrate'],
      20,
      35,
      false,
    ),
    const _RecipeSeed(
      'bitterleaf-soup',
      'Bitterleaf Soup',
      'Dinner',
      'menstrual',
      'Igbo',
      ['bitterleaf', 'cocoyam', 'fish'],
      ['fish'],
      ['leafy vegetables', 'protein'],
      20,
      40,
      false,
    ),
    const _RecipeSeed(
      'groundnut-soup',
      'Groundnut Soup',
      'Dinner',
      'luteal',
      'Northern',
      ['groundnuts', 'spinach', 'chicken'],
      ['peanut'],
      ['healthy fat', 'protein'],
      20,
      35,
      false,
    ),
    const _RecipeSeed(
      'fish-pepper-soup',
      'Fish Pepper Soup with Yam',
      'Dinner',
      'follicular',
      'South-South',
      ['fish', 'yam', 'pepper soup spice'],
      ['fish'],
      ['protein', 'complex carbohydrate'],
      15,
      25,
      false,
    ),
    const _RecipeSeed(
      'chicken-pepper-soup',
      'Chicken Pepper Soup with Plantain',
      'Dinner',
      'follicular',
      'Pan-Nigerian',
      ['chicken', 'plantain', 'pepper soup spice'],
      [],
      ['protein', 'complex carbohydrate'],
      15,
      30,
      false,
    ),
    const _RecipeSeed(
      'grilled-fish-vegetables',
      'Grilled Fish with Vegetables',
      'Dinner',
      'ovulation',
      'Pan-Nigerian',
      ['fish', 'cabbage', 'carrots'],
      ['fish'],
      ['protein', 'vegetables'],
      15,
      25,
      false,
    ),
    const _RecipeSeed(
      'chicken-vegetable-stir-fry',
      'Chicken Vegetable Stir-Fry with Rice',
      'Lunch',
      'follicular',
      'Contemporary',
      ['chicken', 'rice', 'cabbage', 'carrots'],
      [],
      ['protein', 'vegetables'],
      15,
      25,
      false,
    ),
    const _RecipeSeed(
      'beef-vegetable-stir-fry',
      'Beef Vegetable Stir-Fry',
      'Lunch',
      'follicular',
      'Contemporary',
      ['beef', 'cabbage', 'green pepper'],
      [],
      ['protein', 'vegetables'],
      15,
      25,
      false,
    ),
    const _RecipeSeed(
      'chicken-vegetable-rice',
      'Chicken and Vegetable Rice',
      'Dinner',
      'ovulation',
      'Pan-Nigerian',
      ['chicken', 'rice', 'carrots', 'green beans'],
      [],
      ['protein', 'vegetables'],
      15,
      30,
      false,
    ),
    const _RecipeSeed(
      'coconut-rice',
      'Coconut Rice with Vegetables',
      'Lunch',
      'luteal',
      'Pan-Nigerian',
      ['rice', 'coconut milk', 'carrots'],
      ['dairy'],
      ['healthy fat', 'vegetables'],
      15,
      35,
      true,
    ),
    const _RecipeSeed(
      'native-rice',
      'Native Rice with Vegetables',
      'Lunch',
      'menstrual',
      'South-South',
      ['rice', 'ugu', 'fish'],
      ['fish'],
      ['vegetables', 'complex carbohydrate'],
      15,
      35,
      false,
    ),
    const _RecipeSeed(
      'vegetable-rice',
      'Vegetable Rice',
      'Lunch',
      'follicular',
      'Pan-Nigerian',
      ['rice', 'carrots', 'green beans'],
      [],
      ['vegetables', 'complex carbohydrate'],
      15,
      25,
      true,
    ),
    const _RecipeSeed(
      'tomato-spaghetti-vegetables',
      'Tomato Spaghetti with Vegetables',
      'Lunch',
      'follicular',
      'Contemporary',
      ['spaghetti', 'tomatoes', 'carrots'],
      [],
      ['vegetables', 'complex carbohydrate'],
      15,
      25,
      true,
    ),
    const _RecipeSeed(
      'chicken-spaghetti',
      'Chicken Spaghetti with Vegetables',
      'Dinner',
      'ovulation',
      'Contemporary',
      ['spaghetti', 'chicken', 'tomatoes'],
      [],
      ['protein', 'vegetables'],
      15,
      30,
      false,
    ),
    const _RecipeSeed(
      'beans-sweet-potato',
      'Beans with Sweet Potato',
      'Lunch',
      'luteal',
      'Pan-Nigerian',
      ['beans', 'sweet potato', 'ugu'],
      [],
      ['plant protein', 'fibre'],
      15,
      40,
      true,
    ),
    const _RecipeSeed(
      'plantain-vegetable-sauce',
      'Plantain with Vegetable Sauce',
      'Lunch',
      'luteal',
      'Pan-Nigerian',
      ['plantain', 'spinach', 'tomatoes'],
      [],
      ['vegetables', 'complex carbohydrate'],
      12,
      25,
      true,
    ),
    const _RecipeSeed(
      'plantain-grilled-fish',
      'Plantain and Grilled Fish',
      'Dinner',
      'ovulation',
      'Pan-Nigerian',
      ['plantain', 'fish', 'cabbage'],
      ['fish'],
      ['protein', 'complex carbohydrate'],
      15,
      25,
      false,
    ),
    const _RecipeSeed(
      'boiled-plantain-vegetable-stew',
      'Boiled Plantain with Vegetable Stew',
      'Dinner',
      'luteal',
      'Pan-Nigerian',
      ['plantain', 'ugu', 'tomatoes'],
      [],
      ['vegetables', 'complex carbohydrate'],
      12,
      25,
      true,
    ),
    const _RecipeSeed(
      'nigerian-chicken-salad',
      'Nigerian-Style Chicken Salad',
      'Lunch',
      'follicular',
      'Contemporary',
      ['chicken', 'cabbage', 'carrots'],
      [],
      ['protein', 'vegetables'],
      15,
      15,
      false,
    ),
    const _RecipeSeed(
      'vegetable-omelette-meal',
      'Nigerian Vegetable Omelette Meal',
      'Lunch',
      'ovulation',
      'Pan-Nigerian',
      ['eggs', 'ugu', 'tomatoes'],
      ['egg'],
      ['protein', 'vegetables'],
      10,
      15,
      false,
    ),
    const _RecipeSeed(
      'brown-rice-vegetable-stew',
      'Brown Rice with Vegetable Stew',
      'Dinner',
      'luteal',
      'Contemporary',
      ['brown rice', 'spinach', 'tomatoes'],
      [],
      ['fibre', 'vegetables'],
      15,
      35,
      true,
    ),
    const _RecipeSeed(
      'rice-green-vegetable-stew',
      'Rice with Green Vegetable Stew',
      'Dinner',
      'menstrual',
      'Pan-Nigerian',
      ['rice', 'ugu', 'tomatoes'],
      [],
      ['leafy vegetables', 'complex carbohydrate'],
      15,
      30,
      true,
    ),
    const _RecipeSeed(
      'fruit-groundnuts',
      'Fruit and Groundnuts',
      'Snack',
      'luteal',
      'Pan-Nigerian',
      ['banana', 'pawpaw', 'groundnuts'],
      ['peanut'],
      ['fruit', 'healthy fat'],
      10,
      0,
      true,
    ),
    const _RecipeSeed(
      'banana-groundnut-combo',
      'Banana and Groundnut Snack',
      'Snack',
      'menstrual',
      'Pan-Nigerian',
      ['banana', 'groundnuts'],
      ['peanut'],
      ['fruit', 'healthy fat'],
      5,
      0,
      true,
    ),
    const _RecipeSeed(
      'boiled-egg-fruit',
      'Boiled Egg and Fruit',
      'Snack',
      'follicular',
      'Pan-Nigerian',
      ['eggs', 'orange'],
      ['egg'],
      ['protein', 'fruit'],
      5,
      10,
      false,
    ),
    const _RecipeSeed(
      'roasted-plantain',
      'Roasted Plantain',
      'Snack',
      'luteal',
      'Pan-Nigerian',
      ['plantain', 'pepper sauce'],
      [],
      ['complex carbohydrate'],
      5,
      20,
      true,
    ),
    const _RecipeSeed(
      'roasted-corn',
      'Roasted Corn',
      'Snack',
      'follicular',
      'Pan-Nigerian',
      ['corn', 'coconut'],
      [],
      ['fibre', 'whole food carbohydrate'],
      5,
      20,
      true,
    ),
    const _RecipeSeed(
      'yoghurt-fruit',
      'Yoghurt and Fruit',
      'Snack',
      'ovulation',
      'Contemporary',
      ['yoghurt', 'pawpaw', 'banana'],
      ['dairy'],
      ['fruit', 'protein'],
      10,
      0,
      false,
    ),
    const _RecipeSeed(
      'cucumber-groundnut-snack',
      'Cucumber and Groundnut Snack',
      'Snack',
      'follicular',
      'Pan-Nigerian',
      ['cucumber', 'groundnuts'],
      ['peanut'],
      ['vegetables', 'healthy fat'],
      8,
      0,
      true,
    ),
    const _RecipeSeed(
      'small-moi-moi-portion',
      'Small Moi Moi Portion',
      'Snack',
      'menstrual',
      'Pan-Nigerian',
      ['moi moi', 'cucumber'],
      [],
      ['plant protein'],
      5,
      5,
      true,
    ),
    const _RecipeSeed(
      'sweet-potato-wedges',
      'Sweet Potato Wedges',
      'Snack',
      'luteal',
      'Contemporary',
      ['sweet potato', 'vegetable oil'],
      [],
      ['complex carbohydrate'],
      10,
      20,
      true,
    ),
    const _RecipeSeed(
      'fruit-salad',
      'Fruit Salad',
      'Snack',
      'ovulation',
      'Contemporary',
      ['watermelon', 'pawpaw', 'banana'],
      [],
      ['fruit', 'hydrating foods'],
      12,
      0,
      true,
    ),
    const _RecipeSeed(
      'watermelon-groundnuts',
      'Watermelon and Groundnuts',
      'Snack',
      'ovulation',
      'Pan-Nigerian',
      ['watermelon', 'groundnuts'],
      ['peanut'],
      ['fruit', 'healthy fat'],
      5,
      0,
      true,
    ),
    const _RecipeSeed(
      'pawpaw-yoghurt',
      'Pawpaw and Yoghurt Bowl',
      'Snack',
      'follicular',
      'Contemporary',
      ['pawpaw', 'yoghurt'],
      ['dairy'],
      ['fruit', 'protein'],
      8,
      0,
      false,
    ),
    const _RecipeSeed(
      'apple-groundnut-butter',
      'Apple and Groundnut Butter',
      'Snack',
      'luteal',
      'Contemporary',
      ['apple', 'groundnut butter'],
      ['peanut'],
      ['fruit', 'healthy fat'],
      5,
      0,
      true,
    ),
  ];
  return seeds.map(_buildRecipe).toList(growable: false);
}

class _RecipeSeed {
  final String id;
  final String title;
  final String mealType;
  final String phase;
  final String region;
  final List<String> coreIngredients;
  final List<String> allergens;
  final List<String> nutritionTags;
  final int prep;
  final int cook;
  final bool vegetarian;

  const _RecipeSeed(
    this.id,
    this.title,
    this.mealType,
    this.phase,
    this.region,
    this.coreIngredients,
    this.allergens,
    this.nutritionTags,
    this.prep,
    this.cook,
    this.vegetarian,
  );
}

NigerianRecipe _buildRecipe(_RecipeSeed seed) {
  final ingredients = _ingredientsFor(seed);
  final tags = {...seed.nutritionTags, ..._nutritionFromIngredients(seed)};
  return NigerianRecipe(
    id: seed.id,
    title: seed.title,
    mealType: seed.mealType,
    targetPhase: _phaseTitle(seed.phase),
    description:
        '${seed.title} is a balanced ${seed.region} ${seed.mealType.toLowerCase()} option built around ${seed.coreIngredients.take(3).join(', ')}.',
    keyNutrients: tags.take(4).join(', '),
    region: seed.region,
    prepMinutes: seed.prep,
    cookMinutes: seed.cook,
    servings: seed.mealType == 'Snack' ? 1 : 2,
    ingredients: ingredients,
    instructions: _stepsFor(seed, ingredients),
    nutritionTags: tags.toList(growable: false),
    cyclePhaseTags: {seed.phase, 'all'}.toList(growable: false),
    dietaryTags: seed.vegetarian ? const ['Vegetarian'] : const ['Flexible'],
    allergenTags: seed.allergens,
    proteinSources: _proteins(seed.coreIngredients),
    healthyFatSources: _healthyFats(seed.coreIngredients),
    ironRich:
        seed.phase == 'menstrual' ||
        seed.coreIngredients.any(
          (item) => [
            'beans',
            'ugu',
            'spinach',
            'efo leaves',
            'bitterleaf',
          ].contains(item),
        ),
    highFibre:
        seed.coreIngredients.any(
          (item) => [
            'beans',
            'oats',
            'brown rice',
            'sweet potato',
            'plantain',
            'vegetables',
          ].contains(item),
        ) ||
        tags.contains('fibre'),
    complexCarbohydrate: seed.coreIngredients.any(
      (item) => [
        'rice',
        'yam',
        'sweet potato',
        'plantain',
        'oats',
        'beans',
        'millet pap',
        'corn pap',
      ].contains(item),
    ),
    budgetLevel: _budgetFor(seed),
    difficulty: seed.cook > 35 ? 'Moderate' : 'Easy',
    substitutions: _substitutions(seed),
    servingSuggestions: [
      'Serve warm and portion according to appetite.',
      if (seed.mealType != 'Snack')
        'Pair with water and extra vegetables where available.',
    ],
  );
}

List<MealIngredient> _ingredientsFor(_RecipeSeed seed) {
  final items = <MealIngredient>[
    for (final ingredient in seed.coreIngredients)
      MealIngredient(
        name: ingredient,
        quantity: _quantityFor(ingredient, seed.mealType),
        unit: _unitFor(ingredient),
        preparation: _prepFor(ingredient),
        category: _categoryFor(ingredient),
      ),
  ];
  if (seed.mealType != 'Snack') {
    items.addAll(const [
      MealIngredient(
        name: 'onion',
        quantity: 1,
        unit: 'medium',
        preparation: 'sliced',
        category: 'Vegetable',
      ),
      MealIngredient(
        name: 'vegetable oil',
        quantity: 2,
        unit: 'tbsp',
        category: 'Oil',
      ),
      MealIngredient(
        name: 'salt',
        quantity: 0.5,
        unit: 'tsp',
        category: 'Seasoning',
      ),
      MealIngredient(
        name: 'water or light stock',
        quantity: 1,
        unit: 'cup',
        category: 'Liquid',
      ),
    ]);
  }
  return items;
}

List<RecipeStep> _stepsFor(_RecipeSeed seed, List<MealIngredient> ingredients) {
  final core = seed.coreIngredients.join(', ');
  if (seed.mealType == 'Snack' && seed.cook == 0) {
    return [
      RecipeStep(
        stepNumber: 1,
        title: 'Prepare',
        instruction:
            'Rinse or wipe the ingredients, then portion $core into a clean bowl or plate.',
        estimatedMinutes: seed.prep,
      ),
      const RecipeStep(
        stepNumber: 2,
        title: 'Serve',
        instruction:
            'Serve immediately so the fruit or fresh ingredients keep their texture.',
        estimatedMinutes: 1,
      ),
    ];
  }
  return [
    RecipeStep(
      stepNumber: 1,
      title: 'Prepare the ingredients',
      instruction:
          'Rinse, chop, blend, or portion the listed ingredients: ${ingredients.map((i) => i.name).take(8).join(', ')}.',
      estimatedMinutes: seed.prep,
    ),
    const RecipeStep(
      stepNumber: 2,
      title: 'Start gently',
      instruction:
          'Warm the pot or pan over medium heat, add the measured oil where used, then cook the onion until it smells sweet and looks slightly translucent.',
      estimatedMinutes: 3,
    ),
    RecipeStep(
      stepNumber: 3,
      title: 'Build the base',
      instruction:
          'Add the prepared main ingredients for ${seed.title}. Stir so the vegetables, grains, legumes, or protein are coated evenly.',
      estimatedMinutes: 5,
    ),
    RecipeStep(
      stepNumber: 4,
      title: 'Cook through',
      instruction:
          'Add the measured water or light stock in small amounts as needed. Cover partly and cook over low to medium heat until the grains, legumes, tubers, or protein are tender and the sauce is no longer watery.',
      estimatedMinutes: seed.cook > 0
          ? (seed.cook * 0.6).round().clamp(5, 30)
          : 3,
    ),
    const RecipeStep(
      stepNumber: 5,
      title: 'Adjust seasoning',
      instruction:
          'Taste carefully, adjust salt lightly, and simmer uncovered for a few minutes if the sauce needs to thicken.',
      estimatedMinutes: 4,
    ),
    RecipeStep(
      stepNumber: 6,
      title: 'Serve',
      instruction:
          'Serve ${seed.title} warm. Keep portions moderate and add extra vegetables if available.',
      estimatedMinutes: 2,
    ),
  ];
}

String _phaseTitle(String phase) => switch (phase) {
  'menstrual' => 'Menstrual',
  'follicular' => 'Follicular',
  'ovulation' => 'Ovulation',
  'luteal' => 'Luteal',
  _ => 'All',
};

Set<String> _nutritionFromIngredients(_RecipeSeed seed) {
  final tags = <String>{};
  for (final item in seed.coreIngredients) {
    if ([
      'beans',
      'moi moi',
      'eggs',
      'chicken',
      'fish',
      'beef',
      'sardines',
    ].contains(item)) {
      tags.add('protein');
    }
    if ([
      'ugu',
      'spinach',
      'efo leaves',
      'waterleaf',
      'bitterleaf',
      'okra',
      'cabbage',
      'carrots',
    ].contains(item)) {
      tags.add('vegetables');
    }
    if ([
      'rice',
      'yam',
      'plantain',
      'sweet potato',
      'oats',
      'spaghetti',
      'brown rice',
    ].contains(item)) {
      tags.add('complex carbohydrate');
    }
    if ([
      'groundnuts',
      'egusi',
      'ogbono',
      'avocado',
      'coconut',
    ].contains(item)) {
      tags.add('healthy fat');
    }
  }
  return tags;
}

List<String> _proteins(List<String> ingredients) => ingredients
    .where(
      (item) => [
        'beans',
        'moi moi',
        'eggs',
        'chicken',
        'fish',
        'beef',
        'sardines',
        'mushrooms',
        'yoghurt',
      ].contains(item),
    )
    .toList(growable: false);

List<String> _healthyFats(List<String> ingredients) => ingredients
    .where(
      (item) => [
        'groundnuts',
        'egusi',
        'ogbono',
        'avocado',
        'coconut',
        'groundnut butter',
      ].contains(item),
    )
    .toList(growable: false);

List<String> _substitutions(_RecipeSeed seed) {
  final substitutions = <String>[];
  if (seed.allergens.contains('fish')) {
    substitutions.add(
      'Use mushrooms or beans instead of fish if fish is excluded.',
    );
  }
  if (seed.allergens.contains('egg')) {
    substitutions.add(
      'Use moi moi, beans, or tofu-style bean cake where eggs are excluded.',
    );
  }
  if (seed.allergens.contains('peanut')) {
    substitutions.add(
      'Use coconut flakes or roasted chickpeas where groundnuts are excluded.',
    );
  }
  if (substitutions.isEmpty) {
    substitutions.add('Adjust pepper level and vegetable quantity to taste.');
  }
  return substitutions;
}

String _budgetFor(_RecipeSeed seed) {
  if (seed.coreIngredients.any(
    (item) => ['beef', 'chicken', 'fish', 'sardines'].contains(item),
  )) {
    return 'Moderate';
  }
  if (seed.coreIngredients.any(
    (item) => [
      'beans',
      'yam',
      'sweet potato',
      'plantain',
      'rice',
      'oats',
    ].contains(item),
  )) {
    return 'Economical';
  }
  return 'Flexible';
}

double _quantityFor(String ingredient, String mealType) {
  if (mealType == 'Snack') return 1;
  if ([
    'rice',
    'beans',
    'oats',
    'spaghetti',
    'brown rice',
    'ofada rice',
  ].contains(ingredient)) {
    return 1;
  }
  if (['chicken', 'fish', 'beef'].contains(ingredient)) return 2;
  if (['eggs'].contains(ingredient)) return 2;
  if (['tomatoes', 'carrots', 'green beans'].contains(ingredient)) return 2;
  return 1;
}

String _unitFor(String ingredient) {
  if ([
    'rice',
    'beans',
    'oats',
    'spaghetti',
    'brown rice',
    'ofada rice',
    'egusi',
    'ogbono',
    'groundnuts',
  ].contains(ingredient)) {
    return 'cup';
  }
  if (['vegetable oil'].contains(ingredient)) return 'tbsp';
  if (['salt'].contains(ingredient)) return 'tsp';
  if ([
    'chicken',
    'fish',
    'beef',
    'eggs',
    'tomatoes',
    'carrots',
    'banana',
    'plantain',
    'yam',
    'sweet potato',
  ].contains(ingredient)) {
    return ingredient == 'eggs' ? 'large' : 'medium';
  }
  return 'portion';
}

String _prepFor(String ingredient) {
  if (['tomatoes', 'red bell pepper', 'pepper sauce'].contains(ingredient)) {
    return 'blended or chopped';
  }
  if ([
    'rice',
    'beans',
    'oats',
    'spaghetti',
    'brown rice',
    'ofada rice',
  ].contains(ingredient)) {
    return 'rinsed';
  }
  if ([
    'yam',
    'sweet potato',
    'plantain',
    'unripe plantain',
  ].contains(ingredient)) {
    return 'peeled and cut';
  }
  if ([
    'ugu',
    'spinach',
    'waterleaf',
    'efo leaves',
    'bitterleaf',
    'cabbage',
  ].contains(ingredient)) {
    return 'washed and sliced';
  }
  return '';
}

String _categoryFor(String ingredient) {
  if ([
    'rice',
    'beans',
    'oats',
    'spaghetti',
    'brown rice',
    'ofada rice',
    'yam',
    'plantain',
    'sweet potato',
  ].contains(ingredient)) {
    return 'Staple';
  }
  if ([
    'chicken',
    'fish',
    'beef',
    'eggs',
    'sardines',
    'moi moi',
    'yoghurt',
  ].contains(ingredient)) {
    return 'Protein';
  }
  if ([
    'ugu',
    'spinach',
    'waterleaf',
    'efo leaves',
    'bitterleaf',
    'okra',
    'cabbage',
    'carrots',
    'tomatoes',
  ].contains(ingredient)) {
    return 'Vegetable';
  }
  return 'General';
}

bool _matchesDiet(NigerianRecipe recipe, String? dietaryPattern) {
  final lower = dietaryPattern?.toLowerCase() ?? '';
  if (lower.contains('vegetarian') && !recipe.isVegetarian) return false;
  return true;
}

Set<String> _allergensFromDiet(String? dietaryPattern) {
  final lower = dietaryPattern?.toLowerCase() ?? '';
  return {
    if (lower.contains('no dairy') || lower.contains('dairy-free')) 'dairy',
    if (lower.contains('no egg') || lower.contains('egg-free')) 'egg',
    if (lower.contains('no fish') || lower.contains('fish-free')) 'fish',
    if (lower.contains('groundnut') || lower.contains('peanut')) 'peanut',
  };
}

bool _hasExcludedAllergen(NigerianRecipe recipe, Set<String> exclusions) {
  if (exclusions.isEmpty) return false;
  final ingredientText = recipe.ingredients
      .map((item) => item.name)
      .join(' ')
      .toLowerCase();
  return exclusions.any((allergen) {
    final normalized = _normalizeAllergen(allergen);
    return recipe.allergenTags.map(_normalizeAllergen).contains(normalized) ||
        ingredientText.contains(normalized);
  });
}

bool _containsDislikedFood(NigerianRecipe recipe, Set<String> dislikes) {
  if (dislikes.isEmpty) return false;
  final ingredientText = recipe.ingredients
      .map((item) => item.name)
      .join(' ')
      .toLowerCase();
  return dislikes.any(ingredientText.contains);
}

int _regionScore(NigerianRecipe recipe, String? preferredRegion) {
  final pref = preferredRegion?.toLowerCase();
  if (pref == null || pref.contains('all') || pref.contains('pan')) return 0;
  return recipe.region.toLowerCase().contains(pref) ? 1 : 0;
}

int _stableTiebreak(DateTime date, String id) {
  final seed = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  return Object.hash(seed, id).abs() % 41;
}

String _normalizeToken(String value) => value.trim().toLowerCase();

String _normalizeAllergen(String value) {
  final lower = _normalizeToken(value);
  if (lower.contains('groundnut') || lower.contains('peanut')) return 'peanut';
  if (lower.contains('egg')) return 'egg';
  if (lower.contains('fish') ||
      lower.contains('sardine') ||
      lower.contains('stockfish')) {
    return 'fish';
  }
  if (lower.contains('dairy') ||
      lower.contains('milk') ||
      lower.contains('yoghurt')) {
    return 'dairy';
  }
  if (lower.contains('shellfish') ||
      lower.contains('crayfish') ||
      lower.contains('prawn') ||
      lower.contains('crab')) {
    return 'shellfish';
  }
  return lower;
}
