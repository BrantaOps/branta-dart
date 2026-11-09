enum DestinationType {
  bitcoinAddress('bitcoin_address'),
  bolt11('bolt11'),
  arkAddress('ark_address'),
  silentPayment('silent_payment'),
  usdtPolygon('usdt_polygon');

  const DestinationType(this.jsonValue);
  final String jsonValue;

  /// Address rails encrypted with a random branta_secret (not a derived key).
  bool get isSecretKeyAddress =>
      this == DestinationType.bitcoinAddress ||
      this == DestinationType.usdtPolygon;

  static DestinationType? fromJson(String? value) {
    if (value == null) return null;
    for (final e in DestinationType.values) {
      if (e.jsonValue == value) return e;
    }
    return null;
  }
}
