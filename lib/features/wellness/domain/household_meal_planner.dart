import '../../nutrition/data/nigerian_recipe_database.dart';

enum FamilyAgeGroup { adult, teen, child }

class HouseholdProfileModel {
  final String householdName;
  final int adults;
  final int children;
  final int defaultServings;
  final List<String> dietaryPreferences;
  final List<String> allergens;
  final List<String> dislikedIngredients;
  final int weekdayPrepLimitMinutes;
  final int weekendPrepLimitMinutes;
  final int avoidRepeatDinnerDays;
  final double? weeklyBudget;
  final double? monthlyBudget;

  const HouseholdProfileModel({
    this.householdName = '',
    this.adults = 1,
    this.children = 0,
    this.defaultServings = 2,
    this.dietaryPreferences = const [],
    this.allergens = const [],
    this.dislikedIngredients = const [],
    this.weekdayPrepLimitMinutes = 45,
    this.weekendPrepLimitMinutes = 90,
    this.avoidRepeatDinnerDays = 4,
    this.weeklyBudget,
    this.monthlyBudget,
  });

  int get householdSize => adults + children;

  int get effectiveServings {
    if (defaultServings > 0) return defaultServings;
    return householdSize <= 0 ? 1 : householdSize;
  }

  Set<String> get normalizedAllergens =>
      allergens.map(IngredientNormalizer.normalizeToken).toSet();
}

class FamilyMemberModel {
  final String id;
  final String name;
  final FamilyAgeGroup ageGroup;
  final List<String> dietaryPreferences;
  final List<String> allergens;
  final List<String> dislikedIngredients;
  final String notes;
  final bool active;

  const FamilyMemberModel({
    required this.id,
    required this.name,
    this.ageGroup = FamilyAgeGroup.adult,
    this.dietaryPreferences = const [],
    this.allergens = const [],
    this.dislikedIngredients = const [],
    this.notes = '',
    this.active = true,
  });
}

class PantryInventoryItem {
  final String ingredientId;
  final String displayName;
  final double quantity;
  final String unit;
  final String category;
  final DateTime? expiryDate;
  final double? minimumStockLevel;
  final String storageLocation;
  final bool opened;

  const PantryInventoryItem({
    required this.ingredientId,
    required this.displayName,
    required this.quantity,
    required this.unit,
    this.category = 'Other',
    this.expiryDate,
    this.minimumStockLevel,
    this.storageLocation = 'Pantry',
    this.opened = false,
  });

  bool get isExpired {
    final expiry = expiryDate;
    if (expiry == null) return false;
    return normalizeDate(expiry).isBefore(normalizeDate(DateTime.now()));
  }

  bool get lowStock {
    final minimum = minimumStockLevel;
    return minimum != null && quantity < minimum;
  }

  bool useSoon(DateTime today) {
    final expiry = expiryDate;
    if (expiry == null || isExpired) return false;
    return normalizeDate(
          expiry,
        ).difference(normalizeDate(today)).inDays.clamp(0, 999) <=
        3;
  }
}

class PlannedMealSlot {
  final DateTime date;
  final String mealType;
  final NigerianRecipe recipe;
  final int servings;
  final List<String> selectedMemberIds;
  final String notes;
  final String status;

  const PlannedMealSlot({
    required this.date,
    required this.mealType,
    required this.recipe,
    required this.servings,
    this.selectedMemberIds = const [],
    this.notes = '',
    this.status = 'planned',
  });
}

class WeeklyPlanSummary {
  final DateTime weekStart;
  final List<PlannedMealSlot> slots;
  final int pantryFirstMeals;
  final int expiringIngredientMeals;
  final List<String> prepHeavyDays;

  const WeeklyPlanSummary({
    required this.weekStart,
    required this.slots,
    required this.pantryFirstMeals,
    required this.expiringIngredientMeals,
    required this.prepHeavyDays,
  });

  int get plannedMeals => slots.length;
  int get uniqueRecipeCount =>
      slots.map((slot) => slot.recipe.id).toSet().length;
  int get totalServings => slots.fold(0, (sum, slot) => sum + slot.servings);
}

class MonthlyPlanSummary {
  final DateTime monthStart;
  final List<WeeklyPlanSummary> weeks;
  final Map<String, List<ShoppingRequirement>> weeklyFreshWindows;
  final List<ShoppingRequirement> monthlyStaples;

  const MonthlyPlanSummary({
    required this.monthStart,
    required this.weeks,
    required this.weeklyFreshWindows,
    required this.monthlyStaples,
  });

  int get plannedMeals => weeks.fold(0, (sum, week) => sum + week.plannedMeals);
}

class ShoppingRequirement {
  final String ingredientId;
  final String displayName;
  final double quantity;
  final String unit;
  final String category;
  final List<String> sourceRecipeIds;
  final String sourceType;

  const ShoppingRequirement({
    required this.ingredientId,
    required this.displayName,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.sourceRecipeIds,
    this.sourceType = 'weeklyPlan',
  });

  String get quantityLabel => IngredientNormalizer.formatQuantity(quantity);
}

class PantryCoverage {
  final int totalIngredients;
  final int fullyCovered;
  final List<ShoppingRequirement> missing;

  const PantryCoverage({
    required this.totalIngredients,
    required this.fullyCovered,
    required this.missing,
  });

  int get percent => totalIngredients == 0
      ? 0
      : ((fullyCovered / totalIngredients) * 100).round();
}

class HouseholdMealPlanner {
  const HouseholdMealPlanner();

  WeeklyPlanSummary generateWeek({
    required DateTime weekStart,
    required HouseholdProfileModel household,
    required List<FamilyMemberModel> members,
    required List<PantryInventoryItem> pantry,
    String cyclePhase = 'all',
    Set<String> savedMealIds = const {},
    Set<String> recentlyPreparedMealIds = const {},
    List<String> mealTypes = const ['Breakfast', 'Lunch', 'Dinner'],
  }) {
    final start = normalizeDate(weekStart);
    final activeMembers = members.where((member) => member.active).toList();
    final allergens = _householdAllergens(household, activeMembers);
    final dislikes = {
      ...household.dislikedIngredients.map(IngredientNormalizer.normalizeToken),
      for (final member in activeMembers)
        ...member.dislikedIngredients.map(IngredientNormalizer.normalizeToken),
    };
    final selected = <PlannedMealSlot>[];
    final dinnerHistory = <DateTime, String>{};
    final familyHistory = <DateTime, Set<String>>{};
    final selectedFamilies = <String>{};
    final recentFamilies = {
      for (final id in recentlyPreparedMealIds)
        if (NigerianRecipeDatabase.recipeById(id) case final recipe?)
          recipe.dishFamily,
    };
    var pantryFirstMeals = 0;
    var expiringIngredientMeals = 0;
    final prepHeavyDays = <String>{};

    for (var offset = 0; offset < 7; offset++) {
      final date = start.add(Duration(days: offset));
      for (final mealType in mealTypes) {
        final prepLimit = _prepLimitForDate(household, date);
        final ranked = _rankRecipes(
          date: date,
          mealType: mealType,
          household: household,
          pantry: pantry,
          cyclePhase: cyclePhase,
          savedMealIds: savedMealIds,
          recentlyPreparedMealIds: recentlyPreparedMealIds,
          selectedDishFamilies: selectedFamilies,
          recentDishFamilies: recentFamilies,
          allergens: allergens,
          dislikes: dislikes,
        ).where((recipe) => recipe.totalMinutes <= prepLimit + 15).toList();
        final recipe = _firstDiverseRecipe(
          ranked.isEmpty
              ? _rankRecipes(
                  date: date,
                  mealType: mealType,
                  household: household,
                  pantry: pantry,
                  cyclePhase: cyclePhase,
                  savedMealIds: savedMealIds,
                  recentlyPreparedMealIds: recentlyPreparedMealIds,
                  selectedDishFamilies: selectedFamilies,
                  recentDishFamilies: recentFamilies,
                  allergens: allergens,
                  dislikes: dislikes,
                )
              : ranked,
          mealType,
          date,
          dinnerHistory,
          familyHistory,
          household.avoidRepeatDinnerDays,
        );
        if (recipe == null) continue;
        if (mealType == 'Dinner') dinnerHistory[date] = recipe.id;
        selectedFamilies.add(recipe.dishFamily);
        familyHistory
            .putIfAbsent(date, () => <String>{})
            .add(recipe.dishFamily);
        final coverage = pantryCoverage(
          recipe: recipe,
          pantry: pantry,
          servings: household.effectiveServings,
        );
        if (coverage.percent >= 70) pantryFirstMeals++;
        if (_usesExpiringIngredient(recipe, pantry, date)) {
          expiringIngredientMeals++;
        }
        if (recipe.totalMinutes > prepLimit) {
          prepHeavyDays.add(_weekdayLabel(date));
        }
        selected.add(
          PlannedMealSlot(
            date: date,
            mealType: mealType,
            recipe: recipe,
            servings: household.effectiveServings,
            selectedMemberIds: activeMembers
                .map((member) => member.id)
                .toList(),
          ),
        );
      }
    }

    return WeeklyPlanSummary(
      weekStart: start,
      slots: selected,
      pantryFirstMeals: pantryFirstMeals,
      expiringIngredientMeals: expiringIngredientMeals,
      prepHeavyDays: prepHeavyDays.toList()..sort(),
    );
  }

  MonthlyPlanSummary generateMonth({
    required DateTime month,
    required HouseholdProfileModel household,
    required List<FamilyMemberModel> members,
    required List<PantryInventoryItem> pantry,
    String cyclePhase = 'all',
    Set<String> savedMealIds = const {},
    Set<String> recentlyPreparedMealIds = const {},
  }) {
    final monthStart = DateTime(month.year, month.month);
    final firstWeek = monthStart.subtract(
      Duration(days: (monthStart.weekday - DateTime.monday) % 7),
    );
    final weeks = <WeeklyPlanSummary>[];
    final previous = <String>{...recentlyPreparedMealIds};
    for (var week = 0; week < 5; week++) {
      final summary = generateWeek(
        weekStart: firstWeek.add(Duration(days: week * 7)),
        household: household,
        members: members,
        pantry: pantry,
        cyclePhase: cyclePhase,
        savedMealIds: savedMealIds,
        recentlyPreparedMealIds: previous,
      );
      weeks.add(summary);
      previous.addAll(summary.slots.map((slot) => slot.recipe.id));
    }

    final allRequirements = generateShoppingList(
      plannedMeals: weeks.expand((week) => week.slots).toList(),
      pantry: pantry,
      sourceType: 'monthlyPlan',
    );
    final staples = allRequirements
        .where((item) => _storageClass(item.category) == 'Shelf-stable')
        .toList();
    final freshWindows = <String, List<ShoppingRequirement>>{};
    for (final week in weeks) {
      final key = _shortDate(week.weekStart);
      freshWindows[key] =
          generateShoppingList(plannedMeals: week.slots, pantry: pantry)
              .where((item) => _storageClass(item.category) != 'Shelf-stable')
              .toList();
    }

    return MonthlyPlanSummary(
      monthStart: monthStart,
      weeks: weeks,
      monthlyStaples: staples,
      weeklyFreshWindows: freshWindows,
    );
  }

  List<ShoppingRequirement> generateShoppingList({
    required List<PlannedMealSlot> plannedMeals,
    required List<PantryInventoryItem> pantry,
    String sourceType = 'weeklyPlan',
  }) {
    final requirements = <_IngredientKey, _RequirementAccumulator>{};
    for (final slot in plannedMeals) {
      final scale = slot.servings / slot.recipe.servings;
      for (final ingredient in slot.recipe.ingredients) {
        if (ingredient.optional) continue;
        final id = IngredientNormalizer.ingredientId(ingredient.name);
        final unit = IngredientNormalizer.canonicalUnit(ingredient.unit);
        final converted = IngredientNormalizer.convert(
          ingredient.quantity * scale,
          ingredient.unit,
          unit,
        );
        final key = _IngredientKey(id, unit);
        final existing = requirements[key];
        if (existing == null) {
          requirements[key] = _RequirementAccumulator(
            displayName: IngredientNormalizer.displayName(ingredient.name),
            quantity: converted,
            category: normalizeCategory(ingredient.category),
            sourceRecipeIds: {slot.recipe.id},
          );
        } else {
          existing.quantity += converted;
          existing.sourceRecipeIds.add(slot.recipe.id);
        }
      }
    }

    final pantryByKey = <_IngredientKey, double>{};
    for (final item in pantry.where((item) => !item.isExpired)) {
      final id = item.ingredientId.isEmpty
          ? IngredientNormalizer.ingredientId(item.displayName)
          : item.ingredientId;
      final unit = IngredientNormalizer.canonicalUnit(item.unit);
      final key = _IngredientKey(id, unit);
      pantryByKey.update(
        key,
        (value) =>
            value +
            IngredientNormalizer.convert(item.quantity, item.unit, unit),
        ifAbsent: () =>
            IngredientNormalizer.convert(item.quantity, item.unit, unit),
      );
    }

    final output = <ShoppingRequirement>[];
    for (final entry in requirements.entries) {
      final available = pantryByKey[entry.key] ?? 0;
      final missing = entry.value.quantity - available;
      if (missing <= 0.0001) continue;
      output.add(
        ShoppingRequirement(
          ingredientId: entry.key.ingredientId,
          displayName: entry.value.displayName,
          quantity: missing,
          unit: entry.key.unit,
          category: entry.value.category,
          sourceRecipeIds: entry.value.sourceRecipeIds.toList()..sort(),
          sourceType: sourceType,
        ),
      );
    }
    output.sort((a, b) {
      final category = a.category.compareTo(b.category);
      if (category != 0) return category;
      return a.displayName.compareTo(b.displayName);
    });
    return output;
  }

  PantryCoverage pantryCoverage({
    required NigerianRecipe recipe,
    required List<PantryInventoryItem> pantry,
    required int servings,
  }) {
    final missing = generateShoppingList(
      plannedMeals: [
        PlannedMealSlot(
          date: DateTime.now(),
          mealType: recipe.mealType,
          recipe: recipe,
          servings: servings,
        ),
      ],
      pantry: pantry,
    );
    final total = recipe.ingredients.where((item) => !item.optional).length;
    final missingIds = missing.map((item) => item.ingredientId).toSet();
    final covered = recipe.ingredients
        .where(
          (ingredient) =>
              !ingredient.optional &&
              !missingIds.contains(
                IngredientNormalizer.ingredientId(ingredient.name),
              ),
        )
        .length;
    return PantryCoverage(
      totalIngredients: total,
      fullyCovered: covered,
      missing: missing,
    );
  }

  List<NigerianRecipe> _rankRecipes({
    required DateTime date,
    required String mealType,
    required HouseholdProfileModel household,
    required List<PantryInventoryItem> pantry,
    required String cyclePhase,
    required Set<String> savedMealIds,
    required Set<String> recentlyPreparedMealIds,
    required Set<String> selectedDishFamilies,
    required Set<String> recentDishFamilies,
    required Set<String> allergens,
    required Set<String> dislikes,
  }) {
    final pantryIds = pantry
        .where((item) => !item.isExpired)
        .map(
          (item) => item.ingredientId.isEmpty
              ? IngredientNormalizer.ingredientId(item.displayName)
              : item.ingredientId,
        )
        .toSet();
    final phaseKey = NigerianRecipeDatabase.phaseKeyForCyclePhase(cyclePhase);
    final scored = <({NigerianRecipe recipe, int score})>[];
    for (final recipe in NigerianRecipeDatabase.recipes) {
      if (recipe.mealType != mealType) continue;
      if (recipe.allergenTags
          .map(IngredientNormalizer.normalizeToken)
          .any(allergens.contains)) {
        continue;
      }
      if (_containsDislikedIngredient(recipe, dislikes)) continue;
      if (!_matchesHouseholdDiet(recipe, household.dietaryPreferences)) {
        continue;
      }
      var score = 60;
      final pantryMatches = recipe.ingredients
          .where(
            (ingredient) => pantryIds.contains(
              IngredientNormalizer.ingredientId(ingredient.name),
            ),
          )
          .length;
      score += pantryMatches * 8;
      score +=
          recipe.ingredients
              .where((ingredient) => _pantryUseSoon(ingredient, pantry, date))
              .length *
          10;
      if (savedMealIds.contains(recipe.id)) score += 12;
      if (recentlyPreparedMealIds.contains(recipe.id)) score -= 80;
      if (selectedDishFamilies.contains(recipe.dishFamily)) score -= 95;
      if (recentDishFamilies.contains(recipe.dishFamily)) score -= 55;
      if (recipe.cyclePhaseTags.contains(phaseKey)) score += 4;
      if (recipe.totalMinutes <= _prepLimitForDate(household, date)) score += 8;
      if (recipe.budgetLevel.toLowerCase().contains('budget')) score += 3;
      score += _stableTiebreak(date, recipe.id);
      scored.add((recipe: recipe, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.recipe.title.compareTo(b.recipe.title);
    });
    return scored.map((entry) => entry.recipe).toList(growable: false);
  }

  Set<String> _householdAllergens(
    HouseholdProfileModel household,
    List<FamilyMemberModel> members,
  ) {
    return {
      ...household.allergens.map(IngredientNormalizer.normalizeToken),
      for (final member in members)
        ...member.allergens.map(IngredientNormalizer.normalizeToken),
    };
  }

  bool _matchesHouseholdDiet(
    NigerianRecipe recipe,
    List<String> dietaryPreferences,
  ) {
    final prefs = dietaryPreferences.map(IngredientNormalizer.normalizeToken);
    if (prefs.contains('vegetarian') && !recipe.isVegetarian) return false;
    if (prefs.contains('nofish') &&
        recipe.allergenTags
            .map(IngredientNormalizer.normalizeToken)
            .contains('fish')) {
      return false;
    }
    if (prefs.contains('noegg') &&
        recipe.allergenTags
            .map(IngredientNormalizer.normalizeToken)
            .contains('egg')) {
      return false;
    }
    if (prefs.contains('nodairy') &&
        recipe.allergenTags
            .map(IngredientNormalizer.normalizeToken)
            .contains('dairy')) {
      return false;
    }
    if (prefs.contains('nogroundnuts') &&
        recipe.allergenTags
            .map(IngredientNormalizer.normalizeToken)
            .contains('peanut')) {
      return false;
    }
    return true;
  }

  bool _containsDislikedIngredient(
    NigerianRecipe recipe,
    Set<String> dislikes,
  ) {
    if (dislikes.isEmpty) return false;
    return recipe.ingredients.any(
      (ingredient) =>
          dislikes.contains(IngredientNormalizer.ingredientId(ingredient.name)),
    );
  }

  NigerianRecipe? _firstDiverseRecipe(
    List<NigerianRecipe> ranked,
    String mealType,
    DateTime date,
    Map<DateTime, String> dinnerHistory,
    Map<DateTime, Set<String>> familyHistory,
    int repeatDays,
  ) {
    if (ranked.isEmpty) return null;
    for (final recipe in ranked) {
      final repeatedDinner =
          mealType == 'Dinner' &&
          dinnerHistory.entries.any(
            (entry) =>
                entry.value == recipe.id &&
                date.difference(entry.key).inDays.abs() < repeatDays,
          );
      final repeatedFamily = familyHistory.entries.any(
        (entry) =>
            entry.value.contains(recipe.dishFamily) &&
            date.difference(entry.key).inDays.abs() < 4,
      );
      if (!repeatedDinner && !repeatedFamily) return recipe;
    }
    return ranked.first;
  }

  bool _usesExpiringIngredient(
    NigerianRecipe recipe,
    List<PantryInventoryItem> pantry,
    DateTime date,
  ) {
    return recipe.ingredients.any(
      (ingredient) => _pantryUseSoon(ingredient, pantry, date),
    );
  }

  bool _pantryUseSoon(
    MealIngredient ingredient,
    List<PantryInventoryItem> pantry,
    DateTime date,
  ) {
    final id = IngredientNormalizer.ingredientId(ingredient.name);
    return pantry.any((item) {
      final itemId = item.ingredientId.isEmpty
          ? IngredientNormalizer.ingredientId(item.displayName)
          : item.ingredientId;
      return itemId == id && item.useSoon(date);
    });
  }

  int _prepLimitForDate(HouseholdProfileModel household, DateTime date) {
    final weekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    return weekend
        ? household.weekendPrepLimitMinutes
        : household.weekdayPrepLimitMinutes;
  }

  String _storageClass(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('produce')) return 'Fresh';
    if (normalized.contains('protein') ||
        normalized.contains('meat') ||
        normalized.contains('fish') ||
        normalized.contains('dairy')) {
      return 'Refrigerated';
    }
    if (normalized.contains('frozen')) return 'Frozen';
    return 'Shelf-stable';
  }
}

class IngredientNormalizer {
  static String ingredientId(String value) {
    final token = normalizeToken(value);
    if (token.contains('groundnut')) return 'groundnuts';
    if (token.contains('peanut')) return 'groundnuts';
    if (token.contains('redonion')) return 'onion';
    if (token.endsWith('ies') && token.length > 4) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.endsWith('oes') && token.length > 4) {
      return token.substring(0, token.length - 2);
    }
    if (token.endsWith('s') && token.length > 3) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  static String normalizeToken(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
  }

  static String displayName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Ingredient';
    return clean[0].toUpperCase() + clean.substring(1);
  }

  static String canonicalUnit(String unit) {
    final normalized = unit.toLowerCase().trim();
    if (normalized == 'kilogram' ||
        normalized == 'kilograms' ||
        normalized == 'gram' ||
        normalized == 'grams' ||
        normalized == 'g') {
      return 'kg';
    }
    if (normalized == 'litre' ||
        normalized == 'liter' ||
        normalized == 'millilitre' ||
        normalized == 'milliliter' ||
        normalized == 'ml') {
      return 'L';
    }
    if (normalized == 'piece') return 'pieces';
    if (normalized == 'tin') return 'can';
    if (normalized == 'tins') return 'can';
    if (normalized.isEmpty || normalized == 'item') return 'pieces';
    return normalized;
  }

  static double convert(double quantity, String from, String to) {
    final rawSource = from.toLowerCase().trim();
    final rawTarget = to.toLowerCase().trim();
    if ((rawSource == 'g' || rawSource == 'gram' || rawSource == 'grams') &&
        canonicalUnit(to) == 'kg') {
      return quantity / 1000;
    }
    if ((rawSource == 'kg' ||
            rawSource == 'kilogram' ||
            rawSource == 'kilograms') &&
        (rawTarget == 'g' || rawTarget == 'gram' || rawTarget == 'grams')) {
      return quantity * 1000;
    }
    if ((rawSource == 'ml' ||
            rawSource == 'millilitre' ||
            rawSource == 'milliliter') &&
        canonicalUnit(to) == 'L') {
      return quantity / 1000;
    }
    if ((rawSource == 'l' ||
            rawSource == 'L' ||
            rawSource == 'litre' ||
            rawSource == 'liter') &&
        (rawTarget == 'ml' ||
            rawTarget == 'millilitre' ||
            rawTarget == 'milliliter')) {
      return quantity * 1000;
    }
    final source = canonicalUnit(from);
    final target = canonicalUnit(to);
    if (source == target) return quantity;
    return quantity;
  }

  static String formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
}

String normalizeCategory(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('produce') || lower.contains('vegetable')) {
    return 'Produce';
  }
  if (lower.contains('protein') ||
      lower.contains('meat') ||
      lower.contains('fish')) {
    return 'Meat/Fish';
  }
  if (lower.contains('grain') || lower.contains('staple')) {
    return 'Grains & Staples';
  }
  if (lower.contains('bean') || lower.contains('legume')) {
    return 'Beans & Legumes';
  }
  if (lower.contains('dairy')) return 'Dairy';
  if (lower.contains('spice') || lower.contains('season')) {
    return 'Spices & Seasonings';
  }
  if (lower.contains('frozen')) return 'Frozen';
  return value.trim().isEmpty ? 'Other' : value;
}

DateTime normalizeDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _stableTiebreak(DateTime date, String value) {
  final seed = '${date.year}-${date.month}-${date.day}-$value';
  return seed.codeUnits.fold(0, (sum, unit) => sum + unit) % 11;
}

String _weekdayLabel(DateTime date) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[date.weekday - 1];
}

String _shortDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _IngredientKey {
  final String ingredientId;
  final String unit;

  const _IngredientKey(this.ingredientId, this.unit);

  @override
  bool operator ==(Object other) {
    return other is _IngredientKey &&
        other.ingredientId == ingredientId &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(ingredientId, unit);
}

class _RequirementAccumulator {
  final String displayName;
  double quantity;
  final String category;
  final Set<String> sourceRecipeIds;

  _RequirementAccumulator({
    required this.displayName,
    required this.quantity,
    required this.category,
    required this.sourceRecipeIds,
  });
}
