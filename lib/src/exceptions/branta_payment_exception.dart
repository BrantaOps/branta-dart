class BrantaPaymentException implements Exception {
  final String message;
  const BrantaPaymentException(this.message);

  @override
  String toString() => 'BrantaPaymentException: $message';
}
