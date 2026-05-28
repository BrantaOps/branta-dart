import 'payment.dart';

class AddPaymentResult {
  final Payment payment;
  final String secret;
  final String verifyUrl;

  const AddPaymentResult({
    required this.payment,
    required this.secret,
    required this.verifyUrl,
  });
}
