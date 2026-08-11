import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/providers/user_profile_provider.dart';
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

    await db.transaction(() async {
      final allProfiles = await db.select(db.userProfiles).get();
      final DateTime? normalizedLastPeriod = state.lastPeriodStartDate != null
          ? DateTime(
              state.lastPeriodStartDate!.year,
              state.lastPeriodStartDate!.month,
              state.lastPeriodStartDate!.day,
            )
          : null;

      if (allProfiles.isNotEmpty) {
        final primary = allProfiles.first;
        await (db.update(
          db.userProfiles,
        )..where((tbl) => tbl.id.equals(primary.id))).write(
          UserProfilesCompanion(
            userName: Value(state.userName),
            age: Value(state.age),
            averageCycleLength: Value(state.averageCycleLength),
            averagePeriodLength: Value(state.averagePeriodDuration),
            lastPeriodStartDate: Value(normalizedLastPeriod),
            isBiometricEnabled: Value(state.enableBiometrics),
            primaryGoal: Value(state.primaryGoal),
            updatedAt: Value(DateTime.now()),
          ),
        );
        for (var i = 1; i < allProfiles.length; i++) {
          await (db.delete(
            db.userProfiles,
          )..where((tbl) => tbl.id.equals(allProfiles[i].id))).go();
        }
      } else {
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                userName: Value(state.userName),
                age: Value(state.age),
                averageCycleLength: Value(state.averageCycleLength),
                averagePeriodLength: Value(state.averagePeriodDuration),
                lastPeriodStartDate: Value(normalizedLastPeriod),
                isBiometricEnabled: Value(state.enableBiometrics),
                primaryGoal: Value(state.primaryGoal),
                uuid: DateTime.now().millisecondsSinceEpoch.toString(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      }

      if (normalizedLastPeriod != null) {
        final existingPeriod = await (db.select(
          db.cyclePeriods,
        )..limit(1)).getSingleOrNull();
        if (existingPeriod == null) {
          final end = normalizedLastPeriod.add(
            Duration(days: state.averagePeriodDuration - 1),
          );
          await db
              .into(db.cyclePeriods)
              .insert(
                CyclePeriodsCompanion.insert(
                  startDate: normalizedLastPeriod,
                  endDate: Value(end),
                  uuid: DateTime.now().millisecondsSinceEpoch.toString(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
        }
      }

      final existingPrefs = await db
          .select(db.onboardingPreferences)
          .getSingleOrNull();
      final prefsCompanion = OnboardingPreferencesCompanion(
        isIrregular: Value(state.isIrregular),
        contraceptionStatus: Value(state.contraceptionStatus),
        wakeTime: Value(state.wakeTime),
        sleepTime: Value(state.sleepTime),
        focusSessionMinutes: Value(state.focusSessionMinutes),
        workType: Value(state.workType),
        regionPreference: Value(state.regionPreference),
        dietaryPattern: Value(state.dietaryPattern),
        prepTimePreference: Value(state.prepTimePreference),
        fitnessLevel: Value(state.fitnessLevel),
        workoutLocation: Value(state.workoutLocation),
        lowImpactOnly: Value(state.lowImpactOnly),
        enableDiscreetNotifications: Value(state.enableDiscreetNotifications),
        updatedAt: Value(DateTime.now()),
      );

      if (existingPrefs != null) {
        await (db.update(db.onboardingPreferences)
              ..where((tbl) => tbl.id.equals(existingPrefs.id)))
            .write(prefsCompanion);
      } else {
        await db
            .into(db.onboardingPreferences)
            .insert(
              OnboardingPreferencesCompanion.insert(
                isIrregular: Value(state.isIrregular),
                contraceptionStatus: Value(state.contraceptionStatus),
                wakeTime: Value(state.wakeTime),
                sleepTime: Value(state.sleepTime),
                focusSessionMinutes: Value(state.focusSessionMinutes),
                workType: Value(state.workType),
                regionPreference: Value(state.regionPreference),
                dietaryPattern: Value(state.dietaryPattern),
                prepTimePreference: Value(state.prepTimePreference),
                fitnessLevel: Value(state.fitnessLevel),
                workoutLocation: Value(state.workoutLocation),
                lowImpactOnly: Value(state.lowImpactOnly),
                enableDiscreetNotifications: Value(
                  state.enableDiscreetNotifications,
                ),
                uuid: DateTime.now().millisecondsSinceEpoch.toString(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      }
    });

    final verifyProfile = await db.select(db.userProfiles).getSingleOrNull();
    if (verifyProfile == null) {
      throw StateError(
        'Onboarding completion verification failed: UserProfile record missing post-commit.',
      );
    }

    ref.invalidate(userProfileProvider);
  }
}
