import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

class AesEncryption {
  static Future<String> encrypt(String value, String secret) async {
    try {
      final keyData = sha256.convert(utf8.encode(secret)).bytes;

      final iv = Uint8List(12);
      final random = Random.secure();
      for (int i = 0; i < iv.length; i++) {
        iv[i] = random.nextInt(256);
      }

      final plaintext = utf8.encode(value);

      final algorithm = AesGcm.with256bits(nonceLength: 12);

      final secretKey = SecretKey(keyData);

      final secretBox = await algorithm.encrypt(
        plaintext,
        nonce: iv,
        secretKey: secretKey,
      );

      final ciphertext = secretBox.cipherText;
      final tag = secretBox.mac.bytes;

      final result = Uint8List(iv.length + ciphertext.length + tag.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, iv.length + ciphertext.length, ciphertext);
      result.setRange(iv.length + ciphertext.length, result.length, tag);

      return base64.encode(result);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  static Future<String> decrypt(String encryptedValue, String secret) async {
    try {
      final keyData = sha256.convert(utf8.encode(secret)).bytes;

      final encryptedBytes = base64.decode(encryptedValue);

      if (encryptedBytes.length < 28) {
        throw Exception('Invalid encrypted data: too short');
      }

      final iv = encryptedBytes.sublist(0, 12);
      final ciphertext = encryptedBytes.sublist(12, encryptedBytes.length - 16);
      final tag = encryptedBytes.sublist(encryptedBytes.length - 16);

      final algorithm = AesGcm.with256bits(nonceLength: 12);

      final secretKey = SecretKey(keyData);

      final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac(tag));

      final decryptedBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }
}
