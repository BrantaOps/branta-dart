class QRParseException implements Exception {
  final String message;
  const QRParseException(this.message);

  @override
  String toString() => 'QRParseException: $message';
}
