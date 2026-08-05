import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/dashboard/domain/readiness_calculator.dart';

void main() {
  group('Phase 6: Readiness Calculator Unit Tests', () {
    test(
      'Calculates Restore state when pain level is high or energy is low',
      () {
        final result = ReadinessCalculator.calculate(
          selfReportedEnergy: 2,
          sleepHours: 5.0,
          painLevel: 3,
          estimatedPhase: 'Menstrual',
        );

        expect(result.score, ReadinessScore.restore);
        expect(result.label, 'Restore');
      },
    );

    test(
      'Calculates Energised state when energy and sleep are high with zero pain',
      () {
        final result = ReadinessCalculator.calculate(
          selfReportedEnergy: 5,
          sleepHours: 8.5,
          painLevel: 0,
          estimatedPhase: 'Follicular',
        );

        expect(result.score, ReadinessScore.energised);
        expect(result.label, 'Energised');
      },
    );
  });
}
