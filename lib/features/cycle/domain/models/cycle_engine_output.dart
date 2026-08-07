import '../../../../core/models/prediction_confidence.dart';
import '../cycle_engine.dart';
import 'current_cycle_snapshot.dart';
import 'cycle_calendar_phase.dart';
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
    final primaryPred = periodPredictions.firstOrNull;
    return CurrentCycleSnapshot(
      asOfDate: asOfDate,
      currentPeriodStart: currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd,
      cycleDay: hasEnoughData ? currentCycleDay : null,
      phase: EstimatedCyclePhaseLabel.fromString(estimatedPhase),
      nextPeriodRange:
          primaryPred?.predictedBleedingRange ??
          DateRange(
            start: estimatedPeriodStartMin,
            end: estimatedPeriodStartMax,
          ),
      possibleStartRange: primaryPred?.possibleStartRange,
      primaryPrediction: primaryPred,
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

  /// Calculates the canonical estimated phase for any calendar date.
  CycleCalendarPhase getCalendarPhase(
    DateTime date, {
    List<CyclePeriodRecord> history = const [],
  }) {
    final d = DateTime(date.year, date.month, date.day);

    // 1. Confirmed period
    for (final p in history) {
      final start = DateTime(
        p.startDate.year,
        p.startDate.month,
        p.startDate.day,
      );
      final end = p.endDate != null
          ? DateTime(p.endDate!.year, p.endDate!.month, p.endDate!.day)
          : start;
      if (!d.isBefore(start) && !d.isAfter(end)) {
        return CycleCalendarPhase.menstrual;
      }
    }

    // 2. Central predicted bleeding range
    for (final pred in periodPredictions) {
      if (pred.isBleedingDay(d)) {
        return CycleCalendarPhase.menstrual;
      }
    }

    // 3. Estimated Ovulation window
    if (_isOvulationDay(d)) {
      return CycleCalendarPhase.estimatedOvulation;
    }

    // 4. Fertile window
    if (_isFertileDay(d)) {
      return CycleCalendarPhase.fertileWindow;
    }

    // 5. Phase based on cycle position relative to cycle start
    final allStarts = <DateTime>[
      ...history.map(
        (p) => DateTime(p.startDate.year, p.startDate.month, p.startDate.day),
      ),
      ...periodPredictions.map(
        (p) => DateTime(
          p.estimatedStartDate.year,
          p.estimatedStartDate.month,
          p.estimatedStartDate.day,
        ),
      ),
    ]..sort();

    final prevStart = allStarts.where((s) => !s.isAfter(d)).lastOrNull;

    if (prevStart != null) {
      final cycleDay = d.difference(prevStart).inDays + 1;
      final expectedDuration = averagePeriodDuration.round().clamp(1, 14);
      final cycleLen = medianCycleLength.round().clamp(15, 60);
      final ovulationDay = cycleLen - 14;
      final fertileStartDay = ovulationDay - 5;

      if (cycleDay <= expectedDuration) {
        return CycleCalendarPhase.menstrual;
      } else if (cycleDay < fertileStartDay) {
        return CycleCalendarPhase.follicular;
      } else if (cycleDay <= ovulationDay + 1) {
        if ((cycleDay - ovulationDay).abs() <= 1) {
          return CycleCalendarPhase.estimatedOvulation;
        }
        return CycleCalendarPhase.fertileWindow;
      } else {
        return CycleCalendarPhase.luteal;
      }
    }

    return CycleCalendarPhase.unknown;
  }

  bool _isOvulationDay(DateTime d) {
    final curOvuStart = DateTime(
      estimatedOvulationStart.year,
      estimatedOvulationStart.month,
      estimatedOvulationStart.day,
    );
    final curOvuEnd = DateTime(
      estimatedOvulationEnd.year,
      estimatedOvulationEnd.month,
      estimatedOvulationEnd.day,
    );
    if (!d.isBefore(curOvuStart) && !d.isAfter(curOvuEnd)) return true;

    for (final pred in periodPredictions) {
      final ovulationCenter = pred.estimatedStartDate.subtract(
        const Duration(days: 14),
      );
      final oStart = DateTime(
        ovulationCenter.year,
        ovulationCenter.month,
        ovulationCenter.day,
      ).subtract(const Duration(days: 1));
      final oEnd = DateTime(
        ovulationCenter.year,
        ovulationCenter.month,
        ovulationCenter.day,
      ).add(const Duration(days: 1));
      if (!d.isBefore(oStart) && !d.isAfter(oEnd)) return true;
    }
    return false;
  }

  bool _isFertileDay(DateTime d) {
    final curFertStart = DateTime(
      fertileWindowStart.year,
      fertileWindowStart.month,
      fertileWindowStart.day,
    );
    final curFertEnd = DateTime(
      fertileWindowEnd.year,
      fertileWindowEnd.month,
      fertileWindowEnd.day,
    );
    if (!d.isBefore(curFertStart) && !d.isAfter(curFertEnd)) return true;

    for (final pred in periodPredictions) {
      final ovulationCenter = pred.estimatedStartDate.subtract(
        const Duration(days: 14),
      );
      final fStart = DateTime(
        ovulationCenter.year,
        ovulationCenter.month,
        ovulationCenter.day,
      ).subtract(const Duration(days: 5));
      final fEnd = DateTime(
        ovulationCenter.year,
        ovulationCenter.month,
        ovulationCenter.day,
      ).add(const Duration(days: 1));
      if (!d.isBefore(fStart) && !d.isAfter(fEnd)) return true;
    }
    return false;
  }
}
