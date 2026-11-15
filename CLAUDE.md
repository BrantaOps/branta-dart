# Branta Dart SDK

If you are implementing this SDK in a consumer project, product rules (send vs receive, `match` / `unknown` / `tampered`, parent platforms) live in the [developer docs](https://developer.branta.pro). `README.md` is the Dart package: install, constructor, and samples.

## Commands

```bash
dart test
dart analyze
make coverage
```

Live example-QR lookups run only when `BRANTA_RUN_INTEGRATION=1`.

## Layout

Public API is whatever `lib/branta.dart` exports: `BrantaService`, `PaymentBuilder`, `BrantaApiOptions`, `BrantaEnvironment`, `DestinationType`, `VerifyResult`, and the payment models. Export `DestinationType` only from the enum library — do not re-export `evmTokenRails`, `evmTokenType`, or `isSecretKeyAddressType`.

- `lib/src/services/branta_service.dart` orchestrates encrypt/decrypt around HTTP. `branta_client.dart` is the raw HTTP layer. Do not export it.
- `verify` is the only lookup. A raw on-chain address (including bare `0x`) is `unknown` and does not GET. `addPayment` encrypts a copy.
- `DestinationType` is only what `addPayment` accepts: `bitcoin_address`, `bolt11`, `ark_address`, `silent_payment`, `usdt_polygon`, `usdc_polygon`, `usdt_ethereum`, `usdc_ethereum`, `usdt_bsc`, `usdc_bsc`, `usdt_base`, `usdc_base`, `usdt_arbitrum`, `usdc_arbitrum`, `usdt_tron`, `usdt_ton`, `usdt_solana`, `usdc_solana`. EVM stablecoin verify is ERC-681: `ethereum:<contract>@<chainId>/transfer?address=<deposit>&uint256=<amount>` plus `branta_id` / `branta_secret`. Chain id plus token contract select exactly one destination type (`evmTokenRails`, package-private). `uint256` is not bound. `pol:`, `eth:`, `bsc:`, `tron:`, `ton:`, and `sol:` do not verify and do not GET. `addPayment` still encrypts `usdt_tron`, `usdt_ton`, `usdt_solana`, and `usdc_solana`. A bare address is `unknown`.
- `verify()` `match` includes `matchedDestinations` (plaintext + `type`) — wallets send from that list, not by filtering `payments[].destinations`.
- `tampered` and `incomplete` are statuses. Do not throw them. Logo-domain mismatches still throw `BrantaPaymentException`. HTTP calls use a 30s timeout; a verify GET timeout is `incomplete`.
