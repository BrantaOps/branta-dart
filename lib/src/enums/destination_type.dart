enum DestinationType {
  bitcoinAddress('bitcoin_address'),
  bolt11('bolt11'),
  arkAddress('ark_address'),
  silentPayment('silent_payment');

  const DestinationType(this.jsonValue);
  final String jsonValue;

  static DestinationType? fromJson(String? value) {
    if (value == null) return null;
    for (final e in DestinationType.values) {
      if (e.jsonValue == value) return e;
    }
    return null;
  }
}
