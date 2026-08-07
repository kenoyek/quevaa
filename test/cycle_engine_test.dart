import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/models/prediction_confidence.dart';
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

    test('Correctly calculates historical Cycle Day during browsing', () {
      final history = [
        CyclePeriodRecord(startDate: DateTime(2026, 1, 1)),
        CyclePeriodRecord(startDate: DateTime(2026, 1, 29)),
      ];

      // Browsing a date during the FIRST cycle
      final pastOutput = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 1, 15),
      );
      expect(pastOutput.currentCycleDay, 15);

      // Browsing a date during the SECOND cycle
      final presentOutput = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 2, 5),
      );
      expect(presentOutput.currentCycleDay, 8);
    });

    test('Generates 6 months of future projections', () {
      final history = [CyclePeriodRecord(startDate: DateTime(2026, 1, 1))];
      final output = CycleEngine.calculate(
        periodHistory: history,
        targetDate: DateTime(2026, 1, 1),
      );

      expect(output.nextCycles.length, 6);
      expect(output.nextCycles[0].min.isAfter(DateTime(2026, 1, 1)), true);
      expect(output.nextCycles[5].min.isAfter(output.nextCycles[0].min), true);
    });

    test(
      'PredictionConfidence presentation extension returns valid labels',
      () {
        expect(PredictionConfidence.low.label, 'Low');
        expect(PredictionConfidence.moderate.label, 'Moderate');
        expect(PredictionConfidence.high.label, 'High');
        expect(
          PredictionConfidencePresentation.fromString('high'),
          PredictionConfidence.high,
        );
        expect(
          PredictionConfidencePresentation.fromString(null),
          PredictionConfidence.low,
        );
      },
    );

    test('Empty period history returns hasEnoughData = false', () {
      final output = CycleEngine.calculate(
        periodHistory: [],
        targetDate: DateTime(2026, 4, 1),
      );
      expect(output.hasEnoughData, false);
      expect(output.estimatedPhase, 'Phase unavailable');

      final snapshot = output.toSnapshot(DateTime(2026, 4, 1));
      expect(snapshot.hasEnoughData, false);
      expect(snapshot.cycleDay, null);
    });

    group('Period Prediction Range & Uncertainty Separation (Requirement 17)', () {
      test('Four-day duration: start 8 Aug -> expected end 11 Aug', () {
        final history = [
          CyclePeriodRecord(
            startDate: DateTime(2026, 7, 11),
            endDate: DateTime(2026, 7, 14), // 4 days
          ),
        ];
        final output = CycleEngine.calculate(
          periodHistory: history,
          targetDate: DateTime(2026, 8, 1),
          userConfiguredPeriodLength: 4,
          userConfiguredAverageCycleLength: 28,
        );

        final pred = output.periodPredictions.first;
        expect(pred.estimatedStartDate, DateTime(2026, 8, 8));
        expect(pred.expectedDurationDays, 4);
        expect(pred.predictedBleedingRange.start, DateTime(2026, 8, 8));
        expect(pred.predictedBleedingRange.end, DateTime(2026, 8, 11));
      });

      test('Five-day duration: start 8 Aug -> expected end 12 Aug', () {
        final history = [
          CyclePeriodRecord(
            startDate: DateTime(2026, 7, 11),
            endDate: DateTime(2026, 7, 15), // 5 days
          ),
        ];
        final output = CycleEngine.calculate(
          periodHistory: history,
          targetDate: DateTime(2026, 8, 1),
          userConfiguredPeriodLength: 5,
          userConfiguredAverageCycleLength: 28,
        );

        final pred = output.periodPredictions.first;
        expect(pred.estimatedStartDate, DateTime(2026, 8, 8));
        expect(pred.expectedDurationDays, 5);
        expect(pred.predictedBleedingRange.start, DateTime(2026, 8, 8));
        expect(pred.predictedBleedingRange.end, DateTime(2026, 8, 12));
      });

      test(
        'Start uncertainty does not inflate central predicted bleeding range',
        () {
          final history = [
            CyclePeriodRecord(
              startDate: DateTime(2026, 7, 11),
              endDate: DateTime(2026, 7, 14),
            ),
          ];
          final output = CycleEngine.calculate(
            periodHistory: history,
            targetDate: DateTime(2026, 8, 1),
            userConfiguredPeriodLength: 4,
          );

          final pred = output.periodPredictions.first;
          expect(pred.confidence, PredictionConfidence.low);
          expect(pred.possibleStartRange.start, DateTime(2026, 8, 5));
          expect(pred.possibleStartRange.end, DateTime(2026, 8, 11));
          expect(pred.predictedBleedingRange.start, DateTime(2026, 8, 8));
          expect(pred.predictedBleedingRange.end, DateTime(2026, 8, 11));
          expect(pred.isBleedingDay(DateTime(2026, 8, 7)), false);
          expect(pred.isBleedingDay(DateTime(2026, 8, 8)), true);
          expect(pred.isBleedingDay(DateTime(2026, 8, 11)), true);
          expect(pred.isBleedingDay(DateTime(2026, 8, 12)), false);
        },
      );

      test('Month boundary: start 29 Aug, 5 days duration -> end 2 Sep', () {
        final history = [
          CyclePeriodRecord(
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 5),
          ),
        ];
        final output = CycleEngine.calculate(
          periodHistory: history,
          targetDate: DateTime(2026, 8, 10),
          userConfiguredPeriodLength: 5,
          userConfiguredAverageCycleLength: 28,
        );

        final pred = output.periodPredictions.first;
        expect(pred.estimatedStartDate, DateTime(2026, 8, 29));
        expect(pred.predictedBleedingRange.start, DateTime(2026, 8, 29));
        expect(pred.predictedBleedingRange.end, DateTime(2026, 9, 2));
      });

      test('Leap year: period prediction crossing Feb 29', () {
        final history = [
          CyclePeriodRecord(
            startDate: DateTime(2028, 1, 30),
            endDate: DateTime(2028, 2, 2),
          ),
        ];
        final output = CycleEngine.calculate(
          periodHistory: history,
          targetDate: DateTime(2028, 2, 5),
          userConfiguredPeriodLength: 4,
          userConfiguredAverageCycleLength: 28,
        );

        final pred = output.periodPredictions.first;
        expect(pred.estimatedStartDate, DateTime(2028, 2, 27));
        expect(pred.predictedBleedingRange.end, DateTime(2028, 3, 1));
      });

      test(
        'Insufficient history uses user configured duration and sets low confidence',
        () {
          final output = CycleEngine.calculate(
            periodHistory: [],
            targetDate: DateTime(2026, 8, 1),
            userConfiguredPeriodLength: 4,
            userConfiguredAverageCycleLength: 28,
          );
          expect(output.confidence, PredictionConfidence.low);
          expect(output.averagePeriodDuration, 4.0);
        },
      );

      test(
        'New completed cycles update duration from history without inflating period range',
        () {
          final history = [
            CyclePeriodRecord(
              startDate: DateTime(2026, 6, 1),
              endDate: DateTime(2026, 6, 4), // 4 days
            ),
            CyclePeriodRecord(
              startDate: DateTime(2026, 6, 29),
              endDate: DateTime(2026, 7, 2), // 4 days
            ),
          ];
          final output = CycleEngine.calculate(
            periodHistory: history,
            targetDate: DateTime(2026, 7, 5),
            userConfiguredPeriodLength: 5,
          );

          expect(output.averagePeriodDuration, 4.0);
          final pred = output.periodPredictions.first;
          expect(pred.expectedDurationDays, 4);
        },
      );
    });
  });
}
