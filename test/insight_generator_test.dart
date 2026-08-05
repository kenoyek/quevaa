import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/insights/domain/insight_generator.dart';

void main() {
  group('Phase 5: Insight Generator Unit Tests', () {
    test('Returns empty insights when fewer than 3 logs are available', () {
      final insufficientLogs = [
        {
          'symptoms': ['Cramps'],
          'sleepHours': 8,
          'energy': 4,
        },
        {
          'symptoms': ['Cramps'],
          'sleepHours': 7,
          'energy': 3,
        },
      ];

      final result = InsightGenerator.generateInsights(
        loggedEntries: insufficientLogs,
      );
      expect(result.isEmpty, true);
    });

    test('Generates transparent non-causal insights when 3+ logs exist', () {
      final sufficientLogs = [
        {
          'symptoms': ['Cramps'],
          'sleepHours': 8,
          'energy': 4,
          'waterGlasses': 8,
        },
        {
          'symptoms': ['Cramps'],
          'sleepHours': 7.5,
          'energy': 4,
          'waterGlasses': 8,
        },
        {'symptoms': [], 'sleepHours': 8, 'energy': 4, 'waterGlasses': 7},
      ];

      final result = InsightGenerator.generateInsights(
        loggedEntries: sufficientLogs,
      );
      expect(result.isNotEmpty, true);
      final hasNonCausalLanguage = result.any(
        (i) =>
            i.observation.contains('appeared together') ||
            i.observation.contains('logged on'),
      );
      expect(hasNonCausalLanguage, true);
    });
  });
}
