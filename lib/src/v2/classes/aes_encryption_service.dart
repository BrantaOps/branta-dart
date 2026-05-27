import '../../helpers/aes_encryption.dart';
import '../interfaces/i_aes_encryption.dart';

class AesEncryptionService implements IAesEncryption {
  @override
  Future<String> encrypt(String value, String secret, {bool deterministicNonce = false}) =>
      AesEncryption.encrypt(value, secret, deterministicNonce: deterministicNonce);

  @override
  Future<String> decrypt(String encryptedValue, String secret) =>
      AesEncryption.decrypt(encryptedValue, secret);
}
