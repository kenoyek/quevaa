import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quevaa/core/security/app_lock_provider.dart';
import 'package:quevaa/core/providers/user_profile_provider.dart';
import 'package:quevaa/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockNotifier Unit Tests', () {
    test('AppLockNotifier initializes unlocked when profile is null', () {
      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final isLocked = container.read(appLockProvider);
      expect(isLocked, false);
    });

    test('AppLockNotifier locks when profile with isBiometricEnabled: true is loaded', () async {
      final mockProfile = UserProfile(
        id: 1,
        uuid: 'test-uuid',
        userName: 'Adaora',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        isBiometricEnabled: true,
        isPinEnabled: false,
        primaryGoal: 'Understand my period',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        schemaVersion: 1,
        source: 'manual',
      );

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(mockProfile)),
        ],
      );
      addTearDown(container.dispose);

      // Trigger provider initialization
      container.read(appLockProvider);

      // Allow stream emission to process
      await Future<void>.delayed(Duration.zero);

      final isLocked = container.read(appLockProvider);
      expect(isLocked, true);
    });
  });
}
