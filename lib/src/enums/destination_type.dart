enum DestinationType {
  bitcoinAddress('bitcoin_address'),
  bolt11('bolt11'),
  arkAddress('ark_address'),
  silentPayment('silent_payment'),
  usdtPolygon('usdt_polygon'),
  usdcPolygon('usdc_polygon');

  const DestinationType(this.jsonValue);
  final String jsonValue;

  /// Polygon EVM secret-key rails. A `pol:` URI maps to this family for verify
  /// (match-if-any). Token is still the destination type on the payment.
  bool get isPolygonEvm => polygonEvmDestinationTypes.contains(this);

  /// Address rails encrypted with a random branta_secret (not a derived key).
  bool get isSecretKeyAddress =>
      this == DestinationType.bitcoinAddress || isPolygonEvm;

  static DestinationType? fromJson(String? value) {
    if (value == null) return null;
    for (final e in DestinationType.values) {
      if (e.jsonValue == value) return e;
    }
    return null;
  }
}

/// Polygon EVM secret-key rails used when verifying a `pol:` URI.
const List<DestinationType> polygonEvmDestinationTypes = [
  DestinationType.usdtPolygon,
  DestinationType.usdcPolygon,
];
