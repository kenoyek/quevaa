import '../../../../core/models/prediction_confidence.dart';
import 'date_range.dart';
import 'estimated_cycle_phase.dart';
import 'period_prediction.dart';

class CurrentCycleSnapshot {
  final DateTime asOfDate;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final int? cycleDay;
  final EstimatedCyclePhase phase;
  final DateRange? nextPeriodRange;
  final DateRange? possibleStartRange;
  final PeriodPrediction? primaryPrediction;
  final DateRange? fertileWindowRange;
  final DateRange? ovulationRange;
  final PredictionConfidence confidence;
  final bool hasEnoughData;
  final bool isPeriodActive;
  final bool isTtcEnabled;
  final int calculationVersion;

  const CurrentCycleSnapshot({
    required this.asOfDate,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cycleDay,
    required this.phase,
    this.nextPeriodRange,
    this.possibleStartRange,
    this.primaryPrediction,
    this.fertileWindowRange,
    this.ovulationRange,
    required this.confidence,
    required this.hasEnoughData,
    required this.isPeriodActive,
    this.isTtcEnabled = false,
    this.calculationVersion = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrentCycleSnapshot &&
          runtimeType == other.runtimeType &&
          asOfDate == other.asOfDate &&
          currentPeriodStart == other.currentPeriodStart &&
          currentPeriodEnd == other.currentPeriodEnd &&
          cycleDay == other.cycleDay &&
          phase == other.phase &&
          nextPeriodRange == other.nextPeriodRange &&
          possibleStartRange == other.possibleStartRange &&
          primaryPrediction == other.primaryPrediction &&
          fertileWindowRange == other.fertileWindowRange &&
          ovulationRange == other.ovulationRange &&
          confidence == other.confidence &&
          hasEnoughData == other.hasEnoughData &&
          isPeriodActive == other.isPeriodActive &&
          isTtcEnabled == other.isTtcEnabled &&
          calculationVersion == other.calculationVersion;

  @override
  int get hashCode =>
      asOfDate.hashCode ^
      currentPeriodStart.hashCode ^
      currentPeriodEnd.hashCode ^
      cycleDay.hashCode ^
      phase.hashCode ^
      nextPeriodRange.hashCode ^
      possibleStartRange.hashCode ^
      primaryPrediction.hashCode ^
      fertileWindowRange.hashCode ^
      ovulationRange.hashCode ^
      confidence.hashCode ^
      hasEnoughData.hashCode ^
      isPeriodActive.hashCode ^
      isTtcEnabled.hashCode ^
      calculationVersion.hashCode;
}
