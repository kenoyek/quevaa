import '../entities/basal_temperature.dart';
import '../entities/cervical_mucus_entry.dart';
import '../entities/conception_profile.dart';
import '../entities/fertility_assessment.dart';
import '../entities/fertility_observation.dart';
import '../entities/ovulation_test.dart';

class ConfidenceEngine {
  const ConfidenceEngine();

  PredictionConfidence calculate({
    required ConceptionProfile profile,
    required List<FertilityObservation> observations,
  }) {
    var score = 0;

    if (profile.previousPeriodStartDates.length >= 3) score += 2;
    if (profile.cyclesUsuallyRegular) score += 1;
    if (_hasMucus(observations)) score += 1;
    if (_hasOvulationTests(observations)) score += 1;
    if (_reliableTemperatures(observations).length >= 4) score += 2;
    if (_signalsAgree(observations)) score += 1;

    if (!profile.cyclesUsuallyRegular) score -= 2;
    if (_recentContraceptionStop(profile)) score -= 1;
    if (_hasDisturbedTemperatures(observations)) score -= 1;
    if (_hasConflictingTests(observations)) score -= 1;
    if (observations.length < 3) score -= 1;
    if (observations.any((entry) => entry.illness)) score -= 1;

    if (score >= 6) return PredictionConfidence.high;
    if (score >= 3) return PredictionConfidence.moderate;
    return PredictionConfidence.low;
  }

  static bool _hasMucus(List<FertilityObservation> observations) {
    return observations.any((entry) => entry.cervicalMucus != null);
  }

  static bool _hasOvulationTests(List<FertilityObservation> observations) {
    return observations.any((entry) {
      final result = entry.ovulationTest?.result;
      return result != null && result != OvulationTestResult.notTaken;
    });
  }

  static List<BasalTemperatureEntry> _reliableTemperatures(
    List<FertilityObservation> observations,
  ) {
    return observations
        .map((entry) => entry.basalTemperature)
        .whereType<BasalTemperatureEntry>()
        .where((entry) => entry.isReliable)
        .toList();
  }

  static bool _hasDisturbedTemperatures(
    List<FertilityObservation> observations,
  ) {
    return observations.any((entry) {
      final temperature = entry.basalTemperature;
      return temperature != null && !temperature.isReliable;
    });
  }

  static bool _recentContraceptionStop(ConceptionProfile profile) {
    final stopped = profile.contraceptionStoppedDate;
    if (stopped == null) return false;
    return DateTime.now().difference(stopped).inDays < 90;
  }

  static bool _signalsAgree(List<FertilityObservation> observations) {
    final hasFertileMucus = observations.any(
      (entry) => entry.cervicalMucus?.type.isFertileQuality ?? false,
    );
    final hasPositiveTest = observations.any(
      (entry) =>
          entry.ovulationTest?.result.suggestsApproachingOvulation ?? false,
    );
    return hasFertileMucus && hasPositiveTest;
  }

  static bool _hasConflictingTests(List<FertilityObservation> observations) {
    final recent = observations.take(4).toList();
    final hasPositive = recent.any(
      (entry) =>
          entry.ovulationTest?.result == OvulationTestResult.positiveOrPeak,
    );
    final hasInvalid = recent.any(
      (entry) =>
          entry.ovulationTest?.result == OvulationTestResult.unclearOrInvalid,
    );
    return hasPositive && hasInvalid;
  }
}
