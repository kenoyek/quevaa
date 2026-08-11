import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/dashboard/domain/readiness_calculator.dart';

void main() {
  group('Daily readiness model', () {
    test('A: severe pain overrides an otherwise supportive phase', () {
      final result = ReadinessCalculator.calculate(
        selfReportedEnergy: 4,
        sleepHours: 7.5,
        painLevel: 5,
        estimatedPhase: 'Follicular',
        currentCycleDay: 8,
      );

      expect(result.score, ReadinessScore.restore);
      expect(
        result.limitingFactors.map((factor) => factor.label),
        contains('Severe discomfort'),
      );
      expect(result.confidence, ReadinessConfidence.current);
    });

    test('B: modest energy and short sleep produce a gentle plan', () {
      final result = ReadinessCalculator.calculate(
        selfReportedEnergy: 3,
        sleepHours: 6.4,
        painLevel: 1,
        estimatedPhase: 'Luteal',
        currentCycleDay: 23,
      );

      expect(result.score, ReadinessScore.gentle);
      expect(result.primaryRecommendation, contains('one useful priority'));
    });

    test(
      'C: ordinary signals land in steady, not a static balanced bucket',
      () {
        final result = ReadinessCalculator.calculate(
          selfReportedEnergy: 4,
          sleepHours: 7.4,
          painLevel: 1,
          estimatedPhase: 'Follicular',
          currentCycleDay: 10,
        );

        expect(result.score, ReadinessScore.steady);
        expect(result.label, 'Steady');
      },
    );

    test('D: strong energy, sleep and low pain surface strong readiness', () {
      final result = ReadinessCalculator.calculate(
        selfReportedEnergy: 5,
        sleepHours: 8.5,
        painLevel: 0,
        mood: 'Calm',
        stressLevel: 1,
        estimatedPhase: 'Follicular',
        currentCycleDay: 9,
      );

      expect(result.score, ReadinessScore.strong);
      expect(result.supportingFactors.length, greaterThanOrEqualTo(3));
    });

    test('E: phase informs readiness but does not dictate it', () {
      final result = ReadinessCalculator.calculate(
        selfReportedEnergy: 5,
        sleepHours: 8,
        painLevel: 0,
        estimatedPhase: 'Luteal',
        currentCycleDay: 25,
      );

      expect(result.score, isNot(ReadinessScore.restore));
      expect(result.score, isNot(ReadinessScore.gentle));
      expect(result.cycleContext, contains('Luteal'));
    });

    test(
      'F: missing data lowers confidence instead of pretending neutral certainty',
      () {
        final result = ReadinessCalculator.calculate(
          estimatedPhase: 'Follicular',
          currentCycleDay: 11,
        );

        expect(result.confidence, ReadinessConfidence.low);
        expect(
          result.limitingFactors.map((factor) => factor.label),
          contains('Limited check-in data'),
        );
        expect(result.description, contains('Add a quick check-in'));
      },
    );

    test('personal history changes confidence and explanation', () {
      final result = ReadinessCalculator.calculate(
        selfReportedEnergy: 4,
        sleepHours: 7.2,
        painLevel: 1,
        estimatedPhase: 'Luteal',
        currentCycleDay: 24,
        loggedHistoryCount: 12,
        historyProfile: const ReadinessHistoryProfile(
          matchingCycleLogs: 5,
          typicalEnergy: 2.2,
          typicalPain: 3.1,
          typicalSleep: 6.3,
        ),
      );

      expect(result.confidence, ReadinessConfidence.personal);
      expect(result.historyInsight, contains('Across 5 logs'));
      expect(
        result.limitingFactors.map((factor) => factor.label),
        contains('Personal pattern'),
      );
    });
  });
}
