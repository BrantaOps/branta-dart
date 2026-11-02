import 'package:uuid/uuid.dart';
import '../interfaces/secret_generator.dart';

class UuidSecretGenerator implements SecretGenerator {
  @override
  String generate() => const Uuid().v4();

  @override
  bool get deterministicNonce => false;
}
