import 'models/cycle_engine_output.dart';

class CyclePeriodRecord {
  final DateTime startDate;
  final DateTime? endDate;

  const CyclePeriodRecord({required this.startDate, this.endDate});
}

class CycleEngine {
  static const String acogDisclaimer =
      'Fertility window estimates are based on historical cycle length data and are not a form of contraception. Typical-use failure rates for fertility awareness methods vary, especially with cycle irregularity.';

  /// Calculates cycle predictions, ranges, confidence levels, and phase states.
  static CycleEngineOutput calculate({
    required List<CyclePeriodRecord> periodHistory,
    required DateTime targetDate,
    int userConfiguredAverageCycleLength = 28,
    int userConfiguredPeriodLength = 5,
    CycleMode mode = CycleMode.standard,
  }) {
    final normalizedTarget = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    // Sort periods chronologically
    final sortedPeriods = List<CyclePeriodRecord>.from(periodHistory)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // Handle special modes: Pregnancy & Postpartum
    if (mode == CycleMode.pregnancy || mode == CycleMode.postpartum) {
      return _buildSpecialModeOutput(
        mode,
        normalizedTarget,
        sortedPeriods,
        acogDisclaimer,
      );
    }

    if (sortedPeriods.isEmpty) {
      // Default fallback when no period history exists
      final periodStart = normalizedTarget.subtract(const Duration(days: 10));
      return _buildDefaultOutput(
        periodStart: periodStart,
        targetDate: normalizedTarget,
        cycleLength: userConfiguredAverageCycleLength,
        periodLength: userConfiguredPeriodLength,
        confidence: PredictionConfidence.low,
        mode: mode,
        disclaimer: acogDisclaimer,
      );
    }

    // 1. Calculate actual cycle lengths from start date differences
    final List<int> cycleLengths = [];
    final List<int> periodDurations = [];

    for (int i = 0; i < sortedPeriods.length - 1; i++) {
      final currentStart = sortedPeriods[i].startDate;
      final nextStart = sortedPeriods[i + 1].startDate;
      final length = nextStart.difference(currentStart).inDays;

      // Filter extreme outliers unless in irregular mode
      if (mode == CycleMode.irregular || (length >= 15 && length <= 60)) {
        cycleLengths.add(length);
      }

      if (sortedPeriods[i].endDate != null) {
        final duration =
            sortedPeriods[i].endDate!.difference(currentStart).inDays + 1;
        if (duration >= 1 && duration <= 14) {
          periodDurations.add(duration);
        }
      }
    }

    // 2. Compute Weighted Median Cycle Length
    final double medianCycle = _calculateWeightedMedian(
      cycleLengths,
      fallback: userConfiguredAverageCycleLength.toDouble(),
    );

    final double avgPeriodDuration = periodDurations.isNotEmpty
        ? periodDurations.reduce((a, b) => a + b) / periodDurations.length
        : userConfiguredPeriodLength.toDouble();

    final double variability = _calculateVariability(cycleLengths);

    // 3. Determine Confidence Level
    final PredictionConfidence confidence = _determineConfidence(
      usableCycleCount: cycleLengths.length,
      variability: variability,
      mode: mode,
    );

    // 4. Calculate Current Cycle Day & Phase
    final lastPeriodStart = sortedPeriods.last.startDate;
    final int currentCycleDay =
        normalizedTarget.difference(lastPeriodStart).inDays + 1;

    // 5. Compute Next Period & Ovulation Range Estimates
    final int baseLength = medianCycle.round();
    final DateTime nextPeriodCenter = lastPeriodStart.add(
      Duration(days: baseLength),
    );

    final int margin = (confidence == PredictionConfidence.high)
        ? 1
        : (confidence == PredictionConfidence.moderate)
        ? 2
        : (mode == CycleMode.irregular)
        ? 5
        : 3;

    final DateTime periodMin = nextPeriodCenter.subtract(
      Duration(days: margin),
    );
    final DateTime periodMax = nextPeriodCenter.add(Duration(days: margin));

    // Estimated Ovulation: typically 14 days before next expected period
    final DateTime ovulationCenter = nextPeriodCenter.subtract(
      const Duration(days: 14),
    );
    final DateTime ovulationMin = ovulationCenter.subtract(
      const Duration(days: 1),
    );
    final DateTime ovulationMax = ovulationCenter.add(const Duration(days: 1));

    // Fertile Window: 5 days before ovulation through 1 day afterwards (ACOG)
    final DateTime fertileStart = ovulationCenter.subtract(
      const Duration(days: 5),
    );
    final DateTime fertileEnd = ovulationCenter.add(const Duration(days: 1));

    // 6. Determine Current Cycle Phase
    final String currentPhase = _determinePhase(
      currentCycleDay: currentCycleDay,
      periodDuration: avgPeriodDuration.round(),
      ovulationDay: baseLength - 14,
      cycleLength: baseLength,
      mode: mode,
    );

    final int daysLate = normalizedTarget.isAfter(periodMax)
        ? normalizedTarget.difference(periodMax).inDays
        : 0;

    final bool isIrregularPattern =
        variability >= 4.5 || mode == CycleMode.irregular;

    return CycleEngineOutput(
      currentCycleDay: currentCycleDay < 1 ? 1 : currentCycleDay,
      estimatedPhase: currentPhase,
      estimatedPeriodStartMin: periodMin,
      estimatedPeriodStartMax: periodMax,
      estimatedOvulationStart: ovulationMin,
      estimatedOvulationEnd: ovulationMax,
      fertileWindowStart: fertileStart,
      fertileWindowEnd: fertileEnd,
      averageCycleLength: cycleLengths.isNotEmpty
          ? cycleLengths.reduce((a, b) => a + b) / cycleLengths.length
          : userConfiguredAverageCycleLength.toDouble(),
      medianCycleLength: medianCycle,
      averagePeriodDuration: avgPeriodDuration,
      cycleLengthVariability: variability,
      confidence: confidence,
      daysLate: daysLate,
      isIrregularPattern: isIrregularPattern,
      mode: mode,
      disclaimer: acogDisclaimer,
    );
  }

  static double _calculateWeightedMedian(
    List<int> values, {
    required double fallback,
  }) {
    if (values.isEmpty) return fallback;
    if (values.length == 1) return values.first.toDouble();

    // Give higher weight to recent cycles
    final List<double> weighted = [];
    for (int i = 0; i < values.length; i++) {
      final double weight = 1.0 + (i * 0.25);
      final int count = weight.round();
      for (int c = 0; c < count; c++) {
        weighted.add(values[i].toDouble());
      }
    }
    weighted.sort();
    final int middle = weighted.length ~/ 2;
    if (weighted.length % 2 == 1) {
      return weighted[middle];
    } else {
      return (weighted[middle - 1] + weighted[middle]) / 2.0;
    }
  }

  static double _calculateVariability(List<int> lengths) {
    if (lengths.length < 2) return 0.0;
    final double mean = lengths.reduce((a, b) => a + b) / lengths.length;
    double sumOfSquares = 0.0;
    for (final l in lengths) {
      sumOfSquares += (l - mean) * (l - mean);
    }
    return (sumOfSquares / lengths.length);
  }

  static PredictionConfidence _determineConfidence({
    required int usableCycleCount,
    required double variability,
    required CycleMode mode,
  }) {
    if (mode == CycleMode.irregular ||
        mode == CycleMode.hormonalContraception) {
      return PredictionConfidence.low;
    }
    if (usableCycleCount >= 6 && variability < 4.0) {
      return PredictionConfidence.high;
    }
    if (usableCycleCount >= 3 && variability < 7.0) {
      return PredictionConfidence.moderate;
    }
    return PredictionConfidence.low;
  }

  static String _determinePhase({
    required int currentCycleDay,
    required int periodDuration,
    required int ovulationDay,
    required int cycleLength,
    required CycleMode mode,
  }) {
    if (mode == CycleMode.hormonalContraception) {
      return currentCycleDay <= periodDuration
          ? 'Bleeding / Withdrawal'
          : 'Active Contraceptive';
    }
    if (currentCycleDay <= periodDuration) {
      return 'Menstrual';
    } else if (currentCycleDay < (ovulationDay - 2)) {
      return 'Follicular';
    } else if (currentCycleDay <= (ovulationDay + 2)) {
      return 'Estimated Ovulatory Window';
    } else {
      return 'Luteal';
    }
  }

  static CycleEngineOutput _buildSpecialModeOutput(
    CycleMode mode,
    DateTime targetDate,
    List<CyclePeriodRecord> history,
    String disclaimer,
  ) {
    final now = targetDate;
    final isPregnancy = mode == CycleMode.pregnancy;
    return CycleEngineOutput(
      currentCycleDay: isPregnancy ? 120 : 30,
      estimatedPhase: isPregnancy
          ? 'Pregnancy Mode (Predictions Paused)'
          : 'Postpartum Recovery',
      estimatedPeriodStartMin: now,
      estimatedPeriodStartMax: now.add(const Duration(days: 30)),
      estimatedOvulationStart: now,
      estimatedOvulationEnd: now,
      fertileWindowStart: now,
      fertileWindowEnd: now,
      averageCycleLength: 28,
      medianCycleLength: 28,
      averagePeriodDuration: 5,
      cycleLengthVariability: 0,
      confidence: PredictionConfidence.low,
      daysLate: 0,
      isIrregularPattern: true,
      mode: mode,
      disclaimer: isPregnancy
          ? 'Cycle predictions are paused during pregnancy mode.'
          : 'Standard fertility predictions are disabled during postpartum recovery.',
    );
  }

  static CycleEngineOutput _buildDefaultOutput({
    required DateTime periodStart,
    required DateTime targetDate,
    required int cycleLength,
    required int periodLength,
    required PredictionConfidence confidence,
    required CycleMode mode,
    required String disclaimer,
  }) {
    final nextMin = periodStart.add(Duration(days: cycleLength - 2));
    final nextMax = periodStart.add(Duration(days: cycleLength + 2));
    final ovCenter = periodStart.add(Duration(days: cycleLength - 14));

    return CycleEngineOutput(
      currentCycleDay: targetDate.difference(periodStart).inDays + 1,
      estimatedPhase: 'Follicular',
      estimatedPeriodStartMin: nextMin,
      estimatedPeriodStartMax: nextMax,
      estimatedOvulationStart: ovCenter.subtract(const Duration(days: 1)),
      estimatedOvulationEnd: ovCenter.add(const Duration(days: 1)),
      fertileWindowStart: ovCenter.subtract(const Duration(days: 5)),
      fertileWindowEnd: ovCenter.add(const Duration(days: 1)),
      averageCycleLength: cycleLength.toDouble(),
      medianCycleLength: cycleLength.toDouble(),
      averagePeriodDuration: periodLength.toDouble(),
      cycleLengthVariability: 0,
      confidence: confidence,
      daysLate: 0,
      isIrregularPattern: false,
      mode: mode,
      disclaimer: disclaimer,
    );
  }
}
