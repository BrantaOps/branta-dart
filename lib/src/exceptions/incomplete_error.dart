/// A lookup that did not finish (5xx, 429, no network, or HTTP timeout). Not part of the public API.
class IncompleteError implements Exception {
  final String message;
  const IncompleteError([this.message = '']);

  @override
  String toString() => 'IncompleteError: $message';
}
