import '../helpers/aes_gcm_cipher.dart';
import '../interfaces/aes_encryption.dart';

class AesEncryptionService implements AesEncryption {
  @override
  Future<String> encrypt(
    String value,
    String secret, {
    bool deterministicNonce = false,
  }) => AesGcmCipher.encrypt(
    value,
    secret,
    deterministicNonce: deterministicNonce,
  );

  @override
  Future<String> decrypt(String encryptedValue, String secret) =>
      AesGcmCipher.decrypt(encryptedValue, secret);
}
