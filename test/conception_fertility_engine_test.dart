import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/conception/application/conception_controller.dart';
import 'package:quevaa/features/conception/domain/engines/fertility_engine.dart';
import 'package:quevaa/features/conception/domain/entities/cervical_mucus_entry.dart';
import 'package:quevaa/features/conception/domain/entities/conception_profile.dart';
import 'package:quevaa/features/conception/domain/entities/fertility_assessment.dart';
import 'package:quevaa/features/conception/domain/entities/fertility_observation.dart';
import 'package:quevaa/features/conception/domain/entities/ovulation_test.dart';

void main() {
  group('Conception mode switching', () {
    test('can enter and leave conception mode without deleting records', () {
      final controller = ConceptionController();
      final initialObservations = controller.state.observations;

      expect(controller.state.profile.status, ConceptionGoalStatus.paused);

      controller.enterConceptionMode();
      expect(
        controller.state.profile.status,
        ConceptionGoalStatus.tryingToConceive,
      );

      controller.leaveConceptionMode();
      expect(controller.state.profile.status, ConceptionGoalStatus.paused);
      expect(controller.state.observations, initialObservations);
    });
  });

  group('Conception fertility engine', () {
    test(
      'uses fertile mucus and LH tests to raise status without certainty',
      () {
        final today = DateTime(2026, 8, 18);
        final profile = ConceptionProfile(
          status: ConceptionGoalStatus.tryingToConceive,
          tryingStartDate: DateTime(2026, 6, 1),
          lastPeriodStartDate: DateTime(2026, 8, 6),
          previousPeriodStartDates: [
            DateTime(2026, 7, 8),
            DateTime(2026, 6, 10),
            DateTime(2026, 5, 12),
          ],
        );

        final assessment = const FertilityEngine().assess(
          profile: profile,
          targetDate: today,
          observations: [
            FertilityObservation(
              date: today,
              cervicalMucus: CervicalMucusEntry(
                date: today,
                type: CervicalMucusType.clearSlipperyStretchy,
              ),
              ovulationTest: OvulationTestEntry(
                testedAt: today,
                result: OvulationTestResult.positiveOrPeak,
              ),
            ),
          ],
        );

        expect(assessment.status, FertilityStatus.peakFertilitySigns);
        expect(assessment.confidence, isNot(PredictionConfidence.high));
        expect(assessment.explanation, contains('does not confirm ovulation'));
      },
    );

    test('calendar-only estimates remain low confidence', () {
      final today = DateTime(2026, 8, 12);
      final profile = ConceptionProfile(
        status: ConceptionGoalStatus.tryingToConceive,
        tryingStartDate: DateTime(2026, 8, 1),
        lastPeriodStartDate: DateTime(2026, 8, 6),
        previousPeriodStartDates: const [],
        cyclesUsuallyRegular: false,
      );

      final assessment = const FertilityEngine().assess(
        profile: profile,
        targetDate: today,
        observations: const [],
      );

      expect(assessment.confidence, PredictionConfidence.low);
      expect(assessment.status, FertilityStatus.fertilityPreparing);
      expect(
        assessment.confidenceImprovements,
        contains('Add at least three previous cycle start dates'),
      );
    });
  });
}
