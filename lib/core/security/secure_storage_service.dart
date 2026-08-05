import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _dbKeyName = 'quevaa_secure_db_passphrase';

  /// Generates or retrieves a 256-bit cryptographically secure key stored in Keychain / Keystore.
  Future<String> getOrCreateDatabasePassphrase() async {
    String? existingPassphrase = await _storage.read(key: _dbKeyName);
    if (existingPassphrase != null && existingPassphrase.isNotEmpty) {
      return existingPassphrase;
    }

    // Generate a secure 32-byte (256-bit) random key
    final algorithm = SecretKeyData.random(length: 32);
    final keyBytes = await algorithm.extractBytes();
    final newPassphrase = base64Encode(keyBytes);

    await _storage.write(key: _dbKeyName, value: newPassphrase);
    return newPassphrase;
  }
}
