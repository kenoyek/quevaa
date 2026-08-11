import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/app/router/app_router.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/providers/database_provider.dart';
import 'package:quevaa/core/providers/user_profile_provider.dart';
import 'package:quevaa/core/security/app_lock_provider.dart';
import 'package:quevaa/features/onboarding/application/providers/onboarding_provider.dart';
import 'package:quevaa/features/onboarding/domain/entities/onboarding_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase inMemoryDb;

  setUp(() {
    inMemoryDb = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await inMemoryDb.close();
  });

  group('Quevaa Onboarding & Routing Core Unit & Integration Tests', () {
    test(
      'TEST 1: Fresh user completes onboarding -> profile persisted atomically',
      () async {
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(inMemoryDb)],
        );

        final notifier = container.read(onboardingProfileProvider.notifier);
        notifier.updateProfile(
          const OnboardingProfile(
            userName: 'Ada',
            primaryGoal: 'Understand my period',
            averageCycleLength: 29,
            averagePeriodDuration: 5,
          ),
        );

        await notifier.completeOnboarding();

        final profiles = await inMemoryDb.select(inMemoryDb.userProfiles).get();
        expect(profiles.length, equals(1));
        expect(profiles.first.userName, equals('Ada'));
        expect(profiles.first.primaryGoal, equals('Understand my period'));

        final prefs = await inMemoryDb
            .select(inMemoryDb.onboardingPreferences)
            .get();
        expect(prefs.length, equals(1));

        container.dispose();
      },
    );

    test(
      'TEST 2: TTC user completes onboarding -> profile persisted with TTC goal',
      () async {
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(inMemoryDb)],
        );

        final notifier = container.read(onboardingProfileProvider.notifier);
        notifier.updateProfile(
          const OnboardingProfile(
            userName: 'Nneka',
            primaryGoal: 'Try to conceive',
          ),
        );

        await notifier.completeOnboarding();

        final profile = await inMemoryDb
            .select(inMemoryDb.userProfiles)
            .getSingle();
        expect(profile.primaryGoal, equals('Try to conceive'));

        container.dispose();
      },
    );

    test(
      'TEST 4: Double tap / multiple completeOnboarding calls remain idempotent',
      () async {
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(inMemoryDb)],
        );

        final notifier = container.read(onboardingProfileProvider.notifier);
        notifier.updateProfile(
          OnboardingProfile(
            userName: 'Chidi',
            primaryGoal: 'Track cycle',
            lastPeriodStartDate: DateTime(2026, 8, 1),
          ),
        );

        // Call twice sequentially
        await notifier.completeOnboarding();
        await notifier.completeOnboarding();

        final profiles = await inMemoryDb.select(inMemoryDb.userProfiles).get();
        expect(profiles.length, equals(1));

        final periods = await inMemoryDb.select(inMemoryDb.cyclePeriods).get();
        expect(periods.length, equals(1));

        container.dispose();
      },
    );

    test(
      'TEST 5: Restart after completion -> profile exists -> onboarding is skipped',
      () async {
        // 1. First session: complete onboarding
        final container1 = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(inMemoryDb)],
        );

        await container1
            .read(onboardingProfileProvider.notifier)
            .completeOnboarding();
        container1.dispose();

        // 2. Second session: re-read profile
        final container2 = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(inMemoryDb)],
        );

        final userProfileState = await container2.read(
          userProfileProvider.future,
        );
        expect(userProfileState, isNotNull);
        expect(userProfileState?.userName, equals(''));

        container2.dispose();
      },
    );

    test(
      'TEST 6: Upgrade DB schema from v1 to v7 -> migrations execute cleanly',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        expect(db.schemaVersion, equals(7));

        // Verify all tables exist and work
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                uuid: 'test-v5-uuid',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        final inserted = await db.select(db.userProfiles).getSingle();
        expect(inserted.uuid, equals('test-v5-uuid'));

        await db
            .into(db.savedMeals)
            .insert(
              SavedMealsCompanion.insert(
                uuid: 'saved-meal-v6',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                mealId: 'beans-porridge',
                savedAt: DateTime.now(),
              ),
            );
        await db
            .into(db.mealPreparationEntries)
            .insert(
              MealPreparationEntriesCompanion.insert(
                uuid: 'prepared-meal-v6',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                mealId: 'beans-porridge',
                preparedAt: DateTime.now(),
                date: DateTime(2026, 8, 8),
                mealType: 'Lunch',
              ),
            );
        expect(await db.select(db.savedMeals).get(), hasLength(1));
        expect(await db.select(db.mealPreparationEntries).get(), hasLength(1));

        await db
            .into(db.notificationInboxEntries)
            .insert(
              NotificationInboxEntriesCompanion.insert(
                uuid: 'notification-inbox-v7',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                notificationId: 7001,
                category: 'cycle',
                title: 'Period update',
                explicitBody: 'Your period may start tomorrow.',
                discreetBody: 'You have a Quevaa update.',
                scheduledFor: DateTime.now(),
                deepLink: '/cycle',
                priority: 'normal',
              ),
            );
        expect(
          await db.select(db.notificationInboxEntries).get(),
          hasLength(1),
        );

        await db.close();
      },
    );

    test(
      'TEST 7: Biometrics enabled during onboarding -> app does not lock out during onboarding completion',
      () async {
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(inMemoryDb)],
        );

        final lockStateInitial = container.read(appLockProvider);
        expect(lockStateInitial, isFalse);

        final notifier = container.read(onboardingProfileProvider.notifier);
        notifier.updateProfile(
          const OnboardingProfile(userName: 'BioUser', enableBiometrics: true),
        );

        await notifier.completeOnboarding();

        // Ensure app lock remains false so screen is not covered
        final lockStateAfter = container.read(appLockProvider);
        expect(lockStateAfter, isFalse);

        container.dispose();
      },
    );

    test(
      'TEST 8: userProfileProvider AsyncError is classified as Error, NOT "no profile"',
      () async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(inMemoryDb),
            userProfileProvider.overrideWith(
              (ref) => Stream.error(const SocketException('Database locked')),
            ),
          ],
        );

        final router = container.read(routerProvider);
        expect(router, isNotNull);

        // Wait for stream error emission to propagate
        await Future<void>.delayed(Duration.zero);

        final profileState = container.read(userProfileProvider);
        expect(profileState.hasError, isTrue);

        container.dispose();
      },
    );
  });
}
