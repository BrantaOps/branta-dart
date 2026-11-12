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

Public API is whatever `lib/branta.dart` exports: `BrantaService`, `PaymentBuilder`, `BrantaApiOptions`, `BrantaEnvironment`, `DestinationType`, `VerifyResult`, and the payment models. Export `DestinationType` only from the enum library — do not re-export family lists or `secretKeyUriFamilies`.

- `lib/src/services/branta_service.dart` orchestrates encrypt/decrypt around HTTP. `branta_client.dart` is the raw HTTP layer. Do not export it.
- `verify` is the only lookup. A raw on-chain address (including bare `0x`) is `unknown` and does not GET. `addPayment` encrypts a copy.
- `DestinationType` is only what `addPayment` accepts: `bitcoin_address`, `bolt11`, `ark_address`, `silent_payment`, `usdt_polygon`, `usdc_polygon`, `usdt_ethereum`, `usdc_ethereum`, `usdt_bsc`, `usdc_bsc`, `usdt_tron`, `usdt_ton`, `usdt_solana`, `usdc_solana`. Stablecoin rails use a chain URI (`pol:`, `eth:`, `bsc:`, `tron:`, `ton:`, `sol:`) with `branta_id` / `branta_secret` (same secret-key pattern as bitcoin). Token is on the destination type / `matchedDestinations[].type`, not the URI scheme. A bare address is `unknown`.
- `verify()` `match` includes `matchedDestinations` (plaintext + `type`) — wallets send from that list, not by filtering `payments[].destinations`.
- `tampered` and `incomplete` are statuses. Do not throw them. Logo-domain mismatches still throw `BrantaPaymentException`.
