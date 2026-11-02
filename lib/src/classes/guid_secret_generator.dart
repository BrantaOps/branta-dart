import 'package:uuid/uuid.dart';
import '../interfaces/i_secret_generator.dart';

class GuidSecretGenerator implements ISecretGenerator {
  @override
  String generate() => const Uuid().v4();

  @override
  bool get deterministicNonce => false;
}
