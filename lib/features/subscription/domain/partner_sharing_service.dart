class SharedSupportPayload {
  final bool sharePeriodExpectedDate;
  final String?
  supportPreference; // 'I need rest today', 'I would appreciate extra support'
  final bool shareMealPlan;
  final bool shareShoppingList;
  final bool shareWorkoutPlan;

  const SharedSupportPayload({
    this.sharePeriodExpectedDate = false,
    this.supportPreference,
    this.shareMealPlan = false,
    this.shareShoppingList = false,
    this.shareWorkoutPlan = false,
  });

  /// Serializes strictly non-intimate shared payload (journal, symptoms, and fertility are NEVER included).
  Map<String, dynamic> toSharableJson({required String expectedPeriodRange}) {
    final Map<String, dynamic> data = {};

    if (sharePeriodExpectedDate) {
      data['periodExpectedWindow'] = expectedPeriodRange;
    }
    if (supportPreference != null) {
      data['supportNote'] = supportPreference;
    }
    if (shareMealPlan) {
      data['mealPlanShared'] = true;
    }
    if (shareShoppingList) {
      data['shoppingListShared'] = true;
    }
    if (shareWorkoutPlan) {
      data['workoutPlanShared'] = true;
    }

    return data;
  }
}

class PartnerSharingService {
  /// Generates a revocable, time-limited, non-intimate sharing summary string.
  static String formatPartnerShareMessage({
    required SharedSupportPayload payload,
    required String expectedPeriodRange,
  }) {
    final List<String> lines = ['🌸 Quevaa Partner Update'];

    if (payload.supportPreference != null) {
      lines.add('• Note: "${payload.supportPreference}"');
    }
    if (payload.sharePeriodExpectedDate) {
      lines.add('• Period expected: $expectedPeriodRange');
    }
    if (payload.shareMealPlan) {
      lines.add('• Shared Nigerian meal plan updated');
    }
    if (payload.shareShoppingList) {
      lines.add('• Market shopping list updated');
    }

    return lines.join('\n');
  }
}
