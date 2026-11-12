enum DestinationType {
  bitcoinAddress('bitcoin_address'),
  bolt11('bolt11'),
  arkAddress('ark_address'),
  silentPayment('silent_payment'),
  usdtPolygon('usdt_polygon'),
  usdcPolygon('usdc_polygon'),
  usdtEthereum('usdt_ethereum'),
  usdcEthereum('usdc_ethereum'),
  usdtBsc('usdt_bsc'),
  usdcBsc('usdc_bsc'),
  usdtTron('usdt_tron'),
  usdtTon('usdt_ton'),
  usdtSolana('usdt_solana'),
  usdcSolana('usdc_solana');

  const DestinationType(this.jsonValue);
  final String jsonValue;

  /// Address rails encrypted with a random branta_secret (not a derived key).
  bool get isSecretKeyAddress =>
      this == DestinationType.bitcoinAddress ||
      secretKeyUriFamilies.values.any((family) => family.contains(this));

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

const List<DestinationType> ethereumEvmDestinationTypes = [
  DestinationType.usdtEthereum,
  DestinationType.usdcEthereum,
];

const List<DestinationType> bscEvmDestinationTypes = [
  DestinationType.usdtBsc,
  DestinationType.usdcBsc,
];

const List<DestinationType> tronDestinationTypes = [DestinationType.usdtTron];

const List<DestinationType> tonDestinationTypes = [
  DestinationType.usdtTon,
];

const List<DestinationType> solanaDestinationTypes = [
  DestinationType.usdtSolana,
  DestinationType.usdcSolana,
];

/// URI scheme → secret-key destination family for verify (match-if-any).
const Map<String, List<DestinationType>> secretKeyUriFamilies = {
  'pol': polygonEvmDestinationTypes,
  'eth': ethereumEvmDestinationTypes,
  'bsc': bscEvmDestinationTypes,
  'tron': tronDestinationTypes,
  'ton': tonDestinationTypes,
  'sol': solanaDestinationTypes,
};
