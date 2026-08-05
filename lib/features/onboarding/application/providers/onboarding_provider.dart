import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../domain/entities/onboarding_profile.dart';

final onboardingProfileProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingProfile>((ref) {
      return OnboardingNotifier(ref);
    });

class OnboardingNotifier extends StateNotifier<OnboardingProfile> {
  final Ref ref;

  OnboardingNotifier(this.ref) : super(const OnboardingProfile());

  void updateProfile(OnboardingProfile updated) {
    state = updated;
  }

  Future<void> completeOnboarding() async {
    final db = ref.read(appDatabaseProvider);
    final existing = await db.select(db.userProfiles).getSingleOrNull();

    if (existing != null) {
      await (db.update(
        db.userProfiles,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        UserProfilesCompanion(
          userName: const Value('Adaora'),
          averageCycleLength: Value(state.averageCycleLength),
          averagePeriodLength: Value(state.averagePeriodDuration),
          lastPeriodStartDate: Value(state.lastPeriodStartDate),
          isBiometricEnabled: Value(state.enableBiometrics),
          primaryGoal: Value(state.primaryGoal),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              userName: const Value('Adaora'),
              averageCycleLength: Value(state.averageCycleLength),
              averagePeriodLength: Value(state.averagePeriodDuration),
              lastPeriodStartDate: Value(state.lastPeriodStartDate),
              isBiometricEnabled: Value(state.enableBiometrics),
              primaryGoal: Value(state.primaryGoal),
              uuid: DateTime.now().millisecondsSinceEpoch.toString(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    }
  }
}
