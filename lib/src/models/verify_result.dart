import 'destination.dart';
import 'payment.dart';

enum VerifyStatus { match, unknown, tampered, incomplete }

class VerifyResult {
  final VerifyStatus status;
  final List<Payment> payments;

  /// Destinations this scan actually bound — plaintext, with [Destination.type].
  /// Use these for what to send; do not dig through [payments] destinations.
  /// Empty unless [status] is [VerifyStatus.match].
  final List<Destination> matchedDestinations;
  final String verifyUrl;

  const VerifyResult({
    required this.status,
    this.payments = const [],
    this.matchedDestinations = const [],
    required this.verifyUrl,
  });
}
