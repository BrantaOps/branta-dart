abstract class ISecretGenerator {
  String generate();
  bool get deterministicNonce;
}
