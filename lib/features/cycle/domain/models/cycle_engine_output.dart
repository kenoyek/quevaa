import '../../../../core/models/prediction_confidence.dart';
import 'current_cycle_snapshot.dart';
import 'date_range.dart';
import 'estimated_cycle_phase.dart';
import 'period_prediction.dart';

enum CycleMode {
  standard,
  irregular,
  hormonalContraception,
  pregnancy,
  postpartum,
}


class ProjectedPeriod {
  final DateTime min;
  final DateTime max;

  const ProjectedPeriod({required this.min, required this.max});
}

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
  final bool hasEnoughData;
  final String disclaimer;
  final List<ProjectedPeriod> nextCycles;
  final List<PeriodPrediction> periodPredictions;

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
    this.hasEnoughData = true,
    this.nextCycles = const [],
    this.periodPredictions = const [],
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

  CurrentCycleSnapshot toSnapshot(
    DateTime asOfDate, {
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    bool isPeriodActive = false,
    bool isTtcEnabled = false,
  }) {
    return CurrentCycleSnapshot(
      asOfDate: asOfDate,
      currentPeriodStart: currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd,
      cycleDay: hasEnoughData ? currentCycleDay : null,
      phase: EstimatedCyclePhaseLabel.fromString(estimatedPhase),
      nextPeriodRange: DateRange(
        start: estimatedPeriodStartMin,
        end: estimatedPeriodStartMax,
      ),
      fertileWindowRange: DateRange(
        start: fertileWindowStart,
        end: fertileWindowEnd,
      ),
      ovulationRange: DateRange(
        start: estimatedOvulationStart,
        end: estimatedOvulationEnd,
      ),
      confidence: confidence,
      hasEnoughData: hasEnoughData,
      isPeriodActive: isPeriodActive,
      isTtcEnabled: isTtcEnabled,
    );
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
