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

  static const String _journalKeyName = 'quevaa_journal_encryption_key';

  /// Gets or creates the journal encryption key
  Future<List<int>> getOrCreateJournalKey() async {
    String? existingKey = await _storage.read(key: _journalKeyName);
    if (existingKey != null && existingKey.isNotEmpty) {
      return base64Decode(existingKey);
    }
    final keyData = SecretKeyData.random(length: 32);
    final keyBytes = await keyData.extractBytes();
    await _storage.write(key: _journalKeyName, value: base64Encode(keyBytes));
    return keyBytes;
  }

  /// Encrypts journal content using AES-256-GCM
  Future<String> encryptJournalContent(String plainText) async {
    final keyBytes = await getOrCreateJournalKey();
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(keyBytes);
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKey,
      nonce: nonce,
    );
    // Encode as: nonce + cipherText + mac
    final combined = [
      ...nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return base64Encode(combined);
  }

  /// Decrypts journal content
  Future<String> decryptJournalContent(String encrypted) async {
    final keyBytes = await getOrCreateJournalKey();
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(keyBytes);
    final combined = base64Decode(encrypted);
    // AES-GCM nonce is 12 bytes, MAC is 16 bytes
    final nonce = combined.sublist(0, 12);
    final cipherText = combined.sublist(12, combined.length - 16);
    final mac = Mac(combined.sublist(combined.length - 16));
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final plainBytes = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(plainBytes);
  }

  /// Check if content appears to be encrypted (base64 with correct structure)
  static bool isEncrypted(String content) {
    try {
      final bytes = base64Decode(content);
      return bytes.length > 28; // At least nonce(12) + 1 byte content + mac(16)
    } catch (_) {
      return false;
    }
  }
}
