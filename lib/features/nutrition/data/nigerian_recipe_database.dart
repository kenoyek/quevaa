class NigerianRecipe {
  final String title;
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final String targetPhase; // Menstrual, Follicular, Ovulation, Luteal
  final String description;
  final String keyNutrients;
  final String region;

  const NigerianRecipe({
    required this.title,
    required this.mealType,
    required this.targetPhase,
    required this.description,
    required this.keyNutrients,
    this.region = 'Pan-Nigerian',
  });
}

class NigerianRecipeDatabase {
  static const List<NigerianRecipe> recipes = [
    // Menstrual Phase (Iron & Magnesium)
    NigerianRecipe(
      title: 'Ugu & Unripe Plantain Porridge',
      mealType: 'Lunch',
      targetPhase: 'Menstrual',
      description:
          'Rich fluted pumpkin leaves (Ugu) cooked with iron-dense unripe plantain and dry fish.',
      keyNutrients: 'Iron, Magnesium & Fiber',
    ),
    NigerianRecipe(
      title: 'Stewed Beans & Roasted Plantain (Dodo)',
      mealType: 'Dinner',
      targetPhase: 'Menstrual',
      description:
          'Slow-cooked brown beans seasoned with palm oil and paired with ripe plantain.',
      keyNutrients: 'Plant Protein & Folate',
    ),
    NigerianRecipe(
      title: 'Fresh Snail Pepper Soup',
      mealType: 'Dinner',
      targetPhase: 'Menstrual',
      description:
          'Traditional aromatic pepper soup broth featuring iron-rich snail and indigenous herbs.',
      keyNutrients: 'Iron, Vitamin B12 & Zinc',
    ),
    NigerianRecipe(
      title: 'Unsweetened Zobo Infusion',
      mealType: 'Snack',
      targetPhase: 'Menstrual',
      description:
          'Hibiscus flower brew infused with fresh ginger, cloves, and natural pineapple peelings.',
      keyNutrients: 'Antioxidants & Vitamin C',
    ),

    // Follicular Phase (Light & Energizing)
    NigerianRecipe(
      title: 'Catfish Pepper Soup with Boiled Yam',
      mealType: 'Dinner',
      targetPhase: 'Follicular',
      description:
          'Light, comforting pepper soup with fresh catfish and soft boiled white yam.',
      keyNutrients: 'Omega-3 Fatty Acids & Complex Carbs',
    ),
    NigerianRecipe(
      title: 'Abacha (African Salad) with Ugba',
      mealType: 'Lunch',
      targetPhase: 'Follicular',
      description:
          'Fermented cassava shreds tossed with oil bean (Ugba), garden egg leaves, and dry fish.',
      keyNutrients: 'Probiotics & Phytoestrogens',
    ),
    NigerianRecipe(
      title: 'Warm Ogi (Pap) with Evaporated Milk',
      mealType: 'Breakfast',
      targetPhase: 'Follicular',
      description:
          'Smooth fermented maize porridge paired with akara or steamed moin moin.',
      keyNutrients: 'B-Vitamins & Gut Support',
    ),

    // Ovulation Phase (Antioxidants & Zinc)
    NigerianRecipe(
      title: 'Fresh Seafood Okra Soup',
      mealType: 'Dinner',
      targetPhase: 'Ovulation',
      description:
          'Crunchy chopped okra stewed with fresh prawns, crab, and spinach.',
      keyNutrients: 'Zinc, Selenium & Antioxidants',
    ),
    NigerianRecipe(
      title: 'Tigernut Milk (Kunu Aya)',
      mealType: 'Snack',
      targetPhase: 'Ovulation',
      description:
          'Chilled blended tigernut beverage naturally sweetened with dates and coconuts.',
      keyNutrients: 'Vitamin E, Fiber & Magnesium',
    ),
    NigerianRecipe(
      title: 'Steamed Okpa (Bambara Nut Pudding)',
      mealType: 'Breakfast',
      targetPhase: 'Ovulation',
      description:
          'Traditional Eastern Bambara flour pudding steamed with palm oil and yellow pepper.',
      keyNutrients: 'Essential Amino Acids & Zinc',
    ),

    // Luteal Phase (Complex Carbs & Serotonin Support)
    NigerianRecipe(
      title: 'Sweet Potato & Vegetable Fish Stew',
      mealType: 'Lunch',
      targetPhase: 'Luteal',
      description:
          'Naturally sweet boiled potato paired with rich tomato, spinach, and mackerel stew.',
      keyNutrients: 'Vitamin B6, Potassium & Complex Carbs',
    ),
    NigerianRecipe(
      title: 'Rich Egusi Soup with Spinach',
      mealType: 'Dinner',
      targetPhase: 'Luteal',
      description:
          'Melon seed soup simmered with smoked stockfish and leafy green vegetables.',
      keyNutrients: 'Healthy Fats & Serotonin Precursors',
    ),
  ];

  static List<NigerianRecipe> getForPhase(String phase) {
    return recipes
        .where((r) => r.targetPhase.toLowerCase() == phase.toLowerCase())
        .toList();
  }
}
