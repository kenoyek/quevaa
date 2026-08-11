import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cycle/application/cycle_workspace_provider.dart';

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

final quickInsightsProvider = Provider<List<TransparentInsight>>((ref) {
  final logs = ref.watch(cycleLogsInRangeProvider).valueOrNull ?? [];
  final mappedLogs = logs.map((log) {
    List<String> symptoms = [];
    try {
      final decoded = jsonDecode(log.customSymptomsJson);
      if (decoded is List) {
        symptoms.addAll(decoded.map((e) => e.toString()));
      }
    } catch (_) {
      // Ignore malformed historical symptom payloads.
    }
    return {
      'symptoms': symptoms,
      'sleepHours': log.sleepHours,
      'energy': log.energyLevel,
      'waterGlasses': log.waterGlasses,
    };
  }).toList();

  return InsightGenerator.generateInsights(loggedEntries: mappedLogs);
});

class InsightGenerator {
  /// Generates non-causal transparent insights when minimum log thresholds are met.
  static List<TransparentInsight> generateInsights({
    required List<Map<String, dynamic>> loggedEntries,
  }) {
    if (loggedEntries.length < 3) {
      return const [];
    }

    final List<TransparentInsight> insights = [];

    // 1. Most frequently logged symptom observation.
    final symptomCounts = <String, int>{};
    for (final entry in loggedEntries) {
      for (final symptom in eSymptoms(entry)) {
        symptomCounts.update(symptom, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final topSymptom =
        symptomCounts.entries.where((entry) => entry.value >= 2).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    if (topSymptom.isNotEmpty) {
      final symptom = topSymptom.first.key;
      final count = topSymptom.first.value;
      insights.add(
        TransparentInsight(
          title: 'Symptom Pattern',
          observation:
              '$symptom was logged on $count of your recent tracked days.',
          context:
              'This is an observation from your Quevaa logs, not a diagnosis or cause.',
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

  static List<String> eSymptoms(Map<String, dynamic> entry) {
    final symptoms = entry['symptoms'];
    if (symptoms is! List) return const [];
    return symptoms
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
