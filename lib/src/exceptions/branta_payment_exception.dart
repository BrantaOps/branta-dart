enum BrantaPaymentExceptionReason {
  tampered,
}

class BrantaPaymentException implements Exception {
  final String message;
  final BrantaPaymentExceptionReason? reason;
  const BrantaPaymentException(this.message, [this.reason]);

  @override
  String toString() => 'BrantaPaymentException: $message';
}
