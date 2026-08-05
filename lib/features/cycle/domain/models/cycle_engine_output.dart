enum CycleMode {
  standard,
  irregular,
  hormonalContraception,
  pregnancy,
  postpartum,
}

enum PredictionConfidence { low, moderate, high }

class CycleEngineOutput {
  final int currentCycleDay;
  final String
  estimatedPhase; // Menstrual, Follicular, Estimated Ovulatory Window, Luteal
  final DateTime estimatedPeriodStartMin;
  final DateTime estimatedPeriodStartMax;
  final DateTime estimatedOvulationStart;
  final DateTime estimatedOvulationEnd;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final double averageCycleLength;
  final double medianCycleLength;
  final double averagePeriodDuration;
  final double cycleLengthVariability;
  final PredictionConfidence confidence;
  final int daysLate;
  final bool isIrregularPattern;
  final CycleMode mode;
  final String disclaimer;

  const CycleEngineOutput({
    required this.currentCycleDay,
    required this.estimatedPhase,
    required this.estimatedPeriodStartMin,
    required this.estimatedPeriodStartMax,
    required this.estimatedOvulationStart,
    required this.estimatedOvulationEnd,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.averageCycleLength,
    required this.medianCycleLength,
    required this.averagePeriodDuration,
    required this.cycleLengthVariability,
    required this.confidence,
    required this.daysLate,
    required this.isIrregularPattern,
    required this.mode,
    required this.disclaimer,
  });

  String get formattedPeriodRange {
    final startDay = estimatedPeriodStartMin.day;
    final endDay = estimatedPeriodStartMax.day;
    final monthStr = _monthName(estimatedPeriodStartMin.month);
    if (estimatedPeriodStartMin.month == estimatedPeriodStartMax.month) {
      return '$startDay–$endDay $monthStr';
    }
    return '$startDay ${_monthName(estimatedPeriodStartMin.month)} – $endDay ${_monthName(estimatedPeriodStartMax.month)}';
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
