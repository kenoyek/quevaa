import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/onboarding/domain/entities/onboarding_profile.dart';

void main() {
  group('Onboarding & Me Profile Parameter Tests', () {
    test('OnboardingProfile accepts and copies age, period length, cycle length, and last period date', () {
      final now = DateTime.now();
      const initial = OnboardingProfile(
        userName: 'Adaora',
        age: 26,
        averagePeriodDuration: 5,
        averageCycleLength: 28,
      );

      expect(initial.userName, 'Adaora');
      expect(initial.age, 26);
      expect(initial.averagePeriodDuration, 5);
      expect(initial.averageCycleLength, 28);
      expect(initial.lastPeriodStartDate, null);

      final updated = initial.copyWith(
        userName: 'Amina',
        age: 29,
        averagePeriodDuration: 6,
        averageCycleLength: 30,
        lastPeriodStartDate: now,
      );

      expect(updated.userName, 'Amina');
      expect(updated.age, 29);
      expect(updated.averagePeriodDuration, 6);
      expect(updated.averageCycleLength, 30);
      expect(updated.lastPeriodStartDate, now);
    });
  });
}
