import 'payment.dart';

enum VerifyStatus { match, unknown, tampered, incomplete }

class VerifyResult {
  final VerifyStatus status;
  final List<Payment> payments;
  final String verifyUrl;

  const VerifyResult({
    required this.status,
    this.payments = const [],
    required this.verifyUrl,
  });
}
