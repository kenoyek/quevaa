import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/security/export_import_service.dart';
import 'package:quevaa/core/security/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Privacy & Encryption Tests', () {
    late ExportImportService exportImportService;
    late AppLockService appLockService;

    setUp(() {
      exportImportService = ExportImportService();
      appLockService = AppLockService();
    });

    test(
      'Encrypted .quevaa backup and restore pipeline encrypts & decrypts correctly',
      () async {
        final sampleBackup = {
          'version': 1,
          'userProfile': {'userName': 'Adaora', 'goal': 'Understand my period'},
          'dailyLogs': [
            {'date': '2026-08-05', 'energyLevel': 4, 'waterGlasses': 6},
          ],
        };

        const testPassword = 'QuevaaSecurePassword123!';
        const testFileName = 'test_encrypted_backup';

        // 1. Export encrypted .quevaa file
        final encryptedFile = await exportImportService.exportEncryptedBackup(
          rawBackupData: sampleBackup,
          userPassword: testPassword,
          fileName: testFileName,
          outputDirectory: Directory.systemTemp,
        );

        expect(await encryptedFile.exists(), true);
        final rawBytes = await encryptedFile.readAsBytes();
        expect(rawBytes.length > 44, true);

        // 2. Import and decrypt using correct password
        final restoredBackup = await exportImportService.importEncryptedBackup(
          backupFile: encryptedFile,
          userPassword: testPassword,
        );

        expect(restoredBackup['version'], 1);
        expect(restoredBackup['userProfile']['userName'], 'Adaora');

        // Clean up test file
        if (await encryptedFile.exists()) {
          await encryptedFile.delete();
        }
      },
    );

    test(
      'Export import fails when wrong decryption password is provided',
      () async {
        final sampleBackup = {'data': 'Sensitive health log'};
        const correctPassword = 'Password123';
        const wrongPassword = 'WrongPassword456';

        final encryptedFile = await exportImportService.exportEncryptedBackup(
          rawBackupData: sampleBackup,
          userPassword: correctPassword,
          fileName: 'wrong_pass_test',
          outputDirectory: Directory.systemTemp,
        );

        expect(
          () async => await exportImportService.importEncryptedBackup(
            backupFile: encryptedFile,
            userPassword: wrongPassword,
          ),
          throwsA(isA<Exception>()),
        );

        if (await encryptedFile.exists()) {
          await encryptedFile.delete();
        }
      },
    );

    test('AppLockService handles lock states and inactivity timeouts', () {
      expect(appLockService.isLocked, false);

      appLockService.lockApp();
      expect(appLockService.isLocked, true);

      appLockService.unlockApp();
      expect(appLockService.isLocked, false);

      appLockService.updateActivityTimestamp();
      expect(appLockService.checkInactivityLock(120), false);
    });
  });
}
