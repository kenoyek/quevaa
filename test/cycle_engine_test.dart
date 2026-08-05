import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/cycle/domain/cycle_engine.dart';
import 'package:quevaa/features/cycle/domain/models/cycle_engine_output.dart';

void main() {
  group('Phase 4: Cycle Engine Unit Tests', () {
    test(
      'Calculates current cycle day and weighted median range for regular history',
      () {
        final history = [
          CyclePeriodRecord(
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 1, 5),
          ),
          CyclePeriodRecord(
            startDate: DateTime(2026, 1, 29),
            endDate: DateTime(2026, 2, 2),
          ),
          CyclePeriodRecord(
            startDate: DateTime(2026, 2, 27),
            endDate: DateTime(2026, 3, 3),
          ),
          CyclePeriodRecord(
            startDate: DateTime(2026, 3, 28),
            endDate: DateTime(2026, 4, 1),
          ),
        ];

        final output = CycleEngine.calculate(
          periodHistory: history,
          targetDate: DateTime(2026, 4, 5),
        );

        expect(output.currentCycleDay, 9);
        expect(output.estimatedPhase, 'Follicular');
        expect(output.medianCycleLength >= 28, true);
        expect(output.disclaimer.contains('not a form of contraception'), true);
      },
    );

    test('Handles Leap Year boundaries accurately (Feb 29, 2028)', () {
      final history = [
        CyclePeriodRecord(startDate: DateTime(2028, 1, 30)),
        CyclePeriodRecord(startDate: DateTime(2028, 2, 29)), // Leap day!
      ];

      final output = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2028, 3, 1),
      );

      expect(output.currentCycleDay, 2);
      expect(output.estimatedPhase, 'Menstrual');
    });

    test('Handles Month and Year boundaries (Dec 25 to Jan 22)', () {
      final history = [
        CyclePeriodRecord(startDate: DateTime(2025, 12, 25)),
        CyclePeriodRecord(startDate: DateTime(2026, 1, 22)),
      ];

      final output = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 1, 25),
      );

      expect(output.currentCycleDay, 4);
      expect(output.estimatedPhase, 'Menstrual');
    });

    test('Handles Pregnancy Mode by pausing predictions', () {
      final history = [CyclePeriodRecord(startDate: DateTime(2026, 1, 1))];
      final output = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 4, 1),
        mode: CycleMode.pregnancy,
      );

      expect(output.estimatedPhase.contains('Pregnancy Mode'), true);
      expect(output.confidence, PredictionConfidence.low);
    });

    test('Handles Postpartum Mode appropriately', () {
      final history = [CyclePeriodRecord(startDate: DateTime(2026, 1, 1))];
      final output = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 4, 1),
        mode: CycleMode.postpartum,
      );

      expect(output.estimatedPhase.contains('Postpartum Recovery'), true);
    });

    test('Handles Hormonal Contraception Mode', () {
      final history = [CyclePeriodRecord(startDate: DateTime(2026, 4, 1))];
      final output = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 4, 2),
        mode: CycleMode.hormonalContraception,
      );

      expect(output.estimatedPhase, 'Bleeding / Withdrawal');
      expect(output.confidence, PredictionConfidence.low);
    });

    test('Assigns High Confidence for 6+ consistent cycles', () {
      final history = [
        CyclePeriodRecord(startDate: DateTime(2025, 10, 1)),
        CyclePeriodRecord(startDate: DateTime(2025, 10, 29)),
        CyclePeriodRecord(startDate: DateTime(2025, 11, 26)),
        CyclePeriodRecord(startDate: DateTime(2025, 12, 24)),
        CyclePeriodRecord(startDate: DateTime(2026, 1, 21)),
        CyclePeriodRecord(startDate: DateTime(2026, 2, 18)),
        CyclePeriodRecord(startDate: DateTime(2026, 3, 18)),
      ];

      final output = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 3, 20),
      );

      expect(output.confidence, PredictionConfidence.high);
    });
  });
}
