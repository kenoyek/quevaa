import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import '../analytics/app_logger.dart';

class ExportImportService {
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  /// Encrypts raw JSON backup payload with user password using PBKDF2 + AES-GCM.
  Future<File> exportEncryptedBackup({
    required Map<String, dynamic> rawBackupData,
    required String userPassword,
    required String fileName,
    Directory? outputDirectory,
  }) async {
    AppLogger.info('Starting encrypted backup generation');

    // 1. Generate random 16-byte salt and 12-byte nonce
    final salt = SecretKeyData.random(length: 16).bytes;
    final nonce = _aesGcm.newNonce();

    // 2. Derive 256-bit encryption key from password
    final derivedSecretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(userPassword)),
      nonce: salt,
    );

    // 3. Encrypt payload
    final plaintextBytes = utf8.encode(jsonEncode(rawBackupData));
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: derivedSecretKey,
      nonce: nonce,
    );

    // 4. Structure .quevaa binary format: [Salt 16B] + [Nonce 12B] + [Mac 16B] + [Ciphertext...]
    final builder = BytesBuilder();
    builder.add(salt);
    builder.add(secretBox.nonce);
    builder.add(secretBox.mac.bytes);
    builder.add(secretBox.cipherText);

    final dir = outputDirectory ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName.quevaa');
    await file.writeAsBytes(builder.toBytes());

    AppLogger.info('Encrypted backup successfully written to ${file.path}');
    return file;
  }

  /// Decrypts .quevaa backup file with user password.
  Future<Map<String, dynamic>> importEncryptedBackup({
    required File backupFile,
    required String userPassword,
  }) async {
    AppLogger.info('Reading encrypted .quevaa backup file');
    final bytes = await backupFile.readAsBytes();

    if (bytes.length < 44) {
      throw const FormatException(
        'Invalid or corrupted .quevaa backup file structure',
      );
    }

    final salt = bytes.sublist(0, 16);
    final nonce = bytes.sublist(16, 28);
    final macBytes = bytes.sublist(28, 44);
    final cipherText = bytes.sublist(44);

    final derivedSecretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(userPassword)),
      nonce: salt,
    );

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

    final clearTextBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: derivedSecretKey,
    );

    final jsonString = utf8.decode(clearTextBytes);
    AppLogger.info('Backup file successfully decrypted and verified');
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }
}
