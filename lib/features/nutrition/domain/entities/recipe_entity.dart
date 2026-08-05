class RecipeEntity {
  final String id;
  final String name;
  final String alternativeNames;
  final String
  region; // Yoruba, Igbo, Hausa/Northern, South-South, Middle Belt, Contemporary
  final String mealType; // Breakfast, Lunch, Dinner, Snack, Soup, Swallow
  final List<String> ingredients;
  final Map<String, String> ingredientQuantities;
  final int servingSize;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final List<String> equipment;
  final String keyNutrients;
  final List<String> allergens; // Peanuts, Shellfish, Fish, Dairy, Soy, Eggs
  final List<String> dietaryTags; // Vegetarian, Low-Salt, Iron-Rich
  final String costCategory; // Budget, Moderate, Premium
  final String reviewer;
  final String contentVersion;

  const RecipeEntity({
    required this.id,
    required this.name,
    this.alternativeNames = '',
    required this.region,
    required this.mealType,
    required this.ingredients,
    required this.ingredientQuantities,
    this.servingSize = 4,
    this.prepTimeMinutes = 20,
    this.cookTimeMinutes = 30,
    this.equipment = const ['Pot', 'Stove'],
    required this.keyNutrients,
    this.allergens = const [],
    this.dietaryTags = const [],
    this.costCategory = 'Moderate',
    this.reviewer = 'Dr. K. Okonkwo (RD)',
    this.contentVersion = '1.0.0',
  });
}
