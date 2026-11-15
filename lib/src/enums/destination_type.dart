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
  usdcSolana('usdc_solana'),
  usdtBase('usdt_base'),
  usdcBase('usdc_base'),
  usdtArbitrum('usdt_arbitrum'),
  usdcArbitrum('usdc_arbitrum');

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

/// An ERC-681 `ethereum:<contract>@<chainId>/transfer` rail.
/// Package-private — not re-exported from `package:branta/branta.dart`.
class EvmTokenRail {
  final int chainId;

  /// Lowercase, so lookup is case-insensitive.
  final String contract;
  final DestinationType type;

  const EvmTokenRail(this.chainId, this.contract, this.type);
}

/// Chain id plus token contract select one destination type.
const List<EvmTokenRail> evmTokenRails = [
  EvmTokenRail(
    1,
    '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    DestinationType.usdcEthereum,
  ),
  EvmTokenRail(
    1,
    '0xdac17f958d2ee523a2206206994597c13d831ec7',
    DestinationType.usdtEthereum,
  ),
  EvmTokenRail(
    137,
    '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359',
    DestinationType.usdcPolygon,
  ),
  EvmTokenRail(
    137,
    '0xc2132d05d31c914a87c6611c10748aeb04b58e8f',
    DestinationType.usdtPolygon,
  ),
  EvmTokenRail(
    8453,
    '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',
    DestinationType.usdcBase,
  ),
  EvmTokenRail(
    8453,
    '0xfde4c96c8593536e31f229ea8f37b2ada2699bb2',
    DestinationType.usdtBase,
  ),
  EvmTokenRail(
    42161,
    '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
    DestinationType.usdcArbitrum,
  ),
  EvmTokenRail(
    42161,
    '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
    DestinationType.usdtArbitrum,
  ),
  EvmTokenRail(
    56,
    '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
    DestinationType.usdcBsc,
  ),
  EvmTokenRail(
    56,
    '0x55d398326f99059ff775485246999027b3197955',
    DestinationType.usdtBsc,
  ),
];

DestinationType? evmTokenType(int chainId, String contract) {
  final needle = contract.toLowerCase();
  for (final rail in evmTokenRails) {
    if (rail.chainId == chainId && rail.contract == needle) return rail.type;
  }
  return null;
}

/// Address rails `addPayment` encrypts with one UUID secret.
/// Tron, TON, and Solana are included because `addPayment` still encrypts them.
/// They have no verify URI.
final Set<DestinationType> _uuidSecretDestinationTypes = {
  DestinationType.bitcoinAddress,
  for (final rail in evmTokenRails) rail.type,
  DestinationType.usdtTron,
  DestinationType.usdtTon,
  DestinationType.usdtSolana,
  DestinationType.usdcSolana,
};

/// Address rails encrypted with a random branta_secret (not a derived key).
/// Package-private — not re-exported from `package:branta/branta.dart`.
bool isSecretKeyAddressType(DestinationType type) =>
    _uuidSecretDestinationTypes.contains(type);
