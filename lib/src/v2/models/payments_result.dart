import 'payment.dart';

class PaymentsResult {
  final List<Payment> payments;
  final String verifyUrl;

  const PaymentsResult({required this.payments, required this.verifyUrl});
}
