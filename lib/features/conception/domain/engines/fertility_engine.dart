import 'confidence_engine.dart';
import 'ovulation_confirmation_engine.dart';
import '../entities/cervical_mucus_entry.dart';
import '../entities/conception_profile.dart';
import '../entities/fertility_assessment.dart';
import '../entities/fertility_observation.dart';
import '../entities/ovulation_test.dart';

class FertilityEngine {
  final ConfidenceEngine confidenceEngine;
  final OvulationConfirmationEngine ovulationConfirmationEngine;

  const FertilityEngine({
    this.confidenceEngine = const ConfidenceEngine(),
    this.ovulationConfirmationEngine = const OvulationConfirmationEngine(),
  });

  FertilityAssessment assess({
    required ConceptionProfile profile,
    required List<FertilityObservation> observations,
    DateTime? targetDate,
  }) {
    final today = _dateOnly(targetDate ?? DateTime.now());
    final lastPeriod = _dateOnly(profile.lastPeriodStartDate);
    final cycleDay = today.difference(lastPeriod).inDays + 1;
    final expectedOvulation = lastPeriod.add(
      Duration(days: profile.typicalCycleLength - 14),
    );
    final ovulationStart = expectedOvulation.subtract(const Duration(days: 1));
    final ovulationEnd = expectedOvulation.add(const Duration(days: 1));
    final fertileStart = ovulationEnd.subtract(const Duration(days: 5));
    final expectedPeriodStart = lastPeriod.add(
      Duration(days: profile.typicalCycleLength),
    );
    final expectedPeriodEnd = expectedPeriodStart.add(const Duration(days: 2));

    final recentObservations = observations
        .where(
          (entry) =>
              !entry.date.isBefore(today.subtract(const Duration(days: 6))),
        )
        .toList();
    final hasFertileMucus = recentObservations.any(
      (entry) => entry.cervicalMucus?.type.isFertileQuality ?? false,
    );
    final hasPeakLh = recentObservations.any(
      (entry) =>
          entry.ovulationTest?.result == OvulationTestResult.positiveOrPeak,
    );
    final hasHighLh = recentObservations.any(
      (entry) =>
          entry.ovulationTest?.result.suggestsApproachingOvulation ?? false,
    );
    final confirmation = ovulationConfirmationEngine.evaluate(observations);
    final confidence = confidenceEngine.calculate(
      profile: profile,
      observations: observations,
    );

    final status = _statusFor(
      cycleDay: cycleDay,
      profile: profile,
      today: today,
      fertileStart: fertileStart,
      ovulationEnd: ovulationEnd,
      expectedPeriodStart: expectedPeriodStart,
      hasFertileMucus: hasFertileMucus,
      hasHighLh: hasHighLh,
      hasPeakLh: hasPeakLh,
      hasConfirmedShift: confirmation.likelyOvulationDate != null,
    );

    return FertilityAssessment(
      cycleDay: cycleDay,
      status: status,
      confidence: confidence,
      ovulationRangeStart: ovulationStart,
      ovulationRangeEnd: ovulationEnd,
      fertileWindowStart: fertileStart,
      fertileWindowEnd: ovulationEnd,
      expectedPeriodStart: expectedPeriodStart,
      expectedPeriodEnd: expectedPeriodEnd,
      explanation: _explanationFor(
        status: status,
        hasFertileMucus: hasFertileMucus,
        hasPeakLh: hasPeakLh,
        confirmation: confirmation,
      ),
      relevantObservations: _observationsFor(
        recentObservations: recentObservations,
        confirmation: confirmation,
      ),
      confidenceImprovements: _confidenceImprovementsFor(
        profile: profile,
        observations: observations,
      ),
      dailyChecklist: _dailyChecklistFor(profile),
    );
  }

  static FertilityStatus _statusFor({
    required int cycleDay,
    required ConceptionProfile profile,
    required DateTime today,
    required DateTime fertileStart,
    required DateTime ovulationEnd,
    required DateTime expectedPeriodStart,
    required bool hasFertileMucus,
    required bool hasHighLh,
    required bool hasPeakLh,
    required bool hasConfirmedShift,
  }) {
    if (cycleDay <= profile.typicalPeriodDuration) {
      return FertilityStatus.period;
    }
    if (hasConfirmedShift || today.isAfter(ovulationEnd)) {
      if (!today.isBefore(
        expectedPeriodStart.subtract(const Duration(days: 4)),
      )) {
        return FertilityStatus.waitingAndTesting;
      }
      return FertilityStatus.ovulationLikelyPassed;
    }
    if (hasPeakLh) return FertilityStatus.peakFertilitySigns;
    if (hasHighLh || hasFertileMucus) return FertilityStatus.highFertility;
    if (!today.isBefore(fertileStart)) return FertilityStatus.fertilityRising;
    return FertilityStatus.fertilityPreparing;
  }

  static String _explanationFor({
    required FertilityStatus status,
    required bool hasFertileMucus,
    required bool hasPeakLh,
    required OvulationConfirmationResult confirmation,
  }) {
    if (hasPeakLh) {
      return 'A positive or peak LH test can suggest ovulation may occur within about 24 to 48 hours, but it does not confirm ovulation.';
    }
    if (hasFertileMucus) {
      return 'You recorded fertile-quality cervical mucus and your recent cycle pattern suggests ovulation may be approaching.';
    }
    if (confirmation.likelyOvulationDate != null) {
      return 'A sustained temperature pattern suggests ovulation may already have occurred. Quevaa labels this retrospectively.';
    }
    if (status == FertilityStatus.waitingAndTesting) {
      return 'You are past the estimated fertile window. Quevaa is shifting into a calmer waiting phase.';
    }
    return 'Quevaa is starting with cycle history and will adjust as you record mucus, LH tests, waking temperature and symptoms.';
  }

  static List<String> _observationsFor({
    required List<FertilityObservation> recentObservations,
    required OvulationConfirmationResult confirmation,
  }) {
    final items = <String>[];
    if (recentObservations.any((entry) => entry.cervicalMucus != null)) {
      items.add('Cervical mucus logged this week');
    }
    if (recentObservations.any((entry) => entry.ovulationTest != null)) {
      items.add('Ovulation test result available');
    }
    if (recentObservations.any((entry) => entry.basalTemperature != null)) {
      items.add('Waking temperature recorded');
    }
    if (recentObservations.any((entry) => entry.illness)) {
      items.add('Illness or fever may reduce temperature reliability');
    }
    if (confirmation.likelyOvulationDate != null) {
      items.add('Possible temperature shift detected');
    }
    return items.isEmpty ? ['No fertility signs logged yet today'] : items;
  }

  static List<String> _confidenceImprovementsFor({
    required ConceptionProfile profile,
    required List<FertilityObservation> observations,
  }) {
    final items = <String>[];
    if (profile.previousPeriodStartDates.length < 3) {
      items.add('Add at least three previous cycle start dates');
    }
    if (!observations.any((entry) => entry.cervicalMucus != null)) {
      items.add('Record cervical mucus when you notice it');
    }
    if (!observations.any((entry) => entry.ovulationTest != null)) {
      items.add('Log ovulation test timing and result');
    }
    if (observations
            .where((entry) => entry.basalTemperature?.isReliable ?? false)
            .length <
        4) {
      items.add('Add several valid waking temperature readings');
    }
    return items.isEmpty ? ['Signals are becoming more consistent'] : items;
  }

  static List<String> _dailyChecklistFor(ConceptionProfile profile) {
    return [
      if (profile.usesOvulationTests) 'Take ovulation test',
      if (profile.tracksCervicalMucus) 'Record cervical mucus',
      if (profile.tracksBasalTemperature) 'Take waking temperature',
      if (profile.prenatalReminderEnabled)
        'Take prenatal or folic-acid support',
      'Drink water',
      'Complete gentle movement',
      'Record mood',
      'Add private note',
    ];
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
