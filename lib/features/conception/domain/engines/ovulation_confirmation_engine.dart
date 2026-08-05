import '../entities/basal_temperature.dart';
import '../entities/fertility_observation.dart';

class OvulationConfirmationResult {
  final DateTime? likelyOvulationDate;
  final bool waitingForMoreTemperatures;
  final String explanation;

  const OvulationConfirmationResult({
    required this.likelyOvulationDate,
    required this.waitingForMoreTemperatures,
    required this.explanation,
  });
}

class OvulationConfirmationEngine {
  const OvulationConfirmationEngine();

  OvulationConfirmationResult evaluate(
    List<FertilityObservation> observations,
  ) {
    final temperatures =
        observations
            .map((entry) => entry.basalTemperature)
            .whereType<BasalTemperatureEntry>()
            .where((entry) => entry.isReliable)
            .toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    if (temperatures.length < 6) {
      return const OvulationConfirmationResult(
        likelyOvulationDate: null,
        waitingForMoreTemperatures: true,
        explanation:
            'Several valid waking temperatures are needed before Quevaa can look for a sustained shift.',
      );
    }

    for (var index = 3; index < temperatures.length - 2; index++) {
      final baseline =
          temperatures
              .sublist(index - 3, index)
              .map((entry) => entry.celsius)
              .reduce((a, b) => a + b) /
          3;
      final shifted = temperatures
          .sublist(index, index + 3)
          .every((entry) => entry.celsius >= baseline + 0.18);

      if (shifted) {
        return OvulationConfirmationResult(
          likelyOvulationDate: temperatures[index].measuredAt.subtract(
            const Duration(days: 1),
          ),
          waitingForMoreTemperatures: false,
          explanation:
              'A sustained temperature rise may indicate ovulation has already occurred.',
        );
      }
    }

    return const OvulationConfirmationResult(
      likelyOvulationDate: null,
      waitingForMoreTemperatures: true,
      explanation:
          'No sustained temperature shift is visible yet. One high reading is not enough to confirm ovulation.',
    );
  }
}
