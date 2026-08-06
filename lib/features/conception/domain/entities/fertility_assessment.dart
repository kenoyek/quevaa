import '../../../../core/models/prediction_confidence.dart';

enum FertilityStatus {
  period,
  fertilityPreparing,
  fertilityRising,
  highFertility,
  peakFertilitySigns,
  ovulationLikelyPassed,
  waitingAndTesting,
}


extension FertilityStatusLabel on FertilityStatus {
  String get label {
    switch (this) {
      case FertilityStatus.period:
        return 'Period';
      case FertilityStatus.fertilityPreparing:
        return 'Fertility preparing';
      case FertilityStatus.fertilityRising:
        return 'Fertility rising';
      case FertilityStatus.highFertility:
        return 'High fertility';
      case FertilityStatus.peakFertilitySigns:
        return 'Peak fertility signs';
      case FertilityStatus.ovulationLikelyPassed:
        return 'Ovulation likely passed';
      case FertilityStatus.waitingAndTesting:
        return 'Waiting and testing';
    }
  }
}




class FertilityAssessment {
  final int cycleDay;
  final FertilityStatus status;
  final PredictionConfidence confidence;
  final DateTime ovulationRangeStart;
  final DateTime ovulationRangeEnd;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final DateTime expectedPeriodStart;
  final DateTime expectedPeriodEnd;
  final String explanation;
  final List<String> relevantObservations;
  final List<String> confidenceImprovements;
  final List<String> dailyChecklist;
  final String algorithmVersion;

  const FertilityAssessment({
    required this.cycleDay,
    required this.status,
    required this.confidence,
    required this.ovulationRangeStart,
    required this.ovulationRangeEnd,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.expectedPeriodStart,
    required this.expectedPeriodEnd,
    required this.explanation,
    required this.relevantObservations,
    required this.confidenceImprovements,
    required this.dailyChecklist,
    this.algorithmVersion = 'ttc-engine-v1',
  });
}
