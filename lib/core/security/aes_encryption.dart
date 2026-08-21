import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../constants/app_constants.dart';

/// Clean and robust AES-256-CBC encryption utility.
/// Matches Go backend `utils.DecryptField` exactly (16-byte random IV + Ciphertext in Hex format).
class AesEncryption {
  AesEncryption._();

  /// Encrypts plaintext string using AES-256-CBC with PKCS7 padding.
  /// Generates a unique, cryptographically secure 16-byte IV for every encryption.
  static String encrypt(String text, {String? customKey}) {
    if (text.isEmpty) return '';

    final keyStr = customKey ?? AppConstants.aesKey;
    if (keyStr.isEmpty) {
      throw StateError(
        'AES_KEY tidak ditemukan. Pada build Release, injeksikan kunci via --dart-define=AES_KEY=32_karakter_kunci',
      );
    }
    if (keyStr.length != 32) {
      throw ArgumentError(
        'AES Key harus tepat 32 karakter (256-bit). Panjang saat ini: ${keyStr.length}',
      );
    }

    final key = enc.Key.fromUtf8(keyStr);

    // Generate random 16 bytes IV
    final rnd = Random.secure();
    final ivBytes =
        Uint8List.fromList(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(
      enc.AES(
        key,
        mode: enc.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );

    final encrypted = encrypter.encrypt(text, iv: iv);

    // Combine IV (16 bytes) + ciphertext bytes
    final combined = Uint8List(ivBytes.length + encrypted.bytes.length);
    combined.setRange(0, ivBytes.length, ivBytes);
    combined.setRange(ivBytes.length, combined.length, encrypted.bytes);

    return hex.encode(combined);
  }

  /// Decrypts hex string (16-byte IV + ciphertext) back to plaintext.
  static String decrypt(String hexString, {String? customKey}) {
    if (hexString.isEmpty) return '';

    final keyStr = customKey ?? AppConstants.aesKey;
    if (keyStr.isEmpty) {
      throw StateError(
        'AES_KEY tidak ditemukan. Pada build Release, injeksikan kunci via --dart-define=AES_KEY=32_karakter_kunci',
      );
    }
    if (keyStr.length != 32) {
      throw ArgumentError(
        'AES Key harus tepat 32 karakter (256-bit). Panjang saat ini: ${keyStr.length}',
      );
    }

    final key = enc.Key.fromUtf8(keyStr);

    final data = Uint8List.fromList(hex.decode(hexString));
    if (data.length < 16) {
      throw ArgumentError('Ciphertext tidak valid (panjang kurang dari 16 byte IV)');
    }

    final ivBytes = data.sublist(0, 16);
    final cipherBytes = data.sublist(16);

    final encrypter = enc.Encrypter(
      enc.AES(
        key,
        mode: enc.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );

    return encrypter.decrypt(
      enc.Encrypted(cipherBytes),
      iv: enc.IV(ivBytes),
    );
  }
}
