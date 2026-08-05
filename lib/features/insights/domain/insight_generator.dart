class TransparentInsight {
  final String title;
  final String observation;
  final String context;
  final int minLogsRequired;

  const TransparentInsight({
    required this.title,
    required this.observation,
    required this.context,
    this.minLogsRequired = 3,
  });
}

class InsightGenerator {
  /// Generates non-causal transparent insights when minimum log thresholds are met.
  static List<TransparentInsight> generateInsights({
    required List<Map<String, dynamic>> loggedEntries,
  }) {
    if (loggedEntries.length < 3) {
      return []; // Enforce minimum data threshold requirement
    }

    final List<TransparentInsight> insights = [];

    // 1. Cramp observation on early period days
    final crampDays = loggedEntries
        .where((e) => (e['symptoms'] as List? ?? []).contains('Cramps'))
        .length;
    if (crampDays >= 2) {
      insights.add(
        TransparentInsight(
          title: 'Symptom Pattern',
          observation:
              'Cramps were logged on $crampDays of your recent period start days.',
          context:
              'Resting and warm tea during these days often appeared alongside better comfort in your logs.',
        ),
      );
    }

    // 2. Sleep duration & self-reported energy correlation
    final highEnergyGoodSleep = loggedEntries
        .where((e) => (e['sleepHours'] ?? 0) >= 7.5 && (e['energy'] ?? 0) >= 4)
        .length;
    if (highEnergyGoodSleep >= 2) {
      insights.add(
        const TransparentInsight(
          title: 'Energy & Sleep Observation',
          observation:
              'Higher self-reported energy and 7+ hours of sleep often appeared together in your logs.',
          context:
              'Tracking sleep patterns helps understand your natural recovery rhythm.',
        ),
      );
    }

    // 3. Hydration & mood observation
    final goodWaterDays = loggedEntries
        .where((e) => (e['waterGlasses'] ?? 0) >= 7)
        .length;
    if (goodWaterDays >= 2) {
      insights.add(
        const TransparentInsight(
          title: 'Hydration Rhythm',
          observation:
              'Reaching 7+ glasses of water was logged on 2+ days recently.',
          context:
              'Consistent hydration was logged alongside steady energy levels.',
        ),
      );
    }

    return insights;
  }
}
