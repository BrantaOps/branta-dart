abstract class IAesEncryption {
  Future<String> encrypt(String value, String secret, {bool deterministicNonce = false});
  Future<String> decrypt(String encryptedValue, String secret);
}
